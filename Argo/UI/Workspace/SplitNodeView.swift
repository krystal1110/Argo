//
//  SplitNodeView.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct SplitNodeView: View {
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var sessionController: WorkspaceSessionController
    let node: SessionLayoutNode
    let dimsInactivePanes: Bool

    @State private var dragPreviewFraction: Double?

    var body: some View {
        Group {
            if let zoomedPaneID = workspace.zoomedPaneID {
                if let session = sessionController.session(for: zoomedPaneID) {
                    TerminalPaneView(
                        workspace: workspace,
                        sessionController: sessionController,
                        session: session,
                        paneID: zoomedPaneID,
                        dimsWhenInactive: false
                    )
                    .id(zoomedPaneID)
                } else {
                    Color.clear
                }
            } else {
                switch node {
                case .pane(let leaf):
                    if let session = sessionController.session(for: leaf.paneID) {
                        TerminalPaneView(
                            workspace: workspace,
                            sessionController: sessionController,
                            session: session,
                            paneID: leaf.paneID,
                            dimsWhenInactive: dimsInactivePanes
                        )
                        .id(leaf.paneID)
                    } else {
                        Color.clear
                    }
                case .split(let split):
                    GeometryReader { geometry in
                        splitBody(split, in: geometry.size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func splitBody(_ split: PaneSplitNode, in size: CGSize) -> some View {
        let preferredDividerThickness = PaneSplitDividerAppearance.visualThickness
        let clampedFraction = PaneSplitSizing.clampedFraction(split.fraction)

        if split.axis == .vertical {
            let dividerThickness = min(preferredDividerThickness, max(size.width, 0))
            let hitTargetThickness = min(PaneSplitDividerAppearance.hitTargetThickness, max(size.width, 0))
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.width,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 120,
                minimumSecond: 120
            )

            HStack(spacing: 0) {
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.first,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(width: lengths.first)
                Color.clear
                    .frame(width: dividerThickness)
                    .allowsHitTesting(false)
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.second,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(width: lengths.second)
            }
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    if let dragPreviewFraction {
                        let previewLengths = PaneSplitSizing.lengths(
                            totalLength: size.width,
                            dividerThickness: dividerThickness,
                            fraction: dragPreviewFraction,
                            minimumFirst: 120,
                            minimumSecond: 120
                        )
                        SplitDividerPreview(axis: .vertical)
                            .frame(width: dividerThickness)
                            .offset(x: previewLengths.first)
                    }

                    SplitDividerHitTarget(
                        axis: .vertical,
                        fraction: clampedFraction,
                        availableLength: lengths.available
                    ) { fraction in
                        setDragPreviewFraction(fraction)
                    } onCommit: { fraction in
                        clearDragPreviewFraction()
                        workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                    } onCancel: {
                        clearDragPreviewFraction()
                    }
                    .frame(width: hitTargetThickness)
                    .offset(x: dividerHitTargetOffset(
                        leadingLength: lengths.first,
                        dividerThickness: dividerThickness,
                        hitTargetThickness: hitTargetThickness
                    ))
                    .zIndex(PaneSplitDividerAppearance.stackZIndex)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            let dividerThickness = min(preferredDividerThickness, max(size.height, 0))
            let hitTargetThickness = min(PaneSplitDividerAppearance.hitTargetThickness, max(size.height, 0))
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.height,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 90,
                minimumSecond: 90
            )

            VStack(spacing: 0) {
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.first,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(height: lengths.first)
                Color.clear
                    .frame(height: dividerThickness)
                    .allowsHitTesting(false)
                SplitNodeView(
                    workspace: workspace,
                    sessionController: sessionController,
                    node: split.second,
                    dimsInactivePanes: dimsInactivePanes
                )
                .frame(height: lengths.second)
            }
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    if let dragPreviewFraction {
                        let previewLengths = PaneSplitSizing.lengths(
                            totalLength: size.height,
                            dividerThickness: dividerThickness,
                            fraction: dragPreviewFraction,
                            minimumFirst: 90,
                            minimumSecond: 90
                        )
                        SplitDividerPreview(axis: .horizontal)
                            .frame(height: dividerThickness)
                            .offset(y: previewLengths.first)
                    }

                    SplitDividerHitTarget(
                        axis: .horizontal,
                        fraction: clampedFraction,
                        availableLength: lengths.available
                    ) { fraction in
                        setDragPreviewFraction(fraction)
                    } onCommit: { fraction in
                        clearDragPreviewFraction()
                        workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                    } onCancel: {
                        clearDragPreviewFraction()
                    }
                    .frame(height: hitTargetThickness)
                    .offset(y: dividerHitTargetOffset(
                        leadingLength: lengths.first,
                        dividerThickness: dividerThickness,
                        hitTargetThickness: hitTargetThickness
                    ))
                    .zIndex(PaneSplitDividerAppearance.stackZIndex)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func dividerHitTargetOffset(
        leadingLength: CGFloat,
        dividerThickness: CGFloat,
        hitTargetThickness: CGFloat
    ) -> CGFloat {
        leadingLength + ((dividerThickness - hitTargetThickness) / 2)
    }

    private func setDragPreviewFraction(_ fraction: Double) {
        guard dragPreviewFraction != fraction else { return }
        dragPreviewFraction = fraction
    }

    private func clearDragPreviewFraction() {
        guard dragPreviewFraction != nil else { return }
        dragPreviewFraction = nil
    }
}

private struct SplitDividerHitTarget: View {
    let axis: PaneSplitAxis
    let fraction: Double
    let availableLength: CGFloat
    let onPreview: (Double) -> Void
    let onCommit: (Double) -> Void
    let onCancel: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    private var isActive: Bool {
        isHovering || isDragging
    }

    var body: some View {
        ZStack {
            if axis == .vertical {
                Rectangle()
                    .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
                    .frame(width: PaneSplitDividerAppearance.visualThickness)
            } else {
                Rectangle()
                    .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
                    .frame(height: PaneSplitDividerAppearance.visualThickness)
            }

            Capsule(style: .continuous)
                .fill(PaneSplitDividerAppearance.handleColor(isActive: isActive))
                .frame(
                    width: PaneSplitDividerAppearance.handleSize(for: axis).width,
                    height: PaneSplitDividerAppearance.handleSize(for: axis).height
                )
                .scaleEffect(isActive ? PaneSplitDividerAppearance.activeHandleScale : 1)
                .animation(.easeOut(duration: 0.12), value: isActive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            SplitDividerEventLayer(
                axis: axis,
                fraction: fraction,
                availableLength: availableLength,
                isHovering: $isHovering,
                isDragging: $isDragging,
                onPreview: onPreview,
                onCommit: onCommit,
                onCancel: onCancel
            )
        }
        .onDisappear {
            isHovering = false
            isDragging = false
            onCancel()
        }
    }
}

private struct SplitDividerEventLayer: NSViewRepresentable {
    let axis: PaneSplitAxis
    let fraction: Double
    let availableLength: CGFloat
    @Binding var isHovering: Bool
    @Binding var isDragging: Bool
    let onPreview: (Double) -> Void
    let onCommit: (Double) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> EventView {
        EventView(
            axis: axis,
            fraction: fraction,
            availableLength: availableLength,
            setHovering: { isHovering = $0 },
            setDragging: { isDragging = $0 },
            onPreview: onPreview,
            onCommit: onCommit,
            onCancel: onCancel
        )
    }

    func updateNSView(_ nsView: EventView, context: Context) {
        nsView.axis = axis
        nsView.fraction = fraction
        nsView.availableLength = availableLength
        nsView.setHovering = { isHovering = $0 }
        nsView.setDragging = { isDragging = $0 }
        nsView.onPreview = onPreview
        nsView.onCommit = onCommit
        nsView.onCancel = onCancel
    }

    static func dismantleNSView(_ nsView: EventView, coordinator: ()) {
        nsView.cancelDrag()
    }

    final class EventView: NSView {
        var axis: PaneSplitAxis {
            didSet {
                guard oldValue != axis else { return }
                window?.invalidateCursorRects(for: self)
            }
        }
        var fraction: Double
        var availableLength: CGFloat
        var setHovering: (Bool) -> Void
        var setDragging: (Bool) -> Void
        var onPreview: (Double) -> Void
        var onCommit: (Double) -> Void
        var onCancel: () -> Void

        private var dragContext: PaneSplitDragContext?
        private var dragStartLocation: NSPoint?
        private var trackingArea: NSTrackingArea?

        override var mouseDownCanMoveWindow: Bool {
            false
        }

        init(
            axis: PaneSplitAxis,
            fraction: Double,
            availableLength: CGFloat,
            setHovering: @escaping (Bool) -> Void,
            setDragging: @escaping (Bool) -> Void,
            onPreview: @escaping (Double) -> Void,
            onCommit: @escaping (Double) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.axis = axis
            self.fraction = fraction
            self.availableLength = availableLength
            self.setHovering = setHovering
            self.setDragging = setDragging
            self.onPreview = onPreview
            self.onCommit = onCommit
            self.onCancel = onCancel
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: axis == .vertical ? .resizeLeftRight : .resizeUpDown)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
                owner: self
            )
            trackingArea = area
            addTrackingArea(area)
        }

        override func mouseEntered(with event: NSEvent) {
            setHovering(true)
        }

        override func mouseExited(with event: NSEvent) {
            if dragContext == nil {
                setHovering(false)
            }
        }

        override func mouseDown(with event: NSEvent) {
            dragContext = PaneSplitDragContext(
                startFraction: fraction,
                availableLength: availableLength
            )
            dragStartLocation = event.locationInWindow
            setDragging(true)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let dragContext, let dragStartLocation else { return }
            onPreview(dragContext.fraction(forTranslation: translation(from: dragStartLocation, to: event.locationInWindow)))
        }

        override func mouseUp(with event: NSEvent) {
            let context = dragContext ?? PaneSplitDragContext(
                startFraction: fraction,
                availableLength: availableLength
            )
            let startLocation = dragStartLocation ?? event.locationInWindow
            dragContext = nil
            dragStartLocation = nil
            setDragging(false)
            setHovering(bounds.contains(convert(event.locationInWindow, from: nil)))
            onCommit(context.fraction(forTranslation: translation(from: startLocation, to: event.locationInWindow)))
        }

        func cancelDrag() {
            guard dragContext != nil else { return }
            dragContext = nil
            dragStartLocation = nil
            setDragging(false)
            onCancel()
        }

        private func translation(from startLocation: NSPoint, to currentLocation: NSPoint) -> CGFloat {
            switch axis {
            case .vertical:
                return currentLocation.x - startLocation.x
            case .horizontal:
                return startLocation.y - currentLocation.y
            }
        }
    }
}

private struct SplitDividerPreview: View {
    let axis: PaneSplitAxis

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.12))
            Capsule(style: .continuous)
                .fill(PaneSplitDividerAppearance.handleColor(isActive: true))
                .frame(
                    width: PaneSplitDividerAppearance.handleSize(for: axis).width,
                    height: PaneSplitDividerAppearance.handleSize(for: axis).height
                )
                .scaleEffect(PaneSplitDividerAppearance.activeHandleScale)
        }
        .allowsHitTesting(false)
    }
}

enum PaneSplitDividerAppearance {
    static let stackZIndex: Double = 1
    static let visualThickness: CGFloat = 6
    static let hitTargetThickness: CGFloat = 18
    static let inactiveHandleOpacity: Double = 0.9
    static let activeHandleOpacity: Double = 1
    static let activeHandleScale: CGFloat = 1.08
    static let usesSymbolIcon = false
    static let usesIconBacking = false

    static func handleSize(for axis: PaneSplitAxis) -> CGSize {
        switch axis {
        case .vertical:
            return CGSize(width: 3, height: 64)
        case .horizontal:
            return CGSize(width: 56, height: 3)
        }
    }

    static func handleColor(isActive: Bool) -> Color {
        if isActive {
            return Color(red: 0.85, green: 0.88, blue: 0.93).opacity(activeHandleOpacity)
        }
        return Color(red: 0.43, green: 0.48, blue: 0.57).opacity(inactiveHandleOpacity)
    }
}
