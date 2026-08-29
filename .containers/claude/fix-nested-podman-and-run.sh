#!/bin/bash
# Runs as root (see Dockerfile: USER root, CMD points here). Re-grants
# newuidmap/newgidmap setuid-root fresh, under THIS container instance's own
# user namespace, then drops to claude-user for everything else. Must happen
# here, not at image build time — see the Dockerfile comment above the ADD
# for this file.
set -euo pipefail

chown root:root /usr/bin/newuidmap /usr/bin/newgidmap
chmod 4755 /usr/bin/newuidmap /usr/bin/newgidmap

exec setpriv --reuid=claude-user --regid=claude-user --init-groups -- \
    /home/claude-user/setup-and-run-claude.sh "$@"
