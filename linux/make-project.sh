#!/usr/bin/env bash
# Creates a new project folder inside WSL and instantiates template files.
#
# Usage: make-project.sh <name> <type> <projects_root> [--force]
set -euo pipefail

NAME="${1:?missing project name}"
TYPE="${2:?missing project type}"
PROJECTS_ROOT="${3:?missing projects root}"
FORCE=""
if [[ "${4:-}" == "--force" ]]; then FORCE="1"; fi

CUDA_ARCH="86"
TEMPLATE_ROOT="$HOME/.lab-gpu/templates/$TYPE"
PROJECT_DIR="$HOME/$PROJECTS_ROOT/$NAME"

if [[ ! -d "$TEMPLATE_ROOT" ]]; then
    echo "[make-project] ERROR: no template for type '$TYPE' at $TEMPLATE_ROOT" >&2
    exit 1
fi

if [[ -e "$PROJECT_DIR" ]]; then
    if [[ -z "$FORCE" ]]; then
        echo "[make-project] ERROR: '$PROJECT_DIR' already exists. Use -Force to overwrite." >&2
        exit 2
    fi
    echo "[make-project] Removing existing $PROJECT_DIR (--force)"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"
cp -a "$TEMPLATE_ROOT/." "$PROJECT_DIR/"

find "$PROJECT_DIR" -type f \( \
        -name '*.txt'  -o -name '*.md'   -o -name '*.cu' -o \
        -name '*.cpp'  -o -name '*.h'    -o -name '*.hpp' -o \
        -name '*.json' -o -name '*.yml'  -o -name '*.yaml' -o \
        -name '*.cmake' -o -name 'CMakeLists.txt' -o -name '.gitignore' \
     \) -print0 |
while IFS= read -r -d '' f; do
    sed -i \
        -e "s|__PROJECT_NAME__|$NAME|g" \
        -e "s|__CUDA_ARCH__|$CUDA_ARCH|g" \
        -e "s|__USER__|$USER|g" \
        "$f"
done

if command -v git >/dev/null 2>&1; then
    (
        cd "$PROJECT_DIR"
        git init -q -b main
        git add .
        git -c user.email="lab@local" -c user.name="lab-gpu" \
            commit -q -m "Initial project from lab-gpu template ($TYPE)"
    )
fi

echo "[make-project] Created $PROJECT_DIR"
