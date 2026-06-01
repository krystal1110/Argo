//
//  ArgoControlDispatcher.swift
//  Argo
//
//  Author: krystal
//

import Foundation

/// Decodes incoming control frames, performs auth, and routes the typed
/// request to a host. Returns the encoded JSON response (or `nil` for the
/// fire-and-forget `notify` case).
///
/// The dispatcher is host-agnostic so unit tests can drive it without an
/// `ArgoDesktopApplication`. Production wires the host to the real
/// `ArgoDesktopApplication` via `AppDelegate`.
@MainActor
protocol ArgoControlHost: AnyObject {
    func handleNotify(_ request: AgentNotifyRequest)
    func handleOpen(_ request: ArgoOpenRequest) -> ArgoControlResponse
    func handleSplit(_ request: ArgoSplitRequest) -> ArgoControlResponse
    func handleSendKeys(_ request: ArgoSendKeysRequest) -> ArgoControlResponse
    func handleSessionList(_ request: ArgoSessionListRequest) -> ArgoControlResponse
}

/// Note: this class is explicitly `nonisolated`. The project enables
/// `SWIFT_APPROACHABLE_CONCURRENCY`, which makes module-level types default
/// to `@MainActor`. Letting the dispatcher inherit that default emits a
/// main-actor deinit hop, which on this OS/Swift toolchain trips a libmalloc
/// abort under XCTest's deterministic dealloc check (XCTMemoryChecker).
/// `dispatch(frame:)` keeps `@MainActor` so the host call-sites remain safe.
nonisolated final class ArgoControlDispatcher {
    weak var host: ArgoControlHost?
    /// Token resolver — returns the user-configured trust token or nil if
    /// the URL-scheme feature is disabled. Indirection so tests can inject.
    var tokenResolver: () -> String?

    init(
        host: ArgoControlHost?,
        tokenResolver: @escaping () -> String? = { MainActor.assumeIsolated { ArgoURLScheme.isEnabled() ? ArgoURLScheme.storedToken() : nil } }
    ) {
        self.host = host
        self.tokenResolver = tokenResolver
    }

    /// Decode + dispatch a single frame. Returns the response bytes (or nil
    /// for fire-and-forget commands like `notify`).
    @MainActor
    func dispatch(frame: Data) -> Data? {
        guard let envelope = try? JSONDecoder().decode(ArgoControlEnvelope.self, from: trim(frame)) else {
            return ArgoControlEncoder.encodeResponse(.failure("invalid-envelope"))
        }
        let cmd = envelope.cmd ?? .notify

        if cmd == .notify {
            // Notify is intentionally unauthenticated and produces no
            // response — any in-pane process can already print to stdout, so
            // emitting a notification is no privilege escalation.
            if let request = try? JSONDecoder().decode(AgentNotifyRequest.self, from: trim(frame)) {
                host?.handleNotify(request)
            }
            return nil
        }

        // All other commands require auth.
        guard let expected = tokenResolver(), !expected.isEmpty else {
            return ArgoControlEncoder.encodeResponse(.failure("control-disabled"))
        }
        guard let provided = envelope.token, provided == expected else {
            return ArgoControlEncoder.encodeResponse(.failure("token-mismatch"))
        }
        guard let host else {
            return ArgoControlEncoder.encodeResponse(.failure("app-not-ready"))
        }

        let response: ArgoControlResponse
        switch cmd {
        case .notify:
            // Already handled above.
            return nil
        case .open:
            guard let req = try? JSONDecoder().decode(ArgoOpenRequest.self, from: trim(frame)) else {
                response = .failure("invalid-open-payload")
                break
            }
            response = host.handleOpen(req)
        case .split:
            let req = (try? JSONDecoder().decode(ArgoSplitRequest.self, from: trim(frame))) ?? ArgoSplitRequest()
            response = host.handleSplit(req)
        case .sendKeys:
            guard let req = try? JSONDecoder().decode(ArgoSendKeysRequest.self, from: trim(frame)) else {
                response = .failure("invalid-send-keys-payload")
                break
            }
            response = host.handleSendKeys(req)
        case .sessionList:
            let req = (try? JSONDecoder().decode(ArgoSessionListRequest.self, from: trim(frame))) ?? ArgoSessionListRequest()
            response = host.handleSessionList(req)
        }
        return ArgoControlEncoder.encodeResponse(response)
    }

    private func trim(_ data: Data) -> Data {
        data.last == 0x0A ? data.dropLast() : data
    }
}
