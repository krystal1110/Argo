# 官网 Release 历史自动更新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让官网 Release 页面展示最近 4 个版本,并让 release 更新脚本自动维护官网 Release 数据与 HTML。

**Architecture:** 官网 Release 内容拆成 JSON 数据源和生成脚本。`scripts/website_release_notes.sh` 负责读取/更新 `website/releases/releases.json`、生成 `website/releases/index.html`、从 release notes 和 appcast 提取摘要/日期;`scripts/release_homebrew.sh` 在非 resume release bump commit 前调用该 helper 并 stage 官网文件。Shell 检查脚本覆盖页面内容、生成能力和发布脚本接入。

**Tech Stack:** Bash、Python 3 标准库 (`json`, `html`, `xml.etree.ElementTree`, `email.utils`)、Static HTML/CSS、现有 shell verification scripts。

## Global Constraints

- 始终使用简体中文回复；方案文档必须使用简体中文。
- 官网 Release 页面必须展示最近 4 个版本记录。
- 每个版本摘要最多一到两句话。
- 每次走 release 更新脚本时自动更新官网 Release 数据和页面。
- 不引入 Node、npm、构建系统或 CMS。
- 不改 GitHub Release 发布机制。
- 不改 Sparkle appcast 生成机制。
- 首页 Download 仍只指向当前最新版本。
- 旧版本链接只允许出现在 Release 页面历史记录中。

---

## 文件结构

- Create: `website/releases/releases.json` — 官网 Release 展示数据,只保留最近 4 条。
- Create: `scripts/website_release_notes.sh` — 数据更新、摘要提取、日期读取、HTML 生成 helper。
- Create: `scripts/check_website_release_notes_support.sh` — helper 行为和 release 脚本接入检查。
- Modify: `website/releases/index.html` — 改为由 JSON 生成的最近 4 个版本页面。
- Modify: `website/styles.css` — 为历史 release cards 增加布局样式。
- Modify: `scripts/check_website_content.sh` — 校验 4 个版本、摘要长度、旧版本链接边界。
- Modify: `scripts/release_homebrew.sh` — source helper,非 resume 发布时更新并 stage 官网 release 文件。
- Modify: `RELEASING.md` — 说明 release 脚本会自动更新官网 Release 记录。

## Task 1: 页面内容契约先失败

**Files:**
- Modify: `scripts/check_website_content.sh`

**Interfaces:**
- Consumes: 当前 `website/releases/index.html`
- Produces: 会在当前单条 release 页面上失败的内容契约

- [ ] **Step 1: 写失败优先的内容检查**

在 `scripts/check_website_content.sh` 中把 Release 校验改为:

```sh
for version in 1.0.8 1.0.7 1.0.6 1.0.5; do
  grep -q "Argo $version" "$releases"
  grep -q "href=\"https://github.com/krystal1110/Argo/releases/tag/v$version\"" "$releases"
  grep -q "href=\"https://github.com/krystal1110/Argo/releases/download/v$version/Argo-$version.dmg\"" "$releases"
done

release_summary_count="$(grep -c '<p class="release-summary">' "$releases")"
if [[ "$release_summary_count" != "4" ]]; then
  echo "Release page should list exactly 4 summaries, found $release_summary_count" >&2
  exit 1
fi

while IFS= read -r release_summary; do
  summary_words="$(awk '{ print NF }' <<< "$release_summary")"
  if (( summary_words > 60 )); then
    echo "Release page summary is too long: $summary_words words" >&2
    exit 1
  fi
  sentence_count="$(grep -oE '[.!?]+' <<< "$release_summary" | wc -l | tr -d ' ')"
  if (( sentence_count > 2 )); then
    echo "Release page summary should be one or two sentences: $release_summary" >&2
    exit 1
  fi
done < <(awk -F '<p class="release-summary">|</p>' '/release-summary/ { print $2 }' "$releases")

if grep -Eq 'href="https://github.com/krystal1110/Argo/releases/(tag|download)/v1\.0\.[567]' "$html"; then
  echo "homepage should not link old releases as current downloads" >&2
  exit 1
fi
```

- [ ] **Step 2: 运行并确认 RED**

Run: `scripts/check_website_content.sh`

Expected: FAIL,因为当前 release 页面缺少 `1.0.7`、`1.0.6`、`1.0.5`。

## Task 2: 生成最近 4 个版本页面

**Files:**
- Create: `website/releases/releases.json`
- Create: `scripts/website_release_notes.sh`
- Modify: `website/releases/index.html`
- Modify: `website/styles.css`

**Interfaces:**
- Consumes: `website/releases/releases.json`
- Produces:
  - `website_release_notes_generate`
  - `website_release_notes_update <version> <tag> <previous_tag> <dmg_path> <release_notes_file>`
  - 生成后的 `website/releases/index.html`

- [ ] **Step 1: 创建初始 JSON 数据**

`website/releases/releases.json` 写入最近 4 个版本,字段为 `version`、`date`、`summary`。

