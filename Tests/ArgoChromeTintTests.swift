//
//  ArgoChromeTintTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class ArgoChromeTintTests: XCTestCase {
    func testColorfulPaletteUsesBalancedA2RegionStrengths() {
        let tint = ArgoChromeTint.resolved(for: .mint)

        XCTAssertEqual(tint.topFill.alpha, 0.30, accuracy: 0.0001)
        XCTAssertEqual(tint.leadingFill.alpha, 0.28, accuracy: 0.0001)
        XCTAssertEqual(tint.sidebarFill.alpha, 0.16, accuracy: 0.0001)
        XCTAssertEqual(tint.tabBarFill.alpha, 0.28, accuracy: 0.0001)
        XCTAssertEqual(tint.selectionFill.alpha, 0.30, accuracy: 0.0001)
        XCTAssertEqual(tint.glowFill.alpha, 0.20, accuracy: 0.0001)
        XCTAssertFalse(tint.isNeutral)
    }

    func testTopChromeSurfaceComponentsResolveToStableOpaqueTint() {
        let tint = ArgoChromeTint.resolved(for: .mint)

        XCTAssertEqual(tint.topChromeSurfaceComponents.red, 0.2884, accuracy: 0.0001)
        XCTAssertEqual(tint.topChromeSurfaceComponents.green, 0.3848, accuracy: 0.0001)
        XCTAssertEqual(tint.topChromeSurfaceComponents.blue, 0.3534, accuracy: 0.0001)
    }

    func testNeutralPaletteUsesSofterStrengths() {
        let tint = ArgoChromeTint.resolved(for: .graphite)

        XCTAssertTrue(tint.isNeutral)
        XCTAssertLessThan(tint.topFill.alpha, ArgoChromeTint.resolved(for: .mint).topFill.alpha)
        XCTAssertLessThan(tint.sidebarFill.alpha, ArgoChromeTint.resolved(for: .mint).sidebarFill.alpha)
        XCTAssertLessThan(tint.tabBarFill.alpha, ArgoChromeTint.resolved(for: .mint).tabBarFill.alpha)
    }

    func testNilPaletteFallsBackToArgoAccent() {
        let tint = ArgoChromeTint.resolved(for: nil)

        XCTAssertEqual(tint.components, ArgoChromeTint.defaultAccentComponents)
        XCTAssertFalse(tint.isNeutral)
    }

    func testTwilightChromeTintUsesSeedAccent() {
        let theme = TwilightTheme.generate(seed: "#ffb066")
        let tint = ArgoChromeTint.resolved(for: theme)

        XCTAssertEqual(theme.seedHex, "#fabd2f")
        XCTAssertEqual(tint.components.hexString, "#fabd2f")
        XCTAssertFalse(tint.isNeutral)
        XCTAssertEqual(tint.topFill.alpha, 0.34, accuracy: 0.0001)
        XCTAssertEqual(tint.leadingFill.alpha, 0.38, accuracy: 0.0001)
        XCTAssertEqual(tint.sidebarFill.alpha, 0.42, accuracy: 0.0001)
    }

    func testTwilightStaticThemeTokensUseReferenceColors() {
        XCTAssertEqual(ArgoTheme.twilightDefault.seedHex, "#7aa2f7")
        XCTAssertEqual(ArgoTheme.accentHexForTests, "#6f9af6")
        XCTAssertEqual(ArgoTheme.localAccentHexForTests, "#53d9ea")
    }
}
