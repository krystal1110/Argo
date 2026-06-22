# Argo 官网实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 Argo 第一版官网:一个已入库、无构建步骤的静态 landing page,视觉匹配已确认的 Aurora Terminal v4 设计。

**Architecture:** 官网源码位于 `website/`,只包含 HTML、CSS 和静态资源,不影响 Xcode app build。`website/index.html` 负责语义结构、文案、链接和资产引用;`website/styles.css` 负责 Aurora Terminal 视觉系统与响应式布局;`website/assets/` 存放可替换图片资产。`scripts/check_website_*.sh` 提供可重复的静态校验,浏览器预览负责最终视觉检查。

**Tech Stack:** Static HTML5、CSS3、shell verification scripts、`python3 -m http.server` 本地预览、浏览器视觉 smoke check。

## Global Constraints

- 始终使用简体中文回复；方案文档必须使用简体中文。
- 第一版官网使用无构建静态站点。
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
- 当前 hero 截图只是临时资产。正式实现必须把截图作为可替换资产槽位处理,后续换新截图时不需要重写页面结构。
- 不使用 viewport width 缩放字体。
- letter spacing 保持 `0`。

---

## 文件结构

- 修改 `.gitignore`: 删除 `website/` 忽略规则,让源码和静态资源可提交。
- 创建 `website/index.html`: 单页官网结构,包含导航、hero、feature sections、最终 CTA。
- 创建 `website/styles.css`: Aurora Terminal 视觉系统、desktop 布局、窄屏布局。
- 创建 `website/assets/app-icon.png`: 从 `Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512.png` 复制。
- 创建 `website/assets/hero-workspace.png`: 当前从 `images/screenshot.png` 复制,后续只替换这一张文件。
- 创建 `scripts/check_website_assets.sh`: 校验 `website/` 可跟踪、基础文件和图片资产存在。
- 创建 `scripts/check_website_content.sh`: 校验文案、CTA、section anchors、hero image 引用。
- 创建 `scripts/check_website_styles.sh`: 校验 Aurora token、字级、截图比例和响应式约束。
- 修改 `docs/README.md`: 替换已经过时的 `website/src/content/docs/` 描述。
- 创建 `scripts/check_website_docs.sh`: 校验文档里的官网源码说明与实际结构一致。

## Task 1: 跟踪 website 源码与基础资产

**Files:**
- Modify: `.gitignore`
- Create: `scripts/check_website_assets.sh`
- Create: `website/index.html`
- Create: `website/styles.css`
- Create: `website/assets/app-icon.png`
- Create: `website/assets/hero-workspace.png`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-06-22-argo-website-design.md`
- Produces: 可被 git 跟踪的 `website/` 目录、两张可替换图片资产、返回 exit 0 的 `scripts/check_website_assets.sh`

- [ ] **Step 1: 写入失败优先的资产校验脚本**

创建 `scripts/check_website_assets.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if git check-ignore -q website/index.html; then
  echo "website/index.html is ignored" >&2
  exit 1
fi

