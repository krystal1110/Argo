//
//  TwilightThemeTests.swift
//  ArgoTests
//

import XCTest
@testable import Argo

final class TwilightThemeTests: XCTestCase {
    func testDefaultSeedMatchesCurrentPreview() {
        XCTAssertEqual(TwilightTheme.defaultSeedHex, "#7aa2f7")

        let theme = TwilightTheme.default

        XCTAssertEqual(theme.seedHex, "#7aa2f7")
        XCTAssertEqual(theme.ghostty.accent, "#6f9af6")
        XCTAssertEqual(theme.ghostty.background, "#0e1420")
        XCTAssertEqual(theme.ghostty.foreground, "#eeeff2")
        XCTAssertEqual(theme.ghostty.palette[0], "#1e2b3e")
        XCTAssertEqual(theme.ghostty.palette[1], "#eb5c88")
        XCTAssertEqual(theme.ghostty.palette[2], "#37e689")
        XCTAssertEqual(theme.ghostty.palette[3], "#6f9af6")
        XCTAssertEqual(theme.ghostty.palette[4], "#5ca0eb")
        XCTAssertEqual(theme.ghostty.palette[5], "#e26eed")
        XCTAssertEqual(theme.ghostty.palette[6], "#53d9ea")
        XCTAssertEqual(theme.ghostty.palette[7], "#cdcfd6")
        XCTAssertEqual(theme.ghostty.palette[15], "#f4f5f6")
    }

    func testPresetsMatchPreviewOrderAndSeeds() {
        XCTAssertEqual(TwilightTheme.presets.map(\.id), [
            "catppuccinMocha",
            "tokyoNight",
            "dracula",
            "nord",
            "gruvbox",
            "rosePine",
        ])
        XCTAssertEqual(TwilightTheme.presets.map(\.seedHex), [
            "#cba6f7",
            "#7aa2f7",
            "#bd93f9",
            "#88c0d0",
            "#fabd2f",
            "#ebbcba",
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

    func testOldPresetSeedsMigrateToCurrentPreviewSeeds() {
        XCTAssertEqual(TwilightTheme.migratedSeedHex("#ffb066"), "#fabd2f")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("#7af0c0"), "#88c0d0")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("#5cc8ff"), "#7aa2f7")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("#ff9ec4"), "#ebbcba")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("#ff7a59"), "#bd93f9")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("abc"), "#aabbcc")
        XCTAssertEqual(TwilightTheme.migratedSeedHex("not-a-color"), "#7aa2f7")
    }

    func testSeedNormalizationSupportsShortHexAndFallback() {
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("#abc"), "#aabbcc")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("ABCDEF"), "#abcdef")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("  #5cc8ff  "), "#5cc8ff")
        XCTAssertEqual(TwilightTheme.normalizedSeedHex("not-a-color"), TwilightTheme.defaultSeedHex)
        XCTAssertEqual(TwilightTheme.generate(seed: "not-a-color").seedHex, TwilightTheme.defaultSeedHex)
    }

    func testSurfacePaletteMatchesPreviewTintFormula() {
        let catppuccin = TwilightTheme.surfacePalette(seed: "#cba6f7")

        XCTAssertEqual(catppuccin.app.rounded255, [18, 17, 25])
        XCTAssertEqual(catppuccin.glassSide.rounded255, [25, 22, 33])
        XCTAssertEqual(catppuccin.glassRail.rounded255, [20, 18, 28])
        XCTAssertEqual(catppuccin.glassCard.rounded255, [38, 35, 49])
        XCTAssertEqual(catppuccin.glassCardH.rounded255, [47, 44, 61])
        XCTAssertEqual(catppuccin.topGlass.rounded255, [24, 22, 32])
        XCTAssertEqual(catppuccin.term.rounded255, [13, 12, 19])
        XCTAssertEqual(catppuccin.scrim.rounded255, [12, 10, 18])
        XCTAssertEqual(catppuccin.dock.rounded255, [25, 22, 33])
        XCTAssertEqual(catppuccin.toast.rounded255, [26, 24, 35])

        XCTAssertEqual(TwilightTheme.surfacePalette(seed: "#7aa2f7").app.rounded255, [16, 18, 25])
        XCTAssertEqual(TwilightTheme.surfacePalette(seed: "#fabd2f").app.rounded255, [21, 20, 19])
    }

    func testOpacityModelMatchesPreviewTargets() {
        let transparent = TwilightTheme.opacityModel(percent: 0)
        XCTAssertEqual(transparent.appAlpha, 0)
        XCTAssertEqual(transparent.glassSideAlpha, 0)
        XCTAssertEqual(transparent.termAlpha, 0)
        XCTAssertEqual(transparent.scrim2Alpha, 0)

        let defaults = TwilightTheme.opacityModel(percent: 90)
        XCTAssertEqual(defaults.percent, 90)
        XCTAssertEqual(defaults.appAlpha, 0.315, accuracy: 0.0001)
        XCTAssertEqual(defaults.glassSideAlpha, 0.90, accuracy: 0.0001)
        XCTAssertEqual(defaults.termAlpha, 0.585, accuracy: 0.0001)
        XCTAssertEqual(defaults.scrim2Alpha, 0.405, accuracy: 0.0001)
        XCTAssertEqual(defaults.softFillAlpha, 0.405, accuracy: 0.0001)

        let opaque = TwilightTheme.opacityModel(percent: 100)
        XCTAssertEqual(opaque.appAlpha, 0.35, accuracy: 0.0001)
        XCTAssertEqual(opaque.glassRailAlpha, 1, accuracy: 0.0001)
        XCTAssertEqual(opaque.termAlpha, 0.65, accuracy: 0.0001)
        XCTAssertEqual(opaque.toastAlpha, 1, accuracy: 0.0001)
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

private extension TwilightRGBColor {
    var rounded255: [Int] {
        [
            Int(red.rounded()),
            Int(green.rounded()),
            Int(blue.rounded()),
        ]
    }
}
