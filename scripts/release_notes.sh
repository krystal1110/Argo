#!/usr/bin/env bash

release_notes_commit_target() {
  local tag="$1"

  if [[ -n "$tag" ]] && git rev-parse -q --verify "$tag^{commit}" >/dev/null; then
    echo "$tag"
    return
  fi

  echo "HEAD"
}

release_notes_should_skip_commit() {
  local subject="$1"

  case "$subject" in
    "fix(release): bump "*)
      return 0
      ;;
    feat\(*\):\ add\ *spec | feat\(*\):\ add\ *plan)
      return 0
      ;;
  esac

  return 1
}

release_notes_subject_phrase() {
  local subject="$1"
  local scope=""
  local message="$subject"

  if [[ "$subject" == *"):"* ]]; then
    scope="${subject#*(}"
    scope="${scope%%)*}"
    message="${subject#*: }"
  fi

  case "$scope:$message" in
    island:"finish ui")
      echo "Dynamic Island UI and session flow"
      ;;
    island:"sync claude hooks")
      echo "Claude hook integration"
      ;;
    web:"merge site")
      echo "website launch"
      ;;
    web:*notes*)
      echo "release notes"
      ;;
    web:*)
      echo "website updates"
      ;;
    release:*brew*)
      echo "Homebrew release support"
      ;;
    release:*)
      echo "release packaging"
      ;;
    island:*)
      echo "Dynamic Island updates"
      ;;
    *)
      echo "$message"
      ;;
  esac
}

release_notes_join_phrases() {
  local -a phrases=("$@")
  local count="${#phrases[@]}"

  case "$count" in
    0)
      echo "Initial public release."
      ;;
    1)
      echo "Adds ${phrases[0]}."
      ;;
    2)
      echo "Adds ${phrases[0]} and ${phrases[1]}."
      ;;
    *)
      echo "Adds ${phrases[0]}, ${phrases[1]}, and ${phrases[2]}."
      ;;
  esac
}

release_notes_write_commit_summary_sentence() {
  local previous_tag="$1"
  local target="$2"
  local range=""
  local -a phrases=()
  local phrase

  if [[ -z "$previous_tag" ]] || ! git rev-parse -q --verify "$previous_tag^{commit}" >/dev/null; then
    echo "Initial public release."
    return
  fi

  range="$previous_tag..$target"

  while IFS=$'\t' read -r hash subject; do
    [[ -n "$hash" && -n "$subject" ]] || continue
    if release_notes_should_skip_commit "$subject"; then
      continue
    fi
    phrase="$(release_notes_subject_phrase "$subject")"
    local has_phrase=0
    if ((${#phrases[@]} > 0)); then
      for existing_phrase in "${phrases[@]}"; do
        if [[ "$existing_phrase" == "$phrase" ]]; then
          has_phrase=1
          break
        fi
      done
    fi
    if [[ "$has_phrase" -eq 0 ]]; then
      phrases+=("$phrase")
    fi
    if [[ "${#phrases[@]}" -ge 3 ]]; then
      break
    fi
  done < <(git log --first-parent --reverse --format='%h%x09%s' "$range")

  if ((${#phrases[@]} > 0)); then
    release_notes_join_phrases "${phrases[@]}"
  else
    release_notes_join_phrases
  fi
}

release_notes_write() {
  local output_file="$1"
  local version="$2"
  local tag="$3"
  local previous_tag="$4"
  local dmg_name="$5"
  local brew_install_ref="${6:-}"
  local source_file="${7:-}"
  local target

  target="$(release_notes_commit_target "$tag")"

  {
    echo "## Argo $version"
    echo
    if [[ -n "$source_file" && -f "$source_file" ]]; then
      cat "$source_file"
      echo
    else
      echo "### Summary"
      echo
      release_notes_write_commit_summary_sentence "$previous_tag" "$target"
      echo
    fi
    echo "### Install"
    echo
    echo "- DMG: \`$dmg_name\`"
    if [[ -n "$brew_install_ref" ]]; then
      echo "- Homebrew: \`brew install --cask $brew_install_ref\`"
    fi
    if [[ -n "$previous_tag" ]]; then
      echo "- Previous release: \`$previous_tag\`"
    else
      echo "- Previous release: none"
    fi
  } > "$output_file"
}

release_notes_create_file() {
  local version="$1"
  local tag="$2"
  local previous_tag="$3"
  local dmg_name="$4"
  local brew_install_ref="${5:-}"
  local source_file="${6:-}"
  local release_notes_file

  release_notes_file="$(mktemp "${TMPDIR:-/tmp}/argo-release-notes.XXXXXX")"
  release_notes_write \
    "$release_notes_file" \
    "$version" \
    "$tag" \
    "$previous_tag" \
    "$dmg_name" \
    "$brew_install_ref" \
    "$source_file"

  echo "$release_notes_file"
}
