//
//  ClaudeHookInstaller.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated struct ClaudeHookInstallerManifest: Equatable, Codable, Sendable {
    static let fileName = "argo-claude-hooks-install.json"

    var hookCommand: String
    var installedAt: Date

    init(hookCommand: String, installedAt: Date = .now) {
        self.hookCommand = hookCommand
        self.installedAt = installedAt
    }
}

nonisolated struct ClaudeHookSettingsMutation: Equatable, Sendable {
    var contents: Data?
    var changed: Bool
    var managedHooksPresent: Bool
}

nonisolated struct ClaudeHookInstallerStatus: Equatable, Sendable {
    var settingsURL: URL
    var manifestURL: URL
    var hookCommand: String?
    var managedHooksPresent: Bool
    var changed: Bool
}

nonisolated enum ClaudeHookInstallerError: Error, LocalizedError {
    case invalidSettingsJSON
    case invalidManifestJSON

    var errorDescription: String? {
        switch self {
        case .invalidSettingsJSON:
            return "The existing Claude settings.json is not valid JSON."
        case .invalidManifestJSON:
            return "The existing Argo Claude hook manifest is not valid JSON."
        }
    }
}

nonisolated enum ClaudeHookInstaller {
    static let managedTimeout = 86_400

    private static let settingsFileName = "settings.json"
    private static let eventSpecs: [(name: String, matcher: String?, timeout: Int?)] = [
        ("UserPromptSubmit", nil, nil),
        ("SessionStart", nil, nil),
        ("SessionEnd", nil, nil),
        ("Stop", nil, nil),
        ("StopFailure", nil, nil),
        ("SubagentStart", nil, nil),
        ("SubagentStop", nil, nil),
        ("Notification", "*", nil),
        ("PreToolUse", "*", nil),
        ("PermissionRequest", "*", managedTimeout),
        ("PostToolUse", "*", nil),
        ("PostToolUseFailure", "*", nil),
        ("PermissionDenied", "*", nil),
        ("PreCompact", nil, nil),
    ]

    static func hookCommand(for binaryPath: String) -> String {
        "\(binaryPath.shellQuoted) claude-hook"
    }

    static func defaultClaudeDirectory(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appendingPathComponent(".claude", isDirectory: true)
    }

    static func install(
        claudeDirectory: URL = defaultClaudeDirectory(),
        binaryPath: String,
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws -> ClaudeHookInstallerStatus {
        let settingsURL = claudeDirectory.appendingPathComponent(settingsFileName, isDirectory: false)
        let manifestURL = claudeDirectory.appendingPathComponent(ClaudeHookInstallerManifest.fileName, isDirectory: false)
        let hookCommand = hookCommand(for: binaryPath)
        let existingData = fileManager.contents(atPath: settingsURL.path)
        let mutation = try installSettingsJSON(existingData: existingData, hookCommand: hookCommand)

        try fileManager.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        if mutation.changed, fileManager.fileExists(atPath: settingsURL.path) {
            try backupFile(at: settingsURL, fileManager: fileManager)
        }
        if let contents = mutation.contents {
            try contents.write(to: settingsURL, options: [.atomic])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = ClaudeHookInstallerManifest(hookCommand: hookCommand, installedAt: now)
        try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])

        return ClaudeHookInstallerStatus(
            settingsURL: settingsURL,
            manifestURL: manifestURL,
            hookCommand: hookCommand,
            managedHooksPresent: mutation.managedHooksPresent,
            changed: mutation.changed
        )
    }

    static func uninstall(
        claudeDirectory: URL = defaultClaudeDirectory(),
        fileManager: FileManager = .default
    ) throws -> ClaudeHookInstallerStatus {
        let settingsURL = claudeDirectory.appendingPathComponent(settingsFileName, isDirectory: false)
        let manifestURL = claudeDirectory.appendingPathComponent(ClaudeHookInstallerManifest.fileName, isDirectory: false)
        let manifest = try readManifest(at: manifestURL, fileManager: fileManager)
        let existingData = fileManager.contents(atPath: settingsURL.path)
        let mutation = try uninstallSettingsJSON(existingData: existingData, managedCommand: manifest?.hookCommand)

        if mutation.changed, fileManager.fileExists(atPath: settingsURL.path) {
            try backupFile(at: settingsURL, fileManager: fileManager)
        }
        if let contents = mutation.contents {
            try contents.write(to: settingsURL, options: [.atomic])
        } else if fileManager.fileExists(atPath: settingsURL.path) {
            try fileManager.removeItem(at: settingsURL)
        }
        if fileManager.fileExists(atPath: manifestURL.path) {
            try fileManager.removeItem(at: manifestURL)
        }

        return ClaudeHookInstallerStatus(
            settingsURL: settingsURL,
            manifestURL: manifestURL,
            hookCommand: manifest?.hookCommand,
            managedHooksPresent: false,
            changed: mutation.changed
        )
    }

    static func status(
        claudeDirectory: URL = defaultClaudeDirectory(),
        fileManager: FileManager = .default
    ) throws -> ClaudeHookInstallerStatus {
        let settingsURL = claudeDirectory.appendingPathComponent(settingsFileName, isDirectory: false)
        let manifestURL = claudeDirectory.appendingPathComponent(ClaudeHookInstallerManifest.fileName, isDirectory: false)
        let manifest = try readManifest(at: manifestURL, fileManager: fileManager)
        let existingData = fileManager.contents(atPath: settingsURL.path)
        let rootObject = try loadRootObject(from: existingData)
        let hooksObject = rootObject["hooks"] as? [String: Any] ?? [:]
        return ClaudeHookInstallerStatus(
            settingsURL: settingsURL,
            manifestURL: manifestURL,
            hookCommand: manifest?.hookCommand,
            managedHooksPresent: containsAllManagedHooks(in: hooksObject, managedCommand: manifest?.hookCommand),
            changed: false
        )
    }

    static func installSettingsJSON(
        existingData: Data?,
        hookCommand: String
    ) throws -> ClaudeHookSettingsMutation {
        var rootObject = try loadRootObject(from: existingData)
        let existingHooksObject = rootObject["hooks"] as? [String: Any] ?? [:]
        var hooksObject: [String: Any] = [:]

        for (eventName, value) in existingHooksObject {
            let existingGroups = value as? [Any] ?? []
            let cleanedGroups = sanitizeForInstall(groups: existingGroups, replacingCommand: hookCommand)
            if !cleanedGroups.isEmpty {
                hooksObject[eventName] = cleanedGroups
            }
        }

        for spec in eventSpecs {
            let existingGroups = hooksObject[spec.name] as? [Any] ?? []
            let cleanedGroups = sanitizeForInstall(groups: existingGroups, replacingCommand: hookCommand)
            hooksObject[spec.name] = cleanedGroups + [
                managedGroup(matcher: spec.matcher, timeout: spec.timeout, hookCommand: hookCommand)
            ]
        }

        rootObject["hooks"] = hooksObject
        let data = try serialize(rootObject)
        return ClaudeHookSettingsMutation(
            contents: data,
            changed: data != existingData,
            managedHooksPresent: true
        )
    }

    static func uninstallSettingsJSON(
        existingData: Data?,
        managedCommand: String?
    ) throws -> ClaudeHookSettingsMutation {
        guard let existingData else {
            return ClaudeHookSettingsMutation(contents: nil, changed: false, managedHooksPresent: false)
        }

        var rootObject = try loadRootObject(from: existingData)
        var hooksObject = rootObject["hooks"] as? [String: Any] ?? [:]
        var changed = false

        for spec in eventSpecs {
            let existingGroups = hooksObject[spec.name] as? [Any] ?? []
            let cleanedGroups = sanitize(groups: existingGroups, managedCommand: managedCommand)
            if cleanedGroups.count != existingGroups.count || containsManagedHook(in: existingGroups, managedCommand: managedCommand) {
                changed = true
            }
            if cleanedGroups.isEmpty {
                hooksObject.removeValue(forKey: spec.name)
            } else {
                hooksObject[spec.name] = cleanedGroups
            }
        }

        if hooksObject.isEmpty {
            rootObject.removeValue(forKey: "hooks")
        } else {
            rootObject["hooks"] = hooksObject
        }

        let contents = rootObject.isEmpty ? nil : try serialize(rootObject)
        return ClaudeHookSettingsMutation(
            contents: contents,
            changed: changed || contents != existingData,
            managedHooksPresent: false
        )
    }

    private static func readManifest(
        at url: URL,
        fileManager: FileManager
    ) throws -> ClaudeHookInstallerManifest? {
        guard let data = fileManager.contents(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(ClaudeHookInstallerManifest.self, from: data)
        } catch {
            throw ClaudeHookInstallerError.invalidManifestJSON
        }
    }

    private static func loadRootObject(from data: Data?) throws -> [String: Any] {
        guard let data else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let rootObject = object as? [String: Any] else {
            throw ClaudeHookInstallerError.invalidSettingsJSON
        }
        return rootObject
    }

    private static func serialize(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private static func managedGroup(
        matcher: String?,
        timeout: Int?,
        hookCommand: String
    ) -> [String: Any] {
        var hook: [String: Any] = [
            "type": "command",
            "command": hookCommand,
        ]
        if let timeout {
            hook["timeout"] = timeout
        }

        var group: [String: Any] = [
            "hooks": [hook],
        ]
        if let matcher {
            group["matcher"] = matcher
        }
        return group
    }

    private static func sanitize(groups: [Any], managedCommand: String?) -> [[String: Any]] {
        groups.compactMap { item in
            guard var group = item as? [String: Any] else { return nil }
            let existingHooks = group["hooks"] as? [Any] ?? []
            let filteredHooks = existingHooks.compactMap { hook -> [String: Any]? in
                guard let hook = hook as? [String: Any] else { return nil }
                return isManagedHook(hook, managedCommand: managedCommand) ? nil : hook
            }
            guard !filteredHooks.isEmpty else { return nil }
            group["hooks"] = filteredHooks
            return group
        }
    }

    private static func sanitizeForInstall(groups: [Any], replacingCommand: String) -> [[String: Any]] {
        groups.compactMap { item in
            guard var group = item as? [String: Any] else { return nil }
            let existingHooks = group["hooks"] as? [Any] ?? []
            let filteredHooks = existingHooks.compactMap { hook -> [String: Any]? in
                guard let hook = hook as? [String: Any] else { return nil }
                return isManagedHookForInstall(hook, replacingCommand: replacingCommand) ? nil : hook
            }
            guard !filteredHooks.isEmpty else { return nil }
            group["hooks"] = filteredHooks
            return group
        }
    }

    private static func containsAllManagedHooks(in hooksObject: [String: Any], managedCommand: String?) -> Bool {
        eventSpecs.allSatisfy { spec in
            let groups = hooksObject[spec.name] as? [Any] ?? []
            return containsManagedHook(in: groups, managedCommand: managedCommand)
        }
    }

    private static func containsManagedHook(in groups: [Any], managedCommand: String?) -> Bool {
        groups.contains { item in
            guard let group = item as? [String: Any],
                  let hooks = group["hooks"] as? [Any] else {
                return false
            }

            return hooks.contains { hook in
                guard let hook = hook as? [String: Any] else { return false }
                return isManagedHook(hook, managedCommand: managedCommand)
            }
        }
    }

    private static func isManagedHookForInstall(_ hook: [String: Any], replacingCommand: String) -> Bool {
        isManagedHook(hook, managedCommand: replacingCommand)
    }

    private static func isManagedHook(_ hook: [String: Any], managedCommand: String?) -> Bool {
        guard let command = hook["command"] as? String else { return false }
        if let managedCommand, command == managedCommand {
            return true
        }
        return isArgoClaudeHookCommand(command)
    }

    private static func isArgoClaudeHookCommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return normalized.contains("argo")
            && normalized.contains("claude-hook")
    }

    private static func backupFile(at url: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.appendingPathExtension("backup.\(timestamp)")
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: url, to: backupURL)
    }
}
