//
//  main.swift
//  Argo
//
//  Author: krystal
//

import Cocoa

// CLI dispatch: when invoked as `Argo <subcommand> ...` (or via a `argo`
// shim that execs the app binary), behave as a short-lived CLI client
// instead of starting the AppKit event loop. Anything else falls through
// to NSApplicationMain so Finder-launches and `open -a Argo` are
// unaffected.
let cliArguments = Array(CommandLine.arguments.dropFirst())
if let firstArgument = cliArguments.first {
    let rest = Array(cliArguments.dropFirst())
    switch firstArgument {
    case "notify":
        exit(AgentNotifyCLI.run(arguments: rest).rawValue)
    case "claude-hook":
        exit(AgentNotifyCLI.runClaudeHook().rawValue)
    case "claude-hooks":
        exit(ClaudeHookInstallerCLI.run(arguments: rest).rawValue)
    case "ping":
        exit(ArgoControlCLI.runPing(arguments: rest).rawValue)
    case "open":
        exit(ArgoControlCLI.runOpen(arguments: rest).rawValue)
    case "split":
        exit(ArgoControlCLI.runSplit(arguments: rest).rawValue)
    case "send-keys":
        exit(ArgoControlCLI.runSendKeys(arguments: rest).rawValue)
    case "status":
        exit(ArgoControlCLI.runStatus(arguments: rest).rawValue)
    case "read":
        exit(ArgoControlCLI.runRead(arguments: rest).rawValue)
    case "agents":
        exit(ArgoControlCLI.runAgents(arguments: rest).rawValue)
    case "session":
        // `argo session list ...` — second token routes to the subcommand.
        let session = Array(rest.dropFirst())
        switch rest.first {
        case "list":
            exit(ArgoControlCLI.runSessionList(arguments: session).rawValue)
        default:
            FileHandle.standardError.write(Data("argo session: unknown subcommand (try `list`)\n".utf8))
            exit(64)
        }
    default:
        break
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
MainActor.assumeIsolated {
    app.delegate = delegate
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
