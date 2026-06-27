//
//  SidebarIconActivityColorResolverTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class SidebarIconActivityColorResolverTests: XCTestCase {
    func testTwilightThemeUsesThemeAccentInsteadOfFallbackPalette() {
        let theme = TwilightTheme.generate(seed: "#7aa2f7")

        let resolved = ArgoChromeTint.Components(
            color: SidebarIconActivityColorResolver.activityColor(
                twilightTheme: theme,
                fallbackPalette: .rose
            )
        )

        XCTAssertEqual(resolved.hexString, ArgoChromeTint.resolved(for: theme).components.hexString)
        XCTAssertNotEqual(resolved.hexString, ArgoChromeTint.Components(color: SidebarIconPalette.rose.descriptor.gradientEnd).hexString)
    }

    func testPaletteFallbackIsUsedWhenTwilightThemeIsUnavailable() {
        let resolved = ArgoChromeTint.Components(
            color: SidebarIconActivityColorResolver.activityColor(
                twilightTheme: nil,
                fallbackPalette: .rose
            )
        )

        XCTAssertEqual(resolved.hexString, ArgoChromeTint.Components(color: SidebarIconPalette.rose.descriptor.gradientEnd).hexString)
    }
}
