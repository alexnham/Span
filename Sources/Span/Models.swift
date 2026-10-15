import SwiftUI
import AppKit

enum ZoneLayout: String, CaseIterable, Identifiable {
    case focus = "Focus + sides"
    case thirds = "Even thirds"
    case four = "Four columns"
    case wide = "Wide center"
    case custom = "Custom"

    var id: String { rawValue }

    var ratios: [CGFloat] {
        switch self {
        case .focus: return [1, 2, 1]
        case .thirds: return [1, 1, 1]
        case .four: return [1, 1, 1, 1]
        case .wide: return [1, 3, 1]
        case .custom: return [1]
        }
    }

    var detail: String {
        switch self {
        case .focus: return "25 · 50 · 25"
        case .thirds: return "33 · 33 · 33"
        case .four: return "25 · 25 · 25 · 25"
        case .wide: return "20 · 60 · 20"
        case .custom: return "Your saved zones"
        }
    }
}

struct CustomZone: Identifiable, Codable, Equatable {
    var id: UUID
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(id: UUID = UUID(), x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

enum MergeDirection: String, CaseIterable, Identifiable {
    case left, right, up, down
    var id: String { rawValue }
    var title: String { "Merge \(rawValue)" }
    var symbol: String { "arrow.\(rawValue)" }
}

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let resolution: String
    let isMain: Bool
    let frame: CGRect
    let visibleFrame: CGRect
}

@MainActor
final class SpanModel: ObservableObject {
    @Published var layout: ZoneLayout = .focus
    @Published var selectedZone = 1
    @Published var gap: CGFloat = 10
    @Published var horizontalSplit = true
    @Published var displays: [DisplayInfo] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published var hasAccessibilityPermission = false
    @Published var launchAtLogin = false
    @Published var statusMessage = "Ready"
    @Published var lastActionSucceeded = true
    @Published var targetApplicationName = "No target app"
    @Published var customZones: [CustomZone]

    private let windowManager = WindowManager()
    private let customZonesKey = "Span.customZones.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: customZonesKey),
           let zones = try? JSONDecoder().decode([CustomZone].self, from: data),
           !zones.isEmpty {
            customZones = zones
        } else {
            customZones = Self.defaultCustomZones
        }
    }

    private static var defaultCustomZones: [CustomZone] {
        [
            CustomZone(x: 0, y: 0, width: 0.5, height: 0.5),
            CustomZone(x: 0.5, y: 0, width: 0.5, height: 0.5),
            CustomZone(x: 0, y: 0.5, width: 0.5, height: 0.5),
            CustomZone(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
        ]
    }

    var selectedDisplay: DisplayInfo? {
        displays.first { $0.id == selectedDisplayID } ?? displays.first
    }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            let size = screen.frame.size
            let scale = screen.backingScaleFactor
            let resolution = "\(Int(size.width * scale)) × \(Int(size.height * scale))"
            return DisplayInfo(
                id: id,
                name: screen.localizedName,
                resolution: resolution,
                isMain: screen == NSScreen.main,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
        if selectedDisplayID == nil || !displays.contains(where: { $0.id == selectedDisplayID }) {
            selectedDisplayID = displays.first(where: \.isMain)?.id ?? displays.first?.id
        }
    }

    func refreshPermission() {
        hasAccessibilityPermission = windowManager.isTrusted
    }

    func refreshTargetApplication() {
        targetApplicationName = windowManager.targetApplicationName ?? "Switch to the window you want to move"
    }

    func requestPermission() {
        windowManager.requestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refreshPermission() }
    }

    func choose(_ layout: ZoneLayout) {
        self.layout = layout
        selectedZone = min(selectedZone, zoneCount - 1)
        statusMessage = "\(layout.rawValue) selected"
    }

    var zoneCount: Int {
        layout == .custom ? customZones.count : layout.ratios.count * (horizontalSplit ? 2 : 1)
    }

    func setHorizontalSplit(_ enabled: Bool) {
        horizontalSplit = enabled
        selectedZone = min(selectedZone, zoneCount - 1)
        statusMessage = enabled ? "Top and bottom zones enabled" : "Full-height zones enabled"
    }

    func makeCustomFromCurrent() {
        guard layout != .custom else { return }
        let ratios = layout.ratios
        let total = ratios.reduce(0, +)
        var cursor: CGFloat = 0
        let columns = ratios.map { ratio in
            let width = ratio / total
            defer { cursor += width }
            return CustomZone(x: cursor, y: 0, width: width, height: 1)
        }
        if horizontalSplit {
            customZones = columns.map { CustomZone(x: $0.x, y: 0, width: $0.width, height: 0.5) }
                + columns.map { CustomZone(x: $0.x, y: 0.5, width: $0.width, height: 0.5) }
        } else {
            customZones = columns
        }
        normalizeCustomZones()
        choose(.custom)
        persistCustomZones()
    }

    func splitCustomZone(_ id: UUID, vertically: Bool) {
        guard let index = customZones.firstIndex(where: { $0.id == id }) else { return }
        let zone = customZones[index]
        if vertically {
            guard zone.width >= 0.16 else { return }
            customZones[index].width = zone.width / 2
            customZones.insert(CustomZone(x: zone.x + zone.width / 2, y: zone.y, width: zone.width / 2, height: zone.height), at: index + 1)
        } else {
            guard zone.height >= 0.16 else { return }
            customZones[index].height = zone.height / 2
            customZones.insert(CustomZone(x: zone.x, y: zone.y + zone.height / 2, width: zone.width, height: zone.height / 2), at: index + 1)
        }
        selectedZone = index
        persistCustomZones()
    }

    func canMergeCustomZone(_ id: UUID, direction: MergeDirection) -> Bool {
        mergeTarget(for: id, direction: direction) != nil
    }

