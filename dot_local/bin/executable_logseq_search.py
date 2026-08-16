#!/usr/bin/env python3
"""logseq_search.py — search a Logseq graph for a tag, with block context.

Single-file, stdlib-only CLI. Given a tag, it scans every Markdown file in
a Logseq graph (journals/, pages/, and anything else under the graph root)
and prints each block that references the tag together with just enough
surrounding context to understand where it came from.

ALGORITHM
---------
Logseq stores an outline as plain Markdown where indentation encodes
parent/child relationships between blocks (one block per top-level bullet
or heading, deeper bullets are children). The search works in three phases:

1. Parse each file's lines into a tree, using indentation to link every
   line to its parent line. A line's indent level is derived the same way
   Logseq itself renders it: if the line starts with a space, the leading
   whitespace is halved (2 spaces == 1 level); otherwise the raw leading
   whitespace count is used as-is (covers tab-indented or unindented
   lines). Blank lines are skipped entirely, matching Logseq's own
   rendering (they never carry an outline position).

2. Walk the tree looking for lines that reference the tag. For every
   match, walk back up to the root and copy that ancestor chain into a
   result tree — but *without* each ancestor's siblings, since siblings are
   unrelated blocks that just happen to share an indent level. The matched
   line itself is the exception: it keeps its full subtree, since its
   children are part of the content that made it worth showing.

   If a file has multiple independent matches, each match's ancestor chain
   is copied in independently — so a shared ancestor line can appear once
   per match rather than being deduplicated into a single branch. This
   mirrors the reference implementation this script was ported from
   (LogseqTagExtractor.kt in this repo): duplicated ancestor lines are a
   known, accepted quirk rather than a bug to silently "fix", since no
   content is lost either way.

3. Flatten the result tree back into an ordered list of (line number,
   text) pairs via a pre-order walk, and print them prefixed with
   "<relative path>:<line number>:" (grep -n style), so results can be
   piped into an editor's jump-to-line handling.

TAG MATCHING
------------
A tag reference is recognized as either `#sometag` or `[[some tag]]`
(Logseq's two tagging syntaxes), including the hierarchical form
`#parent/child` or `[[parent/child]]`. Matching is case-insensitive.
By default, searching for "project" also matches "project/website"
(hierarchical prefix match) since a sub-tag is conceptually part of its
parent tag; pass --exact to require an exact match only.

PAGE INCLUSION
--------------
Pass -ip/--include-page to also print the full content of the tag's own
page file, if one exists. The tag is resolved to a filename by replacing
"/" with "__" (Logseq's on-disk namespace encoding) and appending ".md";
e.g. tag "example/page" resolves to "example__page.md". The lookup is
case-insensitive and searches the same file set as the normal tag search
(anywhere under the graph root, minus the skipped directories below). If
no matching page file exists, the flag is a silent no-op. The page's
content is appended after the normal per-file match output, in the same
"<path>:<line>:<text>" format, printed line-by-line without filtering —
so lines that also matched the tag directly may appear twice.

GRAPH LOCATION
--------------
The graph root is taken from the LOGSEQ_GRAPH_DIR environment variable if
set, otherwise the current working directory is used. This lets you set
it once in your shell profile and run the search from anywhere, while
still working ad hoc from inside any graph directory without config.

FILE DISCOVERY AND ORDERING
----------------------------
Every *.md file under the graph root is scanned, except inside `logseq/`
(Logseq's own config/backup directory — its bak/ subtree in particular can
contain many stale auto-saved copies of pages, which would otherwise show
up as noisy duplicate matches), `.git`, and any other dot-prefixed
directory.

Results are printed in chronological order: journal files (named
YYYY_MM_DD.md, Logseq's default journal filename format) are ordered by
that date; any other file (typically pages/*.md, which are hand-titled)
falls back to its last-modified time.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import textwrap
import unittest
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path

JOURNAL_DATE_FORMAT = "%Y_%m_%d"
SKIPPED_DIR_NAMES = {"logseq", ".git"}

# Matches `#tag` (no whitespace/brackets) or `[[tag]]` (anything but brackets,
# so multi-word page references like [[some tag]] are captured whole).
TAG_REFERENCE_PATTERN = re.compile(r"#([^\s\[\]]+)|\[\[([^\[\]]+)\]\]")


@dataclass
class Node:
    """One line of a parsed outline, plus its place in the tree."""

    text: str
    indent_level: int
    line_no: int = 0
    parent: "Node | None" = None
    children: list["Node"] = field(default_factory=list)

    def parent_or_root(self) -> "Node":
        return self.parent if self.parent is not None else self

    def is_root(self) -> bool:
        return self.parent is None

    def path_from_root(self) -> list["Node"]:
        path: list[Node] = []
        node: Node | None = self
        while node is not None:
            path.insert(0, node)
            node = node.parent
        return path

    def shallow_copy(self, with_children: bool) -> "Node":
        copy = Node(self.text, self.indent_level, self.line_no, self.parent)
        if with_children:
            copy.children = self.children
        return copy


def count_indent(line: str) -> int:
    leading_ws = len(line) - len(line.lstrip())
    if line.startswith(" "):
        return leading_ws // 2
    return leading_ws


def parse_tree(content: str) -> Node:
    root = Node("", 0)
    current = root
    for line_no, line in enumerate(content.splitlines(), start=1):
        if not line.strip():
            continue
        indent = count_indent(line)
        if indent > current.indent_level:
            node = Node(line, indent, line_no, current)
            current.children.append(node)
            current = node
        elif indent < current.indent_level:
            level_diff = current.indent_level - indent
            for _ in range(level_diff + 1):
                current = current.parent_or_root()
            node = Node(line, indent, line_no, current)
            current.children.append(node)
            current = node
        else:
            parent = current.parent_or_root()
            node = Node(line, indent, line_no, parent)
            parent.children.append(node)
            current = node
    return root


def extract_tag_references(line: str) -> list[str]:
    tags = []
    for hashtag, page_ref in TAG_REFERENCE_PATTERN.findall(line):
        tag = hashtag or page_ref
        tags.append(tag.rstrip("/"))
    return tags


def matches_tag(line: str, query: str, prefix_match: bool, case_insensitive: bool) -> bool:
    q = query.lower() if case_insensitive else query
    for tag in extract_tag_references(line):
        t = tag.lower() if case_insensitive else tag
        if t == q:
            return True
        if prefix_match and t.startswith(q + "/"):
            return True
    return False


def merge_path_into(collector: Node, matched_node: Node) -> None:
    """Copy matched_node's ancestor chain (without siblings) into collector.

    See the ALGORITHM section of the module docstring for why this always
    appends a fresh copy rather than reusing a previously-added ancestor.
    """
    path = matched_node.path_from_root()[1:]  # drop the real root
    current = collector
    last_index = len(path) - 1
    for index, node in enumerate(path):
        with_children = index == last_index
        copy = node.shallow_copy(with_children)
        current.children.append(copy)
        current = copy


def flatten(node: Node, results: list[tuple[int, str]]) -> None:
    if not node.is_root():
        results.append((node.line_no, node.text))
    for child in node.children:
        flatten(child, results)


def find_context_blocks(
    content: str,
    tag: str,
    prefix_match: bool = True,
    case_insensitive: bool = True,
) -> list[tuple[int, str]]:
    root = parse_tree(content)
    collector = Node("", 0)

    def visit(node: Node) -> None:
        if matches_tag(node.text, tag, prefix_match, case_insensitive):
            merge_path_into(collector, node)
        for child in node.children:
            visit(child)

    visit(root)

    results: list[tuple[int, str]] = []
    flatten(collector, results)
    return results


def file_sort_key(path: Path) -> date:
    basename = path.name
    date_part = basename[:-3] if basename.endswith(".md") else basename
    try:
        return datetime.strptime(date_part, JOURNAL_DATE_FORMAT).date()
    except ValueError:
        return datetime.fromtimestamp(path.stat().st_mtime).date()


def discover_markdown_files(graph_dir: Path) -> list[Path]:
    files = []
    for dirpath, dirnames, filenames in os.walk(graph_dir):
        dirnames[:] = [
            d for d in dirnames if d not in SKIPPED_DIR_NAMES and not d.startswith(".")
        ]
        for filename in filenames:
            if filename.endswith(".md"):
                files.append(Path(dirpath) / filename)
    return sorted(files, key=file_sort_key)


def resolve_graph_dir() -> Path:
    env_value = os.environ.get("LOGSEQ_GRAPH_DIR")
    if env_value:
        return Path(env_value).expanduser()
    return Path.cwd()


def page_filename_for_tag(tag: str) -> str:
    """Logseq's on-disk filename for the page a tag refers to.

    Namespace separators ("/") become "__"; everything else (including
    spaces) is kept literal, matching how Logseq names page files itself.
    """
    return tag.replace("/", "__") + ".md"


def find_page_file(files: list[Path], tag: str) -> Path | None:
    """Find the file among `files` that is the page for `tag`, if any."""
    target = page_filename_for_tag(tag).lower()
    for path in files:
        if path.name.lower() == target:
            return path
    return None


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Search a Logseq graph for a tag, printing each matching "
        "block with its ancestor context (no unrelated siblings)."
    )
    parser.add_argument("tag", help="tag to search for, without # or [[ ]] (e.g. 'project')")
    parser.add_argument(
        "--exact",
        action="store_true",
        help="require an exact tag match; by default 'project' also matches "
        "hierarchical sub-tags like 'project/website'",
    )
    parser.add_argument(
        "-ip",
        "--include-page",
        action="store_true",
        help="also print the full content of the tag's own page file, if one "
        "exists (e.g. tag 'example/page' resolves to page file "
        "'example__page.md')",
    )
    args = parser.parse_args(argv)

    graph_dir = resolve_graph_dir()
    prefix_match = not args.exact
    files = discover_markdown_files(graph_dir)

    for path in files:
        content = path.read_text(encoding="utf-8")
        matches = find_context_blocks(content, args.tag, prefix_match=prefix_match)
        if not matches:
            continue
        rel_path = path.relative_to(graph_dir)
        for line_no, text in matches:
            print(f"{rel_path}:{line_no}:{text}")

    if args.include_page:
        page_path = find_page_file(files, args.tag)
        if page_path is not None:
            content = page_path.read_text(encoding="utf-8")
            rel_path = page_path.relative_to(graph_dir)
            for line_no, text in enumerate(content.splitlines(), start=1):
                print(f"{rel_path}:{line_no}:{text}")


# ---------------------------------------------------------------------------
# Tests — run with: python -m unittest logseq_search
# ---------------------------------------------------------------------------


class LogseqSearchTests(unittest.TestCase):
    NESTED_MARKDOWN = textwrap.dedent(
        """\
        # Title 0
          - subtitle 0.1
          - subtitle 0.2
            - subcontent 0.2.1 [[tag 1]]
              - subcontent 0.2.1.1
            - subcontent 0.2.2 #tag-2
        # Title 1
        """
    )

    def _texts(self, content: str, tag: str, **kwargs) -> list[str]:
        return [text for _, text in find_context_blocks(content, tag, **kwargs)]

    def test_extracts_ancestors_without_siblings_and_full_subtree(self):
        result = self._texts(self.NESTED_MARKDOWN, "tag 1")
        self.assertEqual(
            result,
            [
                "# Title 0",
                "  - subtitle 0.2",
                "    - subcontent 0.2.1 [[tag 1]]",
                "      - subcontent 0.2.1.1",
            ],
        )

    def test_no_match_returns_empty(self):
        self.assertEqual(self._texts(self.NESTED_MARKDOWN, "no-such-tag"), [])

    def test_case_insensitive_by_default(self):
        result = self._texts(self.NESTED_MARKDOWN, "TAG 1")
        self.assertIn("    - subcontent 0.2.1 [[tag 1]]", result)

    def test_hashtag_and_trailing_slash_page_ref_forms(self):
        markdown = "- a #project\n- b [[project/]]\n- c [[unrelated]]\n"
        self.assertEqual(
            self._texts(markdown, "project"),
            ["- a #project", "- b [[project/]]"],
        )

    def test_prefix_matches_hierarchical_subtag_by_default(self):
        markdown = "- top level\n  - nested #project/website\n"
        result = self._texts(markdown, "project")
        self.assertIn("  - nested #project/website", result)

    def test_exact_flag_disables_hierarchical_prefix_match(self):
        markdown = "- top level\n  - nested #project/website\n"
        result = self._texts(markdown, "project", prefix_match=False)
        self.assertEqual(result, [])

    def test_line_numbers_reported_are_1_indexed(self):
        markdown = "- first\n- second #findme\n"
        result = find_context_blocks(markdown, "findme")
        self.assertEqual(result, [(2, "- second #findme")])

    def test_blank_lines_do_not_break_indent_tracking(self):
        markdown = "# Title\n\n  - child #findme\n"
        result = self._texts(markdown, "findme")
        self.assertEqual(result, ["# Title", "  - child #findme"])


class FileDiscoveryTests(unittest.TestCase):
    def test_skips_logseq_git_and_dotfile_dirs(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "journals").mkdir()
            (root / "journals" / "2025_01_02.md").write_text("- entry\n")
            (root / "pages").mkdir()
            (root / "pages" / "notes.md").write_text("- note\n")
            (root / "logseq" / "bak").mkdir(parents=True)
            (root / "logseq" / "bak" / "stale.md").write_text("- stale\n")
            (root / ".git").mkdir()
            (root / ".git" / "hooks.md").write_text("- not real\n")

            found = {p.relative_to(root) for p in discover_markdown_files(root)}
            self.assertEqual(
                found,
                {Path("journals/2025_01_02.md"), Path("pages/notes.md")},
            )

    def test_journal_files_sorted_by_filename_date(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "2025_03_01.md").write_text("")
            (root / "2025_01_15.md").write_text("")
            (root / "2025_02_10.md").write_text("")

            found = [p.name for p in discover_markdown_files(root)]
            self.assertEqual(found, ["2025_01_15.md", "2025_02_10.md", "2025_03_01.md"])


class PageResolutionTests(unittest.TestCase):
    def test_slash_becomes_double_underscore(self):
        self.assertEqual(page_filename_for_tag("example/page"), "example__page.md")

    def test_multiple_slashes_and_spaces_kept_literal(self):
        self.assertEqual(
            page_filename_for_tag("my project/sub page"), "my project__sub page.md"
        )

    def test_no_slash_is_unchanged_besides_extension(self):
        self.assertEqual(page_filename_for_tag("project"), "project.md")

    def test_find_page_file_matches_case_insensitively(self):
        files = [Path("pages/example__page.md"), Path("journals/2025_01_01.md")]
        self.assertEqual(find_page_file(files, "Example/Page"), files[0])

    def test_find_page_file_returns_none_when_absent(self):
        files = [Path("journals/2025_01_01.md")]
        self.assertIsNone(find_page_file(files, "example/page"))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        sys.exit(unittest.main(argv=[sys.argv[0]] + sys.argv[2:]))
    main()
