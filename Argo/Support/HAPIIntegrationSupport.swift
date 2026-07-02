//
//  HAPIIntegrationSupport.swift
//  Argo
//
//  Author: Codex
//

import Darwin
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

struct HAPINetworkInterfaceAddress: Hashable {
    var interfaceName: String
    var ipAddress: String
}

enum HAPILANHubEnvironment {
    private static let listenHost = "0.0.0.0"
    private static let listenPort = "3006"
    private static let preferredInterfaceNames = ["en0", "en1"]

    static func environment(merging baseEnvironment: [String: String]) -> [String: String] {
        environment(
            merging: baseEnvironment,
            localIPv4Address: preferredIPv4Address(from: currentInterfaceAddresses())
        )
    }

    static func environment(
        merging baseEnvironment: [String: String],
        localIPv4Address: String?
    ) -> [String: String] {
        var environment = baseEnvironment
        environment["HAPI_LISTEN_HOST"] = listenHost
        environment["HAPI_LISTEN_PORT"] = listenPort
        environment["HAPI_PUBLIC_URL"] = publicURL(for: localIPv4Address)
        return environment
    }

    static func preferredIPv4Address(from addresses: [HAPINetworkInterfaceAddress]) -> String? {
        let usableAddresses = addresses.filter { isUsableIPv4Address($0.ipAddress) }
        for interfaceName in preferredInterfaceNames {
            if let address = usableAddresses.first(where: { $0.interfaceName == interfaceName }) {
                return address.ipAddress
            }
        }
        return usableAddresses.first?.ipAddress
    }

    private static func publicURL(for localIPv4Address: String?) -> String {
        "http://\(localIPv4Address ?? "localhost"):\(listenPort)"
    }

    private static func isUsableIPv4Address(_ ipAddress: String) -> Bool {
        var socketAddress = in_addr()
        guard inet_pton(AF_INET, ipAddress, &socketAddress) == 1 else {
            return false
        }
        return ipAddress != "0.0.0.0" && !ipAddress.hasPrefix("127.")
    }

    private static func currentInterfaceAddresses() -> [HAPINetworkInterfaceAddress] {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return []
        }
        defer { freeifaddrs(interfaceAddresses) }

        var addresses: [HAPINetworkInterfaceAddress] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let interface = current.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  let name = interface.ifa_name else {
                continue
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            addresses.append(
                HAPINetworkInterfaceAddress(
                    interfaceName: String(cString: name),
                    ipAddress: String(cString: hostBuffer)
                )
            )
        }
        return addresses
    }
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
