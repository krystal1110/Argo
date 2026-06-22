#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ARGO_ISLAND_SMOKE_DIR:-/tmp/argo-island-smoke}"
mkdir -p "$OUT"

resolve_argo_bin() {
  if [[ -n "${ARGO_BIN:-}" && -x "${ARGO_BIN}" ]]; then
    printf '%s\n' "$ARGO_BIN"
    return 0
  fi

  local settings="$OUT/build-settings.txt"
  xcodebuild \
    -project "$ROOT/Argo.xcodeproj" \
    -scheme Argo \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -showBuildSettings > "$settings"

  local products
  products="$(awk -F'= ' '/ BUILT_PRODUCTS_DIR = / {print $2; exit}' "$settings")"
  local candidate="$products/Argo.app/Contents/MacOS/Argo"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*/Build/Products/Debug/Argo.app/Contents/MacOS/Argo' \
    -type f \
    -print |
    while IFS= read -r path; do
      stat -f '%m %N' "$path"
    done |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
}

binary_mtime() {
  local argo_bin="$1"
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME:-}" ]]; then
    printf '%s\n' "$ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME"
    return 0
  fi
  stat -f '%m' "$argo_bin"
}

running_argo_pids() {
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_PIDS:-}" ]]; then
    tr ' ' '\n' <<< "$ARGO_ISLAND_SMOKE_FAKE_PIDS" | sed '/^$/d'
    return 0
  fi

  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    local command
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ "$command" == *"/Argo.app/Contents/MacOS/Argo"* ]] || continue
    [[ "$command" == *" notify "* ]] && continue
    printf '%s\n' "$pid"
  done < <(pgrep -f '/Argo.app/Contents/MacOS/Argo' 2>/dev/null || true)
}

pid_command() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi
  ps -p "$pid" -o command= 2>/dev/null || true
}

command_matches_binary() {
  local command="$1"
  local argo_bin="$2"

  [[ "$command" == "$argo_bin" || "$command" == "$argo_bin "* ]]
}

current_process_id() {
  printf '%s\n' "${ARGO_ISLAND_SMOKE_FAKE_CURRENT_PID:-$$}"
}

pid_parent() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi

  ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]' || true
}

target_ancestor_pid() {
  local pid="$1"
  local argo_bin="$2"
  local depth=0

  while [[ -n "$pid" && "$pid" != "0" && "$depth" -lt 64 ]]; do
    local command
    command="$(pid_command "$pid")"
    if command_matches_binary "$command" "$argo_bin"; then
      printf '%s\n' "$pid"
      return 0
    fi

    local parent
    parent="$(pid_parent "$pid" || true)"
    [[ -n "$parent" && "$parent" != "$pid" ]] || break
    pid="$parent"
    depth=$((depth + 1))
  done

  return 1
}

trim_lstart() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$1"
}

pid_start_epoch() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_START_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi

  local raw_start
  local start
  raw_start="$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
  start="$(trim_lstart "$raw_start")"
  [[ -n "$start" ]] || return 1
  LC_TIME=C date -j -f "%a %b %e %T %Y" "$start" "+%s"
}

pid_start_label() {
  local pid="$1"
  local fake_var="ARGO_ISLAND_SMOKE_FAKE_PID_LABEL_${pid}"
  if [[ -n "${!fake_var:-}" ]]; then
    printf '%s\n' "${!fake_var}"
    return 0
  fi
  trim_lstart "$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
}

validate_target_pid_fresh() {
  local pid="$1"
  local argo_bin="$2"
  local bin_mtime="$3"

  local start_epoch
  start_epoch="$(pid_start_epoch "$pid" || true)"
  [[ -n "$start_epoch" ]] || return 0

  if (( start_epoch < bin_mtime )); then
    echo "smoke: running Argo pid $pid is older than the Debug binary" >&2
    echo "smoke: pid start: $(pid_start_label "$pid")" >&2
    echo "smoke: binary: $argo_bin" >&2
    echo "smoke: restart the Debug Argo app before running Dynamic Island smoke" >&2
    return 3
  fi

  return 0
}

validate_running_argo_binary() {
  local argo_bin="$1"
  local bin_mtime
  bin_mtime="$(binary_mtime "$argo_bin")"

  local ancestor_pid
  ancestor_pid="$(target_ancestor_pid "$(current_process_id)" "$argo_bin" || true)"
  if [[ -n "$ancestor_pid" ]]; then
    if validate_target_pid_fresh "$ancestor_pid" "$argo_bin" "$bin_mtime"; then
      return 0
    else
      return $?
    fi
  fi

  local stale=0
  local target_found=0
  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue

    local command
    command="$(pid_command "$pid")"
    if ! command_matches_binary "$command" "$argo_bin"; then
      continue
    fi
    target_found=1

    if ! validate_target_pid_fresh "$pid" "$argo_bin" "$bin_mtime"; then
      stale=1
    fi
  done < <(running_argo_pids)

  if [[ "$stale" -eq 1 ]]; then
    return 3
  fi

  if [[ "$target_found" -eq 0 ]]; then
    echo "smoke: no running Debug Argo process matches $argo_bin" >&2
    echo "smoke: launch that Debug app and run this script from one of its panes" >&2
    return 4
  fi
}

