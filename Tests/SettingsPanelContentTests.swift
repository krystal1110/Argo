//
//  SettingsPanelContentTests.swift
//  ArgoTests
//
//  Author: krystal
//

import Foundation
import XCTest
@testable import Argo

final class SettingsPanelContentTests: XCTestCase {
    func testSettingsPanelContentLivesInSingleSupportFile() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let supportDirectory = repositoryRoot.appendingPathComponent("Argo/Support")

        XCTAssertTrue(FileManager.default.fileExists(atPath: supportDirectory.appendingPathComponent("SettingsPanelContent.swift").path))

        let removedFileNames = [
            "SettingsGeneralPanelContent.swift",
            "SettingsSidebarPanelContent.swift",
            "SidebarIconEditorContent.swift"
        ]
        for fileName in removedFileNames {
            XCTAssertFalse(FileManager.default.fileExists(atPath: supportDirectory.appendingPathComponent(fileName).path))
        }
    }

    func testGeneralPanelShowsOnlyCoreSettings() {
        XCTAssertEqual(
            GeneralSettingsPanelContent.visibleSettings,
            [
                .appLanguage,
                .uiScale,
                .autoRefreshEnabled,
                .autoRefreshIntervalSeconds,
                .confirmQuitWhenCommandsRunning
            ]
        )
    }

    func testGeneralPanelRemovesLowValueSettingsFromVisibleControls() {
        let removedSettingIDs: Set<String> = [
            "autoClosePaneOnProcessExit",
            "fileWatcherEnabled",
            "systemNotificationsEnabled",
            "showArchivedWorkspaces",
            "showHAPIToolbarButton",
            "directoryTreeEnabled",
            "logLevel"
        ]

        XCTAssertTrue(removedSettingIDs.isDisjoint(with: Set(GeneralSettingsPanelContent.visibleSettings.map(\.rawValue))))
        XCTAssertTrue(removedSettingIDs.isDisjoint(with: Set(GeneralSettingsPanelSetting.allCases.map(\.rawValue))))
    }

    func testGeneralPanelGroupsStaySmallEnoughToScan() {
        XCTAssertEqual(GeneralSettingsPanelContent.visibleSections.count, 2)
        XCTAssertTrue(GeneralSettingsPanelContent.visibleSections.allSatisfy { $0.settings.count <= 3 })
    }

    func testSidebarPanelShowsOnlyVisibilitySettings() {
        XCTAssertEqual(
            SidebarSettingsPanelContent.visibleSettings,
            [
                .showSecondaryLabels,
                .showWorkspaceBadges,
                .showWorktreeBadges
            ]
        )
    }

    func testSidebarPanelRemovesColorAndDefaultIconSettings() {
        let removedSettingIDs: Set<String> = [
            "activityIndicatorPalette",
            "defaultRepositoryIcon",
            "defaultLocalTerminalIcon",
            "defaultWorktreeIcon"
        ]

        XCTAssertTrue(removedSettingIDs.isDisjoint(with: Set(SidebarSettingsPanelContent.visibleSettings.map(\.rawValue))))
        XCTAssertTrue(removedSettingIDs.isDisjoint(with: Set(SidebarSettingsPanelSetting.allCases.map(\.rawValue))))
    }

    func testIconEditorKeepsOnlyNonColorControlsVisible() {
        XCTAssertEqual(
            SidebarIconEditorContent.visibleControls,
            [
                .randomize,
                .symbol
            ]
        )
    }

    func testIconEditorRemovesExplicitColorControls() {
        let removedControlIDs: Set<String> = [
            "fillStyle",
            "palette"
        ]

        XCTAssertTrue(removedControlIDs.isDisjoint(with: Set(SidebarIconEditorContent.visibleControls.map(\.rawValue))))
        XCTAssertTrue(removedControlIDs.isDisjoint(with: Set(SidebarIconEditorControl.allCases.map(\.rawValue))))
    }
}
