import Combine
import Foundation

enum SwitcherLayoutMode: String {
    case vertical
    case horizontal
}

enum SelectionNavigator {
    static func movedIndex(current: Int, delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + delta % count + count) % count
    }
}

final class SwitcherModel: ObservableObject {
    private static let layoutDefaultsKey = "switcherLayoutMode"

    @Published private(set) var windows: [WindowItem] = []
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var layoutMode: SwitcherLayoutMode
    @Published var selectedIndex = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        layoutMode = SwitcherLayoutMode(
            rawValue: defaults.string(forKey: Self.layoutDefaultsKey) ?? ""
        ) ?? .vertical
    }

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

    func toggleLayout() {
        layoutMode = layoutMode == .vertical ? .horizontal : .vertical
        defaults.set(layoutMode.rawValue, forKey: Self.layoutDefaultsKey)
    }
}
