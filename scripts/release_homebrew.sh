#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_FILE="${PROJECT_FILE:-$ROOT_DIR/Argo.xcodeproj/project.pbxproj}"
APP_NAME="${APP_NAME:-Argo}"
APP_SLUG="${APP_SLUG:-argo}"
APP_DESC="${APP_DESC:-Terminal workspace manager for git repositories, worktrees, and split panes}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Argo.xcodeproj}"
SCHEME="${SCHEME:-Argo}"
RELEASE_ARCHS="${RELEASE_ARCHS:-arm64 x86_64}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APPCAST_FILE="${APPCAST_FILE:-$ROOT_DIR/appcast.xml}"
WEBSITE_RELEASES_FILE="${WEBSITE_RELEASES_FILE:-$ROOT_DIR/website/releases/releases.json}"
WEBSITE_RELEASES_HTML_FILE="${WEBSITE_RELEASES_HTML_FILE:-$ROOT_DIR/website/releases/index.html}"
SIGN_SCRIPT="${SIGN_SCRIPT:-$ROOT_DIR/scripts/sign_macos.sh}"
ARCHIVE_DSYM_SCRIPT="${ARCHIVE_DSYM_SCRIPT:-$ROOT_DIR/scripts/archive_dsym.sh}"
TAP_PROJECT_PATH="${TAP_PROJECT_PATH:-${TAP_REPO:-}}"
TAP_REMOTE_URL="${TAP_REMOTE_URL:-}"
TAP_DIR_DEFAULT="$ROOT_DIR/tmp/homebrew-argo"
TAP_DIR="${TAP_DIR:-$TAP_DIR_DEFAULT}"
CASK_PATH="${CASK_PATH:-Casks/${APP_SLUG}.rb}"
APP_HOMEPAGE="${APP_HOMEPAGE:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
STABLE_BRANCH="${STABLE_BRANCH:-stable}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
DEFAULT_NOTARYTOOL_PROFILE="${DEFAULT_NOTARYTOOL_PROFILE:-argo-notarytool}"
ARGO_RELEASE_HOME="${ARGO_RELEASE_HOME:-$HOME/.argo_release}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$ARGO_RELEASE_HOME/sparkle_private_key}"
SPARKLE_MAX_VERSIONS="${SPARKLE_MAX_VERSIONS:-10}"
SPARKLE_CHANNEL="${SPARKLE_CHANNEL:-}"
SKIP_BUMP="${SKIP_BUMP:-0}"
BUMP_PART="${BUMP_PART:-patch}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"
SKIP_GITHUB_RELEASE="${SKIP_GITHUB_RELEASE:-0}"
SKIP_CASK_UPDATE="${SKIP_CASK_UPDATE:-0}"
FORCE_REBUILD="${FORCE_REBUILD:-1}"
BUMP_VERSION="${BUMP_VERSION:-}"
RELEASE_NOTES_SOURCE_FILE="${RELEASE_NOTES_SOURCE_FILE:-}"
RELEASE_NOTES_FILE=""
APPCAST_STAGING_DIR=""
CLONED_DEFAULT_TAP_DIR=0

source "$ROOT_DIR/scripts/sparkle_tools.sh"
source "$ROOT_DIR/scripts/github_release_tools.sh"
source "$ROOT_DIR/scripts/release_notes.sh"
source "$ROOT_DIR/scripts/website_release_notes.sh"

usage() {
  cat <<EOF
Usage:
  scripts/release_homebrew.sh

Environment:
  SKIP_BUMP=1            Publish the current MARKETING_VERSION and CURRENT_PROJECT_VERSION unchanged.
  BUMP_PART=patch        Version bump part when SKIP_BUMP=0. patch also increments CURRENT_PROJECT_VERSION by 1.
  BUMP_PART=set BUMP_VERSION=1.2.0
                         Set MARKETING_VERSION explicitly before publishing.
  SKIP_NOTARIZE=1        Skip notarization in sign_macos.sh.
  SKIP_GITHUB_RELEASE=1  Skip GitHub release upload and release asset links.
  SKIP_CASK_UPDATE=1     Skip updating the Homebrew tap repository.
  GITHUB_REPOSITORY=krystal1110/Argo  GitHub repository. Inferred from origin when omitted.
  GH_TOKEN=token          GitHub token with release access. GITHUB_TOKEN is also supported.
  STABLE_BRANCH=stable    Branch pushed after appcast updates so SUFeedURL can read the feed.
  TAP_PROJECT_PATH=owner/homebrew-argo  Optional GitHub tap repository used when updating the cask.
                         Defaults to the release owner, e.g. krystal1110/homebrew-argo.
  TAP_REMOTE_URL=git@host:owner/homebrew-argo.git  Optional explicit tap remote URL.
  RELEASE_NOTES_SOURCE_FILE=path  Optional human-written Markdown body for GitHub/Sparkle release notes.
  ARGO_RELEASE_HOME=dir Release-only secret directory. Default: ~/.argo_release.
  DEFAULT_NOTARYTOOL_PROFILE=name  Auto-detected notarytool profile. Default: argo-notarytool.
  NOTARYTOOL_PROFILE=name  Keychain profile used for Apple notarization.
  SPARKLE_PRIVATE_KEY_FILE=path  Private key used for Sparkle appcast signing.
EOF
}

