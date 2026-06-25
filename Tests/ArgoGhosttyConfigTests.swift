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

    func testManagedConfigContentsIncludesDefaultTwilightOpacityWithoutBlur() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertTrue(contents.contains("background-opacity = 0.50"))
        XCTAssertFalse(contents.contains("background-blur = true"))
    }

    func testManagedConfigContentsUseCurrentTwilightThemeByDefault() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertTrue(contents.contains("# theme: Twilight #7aa2f7"))
        XCTAssertTrue(contents.contains("background = #0e1420"))
        XCTAssertTrue(contents.contains("foreground = #eeeff2"))
        XCTAssertTrue(contents.contains("palette = 0=#1e2b3e"))
        XCTAssertTrue(contents.contains("palette = 15=#f4f5f6"))
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

        XCTAssertTrue(contents.contains("# theme: Twilight #fabd2f"))
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

    func testManagedConfigContentsUseGhosttyOpacitySeparatelyFromTwilightOpacity() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalBackgroundOpacity: 0.55,
                terminalBackgroundBlur: true,
                twilightThemeEnabled: true,
                twilightOpacityPercent: 65
            )
        )

        XCTAssertTrue(contents.contains("background-opacity = 0.55"))
        XCTAssertFalse(contents.contains("background-opacity = 0.65"))
        XCTAssertFalse(contents.contains("background-blur = true"))
    }

    func testManagedConfigContentsAllowFullyTransparentGhosttyBackground() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(terminalBackgroundOpacity: 0)
        )

        XCTAssertTrue(contents.contains("background-opacity = 0.00"))
    }

    func testManagedConfigContentsAllowBlurOnlyOutsideTwilight() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalBackgroundOpacity: 0.65,
                terminalBackgroundBlur: true,
                twilightThemeEnabled: false
            )
        )

        XCTAssertTrue(contents.contains("background-opacity = 0.65"))
        XCTAssertTrue(contents.contains("background-blur = true"))
    }
}
