# mise `latest` alias drift — spec

Goal: rebuilding the claude container image with a newer `mise use --global
<tool>@latest` version (claude, codegraph, python, ...) should take effect on
the next container start, without any manual `mise use ... -g` / prune step.

## Root cause (confirmed empirically, in a live container)

`setup-and-run-claude.sh` seeds the volume-backed `MISE_DATA_DIR` from the
baked `MISE_DATA_DIR_BAKE` on every start:

```bash
cp -rn "${MISE_DATA_DIR_BAKE}/." "${MISE_DATA_DIR}/"
mise reshim
```

`cp -rn` is no-clobber. Every mise-installed tool gets alias symlinks
alongside its version directories — confirmed for claude, codegraph, node,
npm, python:

```
installs/claude/2.1.220/
installs/claude/2 -> ./2.1.220
installs/claude/2.1 -> ./2.1.220
installs/claude/latest -> ./2.1.220
```

`config.toml` (`MISE_CONFIG_DIR`, baked-only, never volume-mounted) pins
`claude = "latest"` — a literal symbolic string, not a resolved version. Shim
resolution goes straight through the `latest` symlink: `which claude` →
`/opt/mise/installs/claude/latest/claude`.

On a **fresh** volume, `cp -rn` copies everything, aliases included — no bug.
On an **existing** volume from a prior image, the new version's own directory
is a new path and gets copied fine, but `latest`/`2`/`2.1` are filenames that
already exist at the destination — `cp -n` skips them. Result: `mise ls`
lists the new version, but `latest` (and therefore every symbolic-latest
tool's active binary) stays pinned to whatever it was the first time this
volume was ever populated. Same mechanism affects any tool pinned as
`"latest"` in config.toml, not just claude — currently also codegraph and
python.

## Decisions made (grilling session, 2026-07-28)

- **Fix layer**: targeted — refresh the stale alias symlink itself, not a
  timestamp/last-run-marker + manual `mise use -g` + prune scheme. The actual
  defect is one no-clobber copy skipping a handful of symlinks; no need for
  volume-state bookkeeping to work around it.
- **Scope**: generic across all tools, not hardcoded to claude/codegraph.
  Every `mise use --global X@latest` line in the Dockerfile gets covered
  automatically, including future additions — no entrypoint edit needed when
  a new tool is baked.
- **Alias scope**: only `latest`, not `2`/`2.1`-style major/minor aliases.
  Nothing in this setup ever pins a tool to `claude@2` etc. — only `"latest"`
  or an exact version appears in config.toml — so those aliases aren't
  load-bearing here.
- **Direction guard — advance-only, never regress**: a live `mise use -g
  <tool>@latest` run inside a session immediately rewrites that tool's
  `latest` symlink in the volume, and since resolution goes straight through
  the symlink, that manual upgrade already survives restarts today (because
  `cp -rn` leaves it alone). A blind force-overwrite would silently revert
  that on the next restart. Fix: per tool, compare the baked target version
  against the volume's current target version (`sort -V`); overwrite only if
  baked's is strictly newer (or the volume has no alias yet). If the volume's
  target is already newer, leave it untouched.
- **Failure tolerance**: best-effort. `setup-and-run-claude.sh` runs under
  `set -e`; one tool with a missing/odd alias must not block `claude` from
  starting. Loop only over tools that actually have a baked `latest` symlink,
  and guard the final `ln -sf`.
- **Deferred, not in scope**: pruning old unreferenced version directories
  (`2.1.215`, `2.1.217`, ... never removed today). Disk hygiene, not
  correctness — nothing breaks from extra version dirs sitting unused — and
  `mise prune` has its own risk (could remove a version some project's local
  `.mise.toml`/`.tool-versions` still pins) that needs separate auditing.

## Target design

Insert between the existing `cp -rn` and `mise reshim` in
`.containers/claude/setup-and-run-claude.sh`:

```bash
# cp -rn above is no-clobber, so on an existing volume a rebuilt image's
# newer `latest`-pinned tool version (claude, codegraph, python, ...) gets
# its version directory copied in, but the `latest` alias symlink — already
# present from a prior run — is skipped and stays pointing at the old
# version. Advance it to the baked target, but never regress a version a
# live `mise use -g <tool>@latest` already installed at runtime (that alone
# rewrites the volume's symlink immediately, and should survive restarts).
# Best-effort: `set -e` is active, one odd tool must not block startup.
for baked_latest in "${MISE_DATA_DIR_BAKE}"/installs/*/latest; do
    [ -L "${baked_latest}" ] || continue
    tool="$(basename "$(dirname "${baked_latest}")")"
    baked_version="$(basename "$(readlink "${baked_latest}")")"
    live_latest="${MISE_DATA_DIR}/installs/${tool}/latest"

    if [ -L "${live_latest}" ]; then
        live_version="$(basename "$(readlink "${live_latest}")")"
        newest="$(printf '%s\n%s\n' "${live_version}" "${baked_version}" | sort -V | tail -1)"
        [ "${newest}" = "${baked_version}" ] && [ "${live_version}" != "${baked_version}" ] || continue
    fi

    ln -sfn "./${baked_version}" "${live_latest}" 2>/dev/null || true
done
```

Note: `-n` matters — plain `ln -sf` on a destination that's already a
symlink-to-directory doesn't replace the symlink, it treats the destination
as that directory and drops the new link *inside* it instead (e.g.
`installs/claude/2.1.219/2.1.220` rather than replacing
`installs/claude/latest`). Caught by testing the loop against a simulated
stale volume before rolling it into the real script — `-n` (no-dereference)
is required to actually overwrite the alias.

Placement rationale: must run after `cp -rn` (so the baked version's
directory already exists in the volume for the new symlink to point at) and
before `mise reshim` (so regenerated shims resolve through the corrected
alias).
