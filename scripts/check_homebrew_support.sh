#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

release_script="scripts/release_homebrew.sh"
website_html="website/index.html"

grep -Fq 'default_tap_project_path()' "$release_script"
grep -Fq 'owner="${GITHUB_REPOSITORY%%/*}"' "$release_script"
grep -Fq 'echo "$owner/homebrew-argo"' "$release_script"
grep -Fq 'TAP_PROJECT_PATH="$(default_tap_project_path || true)"' "$release_script"
grep -Fq 'auto_updates true' "$release_script"
grep -Fq 'depends_on macos: :sonoma' "$release_script"
grep -Fq 'brew install --cask krystal1110/argo/argo' "$website_html"

echo "homebrew support ok"
