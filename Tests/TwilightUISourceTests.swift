import XCTest

final class TwilightUISourceTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testWallpaperViewUsesImageBackgroundAndPreviewOverlay() throws {
        let source = try read("Argo/UI/Components/TwilightWallpaperView.swift")

        XCTAssertTrue(source.contains("AsyncImage"))
        XCTAssertTrue(source.contains("customImagePath"))
        XCTAssertTrue(source.contains("TwilightWallpaperPreset"))
        XCTAssertTrue(source.contains("linear-gradient(115deg"))
        XCTAssertTrue(source.contains("radial-gradient(120% 92%"))
        XCTAssertFalse(source.contains("theme.wallpaper.sunGlow"))
        XCTAssertFalse(source.contains("theme.wallpaper.skyWaterStops"))
    }

    func testMainWindowUsesDynamicTwilightSurfaces() throws {
        let source = try read("Argo/UI/MainWindowView.swift")

        XCTAssertTrue(source.contains("store.currentTwilightSurfacePalette"))
        XCTAssertTrue(source.contains("store.currentTwilightOpacity"))
        XCTAssertTrue(source.contains("TwilightWallpaperView("))
        XCTAssertTrue(source.contains("preset: store.appSettings.twilightWallpaperPreset ?? .desk"))
        XCTAssertTrue(source.contains("customImagePath: store.appSettings.twilightCustomWallpaperPath"))
        XCTAssertFalse(source.contains(".background(ArgoTheme.glassSide)"))
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
        XCTAssertTrue(source.contains("scrim1Alpha"))
        XCTAssertTrue(source.contains("scrim2Alpha"))
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

    func testThemeDockExistsAndIsMountedInMainWindow() throws {
        let dock = try read("Argo/UI/Components/TwilightThemeDockView.swift")
        let main = try read("Argo/UI/MainWindowView.swift")

        XCTAssertTrue(dock.contains("struct TwilightThemeDockView"))
        XCTAssertTrue(dock.contains("TwilightTheme.presets"))
        XCTAssertTrue(dock.contains("TwilightWallpaperPreset.allCases"))
        XCTAssertTrue(dock.contains("NSOpenPanel"))
        XCTAssertTrue(dock.contains("Slider("))
        XCTAssertTrue(dock.contains("TextField("))
        XCTAssertTrue(dock.contains("exportCurrentTwilightWarpTheme"))
        XCTAssertTrue(dock.contains("mv ~/Downloads/"))
        XCTAssertTrue(main.contains("TwilightThemeDockView("))
        XCTAssertTrue(main.contains(".padding(.trailing, 26)"))
        XCTAssertTrue(main.contains(".padding(.bottom, 26)"))
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
