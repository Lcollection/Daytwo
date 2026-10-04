import SwiftUI
import SwiftData

/// 位置分类：按地点名称分组浏览日记
struct LocationListView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    private var groups: [(name: String, entries: [JournalEntry])] {
        let withLocation = entries.filter { !($0.locationName ?? "").isEmpty }
        let dict = Dictionary(grouping: withLocation) { $0.locationName ?? "未知位置" }
        return dict
            .map { (name: $0.key, entries: $0.value) }
            .sorted { $0.entries.count > $1.entries.count }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("暂无位置信息", systemImage: "mappin.slash")
                    } description: {
                        Text("写日记时添加位置，即可按地点浏览")
                    }
                } else {
                    List {
                        ForEach(groups, id: \.name) { group in
                            NavigationLink {
                                EntryListView(
                                    title: group.name,
                                    entries: group.entries,
                                    emptyIcon: "mappin",
                                    emptyMessage: "该位置暂无日记"
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.body.weight(.medium))
                                        Text("\(group.entries.count) 篇日记")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("位置")
        }
    }
}

/// 通用的日记列表（收藏、某个位置下的日记）
struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext

    let title: String
    let entries: [JournalEntry]
    let emptyIcon: String
    let emptyMessage: String

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label(title, systemImage: emptyIcon)
                } description: {
                    Text(emptyMessage)
                }
            } else {
                List {
                    ForEach(entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .contextMenu {
                            Button {
                                entry.favorite.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    entry.favorite ? "取消收藏" : "收藏",
                                    systemImage: entry.favorite ? "star.slash" : "star"
                                )
                            }
                            Divider()
                            Button(role: .destructive) {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
}
