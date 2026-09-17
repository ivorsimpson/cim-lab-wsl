#!/usr/bin/env bash
set -euo pipefail
project=${1:?project path is required}
python_version=${2:?Python version is required}
torch_channel=${3:?PyTorch channel is required}
torch_spec=${4:?torch spec is required}
torchvision_spec=${5:?torchvision spec is required}
force_recreate=${6:-false}
shift 6
extra_packages=("$@")

export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/wsl/lib"
uv="$HOME/.local/bin/uv"
if [[ "$force_recreate" == true ]]; then rm -rf -- "$project"; fi
mkdir -p "$project/src" "$project/notebooks" "$project/data"
cd "$project"
printf '%s\n' "$python_version" > .python-version
"$uv" python install "$python_version"

recreate_venv=false
if [[ -e .venv && ! -x .venv/bin/python ]]; then
  recreate_venv=true
elif [[ -x .venv/bin/python ]]; then
  existing_minor=$(.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  if [[ "$existing_minor" != "$python_version" ]]; then
    recreate_venv=true
  fi
fi

if [[ "$recreate_venv" == true ]]; then
  rm -rf .venv
fi
if [[ ! -x .venv/bin/python ]]; then
  "$uv" venv --python "$python_version"
else
  echo "Reusing existing .venv with Python $python_version"
fi

"$uv" pip install --python .venv/bin/python "$torch_spec" "$torchvision_spec" \
  --index-url "https://download.pytorch.org/whl/$torch_channel"
"$uv" pip install --python .venv/bin/python "${extra_packages[@]}"
{
  printf '%s\n' "$torch_spec" "$torchvision_spec"
  printf '%s\n' "${extra_packages[@]}"
} > requirements-lab.txt
cat > src/check_gpu.py <<'PYCODE'
import platform
import sys
import torch

print(f"Python: {sys.version.split()[0]}")
print(f"Platform: {platform.platform()}")
print(f"PyTorch: {torch.__version__}")
print(f"PyTorch CUDA runtime: {torch.version.cuda}")
print(f"CUDA available: {torch.cuda.is_available()}")
if not torch.cuda.is_available():
    raise SystemExit("ERROR: this PyTorch environment cannot access CUDA")
print(f"GPU: {torch.cuda.get_device_name(0)}")
a = torch.randn((1024, 1024), device="cuda")
b = torch.randn((1024, 1024), device="cuda")
c = a @ b
torch.cuda.synchronize()
assert c.is_cuda and torch.isfinite(c).all()
print("PASS: PyTorch completed a CUDA matrix multiplication")
PYCODE
cat > README.md <<'MARKDOWN'
# Computational Imaging Methods lab

Run the GPU check:

    ~/.local/bin/uv run --python .venv/bin/python python src/check_gpu.py

Start JupyterLab:

    ~/.local/bin/uv run --python .venv/bin/python jupyter lab --no-browser
MARKDOWN
"$uv" run --python .venv/bin/python python src/check_gpu.py
