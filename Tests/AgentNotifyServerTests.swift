//
//  AgentNotifyServerTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

/// End-to-end test: bind a server on a sandboxed temp socket, send via the
/// real client, and assert the dispatched request matches what was sent.
final class AgentNotifyServerTests: XCTestCase {
    private var temporarySocketURL: URL?

    override func setUp() {
        super.setUp()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-agent-notify-tests-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let socketURL = directory.appendingPathComponent("agent-notify.sock", isDirectory: false)
        temporarySocketURL = socketURL
        AgentNotifySocketPath.overrideURL = socketURL
    }

    override func tearDown() {
        AgentNotifySocketPath.overrideURL = nil
        if let url = temporarySocketURL {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        super.tearDown()
    }

    func testEndToEndFrameDeliveryViaRawHandler() throws {
        // Exercise the same socket round-trip as the production path but
        // without the @MainActor convenience-init wrapping — that wrapper
        // hops through Task/MainActor in a way that runs into a Swift 6
        // deinit bug on this machine. Coverage of the wrapper is provided
        // separately by AgentNotifyDispatcherTests + AppDelegate wiring.
        let socketURL = try XCTUnwrap(temporarySocketURL)
        let received = expectation(description: "server received frame")
        let captured = AgentNotifyFrameCapture()

        let server = AgentNotifyServer(socketURL: socketURL) { (frame: Data) -> Data? in
            captured.set(frame)
            received.fulfill()
            return nil
        }
        try server.start()
        defer { server.stop() }

        let request = AgentNotifyRequest(
            title: "Build finished",
            body: "All tests pass",
            paneID: "pane-uuid",
            workspaceID: "ws-uuid",
            agentName: "Claude"
        )

        DispatchQueue.global(qos: .userInitiated).async {
            try? AgentNotifyClient.send(request, socketURL: socketURL)
        }

        wait(for: [received], timeout: 5.0)
        let frame = try XCTUnwrap(captured.value)
        let decoded = try AgentNotifyProtocol.decode(frame)
        XCTAssertEqual(decoded, request)
    }

    @MainActor
    func testStopUnlinksSocket() throws {
        let socketURL = try XCTUnwrap(temporarySocketURL)
        let server = AgentNotifyServer(socketURL: socketURL) { (_: Data) in nil }
        try server.start()
        XCTAssertTrue(FileManager.default.fileExists(atPath: socketURL.path))

        server.stop()
        // stop() unlinks; give the OS a moment to flush.
        XCTAssertFalse(FileManager.default.fileExists(atPath: socketURL.path))
    }

    @MainActor
    func testStartReplacesStaleSocket() throws {
        let socketURL = try XCTUnwrap(temporarySocketURL)
        // Create a stale plain file at the socket path to simulate a crashed
        // previous run; start() must unlink it before bind().
        try Data().write(to: socketURL)

        let server = AgentNotifyServer(socketURL: socketURL) { (_: Data) in nil }
        try server.start()
        defer { server.stop() }

        // After start, the path exists as a socket — sending should succeed.
        let request = AgentNotifyRequest(title: "ok")
        XCTAssertNoThrow(try AgentNotifyClient.send(request, socketURL: socketURL))
    }

    func testClientReportsSocketUnavailableWhenNoServer() {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).sock")
        let request = AgentNotifyRequest(title: "x")
        XCTAssertThrowsError(try AgentNotifyClient.send(request, socketURL: bogus)) { error in
            XCTAssertEqual(error as? AgentNotifyError, .socketUnavailable)
        }
    }

    func testControlServerRetainsDispatcherAndRespondsToPing() throws {
        let socketURL = try XCTUnwrap(temporarySocketURL)
        let executablePath = "/debug/Argo.app/Contents/MacOS/Argo"
        let server = AgentNotifyControlServer(
            socketURL: socketURL,
            host: nil,
            tokenResolver: { nil },
            executablePathProvider: { executablePath }
        )
        try server.start()
        defer { server.stop() }

        let responseBox = AgentNotifyControlResponseCapture()
        let received = expectation(description: "ping response received")
        let frame = ArgoControlCLI.encodeFrame(cmd: "ping", token: nil, payload: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            responseBox.set(try? ArgoControlClient.send(frame: frame, socketURL: socketURL, timeout: 1.0))
            received.fulfill()
        }

        wait(for: [received], timeout: 3.0)
        XCTAssertEqual(responseBox.value??.executablePath, executablePath)
    }