run_argo_ping() {
  local argo_bin="$1"
  if [[ -n "${ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT:-}" || -n "${ARGO_ISLAND_SMOKE_FAKE_PING_STATUS:-}" ]]; then
    printf '%s\n' "${ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT:-}"
    return "${ARGO_ISLAND_SMOKE_FAKE_PING_STATUS:-0}"
  fi

  "$argo_bin" ping
}

canonical_file_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  local dir
  local base
  dir="$(cd "$(dirname "$path")" && pwd -P)"
  base="$(basename "$path")"
  printf '%s/%s\n' "$dir" "$base"
}

validate_control_socket_owner() {
  local argo_bin="$1"
  local ping_stderr="$OUT/ping.stderr"
  local actual
  local status

  if actual="$(run_argo_ping "$argo_bin" 2>"$ping_stderr")"; then
    status=0
  else
    status=$?
  fi

  if [[ "$status" -ne 0 || -z "$actual" ]]; then
    echo "smoke: argo ping failed for $argo_bin" >&2
    if [[ -s "$ping_stderr" ]]; then
      sed 's/^/smoke: ping: /' "$ping_stderr" >&2
    fi
    return 5
  fi

  local expected
  expected="$(canonical_file_path "$argo_bin")"
  actual="$(canonical_file_path "$actual")"

  if [[ "$actual" != "$expected" ]]; then
    echo "smoke: control socket is owned by a different Argo app" >&2
    echo "smoke: expected: $expected" >&2
    echo "smoke: actual:   $actual" >&2
    echo "smoke: quit the non-target Argo app or relaunch the Debug app so the socket points at the target binary" >&2
    return 5
  fi
}

run_self_tests() {
  local fixture_bin="$OUT/self-test-Argo"
  : > "$fixture_bin"
  chmod +x "$fixture_bin"

  if [[ "$(trim_lstart "  Mon Jun 22 10:32:59 2026    ")" != "Mon Jun 22 10:32:59 2026" ]]; then
    echo "self-test: expected lstart trim to remove leading and trailing whitespace" >&2
    return 1
  fi

  local smoke_body
  smoke_body="$(sed -n '/^send_smoke_events()/,/^main()/p' "$0")"
  if ! grep -Fq -- '--option "Always allow=always\\n"' <<< "$smoke_body"; then
    echo "self-test: approval smoke must include the Always allow action" >&2
    return 1
  fi

  local stale_log="$OUT/self-test-stale.log"
  set +e
  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=200 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="123" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_123=100 \
    ARGO_ISLAND_SMOKE_FAKE_PID_LABEL_123="Mon Jun 22 10:32:59 2026" \
    ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_123="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
    validate_running_argo_binary "$fixture_bin" >"$stale_log" 2>&1
  local stale_status=$?
  set -e

  if [[ "$stale_status" -ne 3 ]]; then
    echo "self-test: expected stale guard exit 3, got $stale_status" >&2
    cat "$stale_log" >&2
    return 1
  fi

  if ! grep -q "restart the Debug Argo app" "$stale_log"; then
    echo "self-test: stale guard did not print restart guidance" >&2
    cat "$stale_log" >&2
    return 1
  fi

  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=100 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="123" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_123=200 \
    ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_123="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
    validate_running_argo_binary "$fixture_bin" >/dev/null

  local current_process_log="$OUT/self-test-current-process.log"
  set +e
  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=200 \
    ARGO_ISLAND_SMOKE_FAKE_CURRENT_PID=300 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="123 456" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_123=100 \
    ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_123="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_456=300 \
    ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_456="$fixture_bin -NSDocumentRevisionsDebugMode YES" \
    ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_300=200 \
    ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_200=456 \
    ARGO_ISLAND_SMOKE_FAKE_PID_PARENT_456=1 \
    validate_running_argo_binary "$fixture_bin" >"$current_process_log" 2>&1
  local current_process_status=$?
  set -e

  if [[ "$current_process_status" -ne 0 ]]; then
    echo "self-test: expected current fresh Debug ancestor to bypass unrelated stale process, got $current_process_status" >&2
    cat "$current_process_log" >&2
    return 1
  fi

  local wrong_process_log="$OUT/self-test-wrong-process.log"
  set +e
  ARGO_ISLAND_SMOKE_FAKE_BINARY_MTIME=100 \
    ARGO_ISLAND_SMOKE_FAKE_PIDS="456" \
    ARGO_ISLAND_SMOKE_FAKE_PID_START_456=200 \
    ARGO_ISLAND_SMOKE_FAKE_PID_COMMAND_456="/Applications/Argo.app/Contents/MacOS/Argo" \
    validate_running_argo_binary "$fixture_bin" >"$wrong_process_log" 2>&1
  local wrong_process_status=$?
  set -e

  if [[ "$wrong_process_status" -ne 4 ]]; then
    echo "self-test: expected wrong-process guard exit 4, got $wrong_process_status" >&2
    cat "$wrong_process_log" >&2
    return 1
  fi

  if ! grep -q "no running Debug Argo process matches" "$wrong_process_log"; then
    echo "self-test: wrong-process guard did not explain the target mismatch" >&2
    cat "$wrong_process_log" >&2
    return 1
  fi

  ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT="$fixture_bin" \
    validate_control_socket_owner "$fixture_bin" >/dev/null

  local wrong_socket_log="$OUT/self-test-wrong-socket.log"
  set +e
  ARGO_ISLAND_SMOKE_FAKE_PING_OUTPUT="/Applications/Argo.app/Contents/MacOS/Argo" \
    validate_control_socket_owner "$fixture_bin" >"$wrong_socket_log" 2>&1
  local wrong_socket_status=$?
  set -e

  if [[ "$wrong_socket_status" -ne 5 ]]; then
    echo "self-test: expected wrong socket owner exit 5, got $wrong_socket_status" >&2
    cat "$wrong_socket_log" >&2
    return 1
  fi

  if ! grep -q "control socket is owned by a different Argo app" "$wrong_socket_log"; then
    echo "self-test: wrong socket owner guard did not explain the mismatch" >&2
    cat "$wrong_socket_log" >&2
    return 1
  fi

  echo "self-test: OK"
}

