import SwiftUI

struct ZoneEditorView: View {
    @EnvironmentObject private var model: SpanModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?

    private var selectedZone: CustomZone? {
        model.customZones.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Customize zones").font(.system(size: 18, weight: .semibold))
                    Text("Split regions apart or merge compatible neighbors.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset") { model.resetCustomZones(); selectedID = model.customZones.first?.id }
                Button("Done") { model.choose(.custom); dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(20)
            Divider()

            HStack(spacing: 0) {
                editorCanvas
                    .padding(24)
                Divider()
                inspector
                    .frame(width: 220)
                    .padding(18)
            }
        }
        .frame(width: 780, height: 510)
        .onAppear { selectedID = model.customZones.first?.id }
    }

    private var editorCanvas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen map").font(.headline)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(red: 0.07, green: 0.10, blue: 0.09), Color(red: 0.12, green: 0.15, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ForEach(Array(model.customZones.enumerated()), id: \.element.id) { index, zone in
                        Button { selectedID = zone.id } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selectedID == zone.id ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selectedID == zone.id ? Color.accentColor : Color.white.opacity(0.18), lineWidth: selectedID == zone.id ? 2 : 1)
                                VStack(spacing: 5) {
                                    Text("\(index + 1)").font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("\(Int(zone.width * 100)) × \(Int(zone.height * 100))%").font(.caption2).opacity(0.7)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: max(28, zone.width * geometry.size.width - 5), height: max(28, zone.height * geometry.size.height - 5))
                        .position(x: (zone.x + zone.width / 2) * geometry.size.width, y: (zone.y + zone.height / 2) * geometry.size.height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.16)))
            }
            .aspectRatio(32 / 9, contentMode: .fit)
            Text("Zones fill the monitor without overlap. Split or merge regions until the map fits your workflow.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedZone.map { _ in "Selected zone" } ?? "Select a zone")
                .font(.headline)
            if let zone = selectedZone {
                Label("\(Int(zone.width * 100))% wide", systemImage: "arrow.left.and.right")
                Label("\(Int(zone.height * 100))% tall", systemImage: "arrow.up.and.down")
                Divider()
                Button { model.splitCustomZone(zone.id, vertically: true) } label: {
                    Label("Split left / right", systemImage: "rectangle.split.2x1")
                }
                .buttonStyle(.bordered).frame(maxWidth: .infinity)
                .disabled(zone.width < 0.16)
                Button { model.splitCustomZone(zone.id, vertically: false) } label: {
                    Label("Split top / bottom", systemImage: "rectangle.split.1x2")
                }
                .buttonStyle(.bordered).frame(maxWidth: .infinity)
                .disabled(zone.height < 0.16)
                Divider()
                Text("Merge with neighbor").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(MergeDirection.allCases) { direction in
                        Button {
                            model.mergeCustomZone(zone.id, direction: direction)
                        } label: {
                            Label(direction.title, systemImage: direction.symbol)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!model.canMergeCustomZone(zone.id, direction: direction))
                        .help(model.canMergeCustomZone(zone.id, direction: direction) ? direction.title : "No matching neighbor on this side")
                    }
                }
                Text("A merge is available when two zones share a complete edge.")
                    .font(.caption2).foregroundStyle(.secondary)
                Divider()
                Button(role: .destructive) {
                    model.deleteCustomZone(zone.id)
                    selectedID = model.customZones.first?.id
                } label: {
                    Label("Delete zone", systemImage: "trash")
                }
                .disabled(model.customZones.count <= 1)
            } else {
                Text("Click a region in the screen map to edit it.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(model.customZones.count) zones")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
