# Releasing Argo

[中文版本](./RELEASING.zh-CN.md)

## Preconditions

- Clean git worktree
- `curl` and `python3` available
- GitHub CLI available and authenticated with `gh auth login`, or run with `GH_TOKEN` / `GITHUB_TOKEN` set with release access
- Developer ID signing identity available if signing/notarizing
- Sparkle private key exported locally, usually at `~/.argo_release/sparkle_private_key`
- Metal toolchain installed for Ghostty release builds:

```bash
xcodebuild -downloadComponent MetalToolchain
```

## Versioning

Update the Xcode project version before releasing:

```bash
scripts/bump_version.sh patch
scripts/bump_version.sh minor
scripts/bump_version.sh set 1.2.0
```

The script updates both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
All version bumps skip any semantic version that contains the digit `4` in any component, so `1.0.3` becomes `1.0.5`, `1.3.9` minor-bumps to `1.5.0`, and `3.9.9` major-bumps to `5.0.0`.
Build numbers follow the same rule, so `23` becomes `25` and explicit overrides containing `4` are rejected.
Explicit `set` versions follow the same rule, so values such as `1.2.4`, `1.2.14`, and `1.4.0` are rejected.

## Sparkle Setup

Generate or restore the Sparkle signing key on the machine that will publish releases:

```bash
scripts/setup_sparkle_keys.sh
```

The script prints the public key and exports the private key to `~/.argo_release/sparkle_private_key`. The public key must match `SUPublicEDKey` in the app target.

Because Argo is open source, do not store this private key in the main repository. Prefer one of:

- a private release-infra repository
- a CI/CD secret manager
- a dedicated release machine with `ARGO_RELEASE_HOME` pointing at a protected directory

## Build A Release Bundle

```bash
scripts/build_macos_app.sh
```

Optional environment:

- `SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"`
- `OUTPUT_DIR=/custom/output/path`
- `RELEASE_ARCHS="arm64 x86_64"`

The default release bundle is now a universal macOS artifact that contains both `arm64` and `x86_64` slices.

## Sign And Notarize

Recommended once per release machine:

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

Provide notarization credentials with either:

- `NOTARYTOOL_PROFILE=argo-notarytool` (recommended)
- `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`

## Publish

Argo releases are published to GitHub:

- project: `https://github.com/krystal1110/Argo`
- releases: `https://github.com/krystal1110/Argo/releases`
- Sparkle feed: `https://raw.githubusercontent.com/krystal1110/Argo/stable/appcast.xml`
- release binaries: GitHub Release assets

Authenticate before publishing:

```bash
gh auth login
# or
export GH_TOKEN=<token-with-release-access>
```

Use the root one-command release script for normal releases:

```bash
./release.sh
```

Common forms:

```bash
./release.sh patch
./release.sh minor
./release.sh major
./release.sh 1.2.0
./release.sh set 1.2.0
```

`./release.sh 1.2.0` and `./release.sh set 1.2.0` set `MARKETING_VERSION` explicitly before continuing through the full publish flow.

The lower-level release entrypoint remains available:

```bash
./deploy.sh
```

If the `argo-notarytool` profile exists in the current keychain, `scripts/sign_macos.sh` and `./deploy.sh` will use it automatically. You only need to pass `NOTARYTOOL_PROFILE` when you want to override that default.

Default behavior:

- bumps `MARKETING_VERSION` by patch and increments `CURRENT_PROJECT_VERSION` by 1 unless `SKIP_BUMP=1`
- builds and signs the universal release DMG
- archives `Argo.app.dSYM` to `dist/dSYMs/Argo-<version>.app.dSYM`
- packages `dist/dSYMs/Argo-<version>.app.dSYM.zip`
- packages `Argo-<version>.app.zip` for Sparkle
- notarizes unless `SKIP_NOTARIZE=1`
- updates the repository `appcast.xml`
- pushes the Sparkle feed branch, `stable` by default
- uploads the DMG, Sparkle app zip, dSYM zip, and appcast to GitHub Releases
- creates or updates the GitHub release and attaches release assets for those files
- updates the Homebrew tap unless `SKIP_CASK_UPDATE=1`

Useful overrides:

- `BUMP_PART=minor ./deploy.sh`
- `BUMP_PART=set BUMP_VERSION=1.2.0 ./deploy.sh`
- `SKIP_BUMP=1 ./deploy.sh`
- `SKIP_NOTARIZE=1 ./deploy.sh`
- `SKIP_GITHUB_RELEASE=1 ./deploy.sh`
- `SKIP_CASK_UPDATE=1 ./deploy.sh`
- `GITHUB_REPOSITORY=krystal1110/Argo ./deploy.sh`
- `STABLE_BRANCH=stable ./deploy.sh`
- `TAP_PROJECT_PATH=owner/homebrew-tap ./deploy.sh`
- `TAP_REMOTE_URL=git@github.com:owner/homebrew-tap.git ./deploy.sh`
- `ARGO_RELEASE_HOME=/secure/release-home ./deploy.sh`
- `SPARKLE_PRIVATE_KEY_FILE=/secure/path/private_key ./deploy.sh`

`GITHUB_REPOSITORY` is inferred from `origin` when the remote is `git@github.com:owner/repo.git` or `https://github.com/owner/repo.git`. If the project is private, make sure the Sparkle feed and package download URLs are reachable by installed clients; Sparkle cannot attach GitHub authentication headers during update checks.

If you prefer the old path, `scripts/deploy.sh` remains available as a compatibility wrapper.

Generated GitHub release notes are intentionally concise: they include the DMG name, Homebrew install command, and previous release tag, but do not include commit history. Add any human-written changelog details directly in GitHub after the release if needed.
