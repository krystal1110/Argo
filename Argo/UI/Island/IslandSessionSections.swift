//
//  IslandSessionSections.swift
//  Argo
//
//  Author: krystal
//

import SwiftUI

struct IslandSessionSection: Identifiable {
    let id: String
    let titleKey: String
    let sessions: [IslandAgentSession]
}

struct IslandSessionSectionsView: View {
    let sessions: [IslandAgentSession]
    let controller: IslandPanelController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            LazyVStack(spacing: 4) {
                ForEach(Self.sections(for: sessions, referenceDate: context.date)) { section in
                    if !section.sessions.isEmpty {
                        Text(LocalizationManager.shared.string(section.titleKey))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.top, 6)

                        ForEach(section.sessions) { session in
                            IslandSessionRow(
                                session: session,
                                referenceDate: context.date,
                                isActionable: session.phase.requiresAttention,
                                controller: controller
                            )
                            .id(Self.sessionRowIdentity(for: session))
                        }
                    }
                }
            }
        }
    }

    static func sections(
        for sessions: [IslandAgentSession],
        referenceDate: Date
    ) -> [IslandSessionSection] {
        [
            IslandSessionSection(
                id: "approval",
                titleKey: "island.section.needsApproval",
                sessions: sessions.filter { $0.phase == .waitingForApproval }
            ),
            IslandSessionSection(
                id: "answer",
                titleKey: "island.section.needsAnswer",
                sessions: sessions.filter { $0.phase == .waitingForAnswer }
            ),
            IslandSessionSection(
                id: "running",
                titleKey: "island.section.inProgress",
                sessions: sessions.filter { $0.phase == .running }
            ),
            IslandSessionSection(
                id: "done",
                titleKey: "island.section.justDone",
                sessions: sessions.filter {
                    ($0.phase == .completed && !$0.isStaleCompletedForIsland(at: referenceDate))
                        || $0.phase == .failed
                }
            ),
            IslandSessionSection(
                id: "idle",
                titleKey: "island.section.idle",
                sessions: sessions.filter {
                    $0.phase == .stale || $0.isStaleCompletedForIsland(at: referenceDate)
                }
            )
        ]
    }

    static func sessionRowIdentity(for session: IslandAgentSession) -> String {
        "\(session.id):\(session.phase.rawValue)"
    }
}
