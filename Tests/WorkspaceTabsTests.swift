//
//  WorkspaceTabsTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class WorkspaceTabsTests: XCTestCase {
    func testTerminalLocalChromeIsNotRenderedInsideEachPane() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalPaneSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalPaneView.swift"),
            encoding: .utf8
        )
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(terminalPaneSource.contains("TerminalLocalChrome("))
        XCTAssertTrue(workspaceDetailSource.contains("TerminalLocalChrome("))
    }

    func testTerminalChromeDoesNotUseWindowWideBackingBand() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalPaneSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalPaneView.swift"),
            encoding: .utf8
        )
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )

        let terminalChromeStart = try XCTUnwrap(workspaceDetailSource.range(of: "TerminalLocalChrome(")?.lowerBound)
        let terminalSurfaceStart = try XCTUnwrap(workspaceDetailSource.range(of: "TerminalWorkspaceSurface(chromeTint: store.chromeTint) {")?.lowerBound)
        let terminalSurfaceEnd = try XCTUnwrap(workspaceDetailSource.range(of: "private var terminalChromeTargetPaneID")?.lowerBound)
        let terminalSurfaceBlock = String(workspaceDetailSource[terminalSurfaceStart..<terminalSurfaceEnd])

        XCTAssertLessThan(terminalChromeStart, terminalSurfaceStart)
        XCTAssertFalse(terminalSurfaceBlock.contains("TerminalLocalChrome("))
        XCTAssertTrue(terminalSurfaceBlock.contains("SplitNodeView("))
        XCTAssertTrue(workspaceDetailSource.contains("TerminalWorkspaceSurface(chromeTint: store.chromeTint) {"))
        XCTAssertTrue(workspaceDetailSource.contains("TopChromeSurfaceBackground(chromeTint: store.chromeTint)"))
        XCTAssertFalse(
            mainWindowSource.contains("WorkspaceChromeMetrics.continuousBandHeight"),
            "Workspace mode should not paint a fixed-height chrome backing behind the content; it shows up as a horizontal band."
        )
        XCTAssertFalse(terminalPaneSource.contains(".clipShape(RoundedRectangle"))
        XCTAssertFalse(terminalPaneSource.contains(".background(paneFill, in: RoundedRectangle"))
        XCTAssertFalse(terminalPaneSource.contains(".shadow(color:"))
    }

    func testTerminalSurfaceIsFlushInsteadOfFloatingCard() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(workspaceDetailSource.contains("RoundedRectangle(cornerRadius: 12"))
        XCTAssertTrue(workspaceDetailSource.contains("let shape = Rectangle()"))
        let terminalChromeStart = try XCTUnwrap(workspaceDetailSource.range(of: "TerminalLocalChrome(")?.lowerBound)
        let terminalChromeEnd = try XCTUnwrap(workspaceDetailSource.range(of: ".frame(height: WorkspaceChromeMetrics.terminalHeight)")?.upperBound)
        let terminalChromeBlock = String(workspaceDetailSource[terminalChromeStart..<terminalChromeEnd])
        XCTAssertFalse(terminalChromeBlock.contains(".padding(.horizontal, 6)"))
        XCTAssertFalse(terminalChromeBlock.contains(".padding(.top, 3)"))
    }

    func testTerminalBackgroundAppearanceIsScopedToTerminalSurface() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let desktopApplicationSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/App/ArgoDesktopApplication.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(mainWindowSource.contains("private var terminalIsTranslucent: Bool"))
        XCTAssertTrue(mainWindowSource.contains(".background(windowContentBackground)"))
        XCTAssertFalse(mainWindowSource.contains("""
            .background(ArgoTheme.appBackground)

            if store.isCommandPalettePresented {
"""))

        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.panelRaised.opacity(isTranslucent ? 0.70 : 0.98)"))
        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.paneBackground.opacity(isTranslucent ? 0.64 : 0.98)"))
        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.panelRaised.opacity(0.98)"))
        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.paneBackground.opacity(0.98)"))
        XCTAssertFalse(workspaceDetailSource.contains("Color.black.opacity(0.14)"))
        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.panelRaised.opacity(0.34)"))
        XCTAssertFalse(workspaceDetailSource.contains("ArgoTheme.paneBackground.opacity(0.26)"))
        XCTAssertFalse(workspaceDetailSource.contains("isTranslucent ? 0.24 : 0.58"))
        XCTAssertTrue(workspaceDetailSource.contains("if !isTranslucent {"))
        XCTAssertFalse(workspaceDetailSource.contains("Rectangle().fill(.ultraThinMaterial)"))
        XCTAssertTrue(workspaceDetailSource.contains("TwilightTerminalScrim()"))
        XCTAssertTrue(workspaceDetailSource.contains("private var translucentGlowOpacity: Double"))
        XCTAssertTrue(workspaceDetailSource.contains("TerminalBackgroundBlurView()"))
        XCTAssertTrue(workspaceDetailSource.contains("store.appSettings.terminalBackgroundBlur"))

        XCTAssertFalse(desktopApplicationSource.contains("updateBackgroundBlur(enabled: transparent && settings.terminalBackgroundBlur)"))
        XCTAssertTrue(desktopApplicationSource.contains("window.backgroundColor = .clear"))
        XCTAssertTrue(desktopApplicationSource.contains("updateBackgroundBlur(enabled: false)"))
    }

    func testTerminalChromeBlendsIntoWorkspaceSurface() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("chromeTint: store.chromeTint"))
        XCTAssertFalse(
            mainWindowSource.contains("WorkspaceChromeMetrics.continuousBandHeight"),
            "Terminal chrome should own its local background instead of relying on a window-wide horizontal backing strip."
        )
        XCTAssertTrue(workspaceDetailSource.contains("TopChromeSurfaceBackground(chromeTint: store.chromeTint)"))
        XCTAssertTrue(workspaceDetailSource.contains("TerminalWorkspaceSurfaceStyle.chromeDivider(for: store.chromeTint)"))
        XCTAssertFalse(workspaceDetailSource.contains("static func topChromeBackground"))
        XCTAssertFalse(workspaceDetailSource.contains(".background(TerminalWorkspaceSurfaceStyle.integratedChromeFill"))
        XCTAssertFalse(workspaceDetailSource.contains(".fill(Color.white.opacity(0.105))"))
        XCTAssertTrue(terminalChromeSource.contains("let chromeTint: ArgoChromeTint"))
        XCTAssertTrue(terminalChromeSource.contains("private var backgroundFill: Color"))
        XCTAssertTrue(terminalChromeSource.contains("ArgoTheme.glassCardH"))
        XCTAssertTrue(terminalChromeSource.contains("return isHovered ? ArgoTheme.glassCard : .clear"))
        XCTAssertFalse(terminalChromeSource.contains("chromeTint.topFill.color.opacity(category.isSelected"))
        XCTAssertFalse(terminalChromeSource.contains("LinearGradient("))
        XCTAssertFalse(terminalChromeSource.contains("chromeTint.tabBarFill.color.opacity"))
        XCTAssertFalse(terminalChromeSource.contains("Color.white.opacity(category.isSelected ? (isFocused ? 0.255 : 0.205)"))
        XCTAssertFalse(terminalChromeSource.contains("Color.white.opacity(0.235)"))
    }

    func testTerminalChromeUsesCategoriesInsteadOfPaneChips() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("""
    private var showsTabStrip: Bool {
        workspace.previewPanel != nil
    }
"""))
        XCTAssertTrue(workspaceDetailSource.contains("categories: terminalChromeCategoryDescriptors"))
        XCTAssertTrue(workspaceDetailSource.contains("activeCategoryID: workspace.activeTabID"))
        XCTAssertTrue(workspaceDetailSource.contains("onSelectCategory: selectTerminalCategoryFromChrome"))
        XCTAssertTrue(terminalChromeSource.contains("struct TerminalChromeCategoryDescriptor"))
        XCTAssertTrue(terminalChromeSource.contains("let categories: [TerminalChromeCategoryDescriptor]"))
        XCTAssertTrue(terminalChromeSource.contains("ForEach(categories)"))
        XCTAssertFalse(terminalChromeSource.contains("TerminalChromePaneChip"))
        XCTAssertFalse(terminalChromeSource.contains("ForEach(paneDescriptors)"))
        XCTAssertFalse(terminalChromeSource.contains("combinedTabAndPaneStrip"))
    }

    func testTerminalChromeExposesPopoverCategoryRename() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("let onRenameCategory: (UUID, String) -> Void"))
        XCTAssertTrue(terminalChromeSource.contains("@State private var editingCategoryID: UUID?"))
        XCTAssertTrue(terminalChromeSource.contains("@State private var renameDraft = \"\""))
        XCTAssertTrue(terminalChromeSource.contains("renamePopoverBinding: renamePopoverBinding(for: category.id)"))
        XCTAssertTrue(terminalChromeSource.contains(".popover(isPresented: renamePopoverBinding)"))
        XCTAssertTrue(terminalChromeSource.contains("private struct TerminalChromeCategoryRenamePopover"))
        XCTAssertTrue(terminalChromeSource.contains("TextField(LocalizationManager.shared.string(\"main.tab.namePlaceholder\"), text: $draft)"))
        XCTAssertTrue(terminalChromeSource.contains("Image(systemName: \"checkmark\")"))
        XCTAssertTrue(terminalChromeSource.contains("Image(systemName: \"xmark\")"))
        XCTAssertTrue(terminalChromeSource.contains(".accessibilityLabel(Text(LocalizationManager.shared.string(\"terminal.category.rename\")))"))
        XCTAssertFalse(terminalChromeSource.contains("TerminalChromeRenameTextField"))
        XCTAssertFalse(terminalChromeSource.contains("NSViewRepresentable"))
        XCTAssertFalse(terminalChromeSource.contains("controlTextDidEndEditing"))
        XCTAssertTrue(workspaceDetailSource.contains("onRenameCategory: renameTerminalCategoryFromChrome"))
        XCTAssertTrue(workspaceDetailSource.contains("store.renameTab(in: workspace, tabID: categoryID, title: normalized)"))
    }

    func testTerminalChromeRenameAvoidsAppKitFocusHandoffLoop() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("renamePopoverBinding(for categoryID: UUID) -> Binding<Bool>"))
        XCTAssertTrue(terminalChromeSource.contains("renameDraft = category.title"))
        XCTAssertTrue(terminalChromeSource.contains("editingCategoryID = category.id"))
        XCTAssertFalse(terminalChromeSource.contains("makeFirstResponder"))
        XCTAssertFalse(terminalChromeSource.contains("selectText(nil)"))
        XCTAssertFalse(terminalChromeSource.contains("refocusAfterInitialHandoffIfNeeded"))
    }

    func testTerminalCategoryPillAvoidsParentTapGestureConflicts() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("Button(action: onSelect)"))
        XCTAssertFalse(terminalChromeSource.contains(".onTapGesture(perform: onSelect)"))
        XCTAssertFalse(terminalChromeSource.contains(".onTapGesture(count: 2, perform: onRename)"))
    }

    func testTerminalCategoryDefaultTitleStaysBoundToCategoryRootPane() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("tab.panes.first?.preferredWorkingDirectory"))
        XCTAssertFalse(workspaceDetailSource.contains("return terminalChromePath"))
        XCTAssertFalse(workspaceDetailSource.contains("tab.focusedPaneID.flatMap"))
    }

    @MainActor
    func testClosingInactiveCategoryPreservesSelectedCategory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-category-close-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let firstCategoryID = try XCTUnwrap(workspace.activeTabID)

        workspace.createTab()
        let secondCategoryID = try XCTUnwrap(workspace.activeTabID)

        workspace.createTab()
        let thirdCategoryID = try XCTUnwrap(workspace.activeTabID)

        workspace.selectTab(firstCategoryID)
        workspace.closeTab(thirdCategoryID)

        XCTAssertEqual(workspace.activeTabID, firstCategoryID)
        XCTAssertEqual(workspace.tabs.map(\.id), [firstCategoryID, secondCategoryID])
    }

    @MainActor
    func testSplittingFocusedPaneAddsPaneInsideSelectedCategoryWithoutCreatingCategory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-category-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let initialCategoryCount = workspace.tabs.count
        let initialCategoryID = try XCTUnwrap(workspace.activeTabID)
        let initialPaneCount = workspace.paneOrder.count

        workspace.createPane(splitAxis: .vertical)

        XCTAssertEqual(workspace.tabs.count, initialCategoryCount)
        XCTAssertEqual(workspace.activeTabID, initialCategoryID)
        XCTAssertEqual(workspace.paneOrder.count, initialPaneCount + 1)
        XCTAssertEqual(workspace.paneCount(for: initialCategoryID), initialPaneCount + 1)
    }

    @MainActor
    func testClosingFocusedPaneFocusesNearestRemainingPane() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-pane-close-focus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let firstPaneID = try XCTUnwrap(workspace.paneOrder.first)

        workspace.createPane(splitAxis: .vertical)
        let secondPaneID = try XCTUnwrap(workspace.paneOrder.last)

        workspace.createPane(splitAxis: .vertical)
        let thirdPaneID = try XCTUnwrap(workspace.paneOrder.last)
        XCTAssertEqual(workspace.paneOrder, [firstPaneID, secondPaneID, thirdPaneID])
        XCTAssertEqual(workspace.sessionController.focusedPaneID, thirdPaneID)

        workspace.closePane(thirdPaneID)

        XCTAssertEqual(workspace.paneOrder, [firstPaneID, secondPaneID])
        XCTAssertEqual(workspace.sessionController.focusedPaneID, secondPaneID)
    }

    @MainActor
    func testClosingFocusedMiddlePaneFocusesSplitSibling() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-pane-close-middle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let firstPaneID = try XCTUnwrap(workspace.paneOrder.first)

        workspace.createPane(splitAxis: .vertical)
        let secondPaneID = try XCTUnwrap(workspace.paneOrder.last)

        workspace.createPane(splitAxis: .vertical)
        let thirdPaneID = try XCTUnwrap(workspace.paneOrder.last)

        workspace.focusPane(secondPaneID)
        workspace.closePane(secondPaneID)

        XCTAssertEqual(workspace.paneOrder, [firstPaneID, thirdPaneID])
        XCTAssertEqual(workspace.sessionController.focusedPaneID, thirdPaneID)
    }

    func testInactiveSplitPanesUseVisualOverlayWithoutBlockingInput() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalPaneSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalPaneView.swift"),
            encoding: .utf8
        )
        let splitNodeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/SplitNodeView.swift"),
            encoding: .utf8
        )
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalPaneSource.contains("let dimsWhenInactive: Bool"))
        XCTAssertTrue(terminalPaneSource.contains("private var shouldDimInactivePane: Bool"))
        XCTAssertTrue(terminalPaneSource.contains("TerminalInactivePaneOverlay()"))
        XCTAssertTrue(terminalPaneSource.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(splitNodeSource.contains("let dimsInactivePanes: Bool"))
        XCTAssertTrue(workspaceDetailSource.contains("dimsInactivePanes: shouldDimInactiveTerminalPanes"))
    }

    func testZoomedPaneDisablesInactiveDimming() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let splitNodeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/SplitNodeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("workspace.zoomedPaneID == nil && workspace.paneOrder.count > 1"))
        XCTAssertTrue(splitNodeSource.contains("dimsWhenInactive: false"))
    }

    func testUpsertingAndSelectingTabsKeepsLegacyFieldsInSync() throws {
        var state = WorktreeSessionStateRecord.makeDefault(for: "/tmp/argo-tabs")
        let firstTab = try XCTUnwrap(state.selectedTab)

        let secondTab = WorkspaceTabStateRecord.makeDefault(
            for: "/tmp/argo-tabs",
            title: "Tab 2"
        )
        state.upsertTab(secondTab, selecting: true)

        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.selectedTabID, secondTab.id)
        XCTAssertEqual(state.focusedPaneID, secondTab.focusedPaneID)

        state.setSelectedTabID(firstTab.id)

        XCTAssertEqual(state.selectedTabID, firstTab.id)
        XCTAssertEqual(state.layout, firstTab.layout)
        XCTAssertEqual(state.focusedPaneID, firstTab.focusedPaneID)
    }

    func testRemovingSelectedTabFallsBackToRemainingTab() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-close", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-close", title: "Tab 2")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/argo-tabs-close",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab],
            selectedTabID: secondTab.id
        )

        state.removeTab(secondTab.id)

        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.selectedTabID, firstTab.id)
        XCTAssertEqual(state.selectedTab?.id, firstTab.id)
    }

    func testRenamingTabMarksItAsManualAndPreservesSelection() throws {
        var state = WorktreeSessionStateRecord.makeDefault(for: "/tmp/argo-tabs-rename")
        let secondTab = WorkspaceTabStateRecord.makeDefault(
            for: "/tmp/argo-tabs-rename",
            title: "Tab 2"
        )
        state.upsertTab(secondTab, selecting: false)

        state.renameTab(secondTab.id, title: "Review Queue")

        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.tabs[1].title, "Review Queue")
        XCTAssertTrue(state.tabs[1].isManuallyNamed)
        XCTAssertEqual(state.selectedTabID, state.tabs[0].id)
    }

    func testMovingTabReordersWithoutChangingSelection() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-move", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-move", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-move", title: "Tab 3")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/argo-tabs-move",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab],
            selectedTabID: secondTab.id
        )

        state.moveTab(secondTab.id, by: 1)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 1", "Tab 3", "Tab 2"])
        XCTAssertEqual(state.selectedTabID, secondTab.id)

        state.moveTab(secondTab.id, by: -2)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 2", "Tab 1", "Tab 3"])
        XCTAssertEqual(state.selectedTabID, secondTab.id)
    }

    func testMovingTabToExplicitIndexSupportsDragReordering() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-drop", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-drop", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-drop", title: "Tab 3")
        let fourthTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-drop", title: "Tab 4")
        var state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/argo-tabs-drop",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab, fourthTab],
            selectedTabID: thirdTab.id
        )

        state.moveTab(firstTab.id, to: 3)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 2", "Tab 3", "Tab 4", "Tab 1"])
        XCTAssertEqual(state.selectedTabID, thirdTab.id)

        state.moveTab(fourthTab.id, to: 0)
        XCTAssertEqual(state.tabs.map(\.title), ["Tab 4", "Tab 2", "Tab 3", "Tab 1"])
        XCTAssertEqual(state.selectedTabID, thirdTab.id)
    }

    func testTabIDLookupByIndexReturnsExpectedTabAndRejectsOutOfRangeValues() throws {
        let firstTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-select", title: "Tab 1")
        let secondTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-select", title: "Tab 2")
        let thirdTab = WorkspaceTabStateRecord.makeDefault(for: "/tmp/argo-tabs-select", title: "Tab 3")
        let state = WorktreeSessionStateRecord(
            worktreePath: "/tmp/argo-tabs-select",
            layout: firstTab.layout,
            panes: firstTab.panes,
            focusedPaneID: firstTab.focusedPaneID,
            tabs: [firstTab, secondTab, thirdTab],
            selectedTabID: firstTab.id
        )

        XCTAssertEqual(state.tabID(at: 0), firstTab.id)
        XCTAssertEqual(state.tabID(at: 1), secondTab.id)
        XCTAssertEqual(state.tabID(at: 2), thirdTab.id)
        XCTAssertNil(state.tabID(at: 8))
    }

    func testWorkspaceModePaintsTwilightWallpaperBehindChrome() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let mainWindowSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"), encoding: .utf8)
        let wallpaperSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Components/TwilightWallpaperView.swift"), encoding: .utf8)

        XCTAssertTrue(mainWindowSource.contains("TwilightWallpaperView(theme: store.currentTwilightTheme)"))
        XCTAssertTrue(mainWindowSource.contains("ArgoChromeTint.resolved(for: store.currentTwilightTheme)"))
        XCTAssertTrue(wallpaperSource.contains("RadialGradient"))
        XCTAssertTrue(wallpaperSource.contains("LinearGradient"))
        XCTAssertTrue(wallpaperSource.contains("center: UnitPoint(x: 0.82, y: 0.64)"))
    }

    func testSidebarUsesTwilightPromptAndSingleOuterSurface() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let sidebarSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Sidebar/WorkspaceSidebarView.swift"), encoding: .utf8)
        let mainWindowSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"), encoding: .utf8)

        XCTAssertTrue(sidebarSource.contains("Text(\"❯\")"))
        XCTAssertFalse(sidebarSource.contains("Image(systemName: \"magnifyingglass\")"))
        XCTAssertTrue(mainWindowSource.contains("ArgoTheme.glassSide"))
        XCTAssertFalse(sidebarSource.contains("ArgoTheme.sidebarBackground, in: RoundedRectangle"))
    }

    func testTerminalSurfaceUsesTwilightScrimAndHorizonGlow() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let workspaceDetailSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"), encoding: .utf8)

        XCTAssertTrue(workspaceDetailSource.contains("TwilightTerminalScrim()"))
        XCTAssertTrue(workspaceDetailSource.contains("TwilightHorizonGlow()"))
        XCTAssertTrue(workspaceDetailSource.contains("LinearGradient("))
        XCTAssertTrue(workspaceDetailSource.contains("ArgoTheme.scrimStrong"))
        XCTAssertTrue(workspaceDetailSource.contains("ArgoTheme.scrimSoft"))
        XCTAssertFalse(workspaceDetailSource.contains("Rectangle().fill(.ultraThinMaterial)\n                    Color.black.opacity(opaqueSurfaceScrimOpacity)"))
    }

    func testTerminalLocalChromeUsesPromptGlyph() throws {
        let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let terminalChromeSource = try String(contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"), encoding: .utf8)

        XCTAssertTrue(terminalChromeSource.contains("Text(\"❯\")"))
        XCTAssertFalse(terminalChromeSource.contains("Image(systemName: \"chevron.right\")"))
        XCTAssertTrue(terminalChromeSource.contains("ArgoTheme.glassCardH"))
    }
}
