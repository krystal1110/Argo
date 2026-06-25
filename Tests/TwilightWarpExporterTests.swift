import XCTest
@testable import Argo

final class TwilightWarpExporterTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArgoWarpExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testExporterWritesPresetYamlWithoutOpacityOrWallpaper() throws {
        let theme = TwilightTheme.generate(seed: "#cba6f7")

        let url = try TwilightWarpExporter.export(
            theme: theme,
            seedHex: "#cba6f7",
            directory: temporaryDirectory
        )

        XCTAssertEqual(url.lastPathComponent, "catppuccin.yaml")
        let yaml = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(yaml.contains("name: Catppuccin Mocha"))
        XCTAssertTrue(yaml.contains("accent: '#ad73f2'"))
        XCTAssertTrue(yaml.contains("background: '#0e1320'"))
        XCTAssertTrue(yaml.contains("foreground: '#f0eef2'"))
        XCTAssertTrue(yaml.contains("black:   '#1f283d'"))
        XCTAssertTrue(yaml.contains("white:   '#f5f4f6'"))
        XCTAssertFalse(yaml.contains("opacity"))
        XCTAssertFalse(yaml.contains("wallpaper"))
        XCTAssertFalse(yaml.contains("blur"))
    }

    func testExporterWritesCustomYamlSlugFromSeed() throws {
        let theme = TwilightTheme.generate(seed: "#123456")

        let url = try TwilightWarpExporter.export(
            theme: theme,
            seedHex: "#123456",
            directory: temporaryDirectory
        )

        XCTAssertEqual(url.lastPathComponent, "custom-123456.yaml")
        let yaml = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(yaml.contains("name: Custom #123456"))
    }
}
