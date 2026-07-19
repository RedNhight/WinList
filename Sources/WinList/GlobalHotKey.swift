import ApplicationServices
import Carbon.HIToolbox
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

struct CommandTabSession {
    private(set) var isActive = false
    private var shouldSwallowTabKeyUp = false

    mutating func begin() {
        isActive = true
        shouldSwallowTabKeyUp = true
    }

    mutating func consumeTabKeyUp() -> Bool {
        guard shouldSwallowTabKeyUp else { return false }
        shouldSwallowTabKeyUp = false
        return true
    }

    mutating func commitOnCommandRelease() -> Bool {
        guard isActive else { return false }
        isActive = false
        return true
    }

    mutating func cancel() -> Bool {
        let wasActive = isActive
        isActive = false
        shouldSwallowTabKeyUp = false
        return wasActive
    }
}

/// A session-level event tap catches shortcuts before the frontmost app and Dock.
/// Events are suppressed only while WinList is running, so the system Command-Tab
/// switcher automatically returns when WinList exits.
final class GlobalHotKey {
    enum Action {
        case toggle
        case cycle(Int)
        case commit
        case cancel
    }

    private static let relevantFlags: CGEventFlags = [
        .maskCommand,
        .maskControl,
        .maskAlternate,
        .maskShift,
        .maskSecondaryFn
    ]

    private let keyCode: CGKeyCode
    private let modifiers: CGEventFlags
    private let callback: (Action) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var commandTabSession = CommandTabSession()

    init(
        keyCode: CGKeyCode,
        modifiers: CGEventFlags,
        callback: @escaping (Action) -> Void
    ) throws {
        guard AXIsProcessTrusted() else {
            throw GlobalHotKeyError.accessibilityPermissionRequired
        }

        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantFlags)
        self.callback = callback

        let eventMask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
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
            if commandTabSession.cancel() {
                dispatch(.cancel)
            }
            return Unmanaged.passUnretained(event)
        }

        let pressedKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let pressedModifiers = event.flags.intersection(Self.relevantFlags)

        if type == .flagsChanged {
            if !pressedModifiers.contains(.maskCommand),
               commandTabSession.commitOnCommandRelease() {
                dispatch(.commit)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp,
           pressedKeyCode == CGKeyCode(kVK_Tab),
           commandTabSession.consumeTabKeyUp() {
            return nil
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if pressedKeyCode == keyCode, pressedModifiers == modifiers {
            let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isAutoRepeat {
                dispatch(.toggle)
            }
            return nil
        }

        if pressedKeyCode == CGKeyCode(kVK_Tab), isCommandTab(pressedModifiers) {
            commandTabSession.begin()
            dispatch(.cycle(pressedModifiers.contains(.maskShift) ? -1 : 1))
            return nil
        }

        if pressedKeyCode == CGKeyCode(kVK_Escape), commandTabSession.cancel() {
            dispatch(.cancel)
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func isCommandTab(_ flags: CGEventFlags) -> Bool {
        flags == [.maskCommand] || flags == [.maskCommand, .maskShift]
    }

    private func dispatch(_ action: Action) {
        DispatchQueue.main.async { [callback] in
            callback(action)
        }
    }
}
