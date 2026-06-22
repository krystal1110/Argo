#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

html="website/index.html"

grep -q '<nav class="site-nav"' "$html"
grep -q 'href="#features"' "$html"
grep -q 'href="#download"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo/releases"' "$html"
grep -q 'Command every repo.' "$html"
grep -q 'Keep every agent in view.' "$html"
grep -q 'brew install --cask krystal1110/tap/argo' "$html"
grep -q 'src="./assets/hero-workspace.png"' "$html"
grep -q 'src="./assets/app-icon.png"' "$html"

for id in workspaces panes agents workbench native download; do
  grep -q "id=\"$id\"" "$html"
done

echo "website content ok"
