//
//  ClaudeHookInstallerTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class ClaudeHookInstallerTests: XCTestCase {
    func testInstallSettingsJSONAddsPermissionRequestHookWithMatcherAndTimeout() throws {
        let hookCommand = "'/Applications/Argo.app/Contents/MacOS/Argo' claude-hook"

        let mutation = try ClaudeHookInstaller.installSettingsJSON(
            existingData: nil,
            hookCommand: hookCommand
        )

        XCTAssertTrue(mutation.changed)
        XCTAssertTrue(mutation.managedHooksPresent)
        let root = try XCTUnwrap(jsonObject(from: mutation.contents))
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        let permissionGroups = try XCTUnwrap(hooks["PermissionRequest"] as? [[String: Any]])
        let permissionGroup = try XCTUnwrap(permissionGroups.first)
        XCTAssertEqual(permissionGroup["matcher"] as? String, "*")
        let commandHooks = try XCTUnwrap(permissionGroup["hooks"] as? [[String: Any]])
        let hook = try XCTUnwrap(commandHooks.first)
        XCTAssertEqual(hook["type"] as? String, "command")
        XCTAssertEqual(hook["command"] as? String, hookCommand)
        XCTAssertEqual(hook["timeout"] as? Int, ClaudeHookInstaller.managedTimeout)
    }

    func testInstallSettingsJSONPreservesExistingHooksAndIsIdempotent() throws {
        let existing = Data("""
        {
          "hooks": {
            "PreToolUse": [
              {
                "matcher": "*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "/Users/me/existing.sh"
                  }
                ]
              }
            ]
          },
          "theme": "light"
        }
        """.utf8)
        let hookCommand = "'/tmp/Argo' claude-hook"

        let first = try ClaudeHookInstaller.installSettingsJSON(
            existingData: existing,
            hookCommand: hookCommand
        )
        let second = try ClaudeHookInstaller.installSettingsJSON(
            existingData: try XCTUnwrap(first.contents),
            hookCommand: hookCommand
        )

        XCTAssertFalse(second.changed)
        let root = try XCTUnwrap(jsonObject(from: second.contents))
        XCTAssertEqual(root["theme"] as? String, "light")
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        let preToolGroups = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        let flattenedHooks = preToolGroups.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
        XCTAssertTrue(flattenedHooks.contains { ($0["command"] as? String) == "/Users/me/existing.sh" })
        XCTAssertEqual(flattenedHooks.filter { ($0["command"] as? String) == hookCommand }.count, 1)
    }

    func testUninstallSettingsJSONRemovesOnlyArgoManagedHooks() throws {
        let hookCommand = "'/tmp/Argo' claude-hook"
        let installed = try ClaudeHookInstaller.installSettingsJSON(
            existingData: Data("""
            {
              "hooks": {
                "PermissionRequest": [
                  {
                    "matcher": "*",
                    "hooks": [
                      {
                        "type": "command",
                        "command": "/Users/me/keep.sh"
                      }
                    ]
                  }
                ]
              }
            }
            """.utf8),
            hookCommand: hookCommand
        )

        let mutation = try ClaudeHookInstaller.uninstallSettingsJSON(
            existingData: installed.contents,
            managedCommand: hookCommand
        )

        XCTAssertTrue(mutation.changed)
        XCTAssertFalse(mutation.managedHooksPresent)
        let root = try XCTUnwrap(jsonObject(from: mutation.contents))
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        let permissionGroups = try XCTUnwrap(hooks["PermissionRequest"] as? [[String: Any]])
        let flattenedHooks = permissionGroups.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
        XCTAssertEqual(flattenedHooks.map { $0["command"] as? String }, ["/Users/me/keep.sh"])
    }

    func testInstallWritesSettingsAndManifestFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-claude-hook-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let status = try ClaudeHookInstaller.install(
            claudeDirectory: directory,
            binaryPath: "/tmp/Argo"
        )

        XCTAssertTrue(status.managedHooksPresent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: status.settingsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: status.manifestURL.path))
        let manifestData = try Data(contentsOf: status.manifestURL)
        let manifest = try JSONDecoder().decode(ClaudeHookInstallerManifest.self, from: manifestData)
        XCTAssertEqual(manifest.hookCommand, "'/tmp/Argo' claude-hook")
    }

    func testInstallBacksUpExistingSettingsBeforeChangingThem() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-claude-hook-backup-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let settingsURL = directory.appendingPathComponent("settings.json")
        try Data(#"{"theme":"light"}"#.utf8).write(to: settingsURL)

        _ = try ClaudeHookInstaller.install(claudeDirectory: directory, binaryPath: "/tmp/Argo")

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("settings.json.backup.") })
    }

    func testInstallerCLIInstallStatusAndUninstallUseProvidedClaudeDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-claude-hook-cli-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var stdout = ""
        var stderr = ""

        let installExit = ClaudeHookInstallerCLI.run(
            arguments: ["install", "--claude-dir", directory.path, "--binary", "/tmp/Argo"],
            stdoutWriter: { stdout += $0 + "\n" },
            stderrWriter: { stderr += $0 + "\n" }
        )
        XCTAssertEqual(installExit, .ok)
        XCTAssertTrue(stderr.isEmpty)
        XCTAssertTrue(stdout.contains("Installed Argo Claude hooks"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.json").path))

        stdout = ""
        let statusExit = ClaudeHookInstallerCLI.run(
            arguments: ["status", "--claude-dir", directory.path],
            stdoutWriter: { stdout += $0 + "\n" },
            stderrWriter: { stderr += $0 + "\n" }
        )
        XCTAssertEqual(statusExit, .ok)
        XCTAssertTrue(stdout.contains("Managed hooks present: yes"))

        stdout = ""
        let uninstallExit = ClaudeHookInstallerCLI.run(
            arguments: ["uninstall", "--claude-dir", directory.path],
            stdoutWriter: { stdout += $0 + "\n" },
            stderrWriter: { stderr += $0 + "\n" }
        )
        XCTAssertEqual(uninstallExit, .ok)
        XCTAssertTrue(stdout.contains("Removed Argo Claude hooks"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(ClaudeHookInstallerManifest.fileName).path))
    }

    func testInstallerCLIRejectsUnknownSubcommand() {
        var stderr = ""

        let exit = ClaudeHookInstallerCLI.run(
            arguments: ["repair"],
            stdoutWriter: { _ in },
            stderrWriter: { stderr += $0 + "\n" }
        )

        XCTAssertEqual(exit, .usage)
        XCTAssertTrue(stderr.contains("unknown subcommand"))
    }

    func testAutoInstallerInstallsWhenManagedHooksAreMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-claude-hook-auto-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try ClaudeHookAutoInstaller.installIfMissing(
            claudeDirectory: directory,
            binaryPath: "/tmp/Argo"
        )

        XCTAssertEqual(result, .installed)
        let status = try ClaudeHookInstaller.status(claudeDirectory: directory)
        XCTAssertTrue(status.managedHooksPresent)
    }

    func testAutoInstallerSkipsWhenManagedHooksArePresent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-claude-hook-auto-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try ClaudeHookInstaller.install(claudeDirectory: directory, binaryPath: "/tmp/Argo")

        let result = try ClaudeHookAutoInstaller.installIfMissing(
            claudeDirectory: directory,
            binaryPath: "/tmp/Argo"
        )

        XCTAssertEqual(result, .alreadyInstalled)
    }

    private func jsonObject(from data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
