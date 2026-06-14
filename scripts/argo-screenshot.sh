#!/usr/bin/env bash
# argo-screenshot.sh — 构建并启动 Argo,截取主窗口图,保存到指定路径。
# 用法: argo-screenshot.sh <output_png_path> [--no-build]
# 退出码: 0 成功; 非 0 失败(并向 stderr 打印原因)。
# 若截图为空白: 系统设置 → 隐私与安全性 → 屏幕录制 → 勾选运行本脚本的终端/Claude Code,然后重启该终端。
set -euo pipefail

OUT="${1:-}"
NO_BUILD="${2:-}"
if [[ -z "$OUT" ]]; then
  echo "usage: argo-screenshot.sh <output_png_path> [--no-build]" >&2
  exit 2
fi
mkdir -p "$(dirname "$OUT")"

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ_DIR"

# 1. 构建(可跳过)
if [[ "$NO_BUILD" != "--no-build" ]]; then
  echo "[argo-screenshot] building..." >&2
  xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug \
    -destination 'platform=macOS,arch=arm64' build >/tmp/argo-build.log 2>&1 \
    || { echo "[argo-screenshot] build failed, see /tmp/argo-build.log" >&2; exit 1; }
fi

# 2. 定位产物(maxdepth 5 + 排除 Index.noindex 干扰副本 + 取最新修改时间的 Debug 产物)
APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 5 \
  -name 'Argo.app' -path '*/Build/Products/Debug/*' ! -path '*Index.noindex*' 2>/dev/null \
  | xargs -I{} stat -f '%m %N' {} 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
if [[ -z "$APP_PATH" ]]; then
  echo "[argo-screenshot] Argo.app not found in DerivedData" >&2
  exit 1
fi
echo "[argo-screenshot] app: $APP_PATH" >&2

# 3. 启动并等待窗口
open "$APP_PATH"
sleep 3

# 4. 截窗口:激活 Argo → 动态取 front window 的 bounds → screencapture 区域截。
#    若取不到 bounds 则兜底截全屏。
echo "[argo-screenshot] capturing window..." >&2
osascript -e 'tell application "Argo" to activate' 2>/dev/null || true
osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "Argo") to true' 2>/dev/null || true
sleep 2

BOUNDS="$(osascript -e 'tell application "System Events" to get {position, size} of front window of (first process whose name is "Argo")' 2>/dev/null || true)"
# BOUNDS 形如 "36, 34, 1440, 883"(x, y, w, h)

if [[ -n "$BOUNDS" ]]; then
  # 用逗号分割,去空格
  IFS=',' read -r X Y W H <<< "$BOUNDS"
  X="${X//[[:space:]]/}"
  Y="${Y//[[:space:]]/}"
  W="${W//[[:space:]]/}"
  H="${H//[[:space:]]/}"
fi

RC=0
if [[ -n "${X:-}" && -n "${Y:-}" && -n "${W:-}" && -n "${H:-}" ]]; then
  echo "[argo-screenshot] window bounds: x=$X y=$Y w=$W h=$H" >&2
  screencapture -x -o -R"${X},${Y},${W},${H}" "$OUT" || RC=$?
else
  echo "[argo-screenshot] window bounds unavailable, falling back to full screen" >&2
  screencapture -x -o "$OUT" || RC=$?
fi

if [[ "$RC" -eq 0 && -s "$OUT" ]]; then
  echo "[argo-screenshot] saved: $OUT" >&2
  exit 0
else
  echo "[argo-screenshot] screencapture failed (rc=$RC)" >&2
  exit 1
fi
