#!/bin/sh
# xrdp session startup script for KDE Plasma (X11)

export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/0
export DESKTOP_SESSION=plasma
export XDG_CURRENT_DESKTOP=KDE
export KDE_FULL_SESSION=true

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Disable KWin compositing for software-rendered/headless sessions
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

exec dbus-launch --exit-with-session startplasma-x11
