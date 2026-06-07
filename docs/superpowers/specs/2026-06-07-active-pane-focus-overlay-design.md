# Active Pane Focus Overlay Design

## Goal

When a workspace is split into multiple terminal panes, users must be able to tell immediately which pane will receive keyboard input.

The confirmed direction is based on the provided cmux-like reference:

- The active pane keeps the normal terminal appearance.
- Inactive panes receive a translucent dark overlay.
- The shared terminal chrome shows one path chip per pane.
- The active pane's path chip is a brighter gray rounded capsule.
- No blue focus ring or heavy border is drawn around terminal content.

## Scope

In scope:

- Improve active-pane visibility for split terminal layouts.
- Render multiple pane path chips in `TerminalLocalChrome` when a terminal tab contains multiple panes.
- Highlight the focused pane's path chip with a gray rounded capsule.
- Add an inactive overlay to non-focused `TerminalPaneView` content.
- Allow clicking a path chip to focus the corresponding pane.
- Keep single-pane layouts visually clean and close to the current single path pill.

Out of scope:

- No changes to Ghostty rendering, terminal colors, prompts, cursor drawing, or scrollback content.
- No blue focus rings around panes.
- No new terminal runtime or alternate pane layout model.
- No changes to sidebar, workspace list, repository navigation, or file tree behavior.
- No changes to tab persistence format unless existing fields already support the needed state.

## Current System

`WorkspaceSessionDetailView` renders one shared `TerminalLocalChrome` above the split tree, then renders `SplitNodeView`.

`SplitNodeView` recursively renders `TerminalPaneView` for each `PaneLeaf`.

`TerminalPaneView` already knows whether it is focused:

- `sessionController.focusedPaneID == paneID`
- tap and context-menu actions call `workspace.focusPane(paneID)`

`TerminalLocalChrome` currently receives:

- `path`
- `tabs`
- `activeTabID`
- `isFocused`
- split and tab actions

It does not receive the visible pane order or per-pane session metadata, so it cannot currently show one chip per pane.

## Confirmed Visual Behavior

For split panes:

- The top terminal chrome is divided into chip slots that align visually with the pane order.
- Each chip contains a terminal icon and the pane's abbreviated working directory.
- The active chip uses a light gray capsule fill, subtle border, and stronger text opacity.
- Inactive chips are transparent or very low-emphasis text.
- The right side still contains new tab, split right, and split down actions.
- The terminal body for inactive panes is covered by a translucent dark overlay.
- The active terminal body is unmodified.

For one pane:

- Keep the current single path pill treatment.
- Do not add an inactive overlay.

## Proposed Architecture

Use the existing shared terminal chrome and pane rendering boundaries.

### `TerminalLocalChrome`

Add a pane-chip mode:

- Input: ordered pane descriptors for the active terminal tab.
- Each descriptor contains `paneID`, display path, and focused state.
- If descriptor count is greater than one, render chips across the available chrome width.
- If descriptor count is one, render the existing single path pill.
- Clicking a chip calls `onSelectPane(paneID)`.

The component remains presentation-focused. It should not own focus state or read from `WorkspaceModel` directly.

### `WorkspaceSessionDetailView`

Build pane descriptors from the active tab's current layout:

- Use `workspace.paneOrder` for ordering.
- For each pane ID, resolve `workspace.sessionController.session(for:)`.
- Use `session.effectiveWorkingDirectory.terminalChromeDisplayPath` for the chip label.
- Mark a descriptor focused when its `paneID` equals `workspace.sessionController.focusedPaneID`.

Pass the descriptors and `onSelectPane` closure into `TerminalLocalChrome`.

### `TerminalPaneView`

Overlay inactive panes without changing terminal content:

- Compute `isInactiveInSplit = paneCount > 1 && !isFocused`.
- Place a translucent dark overlay over the `TerminalHostView` region only.
- The overlay must not intercept mouse events; clicks should still be able to focus the pane.
- Keep search bar and status strip behavior intact.

`TerminalPaneView` will need to know whether multiple panes are visible in the current tab. The preferred shape is a small boolean such as `isDimmedWhenInactive`, passed from `SplitNodeView` or `WorkspaceSessionDetailView`.

### `SplitNodeView`

Pass the inactive-dimming flag down to each `TerminalPaneView`.

When zoomed:

- Do not dim the zoomed pane.
- The chrome should behave like a single visible pane, even if the tab has multiple panes underneath.

## Interaction

- Clicking terminal content keeps the existing behavior: focus that pane.
- Clicking a pane path chip focuses that pane.
- Split actions in the shared chrome continue to act on the focused pane.
- If no focused pane exists, fall back to the first visible pane and avoid rendering misleading active state.
- New pane creation should focus the new pane, so the new chip becomes active and old panes receive the overlay.

## Visual Parameters

Use values close to the confirmed mockup rather than a heavy redesign:

- Active chip height: about `34-36px`.
- Active chip shape: full capsule.
- Active chip fill: light gray glass, not accent blue.
- Active chip border: subtle white stroke.
- Inactive overlay: dark translucent fill around `rgba(7, 9, 15, 0.45)`.
- Optional overlay gradient is acceptable if it makes the dimming feel less flat.
- Pane dividers remain thin and understated.

The overlay must be visible enough that active pane discovery is immediate, but not so dark that logs or long-running output become unreadable.

## Accessibility

- Pane chips should expose useful labels, such as `Focus pane ~/Documents/AI`.
- The focused chip should expose selected/focused state where SwiftUI supports it.
- Icon-only actions keep existing accessibility labels and help text.
- The inactive overlay is visual only and should not block VoiceOver navigation or pointer interaction.

## Testing

Unit-level or source-level tests should cover:

- `TerminalLocalChrome` is passed per-pane descriptors when multiple panes exist.
- Single-pane layouts still use the compact single path presentation.
- `TerminalPaneView` receives a dimming flag and applies an overlay only when inactive in a split.
- Zoomed pane mode does not dim the visible pane.
- Clicking a pane chip routes to `workspace.focusPane(paneID)`.

Manual smoke test:

- Open a workspace with one pane and confirm the chrome remains clean.
- Press the duplicate/split shortcut several times to create side-by-side panes.
- Click each pane and confirm the active pane remains normal while other panes receive the dim overlay.
- Click each top path chip and confirm focus follows the chip.
- Split from the shared chrome and confirm the action applies to the currently focused pane.
- Test zoomed pane mode and confirm the visible pane is not dimmed.

## Risks And Mitigations

- Risk: chip widths become cramped with many panes.
  - Mitigation: use horizontal scrolling or truncation; preserve actions on the right.

- Risk: overlay blocks terminal clicks.
  - Mitigation: apply `.allowsHitTesting(false)` to the visual overlay and keep existing tap focus behavior.

- Risk: shared chrome pane order diverges from split layout.
  - Mitigation: derive descriptors from `workspace.paneOrder`, the same source used for focus traversal and session snapshots.

- Risk: inactive overlay makes output too hard to read.
  - Mitigation: keep opacity around the confirmed medium value and avoid blur or color inversion.

## Implementation Notes

Expected primary files:

- `Argo/UI/Workspace/WorkspaceDetailView.swift`
- `Argo/UI/Workspace/TerminalLocalChrome.swift`
- `Argo/UI/Workspace/SplitNodeView.swift`
- `Argo/UI/Workspace/TerminalPaneView.swift`
- `Tests/WorkspaceTabsTests.swift`
- `Tests/PaneLayoutTests.swift` or a focused new test file if needed

The implementation should preserve the existing `AppKit container + SwiftUI content` architecture and avoid touching the Ghostty adapter layer.
