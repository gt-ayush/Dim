FROM debian:trixie-slim

LABEL maintainer="DevOps Team"
LABEL description="Headless KDE Plasma 6 Desktop with SSH and RDP access"

ENV DEBIAN_FRONTEND=noninteractive
ENV XDG_RUNTIME_DIR=/run/user/0

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    xrdp \
    xorgxrdp \
    xorg \
    xvfb \
    kde-plasma-desktop \
    kwin-x11 \
    konsole \
    dbus-x11 \
    xauth \
    ca-certificates \
    procps \
    x11-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /var/run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && echo 'root:changeme' | chpasswd
COPY configs/sshd_config /etc/ssh/sshd_config

# Configure xrdp session startup
COPY configs/startwm.sh /etc/xrdp/startwm.sh
RUN chmod +x /etc/xrdp/startwm.sh

# Configure KDE directories
RUN mkdir -p /root/.config /root/.local/share/wallpapers /run/user/0 \
    && chmod 700 /run/user/0

# Copy custom KDE configuration files and wallpapers into the image
COPY kde-configs/ /root/.config/
COPY Wallpapers/ /root/.local/share/wallpapers/

# Copy and set up entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose service ports
EXPOSE 22 3389

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
