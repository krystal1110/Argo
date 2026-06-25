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

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
