import AppKit
import SwiftUI

final class OverlayController: NSObject {
    private let windowService: WindowService
    private let model = SwitcherModel()
    private lazy var panel = SwitcherPanel(
        contentRect: NSRect(x: 0, y: 0, width: 430, height: 420),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var outsideClickMonitor: Any?

    var isVisible: Bool {
        panel.isVisible
    }

    init(windowService: WindowService) {
        self.windowService = windowService
        super.init()
        configurePanel()
    }

    deinit {
        removeOutsideClickMonitor()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let permissionGranted = AccessibilityPermission.isGranted
        model.replaceWindows(
            permissionGranted ? windowService.windows() : [],
            permissionGranted: permissionGranted
        )

        resizeAndPositionPanel()
        panel.orderFrontRegardless()
        panel.makeKey()
        installOutsideClickMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        removeOutsideClickMonitor()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.keyHandler = { [weak self] action in
            self?.handle(action) ?? false
        }

        let view = SwitcherView(
            model: model,
            onDismiss: { [weak self] in self?.hide() },
            onOpenSettings: {
                AccessibilityPermission.request()
                AccessibilityPermission.openSystemSettings()
            },
            onActivate: { [weak self] item in
                guard let self else { return }
                self.hide()
                self.windowService.activate(item)
            }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func handle(_ action: SwitcherPanel.KeyAction) -> Bool {
        switch action {
        case .previous:
            model.moveSelection(by: -1)
        case .next:
            model.moveSelection(by: 1)
        case .activate:
            guard let selectedWindow = model.selectedWindow else { return true }
            hide()
            windowService.activate(selectedWindow)
        case .dismiss:
            hide()
        }
        return true
    }

    private func resizeAndPositionPanel() {
        let rowCount = max(model.windows.count, 1)
        let contentHeight = min(560, max(190, 84 + rowCount * 62))
        let size = NSSize(width: 430, height: contentHeight)
        let screen = screenAtMousePointer() ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }

        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 22,
            y: visibleFrame.maxY - size.height - 22
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func screenAtMousePointer() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, !NSMouseInRect(NSEvent.mouseLocation, self.panel.frame, false) else {
                return
            }
            self.hide()
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

final class SwitcherPanel: NSPanel {
    enum KeyAction {
        case previous
        case next
        case activate
        case dismiss
    }

    var keyHandler: ((KeyAction) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let action: KeyAction?
        switch event.keyCode {
        case 123, 126:
            action = .previous
        case 124, 125:
            action = .next
        case 36, 76:
            action = .activate
        case 53:
            action = .dismiss
        default:
            action = nil
        }

        if let action, keyHandler?(action) == true {
            return
        }
        super.keyDown(with: event)
    }
}
