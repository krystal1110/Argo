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
    func testAttachReportsWhetherHostedViewChanged() {
        let container = TerminalViewContainer(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let hostedView = NSView(frame: .zero)

        XCTAssertTrue(container.attach(hostedView, restoreFocus: false))
        XCTAssertFalse(container.attach(hostedView, restoreFocus: false))

        let replacementView = NSView(frame: .zero)
        XCTAssertTrue(container.attach(replacementView, restoreFocus: false))
    }

    func testAttachRestoresFocusEvenWhenViewWasAlreadyHosted() async {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        let root = NSView(frame: window.contentView?.bounds ?? .zero)
        let container = TerminalViewContainer(frame: root.bounds)
        let hostedView = FocusableTestView(frame: .zero)

        window.contentView = root
        root.addSubview(container)

        XCTAssertTrue(container.attach(hostedView, restoreFocus: false))
        XCTAssertFalse(container.attach(hostedView, restoreFocus: true))
        await Task.yield()

        XCTAssertTrue(window.firstResponder === hostedView)
    }

    func testLayoutRequestsSurfaceRefresh() {
        let container = TerminalViewContainer(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        var refreshCount = 0
        container.onNeedsSurfaceRefresh = {
            refreshCount += 1
        }

        container.layout()

        XCTAssertEqual(refreshCount, 1)
    }

    func testRemovingContainerFromSuperviewDetachesHostedTerminalView() async {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let container = TerminalViewContainer(frame: parent.bounds)
        let hostedView = NSView(frame: .zero)

        parent.addSubview(container)
        container.attach(hostedView, restoreFocus: false)

        XCTAssertEqual(hostedView.superview, container)

        container.removeFromSuperview()
        await Task.yield()

        XCTAssertNil(hostedView.superview)
        XCTAssertTrue(container.subviews.isEmpty)
    }

    func testTemporarySuperviewRemovalDoesNotDetachHostedTerminalView() async {
        let firstParent = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let secondParent = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        let container = TerminalViewContainer(frame: firstParent.bounds)
        let hostedView = NSView(frame: .zero)

        firstParent.addSubview(container)
        container.attach(hostedView, restoreFocus: false)

        container.removeFromSuperview()
        secondParent.addSubview(container)
        await Task.yield()

        XCTAssertEqual(hostedView.superview, container)
        XCTAssertEqual(container.subviews, [hostedView])
    }

    func testDismantleDefersDetachSoReparentedContainerKeepsHostedTerminalView() async {
        let firstParent = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let secondParent = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        let container = TerminalViewContainer(frame: firstParent.bounds)
        let hostedView = NSView(frame: .zero)

        firstParent.addSubview(container)
        container.attach(hostedView, restoreFocus: false)

        container.removeFromSuperview()
        TerminalHostView.dismantleNSView(container, coordinator: TerminalHostView.Coordinator())
        secondParent.addSubview(container)
        await Task.yield()

        XCTAssertEqual(hostedView.superview, container)
        XCTAssertEqual(container.subviews, [hostedView])
    }

    func testContainerReattachesDesiredHostedViewWhenReinsertedAfterDeferredDetach() async {
        let firstParent = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let secondParent = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        let container = TerminalViewContainer(frame: firstParent.bounds)
        let hostedView = NSView(frame: .zero)

        firstParent.addSubview(container)
        container.attach(hostedView, restoreFocus: false)

        container.removeFromSuperview()
        await Task.yield()

        XCTAssertNil(hostedView.superview)

        secondParent.addSubview(container)
        await Task.yield()

        XCTAssertEqual(hostedView.superview, container)
        XCTAssertEqual(container.subviews, [hostedView])
    }
}

private final class FocusableTestView: NSView {
    override var acceptsFirstResponder: Bool { true }
}
