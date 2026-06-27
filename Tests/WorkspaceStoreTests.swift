//
//  WorkspaceStoreTests.swift
//  ArgoTests
//
//  Author: krystal
//

import SwiftUI
import XCTest
@testable import Argo

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    override func tearDown() {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        super.tearDown()
    }

    func testOpenWorkspaceAsRepositoryAddsRepositoryWorkspaceWithoutChangingLocalWorkspace() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try runProcess(
            executable: "/usr/bin/env",
            arguments: ["git", "init", "-b", "main"],
            currentDirectory: directoryURL.path
        )

        let store = WorkspaceStore(persistsWorkspaceState: false)
        let localWorkspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        store.workspaces = [localWorkspace]
        store.selectedWorkspaceID = localWorkspace.id

        try await store.openWorkspaceAsRepository(localWorkspace, persistAfterChange: false)

        XCTAssertEqual(store.workspaces.count, 2)
        XCTAssertEqual(store.workspaces.filter { !$0.supportsRepositoryFeatures }.count, 1)
        XCTAssertEqual(store.workspaces.filter(\.supportsRepositoryFeatures).count, 1)
        XCTAssertTrue(store.workspaces.contains(where: { $0.id == localWorkspace.id && !$0.supportsRepositoryFeatures }))
        XCTAssertEqual(
            store.workspaces.first(where: \.supportsRepositoryFeatures).map {
                URL(fileURLWithPath: $0.repositoryRoot).standardizedFileURL.path
            },
            directoryURL.standardizedFileURL.path
        )
    }

    func testLoadIfNeededAppliesInitialAppLanguageToLocalizationManager() async {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        let store = WorkspaceStore(
            initialAppSettings: AppSettings(appLanguage: .simplifiedChinese),
            persistsWorkspaceState: false
        )

        await store.loadIfNeeded()

        XCTAssertEqual(LocalizationManager.shared.selectedLanguage, .simplifiedChinese)
    }

    func testUpdateAppSettingsPublishesSelectedLanguageToLocalizationManager() {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.updateAppSettings(AppSettings(appLanguage: .simplifiedChinese))

        XCTAssertEqual(store.appSettings.appLanguage, .simplifiedChinese)
        XCTAssertEqual(LocalizationManager.shared.selectedLanguage, .simplifiedChinese)
    }

    func testUpdateAppSettingsPreservesInterfaceScale() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.updateAppSettings(AppSettings(uiScale: 1.25))

        XCTAssertEqual(store.appSettings.uiScale, 1.25)
    }

    func testUpdateAppSettingsPreservesTerminalBackgroundAppearance() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.updateAppSettings(
            AppSettings(
                terminalBackgroundOpacity: 0.65,
                terminalBackgroundBlur: true,
                twilightThemeEnabled: false
            )
        )

        XCTAssertEqual(store.appSettings.terminalBackgroundOpacity, 0.65, accuracy: 0.0001)
        XCTAssertTrue(store.appSettings.terminalBackgroundBlur)
    }

    func testDefaultAppSettingsUseCurrentTwilightDefaults() {
        let settings = AppSettings()

        XCTAssertTrue(settings.twilightThemeEnabled)
        XCTAssertEqual(settings.twilightThemeSeedHex, "#7aa2f7")
        XCTAssertEqual(settings.twilightOpacityPercent, 90)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.50, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsKeepGhosttyOpacitySeparateWhenTwilightIsEnabled() {
        let settings = AppSettings(
            terminalBackgroundOpacity: 0.55,
            terminalBackgroundBlur: true,
            twilightThemeEnabled: true,
            twilightOpacityPercent: 72
        )

        XCTAssertEqual(settings.twilightOpacityPercent, 72)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.55, accuracy: 0.0001)
        XCTAssertTrue(settings.terminalBackgroundBlur)
    }

    func testAppSettingsNormalizeInvalidTwilightSeed() {
        let settings = AppSettings(twilightThemeSeedHex: "not-a-color")

        XCTAssertEqual(settings.twilightThemeSeedHex, TwilightTheme.defaultSeedHex)
    }

    func testDecodedLegacySettingsUseTwilightDefaults() throws {
        let json = #"{"uiScale":1.1}"#.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertTrue(settings.twilightThemeEnabled)
        XCTAssertEqual(settings.twilightThemeSeedHex, TwilightTheme.defaultSeedHex)
    }

    func testAppSettingsMigrateOldTwilightSeedAndOpacityDefaults() throws {
        let json = """
        {
          "twilightThemeEnabled": true,
          "twilightThemeSeedHex": "#ffb066",
          "terminalBackgroundOpacity": 0.76,
          "terminalBackgroundBlur": true,
          "terminalBackgroundAppearanceVersion": 2
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightThemeSeedHex, "#fabd2f")
        XCTAssertEqual(settings.twilightOpacityPercent, 90)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.50, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsMigrateLegacyOpacityDefaultToCurrentDefaultPercent() throws {
        let json = """
        {
          "terminalBackgroundOpacity": 0.82,
          "terminalBackgroundBlur": true,
          "terminalBackgroundAppearanceVersion": 1
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 90)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.50, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsMigrateOldExplicitHundredPercentTwilightDefaultToCurrentDefaultPercent() throws {
        let json = """
        {
          "twilightThemeEnabled": true,
          "twilightOpacityPercent": 100,
          "terminalBackgroundOpacity": 1,
          "terminalBackgroundBlur": true,
          "terminalBackgroundAppearanceVersion": 1
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 90)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.50, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsMigrateVersionTwoExplicitHundredPercentTwilightDefaultToCurrentDefaultPercent() throws {
        let json = """
        {
          "twilightThemeEnabled": true,
          "twilightOpacityPercent": 100,
          "terminalBackgroundOpacity": 1,
          "terminalBackgroundBlur": false,
          "terminalBackgroundAppearanceVersion": 2
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 90)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.50, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsPreserveCurrentExplicitHundredPercentTwilightOpacity() throws {
        let json = """
        {
          "twilightThemeEnabled": true,
          "twilightOpacityPercent": 100,
          "terminalBackgroundOpacity": 1,
          "terminalBackgroundBlur": false,
          "terminalBackgroundAppearanceVersion": 3
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 100)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 1, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testAppSettingsMigrateCustomOpacityIntoPercent() throws {
        let json = """
        {
          "terminalBackgroundOpacity": 0.65,
          "terminalBackgroundBlur": false,
          "terminalBackgroundAppearanceVersion": 2
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 65)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.65, accuracy: 0.0001)
        XCTAssertFalse(settings.terminalBackgroundBlur)
    }

    func testDecodedCurrentSettingsKeepGhosttyOpacitySeparateFromTwilightOpacity() throws {
        let json = """
        {
          "twilightThemeEnabled": true,
          "twilightOpacityPercent": 72,
          "terminalBackgroundOpacity": 0.55,
          "terminalBackgroundBlur": true,
          "terminalBackgroundAppearanceVersion": 3
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.twilightOpacityPercent, 72)
        XCTAssertEqual(settings.terminalBackgroundOpacity, 0.55, accuracy: 0.0001)
        XCTAssertTrue(settings.terminalBackgroundBlur)
    }

    func testUpdateAppSettingsPreservesTwilightSettings() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.updateAppSettings(
            AppSettings(
                twilightThemeEnabled: false,
                twilightThemeSeedHex: "#5cc8ff",
                twilightOpacityPercent: 72
            )
        )

        XCTAssertFalse(store.appSettings.twilightThemeEnabled)
        XCTAssertEqual(store.appSettings.twilightThemeSeedHex, "#7aa2f7")
        XCTAssertEqual(store.appSettings.twilightOpacityPercent, 72)
        XCTAssertEqual(store.currentTwilightTheme.seedHex, "#7aa2f7")
        XCTAssertEqual(store.currentTwilightOpacity.termAlpha, 0.468, accuracy: 0.0001)
    }

    func testUpdateAppSettingsPreservesSSHPresets() {
        let store = WorkspaceStore(persistsWorkspaceState: false)
        let customPreset = SSHPreset(
            name: "Deploy",
            host: "prod.example.com",
            user: "deploy",
            port: 2222,
            identityFilePath: "~/.ssh/prod",
            remoteWorkingDirectory: "/srv/app",
            remoteCommand: "lazygit"
        )

        store.updateAppSettings(
            AppSettings(
                sshPresets: [customPreset],
                preferredSSHPresetID: customPreset.id
            )
        )

        XCTAssertEqual(store.appSettings.sshPresets, [customPreset])
        XCTAssertEqual(store.appSettings.preferredSSHPresetID, customPreset.id)
    }

    func testCommandPaletteItemsLocalizeForSimplifiedChinese() async throws {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)
        let store = WorkspaceStore(persistsWorkspaceState: false)

        let items = store.commandPaletteItems

        XCTAssertTrue(items.contains(where: { $0.id == "overview" && $0.title == "打开工作区概览" }))
        XCTAssertTrue(items.contains(where: { $0.id == "settings" && $0.title == "打开设置" }))
        XCTAssertTrue(items.contains(where: { $0.id == "check-updates" && $0.title == "检查 Argo 更新" }))
    }

    func testCommandPaletteOmitsLocalScriptCommandsForRemoteWorkspace() {
        let store = WorkspaceStore(persistsWorkspaceState: false)
        let remote = makeRemoteWorkspace(path: "/srv/app", setupScript: "mise install", runScript: "make deploy")
        store.workspaces = [remote]
        store.selectedWorkspaceID = remote.id

        let itemIDs = Set(store.commandPaletteItems.map(\.id))

        XCTAssertFalse(itemIDs.contains("workspace-selected-setup:\(remote.id.uuidString)"))
        XCTAssertFalse(itemIDs.contains("workspace-setup:\(remote.id.uuidString)"))
        XCTAssertFalse(itemIDs.contains("workspace-run:\(remote.id.uuidString)"))
    }

    func testCommandPaletteKeepsLocalScriptCommandsForRepositoryWorkspace() {
        let store = WorkspaceStore(persistsWorkspaceState: false)
        let repository = makeRepositoryWorkspace(path: "/tmp/repo", setupScript: "mise install", runScript: "make test")
        store.workspaces = [repository]
        store.selectedWorkspaceID = repository.id

        let itemIDs = Set(store.commandPaletteItems.map(\.id))

        XCTAssertTrue(itemIDs.contains("workspace-selected-setup:\(repository.id.uuidString)"))
        XCTAssertTrue(itemIDs.contains("workspace-setup:\(repository.id.uuidString)"))
        XCTAssertTrue(itemIDs.contains("workspace-run:\(repository.id.uuidString)"))
    }

    func testMainWindowModeDefaultsToWorkspace() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        XCTAssertEqual(store.mainWindowMode, .workspace)
    }

    func testOverviewCommandTogglesMainWindowMode() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.dispatch(.toggleOverview)
        XCTAssertEqual(store.mainWindowMode, .overview)

        store.dispatch(.toggleOverview)
        XCTAssertEqual(store.mainWindowMode, .workspace)
    }

    func testOverviewCommandDismissesCommandPalette() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        store.dispatch(.toggleCommandPalette)
        XCTAssertTrue(store.isCommandPalettePresented)

        store.dispatch(.toggleOverview)

        XCTAssertEqual(store.mainWindowMode, .overview)
        XCTAssertFalse(store.isCommandPalettePresented)
    }

    func testOverviewCommandPaletteTitleReflectsMainWindowMode() {
        LocalizationManager.shared.updateSelectedLanguage(.english)
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.setMainWindowMode(.overview)

        let overviewItem = store.commandPaletteItems.first { $0.id == "overview" }

        XCTAssertEqual(overviewItem?.title, "Close Workspace Overview")
    }

    func testPresentSettingsDoesNotChangeMainWindowMode() {
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.setMainWindowMode(.canvas)

        store.dispatch(.presentSettings)

        XCTAssertEqual(store.mainWindowMode, .canvas)
        XCTAssertNotNil(store.settingsRequest)
    }

    func testDismissTransientUIReturnsToWorkspaceMode() {
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.setMainWindowMode(.overview)

        store.dispatch(.dismissTransientUI)

        XCTAssertEqual(store.mainWindowMode, .workspace)
    }

    func testSelectWorkspaceReturnsToWorkspaceMode() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]
        store.setMainWindowMode(.canvas)

        store.dispatch(.selectWorkspace(workspace.id))

        XCTAssertEqual(store.selectedWorkspaceID, workspace.id)
        XCTAssertEqual(store.mainWindowMode, .workspace)
    }

    func testChromeTintPrefersActiveWorktreeIconPalette() {
        let root = "/tmp/argo"
        let featurePath = "/tmp/argo/.worktrees/feature"
        let workspace = WorkspaceModel(record: WorkspaceRecord(
            id: UUID(),
            kind: .repository,
            name: "argo",
            repositoryRoot: root,
            activeWorktreePath: featurePath,
            worktreeStates: [],
            isSidebarExpanded: true,
            worktrees: [
                WorktreeModel(path: root, branch: "main", head: "abc", isMainWorktree: true, isLocked: false, lockReason: nil),
                WorktreeModel(path: featurePath, branch: "feature", head: "def", isMainWorktree: false, isLocked: false, lockReason: nil),
            ],
            settings: WorkspaceSettings(
                workspaceIcon: SidebarItemIcon(symbolName: "folder.fill", palette: .blue),
                worktreeIconOverrides: [
                    featurePath: SidebarItemIcon(symbolName: "circle.fill", palette: .rose)
                ]
            ),
            activityLog: []
        ))
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]
        store.selectedWorkspaceID = workspace.id

        XCTAssertEqual(store.chromeTint, ArgoChromeTint.resolved(for: .rose))
    }

    func testChromeTintFallsBackToWorkspaceIconPalette() {
        let root = "/tmp/argo"
        let workspace = WorkspaceModel(record: WorkspaceRecord(
            id: UUID(),
            kind: .repository,
            name: "argo",
            repositoryRoot: root,
            activeWorktreePath: root,
            worktreeStates: [],
            isSidebarExpanded: true,
            worktrees: [],
            settings: WorkspaceSettings(
                workspaceIcon: SidebarItemIcon(symbolName: "folder.fill", palette: .gold)
            ),
            activityLog: []
        ))
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]
        store.selectedWorkspaceID = workspace.id

        XCTAssertEqual(store.chromeTint, ArgoChromeTint.resolved(for: .gold))
    }

    func testChromeTintUsesAccentFallbackWithoutSelection() {
        let store = WorkspaceStore(persistsWorkspaceState: false)

        XCTAssertEqual(store.chromeTint, .fallback)
    }

    func testDynamicIslandStatusMessagePostsSessionEvent() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let store = WorkspaceStore(persistsWorkspaceState: false)
        store.workspaces = [workspace]
        store.selectedWorkspaceID = workspace.id
        store.updateAppSettings(AppSettings(dynamicIslandEnabled: true))

        IslandNotificationState.shared.clearAll()
        defer { IslandNotificationState.shared.clearAll() }

        store.receive(.statusMessage(
            "Setup complete",
            .success,
            deliverSystemNotification: true,
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath
        ))

        XCTAssertTrue(IslandNotificationState.shared.items.isEmpty)
        let successSession = try XCTUnwrap(IslandNotificationState.shared.sessions.first)
        XCTAssertEqual(successSession.title, "Setup complete")
        XCTAssertEqual(successSession.phase, .completed)

        store.receive(.statusMessage(
            "Setup failed",
            .warning,
            deliverSystemNotification: true,
            workspaceID: workspace.id,
            worktreePath: workspace.activeWorktreePath
        ))

        let warningSession = try XCTUnwrap(IslandNotificationState.shared.sessionState.session(
            id: "status:\(workspace.id.uuidString.lowercased()):Setup failed"
        ))
        XCTAssertEqual(warningSession.phase, .failed)
        XCTAssertEqual(warningSession.lastError, "Setup failed")
    }

    func testMainWindowLayoutRestoresWorkspaceSidebarWhenReturningFromGlobalMode() {
        var layoutState = MainWindowLayoutState()
        layoutState.workspaceColumnVisibility = .all

        layoutState.selectMode(.overview)
        layoutState.selectMode(.workspace)

        XCTAssertEqual(layoutState.workspaceColumnVisibility, .all)
    }

    func testMainWindowLayoutHidesWorkspaceSidebarWhenEnteringGlobalModes() {
        for newMode in [MainWindowMode.canvas, .overview] {
            var layoutState = MainWindowLayoutState()
            layoutState.workspaceColumnVisibility = .all

            layoutState.selectMode(newMode)

            XCTAssertEqual(
                layoutState.workspaceColumnVisibility,
                .detailOnly,
                "Expected workspace -> \(newMode.rawValue) to hide the workspace sidebar column"
            )
        }
    }

    func testMainWindowLayoutPreservesCollapsedWorkspaceSidebarAcrossGlobalModeRoundTrip() {
        var layoutState = MainWindowLayoutState()
        layoutState.workspaceColumnVisibility = .detailOnly

        layoutState.selectMode(.canvas)
        layoutState.selectMode(.workspace)

        XCTAssertEqual(layoutState.workspaceColumnVisibility, .detailOnly)
    }

    func testMainWindowLayoutPreservesExpandedWorkspaceSidebarWhenModeChangeIsObservedTwice() {
        var layoutState = MainWindowLayoutState()
        layoutState.workspaceColumnVisibility = .all

        layoutState.selectMode(.canvas)
        layoutState.selectMode(.canvas)
        layoutState.selectMode(.workspace)

        XCTAssertEqual(layoutState.workspaceColumnVisibility, .all)
    }

    func testMainWindowLayoutKeepsWorkspaceSidebarStateWhenReselectingWorkspace() {
        var layoutState = MainWindowLayoutState()
        layoutState.workspaceColumnVisibility = .detailOnly

        layoutState.selectMode(.workspace)

        XCTAssertEqual(layoutState.workspaceColumnVisibility, .detailOnly)
    }

    func testMainWindowLayoutTogglesWorkspaceSidebarOnlyInWorkspaceMode() {
        var layoutState = MainWindowLayoutState()

        XCTAssertTrue(layoutState.isWorkspaceSidebarVisible(in: .workspace))

        layoutState.toggleWorkspaceSidebar()
        XCTAssertFalse(layoutState.isWorkspaceSidebarVisible(in: .workspace))

        layoutState.selectMode(.overview)
        XCTAssertFalse(layoutState.isWorkspaceSidebarVisible(in: .overview))

        layoutState.toggleWorkspaceSidebar()
        XCTAssertFalse(
            layoutState.isWorkspaceSidebarVisible(in: .overview),
            "Global modes should not reveal the workspace sidebar."
        )

        layoutState.selectMode(.workspace)
        XCTAssertFalse(layoutState.isWorkspaceSidebarVisible(in: .workspace))

        layoutState.toggleWorkspaceSidebar()
        XCTAssertTrue(layoutState.isWorkspaceSidebarVisible(in: .workspace))
    }

    func testMainWindowModeTransitionsDoNotAnimateBetweenContentModes() {
        for previousMode in MainWindowMode.allCases {
            for newMode in MainWindowMode.allCases {
                XCTAssertFalse(
                    MainWindowModeTransition(previousMode: previousMode, newMode: newMode).shouldAnimate,
                    "Expected \(previousMode.rawValue) -> \(newMode.rawValue) to avoid animated AppKit host remounts"
                )
            }
        }
    }

    func testStaleTerminalCloseActionDoesNotCloseRemainingPaneAfterSmartClose() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let originalPane = PaneSnapshot.makeDefault(cwd: directoryURL.path)
        let focusedPane = PaneSnapshot.makeDefault(cwd: directoryURL.path)
        let layout = SessionLayoutNode.split(PaneSplitNode(
            axis: .vertical,
            first: .pane(PaneLeaf(paneID: originalPane.id)),
            second: .pane(PaneLeaf(paneID: focusedPane.id))
        ))
        let state = WorktreeSessionStateRecord(
            worktreePath: directoryURL.path,
            layout: layout,
            panes: [originalPane, focusedPane],
            focusedPaneID: focusedPane.id
        )
        let workspace = WorkspaceModel(record: WorkspaceRecord(
            id: UUID(),
            kind: .localTerminal,
            name: "demo",
            repositoryRoot: directoryURL.path,
            activeWorktreePath: directoryURL.path,
            worktreeStates: [state],
            isSidebarExpanded: false,
            settings: WorkspaceSettings(),
            activityLog: []
        ))

        XCTAssertEqual(workspace.paneOrder.count, 2)

        workspace.closePane(focusedPane.id)
        XCTAssertEqual(workspace.paneOrder, [originalPane.id])

        let originalSession = try XCTUnwrap(workspace.sessionController.session(for: originalPane.id))
        originalSession.onWorkspaceAction?(.closePane)

        XCTAssertEqual(workspace.paneOrder, [originalPane.id])
        XCTAssertNotNil(workspace.sessionController.session(for: originalPane.id))
    }

    func testSleepPreventionStringsLocalizeForSimplifiedChinese() async throws {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)
        let store = WorkspaceStore(persistsWorkspaceState: false)

        XCTAssertEqual(store.sleepPreventionStatusText, "禁止休眠")
        XCTAssertEqual(store.sleepPreventionPrimaryActionLabel, "开始禁止休眠")
        XCTAssertEqual(store.sleepPreventionPrimaryActionHelpText, "为 macOS 启用禁止休眠：1 小时")
    }

    func testModelDisplayStringsLocalizeForSimplifiedChinese() {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)

        XCTAssertEqual(WorkspaceKind.repository.displayName, "仓库")
        XCTAssertEqual(WorkspaceKind.localTerminal.displayName, "本地终端")
        XCTAssertEqual(SessionBackendKind.localShell.displayName, "本地 Shell")
        XCTAssertEqual(WorkspaceActivityKind.workflow.displayName, "工作流")
        XCTAssertEqual(GlobalCanvasColorGroup.slate.title, "石板灰")
        XCTAssertEqual(WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo").title, "标签页 1")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.new", language: .english), "New Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.rename", language: .english), "Rename Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.close", language: .english), "Close Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.new", language: .simplifiedChinese), "新建分类")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.rename", language: .simplifiedChinese), "重命名分类")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.close", language: .simplifiedChinese), "关闭分类")
    }

    func testMainWindowModeMetadataIsStable() {
        XCTAssertEqual(MainWindowMode.allCases, [.workspace, .canvas, .overview])
        XCTAssertEqual(MainWindowMode.workspace.id, "workspace")
        XCTAssertEqual(MainWindowMode.canvas.id, "canvas")
        XCTAssertEqual(MainWindowMode.overview.id, "overview")
        XCTAssertEqual(MainWindowMode.workspace.titleLocalizationKey, "main.rail.workspace")
        XCTAssertEqual(MainWindowMode.canvas.titleLocalizationKey, "main.canvas.title")
        XCTAssertEqual(MainWindowMode.overview.titleLocalizationKey, "main.overview.title")
        XCTAssertEqual(MainWindowMode.workspace.iconSystemName(selected: false), "sidebar.leading")
        XCTAssertEqual(MainWindowMode.canvas.iconSystemName(selected: true), "square.grid.3x2.fill")
        XCTAssertEqual(MainWindowMode.overview.iconSystemName(selected: true), "building.2.fill")
    }

    func testMainRailStringsLocalizeForSimplifiedChinese() {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)

        XCTAssertEqual(L10nTable.string(for: "main.rail.workspace", language: .simplifiedChinese), "工作区")
        XCTAssertEqual(L10nTable.string(for: "main.rail.settings", language: .simplifiedChinese), "设置")
    }

    func testWorktreeAndRemoteStringsLocalizeForSimplifiedChinese() throws {
        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)

        let worktree = WorktreeModel(
            path: "/tmp/argo-main",
            branch: "main",
            head: "abc123",
            isMainWorktree: true,
            isLocked: false,
            lockReason: nil
        )
        XCTAssertEqual(worktree.displayName, "main")
        XCTAssertEqual(worktree.branchLabel, "main")
        XCTAssertEqual(
            L10nTable.string(for: "remote.activity.openedShell", language: .simplifiedChinese),
            "已打开远程目标 Shell"
        )
        XCTAssertEqual(RemoteSessionCoordinatorError.missingTarget.errorDescription, "找不到所选远程目标。")
    }

    func testRememberedAgentPresetSelectionAddsBuiltInPresetAndMarksItPreferred() {
        let customPreset = AgentPreset(
            name: "Custom Review",
            launchPath: "/usr/bin/env",
            arguments: ["custom-agent", "review"]
        )

        let selection = argoRememberedAgentPresetSelection(
            currentPresets: [customPreset],
            selectedPresetID: AgentPreset.claudeCode.id
        )

        XCTAssertEqual(selection.preferredPresetID, customPreset.id)
        XCTAssertTrue(selection.presets.contains(where: { $0.id == customPreset.id }))
    }

    func testRememberedSSHPresetSelectionKeepsSelectedPresetPreferred() {
        let selection = argoRememberedSSHPresetSelection(
            currentPresets: SSHPreset.builtInPresets,
            selectedPresetID: SSHPreset.yazi.id
        )

        XCTAssertEqual(selection.preferredPresetID, SSHPreset.yazi.id)
        XCTAssertEqual(selection.presets.map(\.id), SSHPreset.builtInPresets.map(\.id))
    }

    func testRememberedSSHPresetSelectionDoesNotFallbackToFirstPreset() {
        let selection = argoRememberedSSHPresetSelection(
            currentPresets: SSHPreset.builtInPresets,
            selectedPresetID: UUID()
        )

        XCTAssertNil(selection.preferredPresetID)
        XCTAssertEqual(selection.presets.map(\.id), SSHPreset.builtInPresets.map(\.id))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let directoryURL = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func makeRepositoryWorkspace(
        path: String,
        setupScript: String = "",
        runScript: String = ""
    ) -> WorkspaceModel {
        WorkspaceModel(record: WorkspaceRecord(
            id: UUID(),
            kind: .repository,
            name: URL(fileURLWithPath: path).lastPathComponent,
            repositoryRoot: path,
            activeWorktreePath: path,
            worktreeStates: [WorktreeSessionStateRecord.makeDefault(for: path)],
            isSidebarExpanded: false,
            settings: WorkspaceSettings(runScript: runScript, setupScript: setupScript)
        ))
    }

    private func makeRemoteWorkspace(
        path: String,
        setupScript: String = "",
        runScript: String = ""
    ) -> WorkspaceModel {
        let sshConfig = SSHSessionConfiguration(
            host: "example.com",
            user: "deploy",
            port: nil,
            identityFilePath: nil,
            remoteWorkingDirectory: path,
            remoteCommand: nil
        )
        return WorkspaceModel(record: WorkspaceRecord(
            id: UUID(),
            kind: .remoteServer,
            name: "Remote",
            repositoryRoot: path,
            activeWorktreePath: path,
            worktreeStates: [WorktreeSessionStateRecord.makeDefault(for: path)],
            isSidebarExpanded: false,
            settings: WorkspaceSettings(runScript: runScript, setupScript: setupScript),
            sshTarget: sshConfig
        ))
    }


    private func runProcess(
        executable: String,
        arguments: [String],
        currentDirectory: String
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            XCTFail("Command failed: \(arguments.joined(separator: " "))\nstdout: \(stdout)\nstderr: \(stderr)")
            return
        }
    }
}
