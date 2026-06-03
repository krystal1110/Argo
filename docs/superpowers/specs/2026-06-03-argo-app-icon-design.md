# Argo App Icon Redesign

## Goal

Replace the current Argo macOS app icon with a cleaner, more durable version that preserves the product's existing identity: a terminal-centered developer workspace with a dark, cosmic, navigation-like atmosphere.

The new icon should feel native on macOS, remain recognizable at small Dock and Finder sizes, and align with Argo's existing visual system: deep charcoal backgrounds, blue and teal accents, restrained glow, rounded geometry, and command-line symbolism.

## Chosen Direction

Use the **Terminal Constellation** direction.

The icon keeps the familiar terminal-window metaphor and adds a subtle constellation/orbit layer behind it. The terminal remains the primary read, while the stars and orbit imply navigation, multi-repository context, and a workspace that helps the user move through complex development states.

This direction is preferred because it gives Argo continuity with the existing app icon while improving clarity, polish, and small-size behavior.

## Visual Specification

The final icon should use a macOS squircle-style rounded rectangle with a dark layered base:

- Background: near-black charcoal with subtle depth, using Argo-like values around `#0B0D12`, `#111520`, and `#151B29`.
- Accent light: blue to cyan/teal glow, drawing from `ArgoTheme.accent` and `ArgoTheme.localAccent`.
- Secondary accent: a very small amount of violet or cool blue shadow is acceptable, but it should not become the dominant palette.
- Main object: a simplified terminal panel in the lower half, with a soft light surface and clear prompt chevron plus short cursor.
- Supporting layer: 2-4 small star points and one thin orbit/constellation curve behind or above the terminal.
- Texture: minimal. Avoid photographic imagery, noisy nebula textures, visible text, tiny UI details, or dense decorative particles.

The terminal panel should be clean enough to read at 32px. The prompt chevron and cursor should survive downscaling better than the current icon.

## Composition

Use a centered composition with the terminal panel occupying the lower-middle area. The constellation layer sits in the upper half and should remain secondary.

Recommended proportions:

- Icon safe area: keep important content inside roughly 82% of the canvas.
- Terminal panel: about 58-68% of icon width.
- Prompt mark: bold enough to read at 32px, but not so large that it becomes a standalone logo.
- Orbit line: thin and low contrast, used for motion and depth rather than literal detail.

The overall silhouette should be simple when blurred or viewed at Dock size.

## Deliverables

Produce the replacement asset set for `Argo/Assets.xcassets/AppIcon.appiconset`:

- `appicon_16x16.png`
- `appicon_16x16@2x.png`
- `appicon_32x32.png`
- `appicon_32x32@2x.png`
- `appicon_128x128.png`
- `appicon_128x128@2x.png`
- `appicon_256x256.png`
- `appicon_256x256@2x.png`
- `appicon_512x512.png`
- `appicon_512x512@2x.png`

The generated 1024px master should be archived in a project-local asset path before downscaling, so the icon can be regenerated without depending on an external temporary file.

## Constraints

- Do not change app behavior, bundle identifiers, signing, or release scripts.
- Do not modify unrelated UI icon systems such as sidebar repository icons or toolbar feature icons.
- Do not introduce text into the icon.
- Do not use a one-note blue/purple gradient. The palette should balance blue with teal/cyan and dark neutral depth.
- Do not replace the icon with a generic terminal glyph; it should still feel like Argo.

## Validation

Visual validation should include:

- Compare the new icon at 1024px, 512px, 128px, 64px, 32px, and 16px.
- Confirm the terminal panel and prompt remain legible at 32px.
- Confirm 16px still reads as a dark app icon with a bright terminal/prompt signal, even if constellation details disappear.
- Confirm the icon does not feel like a screenshot, photo, or generic SF Symbol tile.
- Confirm it sits comfortably beside other macOS app icons in Dock scale.

Project validation should include:

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

If only image assets change, focused visual validation plus an Xcode asset catalog build is sufficient.
