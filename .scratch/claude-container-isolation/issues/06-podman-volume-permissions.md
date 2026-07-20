# Verify named volume works with rootless podman + --userns=keep-id

Type: task
Status: open

## Question

The current bind-mount setup relies on `--userns=keep-id` to match host UID/GID so the bind-mounted host directories are writable by `claude-user` inside the container. Confirm that a podman named volume (not a bind mount) is writable by `claude-user` under the same `--userns=keep-id` setup, and note any permission fixup needed (e.g. an init step that chowns the volume on first use, since named volumes are typically initialized as root-owned). This is a hands-on check (spin up a scratch volume + container, `touch`/`ls -la` inside), not a design decision — do it and record what was found.
