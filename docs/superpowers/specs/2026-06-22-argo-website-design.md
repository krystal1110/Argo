# Argo 官网设计方案

## 背景

Argo 需要一个官网首页,参考 Prowl 的强首屏节奏,但不能做成 Prowl 的换皮。目标是让访问者在第一屏理解 Argo 是一个原生 macOS terminal workspace,用于管理 repositories、worktrees、split panes、SSH sessions、local previews 和 coding agents。

当前仓库没有可提交的 `website/` 源码目录,`.gitignore` 也忽略了 `website/`。本方案定义官网设计与第一版实现边界:使用无构建静态站点作为默认实现,后续实现计划只需要展开文件级任务、验证命令和部署衔接。

## 已确认方向

用户已确认以浏览器 mockup `Aurora Terminal v4` 为设计基线:

- 借鉴 Prowl 的信息节奏:轻导航、强品牌首屏、产品窗口、下载按钮、Homebrew 命令、功能入口。
- 使用 Argo 自己的视觉语言:深蓝黑底、冷青绿强调、终端/工作区截图、app icon、轻微轨道线。
- 字体比例接近 Prowl:品牌标题约 `72px / 700`,tagline 约 `24px / 500`,正文约 `16.8px`,按钮约 `14.4px`。
- 配色采用 `Aurora Terminal`:主背景 `#070d16`,中层背景 `#0a1624`,深青背景 `#061215`,主强调 `#5fd7ca`,按钮高光 `#74e4d8` 到 `#52cfc1`。
- 当前 hero 截图只是临时资产。正式实现必须把截图作为可替换资产槽位处理,后续换新截图时不需要重写页面结构。

## 首屏设计

首屏是官网的核心。第一视口必须同时传达品牌、产品定位、下载入口和真实产品感。

导航:

```text
Argo        Home    Features    Download    GitHub
```

首屏文案:

```text
Argo

Command every repo.
Keep every agent in view.

A native macOS terminal workspace for repositories, worktrees,
split panes, previews, SSH sessions, and coding agents.
```

CTA:

```text
Download
GitHub

brew install --cask krystal1110/tap/argo
```

开源说明:

```text
Free & Open Source. Built for fast local work across many repositories.
```

右侧视觉:

- macOS app window 样式包住 hero screenshot。
- app icon 轻微浮在 screenshot 右下侧。
- 一张轻量 status card 覆盖在 screenshot 左下附近,表达 agent/worktree 状态。
- status card 文案使用真实产品语义,例如:

```text
liney / main
✓ 23 tests passed · agent complete
pane layout restored
```

## 首页信息架构

首页采用单页产品站,先不做完整文档站。首屏下方保留一排 feature chips,后续滚动区域展开 5 个核心模块。

模块顺序:

1. `Workspaces`
   - 多仓库 sidebar。
   - worktree-aware navigation。
   - 重点表达“每个 repo 都有自己的位置”。

2. `Panes`
   - Ghostty-powered terminal panes。
   - split layouts。
   - per-worktree restoration。

3. `Agents`
   - local shell、SSH、agent-backed sessions。
   - agent run 可见、可回到对应 pane。
   - pane-aware notification 与 `argo notify` 可作为细节出现。

4. `Workbench`
   - right-hand file tree。
   - Markdown/HTML preview。
   - localhost web pages。
   - 重点表达“终端旁边就能看代码、预览和本地网页”。

5. `Native`
   - AppKit + SwiftUI。
   - vendored Ghostty runtime。
   - macOS 14.6+。
   - Apple Silicon 和 Intel 支持。

页尾重复下载 CTA 和 GitHub 入口。

## 视觉系统

### 配色

主配色必须避免整页只有单一蓝紫或完全复制 Prowl 的青绿。允许冷青绿作为主强调,但整体读感应是 Argo 的深色 macOS 工具。

建议 token:

| 用途 | 颜色 |
| --- | --- |
| 页面底色 | `#070d16` |
| 深层背景 | `#061215` |
| 中层背景 | `#0a1624` |
| 主文字 | `#f5f9ff` |
| 次级文字 | `rgba(214, 229, 252, 0.65)` |
| 弱文字 | `rgba(205, 220, 246, 0.44)` |
| 主强调 | `#5fd7ca` |
| 主按钮顶部 | `#74e4d8` |
| 主按钮底部 | `#52cfc1` |
| 边框 | `rgba(238, 251, 255, 0.08)` |

背景可以使用很轻的 radial glow 和一条轨道线,但不能使用离散装饰 blob 或大面积渐变球。轨道线应服务于 Argo icon 的“轨道/终端”联想。