    func testControlServerRespondsOnExecutableScopedSocketWhenSharedSocketIsOwned() throws {
        let sharedSocketURL = try XCTUnwrap(temporarySocketURL)
        let executablePath = "/debug/Argo.app/Contents/MacOS/Argo"
        let scopedSocketURL = AgentNotifySocketPath.resolveExecutableSocketURL(executablePath: executablePath)
        let sharedOwner = AgentNotifyServer(socketURL: sharedSocketURL) { _ in nil }
        try sharedOwner.start()
        defer { sharedOwner.stop() }

        let server = AgentNotifyControlServer(
            socketURL: sharedSocketURL,
            host: nil,
            tokenResolver: { nil },
            executablePathProvider: { executablePath }
        )
        try server.start()
        defer { server.stop() }

        XCTAssertNil(try? ArgoControlClient.send(
            frame: ArgoControlCLI.encodeFrame(cmd: "ping", token: nil, payload: [:]),
            socketURL: sharedSocketURL,
            timeout: 1.0
        ))

        let responseBox = AgentNotifyControlResponseCapture()
        let received = expectation(description: "scoped ping response received")
        let frame = ArgoControlCLI.encodeFrame(cmd: "ping", token: nil, payload: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            responseBox.set(try? ArgoControlClient.send(frame: frame, socketURL: scopedSocketURL, timeout: 1.0))
            received.fulfill()
        }

        wait(for: [received], timeout: 3.0)
        XCTAssertEqual(responseBox.value??.executablePath, executablePath)
    }

    @MainActor
    func testClaudeHookPermissionRequestRoundTripsThroughControlSocket() throws {
        ClaudeHookInteractionRegistry.shared.clearAll()
        defer { ClaudeHookInteractionRegistry.shared.clearAll() }

        let socketURL = try XCTUnwrap(temporarySocketURL)
        let receivedNotify = expectation(description: "host received claude hook notify")
        let receivedResponse = expectation(description: "hook client received response")
        let host = ClaudeHookRecordingHost { request in
            XCTAssertEqual(request.kind, .question)
            XCTAssertEqual(request.sessionID, "claude-e2e")
            XCTAssertEqual(request.title, "Pick a deploy target?")
            XCTAssertEqual(request.options?.map(\.label), ["Production", "Staging"])
            receivedNotify.fulfill()
        }
        let server = AgentNotifyControlServer(
            socketURL: socketURL,
            host: host,
            tokenResolver: { nil },
            executablePathProvider: { "/debug/Argo.app/Contents/MacOS/Argo" }
        )
        try server.start()
        defer { server.stop() }

        var frame = try JSONSerialization.data(withJSONObject: [
            "cmd": "claude-hook",
            "cwd": "/tmp/demo",
            "hook_event_name": "PermissionRequest",
            "session_id": "claude-e2e",
            "tool_name": "AskUserQuestion",
            "tool_input": [
                "questions": [
                    [
                        "question": "Pick a deploy target?",
                        "header": "Target",
                        "options": [
                            ["label": "Production"],
                            ["label": "Staging"],
                        ],
                    ],
                ],
            ],
        ], options: [.sortedKeys])
        frame.append(0x0A)
        let responseBox = AgentNotifyRawResponseCapture()

        DispatchQueue.global(qos: .userInitiated).async {
            responseBox.set(try? ArgoControlClient.sendRaw(
                frame: frame,
                socketURL: socketURL,
                timeout: 5.0
            ))
            receivedResponse.fulfill()
        }

        wait(for: [receivedNotify], timeout: 3.0)
        XCTAssertTrue(ClaudeHookInteractionRegistry.shared.resolve(
            sessionID: "claude-e2e",
            responseText: "2\n"
        ))

        wait(for: [receivedResponse], timeout: 3.0)
        let responseData = try XCTUnwrap(responseBox.value ?? nil)
        let stdoutData = try XCTUnwrap(try ClaudeHookNotifyBridge.cliStdout(from: responseData))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: stdoutData) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        let updatedInput = try XCTUnwrap(decision["updatedInput"] as? [String: Any])
        let answers = try XCTUnwrap(updatedInput["answers"] as? [String: Any])
        XCTAssertEqual(decision["behavior"] as? String, "allow")
        XCTAssertEqual(answers["Pick a deploy target?"] as? String, "Staging")
    }

    @MainActor
    func testClaudeHookToolPermissionRoundTripsThroughControlSocket() throws {
        ClaudeHookInteractionRegistry.shared.clearAll()
        defer { ClaudeHookInteractionRegistry.shared.clearAll() }

        let socketURL = try XCTUnwrap(temporarySocketURL)
        let receivedNotify = expectation(description: "host received claude hook permission notify")
        let receivedResponse = expectation(description: "hook client received permission response")
        let host = ClaudeHookRecordingHost { request in
            XCTAssertEqual(request.kind, .approval)
            XCTAssertEqual(request.sessionID, "claude-permission-e2e")
            XCTAssertEqual(request.title, "Allow Bash")
            XCTAssertEqual(request.commandPreview, "echo argo-smoke")
            XCTAssertEqual(request.options?.map(\.label), ["Yes", "No"])
            receivedNotify.fulfill()
        }
        let server = AgentNotifyControlServer(
            socketURL: socketURL,
            host: host,
            tokenResolver: { nil },
            executablePathProvider: { "/debug/Argo.app/Contents/MacOS/Argo" }
        )
        try server.start()
        defer { server.stop() }

        var frame = try JSONSerialization.data(withJSONObject: [
            "cmd": "claude-hook",
            "cwd": "/tmp/demo",
            "hook_event_name": "PermissionRequest",
            "session_id": "claude-permission-e2e",
            "tool_name": "Bash",
            "tool_input": [
                "command": "echo argo-smoke",
                "description": "Run smoke command",
            ],
        ], options: [.sortedKeys])
        frame.append(0x0A)
        let responseBox = AgentNotifyRawResponseCapture()

        DispatchQueue.global(qos: .userInitiated).async {
            responseBox.set(try? ArgoControlClient.sendRaw(
                frame: frame,
                socketURL: socketURL,
                timeout: 5.0
            ))
            receivedResponse.fulfill()
        }

        wait(for: [receivedNotify], timeout: 3.0)
        XCTAssertTrue(ClaudeHookInteractionRegistry.shared.resolve(
            sessionID: "claude-permission-e2e",
            responseText: "1\n"
        ))

        wait(for: [receivedResponse], timeout: 3.0)
        let responseData = try XCTUnwrap(responseBox.value ?? nil)
        let stdoutData = try XCTUnwrap(try ClaudeHookNotifyBridge.cliStdout(from: responseData))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: stdoutData) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        let updatedInput = try XCTUnwrap(decision["updatedInput"] as? [String: Any])
        XCTAssertEqual(decision["behavior"] as? String, "allow")
        XCTAssertEqual(updatedInput["command"] as? String, "echo argo-smoke")
    }
}

