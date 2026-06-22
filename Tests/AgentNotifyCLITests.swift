//
//  AgentNotifyCLITests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class AgentNotifyCLITests: XCTestCase {
    func testParsePositionalTitleAndBody() throws {
        let options = try AgentNotifyCLI.parse(arguments: ["Build done", "All tests pass"])
        XCTAssertEqual(options.title, "Build done")
        XCTAssertEqual(options.body, "All tests pass")
    }

    func testParseLongFlags() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "--title", "Claude waiting",
            "--body", "needs your input",
            "--pane", "ABC",
            "--workspace", "WSX",
            "--agent", "Claude",
        ])
        XCTAssertEqual(options.title, "Claude waiting")
        XCTAssertEqual(options.body, "needs your input")
        XCTAssertEqual(options.paneID, "ABC")
        XCTAssertEqual(options.workspaceID, "WSX")
        XCTAssertEqual(options.agentName, "Claude")
    }

    func testParseShortFlags() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "-t", "Title",
            "-m", "Body",
            "-p", "PANE",
            "-a", "Codex",
        ])
        XCTAssertEqual(options.title, "Title")
        XCTAssertEqual(options.body, "Body")
        XCTAssertEqual(options.paneID, "PANE")
        XCTAssertEqual(options.agentName, "Codex")
    }

    func testParseApprovalOptions() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "--approval",
            "--title", "Approve",
            "--body", "Run tests?",
            "--option", "Allow=1\\n",
            "--option", "Deny=2\\n",
            "--session", "s1",
            "--source", "approval-1",
            "--current-tool", "exec_command",
            "--command-preview", "xcodebuild test"
        ])
        let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])

        XCTAssertEqual(request.kind, .approval)
        XCTAssertEqual(request.sessionID, "s1")
        XCTAssertEqual(request.sourceID, "approval-1")
        XCTAssertEqual(request.currentTool, "exec_command")
        XCTAssertEqual(request.commandPreview, "xcodebuild test")
        XCTAssertEqual(request.options?.map(\.label), ["Allow", "Deny"])
        XCTAssertEqual(request.options?.map(\.responseText), ["1\n", "2\n"])
    }

    func testParseApprovalAffectedPath() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "--approval",
            "--title", "Approve",
            "--command-preview", "xcodebuild test",
            "--affected-path", "/tmp/repo",
            "--option", "Allow=1\\n",
            "--option", "Deny=2\\n"
        ])
        let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])

        XCTAssertEqual(request.kind, .approval)
        XCTAssertEqual(request.commandPreview, "xcodebuild test")
        XCTAssertEqual(request.affectedPath, "/tmp/repo")
    }

    func testParseQuestionPromptAlias() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "--question",
            "--prompt", "Which target?",
            "--option", "Production",
            "--option", "Staging"
        ])
        let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])

        XCTAssertEqual(request.kind, .question)
        XCTAssertEqual(request.title, "Which target?")
        XCTAssertNil(request.body)
        XCTAssertEqual(request.options?.map(\.label), ["Production", "Staging"])
        XCTAssertEqual(request.options?.map(\.responseText), ["Production\n", "Staging\n"])
    }

    func testParseCompletedSummaryAndToolAliases() throws {
        let options = try AgentNotifyCLI.parse(arguments: [
            "--completed",
            "--summary", "All tests passed",
            "--tool", "Codex"
        ])
        let request = try AgentNotifyCLI.makeRequest(from: options, environment: [:])

        XCTAssertEqual(request.kind, .completed)
        XCTAssertEqual(request.title, "All tests passed")
        XCTAssertEqual(request.toolName, "Codex")
    }

    func testParseHelpAndVersion() throws {
        XCTAssertTrue(try AgentNotifyCLI.parse(arguments: ["--help"]).showHelp)
        XCTAssertTrue(try AgentNotifyCLI.parse(arguments: ["-h"]).showHelp)
        XCTAssertTrue(try AgentNotifyCLI.parse(arguments: ["--version"]).showVersion)
        XCTAssertTrue(try AgentNotifyCLI.parse(arguments: ["-V"]).showVersion)
    }

    func testParseRejectsUnknownFlag() {
        XCTAssertThrowsError(try AgentNotifyCLI.parse(arguments: ["--bogus"])) { error in
            XCTAssertEqual(error as? AgentNotifyCLI.ParseError, .unknownFlag("--bogus"))
        }
    }

    func testParseRejectsFlagWithoutValue() {
        XCTAssertThrowsError(try AgentNotifyCLI.parse(arguments: ["--title"])) { error in
            XCTAssertEqual(error as? AgentNotifyCLI.ParseError, .missingValue(flag: "--title"))
        }
    }

    func testMakeRequestPullsPaneIDFromEnvironmentWhenAbsent() throws {
        let options = try AgentNotifyCLI.parse(arguments: ["--title", "Done"])
        let request = try AgentNotifyCLI.makeRequest(
            from: options,
            environment: ["ARGO_PANE_ID": "env-pane-id"]
        )
        XCTAssertEqual(request.paneID, "env-pane-id")
    }

    func testMakeRequestPrefersExplicitPaneIDOverEnvironment() throws {
        let options = try AgentNotifyCLI.parse(arguments: ["--title", "T", "--pane", "explicit"])
        let request = try AgentNotifyCLI.makeRequest(
            from: options,
            environment: ["ARGO_PANE_ID": "env-pane-id"]
        )
        XCTAssertEqual(request.paneID, "explicit")
    }

    func testMakeRequestRejectsMissingTitleAndBody() {
        let options = AgentNotifyCLI.Options()
        XCTAssertThrowsError(try AgentNotifyCLI.makeRequest(from: options, environment: [:])) { error in
            XCTAssertEqual(error as? AgentNotifyCLI.ParseError, .missingTitleAndBody)
        }
    }

    func testRunReturnsOKOnSuccess() {
        var captured: AgentNotifyRequest?
        var stderrOutput = ""
        let exit = AgentNotifyCLI.run(
            arguments: ["Build done"],
            send: { captured = $0 },
            stdoutWriter: { _ in },
            stderrWriter: { stderrOutput += $0 },
            environment: [:]
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertEqual(captured?.title, "Build done")
        XCTAssertTrue(stderrOutput.isEmpty, "stderr should be empty on success, got: \(stderrOutput)")
    }

    func testRunReturnsUnavailableWhenServerMissing() {
        let exit = AgentNotifyCLI.run(
            arguments: ["Build done"],
            send: { _ in throw AgentNotifyError.socketUnavailable },
            stdoutWriter: { _ in },
            stderrWriter: { _ in },
            environment: [:]
        )
        XCTAssertEqual(exit, .unavailable)
    }

    func testRunReturnsUsageOnMissingTitleAndBody() {
        let exit = AgentNotifyCLI.run(
            arguments: [],
            send: { _ in XCTFail("send should not be called") },
            stdoutWriter: { _ in },
            stderrWriter: { _ in },
            environment: [:]
        )
        XCTAssertEqual(exit, .usage)
    }

    func testRunReturnsOKOnHelp() {
        var stdoutOutput = ""
        let exit = AgentNotifyCLI.run(
            arguments: ["--help"],
            send: { _ in XCTFail("send should not be called") },
            stdoutWriter: { stdoutOutput += $0 },
            stderrWriter: { _ in },
            environment: [:]
        )
        XCTAssertEqual(exit, .ok)
        XCTAssertTrue(stdoutOutput.contains("argo notify"))
    }

    func testRunClaudeHookSendsControlFrameAndWritesReturnedStdout() throws {
        let input = Data(#"{"cwd":"/tmp/demo","hook_event_name":"PermissionRequest","session_id":"s1"}"#.utf8)
        var capturedFrame: Data?
        var capturedSocketURL: URL?
        var capturedTimeout: TimeInterval?
        var stdout = Data()
        let response = ClaudeHookNotifyBridge.encodeControlResponse(.success(stdout: "hook-output\n"))

        let exit = AgentNotifyCLI.runClaudeHook(
            input: input,
            send: { frame, socketURL, timeout in
                capturedFrame = frame
                capturedSocketURL = socketURL
                capturedTimeout = timeout
                return response
            },
            stdoutWriter: { stdout.append($0) },
            stderrWriter: { _ in },
            environment: ["ARGO_PANE_ID": "pane-123"],
            executablePath: "/tmp/Debug/Argo.app/Contents/MacOS/Argo"
        )

        XCTAssertEqual(exit, .ok)
        XCTAssertEqual(stdout, Data("hook-output\n".utf8))
        XCTAssertEqual(capturedTimeout, ClaudeHookNotifyBridge.interactiveTimeout)
        XCTAssertEqual(
            capturedSocketURL,
            AgentNotifySocketPath.resolveExecutableSocketURL(
                executablePath: "/tmp/Debug/Argo.app/Contents/MacOS/Argo"
            )
        )
        let frame = try XCTUnwrap(capturedFrame)
        let request = try ClaudeHookNotifyBridge.decodeControlRequest(from: frame)
        XCTAssertEqual(request.paneID, "pane-123")
        XCTAssertEqual(request.payload.sessionID, "s1")
    }

    func testRunClaudeHookFallsBackToSharedSocketWhenScopedSocketIsUnavailable() throws {
        let input = Data(#"{"cwd":"/tmp/demo","hook_event_name":"PermissionRequest","session_id":"s1"}"#.utf8)
        let response = ClaudeHookNotifyBridge.encodeControlResponse(.success(stdout: "hook-output\n"))
        var attemptedSocketURLs: [URL] = []
        var stdout = Data()

        let exit = AgentNotifyCLI.runClaudeHook(
            input: input,
            send: { _, socketURL, _ in
                attemptedSocketURLs.append(socketURL)
                if attemptedSocketURLs.count == 1 {
                    throw AgentNotifyError.socketUnavailable
                }
                return response
            },
            stdoutWriter: { stdout.append($0) },
            stderrWriter: { _ in },
            environment: [:],
            executablePath: "/tmp/Debug/Argo.app/Contents/MacOS/Argo"
        )

        XCTAssertEqual(exit, .ok)
        XCTAssertEqual(stdout, Data("hook-output\n".utf8))
        XCTAssertEqual(attemptedSocketURLs, [
            AgentNotifySocketPath.resolveExecutableSocketURL(
                executablePath: "/tmp/Debug/Argo.app/Contents/MacOS/Argo"
            ),
            AgentNotifySocketPath.resolveSocketURL(),
        ])
    }
}
