#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

: "${GITHUB_REPOSITORY:=krystal1110/Argo}"

export GITHUB_REPOSITORY

usage() {
  cat <<EOF
Usage:
  ./release.sh                 Bump patch and publish a GitHub release.
  ./release.sh patch           Bump patch and publish.
  ./release.sh minor           Bump minor and publish.
  ./release.sh major           Bump major and publish.
  ./release.sh 1.2.0           Set version and publish.
  ./release.sh set 1.2.0       Set version and publish.

Environment:
  GH_TOKEN=token               GitHub token with release access. GITHUB_TOKEN is also supported.
  SKIP_NOTARIZE=1              Skip notarization.
  SKIP_CASK_UPDATE=1           Skip Homebrew tap update.
  SKIP_GITHUB_RELEASE=1        Skip GitHub release publishing.
EOF
}

require_github_auth() {
  if [[ "${SKIP_GITHUB_RELEASE:-0}" == "1" ]]; then
    return
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "Missing GitHub CLI. Install gh or set SKIP_GITHUB_RELEASE=1." >&2
    exit 1
  fi

  if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    return
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub authentication is required. Run gh auth login, or export GH_TOKEN / GITHUB_TOKEN." >&2
    exit 1
  fi
}

semver_pattern='^[0-9]+\.[0-9]+(\.[0-9]+)?$'

case "$#" in
  0)
    export BUMP_PART="${BUMP_PART:-patch}"
    ;;
  1)
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      patch|minor|major)
        export BUMP_PART="$1"
        ;;
      *)
        if [[ "$1" =~ $semver_pattern ]]; then
          export BUMP_PART=set
          export BUMP_VERSION="$1"
        else
          echo "Unknown release argument: $1" >&2
          usage >&2
          exit 1
        fi
        ;;
    esac
    ;;
  2)
    if [[ "$1" != "set" ]]; then
      echo "Unknown release arguments: $*" >&2
      usage >&2
      exit 1
    fi
    export BUMP_PART=set
    export BUMP_VERSION="$2"
    ;;
  *)
    echo "Too many release arguments: $*" >&2
    usage >&2
    exit 1
    ;;
esac

require_github_auth
exec "$ROOT_DIR/deploy.sh"
