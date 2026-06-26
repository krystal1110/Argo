//
//  ArgoMainWindow.swift
//  Argo
//
//  Author: krystal
//

import AppKit

class ArgoMainWindow: NSWindow {
    private static let topChromeDoubleClickHeight: CGFloat = WorkspaceChromeMetrics.topHeight + 32
    private static let topChromeDoubleClickDistance: CGFloat = 8

    private var previousTopChromeClick: TopChromeClick?

    override func sendEvent(_ event: NSEvent) {
        if consumesTopChromeDoubleClick(event) {
            performZoom(nil)
            return
        }

        super.sendEvent(event)
    }

    private func consumesTopChromeDoubleClick(_ event: NSEvent) -> Bool {
        guard event.type == .leftMouseDown,
              event.buttonNumber == 0 else {
            return false
        }

        guard isInTopChrome(event.locationInWindow) else {
            previousTopChromeClick = nil
            return false
        }

        if event.clickCount == 2 {
            previousTopChromeClick = nil
            return true
        }

        guard event.clickCount == 1 else {
            previousTopChromeClick = nil
            return false
        }

        let currentClick = TopChromeClick(
            timestamp: event.timestamp,
            location: event.locationInWindow
        )

        if let previousTopChromeClick,
           currentClick.isDoubleClick(after: previousTopChromeClick) {
            self.previousTopChromeClick = nil
            return true
        }

        previousTopChromeClick = currentClick
        return false
    }

    private func isInTopChrome(_ windowLocation: NSPoint) -> Bool {
        let windowBounds = NSRect(origin: .zero, size: frame.size)
        guard windowBounds.contains(windowLocation) else {
            return false
        }

        return windowLocation.y >= windowBounds.maxY - Self.topChromeDoubleClickHeight
    }

    private struct TopChromeClick {
        let timestamp: TimeInterval
        let location: NSPoint

        func isDoubleClick(after previous: TopChromeClick) -> Bool {
            let elapsed = timestamp - previous.timestamp
            guard elapsed >= 0,
                  elapsed <= NSEvent.doubleClickInterval else {
                return false
            }

            let deltaX = location.x - previous.location.x
            let deltaY = location.y - previous.location.y
            let maximumDistance = ArgoMainWindow.topChromeDoubleClickDistance

            return deltaX * deltaX + deltaY * deltaY <= maximumDistance * maximumDistance
        }
    }
}
