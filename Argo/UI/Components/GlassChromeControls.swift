//
//  GlassChromeControls.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct GlassToolbarGroup<Content: View>: View {
    var minHeight: CGFloat = 38
    var horizontalPadding: CGFloat = 12
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: minHeight)
        .background(glassFill, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var glassFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.155),
                Color.white.opacity(0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct GlassToolbarIconButton: View {
    let systemName: String
    var tint: Color = ArgoTheme.secondaryText
    var isActive = false
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? Color.white : tint)
                .background(
                    Circle()
                        .fill(isActive ? ArgoTheme.accent.opacity(0.88) : Color.white.opacity(0.025))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}

struct GlassToolbarMenuIconButton: View {
    let systemName: String
    var tint: Color = ArgoTheme.secondaryText
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: (NSView?) -> Void

    @State private var anchorView: NSView?

    var body: some View {
        Button {
            action(anchorView)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(tint)
                .contentShape(Circle())
                .background(GlassToolbarAnchorView(anchorView: $anchorView))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}

struct GlassToolbarSplitButton<LeadingContent: View, TrailingContent: View>: View {
    let leadingAction: (NSView?) -> Void
    let trailingAction: (NSView?) -> Void
    var isLeadingDisabled = false
    var isTrailingDisabled = false
    let leadingAccessibilityLabel: String
    let leadingHelp: String
    let trailingAccessibilityLabel: String
    let trailingHelp: String
    @ViewBuilder let leadingContent: () -> LeadingContent
    @ViewBuilder let trailingContent: () -> TrailingContent

    @State private var leadingAnchorView: NSView?
    @State private var trailingAnchorView: NSView?

    var body: some View {
        HStack(spacing: 0) {
            Button {
                leadingAction(leadingAnchorView)
            } label: {
                leadingContent()
                    .padding(.leading, 10)
                    .padding(.trailing, 9)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .background(GlassToolbarAnchorView(anchorView: $leadingAnchorView))
            }
            .buttonStyle(.plain)
            .disabled(isLeadingDisabled)
            .accessibilityLabel(leadingAccessibilityLabel)
            .help(leadingHelp)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)

            Button {
                trailingAction(trailingAnchorView)
            } label: {
                trailingContent()
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .background(GlassToolbarAnchorView(anchorView: $trailingAnchorView))
            }
            .buttonStyle(.plain)
            .disabled(isTrailingDisabled)
            .accessibilityLabel(trailingAccessibilityLabel)
            .help(trailingHelp)
        }
        .frame(height: 38)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.155),
                    Color.white.opacity(0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .opacity(isLeadingDisabled && isTrailingDisabled ? 0.5 : 1)
    }
}

private struct GlassToolbarAnchorView: NSViewRepresentable {
    @Binding var anchorView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        updateAnchorView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateAnchorView(nsView)
    }

    private func updateAnchorView(_ nsView: NSView) {
        guard anchorView !== nsView else { return }
        DispatchQueue.main.async {
            guard anchorView !== nsView else { return }
            anchorView = nsView
        }
    }
}
