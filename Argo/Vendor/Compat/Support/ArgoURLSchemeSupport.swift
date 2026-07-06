//
//  ArgoURLSchemeSupport.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import Foundation

enum ArgoURLScheme {
    static let scheme = "argo"
    static let tokenDefaultsKey = "com.krystal.argo.urlScheme.token"
    static let enabledDefaultsKey = "com.krystal.argo.urlScheme.enabled"
    static let skipConfirmationDefaultsKey = "com.krystal.argo.urlScheme.skipConfirmation"

    struct RunRequest {
        let cmd: String
        let cwd: String
        let token: String?
    }

    static func isEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledDefaultsKey)
    }

    /// When true, incoming URLs whose token already matches are executed
    /// without a confirmation dialog. Defaults to `false` so first-run
    /// behavior still prompts the user.
    static func skipConfirmation() -> Bool {
        UserDefaults.standard.bool(forKey: skipConfirmationDefaultsKey)
    }

    static func setSkipConfirmation(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: skipConfirmationDefaultsKey)
    }

    static func storedToken() -> String? {
        let value = UserDefaults.standard.string(forKey: tokenDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static func setStoredToken(_ token: String?) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: tokenDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: tokenDefaultsKey)
        }
    }

    static func generateToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Parses `argo://run?cmd=...&cwd=...&token=...`.
    /// Returns nil if the URL is not a well-formed run request.
    static func parseRunURL(_ url: URL) -> RunRequest? {
        guard url.scheme == scheme, url.host == "run" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        var cmd = ""
        var cwd = ""
        var token: String? = nil
        for item in items {
            switch item.name {
            case "cmd": cmd = item.value ?? ""
            case "cwd": cwd = item.value ?? ""
            case "token": token = item.value
            default: break
            }
        }

        let trimmedCmd = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCwd = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCmd.isEmpty, !trimmedCwd.isEmpty else { return nil }
        return RunRequest(cmd: trimmedCmd, cwd: trimmedCwd, token: token)
    }
}
