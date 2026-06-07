//
//  TerminalHostView.swift
//  Argo
//
//  Author: krystal
//

import AppKit
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
    @ObservedObject var session: ShellSession
    var shouldRestoreFocus: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TerminalViewContainer {
        let container = TerminalViewContainer()
        context.coordinator.session = session
        container.desiredHostedViewProvider = { [weak session] in
            session?.nsView
        }
        container.onNeedsSurfaceRefresh = { [weak coordinator = context.coordinator] in
            coordinator?.refreshSurface()
        }
        container.attach(session.nsView, restoreFocus: shouldRestoreFocus)
        session.surfaceHostDidAttach()
        return container
    }

    func updateNSView(_ nsView: TerminalViewContainer, context: Context) {
        context.coordinator.session = session
        nsView.desiredHostedViewProvider = { [weak session] in
            session?.nsView
        }
        nsView.onNeedsSurfaceRefresh = { [weak coordinator = context.coordinator] in
            coordinator?.refreshSurface()
        }
        nsView.attach(session.nsView, restoreFocus: shouldRestoreFocus)
        session.surfaceHostDidAttach()
    }

    static func dismantleNSView(_ nsView: TerminalViewContainer, coordinator: Coordinator) {
        nsView.scheduleDeferredDetach()
    }

    final class Coordinator {
        weak var session: ShellSession?

        func refreshSurface() {
            session?.surfaceHostDidAttach()
        }
    }
}

final class TerminalViewContainer: NSView {
    var onNeedsSurfaceRefresh: (() -> Void)?
    var desiredHostedViewProvider: (() -> NSView?)?

    private weak var desiredHostedView: NSView?
    private weak var hostedView: NSView?
    private var hostedConstraints: [NSLayoutConstraint] = []
    private var deferredDetachGeneration = 0

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            scheduleDeferredDetach()
        } else {
            deferredDetachGeneration += 1
            scheduleDesiredViewReattach()
        }
        super.viewWillMove(toSuperview: newSuperview)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview != nil {
            scheduleDesiredViewReattach()
        }
    }

    override func willRemoveSubview(_ subview: NSView) {
        if subview === hostedView {
            NSLayoutConstraint.deactivate(hostedConstraints)
            hostedConstraints = []
            hostedView = nil
        }
        super.willRemoveSubview(subview)
    }

    override func layout() {
        super.layout()
        reattachDesiredViewIfNeeded()
        onNeedsSurfaceRefresh?()
    }

    @discardableResult
    func attach(_ view: NSView, restoreFocus: Bool) -> Bool {
        desiredHostedView = view
        deferredDetachGeneration += 1
        let needsAttach = hostedView !== view || view.superview !== self

        if needsAttach {
            detachHostedView(clearDesired: false)
            view.removeFromSuperview()
            hostedView = view
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            let constraints = [
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ]
            hostedConstraints = constraints
            NSLayoutConstraint.activate(constraints)
        }

        if restoreFocus {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, let window = self.window ?? view.window else { return }
                if window.firstResponder !== view {
                    window.makeFirstResponder(view)
                }
            }
        }
        return needsAttach
    }

    func detachHostedView() {
        desiredHostedViewProvider = nil
        detachHostedView(clearDesired: true)
    }

    private func detachHostedView(clearDesired: Bool) {
        deferredDetachGeneration += 1
        if clearDesired {
            desiredHostedView = nil
        }
        NSLayoutConstraint.deactivate(hostedConstraints)
        hostedConstraints = []

        guard let hostedView else { return }
        self.hostedView = nil
        if hostedView.superview === self {
            hostedView.removeFromSuperview()
        }
    }

    func scheduleDeferredDetach() {
        deferredDetachGeneration += 1
        let generation = deferredDetachGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.deferredDetachGeneration == generation,
                  self.superview == nil else { return }
            self.detachHostedView(clearDesired: false)
        }
    }

    private func scheduleDesiredViewReattach() {
        let generation = deferredDetachGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.deferredDetachGeneration == generation,
                  self.superview != nil else { return }
            self.reattachDesiredViewIfNeeded()
        }
    }

    private func reattachDesiredViewIfNeeded() {
        guard let desiredHostedView = desiredHostedView ?? desiredHostedViewProvider?(),
              hostedView !== desiredHostedView || desiredHostedView.superview !== self else { return }
        attach(desiredHostedView, restoreFocus: false)
    }
}
