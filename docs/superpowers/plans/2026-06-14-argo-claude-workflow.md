# Argo Claude 后台开发工作流 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Argo 项目内搭建一套基于 Claude Code 的后台自主开发工作流(派单 → worktree 隔离 → TDD → 自测 → 截图自检 → 写总结 → 停下等验收)。

**Architecture:** 通过项目级 `.claude/`(agent + 3 个 slash command + settings)、一个截图脚本和一份设计规范文档组合实现。核心是 `argo-feature-runner` agent 在独立 worktree 内跑完整闭环,`/argo-batch` 派单、`/argo-review` 验收、`/argo-optimize` 扫描优化点。

**Tech Stack:** Claude Code(agents / slash commands / settings.json)、Bash、`xcodebuild`、`git worktree`、`screencapture` / AppleScript、Markdown。

**对应 spec:** `docs/superpowers/specs/2026-06-14-argo-claude-workflow-design.md`

---

## 关键事实(探查所得,实现时直接用)

- App bundle id: `com.krystal.argo`;构建产物名取自 scheme `Argo`,Debug 产物路径形如
  `~/Library/Developer/Xcode/DerivedData/Argo-*/Build/Products/Debug/Argo.app`。
- 构建命令(来自 CLAUDE.md):
  `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- 测试命令:
  `xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test`
- 全局 `~/.claude/settings.json` 已有 `Bash(*)` 全放行 + `skipDangerousModePermissionPrompt: true`。
  → 项目级 settings 的"减少弹框"作用有限,但仍作为**项目自文档化护栏**:用 `deny` 明确禁止
  危险操作(push / pr create / merge / rm -rf),即使全局放行,项目级 deny 也会生效拦截。
- UI 源码集中在 `Argo/UI/` 下,样式以内联 SwiftUI 修饰符为主(无集中式 design token 文件)。
- 现有 git worktree 仅主仓 `/Users/liaojingyu/argo`。

## 文件结构

| 文件 | 职责 | 任务 |
|------|------|------|
| `.claude/agents/argo-feature-runner.md` | 单需求执行闭环 agent | Task 4 |
| `.claude/commands/argo-batch.md` | 批量派单命令 | Task 5 |
| `.claude/commands/argo-review.md` | 验收命令 | Task 6 |
| `.claude/commands/argo-optimize.md` | 优化扫描命令 | Task 7 |
| `scripts/argo-screenshot.sh` | 启动 Argo + 截窗口图 | Task 2、3 |
| `docs/design-system.md` | 现有 UI 设计规范 | Task 1 |
| `.claude/settings.json` | 项目级权限护栏 | Task 8 |
| `.gitignore`(修改) | 忽略 `.screenshots/` | Task 3 |

## 任务顺序与依赖

```
Task 1 (design-system.md)   ─┐
Task 2 (截图脚本骨架)        ─┤
Task 3 (截图脚本实地调通)    ─┘  ← 这三个是 agent 的依赖,先做
Task 4 (feature-runner agent) ← 依赖 1、3
Task 5 (argo-batch)           ← 依赖 4
Task 6 (argo-review)
Task 7 (argo-optimize)        ← 复用 5
Task 8 (settings.json 护栏)
Task 9 (端到端冒烟验证)       ← 依赖全部
```

---

### Task 1: 提炼现有 UI 设计规范 → `docs/design-system.md`

**Files:**
- Create: `docs/design-system.md`
- 参考(只读): `Argo/UI/**/*.swift`、`Argo/Support/**/*.swift`

- [ ] **Step 1: 采集现有颜色 token**

Run:
```bash
grep -rhoE "Color(\.[a-zA-Z]+|\(red:[^)]*\)|\(\"[^\"]+\"\))" Argo/UI Argo/Support 2>/dev/null | sort | uniq -c | sort -rn | head -40
```
把出现的系统色(`.primary`/`.secondary`/`.accentColor` 等)、自定义 RGB、Asset 颜色名记录下来。

- [ ] **Step 2: 采集字体层级**

Run:
```bash
grep -rhoE "\.font\([^)]*\)|Font\.[a-zA-Z]+" Argo/UI Argo/Support 2>/dev/null | sort | uniq -c | sort -rn | head -40
```
归纳标题/正文/说明文字各用什么字号字重。

- [ ] **Step 3: 采集间距与圆角**

Run:
```bash
grep -rhoE "\.padding\([^)]*\)|cornerRadius\([^)]*\)|spacing:[^,)]*" Argo/UI 2>/dev/null | sort | uniq -c | sort -rn | head -40
```
归纳常用间距档位(如 4/8/12/16)和圆角档位。

- [ ] **Step 4: 采集可复用组件清单**

Run:
```bash
ls Argo/UI/Components/ && grep -rl "struct .*View" Argo/UI/Components 2>/dev/null
```
列出 `GlassChromeControls`、`CommandPaletteView`、`ToolbarFeatureIcon` 等可复用件及其用途(看文件头注释/struct 名)。

- [ ] **Step 5: 写 `docs/design-system.md`**

按以下骨架填入 Step 1-4 的**真实采集结果**(禁止臆造未在代码出现的 token):
```markdown
# Argo 设计规范

