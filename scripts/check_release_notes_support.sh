#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/release_notes.sh"

notes_file="$(mktemp "${TMPDIR:-/tmp}/argo-release-notes-check.XXXXXX.md")"
source_file="$(mktemp "${TMPDIR:-/tmp}/argo-release-notes-source.XXXXXX.md")"
trap 'rm -f "$notes_file" "$source_file"' EXIT

release_notes_write \
  "$notes_file" \
  "1.0.6" \
  "v1.0.6" \
  "v1.0.5" \
  "Argo-1.0.6.dmg" \
  "krystal1110/argo/argo"

grep -Fq '## Argo 1.0.6' "$notes_file"
grep -Fq '### Highlights' "$notes_file"
grep -Fq 'feat(island): finish ui' "$notes_file"
grep -Fq 'feat(web): merge site' "$notes_file"
grep -Fq 'fix(island): sync claude hooks' "$notes_file"
grep -Fq '### Install' "$notes_file"
grep -Fq 'DMG: `Argo-1.0.6.dmg`' "$notes_file"
grep -Fq 'Homebrew: `brew install --cask krystal1110/argo/argo`' "$notes_file"
grep -Fq 'Previous release: `v1.0.5`' "$notes_file"

cat > "$source_file" <<'NOTES'
### Highlights

- Human-written highlight.
NOTES

release_notes_write \
  "$notes_file" \
  "1.0.7" \
  "v1.0.7" \
  "v1.0.6" \
  "Argo-1.0.7.dmg" \
  "krystal1110/argo/argo" \
  "$source_file"

grep -Fq 'Human-written highlight.' "$notes_file"
grep -Fq 'DMG: `Argo-1.0.7.dmg`' "$notes_file"

release_notes_write \
  "$notes_file" \
  "1.0.0" \
  "v1.0.0" \
  "" \
  "Argo-1.0.0.dmg" \
  "krystal1110/argo/argo"

grep -Fq 'Initial public release.' "$notes_file"
grep -Fq 'Previous release: none' "$notes_file"

grep -Fq 'source "$ROOT_DIR/scripts/release_notes.sh"' scripts/release_homebrew.sh
grep -Fq 'RELEASE_NOTES_SOURCE_FILE' scripts/release_homebrew.sh
grep -Fq 'release_notes_create_file' scripts/release_homebrew.sh

echo "release notes support ok"