### 字体与密度

- 不引入外部字体,使用 system stack。
- 不使用 viewport width 缩放字体。
- 首屏 `h1` 约 `72px`,移动端保持可读而不是无限缩小。
- tagline 约 `24px`,两行以内。
- 正文约 `16.8px`,line-height 约 `28.56px`。
- 导航约 `14px`,按钮约 `14.4px`。
- letter spacing 保持 `0`。

### 圆角与卡片

- 按钮和产品窗口圆角保持 `7-8px`。
- 不把页面 section 做成嵌套卡片。
- 卡片只用于 feature chips、status card 或重复项。
- 产品截图窗口可以使用轻边框和阴影,但不能像装饰框一样压过内容。

## 资产策略

必须把当前截图当成临时资产:

- 首屏 hero screenshot 使用可替换文件,例如 `website/public/assets/hero-workspace.png`。
- 实现时不要在 CSS 中依赖某张截图的具体内容位置来决定布局。
- screenshot 容器使用稳定比例,建议 `16 / 9.6` 或接近当前 mockup 的窗口比例。
- 当新 app UI 截图准备好时,只替换图片文件即可。
- app icon 可从 `Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512.png` 复制到网站静态资源中。

后续如果有更准确的新截图,应优先使用真实产品截图,而不是重新绘制复杂假 UI。需要强调功能状态时,可以叠加轻量 status card。

## 内容语气

文案要短、具体、工程化。不要使用夸张营销语,也不要解释“这个网站怎么用”。可使用类似 Prowl 的短句节奏,但不要借用 Prowl 的动物意象。

推荐语气:

- `Command every repo.`
- `Keep every agent in view.`
- `Every worktree gets its own place.`
- `Split panes come back where you left them.`
- `Preview files and localhost pages beside your terminal.`

避免:

- 大段抽象愿景。
- 动物、爪印、狩猎类隐喻。
- 过度解释快捷键或实现细节。

## 技术边界

实现应优先简单、可维护。第一版默认使用无构建静态站点:

- 创建 `website/` 源码目录并让它入库。
- 使用 `website/index.html` 承载单页结构。
- 使用 `website/styles.css` 承载视觉系统和响应式布局。
- 使用 `website/assets/` 存放 app icon、hero screenshot 和后续替换截图。
- 不引入 npm 依赖、不添加 package manager lockfile,除非实现阶段发现部署环境强制需要。
- 不需要 CMS、搜索、复杂 docs routing 或动画系统。
- 不需要视频 demo。
- 需要支持本地静态预览,例如从 `website/` 目录运行 `python3 -m http.server 4173`。
- `website/` 当前被 `.gitignore` 忽略,实现计划需要明确如何让官网源码入库。
- 不影响 macOS app 的 Xcode build。

## 响应式要求

Desktop:

- 首屏为左右两栏。
- 左侧文案固定在约 `360-380px` 宽度。
- 右侧产品窗口更早进入第一视口。
- feature chips 在首屏底部或首屏之后露出。

Mobile / narrow browser:

- 导航保持简洁,避免文字溢出。
- 文案在上,截图在下。
- screenshot 必须在首屏附近可见。
- floating icon 和 status card 不能遮挡关键截图内容。
- 文本不得溢出按钮、卡片或页面边界。

## 验证标准

设计和实现完成后至少验证:

- 首页能在本地浏览器打开。
- desktop 视口下首屏包含品牌、tagline、下载按钮、Homebrew 命令、产品截图。
- narrow browser 下文本不重叠、不溢出,截图能在首屏附近出现。
- hero screenshot 可通过替换单一图片文件更新。
- GitHub 和 Download CTA 指向正确位置。
- Homebrew 命令与 release/homebrew 配置一致。
- `website/` 源码入库策略明确,不会被 `.gitignore` 吞掉。

## 非目标

第一版不做:

- 完整文档站。
- 多页面 feature deep dive。
- 用户登录、analytics、newsletter。
- 复杂动画或 WebGL。
- 人工重绘完整 app UI 来代替真实截图。

## 实现计划关注点

正式实现计划需要展开:

- 调整 `.gitignore` 中的 `website/`,让源码和必要静态资源可提交。
- 创建 `website/index.html`、`website/styles.css` 和 `website/assets/`。
- 静态资源目录和 screenshot 替换流程。
- 是否需要在 README 或 docs 中更新官网源码说明。
- 是否需要 GitHub Pages 或其他部署脚本。
