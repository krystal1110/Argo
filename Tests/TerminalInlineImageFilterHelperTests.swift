//
//  TerminalInlineImageFilterHelperTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest

final class TerminalInlineImageFilterHelperTests: XCTestCase {
    func testHelperTranslatesOSC1337PNGToKittyGraphics() throws {
        let helper = try compileHelper()
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
        let output = try runHelper(helper, script: #"printf '\033]1337;File=name=test.png:inline=1:\#(pngBase64)\a'"#)

        XCTAssertTrue(output.contains("\u{1B}_Ga=T,f=100,m=0;"))
        XCTAssertTrue(output.contains(pngBase64))
        XCTAssertFalse(output.contains("1337;File="))
    }

    func testHelperLeavesNonPNGOSC1337FileSequenceUntouched() throws {
        let helper = try compileHelper()
        let jpegBase64 = "/9j/4AAQSkZJRgABAQAAAQABAAD"
        let output = try runHelper(helper, script: #"printf '\033]1337;File=name=test.jpg:inline=1:\#(jpegBase64)\033\\'"#)

        XCTAssertTrue(output.contains("1337;File=name=test.jpg:inline=1:\(jpegBase64)"))
        XCTAssertTrue(output.contains("\u{1B}\\"))
        XCTAssertFalse(output.contains("\u{1B}_G"))
    }

    func testHelperPassesPlainTextThrough() throws {
        let helper = try compileHelper()
        let output = try runHelper(helper, script: #"printf 'hello\nworld\n'"#)

        XCTAssertTrue(
            output == "hello\r\nworld\r\n" || output == "hello\nworld\n",
            "unexpected plain text output: \(output.debugDescription)"
        )
    }

    func testXcodeProjectBuildsOSCFilterIntoResources() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: rootURL.appendingPathComponent("Argo.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("Compile OSC Filter"))
        XCTAssertTrue(project.contains("$(SRCROOT)/tools/argo-osc-filter.c"))
        XCTAssertTrue(project.contains("$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/argo-osc-filter"))
        XCTAssertTrue(project.contains("8C1D2E3F4A5B6C7D8E9F0002 /* Compile OSC Filter */"))
    }

    private func compileHelper() throws -> URL {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = rootURL.appendingPathComponent("tools/argo-osc-filter.c")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-osc-filter-\(UUID().uuidString)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "clang",
            "-O2",
            "-Wall",
            "-o",
            outputURL.path,
            sourceURL.path,
        ]
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            XCTFail("helper compile failed: \(message)")
        }

        return outputURL
    }

    private func runHelper(_ helper: URL, script: String) throws -> String {
        let process = Process()
        process.executableURL = helper
        process.arguments = ["/bin/sh", "-lc", script]

        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
