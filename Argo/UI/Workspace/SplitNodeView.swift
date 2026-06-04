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
        let dividerThickness: CGFloat = 6
        let clampedFraction = PaneSplitSizing.clampedFraction(split.fraction)

        if split.axis == .vertical {
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
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(width: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(width: lengths.second)
            }
        } else {
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
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(height: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(height: lengths.second)
            }
        }
    }
}

private struct SplitDivider: View {
    let axis: PaneSplitAxis
    let fraction: Double
    let availableLength: CGFloat
    let onUpdate: (Double) -> Void

    @State private var dragStartFraction: Double?
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var didPushCursor = false

    private var isActive: Bool {
        isHovering || isDragging
    }

    private var resizeCursor: NSCursor {
        axis == .vertical ? .resizeLeftRight : .resizeUpDown
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.18 : 0.08))
                .frame(width: axis == .vertical ? 4 : 44, height: axis == .horizontal ? 4 : 44)
            Capsule(style: .continuous)
                .fill(isActive ? Color.white.opacity(0.72) : ArgoTheme.strongBorder)
                .frame(width: axis == .vertical ? 2 : 16, height: axis == .horizontal ? 2 : 16)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            setCursorVisible(hovering || isDragging)
        }
        .onDisappear {
            setCursorVisible(false)
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let startFraction = dragStartFraction ?? fraction
                    if dragStartFraction == nil {
                        dragStartFraction = fraction
                        isDragging = true
                        setCursorVisible(true)
                    }
                    let translation = axis == .vertical
                        ? value.translation.width
                        : value.translation.height
                    onUpdate(
                        PaneSplitSizing.fraction(
                            startingAt: startFraction,
                            translation: translation,
                            availableLength: availableLength
                        )
                    )
                }
                .onEnded { _ in
                    dragStartFraction = nil
                    isDragging = false
                    setCursorVisible(isHovering)
                }
        )
    }

    private func setCursorVisible(_ visible: Bool) {
        if visible, !didPushCursor {
            resizeCursor.push()
            didPushCursor = true
        } else if !visible, didPushCursor {
            NSCursor.pop()
            didPushCursor = false
        }
    }
}
