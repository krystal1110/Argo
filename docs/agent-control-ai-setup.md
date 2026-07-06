# Argo Agent 控制协议 AI 配置指南

这份文档给 AI agent 阅读和执行。目标是让用户用一句话把 Argo 配成 agent host：AI 可以自动检测 Argo、安装 Claude Code hooks，或为其他 agent 加上轻量 wrapper，然后告诉用户如何查看状态、读屏和列出 agents。

## 给 AI 的执行目标

当用户说“帮我配置 Argo agent 控制协议”“让 Claude/Codex 接入 Argo”“让 Argo 能看到 agent 状态”时，按本节执行。

你的任务：

1. 找到可执行的 Argo binary。
2. 确认 Argo GUI 正在运行并能响应 IPC。
3. 如果用户使用 Claude Code，优先调用内置 installer：`argo claude-hooks install`。
4. 如果用户使用其他 agent，不要猜测它的私有 hook 机制；先用通用 shell wrapper 注入 `argo status`，必要时再按该 agent 的官方 hook 文档集成。
5. 配置后运行验证命令，并把常用命令告诉用户。

不要做这些事：

- 不要要求用户提供 `ARGO_CONTROL_TOKEN` 来运行 `status`、`read`、`agents`、`session list`。这些是本机 read-only/self-report 命令，不需要 token。
- 不要把 `open`、`split`、`send-keys` 暴露给远端服务，除非用户明确同意并理解这些 mutating 命令需要 `ARGO_CONTROL_TOKEN`。
- 不要覆盖用户已有 hook 配置。Claude installer 会备份并合并；其他 agent 的配置必须先读取现有文件再最小修改。

## 一键配置流程

### 1. 找到 Argo binary

优先使用用户 PATH 里的 `argo`。如果不存在，使用已安装 app 的主 binary。

```sh
if command -v argo >/dev/null 2>&1; then
  ARGO_BIN="$(command -v argo)"
elif [ -x "/Applications/Argo.app/Contents/MacOS/Argo" ]; then
  ARGO_BIN="/Applications/Argo.app/Contents/MacOS/Argo"
else
  ARGO_BIN="$(mdfind 'kMDItemCFBundleIdentifier == "com.krystal.argo"' | head -n 1)/Contents/MacOS/Argo"
fi

if [ ! -x "$ARGO_BIN" ]; then
  echo "找不到 Argo binary。请先安装并启动 Argo。" >&2
  exit 1
fi

echo "$ARGO_BIN"
```

### 2. 确认 Argo 正在运行

```sh
"$ARGO_BIN" ping
```

成功时会输出拥有 control socket 的 Argo app binary 路径。失败时通常表示 Argo GUI 没有启动；让用户先打开 Argo。

### 3. 为 Claude Code 安装 hooks

如果用户使用 Claude Code，执行：

```sh
"$ARGO_BIN" claude-hooks install
"$ARGO_BIN" claude-hooks status
```

安装器会修改 `~/.claude/settings.json`，写入 Argo 管理的 hooks，并生成 `~/.claude/argo-claude-hooks-install.json`。如果已有 `settings.json`，安装器会在改写前备份。回滚命令：

```sh
"$ARGO_BIN" claude-hooks uninstall
```

### 4. 为其他 agent 加通用 wrapper

如果用户使用 Codex、Aider、Gemini CLI、OpenCode、Cursor Agent、Qwen Code、Goose、Crush、Cline 或 Amp，Argo 可以通过进程探测识别一部分 agent；但为了获得更准确的状态，推荐用 wrapper 明确上报。

把下面脚本保存到用户自选位置，例如 `~/.local/bin/argo-agent-wrap`：

```sh
#!/usr/bin/env bash
set -u

AGENT_NAME="${ARGO_AGENT_NAME:-Agent}"
ARGO_BIN="${ARGO_BIN:-argo}"

"$ARGO_BIN" status running --agent "$AGENT_NAME" --title "Working..." >/dev/null 2>&1 || true

set +e
"$@"
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  "$ARGO_BIN" status done --agent "$AGENT_NAME" --title "Done" >/dev/null 2>&1 || true
else
  "$ARGO_BIN" status error --agent "$AGENT_NAME" --title "Exited with $exit_code" >/dev/null 2>&1 || true
fi

exit "$exit_code"
```

然后：

```sh
chmod +x ~/.local/bin/argo-agent-wrap

# 示例：用 wrapper 启动 Codex，并让 Argo 看到状态
ARGO_AGENT_NAME=Codex argo-agent-wrap codex
```

## HAPI 手机公网访问

如果还需要通过 HAPI 在手机上访问 Argo/agent host，参考：

```text
docs/hapi-mobile-access.md
```

如果目标是通过 Argo + HAPI 在手机上查看本机 HTML 页面，参考教程版：

```text
docs/argo-hapi-local-html-mobile.md
```
