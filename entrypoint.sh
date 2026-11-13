#!/bin/bash
set -e

# Ensure the environment is clean
export DISPLAY=:1
export XDG_RUNTIME_DIR=/run/user/0
export XDG_SESSION_TYPE=x11

cleanup() {
  echo "[INFO] Shutting down..."
  kill 0 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT

echo "[INFO] Initializing environment..."
mkdir -p /run/user/0
chmod 700 /run/user/0

# 1. Start SSH Server
echo "[INFO] Starting OpenSSH Server..."
/usr/sbin/sshd

# 2. Start Xvfb (Virtual Framebuffer)
echo "[INFO] Starting Xvfb on :1 (1280x720x24)..."
Xvfb :1 -screen 0 1280x720x24 &
sleep 2

# 3. Disable KWin Compositing for software rendering efficiency
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

# 4. Start KDE Plasma in a DBus session
echo "[INFO] Launching KDE Plasma Desktop..."
dbus-launch --exit-with-session startplasma-x11 &
sleep 8

# Ensure a window manager is running (helps in headless/container setups)
if ! pgrep -x kwin_x11 >/dev/null 2>&1; then
  echo "[INFO] Starting kwin_x11..."
  kwin_x11 --replace >/tmp/kwin.log 2>&1 &
fi
sleep 5

# 5. Start x11vnc
echo "[INFO] Starting x11vnc on port 5900..."
x11vnc -display :1 -passwd changeme -forever -shared -rfbport 5900 &
sleep 2

# 6. Start websockify and noVNC
echo "[INFO] Starting noVNC on port 6080..."
/usr/bin/websockify --web /usr/share/novnc/ 6080 localhost:5900 &

echo "[SUCCESS] All services are running."
echo "  - SSH: port 22"
echo "  - VNC (Web): http://localhost:6080/vnc.html"
echo "  - VNC (Raw): localhost:5900"

# Keep the script running to prevent the container from exiting
wait
