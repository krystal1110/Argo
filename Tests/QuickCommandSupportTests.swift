//
//  QuickCommandSupportTests.swift
//  ArgoTests
//
//  Author: krystal
//

import Carbon
import XCTest
@testable import Argo

final class QuickCommandSupportTests: XCTestCase {
    func testLegacySettingsDecodeDefaultsQuickCommands() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(settings.quickCommandPresets, QuickCommandCatalog.defaultCommands)
        XCTAssertEqual(settings.quickCommandCategories, QuickCommandCatalog.defaultCategories)
        XCTAssertTrue(settings.quickCommandRecentIDs.isEmpty)
        XCTAssertFalse(settings.hotKeyWindowEnabled)
        XCTAssertTrue(settings.confirmQuitWhenCommandsRunning)
        XCTAssertEqual(
            settings.hotKeyWindowShortcut,
            StoredShortcut(key: " ", command: false, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            QuickCommandCatalog.defaultCommands.first(where: { $0.id == "codex-resume" })?.command,
            "codex resume"
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .closeWindow, in: settings),
            StoredShortcut(key: "w", command: true, shift: true, option: false, control: false)
        )
    }

    func testLegacySettingsDecodeDefaultsAppLanguageToAutomatic() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(settings.appLanguage, .automatic)
    }

    func testLegacySettingsDecodeMigratesOldHotKeyWindowDefault() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("""
        {
          "hotKeyWindowShortcut": {
            "key": " ",
            "command": true,
            "shift": true,
            "option": false,
            "control": false
          }
        }
        """.utf8))

        XCTAssertEqual(
            settings.hotKeyWindowShortcut,
            StoredShortcut(key: " ", command: false, shift: false, option: true, control: false)
        )
    }

    func testSettingsEncodingPreservesAppLanguage() throws {
        let settings = AppSettings(appLanguage: .simplifiedChinese)

        let data = try JSONEncoder().encode(settings)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["appLanguage"] as? String, "simplifiedChinese")
    }

    func testSettingsEncodingPreservesHotKeyWindowFields() throws {
        let settings = AppSettings(
            confirmQuitWhenCommandsRunning: false,
            hotKeyWindowEnabled: true,
            hotKeyWindowShortcut: StoredShortcut(key: "k", command: true, shift: true, option: false, control: false)
        )

        let data = try JSONEncoder().encode(settings)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["hotKeyWindowEnabled"] as? Bool, true)
        XCTAssertEqual(object["confirmQuitWhenCommandsRunning"] as? Bool, false)

        let shortcut = try XCTUnwrap(object["hotKeyWindowShortcut"] as? [String: Any])
        XCTAssertEqual(shortcut["key"] as? String, "k")
        XCTAssertEqual(shortcut["command"] as? Bool, true)
        XCTAssertEqual(shortcut["shift"] as? Bool, true)
        XCTAssertEqual(shortcut["option"] as? Bool, false)
        XCTAssertEqual(shortcut["control"] as? Bool, false)
    }

    func testSettingsEncodeAndDecodePreserveUIScale() throws {
        let settings = AppSettings(uiScale: 1.25)

        let data = try JSONEncoder().encode(settings)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["uiScale"] as? Double, 1.25)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.uiScale, 1.25, accuracy: 0.001)
    }

    func testDebugBuildUsesSeparatePersistenceDirectoryName() {
        XCTAssertEqual(argoStateDirectoryName(isDebugBuild: true), ".argo-debug")
        XCTAssertEqual(argoStateDirectoryName(isDebugBuild: false), ".argo")
    }

    func testQuickCommandNormalizationTrimsAndDropsDuplicates() {
        let commands = [
            QuickCommandPreset(
                id: "dup",
                title: "  ",
                command: "  ls -la  ",
                categoryID: QuickCommandCategory.linux.id
            ),
            QuickCommandPreset(
                id: "dup",
                title: "Other",
                command: "pwd",
                categoryID: QuickCommandCategory.linux.id
            ),
            QuickCommandPreset(
                id: "empty",
                title: "Empty",
                command: "   ",
                categoryID: QuickCommandCategory.codex.id
            ),
        ]

        let normalized = QuickCommandCatalog.normalizedCommands(commands)

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized[0].id, "dup")
        XCTAssertEqual(normalized[0].title, "ls -la")
        XCTAssertEqual(normalized[0].command, "ls -la")
    }

    func testQuickCommandNormalizationClearsConflictingShortcuts() {
        let reservedShortcut = StoredShortcut(key: "p", command: true, shift: false, option: false, control: false)
        let commands = [
            QuickCommandPreset(
                id: "first",
                title: "First",
                command: "echo first",
                categoryID: QuickCommandCategory.linux.id,
                shortcut: reservedShortcut
            ),
            QuickCommandPreset(
                id: "second",
                title: "Second",
                command: "echo second",
                categoryID: QuickCommandCategory.linux.id,
                shortcut: StoredShortcut(key: "k", command: true, shift: false, option: false, control: false)
            ),
            QuickCommandPreset(
                id: "third",
                title: "Third",
                command: "echo third",
                categoryID: QuickCommandCategory.linux.id,
                shortcut: StoredShortcut(key: "k", command: true, shift: false, option: false, control: false)
            ),
        ]

        let normalized = QuickCommandCatalog.normalizedCommands(commands, reservedShortcuts: Set([reservedShortcut]))

        XCTAssertNil(normalized[0].shortcut)
        XCTAssertEqual(normalized[1].shortcut, StoredShortcut(key: "k", command: true, shift: false, option: false, control: false))
        XCTAssertNil(normalized[2].shortcut)
    }

    func testQuickCommandShortcutMatchReturnsPreset() {
        let shortcut = StoredShortcut(key: "k", command: true, shift: true, option: false, control: false)
        let settings = AppSettings(
            quickCommandPresets: [
                QuickCommandPreset(
                    id: "deploy",
                    title: "Deploy",
                    command: "deploy-now",
                    categoryID: QuickCommandCategory.cloud.id,
                    shortcut: shortcut,
                    submitsReturn: true
                )
            ]
        )

        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .shift],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "K",
                charactersIgnoringModifiers: "k",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_K)
            )
        )

        let match = argoQuickCommandMatch(for: event, in: settings)
        XCTAssertEqual(match?.id, "deploy")
        XCTAssertEqual(match?.submitsReturn, true)
    }

    func testQuickCommandDispatchUsesRunOnlyWhenAutoReturnIsEnabled() {
        let insertPreset = QuickCommandPreset(
            id: "insert",
            title: "Insert",
            command: "codex",
            categoryID: QuickCommandCategory.codex.id,
            submitsReturn: false
        )
        let runPreset = QuickCommandPreset(
            id: "run",
            title: "Run",
            command: "codex",
            categoryID: QuickCommandCategory.codex.id,
            submitsReturn: true
        )

        XCTAssertEqual(argoQuickCommandDispatch(for: insertPreset), .insert("codex"))
        XCTAssertEqual(argoQuickCommandDispatch(for: runPreset), .run("codex"))
    }

    func testSettingsEncodingPreservesQuickCommandShortcutAndAutoReturn() throws {
        let settings = AppSettings(
            quickCommandPresets: [
                QuickCommandPreset(
                    id: "run-tests",
                    title: "Run Tests",
                    command: "swift test",
                    categoryID: QuickCommandCategory.codex.id,
                    shortcut: StoredShortcut(key: "t", command: true, shift: true, option: false, control: false),
                    submitsReturn: true
                )
            ]
        )

        let data = try JSONEncoder().encode(settings)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let presets = try XCTUnwrap(object["quickCommandPresets"] as? [[String: Any]])
        let shortcut = try XCTUnwrap(presets.first?["shortcut"] as? [String: Any])

        XCTAssertEqual(shortcut["key"] as? String, "t")
        XCTAssertEqual(shortcut["command"] as? Bool, true)
        XCTAssertEqual(shortcut["shift"] as? Bool, true)
        XCTAssertEqual(presets.first?["submitsReturn"] as? Bool, true)
    }

    func testRecentQuickCommandsArePrunedAndDeduplicated() {
        let commands = [
            QuickCommandPreset(id: "a", title: "A", command: "a", categoryID: QuickCommandCategory.codex.id),
            QuickCommandPreset(id: "b", title: "B", command: "b", categoryID: QuickCommandCategory.cloud.id),
        ]

        let normalized = QuickCommandCatalog.normalizedRecentCommandIDs(
            ["missing", "a", "a", "b", "c"],
            availableCommands: commands
        )

        XCTAssertEqual(normalized, ["a", "b"])
    }

    func testQuickCommandPresetDecodesLegacyCategoryString() throws {
        let preset = try JSONDecoder().decode(
            QuickCommandPreset.self,
            from: Data(#"{"id":"legacy","title":"Legacy","command":"ls","category":"linux"}"#.utf8)
        )

        XCTAssertEqual(preset.categoryID, QuickCommandCategory.linux.id)
    }

    func testQuickCommandCategoryDecodesLegacyStringValue() throws {
        let category = try JSONDecoder().decode(
            QuickCommandCategory.self,
            from: Data(#""cloud""#.utf8)
        )

        XCTAssertEqual(category, .cloud)
    }

    func testQuickCommandCategoriesNormalizeByKeepingBuiltInsAndCustomCategories() {
        let custom = QuickCommandCategory(id: "custom-tools", title: "Tools", symbolName: "tag")

        let normalized = QuickCommandCatalog.normalizedCategories([custom, .linux])

        XCTAssertTrue(normalized.contains(.linux))
        XCTAssertTrue(normalized.contains(custom))
        XCTAssertEqual(normalized.first, .general)
    }

    func testQuickCommandNormalizationFallsBackWhenCategoryIsMissing() {
        let normalized = QuickCommandCatalog.normalizedCommands(
            [
                QuickCommandPreset(
                    id: "custom",
                    title: "Custom",
                    command: "echo hi",
                    categoryID: "missing"
                )
            ],
            categories: QuickCommandCatalog.defaultCategories
        )

        XCTAssertEqual(normalized.first?.categoryID, QuickCommandCategory.general.id)
    }

    func testReplacingQuickCommandClearsConflictingShortcutFromPreviousCommand() {
        let shortcut = StoredShortcut(key: "k", command: true, shift: true, option: false, control: false)
        let codex = QuickCommandPreset(
            id: "codex",
            title: "Codex",
            command: "codex",
            categoryID: QuickCommandCategory.codex.id,
            shortcut: shortcut
        )
        let claude = QuickCommandPreset(
            id: "claude",
            title: "Claude",
            command: "claude",
            categoryID: QuickCommandCategory.claude.id
        )

        var updatedClaude = claude
        updatedClaude.shortcut = shortcut

        let replaced = QuickCommandCatalog.replacingCommand(updatedClaude, in: [codex, claude])

        XCTAssertNil(replaced.first(where: { $0.id == "codex" })?.shortcut)
        XCTAssertEqual(replaced.first(where: { $0.id == "claude" })?.shortcut, shortcut)
    }

    func testPredefinedQuickCommandLibraryContainsLargeCuratedCatalog() {
        XCTAssertEqual(QuickCommandCatalog.predefinedCommands.count, 175)
        XCTAssertEqual(QuickCommandCatalog.predefinedCommandCount, QuickCommandCatalog.predefinedCommands.count)
        XCTAssertTrue(QuickCommandCatalog.defaultCategories.contains(.complex))

        let complexCommands = QuickCommandCatalog.predefinedCommands.filter {
            $0.categoryID == QuickCommandCategory.complex.id
        }
        XCTAssertGreaterThanOrEqual(complexCommands.count, 60)
    }

    func testPredefinedQuickCommandLibraryOmitsGitCategoryAndCommands() {
        XCTAssertFalse(QuickCommandCatalog.defaultCategories.contains { $0.id == "git" })
        XCTAssertFalse(QuickCommandCatalog.normalizedCategories([
            QuickCommandCategory(id: "git", title: "Git", symbolName: "tag")
        ]).contains { $0.id == "git" })
        XCTAssertFalse(QuickCommandCatalog.predefinedCommands.contains { $0.categoryID == "git" })
        XCTAssertFalse(QuickCommandCatalog.predefinedCommands.contains {
            $0.normalizedCommand == "git" || $0.normalizedCommand.hasPrefix("git ")
        })
    }

    func testShortcutActionsDoNotExposeGitReviewWindows() {
        let actionIDs = ArgoShortcutAction.allCases.map(\.rawValue)

        XCTAssertFalse(actionIDs.contains("openDiff"))
        XCTAssertFalse(actionIDs.contains("openHistory"))
    }

    func testCommandPaletteShortcutDefaultsToCommandShiftP() {
        let settings = AppSettings()

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in: settings),
            StoredShortcut(key: "p", command: true, shift: true, option: false, control: false)
        )
    }

    func testMainWindowDoesNotExposeMoreActionsMenu() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("ellipsis.circle"))
        XCTAssertFalse(source.contains("main.menu.moreActions"))
    }

    func testTopChromeUsesInsetToolbarSurfaces() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controlsSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Components/GlassChromeControls.swift"),
            encoding: .utf8
        )
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(controlsSource.contains("InsetToolbarCapsuleSurface"))
        XCTAssertTrue(controlsSource.contains("fillOpacity: Double = 0.12"))
        XCTAssertTrue(controlsSource.contains("glassHighlightOpacity: Double = 0.05"))
        XCTAssertTrue(controlsSource.contains("topShadowOpacity: Double = 0.2"))
        XCTAssertTrue(mainWindowSource.contains(".insetToolbarCapsuleSurface()"))
        XCTAssertTrue(mainWindowSource.contains(".fill(.ultraThinMaterial)"))
        XCTAssertTrue(mainWindowSource.contains("ArgoTheme.chromeBackground.opacity(0.68)"))
        XCTAssertFalse(controlsSource.contains(".shadow(color: .black.opacity(0.18), radius: 12, y: 6)"))
    }

    func testMainWindowWrapsWorkspaceSidebarInFloatingSurface() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mainWindowSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )
        let sidebarSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Sidebar/WorkspaceSidebarView.swift"),
            encoding: .utf8
        )
        let floatingSidebarPattern = #"FloatingWorkspaceSidebarSurface\s*\{\s*WorkspaceSidebarView\(\)\s*\}\s*\.navigationSplitViewColumnWidth\(min: 210, ideal: 260, max: 340\)"#

        XCTAssertNotNil(
            mainWindowSource.range(of: floatingSidebarPattern, options: .regularExpression),
            "WorkspaceSidebarView should be wrapped by the floating surface at the NavigationSplitView boundary."
        )
        XCTAssertTrue(mainWindowSource.contains("struct FloatingWorkspaceSidebarSurface<Content: View>: View"))
        XCTAssertTrue(mainWindowSource.contains("RoundedRectangle(cornerRadius: 8, style: .continuous)"))
        XCTAssertTrue(mainWindowSource.contains(".background(ArgoTheme.sidebarBackground, in: panelShape)"))
        XCTAssertTrue(mainWindowSource.contains(".padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))"))
        XCTAssertTrue(mainWindowSource.contains(".shadow(color: .black.opacity(0.28), radius: 22, x: 14, y: 1)"))
        XCTAssertFalse(
            sidebarSource.contains("FloatingWorkspaceSidebarSurface"),
            "The existing sidebar contents should not own the floating shell."
        )

        let fullSidebarBackgroundCount = sidebarSource
            .components(separatedBy: ".background(ArgoTheme.sidebarBackground)")
            .count - 1
        XCTAssertEqual(
            fullSidebarBackgroundCount,
            0,
            "WorkspaceSidebarView should let FloatingWorkspaceSidebarSurface own the full-panel background."
        )

        XCTAssertTrue(sidebarSource.contains("let outlineView = SidebarOutlineView()"))
        XCTAssertTrue(sidebarSource.contains("private final class SidebarOutlineContainerView: NSView"))
    }

    func testSleepPreventionToolbarMainButtonOpensDurationMenu() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/MainWindowView.swift"),
            encoding: .utf8
        )
        let menuButtonPattern = #"GlassToolbarMenuIconButton\(\s*systemName: sleepPreventionIconName,[\s\S]*?\)\s*\{\s*anchorView in\s*present\(menu: makeSleepPreventionMenu\(\), from: anchorView\)\s*\}"#

        XCTAssertNotNil(
            source.range(of: menuButtonPattern, options: .regularExpression),
            "The visible sleep prevention toolbar button should open the duration menu."
        )
    }

    func testRemovedSessionAndLayoutActionsDoNotLocalize() {
        let removedKeys = [
            "main.menu.restartFocusedSession",
            "main.menu.restartAllSessions",
            "main.menu.resetLayout",
            "main.menu.moreActions",
        ]

        for key in removedKeys {
            XCTAssertEqual(L10nTable.string(for: key, language: .english), key)
            XCTAssertEqual(L10nTable.string(for: key, language: .simplifiedChinese), key)
        }
    }

    func testRecommendedComplexSubsetResolvesToExistingComplexCommands() throws {
        let allCommandsByID = Dictionary(uniqueKeysWithValues: QuickCommandCatalog.predefinedCommands.map { ($0.id, $0) })

        XCTAssertEqual(QuickCommandCatalog.recommendedComplexCommandIDs.count, 11)

        for id in QuickCommandCatalog.recommendedComplexCommandIDs {
            let command = try XCTUnwrap(allCommandsByID[id])
            XCTAssertEqual(command.categoryID, QuickCommandCategory.complex.id)
        }
    }

    func testShortcutAssignmentDisablesConflictingAction() {
        var settings = AppSettings()
        let shortcut = StoredShortcut(key: "p", command: true, shift: true, option: false, control: false)

        ArgoKeyboardShortcuts.setShortcut(shortcut, for: .toggleOverview, in: &settings)

        XCTAssertEqual(ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleOverview, in: settings), shortcut)
        XCTAssertNil(ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in: settings))
        XCTAssertEqual(ArgoKeyboardShortcuts.state(for: .toggleCommandPalette, in: settings), .disabled)
    }

    func testCommandPDoesNotMatchCommandPaletteByDefault() {
        let settings = AppSettings()
        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "p",
                charactersIgnoringModifiers: "p",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_P)
            )
        )

        XCTAssertNil(argoShortcutMatch(for: event, in: settings))
    }

    func testCommandShiftPMatchesCommandPaletteByDefault() {
        let settings = AppSettings()
        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .shift],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "P",
                charactersIgnoringModifiers: "p",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_P)
            )
        )

        XCTAssertEqual(
            argoShortcutMatch(for: event, in: settings),
            ArgoShortcutMatch(action: .toggleCommandPalette, tabNumber: nil)
        )
    }

    func testShortcutResetRestoresDefaultBinding() {
        var settings = AppSettings()

        ArgoKeyboardShortcuts.disableShortcut(for: .closePane, in: &settings)
        XCTAssertNil(ArgoKeyboardShortcuts.effectiveShortcut(for: .closePane, in: settings))

        ArgoKeyboardShortcuts.resetShortcut(for: .closePane, in: &settings)

        // closePane has no default shortcut (Cmd+W handles smart close via closeTab)
        XCTAssertNil(ArgoKeyboardShortcuts.effectiveShortcut(for: .closePane, in: settings))
    }

    func testNumberedTabShortcutNormalizesToDigitTemplate() {
        var settings = AppSettings()
        let shortcut = StoredShortcut(key: "7", command: true, shift: false, option: false, control: false)

        ArgoKeyboardShortcuts.setShortcut(shortcut, for: .selectTabByNumber, in: &settings)

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .selectTabByNumber, in: settings),
            StoredShortcut(key: "1", command: true, shift: false, option: false, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.displayString(for: .selectTabByNumber, in: settings),
            "⌘1…9"
        )
    }

    func testStoredShortcutComputesCarbonHotKeyValues() {
        let shortcut = StoredShortcut(key: " ", command: false, shift: true, option: true, control: false)

        XCTAssertEqual(shortcut.carbonKeyCode, UInt32(kVK_Space))
        XCTAssertEqual(shortcut.carbonModifierFlags, UInt32(optionKey | shiftKey))
    }

    func testPaneFocusShortcutsDefaultToCommandOptionArrows() {
        let settings = AppSettings()

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .focusPaneLeft, in: settings),
            StoredShortcut(key: "←", command: true, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .focusPaneRight, in: settings),
            StoredShortcut(key: "→", command: true, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .focusPaneUp, in: settings),
            StoredShortcut(key: "↑", command: true, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .focusPaneDown, in: settings),
            StoredShortcut(key: "↓", command: true, shift: false, option: true, control: false)
        )
    }

    func testTabNavigationShortcutsUseControlTabVariants() {
        let settings = AppSettings()

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .nextTab, in: settings),
            StoredShortcut(key: "\t", command: false, shift: false, option: false, control: true)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .previousTab, in: settings),
            StoredShortcut(key: "\t", command: false, shift: true, option: false, control: true)
        )
    }

    func testPaneShortcutsUseNewDefaults() {
        let settings = AppSettings()

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .duplicatePane, in: settings),
            StoredShortcut(key: "d", command: true, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .togglePaneZoom, in: settings),
            StoredShortcut(key: "\r", command: true, shift: true, option: false, control: false)
        )
    }

    func testStandardMenuShortcutsUseConfigurableDefaults() {
        let settings = AppSettings()

        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .hideApp, in: settings),
            StoredShortcut(key: "h", command: true, shift: false, option: false, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .hideOtherApps, in: settings),
            StoredShortcut(key: "h", command: true, shift: false, option: true, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .quitApp, in: settings),
            StoredShortcut(key: "q", command: true, shift: false, option: false, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .copy, in: settings),
            StoredShortcut(key: "c", command: true, shift: false, option: false, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .findPrevious, in: settings),
            StoredShortcut(key: "g", command: true, shift: true, option: false, control: false)
        )
        XCTAssertEqual(
            ArgoKeyboardShortcuts.effectiveShortcut(for: .minimizeWindow, in: settings),
            StoredShortcut(key: "m", command: true, shift: false, option: false, control: false)
        )
    }

    func testShortcutMatchingSupportsArrowKeys() {
        let settings = AppSettings()

        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .option],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "\u{F702}",
                charactersIgnoringModifiers: "\u{F702}",
                isARepeat: false,
                keyCode: UInt16(kVK_LeftArrow)
            )
        )

        XCTAssertEqual(
            argoShortcutMatch(for: event, in: settings),
            ArgoShortcutMatch(action: .focusPaneLeft, tabNumber: nil)
        )
    }

    func testShortcutMatchingUsesStoredKeyForOptionModifiedLetters() {
        var settings = AppSettings()
        let shortcut = StoredShortcut(key: "d", command: false, shift: false, option: true, control: false)
        ArgoKeyboardShortcuts.setShortcut(shortcut, for: .splitRight, in: &settings)

        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.option],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "\u{2202}",
                charactersIgnoringModifiers: "d",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_D)
            )
        )

        XCTAssertEqual(
            argoShortcutMatch(for: event, in: settings),
            ArgoShortcutMatch(action: .splitRight, tabNumber: nil)
        )
    }

    func testShortcutMatchingSupportsControlTab() {
        let settings = AppSettings()

        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.control],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "\t",
                charactersIgnoringModifiers: "\t",
                isARepeat: false,
                keyCode: UInt16(kVK_Tab)
            )
        )

        XCTAssertEqual(
            argoShortcutMatch(for: event, in: settings),
            ArgoShortcutMatch(action: .nextTab, tabNumber: nil)
        )
    }

    func testShortcutMatchingSupportsCommandShiftReturn() {
        let settings = AppSettings()

        let event = try! XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .shift],
                timestamp: 1,
                windowNumber: 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: UInt16(kVK_Return)
            )
        )

        XCTAssertEqual(
            argoShortcutMatch(for: event, in: settings),
            ArgoShortcutMatch(action: .togglePaneZoom, tabNumber: nil)
        )
    }

    func testHotKeyWindowKeepsAppRunningWhenLastWindowCloses() {
        XCTAssertFalse(argoShouldTerminateAfterLastWindowClosed(hotKeyWindowEnabled: true, isRunningTests: false))
    }

    func testHotKeyWindowPresentationKeepsNormalWindowLevelWhenEnabled() {
        let baseBehavior: NSWindow.CollectionBehavior = [.managed]
        let presentation = argoWindowPresentation(
            hotKeyWindowEnabled: true,
            isPrimaryWorkspaceWindow: true,
            baseLevel: .normal,
            baseCollectionBehavior: baseBehavior
        )

        XCTAssertEqual(presentation.level, .normal)
        XCTAssertTrue(presentation.collectionBehavior.contains(.managed))
        XCTAssertTrue(presentation.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertTrue(presentation.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    func testStandardWindowModeTerminatesAfterLastWindowCloses() {
        XCTAssertTrue(argoShouldTerminateAfterLastWindowClosed(hotKeyWindowEnabled: false, isRunningTests: false))
    }

    func testRunningTestsKeepsAppAliveAfterLastWindowCloses() {
        XCTAssertFalse(argoShouldTerminateAfterLastWindowClosed(hotKeyWindowEnabled: false, isRunningTests: true))
    }

    func testLastWindowCloseInterceptsTerminationWhenQuitNeedsConfirmation() {
        XCTAssertTrue(
            argoShouldInterceptLastWindowCloseForTermination(
                hotKeyWindowEnabled: false,
                openWindowCount: 1,
                needsConfirmQuit: true
            )
        )
        XCTAssertFalse(
            argoShouldInterceptLastWindowCloseForTermination(
                hotKeyWindowEnabled: false,
                openWindowCount: 2,
                needsConfirmQuit: true
            )
        )
        XCTAssertFalse(
            argoShouldInterceptLastWindowCloseForTermination(
                hotKeyWindowEnabled: true,
                openWindowCount: 1,
                needsConfirmQuit: true
            )
        )
        XCTAssertFalse(
            argoShouldInterceptLastWindowCloseForTermination(
                hotKeyWindowEnabled: false,
                openWindowCount: 1,
                needsConfirmQuit: false
            )
        )
    }

    func testDockReopenRestoresWindowWhenNoVisibleWindows() {
        XCTAssertTrue(argoShouldReopenMainWindow(hasVisibleWindows: false))
        XCTAssertFalse(argoShouldReopenMainWindow(hasVisibleWindows: true))
    }

    func testQuitConfirmationOnlyAppliesWhenEnabledAndCommandsNeedIt() {
        XCTAssertTrue(
            argoShouldConfirmTermination(
                confirmQuitWhenCommandsRunning: true,
                needsConfirmQuit: true
            )
        )
        XCTAssertFalse(
            argoShouldConfirmTermination(
                confirmQuitWhenCommandsRunning: false,
                needsConfirmQuit: true
            )
        )
        XCTAssertFalse(
            argoShouldConfirmTermination(
                confirmQuitWhenCommandsRunning: true,
                needsConfirmQuit: false
            )
        )
    }

    func testQuitConfirmationCopyUsesSingularAndPluralText() {
        LocalizationManager.shared.updateSelectedLanguage(.english)
        XCTAssertEqual(
            argoQuitConfirmationCopy(quitConfirmationSessionCount: 1).message,
            "1 terminal session still has a running command. Quitting now will stop it. You can turn this confirmation off in Settings > General."
        )
        XCTAssertEqual(
            argoQuitConfirmationCopy(quitConfirmationSessionCount: 3).message,
            "3 terminal sessions still have running commands. Quitting now will stop them. You can turn this confirmation off in Settings > General."
        )

        LocalizationManager.shared.updateSelectedLanguage(.simplifiedChinese)
        XCTAssertEqual(
            argoQuitConfirmationCopy(quitConfirmationSessionCount: 1).title,
            "要退出 Argo 吗？"
        )
        XCTAssertEqual(
            argoQuitConfirmationCopy(quitConfirmationSessionCount: 1).message,
            "仍有 1 个终端会话在运行命令。 现在退出会停止它。 你可以在“设置 > 通用”中关闭此确认。"
        )
        XCTAssertEqual(
            argoQuitConfirmationCopy(quitConfirmationSessionCount: 3).message,
            "仍有 3 个终端会话在运行命令。 现在退出会停止它们。 你可以在“设置 > 通用”中关闭此确认。"
        )

        LocalizationManager.shared.updateSelectedLanguage(.automatic)
    }

    func testGhosttyLogFilterSuppressesKnownGhosttySpamOnly() {
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("io_thread: mailbox message=start_synchronized_output"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("debug(io_thread): mailbox message=start_synchronized_output"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("reading configuration file path=/Users/eevv/Library/Application Support/com.mitchellh.ghostty/config"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("config: default shell source=env value=/bin/zsh"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("generic_renderer: updating display link display id=3"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("\n"))
        XCTAssertTrue(ArgoGhosttyLogFilter.shouldSuppress("   \n"))
        XCTAssertFalse(ArgoGhosttyLogFilter.shouldSuppress("io_thread: mailbox message=end_synchronized_output"))
        XCTAssertFalse(ArgoGhosttyLogFilter.shouldSuppress("warning(io_thread): error draining mailbox err=something"))
        XCTAssertFalse(ArgoGhosttyLogFilter.shouldSuppress("generic_renderer: fatal display link failure"))
    }
}
