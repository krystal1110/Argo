//
//  ReleaseUpdateTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class ReleaseUpdateTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        LocalizationManager.shared.updateSelectedLanguage(.english)
    }

    override func tearDown() async throws {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        try await super.tearDown()
    }
    
    func testNewWindowShortcutDefaultsToCommandN() {
        XCTAssertEqual(ArgoShortcutAction.newWindow.category, .window)
        XCTAssertEqual(ArgoShortcutAction.newWindow.title, "New Window")
        XCTAssertEqual(
            ArgoShortcutAction.newWindow.defaultShortcut,
            StoredShortcut(key: "n", command: true, shift: false, option: false, control: false)
        )
    }

    func testWindowLifecycleHelpersRespectHotKeyAndVisibility() {
        XCTAssertTrue(argoShouldTerminateAfterLastWindowClosed(hotKeyWindowEnabled: false, isRunningTests: false))
        XCTAssertFalse(argoShouldTerminateAfterLastWindowClosed(hotKeyWindowEnabled: true, isRunningTests: false))
        XCTAssertTrue(argoShouldReopenMainWindow(hasVisibleWindows: false))
        XCTAssertFalse(argoShouldReopenMainWindow(hasVisibleWindows: true))
    }

    func testAppUpdaterDefaultsToStableAppcastFeed() {
        XCTAssertEqual(
            AppUpdaterController.defaultFeedURLString,
            "https://raw.githubusercontent.com/krystal1110/Argo/stable/appcast.xml"
        )
    }

    func testAppUpdaterReleasesURLUsesGitHubProject() {
        XCTAssertEqual(
            AppUpdaterController.releasesURL.absoluteString,
            "https://github.com/krystal1110/Argo/releases"
        )
    }

    func testReleaseScriptsUseGitHubPublishing() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for relativePath in ["scripts/release_homebrew.sh", "scripts/release_macos.sh"] {
            let script = try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
            XCTAssertTrue(script.contains("scripts/github_release_tools.sh"), "\(relativePath) should use GitHub release helpers")
            XCTAssertTrue(script.contains("SKIP_GITHUB_RELEASE"), "\(relativePath) should expose GitHub release skipping")
            XCTAssertFalse(script.contains("scripts/gitlab_release_tools.sh"), "\(relativePath) should not use GitLab release helpers")
            XCTAssertFalse(script.contains("SKIP_GITLAB_RELEASE"), "\(relativePath) should not expose the old GitLab release flag")
        }
    }

    func testReleaseShortcutScriptPublishesOneCommandGitHubRelease() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shortcut = try String(contentsOf: rootURL.appendingPathComponent("release.sh"), encoding: .utf8)
        let homebrewRelease = try String(contentsOf: rootURL.appendingPathComponent("scripts/release_homebrew.sh"), encoding: .utf8)

        XCTAssertTrue(shortcut.contains("GITHUB_REPOSITORY:=krystal1110/Argo"))
        XCTAssertTrue(shortcut.contains("BUMP_PART=set"))
        XCTAssertTrue(shortcut.contains("BUMP_VERSION"))
        XCTAssertTrue(shortcut.contains("exec \"$ROOT_DIR/deploy.sh\""))
        XCTAssertTrue(homebrewRelease.contains("BUMP_VERSION"))
        XCTAssertTrue(homebrewRelease.contains("\"$ROOT_DIR/scripts/bump_version.sh\" set \"$BUMP_VERSION\""))
    }

    func testReleaseShortcutRequiresGitHubCLIWhenTokenIsSet() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shortcut = try String(contentsOf: rootURL.appendingPathComponent("release.sh"), encoding: .utf8)

        let githubCLICheck = try XCTUnwrap(shortcut.range(of: "command -v gh"))
        let tokenBypass = try XCTUnwrap(shortcut.range(of: "GH_TOKEN:-${GITHUB_TOKEN:-}"))

        XCTAssertLessThan(
            shortcut.distance(from: shortcut.startIndex, to: githubCLICheck.lowerBound),
            shortcut.distance(from: shortcut.startIndex, to: tokenBypass.lowerBound),
            "release.sh should fail fast when gh is missing even if GH_TOKEN / GITHUB_TOKEN is set."
        )
    }

    func testReleaseScriptSupportsGitHubReleaseAssetsAndStableFeedBranch() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let homebrewRelease = try String(contentsOf: rootURL.appendingPathComponent("scripts/release_homebrew.sh"), encoding: .utf8)
        let githubHelpers = try String(contentsOf: rootURL.appendingPathComponent("scripts/github_release_tools.sh"), encoding: .utf8)

        XCTAssertTrue(homebrewRelease.contains("github_release_download_url_prefix \"$TAG\""))
        XCTAssertTrue(homebrewRelease.contains("git push origin \"HEAD:$STABLE_BRANCH\""))
        XCTAssertTrue(githubHelpers.contains("github_create_or_update_release()"))
        XCTAssertTrue(githubHelpers.contains("github_upload_release_assets()"))
        XCTAssertTrue(githubHelpers.contains("gh release upload"))
    }

    func testGeneratedReleaseNotesDoNotIncludeCommitHistory() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let homebrewRelease = try String(contentsOf: rootURL.appendingPathComponent("scripts/release_homebrew.sh"), encoding: .utf8)

        XCTAssertFalse(homebrewRelease.contains("Showing the most recent"))
        XCTAssertFalse(homebrewRelease.contains("## Included Commits"))
        XCTAssertFalse(homebrewRelease.contains("git log \\"))
        XCTAssertFalse(homebrewRelease.contains("Truncated to the most recent"))
    }

    func testSigningScriptAssessesGatekeeperOnlyAfterNotarizationWhenRequested() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(contentsOf: rootURL.appendingPathComponent("scripts/sign_macos.sh"), encoding: .utf8)

        XCTAssertFalse(
            script.contains("""
            /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"
            /usr/sbin/spctl --assess -vv --type execute "$APP_BUNDLE_PATH"
            """),
            "Gatekeeper assessment rejects Developer ID apps before notarization finishes."
        )
        XCTAssertTrue(script.contains("""
        if [[ "$NOTARIZE" != "1" ]]; then
          /usr/sbin/spctl --assess -vv --type execute "$APP_BUNDLE_PATH"
        fi
        """))
        XCTAssertTrue(script.contains("""
            xcrun stapler validate "$DMG_PATH"
            /usr/sbin/spctl --assess -vv --type execute "$APP_BUNDLE_PATH"
        """))
    }

    func testAppcastUsesGitHubReleaseAssets() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appcast = try String(contentsOf: rootURL.appendingPathComponent("appcast.xml"), encoding: .utf8)

        XCTAssertTrue(appcast.contains("https://github.com/krystal1110/Argo/releases"))
        XCTAssertTrue(appcast.contains("https://github.com/krystal1110/Argo/releases/download/"))
        XCTAssertFalse(appcast.contains("https://code.devops.xiaohongshu.com"))
    }

    func testAppUpdaterFallsBackToStableFeedWhenInfoPlistValueMissing() {
        XCTAssertEqual(
            AppUpdaterController.resolveFeedURLString(infoDictionary: nil),
            AppUpdaterController.defaultFeedURLString
        )
        XCTAssertEqual(
            AppUpdaterController.resolveFeedURLString(infoDictionary: [:]),
            AppUpdaterController.defaultFeedURLString
        )
    }

    func testAppUpdaterPrefersInfoPlistFeedURL() {
        XCTAssertEqual(
            AppUpdaterController.resolveFeedURLString(
                infoDictionary: [AppUpdaterController.feedURLInfoPlistKey: "https://example.com/appcast.xml"]
            ),
            "https://example.com/appcast.xml"
        )
    }

    func testAppSettingsDecodesLegacyPayloadWithUpdateDefaults() throws {
        let data = Data(
            """
            {
              "autoRefreshEnabled": false,
              "autoRefreshIntervalSeconds": 60,
              "fileWatcherEnabled": false,
              "githubIntegrationEnabled": true,
              "systemNotificationsEnabled": false,
              "showArchivedWorkspaces": true,
              "commandPaletteRecents": {
                "office": 123
              }
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertFalse(decoded.autoRefreshEnabled)
        XCTAssertEqual(decoded.autoRefreshIntervalSeconds, 60)
        XCTAssertTrue(decoded.autoClosePaneOnProcessExit)
        XCTAssertTrue(decoded.confirmQuitWhenCommandsRunning)
        XCTAssertTrue(decoded.autoCheckForUpdates)
        XCTAssertFalse(decoded.autoDownloadUpdates)
        XCTAssertTrue(decoded.sidebarShowsSecondaryLabels)
        XCTAssertTrue(decoded.sidebarShowsWorkspaceBadges)
        XCTAssertTrue(decoded.sidebarShowsWorktreeBadges)
        XCTAssertNil(decoded.terminalFontFamily)
        XCTAssertNil(decoded.terminalFontSize)
        XCTAssertEqual(decoded.defaultRepositoryIcon, .repositoryDefault)
        XCTAssertEqual(decoded.defaultLocalTerminalIcon, .localTerminalDefault)
        XCTAssertEqual(decoded.defaultWorktreeIcon, .worktreeDefault)
        XCTAssertEqual(decoded.releaseChannel, .stable)
        XCTAssertEqual(decoded.agentPresets.first?.name, "Claude Code")
        XCTAssertEqual(decoded.preferredAgentPresetID, AgentPreset.claudeCode.id)
        XCTAssertEqual(decoded.sshPresets.first?.name, "Shell")
        XCTAssertNil(decoded.preferredSSHPresetID)
    }

    func testAppSettingsPreservesEmptySSHPresets() throws {
        let encoded = try JSONEncoder().encode(
            AppSettings(
                sshPresets: [],
                preferredSSHPresetID: nil
            )
        )

        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

        XCTAssertTrue(decoded.sshPresets.isEmpty)
        XCTAssertNil(decoded.preferredSSHPresetID)
    }

    func testAppSettingsPreservesCustomTerminalFontSize() throws {
        let encoded = try JSONEncoder().encode(
            AppSettings(terminalFontSize: 15)
        )

        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(decoded.terminalFontSize, 15)
    }

    func testAppSettingsPreservesCustomTerminalFontFamily() throws {
        let encoded = try JSONEncoder().encode(
            AppSettings(terminalFontFamily: "JetBrains Mono")
        )

        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(decoded.terminalFontFamily, "JetBrains Mono")
    }
}
