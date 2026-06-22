#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if git check-ignore -q website/index.html; then
  echo "website/index.html is ignored" >&2
  exit 1
fi

required_files=(
  "website/index.html"
  "website/styles.css"
  "website/assets/app-icon.png"
  "website/assets/hero-workspace.png"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "missing $path" >&2
    exit 1
  fi
done

file website/assets/app-icon.png | grep -q "PNG image data"
file website/assets/hero-workspace.png | grep -q "PNG image data"

echo "website assets ok"
