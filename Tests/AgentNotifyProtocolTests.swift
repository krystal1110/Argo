//
//  AgentNotifyProtocolTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class AgentNotifyProtocolTests: XCTestCase {
    func testEncodeDecodeRoundTripPreservesAllFields() throws {
        let original = AgentNotifyRequest(
            title: "Build finished",
            body: "All tests pass",
            paneID: "abc-pane",
            workspaceID: "ws-1",
            agentName: "Claude"
        )
        let frame = try AgentNotifyProtocol.encode(original)
        XCTAssertEqual(frame.last, 0x0A, "frame must end with newline")

        let decoded = try AgentNotifyProtocol.decode(frame)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.paneID, "abc-pane")
        XCTAssertEqual(decoded.workspaceID, "ws-1")
        XCTAssertEqual(decoded.agentName, "Claude")
    }

    func testEncodeRejectsEmptyTitleAndBody() {
        let request = AgentNotifyRequest(title: "   ", body: "")
        XCTAssertThrowsError(try AgentNotifyProtocol.encode(request)) { error in
            XCTAssertEqual(error as? AgentNotifyError, .missingTitle)
        }
    }

    func testEncodeAcceptsBodyWhenTitleIsBlank() throws {
        let request = AgentNotifyRequest(title: "", body: "agent waiting")
        let frame = try AgentNotifyProtocol.encode(request)
        XCTAssertFalse(frame.isEmpty)
    }

    func testEncodeRejectsOversizedPayload() {
        let huge = String(repeating: "x", count: AgentNotifyProtocol.maxFrameBytes + 100)
        let request = AgentNotifyRequest(title: "x", body: huge)
        XCTAssertThrowsError(try AgentNotifyProtocol.encode(request)) { error in
            switch error as? AgentNotifyError {
            case .payloadTooLarge:
                break
            default:
                XCTFail("expected payloadTooLarge, got \(error)")
            }
        }
    }

    func testDecodeIgnoresUnknownFields() throws {
        // Forward compatibility: fields the server doesn't recognize must not
        // cause a hard failure, so newer CLI versions can talk to older apps.
        let json = #"{"v":1,"title":"Hello","body":"World","futureField":"x"}"#
        let data = Data(json.utf8)
        let decoded = try AgentNotifyProtocol.decode(data)
        XCTAssertEqual(decoded.title, "Hello")
        XCTAssertEqual(decoded.body, "World")
    }

    func testToolFieldRoundTripsAsRichNotifyTool() throws {
        let original = AgentNotifyRequest(
            title: "Running",
            toolName: "Codex",
            kind: .activity
        )

        let decoded = try AgentNotifyProtocol.decode(try AgentNotifyProtocol.encode(original))

        XCTAssertEqual(decoded.toolName, "Codex")
    }

    func testDecodeAcceptsTrailingNewline() throws {
        let json = #"{"v":1,"title":"Hello"}"# + "\n"
        let data = Data(json.utf8)
        let decoded = try AgentNotifyProtocol.decode(data)
        XCTAssertEqual(decoded.title, "Hello")
    }

    func testDecodeRejectsMalformedJSON() {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try AgentNotifyProtocol.decode(data)) { error in
            switch error as? AgentNotifyError {
            case .decode:
                break
            default:
                XCTFail("expected decode error, got \(error)")
            }
        }
    }

    func testSocketPathStaysWithinSunPathLimit() {
        let url = AgentNotifySocketPath.resolveSocketURL(homeDirectory: "/Users/krystal")
        XCTAssertLessThanOrEqual(url.path.utf8.count, 103, "socket path must fit sockaddr_un.sun_path on Darwin")
    }

    func testSocketPathDirectoryMatchesSocketURL() {
        let dir = AgentNotifySocketPath.resolveDirectory(homeDirectory: "/Users/eve")
        let url = AgentNotifySocketPath.resolveSocketURL(homeDirectory: "/Users/eve")
        XCTAssertEqual(url.deletingLastPathComponent().path, dir.path)
        XCTAssertEqual(url.lastPathComponent, AgentNotifySocketPath.socketFileName)
    }

    func testExecutableScopedSocketPathIsStableAndDistinctFromSharedSocket() {
        let executablePath = "/Users/eve/Library/Developer/Xcode/DerivedData/Argo/Build/Products/Debug/Argo.app/Contents/MacOS/Argo"
        let first = AgentNotifySocketPath.resolveExecutableSocketURL(
            executablePath: executablePath,
            homeDirectory: "/Users/eve"
        )
        let second = AgentNotifySocketPath.resolveExecutableSocketURL(
            executablePath: executablePath,
            homeDirectory: "/Users/eve"
        )
        let shared = AgentNotifySocketPath.resolveSocketURL(homeDirectory: "/Users/eve")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.deletingLastPathComponent(), shared.deletingLastPathComponent())
        XCTAssertNotEqual(first.lastPathComponent, shared.lastPathComponent)
        XCTAssertTrue(first.lastPathComponent.hasPrefix("a-"))
        XCTAssertLessThanOrEqual(first.path.utf8.count, 103, "socket path must fit sockaddr_un.sun_path on Darwin")
    }
}
