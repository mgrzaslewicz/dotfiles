# Verify named volume works with rootless podman + --userns=keep-id

Type: task
Status: resolved

## Question

The current bind-mount setup relies on `--userns=keep-id` to match host UID/GID so the bind-mounted host directories are writable by `claude-user` inside the container. Confirm that a podman named volume (not a bind mount) is writable by `claude-user` under the same `--userns=keep-id` setup, and note any permission fixup needed (e.g. an init step that chowns the volume on first use, since named volumes are typically initialized as root-owned). This is a hands-on check (spin up a scratch volume + container, `touch`/`ls -la` inside), not a design decision — do it and record what was found.

## Answer

**No permission fixup needed — confirmed empirically.** Built a throwaway image replicating the real Dockerfile's user-creation logic exactly (`groupdel`/`userdel` any pre-existing entry at that GID/UID, then `groupadd`/`useradd claude-user` with `--build-arg USER_ID="$(id -u)" --build-arg GROUP_ID="$(id -g)"`), then ran it with `podman run --rm --userns=keep-id -v <fresh-named-volume>:/home/claude-user/.claude:rw <image>` — no explicit `--user` override, relying on the image's baked `USER claude-user` (matching how `claude-toolbox()` actually invokes it).

- On first mount, podman auto-chowned the empty named volume to match the container's running user (`claude-user`, UID/GID = host's, via `--userns=keep-id`) — `ls -lan` showed the volume root owned by that UID/GID, not root.
- `touch`/write succeeded immediately as `claude-user`, no permission errors.
- Re-running a second container against the *same* volume showed the written file persisted and remained writable — confirms cross-run persistence works as expected for the design in tickets 03/04.

Conclusion: `claude-toolbox()` can switch its `-v ${HOME}/.claude:/home/claude-user/.claude:rw` bind-mount line to `-v claude-toolbox-config:/home/claude-user/.claude:rw` (a named volume) with no other changes needed for permissions — `--userns=keep-id` plus the existing baked-UID `claude-user` account is sufficient.
