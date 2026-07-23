# Container git identity + SSH access — spec

Reached via a `/grilling` session. Goal: let the claude-toolbox container make
git commits with the right author identity, and authenticate over SSH for git
operations (including push), without baking any secret into the image or
exposing raw private key material to the agent process.

## Starting state (confirmed by inspection, not assumption)

- No host directory is mounted into the container except the project dir
  itself (`$PWD` → same or `/workspace/$(basename "$PWD")`). No `~/.gitconfig`,
  no `~/.ssh`, reach the container today.
- `user.name` is unset everywhere in the container; `user.email` only appears
  in this exact repo's clone because `.git/config` happens to carry it along
  with the bind-mounted project directory.
- The host's real `~/.gitconfig` uses `includeIf`-style per-repo identity
  (confirmed: this repo's `.git/config` has `user.email=...@gmail.com`, a
  personal address, while the session's own work email is `...@olx.pl` — i.e.
  identity depends on which repo you're in, not a single global value) and
  also sets `core.sshCommand=ssh -i ~/.ssh/olx_mg_github -o IdentitiesOnly=yes`
  — a host-only key path that would break inside the container if inherited
  verbatim.

## 1. Git identity — env vars, not a mounted gitconfig

Resolved on the host **per session**, at launch, via:

```bash
GIT_AUTHOR_NAME="$(git -C "$PWD" config --get user.name 2>/dev/null || true)"
GIT_AUTHOR_EMAIL="$(git -C "$PWD" config --get user.email 2>/dev/null || true)"
```

then passed into the container as `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` +
`GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL` env vars — git honors these
directly, no config file needed. `-C "$PWD"` (not `--global`) reproduces git's
own resolution order (system → global → `includeIf` → local) for whichever
directory is bind-mounted that session, which a flat `--global` lookup would
get wrong for any repo with a conditional override. Resolving once at launch
is correct since `$PWD` is fixed for the container's whole lifetime.

Rejected: mounting `~/.gitconfig` directly. Would also drag in
`core.sshCommand`, signing config, and credential helpers that have no
business inside the sandbox — confirmed concretely by the `-i
~/.ssh/olx_mg_github` example above.

If either field resolves empty, it's just omitted — no warning, no launch
failure. Commit fails with git's own normal "author identity unknown" error,
same as today.

## 2. SSH access — agent forwarding, not mounted private keys

Scope needed: **broad** — general SSH-based git auth during a session (clone,
fetch, push against whatever the host can already reach), not a fixed list of
repos known in advance.

Mechanism: forward the host's running ssh-agent socket
(`$SSH_AUTH_SOCK`), not the `~/.ssh` private key files.

**Why this over a raw key mount:** this is an LLM agent with file
read/write access. Raw private key bytes sitting in the container filesystem
are a one-command exfiltration risk (prompt injection or a misbehaving
session could just `cat` and paste them) — a risk that persists for the
life of the key, not just the container. Agent forwarding exposes only a
live signing channel tied to keys already loaded on the host: nothing to
copy out, and it dies with the container or the host agent session.

```bash
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    SSH_MOUNT_ARGS+=(-v "${SSH_AUTH_SOCK}:/tmp/ssh-agent.sock:rw" --env SSH_AUTH_SOCK=/tmp/ssh-agent.sock)
fi
```

Only forwarded when the host actually has an agent socket live at launch
time — same "degrade silently, don't fail the launch" pattern as the git
identity vars.

### Supporting metadata (non-secret, read-only)

Agent forwarding alone isn't sufficient: host aliases live in `~/.ssh/config`
and host-key verification needs `~/.ssh/known_hosts`. Neither file contains
key material, so both are mounted read-only when present:

```bash
[ -f "${HOME}/.ssh/config" ]       && SSH_MOUNT_ARGS+=(-v "${HOME}/.ssh/config:/home/claude-user/.ssh/config:ro")
[ -f "${HOME}/.ssh/known_hosts" ]  && SSH_MOUNT_ARGS+=(-v "${HOME}/.ssh/known_hosts:/home/claude-user/.ssh/known_hosts:ro")
```

### New-host handling

A read-only known_hosts can verify already-known hosts but can't persist a
brand-new one. Fixed by layering a second, container-writable known_hosts
file on top via ssh's colon-separated `UserKnownHostsFile` list, combined
with `StrictHostKeyChecking=accept-new` (verify existing entries strictly,
auto-accept-and-persist genuinely new ones to the writable file only — the
host's real known_hosts is never written to):

```bash
--env "GIT_SSH_COMMAND=ssh -o UserKnownHostsFile=/home/claude-user/.ssh/known_hosts:/home/claude-user/.ssh/known_hosts.local -o StrictHostKeyChecking=accept-new"
```

This also solves the `core.sshCommand` problem from the starting state:
`GIT_SSH_COMMAND` has top precedence over `core.sshCommand` in git's
resolution order, so this env var silently supersedes any repo/global
override that references a host-only `-i <key>` path — git operations use
the generic `ssh` here, which offers only the agent's loaded identities
(no `-i` flag; any `IdentityFile` line the mounted `~/.ssh/config` still
specifies just points at a path that doesn't exist in the container and is
silently skipped by ssh in favor of the agent).

### Push is now possible — accepted, not blocked

Broad forwarding means the container can authenticate for `git push`, not
just fetch/clone — this replaces the original "no SSH keys, so no push"
assumption. Explicitly discussed and accepted: no push-blocking wrapper was
added, since wrapping `git push` around otherwise-broad forwarded access
would be a false sense of security (the agent could still push via other
tools/transports once it has auth). Relies on the existing auto-permission
classifier and normal review instead.

## 3. Runtime-only, both launch points

All of the above is computed/mounted fresh at every container start — never
baked into the image. Partly forced (a live agent socket can't be baked;
there's nothing to copy at build time) and partly by convention (matches the
Dockerfile's existing "keep credentials/config outside the image" principle
and the pattern already used for `claude-toolbox-config`/`-config-json`/
`-mise` volumes).

Applied identically to both:
- `claude-toolbox()` in `dot_oh-my-zsh/custom/executable_claude.zsh`
- the standalone `dot_local/bin/executable_claude` wrapper

These two scripts already duplicate their `podman run` construction rather
than sharing a lib (see `claude-host-detection/spec.md` §1) — this change
follows that existing precedent rather than introducing a new abstraction.

## 4. One Dockerfile change: `~/.ssh` mount anchor

Bind-mounting individual files (`config`, `known_hosts`) into
`/home/claude-user/.ssh/` needs that directory to already exist with correct
ownership/permissions, or the mount points get created root-owned. Added to
the existing user-setup `RUN mkdir -p ...` block:

```dockerfile
mkdir -p ... /home/claude-user/.ssh \
    && chmod 700 /home/claude-user/.ssh \
    && chown -R claude-user:claude-user ... /home/claude-user/.ssh
```

`setup-and-run-claude.sh` needs no changes — env vars and mounted
sockets/files just flow through `tini` → `exec claude "$@"` → any Bash-tool
subprocess Claude spawns.

## 5. Amendment: broken on macOS + podman machine

Discovered after the above shipped: on macOS, `podman machine` runs containers
inside a Linux VM, with the VM's filesystem shared from the host over
virtiofs. Bind-mounting `$SSH_AUTH_SOCK` there fails outright --

```
Error: statfs /var/run/com.apple.launchd.PxraXfU4IZ/Listeners: no such file or directory
```

-- because macOS's `ssh-agent` socket is launchd-activated: it lives under a
dynamic `/var/run/com.apple.launchd.*/Listeners/...` path that virtiofs can't
pass an `statfs` through, unlike a normal file. This is a real, currently-open
Podman limitation (containers/podman#23245, #23785), not something fixable by
changing the mount path or flags. Unlike a merely-absent socket (which the
existing `[ -S "$SSH_AUTH_SOCK" ]` check already tolerates), attempting this
mount doesn't just skip SSH forwarding -- it fails the whole `podman run`, so
the container never starts at all on macOS.

**Immediate fix (this amendment):** skip the SSH_AUTH_SOCK mount entirely when
the host is Darwin (`uname -s`), in both `claude-toolbox()` and the standalone
`executable_claude` wrapper. Same "degrade silently" precedent as an absent
socket: git identity + `~/.ssh/config`/`known_hosts` mounts still work, the
container starts, only SSH-based git auth is unavailable. Rejected leaving it
as-is: a container that refuses to start is strictly worse than one that
starts without git push access, since every other feature (editing, local
commits, non-git tool use) is blocked along with it.

**Not done here, left for a follow-up:** a working forwarding path exists --
relay over TCP instead of a bind-mounted socket, the same trick used for
Docker Desktop's `host.docker.internal` ssh-agent forwarding: a `socat`
listener on the macOS host bridges `$SSH_AUTH_SOCK` to a loopback TCP port,
and a second `socat` inside the container bridges `host.containers.internal:
<port>` back to a local unix socket that becomes `SSH_AUTH_SOCK`. Deferred
because it needs `socat` baked into the Dockerfile, host-side process
lifecycle management (start/reuse/clean up the relay across invocations), and
changes to `setup-and-run-claude.sh` to start the container-side half before
`exec claude` -- real scope, and it also modestly widens exposure (the
relayed port becomes reachable by anything that can reach that podman
machine's VM gateway, not just this one container). Revisit if losing SSH git
auth on macOS becomes an active pain point rather than a degrade-gracefully
case.


## 6. Amendment: forwarded agent with zero loaded identities

Discovered live, from inside a running container: `git push` failed with
`Permission denied (publickey)` even though the socket forwarding from §2
worked correctly (the container could reach the agent, and github.com's host
key was already trusted via the mounted `known_hosts` — confirmed by `ssh -v`
going straight to the publickey stage with no host-key prompt). Root cause,
confirmed with `ssh-add -l` on both sides of the socket:
`get_agent_identities: ssh_fetch_identitylist: agent contains no identities`
— the host's ssh-agent process was live but had no keys loaded into it at
the time the container was launched.

This is a distinct failure mode from everything §2 already handles: a *live
but empty* agent is not the same as *no socket* (`[ -S "$SSH_AUTH_SOCK" ]`
passes either way) — forwarding succeeds, authentication still fails, and
nothing in the existing degrade-silently logic surfaces or fixes it.

**Fix:** since the mount is a direct pass-through of the host's actual agent
process (not a copy), loading a key into the host agent takes effect for an
already-running container immediately, no restart needed. Applied that as an
auto-load step, in the same `if` guard as the socket mount (so it only runs
when forwarding is actually going to happen — i.e. not on Darwin): scan
`~/.ssh/*` for files whose content starts with `PRIVATE KEY` (skipping
`*.pub`, `known_hosts*`, `config`, `authorized_keys`), and `ssh-add` each one
before mounting the socket.

```bash
for key_file in "${HOME}/.ssh"/*; do
    [ -f "$key_file" ] || continue
    case "$key_file" in
        *.pub|*known_hosts*|*/config|*/authorized_keys) continue ;;
    esac
    if head -c 100 "$key_file" 2>/dev/null | grep -q "PRIVATE KEY"; then
        ssh-add "$key_file" </dev/null >/dev/null 2>&1 || true
    fi
done
```

`</dev/null` on the `ssh-add` call makes a passphrase prompt fail fast
instead of hanging when there's no controlling tty — matters for
`dot_local/bin/executable_claude`, which is explicitly also invoked
non-interactively (see its own comments on `TTY_FLAG`). `|| true` on both the
`grep -q` branch and the `ssh-add` call is required, not cosmetic: the
standalone script runs under `set -euo pipefail`, and a bare
`grep -q ... && ssh-add ...` as a statement would abort the whole script the
first time a key doesn't match or fails to add. Re-adding an already-loaded
key is a harmless no-op.

**Accepted tradeoff, not fully resolved:** this widens what's reachable
through the forwarded socket from *whatever keys the user happened to have
manually `ssh-add`ed* to *every private key `ssh-add` can load from
`~/.ssh`* — work keys, server-admin keys, anything, not just the one this
repo's `core.sshCommand` names. That's a meaningfully larger blast radius
under the same "LLM agent with file read/write access" threat model that
justified agent-forwarding-over-key-mounting in §2 in the first place (the
container still never sees raw key bytes, but it gains a live signing
channel for keys that have nothing to do with this repo). Chosen anyway,
explicitly, since the auto-load is scoped to "every key already sitting
unencrypted-at-rest as a file the host user controls" — no new secret
exposure, just broader agent reach. Revisit if a narrower/allowlisted scope
becomes necessary (e.g. loading only the key implied by the current repo's
`core.sshCommand`/remote host, if one is set).

Applied identically to both `claude-toolbox()` in
`dot_oh-my-zsh/custom/executable_claude.zsh` and the standalone
`dot_local/bin/executable_claude` wrapper, same as §3.
