#!/bin/bash
# 严格校验 Argo 开发环境：必须安装 superpowers 插件 + codegraph，否则阻止开发操作。
# 用于 Claude Code hooks（SessionStart 提示 / PreToolUse 阻断）。
# 退出码 2 = 校验失败（PreToolUse 会阻止本次工具调用，stderr 反馈给模型）。
set -u

CLAUDE_SETTINGS="${ARGO_CHECK_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

errors=()

# 1. codegraph CLI 必须已安装
if ! command -v codegraph >/dev/null 2>&1; then
  errors+=("缺少 codegraph CLI。安装：npm install -g @colbymchenry/codegraph")
fi

# 2. 仓库必须已建立 CodeGraph 索引
if [ ! -d "$REPO_ROOT/.codegraph" ]; then
  errors+=("仓库缺少 CodeGraph 索引（.codegraph/ 不存在）。在仓库根目录运行：codegraph init")
fi

# 3. superpowers 插件必须已启用（enabledPlugins 中存在 superpowers@* 且未被禁用）
if ! jq -e '
    .enabledPlugins
    | to_entries[]
    | select(.key | startswith("superpowers@"))
    | select(.value == true or (.value | type == "array"))
  ' "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
  errors+=("未启用 superpowers 插件。安装：claude plugin install superpowers@claude-plugins-official（或在 Claude Code 中执行 /plugin）")
fi

if [ ${#errors[@]} -gt 0 ]; then
  {
    echo "🚫 Argo 开发环境校验失败，已阻止本次操作。开发 Argo 必须先满足以下要求："
    for e in "${errors[@]}"; do
      echo "  - $e"
    done
    echo "全部满足后重试即可。"
  } >&2
  exit 2
fi

exit 0
