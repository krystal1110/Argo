//
//  ArgoControlDispatcherTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

/// Exercises `ArgoControlDispatcher` against a recording fake host so we
/// can assert auth gating and command routing without spinning up the
/// AppKit application.
@MainActor
final class ArgoControlDispatcherTests: XCTestCase {

    private var host: RecordingHost!
    private var dispatcher: ArgoControlDispatcher!

    override func setUp() {
        super.setUp()
        host = RecordingHost()
        dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { "secret" })
    }

    override func tearDown() {
        host = nil
        dispatcher = nil
        super.tearDown()
    }

    // MARK: - notify (legacy, no auth)

    func testNotifyFrameWithoutCmdRoutesToHandleNotify() {
        // Field names must match AgentNotifyRequest.CodingKeys: v / title / body / pane.
        let frame = makeFrame([
            "v": 1,
            "title": "Build done",
            "body": "All tests pass",
            "pane": "p1",
        ])
        let response = dispatcher.dispatch(frame: frame)
        XCTAssertNil(response, "notify is fire-and-forget; no response bytes")
        XCTAssertEqual(host.notifyCalls.count, 1)
        XCTAssertEqual(host.notifyCalls.first?.title, "Build done")
        XCTAssertEqual(host.notifyCalls.first?.paneID, "p1")
    }

    func testNotifyFrameWithExplicitCmdAlsoRoutes() {
        let frame = makeFrame(["v": 1, "cmd": "notify", "title": "hi"])
        _ = dispatcher.dispatch(frame: frame)
        XCTAssertEqual(host.notifyCalls.count, 1)
    }

    // MARK: - Ping (socket health, no auth)

    func testPingDoesNotRequireTokenAndReturnsExecutablePath() throws {
        dispatcher = ArgoControlDispatcher(
            host: host,
            tokenResolver: { nil },
            executablePathProvider: { "/debug/Argo.app/Contents/MacOS/Argo" }
        )
        let frame = makeFrame(["cmd": "ping"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.executablePath, "/debug/Argo.app/Contents/MacOS/Argo")
        XCTAssertTrue(host.openCalls.isEmpty)
        XCTAssertTrue(host.notifyCalls.isEmpty)
    }

    func testInvalidEnvelopeReturnsError() throws {
        let response = try XCTUnwrap(dispatcher.dispatch(frame: Data("not-json".utf8)))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertFalse(decoded.ok)
        XCTAssertEqual(decoded.error, "invalid-envelope")
    }

    // MARK: - Auth gate

    func testTokenMismatchIsRejected() throws {
        let frame = makeFrame(["cmd": "open", "token": "wrong", "repo": "/repo"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.ok, false)
        XCTAssertEqual(decoded.error, "token-mismatch")
        XCTAssertTrue(host.openCalls.isEmpty, "auth failure must short-circuit before host call")
    }

    func testMissingTokenIsRejected() throws {
        let frame = makeFrame(["cmd": "open", "repo": "/repo"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "token-mismatch")
    }

    func testControlDisabledWhenResolverReturnsNil() throws {
        dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { nil })
        let frame = makeFrame(["cmd": "open", "token": "anything", "repo": "/repo"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "control-disabled")
    }

    func testControlDisabledWhenResolverReturnsEmpty() throws {
        dispatcher = ArgoControlDispatcher(host: host, tokenResolver: { "" })
        let frame = makeFrame(["cmd": "split", "token": "anything"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "control-disabled")
    }

    func testHostAbsentReturnsAppNotReady() throws {
        let detached = ArgoControlDispatcher(host: nil, tokenResolver: { "secret" })
        let frame = makeFrame(["cmd": "open", "token": "secret", "repo": "/repo"])
        let response = try XCTUnwrap(detached.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "app-not-ready")
    }

    // MARK: - Open

    func testOpenRoutesPayloadToHost() throws {
        let frame = makeFrame([
            "cmd": "open",
            "token": "secret",
            "repo": "/repo",
            "worktree": "/repo/wt",
        ])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(host.openCalls.count, 1)
        XCTAssertEqual(host.openCalls.first?.repo, "/repo")
        XCTAssertEqual(host.openCalls.first?.worktree, "/repo/wt")
    }

    func testOpenWithMissingRepoReturnsInvalidPayload() throws {
        let frame = makeFrame(["cmd": "open", "token": "secret"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "invalid-open-payload")
    }

    // MARK: - Split

    func testSplitRoutesAxisAndPane() throws {
        let frame = makeFrame([
            "cmd": "split",
            "token": "secret",
            "axis": "horizontal",
            "pane": "ABCDEF12-3456-7890-1234-567890ABCDEF",
        ])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(host.splitCalls.count, 1)
        XCTAssertEqual(host.splitCalls.first?.axis, "horizontal")
        XCTAssertEqual(host.splitCalls.first?.pane, "ABCDEF12-3456-7890-1234-567890ABCDEF")
    }

    func testSplitWithEmptyPayloadStillDispatches() throws {
        let frame = makeFrame(["cmd": "split", "token": "secret"])
        _ = dispatcher.dispatch(frame: frame)
        XCTAssertEqual(host.splitCalls.count, 1)
        XCTAssertNil(host.splitCalls.first?.axis)
        XCTAssertNil(host.splitCalls.first?.pane)
    }

    // MARK: - Send keys

    func testSendKeysRequiresTextField() throws {
        let frame = makeFrame([
            "cmd": "send-keys",
            "token": "secret",
            "pane": "p1",
            // text intentionally missing
        ])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertEqual(decoded.error, "invalid-send-keys-payload")
    }

    func testSendKeysRoutesText() throws {
        let frame = makeFrame([
            "cmd": "send-keys",
            "token": "secret",
            "pane": "p1",
            "text": "ls -la\n",
        ])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(host.sendKeysCalls.first?.text, "ls -la\n")
        XCTAssertEqual(host.sendKeysCalls.first?.pane, "p1")
    }

    // MARK: - Session list

    func testSessionListReturnsHostsSessions() throws {
        host.stubbedSessions = [
            ArgoControlSession(
                workspaceID: "ws-1",
                workspaceName: "demo",
                paneID: "p-1",
                cwd: "/tmp/x",
                branch: "main",
                listeningPorts: [3000]
            )
        ]
        let frame = makeFrame(["cmd": "session-list", "token": "secret"])
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.sessions?.count, 1)
        XCTAssertEqual(decoded.sessions?.first?.workspaceName, "demo")
        XCTAssertEqual(decoded.sessions?.first?.listeningPorts, [3000])
    }

    // MARK: - Trailing newline tolerance

    func testTrailingNewlineIsStrippedBeforeDecoding() throws {
        var frame = makeFrame(["cmd": "open", "token": "secret", "repo": "/r"])
        frame.append(0x0A)
        let response = try XCTUnwrap(dispatcher.dispatch(frame: frame))
        let decoded = try JSONDecoder().decode(ArgoControlResponse.self, from: response)
        XCTAssertTrue(decoded.ok)
    }

    // MARK: - Helpers

    private func makeFrame(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }
}

// MARK: - Recording fake host

@MainActor
private final class RecordingHost: ArgoControlHost {
    var notifyCalls: [AgentNotifyRequest] = []
    var openCalls: [ArgoOpenRequest] = []
    var splitCalls: [ArgoSplitRequest] = []
    var sendKeysCalls: [ArgoSendKeysRequest] = []
    var sessionListCalls = 0
    var stubbedSessions: [ArgoControlSession] = []

    func handleNotify(_ request: AgentNotifyRequest) {
        notifyCalls.append(request)
    }

    func handleOpen(_ request: ArgoOpenRequest) -> ArgoControlResponse {
        openCalls.append(request)
        return .success
    }

    func handleSplit(_ request: ArgoSplitRequest) -> ArgoControlResponse {
        splitCalls.append(request)
        return .success
    }

    func handleSendKeys(_ request: ArgoSendKeysRequest) -> ArgoControlResponse {
        sendKeysCalls.append(request)
        return .success
    }

    func handleSessionList(_ request: ArgoSessionListRequest) -> ArgoControlResponse {
        sessionListCalls += 1
        return ArgoControlResponse(ok: true, error: nil, sessions: stubbedSessions)
    }
}
