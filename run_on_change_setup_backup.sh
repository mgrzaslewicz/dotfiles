#!/bin/bash
set -e
set -x

systemctl --user daemon-reload
systemctl --user enable backup.service
systemctl --user start backup.service

systemctl --user enable backup.timer
systemctl --user start backup.timer

echo "Check backup.service status: systemctl --user status backup.service"
echo "View backup.service logs: journalctl --user-unit backup.service -f"
