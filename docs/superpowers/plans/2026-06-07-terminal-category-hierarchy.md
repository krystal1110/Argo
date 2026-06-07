# Terminal Category Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the terminal chrome show second-level terminal categories only, while split actions add third-level terminal panes inside the selected category.

**Architecture:** Reuse the existing `WorkspaceTabStateRecord` persistence/runtime container as the category backing store. Add a chrome-specific `TerminalChromeCategoryDescriptor` so the UI no longer renders pane descriptors as top chrome chips; `WorkspaceSessionDetailView` builds category descriptors and keeps all state mutations routed through `WorkspaceStore`.

**Tech Stack:** Swift, SwiftUI, AppKit-hosted terminal surfaces, XCTest source-level and model tests, Xcode project `Argo.xcodeproj`.

---

## File Structure

- Modify `Tests/WorkspaceTabsTests.swift`
  - Replace old source assertions that expect pane chips in the top chrome.
  - Add assertions that the chrome accepts category descriptors, exposes rename callbacks, and does not render `TerminalChromePaneChip`.
  - Add a model regression test proving split panes increase pane count without increasing category count.
- Modify `Argo/UI/Workspace/TerminalLocalChrome.swift`
  - Replace `TerminalChromePaneDescriptor` with `TerminalChromeCategoryDescriptor`.
  - Render only category pills in the top chrome.
  - Add inline rename state and callbacks.
  - Keep split buttons wired separately from category creation.
- Modify `Argo/UI/Workspace/WorkspaceDetailView.swift`
  - Build category descriptors from `workspace.tabs`.
  - Use manually renamed titles when present; otherwise display the category's focused/default pane working directory as the path-style label.
  - Route create/select/close/rename/split actions through existing store methods.
- Modify `Argo/Support/L10n.swift`
  - Add terminal category labels for `New Category`, `Rename Category`, and `Close Category` in English and Simplified Chinese.

---

### Task 1: Add Failing Tests For Category-Only Chrome

**Files:**
- Modify: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Replace stale chrome source tests**

In `Tests/WorkspaceTabsTests.swift`, replace these existing tests:

- `testTerminalTabsUseIntegratedChromeInsteadOfSeparateTopStrip`
- `testSplitPaneChromeUsesPaneDescriptorsAndFocusCallback`
- `testSplitPaneChromeKeepsSinglePanePathPillFallback`
- `testSplitPaneChromeKeepsTerminalTabsReachableWhenMultipleTabsExist`

with these tests:

```swift
    func testTerminalChromeUsesCategoriesInsteadOfPaneChips() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspaceDetailSource.contains("""
    private var showsTabStrip: Bool {
        workspace.previewPanel != nil
    }
"""))
        XCTAssertTrue(workspaceDetailSource.contains("categories: terminalChromeCategoryDescriptors"))
        XCTAssertTrue(workspaceDetailSource.contains("activeCategoryID: workspace.activeTabID"))
        XCTAssertTrue(workspaceDetailSource.contains("onSelectCategory: selectTerminalCategoryFromChrome"))
        XCTAssertTrue(terminalChromeSource.contains("struct TerminalChromeCategoryDescriptor"))
        XCTAssertTrue(terminalChromeSource.contains("let categories: [TerminalChromeCategoryDescriptor]"))
        XCTAssertTrue(terminalChromeSource.contains("ForEach(categories)"))
        XCTAssertFalse(terminalChromeSource.contains("TerminalChromePaneChip"))
        XCTAssertFalse(terminalChromeSource.contains("ForEach(paneDescriptors)"))
        XCTAssertFalse(terminalChromeSource.contains("combinedTabAndPaneStrip"))
    }

    func testTerminalChromeExposesInlineCategoryRename() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workspaceDetailSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/WorkspaceDetailView.swift"),
            encoding: .utf8
        )
        let terminalChromeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/TerminalLocalChrome.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(terminalChromeSource.contains("let onRenameCategory: (UUID, String) -> Void"))
        XCTAssertTrue(terminalChromeSource.contains("@State private var editingCategoryID: UUID?"))
        XCTAssertTrue(terminalChromeSource.contains("@State private var renameDraft = \"\""))
        XCTAssertTrue(terminalChromeSource.contains("TextField(\"\", text: $renameDraft)"))
        XCTAssertTrue(workspaceDetailSource.contains("onRenameCategory: renameTerminalCategoryFromChrome"))
        XCTAssertTrue(workspaceDetailSource.contains("store.renameTab(in: workspace, tabID: categoryID, title: normalized)"))
    }

    @MainActor
    func testSplittingFocusedPaneAddsPaneInsideSelectedCategoryWithoutCreatingCategory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-category-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let workspace = WorkspaceModel(localDirectoryPath: directoryURL.path, name: "demo")
        let initialCategoryCount = workspace.tabs.count
        let initialCategoryID = try XCTUnwrap(workspace.activeTabID)
        let initialPaneCount = workspace.paneOrder.count

        workspace.createPane(splitAxis: .vertical)

        XCTAssertEqual(workspace.tabs.count, initialCategoryCount)
        XCTAssertEqual(workspace.activeTabID, initialCategoryID)
        XCTAssertEqual(workspace.paneOrder.count, initialPaneCount + 1)
        XCTAssertEqual(workspace.paneCount(for: initialCategoryID), initialPaneCount + 1)
    }
```

