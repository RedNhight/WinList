import ApplicationServices
import Foundation

private func winListEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userInfo).takeUnretainedValue()
    return hotKey.handle(type: type, event: event)
}

enum GlobalHotKeyError: LocalizedError {
    case accessibilityPermissionRequired
    case eventTapUnavailable
    case runLoopSourceUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Allow WinList in Accessibility settings first."
        case .eventTapUnavailable:
            return "macOS did not allow WinList to create a keyboard event tap."
        case .runLoopSourceUnavailable:
            return "WinList could not attach the keyboard event tap to its main run loop."
        }
    }
}

/// A session-level event tap catches the shortcut before the frontmost app.
/// This is more predictable than the legacy Carbon hot-key dispatcher and also
/// lets us suppress the original Fn+Space event after handling it.
final class GlobalHotKey {
    private static let relevantFlags: CGEventFlags = [
        .maskCommand,
        .maskControl,
        .maskAlternate,
        .maskShift,
        .maskSecondaryFn
    ]

    private let keyCode: CGKeyCode
    private let modifiers: CGEventFlags
    private let callback: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        keyCode: CGKeyCode,
        modifiers: CGEventFlags,
        callback: @escaping () -> Void
    ) throws {
        guard AXIsProcessTrusted() else {
            throw GlobalHotKeyError.accessibilityPermissionRequired
        }

        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantFlags)
        self.callback = callback

        let eventMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: winListEventTapCallback,
            userInfo: userInfo
        ) else {
            throw GlobalHotKeyError.eventTapUnavailable
        }
        self.eventTap = eventTap

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            throw GlobalHotKeyError.runLoopSourceUnavailable
        }
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }

    fileprivate func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown,
              CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode,
              event.flags.intersection(Self.relevantFlags) == modifiers else {
            return Unmanaged.passUnretained(event)
        }

        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if !isAutoRepeat {
            DispatchQueue.main.async { [callback] in
                callback()
            }
        }

        // Swallow Fn+Space so the frontmost application does not also handle it.
        return nil
    }
}
