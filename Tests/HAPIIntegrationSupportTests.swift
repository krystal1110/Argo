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

    func testLANHubAddressPrefersPrimaryInterfaceIPv4() {
        let addresses = [
            HAPINetworkInterfaceAddress(interfaceName: "utun4", ipAddress: "100.64.0.9"),
            HAPINetworkInterfaceAddress(interfaceName: "en1", ipAddress: "192.168.4.8"),
            HAPINetworkInterfaceAddress(interfaceName: "en0", ipAddress: "10.21.18.15"),
        ]

        XCTAssertEqual(HAPILANHubEnvironment.preferredIPv4Address(from: addresses), "10.21.18.15")
    }

    func testLANHubAddressFallsBackToFirstUsableIPv4() {
        let addresses = [
            HAPINetworkInterfaceAddress(interfaceName: "lo0", ipAddress: "127.0.0.1"),
            HAPINetworkInterfaceAddress(interfaceName: "bridge100", ipAddress: "172.16.0.2"),
            HAPINetworkInterfaceAddress(interfaceName: "utun4", ipAddress: "100.64.0.9"),
        ]

        XCTAssertEqual(HAPILANHubEnvironment.preferredIPv4Address(from: addresses), "172.16.0.2")
    }

    func testLANHubAddressRejectsLoopbackAndWildcardAddresses() {
        let addresses = [
            HAPINetworkInterfaceAddress(interfaceName: "lo0", ipAddress: "127.0.0.1"),
            HAPINetworkInterfaceAddress(interfaceName: "en0", ipAddress: "0.0.0.0"),
        ]

        XCTAssertNil(HAPILANHubEnvironment.preferredIPv4Address(from: addresses))
    }

    func testLANHubEnvironmentUsesLANAddressWhenAvailable() {
        let environment = HAPILANHubEnvironment.environment(
            merging: ["PATH": "/opt/homebrew/bin:/usr/bin"],
            localIPv4Address: "10.21.18.15"
        )

        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/usr/bin")
        XCTAssertEqual(environment["HAPI_LISTEN_HOST"], "0.0.0.0")
        XCTAssertEqual(environment["HAPI_LISTEN_PORT"], "3006")
        XCTAssertEqual(environment["HAPI_PUBLIC_URL"], "http://10.21.18.15:3006")
    }

    func testLANHubEnvironmentFallsBackToLocalhostPublicURL() {
        let environment = HAPILANHubEnvironment.environment(
            merging: [:],
            localIPv4Address: nil
        )

        XCTAssertEqual(environment["HAPI_LISTEN_HOST"], "0.0.0.0")
        XCTAssertEqual(environment["HAPI_LISTEN_PORT"], "3006")
        XCTAssertEqual(environment["HAPI_PUBLIC_URL"], "http://localhost:3006")
    }
}
