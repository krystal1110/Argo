//
//  ArgoGhosttyControllerTests.swift
//  ArgoTests
//
//  Author: Codex
//

import XCTest
import GhosttyKit
@testable import Argo

final class ArgoGhosttyControllerTests: XCTestCase {
    func testCommandFinishedDoesNotReportProcessExit() {
        XCTAssertFalse(
            argoGhosttyShouldReportProcessExitForCommandFinished(
                ghostty_action_command_finished_s(
                    exit_code: 0,
                    duration: 42
                )
            )
        )
    }

    func testSurfaceCloseWhileProcessIsAliveDoesNotReportProcessExit() {
        XCTAssertFalse(argoGhosttyShouldReportProcessExitForSurfaceClose(processAlive: true))
    }

    func testSurfaceCloseAfterProcessExitReportsExit() {
        XCTAssertTrue(argoGhosttyShouldReportProcessExitForSurfaceClose(processAlive: false))
    }

    func testSurfaceRefreshRunsWhenDisplayMetricsChange() {
        let previous = ArgoGhosttySurfaceMetricsSignature(
            width: 800,
            height: 600,
            scale: 2,
            displayID: 1
        )
        let next = ArgoGhosttySurfaceMetricsSignature(
            width: 800,
            height: 600,
            scale: 1,
            displayID: 2
        )

        XCTAssertTrue(argoGhosttyShouldRefreshSurface(after: previous, next: next))
        XCTAssertFalse(argoGhosttyShouldRefreshSurface(after: next, next: next))
    }
}
