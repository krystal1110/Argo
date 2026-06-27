//
//  TerminalInlineImageFilterTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class TerminalInlineImageFilterTests: XCTestCase {
    private let helperPath = "/Applications/Argo.app/Contents/Resources/argo-osc-filter"

    func testWrapsCommandThroughHelperWithOriginalAsArguments() {
        let command = TerminalCommandDefinition(
            executablePath: "/bin/zsh",
            arguments: ["-l"],
            displayName: "zsh"
        )

        let wrapped = TerminalInlineImageFilter.wrapped(command: command, helperPath: helperPath)

        XCTAssertEqual(wrapped.executablePath, helperPath)
        XCTAssertEqual(wrapped.arguments, ["/bin/zsh", "-l"])
        XCTAssertEqual(wrapped.displayName, "zsh")
    }

    func testWrappingPreservesAllOriginalArguments() {
        let command = TerminalCommandDefinition(
            executablePath: "/usr/bin/env",
            arguments: ["claude", "--continue", "--flag=value"],
            displayName: "Claude Code"
        )

        let wrapped = TerminalInlineImageFilter.wrapped(command: command, helperPath: helperPath)

        XCTAssertEqual(wrapped.arguments, ["/usr/bin/env", "claude", "--continue", "--flag=value"])
    }

    func testDoesNotDoubleWrapWhenExecutableIsAlreadyTheHelper() {
        let alreadyWrapped = TerminalCommandDefinition(
            executablePath: helperPath,
            arguments: ["/bin/zsh", "-l"],
            displayName: "zsh"
        )

        let result = TerminalInlineImageFilter.wrapped(command: alreadyWrapped, helperPath: helperPath)

        XCTAssertEqual(result, alreadyWrapped)
    }

    func testLeavesEmptyExecutableUntouched() {
        let empty = TerminalCommandDefinition(executablePath: "", arguments: [], displayName: "")

        let result = TerminalInlineImageFilter.wrapped(command: empty, helperPath: helperPath)

        XCTAssertEqual(result, empty)
    }

    func testEnabledByDefaultWhenUnsetThenHonorsStoredChoice() {
        let key = TerminalInlineImageFilter.defaultsKey
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        XCTAssertTrue(TerminalInlineImageFilter.isEnabled)

        defaults.set(false, forKey: key)
        XCTAssertFalse(TerminalInlineImageFilter.isEnabled)

        defaults.set(true, forKey: key)
        XCTAssertTrue(TerminalInlineImageFilter.isEnabled)
    }

    func testLocalShellLaunchWrapsPreparedCommandWhenHelperPathIsProvided() {
        let configuration = SessionBackendConfiguration.local(
            shellPath: "/bin/zsh",
            shellArguments: ["-l"]
        )

        let launch = configuration.makeLaunchConfiguration(
            preferredWorkingDirectory: "/tmp/argo-inline-images",
            baseEnvironment: [:],
            inlineImageFilter: { command in
                TerminalInlineImageFilter.wrapped(command: command, helperPath: self.helperPath)
            }
        )

        XCTAssertEqual(launch.command.executablePath, helperPath)
        XCTAssertEqual(launch.command.arguments, ["/bin/zsh", "-l"])
        XCTAssertEqual(launch.command.displayName, "zsh")
    }

    func testAgentLaunchWrapsPreparedCommandWhenHelperPathIsProvided() {
        let configuration = SessionBackendConfiguration.agent(
            AgentSessionConfiguration(
                name: "Claude Code",
                launchPath: "/usr/bin/env",
                arguments: ["claude", "--continue"],
                environment: [:],
                workingDirectory: nil
            )
        )

        let launch = configuration.makeLaunchConfiguration(
            preferredWorkingDirectory: "/tmp/argo-inline-images",
            baseEnvironment: [:],
            inlineImageFilter: { command in
                TerminalInlineImageFilter.wrapped(command: command, helperPath: self.helperPath)
            }
        )

        XCTAssertEqual(launch.command.executablePath, helperPath)
        XCTAssertEqual(launch.command.arguments, ["/usr/bin/env", "claude", "--continue"])
        XCTAssertEqual(launch.command.displayName, "Claude Code")
    }

    func testSSHLaunchDoesNotWrapInlineImageFilter() {
        let configuration = SessionBackendConfiguration.ssh(
            SSHSessionConfiguration(
                host: "example.com",
                user: "dev",
                port: nil,
                identityFilePath: nil,
                remoteWorkingDirectory: nil,
                remoteCommand: nil
            )
        )

        let launch = configuration.makeLaunchConfiguration(
            preferredWorkingDirectory: "/tmp/argo-inline-images",
            baseEnvironment: [:],
            inlineImageFilter: { command in
                TerminalInlineImageFilter.wrapped(command: command, helperPath: self.helperPath)
            }
        )

        XCTAssertEqual(launch.command.executablePath, "/usr/bin/ssh")
    }

    func testSettingsExposeInlineImageToggleWithLocalizedText() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Sheets/SettingsSheet.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("@AppStorage(TerminalInlineImageFilter.defaultsKey) private var inlineImagesEnabled = true"))
        XCTAssertTrue(settingsSource.contains("Toggle(localized(\"settings.general.terminal.inlineImages\"), isOn: $inlineImagesEnabled)"))
        XCTAssertTrue(settingsSource.contains("Text(localized(\"settings.general.terminal.inlineImagesHint\"))"))
    }
}
