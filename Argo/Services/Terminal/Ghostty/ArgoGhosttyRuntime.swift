//
//  ArgoGhosttyRuntime.swift
//  Argo
//
//  Author: krystal
//

@preconcurrency import AppKit
import Foundation
import GhosttyKit

@MainActor
final class ArgoGhosttyRuntime: NSObject {
    static let shared = ArgoGhosttyRuntime()

    var config: ghostty_config_t!
    var app: ghostty_app_t!
    private var appSettingsObserver: NSObjectProtocol?

    /// Current terminal background opacity (0...1). Surface views read this
    /// to decide whether their backing layer should stay opaque or go clear so
    /// Ghostty's `background-opacity` is the sole source of translucency.
    private(set) var terminalBackgroundOpacity: CGFloat = 1

    var needsConfirmQuit: Bool {
        guard let app else { return false }
        return ghostty_app_needs_confirm_quit(app)
    }

    private override init() {
        super.init()
        ArgoGhosttyBootstrap.initialize()

        let initialSettings = AppSettingsPersistence().load()
        terminalBackgroundOpacity = CGFloat(initialSettings.terminalBackgroundOpacity)
        config = Self.makeConfig(for: initialSettings)

        var runtimeConfiguration = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: true,
            wakeup_cb: argoGhosttyWakeupCallback,
            action_cb: argoGhosttyActionCallback,
            read_clipboard_cb: argoGhosttyReadClipboardCallback,
            confirm_read_clipboard_cb: argoGhosttyConfirmReadClipboardCallback,
            write_clipboard_cb: argoGhosttyWriteClipboardCallback,
            close_surface_cb: argoGhosttyCloseSurfaceCallback
        )

