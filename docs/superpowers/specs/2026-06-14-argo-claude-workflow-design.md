# Argo Claude 后台开发工作流 — 设计文档

- 日期: 2026-06-14
- 状态: 已批准设计,待写实现计划
- 范围: 在 Argo 项目内搭建一套基于 Claude Code 的后台自主开发工作流基础设施

## 1. 背景与目标

当前开发 Argo 的效率瓶颈集中在四点(按用户优先级排序):

1. **A — 需求并行**: 希望多个需求同时推进,互不干扰。
2. **B — 测试验证慢**: 每次改完手动跑 `xcodebuild`、手动点 app 验证,反馈循环长。
3. **C — 设计质量**: UI 改动需保证美观且与现有风格一致。
4. **E — 自主优化**: 希望 Claude 能主动发现性能/坏味道/潜在 bug 并修复。

(用户明确跳过了 D「消除固定指令重复」,该项不是主要痛点。)

本设计的目标是:**把这四点固化成一套可复用的 `.claude/` 配置 + 脚本**,形成「派单 → 隔离 → TDD → 自测 → 截图自检 → 写总结 → 停下等验收」的闭环。

## 2. 已确定的关键决策

逐项 brainstorm 后锁定的选型:

| 维度 | 决策 | 说明 |
|------|------|------|
| 并行形态 | **A3 — 后台自主跑** | 丢一批需求,后台逐个/并行处理,完成后回来收结果 |
| 完成状态 | **A3-a — 停在 worktree 等 review** | 每个需求在独立 worktree 完成 + 自测 + 写总结,**不 merge / 不 PR**,等用户验收 |
| 自测档位 | **B3-3,以 B3-1 为主** | 主力:编译 + 单元测试 + 截图视觉自检(确定性、可回归);computer use(B3-2)仅作疑难交互的人工验收兜底,不自动跑 |
| UI 视觉准确性主路线 | **B3-1 — XCUITest/截图断言** | macOS 原生 app 的标准做法,CI 友好、可重复 |
| 视觉一致性约束 | **C1 — 设计规范文档 + frontend-design** | 提炼现有 UI 为 `docs/design-system.md`,UI 改动必读;后续可加 C2 截图视觉回归 |
| 自主优化触发 | **E1 — 按需手动触发** | 用户喊「扫一遍找优化点」→ 列清单 → 用户挑选 → 选中的转入 A3 流程 |
| 实现机制 | **路径 1 — 会话内后台 subagent** | Claude Code 原生 `run_in_background` + `isolation: worktree`,零外部依赖;会话需保持开启(用户长期开着 Argo 终端,此缺点几乎不成立) |
| 截图自检轮数 | **最多 5 轮** | 涉及 UI 时反复抓图自检的上限,避免无限抠细节烧 token |

## 3. 整体架构

```
用户: /argo-batch "需求1" "需求2" "需求3"
        │
        ├─► 后台 subagent A ──► worktree A ──► TDD → build/test → 截图自检 → SUMMARY.md → 停
        ├─► 后台 subagent B ──► worktree B ──► TDD → build/test → 截图自检 → SUMMARY.md → 停
        └─► 后台 subagent C ──► worktree C ──► TDD → build/test → 截图自检 → SUMMARY.md → 停
        │
        ▼
   全部完成 → 通知用户 → /argo-review 逐个看 diff + 截图 + 总结 → merge 或打回
```

闭环三段:**派单(argo-batch)→ 后台跑(argo-feature-runner)→ 验收(argo-review)**。

## 4. 交付产物

| 产物 | 作用 | 对应需求 |
|------|------|---------|
| `.claude/agents/argo-feature-runner.md` | 单需求执行 agent:TDD→自测→截图→总结→停 的完整闭环 | A3-a + B3 |
| `.claude/commands/argo-batch.md` | 批量派单命令:接多个需求,各派一个后台 worktree subagent | A3 |
| `.claude/commands/argo-review.md` | 验收入口:逐个看 SUMMARY + diff + 截图,merge 或打回 | A3-a |
| `.claude/commands/argo-optimize.md` | 手动触发优化扫描:列清单给用户挑,选中的转 argo-batch | E1 |
| `scripts/argo-screenshot.sh` | 启动 Argo + 截指定窗口图(给 B3-1 截图自检用) | B3 |
| `docs/design-system.md` | 从现有 UI 提炼的设计规范,UI 改动必读 | C1 |
| `.claude/settings.json` | 项目级权限白名单,让后台跑少弹权限框 | 支撑 A3 |