> 本文档由现有 UI 代码提炼,UI 改动前必读。改动须遵守此处约定,不得引入未列出的新 token,除非有充分理由并在 SUMMARY 中说明。

## 配色
（Step 1 结果:系统色用法 + 自定义色 + Asset 色名,各注明使用场景）

## 字体层级
（Step 2 结果:标题/正文/说明 各自字号字重)

## 间距与圆角
（Step 3 结果:间距档位、圆角档位）

## 可复用组件
（Step 4 结果:组件名 + 用途 + 所在文件)

## 该做 / 不该做
- ✅ 复用上述组件与 token;新 UI 跟随现有 AppKit 容器 + SwiftUI 内容架构
- ✅ 间距/圆角从已有档位取值
- ❌ 不引入与现有风格冲突的新配色
- ❌ 不为小改动重写大段 UI(遵守 CLAUDE.md 修改约定)
```

- [ ] **Step 6: 自检文档与代码一致**

Run:
```bash
test -f docs/design-system.md && echo "exists" && grep -c "#" docs/design-system.md
```
人工复核:文档里每个 token 都能在代码里找到出处,无臆造。

- [ ] **Step 7: Commit**

```bash
git add docs/design-system.md
git commit -m "docs: add design system reference"
```

---

### Task 2: 截图脚本骨架 `scripts/argo-screenshot.sh`

**Files:**
- Create: `scripts/argo-screenshot.sh`

- [ ] **Step 1: 写脚本骨架(参数解析 + 用法)**

Create `scripts/argo-screenshot.sh`:
```bash
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
```

- [ ] **Step 2: 赋可执行权限并验证语法**

Run:
```bash
chmod +x scripts/argo-screenshot.sh && bash -n scripts/argo-screenshot.sh && echo "syntax ok"
```
Expected: `syntax ok`

- [ ] **Step 3: 验证参数校验**

Run:
```bash
scripts/argo-screenshot.sh 2>&1; echo "exit=$?"
```
Expected: 打印 usage,`exit=2`

- [ ] **Step 4: Commit**

```bash
git add scripts/argo-screenshot.sh
git commit -m "feat: add argo screenshot script skeleton"
```

---

### Task 3: 截图脚本实地调通(窗口定位 + 截图)

**Files:**
- Modify: `scripts/argo-screenshot.sh`(Step 4 的 placeholder 段)
- Modify: `.gitignore`

> **注意**: 此任务需要实地运行,可能触发「屏幕录制」权限请求(系统设置 → 隐私与安全性 → 屏幕录制,授权给终端/Claude Code)。这是整个搭建里最不确定的一步。

- [ ] **Step 1: 探测 Argo 窗口 id**

Run(Argo 已在运行时):
```bash
osascript -e 'tell application "System Events" to get id of every window of (first process whose name is "Argo")' 2>&1
```
若返回窗口 id 列表 → 用 `screencapture -l<id>` 按窗口截。
若 AppleScript 取不到 id(常见)→ 改用方案 B(下一步)。

- [ ] **Step 2: 选定截图实现并替换 placeholder**

把 Task 2 脚本里 `# placeholder` 那段替换为以下二选一(实地测哪个能截到):

