import AppKit
import ApplicationServices
import Carbon.HIToolbox

@main
enum WinListApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowService = WindowService()
    private var overlayController: OverlayController?
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlayController = OverlayController(windowService: windowService)
        self.overlayController = overlayController

        configureStatusItem()
        requestAccessibilityPermissionIfNeeded()
        installHotKeyWhenPermitted()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.stack.fill",
            accessibilityDescription: "WinList"
        )

        let menu = NSMenu()
        let showItem = NSMenuItem(
            title: "Show WinList (fn + Space)",
            action: #selector(showSwitcher),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let permissionItem = NSMenuItem(
            title: "Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit WinList",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    private func installHotKeyWhenPermitted() {
        guard hotKey == nil else { return }

        guard AXIsProcessTrusted() else {
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.permissionTimer = nil
                self?.installHotKeyWhenPermitted()
            }
            return
        }

        do {
            hotKey = try GlobalHotKey(
                keyCode: CGKeyCode(kVK_Space),
                modifiers: .maskSecondaryFn
            ) { [weak overlayController] in
                overlayController?.toggle()
            }
        } catch {
            showHotKeyError(error)
        }
    }

    private func showHotKeyError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could Not Enable the fn + Space Shortcut"
        alert.informativeText = "\(error.localizedDescription) Try turning WinList off and back on in Accessibility settings."
        alert.runModal()
    }

    @objc private func showSwitcher() {
        installHotKeyWhenPermitted()
        overlayController?.show()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.openSystemSettings()
    }
}