/// Captures the raw `Data` frame the server hands to its handler. The
/// project enables `SWIFT_APPROACHABLE_CONCURRENCY`, which would otherwise
/// infer @MainActor isolation for this helper — and a main-actor deinit
/// hop trips a libmalloc abort in XCTest's deterministic dealloc check on
/// this Swift/macOS combination. `nonisolated` opts back out. Reads happen
/// only on the main thread after `wait(for:)` returns, so the @unchecked
/// Sendable is sound.
nonisolated final class AgentNotifyFrameCapture: @unchecked Sendable {
    var value: Data?

    func set(_ value: Data) {
        self.value = value
    }
}

nonisolated final class AgentNotifyControlResponseCapture: @unchecked Sendable {
    var value: ArgoControlResponse??

    func set(_ value: ArgoControlResponse??) {
        self.value = value
    }
}

nonisolated final class AgentNotifyRawResponseCapture: @unchecked Sendable {
    var value: Data??

    func set(_ value: Data??) {
        self.value = value
    }
}

nonisolated final class ClaudeHookRecordingHost: ArgoControlHost, @unchecked Sendable {
    private let onNotify: (AgentNotifyRequest) -> Void

    init(onNotify: @escaping (AgentNotifyRequest) -> Void) {
        self.onNotify = onNotify
    }

    @MainActor
    func handleNotify(_ request: AgentNotifyRequest) {
        onNotify(request)
    }

    @MainActor
    func handleStatus(_ request: ArgoStatusRequest) {}

    @MainActor
    func handleOpen(_ request: ArgoOpenRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true)
    }

    @MainActor
    func handleSplit(_ request: ArgoSplitRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true)
    }

    @MainActor
    func handleSendKeys(_ request: ArgoSendKeysRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true)
    }

    @MainActor
    func handleSessionList(_ request: ArgoSessionListRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true)
    }

    @MainActor
    func handleRead(_ request: ArgoReadRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true, text: "", lineCount: 0)
    }

    @MainActor
    func handleAgents(_ request: ArgoAgentsRequest) -> ArgoControlResponse {
        ArgoControlResponse(ok: true, agents: [])
    }
}
