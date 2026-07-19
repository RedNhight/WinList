import XCTest
@testable import WinList

final class SelectionNavigatorTests: XCTestCase {
    func testMovesForward() {
        XCTAssertEqual(SelectionNavigator.movedIndex(current: 1, delta: 1, count: 4), 2)
    }

    func testWrapsPastLastItem() {
        XCTAssertEqual(SelectionNavigator.movedIndex(current: 3, delta: 1, count: 4), 0)
    }

    func testWrapsBeforeFirstItem() {
        XCTAssertEqual(SelectionNavigator.movedIndex(current: 0, delta: -1, count: 4), 3)
    }

    func testEmptyListStaysAtZero() {
        XCTAssertEqual(SelectionNavigator.movedIndex(current: 7, delta: 1, count: 0), 0)
    }
}
