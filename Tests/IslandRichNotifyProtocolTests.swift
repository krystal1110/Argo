import XCTest
@testable import Argo

final class IslandRichNotifyProtocolTests: XCTestCase {
    func testRichNotifyRoundTripPreservesApprovalFields() throws {
        let request = AgentNotifyRequest(
            title: "Approve command",
            body: "Run tests?",
            paneID: "pane-1",
            workspaceID: "workspace-1",
            agentName: "Codex",
            kind: .approval,
            sessionID: "session-1",
            sourceID: "approval-1",
            currentTool: "exec_command",
            commandPreview: "xcodebuild test",
            options: [
                AgentNotifyOption(label: "Allow", responseText: "1\n"),
                AgentNotifyOption(label: "Deny", responseText: "2\n")
            ]
        )

        let decoded = try AgentNotifyProtocol.decode(try AgentNotifyProtocol.encode(request))

        XCTAssertEqual(decoded.kind, .approval)
        XCTAssertEqual(decoded.sessionID, "session-1")
        XCTAssertEqual(decoded.sourceID, "approval-1")
        XCTAssertEqual(decoded.options?.map(\.label), ["Allow", "Deny"])
        XCTAssertEqual(decoded.commandPreview, "xcodebuild test")
    }

    func testLegacyNotifyDecodeStillWorks() throws {
        let data = Data(#"{"v":1,"title":"Done","body":"ok","pane":"abc"}"#.utf8)

        let decoded = try AgentNotifyProtocol.decode(data)

        XCTAssertEqual(decoded.title, "Done")
        XCTAssertEqual(decoded.body, "ok")
        XCTAssertEqual(decoded.paneID, "abc")
        XCTAssertNil(decoded.kind)
    }

    func testRichNotifyRoundTripPreservesAffectedPath() throws {
        let request = AgentNotifyRequest(
            title: "Approve command",
            body: "Run tests?",
            paneID: "pane-1",
            workspaceID: "workspace-1",
            agentName: "Codex",
            kind: .approval,
            sessionID: "session-1",
            sourceID: "approval-1",
            currentTool: "exec_command",
            commandPreview: "xcodebuild test",
            affectedPath: "/tmp/repo",
            options: [
                AgentNotifyOption(label: "Allow", responseText: "1\n"),
                AgentNotifyOption(label: "Deny", responseText: "2\n")
            ]
        )

        let decoded = try AgentNotifyProtocol.decode(try AgentNotifyProtocol.encode(request))

        XCTAssertEqual(decoded.affectedPath, "/tmp/repo")

        let event = try XCTUnwrap(decoded.followupEvent(
            sessionID: "session-1",
            summary: "Run tests?",
            timestamp: Date(timeIntervalSince1970: 10)
        ))
        guard case let .permissionRequested(payload) = event else {
            return XCTFail("Expected permissionRequested")
        }
        XCTAssertEqual(payload.request.affectedPath, "/tmp/repo")
    }

    func testApprovalFollowupPreservesAllActionOptions() throws {
        let request = AgentNotifyRequest(
            title: "Approve command",
            body: "Run tests?",
            kind: .approval,
            options: [
                AgentNotifyOption(label: "Deny", responseText: "2\n"),
                AgentNotifyOption(label: "Allow once", responseText: "1\n"),
                AgentNotifyOption(label: "Always allow", responseText: "always\n")
            ]
        )

        let event = try XCTUnwrap(request.followupEvent(
            sessionID: "session-1",
            summary: "Run tests?",
            timestamp: Date(timeIntervalSince1970: 10)
        ))
        guard case let .permissionRequested(payload) = event else {
            return XCTFail("Expected permissionRequested")
        }
        XCTAssertEqual(payload.request.actions.map(\.title), ["Deny", "Allow once", "Always allow"])
        XCTAssertEqual(payload.request.actions.map(\.responseText), ["2\n", "1\n", "always\n"])
    }
}
