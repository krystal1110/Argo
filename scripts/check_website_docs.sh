#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

grep -q "website/" docs/README.md
grep -q "static landing page" docs/README.md
grep -q "website/assets/hero-workspace.png" docs/README.md

if grep -q "website/src/content/docs" docs/README.md; then
  echo "docs/README.md still references removed website docs structure" >&2
  exit 1
fi

echo "website docs ok"