- [ ] **Step 2: Run tests and verify the category source tests fail**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: `testTerminalChromeUsesCategoriesInsteadOfPaneChips` and `testTerminalChromeExposesInlineCategoryRename` fail because `TerminalChromeCategoryDescriptor`, category callbacks, and rename state do not exist yet. The split regression test may already pass; keep it as a guard for the accepted behavior.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/WorkspaceTabsTests.swift
git commit -m "test: define terminal category chrome behavior"
```

---

### Task 2: Replace Pane Chips With Category Descriptors

**Files:**
- Modify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Modify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Test: `Tests/WorkspaceTabsTests.swift`

- [ ] **Step 1: Update the chrome descriptor and inputs**

In `Argo/UI/Workspace/TerminalLocalChrome.swift`, replace `TerminalChromePaneDescriptor` with:

```swift
struct TerminalChromeCategoryDescriptor: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isSelected: Bool
    let canClose: Bool
}
```

Then replace the stored properties at the top of `TerminalLocalChrome` with:

```swift
    let path: String
    let categories: [TerminalChromeCategoryDescriptor]
    let activeCategoryID: UUID?
    let isFocused: Bool
    let canCreateCategory: Bool
    let canSplit: Bool
    let onSelectCategory: (UUID) -> Void
    let onCloseCategory: (UUID) -> Void
    let onRenameCategory: (UUID, String) -> Void
    let onCreateCategory: () -> Void
    let onSplitRight: () -> Void
    let onSplitDown: () -> Void

    @FocusState private var isRenameFieldFocused: Bool
    @State private var editingCategoryID: UUID?
    @State private var renameDraft = ""
```

- [ ] **Step 2: Replace the top chrome body**

In `TerminalLocalChrome`, replace `body` with:

```swift
    var body: some View {
        HStack(spacing: 12) {
            categoryArea

            HStack(spacing: 5) {
                TransparentPaneActionButton(
                    systemName: "plus",
                    isDisabled: !canCreateCategory,
                    accessibilityLabel: localized("terminal.category.new"),
                    help: localized("terminal.category.new"),
                    action: onCreateCategory
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.2x1",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitRight"),
                    help: localized("menu.file.splitRight"),
                    action: onSplitRight
                )

                TransparentPaneActionButton(
                    systemName: "rectangle.split.1x2",
                    isDisabled: !canSplit,
                    accessibilityLabel: localized("menu.file.splitDown"),
                    help: localized("menu.file.splitDown"),
                    action: onSplitDown
                )
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: activeCategoryID) { _, _ in
            cancelRename()
        }
    }