required_files=(
  "website/index.html"
  "website/styles.css"
  "website/assets/app-icon.png"
  "website/assets/hero-workspace.png"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "missing $path" >&2
    exit 1
  fi
done

file website/assets/app-icon.png | grep -q "PNG image data"
file website/assets/hero-workspace.png | grep -q "PNG image data"

echo "website assets ok"
```

- [ ] **Step 2: 运行校验并确认失败原因正确**

Run:

```bash
chmod +x scripts/check_website_assets.sh
scripts/check_website_assets.sh
```

Expected: FAIL with `website/index.html is ignored`,因为 `.gitignore` 仍包含 `website/`。

- [ ] **Step 3: 让官网源码可入库**

修改 `.gitignore`: 删除最后的 `website/` 行。保留 `.superpowers/`、`.worktrees/`、`dist/`、构建产物和 Xcode user data 规则。

- [ ] **Step 4: 创建最小官网结构并复制图片资产**

Run:

```bash
mkdir -p website/assets
cp Argo/Assets.xcassets/AppIcon.appiconset/appicon_512x512.png website/assets/app-icon.png
cp images/screenshot.png website/assets/hero-workspace.png
```

创建 `website/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Argo</title>
    <meta name="description" content="A native macOS terminal workspace for repositories, worktrees, split panes, previews, SSH sessions, and coding agents.">
    <link rel="stylesheet" href="./styles.css">
  </head>
  <body>
    <main>
      <h1>Argo</h1>
      <p>A native macOS terminal workspace.</p>
      <img src="./assets/hero-workspace.png" alt="Argo workspace screenshot">
    </main>
  </body>
</html>
```

创建 `website/styles.css`:

```css
:root {
  color-scheme: dark;
}

body {
  margin: 0;
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
  background: #070d16;
  color: #f5f9ff;
}

img {
  max-width: 100%;
}
```

- [ ] **Step 5: 再次运行资产校验**

Run:

```bash
scripts/check_website_assets.sh
```

Expected: PASS with `website assets ok`。

- [ ] **Step 6: 提交**

```bash
git add .gitignore scripts/check_website_assets.sh website/index.html website/styles.css website/assets/app-icon.png website/assets/hero-workspace.png
git commit -m "feat(web): track source"
```

## Task 2: 实现首页内容契约

**Files:**
- Create: `scripts/check_website_content.sh`
- Modify: `website/index.html`

**Interfaces:**
- Consumes: Task 1 的 tracked scaffold
- Produces: 语义化单页官网,稳定提供 `#features`、`#download`、`./assets/hero-workspace.png`、GitHub 链接和 Releases 下载链接

- [ ] **Step 1: 写入失败优先的内容校验脚本**

创建 `scripts/check_website_content.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

html="website/index.html"

grep -q '<nav class="site-nav"' "$html"
grep -q 'href="#features"' "$html"
grep -q 'href="#download"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo"' "$html"
grep -q 'href="https://github.com/krystal1110/Argo/releases"' "$html"
grep -q 'Command every repo.' "$html"
grep -q 'Keep every agent in view.' "$html"
grep -q 'brew install --cask krystal1110/tap/argo' "$html"
grep -q 'src="./assets/hero-workspace.png"' "$html"
grep -q 'src="./assets/app-icon.png"' "$html"

for id in workspaces panes agents workbench native download; do
  grep -q "id=\"$id\"" "$html"
done

echo "website content ok"
```

- [ ] **Step 2: 运行校验并确认失败原因正确**

Run:

```bash
chmod +x scripts/check_website_content.sh
scripts/check_website_content.sh
```

Expected: FAIL,因为 scaffold 还没有 `site-nav`、CTA links、feature anchors 和 Homebrew 文案。

- [ ] **Step 3: 替换 `website/index.html` 为完整首页结构**

使用以下完整内容:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Argo — Native macOS Terminal Workspace</title>
    <meta name="description" content="A native macOS terminal workspace for repositories, worktrees, split panes, previews, SSH sessions, and coding agents.">
    <link rel="icon" href="./assets/app-icon.png">
    <link rel="stylesheet" href="./styles.css">
  </head>
  <body>
    <header class="site-header">
      <nav class="site-nav" aria-label="Primary navigation">
        <a class="brand" href="#top" aria-label="Argo home">
          <img src="./assets/app-icon.png" alt="" width="31" height="31">
          <span>Argo</span>
        </a>
        <div class="nav-links">
          <a href="#top">Home</a>
          <a href="#features">Features</a>
          <a href="#download">Download</a>
          <a href="https://github.com/krystal1110/Argo">GitHub</a>
        </div>
      </nav>
    </header>

    <main id="top">
      <section class="hero" aria-labelledby="hero-title">
        <div class="hero-copy">
          <h1 id="hero-title">Argo</h1>
          <p class="tagline">Command every repo.<br>Keep every agent in view.</p>
          <p class="hero-body">A native macOS terminal workspace for repositories, worktrees, split panes, previews, SSH sessions, and coding agents.</p>
          <div class="cta-row" aria-label="Primary actions">
            <a class="button primary" href="https://github.com/krystal1110/Argo/releases">Download</a>
            <a class="button secondary" href="https://github.com/krystal1110/Argo">GitHub</a>
          </div>
          <p class="install-copy">Or install through Homebrew:<br><code>brew install --cask krystal1110/tap/argo</code></p>
          <p class="opensource-copy">Free & Open Source. Built for fast local work across many repositories.</p>
        </div>

        <div class="hero-visual" aria-label="Argo workspace preview">
          <div class="orbit-line" aria-hidden="true"></div>
          <figure class="app-window">
            <div class="window-chrome" aria-hidden="true">
              <span class="dot red"></span>
              <span class="dot yellow"></span>
              <span class="dot green"></span>
              <span class="window-title">Argo workspace</span>
            </div>
            <img src="./assets/hero-workspace.png" alt="Argo workspace with sidebar, split terminal panes, and file workbench">
          </figure>
          <aside class="status-card" aria-label="Agent completion status">
            <strong>liney / main</strong>
            <span>✓ 23 tests passed · agent complete</span>
            <span>pane layout restored</span>
          </aside>
          <img class="floating-icon" src="./assets/app-icon.png" alt="" width="118" height="118">
        </div>
      </section>

      <section class="feature-strip" aria-label="Feature summary">
        <a class="feature-chip" href="#workspaces"><strong>Workspaces</strong><span>Multi-repository sidebar with worktree-aware navigation.</span></a>
        <a class="feature-chip" href="#panes"><strong>Panes</strong><span>Ghostty-powered split layouts restored per worktree.</span></a>
        <a class="feature-chip" href="#agents"><strong>Agents</strong><span>Local shell, SSH, and agent-backed sessions stay visible.</span></a>
        <a class="feature-chip" href="#workbench"><strong>Workbench</strong><span>File tree, Markdown/HTML preview, and localhost pages.</span></a>
        <a class="feature-chip" href="#native"><strong>Native</strong><span>AppKit + SwiftUI with a vendored Ghostty runtime.</span></a>
      </section>

      <section id="features" class="feature-sections" aria-label="Argo features">
        <article id="workspaces" class="feature-section">
          <p class="section-number">01</p>
          <h2>Every repo gets a place.</h2>
          <p>Keep many repositories visible without turning your terminal into a tab hunt. Argo keeps workspace navigation, branches, and worktrees in one steady sidebar.</p>
        </article>
        <article id="panes" class="feature-section">
          <p class="section-number">02</p>
          <h2>Pane layouts come back.</h2>
          <p>Ghostty-powered terminal panes restore per worktree, so builds, tests, shells, and long-running sessions return where you left them.</p>
        </article>
        <article id="agents" class="feature-section">
          <p class="section-number">03</p>
          <h2>Keep agents in view.</h2>
          <p>Local shells, SSH sessions, and agent-backed tabs stay visible. Pane-aware notifications and <code>argo notify</code> help completions surface at the right moment.</p>
        </article>
        <article id="workbench" class="feature-section">
          <p class="section-number">04</p>
          <h2>Preview beside the terminal.</h2>
          <p>Open a file tree, Markdown or HTML preview, and localhost web pages beside the terminal that produced them.</p>
        </article>
        <article id="native" class="feature-section">
          <p class="section-number">05</p>
          <h2>Native macOS, no detour.</h2>
          <p>Argo is built with AppKit, SwiftUI, and a vendored Ghostty runtime for macOS 14.6 or later on Apple Silicon and Intel Macs.</p>
        </article>
      </section>

      <section id="download" class="final-cta" aria-labelledby="download-title">
        <p class="section-number">Start</p>
        <h2 id="download-title">Put every workspace in reach.</h2>
        <div class="cta-row">
          <a class="button primary" href="https://github.com/krystal1110/Argo/releases">Download Argo</a>
          <a class="button secondary" href="https://github.com/krystal1110/Argo">View on GitHub</a>
        </div>
        <p class="install-copy">Or install through Homebrew:<br><code>brew install --cask krystal1110/tap/argo</code></p>
      </section>
    </main>
  </body>
</html>
```

- [ ] **Step 4: 再次运行内容校验**

Run:

```bash
scripts/check_website_content.sh
```

Expected: PASS with `website content ok`。

- [ ] **Step 5: 提交**

```bash
git add scripts/check_website_content.sh website/index.html
git commit -m "feat(web): add hero"
```

## Task 3: 实现 Aurora Terminal 样式

**Files:**
- Create: `scripts/check_website_styles.sh`
- Modify: `website/styles.css`

**Interfaces:**
- Consumes: Task 2 的语义化首页
- Produces: Aurora Terminal v4 视觉实现,包含固定字级、响应式布局、稳定截图比例、无 viewport-width 字体和无负 letter spacing

- [ ] **Step 1: 写入失败优先的样式校验脚本**

创建 `scripts/check_website_styles.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

css="website/styles.css"

grep -q -- "--bg-page: #070d16" "$css"
grep -q -- "--bg-deep: #061215" "$css"
grep -q -- "--bg-mid: #0a1624" "$css"
grep -q -- "--accent: #5fd7ca" "$css"
grep -q -- "font-size: 72px" "$css"
grep -q -- "font-size: 24px" "$css"
grep -q -- "font-size: 16.8px" "$css"
grep -q -- "aspect-ratio: 16 / 9.6" "$css"
grep -q -- "@media (max-width: 760px)" "$css"

if grep -E "font-size:[^;]+vw" "$css"; then
  echo "font-size must not use viewport units" >&2
  exit 1
fi

if grep -E "letter-spacing:[[:space:]]*-" "$css"; then
  echo "letter-spacing must not be negative" >&2
  exit 1
fi

echo "website styles ok"
```

- [ ] **Step 2: 运行校验并确认失败原因正确**

Run:

```bash
chmod +x scripts/check_website_styles.sh
scripts/check_website_styles.sh
```

Expected: FAIL,因为 scaffold CSS 还没有 Aurora tokens、hero typography、aspect ratio 和 responsive query。

- [ ] **Step 3: 替换 `website/styles.css` 为 Aurora Terminal 样式**

样式必须包含这些 token:

```css
:root {
  color-scheme: dark;
  --bg-page: #070d16;
  --bg-deep: #061215;
  --bg-mid: #0a1624;
  --text-primary: #f5f9ff;
  --text-secondary: rgba(214, 229, 252, 0.65);
  --text-muted: rgba(205, 220, 246, 0.44);
  --accent: #5fd7ca;
  --accent-top: #74e4d8;
  --accent-bottom: #52cfc1;
  --border: rgba(238, 251, 255, 0.08);
}
```

样式必须实现这些 selector:

```css
body, .site-header, .site-nav, .brand, .nav-links, .hero, .hero-copy,
.hero h1, .tagline, .hero-body, .cta-row, .button, .install-copy,
.opensource-copy, .hero-visual, .orbit-line, .app-window, .window-chrome,
.dot, .window-title, .status-card, .floating-icon, .feature-strip,
.feature-chip, .feature-sections, .feature-section, .section-number,
.final-cta
```

核心字级和截图契约必须写成:

```css
.hero h1 {
  font-size: 72px;
  line-height: 72px;
  font-weight: 700;
  letter-spacing: 0;
}

.tagline {
  font-size: 24px;
  line-height: 33.6px;
  font-weight: 500;
  letter-spacing: 0;
}

.hero-body {
  font-size: 16.8px;
  line-height: 28.56px;
}

.app-window img {
  aspect-ratio: 16 / 9.6;
  object-fit: cover;
  object-position: 50% 0;
}

@media (max-width: 760px) {
  .hero {
    display: block;
  }
}
```

最终视觉要贴合 `Aurora Terminal v4`:冷青绿更收敛、深蓝黑底、轻产品窗口阴影、截图更早进入首屏、status card 更轻。

- [ ] **Step 4: 再次运行样式校验**

Run:

```bash
scripts/check_website_styles.sh
```

Expected: PASS with `website styles ok`。

- [ ] **Step 5: 提交**

```bash
git add scripts/check_website_styles.sh website/styles.css
git commit -m "feat(web): add styles"
```

## Task 4: 更新文档并运行静态校验

**Files:**
- Create: `scripts/check_website_docs.sh`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: Tasks 1-3 的静态站点与校验脚本
- Produces: 与 `website/` 当前结构一致的 docs guide,以及完整静态校验命令集

- [ ] **Step 1: 写入失败优先的文档校验脚本**

创建 `scripts/check_website_docs.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

grep -q "website/" docs/README.md
grep -q "static landing page" docs/README.md
grep -q "website/assets/hero-workspace.png" docs/README.md

if grep -q "website/src/content/docs" docs/README.md; then
  echo "docs/README.md still references removed website docs structure" >&2
  exit 1
fi

echo "website docs ok"
```

- [ ] **Step 2: 运行校验并确认失败原因正确**

Run:

```bash
chmod +x scripts/check_website_docs.sh
scripts/check_website_docs.sh
```

Expected: FAIL,因为 `docs/README.md` 仍引用 `website/src/content/docs/`。

- [ ] **Step 3: 替换 `docs/README.md` 为当前文档指南**

使用:

```markdown
# Documentation Guide

This repository has three documentation and presentation layers:

- `docs/`: maintainer and contributor documentation
- `docs/superpowers/`: design specs and implementation plans for agentic work
- `website/`: static landing page source for the public website

## Maintainer docs

Use `docs/` for:

- build and test workflows
- release and packaging notes
- architecture details
- internal feature planning

## Website

Use `website/` for the public Argo landing page. The first version is a no-build static site:

- `website/index.html`: single-page product content
- `website/styles.css`: Aurora Terminal visual system and responsive layout
- `website/assets/app-icon.png`: copied app icon
- `website/assets/hero-workspace.png`: replaceable hero screenshot

When the app UI changes, replace `website/assets/hero-workspace.png` with a new screenshot and keep the file path stable.
```

- [ ] **Step 4: 运行所有静态校验**

Run:

```bash
scripts/check_website_assets.sh
scripts/check_website_content.sh
scripts/check_website_styles.sh
scripts/check_website_docs.sh
```

Expected:

```text
website assets ok
website content ok
website styles ok
website docs ok
```

- [ ] **Step 5: 提交**

```bash
git add -f docs/README.md scripts/check_website_docs.sh
git commit -m "feat(web): add docs"
```

## Task 5: 浏览器预览和用户批准门禁

**Files:**
- 不修改源码文件,除非视觉检查暴露明确问题。

**Interfaces:**
- Consumes: Tasks 1-4 的完整静态站点
- Produces: 本地预览证据,并在提交到 GitHub 前取得用户批准

- [ ] **Step 1: 启动本地静态服务器**

Run:

```bash
cd website
python3 -m http.server 4173
```

Expected: server prints `Serving HTTP on :: port 4173` or `Serving HTTP on 0.0.0.0 port 4173`。

- [ ] **Step 2: 打开 desktop preview**

Open:

```text
http://localhost:4173/
```

视觉检查:

- 第一屏可见 brand、navigation、headline、tagline、Download button、GitHub button、Homebrew command、product screenshot、app icon、status card。
- 页面读感是 Aurora Terminal v4,不是早期纯蓝方案或 ember 方案。
- 当前截图可以过时,但容器和裁切必须作为可替换资产槽位成立。

- [ ] **Step 3: 打开窄屏 preview**

使用约 `390px` 宽度视口检查:

- 文本不重叠、不溢出。
- 导航仍可读。
- 产品截图出现在首屏附近。
- floating icon 和 status card 不遮挡关键文案。

- [ ] **Step 4: 运行最终静态校验**

从仓库根目录运行:

```bash
scripts/check_website_assets.sh
scripts/check_website_content.sh
scripts/check_website_styles.sh
scripts/check_website_docs.sh
git status --short
```

Expected:

```text
website assets ok
website content ok
website styles ok
website docs ok
```

`git status --short` 应显示没有未提交源码变更。

- [ ] **Step 5: 提交 GitHub 前请求用户批准**

报告本地 URL 和视觉检查结果。用户批准渲染后的官网前,不要 push 或创建 PR。

预期面向用户的门禁文案:

```text
官网本地预览已准备好: http://localhost:4173/
你确认这版可以提交到 GitHub 吗？
```
