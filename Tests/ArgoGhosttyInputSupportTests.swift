//
//  ArgoGhosttyInputSupportTests.swift
//  ArgoTests
//
//  Author: krystal
//

import AppKit
import Carbon
import GhosttyKit
import XCTest
@testable import Argo

final class ArgoGhosttyInputSupportTests: XCTestCase {
    private let returnKeyCode = UInt16(kVK_Return)
    private let keypadEnterKeyCode = UInt16(kVK_ANSI_KeypadEnter)

    func testShiftReturnUsesTextInputRouting() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: [.shift]
            )
        )
    }

    func testCommandReturnStillUsesRawKeyRouting() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: [.command]
            )
        )
    }

    func testOptionKeypadEnterStillUsesRawKeyRouting() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: keypadEnterKeyCode,
                modifierFlags: [.option]
            )
        )
    }

    func testOptionLeftArrowUsesRawKeyRouting() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option]
            )
        )
    }

    func testOptionDeleteUsesRawKeyRouting() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_Delete),
                modifierFlags: [.option]
            )
        )
    }

    func testOptionPrintableKeyStillUsesTextInputRouting() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_ANSI_B),
                modifierFlags: [.option]
            )
        )
    }

    func testSSHOptionLeftArrowUsesBackwardWordEscapeSequence() {
        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHOptionRightArrowUsesForwardWordEscapeSequence() {
        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_RightArrow),
                modifierFlags: [.option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}f"
        )
    }

    func testLocalOptionArrowUsesWordNavigationEscapeSequence() {
        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option],
                backendConfiguration: .local()
            ),
            "\u{1B}b"
        )
    }

    func testSSHCommandOptionArrowDoesNotUseSSHWordNavigationEscapeSequence() {
        XCTAssertNil(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.command, .option],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            )
        )
    }

    func testSSHOptionArrowAllowsAdditionalSystemModifierBits() {
        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: [.option, .numericPad],
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHLeftOptionArrowUsesBackwardWordEscapeSequenceWithRawAltBit() {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELALTKEYMASK))

        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_LeftArrow),
                modifierFlags: flags,
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}b"
        )
    }

    func testSSHRightOptionArrowUsesForwardWordEscapeSequenceWithRawAltBit() {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERALTKEYMASK))

        XCTAssertEqual(
            argoGhosttySSHWordNavigationEscapeSequence(
                keyCode: UInt16(kVK_RightArrow),
                modifierFlags: flags,
                backendConfiguration: .ssh(
                    SSHSessionConfiguration(
                        host: "example.com",
                        user: "dev",
                        port: nil,
                        identityFilePath: nil,
                        remoteWorkingDirectory: nil,
                        remoteCommand: nil
                    )
                )
            ),
            "\u{1B}f"
        )
    }

    func testPlainReturnDoesNotUseRawKeyRouting() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: returnKeyCode,
                modifierFlags: []
            )
        )
    }

    func testNonReturnKeyNeverUsesRawKeyRouting() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldPreferRawKeyEvent(
                keyCode: UInt16(kVK_ANSI_A),
                modifierFlags: [.command]
            )
        )
    }

    func testRawKeyDispatchStaysComposingWhileMarkedTextIsActive() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testRawKeyDispatchStaysComposingWhenMarkedTextWasJustCleared() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testRawKeyDispatchIsPlainOutsideComposition() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldMarkRawKeyEventAsComposing(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testImeMarkedTextUpdateSkipsRawFallback() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testImeMarkedTextClearSkipsRawFallback() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testImeMarkedTextUpdateSyncsPreedit() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: true
            )
        )
    }

    func testImeMarkedTextClearSyncsPreedit() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: true,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testPlainUnhandledKeyDoesNotSyncPreedit() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldSyncPreeditAfterTextInterpretation(
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testPlainUnhandledKeyStillUsesRawFallback() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldDispatchRawKeyFallbackAfterTextInterpretation(
                accumulatedText: "",
                handledTextInputCommand: false,
                hadMarkedTextBeforeInterpretation: false,
                hasMarkedTextAfterInterpretation: false
            )
        )
    }

    func testDeleteEventKeepsInsertedAsciiAsMarkedTextWhileComposing() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteEventKeepsInsertedCjkTextAsMarkedTextWhileComposing() {
        XCTAssertTrue(
            ArgoGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "你",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteEventWithoutMarkedTextDoesNotCreateMarkedText() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_Delete),
                hadMarkedTextBeforeDeletion: false
            )
        )
    }

    func testNonDeleteEventStillCommitsInsertedText() {
        XCTAssertFalse(
            ArgoGhosttyTextInputRouting.shouldTreatInsertedTextAsMarkedTextDuringDeletion(
                insertedText: "n",
                keyCode: UInt16(kVK_ANSI_N),
                hadMarkedTextBeforeDeletion: true
            )
        )
    }

    func testDeleteBackwardByDecomposingSelectorDeletesMarkedText() {
        XCTAssertEqual(
            ArgoGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.deleteBackwardByDecomposingPreviousCharacter(_:)),
                hasMarkedText: true
            ),
            .deleteBackwardInMarkedText
        )
    }

    func testCancelOperationClearsMarkedText() {
        XCTAssertEqual(
            ArgoGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.cancelOperation(_:)),
                hasMarkedText: true
            ),
            .cancelMarkedText
        )
    }

    func testCancelOperationWithoutMarkedTextFallsThrough() {
        XCTAssertEqual(
            ArgoGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.cancelOperation(_:)),
                hasMarkedText: false
            ),
            .none
        )
    }

    func testMoveWordLeftSelectorResolvesToBackwardWordCommand() {
        XCTAssertEqual(
            ArgoGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.moveWordLeft(_:)),
                hasMarkedText: false
            ),
            .moveBackwardWord
        )
    }

    func testMoveWordRightSelectorResolvesToForwardWordCommand() {
        XCTAssertEqual(
            ArgoGhosttyTextInputCommandAction.resolve(
                selector: #selector(NSResponder.moveWordRight(_:)),
                hasMarkedText: false
            ),
            .moveForwardWord
        )
    }

    func testImeDebugLoggingCanBeEnabledByEnvironment() {
        XCTAssertTrue(
            argoGhosttyShouldEnableIMEDebugLogging(environment: ["ARGO_DEBUG_IME": "1"])
        )
    }

    func testImeDebugLoggingDefaultsToEnabled() {
        XCTAssertTrue(argoGhosttyShouldEnableIMEDebugLogging(environment: [:]))
    }

    func testReturnIsNotSentAsLiteralText() {
        XCTAssertFalse(shouldSendGhosttyText("\r"))
        XCTAssertFalse(shouldSendGhosttyText("\n"))
    }

    func testPrintableTextIsStillSent() {
        XCTAssertTrue(shouldSendGhosttyText("a"))
        XCTAssertTrue(shouldSendGhosttyText("你"))
    }

    func testCtrlLetterDoesNotAttachPrintableTextToGhosttyKeyEvent() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{19}",
            charactersIgnoringModifiers: "y",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_Y)
        )

        XCTAssertNotNil(event)
        XCTAssertNil(textForGhosttyKeyEvent(event!))
    }

    func testCtrlReturnDoesNotAttachTextToGhosttyKeyEvent() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: UInt16(kVK_Return)
        )

        XCTAssertNotNil(event)
        XCTAssertNil(textForGhosttyKeyEvent(event!))
    }

    func testConsumedBindingWithoutActiveSequencesAttemptsMenu() {
        XCTAssertTrue(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testPerformableBindingDoesNotAttemptMenu() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(
                    GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue | GHOSTTY_BINDING_FLAGS_PERFORMABLE.rawValue
                ),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testActiveKeySequenceSuppressesMenuAttempt() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue),
                hasActiveKeySequence: true,
                hasActiveKeyTable: false
            )
        )
    }

    func testAllBindingDoesNotAttemptMenu() {
        XCTAssertFalse(
            ghosttyShouldAttemptMenu(
                flags: ghostty_binding_flags_e(
                    GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue | GHOSTTY_BINDING_FLAGS_ALL.rawValue
                ),
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testUnboundOptionShortcutStillAttemptsMenu() {
        XCTAssertTrue(
            argoGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [.option],
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testPlainUnboundKeyDoesNotAttemptMenu() {
        XCTAssertFalse(
            argoGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [],
                hasActiveKeySequence: false,
                hasActiveKeyTable: false
            )
        )
    }

    func testUnboundShortcutSkipsMenuDuringActiveKeySequence() {
        XCTAssertFalse(
            argoGhosttyShouldAttemptMenuKeyEquivalent(
                bindingFlags: nil,
                modifierFlags: [.option],
                hasActiveKeySequence: true,
                hasActiveKeyTable: false
            )
        )
    }

    func testGhosttySplitRightStopsDispatchingWhenShortcutIsCustomized() {
        var settings = AppSettings()
        ArgoKeyboardShortcuts.setShortcut(
            StoredShortcut(key: "d", command: false, shift: false, option: true, control: false),
            for: .splitRight,
            in: &settings
        )

        XCTAssertFalse(
            argoGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_RIGHT,
                settings: settings
            )
        )
    }

    func testGhosttySplitDownStopsDispatchingWhenShortcutIsDisabled() {
        var settings = AppSettings()
        ArgoKeyboardShortcuts.disableShortcut(for: .splitDown, in: &settings)

        XCTAssertFalse(
            argoGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_DOWN,
                settings: settings
            )
        )
    }

    func testGhosttySplitRightStillDispatchesWithDefaultShortcut() {
        XCTAssertTrue(
            argoGhosttyShouldDispatchWorkspaceSplitAction(
                GHOSTTY_SPLIT_DIRECTION_RIGHT,
                settings: AppSettings()
            )
        )
    }

    func testCtrlReturnEquivalentKeyStaysReturn() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "\r",
            characters: "\r",
            modifierFlags: [.control],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )

        XCTAssertEqual(resolution.equivalent, "\r")
        XCTAssertNil(resolution.nextLastPerformKeyEvent)
    }

    func testCommandKeyEquivalentRequiresSecondPassToRedispatch() {
        let firstResolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )
        XCTAssertNil(firstResolution.equivalent)
        XCTAssertEqual(firstResolution.nextLastPerformKeyEvent, 42)

        let secondResolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 42,
            lastPerformKeyEvent: firstResolution.nextLastPerformKeyEvent
        )
        XCTAssertEqual(secondResolution.equivalent, "k")
        XCTAssertNil(secondResolution.nextLastPerformKeyEvent)
    }

    func testCtrlSlashEquivalentKeyBecomesUnderscore() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "/",
            characters: "/",
            modifierFlags: [.control],
            eventTimestamp: 42,
            lastPerformKeyEvent: nil
        )

        XCTAssertEqual(resolution.equivalent, "_")
        XCTAssertNil(resolution.nextLastPerformKeyEvent)
    }

    func testZeroTimestampDoesNotRedispatchEquivalentKey() {
        let resolution = resolveGhosttyEquivalentKey(
            charactersIgnoringModifiers: "k",
            characters: "k",
            modifierFlags: [.command],
            eventTimestamp: 0,
            lastPerformKeyEvent: 99
        )

        XCTAssertNil(resolution.equivalent)
        XCTAssertEqual(resolution.nextLastPerformKeyEvent, 99)
    }

    func testClampUsesTextLengthForNotFoundSelection() {
        XCTAssertEqual(
            ArgoGhosttyMarkedTextState.clamp(NSRange(location: NSNotFound, length: 3), textLength: 5),
            NSRange(location: 5, length: 0)
        )
    }

    func testClampCollapsesEmptyTextSelections() {
        XCTAssertEqual(
            ArgoGhosttyMarkedTextState.clamp(NSRange(location: 4, length: 2), textLength: 0),
            NSRange(location: 0, length: 0)
        )
    }

    func testTextFinderActionResolvesFromMenuItemTag() {
        let menuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "f")
        menuItem.tag = NSTextFinder.Action.showFindInterface.rawValue

        XCTAssertEqual(argoTextFinderAction(for: menuItem), .showFindInterface)
    }

    func testTextFinderActionIgnoresUnsupportedSender() {
        XCTAssertNil(argoTextFinderAction(for: NSObject()))
    }

    func testGhosttySearchBindingActionUsesSearchPrefix() {
        XCTAssertEqual(
            argoGhosttySearchBindingAction(for: "needle"),
            "search:needle"
        )
    }

    func testGhosttySearchBindingActionPreservesLiteralQueryText() {
        XCTAssertEqual(
            argoGhosttySearchBindingAction(for: "error: timeout /tmp/a b"),
            "search:error: timeout /tmp/a b"
        )
    }

    func testGhosttySearchBindingActionAllowsEmptyQuery() {
        XCTAssertEqual(
            argoGhosttySearchBindingAction(for: ""),
            "search:"
        )
    }

    func testGhosttySearchNavigationBindingActionUsesNavigateSearchAction() {
        XCTAssertEqual(
            argoGhosttySearchNavigationBindingAction(.next),
            "navigate_search:next"
        )
        XCTAssertEqual(
            argoGhosttySearchNavigationBindingAction(.previous),
            "navigate_search:previous"
        )
    }

    func testTerminalDropTextEscapesFilePathsForShells() {
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/argo screenshot.png"),
            URL(fileURLWithPath: "/tmp/it's-argo.jpg"),
        ]

        XCTAssertEqual(
            argoTerminalDropText(fileURLs: fileURLs, plainText: nil),
            "/tmp/argo\\ screenshot.png /tmp/it\\'s-argo.jpg"
        )
    }

    func testTerminalDropTextFallsBackToPlainText() {
        XCTAssertEqual(
            argoTerminalDropText(fileURLs: [], plainText: "dragged prompt"),
            "dragged prompt"
        )
    }

    func testDeleteBackwardRemovesSingleComposedCharacter() {
        var state = ArgoGhosttyMarkedTextState(
            text: "你好",
            selectedRange: NSRange(location: 2, length: 0)
        )

        state.deleteBackward()

        XCTAssertEqual(state.text, "你")
        XCTAssertEqual(state.selectedRange, NSRange(location: 1, length: 0))
    }

    func testDeleteBackwardRemovesSingleCharacterWhenImeSelectionSpansMarkedText() {
        var state = ArgoGhosttyMarkedTextState(
            text: "你好",
            selectedRange: NSRange(location: 0, length: 2)
        )

        state.deleteBackward()

        XCTAssertEqual(state.text, "你")
        XCTAssertEqual(state.selectedRange, NSRange(location: 1, length: 0))
    }

    func testSetMarkedTextHonorsReplacementRangeAndOffsetsSelection() {
        var state = ArgoGhosttyMarkedTextState(
            text: "nihao",
            selectedRange: NSRange(location: 5, length: 0)
        )

        state.setMarkedText(
            "u",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: 4, length: 1)
        )

        XCTAssertEqual(state.text, "nihau")
        XCTAssertEqual(state.selectedRange, NSRange(location: 5, length: 0))
    }

    func testAppKitModsReplacesDirectionalModifiersButPreservesFallbackFlags() {
        let mods = ghostty_input_mods_e(GHOSTTY_MODS_ALT.rawValue | GHOSTTY_MODS_SHIFT.rawValue)
        let resolved = appKitMods(mods, fallback: [.capsLock, .command])

        XCTAssertEqual(resolved.intersection([.shift, .option, .command, .capsLock]), [.shift, .option, .capsLock])
    }

    func testModifierActionReleasesControlEvenWhenAnotherModifierRemainsPressed() {
        XCTAssertEqual(
            argoGhosttyModifierAction(
                keyCode: UInt16(kVK_Control),
                modifierFlags: [.command]
            ),
            GHOSTTY_ACTION_RELEASE
        )
    }

    func testModifierActionPressesRightControlOnlyWhenDirectionalBitIsSet() {
        let flags = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.control.rawValue | UInt(NX_DEVICERCTLKEYMASK)
        )

        XCTAssertEqual(
            argoGhosttyModifierAction(
                keyCode: UInt16(kVK_RightControl),
                modifierFlags: flags
            ),
            GHOSTTY_ACTION_PRESS
        )
    }

    func testModifierActionIgnoresNonModifierKeys() {
        XCTAssertNil(
            argoGhosttyModifierAction(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlags: [.control]
            )
        )
    }

    func testReclaimsFirstResponderWhenFocusedSurfaceLostInputInKeyWindow() {
        XCTAssertTrue(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: true,
                windowIsKey: true,
                isAlreadyFirstResponder: false,
                firstResponderIsClaimable: true,
                hasSurface: true
            )
        )
    }

    func testDoesNotReclaimFirstResponderWhenAlreadyFirstResponder() {
        XCTAssertFalse(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: true,
                windowIsKey: true,
                isAlreadyFirstResponder: true,
                firstResponderIsClaimable: true,
                hasSurface: true
            )
        )
    }

    func testDoesNotReclaimFirstResponderWhenAnotherControlHoldsFocus() {
        // e.g. the in-pane search field is first responder.
        XCTAssertFalse(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: true,
                windowIsKey: true,
                isAlreadyFirstResponder: false,
                firstResponderIsClaimable: false,
                hasSurface: true
            )
        )
    }

    func testDoesNotReclaimFirstResponderWhenWindowIsNotKey() {
        XCTAssertFalse(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: true,
                windowIsKey: false,
                isAlreadyFirstResponder: false,
                firstResponderIsClaimable: true,
                hasSurface: true
            )
        )
    }

    func testDoesNotReclaimFirstResponderForUnfocusedPane() {
        XCTAssertFalse(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: false,
                windowIsKey: true,
                isAlreadyFirstResponder: false,
                firstResponderIsClaimable: true,
                hasSurface: true
            )
        )
    }

    func testDoesNotReclaimFirstResponderWithoutSurface() {
        XCTAssertFalse(
            argoGhosttyShouldReclaimFirstResponder(
                isWorkspaceFocused: true,
                windowIsKey: true,
                isAlreadyFirstResponder: false,
                firstResponderIsClaimable: true,
                hasSurface: false
            )
        )
    }
}
