import SwiftUI
import SwiftData
import MapKit

/// 地图视图：所有带位置的日记以标记展示，点选查看详情
struct EntriesMapView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    @State private var selectedID: UUID?
    @State private var position: MapCameraPosition = .automatic

    private var located: [JournalEntry] {
        entries.filter(\.hasLocation)
    }

    var body: some View {
        NavigationStack {
            Group {
                if located.isEmpty {
                    ContentUnavailableView {
                        Label("还没有位置记录", systemImage: "map")
                    } description: {
                        Text("写日记时添加位置，就能在地图上回顾你的足迹")
                    }
                } else {
                    map
                }
            }
            .navigationTitle("地图")
            .navigationDestination(for: JournalEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .onAppear(perform: fitCamera)
    }

    private var map: some View {
        Map(position: $position, selection: $selectedID) {
            ForEach(located) { entry in
                if let coordinate = entry.coordinate {
                    Marker(entry.displayName, systemImage: "book.closed.fill", coordinate: coordinate)
                        .tag(entry.id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { selectionCard }
    }

    /// 底部选中日记卡片
    @ViewBuilder
    private var selectionCard: some View {
        if let id = selectedID,
           let entry = located.first(where: { $0.id == id }) {
            NavigationLink(value: entry) {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(subtitle(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func subtitle(for entry: JournalEntry) -> String {
        var parts: [String] = [DateFormatters.timelineHeader(for: entry.createdAt)]
        if let locationName = entry.locationName {
            parts.append(locationName)
        }
        return parts.joined(separator: " · ")
    }

    /// 让所有标记都进入视野
    private func fitCamera() {
        let coordinates = located.compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pad: Double = 4_000
            let item = MKMapRect(
                x: point.x - pad,
                y: point.y - pad,
                width: pad * 2,
                height: pad * 2
            )
            rect = rect.union(item)
        }
        position = .rect(rect)
    }
}
