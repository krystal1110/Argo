//
//  ClaudeHookNotifyBridgeTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class ClaudeHookNotifyBridgeTests: XCTestCase {
    func testAskUserQuestionPermissionRequestBecomesQuestionNotifyRequest() throws {
        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session-1",
          "tool_name": "AskUserQuestion",
          "tool_input": {
            "questions": [
              {
                "question": "Pick a deploy target?",
                "header": "Target",
                "options": [
                  { "label": "Production", "description": "Ship to real users" },
                  { "label": "Staging", "description": "Internal validation" }
                ]
              }
            ]
          }
        }
        """

        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(
            from: Data(json.utf8),
            environment: ["ARGO_PANE_ID": "pane-123"]
        ))

        XCTAssertEqual(request.kind, .question)
        XCTAssertEqual(request.title, "Pick a deploy target?")
        XCTAssertEqual(request.agentName, "Claude")
        XCTAssertEqual(request.toolName, "Claude")
        XCTAssertEqual(request.currentTool, "AskUserQuestion")
        XCTAssertEqual(request.sessionID, "claude-session-1")
        XCTAssertEqual(request.sourceID, "claude:claude-session-1:question")
        XCTAssertEqual(request.paneID, "pane-123")
        XCTAssertEqual(request.affectedPath, "/tmp/demo")
        XCTAssertEqual(request.options?.map(\.label), ["Production", "Staging"])
        XCTAssertEqual(request.options?.map(\.responseText), ["1\n", "2\n"])
    }

    func testToolPermissionRequestBecomesApprovalNotifyRequest() throws {
        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session-2",
          "tool_name": "Bash",
          "tool_input": {
            "command": "xcodebuild test",
            "description": "Run the focused test suite"
          }
        }
        """

        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(
            from: Data(json.utf8),
            environment: [:]
        ))

        XCTAssertEqual(request.kind, .approval)
        XCTAssertEqual(request.title, "Allow Bash")
        XCTAssertEqual(request.body, "Claude wants to run Bash.")
        XCTAssertEqual(request.currentTool, "Bash")
        XCTAssertEqual(request.commandPreview, "xcodebuild test")
        XCTAssertEqual(request.affectedPath, "xcodebuild test")
        XCTAssertEqual(request.options?.map(\.label), ["Yes", "No"])
        XCTAssertEqual(request.options?.map(\.responseText), ["1\n", "2\n"])
    }

    func testToolPermissionRequestWithSuggestionMirrorsClaudeNativeOptions() throws {
        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session-suggested",
          "tool_name": "Bash",
          "tool_input": {
            "command": "mkdir -p /tmp/rmrf-test-loop && rm -rf /tmp/rmrf-test-loop && echo \\"done\\"",
            "description": "Run rm -rf test command"
          },
          "permission_suggestions": [
            {
              "type": "addRules",
              "destination": "localSettings",
              "rules": [
                {
                  "toolName": "Bash",
                  "ruleContent": "mkdir -p /tmp/rmrf-test-loop"
                }
              ],
              "behavior": "allow"
            }
          ]
        }
        """

        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(
            from: Data(json.utf8),
            environment: [:]
        ))

        XCTAssertEqual(request.kind, .approval)
        XCTAssertEqual(request.options?.map(\.label), [
            "Yes",
            "Yes, and don't ask again for: mkdir -p /tmp/rmrf-test-loop",
            "No"
        ])
        XCTAssertEqual(request.options?.map(\.responseText), ["1\n", "2\n", "3\n"])
    }

    func testSuggestedApprovalResponseAllowsWithUpdatedPermissions() throws {
        ClaudeHookInteractionRegistry.shared.clearAll()
        defer { ClaudeHookInteractionRegistry.shared.clearAll() }

        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session-suggested",
          "tool_name": "Bash",
          "tool_input": {
            "command": "mkdir -p /tmp/rmrf-test-loop && rm -rf /tmp/rmrf-test-loop && echo \\"done\\""
          },
          "permission_suggestions": [
            {
              "type": "addRules",
              "destination": "localSettings",
              "rules": [
                {
                  "toolName": "Bash",
                  "ruleContent": "mkdir -p /tmp/rmrf-test-loop"
                }
              ],
              "behavior": "allow"
            }
          ]
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        let request = try XCTUnwrap(ClaudeHookNotifyBridge.notifyRequest(from: payload, paneID: nil))
        let pending = try XCTUnwrap(ClaudeHookInteractionRegistry.shared.register(payload: payload, request: request))

        XCTAssertTrue(ClaudeHookInteractionRegistry.shared.resolve(sessionID: "claude-session-suggested", responseText: "2\n"))

        let result = try XCTUnwrap(pending.wait(timeout: 0.1))
        let stdout = try ClaudeHookNotifyBridge.stdout(for: result)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        let updatedPermissions = try XCTUnwrap(decision["updatedPermissions"] as? [[String: Any]])
        let firstUpdate = try XCTUnwrap(updatedPermissions.first)
        let rules = try XCTUnwrap(firstUpdate["rules"] as? [[String: Any]])
        let firstRule = try XCTUnwrap(rules.first)

        XCTAssertEqual(decision["behavior"] as? String, "allow")
        XCTAssertEqual(firstUpdate["type"] as? String, "addRules")
        XCTAssertEqual(firstUpdate["destination"] as? String, "localSettings")
        XCTAssertEqual(firstRule["toolName"] as? String, "Bash")
        XCTAssertEqual(firstRule["ruleContent"] as? String, "mkdir -p /tmp/rmrf-test-loop")
    }

    func testNonPermissionHookIsIgnored() throws {
        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PreToolUse",
          "session_id": "claude-session-3",
          "tool_name": "Bash"
        }
        """

        XCTAssertNil(try ClaudeHookNotifyBridge.notifyRequest(from: Data(json.utf8), environment: [:]))
    }

    func testControlFrameWrapsHookPayloadWithCommandAndPane() throws {
        let json = #"{"cwd":"/tmp/demo","hook_event_name":"PermissionRequest","session_id":"s1"}"#

        let frame = try XCTUnwrap(ClaudeHookNotifyBridge.controlFrame(
            from: Data(json.utf8),
            environment: ["ARGO_PANE_ID": "pane-123"]
        ))
        let request = try ClaudeHookNotifyBridge.decodeControlRequest(from: frame)

        XCTAssertEqual(request.paneID, "pane-123")
        XCTAssertEqual(request.payload.sessionID, "s1")
        XCTAssertEqual(request.payload.hookEventName, .permissionRequest)
    }

    func testQuestionResponseStdoutAllowsWithUpdatedAnswers() throws {
        let json = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "session_id": "claude-session-1",
          "tool_name": "AskUserQuestion",
          "tool_input": {
            "questions": [
              {
                "question": "Pick a deploy target?",
                "header": "Target",
                "options": [
                  { "label": "Production", "description": "Ship to real users" },
                  { "label": "Staging", "description": "Internal validation" }
                ]
              }
            ]
          }
        }
        """
        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
        let result = ClaudeHookInteractionResult(
            decision: .allow(updatedInput: payload.updatedQuestionInput(answeredBy: "2\n"))
        )

        let stdout = try ClaudeHookNotifyBridge.stdout(for: result)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any])
        let hookSpecificOutput = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(hookSpecificOutput["decision"] as? [String: Any])
        let updatedInput = try XCTUnwrap(decision["updatedInput"] as? [String: Any])
        let answers = try XCTUnwrap(updatedInput["answers"] as? [String: Any])

        XCTAssertEqual(object["continue"] as? Bool, true)
        XCTAssertEqual(object["suppressOutput"] as? Bool, true)
        XCTAssertEqual(hookSpecificOutput["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual(decision["behavior"] as? String, "allow")
        XCTAssertEqual(answers["Pick a deploy target?"] as? String, "Staging")
    }

    func testCLIStdoutExtractsHookOutputFromControlResponse() throws {
        let response = ClaudeHookNotifyBridge.encodeControlResponse(.success(stdout: "hello\n"))
        let stdout = try ClaudeHookNotifyBridge.cliStdout(from: response)

        XCTAssertEqual(stdout, Data("hello\n".utf8))
    }
}
