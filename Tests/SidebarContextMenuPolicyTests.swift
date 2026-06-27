//
//  SidebarContextMenuPolicyTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

@MainActor
final class SidebarContextMenuPolicyTests: XCTestCase {
    func testRevealInFinderRequiresAllSelectedWorkspacesToBeLocal() {
        let local = makeRepositoryWorkspace(path: "/tmp/local-repo")
        let remote = makeRemoteWorkspace(path: "/srv/app")

        XCTAssertTrue(SidebarContextMenuPolicy.canRevealInFinder(for: [local]))
        XCTAssertFalse(SidebarContextMenuPolicy.canRevealInFinder(for: [remote]))
        XCTAssertFalse(SidebarContextMenuPolicy.canRevealInFinder(for: [local, remote]))
    }

    func testFetchRequiresAllSelectedWorkspacesToBeLocalRepositories() {
        let repository = makeRepositoryWorkspace(path: "/tmp/repo")
        let localTerminal = WorkspaceModel(localDirectoryPath: "/tmp/scratch", name: "Scratch")
        let remote = makeRemoteWorkspace(path: "/srv/app")

        XCTAssertTrue(SidebarContextMenuPolicy.canFetchRepositories(for: [repository]))
        XCTAssertFalse(SidebarContextMenuPolicy.canFetchRepositories(for: [localTerminal]))
        XCTAssertFalse(SidebarContextMenuPolicy.canFetchRepositories(for: [remote]))
        XCTAssertFalse(SidebarContextMenuPolicy.canFetchRepositories(for: [repository, remote]))
    }

    func testRunWorkspaceScriptRequiresLocalWorkspaceWithConfiguredScript() {
        let localWithScript = makeRepositoryWorkspace(path: "/tmp/repo", runScript: "make test")
        let localWithoutScript = makeRepositoryWorkspace(path: "/tmp/repo-empty", runScript: "  ")
        let remoteWithScript = makeRemoteWorkspace(path: "/srv/app", runScript: "make deploy")

        XCTAssertTrue(SidebarContextMenuPolicy.canRunWorkspaceScript(in: localWithScript))
        XCTAssertFalse(SidebarContextMenuPolicy.canRunWorkspaceScript(in: localWithoutScript))
        XCTAssertFalse(SidebarContextMenuPolicy.canRunWorkspaceScript(in: remoteWithScript))
    }
}

private func makeRepositoryWorkspace(path: String, runScript: String = "") -> WorkspaceModel {
    WorkspaceModel(record: WorkspaceRecord(
        id: UUID(),
        kind: .repository,
        name: URL(fileURLWithPath: path).lastPathComponent,
        repositoryRoot: path,
        activeWorktreePath: path,
        worktreeStates: [WorktreeSessionStateRecord.makeDefault(for: path)],
        isSidebarExpanded: false,
        settings: WorkspaceSettings(runScript: runScript)
    ))
}

private func makeRemoteWorkspace(path: String, runScript: String = "") -> WorkspaceModel {
    let sshConfig = SSHSessionConfiguration(
        host: "example.com",
        user: "deploy",
        port: nil,
        identityFilePath: nil,
        remoteWorkingDirectory: path,
        remoteCommand: nil
    )
    return WorkspaceModel(record: WorkspaceRecord(
        id: UUID(),
        kind: .remoteServer,
        name: "Remote",
        repositoryRoot: path,
        activeWorktreePath: path,
        worktreeStates: [WorktreeSessionStateRecord.makeDefault(for: path)],
        isSidebarExpanded: false,
        settings: WorkspaceSettings(runScript: runScript),
        sshTarget: sshConfig
    ))
}
