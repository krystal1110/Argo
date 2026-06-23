//
//  ArgoChromeTintTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class ArgoChromeTintTests: XCTestCase {
    func testColorfulPaletteUsesBalancedA2RegionStrengths() {
        let tint = ArgoChromeTint.resolved(for: .mint)

        XCTAssertEqual(tint.topFill.alpha, 0.20, accuracy: 0.0001)
        XCTAssertEqual(tint.leadingFill.alpha, 0.16, accuracy: 0.0001)
        XCTAssertEqual(tint.sidebarFill.alpha, 0.07, accuracy: 0.0001)
        XCTAssertEqual(tint.tabBarFill.alpha, 0.17, accuracy: 0.0001)
        XCTAssertEqual(tint.selectionFill.alpha, 0.21, accuracy: 0.0001)
        XCTAssertEqual(tint.glowFill.alpha, 0.10, accuracy: 0.0001)
        XCTAssertFalse(tint.isNeutral)
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
}
