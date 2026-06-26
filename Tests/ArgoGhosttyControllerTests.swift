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
    func testGhosttySurfaceDoesNotAllowMouseDownToDragWindow() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/Services/Terminal/Ghostty/ArgoGhosttyController.swift"),
            encoding: .utf8
        )
        let surfaceStart = try XCTUnwrap(source.range(of: "private final class ArgoGhosttySurfaceView: NSView")?.lowerBound)
        let mouseDownStart = try XCTUnwrap(
            source.range(of: "override func mouseDown(with event: NSEvent)", range: surfaceStart..<source.endIndex)?.lowerBound
        )
        let surfaceHeader = source[surfaceStart..<mouseDownStart]

        XCTAssertTrue(surfaceHeader.contains("override var mouseDownCanMoveWindow: Bool { false }"))
    }

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
