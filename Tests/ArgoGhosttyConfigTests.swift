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

    func testManagedConfigContentsUseTwilightThemeByDefault() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertTrue(contents.contains("background = #140d21"))
        XCTAssertTrue(contents.contains("foreground = #f2f0ee"))
        XCTAssertTrue(contents.contains("palette = 0=#251c40"))
        XCTAssertTrue(contents.contains("palette = 15=#f6f5f4"))
        XCTAssertFalse(contents.contains("theme = "))
    }

    func testManagedConfigContentsIgnoreGhosttyThemeWhenTwilightIsEnabled() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalTheme: "Catppuccin Mocha",
                twilightThemeEnabled: true,
                twilightThemeSeedHex: "#ffb066"
            )
        )

        XCTAssertTrue(contents.contains("# theme: Twilight #ffb066"))
        XCTAssertTrue(contents.contains("background = #140d21"))
        XCTAssertFalse(contents.contains("theme = Catppuccin Mocha"))
    }

    func testManagedConfigContentsKeepGhosttyThemeWhenTwilightIsDisabled() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalTheme: "Catppuccin Mocha",
                twilightThemeEnabled: false
            )
        )

        XCTAssertFalse(contents.contains("# theme: Twilight"))
        XCTAssertTrue(contents.contains("Catppuccin Mocha"))
    }

    func testManagedConfigContentsKeepOpacityAndBlurWithTwilight() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalBackgroundOpacity: 0.65,
                terminalBackgroundBlur: true,
                twilightThemeEnabled: true
            )
        )

        XCTAssertTrue(contents.contains("background-opacity = 0.65"))
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
