//
//  IslandCollapsedView.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

struct IslandCollapsedView: View {
    @ObservedObject var state: IslandNotificationState
    var notchWidth: CGFloat = 0
    var pixelAnimationStyle: IslandPixelAnimationStyle = .random

    /// Padding added to each side of the notch gap to keep content clear of the notch edges.
    private let notchEdgePadding: CGFloat = 8

    private var hasNotch: Bool { notchWidth > 0 }

    private var spotlightTitle: String? {
        state.spotlightSession?.spotlightHeadlineText
    }

    private var rightSlot: IslandRightSlotContent? {
        let sessions = state.prioritySessions
        guard !sessions.isEmpty else { return nil }
        if sessions.count <= 1 { return .count(sessions.count) }

        let cells = sessions.prefix(8).map { session in
            IslandGridCell.session(
                hexColor: session.tool.brandColorHex,
                state: IslandGridCellState(phase: session.phase)
            )
        }
        if sessions.count > 8 {
            return .agents(Array(cells.prefix(7)) + [.overflow(sessions.count - 7)])
        }
        return .agents(Array(cells))
    }

    var body: some View {
        if hasNotch {
            notchedLayout
        } else {
            standardLayout
        }
    }

    /// Layout for screens with a notch: content is split into left and right areas
    /// around a transparent gap matching the physical notch width.
    private var notchedLayout: some View {
        HStack(spacing: 0) {
            // Left side — status icon + title
            leadingContent
            .padding(.leading, 16)
            .padding(.trailing, notchEdgePadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Notch gap
            Spacer()
                .frame(width: notchWidth)

            // Right side — badge / animation
            rightSlotContent
            .padding(.leading, notchEdgePadding)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    /// Standard layout for screens without a notch.
    private var standardLayout: some View {
        HStack(spacing: 10) {
            leadingContent
            Spacer(minLength: 4)
            rightSlotContent
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var leadingContent: some View {
        HStack(spacing: 8) {
            if let session = state.spotlightSession {
                islandSessionStatusIcon(session.phase)
                    .font(.system(size: 14))

                Text(spotlightTitle ?? session.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))

                Text("ARGO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var rightSlotContent: some View {
        if let rightSlot {
            IslandRightSlotView(content: rightSlot)
        } else if pixelAnimationStyle != .none {
            IslandPixelAnimationView(style: pixelAnimationStyle)
                .frame(width: 20, height: 14)
                .fixedSize()
        }
    }
}

@ViewBuilder
func islandStatusIcon(for item: IslandNotificationItem) -> some View {
    switch item.status {
    case .running:
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
    case .completed:
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case .failed:
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
    case .waitingForApproval:
        Image(systemName: "hand.raised.circle.fill")
            .foregroundStyle(.orange)
    case .waitingForAnswer:
        Image(systemName: "questionmark.circle.fill")
            .foregroundStyle(.cyan)
    case .stale:
        Image(systemName: "link.badge.plus")
            .foregroundStyle(.gray)
    }
}