        guard let app = ghostty_app_new(&runtimeConfiguration, config) else {
            fatalError("Unable to initialize libghostty runtime")
        }
        self.app = app
        ghostty_app_set_focus(app, NSApp.isActive)
        installObservers()
    }

    deinit {
        if let appSettingsObserver {
            NotificationCenter.default.removeObserver(appSettingsObserver)
        }
        if let app {
            ghostty_app_free(app)
        }
        if let config {
            ghostty_config_free(config)
        }
    }

    func tick() {
        ghostty_app_tick(app)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(keyboardSelectionDidChange(_:)),
            name: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        appSettingsObserver = center.addObserver(
            forName: .argoAppSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let settings = notification.object as? AppSettings else {
                return
            }
            Task { @MainActor [weak self] in
                self?.apply(settings: settings)
            }
        }
    }

    @objc private func keyboardSelectionDidChange(_ notification: Notification) {
        ghostty_app_keyboard_changed(app)
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        ghostty_app_set_focus(app, true)
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        ghostty_app_set_focus(app, false)
    }

    private func apply(settings: AppSettings) {
        terminalBackgroundOpacity = CGFloat(settings.terminalBackgroundOpacity)
        let nextConfig = Self.makeConfig(for: settings)
        ghostty_app_update_config(app, nextConfig)
        for controller in ArgoGhosttyControllerRegistry.shared.liveControllers() {
            controller.applyConfig(nextConfig)
        }

        if let previousConfig = config {
            ghostty_config_free(previousConfig)
        }
        config = nextConfig
    }

    private static func makeConfig(for settings: AppSettings) -> ghostty_config_t {
        do {
            return try ArgoGhosttyConfigManager.buildConfig(settings: settings)
        } catch {
            fatalError("Unable to configure libghostty: \(error.localizedDescription)")
        }
    }

    nonisolated fileprivate static func wakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let userdata else { return }
        let runtime = Unmanaged<ArgoGhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                runtime.tick()
            }
        }
    }

    nonisolated fileprivate static func handleAction(
        _ app: ghostty_app_t?,
        target: ghostty_target_s,
        action: ghostty_action_s
    ) -> Bool {
        let appAddress = pointerAddress(app)
        return onMainSync {
            switch target.tag {
            case GHOSTTY_TARGET_SURFACE:
                guard let surface = target.target.surface else {
                    return false
                }
                let userdataAddress = pointerAddress(ghostty_surface_userdata(surface))
                guard let controller = ArgoGhosttyControllerRegistry.shared.controller(for: userdataAddress) else {
                    return false
                }
                return controller.handleGhosttyAction(action, on: surface)

            case GHOSTTY_TARGET_APP:
                return handleAppAction(pointer(from: appAddress), action: action)

            default:
                return false
            }
        }
    }

    private static func handleAppAction(_ app: ghostty_app_t?, action: ghostty_action_s) -> Bool {
        switch action.tag {
        case GHOSTTY_ACTION_OPEN_URL:
            guard let urlCString = action.action.open_url.url else { return false }
            let value = String(cString: urlCString)
            let url: URL
            if let candidate = URL(string: value), candidate.scheme != nil {
                url = candidate
            } else {
                url = URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
            }
            NSWorkspace.shared.open(url)
            return true

        case GHOSTTY_ACTION_RING_BELL:
            NSSound.beep()
            return true

        case GHOSTTY_ACTION_OPEN_CONFIG:
            if let app {
                ghostty_app_open_config(app)
                return true
            }
            return false

        default:
            return false
        }
    }

    nonisolated fileprivate static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?
    ) -> Bool {
        let controllerAddress = pointerAddress(userdata)
        let stateAddress = pointerAddress(state)
        return onMainSync {
            guard let controller = controller(fromAddress: controllerAddress),
                  let pasteboard = argoGhosttyPasteboard(for: location),
                  let value = pasteboard.argoGhosttyBestString else {
                return false
            }

            controller.completeClipboardRequest(
                value,
                state: pointer(from: stateAddress),
                confirmed: false
            )
            return true
        }
    }

    nonisolated fileprivate static func confirmReadClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        string: UnsafePointer<CChar>?,
        state: UnsafeMutableRawPointer?,
        request: ghostty_clipboard_request_e
    ) {
        guard let string else { return }
        let text = String(cString: string)
        let controllerAddress = pointerAddress(userdata)
        let stateAddress = pointerAddress(state)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let controller = controller(fromAddress: controllerAddress) else { return }
                controller.confirmClipboardRead(
                    text: text,
                    state: pointer(from: stateAddress),
                    request: request
                )
            }
        }
    }

    nonisolated fileprivate static func writeClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int,
        confirm: Bool
    ) {
        guard let content, count > 0 else { return }

        let items = (0..<count).compactMap { index -> ArgoGhosttyClipboardPayload? in
            let entry = content[index]
            guard let mime = entry.mime, let data = entry.data else { return nil }
            return ArgoGhosttyClipboardPayload(mimeType: String(cString: mime), text: String(cString: data))
        }
        guard !items.isEmpty else { return }

        if confirm {
            let controllerAddress = pointerAddress(userdata)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let controller = controller(fromAddress: controllerAddress) else { return }
                    controller.confirmClipboardWrite(items: items, location: location)
                }
            }
            return
        }

        onMainSync {
            guard let pasteboard = argoGhosttyPasteboard(for: location) else { return }
            writeClipboard(items, to: pasteboard)
        }
    }

    private static func writeClipboard(_ items: [ArgoGhosttyClipboardPayload], to pasteboard: NSPasteboard) {
        argoGhosttyWriteClipboard(items, to: pasteboard)
    }

    nonisolated fileprivate static func closeSurface(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        let controllerAddress = pointerAddress(userdata)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let controller = controller(fromAddress: controllerAddress) else { return }
                controller.handleSurfaceClose(processAlive: processAlive)
            }
        }
    }

    private static func controller(from userdata: UnsafeMutableRawPointer?) -> ArgoGhosttyController? {
        ArgoGhosttyControllerRegistry.shared.controller(for: pointerAddress(userdata))
    }

    private static func controller(fromAddress address: UInt?) -> ArgoGhosttyController? {
        controller(from: pointer(from: address))
    }

    nonisolated private static func pointerAddress<T>(_ pointer: UnsafeMutablePointer<T>?) -> UInt? {
        pointer.map { UInt(bitPattern: $0) }
    }

    nonisolated private static func pointerAddress<T>(_ pointer: UnsafePointer<T>?) -> UInt? {
        pointer.map { UInt(bitPattern: $0) }
    }

    nonisolated private static func pointerAddress(_ pointer: UnsafeMutableRawPointer?) -> UInt? {
        pointer.map { UInt(bitPattern: $0) }
    }

    nonisolated private static func pointer<T>(from address: UInt?) -> UnsafeMutablePointer<T>? {
        guard let address else { return nil }
        return UnsafeMutablePointer<T>(bitPattern: address)
    }

    nonisolated private static func pointer(from address: UInt?) -> UnsafeMutableRawPointer? {
        guard let address else { return nil }
        return UnsafeMutableRawPointer(bitPattern: address)
    }

    nonisolated private static func onMainSync<T: Sendable>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                body()
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                body()
            }
        }
    }
}

nonisolated private func argoGhosttyWakeupCallback(_ userdata: UnsafeMutableRawPointer?) {
    ArgoGhosttyRuntime.wakeup(userdata)
}

nonisolated private func argoGhosttyActionCallback(
    _ app: ghostty_app_t?,
    _ target: ghostty_target_s,
    _ action: ghostty_action_s
) -> Bool {
    ArgoGhosttyRuntime.handleAction(app, target: target, action: action)
}

nonisolated private func argoGhosttyReadClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ state: UnsafeMutableRawPointer?
) -> Bool {
    ArgoGhosttyRuntime.readClipboard(userdata, location: location, state: state)
}

nonisolated private func argoGhosttyConfirmReadClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ string: UnsafePointer<CChar>?,
    _ state: UnsafeMutableRawPointer?,
    _ request: ghostty_clipboard_request_e
) {
    ArgoGhosttyRuntime.confirmReadClipboard(userdata, string: string, state: state, request: request)
}

nonisolated private func argoGhosttyWriteClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ content: UnsafePointer<ghostty_clipboard_content_s>?,
    _ count: Int,
    _ confirm: Bool
) {
    ArgoGhosttyRuntime.writeClipboard(userdata, location: location, content: content, count: count, confirm: confirm)
}

nonisolated private func argoGhosttyCloseSurfaceCallback(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
    ArgoGhosttyRuntime.closeSurface(userdata, processAlive: processAlive)
}
