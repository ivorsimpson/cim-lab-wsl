#!/usr/bin/env bash
# First-run distro setup: creates a normal user, sets as default, installs
# baseline packages. Runs as root immediately after `wsl --import`.
set -euo pipefail

WIN_USER="${1:-student}"
LINUX_USER=$(echo "$WIN_USER" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
if [[ -z "$LINUX_USER" || ! "$LINUX_USER" =~ ^[a-z] ]]; then
    LINUX_USER="student"
fi

echo "[bootstrap-distro] Creating Linux user '$LINUX_USER'..."
if ! id -u "$LINUX_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$LINUX_USER"
    usermod -aG sudo "$LINUX_USER"
    echo "$LINUX_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$LINUX_USER"
    chmod 0440 "/etc/sudoers.d/90-$LINUX_USER"
fi

cat > /etc/wsl.conf <<EOF
[user]
default=$LINUX_USER

[boot]
systemd=false

[interop]
appendWindowsPath=true
EOF

echo "[bootstrap-distro] Installing baseline apt packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    sudo build-essential ca-certificates curl wget git gnupg \
    cmake ninja-build pkg-config unzip xz-utils bzip2
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[bootstrap-distro] Done."