```

- [ ] **Step 3: Replace tab/pane chip rendering with category rendering**

Delete `tabArea`, `combinedTabAndPaneStrip`, `terminalTabStrip`, `paneChipStrip`, `pathPill`, `TerminalChromePaneChip`, and `TerminalChromeTabButton`.

Add this code inside `TerminalLocalChrome` after `body`:

```swift
    @ViewBuilder
    private var categoryArea: some View {
        if categories.isEmpty {
            fallbackCategoryPill
        } else {
            categoryStrip
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    if editingCategoryID == category.id {
                        renameField(for: category)
                    } else {
                        TerminalChromeCategoryPill(
                            category: category,
                            isFocused: isFocused && category.isSelected,
                            onSelect: {
                                onSelectCategory(category.id)
                            },
                            onRename: {
                                beginRename(category)
                            },
                            onClose: {
                                onCloseCategory(category.id)
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var fallbackCategoryPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(path)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1)))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(pathFill(isSelected: true), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.235), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
        .layoutPriority(1)
    }

    private func renameField(for category: TerminalChromeCategoryDescriptor) -> some View {
        TextField("", text: $renameDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.96))
            .focused($isRenameFieldFocused)
            .onSubmit {
                commitRename()
            }
            .onExitCommand {
                cancelRename()
            }
            .frame(width: 220, height: 32)
            .padding(.horizontal, 12)
            .background(pathFill(isSelected: true), in: Capsule())
            .overlay(Capsule().stroke(ArgoTheme.accent.opacity(0.42), lineWidth: 1))
            .onAppear {
                renameDraft = category.title
                DispatchQueue.main.async {
                    isRenameFieldFocused = true
                }
            }
    }

    private func beginRename(_ category: TerminalChromeCategoryDescriptor) {
        renameDraft = category.title
        editingCategoryID = category.id
        DispatchQueue.main.async {
            isRenameFieldFocused = true
        }
    }

    private func commitRename() {
        guard let editingCategoryID else {
            cancelRename()
            return
        }
        let normalized = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            onRenameCategory(editingCategoryID, normalized)
        }
        cancelRename()
    }

    private func cancelRename() {
        editingCategoryID = nil
        renameDraft = ""
        isRenameFieldFocused = false
    }

    private func pathFill(isSelected: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isSelected ? (isFocused ? 0.255 : 0.205) : 0.12),
                Color.white.opacity(isSelected ? (isFocused ? 0.145 : 0.105) : 0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
```

Add this private view below `TerminalLocalChrome`:

```swift
private struct TerminalChromeCategoryPill: View {
    let category: TerminalChromeCategoryDescriptor
    let isFocused: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(category.isSelected ? 0.72 : 0.46))

            Text(category.title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if category.isSelected {
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(isHovered ? 0.76 : 0.48))
                .help(LocalizationManager.shared.string("terminal.category.rename"))
            }

            if category.canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(closeOpacity))
                .background(Color.white.opacity(isCloseHovered ? 0.14 : 0.06), in: Circle())
                .onHover { hovering in
                    isCloseHovered = hovering
                }
                .help(LocalizationManager.shared.string("terminal.category.close"))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: category.isSelected ? 250 : 180, height: 32)
        .contentShape(Capsule())
        .background(backgroundFill, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: category.isSelected ? 1 : 0.8))
        .shadow(color: .black.opacity(category.isSelected ? 0.07 : 0), radius: 8, y: 3)
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onRename)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(category.title)
    }

    private var foreground: Color {
        if category.isSelected {
            return Color(nsColor: NSColor(calibratedRed: 0.968, green: 0.976, blue: 0.988, alpha: 1))
        }
        return Color.white.opacity(isHovered ? 0.70 : 0.46)
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(category.isSelected ? (isFocused ? 0.255 : 0.205) : (isHovered ? 0.09 : 0.0)),
                Color.white.opacity(category.isSelected ? (isFocused ? 0.145 : 0.105) : (isHovered ? 0.045 : 0.0))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        if category.isSelected {
            return Color.white.opacity(0.235)
        }
        return Color.white.opacity(isHovered ? 0.10 : 0.0)
    }

    private var closeOpacity: Double {
        if isCloseHovered {
            return 0.92
        }
        if isHovered || category.isSelected {
            return 0.68
        }
        return 0.42
    }
}
```

- [ ] **Step 4: Update the workspace detail call site**

In `Argo/UI/Workspace/WorkspaceDetailView.swift`, replace the `TerminalLocalChrome` call arguments with:

```swift
                    TerminalLocalChrome(
                        path: terminalChromePath,
                        categories: terminalChromeCategoryDescriptors,
                        activeCategoryID: workspace.activeTabID,
                        isFocused: terminalChromeTargetPaneID == workspace.sessionController.focusedPaneID,
                        canCreateCategory: true,
                        canSplit: terminalChromeTargetPaneID != nil,
                        onSelectCategory: selectTerminalCategoryFromChrome,
                        onCloseCategory: closeTerminalCategoryFromChrome,
                        onRenameCategory: renameTerminalCategoryFromChrome,
                        onCreateCategory: createTerminalCategoryFromChrome,
                        onSplitRight: {
                            splitTerminalFromChrome(axis: .vertical)
                        },
                        onSplitDown: {
                            splitTerminalFromChrome(axis: .horizontal)
                        }
                    )
```

Delete `terminalChromePaneDescriptors` and `focusTerminalPaneFromChrome`.

Add this computed property below `shouldDimInactiveTerminalPanes`:

```swift
    private var terminalChromeCategoryDescriptors: [TerminalChromeCategoryDescriptor] {
        workspace.tabs.map { tab in
            TerminalChromeCategoryDescriptor(
                id: tab.id,
                title: terminalChromeCategoryTitle(for: tab),
                isSelected: tab.id == workspace.activeTabID,
                canClose: workspace.tabs.count > 1
            )
        }
    }
```

Add this helper below it:

```swift
    private func terminalChromeCategoryTitle(for tab: WorkspaceTabStateRecord) -> String {
        if tab.isManuallyNamed {
            return tab.title
        }
        if tab.id == workspace.activeTabID {
            return terminalChromePath
        }
        let focusedPane = tab.focusedPaneID.flatMap { focusedPaneID in
            tab.panes.first { $0.id == focusedPaneID }
        }
        let pane = focusedPane ?? tab.panes.first
        return (pane?.preferredWorkingDirectory ?? workspace.activeWorktreePath)
            .terminalChromeDisplayPath
    }
