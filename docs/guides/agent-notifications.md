# Agent Notifications

Argo surfaces notifications from anything running inside a pane — shells,
build tools, AI coding agents — through the dynamic island and the system
notification center. There are two delivery paths.

## OSC escape sequences (works automatically)

Anything in a pane that emits an OSC 9 or OSC 777 sequence is already picked
up. No setup required.

```sh
# OSC 9 (iTerm2 style) — title only
printf '\e]9;Build finished\a'

# OSC 777 (rxvt style) — title + body
printf '\e]777;notify;Build finished;All tests pass\a'
```

The body and title both flow through to the dynamic island. The originating
pane is recorded with the notification.

## `argo notify` CLI (out-of-band)

Use `argo notify` when an agent or script can't easily print to its parent
PTY — for example, a background job, a remote command over SSH, or a
process that buffers stdout. The CLI sends a JSON frame to the running
Argo app over a Unix domain socket; no PTY is required.

```sh
# Two positional arguments → title, body
argo notify "Claude is waiting" "Choose an option"

# Flag form
argo notify --title "Build done" --body "All tests pass"

# Short flags
argo notify -t "Codex" -m "Needs your input" -a "Codex"

# From inside a pane, $ARGO_PANE_ID auto-routes to that pane
argo notify --title "Tests passing" --body "🎉"
```

### Options

| Flag | Meaning |
|---|---|
| `-t, --title <text>` | Notification title (required if no positional given) |
| `-b, --body <text>`  | Notification body (alias `-m`, `--message`) |
| `-p, --pane <uuid>`  | Originating pane (defaults to `$ARGO_PANE_ID`) |
| `-w, --workspace <uuid>` | Originating workspace |
| `-a, --agent <name>` | Agent display name (e.g. `Claude`, `Codex`) |
| `-V, --version`      | Print Argo version and exit |
| `-h, --help`         | Show help and exit |

### Exit codes

| Code | Meaning |
|---|---|
| `0`  | Notification accepted by the app |
| `64` | Usage error (missing arguments, unknown flag) |
| `69` | Argo is not running |
| `74` | I/O error talking to the socket |

### Routing rules

When a request arrives, Argo resolves the target workspace in this order:

1. Explicit `--workspace <uuid>` if provided.
2. The workspace whose currently-active session controller owns the
   `--pane <uuid>` (or `$ARGO_PANE_ID`) the request was tagged with.
3. The currently-selected workspace.

The notification is then posted to the dynamic island for that workspace
with the pane recorded as `terminalTag` so click-through can navigate
back to the originating pane.

## Environment variables Argo injects

Inside every pane Argo spawns, these are set:

| Variable | Value |
|---|---|
| `ARGO_PANE_ID` | UUID of the owning pane — used by `argo notify` for routing |
| `ARGO_SESSION_ID` | UUID of the current process-launch attempt — used by Argo's process-reaper |
| `TERM_PROGRAM` | `Argo` |
| `TERM_PROGRAM_VERSION` | The current Argo version |

`ARGO_PANE_ID` is the one to use from agents and scripts.

## Installing the CLI shim

The Argo app binary is itself the CLI; the executable inside the .app bundle
already understands `notify` as a subcommand. The simplest way to expose it
on `$PATH`:

```sh
sudo ln -sf /Applications/Argo.app/Contents/MacOS/Argo /usr/local/bin/argo
```

After that, `argo notify ...` works from any shell.

## Wire format (for tooling)

The CLI is a thin client over a JSON-line protocol. If you'd rather skip the
binary and write directly to the socket, send a single newline-terminated
JSON object to `~/Library/Application Support/Argo/agent-notify.sock`:

```json
{"v":1,"title":"Build done","body":"All tests pass","pane":"<uuid>","agent":"Claude"}
```

Fields: `v` (int, currently `1`), `title` (string, optional if `body` set),
`body`, `pane`, `workspace`, `agent` (all optional strings). Unknown fields
are ignored — the protocol is forward-compatible.
