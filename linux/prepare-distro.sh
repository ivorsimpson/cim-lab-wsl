#!/usr/bin/env bash
set -euo pipefail
user_name=${1:?Linux username is required}
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends sudo passwd ca-certificates curl git build-essential pkg-config
install -d -m 0755 /etc/sudoers.d
if ! id -u "$user_name" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$user_name"
fi
usermod -aG sudo "$user_name"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$user_name" > /etc/sudoers.d/90-cim-student
chmod 0440 /etc/sudoers.d/90-cim-student
visudo --check --file=/etc/sudoers.d/90-cim-student
printf '%s\n' '[boot]' 'systemd=true' '[user]' "default=$user_name" > /etc/wsl.conf
rm -rf /var/lib/apt/lists/*
