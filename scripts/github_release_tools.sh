#!/usr/bin/env bash

github_configure() {
  : "${GITHUB_REPOSITORY:=}"
  : "${GITHUB_RELEASE_MAX_ATTEMPTS:=3}"
  : "${GITHUB_RELEASE_RETRY_DELAY:=10}"
  if [[ -z "$GITHUB_REPOSITORY" ]]; then
    GITHUB_REPOSITORY="$(github_infer_repository || true)"
  fi
}

github_infer_repository() {
  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || true)"

  if [[ "$remote_url" =~ ^git@github\.com:(.+)$ ]]; then
    echo "${BASH_REMATCH[1]%.git}"
    return
  fi
  if [[ "$remote_url" =~ ^https://github\.com/(.+)$ ]]; then
    echo "${BASH_REMATCH[1]%.git}"
    return
  fi

  return 1
}

github_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    return 1
  fi
}

github_require_config() {
  github_configure
  if [[ -z "$GITHUB_REPOSITORY" ]]; then
    echo "Unable to infer GitHub repository from origin. Set GITHUB_REPOSITORY=krystal1110/Argo." >&2
    return 1
  fi
}

github_require_auth() {
  github_require_config || return 1
  github_require_cmd gh || return 1
  if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub authentication is required. Run gh auth login, or set GH_TOKEN / GITHUB_TOKEN." >&2
    return 1
  fi
}

github_repository_url() {
  github_require_config >/dev/null || return 1
  echo "https://github.com/$GITHUB_REPOSITORY"
}

github_releases_url() {
  echo "$(github_repository_url)/releases"
}

github_release_url() {
  local tag="$1"
  echo "$(github_releases_url)/tag/$tag"
}

github_release_download_url_prefix() {
  local tag="$1"
  echo "$(github_repository_url)/releases/download/$tag/"
}

github_release_download_url() {
  local tag="$1"
  local file_name="$2"
  echo "$(github_release_download_url_prefix "$tag")$file_name"
}

github_retry() {
  local label="$1"
  shift
  local attempt=1
  local rc=0

  while :; do
    if "$@"; then
      return 0
    fi
    rc=$?
    if (( attempt >= GITHUB_RELEASE_MAX_ATTEMPTS )); then
      echo "${label} failed after ${attempt} attempts." >&2
      return "$rc"
    fi
    echo "${label} failed (exit ${rc}); retrying in ${GITHUB_RELEASE_RETRY_DELAY}s (attempt $((attempt + 1))/${GITHUB_RELEASE_MAX_ATTEMPTS})..." >&2
    sleep "$GITHUB_RELEASE_RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

github_release_exists() {
  local tag="$1"
  gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1
}

github_create_or_update_release() {
  local tag="$1"
  local title="$2"
  local notes_file="$3"
  local target="${GITHUB_RELEASE_TARGET:-$(git rev-parse HEAD)}"

  github_require_auth || return 1
  if github_release_exists "$tag"; then
    gh release edit "$tag" \
      --repo "$GITHUB_REPOSITORY" \
      --title "$title" \
      --notes-file "$notes_file" >/dev/null
  else
    gh release create "$tag" \
      --repo "$GITHUB_REPOSITORY" \
      --target "$target" \
      --title "$title" \
      --notes-file "$notes_file" >/dev/null
  fi
}

github_upload_release_assets() {
  local tag="$1"
  shift
  github_require_auth || return 1
  gh release upload "$tag" "$@" --repo "$GITHUB_REPOSITORY" --clobber
}

github_release_assets_complete() {
  local tag="$1"
  shift
  local assets
  assets="$(gh release view "$tag" --repo "$GITHUB_REPOSITORY" --json assets --jq '.assets[].name' 2>/dev/null)" || return 1

  local required
  for required in "$@"; do
    if ! grep -Fxq "$required" <<< "$assets"; then
      return 1
    fi
  done
}

github_publish_release_assets() {
  local tag="$1"
  local title="$2"
  local notes_file="$3"
  shift 3

  github_retry "GitHub release upsert" \
    github_create_or_update_release "$tag" "$title" "$notes_file"
  github_retry "GitHub release asset upload" \
    github_upload_release_assets "$tag" "$@"
}
