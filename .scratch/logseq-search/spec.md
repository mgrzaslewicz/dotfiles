# logseq-search: design decisions

## Invocation model
- Plain CLI tool, invoked from a terminal. No Logseq-app/plugin integration.
- Single Python file: algorithm + CLI + unittest tests all in one file.
  Tests run via `python -m unittest logseq_search`; can be stripped out
  later without touching the CLI code.
- Stdlib only, no third-party dependencies (no click/typer, no venv/pip
  step needed). Runs with any Python interpreter — mise can pin the
  version if desired, but nothing in the script requires it.

## Graph location
- Reads `LOGSEQ_GRAPH_DIR` env var for the graph root; falls back to the
  current working directory if unset. Chosen over a `--graph` CLI flag so
  it can be set once in a shell profile and never typed again, while still
  working ad hoc from inside any graph dir with no config.

## Scope and file discovery
- Whole graph (journals/ and pages/, recursively), not journals-only —
  tags can appear anywhere.
- Skips `logseq/` (its `bak/` subtree holds stale auto-backups that would
  otherwise show up as noisy duplicate matches), `.git`, and any other
  dot-prefixed directory.
- Only `*.md` files are considered.

## Ordering
- Chronological: journal files (`YYYY_MM_DD.md`, Logseq's default journal
  filename) sort by that date; anything else (pages, typically
  hand-titled) falls back to last-modified time.

## Tag matching
- Case-insensitive by default.
- Hierarchical prefix match by default: searching `project` also matches
  `project/website`. `--exact` flag disables this and requires an exact
  match only.
- Recognizes both `#tag` and `[[tag]]` syntaxes, including a trailing-slash
  page-ref form (`[[tag/]]`).

## Output format
- grep-style: `<relative-path>:<line-number>:<text>` per line, so results
  are directly actionable (pipeable to an editor's jump-to-line handling).
  No separate per-file banner — each line is self-sufficient.

## CLI scope (v1)
- One tag per invocation; no multi-tag OR matching. Deliberately deferred
  as speculative complexity — loop shell-side if multiple tags are needed.

## Algorithm
Ported from a working, tested Kotlin implementation (`LogseqTagExtractor`,
in the logseq-tag-extractor repo) rather than designed from scratch:
1. Parse indented Markdown lines into a tree (indent level = leading
   whitespace / 2 if the line starts with a space, else raw leading
   whitespace count — handles both space- and tab-indented lines).
2. For each line matching the tag, copy its ancestor chain into a result
   tree *without* each ancestor's siblings (siblings are unrelated
   content at the same indent level) — except the matched line itself,
   which keeps its full subtree.
3. Known accepted quirk (inherited from the Kotlin source, not a bug to
   fix silently): when multiple matches in one file share a common
   ancestor, that ancestor line is duplicated once per match rather than
   deduplicated into a single shared branch. No content is lost, just
   occasionally repeated.

## Existing Kotlin tool
Kept untouched as the reference implementation (own Maven build + JUnit
tests) — not relevant once this script is the thing living in dotfiles,
noted here only so future-you knows the Python port has a tested spec to
diff against if matching behavior is ever in question.
Repository of the original tool:
https://github.com/mgrzaslewicz/logseq-tag-extractor
