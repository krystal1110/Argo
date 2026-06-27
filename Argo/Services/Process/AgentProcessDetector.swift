//
//  AgentProcessDetector.swift
//  Argo
//
//  Author: krystal
//

import Darwin
import Foundation

/// Best-effort detector for common coding-agent CLIs running inside a pane's
/// process tree. Self-reported `argo status` remains the authoritative signal;
/// this is the passive fallback used by `argo agents`.
nonisolated enum AgentProcessDetector {
    struct Detected: Equatable {
        let pid: pid_t
        let type: String
        let displayName: String
    }

    struct Definition {
        let type: String
        let name: String
        let tokens: [String]
    }

    static let definitions: [Definition] = [
        Definition(type: "claude-code", name: "Claude Code", tokens: ["claude", "claude-code"]),
        Definition(type: "codex", name: "Codex", tokens: ["codex", "codex-cli"]),
        Definition(type: "aider", name: "Aider", tokens: ["aider"]),
        Definition(type: "gemini", name: "Gemini CLI", tokens: ["gemini-cli", "gemini"]),
        Definition(type: "opencode", name: "OpenCode", tokens: ["opencode"]),
        Definition(type: "cursor-agent", name: "Cursor Agent", tokens: ["cursor-agent"]),
        Definition(type: "qwen-code", name: "Qwen Code", tokens: ["qwen-code", "qwen"]),
        Definition(type: "goose", name: "Goose", tokens: ["goose"]),
        Definition(type: "crush", name: "Crush", tokens: ["crush"]),
        Definition(type: "cline", name: "Cline", tokens: ["cline"]),
        Definition(type: "amp", name: "Amp", tokens: ["amp"]),
    ]

    static func detect(
        rootPID: pid_t,
        argsProvider: (pid_t) -> [UInt8]? = procArgsRaw(pid:)
    ) -> Detected? {
        var pids = [rootPID]
        pids.append(contentsOf: ProcessTree.descendants(of: rootPID))

        for pid in pids {
            guard let raw = argsProvider(pid),
                  let parsed = parseProcArgs(raw),
                  let hit = classify(execPath: parsed.execPath, argv: parsed.argv) else {
                continue
            }
            return Detected(pid: pid, type: hit.type, displayName: hit.name)
        }
        return nil
    }

    static func classify(execPath: String, argv: [String]) -> (type: String, name: String)? {
        var candidates = Set<String>()
        addComponents(of: execPath, to: &candidates)
        if let firstArg = argv.first {
            addComponents(of: firstArg, to: &candidates)
        }
        if argv.count >= 2 {
            addComponents(of: argv[1], to: &candidates)
        }

        for definition in definitions {
            for token in definition.tokens where candidates.contains(token) {
                return (definition.type, definition.name)
            }
        }
        return nil
    }

    private static func addComponents(of path: String, to candidates: inout Set<String>) {
        let lowercased = path.lowercased()
        candidates.insert((lowercased as NSString).lastPathComponent)
        for component in lowercased.split(separator: "/") where !component.isEmpty {
            candidates.insert(String(component))
        }
    }

    static func parseProcArgs(_ data: [UInt8]) -> (execPath: String, argv: [String])? {
        guard data.count > 4 else { return nil }
        let argc = data.prefix(4).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: Int32.self)
        }
        guard argc >= 0 else { return nil }

        var index = 4
        let execStart = index
        while index < data.count, data[index] != 0 {
            index += 1
        }
        let execPath = String(decoding: data[execStart..<index], as: UTF8.self)
        while index < data.count, data[index] == 0 {
            index += 1
        }

        var argv: [String] = []
        var read = 0
        while read < Int(argc), index < data.count {
            let start = index
            while index < data.count, data[index] != 0 {
                index += 1
            }
            argv.append(String(decoding: data[start..<index], as: UTF8.self))
            while index < data.count, data[index] == 0 {
                index += 1
            }
            read += 1
        }
        return (execPath, argv)
    }

    static func procArgsRaw(pid: pid_t) -> [UInt8]? {
        var argmax = 0
        var argmaxSize = MemoryLayout<Int>.size
        var argmaxMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&argmaxMib, 2, &argmax, &argmaxSize, nil, 0) == 0, argmax > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: argmax)
        var size = argmax
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        return Array(buffer.prefix(size))
    }
}
