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

hero_width="$(sips -g pixelWidth website/assets/hero-workspace.png | awk '/pixelWidth/ { print $2 }')"
hero_height="$(sips -g pixelHeight website/assets/hero-workspace.png | awk '/pixelHeight/ { print $2 }')"
hero_bytes="$(wc -c < website/assets/hero-workspace.png | tr -d ' ')"

if (( hero_width < 2400 || hero_height < 1600 || hero_height > 1800 )); then
  echo "unexpected hero screenshot dimensions: ${hero_width}x${hero_height}" >&2
  exit 1
fi

if (( hero_bytes > 700000 )); then
  echo "hero screenshot is too large: ${hero_bytes} bytes" >&2
  exit 1
fi

echo "website assets ok"
