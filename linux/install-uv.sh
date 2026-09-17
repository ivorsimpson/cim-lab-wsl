#!/usr/bin/env bash
set -euo pipefail
uv_version=${1:?uv version is required}
export UV_NO_MODIFY_PATH=1
curl -LsSf "https://astral.sh/uv/${uv_version}/install.sh" | sh
"$HOME/.local/bin/uv" --version