    func mergeCustomZone(_ id: UUID, direction: MergeDirection) {
        guard let index = customZones.firstIndex(where: { $0.id == id }),
              let neighbor = mergeTarget(for: id, direction: direction) else { return }
        let zone = customZones[index]
        let minX = min(zone.x, neighbor.x)
        let minY = min(zone.y, neighbor.y)
        let maxX = max(zone.x + zone.width, neighbor.x + neighbor.width)
        let maxY = max(zone.y + zone.height, neighbor.y + neighbor.height)
        customZones[index] = CustomZone(id: zone.id, x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        customZones.removeAll { $0.id == neighbor.id }
        selectedZone = customZones.firstIndex { $0.id == id } ?? 0
        statusMessage = "Zones merged"
        persistCustomZones()
    }

    private func mergeTarget(for id: UUID, direction: MergeDirection) -> CustomZone? {
        guard let zone = customZones.first(where: { $0.id == id }) else { return nil }
        let alignmentTolerance: CGFloat = 0.012
        let maximumGap: CGFloat = 0.03
        func equal(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < alignmentTolerance }
        func adjacent(_ firstEdge: CGFloat, _ secondEdge: CGFloat) -> Bool {
            let gap = secondEdge - firstEdge
            return gap > -alignmentTolerance && gap < maximumGap
        }

        return customZones.first { other in
            guard other.id != id else { return false }
            switch direction {
            case .left:
                return adjacent(other.x + other.width, zone.x) && equal(other.y, zone.y) && equal(other.height, zone.height)
            case .right:
                return adjacent(zone.x + zone.width, other.x) && equal(other.y, zone.y) && equal(other.height, zone.height)
            case .up:
                return adjacent(other.y + other.height, zone.y) && equal(other.x, zone.x) && equal(other.width, zone.width)
            case .down:
                return adjacent(zone.y + zone.height, other.y) && equal(other.x, zone.x) && equal(other.width, zone.width)
            }
        }
    }

    func deleteCustomZone(_ id: UUID) {
        guard customZones.count > 1 else { return }
        customZones.removeAll { $0.id == id }
        selectedZone = min(selectedZone, customZones.count - 1)
        persistCustomZones()
    }

    func resetCustomZones() {
        customZones = Self.defaultCustomZones
        selectedZone = 0
        persistCustomZones()
    }

    private func normalizeCustomZones() {
        customZones = customZones.map { zone in
            CustomZone(id: zone.id, x: max(0, min(1, zone.x)), y: max(0, min(1, zone.y)), width: max(0.05, min(1, zone.width)), height: max(0.05, min(1, zone.height)))
        }
    }

    private func persistCustomZones() {
        guard let data = try? JSONEncoder().encode(customZones) else { return }
        UserDefaults.standard.set(data, forKey: customZonesKey)
    }

    func snap(to index: Int) {
        guard let display = selectedDisplay else { return }
        let zones = zoneFrames(in: display.visibleFrame)
        guard zones.indices.contains(index) else { return }
        selectedZone = index
        perform { try windowManager.moveFocusedWindow(to: zones[index]) }
    }

    func snapPrevious() {
        let next = max(0, selectedZone - 1)
        snap(to: next)
    }

    func snapNext() {
        let next = min(zoneCount - 1, selectedZone + 1)
        snap(to: next)
    }

    func maximize() {
        guard let display = selectedDisplay else { return }
        perform { try windowManager.moveFocusedWindow(to: display.visibleFrame) }
    }

    func centerWindow() {
        guard let display = selectedDisplay else { return }
        let visible = display.visibleFrame
        let width = min(1100, visible.width * 0.62)
        let height = min(900, visible.height * 0.82)
        let frame = CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        perform { try windowManager.moveFocusedWindow(to: frame) }
    }

    func applyAllVisibleWindows() {
        guard let display = selectedDisplay else { return }
        let zones = zoneFrames(in: display.visibleFrame)
        perform { try windowManager.tileVisibleWindows(into: zones) }
    }

    func zoneFrames(in frame: CGRect) -> [CGRect] {
        if layout == .custom {
            return customZones.map { zone in
                let inset = gap / 2
                return CGRect(
                    x: frame.minX + zone.x * frame.width + inset,
                    y: frame.maxY - (zone.y + zone.height) * frame.height + inset,
                    width: max(60, zone.width * frame.width - gap),
                    height: max(60, zone.height * frame.height - gap)
                )
            }
        }
        let ratios = layout.ratios
        let usableWidth = frame.width - gap * CGFloat(max(0, ratios.count - 1))
        let unit = usableWidth / ratios.reduce(0, +)
        var cursor = frame.minX
        let columns = ratios.map { ratio in
            let width = unit * ratio
            defer { cursor += width + gap }
            return CGRect(x: cursor, y: frame.minY, width: width, height: frame.height)
        }
        guard horizontalSplit else { return columns }
        let halfHeight = (frame.height - gap) / 2
        let top = columns.map { CGRect(x: $0.minX, y: frame.minY + halfHeight + gap, width: $0.width, height: halfHeight) }
        let bottom = columns.map { CGRect(x: $0.minX, y: frame.minY, width: $0.width, height: halfHeight) }
        return top + bottom
    }

    private func perform(_ action: () throws -> Void) {
        refreshPermission()
        refreshTargetApplication()
        guard hasAccessibilityPermission else {
            lastActionSucceeded = false
            statusMessage = "Accessibility permission required"
            requestPermission()
            return
        }
        do {
            try action()
            lastActionSucceeded = true
            statusMessage = "Moved \(targetApplicationName)"
        } catch {
            lastActionSucceeded = false
            statusMessage = error.localizedDescription
        }
    }
}