```

Replace the old tab action functions with:

```swift
    private func createTerminalCategoryFromChrome() {
        if let terminalChromeTargetPaneID {
            workspace.focusPane(terminalChromeTargetPaneID)
        }
        store.createTab(in: workspace)
    }

    private func selectTerminalCategoryFromChrome(_ categoryID: UUID) {
        store.selectTab(in: workspace, tabID: categoryID)
    }

    private func closeTerminalCategoryFromChrome(_ categoryID: UUID) {
        store.closeTab(in: workspace, tabID: categoryID)
    }

    private func renameTerminalCategoryFromChrome(_ categoryID: UUID, title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        store.renameTab(in: workspace, tabID: categoryID, title: normalized)
    }
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  test
```

Expected: all `WorkspaceTabsTests` pass.

- [ ] **Step 6: Commit category chrome implementation**

```bash
git add Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/WorkspaceDetailView.swift Tests/WorkspaceTabsTests.swift
git commit -m "fix: render terminal categories above panes"
```

---

### Task 3: Add Category-Specific Localization

**Files:**
- Modify: `Argo/Support/L10n.swift`
- Test: `Tests/WorkspaceStoreTests.swift`

- [ ] **Step 1: Add localization regression checks**

In `Tests/WorkspaceStoreTests.swift`, append these assertions to `testModelDisplayStringsLocalizeForSimplifiedChinese()` after the existing `WorkspaceTabStateRecord.makeDefault` assertion:

```swift
        XCTAssertEqual(L10nTable.string(for: "terminal.category.new", language: .english), "New Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.rename", language: .english), "Rename Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.close", language: .english), "Close Category")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.new", language: .simplifiedChinese), "新建分类")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.rename", language: .simplifiedChinese), "重命名分类")
        XCTAssertEqual(L10nTable.string(for: "terminal.category.close", language: .simplifiedChinese), "关闭分类")
```

- [ ] **Step 2: Run the localization test and verify it fails**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testModelDisplayStringsLocalizeForSimplifiedChinese \
  test
```

Expected: the test fails because the `terminal.category.*` keys are not in `L10n.swift`.

- [ ] **Step 3: Add English strings**

In the English dictionary in `Argo/Support/L10n.swift`, near the existing `terminal.menu.*` keys, add:

```swift
        "terminal.category.new": "New Category",
        "terminal.category.rename": "Rename Category",
        "terminal.category.close": "Close Category",
```

- [ ] **Step 4: Add Simplified Chinese strings**

In the Simplified Chinese dictionary in `Argo/Support/L10n.swift`, near the existing `terminal.menu.*` keys, add:

```swift
        "terminal.category.new": "新建分类",
        "terminal.category.rename": "重命名分类",
        "terminal.category.close": "关闭分类",
```

- [ ] **Step 5: Run the localization test**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceStoreTests/testModelDisplayStringsLocalizeForSimplifiedChinese \
  test
```

Expected: PASS.

- [ ] **Step 6: Commit localization**

```bash
git add Argo/Support/L10n.swift Tests/WorkspaceStoreTests.swift
git commit -m "chore: localize terminal category labels"
```

---

### Task 4: Final Verification

**Files:**
- Verify: `Argo/UI/Workspace/TerminalLocalChrome.swift`
- Verify: `Argo/UI/Workspace/WorkspaceDetailView.swift`
- Verify: `Tests/WorkspaceTabsTests.swift`
- Verify: `Tests/WorkspaceStoreTests.swift`

- [ ] **Step 1: Run focused terminal/category tests**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/WorkspaceTabsTests \
  -only-testing:ArgoTests/WorkspaceStoreTests/testModelDisplayStringsLocalizeForSimplifiedChinese \
  test
```

Expected: PASS.

- [ ] **Step 2: Run a Debug build**

Run:

```bash
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke test**

Launch the built app from Xcode or the existing local app workflow, then verify:

1. Open a workspace.
2. Confirm the top chrome shows only category pills.
3. Press Command+D and confirm the top category pills do not increase; only the pane grid changes.
4. Click the `+` button and confirm a new top category appears with one pane.
5. Rename the selected category with the pencil affordance and press Return.
6. Switch categories and confirm each category keeps its own pane layout.

- [ ] **Step 4: Commit verification notes if code changed during verification**

If verification requires code or test changes, commit them:

```bash
git add Argo/UI/Workspace/TerminalLocalChrome.swift Argo/UI/Workspace/WorkspaceDetailView.swift Argo/Support/L10n.swift Tests/WorkspaceTabsTests.swift Tests/WorkspaceStoreTests.swift
git commit -m "fix: polish terminal category verification"
```

If no files changed during verification, do not create an empty commit.
