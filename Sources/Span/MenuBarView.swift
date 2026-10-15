import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: SpanModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "rectangle.split.3x1.fill").foregroundStyle(Color.accentColor)
                Text("Span").font(.headline)
                Spacer()
                Text(model.layout.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Group {
                if model.layout == .custom {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: min(4, model.customZones.count)), spacing: 5) {
                        ForEach(model.customZones.indices, id: \.self) { index in menuZone(index) }
                    }
                } else {
                    HStack(spacing: 7) {
                        ForEach(Array(model.layout.ratios.enumerated()), id: \.offset) { index, ratio in
                            VStack(spacing: 5) {
                                menuZone(index)
                                if model.horizontalSplit { menuZone(index + model.layout.ratios.count) }
                            }
                            .frame(width: ratio * 40)
                        }
                    }
                }
            }
            Divider()
            Button("Tile open windows") { model.applyAllVisibleWindows() }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            HStack {
                Button("Show Span") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }.font(.caption)
        }
        .padding(14).frame(width: 320)
    }

    private func menuZone(_ index: Int) -> some View {
        Button { model.snap(to: index) } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(index == model.selectedZone ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12))
                .overlay(Text("\(index + 1)").font(.caption).foregroundStyle(index == model.selectedZone ? Color.accentColor : .secondary))
        }
        .buttonStyle(.plain).frame(height: model.horizontalSplit ? 34 : 54)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: SpanModel

    var body: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    HStack {
                        Text(model.hasAccessibilityPermission ? "Granted" : "Required").foregroundStyle(model.hasAccessibilityPermission ? .green : .orange)
                        if !model.hasAccessibilityPermission { Button("Request") { model.requestPermission() } }
                    }
                }
                Text("Span uses Accessibility only to read and resize the frontmost app window.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Shortcuts") {
                LabeledContent("Move between zones", value: "Control–Option–Arrow")
                LabeledContent("Select zone", value: "Control–Option–1…4")
                LabeledContent("Maximize", value: "Control–Option–Return")
            }
        }
        .formStyle(.grouped).padding()
        .onAppear { model.refreshPermission() }
    }
}
