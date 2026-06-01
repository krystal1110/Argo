#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

: "${GITLAB_HOST:=code.devops.xiaohongshu.com}"
: "${GITLAB_PROJECT_PATH:=huying/Argo}"
: "${GITLAB_PACKAGE_NAME:=argo}"

export GITLAB_HOST
export GITLAB_PROJECT_PATH
export GITLAB_PACKAGE_NAME

usage() {
  cat <<EOF
Usage:
  ./release.sh                 Bump patch and publish a GitLab release.
  ./release.sh patch           Bump patch and publish.
  ./release.sh minor           Bump minor and publish.
  ./release.sh major           Bump major and publish.
  ./release.sh 1.2.0           Set version and publish.
  ./release.sh set 1.2.0       Set version and publish.

Environment:
  GITLAB_TOKEN=token           Token with api scope for GitLab packages and releases.
  SKIP_NOTARIZE=1              Skip notarization.
  SKIP_CASK_UPDATE=1           Skip Homebrew tap update.
  SKIP_SENTRY_DSYM_UPLOAD=1    Skip Sentry dSYM upload.
  SKIP_GITLAB_RELEASE=1        Skip GitLab publishing.
EOF
}

require_gitlab_token() {
  if [[ "${SKIP_GITLAB_RELEASE:-0}" == "1" ]]; then
    return
  fi

  if [[ -z "${GITLAB_TOKEN:-${GITLAB_PRIVATE_TOKEN:-${PRIVATE_TOKEN:-}}}" ]]; then
    echo "Missing GitLab token. Export GITLAB_TOKEN=<token-with-api-scope> before running release.sh." >&2
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

require_gitlab_token
exec "$ROOT_DIR/deploy.sh"
