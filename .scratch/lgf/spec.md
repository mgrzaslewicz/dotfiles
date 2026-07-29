# lgf: design decisions

## Invocation model
- Fuzzy-pick-and-open helper modeled on `rgf` (same file:
  `dot_oh-my-zsh/custom/executable_file-search.zsh`, defined right after it).
- Unlike `rgf` (no args, free-text fuzzy search via `rg .`), `lgf` requires a
  tag argument up front: `lgf <tag> [extra logseq_search.py args...]`.
  `logseq_search.py` is not a text grep — it needs a tag to match against
  Logseq's `#tag` / `[[tag]]` syntax — so there's no zero-arg mode.

## Search backend
- Backend is `logseq_search.py`, not ripgrep/grep. It already does
  tag-aware matching (with ancestor-block context) that a raw text search
  can't reproduce, so rg/grep never enters the picture — fzf is only used
  to narrow down *which* matched block to jump to, same role it plays in
  `rgf`.
- All args after the tag are forwarded verbatim (`"$@"`) to
  `logseq_search.py`, so e.g. `lgf project --exact` works for free without
  `lgf` needing to know about `--exact` itself.

## Dependency guard
- Defined only `if command -v fzf >/dev/null 2>&1` — matches the guard
  style already used for `rgf`, minus the `rg` check since it's not used.

## Graph location
- `${LOGSEQ_GRAPH_DIR:-~/Logseq}` — respects an existing override (same
  variable `logseq_search.py` itself reads) but defaults to `~/Logseq`
  specifically for `lgf`, rather than falling back to CWD like the bare
  script does. `lgf`'s whole point is "search my graph from anywhere."

## Working directory
- `logseq_search.py` prints paths relative to the graph dir. `lgf` runs
  the search + fzf pick inside a subshell (`(cd "$graph_dir" && ...)`) so
  the interactive shell's cwd is never touched, but resolves the picked
  file to an absolute path (`$graph_dir/$rel_path`) before using it for
  preview/open — running `lgf` should feel like a normal command, not a
  `cd`.

## Output parsing / preview
- Output format is grep-style (`rel_path:line:text`), same shape `rgf`
  already parses — reuses the same `cut -d: -f1`/`-f2` approach.
- Preview: bat (if available) else cat, same fallback `rgf` uses, against
  the resolved absolute path.

## Opening the result
- `${EDITOR:-vi} "$abs_file" "+$line"` — unlike `rgf`'s hardcoded `vi`,
  `lgf` respects `$EDITOR` if set.
- Follow-up (separate commit, not bundled here): align `rgf` to also use
  `${EDITOR:-vi}` instead of hardcoded `vi`, for consistency between the
  two.

## Out of scope for this pass
- No fallback path if `fzf` is missing (function simply isn't defined,
  same as `rgf`).
- No interactive prompt for a missing tag argument — just requires it.
