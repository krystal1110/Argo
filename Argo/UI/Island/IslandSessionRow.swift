//
//  IslandSessionRow.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

struct IslandSessionRow: View {
    let session: IslandAgentSession
    let referenceDate: Date
    let isActionable: Bool
    let controller: IslandPanelController
    @State private var showsDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            if showsDetail || isActionable {
                detail
            }
        }
        .background(rowFill)
        .contentShape(Rectangle())
        .onTapGesture {
            if session.phase.requiresAttention {
                showsDetail.toggle()
            } else {
                controller.navigateToSession(session)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            islandSessionStatusIcon(session.phase)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.spotlightHeadlineText)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let line = session.spotlightActivityLineText {
                    Text(line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            IslandTagPill(text: session.tool.shortName.lowercased())
            if let terminalTag = session.terminalTag {
                IslandTagPill(text: terminalTag)
            }
            Text(session.spotlightAgeBadge(at: referenceDate))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var detail: some View {
        switch session.phase {
        case .waitingForApproval:
            approvalActionBody
        case .waitingForAnswer:
            questionActionBody
        case .completed, .failed:
            completionActionBody
        case .running, .stale:
            if let lastError = session.lastError {
                Text(lastError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
            }
        }
    }

    private var approvalActionBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.permissionRequest?.title ?? "Approval needed")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            if session.approvalCommandPreviewText != nil || session.approvalAffectedPathText != nil {
                approvalContextBlock
            }

            HStack(spacing: 8) {
                ForEach(Array((session.permissionRequest?.actions ?? []).enumerated()), id: \.element.id) { index, action in
                    Button(action.title) {
                        controller.respondToSession(session, text: action.responseText)
                    }
                    .buttonStyle(IslandActionButtonStyle(
                        kind: approvalButtonKind(for: action, index: index),
                        expands: true
                    ))
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    private func approvalButtonKind(
        for action: IslandPermissionAction,
        index: Int
    ) -> IslandActionButtonStyle.Kind {
        let normalized = action.title.lowercased()
        if normalized.contains("deny")
            || normalized.contains("reject")
            || normalized.contains("cancel")
            || normalized == "no" {
            return .secondary
        }
        if normalized.contains("always")
            || normalized.contains("permanent") {
            return .primary
        }
        return index == 0 && (session.permissionRequest?.actions.count ?? 0) == 1 ? .primary : .warning
    }

    private var approvalContextBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let commandPreview = session.approvalCommandPreviewText {
                Text(commandPreview)
                    .font(.system(size: 11.2, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let affectedPath = session.approvalAffectedPathText {
                Text(affectedPath)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.045))
        )
    }

    private var questionActionBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(session.questionPrompt?.options ?? []) { option in
                Button(option.label) {
                    controller.respondToSession(session, text: option.responseText)
                }
                .buttonStyle(IslandActionButtonStyle(kind: .primary, expands: true))
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    private var completionActionBody: some View {
        Text(session.lastAssistantMessage ?? session.summary)
            .font(.system(size: 11.5))
            .foregroundStyle(session.phase == .failed ? .red.opacity(0.85) : .white.opacity(0.72))
            .lineLimit(3)
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
    }

    private var rowFill: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(session.phase.requiresAttention ? .orange.opacity(0.08) : .white.opacity(0.02))
    }
}

private struct IslandActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case warning
        case secondary
    }

    let kind: Kind
    var expands = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(background(configuration: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(border, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .primary, .warning:
            return .white
        case .secondary:
            return .white.opacity(0.72)
        }
    }

    private var fill: Color {
        switch kind {
        case .primary:
            return Color(red: 0.18, green: 0.39, blue: 0.95).opacity(0.78)
        case .warning:
            return Color.orange.opacity(0.68)
        case .secondary:
            return .white.opacity(0.075)
        }
    }

    private var border: Color {
        switch kind {
        case .primary:
            return Color(red: 0.42, green: 0.58, blue: 1).opacity(0.35)
        case .warning:
            return Color.orange.opacity(0.42)
        case .secondary:
            return .white.opacity(0.11)
        }
    }

    private func background(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill.opacity(configuration.isPressed ? 0.72 : 1))
    }
}

@ViewBuilder
func islandSessionStatusIcon(_ phase: IslandSessionPhase) -> some View {
    switch phase {
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
