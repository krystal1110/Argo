# Command Palette Image Button Design

## Goal

Replace the current wide Command Palette toolbar button in the top glass chrome with a compact image-style button. The command palette behavior stays the same: clicking the button toggles the existing command palette, keyboard shortcuts continue to use the same `WorkspaceCommand.toggleCommandPalette` path, and the overlay UI remains unchanged.

## Chosen Direction

Use the refined A2 direction from the visual companion: a small circular image-mark button centered where the existing wide Command Palette pill lives today.

The button should:

- Keep the current top-toolbar balance by staying between the workspace pill and the right-side toolbar cluster.
- Use a 36px circular mark so it reads as a single image rather than a text command.
- Reuse the glass chrome visual language: subtle border, small shadow, and a compact icon/image mark.
- Preserve `accessibilityLabel` and `help` as the localized Command Palette title.

## Implementation Shape

The implementation should stay scoped to `Argo/UI/MainWindowView.swift` unless extracting a tiny reusable view into nearby UI component code clearly improves readability.

The existing wide button:

- Dispatches `store.dispatch(.toggleCommandPalette)`.
- Contains a `GlassToolbarGroup` with `sparkle` plus localized text.
- Has a fixed wide frame.

The new button should:

- Keep the same `Button` action and plain button style.
- Replace the long label with a compact image-mark view.
- Avoid visible text inside the toolbar button.
- Continue respecting `uiScale` through the existing `.scaleEffect(uiScale)`.

## Testing And Verification

Because this is a SwiftUI visual chrome change with unchanged command dispatch behavior, verification should focus on build coverage and a manual visual smoke test:

- Run the macOS Debug build with `xcodebuild -project Argo.xcodeproj -scheme Argo -configuration Debug -destination 'platform=macOS,arch=arm64' build`.
- Confirm the top toolbar no longer shows the Command Palette text pill.
- Confirm the small image button opens and dismisses the existing command palette.
- Confirm surrounding toolbar groups still fit without overlap at the default UI scale.
