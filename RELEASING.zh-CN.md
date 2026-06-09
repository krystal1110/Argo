# 发布 Argo

[English Version](./RELEASING.md)

## 前置条件

- Git 工作区干净，没有未提交改动
- 本机可用 `curl` 和 `python3`
- 已设置具备 `api` scope 的 GitLab token：`GITLAB_TOKEN`
- 如果需要签名或公证，机器上已具备 Developer ID 签名身份
- 已在本地导出 Sparkle 私钥，通常位于 `~/.argo_release/sparkle_private_key`
- 已安装用于 Ghostty 发布构建的 Metal 工具链：

```bash
xcodebuild -downloadComponent MetalToolchain
```

## 版本管理

发布前先更新 Xcode 项目版本：

```bash
scripts/bump_version.sh patch
scripts/bump_version.sh minor
scripts/bump_version.sh set 1.2.0
```

该脚本会同时更新 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`。
所有版本递增都会跳过任意组件中包含数字 `4` 的语义版本，因此 `1.0.3` 会变成 `1.0.5`，`1.3.9` 做 minor 递增时会变成 `1.5.0`，`3.9.9` 做 major 递增时会变成 `5.0.0`。
构建号同样遵循这一规则，因此 `23` 会变成 `25`，显式指定包含 `4` 的构建号也会被拒绝。
使用 `set` 显式设置版本时也遵循同样的规则，因此 `1.2.4`、`1.2.14` 和 `1.4.0` 这类版本号都会被拒绝。

## Sparkle 配置

在用于发布版本的机器上生成或恢复 Sparkle 签名密钥：

```bash
scripts/setup_sparkle_keys.sh
```

该脚本会打印公钥，并将私钥导出到 `~/.argo_release/sparkle_private_key`。公钥必须与应用 target 中的 `SUPublicEDKey` 一致。

由于 Argo 是开源项目，不要将这个私钥存放在主仓库中。推荐使用以下任一方式保存：

- 私有的发布基础设施仓库
- CI/CD 密钥管理服务
- 专用发布机器，并将 `ARGO_RELEASE_HOME` 指向受保护目录

## 构建发布包

```bash
scripts/build_macos_app.sh
```

可选环境变量：

- `SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"`
- `OUTPUT_DIR=/custom/output/path`
- `RELEASE_ARCHS="arm64 x86_64"`

默认的发布产物是一个通用的 macOS 构建包，同时包含 `arm64` 和 `x86_64` 两种架构切片。

## 签名与公证

建议每台发布机器执行一次：

```bash
xcrun notarytool store-credentials argo-notarytool \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --validate
```

```bash
scripts/sign_macos.sh \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --version 1.0.0 \
  --force-rebuild \
  --notarize
```

可通过以下任一方式提供公证凭据：

- `NOTARYTOOL_PROFILE=argo-notarytool`（推荐）
- `APPLE_ID`、`APPLE_TEAM_ID` 和 `APPLE_APP_SPECIFIC_PASSWORD`

## 发布

Argo 发布产物现在发布到 GitLab：

- 项目：`https://code.devops.xiaohongshu.com/huying/Argo`
- Releases：`https://code.devops.xiaohongshu.com/huying/Argo/-/releases`
- Sparkle feed：`https://code.devops.xiaohongshu.com/huying/Argo/-/raw/stable/appcast.xml`
- 发布二进制：GitLab Generic Package Registry 中的 `argo/<version>` package

发布前先设置 GitLab token：

```bash
export GITLAB_TOKEN=<token-with-api-scope>
```

推荐使用根目录的一键发布脚本：

```bash
./release.sh
```

常用方式：

```bash
./release.sh patch
./release.sh minor
./release.sh major
./release.sh 1.2.0
./release.sh set 1.2.0
```

`./release.sh 1.2.0` 和 `./release.sh set 1.2.0` 会先把 `MARKETING_VERSION` 设置为指定版本，再继续走完整发布流程。

底层发布入口仍然可直接使用：

```bash
./deploy.sh
```

如果当前钥匙串中存在 `argo-notarytool` 配置，`scripts/sign_macos.sh` 和 `./deploy.sh` 会自动使用它。只有在你想覆盖这个默认值时，才需要显式传入 `NOTARYTOOL_PROFILE`。

默认行为如下：

- 将 `MARKETING_VERSION` 做一次 patch 递增，并将 `CURRENT_PROJECT_VERSION` 加 1，除非设置 `SKIP_BUMP=1`
- 构建并签名通用版发布 DMG
- 将 `Argo.app.dSYM` 归档到 `dist/dSYMs/Argo-<version>.app.dSYM`
- 打包 `dist/dSYMs/Argo-<version>.app.dSYM.zip`
- 为 Sparkle 打包 `Argo-<version>.app.zip`
- 除非设置 `SKIP_NOTARIZE=1`，否则执行公证
- 更新仓库中的 `appcast.xml`
- 将 DMG、Sparkle app zip、dSYM zip 和 appcast 上传到 GitLab Generic Package Registry
- 创建或更新 GitLab Release，并为这些文件附加 Release asset links
- 除非设置 `SKIP_CASK_UPDATE=1`，否则更新 Homebrew tap

常用覆盖方式：

- `BUMP_PART=minor ./deploy.sh`
- `BUMP_PART=set BUMP_VERSION=1.2.0 ./deploy.sh`
- `SKIP_BUMP=1 ./deploy.sh`
- `SKIP_NOTARIZE=1 ./deploy.sh`
- `SKIP_GITLAB_RELEASE=1 ./deploy.sh`
- `SKIP_CASK_UPDATE=1 ./deploy.sh`
- `GITLAB_PROJECT_PATH=huying/Argo ./deploy.sh`
- `GITLAB_PROJECT_ID=<numeric-id> ./deploy.sh`
- `TAP_PROJECT_PATH=group/homebrew-tap ./deploy.sh`
- `TAP_REMOTE_URL=git@code.devops.xiaohongshu.com:group/homebrew-tap.git ./deploy.sh`
- `ARGO_RELEASE_HOME=/secure/release-home ./deploy.sh`
- `SPARKLE_PRIVATE_KEY_FILE=/secure/path/private_key ./deploy.sh`

当 `origin` 是 `git@code.devops.xiaohongshu.com:huying/Argo.git` 时，脚本会自动推断 `GITLAB_PROJECT_PATH`。只有在你希望 API URL 使用数字项目 ID 时，才需要设置 `GITLAB_PROJECT_ID`。如果 GitLab 项目是私有项目，请确认 Sparkle feed 和 package 下载地址对已安装客户端可访问；Sparkle 检查更新时不会自动附加 GitLab 认证 header。

如果你仍在使用旧路径，`scripts/deploy.sh` 依然保留为兼容包装脚本。

对于首次公开发布，建议手动编写 GitLab Release Notes，而不是完全依赖自动生成的提交摘要。
