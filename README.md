# Headless KDE Plasma Desktop (Rootless Podman)

A production-ready, rootless Podman container running a minimal headless KDE Plasma desktop environment, accessible via browser-based noVNC, raw VNC, and SSH. Rendering is software-based (Xvfb + KWin compositing disabled) for smooth remote performance.

## Architecture Overview

The container runs as a single image orchestrated by an `entrypoint.sh` process manager that launches the following stack:

1. **OpenSSH Server** (`sshd`) — Remote shell access on container port `22`.
2. **Xvfb** — Virtual X11 framebuffer on display `:1` (`1280x720x24`), providing a headless display.
3. **DBus Session** — User session bus required by KDE/Plasma components.
4. **KDE Plasma Desktop** (`startplasma-x11`) — Minimal desktop session (`kde-plasma-desktop`, `konsole`) with KWin compositing explicitly disabled via `/root/.config/kwinrc` (`Enabled=false`).
5. **x11vnc** — VNC server attached to display `:1` on port `5900`.
6. **websockify + noVNC** — WebSocket proxy serving the browser-based VNC client on port `6080`.

### Custom Assets
The image build copies repository-provided KDE configuration and wallpapers into the container:
- KDE config files in `kde-configs/` (`kcminputrc`, `kdeglobals`, `kglobalshortcutsrc`, `krunnerrc`, `kscreenlockerrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `plasmarc`, `plasmashellrc`) → `/root/.config/`
- `Wallpapers/` directory → `/root/.local/share/wallpapers/`

## Repository Structure

```text
.
├── configs/
│   ├── sshd_config                      # SSH daemon configuration
│   └── authorized_keys                  # Optional: SSH public keys (build-time)
├── kde-configs/                         # KDE Plasma configuration files
│   ├── kcminputrc
│   ├── kdeglobals
│   ├── kglobalshortcutsrc
│   ├── krunnerrc
│   ├── kscreenlockerrc
│   ├── plasma-org.kde.plasma.desktop-appletsrc
│   ├── plasmarc
│   └── plasmashellrc
├── Wallpapers/                          # Custom wallpapers (copied into image)
├── Containerfile                        # Container build definition
├── entrypoint.sh                        # Service/process manager
├── Makefile                             # Build/run shortcuts
├── README.md
├── LICENSE
└── .gitignore
```

> **Note:** Ensure the KDE config files in `kde-configs/` and the `Wallpapers/` directory are present before building, as the `Containerfile` copies them into the image.

## Prerequisites

- [Podman](https://podman.io/) (rootless-capable)
- `make` (optional, for shortcuts)

## Build and Run

### Using Makefile

```bash
# Build the image
make build

# Run the container (detached)
make run

# View logs
make logs

# Open a shell inside the container
make shell

# Stop the container
make stop

# Stop and remove the image
make clean
```

### Using Podman directly

```bash
podman build -t kde-headless -f Containerfile .

podman run -d --rm \
  --name kde-headless \
  -p 2222:22 \
  -p 5900:5900 \
  -p 6080:6080 \
  --shm-size=512m \
  kde-headless
```

`--shm-size=512m` is recommended to avoid shared-memory issues with desktop applications.

## Port Mappings

| Service        | Container Port | Host Port (default) | Protocol |
|----------------|---------------:|--------------------:|----------|
| SSH            |             22 |                2222 | TCP      |
| VNC (x11vnc)   |           5900 |                5900 | TCP      |
| noVNC (Web UI) |           6080 |                6080 | HTTP/WS  |

> Host ports can be adjusted in the `Makefile` or in your `podman run` command.

## Connection Guides

### 1. Browser-based noVNC (Recommended)

Open in your browser:

```
http://localhost:6080/vnc.html
```

- Click **Connect** when prompted.
- Enter the VNC password: `changeme`

### 2. SSH

Connect directly via SSH (mapped to host port `2222` by default):

```bash
ssh -p 2222 root@localhost
```

- **Username:** `root`
- **Password:** `changeme`

#### Adding your SSH public key

Public key authentication is supported by the provided `sshd_config`.

**Option A: Runtime (quick, no rebuild)**

```bash
# Copy your public key into the running container (prompts for password once)
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 2222 root@localhost
```

Or manually:

```bash
cat ~/.ssh/id_ed25519.pub | ssh -p 2222 root@localhost \
  'mkdir -p /root/.ssh && chmod 700 /root/.ssh && cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'
```

> **Note:** `make run` uses `--rm`, so keys added inside the container are removed when it stops. Use a persistent container/volume or Option B for keys that survive rebuilds/restarts.

**Option B: Build time (recommended for a reusable image)**

1. Add your public key to `configs/authorized_keys`:
   ```bash
   cp ~/.ssh/id_ed25519.pub configs/authorized_keys
   ```
2. Update `Containerfile` to install it with correct permissions:
   ```dockerfile
   RUN mkdir -p /var/run/sshd /root/.ssh \
       && chmod 700 /root/.ssh \
       && echo 'root:changeme' | chpasswd
   COPY configs/sshd_config /etc/ssh/sshd_config
   COPY configs/authorized_keys /root/.ssh/authorized_keys
   RUN chmod 600 /root/.ssh/authorized_keys
   ```
3. Rebuild and run: `make build && make run`
4. (Optional) Add `configs/authorized_keys` to `.gitignore` to avoid committing keys.

Once key auth works, you can harden access by setting `PasswordAuthentication no` in `configs/sshd_config` and rebuilding.

### 3. Native VNC Client

Point any VNC client to:

```
localhost:5900
```

- **Password:** `changeme`

### 4. SOCKS5 Tunneling (Secure Remote Access)

To securely access VNC/noVNC over an untrusted network without exposing ports publicly, create a dynamic SOCKS5 proxy over SSH:

```bash
ssh -p 2222 -D 1080 -N root@localhost
```

- `-D 1080`: Opens a local SOCKS5 proxy on port `1080`
- `-N`: No remote command (tunnel only)

Then configure your browser or VNC client to use a SOCKS5 proxy at `127.0.0.1:1080`.  
- For browser noVNC access through the tunnel, navigate to `http://localhost:6080/vnc.html` via the proxied browser session, or target the container's network address as reachable through the tunnel.
- Alternatively, use local port forwarding for specific services:

```bash
# Forward noVNC
ssh -p 2222 -L 6080:localhost:6080 -N root@localhost

# Forward raw VNC
ssh -p 2222 -L 5900:localhost:5900 -N root@localhost
```

After forwarding, access services on your local machine as usual (`http://localhost:6080/vnc.html`, `localhost:5900`).

## Credentials

| Service | Username | Password   |
|---------|----------|------------|
| SSH     | `root`   | `changeme` |
| VNC     | *(n/a)*  | `changeme` |

> ⚠️ **Security Warning:** These are default credentials intended for local/testing use. Change the root password and VNC password before deploying in any shared or exposed environment.
> - Change root password: update `Containerfile` (`echo 'root:changeme' | chpasswd`) and rebuild.
> - Change VNC password: update `entrypoint.sh` (`x11vnc -passwd ...`) and rebuild.

## Notes & Troubleshooting

- **Compositing:** KWin compositing is disabled (`/root/.config/kwinrc`) to ensure acceptable performance under software rendering in Xvfb.
- **Resolution:** Default virtual display is `1280x720x24`. Adjust in `entrypoint.sh` (`Xvfb :1 -screen 0 ...`).
- **Plasma startup time:** The entrypoint includes brief delays to allow Xvfb/DBus/Plasma to initialize before starting VNC services. Increase `sleep` durations in `entrypoint.sh` on slower hosts if needed.
- **Rootless Podman:** Binding to ports <1024 inside the container is fine; host-side mappings (e.g. `2222:22`) are unprivileged. Ensure your system allows the configured host ports.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
