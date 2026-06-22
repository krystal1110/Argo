#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

workflow=".github/workflows/pages.yml"

if [[ ! -f "$workflow" ]]; then
  echo "missing $workflow" >&2
  exit 1
fi

required_patterns=(
  'name: Deploy website'
  'branches: ["main"]'
  'uses: actions/configure-pages@v5'
  'uses: actions/upload-pages-artifact@v3'
  'path: website'
  'uses: actions/deploy-pages@v4'
  'contents: read'
  'pages: write'
  'id-token: write'
  'github-pages'
  'url: ${{ steps.deployment.outputs.page_url }}'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -Fq "$pattern" "$workflow"; then
    echo "missing Pages workflow pattern: $pattern" >&2
    exit 1
  fi
done

if grep -Eq 'path:[[:space:]]*docs|docs/' "$workflow"; then
  echo "Pages workflow must deploy website/, not docs/" >&2
  exit 1
fi

echo "pages workflow ok"