## 5. 各产物详细设计

### 5.1 `argo-feature-runner` agent(执行闭环)

每个需求一个实例,在自己的 worktree 内独立跑完下面流水线,严格遵循 Superpowers 纪律:

```
1.  建 worktree         git worktree 隔离,分支名 argo/<slug>
2.  brainstorm(轻量)   需求明确则跳过;模糊则【不瞎猜】,在 SUMMARY 标记「需澄清」并停
3.  写 plan            superpowers:writing-plans,落到 .superpowers/plans/
4.  TDD 实现           superpowers:test-driven-development,红→绿→重构
5.  UI 改动?           是 → 先读 docs/design-system.md,遵守规范
6.  自测 B3-1          xcodebuild build + test,必须全绿
7.  截图自检           涉及 UI → 跑 scripts/argo-screenshot.sh 抓图,自看判断是否符合预期,
                       不对则回 step4 再调,【最多 5 轮】
8.  截图说不清?        复杂交互 → 标记「建议 computer use 人工验收」(B3-2 兜底,不自动跑)
9.  verification       superpowers:verification-before-completion
10. 写总结            <worktree>/SUMMARY.md:做了什么、改了哪些文件、测试结果、截图、待决策点
11. 停                不 merge、不 PR、不 push。等用户 review
```

**护栏(硬约束):**

- **绝不 merge / push / `gh pr create`** — 只停在 worktree。
- **build/test 不绿 ≠ 完成** — 在 SUMMARY.md 如实写失败,严禁谎报(符合用户 CLAUDE.md 诚实要求)。
- **模糊需求不瞎猜** — 后台无法向用户提问,遇到歧义就停下标记「需澄清」。
- 调用任何 subagent 时显式传 `model: opus`(符合用户全局 CLAUDE.md)。
- 全程使用简体中文产出面向用户的内容(SUMMARY、计划等)。

### 5.2 `/argo-batch` 命令(批量派单)

用法: `/argo-batch "需求1" "需求2" "需求3"`

行为:

1. 解析出 N 个需求。
2. 对每个需求,用 Agent 工具派一个 `run_in_background: true` + `isolation: worktree` + `model: opus` 的 `argo-feature-runner`。
3. 并发上限约 10(Claude Code 限制),超出排队。
4. 派完给用户一句回执:「已派 N 个需求到后台,完成后逐个通知,期间可继续用本会话。」
5. 每个 subagent 完成时通知用户;全部完成后汇总一张表(需求 / 状态 / worktree 路径 / 是否需决策)。

### 5.3 `/argo-review` 命令(验收入口)

- 列出所有「已完成等验收」的 worktree。
- 带用户逐个看 `SUMMARY.md` + diff + 截图。
- 用户说「merge」或「打回 + 理由」。
- 打回时:回到该 worktree,读理由,继续改 → 再次自测 → 再停。

### 5.4 `/argo-optimize` 命令(E1 优化扫描)

- 用户手动触发:「扫一遍找优化点」。
- 跑一轮扫描:性能 / 坏味道 / 潜在 bug。
- 列出清单给用户挑选。
- 用户选中的项,转入 `/argo-batch` 走 A3 流程修复。
- **不自动修、不失控** — 扫什么、修什么完全由用户掌控。

### 5.5 `scripts/argo-screenshot.sh`(B3 截图)

职责单一:**启动/聚焦 Argo,截指定窗口图,存到指定路径**。

- 实现:`xcodebuild build` 产物路径 → `open` 启动 → `screencapture -l<windowid>` 按窗口截图(不截全屏),或 AppleScript 聚焦后区域截图。
- 输出:`<worktree>/.screenshots/<step>.png`,供 agent 用 Read 工具看图。
- **前期需实地调一次**(macOS 截窗口有权限/窗口定位的坑),搭好后 agent 直接调用。

### 5.6 `docs/design-system.md`(C1 设计规范)

扫描现有 UI 代码(`Argo/UI/` 下的颜色、字号、间距、圆角、SwiftUI 组件模式),提炼成规范文档。UI 改动的 agent 必读。内容:

