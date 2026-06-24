//
//  TwilightThemeTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class TwilightThemeTests: XCTestCase {
    func testDefaultSeedMatchesReferenceWarpTheme() {
        let theme = TwilightTheme.generate(seed: "#ffb066")

        XCTAssertEqual(theme.seedHex, "#ffb066")
        XCTAssertEqual(theme.ghostty.accent, "#fcb069")
        XCTAssertEqual(theme.ghostty.background, "#140d21")
        XCTAssertEqual(theme.ghostty.foreground, "#f2f0ee")
        XCTAssertEqual(theme.ghostty.palette[0], "#251c40")
        XCTAssertEqual(theme.ghostty.palette[1], "#eb605c")
        XCTAssertEqual(theme.ghostty.palette[2], "#37e646")
        XCTAssertEqual(theme.ghostty.palette[3], "#fcb069")
        XCTAssertEqual(theme.ghostty.palette[4], "#5c70eb")
        XCTAssertEqual(theme.ghostty.palette[5], "#ed6ecd")
        XCTAssertEqual(theme.ghostty.palette[6], "#53eac0")
        XCTAssertEqual(theme.ghostty.palette[7], "#d6d1cd")
        XCTAssertEqual(theme.ghostty.palette[8], "#584983")
        XCTAssertEqual(theme.ghostty.palette[9], "#f08c89")
        XCTAssertEqual(theme.ghostty.palette[10], "#69ec74")
        XCTAssertEqual(theme.ghostty.palette[11], "#f9d8b9")
        XCTAssertEqual(theme.ghostty.palette[12], "#8998f0")
        XCTAssertEqual(theme.ghostty.palette[13], "#f39bdd")
        XCTAssertEqual(theme.ghostty.palette[14], "#80efd1")
        XCTAssertEqual(theme.ghostty.palette[15], "#f6f5f4")
    }

    func testPresetsAreStableAndGenerateThemes() {
        XCTAssertEqual(TwilightTheme.presets.map(\.seedHex), [
            "#ffb066",
            "#7af0c0",
            "#5cc8ff",
            "#ff9ec4",
            "#ff7a59",
        ])

        for preset in TwilightTheme.presets {
            let theme = TwilightTheme.generate(seed: preset.seedHex)

            XCTAssertEqual(theme.seedHex, preset.seedHex)
            XCTAssertEqual(theme.ghostty.palette.count, 16)
            XCTAssertTrue(theme.ghostty.palette.allSatisfy { $0.value.hasPrefix("#") && $0.value.count == 7 })
            XCTAssertGreaterThanOrEqual(theme.amber.lightness, 58, preset.seedHex)
            XCTAssertLessThanOrEqual(theme.amber.lightness, 70, preset.seedHex)
            XCTAssertGreaterThanOrEqual(theme.amber2.lightness, 72, preset.seedHex)
            XCTAssertLessThanOrEqual(theme.amber2.lightness, 86, preset.seedHex)
        }
    }

    func testSeedNormalizationSupportsShortHexAndFallback() {
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("#abc"), "#aabbcc")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("ABCDEF"), "#abcdef")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("  #5cc8ff  "), "#5cc8ff")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("not-a-color"), TwilightTheme.defaultSeedHex)
        XCTAssertEqual(TwilightTheme.generate(seed: "not-a-color").seedHex, TwilightTheme.defaultSeedHex)
    }

    func testAnsiSemanticHuesStayRecognizableAcrossExtremeSeeds() {
        for seed in ["#333333", "#ff0000", "#5cc8ff", "#7af0c0"] {
            let theme = TwilightTheme.generate(seed: seed)

            XCTAssertTrue((330...360).contains(theme.ghostty.normal.red.normalizedHue) || (0...28).contains(theme.ghostty.normal.red.normalizedHue), seed)
            XCTAssertTrue((108...166).contains(theme.ghostty.normal.green.normalizedHue), seed)
            XCTAssertTrue((188...234).contains(theme.ghostty.normal.blue.normalizedHue), seed)
        }
    }
}
