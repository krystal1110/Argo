#!/usr/bin/env bash

gitlab_configure() {
  : "${GITLAB_PROTOCOL:=https}"
  : "${GITLAB_HOST:=code.devops.xiaohongshu.com}"
  : "${GITLAB_PACKAGE_NAME:=argo}"
  : "${GITLAB_RELEASE_MAX_ATTEMPTS:=3}"
  : "${GITLAB_RELEASE_RETRY_DELAY:=10}"
  GITLAB_TOKEN="${GITLAB_TOKEN:-${GITLAB_PRIVATE_TOKEN:-${PRIVATE_TOKEN:-}}}"

  if [[ -z "${GITLAB_PROJECT_PATH:-}" ]]; then
    GITLAB_PROJECT_PATH="$(gitlab_infer_project_path || true)"
  fi
}

gitlab_infer_project_path() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "$remote" =~ ^git@([^:]+):(.+)$ ]]; then
    [[ "${BASH_REMATCH[1]}" == "${GITLAB_HOST:-code.devops.xiaohongshu.com}" ]] || return 1
    echo "${BASH_REMATCH[2]%.git}"
    return
  fi
  if [[ "$remote" =~ ^https?://([^/]+)/(.+)$ ]]; then
    [[ "${BASH_REMATCH[1]}" == "${GITLAB_HOST:-code.devops.xiaohongshu.com}" ]] || return 1
    echo "${BASH_REMATCH[2]%.git}"
    return
  fi
  if [[ "$remote" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    [[ "${BASH_REMATCH[1]}" == "${GITLAB_HOST:-code.devops.xiaohongshu.com}" ]] || return 1
    echo "${BASH_REMATCH[2]%.git}"
    return
  fi
  return 1
}

gitlab_urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
}

gitlab_project_ref() {
  if [[ -n "${GITLAB_PROJECT_ID:-}" ]]; then
    echo "$GITLAB_PROJECT_ID"
    return
  fi
  gitlab_urlencode "$GITLAB_PROJECT_PATH"
}

gitlab_api_base() {
  echo "${GITLAB_PROTOCOL}://${GITLAB_HOST}/api/v4"
}

gitlab_project_url() {
  echo "${GITLAB_PROTOCOL}://${GITLAB_HOST}/${GITLAB_PROJECT_PATH}"
}

gitlab_releases_url() {
  echo "$(gitlab_project_url)/-/releases"
}

gitlab_release_url() {
  local tag="$1"
  echo "$(gitlab_releases_url)/$tag"
}

gitlab_compare_url() {
  local previous_tag="$1"
  local tag="$2"
  echo "$(gitlab_project_url)/-/compare/$previous_tag...$tag"
}

gitlab_package_version_url() {
  local version="$1"
  echo "$(gitlab_api_base)/projects/$(gitlab_project_ref)/packages/generic/$GITLAB_PACKAGE_NAME/$version"
}

gitlab_package_file_url() {
  local version="$1"
  local file_name="$2"
  echo "$(gitlab_package_version_url "$version")/$(gitlab_urlencode "$file_name")"
}

gitlab_require_config() {
  gitlab_configure
  if [[ -z "${GITLAB_PROJECT_PATH:-}" ]]; then
    echo "Unable to infer GitLab project from origin. Set GITLAB_PROJECT_PATH=huying/Argo." >&2
    return 1
  fi
}

gitlab_require_token() {
  gitlab_require_config || return 1
  if [[ -z "${GITLAB_TOKEN:-}" ]]; then
    echo "Missing GitLab token. Set GITLAB_TOKEN to a token with api scope." >&2
    return 1
  fi
}

gitlab_auth_header() {
  echo "PRIVATE-TOKEN: $GITLAB_TOKEN"
}

gitlab_api() {
  curl --fail --show-error --silent \
    --header "$(gitlab_auth_header)" \
    "$@"
}

gitlab_project_api_url() {
  echo "$(gitlab_api_base)/projects/$(gitlab_project_ref)"
}

gitlab_retry() {
  local label="$1"
  shift
  local attempt=1
  local rc
  while :; do
    rc=0
    "$@" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      return 0
    fi
    if (( attempt >= GITLAB_RELEASE_MAX_ATTEMPTS )); then
      echo "${label} failed after ${attempt} attempt(s) (exit ${rc})." >&2
      return "$rc"
    fi
    echo "${label} failed (exit ${rc}); retrying in ${GITLAB_RELEASE_RETRY_DELAY}s (attempt $((attempt + 1))/${GITLAB_RELEASE_MAX_ATTEMPTS})..." >&2
    sleep "$GITLAB_RELEASE_RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

gitlab_release_exists() {
  local tag="$1"
  local encoded_tag
  local http_code
  encoded_tag="$(gitlab_urlencode "$tag")"
  http_code="$(
    curl --silent --show-error --output /dev/null --write-out "%{http_code}" \
      --header "$(gitlab_auth_header)" \
      "$(gitlab_project_api_url)/releases/$encoded_tag"
  )" || return 1
  [[ "$http_code" == "200" ]]
}

gitlab_create_or_update_release() {
  local tag="$1"
  local title="$2"
  local notes_file="$3"
  local encoded_tag
  encoded_tag="$(gitlab_urlencode "$tag")"

  if gitlab_release_exists "$tag"; then
    gitlab_api \
      --request PUT \
      --form "name=$title" \
      --form "description=<$notes_file" \
      "$(gitlab_project_api_url)/releases/$encoded_tag" >/dev/null
  else
    gitlab_api \
      --request POST \
      --form "tag_name=$tag" \
      --form "name=$title" \
      --form "description=<$notes_file" \
      "$(gitlab_project_api_url)/releases" >/dev/null
  fi
}

gitlab_package_upload_once() {
  local version="$1"
  local asset_path="$2"
  local file_name
  local url
  local tmp_response
  local http_code
  file_name="$(basename "$asset_path")"
  url="$(gitlab_package_file_url "$version" "$file_name")"
  tmp_response="$(mktemp "${TMPDIR:-/tmp}/argo-gitlab-upload.XXXXXX")"

  http_code="$(
    curl --silent --show-error --output "$tmp_response" --write-out "%{http_code}" \
      --request PUT \
      --header "$(gitlab_auth_header)" \
      --upload-file "$asset_path" \
      "$url"
  )" || {
    local rc=$?
    echo "GitLab package upload failed for $file_name (curl exit $rc)." >&2
    cat "$tmp_response" >&2
    rm -f "$tmp_response"
    return "$rc"
  }

  case "$http_code" in
    200|201)
      rm -f "$tmp_response"
      return 0
      ;;
    400|409)
      if grep -Eiq 'already|exists|taken' "$tmp_response"; then
        echo "Package file already exists on GitLab: $file_name" >&2
        rm -f "$tmp_response"
        return 0
      fi
      ;;
  esac

  echo "GitLab package upload failed for $file_name with HTTP $http_code:" >&2
  cat "$tmp_response" >&2
  rm -f "$tmp_response"
  return 1
}

