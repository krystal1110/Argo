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

    func makeNSView(context: Context) -> TerminalViewContainer {
        let container = TerminalViewContainer()
        container.attach(session.nsView, restoreFocus: shouldRestoreFocus)
        return container
    }

    func updateNSView(_ nsView: TerminalViewContainer, context: Context) {
        nsView.attach(session.nsView, restoreFocus: shouldRestoreFocus)
    }

    static func dismantleNSView(_ nsView: TerminalViewContainer, coordinator: ()) {
        nsView.detachHostedView()
    }
}

final class TerminalViewContainer: NSView {
    private weak var hostedView: NSView?
    private var hostedConstraints: [NSLayoutConstraint] = []

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            detachHostedView()
        }
        super.viewWillMove(toSuperview: newSuperview)
    }

    override func willRemoveSubview(_ subview: NSView) {
        if subview === hostedView {
            NSLayoutConstraint.deactivate(hostedConstraints)
            hostedConstraints = []
            hostedView = nil
        }
        super.willRemoveSubview(subview)
    }

    func attach(_ view: NSView, restoreFocus: Bool) {
        let needsAttach = hostedView !== view || view.superview !== self

        if needsAttach {
            detachHostedView()
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

        guard restoreFocus, needsAttach else { return }
        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, let view, let window = self.window ?? view.window else { return }
            if window.firstResponder !== view {
                window.makeFirstResponder(view)
            }
        }
    }

    func detachHostedView() {
        NSLayoutConstraint.deactivate(hostedConstraints)
        hostedConstraints = []

        guard let hostedView else { return }
        self.hostedView = nil
        if hostedView.superview === self {
            hostedView.removeFromSuperview()
        }
    }
}