- [ ] **Step 2: 创建最小 helper**

`scripts/website_release_notes.sh` 提供 `website_release_notes_generate`,用 Python 标准库读取 JSON 并生成完整 HTML。URL 按 `GITHUB_REPOSITORY` fallback `krystal1110/Argo` 生成。

- [ ] **Step 3: 生成 HTML**

Run: `source scripts/website_release_notes.sh && website_release_notes_generate`

Expected: `website/releases/index.html` 包含 4 个 `release-summary`,最新版本有 `Latest` badge。

- [ ] **Step 4: 添加历史卡片样式**

在 `website/styles.css` 增加 `.release-history`、`.release-card`、`.release-card .button` 和窄屏规则。

- [ ] **Step 5: 运行 GREEN**

Run: `scripts/check_website_content.sh`

Expected: PASS with `website content ok`。

## Task 3: 自动更新数据并接入 release 脚本

**Files:**
- Create: `scripts/check_website_release_notes_support.sh`
- Modify: `scripts/website_release_notes.sh`
- Modify: `scripts/release_homebrew.sh`

**Interfaces:**
- Consumes:
  - `website_release_notes_update <version> <tag> <previous_tag> <dmg_path> <release_notes_file>`
  - existing `release_notes_write_commit_summary_sentence`
- Produces:
  - 自动 prepend 当前版本
  - 同版本去重
  - 裁剪到最近 4 条
  - 从 `appcast.xml` 的 `pubDate` 生成官网日期
  - release bump commit stage 官网 release 文件

- [ ] **Step 1: 写失败优先的 helper 检查**

创建 `scripts/check_website_release_notes_support.sh`,使用临时 JSON、HTML、appcast 和 release notes fixture 调用 `website_release_notes_update "1.0.9" "v1.0.9" "v1.0.8" "$tmp/Argo-1.0.9.dmg" "$notes"`。

检查:

- JSON 只保留 4 条。
- `1.0.9` 在第一条。
- `1.0.5` 被裁剪。
- HTML 包含 `Argo 1.0.9`、`Latest`、`Argo-1.0.9.dmg`。
- `scripts/release_homebrew.sh` source `scripts/website_release_notes.sh`。
- `scripts/release_homebrew.sh` 调用 `website_release_notes_update`。
- `git add --` 包含 `website/releases/releases.json` 和 `website/releases/index.html`。

- [ ] **Step 2: 运行并确认 RED**

Run: `chmod +x scripts/check_website_release_notes_support.sh && scripts/check_website_release_notes_support.sh`

Expected: FAIL,因为 helper 还没有 update 函数,release 脚本也未接入。

- [ ] **Step 3: 实现 update 函数**

在 `scripts/website_release_notes.sh` 中补:

- `website_release_notes_extract_summary`
- `website_release_notes_date_for_version`
- `website_release_notes_update`

Python 负责 Markdown 摘要截断、JSON 去重裁剪、日期格式化和 HTML 再生成。

- [ ] **Step 4: 接入 release 脚本**

在 `scripts/release_homebrew.sh`:

- source `"$ROOT_DIR/scripts/website_release_notes.sh"`。
- `RESUMING != 1` 且 `appcast.xml` 已复制后,调用 `website_release_notes_update "$VERSION" "$TAG" "$PREVIOUS_TAG" "$DIST_DMG_PATH" "$RELEASE_NOTES_FILE"`。
- `git add -- "$PROJECT_FILE" "$APPCAST_FILE" "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE"`。
- cleanup 失败时也把官网 release 文件纳入 restore 范围。

- [ ] **Step 5: 运行 GREEN**

Run: `scripts/check_website_release_notes_support.sh`

Expected: PASS with `website release notes support ok`。

## Task 4: 文档与最终验证

**Files:**
- Modify: `RELEASING.md`

**Interfaces:**
- Consumes: Task 1-3 的脚本与页面
- Produces: release docs 明确官网 Release 自动更新能力

- [ ] **Step 1: 更新 release 文档**

在 `RELEASING.md` 默认行为列表中加入:

```md
- updates the website Release Notes page with the latest 4 releases
```

并在 useful overrides 后说明官网摘要来源:

```md
The website Release Notes page is regenerated during the release bump commit. It keeps the latest four releases in `website/releases/releases.json`; pass `RELEASE_NOTES_SOURCE_FILE` when you want the website summary to start from human-written release copy.
```

- [ ] **Step 2: 运行最终验证**

Run:

```bash
scripts/check_website_content.sh
scripts/check_website_release_notes_support.sh
scripts/check_release_notes_support.sh
scripts/check_website_styles.sh
scripts/check_website_assets.sh
```

Expected: all PASS.

- [ ] **Step 3: 查看变更范围**

Run: `git status --short`

Expected: 只包含本次官网 release、脚本、文档和计划相关文件,以及此前已存在的未跟踪 `default.profraw`。
