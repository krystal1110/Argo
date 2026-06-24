//
//  ArgoGhosttyConfigTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class ArgoGhosttyConfigTests: XCTestCase {
    func testManagedConfigContentsIncludeFontOverrides() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalFontFamily: "JetBrains Mono",
                terminalFontSize: 14.2
            )
        )

        XCTAssertTrue(contents.contains("font-family = \"JetBrains Mono\""))
        XCTAssertTrue(contents.contains("font-size = 14"))
    }

    func testManagedConfigContentsIncludesDefaultTranslucentBackground() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertTrue(contents.contains("background-opacity = 0.76"))
        XCTAssertTrue(contents.contains("background-blur = true"))
    }

    func testManagedConfigContentsIncludeBackgroundAppearanceOverrides() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalBackgroundOpacity: 0.65,
                terminalBackgroundBlur: true
            )
        )

        XCTAssertTrue(contents.contains("background-opacity = 0.65"))
        XCTAssertTrue(contents.contains("background-blur = true"))
    }
}
