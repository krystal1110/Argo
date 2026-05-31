//
//  ArgoGhosttyConfigTests.swift
//  ArgoTests
//
//  Author: everettjf
//

import XCTest
@testable import Argo

final class ArgoGhosttyConfigTests: XCTestCase {
    func testManagedConfigContentsIncludeFontOverrides() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(
            settings: AppSettings(
                terminalFontFamily: "JetBrains Mono",
                terminalFontSize: 14.2
            )
        )

        XCTAssertTrue(contents.contains("font-family = \"JetBrains Mono\""))
        XCTAssertTrue(contents.contains("font-size = 14"))
    }

    func testManagedConfigContentsOnlyContainHeaderWithoutOverrides() {
        let contents = ArgoGhosttyConfigManager.managedConfigContents(settings: AppSettings())

        XCTAssertEqual(
            contents,
            "# Managed by Argo. Manual edits will be overwritten.\n"
        )
    }
}
