import AppKit

@MainActor
final class GlobalShortcutMonitor {
    private weak var model: SpanModel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(model: SpanModel) { self.model = model }

    func start() {
        let mask: NSEvent.EventTypeMask = .keyDown
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if self?.handle(event) == true { return nil }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        let required: NSEvent.ModifierFlags = [.control, .option]
        guard event.modifierFlags.intersection([.control, .option, .command, .shift]) == required else { return false }
        switch event.keyCode {
        case 123: model?.snapPrevious()
        case 124: model?.snapNext()
        case 36: model?.maximize()
        case 18: model?.snap(to: 0)
        case 19: model?.snap(to: 1)
        case 20: model?.snap(to: 2)
        case 21: model?.snap(to: 3)
        case 23: model?.snap(to: 4)
        case 22: model?.snap(to: 5)
        default: return false
        }
        return true
    }
}
