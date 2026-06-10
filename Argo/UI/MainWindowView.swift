//
//  MainWindowView.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import Combine
import ObjectiveC
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var layoutState = MainWindowLayoutState()
    @State private var commandPaletteClockDate = Date()

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        l10nFormat(localized(key), locale: Locale.current, arguments: arguments)
    }

    private var hasSelectedWorkspace: Bool {
        store.selectedWorkspace != nil
    }

    private var uiScale: CGFloat {
        CGFloat(store.appSettings.uiScale)
    }

    private var hasSelectedSession: Bool {
        guard let workspace = store.selectedWorkspace else { return false }
        let targetPaneID = workspace.sessionController.focusedPaneID ?? workspace.paneOrder.first
        guard let targetPaneID else { return false }
        return workspace.sessionController.session(for: targetPaneID) != nil
    }

    private var selectedWorkspaceDisplayName: String {
        store.selectedWorkspace?.name ?? localized("main.workspace.openWorkspace")
    }

    private var effectiveExternalEditorDisplayName: String {
        effectiveExternalEditor?.editor.displayName ?? localized("main.toolbar.openCurrentWorkspaceInExternalEditor")
    }

    private var availableExternalEditors: [ExternalEditorDescriptor] {
        store.availableExternalEditors
    }

    private var effectiveExternalEditor: ExternalEditorDescriptor? {
        store.effectiveExternalEditor
    }

    private var availableHAPIInstallation: HAPIInstallationStatus? {
        store.availableHAPIInstallation
    }

    private var externalEditorHelpText: String {
        if let editor = effectiveExternalEditor {
            return localizedFormat("main.toolbar.openCurrentWorkspaceInFormat", editor.editor.displayName)
        }
        return localized("main.toolbar.openCurrentWorkspaceInExternalEditor")
    }

    private var hapiHelpText: String {
        availableHAPIInstallation?.primaryActionHelpText ?? localized("main.hapi.defaultHelpText")
    }

    private func selectMainWindowMode(_ mode: MainWindowMode, restoreFocus: Bool = true) {
        let previousMode = store.mainWindowMode
        layoutState.selectMode(mode)
        let wasCanvasMode = previousMode == .canvas
        store.setMainWindowMode(mode)
        if restoreFocus, wasCanvasMode, mode == .workspace {
            restoreFocusedPane()
        }
    }

    private func restoreFocusedPane() {
        guard let workspace = store.selectedWorkspace,
              let focusedPaneID = workspace.sessionController.focusedPaneID else {
            return
        }
        DispatchQueue.main.async {
            workspace.sessionController.focus(focusedPaneID)
        }
    }

    private var sleepPreventionIconName: String {
        store.sleepPreventionSession == nil ? "moon.zzz" : "moon.zzz.fill"
    }

    private func dismissGlobalMode(restoreFocus: Bool = true) {
        selectMainWindowMode(.workspace, restoreFocus: restoreFocus)
    }

    @ViewBuilder
    private var webPreviewMenuContent: some View {
        if let workspace = store.selectedWorkspace {
            if workspace.listeningPorts.isEmpty {
                Text(localized("main.web.noPortsDetected"))
            } else {
                Section(localized("main.web.detectedPorts")) {
                    ForEach(workspace.listeningPorts, id: \.self) { port in
                        Button("localhost:\(port)") {
                            workspace.openPreviewForPort(port)
                        }
                    }
                }
            }
            Divider()
            Button(localized("main.web.openURL")) {
                promptForWebURL(workspace)
            }
            if workspace.previewPanel != nil {
                Divider()
                Button(localized("main.web.closePreview")) {
                    workspace.closePreview()
                }
            }
        }
    }

    private func promptForWebURL(_ workspace: WorkspaceModel) {
        let alert = NSAlert()
        alert.messageText = localized("main.web.openURL")
        alert.informativeText = localized("main.web.openURLPrompt")
        alert.addButton(withTitle: localized("common.ok"))
        alert.addButton(withTitle: localized("common.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "localhost:3000"
        field.stringValue = workspace.listeningPorts.first.map { "localhost:\($0)" } ?? "localhost:3000"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let url = WorkspacePreviewContent.webURL(fromUserInput: field.stringValue) {
            workspace.openPreview(.web(url))
        }
    }

    private func toggleWorkspaceSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
        )
    }

    private var topGlassChrome: some View {
        HStack(spacing: 14) {
            Button {
                toggleWorkspaceSidebar()
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(store.mainWindowMode == .workspace ? ArgoTheme.secondaryText : ArgoTheme.mutedText)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(store.mainWindowMode != .workspace)
            .opacity(store.mainWindowMode == .workspace ? 1 : 0.42)
            .scaleEffect(uiScale)
            .accessibilityLabel(localized("menu.view.toggleSidebar"))
            .help(localized("menu.view.toggleSidebar"))

            GlassToolbarGroup(horizontalPadding: 12, spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArgoTheme.secondaryText)
                Text(selectedWorkspaceDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArgoTheme.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 156, alignment: .leading)
            }
            .scaleEffect(uiScale)

            Spacer(minLength: 14)

            Button {
                store.dispatch(.toggleCommandPalette)
            } label: {
                TimeCommandPaletteButtonLabel(
                    date: commandPaletteClockDate,
                    commandText: TimeCommandPaletteCommandDisplay.commandText(in: store.appSettings)
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(uiScale)
            .accessibilityLabel(localized("menu.view.commandPalette"))
            .help(localized("menu.view.commandPalette"))

            Spacer(minLength: 14)

            GlassToolbarGroup(horizontalPadding: 5, spacing: 2) {
                GlassToolbarMenuIconButton(
                    systemName: "chevron.left.slash.chevron.right",
                    tint: ArgoTheme.accent,
                    accessibilityLabel: localized("main.toolbar.chooseQuickCommand"),
                    help: localized("main.toolbar.chooseQuickCommand")
                ) { anchorView in
                    present(menu: makeQuickCommandMenu(), from: anchorView)
                }

                GlassToolbarMenuIconButton(
                    systemName: "play.rectangle.on.rectangle",
                    tint: ArgoTheme.accent,
                    isDisabled: !hasSelectedWorkspace,
                    accessibilityLabel: localized("main.toolbar.chooseWorkflow"),
                    help: localized("main.toolbar.chooseWorkflow")
                ) { anchorView in
                    present(menu: makeWorkflowMenu(), from: anchorView)
                }

                if let hapiInstallation = availableHAPIInstallation, store.appSettings.showHAPIToolbarButton {
                    GlassToolbarMenuIconButton(
                        systemName: "dot.radiowaves.left.and.right",
                        tint: ArgoTheme.accent,
                        isDisabled: !hasSelectedWorkspace,
                        accessibilityLabel: hapiInstallation.primaryActionTitle,
                        help: hapiHelpText
                    ) { anchorView in
                        present(menu: makeHAPIMenu(using: hapiInstallation), from: anchorView)
                    }
                }

                GlassToolbarMenuIconButton(
                    systemName: sleepPreventionIconName,
                    tint: store.sleepPreventionSession == nil ? ArgoTheme.secondaryText : ArgoTheme.warning,
                    accessibilityLabel: store.sleepPreventionStatusText,
                    help: store.sleepPreventionStatusText
                ) { anchorView in
                    present(menu: makeSleepPreventionMenu(), from: anchorView)
                }

                GlassToolbarIconButton(
                    systemName: store.selectedWorkspace?.isFileTreePresented == true ? "list.bullet.indent" : "sidebar.squares.leading",
                    tint: ArgoTheme.secondaryText,
                    isActive: store.selectedWorkspace?.isFileTreePresented == true,
                    isDisabled: !hasSelectedWorkspace,
                    accessibilityLabel: localized("main.toolbar.toggleFileTree"),
                    help: localized("main.toolbar.toggleFileTree")
                ) {
                    store.selectedWorkspace?.toggleFileTree()
                }

                Menu {
                    webPreviewMenuContent
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(ArgoTheme.secondaryText)
                }
                .menuIndicator(.hidden)
                .disabled(!hasSelectedWorkspace)
                .accessibilityLabel(localized("main.toolbar.webPreview"))
                .help(localized("main.toolbar.webPreview"))
            }
            .scaleEffect(uiScale)

            GlassToolbarSplitButton(
                leadingAction: { _ in
                    store.openSelectedWorkspaceInPreferredExternalEditor()
                },
                trailingAction: { anchorView in
                    present(menu: makeExternalEditorMenu(), from: anchorView)
                },
                isLeadingDisabled: !hasSelectedWorkspace || effectiveExternalEditor == nil,
                isTrailingDisabled: !hasSelectedWorkspace,
                leadingAccessibilityLabel: externalEditorHelpText,
                leadingHelp: externalEditorHelpText,
                trailingAccessibilityLabel: localized("main.toolbar.chooseExternalEditor"),
                trailingHelp: localized("main.toolbar.chooseExternalEditorDefault"),
                leadingContent: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ArgoTheme.secondaryText)
                        Text(effectiveExternalEditorDisplayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ArgoTheme.tertiaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 96)
                    }
                },
                trailingContent: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ArgoTheme.secondaryText)
                }
            )
            .scaleEffect(uiScale)
        }
        .padding(.leading, 92)
        .padding(.trailing, 24)
        .frame(height: 62)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                ArgoTheme.chromeBackground.opacity(0.68)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.055),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(height: 1)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topGlassChrome

                HStack(spacing: 0) {
                    GlobalModeRailView(
                        selectedMode: store.mainWindowMode,
                        uiScale: uiScale,
                        onSelectMode: { mode in
                            selectMainWindowMode(mode, restoreFocus: mode == .workspace)
                        },
                        onOpenSettings: {
                            store.presentSettings(for: store.selectedWorkspace)
                        }
                    )

                    NavigationSplitView(columnVisibility: $layoutState.workspaceColumnVisibility) {
                        FloatingWorkspaceSidebarSurface {
                            WorkspaceSidebarView()
                        }
                        .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)
                    } detail: {
                        Group {
                            switch store.mainWindowMode {
                            case .workspace:
                                WorkspaceDetailView()

                            case .canvas:
                                GlobalCanvasView {
                                    dismissGlobalMode()
                                }
                                .environmentObject(store)

                            case .overview:
                                OverviewView {
                                    dismissGlobalMode(restoreFocus: false)
                                }
                                .environmentObject(store)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .navigationSplitViewStyle(.balanced)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ArgoTheme.appBackground)

            if store.isCommandPalettePresented {
                CommandPaletteView()
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(3)
            }

            VStack {
                if let statusMessage = store.statusMessage {
                    StatusBanner(message: statusMessage)
                        .padding(.top, 72)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .zIndex(2)
        }
        .ignoresSafeArea(.container, edges: .top)
        .task {
            await store.refreshHAPIIntegrationStatus()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            commandPaletteClockDate = date
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { @MainActor in
                await store.refreshHAPIIntegrationStatus()
            }
            store.refreshAvailableExternalEditors()
        }
        .onChange(of: store.mainWindowMode) { _, newMode in
            layoutState.selectMode(newMode)
        }
        .sheet(item: $store.renameWorkspaceRequest) { request in
            RenameWorkspaceSheet(request: request) { name in
                if request.isGroupCreation {
                    store.createWorkspaceGroup(named: name, workspaceIDs: request.groupWorkspaceIDs)
                } else if request.isGroupRename, let groupID = request.groupID {
                    store.renameWorkspaceGroup(groupID, to: name)
                } else {
                    store.renameWorkspace(id: request.workspaceID, to: name)
                }
            }
        }
        .sheet(item: $store.createWorktreeRequest) { request in
            CreateWorktreeSheet(request: request) { draft in
                store.createWorktree(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.editWorktreeNoteRequest) { request in
            EditWorktreeNoteSheet(request: request) { note in
                guard let workspace = store.workspaces.first(where: { $0.id == request.workspaceID }),
                      let worktree = workspace.worktrees.first(where: { $0.path == request.worktreePath }) else { return }
                store.setWorktreeNote(note.isEmpty ? nil : note, for: worktree, in: workspace)
            }
        }
        .sheet(item: $store.createSSHSessionRequest) { request in
            CreateSSHSessionSheet(request: request) { draft in
                store.createSSHSession(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.createAgentSessionRequest) { request in
            CreateAgentSessionSheet(request: request) { draft in
                store.createAgentSession(workspaceID: request.workspaceID, draft: draft)
            }
        }
        .sheet(item: $store.connectSSHRequest) { request in
            ConnectSSHSheet(request: request) { sshConfig, name, mode, presetID in
                if presetID != nil {
                    store.rememberSSHPresetSelection(selectedPresetID: presetID)
                }
                switch mode {
                case .remoteWorkspace:
                    store.addRemoteWorkspace(sshConfig: sshConfig, name: name)
                case .terminalOnly:
                    store.addSSHTerminalWorkspace(sshConfig: sshConfig, name: name)
                }
            }
        }
        .sheet(item: $store.settingsRequest) { request in
            SettingsSheet(request: request)
                .environmentObject(store)
        }
        .sheet(item: $store.quickCommandEditorRequest) { _ in
            QuickCommandEditorSheet()
                .environmentObject(store)
        }
        .sheet(item: $store.workflowEditorRequest) { request in
            WorkflowEditorSheet(workspaceID: request.workspaceID)
                .environmentObject(store)
        }

        .sheet(item: $store.workspaceFileBrowserRequest) { request in
            WorkspaceFileBrowserSheet(request: request)
                .environmentObject(store)
        }
        .sheet(item: $store.sidebarIconCustomizationRequest) { request in
            SidebarIconCustomizationSheet(request: request)
                .environmentObject(store)
        }
        .alert(item: $store.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text(localized("common.ok")))
            )
        }
        .alert(item: $store.pendingWorktreeSwitch) { request in
            Alert(
                title: Text(localized("main.worktreeSwitch.title")),
                message: Text(localizedFormat("main.worktreeSwitch.messageFormat", request.targetName, request.runningPaneCount, request.requestedAction.displayLabel)),
                primaryButton: .destructive(Text(localized("main.worktreeSwitch.confirm"))) {
                    store.confirmPendingWorktreeSwitch()
                },
                secondaryButton: .cancel {
                    store.pendingWorktreeSwitch = nil
                }
            )
        }
        .confirmationDialog(
            store.pendingWorktreeRemoval?.itemCount == 1 ? localized("main.worktreeRemoval.singleTitle") : localized("main.worktreeRemoval.multiTitle"),
            isPresented: Binding(
                get: { store.pendingWorktreeRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        store.pendingWorktreeRemoval = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: store.pendingWorktreeRemoval
        ) { request in
            Button(localized("main.worktreeRemoval.remove"), role: .destructive) {
                store.confirmPendingWorktreeRemoval()
            }
            if request.allowsForceRemove {
                Button(localized("main.worktreeRemoval.forceRemove"), role: .destructive) {
                    store.confirmPendingWorktreeRemoval(force: true)
                }
            }
            Button(localized("common.cancel"), role: .cancel) {
                store.pendingWorktreeRemoval = nil
            }
        } message: { request in
            Text(request.detailMessage)
        }
        .animation(.easeInOut(duration: 0.18), value: store.statusMessage?.id)
        .animation(.easeInOut(duration: 0.18), value: store.isCommandPalettePresented)
    }

    private func present(menu: NSMenu, from anchorView: NSView?) {
        guard let anchorView else { return }

        if let currentEvent = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: currentEvent, for: anchorView)
            return
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchorView.bounds.maxY + 6), in: anchorView)
    }

    private func makeQuickCommandMenu() -> NSMenu {
        let menu = NSMenu()

        if !hasSelectedSession {
            menu.addDisabledItem(title: localized("main.quickCommands.focusTerminal"))
            menu.addItem(.separator())
        }

        let recentCommands = store.recentQuickCommandPresets
        if !recentCommands.isEmpty {
            menu.addSectionHeader(localized("main.quickCommands.recent"))
            for command in recentCommands {
                let category = store.quickCommandCategoryMap[command.categoryID] ?? .fallbackCategory
                menu.addActionItem(
                    title: command.normalizedTitle,
                    imageSystemName: category.symbolName,
                    isEnabled: hasSelectedSession,
                    toolTip: command.command
                ) {
                    store.insertQuickCommand(command)
                }
            }
            menu.addItem(.separator())
        }

        let commandsByCategory = Dictionary(grouping: store.quickCommandPresets, by: \.categoryID)
        for category in QuickCommandCatalog.visibleCategories(
            commands: store.quickCommandPresets,
            categories: store.quickCommandCategories
        ) {
            guard let commands = commandsByCategory[category.id], !commands.isEmpty else { continue }
            menu.addSectionHeader(category.title)
            for command in commands {
                menu.addActionItem(
                    title: command.normalizedTitle,
                    imageSystemName: category.symbolName,
                    isEnabled: hasSelectedSession,
                    toolTip: command.command
                ) {
                    store.insertQuickCommand(command)
                }
            }
            menu.addItem(.separator())
        }

        if menu.items.last?.isSeparatorItem == true {
            menu.removeItem(at: menu.items.count - 1)
        }

        if store.quickCommandPresets.isEmpty {
            menu.addDisabledItem(title: localized("main.quickCommands.noneConfigured"))
            menu.addItem(.separator())
        }

        if !menu.items.isEmpty, menu.items.last?.isSeparatorItem == false {
            menu.addItem(.separator())
        }

        menu.addActionItem(title: localized("main.quickCommands.edit"), imageSystemName: "slider.horizontal.3") {
            store.presentQuickCommandEditor()
        }

        return menu
    }

    private func makeWorkflowMenu() -> NSMenu {
        let menu = NSMenu()

        guard let workspace = store.selectedWorkspace else {
            menu.addDisabledItem(title: localized("main.workflows.noneConfigured"))
            return menu
        }

        let workflows = workspace.workflows
        if workflows.isEmpty {
            menu.addDisabledItem(title: localized("main.workflows.noneConfigured"))
        } else {
            for workflow in workflows {
                let commandCount = workflow.commands.count
                let toolTip = commandCount > 0
                    ? localizedFormat("main.workflows.commandCountFormat", commandCount)
                    : nil
                menu.addActionItem(
                    title: workflow.name,
                    imageSystemName: "play.rectangle.on.rectangle",
                    isEnabled: true,
                    toolTip: toolTip
                ) {
                    store.dispatch(.runWorkflow(workspace.id, workflow.id))
                }
            }
        }

        menu.addItem(.separator())
        menu.addActionItem(title: localized("main.workflows.addWorkflow"), imageSystemName: "plus") {
            workspace.settings.workflows.append(
                WorkspaceWorkflow(name: localized("defaults.workflow.name"))
            )
            store.presentWorkflowEditor(for: workspace)
        }
        menu.addActionItem(title: localized("main.workflows.editWorkflows"), imageSystemName: "slider.horizontal.3") {
            store.presentWorkflowEditor(for: workspace)
        }

        return menu
    }

    private func makeExternalEditorMenu() -> NSMenu {
        let menu = NSMenu()

        if availableExternalEditors.isEmpty {
            menu.addDisabledItem(title: localized("main.externalEditor.noneFound"))
        } else {
            menu.addSectionHeader(localized("main.externalEditor.openWorkspaceIn"))
            for editor in availableExternalEditors {
                menu.addActionItem(
                    title: editor.editor.displayName,
                    state: effectiveExternalEditor?.editor == editor.editor ? .on : .off
                ) {
                    store.openSelectedWorkspaceInExternalEditor(editor.editor)
                }
            }
            menu.addItem(.separator())
        }

        menu.addActionItem(title: localized("menu.app.settings"), imageSystemName: "gearshape") {
            store.presentSettings(for: store.selectedWorkspace)
        }

        return menu
    }

    private func makeHAPIMenu(using installation: HAPIInstallationStatus) -> NSMenu {
        let menu = NSMenu()

        menu.addActionItem(title: localized("main.hapi.startHub"), imageSystemName: "dot.radiowaves.left.and.right") {
            guard let workspace = store.selectedWorkspace else { return }
            store.startHAPIHub(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.startHubRelay"), imageSystemName: "dot.radiowaves.left.and.right") {
            guard let workspace = store.selectedWorkspace else { return }
            store.startHAPIHubRelay(workspaceID: workspace.id)
        }

        menu.addItem(.separator())
        menu.addActionItem(title: localized("main.hapi.claude"), imageSystemName: "play.circle") {
            guard let workspace = store.selectedWorkspace else { return }
            store.launchHAPISession(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.codex"), imageSystemName: "terminal") {
            guard let workspace = store.selectedWorkspace else { return }
            store.launchHAPICodex(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.cursor"), imageSystemName: "cursorarrow.rays") {
            guard let workspace = store.selectedWorkspace else { return }
            store.launchHAPICursor(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.gemini"), imageSystemName: "sparkles") {
            guard let workspace = store.selectedWorkspace else { return }
            store.launchHAPIGemini(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.opencode"), imageSystemName: "chevron.left.forwardslash.chevron.right") {
            guard let workspace = store.selectedWorkspace else { return }
            store.launchHAPIOpenCode(workspaceID: workspace.id)
        }

        menu.addItem(.separator())
        menu.addActionItem(title: localized("main.hapi.showSettings"), imageSystemName: "doc.text.magnifyingglass") {
            guard let workspace = store.selectedWorkspace else { return }
            store.showHAPISettings(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.authStatus"), imageSystemName: "info.circle") {
            guard let workspace = store.selectedWorkspace else { return }
            store.showHAPIAuthStatus(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.authLogin"), imageSystemName: "key") {
            guard let workspace = store.selectedWorkspace else { return }
            store.loginToHAPI(workspaceID: workspace.id)
        }
        menu.addActionItem(title: localized("main.hapi.authLogout"), imageSystemName: "rectangle.portrait.and.arrow.right") {
            guard let workspace = store.selectedWorkspace else { return }
            store.logoutFromHAPI(workspaceID: workspace.id)
        }

        if installation.cloudflaredExecutablePath != nil {
            menu.addItem(.separator())
            menu.addActionItem(title: localized("main.hapi.cloudflaredTunnel"), imageSystemName: "network") {
                guard let workspace = store.selectedWorkspace else { return }
                store.launchCloudflaredTunnel(workspaceID: workspace.id)
            }
            menu.addActionItem(title: localized("main.hapi.cloudflaredLogin"), imageSystemName: "person.badge.key") {
                guard let workspace = store.selectedWorkspace else { return }
                store.loginToCloudflaredTunnel(workspaceID: workspace.id)
            }
            menu.addActionItem(title: localized("main.hapi.cloudflaredRun"), imageSystemName: "bolt.horizontal.circle") {
                guard let workspace = store.selectedWorkspace else { return }
                store.runCloudflaredTunnel(workspaceID: workspace.id)
            }
        }

        menu.addItem(.separator())
        menu.addActionItem(title: localized("main.hapi.docs"), imageSystemName: "book") {
            guard let url = URL(string: "https://hapi.run/") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
        if installation.cloudflaredExecutablePath != nil {
            menu.addActionItem(title: localized("main.hapi.cloudflareDocs"), imageSystemName: "book") {
                guard let url = URL(string: "https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/") else {
                    return
                }
                NSWorkspace.shared.open(url)
            }
        }

        return menu
    }

    private func makeSleepPreventionMenu() -> NSMenu {
        let menu = NSMenu()

        if let session = store.sleepPreventionSession {
            menu.addDisabledItem(title: localizedFormat("main.sleepPrevention.activeFormat", session.remainingDescription(relativeTo: store.sleepPreventionReferenceDate)))
            menu.addActionItem(title: localized("main.sleepPrevention.stop"), imageSystemName: "xmark.circle") {
                store.stopSleepPrevention()
            }
            menu.addItem(.separator())
        }

        menu.addSectionHeader(localized("main.sleepPrevention.preventFor"))
        for option in store.sleepPreventionOptions {
            menu.addActionItem(
                title: option.title,
                state: store.sleepPreventionQuickActionOption == option ? .on : .off
            ) {
                store.activateSleepPrevention(option)
            }
        }

        return menu
    }
}

private struct FloatingWorkspaceSidebarSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private var panelShape: some Shape {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ArgoTheme.sidebarBackground, in: panelShape)
            .clipShape(panelShape)
            .overlay {
                panelShape
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                panelShape
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(1)
            }
            .shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)
            .padding(.init(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(ArgoTheme.appBackground)
    }
}

private struct TimeCommandPaletteButtonLabel: View {
    let date: Date
    let commandText: String

    private var phase: TimeCommandPalettePhase {
        TimeCommandPaletteClock.phase(for: date)
    }

    private var timeText: String {
        TimeCommandPaletteClock.timeText(for: date)
    }

    private var iconSystemName: String {
        switch phase {
        case .morning:
            return "sunrise.fill"
        case .afternoon:
            return "sun.max.fill"
        case .sunset:
            return "sunset.fill"
        case .night:
            return "moon.stars.fill"
        }
    }

    private var iconColor: Color {
        switch phase {
        case .morning:
            return Color(red: 1.0, green: 0.63, blue: 0.25)
        case .afternoon:
            return Color(red: 1.0, green: 0.82, blue: 0.22)
        case .sunset:
            return Color(red: 1.0, green: 0.16, blue: 0.31)
        case .night:
            return Color(red: 0.56, green: 0.64, blue: 1.0)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconSystemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 18, height: 18)

            Text(timeText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ArgoTheme.tertiaryText)
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .leading)

            Text("–")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ArgoTheme.mutedText)

            Text(commandText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ArgoTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .padding(.horizontal, 18)
        .frame(height: 42)
        .insetToolbarCapsuleSurface()
        .contentShape(Capsule())
    }
}

private var toolbarMenuActionAssociationKey: UInt8 = 0

private final class ToolbarMenuActionHandler: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc
    func handleAction(_: Any?) {
        action()
    }
}

private extension NSMenu {
    func addSectionHeader(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }

    func addDisabledItem(title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }

    func addActionItem(
        title: String,
        imageSystemName: String? = nil,
        state: NSControl.StateValue = .off,
        isEnabled: Bool = true,
        toolTip: String? = nil,
        action: @escaping () -> Void
    ) {
        let handler = ToolbarMenuActionHandler(action: action)
        let item = NSMenuItem(title: title, action: #selector(ToolbarMenuActionHandler.handleAction(_:)), keyEquivalent: "")
        item.target = handler
        item.state = state
        item.isEnabled = isEnabled
        item.toolTip = toolTip
        if let imageSystemName {
            item.image = NSImage(systemSymbolName: imageSystemName, accessibilityDescription: title)
        }
        objc_setAssociatedObject(item, &toolbarMenuActionAssociationKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addItem(item)
    }
}

private struct StatusBanner: View {
    let message: WorkspaceStatusMessage

    private var tint: Color {
        switch message.tone {
        case .neutral:
            return ArgoTheme.secondaryText
        case .success:
            return ArgoTheme.success
        case .warning:
            return ArgoTheme.warning
        }
    }

    /// Hard cap so a runaway error message can't fill the screen, while still
    /// showing the full text for anything reasonable.
    private static let maxCharacters = 1000

    private var displayText: String {
        guard message.text.count > Self.maxCharacters else { return message.text }
        return String(message.text.prefix(Self.maxCharacters)) + "…"
    }

    private var isMultiline: Bool {
        message.text.contains("\n") || message.text.count > 80
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            Text(displayText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560, alignment: .leading)
        .background(ArgoTheme.canvasBackground.opacity(0.96), in: shape)
        .overlay(shape.stroke(ArgoTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private var shape: AnyShape {
        isMultiline
            ? AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            : AnyShape(Capsule())
    }
}
