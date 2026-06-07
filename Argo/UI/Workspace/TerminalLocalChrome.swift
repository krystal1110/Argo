//
//  TerminalLocalChrome.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct TerminalChromePaneDescriptor: Identifiable, Equatable {
    let paneID: UUID
    let path: String
    let isFocused: Bool

    var id: UUID { paneID }
}

struct TerminalLocalChrome: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let path: String
    let paneDescriptors: [TerminalChromePaneDescriptor]
    let tabs: [WorkspaceTabStateRecord]
    let activeTabID: UUID?
    let isFocused: Bool
    let canCreateTab: Bool
    let canSplit: Bool
    let paneCountForTab: (UUID) -> Int
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onSelectPane: (UUID) -> Void
    let onCreateTab: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        HStack(spacing: 12) {
            tabArea

            HStack(spacing: 5) {
                TransparentPaneActionButton(
                    systemName: "plus",
                    isDisabled: !canCreateTab,
                    accessibilityLabel: localized("menu.file.newTab"),
                    help: localized("menu.file.newTab"),
                    action: onCreateTab
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.2x1",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitRight"),
                    help: localized("menu.file.splitRight"),
                    action: onSplitRight
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.1x2",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitDown"),
                    help: localized("menu.file.splitDown"),
                    action: onSplitDown
                )
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabArea: some View {
        if paneDescriptors.count > 1 {
            paneChipStrip
        } else if tabs.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        TerminalChromeTabButton(
                            title: tab.title,
                            paneCount: paneCountForTab(tab.id),
                            isSelected: tab.id == activeTabID,
                            canClose: tabs.count > 1,
                            onSelect: {
                                onSelectTab(tab.id)
                            },
                            onClose: {
                                onCloseTab(tab.id)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        } else {
            pathPill
        }
    }

    private var paneChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(paneDescriptors) { descriptor in
                    TerminalChromePaneChip(
                        descriptor: descriptor,
                        onSelect: {
                            onSelectPane(descriptor.paneID)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var pathPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(path)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1)))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(pathFill, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.235), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
        .layoutPriority(1)
    }

    private var pathFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isFocused ? 0.255 : 0.205),
                Color.white.opacity(isFocused ? 0.145 : 0.105)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TerminalChromePaneChip: View {
    let descriptor: TerminalChromePaneDescriptor
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(foreground.opacity(descriptor.isFocused ? 0.92 : 0.62))

                Text(descriptor.path)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(width: 190, height: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(backgroundFill, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: descriptor.isFocused ? 1 : 0.8))
        .shadow(color: .black.opacity(descriptor.isFocused ? 0.16 : 0), radius: 8, y: 3)
        .accessibilityLabel("Focus pane \(descriptor.path)")
        .help(descriptor.path)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foreground: Color {
        descriptor.isFocused ? Color.white.opacity(0.94) : Color.white.opacity(isHovered ? 0.70 : 0.44)
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(descriptor.isFocused ? 0.28 : (isHovered ? 0.09 : 0.0)),
                Color.white.opacity(descriptor.isFocused ? 0.18 : (isHovered ? 0.045 : 0.0))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        if descriptor.isFocused {
            return Color.white.opacity(0.22)
        }
        return Color.white.opacity(isHovered ? 0.10 : 0.0)
    }
}

private struct TerminalChromeTabButton: View {
    let title: String
    let paneCount: Int
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(paneCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? ArgoTheme.accent : Color.white.opacity(0.48))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(isSelected ? 0.15 : 0.08), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.trailing, canClose ? 30 : 12)
            .frame(height: 32)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(isHovered ? 0.82 : 0.62))
        .frame(width: 178)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 1.05 : 0.8)
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                Capsule()
                    .fill(ArgoTheme.accent)
                    .frame(width: 24, height: 2.5)
                    .padding(.top, 1)
                    .padding(.leading, 12)
            }
        }
        .overlay(alignment: .trailing) {
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(closeOpacity))
                .background(Color.white.opacity(isCloseHovered ? 0.14 : 0.06), in: Circle())
                .padding(.trailing, 8)
                .onHover { hovering in
                    isCloseHovered = hovering
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isSelected ? 0.22 : (isHovered ? 0.12 : 0.075)),
                Color.white.opacity(isSelected ? 0.12 : (isHovered ? 0.075 : 0.045))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.24)
        }
        return Color.white.opacity(isHovered ? 0.14 : 0.08)
    }

    private var closeOpacity: Double {
        if isCloseHovered {
            return 0.92
        }
        if isHovered || isSelected {
            return 0.68
        }
        return 0.42
    }
}

private struct TransparentPaneActionButton: View {
    let systemName: String
    var isDisabled = false
    let accessibilityLabel: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: isDisabled ? .regular : .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.white.opacity(isDisabled ? 0.32 : 0.88))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}
