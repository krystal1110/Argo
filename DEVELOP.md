# Develop Argo

This guide is for contributors and maintainers working on the Argo codebase.

## Requirements

- macOS 14+
- Xcode 16+ with command line tools
- `gh` is required for GitHub release publishing; authenticate it with `gh auth login`, or supply `GH_TOKEN` / `GITHUB_TOKEN`
- `curl` and `python3` are required for release publishing

Release builds also require the Metal toolchain component used by Ghostty:

```bash
xcodebuild -downloadComponent MetalToolchain
```

## Build

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Test

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS' \
  test
```

## Run The Debug Build

```bash
open ~/Library/Developer/Xcode/DerivedData/Argo-*/Build/Products/Debug/Argo.app
```

## Project Layout

```text
Argo/
├─ App/
├─ Domain/
├─ Persistence/
├─ Services/
│  ├─ Git/
│  ├─ Process/
│  └─ Terminal/
│     └─ Ghostty/
├─ Support/
├─ UI/
└─ Vendor/
```

## Docs

- Testing guide: [`docs/testing.md`](./docs/testing.md)
- Terminal architecture: [`docs/terminal-architecture.md`](./docs/terminal-architecture.md)
- Workbench panels (file tree / preview / web): [`docs/workbench-panels.md`](./docs/workbench-panels.md)
- Ghostty vendor rebuild: [`docs/build_ghostty.md`](./docs/build_ghostty.md)
- Feature backlog: [`docs/feature-backlog.md`](./docs/feature-backlog.md)
- Release process: [`RELEASING.md`](./RELEASING.md)
- Contributing guide: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Security policy: [`SECURITY.md`](./SECURITY.md)

## Data

Argo stores workspace state and app settings in `~/.argo/`, and still reads legacy state from `~/Library/Application Support/Argo/` when present.

## Release Build

```bash
scripts/build_macos_app.sh
open dist/Argo.app
```

Optional variables:

- `SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"` to sign the `.app`
- `OUTPUT_DIR=/custom/output/path` to change the output folder
- `RELEASE_ARCHS="arm64 x86_64"` to override the default universal macOS artifact

The committed `GhosttyKit.xcframework` now includes both macOS `arm64` and `x86_64` slices, so the default release build emits a universal app bundle and DMG.

If you need to rebuild the vendored Ghostty xcframework, see [`docs/build_ghostty.md`](./docs/build_ghostty.md).

The build script emits:

- `dist/Argo.app`
- `dist/Argo-<version>.dmg`

## Auto Updates

Argo uses Sparkle for signed app updates.

The stable feed is hosted from the GitHub `stable` branch:

```text
https://raw.githubusercontent.com/krystal1110/Argo/stable/appcast.xml
```

Release archives referenced by the feed are uploaded as GitHub Release assets.

To prepare the signing key on a release machine:

```bash
scripts/setup_sparkle_keys.sh
```

This exports the private key to `~/.argo_release/sparkle_private_key` and prints the public key that must stay in the app target's `SUPublicEDKey`.

Because Argo is open source, keep the private key outside this repository. A private release-infra repo, CI secret store, or dedicated release machine is the right place for it.

## Publish

The recommended one-command release entrypoint is:

```bash
./release.sh
```

You can choose the bump directly:

```bash
./release.sh patch
./release.sh minor
./release.sh major
./release.sh 1.2.0
```

The lower-level release entrypoint remains available:

```bash
./deploy.sh
```

By default it:

- bumps the patch version
- increments the build number by 1
- signs and notarizes universal release artifacts
- uploads release artifacts to GitHub Releases
- creates or updates the GitHub release and its asset links
- updates Sparkle appcast metadata and the optional Homebrew tap

Authenticate `gh` before publishing, or set `GH_TOKEN` / `GITHUB_TOKEN`. `GITHUB_REPOSITORY` is inferred from `origin`, and can be overridden with `GITHUB_REPOSITORY=krystal1110/Argo`.

`deploy.sh` remains available as a compatibility wrapper around `scripts/release_homebrew.sh`.

## Current Limitations

- The main supported local development path is the Xcode project
- Ghostty is required for the terminal stack
- Worktree switching restarts active panes after confirmation so their cwd always matches the newly selected worktree
- Session persistence restores per-worktree layout, zoom state, and pane cwd, but relaunch still recreates fresh shell processes
- Some GitHub workflow features expect `gh` to be installed and authenticated
