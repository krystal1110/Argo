# 官网 Release 历史自动更新设计方案

## 背景

官网当前已有 `website/releases/index.html`,但页面只静态展示 `Argo 1.0.8` 一条记录。发布流程位于 `scripts/release_homebrew.sh`,会生成 GitHub/Sparkle release notes 并更新 `appcast.xml`,但不会同步更新官网 Release 页面。

本次目标是让官网 Release 页面展示最近 4 个版本记录,每个版本用一到两句话描述关键更新,并补齐“每次走更新脚本时自动更新官网”的能力。

## 现状依据

- `appcast.xml` 已包含最近版本、发布日期、GitHub release 链接和 Sparkle 包下载链接。
- 本地 tags 的最近 4 个版本为 `v1.0.8`、`v1.0.7`、`v1.0.6`、`v1.0.5`。
- `scripts/release_notes.sh` 已能根据提交摘要生成一段简短 Summary,并允许 `RELEASE_NOTES_SOURCE_FILE` 提供人工 Markdown。
- `scripts/release_homebrew.sh` 当前 release bump commit 只 stage `Argo.xcodeproj/project.pbxproj` 和 `appcast.xml`。
- `scripts/check_website_content.sh` 当前只校验单条 `1.0.8` release,并禁止首页或 release 页把旧版本当成当前下载链接。

## 推荐方案

新增官网 Release 数据源和生成脚本:

- `website/releases/releases.json` 保存官网展示用 release 数据。
- `scripts/website_release_notes.sh` 提供数据更新和 HTML 生成函数。
- `scripts/release_homebrew.sh` 在生成 `RELEASE_NOTES_FILE` 后调用官网更新函数,把当前版本放到数据顶部、去重、裁剪到最近 4 条,并重新生成 `website/releases/index.html`。

这样官网文案保持可控,发布流程也能自动落盘。相比直接用 `sed` 修改 HTML,数据文件更稳;相比完全从 `appcast.xml + git log` 推导,人工可读的一到两句话更容易维护。

## 页面结构

Release 页面继续使用现有导航和深色官网视觉。主区域展示:

- 标题 `Release Notes`。
- 一句说明:页面保留最近 4 个版本,每条聚焦用户可见变化。
- 最新版本使用当前 `latest-release` 视觉样式,带 `Latest` badge、日期、GitHub tag 链接、DMG 下载按钮、摘要和 Homebrew 安装命令。
- 其余 3 个版本使用同一 release card 结构,展示日期、版本标题、GitHub tag 链接、DMG 下载按钮和摘要。

页面不得使用长列表 bullet 作为版本详情。每个版本摘要最多两句,保持官网式产品文案。

## 初始 4 个版本内容

初始数据来自当前 `appcast.xml` 日期和本地 tag 提交范围:

- `1.0.8`, `June 26, 2026`: 顶部窗口区域的双击缩放/还原更可靠,并修正 full-size titlebar 的拖拽命中。
- `1.0.7`, `June 25, 2026`: 终端视觉与主题系统完成一轮扩展,包含 Twilight 主题、wallpaper 与主题设置入口。
- `1.0.6`, `June 22, 2026`: 官网发布上线,并完善 Dynamic Island 会话流与 Claude hook 同步。
- `1.0.5`, `June 22, 2026`: 设置面板更精简,Dynamic Island 稳定分支合入,release 流程隐藏 notarization 凭据细节。

这些摘要可在后续发布时由 `RELEASE_NOTES_SOURCE_FILE` 或自动摘要替换。数据文件是人工可读 JSON,允许维护者直接编辑文案。

## 发布脚本数据流

发布流程保持现有顺序,新增官网更新点:

1. `scripts/release_homebrew.sh` 计算 `VERSION`、`TAG`、`PREVIOUS_TAG`。
2. `generate_release_notes` 生成 `RELEASE_NOTES_FILE`。
3. 新增调用 `website_release_notes_update "$VERSION" "$TAG" "$PREVIOUS_TAG" "$DIST_DMG_PATH" "$RELEASE_NOTES_FILE"`。
4. 更新函数从 release notes 中抽取 Summary 第一段作为官网摘要;若没有 Summary,回退到当前 `release_notes_write_commit_summary_sentence` 生成的句子。
5. 更新函数从 `appcast.xml` 中读取当前版本 `pubDate`,格式化为官网日期;如当前版本还未进入 appcast,回退到当前日期。
6. 数据文件更新为新版本在顶部,同版本去重,只保留最近 4 条。
7. 生成脚本用数据文件重写 `website/releases/index.html`。
8. release bump commit stage `website/releases/releases.json` 和 `website/releases/index.html`。

Resume 模式下不重新生成 appcast 或 tag,但仍可使用已有 `RELEASE_NOTES_FILE` 发布资产。为避免改写已发布官网记录,resume 模式不更新官网 Release 数据。

## 错误处理

- 数据文件缺失时,生成脚本应给出明确错误,避免发布时生成空页面。
- JSON 解析失败时脚本退出非零,不继续发布。
- 自动摘要为空时使用 `Initial public release.` 作为兜底,但正常发布路径不应触发。
- 摘要超过两句时生成脚本只取前两句;检查脚本再验证长度。
- 生成后的页面必须包含 4 个 release card,否则检查失败。

## 验证标准

- `scripts/check_website_content.sh` 校验 Release 页面包含最近 4 个版本: `1.0.8`、`1.0.7`、`1.0.6`、`1.0.5`。
- 检查脚本确认每条 release summary 不超过 2 句且不过长。
- 检查脚本确认首页 Download 仍只指向最新版本 `1.0.8`,旧版本链接只允许出现在 Release 页面记录中。
- 新增脚本级检查验证 `scripts/release_homebrew.sh` 已 source 官网 release helper,并把 `website/releases/releases.json` 和 `website/releases/index.html` 纳入 release bump commit。
- 运行官网生成脚本后 `website/releases/index.html` 稳定、可重复生成。

## 非目标

- 不改 GitHub Release 发布机制。
- 不改 Sparkle appcast 生成机制。
- 不引入 Node、npm、构建系统或 CMS。
- 不把完整 commit history 展示到官网。
- 不更新首页除当前下载链接校验以外的内容。
