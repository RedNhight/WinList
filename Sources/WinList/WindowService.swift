import AppKit
import ApplicationServices

struct RecentOrdering<Key: Equatable> {
    private(set) var keys: [Key] = []

    mutating func synchronize(available: [Key], current: Key?) -> [Key] {
        keys.removeAll { !available.contains($0) }

        for key in available where !keys.contains(key) {
            keys.append(key)
        }

        if let current {
            promote(current)
        }
        return keys
    }

    mutating func promote(_ key: Key) {
        keys.removeAll { $0 == key }
        keys.insert(key, at: 0)
    }
}

struct WindowIdentity: Hashable {
    let processIdentifier: pid_t
    fileprivate let element: AXUIElement

    static func == (lhs: WindowIdentity, rhs: WindowIdentity) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier && CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(processIdentifier)
        hasher.combine(CFHash(element))
    }
}

struct WindowItem: Identifiable {
    let id: WindowIdentity
    let processIdentifier: pid_t
    let applicationName: String
    let title: String
    let icon: NSImage
    let isMinimized: Bool
    let isFocused: Bool

    fileprivate var accessibilityElement: AXUIElement {
        id.element
    }
}

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func request() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

final class WindowService {
    private var recentWindows = RecentOrdering<WindowIdentity>()

    func windows() -> [WindowItem] {
        guard AccessibilityPermission.isGranted else { return [] }

        let focusedWindow = focusedWindowElement()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                    !app.isTerminated &&
                    app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
            .sorted { lhs, rhs in
                if lhs.processIdentifier == frontmostPID { return true }
                if rhs.processIdentifier == frontmostPID { return false }
                return (lhs.localizedName ?? "").localizedCaseInsensitiveCompare(rhs.localizedName ?? "") == .orderedAscending
            }

        var result: [WindowItem] = []

        for application in applications {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            guard let windowElements = attribute(
                kAXWindowsAttribute as CFString,
                from: applicationElement
            ) as? [AXUIElement] else {
                continue
            }

            for windowElement in windowElements {
                guard isUsefulWindow(windowElement) else { continue }

                let title = attribute(kAXTitleAttribute as CFString, from: windowElement) as? String
                let minimized = attribute(kAXMinimizedAttribute as CFString, from: windowElement) as? Bool ?? false
                let focused = focusedWindow.map { CFEqual($0, windowElement) } ?? false

                result.append(
                    WindowItem(
                        id: WindowIdentity(
                            processIdentifier: application.processIdentifier,
                            element: windowElement
                        ),
                        processIdentifier: application.processIdentifier,
                        applicationName: application.localizedName ?? "Untitled App",
                        title: normalizedTitle(title, applicationName: application.localizedName),
                        icon: application.icon ?? NSImage(
                            systemSymbolName: "app.fill",
                            accessibilityDescription: nil
                        ) ?? NSImage(),
                        isMinimized: minimized,
                        isFocused: focused
                    )
                )
            }
        }

        let baseline = result.sorted { lhs, rhs in
            if lhs.isFocused != rhs.isFocused { return lhs.isFocused }
            if lhs.processIdentifier == frontmostPID, rhs.processIdentifier != frontmostPID { return true }
            if rhs.processIdentifier == frontmostPID, lhs.processIdentifier != frontmostPID { return false }
            if lhs.applicationName != rhs.applicationName {
                return lhs.applicationName.localizedCaseInsensitiveCompare(rhs.applicationName) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        let orderedIdentities = recentWindows.synchronize(
            available: baseline.map(\.id),
            current: baseline.first(where: \.isFocused)?.id
        )
        return orderedIdentities.compactMap { identity in
            baseline.first { $0.id == identity }
        }
    }

    func activate(_ item: WindowItem) {
        recentWindows.promote(item.id)
        let window = item.accessibilityElement
        if item.isMinimized {
            AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
        }

        NSRunningApplication(processIdentifier: item.processIdentifier)?.activate(
            options: [.activateIgnoringOtherApps]
        )
        focusAndRaise(window)

        // Raising an AX window from another Space can race the Space transition.
        // Repeating the idempotent focus request after activation makes the
        // selected window reliably become key once that transition has started.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.focusAndRaise(window)
        }
    }

    private func focusedWindowElement() -> AXUIElement? {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }
        let frontmostApplication = AXUIElementCreateApplication(frontmostPID)
        return attribute(
            kAXFocusedWindowAttribute as CFString,
            from: frontmostApplication
        ) as! AXUIElement?
    }

    private func isUsefulWindow(_ window: AXUIElement) -> Bool {
        let role = attribute(kAXRoleAttribute as CFString, from: window) as? String
        guard role == (kAXWindowRole as String) else { return false }

        let subrole = attribute(kAXSubroleAttribute as CFString, from: window) as? String
        return subrole != (kAXUnknownSubrole as String)
    }

    private func normalizedTitle(_ title: String?, applicationName: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? (applicationName ?? "Untitled Window") : trimmed
    }

    private func focusAndRaise(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func attribute(_ name: CFString, from element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
            return nil
        }
        return value
    }
}
