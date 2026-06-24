//
//  GlobalModeRailView.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

struct GlobalModeRailView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let selectedMode: MainWindowMode
    let chromeTint: ArgoChromeTint
    let uiScale: CGFloat
    let onSelectMode: (MainWindowMode) -> Void
    let onOpenSettings: () -> Void

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    var body: some View {
        VStack(spacing: 10 * uiScale) {
            ForEach(MainWindowMode.allCases) { mode in
                GlobalModeRailButton(
                    systemName: mode.iconSystemName(selected: selectedMode == mode),
                    title: localized(mode.titleLocalizationKey),
                    isSelected: selectedMode == mode,
                    chromeTint: chromeTint,
                    uiScale: uiScale
                ) {
                    onSelectMode(mode)
                }
            }

            Spacer(minLength: 12 * uiScale)

            GlobalModeRailButton(
                systemName: "gearshape",
                title: localized("main.rail.settings"),
                isSelected: false,
                chromeTint: chromeTint,
                uiScale: uiScale,
                action: onOpenSettings
            )
        }
        .padding(.vertical, 12 * uiScale)
        .frame(width: 54 * uiScale)
        .frame(maxHeight: .infinity)
        .background(ArgoTheme.glassRail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(width: 1)
        }
    }
}

private struct GlobalModeRailButton: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let chromeTint: ArgoChromeTint
    let uiScale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16 * uiScale, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : ArgoTheme.secondaryText)
                .frame(width: 34 * uiScale, height: 34 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous)
                        .fill(isSelected ? chromeTint.selectionFill.color : ArgoTheme.subtleFill.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * uiScale, style: .continuous)
                        .stroke(isSelected ? chromeTint.components.color.opacity(0.65) : ArgoTheme.border.opacity(0.6), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(ArgoTheme.amber)
                            .frame(width: 3 * uiScale, height: 20 * uiScale)
                            .shadow(color: ArgoTheme.amber.opacity(0.65), radius: 10 * uiScale)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}
