#!/usr/bin/env bash
# argo-screenshot.sh — 构建并启动 Argo,截取主窗口图,保存到指定路径。
# 用法: argo-screenshot.sh <output_png_path> [--no-build]
# 退出码: 0 成功; 非 0 失败(并向 stderr 打印原因)。
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

# 2. 定位产物
APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 4 \
  -name 'Argo.app' -path '*/Build/Products/Debug/*' 2>/dev/null | head -1)"
if [[ -z "$APP_PATH" ]]; then
  echo "[argo-screenshot] Argo.app not found in DerivedData" >&2
  exit 1
fi
echo "[argo-screenshot] app: $APP_PATH" >&2

# 3. 启动并等待窗口
open "$APP_PATH"
sleep 3

# 4. 截窗口(Task 3 实地调通此段)
echo "[argo-screenshot] capturing window..." >&2
# placeholder — Task 3 填入实际窗口定位 + screencapture
exit 0
