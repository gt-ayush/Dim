# Headless KDE Plasma 6 Desktop (Rootless Podman)

A production-ready, rootless Podman container running a minimal headless **KDE Plasma 6** desktop environment (Debian Trixie), accessible via **RDP** and **SSH**. Rendering is software-based (Xorg/Xrdp session with KWin compositing disabled) for smooth remote performance.

## Architecture Overview

- **Base image:** `debian:trixie-slim` (KDE Plasma 6 / Qt 6 stack)
- **Desktop:** minimal `kde-plasma-desktop` with `kwin-x11` and `konsole`
- **Remote access:** `xrdp` + `xorgxrdp` (per-login X11 sessions via RDP)

The container runs as a single image orchestrated by an `entrypoint.sh` process manager that launches the following stack:

1. **OpenSSH Server** (`sshd`) — Remote shell access on container port `22`.
2. **xrdp-sesman** — RDP session manager.
3. **xrdp** — RDP server on container port `3389`, launching KDE Plasma sessions via `/etc/xrdp/startwm.sh` (`dbus-launch --exit-with-session startplasma-x11`).

KWin compositing is explicitly disabled (`[Compositing] Enabled=false` in `/root/.config/kwinrc`, enforced by `entrypoint.sh` and `configs/startwm.sh`) for reliable software-rendered headless operation.

### Custom Assets
The image build copies repository-provided KDE configuration and wallpapers into the container:
- KDE config files in `kde-configs/` (`kcminputrc`, `kdeglobals`, `kglobalshortcutsrc`, `krunnerrc`, `kscreenlockerrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `plasmarc`, `plasmashellrc`) → `/root/.config/`
- `Wallpapers/` directory → `/root/.local/share/wallpapers/`

## Repository Structure

```text
.
├── configs/
│   ├── sshd_config                      # SSH daemon configuration
│   ├── startwm.sh                       # xrdp session startup (KDE Plasma X11)
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
- An RDP client (e.g. Windows Remote Desktop `mstsc`, [Remmina](https://remmina.org/), [FreeRDP](https://www.freerdp.com/) `xfreerdp`)

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
  -p 3389:3389 \
  --shm-size=512m \
  kde-headless
```

`--shm-size=512m` is recommended to avoid shared-memory issues with desktop applications.

## Port Mappings

| Service | Container Port | Host Port (default) | Protocol |
|---------|---------------:|--------------------:|----------|
| SSH     |             22 |                2222 | TCP      |
| RDP     |           3389 |                3389 | TCP      |

> Host ports can be adjusted in the `Makefile` or in your `podman run` command (e.g. `-p 13389:3389` if host port `3389` is in use).

## Connection Guides

### 1. RDP (Desktop)

Connect with your preferred RDP client to:

- **Host:** `localhost`
- **Port:** `3389` (or your mapped host port)
- **Username:** `root`
- **Password:** `changeme`

Examples:

```bash
# FreeRDP (Linux)
xfreerdp /v:localhost:3389 /u:root /p:changeme /cert:ignore

# Remmina: create an RDP connection to localhost:3389 (user root)
```

> The first connection may take a few moments while the Plasma session starts. If you see a black screen briefly, wait and/or reconnect once.

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

### 3. SSH Port Forwarding (Secure Remote Access)

To access RDP over an untrusted network without exposing port `3389` publicly, tunnel it over SSH:

```bash
ssh -p 2222 -L 3389:localhost:3389 -N root@localhost
```

Then connect your RDP client to `localhost:3389` on your local machine; traffic will be forwarded securely through SSH.

## Credentials

| Service | Username | Password   |
|---------|----------|------------|
| SSH     | `root`   | `changeme` |
| RDP     | `root`   | `changeme` |

> ⚠️ **Security Warning:** These are default credentials intended for local/testing use. Change the root password before deploying in any shared or exposed environment.
> - Change root password: update `Containerfile` (`echo 'root:changeme' | chpasswd`) and rebuild.
> - Consider disabling SSH password auth (`PasswordAuthentication no` in `configs/sshd_config`) after configuring key-based access.

## Local Storage / Persistence

`make run` uses `--rm`, so container filesystem changes are lost when the container stops. To persist data, use a bind mount or volume:

```bash
mkdir -p ./data
podman run -d --rm \
  --name kde-headless \
  -p 2222:22 -p 3389:3389 \
  --shm-size=512m \
  -v ./data:/root/data:Z \
  kde-headless
```

- Use `:Z` (or `:z`) on SELinux systems as needed.
- Mounting over `/root` (e.g. `-v ./kde-home:/root:Z`) will hide image-provided configs/wallpapers; initialize the host directory from the image first if you need them.
- `--shm-size` configures RAM-backed `/dev/shm` (not persistent storage).

## Notes & Troubleshooting

- **Compositing:** KWin compositing is disabled via `kwinrc` to ensure acceptable performance/stability under software rendering in headless sessions.
- **Black screen / slow first connect:** allow time for the Plasma session to initialize on first RDP login; reconnect if necessary.
- **Session logs:** check `podman logs kde-headless`, `/var/log/xrdp.log`, and `/var/log/xrdp-sesman.log` inside the container for RDP/session issues.
- **Rootless Podman:** binding to container ports like 3389 is fine; host-side mappings are unprivileged. Ensure your chosen host ports are available.
- **SELinux:** when using bind mounts, add `:Z` (or `:z`) to volume options if access is denied.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
