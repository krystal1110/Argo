#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

html="website/index.html"
releases="website/releases/index.html"
release_data="website/releases/releases.json"
readme="README.md"
latest_version="$(python3 - "$release_data" <<'PY'
import json
import sys
from pathlib import Path

releases = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["releases"]
print(releases[0]["version"])
PY
)"

grep -q '<nav class="site-nav"' "$html"
grep -q 'href="#features"' "$html"
grep -q 'href="./releases/"' "$html"
grep -q 'href="#download"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo"' "$html"
if ! grep -q "href=\"https://github.com/krystal1110/Argo/releases/download/v$latest_version/Argo-$latest_version.dmg\"" "$html"; then
  echo "homepage missing latest download link for Argo $latest_version" >&2
  exit 1
fi
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
while IFS=$'\t' read -r version date summary; do
  if ! grep -q "Argo $version" "$releases"; then
    echo "Release page missing Argo $version" >&2
    exit 1
  fi
  if ! grep -q "href=\"https://github.com/krystal1110/Argo/releases/tag/v$version\"" "$releases"; then
    echo "Release page missing tag link for Argo $version" >&2
    exit 1
  fi
  if ! grep -q "href=\"https://github.com/krystal1110/Argo/releases/download/v$version/Argo-$version.dmg\"" "$releases"; then
    echo "Release page missing DMG link for Argo $version" >&2
    exit 1
  fi
  if ! grep -q "$date" "$releases"; then
    echo "Release page missing date for Argo $version: $date" >&2
    exit 1
  fi
  if ! grep -Fq "$summary" "$releases"; then
    echo "Release page missing summary for Argo $version" >&2
    exit 1
  fi
done < <(python3 - "$release_data" <<'PY'
import json
import sys
from pathlib import Path

for release in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["releases"]:
    print("\t".join([release["version"], release["date"], release["summary"]]))
PY
)
grep -q 'brew install --cask krystal1110/argo/argo' "$releases"

release_summary_count="$(grep -c '<p class="release-summary">' "$releases" || true)"
if [[ "$release_summary_count" != "4" ]]; then
  echo "Release page should list exactly 4 summaries, found $release_summary_count" >&2
  exit 1
fi

while IFS= read -r release_summary; do
  summary_words="$(awk '{ print NF }' <<< "$release_summary")"
  if (( summary_words > 60 )); then
    echo "Release page summary is too long: $summary_words words" >&2
    exit 1
  fi

  sentence_count="$(awk '{ count += gsub(/[.!?]+/, "&") } END { print count + 0 }' <<< "$release_summary")"
  if (( sentence_count > 2 )); then
    echo "Release page summary should be one or two sentences: $release_summary" >&2
    exit 1
  fi
done < <(awk -F '<p class="release-summary">|</p>' '/release-summary/ { print $2 }' "$releases")

if grep -Eq '<li>|<ul>|release-groups' "$releases"; then
  echo "Release page should keep each generated note to one concise sentence" >&2
  exit 1
fi

old_homepage_release_link="$(
  grep -Eo 'https://github.com/krystal1110/Argo/releases/(tag|download)/v[0-9]+\.[0-9]+\.[0-9]+' "$html" |
    grep -v "/v$latest_version$" || true
)"
if [[ -n "$old_homepage_release_link" ]]; then
  echo "homepage should not link old releases as current downloads" >&2
  echo "$old_homepage_release_link" >&2
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