**方案 A — 按窗口 id 截(优先):**
```bash
WIN_ID="$(osascript -e 'tell application "System Events" to get id of front window of (first process whose name is "Argo")' 2>/dev/null || true)"
if [[ -n "$WIN_ID" ]]; then
  screencapture -x -o -l"$WIN_ID" "$OUT"
else
  # 回退到方案 B
  osascript -e 'tell application "Argo" to activate' 2>/dev/null || true
  sleep 1
  screencapture -x -o -R0,0,1600,1000 "$OUT"
fi
```

**方案 B — 激活后全屏/区域截(兜底):**
```bash
osascript -e 'tell application "Argo" to activate' 2>/dev/null || true
sleep 1
screencapture -x -o "$OUT"
```

- [ ] **Step 3: 实地运行,确认截到图**

Run:
```bash
scripts/argo-screenshot.sh /tmp/argo-shot-test.png && \
  file /tmp/argo-shot-test.png && \
  ls -la /tmp/argo-shot-test.png
```
Expected: 文件存在、类型为 PNG、大小 > 0。用 Read 工具打开 `/tmp/argo-shot-test.png` 肉眼确认是 Argo 界面(而非空白/桌面)。

- [ ] **Step 4: 若权限被拒,记录排查指引**

若 `screencapture` 产出空白图,在脚本顶部注释加一行排查提示:
```bash
# 若截图为空白: 系统设置 → 隐私与安全性 → 屏幕录制 → 勾选运行本脚本的终端/Claude Code,然后重启该终端。
```

- [ ] **Step 5: gitignore 忽略截图产物**

Run:
```bash
grep -q '.screenshots/' .gitignore 2>/dev/null || printf '\n# Argo screenshot self-check artifacts\n.screenshots/\n' >> .gitignore
echo "--- .gitignore tail ---"; tail -3 .gitignore
```

- [ ] **Step 6: Commit**

```bash
git add scripts/argo-screenshot.sh .gitignore
git commit -m "feat: make argo screenshot script capture window"
```

---

### Task 4: `argo-feature-runner` agent

**Files:**
- Create: `.claude/agents/argo-feature-runner.md`

- [ ] **Step 1: 写 agent 定义**

Create `.claude/agents/argo-feature-runner.md`:
```markdown
---
name: argo-feature-runner
description: 在独立 git worktree 内自主完成单个 Argo 需求 —— TDD 实现、自测、截图自检,完成后写 SUMMARY.md 并停下等用户验收,绝不 merge/push/开 PR。
---

你是 Argo 项目的后台需求执行 agent。你会被派去在【独立 worktree】里完成【一个】需求,全程无法向用户提问。严格按下面流水线执行,遵守 Superpowers 纪律。

## 输入
你会收到一个需求描述(自然语言)。

## 流水线(严格按序)

1. **建 worktree**: 用 superpowers:using-git-worktrees(或本 agent 已被 isolation:worktree 放入隔离工作区,则直接用当前目录)。分支名 `argo/<从需求生成的 slug>`。
2. **判断清晰度**: 需求明确 → 继续;**模糊/有歧义 → 不要瞎猜**,直接跳到 step 9 写 SUMMARY 标记「⚠️ 需澄清」并停。
3. **写 plan**: 用 superpowers:writing-plans,落到 `docs/superpowers/plans/`。
4. **TDD 实现**: 用 superpowers:test-driven-development,红→绿→重构,频繁提交。
5. **若涉及 UI 改动**: 实现前先 Read `docs/design-system.md`,严格遵守其 token 与组件约定。
6. **自测(B3-1)**: 运行
   `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build`
   和
   `xcodebuild -project Argo.xcodeproj -scheme Argo -destination 'platform=macOS,arch=arm64' test`
   两者**必须全绿**才算通过。不绿 → 继续修,直到绿或确认无法解决(后者如实写进 SUMMARY)。
7. **截图自检(仅 UI 改动)**: 运行 `scripts/argo-screenshot.sh "$PWD/.screenshots/check-N.png"`,用 Read 看图,
   判断视觉是否符合需求与 design-system。不符合 → 回 step 4 调整。**最多 5 轮**,超出则在 SUMMARY 记录「截图自检达上限,建议人工复核」。
8. **截图说不清的复杂交互**(拖拽/多窗口/动画): 标记「建议 computer use 人工验收」,不自动跑 computer use。
9. **verification**: 用 superpowers:verification-before-completion,确认所有声明都有证据。
10. **写 SUMMARY**: 在 worktree 根写 `SUMMARY.md`(简体中文),含:
    - 需求原文
    - 做了什么(要点)
    - 改动文件清单
    - 测试结果(贴 build/test 关键输出,**如实**,失败就写失败)
    - 截图路径(若有)
    - 待用户决策点 / 风险 / 是否需澄清
11. **停**: **绝不** `git merge` / `git push` / `gh pr create`。停在 worktree 等用户 review。

## 硬约束(护栏)
- 绝不 merge / push / 开 PR / 删主仓文件。
- build/test 不绿 ≠ 完成;严禁谎报测试结果(诚实优先)。
- 模糊需求不瞎猜,停下标记需澄清。
- 调用任何子 agent 时显式传 `model: opus`。
- 所有面向用户的产出(SUMMARY、plan)用简体中文。
- 遵守项目 CLAUDE.md 与 Superpowers 要求。

## 最终输出
你的最后一条消息要简短汇报:需求 slug、worktree 路径、状态(✅完成等验收 / ⚠️需澄清 / ❌测试未通过)、一句话结论。
```

