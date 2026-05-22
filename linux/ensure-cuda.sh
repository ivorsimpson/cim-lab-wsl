#!/usr/bin/env bash
# Installs the CUDA toolkit system-wide via NVIDIA's official WSL apt repo.
# No conda, no Miniconda — just the CUDA bits NVIDIA ships for WSL Ubuntu.
#
# This is what NVIDIA recommends for WSL:
#   https://docs.nvidia.com/cuda/wsl-user-guide/
#
# The wsl-ubuntu repo deliberately omits the GPU kernel driver (the Windows
# host driver passes through), so we only get the toolkit bits.
#
# Usage: ensure-cuda.sh <cuda_version>   e.g. ensure-cuda.sh 12.8
set -euo pipefail

CUDA_VER="${1:?missing CUDA version}"            # e.g. 12.8
CUDA_PKG_SUFFIX="${CUDA_VER//./-}"               # 12.8 -> 12-8
PKG="cuda-toolkit-${CUDA_PKG_SUFFIX}"
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb"

echo "[ensure-cuda] Target package: $PKG"

if dpkg -s "$PKG" >/dev/null 2>&1; then
    installed=$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null || echo "unknown")
    echo "[ensure-cuda] $PKG already installed (version $installed). Nothing to do."
else
    echo "[ensure-cuda] Installing NVIDIA CUDA repo keyring..."
    tmp_deb=$(mktemp --suffix=.deb)
    trap 'rm -f "$tmp_deb"' EXIT
    curl -fsSL "$KEYRING_URL" -o "$tmp_deb"
    sudo dpkg -i "$tmp_deb" >/dev/null

    echo "[ensure-cuda] apt-get update (NVIDIA repo)..."
    sudo apt-get update -qq

    echo "[ensure-cuda] Installing $PKG (this is the big download)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$PKG"
fi

# Wire up PATH and LD_LIBRARY_PATH idempotently. NVIDIA installs to
# /usr/local/cuda-X.Y with a /usr/local/cuda symlink to the active one,
# but the wsl-ubuntu apt package doesn't add anything to PATH for you.
# We need three flavours of fix to cover all the shell contexts a student
# might hit:
#   - /etc/profile.d/cuda.sh    -> login shells (ssh, wsl bash -l)
#   - ~/.bashrc append          -> interactive non-login (VS Code terminals)
#   - /usr/local/bin symlinks   -> non-interactive (`bash -c`, scripts,
#                                  cmake invoked from outside an env)
sudo tee /etc/profile.d/cuda.sh >/dev/null <<'EOF'
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
EOF
sudo chmod 0644 /etc/profile.d/cuda.sh

PROFILE_LINE_MARKER='# Added by lab-gpu ensure-cuda.sh'
if ! grep -qF "$PROFILE_LINE_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ''
        echo "$PROFILE_LINE_MARKER"
        echo 'export PATH="/usr/local/cuda/bin:$PATH"'
        echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"'
    } >> "$HOME/.bashrc"
fi

for bin in nvcc cuda-gdb; do
    sudo ln -sf "/usr/local/cuda/bin/$bin" "/usr/local/bin/$bin"
done

# Activate for this script's verification step.
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

echo ""
echo "[ensure-cuda] Verifying:"
echo -n "  nvcc:   "; nvcc --version 2>/dev/null | grep -oE 'release [0-9]+\.[0-9]+' || echo "MISSING"
echo -n "  cmake:  "; cmake --version 2>/dev/null | head -n1 || echo "MISSING"
echo -n "  ninja:  "; ninja --version 2>/dev/null || echo "MISSING"
# Deliberately not calling nvidia-smi here. On WSL, all GPU traffic routes
# through /dev/dxg to the Windows host driver. If that driver's userspace
# state is stale (a long-lived distro session, a driver update mid-session,
# etc.), nvidia-smi enters uninterruptible kernel sleep (D state) that even
# SIGKILL can't break — and `timeout` is useless against D state.
#
# The cure for that condition is `wsl --shutdown` on the Windows side, which
# costs the student nothing. So we just tell them how to check, rather than
# risk hanging the installer.
echo "  driver: run 'nvidia-smi' in a new WSL terminal to check. If it hangs,"
echo "          run 'wsl --shutdown' in PowerShell on Windows and try again."
echo ""
echo "[ensure-cuda] Done."
