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
        .insetToolbarCapsuleSurface()
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
        .insetToolbarCapsuleSurface()
        .opacity(isLeadingDisabled && isTrailingDisabled ? 0.5 : 1)
    }
}

struct InsetToolbarCapsuleSurface: ViewModifier {
    var fillOpacity: Double = 0.12
    var glassHighlightOpacity: Double = 0.05
    var borderOpacity: Double = 0.12
    var topShadowOpacity: Double = 0.2
    var bottomHighlightOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.black.opacity(fillOpacity))
                Capsule().fill(Color.white.opacity(glassHighlightOpacity))
            }
            .overlay(Capsule().stroke(Color.white.opacity(borderOpacity), lineWidth: 1))
            .overlay(alignment: .top) {
                Capsule()
                    .stroke(Color.black.opacity(topShadowOpacity), lineWidth: 2)
                    .blur(radius: 1)
                    .mask(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .padding(1)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .stroke(Color.white.opacity(bottomHighlightOpacity), lineWidth: 1)
                    .blur(radius: 0.5)
                    .mask(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .padding(1)
            }
    }
}

extension View {
    func insetToolbarCapsuleSurface(
        fillOpacity: Double = 0.12,
        glassHighlightOpacity: Double = 0.05,
        borderOpacity: Double = 0.12,
        topShadowOpacity: Double = 0.2,
        bottomHighlightOpacity: Double = 0.08
    ) -> some View {
        modifier(
            InsetToolbarCapsuleSurface(
                fillOpacity: fillOpacity,
                glassHighlightOpacity: glassHighlightOpacity,
                borderOpacity: borderOpacity,
                topShadowOpacity: topShadowOpacity,
                bottomHighlightOpacity: bottomHighlightOpacity
            )
        )
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