- [ ] **Step 2: 验证 frontmatter 可被识别**

Run:
```bash
head -5 .claude/agents/argo-feature-runner.md && echo "---check---" && grep -c "^name:\|^description:" .claude/agents/argo-feature-runner.md
```
Expected: 能看到 `name:` 和 `description:` 两行(grep 计数为 2)。

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/argo-feature-runner.md
git commit -m "feat: add argo-feature-runner agent"
```

---

### Task 5: `/argo-batch` 派单命令

**Files:**
- Create: `.claude/commands/argo-batch.md`

- [ ] **Step 1: 写命令定义**

Create `.claude/commands/argo-batch.md`:
```markdown
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
```

- [ ] **Step 2: 验证命令文件结构**

Run:
```bash
test -f .claude/commands/argo-batch.md && grep -c "argo-feature-runner\|run_in_background\|isolation" .claude/commands/argo-batch.md
```
Expected: 文件存在,关键字计数 ≥ 3。

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/argo-batch.md
git commit -m "feat: add /argo-batch command"
```

---

### Task 6: `/argo-review` 验收命令

**Files:**
- Create: `.claude/commands/argo-review.md`

- [ ] **Step 1: 写命令定义**

Create `.claude/commands/argo-review.md`:
```markdown
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
```

- [ ] **Step 2: 验证**

Run:
```bash
test -f .claude/commands/argo-review.md && grep -c "worktree\|SUMMARY\|merge" .claude/commands/argo-review.md
```
Expected: 文件存在,关键字计数 ≥ 3。

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/argo-review.md
git commit -m "feat: add /argo-review command"
```

---

### Task 7: `/argo-optimize` 优化扫描命令

**Files:**
- Create: `.claude/commands/argo-optimize.md`

- [ ] **Step 1: 写命令定义**

Create `.claude/commands/argo-optimize.md`:
```markdown
---
description: 手动触发优化扫描 —— 扫性能/坏味道/潜在 bug,列清单给用户挑,选中项转 /argo-batch 修复
---

可选扫描范围(留空则扫近期改动 + 核心热点文件):

$ARGUMENTS

## 你的任务

1. 确定扫描范围:
   - 有参数 → 按参数(目录/文件/主题)。
   - 无参数 → 扫近期改动(`git log --oneline -20` 涉及的文件)+ CLAUDE.md 列出的 Code Hotspots。
2. 用 superpowers:systematic-debugging 的视角扫描,分三类列出发现:
   - **性能**(主线程阻塞、重复计算、大列表无复用等)
   - **坏味道**(超大文件/函数、重复代码、边界不清)
   - **潜在 bug**(空值、并发、状态不一致、未处理错误)
3. 输出一张编号清单(简体中文),每项含:类型 | 文件:行 | 问题 | 建议修法 | 预估风险。
4. 让用户挑选要修的编号(可多选 / 全选 / 全不选)。
5. 把用户选中的项,**逐条转成需求文本**,调用 `/argo-batch` 派单修复(走 A3 流程,停在 worktree 等验收)。

