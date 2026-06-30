#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

home="website/index.html"
remote="website/remote-preview.html"
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

for path in "$home" "$remote" "$releases"; do
  grep -Fq 'const storageKey = "argo-site-language";' "$path"
  grep -Fq '<body data-lang="en">' "$path"
  grep -Fq 'data-lang-toggle' "$path"
  grep -Fq 'href="https://github.com/krystal1110/Argo"' "$path"
  if grep -Eq 'site-nav|site-header|styles\.css|argo-hapi-style|argo-hapi-remote-preview' "$path"; then
    echo "$path should use the official new website shell only" >&2
    exit 1
  fi
done

grep -Fq 'Repos, terminals, and agents' "$home"
grep -Fq 'in one workspace.' "$home"
grep -Fq 'href="./remote-preview.html"' "$home"
grep -Fq 'href="./releases/"' "$home"
grep -Fq 'brew install --cask krystal1110/argo/argo' "$home"
grep -Fq 'src="./assets/hero-workspace-1440.webp"' "$home"
grep -Fq 'fetchpriority="high"' "$home"
grep -Fq 'decoding="async"' "$home"

if ! grep -Fq "href=\"https://github.com/krystal1110/Argo/releases/download/v$latest_version/Argo-$latest_version.dmg\"" "$home"; then
  echo "homepage missing latest download link for Argo $latest_version" >&2
  exit 1
fi
grep -Fq "Latest $latest_version" "$home"
grep -Fq "Argo $latest_version macOS installer" "$home"

grep -Fq 'Preview local HTML' "$remote"
grep -Fq 'from your phone.' "$remote"
grep -Fq 'href="./#top"' "$remote"
grep -Fq 'href="./remote-preview.html"' "$remote"
grep -Fq 'href="./releases/"' "$remote"
grep -Fq 'Install HAPI first' "$remote"
grep -Fq 'npm install -g --prefix "$HOME/.local" @twsxtd/hapi' "$remote"
grep -Fq "zsh -lic 'whence -p hapi; hapi --version'" "$remote"
grep -Fq 'HAPI Show Settings' "$remote"
grep -Fq 'HAPI Claude' "$remote"
if grep -Fq '打开 Argo，选中 workspace，就可以开始。' "$remote"; then
  echo "remote preview footer CTA should stay removed" >&2
  exit 1
fi

grep -Fq 'href="../#top"' "$releases"
grep -Fq 'href="../remote-preview.html"' "$releases"
grep -Fq 'href="./"' "$releases"
grep -Fq 'RELEASE_NOTES_GENERATED_START' "$releases"
grep -Fq 'RELEASE_NOTES_GENERATED_END' "$releases"
grep -Fq '<section id="history"' "$releases"
grep -Fq '<div class="release-board"' "$releases"
grep -Fq 'brew install --cask krystal1110/argo/argo' "$releases"
grep -Fq 'https://github.com/krystal1110/Argo/releases' "$releases"

while IFS=$'\t' read -r version date summary; do
  if ! grep -Fq "Argo $version" "$releases"; then
    echo "Release page missing Argo $version" >&2
    exit 1
  fi
  if ! grep -Fq "href=\"https://github.com/krystal1110/Argo/releases/tag/v$version\"" "$releases"; then
    echo "Release page missing tag link for Argo $version" >&2
    exit 1
  fi
  if ! grep -Fq "href=\"https://github.com/krystal1110/Argo/releases/download/v$version/Argo-$version.dmg\"" "$releases"; then
    echo "Release page missing DMG link for Argo $version" >&2
    exit 1
  fi
  if ! grep -Fq "$date" "$releases"; then
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

release_row_count="$(grep -c '<article class="release-row"' "$releases" || true)"
if [[ "$release_row_count" != "4" ]]; then
  echo "Release page should list exactly 4 release rows, found $release_row_count" >&2
  exit 1
fi

old_homepage_release_link="$(
  grep -Eo 'https://github.com/krystal1110/Argo/releases/download/v[0-9]+\.[0-9]+\.[0-9]+' "$home" |
    grep -v "/v$latest_version$" || true
)"
if [[ -n "$old_homepage_release_link" ]]; then
  echo "homepage should not link old releases as current downloads" >&2
  echo "$old_homepage_release_link" >&2
  exit 1
fi

for old_path in \
  website/argo-hapi-style-home-demo.html \
  website/argo-hapi-style-releases-demo.html \
  website/argo-hapi-remote-preview.html \
  website/styles.css; do
  if [[ -e "$old_path" ]]; then
    echo "old website artifact should be removed: $old_path" >&2
    exit 1
  fi
done

grep -Fq 'href="https://krystal1110.github.io/Argo/"' "$readme"
grep -Fq 'Website-krystal1110.github.io%2FArgo' "$readme"
if grep -Fq 'https://argo.dev' "$readme"; then
  echo "README website link should use GitHub Pages" >&2
  exit 1
fi

echo "website content ok"
