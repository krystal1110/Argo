//
//  HAPIIntegrationSupport.swift
//  Argo
//
//  Author: Codex
//

import Foundation

private func argoLocalizedHAPIString(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

struct HAPICodexVersion: Hashable, Comparable, CustomStringConvertible {
    var major: Int
    var minor: Int
    var patch: Int

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: HAPICodexVersion, rhs: HAPICodexVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

struct HAPIInstallationStatus: Hashable {
    var executablePath: String
    var cloudflaredExecutablePath: String? = nil
    var codexExecutablePath: String? = nil
    var codexVersion: HAPICodexVersion? = nil

    var hasUsableCodexCLI: Bool {
        guard let codexExecutablePath, !codexExecutablePath.isEmpty,
              let codexVersion else { return false }
        return HAPIIntegrationCatalog.isSupportedCodexVersion(codexVersion)
    }

    var codexPathDirectory: String? {
        codexExecutablePath
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
            .flatMap(\.nilIfEmpty)
    }

    var primaryActionTitle: String {
        argoLocalizedHAPIString("main.hapi.openMenu")
    }

    var primaryActionHelpText: String {
        argoLocalizedHAPIString("main.hapi.help.openMenu")
    }
}

enum HAPIIntegrationState: Hashable {
    case unavailable
    case available(HAPIInstallationStatus)
}

enum HAPIIntegrationCatalog {
    static let minimumSupportedCodexVersion = HAPICodexVersion(major: 0, minor: 124, patch: 0)
    private static let bundledCodexExecutablePath = "/Applications/Codex.app/Contents/Resources/codex"

    static func detect(using runner: ShellCommandRunner = ShellCommandRunner()) async -> HAPIIntegrationState {
        guard let executablePath = await resolveExecutablePath(named: "hapi", using: runner) else {
            return .unavailable
        }

        let cloudflaredExecutablePath = await resolveExecutablePath(named: "cloudflared", using: runner)
        let codexCLI = await detectCodexCLI(using: runner)
        return .available(
            HAPIInstallationStatus(
                executablePath: executablePath,
                cloudflaredExecutablePath: cloudflaredExecutablePath,
                codexExecutablePath: codexCLI?.path,
                codexVersion: codexCLI?.version
            )
        )
    }

    static func parseExecutablePath(_ output: String) -> String? {
        let path = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.hasPrefix("/") })
        return path?.nilIfEmpty
    }

    static func parseCodexVersion(_ output: String) -> HAPICodexVersion? {
        guard let match = output.firstMatch(for: #"(\d+)\.(\d+)\.(\d+)"#),
              match.count == 4,
              let major = Int(match[1]),
              let minor = Int(match[2]),
              let patch = Int(match[3]) else {
            return nil
        }
        return HAPICodexVersion(major: major, minor: minor, patch: patch)
    }

    static func isSupportedCodexVersion(_ version: HAPICodexVersion) -> Bool {
        version >= minimumSupportedCodexVersion
    }

    private static func detectCodexCLI(using runner: ShellCommandRunner) async -> (path: String, version: HAPICodexVersion)? {
        let candidatePaths = await codexCandidatePaths(using: runner)
        for path in candidatePaths {
            guard let version = await resolveCodexVersion(at: path, using: runner),
                  isSupportedCodexVersion(version) else { continue }
            return (path, version)
        }
        return nil
    }

    private static func codexCandidatePaths(using runner: ShellCommandRunner) async -> [String] {
        var paths: [String] = []
        if let path = await resolveExecutablePath(named: "codex", using: runner) {
            paths.append(path)
        }
        if FileManager.default.isExecutableFile(atPath: bundledCodexExecutablePath) {
            paths.append(bundledCodexExecutablePath)
        }
        return paths.deduplicated()
    }

    private static func resolveCodexVersion(
        at executablePath: String,
        using runner: ShellCommandRunner
    ) async -> HAPICodexVersion? {
        do {
            let result = try await runner.run(
                executable: executablePath,
                arguments: ["--version"],
                timeout: 5
            )
            return parseCodexVersion(result.stdout + "\n" + result.stderr)
        } catch {
            return nil
        }
    }

    private static func resolveExecutablePath(
        named executableName: String,
        using runner: ShellCommandRunner
    ) async -> String? {
        do {
            let result = try await runner.run(
                executable: "/bin/zsh",
                arguments: ["-lic", "whence -p \(executableName.shellQuoted)"]
            )
            return parseExecutablePath(result.stdout)
        } catch {
            return nil
        }
    }
}

private extension String {
    func firstMatch(for pattern: String) -> [String]? {
        guard let regularExpression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regularExpression.firstMatch(in: self, range: range) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            guard let swiftRange = Range(match.range(at: index), in: self) else { return "" }
            return String(self[swiftRange])
        }
    }
}

private extension Array where Element: Hashable {
    func deduplicated() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
