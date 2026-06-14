---
description: 批量派单 —— 把多个需求各派一个后台 worktree subagent 自主执行,完成后停在 worktree 等验收
---

用户输入(多个需求,可能用引号分隔或换行分隔):

$ARGUMENTS

## 你的任务

1. 把上面的输入解析成 N 个独立需求(按引号、换行或明显分隔切分)。若只解析出 0 个,提示用户用法:`/argo-batch "需求1" "需求2"` 并停止。
2. 对【每一个】需求,用 Agent 工具派一个 subagent,参数:
   - `subagent_type: "argo-feature-runner"`
   - `model: "opus"`(必须,遵守全局 CLAUDE.md)
   - `isolation: "worktree"`
   - `run_in_background: true`
   - `description`: 需求的 3-5 字短描述
   - `prompt`: 完整需求原文 + 「按你的流水线执行,完成后写 SUMMARY.md 并停下,绝不 merge/push/开 PR」
   **在同一条消息里发出所有 Agent 调用**,使其并行。
3. 派完后给用户一句回执(简体中文):「已派 N 个需求到后台,完成后逐个通知。期间可继续使用本会话。用 `/argo-review` 验收。」
4. 收到各 subagent 完成通知后,汇总一张表:需求 | 状态(✅/⚠️/❌) | worktree 路径 | 是否需决策。

## 注意
- Claude Code 后台并发上限约 10,超出会自动排队,无需特殊处理。
- 不要替 subagent 做 merge/PR 决策。
