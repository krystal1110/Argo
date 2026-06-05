//
//  PathFormattingTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class PathFormattingTests: XCTestCase {
    func testShellQuotedEscapesSingleQuotes() {
        XCTAssertEqual("/tmp/it's-argo".shellQuoted, "'/tmp/it'\\''s-argo'")
    }

    func testAbbreviatedPathUsesTildeInsideHomeDirectory() {
        let home = NSHomeDirectory()
        XCTAssertEqual("\(home)/src/argo".abbreviatedPath, "~/src/argo")
    }

    func testTerminalChromeDisplayPathUsesTildeForHomeDirectory() {
        let home = NSHomeDirectory()
        XCTAssertEqual(
            "\(home)/Documents/Claude 相关".terminalChromeDisplayPath,
            "~/Documents/Claude 相关"
        )
    }

    func testTerminalChromeDisplayPathKeepsAbsolutePathOutsideHomeDirectory() {
        XCTAssertEqual(
            "/tmp/Argo Scratch".terminalChromeDisplayPath,
            "/tmp/Argo Scratch"
        )
    }

    func testShellEscapedEscapesSpaces() {
        XCTAssertEqual(
            "/Users/eevv/Screen Studio Projects".shellEscaped,
            "/Users/eevv/Screen\\ Studio\\ Projects"
        )
    }

    func testShellEscapedEscapesShellMetacharacters() {
        XCTAssertEqual(
            "/tmp/a (b) & c$d'e\"f".shellEscaped,
            "/tmp/a\\ \\(b\\)\\ \\&\\ c\\$d\\'e\\\"f"
        )
    }

    func testShellEscapedLeavesPlainPathUnchanged() {
        XCTAssertEqual("/Users/eevv/src/argo".shellEscaped, "/Users/eevv/src/argo")
    }

    func testShellEscapedKeepsNonASCIIUnescaped() {
        XCTAssertEqual("/Users/eevv/文档".shellEscaped, "/Users/eevv/文档")
    }

    func testShellEscapedEmptyStringIsQuotedEmpty() {
        XCTAssertEqual("".shellEscaped, "''")
    }
}
