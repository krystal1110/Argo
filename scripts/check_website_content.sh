#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

html="website/index.html"

grep -q '<nav class="site-nav"' "$html"
grep -q 'href="#features"' "$html"
grep -q 'href="#download"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo/releases/download/v1.0.5/Argo-1.0.5.dmg"' "$html"
grep -q '>GitHub</a>' "$html"
grep -q '>Download</a>' "$html"
grep -q '>Details</a>' "$html"
grep -q 'Command every repo.' "$html"
grep -q 'Keep every agent in view.' "$html"
grep -q 'brew install --cask krystal1110/tap/argo' "$html"
grep -q 'src="./assets/hero-workspace.png"' "$html"
grep -q 'src="./assets/app-icon.png"' "$html"
grep -q '<figure class="app-window">' "$html"

for id in workspaces panes agents workbench native download; do
  grep -q "id=\"$id\"" "$html"
done

if grep -q 'class="button secondary" href="https://github.com/krystal1110/Argo"' "$html"; then
  echo "GitHub should not be a secondary CTA button" >&2
  exit 1
fi

if grep -Eq 'Download DMG|All releases|View source on GitHub|>Source</a>|download-note|source-link' "$html"; then
  echo "download CTA should be Download + Details, with GitHub in nav" >&2
  exit 1
fi

if grep -Eq 'window-chrome|orbit-line|status-card|floating-icon' "$html"; then
  echo "hero screenshot should not be covered by decorative chrome or overlays" >&2
  exit 1
fi

echo "website content ok"
