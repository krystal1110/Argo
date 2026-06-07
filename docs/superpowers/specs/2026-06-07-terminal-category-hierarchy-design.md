# Terminal Category Hierarchy Design

## Goal

Fix the terminal chrome hierarchy so the user-visible model matches the intended structure:

1. The left sidebar remains the workspace/repository tree.
2. The top terminal chrome path bubble represents a second-level terminal category within the selected workspace/worktree.
3. Split actions such as Command+D create third-level terminal panes inside the selected category, not new top-level chrome items.
4. Second-level categories can be renamed.

The validated demo is V3: the top chrome only changes when a category is created, selected, or renamed; splitting changes only the pane grid below it.

## Existing Structure

The persisted runtime already has a compatible three-level shape:

- `WorkspaceModel` is the first-level workspace.
- `WorktreeSessionStateRecord.tabs` stores multiple per-worktree session containers.
- Each `WorkspaceTabStateRecord` owns its own `layout`, `panes`, `focusedPaneID`, and `zoomedPaneID`.

Today the UI names and renders `WorkspaceTabStateRecord` as terminal tabs. That makes split and duplicate actions look conceptually close to top chrome tab creation, even though pane splitting already belongs under the selected tab/session container.

## Chosen Approach

Reuse `WorkspaceTabStateRecord` as the persistence and runtime container, but present it as a second-level terminal category in the terminal chrome.

This avoids a risky model migration while correcting the user-facing hierarchy:

- Existing `createTab`, `selectTab`, `closeTab`, `renameTab`, and tab-scoped layout persistence remain the data operations.
- The terminal chrome no longer presents third-level terminals as top-level chips.
- User-facing names and controls shift from "tab" language toward "category" or "session group" language where visible.
- Command+D and split buttons continue to call `splitFocusedPane`; they never call `createTab`.

## Alternatives Considered

### New TerminalGroup Model

Add a new `TerminalGroupStateRecord` type and migrate `WorkspaceTabStateRecord` into it.

This is semantically clean, but it creates unnecessary migration risk and touches persistence, tests, command naming, canvas card IDs, and runtime controller lookup at once.

### UI-Only Hide Existing Tabs

Keep all names and behavior internally as tabs and only hide tab chips from the chrome.

This is fastest, but it leaves rename, shortcuts, settings, and command palette language inconsistent. It also makes future bugs likely because the code would still describe the wrong concept.

## UI Design

`TerminalLocalChrome` should render one horizontal strip for second-level categories only.

The selected category appears as the existing path-style capsule, preserving the current Argo visual language: compact height, dark glass chrome, monospaced path text, subtle stroke, and icon-only controls.

When more than one category exists, additional category capsules can appear in the same strip as switch targets. These are still second-level categories, not terminals. Third-level terminals are represented only by the split pane layout below the chrome and by each pane's own focus/status affordances.

The chrome action area should contain:

- `+`: create a new second-level category under the current workspace/worktree.
- split right: create a new third-level pane in the selected category.
- split down: create a new third-level pane in the selected category.

Rename is available on the selected category capsule. The implementation can use an inline text field, double-click, and/or a small pencil/menu affordance, but it must not require the old preview-only tab strip.

## Behavior

Creating a category:

- Triggered only by the chrome `+` button or existing "new tab" command paths that intentionally create a new category.
- Creates a new `WorkspaceTabStateRecord` for the active worktree.
- Selects the new category.
- Starts with one pane using the active worktree path and existing backend configuration rules.

Splitting a terminal:

- Triggered by Command+D, Command+Shift+D, the split buttons, context menu split actions, or command palette split actions.
- Calls the existing focused-pane split path.
- Adds a pane to the selected category's `layout` and `panes`.
- Leaves the category count and category titles unchanged.

Renaming a category:

- Updates the selected `WorkspaceTabStateRecord.title`.
- Sets `isManuallyNamed = true`.
- Ignores empty or whitespace-only names.
- Persists through the existing workspace state save path.

Switching category:

- Saves the active category state.
- Loads the selected category's controller, layout, panes, focus, and zoom state.
- Returns from preview mode to terminals, matching current tab selection behavior.

Closing category:

- Uses existing close-tab semantics if exposed in the new chrome.
- If the last category is closed, replace it with a fresh default category rather than leaving the workspace without a usable terminal container.

## Data Flow

`WorkspaceSessionDetailView` passes category data into `TerminalLocalChrome`:

- `categories`: current `workspace.tabs`
- `activeCategoryID`: current `workspace.activeTabID`
- `categoryPaneCount`: derived from `workspace.paneCount(for:)`
- `onSelectCategory`: calls `store.selectTab(in:tabID:)`
- `onCreateCategory`: calls `store.createTab(in:)`
- `onRenameCategory`: calls `store.renameTab(in:tabID:title:)`
- `onSplitRight` / `onSplitDown`: focus the current pane and call `store.splitFocusedPane`

`TerminalLocalChrome` owns only transient edit state for inline rename. It should not mutate workspace state directly.

## Text And Shortcut Naming

The visible UI should avoid suggesting that split panes are top chrome tabs.

Recommended naming:

- Existing user-facing "New Tab" in the terminal chrome can become "New Category" or "New Terminal Group".
- Shortcut settings can continue to map to the same action initially, but subtitles should clarify that this creates a new terminal category/group, not a split pane.
- Split shortcut subtitles remain pane-focused.

If a full terminology pass is too large for the first implementation, the chrome itself must still be correct; settings and command palette copy can be updated in the same patch if the touched surface stays small.

## Error Handling

- Empty rename commits are ignored and leave the old title intact.
- Rename cancel restores the previous title.
- Split actions are disabled or no-op when no focused pane exists.
- Category creation should still work when the active layout is empty by using the existing default pane creation behavior.
- Switching or closing a category must persist the current category state before loading another one.

## Testing

Add or update focused tests around the state layer:

- `WorktreeSessionStateRecord.renameTab` continues to trim names, ignore empty names, and mark manual titles.
- Creating a category increases `tabs.count`.
- Splitting a pane increases the selected category's pane count without increasing `tabs.count`.
- Switching categories preserves separate layouts/pane counts.

Add UI/source-level coverage where the project already uses source assertions:

- `TerminalLocalChrome` no longer renders third-level pane chips as top chrome tab buttons.
- The chrome exposes a rename callback for the selected category.
- Split buttons call split callbacks, not category creation.

Manual smoke test:

1. Open a workspace with one category.
2. Press Command+D and confirm only the pane grid changes.
3. Click `+` and confirm a new top category appears with one pane.
4. Rename the selected category and restart or switch workspaces to confirm persistence.
5. Switch back and forth between categories to confirm each keeps its own pane layout.

## Out Of Scope

- Replacing the persisted `WorkspaceTabStateRecord` type with a new model.
- Changing the left sidebar workspace/worktree hierarchy.
- Changing Ghostty or terminal backend behavior.
- Redesigning the terminal pane content or status strip.
- Changing global canvas card identity unless a compile-time dependency requires a small naming adapter.

## Acceptance Criteria

- The top chrome represents only second-level categories.
- Command+D and split controls never add a new top chrome item.
- The selected category can be renamed and persists.
- Existing saved workspaces continue to load without migration breakage.
- Unit tests cover the category-vs-pane distinction.
