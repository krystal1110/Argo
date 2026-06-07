# Left Rail Canvas and Overview Design

## Goal

Move the global Canvas entry from the top toolbar into a new fixed left rail, and use that rail as the app's global mode switcher. The user should be able to switch between the normal workspace view, Canvas, and Overview from the far-left edge without mixing those global modes into the workspace tree.

## Chosen Direction

Use a narrow global rail at the far left with these entries:

- Workspace
- Canvas
- Overview
- Settings

Command Palette is intentionally not included in the rail. It remains available through the existing keyboard shortcut and existing command palette entry points.

## Mode Behavior

Workspace mode shows the existing workspace sidebar and `WorkspaceDetailView`.

Canvas mode hides the workspace sidebar and gives the main area to `GlobalCanvasView`. Canvas remains a full global mode rather than a workspace child node.

Overview mode also hides the workspace sidebar and gives the main area to `OverviewView`. This keeps Canvas and Overview consistent: both are global views, while Workspace is the mode that brings back the project list.

Settings is an action entry, not a persistent mode. Activating it should open the existing settings UI using current app conventions. After the sheet/window closes, the active global mode remains unchanged.

## Structure

Introduce an app-level view mode state for the main window, conceptually:

- `workspace`
- `canvas`
- `overview`

Render the new rail beside the existing `NavigationSplitView`. In workspace mode, keep the current split view behavior. In canvas and overview modes, render only the rail plus the selected global content, without the workspace sidebar column.

The rail should be compact and icon-led, with tooltips and accessibility labels for each item. The selected mode should be visually obvious. Use existing theme colors and existing icon conventions.

## Existing Entry Points

The current top toolbar Canvas and Overview buttons can either be removed or kept briefly as duplicates during migration. The preferred final state is to avoid duplicate primary navigation and let the left rail own Workspace, Canvas, and Overview switching.

Command Palette remains outside the rail.

## Persistence

The selected global mode does not need to be persisted in the first version. Opening the app can default to Workspace mode. Existing Canvas state persistence stays unchanged through `globalCanvasState`.

## Testing

Add focused tests where practical for mode state behavior if extracted into a small model. Existing UI-heavy behavior should be verified with an `xcodebuild` test run and a manual smoke test:

- Workspace mode shows the workspace sidebar and selected workspace detail.
- Canvas mode hides the workspace sidebar and shows `GlobalCanvasView`.
- Overview mode hides the workspace sidebar and shows `OverviewView`.
- Settings opens from the rail without changing the active mode.
- Command Palette still opens through its existing shortcut/entry point.
