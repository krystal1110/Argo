import XCTest
@testable import Argo

final class IslandClosedAgentsGridTests: XCTestCase {
    func testBalancedRowsMatchOpenVibeShapes() {
        XCTAssertEqual(IslandRightSlotView.balancedRows(1), [1])
        XCTAssertEqual(IslandRightSlotView.balancedRows(4), [2, 2])
        XCTAssertEqual(IslandRightSlotView.balancedRows(7), [4, 3])
        XCTAssertEqual(IslandRightSlotView.balancedRows(9), [3, 3, 3])
    }

    func testGridCellsMapSessionPhases() {
        XCTAssertEqual(IslandGridCellState(phase: .running), .running)
        XCTAssertEqual(IslandGridCellState(phase: .waitingForAnswer), .waiting)
        XCTAssertEqual(IslandGridCellState(phase: .completed), .idle)
    }
}
