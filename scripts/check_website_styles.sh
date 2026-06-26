#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

css="website/styles.css"

grep -q -- "--bg-page: #070d16" "$css"
grep -q -- "--bg-deep: #061215" "$css"
grep -q -- "--bg-mid: #0a1624" "$css"
grep -q -- "--accent: #5fd7ca" "$css"
grep -q -- "font-size: 72px" "$css"
grep -q -- "font-size: 24px" "$css"
grep -q -- "font-size: 16.8px" "$css"
grep -q -- "aspect-ratio: 2880 / 1778" "$css"
grep -q -- ".app-window picture" "$css"
grep -q -- ".releases-page" "$css"
grep -q -- ".latest-release" "$css"
grep -q -- ".release-summary" "$css"
grep -q -- "@media (max-width: 760px)" "$css"

if grep -E "font-size:[^;]+vw" "$css"; then
  echo "font-size must not use viewport units" >&2
  exit 1
fi

if grep -E "letter-spacing:[[:space:]]*-" "$css"; then
  echo "letter-spacing must not be negative" >&2
  exit 1
fi

echo "website styles ok"
