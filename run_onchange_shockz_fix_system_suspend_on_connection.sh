#!/bin/bash
set -e
set -x

if command -v udevadm >/dev/null 2>&1; then
  sudo install -m 0644 /dev/stdin "/etc/udev/rules.d/99-shokz-fix.rules" <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="3511", ATTRS{idProduct}=="2b1e", DRIVER=="usbhid", ATTR{authorized}="0"
EOF
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi
