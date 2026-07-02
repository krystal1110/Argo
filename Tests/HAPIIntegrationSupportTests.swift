//
//  HAPIIntegrationSupportTests.swift
//  ArgoTests
//
//  Author: Codex
//

import XCTest
@testable import Argo

final class HAPIIntegrationSupportTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LocalizationManager.shared.updateSelectedLanguage(.english)
    }

    override func tearDown() {
        LocalizationManager.shared.updateSelectedLanguage(.automatic)
        super.tearDown()
    }

    func testParseExecutablePathReturnsFirstAbsolutePath() {
        let output = """

        /opt/homebrew/bin/hapi
        /usr/local/bin/hapi
        """

        XCTAssertEqual(HAPIIntegrationCatalog.parseExecutablePath(output), "/opt/homebrew/bin/hapi")
    }

    func testInstallationUsesLaunchAsPrimaryAction() {
        let installation = HAPIInstallationStatus(executablePath: "/opt/homebrew/bin/hapi")

        XCTAssertEqual(installation.primaryActionTitle, "Open HAPI Menu")
        XCTAssertEqual(installation.primaryActionHelpText, "Open the HAPI menu")
    }

    func testParseCodexVersionExtractsSemanticVersion() {
        XCTAssertEqual(
            HAPIIntegrationCatalog.parseCodexVersion("codex-cli 0.142.5\n"),
            HAPICodexVersion(major: 0, minor: 142, patch: 5)
        )
        XCTAssertEqual(
            HAPIIntegrationCatalog.parseCodexVersion("codex 1.2.3"),
            HAPICodexVersion(major: 1, minor: 2, patch: 3)
        )
    }

    func testCodexVersionSupportMatchesHAPIMinimum() {
        XCTAssertTrue(HAPIIntegrationCatalog.isSupportedCodexVersion(HAPICodexVersion(major: 0, minor: 124, patch: 0)))
        XCTAssertTrue(HAPIIntegrationCatalog.isSupportedCodexVersion(HAPICodexVersion(major: 0, minor: 142, patch: 5)))
        XCTAssertFalse(HAPIIntegrationCatalog.isSupportedCodexVersion(HAPICodexVersion(major: 0, minor: 123, patch: 9)))
    }

    func testInstallationReportsUsableCodexCLI() {
        let installation = HAPIInstallationStatus(
            executablePath: "/opt/homebrew/bin/hapi",
            codexExecutablePath: "/Applications/Codex.app/Contents/Resources/codex",
            codexVersion: HAPICodexVersion(major: 0, minor: 142, patch: 5)
        )

        XCTAssertTrue(installation.hasUsableCodexCLI)
    }
}
