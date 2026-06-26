#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

html="website/index.html"
releases="website/releases/index.html"
readme="README.md"

grep -q '<nav class="site-nav"' "$html"
grep -q 'href="#features"' "$html"
grep -q 'href="./releases/"' "$html"
grep -q 'href="#download"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo/releases/download/v1.0.8/Argo-1.0.8.dmg"' "$html"
grep -q '>GitHub</a>' "$html"
grep -q '>Download</a>' "$html"
grep -q '>Details</a>' "$html"
grep -q '>Releases</a>' "$html"
grep -q 'Command every repo.' "$html"
grep -q 'Keep every agent in view.' "$html"
grep -q 'brew install --cask krystal1110/argo/argo' "$html"
grep -q '<picture>' "$html"
grep -q 'type="image/webp"' "$html"
grep -q 'srcset="./assets/hero-workspace-960.webp 960w, ./assets/hero-workspace-1440.webp 1440w, ./assets/hero-workspace-2160.webp 2160w, ./assets/hero-workspace-2880.webp 2880w"' "$html"
grep -q 'src="./assets/hero-workspace.png"' "$html"
grep -q 'fetchpriority="high"' "$html"
grep -q 'decoding="async"' "$html"
grep -q 'src="./assets/app-icon-64.png"' "$html"
grep -q 'srcset="./assets/app-icon-64.png 1x, ./assets/app-icon-128.png 2x"' "$html"
grep -q '<figure class="app-window">' "$html"
grep -q 'href="https://krystal1110.github.io/Argo/"' "$readme"
grep -q 'Website-krystal1110.github.io%2FArgo' "$readme"
grep -q '<main class="releases-page"' "$releases"
grep -q '<h1 id="releases-title">Release Notes</h1>' "$releases"
grep -q 'Latest' "$releases"
grep -q 'Argo 1.0.8' "$releases"
grep -q 'June 26, 2026' "$releases"
grep -q 'href="https://github.com/krystal1110/Argo/releases/tag/v1.0.8"' "$releases"
grep -q 'href="https://github.com/krystal1110/Argo/releases/download/v1.0.8/Argo-1.0.8.dmg"' "$releases"
grep -q 'brew install --cask krystal1110/argo/argo' "$releases"
grep -q 'Argo 1.0.8 makes top chrome double-click zoom and restore reliable across the full-size titlebar.' "$releases"

release_summary="$(awk -F '<p class="release-summary">|</p>' '/release-summary/ { print $2; exit }' "$releases")"
summary_words="$(awk '{ print NF }' <<< "$release_summary")"
if (( summary_words > 50 )); then
  echo "Release page summary is too long: $summary_words words" >&2
  exit 1
fi

if grep -Eq '<li>|<ul>|release-groups' "$releases"; then
  echo "Release page should keep each generated note to one concise sentence" >&2
  exit 1
fi

if grep -Eq 'href="https://github.com/krystal1110/Argo/releases/(tag|download)/v1\.0\.[67]' "$html" "$releases"; then
  echo "website should not link to Argo 1.0.6 or 1.0.7 as the current release" >&2
  exit 1
fi

for id in workspaces panes agents workbench native download; do
  grep -q "id=\"$id\"" "$html"
done

if grep -q 'https://argo.dev' "$readme"; then
  echo "README website link should use GitHub Pages" >&2
  exit 1
fi

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
