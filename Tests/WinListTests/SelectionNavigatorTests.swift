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

final class CommandTabSessionTests: XCTestCase {
    func testBeginsAndCommitsOnCommandRelease() {
        var session = CommandTabSession()

        session.begin()

        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.commitOnCommandRelease())
        XCTAssertFalse(session.isActive)
        XCTAssertFalse(session.commitOnCommandRelease())
    }

    func testConsumesOnlyOneMatchingTabKeyUp() {
        var session = CommandTabSession()

        session.begin()

        XCTAssertTrue(session.consumeTabKeyUp())
        XCTAssertFalse(session.consumeTabKeyUp())
    }

    func testCancelPreventsCommit() {
        var session = CommandTabSession()

        session.begin()

        XCTAssertTrue(session.cancel())
        XCTAssertFalse(session.isActive)
        XCTAssertFalse(session.commitOnCommandRelease())
        XCTAssertFalse(session.consumeTabKeyUp())
    }
}

final class RecentOrderingTests: XCTestCase {
    func testRepeatedActivationTogglesTheTwoMostRecentItems() {
        var ordering = RecentOrdering<String>()
        XCTAssertEqual(
            ordering.synchronize(
                available: ["ChatGPT", "Chrome", "Kitty", "Telegram"],
                current: "ChatGPT"
            ),
            ["ChatGPT", "Chrome", "Kitty", "Telegram"]
        )

        ordering.promote("Kitty")
        XCTAssertEqual(ordering.keys, ["Kitty", "ChatGPT", "Chrome", "Telegram"])

        ordering.promote("ChatGPT")
        XCTAssertEqual(ordering.keys, ["ChatGPT", "Kitty", "Chrome", "Telegram"])
    }

    func testSynchronizationKeepsKnownOrderAndAppendsNewItems() {
        var ordering = RecentOrdering<String>()
        _ = ordering.synchronize(available: ["A", "B", "C"], current: "A")

        XCTAssertEqual(
            ordering.synchronize(available: ["A", "C", "D"], current: "C"),
            ["C", "A", "D"]
        )
    }
}

final class SwitcherLayoutModeTests: XCTestCase {
    func testLayoutToggleIsPersisted() throws {
        let suiteName = "WinListTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = SwitcherModel(defaults: defaults)
        XCTAssertEqual(model.layoutMode, .vertical)

        model.toggleLayout()
        XCTAssertEqual(model.layoutMode, .horizontal)
        XCTAssertEqual(SwitcherModel(defaults: defaults).layoutMode, .horizontal)
    }
}
