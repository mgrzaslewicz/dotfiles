#!/bin/bash
# Runs as root (see Dockerfile: USER root, CMD points here). Re-grants
# newuidmap/newgidmap privilege fresh, under THIS container instance's own
# user namespace, then drops to claude-user for everything else. Must happen
# here, not at image build time — see the Dockerfile comment above the ADD
# for this file.
#
# Setuid-root alone can never work for this, no matter when it's applied:
# the kernel's setuid fast path only grants full capabilities when the file
# is owned by the true *global* uid 0, and no rootless container — this one
# included, even as its own "root" — ever has that. Only file capabilities
# work here, because the kernel checks those via a rootid match against the
# *current* namespace rather than requiring global root, and setting them
# fresh right now makes that match self-consistent by construction. Setuid
# and file-caps together on the same file is its own landmine (a different
# failure, "Permission denied" opening uid_map) so the setuid bit is
# stripped right after.
set -euo pipefail

chown root:root /usr/bin/newuidmap /usr/bin/newgidmap
setcap cap_setuid=ep /usr/bin/newuidmap
setcap cap_setgid=ep /usr/bin/newgidmap
chmod -s /usr/bin/newuidmap /usr/bin/newgidmap

exec setpriv --reuid=claude-user --regid=claude-user --init-groups -- \
    /home/claude-user/setup-and-run-claude.sh "$@"
