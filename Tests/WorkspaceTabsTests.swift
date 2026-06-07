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

    func testTerminalChromeAndPanesShareOneOuterSurface() throws {
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

        XCTAssertTrue(workspaceDetailSource.contains("TerminalWorkspaceSurface {"))
        XCTAssertFalse(terminalPaneSource.contains(".clipShape(RoundedRectangle"))
        XCTAssertFalse(terminalPaneSource.contains(".background(paneFill, in: RoundedRectangle"))
        XCTAssertFalse(terminalPaneSource.contains(".shadow(color:"))
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

    func testTerminalChromeExposesInlineCategoryRename() throws {
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
        XCTAssertTrue(terminalChromeSource.contains("TextField(\"\", text: $renameDraft)"))
        XCTAssertTrue(workspaceDetailSource.contains("onRenameCategory: renameTerminalCategoryFromChrome"))
        XCTAssertTrue(workspaceDetailSource.contains("store.renameTab(in: workspace, tabID: categoryID, title: normalized)"))
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
}
