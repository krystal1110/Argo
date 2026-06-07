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

    func testTerminalTabsUseIntegratedChromeInsteadOfSeparateTopStrip() throws {
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
        XCTAssertTrue(workspaceDetailSource.contains("tabs: workspace.tabs"))
        XCTAssertTrue(workspaceDetailSource.contains("activeTabID: workspace.activeTabID"))
        XCTAssertTrue(workspaceDetailSource.contains("onSelectTab: selectTerminalTabFromChrome"))
        XCTAssertTrue(terminalChromeSource.contains("ForEach(tabs)"))
        XCTAssertFalse(terminalChromeSource.contains(".frame(maxWidth: 430"))
        XCTAssertTrue(terminalChromeSource.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
    }

    func testSplitPaneChromeUsesPaneDescriptorsAndFocusCallback() throws {
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

        XCTAssertTrue(terminalChromeSource.contains("struct TerminalChromePaneDescriptor"))
        XCTAssertTrue(terminalChromeSource.contains("let paneDescriptors: [TerminalChromePaneDescriptor]"))
        XCTAssertTrue(terminalChromeSource.contains("ForEach(paneDescriptors)"))
        XCTAssertTrue(terminalChromeSource.contains("onSelectPane(descriptor.paneID)"))
        XCTAssertTrue(workspaceDetailSource.contains("paneDescriptors: terminalChromePaneDescriptors"))
        XCTAssertTrue(workspaceDetailSource.contains("onSelectPane: focusTerminalPaneFromChrome"))
    }

    func testSplitPaneChromeKeepsSinglePanePathPillFallback() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("if paneDescriptors.count > 1"))
        XCTAssertTrue(terminalChromeSource.contains("} else if tabs.count > 1 {"))
        XCTAssertTrue(terminalChromeSource.contains("pathPill"))
    }

    func testSplitPaneChromeKeepsTerminalTabsReachableWhenMultipleTabsExist() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("if paneDescriptors.count > 1 && tabs.count > 1"))
        XCTAssertTrue(terminalChromeSource.contains("combinedTabAndPaneStrip"))
        XCTAssertTrue(terminalChromeSource.contains("} else if paneDescriptors.count > 1 {"))
        XCTAssertTrue(terminalChromeSource.contains("} else if tabs.count > 1 {"))

        let combinedStripRange = try XCTUnwrap(terminalChromeSource.range(of: "private var combinedTabAndPaneStrip"))
        let combinedStripSource = String(terminalChromeSource[combinedStripRange.lowerBound...])
        XCTAssertTrue(combinedStripSource.contains("terminalTabStrip"))
        XCTAssertTrue(combinedStripSource.contains("paneChipStrip"))
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
