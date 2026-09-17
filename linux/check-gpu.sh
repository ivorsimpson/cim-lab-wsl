#!/usr/bin/env bash
set -euo pipefail
if command -v nvidia-smi >/dev/null 2>&1; then
  exec nvidia-smi
elif [[ -x /usr/lib/wsl/lib/nvidia-smi ]]; then
  exec /usr/lib/wsl/lib/nvidia-smi
else
  echo 'nvidia-smi was not found. Check the Windows NVIDIA WSL driver.' >&2
  exit 127
fi