## 注意
- **只扫不自动修**;修什么完全由用户挑。
- 不夸大问题;不确定的标「待确认」,不计入强烈建议。
- 扫描是只读操作,不改任何代码。
```

- [ ] **Step 2: 验证**

Run:
```bash
test -f .claude/commands/argo-optimize.md && grep -c "argo-batch\|性能\|坏味道\|潜在 bug" .claude/commands/argo-optimize.md
```
Expected: 文件存在,关键字计数 ≥ 3。

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/argo-optimize.md
git commit -m "feat: add /argo-optimize command"
```

---

### Task 8: 项目级权限护栏 `.claude/settings.json`

**Files:**
- Create: `.claude/settings.json`

> 全局已 `Bash(*)` 放行,本文件价值在 `deny`:项目级 deny 优先于全局 allow,确保后台 agent 不会误 push/merge/开 PR。

- [ ] **Step 1: 写 settings**

Create `.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(xcodebuild:*)",
      "Bash(git worktree:*)",
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git log:*)",
      "Bash(screencapture:*)",
      "Bash(scripts/argo-screenshot.sh:*)"
    ],
    "deny": [
      "Bash(git push:*)",
      "Bash(gh pr create:*)",
      "Bash(git merge:*)",
      "Bash(rm -rf:*)"
    ]
  }
}
```

- [ ] **Step 2: 验证 JSON 合法**

Run:
```bash
python3 -c "import json;json.load(open('.claude/settings.json'));print('valid json')"
```
Expected: `valid json`

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "chore: add project claude permission guardrails"
```

---

### Task 9: 端到端冒烟验证

**Files:** 无新增(验证既有产物)

> 用一个真实小需求或 demo 需求跑通完整闭环。本任务**不提交代码**,只验证流程并记录结果。

- [ ] **Step 1: 确认所有产物就位**

Run:
```bash
ls -la .claude/agents/argo-feature-runner.md \
       .claude/commands/argo-batch.md \
       .claude/commands/argo-review.md \
       .claude/commands/argo-optimize.md \
       .claude/settings.json \
       scripts/argo-screenshot.sh \
       docs/design-system.md
```
Expected: 7 个文件全部存在。

- [ ] **Step 2: 派一个 demo 小需求**

在主会话执行 `/argo-batch "在 README 顶部加一行项目一句话简介(纯文档改动,便于验证闭环)"`。
观察:是否正确派出 1 个后台 `argo-feature-runner`(opus + worktree + background)。

- [ ] **Step 3: 等待完成并验收**

收到完成通知后执行 `/argo-review`。
观察:能否列出该 worktree、展示 SUMMARY 与 diff、给出 merge/打回选项。

- [ ] **Step 4: 走一次 merge**

选择 merge,确认:能合并、worktree 可清理、主仓得到改动。

- [ ] **Step 5: 记录冒烟结果**

把端到端结果(各环节是否通过、截图自检是否触发、有无卡点)追加到
`docs/superpowers/specs/2026-06-14-argo-claude-workflow-design.md` 末尾的「验证记录」小节,并 commit。

---

## Self-Review

**Spec 覆盖检查:**
- A3(后台派单)→ Task 4 + 5 ✅
- A3-a(停 worktree 等 review)→ Task 4 step 11 + Task 6 ✅
- B3-1(build/test 自测)→ Task 4 step 6 ✅
- B3 截图自检(5 轮)→ Task 2/3 + Task 4 step 7 ✅
- B3-2 兜底标记 → Task 4 step 8 ✅
- C1(design-system)→ Task 1 + Task 4 step 5 ✅
- E1(优化扫描)→ Task 7 ✅
- 权限护栏 → Task 8 ✅
- 端到端验证 → Task 9 ✅

**占位符扫描:** Task 2/3 的脚本 placeholder 是有意的两阶段实现(骨架→实地调通),非计划缺陷,已在 Task 3 给出完整替换代码。其余无 TBD。

**类型/命名一致性:** agent 名 `argo-feature-runner` 在 Task 4 定义、Task 5/6 引用一致;截图脚本路径 `scripts/argo-screenshot.sh` 全篇一致;`SUMMARY.md`、`.screenshots/` 命名一致。

无遗留问题。
