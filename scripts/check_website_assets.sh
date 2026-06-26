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
  "website/releases/index.html"
  "website/styles.css"
  "website/assets/app-icon.png"
  "website/assets/app-icon-64.png"
  "website/assets/app-icon-128.png"
  "website/assets/hero-workspace.png"
  "website/assets/hero-workspace-960.webp"
  "website/assets/hero-workspace-1440.webp"
  "website/assets/hero-workspace-2160.webp"
  "website/assets/hero-workspace-2880.webp"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "missing $path" >&2
    exit 1
  fi
done

file website/assets/app-icon.png | grep -q "PNG image data"
file website/assets/app-icon-64.png | grep -q "PNG image data"
file website/assets/app-icon-128.png | grep -q "PNG image data"
file website/assets/hero-workspace.png | grep -q "PNG image data"
file website/assets/hero-workspace-960.webp | grep -q "Web/P image"
file website/assets/hero-workspace-1440.webp | grep -q "Web/P image"
file website/assets/hero-workspace-2160.webp | grep -q "Web/P image"
file website/assets/hero-workspace-2880.webp | grep -q "Web/P image"

hero_width="$(sips -g pixelWidth website/assets/hero-workspace.png | awk '/pixelWidth/ { print $2 }')"
hero_height="$(sips -g pixelHeight website/assets/hero-workspace.png | awk '/pixelHeight/ { print $2 }')"
hero_bytes="$(wc -c < website/assets/hero-workspace.png | tr -d ' ')"
icon64_width="$(sips -g pixelWidth website/assets/app-icon-64.png | awk '/pixelWidth/ { print $2 }')"
icon64_height="$(sips -g pixelHeight website/assets/app-icon-64.png | awk '/pixelHeight/ { print $2 }')"
icon128_width="$(sips -g pixelWidth website/assets/app-icon-128.png | awk '/pixelWidth/ { print $2 }')"
icon128_height="$(sips -g pixelHeight website/assets/app-icon-128.png | awk '/pixelHeight/ { print $2 }')"
hero_webp_1440_bytes="$(wc -c < website/assets/hero-workspace-1440.webp | tr -d ' ')"
hero_webp_2880_bytes="$(wc -c < website/assets/hero-workspace-2880.webp | tr -d ' ')"

if (( hero_width < 2400 || hero_height < 1600 || hero_height > 1800 )); then
  echo "unexpected hero screenshot dimensions: ${hero_width}x${hero_height}" >&2
  exit 1
fi

if (( icon64_width != 64 || icon64_height != 64 )); then
  echo "unexpected 1x app icon dimensions: ${icon64_width}x${icon64_height}" >&2
  exit 1
fi

if (( icon128_width != 128 || icon128_height != 128 )); then
  echo "unexpected 2x app icon dimensions: ${icon128_width}x${icon128_height}" >&2
  exit 1
fi

if (( hero_bytes > 700000 )); then
  echo "hero screenshot is too large: ${hero_bytes} bytes" >&2
  exit 1
fi

if (( hero_webp_1440_bytes > 80000 )); then
  echo "1440px hero WebP is too large: ${hero_webp_1440_bytes} bytes" >&2
  exit 1
fi

if (( hero_webp_2880_bytes > 160000 )); then
  echo "2880px hero WebP is too large: ${hero_webp_2880_bytes} bytes" >&2
  exit 1
fi

echo "website assets ok"
