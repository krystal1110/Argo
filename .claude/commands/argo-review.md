---
description: 验收后台完成的需求 —— 逐个展示 SUMMARY + diff + 截图,由用户决定 merge 或打回
---

可选参数(指定某个 worktree/分支,留空则列全部):

$ARGUMENTS

## 你的任务

1. 列出所有 Argo 相关 worktree 及其状态:
   ```bash
   git worktree list
   ```
   对每个非主仓 worktree,检查是否存在 `SUMMARY.md`。
2. 对每个「已完成等验收」的 worktree,依次:
   - Read 其 `SUMMARY.md` 并用简体中文转述要点(做了什么、测试结果、待决策点)。
   - 展示 diff 概览:`git -C <worktree> diff main --stat`,必要时展开关键文件 diff。
   - 若有 `.screenshots/*.png`,用 Read 打开给用户看。
   - 问用户:**merge / 打回(给理由)/ 跳过**。
3. 根据用户决定执行:
   - **merge**: 切回主仓,`git merge <分支>`(快进或常规),成功后可选 `git worktree remove <worktree>`。**merge 与删除前向用户确认**。
   - **打回**: 把用户理由作为新 prompt,派一个 `argo-feature-runner`(`model: opus`)回到该 worktree 继续改 → 再自测 → 再停。
   - **跳过**: 保留现状,继续下一个。
4. 全部过完后给一句总结(几个 merge、几个打回、几个待定)。

## 注意
- merge / `git worktree remove` 是不可逆操作,执行前必须向用户确认。
- 不主动 push 到远端,除非用户明确要求。
