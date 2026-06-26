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
    func testArgoMainWindowZoomsWhenDoubleClickingTopChromeArea() throws {
        let window = TestArgoMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.setContentSize(NSSize(width: 800, height: 600))

        window.sendEvent(try mouseEvent(
            clickCount: 1,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 400, y: 580)
        ))
        XCTAssertEqual(window.zoomCount, 0)

        window.sendEvent(try mouseEvent(
            clickCount: 2,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 400, y: 580)
        ))
        XCTAssertEqual(window.zoomCount, 1)
    }

    func testArgoMainWindowZoomsWhenTopChromeReceivesTwoFastSingleClicks() throws {
        let window = TestArgoMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.setContentSize(NSSize(width: 800, height: 600))

        let timestamp = ProcessInfo.processInfo.systemUptime
        window.sendEvent(try mouseEvent(
            clickCount: 1,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 400, y: 580),
            timestamp: timestamp,
            eventNumber: 10
        ))
        XCTAssertEqual(window.zoomCount, 0)

        window.sendEvent(try mouseEvent(
            clickCount: 1,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 403, y: 578),
            timestamp: timestamp + 0.05,
            eventNumber: 11
        ))
        XCTAssertEqual(window.zoomCount, 1)
    }

    func testArgoMainWindowZoomsInFullSizeTitlebarSafeArea() throws {
        let window = TestArgoMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 1200, height: 760))

        window.sendEvent(try mouseEvent(
            clickCount: 2,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 300, y: window.frame.height - 24)
        ))
        XCTAssertEqual(window.zoomCount, 1)
    }

    func testArgoMainWindowIgnoresContentAreaDoubleClick() throws {
        let window = TestArgoMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.setContentSize(NSSize(width: 800, height: 600))

        window.sendEvent(try mouseEvent(
            clickCount: 2,
            windowNumber: window.windowNumber,
            location: NSPoint(x: 400, y: 320)
        ))
        XCTAssertEqual(window.zoomCount, 0)
    }

    private func mouseEvent(
        clickCount: Int,
        windowNumber: Int,
        location: NSPoint = NSPoint(x: 24, y: 24),
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime,
        eventNumber: Int? = nil
    ) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: location,
                modifierFlags: [],
                timestamp: timestamp,
                windowNumber: windowNumber,
                context: nil,
                eventNumber: eventNumber ?? clickCount,
                clickCount: clickCount,
                pressure: 1
            )
        )
    }
}

private final class TestArgoMainWindow: ArgoMainWindow {
    var zoomCount = 0

    override func performZoom(_ sender: Any?) {
        zoomCount += 1
    }
}