read_setting() {
  local key="$1"
  awk -F ' = ' -v key="$key" '$1 ~ key { gsub(/;/, "", $2); print $2; exit }' "$PROJECT_FILE"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

detect_notarytool_profile() {
  local profile="${1:-}"
  [[ -n "$profile" ]] || return 1
  xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1
}

ensure_clean_worktree() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "Working tree is not clean. Commit or stash changes before release." >&2
    exit 1
  fi
}

detect_signing_identity() {
  security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' |
    head -n 1
}

generate_release_notes() {
  local version="$1"
  local tag="$2"
  local previous_tag="$3"
  local dmg_name="$4"
  local brew_install_ref

  brew_install_ref="$(brew_install_target)"
  release_notes_create_file "$version" "$tag" "$previous_tag" "$dmg_name" "$brew_install_ref" "$RELEASE_NOTES_SOURCE_FILE"
}

brew_install_target() {
  if [[ "$TAP_PROJECT_PATH" =~ ^([^/]+)/homebrew-(.+)$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/$APP_SLUG"
    return
  fi

  echo "$APP_SLUG"
}

default_tap_project_path() {
  [[ -n "$GITHUB_REPOSITORY" && "$GITHUB_REPOSITORY" == */* ]] || return 1

  local owner
  owner="${GITHUB_REPOSITORY%%/*}"
  [[ -n "$owner" ]] || return 1

  echo "$owner/homebrew-argo"
}

ensure_cask_metadata() {
  local cask_file="$1"

  python3 - "$cask_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
metadata = [
    "  auto_updates true",
    "  depends_on macos: :sonoma",
]
lines = [
    "  depends_on macos: :sonoma"
    if line == "  depends_on macos: \">= :sonoma\""
    else line
    for line in lines
]
missing = [line for line in metadata if line not in lines]

if missing:
    for index, line in enumerate(lines):
        if line.startswith("  homepage "):
            lines[index + 1:index + 1] = ["", *missing]
            break
    else:
        for index, line in enumerate(lines):
            if line.startswith("  app "):
                lines[index:index] = [*missing, ""]
                break
        else:
            lines.extend(["", *missing])

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

# A previous run is considered "fully published" when the GitHub release for
# the tag already carries every core artifact (DMG, app zip, dSYM zip). The
# appcast.xml alone does not count — a release with only the appcast is the
# signature of a publish that died midway through asset upload.
release_assets_complete() {
  local tag="$1"
  local required=(
    "$(basename "$DIST_DMG_PATH")"
    "$(basename "$DIST_ZIP_PATH")"
    "$(basename "$DIST_DSYM_ZIP_PATH")"
  )
  github_release_assets_complete "$tag" "${required[@]}"
}

tap_remote_url() {
  if [[ -n "$TAP_REMOTE_URL" ]]; then
    echo "$TAP_REMOTE_URL"
    return
  fi
  if [[ -n "$TAP_PROJECT_PATH" ]]; then
    echo "git@github.com:$TAP_PROJECT_PATH.git"
  fi
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

for cmd in git curl python3 shasum mktemp security; do
  require_cmd "$cmd"
done

if [[ -z "$NOTARYTOOL_PROFILE" ]] && detect_notarytool_profile "$DEFAULT_NOTARYTOOL_PROFILE"; then
  NOTARYTOOL_PROFILE="$DEFAULT_NOTARYTOOL_PROFILE"
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Missing Xcode project file: $PROJECT_FILE" >&2
  exit 1
fi

if [[ ! -x "$SIGN_SCRIPT" ]]; then
  echo "Missing executable sign script: $SIGN_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$ARCHIVE_DSYM_SCRIPT" ]]; then
  echo "Missing executable dSYM archive script: $ARCHIVE_DSYM_SCRIPT" >&2
  exit 1
fi

cd "$ROOT_DIR"
if [[ "$SKIP_GITHUB_RELEASE" != "1" ]]; then
  github_require_auth
else
  github_require_config
fi

if [[ -z "$TAP_PROJECT_PATH" && -z "$TAP_REMOTE_URL" ]]; then
  TAP_PROJECT_PATH="$(default_tap_project_path || true)"
fi

if [[ -z "$APP_HOMEPAGE" ]]; then
  APP_HOMEPAGE="$(github_repository_url)"
fi

ensure_clean_worktree

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(detect_signing_identity)"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "Unable to detect a Developer ID Application signing identity." >&2
  exit 1
fi

if [[ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
  echo "Missing Sparkle private key file: $SPARKLE_PRIVATE_KEY_FILE" >&2
  echo "Run scripts/setup_sparkle_keys.sh first, or set SPARKLE_PRIVATE_KEY_FILE / ARGO_RELEASE_HOME." >&2
  exit 1
fi

VERSION="$(read_setting MARKETING_VERSION)"
TAG="v$VERSION"
DIST_DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
DIST_ZIP_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.app.zip"
DIST_DSYM_PATH="$OUTPUT_DIR/dSYMs/$APP_NAME-$VERSION.app.dSYM"
DIST_DSYM_ZIP_PATH="$DIST_DSYM_PATH.zip"
RELEASE_DONE=0
DID_BUMP=0
FAILED_LINE=""
FAILED_COMMAND=""
PREVIOUS_TAG="$(git tag -l 'v*' --sort=-version:refname | head -n 1 || true)"

record_failure() {
  FAILED_LINE="$1"
  FAILED_COMMAND="$2"
}
trap 'record_failure "$LINENO" "$BASH_COMMAND"' ERR

cleanup() {
  local exit_code=$?
  if [[ "$RELEASE_DONE" -eq 0 ]]; then
    if [[ "$exit_code" -ne 0 ]]; then
      if [[ -n "$FAILED_COMMAND" ]]; then
        echo "Release aborted (exit $exit_code) at release_homebrew.sh:$FAILED_LINE — $FAILED_COMMAND" >&2
      else
        echo "Release aborted with exit code $exit_code." >&2
      fi
    fi
    if ! git diff --quiet -- "$PROJECT_FILE" "$APPCAST_FILE" "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE" 2>/dev/null \
        || ! git diff --cached --quiet -- "$PROJECT_FILE" "$APPCAST_FILE" "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE" 2>/dev/null; then
      echo "Reverting uncommitted release metadata changes." >&2
      git restore --source=HEAD --staged --worktree -- "$PROJECT_FILE" "$APPCAST_FILE" "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$RELEASE_NOTES_FILE" && -f "$RELEASE_NOTES_FILE" ]]; then
    rm -f "$RELEASE_NOTES_FILE"
  fi
  if [[ -n "$APPCAST_STAGING_DIR" && -d "$APPCAST_STAGING_DIR" ]]; then
    rm -rf "$APPCAST_STAGING_DIR"
  fi
}
trap cleanup EXIT

# Resume vs. new-release detection. A tag matching the current
# MARKETING_VERSION already existing locally means a previous run got at least
# as far as tagging. Two cases to tell apart:
#   1. The previous run fully published — the GitHub release already carries
#      every core asset. The version simply was never bumped afterwards, so
#      this invocation is a brand new release: fall through and bump normally.
#   2. The publish step died partway (tag pushed, but some/all assets missing,
#      e.g. flaky TLS during a package upload). This is a real resume: skip
#      everything already done and only redo the upload.
RESUMING=0
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  if [[ "$SKIP_GITHUB_RELEASE" == "1" ]]; then
    echo "Tag v$VERSION already exists and SKIP_GITHUB_RELEASE=1 prevents checking whether it is fully published." >&2
    exit 1
  fi
  if release_assets_complete "v$VERSION"; then
    echo "Release v$VERSION is already published with all core assets — treating this as a new release and bumping the version." >&2
  else
    RESUMING=1
    SKIP_BUMP=1
    echo "Tag v$VERSION already exists locally but its release is incomplete — resuming release upload only." >&2
    echo "Skipping: bump, sign/notarize, dSYM archive+upload, app zip, appcast regen, commit, tag push." >&2
    echo "All artifacts must already exist in $OUTPUT_DIR." >&2
    # On resume the latest tag IS the current release, so step back one for
    # the release-notes diff.
    PREVIOUS_TAG="$(git tag -l 'v*' --sort=-version:refname | grep -v "^v${VERSION}\$" | head -n 1 || true)"
  fi
fi

if [[ "$SKIP_BUMP" != "1" ]]; then
  if [[ "$BUMP_PART" == "set" ]]; then
    if [[ -z "$BUMP_VERSION" ]]; then
      echo "BUMP_PART=set requires BUMP_VERSION=<version>." >&2
      exit 1
    fi
    "$ROOT_DIR/scripts/bump_version.sh" set "$BUMP_VERSION"
  else
    "$ROOT_DIR/scripts/bump_version.sh" "$BUMP_PART"
  fi
  DID_BUMP=1
  VERSION="$(read_setting MARKETING_VERSION)"
fi

TAG="v$VERSION"
DIST_DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
DIST_ZIP_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.app.zip"
DIST_DSYM_PATH="$OUTPUT_DIR/dSYMs/$APP_NAME-$VERSION.app.dSYM"
DIST_DSYM_ZIP_PATH="$DIST_DSYM_PATH.zip"

if [[ "$RESUMING" != "1" ]] && git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  # Tag appeared between the initial check and now (e.g. bump took us to a
  # version that already has a tag — should not normally happen).
  echo "Tag already exists: $TAG" >&2
  exit 1
fi

SIGN_ARGS=(
  --identity "$SIGNING_IDENTITY"
  --version "$VERSION"
  --output-dir "$OUTPUT_DIR"
  --release-archs "$RELEASE_ARCHS"
)

if [[ "$FORCE_REBUILD" == "1" ]]; then
  SIGN_ARGS+=(--force-rebuild)
fi

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
  SIGN_ARGS+=(--notarize)
fi

if [[ "$RESUMING" != "1" ]]; then
  NOTARYTOOL_PROFILE="$NOTARYTOOL_PROFILE" \
  PROJECT_PATH="$PROJECT_PATH" \
  SCHEME="$SCHEME" \
  "$SIGN_SCRIPT" "${SIGN_ARGS[@]}"
fi

if [[ ! -f "$DIST_DMG_PATH" ]]; then
  echo "Missing packaged DMG: $DIST_DMG_PATH" >&2
  exit 1
fi

if [[ "$RESUMING" != "1" ]]; then
  APP_NAME="$APP_NAME" \
  VERSION="$VERSION" \
  OUTPUT_DIR="$OUTPUT_DIR" \
  "$ARCHIVE_DSYM_SCRIPT" --version "$VERSION"
fi

if [[ ! -d "$DIST_DSYM_PATH" || ! -f "$DIST_DSYM_ZIP_PATH" ]]; then
  echo "Missing archived dSYM artifacts: $DIST_DSYM_PATH / $DIST_DSYM_ZIP_PATH" >&2
  exit 1
fi

RELEASE_NOTES_FILE="$(generate_release_notes "$VERSION" "$TAG" "$PREVIOUS_TAG" "$(basename "$DIST_DMG_PATH")")"

if [[ "$RESUMING" != "1" ]]; then
  sparkle_create_app_zip "$OUTPUT_DIR/$APP_NAME.app" "$DIST_ZIP_PATH"

  APPCAST_DOWNLOAD_URL_PREFIX="$(github_release_download_url_prefix "$TAG")"

  APPCAST_STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/argo-appcast.XXXXXX")"
  ZIP_BASENAME="$(basename "$DIST_ZIP_PATH" .zip)"
  cp "$DIST_ZIP_PATH" "$APPCAST_STAGING_DIR/"
  cp "$RELEASE_NOTES_FILE" "$APPCAST_STAGING_DIR/$ZIP_BASENAME.md"
  if [[ -f "$APPCAST_FILE" ]]; then
    cp "$APPCAST_FILE" "$APPCAST_STAGING_DIR/appcast.xml"
  fi

  sparkle_generate_appcast \
    "$APPCAST_STAGING_DIR" \
    "$SPARKLE_PRIVATE_KEY_FILE" \
    "$APPCAST_DOWNLOAD_URL_PREFIX" \
    "$(github_release_url "$TAG")" \
    "$APP_HOMEPAGE" \
    "$SPARKLE_MAX_VERSIONS" \
    "$SPARKLE_CHANNEL" \
    "$ROOT_DIR" \
    "$PROJECT_PATH" \
    "$SCHEME"

  cp "$APPCAST_STAGING_DIR/appcast.xml" "$APPCAST_FILE"
  rm -rf "$APPCAST_STAGING_DIR"

  WEBSITE_BREW_INSTALL_REF="$(brew_install_target)" \
    website_release_notes_update "$VERSION" "$TAG" "$PREVIOUS_TAG" "$DIST_DMG_PATH" "$RELEASE_NOTES_FILE"

  git add -- "$PROJECT_FILE" "$APPCAST_FILE" "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE"
  if ! git diff --cached --quiet; then
    git commit -m "fix(release): bump $VERSION"
    git push origin "$(git branch --show-current)"
    git push origin "HEAD:$STABLE_BRANCH"
  fi

  git tag "$TAG"
  git push origin "$TAG"
fi

if [[ ! -f "$DIST_ZIP_PATH" ]]; then
  echo "Missing app zip: $DIST_ZIP_PATH" >&2
  exit 1
fi

if [[ "$SKIP_GITHUB_RELEASE" != "1" ]]; then
  github_publish_release_assets \
    "$TAG" \
    "$APP_NAME $VERSION" \
    "$RELEASE_NOTES_FILE" \
    "$DIST_DMG_PATH" \
    "$DIST_ZIP_PATH" \
    "$DIST_DSYM_ZIP_PATH" \
    "$APPCAST_FILE"
fi

if [[ "$SKIP_CASK_UPDATE" != "1" ]]; then
  SHA256="$(shasum -a 256 "$DIST_DMG_PATH" | awk '{print $1}')"
  TAP_REMOTE="$(tap_remote_url)"
  if [[ -z "$TAP_REMOTE" ]]; then
    echo "Set TAP_PROJECT_PATH or TAP_REMOTE_URL, or set SKIP_CASK_UPDATE=1." >&2
    exit 1
  fi
  CASK_DMG_URL_TEMPLATE="$(github_release_download_url 'v#{version}' "$APP_NAME-#{version}.dmg")"

  if [[ "$TAP_DIR" == "$TAP_DIR_DEFAULT" ]]; then
    rm -rf "$TAP_DIR"
    mkdir -p "$(dirname "$TAP_DIR")"
    git clone "$TAP_REMOTE" "$TAP_DIR"
    CLONED_DEFAULT_TAP_DIR=1
  elif [[ ! -d "$TAP_DIR/.git" ]]; then
    mkdir -p "$(dirname "$TAP_DIR")"
    git clone "$TAP_REMOTE" "$TAP_DIR"
  fi

  cd "$TAP_DIR"
  git fetch origin
  if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    git checkout main
  fi
  git pull --rebase origin main

  mkdir -p "$(dirname "$CASK_PATH")"
  if [[ ! -f "$CASK_PATH" ]]; then
    cat > "$CASK_PATH" <<EOF
cask "$APP_SLUG" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$CASK_DMG_URL_TEMPLATE"
  name "$APP_NAME"
  desc "$APP_DESC"
  homepage "$APP_HOMEPAGE"

  auto_updates true
  depends_on macos: :sonoma

  app "$APP_NAME.app"
end
EOF
  else
    sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/" "$CASK_PATH"
    sed -i '' "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" "$CASK_PATH"
    sed -i '' "s|^  url \".*\"|  url \"$CASK_DMG_URL_TEMPLATE\"|" "$CASK_PATH"
    ensure_cask_metadata "$CASK_PATH"
  fi

  git add "$CASK_PATH"
  if ! git diff --cached --quiet; then
    git commit -m "bump ${APP_SLUG} to $VERSION"
    if ! git push origin main; then
      git pull --rebase origin main
      git push origin main
    fi
  fi
fi

RELEASE_DONE=1
if [[ "$CLONED_DEFAULT_TAP_DIR" == "1" ]]; then
  rm -rf "$TAP_DIR"
fi
echo "Done. Released $TAG"
