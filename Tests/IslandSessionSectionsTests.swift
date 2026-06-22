import XCTest
@testable import Argo

final class IslandSessionSectionsTests: XCTestCase {
    func testStaleCompletedSessionsMoveFromJustDoneToIdle() {
        let recent = makeSession(
            id: "recent",
            phase: .completed,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let stale = makeSession(
            id: "stale",
            phase: .completed,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let sections = IslandSessionSectionsView.sections(
            for: [recent, stale],
            referenceDate: Date(timeIntervalSince1970: IslandAgentSession.staleCompletedDisplayThreshold)
        )

        XCTAssertEqual(section(sections, id: "done")?.sessions.map(\.id), ["recent"])
        XCTAssertEqual(section(sections, id: "idle")?.sessions.map(\.id), ["stale"])
    }

    private func section(_ sections: [IslandSessionSection], id: String) -> IslandSessionSection? {
        sections.first { $0.id == id }
    }

    private func makeSession(
        id: String,
        phase: IslandSessionPhase,
        updatedAt: Date
    ) -> IslandAgentSession {
        IslandAgentSession(
            id: id,
            identity: IslandSessionIdentity(
                workspaceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                worktreePath: "/tmp/repo",
                paneID: nil,
                sourceID: id
            ),
            title: id,
            tool: .codex,
            phase: phase,
            summary: id,
            updatedAt: updatedAt
        )
    }
}
