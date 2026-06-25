import XCTest

final class TwilightUISourceTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testMainWindowUsesDynamicTwilightSurfaces() throws {
        let source = try read("Argo/UI/MainWindowView.swift")

        XCTAssertTrue(source.contains("store.currentTwilightSurfacePalette"))
        XCTAssertTrue(source.contains("store.currentTwilightOpacity"))
        XCTAssertFalse(source.contains("TwilightWallpaperView("))
        XCTAssertFalse(source.contains("twilightWallpaperPreset"))
        XCTAssertFalse(source.contains("twilightCustomWallpaperPath"))
        XCTAssertFalse(source.contains(".background(ArgoTheme.glassSide)"))
    }

    func testMainWindowCommandAndStatusUseDynamicTwilightThemeColors() throws {
        let source = try read("Argo/UI/MainWindowView.swift")

        XCTAssertTrue(source.contains("theme: store.appSettings.twilightThemeEnabled ? store.currentTwilightTheme : nil"))
        XCTAssertTrue(source.contains("private var commandAccentColor: Color"))
        XCTAssertTrue(source.contains("theme?.amber.color ?? ArgoTheme.amber"))
        XCTAssertTrue(source.contains("theme?.amber2.color ?? ArgoTheme.amber2"))
        XCTAssertTrue(source.contains("theme?.green.color ?? ArgoTheme.green"))
        XCTAssertFalse(source.contains(".fill(ArgoTheme.amber.opacity(0.12))"))
        XCTAssertFalse(source.contains(".stroke(ArgoTheme.amber.opacity(0.32), lineWidth: 1)"))
        XCTAssertFalse(source.contains(".fill(isRunning ? ArgoTheme.green : ArgoTheme.textFaint)"))
    }

    func testGlobalRailUsesDynamicTwilightSurface() throws {
        let source = try read("Argo/UI/Components/GlobalModeRailView.swift")

        XCTAssertTrue(source.contains("surfacePalette.color(\\.glassRail"))
        XCTAssertTrue(source.contains("glassRailAlpha"))
        XCTAssertFalse(source.contains(".background(ArgoTheme.glassRail)"))
    }

    func testTerminalSurfaceDoesNotUseBlurView() throws {
        let source = try read("Argo/UI/Workspace/WorkspaceDetailView.swift")

        XCTAssertTrue(source.contains("surfacePalette"))
        let terminalSurfaceSource = try extract(
            "private struct TerminalWorkspaceSurface<Content: View",
            from: source,
            endingBefore: "private enum TerminalWorkspaceSurfaceStyle"
        )
        XCTAssertFalse(terminalSurfaceSource.contains("scrim1Alpha"))
        XCTAssertFalse(terminalSurfaceSource.contains("scrim2Alpha"))
        XCTAssertFalse(terminalSurfaceSource.contains("surfacePalette.scrim.color"))
        XCTAssertFalse(source.contains("TerminalBackgroundBlurView()"))
        XCTAssertFalse(source.contains("NSVisualEffectView"))
    }

    func testTerminalPaneAndChromeUseDynamicTwilightSurfaces() throws {
        let paneSource = try read("Argo/UI/Workspace/TerminalPaneView.swift")
        let chromeSource = try read("Argo/UI/Workspace/TerminalLocalChrome.swift")

        XCTAssertTrue(paneSource.contains("store.appSettings.twilightThemeEnabled || store.appSettings.terminalBackgroundOpacity < 1"))
        XCTAssertTrue(chromeSource.contains("surfacePalette.color(\\.glassCardH"))
        XCTAssertTrue(chromeSource.contains("glassCardHAlpha"))
        XCTAssertTrue(chromeSource.contains("surfacePalette.color(\\.glassCard"))
        XCTAssertTrue(chromeSource.contains("glassCardAlpha"))
    }

    func testSidebarSelectionUsesTwilightSubtleAmberRailInsteadOfBlueCard() throws {
        let source = try read("Argo/UI/Sidebar/WorkspaceSidebarView.swift")

        XCTAssertTrue(source.contains("NSGradient(colors: ["))
        XCTAssertTrue(source.contains("withAlphaComponent(0.05)"))
        XCTAssertTrue(source.contains("withAlphaComponent(0.65)"))
        XCTAssertTrue(source.contains("width: 2"))
        XCTAssertTrue(source.contains("let railVerticalInset"))
        XCTAssertTrue(source.contains("let railHeight"))
        XCTAssertFalse(source.contains("ArgoTheme.sidebarSelectionFill.setFill()"))
        XCTAssertFalse(source.contains("ArgoTheme.sidebarSelectionStroke"))
    }

    func testSidebarUsesDynamicTwilightThemeForSelectionIconsAndBadges() throws {
        let source = try read("Argo/UI/Sidebar/WorkspaceSidebarView.swift")

        XCTAssertTrue(source.contains("rowView.selectionColor"))
        XCTAssertTrue(source.contains("store?.currentTwilightTheme.amber.nsColor"))
        XCTAssertTrue(source.contains("private enum TwilightSidebarIconAccent"))
        XCTAssertTrue(source.contains("SidebarIconPaletteDescriptor.twilight("))
        XCTAssertTrue(source.contains("softFillAlpha * 0.08"))
        XCTAssertTrue(source.contains("return 52"))
        XCTAssertTrue(source.contains("theme: twilightTheme"))
        XCTAssertTrue(source.contains("usesSecondaryTwilightAccent: workspace.supportsRepositoryFeatures"))
        XCTAssertFalse(source.contains("usesSecondaryTwilightAccent: !workspace.supportsRepositoryFeatures"))
        XCTAssertFalse(source.contains("let amber = NSColor(TwilightTheme.default.amber.color)"))
        XCTAssertFalse(source.contains("return (store?.appSettings.sidebarShowsSecondaryLabels ?? true) ? 33 : 24"))
    }

    func testSidebarRefreshFingerprintIncludesTwilightThemeState() throws {
        let source = try read("Argo/UI/Sidebar/WorkspaceSidebarView.swift")

        XCTAssertTrue(source.contains("settings.twilightThemeEnabled.description"))
        XCTAssertTrue(source.contains("settings.twilightThemeSeedHex"))
        XCTAssertTrue(source.contains("settings.twilightOpacityPercent.description"))
        XCTAssertTrue(source.contains("settings.uiScale.description"))
    }

    func testTwilightControlsLiveInSettingsInsteadOfFloatingDock() throws {
        let settings = try read("Argo/UI/Sheets/SettingsSheet.swift")
        let main = try read("Argo/UI/MainWindowView.swift")

        XCTAssertTrue(settings.contains("TwilightTheme.presets"))
        XCTAssertTrue(settings.contains("ColorPicker("))
        XCTAssertTrue(settings.contains("Slider("))
        XCTAssertTrue(settings.contains("TextField("))
        XCTAssertTrue(settings.contains("exportCurrentTwilightWarpTheme"))
        XCTAssertTrue(settings.contains("settings.twilight.exportWarp"))
        XCTAssertFalse(settings.contains("TwilightWallpaperPreset.allCases"))
        XCTAssertFalse(settings.contains("chooseCustomWallpaper()"))
        XCTAssertFalse(settings.contains("settings.twilight.customWallpaper"))
        XCTAssertFalse(settings.contains("settings.twilight.wallpaper.none"))
        XCTAssertFalse(main.contains("TwilightThemeDockView("))
        XCTAssertFalse(main.contains(".padding(.trailing, 26)"))
        XCTAssertFalse(main.contains(".padding(.bottom, 26)"))
    }

    func testSettingsUseTwilightOpacityPercentWithoutWallpaperControls() throws {
        let source = try read("Argo/UI/Sheets/SettingsSheet.swift")

        XCTAssertTrue(source.contains("twilightOpacityPercent"))
        XCTAssertTrue(source.contains("ColorPicker("))
        XCTAssertTrue(source.contains("exportWarpTheme()"))
        XCTAssertTrue(source.contains("0...100"))
        XCTAssertFalse(source.contains("TwilightWallpaperPreset.allCases"))
        XCTAssertFalse(source.contains("chooseCustomWallpaper()"))
        XCTAssertFalse(source.contains("twilightWallpaperPreset"))
        XCTAssertFalse(source.contains("twilightCustomWallpaperPath"))
        XCTAssertFalse(source.contains("Slider(value: $appSettings.terminalBackgroundOpacity, in: 0.5...1"))
    }

    func testGhosttyOpacityControlsStaySeparateFromTwilightOpacity() throws {
        let settings = try read("Argo/UI/Sheets/SettingsSheet.swift")
        let store = try read("Argo/App/WorkspaceStore.swift")

        XCTAssertTrue(settings.contains("Text(localized(\"settings.general.terminal.backgroundOpacity\"))"))
        XCTAssertTrue(settings.contains("Slider(value: terminalBackgroundOpacityBinding, in: 0...1, step: 0.05)"))
        XCTAssertTrue(settings.contains("set: { appSettings.terminalBackgroundOpacity = min(max($0, 0), 1) }"))
        XCTAssertFalse(settings.contains("if !appSettings.twilightThemeEnabled {\n                        HStack {\n                            Text(localized(\"settings.general.terminal.backgroundOpacity\"))"))
        XCTAssertFalse(settings.contains("appSettings.terminalBackgroundOpacity = Double(appSettings.twilightOpacityPercent) / 100"))
        XCTAssertFalse(store.contains("settings.terminalBackgroundOpacity = Double(settings.twilightOpacityPercent) / 100"))
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func extract(_ marker: String, from source: String, endingBefore endMarker: String) throws -> String {
        guard let startRange = source.range(of: marker),
              let endRange = source.range(of: endMarker, range: startRange.upperBound..<source.endIndex) else {
            XCTFail("Could not extract source block from \(marker) to \(endMarker)")
            return ""
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }
}
