//
//  ArgoControlCLITests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

/// Drives the CLI argument parsers with stubbed I/O so we can assert exit
/// codes and the exact bytes that would have been written to the socket
/// without standing up a real server.
final class ArgoControlCLITests: XCTestCase {

    // MARK: - open

    func testOpenRequiresRepoPositional() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: [],
            send: { _ in nil },
            environment: ["ARGO_CONTROL_TOKEN": "t"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .usage)
    }

    func testOpenRequiresToken() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: ["/repo"],
            send: { _ in nil },
            environment: [:],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .authRequired)
        XCTAssertTrue(stderr.text.contains("--token"))
    }

    func testOpenEncodesFrameWithRepoAndWorktree() throws {
        let captured = FrameCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: ["/repo", "--worktree", "/repo/wt"],
            send: captured.capture,
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["cmd"] as? String, "open")
        XCTAssertEqual(json["token"] as? String, "secret")
        XCTAssertEqual(json["repo"] as? String, "/repo")
        XCTAssertEqual(json["worktree"] as? String, "/repo/wt")
    }

    func testOpenSurfacesServerErrorAsIOFailure() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: ["/repo"],
            send: { _ in ArgoControlResponse.failure("boom") },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .ioError)
        XCTAssertTrue(stderr.text.contains("boom"))
    }

    func testOpenMapsTokenMismatchToAuthExitCode() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: ["/repo"],
            send: { _ in ArgoControlResponse.failure("token-mismatch") },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .authRequired)
    }

    func testOpenReportsUnavailableWhenSocketDown() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runOpen(
            arguments: ["/repo"],
            send: { _ in throw AgentNotifyError.socketUnavailable },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .unavailable)
        XCTAssertTrue(stderr.text.contains("not running"))
    }

    // MARK: - split

    func testSplitDefaultsAndFallsBackToEnvPane() throws {
        let captured = FrameCollector()
        _ = ArgoControlCLI.runSplit(
            arguments: [],
            send: captured.capture,
            environment: [
                "ARGO_CONTROL_TOKEN": "secret",
                ArgoAgentNotifyEnvironment.paneIDKey: "pane-from-env",
            ],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["cmd"] as? String, "split")
        XCTAssertEqual(json["pane"] as? String, "pane-from-env")
        // axis omitted when not provided — server defaults to vertical
        XCTAssertNil(json["axis"])
    }

    func testSplitHorizontalAxisIsForwarded() throws {
        let captured = FrameCollector()
        _ = ArgoControlCLI.runSplit(
            arguments: ["--axis", "horizontal"],
            send: captured.capture,
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["axis"] as? String, "horizontal")
    }

    // MARK: - send-keys

    func testSendKeysAcceptsPositionalPaneAndText() throws {
        let captured = FrameCollector()
        let exit = ArgoControlCLI.runSendKeys(
            arguments: ["pane-uuid", "ls -la\n"],
            send: captured.capture,
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["pane"] as? String, "pane-uuid")
        XCTAssertEqual(json["text"] as? String, "ls -la\n")
    }

    func testSendKeysFlagFormBeatsPositionalAbsence() throws {
        let captured = FrameCollector()
        let exit = ArgoControlCLI.runSendKeys(
            arguments: ["--pane", "p1", "--text", "y"],
            send: captured.capture,
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["pane"] as? String, "p1")
        XCTAssertEqual(json["text"] as? String, "y")
    }

    func testSendKeysRequiresPane() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runSendKeys(
            arguments: ["--text", "hi"],
            send: { _ in nil },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .usage)
        XCTAssertTrue(stderr.text.contains("pane is required"))
    }

    func testSendKeysRequiresText() {
        let stderr = StreamCollector()
        let exit = ArgoControlCLI.runSendKeys(
            arguments: ["--pane", "p1"],
            send: { _ in nil },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: { _ in },
            stderrWriter: stderr.write
        )
        XCTAssertEqual(exit, .usage)
        XCTAssertTrue(stderr.text.contains("text is required"))
    }

    // MARK: - session list

    func testSessionListNoLongerRequiresTokenAndPrintsStatus() {
        let stdout = StreamCollector()
        let exit = ArgoControlCLI.runSessionList(
            arguments: [],
            send: { _ in
                ArgoControlResponse(ok: true, sessions: [
                    ArgoControlSession(
                        workspaceID: "w1",
                        workspaceName: "demo",
                        paneID: "p-1",
                        cwd: "/tmp/x",
                        branch: "main",
                        listeningPorts: [],
                        status: "waiting"
                    )
                ])
            },
            environment: [:],
            stdoutWriter: stdout.write,
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertTrue(stdout.text.contains("demo [main] <waiting> p-1 /tmp/x"))
    }

    func testSessionListPrintsHumanLines() {
        let stdout = StreamCollector()
        let exit = ArgoControlCLI.runSessionList(
            arguments: [],
            send: { _ in
                ArgoControlResponse(
                    ok: true,
                    error: nil,
                    sessions: [
                        ArgoControlSession(
                            workspaceID: "w1",
                            workspaceName: "demo",
                            paneID: "p-1",
                            cwd: "/tmp/x",
                            branch: "main",
                            listeningPorts: [3000, 8080]
                        )
                    ]
                )
            },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: stdout.write,
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertTrue(stdout.text.contains("demo [main] p-1 /tmp/x ports=:3000,:8080"))
    }

    func testSessionListJSONShape() throws {
        let stdout = StreamCollector()
        let exit = ArgoControlCLI.runSessionList(
            arguments: ["--json"],
            send: { _ in
                ArgoControlResponse(
                    ok: true,
                    error: nil,
                    sessions: [
                        ArgoControlSession(
                            workspaceID: "w1",
                            workspaceName: "demo",
                            paneID: "p-1",
                            cwd: "/tmp/x",
                            branch: nil,
                            listeningPorts: []
                        )
                    ]
                )
            },
            environment: ["ARGO_CONTROL_TOKEN": "secret"],
            stdoutWriter: stdout.write,
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let data = Data(stdout.text.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(parsed?.first?["workspace"] as? String, "w1")
        XCTAssertEqual(parsed?.first?["pane"] as? String, "p-1")
    }

    // MARK: - status

    func testStatusEncodesFrameWithoutTokenAndUsesEnvPane() throws {
        let captured = FrameCollector()
        let exit = ArgoControlCLI.runStatus(
            arguments: ["needs-input", "--title", "Approve command", "--agent", "Codex"],
            send: captured.capture,
            environment: [ArgoAgentNotifyEnvironment.paneIDKey: "pane-from-env"],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["cmd"] as? String, "status")
        XCTAssertEqual(json["state"] as? String, "waiting")
        XCTAssertEqual(json["pane"] as? String, "pane-from-env")
        XCTAssertEqual(json["title"] as? String, "Approve command")
        XCTAssertEqual(json["agent"] as? String, "Codex")
        XCTAssertNil(json["token"])
    }

    // MARK: - read

    func testReadEncodesFrameWithoutToken() throws {
        let captured = FrameCollector(response: ArgoControlResponse(ok: true, text: "hello\n", lineCount: 1))
        let exit = ArgoControlCLI.runRead(
            arguments: ["--pane", "p1", "--last", "40", "--scrollback"],
            send: captured.capture,
            environment: [:],
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["cmd"] as? String, "read")
        XCTAssertEqual(json["pane"] as? String, "p1")
        XCTAssertEqual(json["lines"] as? Int, 40)
        XCTAssertEqual(json["scrollback"] as? Bool, true)
        XCTAssertNil(json["token"])
    }

    func testReadWaitStablePollsUntilTextRepeats() {
        var calls = 0
        let exit = ArgoControlCLI.runRead(
            arguments: ["--wait-stable"],
            send: { _ in
                defer { calls += 1 }
                return ArgoControlResponse(ok: true, text: calls == 0 ? "a" : "ab", lineCount: 1)
            },
            environment: [:],
            stdoutWriter: { _ in },
            stderrWriter: { _ in },
            sleeper: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertEqual(calls, 3)
    }

    // MARK: - agents

    func testAgentsPrintsJSON() throws {
        let stdout = StreamCollector()
        let agents = [
            ArgoAgentInfo(
                workspaceID: "w",
                workspaceName: "demo",
                paneID: "p",
                type: "codex",
                name: "Codex",
                status: "running",
                reported: false,
                cwd: "/tmp",
                branch: "main",
                focused: true
            )
        ]
        let exit = ArgoControlCLI.runAgents(
            arguments: ["--json"],
            send: { _ in ArgoControlResponse(ok: true, agents: agents) },
            environment: [:],
            stdoutWriter: stdout.write,
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let data = Data(stdout.text.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(parsed?.first?["type"] as? String, "codex")
    }

    // MARK: - ping

    func testPingEncodesFrameWithoutToken() throws {
        let captured = FrameCollector(response: ArgoControlResponse(
            ok: true,
            error: nil,
            sessions: nil,
            executablePath: "/debug/Argo.app/Contents/MacOS/Argo"
        ))
        let exit = ArgoControlCLI.runPing(
            arguments: [],
            send: captured.capture,
            stdoutWriter: { _ in },
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        let json = try captured.decodedJSON()
        XCTAssertEqual(json["cmd"] as? String, "ping")
        XCTAssertNil(json["token"])
    }

    func testPingPrintsExecutablePath() {
        let stdout = StreamCollector()
        let exit = ArgoControlCLI.runPing(
            arguments: [],
            send: { _ in ArgoControlResponse(
                ok: true,
                error: nil,
                sessions: nil,
                executablePath: "/debug/Argo.app/Contents/MacOS/Argo"
            ) },
            stdoutWriter: stdout.write,
            stderrWriter: { _ in }
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertEqual(stdout.text, "/debug/Argo.app/Contents/MacOS/Argo\n")
    }

    // MARK: - encodeFrame helper

    func testEncodeFrameOmitsNilPayloadEntries() throws {
        let frame = ArgoControlCLI.encodeFrame(
            cmd: "split",
            token: "t",
            payload: ["pane": nil as Any?, "axis": "vertical"]
        )
        let trimmed = frame.last == 0x0A ? frame.dropLast() : frame
        let json = try JSONSerialization.jsonObject(with: trimmed) as? [String: Any]
        XCTAssertEqual(json?["cmd"] as? String, "split")
        XCTAssertEqual(json?["axis"] as? String, "vertical")
        XCTAssertEqual(json?["v"] as? Int, 1)
        XCTAssertNil(json?["pane"])
    }

    func testEncodeFrameTerminatesWithNewline() {
        let frame = ArgoControlCLI.encodeFrame(cmd: "notify", token: nil, payload: [:])
        XCTAssertEqual(frame.last, 0x0A)
    }
}

// MARK: - Test fixtures

// `nonisolated` opt-out: the project sets SWIFT_APPROACHABLE_CONCURRENCY,
// which would otherwise infer @MainActor isolation for these helpers. A
// main-actor deinit hop trips a libmalloc abort in XCTest's deterministic
// dealloc check on this Swift/macOS combo, so we keep these strictly
// nonisolated. Reads only happen on the calling test's thread.
nonisolated private final class StreamCollector {
    private(set) var text: String = ""
    func write(_ line: String) { text += line + "\n" }
}

nonisolated private final class FrameCollector {
    private(set) var frame: Data?
    private let response: ArgoControlResponse?

    init(response: ArgoControlResponse? = .success) {
        self.response = response
    }

    func capture(_ data: Data) throws -> ArgoControlResponse? {
        frame = data
        return response
    }

    func decodedJSON() throws -> [String: Any] {
        guard let raw = frame else {
            throw NSError(domain: "FrameCollector", code: -1, userInfo: [NSLocalizedDescriptionKey: "no frame captured"])
        }
        let trimmed = raw.last == 0x0A ? raw.dropLast() : raw
        guard let object = try JSONSerialization.jsonObject(with: trimmed) as? [String: Any] else {
            throw NSError(domain: "FrameCollector", code: -2, userInfo: [NSLocalizedDescriptionKey: "frame was not a JSON object"])
        }
        return object
    }
}