- 配色 token
- 字体层级
- 间距 / 圆角约定
- 现有可复用组件清单
- 「该做 / 不该做」示例

### 5.7 `.claude/settings.json`(权限白名单)

后台跑最怕频繁弹权限框打断。

- **放行**(安全高频): `xcodebuild`、`git worktree`、`git diff/status/add/commit`、`screencapture`、读写 worktree 内文件。
- **不放行**(危险): `git push`、`gh pr create`、`rm -rf`、merge —— 必须用户手动确认,与 A3-a「只停在 worktree」一致。

## 6. 非目标(YAGNI)

- 不做 D(固定指令消除)的专门工具。
- 不做路径 2(headless 守护队列)—— 等路径 1 跑顺、确需「关机也跑」时再升级。
- 不做 C2(截图视觉回归基准库)—— C1 起步,后续增强。
- 不做 E2/E3(定时巡检 / 完成后顺带扫)—— E1 起步。
- computer use(B3-2)不自动跑,仅作疑难交互的人工验收兜底标记。

## 7. 后续增强路线(本次不做)

- C2: 关键界面基准截图 + 视觉回归对比。
- E2: cron 定时巡检生成报告。
- 路径 2: headless 守护队列,支持关机续跑。

## 8. 验证方式

- 各命令/agent 文件:语法正确,能被 Claude Code 正确识别和调用。
- `scripts/argo-screenshot.sh`:实地跑通,能正确截到 Argo 窗口图。
- `docs/design-system.md`:内容与现有 UI 代码一致,无臆造 token。
- 端到端:用一个小需求跑通 `argo-batch → feature-runner → argo-review` 全闭环。

## 9. 验证记录(2026-06-14 实施完成)

全部 7 个产物已实现并通过两阶段审查(spec 合规 + 代码质量),共 11 个提交,全部无 Claude 署名。

### 各项验证结果

- **`docs/design-system.md`**:✅ 提炼出真实存在的集中式 token 文件 `Argo/Support/ArgoTheme.swift`(30 个 token),reviewer 逐行核对 RGB/α 值与源码一致,无臆造。修复了 `tertiaryText` 命名歧义等 3 处问题。
- **`scripts/argo-screenshot.sh`**:✅ 实地跑通,成功截到清晰 Argo 窗口图(主会话亲自 Read 确认)。修正了两个真实坑:产物在 DerivedData 第 5 层(骁架误用 maxdepth 4)、System Events 取不到 window id(改用动态取 bounds + `screencapture -R` 区域截 + 全屏兜底)。
- **`.claude/agents/` + `commands/` + `settings.json`**:✅ frontmatter/JSON 合法,内容与规格一致,deny 护栏(push/merge/pr create/rm -rf)就位。
- **端到端闭环**:✅ 派后台 worktree subagent 完成「README 加项目简介」需求 → 写出 SUMMARY.md → 走验收 → 拣选真实改动 merge → 清理 worktree。全程 agent 未 merge/push/PR,护栏生效。

### 实施中发现的关键问题(使用前必读)

1. **新 agent 定义需重启 Claude Code 会话才生效**:`argo-feature-runner` 作为 `subagent_type` 在创建它的同一会话里**无法被识别**(报 `Agent type not found`),但 slash command 当场即可用。**首次使用这套工作流前,请重启一次 Claude Code 会话**让 agent 加载。本次端到端验证用 `general-purpose` 注入相同定义的方式替代验证了闭环逻辑。

2. **worktree 基线差异导致 `git diff main --stat` 有假象**:后台 agent 的 worktree 基于 `main`,而本次开发的 spec/plan/配置在 feature 分支上。验收时 `diff main` 会显示"删除"这些文件,这是基线差异不是 agent 行为。**验收应看 agent 自己那个 commit 的 diff**(`git show <sha>`),而非 `diff main`。`/argo-review` 实际使用时若 main 已包含这套配置则无此问题。

3. **`.claude/` 默认被 .gitignore 忽略**:已改 `.gitignore` 放行 `agents/`、`commands/`、`settings.json`,忽略 `settings.local.json` 等个人文件,新增配置自动入库。

### 已知后续可优化项

- agent 生效需重启会话这一点,可在 README/DEVELOP 里加一句使用说明。
- 截图脚本目前按「front window」截,多窗口场景可能截错窗口,后续可加窗口标题匹配。
