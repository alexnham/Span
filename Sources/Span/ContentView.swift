import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: SpanModel
    @State private var hoverZone: Int?
    @State private var showingZoneEditor = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            monitorSection
                            controls
                        }
                        .padding(28)
                    }
                }
            }
        }
        .tint(Color(red: 0.55, green: 0.72, blue: 0.95))
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            model.refreshDisplays()
        }
        .sheet(isPresented: $showingZoneEditor) {
            ZoneEditorView()
                .environmentObject(model)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: 31, height: 31)
                    .background(Color(red: 0.62, green: 0.77, blue: 0.98), in: RoundedRectangle(cornerRadius: 9))
                Text("Span").font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 24)

            Text("Layouts")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 7)

            ForEach(ZoneLayout.allCases) { layout in
                Button { model.choose(layout) } label: {
                    HStack(spacing: 11) {
                        MiniLayout(layout: layout)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layout.rawValue).font(.system(size: 12, weight: .medium))
                            Text(layout.detail).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10).frame(height: 49)
                    .background(model.layout == layout ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 7)
            }

            Spacer()

            VStack(spacing: 7) {
                Label(model.hasAccessibilityPermission ? "Window control ready" : "Permission needed", systemImage: model.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.hasAccessibilityPermission ? .green : .orange)
                    .font(.caption)
                Button("Open settings") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                    .buttonStyle(.link).font(.caption)
            }
            .frame(maxWidth: .infinity).padding(16)
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ultrawide workspace").font(.system(size: 19, weight: .semibold))
                Text(displaySubtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            statusPill
            Button("Tile open windows") { model.applyAllVisibleWindows() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(.horizontal, 26).frame(height: 78)
    }

    private var displaySubtitle: String {
        guard let display = model.selectedDisplay else { return "No display found" }
        return "\(display.name)  ·  \(display.resolution)"
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(model.lastActionSucceeded ? Color.green : Color.orange).frame(width: 6, height: 6)
            Text(model.statusMessage).font(.caption)
        }
        .foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 7)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    private var monitorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose a zone").font(.system(size: 15, weight: .semibold))
                    Text("Click a zone to move the frontmost window there.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if model.layout != .custom { model.makeCustomFromCurrent() }
                    showingZoneEditor = true
                } label: {
                    Label("Edit zones", systemImage: "square.split.2x2")
                }
                Picker("Display", selection: $model.selectedDisplayID) {
                    ForEach(model.displays) { display in Text(display.name).tag(Optional(display.id)) }
                }
                .labelsHidden().frame(maxWidth: 220)
            }

            MonitorPreview(layout: model.layout, customZones: model.customZones, selectedZone: model.selectedZone, hoverZone: hoverZone, gap: model.gap, horizontalSplit: model.horizontalSplit) { index in
                model.snap(to: index)
            } onHover: { index in
                hoverZone = index
            }
        }
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    HStack { Text("Zone spacing"); Spacer(); Text("\(Int(model.gap)) px").foregroundStyle(.secondary) }
                    Slider(value: $model.gap, in: 0...28, step: 1)
                    if model.layout == .custom {
                        Button { showingZoneEditor = true } label: { Label("Customize zones", systemImage: "pencil.and.outline") }
                            .buttonStyle(.bordered)
                    } else {
                        Toggle("Split horizontally", isOn: Binding(get: { model.horizontalSplit }, set: { model.setHorizontalSplit($0) }))
                        Text("Adds top and bottom zones across the display.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Divider()
                    shortcut("Previous zone", keys: "⌃⌥←")
                    shortcut("Next zone", keys: "⌃⌥→")
                    shortcut("Maximize", keys: "⌃⌥↩")
                }.padding(6)
            } label: { Label("Arrangement", systemImage: "slider.horizontal.3") }

            GroupBox {
                VStack(alignment: .leading, spacing: 13) {
                    permissionRow
                    HStack {
                        Text("Target app").foregroundStyle(.secondary)
                        Spacer()
                        Text(model.targetApplicationName).lineLimit(1)
                    }
                    Divider()
                    Button { model.centerWindow() } label: { Label("Center frontmost window", systemImage: "rectangle.center.inset.filled") }
                        .buttonStyle(.plain)
                    Button { model.maximize() } label: { Label("Fill current display", systemImage: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.plain)
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            } label: { Label("Window control", systemImage: "macwindow") }
        }
        .font(.system(size: 12))
    }

    private func shortcut(_ title: String, keys: String) -> some View {
        HStack { Text(title); Spacer(); Text(keys).font(.system(size: 10, design: .rounded)).padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary, in: RoundedRectangle(cornerRadius: 5)) }
    }

    @ViewBuilder private var permissionRow: some View {
        if model.hasAccessibilityPermission {
            Label("Accessibility access granted", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Accessibility access required", systemImage: "lock.trianglebadge.exclamationmark")
                Button("Grant access") { model.requestPermission() }.buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct MiniLayout: View {
    let layout: ZoneLayout
    var body: some View {
        Group {
            if layout == .custom {
                Image(systemName: "square.grid.3x3.topleft.filled").frame(width: 30, height: 18)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(layout.ratios.enumerated()), id: \.offset) { _, ratio in
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.secondary.opacity(0.45)).frame(width: ratio * 8, height: 18)
                    }
                }
            }
        }
        .padding(4).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct MonitorPreview: View {
    let layout: ZoneLayout
    let customZones: [CustomZone]
    let selectedZone: Int
    let hoverZone: Int?
    let gap: CGFloat
    let horizontalSplit: Bool
    let onSelect: (Int) -> Void
    let onHover: (Int?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                if layout == .custom {
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(customZones.enumerated()), id: \.element.id) { index, zone in
                            customZoneButton(index: index)
                                .frame(
                                    width: max(20, zone.width * (geometry.size.width - 28) - max(4, gap * 0.45)),
                                    height: max(20, zone.height * (geometry.size.height - 28) - max(4, gap * 0.45))
                                )
                                .position(
                                    x: 14 + (zone.x + zone.width / 2) * (geometry.size.width - 28),
                                    y: 14 + (zone.y + zone.height / 2) * (geometry.size.height - 28)
                                )
                        }
                    }
                } else {
                    let total = layout.ratios.reduce(0, +)
                    let innerWidth = geometry.size.width - 28 - CGFloat(layout.ratios.count - 1) * max(4, gap * 0.45)
                    HStack(spacing: max(4, gap * 0.45)) {
                        ForEach(Array(layout.ratios.enumerated()), id: \.offset) { index, ratio in
                            VStack(spacing: horizontalSplit ? max(4, gap * 0.45) : 0) {
                                zoneButton(index: index)
                                if horizontalSplit { zoneButton(index: index + layout.ratios.count) }
                            }
                            .frame(width: innerWidth * ratio / total)
                        }
                    }
                    .padding(14)
                }
            }
            .frame(height: 245)
            .background(
                LinearGradient(colors: [Color(red: 0.08, green: 0.11, blue: 0.10), Color(red: 0.12, green: 0.15, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.15)))
            Rectangle().fill(.secondary.opacity(0.5)).frame(width: 42, height: 13).clipShape(.trapezoid)
            Capsule().fill(.secondary.opacity(0.55)).frame(width: 126, height: 6)
        }
    }

    private func zoneButton(index: Int) -> some View {
        Button { onSelect(index) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(index == selectedZone ? Color.accentColor.opacity(0.28) : Color.white.opacity(hoverZone == index ? 0.12 : 0.07))
                RoundedRectangle(cornerRadius: 7)
                    .stroke(index == selectedZone ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.15), lineWidth: 1)
                VStack(spacing: 5) {
                    Image(systemName: index == selectedZone ? "macwindow.on.rectangle" : "rectangle")
                    Text("Zone \(index + 1)").font(.caption2)
                }.foregroundStyle(index == selectedZone ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { inside in onHover(inside ? index : nil) }
    }

    private func customZoneButton(index: Int) -> some View {
        zoneButton(index: index)
    }
}

private extension Shape where Self == UnevenRoundedRectangle {
    static var trapezoid: UnevenRoundedRectangle { UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0) }
}
