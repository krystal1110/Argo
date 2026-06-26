//
//  MainWindowChromeInteractionTests.swift
//  ArgoTests
//
//  Author: krystal
//

import AppKit
import XCTest
@testable import Argo

@MainActor
final class MainWindowChromeInteractionTests: XCTestCase {
    private let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testTopChromeDoubleClickZoomEventViewOnlyZoomsOnDoubleClick() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        var zoomCount = 0
        let eventView = TopChromeDoubleClickZoomEventView { eventWindow in
            XCTAssertTrue(eventWindow === window)
            zoomCount += 1
        }

        eventView.frame = NSRect(x: 0, y: 0, width: 640, height: 52)
        window.contentView?.addSubview(eventView)

        XCTAssertFalse(eventView.mouseDownCanMoveWindow)

        eventView.mouseDown(with: try mouseEvent(clickCount: 1, windowNumber: window.windowNumber))
        XCTAssertEqual(zoomCount, 0)

        eventView.mouseDown(with: try mouseEvent(clickCount: 2, windowNumber: window.windowNumber))
        XCTAssertEqual(zoomCount, 1)
    }

    func testTopChromeInstallsDoubleClickZoomLayerInInteractiveOverlay() throws {
        let source = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("TopChromeDoubleClickZoomLayer()"))
        XCTAssertTrue(source.contains("TopChromeDoubleClickZoomEventView"))
        XCTAssertTrue(source.contains("window.performZoom(nil)"))
        XCTAssertTrue(
            source.contains("""
        .overlay {
            TopChromeDoubleClickZoomLayer()
        }
"""),
            "The double-click layer must be in the interactive overlay stack so it receives top-chrome hit tests."
        )
        XCTAssertFalse(
            source.contains("""
        .background {
            TopChromeDoubleClickZoomLayer()
        }
"""),
            "A SwiftUI background layer sits behind top chrome content and can miss mouse hit testing."
        )
    }

    private func mouseEvent(clickCount: Int, windowNumber: Int) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 24, y: 24),
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: windowNumber,
                context: nil,
                eventNumber: clickCount,
                clickCount: clickCount,
                pressure: 1
            )
        )
    }
}
