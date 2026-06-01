//
//  ReleaseUpdateTests.swift
//  ArgoTests
//
//  Author: everettjf
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
            "https://code.devops.xiaohongshu.com/huying/Argo/-/raw/stable/appcast.xml"
        )
    }

    func testAppUpdaterReleasesURLUsesGitLabProject() {
        XCTAssertEqual(
            AppUpdaterController.releasesURL.absoluteString,
            "https://code.devops.xiaohongshu.com/huying/Argo/-/releases"
        )
    }

    func testReleaseScriptsUseGitLabPublishing() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for relativePath in ["scripts/release_homebrew.sh", "scripts/release_macos.sh"] {
            let script = try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
            XCTAssertTrue(script.contains("scripts/gitlab_release_tools.sh"), "\(relativePath) should use GitLab release helpers")
            XCTAssertTrue(script.contains("SKIP_GITLAB_RELEASE"), "\(relativePath) should expose GitLab release skipping")
            XCTAssertFalse(script.contains("gh release"), "\(relativePath) should not shell out to GitHub release commands")
            XCTAssertFalse(script.contains("SKIP_GH_RELEASE"), "\(relativePath) should not expose the old GitHub release flag")
        }
    }

    func testReleaseShortcutScriptPublishesOneCommandGitLabRelease() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shortcut = try String(contentsOf: rootURL.appendingPathComponent("release.sh"), encoding: .utf8)
        let homebrewRelease = try String(contentsOf: rootURL.appendingPathComponent("scripts/release_homebrew.sh"), encoding: .utf8)

        XCTAssertTrue(shortcut.contains("GITLAB_PROJECT_PATH:=huying/Argo"))
        XCTAssertTrue(shortcut.contains("BUMP_PART=set"))
        XCTAssertTrue(shortcut.contains("BUMP_VERSION"))
        XCTAssertTrue(shortcut.contains("exec \"$ROOT_DIR/deploy.sh\""))
        XCTAssertTrue(homebrewRelease.contains("BUMP_VERSION"))
        XCTAssertTrue(homebrewRelease.contains("\"$ROOT_DIR/scripts/bump_version.sh\" set \"$BUMP_VERSION\""))
    }

    func testReleaseScriptSupportsGitLabProjectUploadsAndStableFeedBranch() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let homebrewRelease = try String(contentsOf: rootURL.appendingPathComponent("scripts/release_homebrew.sh"), encoding: .utf8)
        let gitlabHelpers = try String(contentsOf: rootURL.appendingPathComponent("scripts/gitlab_release_tools.sh"), encoding: .utf8)

        XCTAssertTrue(homebrewRelease.contains("GITLAB_ASSET_BACKEND"))
        XCTAssertTrue(homebrewRelease.contains("project_uploads"))
        XCTAssertTrue(homebrewRelease.contains("gitlab_project_upload_file \"$DIST_ZIP_PATH\""))
        XCTAssertTrue(homebrewRelease.contains("git push origin \"HEAD:$STABLE_BRANCH\""))
        XCTAssertTrue(gitlabHelpers.contains("gitlab_project_upload_file()"))
        XCTAssertTrue(gitlabHelpers.contains("/uploads"))
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

    func testAppcastUsesGitLabReleaseAssets() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appcast = try String(contentsOf: rootURL.appendingPathComponent("appcast.xml"), encoding: .utf8)

        XCTAssertTrue(appcast.contains("https://code.devops.xiaohongshu.com/huying/Argo/-/releases"))
        XCTAssertTrue(appcast.contains("https://code.devops.xiaohongshu.com/huying/Argo/uploads/"))
        XCTAssertFalse(appcast.contains("https://github.com/everettjf/argo/releases"))
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
