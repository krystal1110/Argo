//
//  TerminalViewContainerTests.swift
//  ArgoTests
//
//  Author: krystal
//

import AppKit
import XCTest
@testable import Argo

@MainActor
final class TerminalViewContainerTests: XCTestCase {
    func testRemovingContainerFromSuperviewDetachesHostedTerminalView() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let container = TerminalViewContainer(frame: parent.bounds)
        let hostedView = NSView(frame: .zero)

        parent.addSubview(container)
        container.attach(hostedView, restoreFocus: false)

        XCTAssertEqual(hostedView.superview, container)

        container.removeFromSuperview()

        XCTAssertNil(hostedView.superview)
        XCTAssertTrue(container.subviews.isEmpty)
    }
}
