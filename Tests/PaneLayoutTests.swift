//
//  PaneLayoutTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class PaneLayoutTests: XCTestCase {
    func testSplitDividerBlocksWindowDraggingWhileUsingExpandedHitTarget() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let splitNodeSource = try String(
            contentsOf: rootURL.appendingPathComponent("Argo/UI/Workspace/SplitNodeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(splitNodeSource.contains("static let visualThickness: CGFloat = 6"))
        XCTAssertTrue(splitNodeSource.contains("static let hitTargetThickness: CGFloat = 18"))
        XCTAssertTrue(splitNodeSource.contains("SplitDividerHitTarget("))
        XCTAssertTrue(splitNodeSource.contains("SplitDividerEventLayer("))
        XCTAssertTrue(splitNodeSource.contains("override var mouseDownCanMoveWindow: Bool"))
        XCTAssertTrue(splitNodeSource.contains("false"))
    }

    func testSplitAndRemovePaneKeepsTreeValid() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        var root: SessionLayoutNode = .pane(PaneLeaf(paneID: first))
        XCTAssertTrue(root.split(paneID: first, axis: .vertical, newPaneID: second))
        XCTAssertTrue(root.split(paneID: second, axis: .horizontal, newPaneID: third))

        XCTAssertEqual(root.paneIDs, [first, second, third])

        _ = root.removePane(second)
        XCTAssertEqual(Set(root.paneIDs), Set([first, third]))
    }

    func testEqualizeSplitsRecursivelyResetsFractions() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        var root: SessionLayoutNode = .split(
            PaneSplitNode(
                axis: .vertical,
                fraction: 0.2,
                first: .pane(PaneLeaf(paneID: first)),
                second: .split(
                    PaneSplitNode(
                        axis: .horizontal,
                        fraction: 0.8,
                        first: .pane(PaneLeaf(paneID: second)),
                        second: .pane(PaneLeaf(paneID: third))
                    )
                )
            )
        )

        root.equalizeSplits()

        guard case .split(let outer) = root else {
            return XCTFail("Expected split root")
        }
        XCTAssertEqual(outer.fraction, 1.0 / 3.0, accuracy: 0.0001)

        guard case .split(let inner) = outer.second else {
            return XCTFail("Expected nested split")
        }
        XCTAssertEqual(inner.fraction, 0.5, accuracy: 0.0001)
    }

    func testDirectionalFocusUsesSplitAxes() {
        let left = UUID()
        let middle = UUID()
        let bottom = UUID()

        let layout: SessionLayoutNode = .split(
            PaneSplitNode(
                axis: .vertical,
                first: .pane(PaneLeaf(paneID: left)),
                second: .split(
                    PaneSplitNode(
                        axis: .horizontal,
                        first: .pane(PaneLeaf(paneID: middle)),
                        second: .pane(PaneLeaf(paneID: bottom))
                    )
                )
            )
        )

        XCTAssertEqual(layout.paneID(in: .left, from: middle), left)
        XCTAssertEqual(layout.paneID(in: .down, from: middle), bottom)
        XCTAssertEqual(layout.paneID(in: .up, from: bottom), middle)
        XCTAssertNil(layout.paneID(in: .right, from: bottom))
    }

    func testSplitSizingClampsFractionsAndDragTranslation() {
        XCTAssertEqual(PaneSplitSizing.clampedFraction(-0.5), 0.12, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(1.5), 0.88, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(.nan), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(.infinity), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PaneSplitSizing.clampedFraction(-Double.infinity), 0.5, accuracy: 0.0001)

        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: 50, availableLength: 200),
            0.65,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: -500, availableLength: 200),
            0.12,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PaneSplitSizing.fraction(startingAt: 0.4, translation: 500, availableLength: 200),
            0.88,
            accuracy: 0.0001
        )
    }

    func testSplitDragContextUsesFrozenStartingPointForPreviewFractions() {
        let context = PaneSplitDragContext(startFraction: 0.4, availableLength: 200)

        XCTAssertEqual(
            context.fraction(forTranslation: 50),
            0.65,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            context.fraction(forTranslation: -500),
            0.12,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            context.fraction(forTranslation: 500),
            0.88,
            accuracy: 0.0001
        )
    }

    func testSplitSizingAllocatesLengthsWithoutOverflowingContainer() {
        let balanced = PaneSplitSizing.lengths(
            totalLength: 500,
            dividerThickness: 6,
            fraction: 0.5,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(balanced.available, 494, accuracy: 0.0001)
        XCTAssertEqual(balanced.first, 247, accuracy: 0.0001)
        XCTAssertEqual(balanced.second, 247, accuracy: 0.0001)

        let minimumPreserved = PaneSplitSizing.lengths(
            totalLength: 500,
            dividerThickness: 6,
            fraction: 0.1,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(minimumPreserved.available, 494, accuracy: 0.0001)
        XCTAssertEqual(minimumPreserved.first, 120, accuracy: 0.0001)
        XCTAssertEqual(minimumPreserved.second, 374, accuracy: 0.0001)

        let constrained = PaneSplitSizing.lengths(
            totalLength: 220,
            dividerThickness: 6,
            fraction: 0.8,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(constrained.available, 214, accuracy: 0.0001)
        XCTAssertEqual(constrained.first + constrained.second, constrained.available, accuracy: 0.0001)
        XCTAssertGreaterThan(constrained.first, 0)
        XCTAssertGreaterThan(constrained.second, 0)

        let collapsed = PaneSplitSizing.lengths(
            totalLength: 0,
            dividerThickness: 6,
            fraction: 0.5,
            minimumFirst: 120,
            minimumSecond: 120
        )

        XCTAssertEqual(collapsed.available, 0, accuracy: 0.0001)
        XCTAssertEqual(collapsed.first, 0, accuracy: 0.0001)
        XCTAssertEqual(collapsed.second, 0, accuracy: 0.0001)
    }

    func testUpdateFractionClampsAtBounds() {
        let splitID = UUID()
        let first = UUID()
        let second = UUID()
        var layout: SessionLayoutNode = .split(
            PaneSplitNode(
                id: splitID,
                axis: .vertical,
                fraction: 0.5,
                first: .pane(PaneLeaf(paneID: first)),
                second: .pane(PaneLeaf(paneID: second))
            )
        )

        XCTAssertTrue(layout.updateFraction(splitID: splitID, fraction: -1))
        guard case .split(let lowClampedSplit) = layout else {
            return XCTFail("Expected split root")
        }
        XCTAssertEqual(lowClampedSplit.fraction, 0.12, accuracy: 0.0001)

        XCTAssertTrue(layout.updateFraction(splitID: splitID, fraction: 2))
        guard case .split(let highClampedSplit) = layout else {
            return XCTFail("Expected split root")
        }
        XCTAssertEqual(highClampedSplit.fraction, 0.88, accuracy: 0.0001)
    }

    func testNestedUpdateFractionOnlyMutatesTargetSplit() {
        let outerID = UUID()
        let innerID = UUID()
        let top = UUID()
        let bottomLeft = UUID()
        let bottomRight = UUID()

        var layout: SessionLayoutNode = .split(
            PaneSplitNode(
                id: outerID,
                axis: .horizontal,
                fraction: 0.42,
                first: .pane(PaneLeaf(paneID: top)),
                second: .split(
                    PaneSplitNode(
                        id: innerID,
                        axis: .vertical,
                        fraction: 0.5,
                        first: .pane(PaneLeaf(paneID: bottomLeft)),
                        second: .pane(PaneLeaf(paneID: bottomRight))
                    )
                )
            )
        )

        XCTAssertTrue(layout.updateFraction(splitID: innerID, fraction: 0.7))

        guard case .split(let outerAfterInnerUpdate) = layout else {
            return XCTFail("Expected outer split")
        }
        XCTAssertEqual(outerAfterInnerUpdate.fraction, 0.42, accuracy: 0.0001)
        guard case .split(let innerAfterInnerUpdate) = outerAfterInnerUpdate.second else {
            return XCTFail("Expected nested split")
        }
        XCTAssertEqual(innerAfterInnerUpdate.fraction, 0.7, accuracy: 0.0001)

        XCTAssertTrue(layout.updateFraction(splitID: outerID, fraction: 0.3))

        guard case .split(let outerAfterOuterUpdate) = layout else {
            return XCTFail("Expected outer split")
        }
        XCTAssertEqual(outerAfterOuterUpdate.fraction, 0.3, accuracy: 0.0001)
        guard case .split(let innerAfterOuterUpdate) = outerAfterOuterUpdate.second else {
            return XCTFail("Expected nested split")
        }
        XCTAssertEqual(innerAfterOuterUpdate.fraction, 0.7, accuracy: 0.0001)
    }

    func testSplitDividerAppearanceUsesPrototypeHandleDimensions() {
        XCTAssertEqual(
            PaneSplitDividerAppearance.handleSize(for: .vertical),
            CGSize(width: 3, height: 64)
        )
        XCTAssertEqual(
            PaneSplitDividerAppearance.handleSize(for: .horizontal),
            CGSize(width: 56, height: 3)
        )
    }

    func testSplitDividerHandleStaysVisibleAndBrightensWhenActive() {
        XCTAssertGreaterThan(PaneSplitDividerAppearance.inactiveHandleOpacity, 0)
        XCTAssertGreaterThan(
            PaneSplitDividerAppearance.activeHandleOpacity,
            PaneSplitDividerAppearance.inactiveHandleOpacity
        )
    }

    func testSplitDividerHandleUsesPrototypeHoverScale() {
        XCTAssertEqual(PaneSplitDividerAppearance.activeHandleScale, 1.08, accuracy: 0.0001)
    }

    func testSplitDividerHandleDoesNotUseSymbolIconOrCircularBacking() {
        XCTAssertFalse(PaneSplitDividerAppearance.usesSymbolIcon)
        XCTAssertFalse(PaneSplitDividerAppearance.usesIconBacking)
    }

    func testSplitDividerRendersAboveAdjacentPanesSoHoverHandleIsNotOccluded() {
        XCTAssertGreaterThan(PaneSplitDividerAppearance.stackZIndex, 0)
    }
}
