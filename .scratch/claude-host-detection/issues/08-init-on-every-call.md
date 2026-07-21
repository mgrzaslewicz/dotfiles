# Running init on every call

Type: grilling
Status: resolved

## Question

The container's `CMD` runs `setup-and-run-claude.sh`, which does idempotent
init (symlinking `~/.claude.json` into the credentials volume, `mise
reshim`, plugin/settings reconciliation, codegraph install/sync, rtk hook
install) and, before this change, ended with a bare `claude` — no arg
forwarding. If the wrapper passes `claude "$@"` as the podman command, that
override replaces `CMD` entirely and `setup-and-run-claude.sh` never runs —
found while designing the wrapper, not previously documented. On a fresh or
just-reset volume this would skip the credentials symlink and other
first-run setup. Should the wrapper run the setup script on every call
(forwarding args to claude at its end), or skip it and require the volume to
already be primed by a prior interactive `claude-toolbox` run?

## Answer

Run the setup script every call: change `setup-and-run-claude.sh`'s final
line from `claude` to `exec claude "$@"`, and have the wrapper invoke
`podman run ... claude-toolbox:latest /home/claude-user/setup-and-run-claude.sh "$@"`
(naming the script explicitly, not `claude`). Every call — interactive or
automated — gets the idempotent init before claude runs, so a fresh volume
or freshly rebuilt image just works with no separate priming step. Adds a
small amount of per-call overhead (mostly fast idempotent jq checks plus a
codegraph sync), judged worth it for correctness. No-op for
`claude-toolbox()`'s existing invocation, which never passes a command
override, so `"$@"` is empty there.
