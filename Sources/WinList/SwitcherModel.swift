import Combine
import Foundation

enum SelectionNavigator {
    static func movedIndex(current: Int, delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + delta % count + count) % count
    }
}

final class SwitcherModel: ObservableObject {
    @Published private(set) var windows: [WindowItem] = []
    @Published private(set) var hasAccessibilityPermission = false
    @Published var selectedIndex = 0

    var selectedWindow: WindowItem? {
        guard windows.indices.contains(selectedIndex) else { return nil }
        return windows[selectedIndex]
    }

    func replaceWindows(_ windows: [WindowItem], permissionGranted: Bool) {
        self.windows = windows
        hasAccessibilityPermission = permissionGranted
        selectedIndex = windows.firstIndex(where: \.isFocused) ?? 0
    }

    func moveSelection(by delta: Int) {
        selectedIndex = SelectionNavigator.movedIndex(
            current: selectedIndex,
            delta: delta,
            count: windows.count
        )
    }
}
