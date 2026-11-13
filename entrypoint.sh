#!/bin/bash
set -e

# Ensure the environment is clean
export DISPLAY=:1
export XDG_RUNTIME_DIR=/run/user/0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus

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
echo "Enabled=false" >> /root/.config/kwinrc

# 4. Start DBUS Session
echo "[INFO] Starting DBUS..."
dbus-launch --exit-with-session &
sleep 2

# 5. Start KDE Plasma
echo "[INFO] Launching KDE Plasma Desktop..."
startplasma-x11 &
sleep 10 # Give Plasma time to initialize

# 6. Start x11vnc
echo "[INFO] Starting x11vnc on port 5900..."
x11vnc -display :1 -passwd changeme -forever -shared -rfbport 5900 &
sleep 2

# 7. Start websockify and noVNC
echo "[INFO] Starting noVNC on port 6080..."
/usr/bin/websockify --web /usr/share/novnc/ 6080 localhost:5900 &

echo "[SUCCESS] All services are running."
echo "  - SSH: port 22"
echo "  - VNC (Web): http://localhost:6080/vnc.html"
echo "  - VNC (Raw): localhost:5900"

# Keep the script running to prevent the container from exiting
tail -f /dev/null
