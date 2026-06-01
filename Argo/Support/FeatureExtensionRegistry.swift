//
//  FeatureExtensionRegistry.swift
//  Argo
//

import Foundation

struct ArgoExtensionContext {
    let selectedWorkspace: WorkspaceModel?
    let workspaces: [WorkspaceModel]
}

protocol ArgoFeatureExtension {
    var id: String { get }
    func commandPaletteItems(context: ArgoExtensionContext) -> [CommandPaletteItem]
}

struct SupportLinksExtension: ArgoFeatureExtension {
    let id = "support-links"

    func commandPaletteItems(context: ArgoExtensionContext) -> [CommandPaletteItem] {
        _ = context
        return [
            CommandPaletteItem(
                id: "extension-support-website",
                title: LocalizationManager.shared.string("extension.support.website"),
                subtitle: "argo.dev",
                group: .navigation,
                keywords: ["extension", "help", "website", "docs"],
                isGlobal: true,
                kind: .command(.openArgoWebsite)
            ),
            CommandPaletteItem(
                id: "extension-support-feedback",
                title: LocalizationManager.shared.string("extension.support.feedback"),
                subtitle: "code.devops.xiaohongshu.com/huying/Argo/-/issues/new",
                group: .navigation,
                keywords: ["extension", "feedback", "issue", "bug"],
                isGlobal: true,
                kind: .command(.submitArgoFeedback)
            )
        ]
    }
}

final class ArgoFeatureRegistry {
    static let shared = ArgoFeatureRegistry(extensions: [
        SupportLinksExtension()
    ])

    private(set) var extensions: [any ArgoFeatureExtension]

    init(extensions: [any ArgoFeatureExtension] = []) {
        self.extensions = extensions
    }

    func register(_ featureExtension: any ArgoFeatureExtension) {
        guard !extensions.contains(where: { $0.id == featureExtension.id }) else { return }
        extensions.append(featureExtension)
    }

    func commandPaletteItems(context: ArgoExtensionContext) -> [CommandPaletteItem] {
        extensions.flatMap { $0.commandPaletteItems(context: context) }
    }
}