send_smoke_events() {
  "$ARGO_BIN" notify \
    --activity \
    --title "Smoke activity" \
    --body "Pane activity route" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-activity" \
    --tool Codex \
    --current-tool exec_command
  sleep 0.8
  screencapture -x "$OUT/activity.png" || true

  "$ARGO_BIN" notify \
    --approval \
    --title "Approve command" \
    --body "Run tests?" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-approval" \
    --source "smoke-approval" \
    --tool Codex \
    --current-tool exec_command \
    --command-preview "xcodebuild test" \
    --affected-path "$PWD" \
    --option "Allow=1\\n" \
    --option "Deny=2\\n" \
    --option "Always allow=always\\n"
  sleep 1.0
  screencapture -x "$OUT/approval-card.png" || true

  "$ARGO_BIN" notify \
    --question \
    --title "Deploy target" \
    --body "Which target?" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-question" \
    --source "smoke-question" \
    --tool Codex \
    --option "Production=Production\\n" \
    --option "Staging=Staging\\n"
  sleep 1.0
  screencapture -x "$OUT/question-card.png" || true

  "$ARGO_BIN" notify \
    --completed \
    --title "Smoke complete" \
    --summary "All clear" \
    --pane "$ARGO_PANE_ID" \
    --session "smoke-complete" \
    --source "smoke-complete" \
    --tool Codex
  sleep 0.8
  screencapture -x "$OUT/completed-card.png" || true

  echo "smoke: screenshots written to $OUT"
  echo "smoke: approval-card.png must show Approve command, xcodebuild test, and $PWD"
  echo "smoke: click Allow in the island and confirm the focused pane receives 1 plus a newline"
  echo "smoke: click Always allow in the island and confirm the focused pane receives always plus a newline"
  echo "smoke: click Staging in the island and confirm the focused pane receives Staging plus a newline"
}

main() {
  if [[ "${ARGO_ISLAND_SMOKE_SELF_TEST:-}" == "1" ]]; then
    run_self_tests
    return
  fi

  if [[ -z "${ARGO_PANE_ID:-}" ]]; then
    echo "smoke: ARGO_PANE_ID is missing; run this script from inside an Argo terminal pane" >&2
    exit 2
  fi

  ARGO_BIN="$(resolve_argo_bin)"
  if [[ -z "${ARGO_BIN:-}" || ! -x "$ARGO_BIN" ]]; then
    echo "smoke: could not find a Debug Argo binary; run xcodebuild build first or pass ARGO_BIN=/path/to/Argo" >&2
    exit 1
  fi

  validate_running_argo_binary "$ARGO_BIN"
  validate_control_socket_owner "$ARGO_BIN"

  echo "smoke: using $ARGO_BIN"
  echo "smoke: pane $ARGO_PANE_ID"

  send_smoke_events
}

main "$@"
