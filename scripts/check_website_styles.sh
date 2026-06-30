#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pages=(
  "website/index.html"
  "website/remote-preview.html"
  "website/releases/index.html"
)

for page in "${pages[@]}"; do
  grep -Fq -- "--bg: #fbf4ea" "$page"
  grep -Fq -- "--red: #f04437" "$page"
  grep -Fq -- "--green: #bdf3c9" "$page"
  grep -Fq -- "--blue: #cde8ff" "$page"
  grep -Fq -- "--max: 1160px" "$page"
  grep -Fq -- ".topbar" "$page"
  grep -Fq -- ".nav-lang-mobile" "$page"
  grep -Fq -- ".nav-links .nav-lang-desktop" "$page"
  grep -Fq -- "@media (max-width: 680px)" "$page"

  if grep -E "font-size:[^;]+vw" "$page"; then
    echo "font-size must not use viewport units in $page" >&2
    exit 1
  fi

  if grep -E "letter-spacing:[[:space:]]*-" "$page"; then
    echo "letter-spacing must not be negative in $page" >&2
    exit 1
  fi
done

grep -Fq ".hero-board" website/index.html
grep -Fq ".hero-flow" website/remote-preview.html
grep -Fq ".release-board" website/releases/index.html
grep -Fq ".latest-card" website/releases/index.html

echo "website styles ok"
