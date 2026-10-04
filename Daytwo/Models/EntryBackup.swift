import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 单篇日记的备份结构（与持久化模型解耦，方便版本演进）
struct EntryBackup: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
    let modifiedAt: Date
    let favorite: Bool
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let locality: String?

    init(from entry: JournalEntry) {
        self.id = entry.id
        self.title = entry.title
        self.content = entry.content
        self.createdAt = entry.createdAt
        self.modifiedAt = entry.modifiedAt
        self.favorite = entry.favorite
        self.latitude = entry.latitude
        self.longitude = entry.longitude
        self.locationName = entry.locationName
        self.locality = entry.locality
    }

    init(
        id: UUID,
        title: String,
        content: String,
        createdAt: Date,
        modifiedAt: Date,
        favorite: Bool,
        latitude: Double?,
        longitude: Double?,
        locationName: String?,
        locality: String?
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.favorite = favorite
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.locality = locality
    }

    func makeEntry() -> JournalEntry {
        JournalEntry(
            id: id,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            title: title,
            content: content,
            favorite: favorite,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            locality: locality
        )
    }

    func apply(to entry: JournalEntry) {
        entry.title = title
        entry.content = content
        entry.createdAt = createdAt
        entry.modifiedAt = modifiedAt
        entry.favorite = favorite
        entry.latitude = latitude
        entry.longitude = longitude
        entry.locationName = locationName
        entry.locality = locality
    }
}

/// JSON 备份文档（用于系统导出面板）
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var entries: [EntryBackup]

    init(entries: [EntryBackup]) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        entries = try JSONDecoder().decode([EntryBackup].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }

    static func decode(from data: Data) throws -> [EntryBackup] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([EntryBackup].self, from: data)
    }
}