gitlab_release_link_id_for_name() {
  local tag="$1"
  local name="$2"
  local encoded_tag
  local response
  encoded_tag="$(gitlab_urlencode "$tag")"
  response="$(gitlab_api --request GET "$(gitlab_project_api_url)/releases/$encoded_tag/assets/links")" || return 1
  printf '%s' "$response" | python3 -c '
import json
import sys

target = sys.argv[1]
links = json.load(sys.stdin)
for link in links:
    if link.get("name") == target:
        print(link.get("id", ""))
        sys.exit(0)
sys.exit(1)
' "$name"
}

gitlab_release_link_upsert() {
  local tag="$1"
  local name="$2"
  local url="$3"
  local direct_asset_path="$4"
  local encoded_tag
  local link_id
  encoded_tag="$(gitlab_urlencode "$tag")"

  if link_id="$(gitlab_release_link_id_for_name "$tag" "$name")"; then
    gitlab_api \
      --request PUT \
      --form "name=$name" \
      --form "url=$url" \
      --form "direct_asset_path=$direct_asset_path" \
      --form "link_type=package" \
      "$(gitlab_project_api_url)/releases/$encoded_tag/assets/links/$link_id" >/dev/null
  else
    gitlab_api \
      --request POST \
      --form "name=$name" \
      --form "url=$url" \
      --form "direct_asset_path=$direct_asset_path" \
      --form "link_type=package" \
      "$(gitlab_project_api_url)/releases/$encoded_tag/assets/links" >/dev/null
  fi
}

gitlab_release_assets_complete() {
  local tag="$1"
  shift
  local encoded_tag
  local response
  encoded_tag="$(gitlab_urlencode "$tag")"
  response="$(gitlab_api --request GET "$(gitlab_project_api_url)/releases/$encoded_tag/assets/links" 2>/dev/null)" || return 1
  printf '%s' "$response" | python3 -c '
import json
import sys

required = set(sys.argv[1:])
links = json.load(sys.stdin)
names = {link.get("name") for link in links}
missing = required - names
sys.exit(0 if not missing else 1)
' "$@"
}

gitlab_publish_release_assets() {
  local tag="$1"
  local version="$2"
  local title="$3"
  local notes_file="$4"
  shift 4

  gitlab_require_token || return 1
  gitlab_retry "GitLab release upsert" \
    gitlab_create_or_update_release "$tag" "$title" "$notes_file"

  local asset_path
  local file_name
  local file_url
  local direct_asset_path
  for asset_path in "$@"; do
    file_name="$(basename "$asset_path")"
    file_url="$(gitlab_package_file_url "$version" "$file_name")"
    direct_asset_path="/downloads/$tag/$file_name"
    gitlab_retry "GitLab package upload $file_name" \
      gitlab_package_upload_once "$version" "$asset_path"
    gitlab_retry "GitLab release asset link $file_name" \
      gitlab_release_link_upsert "$tag" "$file_name" "$file_url" "$direct_asset_path"
  done
}
