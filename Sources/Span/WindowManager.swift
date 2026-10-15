import AppKit
import ApplicationServices

enum WindowManagerError: LocalizedError {
    case permissionRequired
    case noActiveApplication
    case noFocusedWindow
    case windowCannotMove
    case accessibilityError(String)

    var errorDescription: String? {
        switch self {
        case .permissionRequired: return "Enable Span in Privacy & Security"
        case .noActiveApplication: return "No active application found"
        case .noFocusedWindow: return "The active app has no movable window"
        case .windowCannotMove: return "This window cannot be moved"
        case .accessibilityError(let message): return message
        }
    }
}

final class WindowManager {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var lastExternalPID: pid_t?
    private var activationObserver: NSObjectProtocol?

    init() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.processIdentifier != ownPID {
            lastExternalPID = app.processIdentifier
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != self.ownPID else { return }
            self.lastExternalPID = app.processIdentifier
        }
    }

    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    var isTrusted: Bool { AXIsProcessTrusted() }

    var targetApplicationName: String? {
        guard let pid = targetPID else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    private var targetPID: pid_t? {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.processIdentifier != ownPID,
           current.activationPolicy == .regular {
            return current.processIdentifier
        }
        return lastExternalPID
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func moveFocusedWindow(to cocoaFrame: CGRect) throws {
        guard isTrusted else { throw WindowManagerError.permissionRequired }
        guard let targetPID else {
            throw WindowManagerError.noActiveApplication
        }

        let application = AXUIElementCreateApplication(targetPID)
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &windowValue)
        guard result == .success, let windowValue else {
            throw WindowManagerError.accessibilityError("Could not read \(targetApplicationName ?? "the app") window (AX error \(result.rawValue))")
        }
        let window = windowValue as! AXUIElement
        try move(window, to: cocoaFrame)
    }

    func tileVisibleWindows(into cocoaFrames: [CGRect]) throws {
        guard isTrusted else { throw WindowManagerError.permissionRequired }
        var windows: [AXUIElement] = []

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != ownPID {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let appWindows = value as? [AXUIElement] else { continue }
            for window in appWindows {
                var minimized: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
                if (minimized as? Bool) != true { windows.append(window) }
            }
        }

        guard !windows.isEmpty else { throw WindowManagerError.noFocusedWindow }
        for (index, window) in windows.prefix(cocoaFrames.count).enumerated() {
            try? move(window, to: cocoaFrames[index])
        }
    }

    private func move(_ window: AXUIElement, to cocoaFrame: CGRect) throws {
        let axFrame = cocoaToAccessibility(cocoaFrame)
        var position = CGPoint(x: axFrame.minX, y: axFrame.minY)
        var size = CGSize(width: axFrame.width, height: axFrame.height)
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowManagerError.windowCannotMove
        }

        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        guard positionResult == .success || sizeResult == .success else {
            throw WindowManagerError.accessibilityError("The app rejected the move (AX \(positionResult.rawValue)/\(sizeResult.rawValue))")
        }
    }

    private func cocoaToAccessibility(_ frame: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main else { return frame }
        return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }
}
