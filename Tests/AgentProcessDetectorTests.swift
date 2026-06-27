//
//  AgentProcessDetectorTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class AgentProcessDetectorTests: XCTestCase {
    func testClassifiesNodeWrappedClaudeCode() {
        let hit = AgentProcessDetector.classify(
            execPath: "/opt/homebrew/bin/node",
            argv: ["node", "/Users/me/.npm/_npx/123/node_modules/@anthropic-ai/claude-code/cli.js"]
        )

        XCTAssertEqual(hit?.type, "claude-code")
        XCTAssertEqual(hit?.name, "Claude Code")
    }

    func testClassifiesCodexBinary() {
        let hit = AgentProcessDetector.classify(
            execPath: "/opt/homebrew/bin/codex",
            argv: ["codex", "resume", "--last"]
        )

        XCTAssertEqual(hit?.type, "codex")
    }

    func testDoesNotClassifyTrailingArgumentOrCwdLikePath() {
        let hit = AgentProcessDetector.classify(
            execPath: "/bin/zsh",
            argv: ["zsh", "-lc", "cd /tmp/codex-demo && npm test"]
        )

        XCTAssertNil(hit)
    }

    func testParseProcArgsReadsExecPathAndArgv() {
        var raw: [UInt8] = []
        var argc = Int32(2)
        withUnsafeBytes(of: &argc) { raw.append(contentsOf: $0) }
        raw.append(contentsOf: Array("/usr/bin/node".utf8))
        raw.append(0)
        raw.append(0)
        raw.append(contentsOf: Array("node".utf8))
        raw.append(0)
        raw.append(contentsOf: Array("/tmp/cli.js".utf8))
        raw.append(0)

        let parsed = AgentProcessDetector.parseProcArgs(raw)

        XCTAssertEqual(parsed?.execPath, "/usr/bin/node")
        XCTAssertEqual(parsed?.argv, ["node", "/tmp/cli.js"])
    }
}
