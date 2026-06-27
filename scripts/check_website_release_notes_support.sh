#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/website_release_notes.sh"

if ! declare -f website_release_notes_update >/dev/null; then
  echo "website_release_notes_update function is missing" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/argo-website-release-notes.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/releases.json" <<'JSON'
{
  "releases": [
    {
      "version": "1.0.8",
      "date": "June 26, 2026",
      "summary": "Top chrome double-click zoom and restore reliable across the full-size titlebar."
    },
    {
      "version": "1.0.7",
      "date": "June 25, 2026",
      "summary": "Terminal theming gets a broader Twilight pass."
    },
    {
      "version": "1.0.6",
      "date": "June 22, 2026",
      "summary": "The public website launches alongside Dynamic Island updates."
    },
    {
      "version": "1.0.5",
      "date": "June 22, 2026",
      "summary": "Settings are trimmed down while release packaging is hardened."
    }
  ]
}
JSON

cat > "$tmp_dir/appcast.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <title>1.0.9</title>
      <pubDate>Sat, 27 Jun 2026 10:11:12 +0800</pubDate>
      <sparkle:shortVersionString>1.0.9</sparkle:shortVersionString>
    </item>
  </channel>
</rss>
XML

cat > "$tmp_dir/release-notes.md" <<'MD'
## Argo 1.0.9

### Summary

Adds website release automation. Keeps the public release history fresh.

### Install

- DMG: `Argo-1.0.9.dmg`
MD

touch "$tmp_dir/Argo-1.0.9.dmg"

WEBSITE_RELEASES_FILE="$tmp_dir/releases.json" \
WEBSITE_RELEASES_HTML_FILE="$tmp_dir/index.html" \
WEBSITE_APPCAST_FILE="$tmp_dir/appcast.xml" \
WEBSITE_GITHUB_REPOSITORY="krystal1110/Argo" \
WEBSITE_APP_NAME="Argo" \
WEBSITE_BREW_INSTALL_REF="krystal1110/argo/argo" \
  website_release_notes_update \
    "1.0.9" \
    "v1.0.9" \
    "v1.0.8" \
    "$tmp_dir/Argo-1.0.9.dmg" \
    "$tmp_dir/release-notes.md"

python3 - "$tmp_dir/releases.json" <<'PY'
import json
import sys
from pathlib import Path

releases = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["releases"]
versions = [release["version"] for release in releases]
assert versions == ["1.0.9", "1.0.8", "1.0.7", "1.0.6"], versions
assert releases[0]["date"] == "June 27, 2026", releases[0]["date"]
assert releases[0]["summary"] == "Adds website release automation. Keeps the public release history fresh.", releases[0]["summary"]
PY

grep -Fq 'Argo 1.0.9' "$tmp_dir/index.html"
grep -Fq 'Latest' "$tmp_dir/index.html"
grep -Fq 'June 27, 2026' "$tmp_dir/index.html"
grep -Fq 'Argo-1.0.9.dmg' "$tmp_dir/index.html"
grep -Fq 'Adds website release automation. Keeps the public release history fresh.' "$tmp_dir/index.html"
if grep -Fq 'Argo 1.0.5' "$tmp_dir/index.html"; then
  echo "Generated website release page should keep only the latest 4 releases" >&2
  exit 1
fi

grep -Fq 'source "$ROOT_DIR/scripts/website_release_notes.sh"' scripts/release_homebrew.sh
grep -Fq 'website_release_notes_update' scripts/release_homebrew.sh
grep -Fq 'WEBSITE_RELEASES_FILE' scripts/release_homebrew.sh
grep -Fq 'WEBSITE_RELEASES_HTML_FILE' scripts/release_homebrew.sh
grep -Fq '"$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE"' scripts/release_homebrew.sh

echo "website release notes support ok"
