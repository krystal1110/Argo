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

if grep -R "krystal1110/tap/argo" \
  docs/superpowers/plans/2026-06-22-argo-website.md \
  docs/superpowers/specs/2026-06-22-argo-website-design.md \
  website/index.html \
  scripts/check_website_content.sh \
  scripts/check_homebrew_support.sh; then
  echo "old Homebrew tap reference found" >&2
  exit 1
fi

echo "website docs ok"
