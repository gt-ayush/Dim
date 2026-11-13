#!/bin/bash
set -e

cleanup() {
  echo "[INFO] Shutting down..."
  kill 0 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT

echo "[INFO] Initializing environment..."
mkdir -p /run/user/0
chmod 700 /run/user/0

# Disable KWin compositing for software-rendered/headless sessions
echo "[INFO] Disabling KWin compositing..."
mkdir -p /root/.config
if [ -f /root/.config/kwinrc ]; then
  if grep -q '^\[Compositing\]' /root/.config/kwinrc; then
    if grep -q '^Enabled=' /root/.config/kwinrc; then
      sed -i 's/^Enabled=.*/Enabled=false/' /root/.config/kwinrc
    else
      sed -i '/^\[Compositing\]/a Enabled=false' /root/.config/kwinrc
    fi
  else
    printf '\n[Compositing]\nEnabled=false\n' >> /root/.config/kwinrc
  fi
else
  printf '[Compositing]\nEnabled=false\n' > /root/.config/kwinrc
fi

# 1. Start SSH Server
echo "[INFO] Starting OpenSSH Server..."
/usr/sbin/sshd

# 2. Start xrdp services
echo "[INFO] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman

echo "[INFO] Starting xrdp..."
/usr/sbin/xrdp

echo "[SUCCESS] All services are running."
echo "  - SSH: port 22"
echo "  - RDP: port 3389 (user: root, password: changeme)"

# Keep the script running to prevent the container from exiting
sleep infinity &
wait $!

