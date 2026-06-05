//
//  TerminalLocalChrome.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct TerminalLocalChrome: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let path: String
    let isFocused: Bool
    let canCreateTab: Bool
    let canSplit: Bool
    let onCreateTab: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        HStack(spacing: 12) {
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
            .frame(maxWidth: 430, alignment: .leading)
            .frame(height: 32)
            .padding(.horizontal, 12)
            .background(pathFill, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.235), lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 8, y: 3)

            Spacer(minLength: 8)

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
