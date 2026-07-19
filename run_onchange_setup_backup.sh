#!/bin/bash
set -e
set -x

# containers often have no systemctl
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable backup.service
    systemctl --user start backup.service

    systemctl --user enable backup.timer
    systemctl --user start backup.timer

    echo "Check backup.service status: systemctl --user status backup.service"
    echo "View backup.service logs: journalctl --user-unit backup.service -f"
else
    echo "systemctl is not available; skipping user service/timer setup"
fi

mkdir -p ~/.vim/backup
