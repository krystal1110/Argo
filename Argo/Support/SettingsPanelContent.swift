//
//  SettingsPanelContent.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum GeneralSettingsPanelSetting: String, CaseIterable, Hashable, Identifiable {
    case appLanguage
    case uiScale
    case autoRefreshEnabled
    case autoRefreshIntervalSeconds
    case confirmQuitWhenCommandsRunning

    var id: String { rawValue }
}

struct GeneralSettingsPanelSection: Equatable, Identifiable {
    enum SectionID: String {
        case basics
        case behavior
    }

    let id: SectionID
    let titleKey: String
    let settings: [GeneralSettingsPanelSetting]
}

enum GeneralSettingsPanelContent {
    static let visibleSections: [GeneralSettingsPanelSection] = [
        GeneralSettingsPanelSection(
            id: .basics,
            titleKey: "settings.general.basic.group",
            settings: [
                .appLanguage,
                .uiScale
            ]
        ),
        GeneralSettingsPanelSection(
            id: .behavior,
            titleKey: "settings.general.behavior.group",
            settings: [
                .autoRefreshEnabled,
                .autoRefreshIntervalSeconds,
                .confirmQuitWhenCommandsRunning
            ]
        )
    ]

    static var visibleSettings: [GeneralSettingsPanelSetting] {
        visibleSections.flatMap(\.settings)
    }
}

enum SidebarSettingsPanelSetting: String, CaseIterable, Hashable, Identifiable {
    case showSecondaryLabels
    case showWorkspaceBadges
    case showWorktreeBadges

    var id: String { rawValue }
}

struct SidebarSettingsPanelSection: Equatable, Identifiable {
    enum SectionID: String {
        case visibility
    }

    let id: SectionID
    let titleKey: String
    let settings: [SidebarSettingsPanelSetting]
}

enum SidebarSettingsPanelContent {
    static let visibleSections: [SidebarSettingsPanelSection] = [
        SidebarSettingsPanelSection(
            id: .visibility,
            titleKey: "settings.sidebar.visibility.group",
            settings: [
                .showSecondaryLabels,
                .showWorkspaceBadges,
                .showWorktreeBadges
            ]
        )
    ]

    static var visibleSettings: [SidebarSettingsPanelSetting] {
        visibleSections.flatMap(\.settings)
    }
}

enum SidebarIconEditorControl: String, CaseIterable, Hashable, Identifiable {
    case randomize
    case symbol

    var id: String { rawValue }
}

enum SidebarIconEditorContent {
    static let visibleControls: [SidebarIconEditorControl] = [
        .randomize,
        .symbol
    ]
}
