//
//  AgentStatusStoreTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class AgentStatusStoreTests: XCTestCase {
    override func tearDown() {
        AgentStatusStore.shared.clearAll()
        super.tearDown()
    }

    func testReportedStateParsesSynonyms() {
        XCTAssertEqual(AgentReportedState(cliValue: "working"), .running)
        XCTAssertEqual(AgentReportedState(cliValue: "needs-input"), .waiting)
        XCTAssertEqual(AgentReportedState(cliValue: "success"), .done)
        XCTAssertEqual(AgentReportedState(cliValue: "failed"), .error)
        XCTAssertNil(AgentReportedState(cliValue: "sleeping"))
    }

    func testStoreUpdateStateAndClear() {
        let pane = UUID()
        AgentStatusStore.shared.update(
            pane: pane,
            state: .waiting,
            title: "Approve command",
            agentName: "Codex"
        )

        XCTAssertEqual(AgentStatusStore.shared.state(for: pane), .waiting)
        XCTAssertEqual(AgentStatusStore.shared.entries[pane]?.title, "Approve command")
        XCTAssertEqual(AgentStatusStore.shared.entries[pane]?.agentName, "Codex")

        AgentStatusStore.shared.clear(pane: pane)
        XCTAssertNil(AgentStatusStore.shared.state(for: pane))
    }

    func testControlTokenRulesKeepMutatingCommandsProtected() {
        XCTAssertFalse(ArgoControlCommand.notify.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.ping.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.status.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.sessionList.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.read.requiresControlToken)
        XCTAssertFalse(ArgoControlCommand.agents.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.open.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.split.requiresControlToken)
        XCTAssertTrue(ArgoControlCommand.sendKeys.requiresControlToken)
    }
}
