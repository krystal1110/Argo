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

    @State private var dragPreviewFraction: Double?

    var body: some View {
        Group {
            if let zoomedPaneID = workspace.zoomedPaneID {
                if let session = sessionController.session(for: zoomedPaneID) {
                    TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: zoomedPaneID)
                        .id(zoomedPaneID)
                } else {
                    Color.clear
                }
            } else {
                switch node {
                case .pane(let leaf):
                    if let session = sessionController.session(for: leaf.paneID) {
                        TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: leaf.paneID)
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
        let preferredDividerThickness: CGFloat = 6
        let clampedFraction = PaneSplitSizing.clampedFraction(split.fraction)

        if split.axis == .vertical {
            let dividerThickness = min(preferredDividerThickness, max(size.width, 0))
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.width,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 120,
                minimumSecond: 120
            )

            HStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(width: lengths.first)
                SplitDivider(
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
                    .frame(width: dividerThickness)
                    .zIndex(PaneSplitDividerAppearance.stackZIndex)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(width: lengths.second)
            }
            .overlay(alignment: .leading) {
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
            }
        } else {
            let dividerThickness = min(preferredDividerThickness, max(size.height, 0))
            let lengths = PaneSplitSizing.lengths(
                totalLength: size.height,
                dividerThickness: dividerThickness,
                fraction: clampedFraction,
                minimumFirst: 90,
                minimumSecond: 90
            )

            VStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(height: lengths.first)
                SplitDivider(
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
                    .frame(height: dividerThickness)
                    .zIndex(PaneSplitDividerAppearance.stackZIndex)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(height: lengths.second)
            }
            .overlay(alignment: .top) {
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
            }
        }
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

private struct SplitDivider: View {
    let axis: PaneSplitAxis
    let fraction: Double
    let availableLength: CGFloat
    let onPreview: (Double) -> Void
    let onCommit: (Double) -> Void
    let onCancel: () -> Void

    @State private var dragContext: PaneSplitDragContext?
    @State private var isHovering = false
    @State private var isDragging = false

    private var isActive: Bool {
        isHovering || isDragging
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
            Capsule(style: .continuous)
                .fill(PaneSplitDividerAppearance.handleColor(isActive: isActive))
                .frame(
                    width: PaneSplitDividerAppearance.handleSize(for: axis).width,
                    height: PaneSplitDividerAppearance.handleSize(for: axis).height
                )
                .scaleEffect(isActive ? PaneSplitDividerAppearance.activeHandleScale : 1)
                .animation(.easeOut(duration: 0.12), value: isActive)
        }
        .background(SplitCursorArea(axis: axis))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onDisappear {
            isHovering = false
            isDragging = false
            dragContext = nil
            onCancel()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let context: PaneSplitDragContext
                    if let existingContext = dragContext {
                        context = existingContext
                    } else {
                        let startedContext = PaneSplitDragContext(
                            startFraction: fraction,
                            availableLength: availableLength
                        )
                        dragContext = startedContext
                        context = startedContext
                        isDragging = true
                    }
                    onPreview(context.fraction(forTranslation: dragTranslation(from: value)))
                }
                .onEnded { value in
                    let context = dragContext ?? PaneSplitDragContext(
                        startFraction: fraction,
                        availableLength: availableLength
                    )
                    dragContext = nil
                    isDragging = false
                    onCommit(context.fraction(forTranslation: dragTranslation(from: value)))
                }
        )
    }

    private func dragTranslation(from value: DragGesture.Value) -> CGFloat {
        axis == .vertical
            ? value.translation.width
            : value.translation.height
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

private struct SplitCursorArea: NSViewRepresentable {
    let axis: PaneSplitAxis

    func makeNSView(context: Context) -> CursorRectView {
        CursorRectView(axis: axis)
    }

    func updateNSView(_ nsView: CursorRectView, context: Context) {
        nsView.axis = axis
    }

    final class CursorRectView: NSView {
        var axis: PaneSplitAxis {
            didSet {
                guard oldValue != axis else { return }
                window?.invalidateCursorRects(for: self)
            }
        }

        init(axis: PaneSplitAxis) {
            self.axis = axis
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: axis == .vertical ? .resizeLeftRight : .resizeUpDown)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
