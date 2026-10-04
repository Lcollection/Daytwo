import SwiftUI
import SwiftData
import MarkdownUI

/// 日记详情：渲染后的 Markdown + 元信息
struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: JournalEntry

    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.createdAt, formatter: DateFormatters.full)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(.title2.weight(.bold))
                }

                if entry.hasLocation {
                    locationChip
                }

                Divider()

                Markdown(entry.content)
                    .markdownTheme(.gitHub)

                Spacer(minLength: 40)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(DateFormatters.timelineHeader(for: entry.createdAt))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("编辑", systemImage: "square.and.pencil")
                    }
                    Button {
                        entry.favorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            entry.favorite ? "取消收藏" : "收藏",
                            systemImage: entry.favorite ? "star.slash" : "star"
                        )
                    }
                    ShareLink(item: entry.exportMarkdown()) {
                        Label("分享 Markdown", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ComposerView(entry: entry)
        }
        .confirmationDialog(
            "确定删除这篇日记吗？此操作不可撤销。",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var locationChip: some View {
        if let url = entry.mapURL, let name = entry.locationName {
            Link(destination: url) {
                Label(name, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .chipStyle()
            }
            .help("在地图中查看")
        } else if let name = entry.locationName {
            Label(name, systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .chipStyle()
        }
    }
}
