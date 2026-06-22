//
//  ClaudeHookInteractionRegistry.swift
//  Argo
//
//  Author: krystal
//

import Foundation

nonisolated final class ClaudeHookInteractionRegistry: @unchecked Sendable {
    static let shared = ClaudeHookInteractionRegistry()

    private let lock = NSLock()
    private var pending: [String: ClaudeHookPendingInteraction] = [:]

    func register(payload: ClaudeHookPayload, request: AgentNotifyRequest) -> ClaudeHookPendingInteraction? {
        guard let sessionID = request.sessionID else { return nil }
        let interaction = ClaudeHookPendingInteraction(sessionID: sessionID, payload: payload, request: request)
        lock.withLock {
            pending[sessionID] = interaction
        }
        return interaction
    }

    func resolve(sessionID: String, responseText: String) -> Bool {
        let interaction = lock.withLock {
            pending.removeValue(forKey: sessionID)
        }
        guard let interaction else { return false }
        interaction.resolve(responseText: responseText)
        return true
    }

    func cancel(sessionID: String) {
        let interaction = lock.withLock {
            pending.removeValue(forKey: sessionID)
        }
        interaction?.cancel()
    }

    func clearAll() {
        let interactions = lock.withLock {
            let values = Array(pending.values)
            pending.removeAll()
            return values
        }
        interactions.forEach { $0.cancel() }
    }
}

nonisolated final class ClaudeHookPendingInteraction: @unchecked Sendable {
    let sessionID: String

    private let payload: ClaudeHookPayload
    private let request: AgentNotifyRequest
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: ClaudeHookInteractionResult?
    private var isCancelled = false

    init(sessionID: String, payload: ClaudeHookPayload, request: AgentNotifyRequest) {
        self.sessionID = sessionID
        self.payload = payload
        self.request = request
    }

    func wait(timeout: TimeInterval) -> ClaudeHookInteractionResult? {
        let deadline = DispatchTime.now() + timeout
        guard semaphore.wait(timeout: deadline) == .success else {
            return nil
        }
        return lock.withLock { result }
    }

    func resolve(responseText: String) {
        let nextResult: ClaudeHookInteractionResult
        switch request.kind {
        case .approval:
            let normalizedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedResponse == "1" {
                nextResult = ClaudeHookInteractionResult(
                    decision: .allow(updatedInput: payload.toolInput)
                )
            } else if normalizedResponse == "2",
                      let permissionSuggestions = payload.permissionSuggestions,
                      !permissionSuggestions.isEmpty {
                nextResult = ClaudeHookInteractionResult(
                    decision: .allow(
                        updatedInput: payload.toolInput,
                        updatedPermissions: permissionSuggestions
                    )
                )
            } else {
                nextResult = ClaudeHookInteractionResult(
                    decision: .deny(message: "Permission denied in Argo.", interrupt: false)
                )
            }
        case .question:
            nextResult = ClaudeHookInteractionResult(
                decision: .allow(updatedInput: payload.updatedQuestionInput(answeredBy: responseText))
            )
        default:
            nextResult = ClaudeHookInteractionResult(decision: .allow(updatedInput: payload.toolInput))
        }

        let shouldSignal = lock.withLock { () -> Bool in
            guard result == nil, !isCancelled else { return false }
            result = nextResult
            return true
        }
        if shouldSignal {
            semaphore.signal()
        }
    }

    func cancel() {
        let shouldSignal = lock.withLock { () -> Bool in
            guard result == nil, !isCancelled else { return false }
            isCancelled = true
            return true
        }
        if shouldSignal {
            semaphore.signal()
        }
    }
}

private nonisolated extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
