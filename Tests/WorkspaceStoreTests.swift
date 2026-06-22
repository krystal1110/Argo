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
                terminalBackgroundBlur: true
            )
        )

        XCTAssertEqual(store.appSettings.terminalBackgroundOpacity, 0.65, accuracy: 0.0001)
        XCTAssertTrue(store.appSettings.terminalBackgroundBlur)
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
