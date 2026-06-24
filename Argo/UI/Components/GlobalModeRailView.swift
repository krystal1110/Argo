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
        VStack(spacing: 6 * uiScale) {
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
        .padding(.vertical, 14 * uiScale)
        .frame(width: 64 * uiScale)
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
                .font(.system(size: 19 * uiScale, weight: .semibold))
                .foregroundStyle(isSelected ? chromeTint.components.color : ArgoTheme.textFaint)
                .frame(width: 38 * uiScale, height: 38 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 10 * uiScale, style: .continuous)
                        .fill(isSelected ? chromeTint.selectionFill.color : Color.white.opacity(0.001))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * uiScale, style: .continuous)
                        .stroke(isSelected ? chromeTint.components.color.opacity(0.65) : Color.clear, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(chromeTint.components.color)
                            .frame(width: 3 * uiScale, height: 20 * uiScale)
                            .shadow(color: chromeTint.components.color.opacity(0.65), radius: 10 * uiScale)
                            .offset(x: -14 * uiScale)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}
