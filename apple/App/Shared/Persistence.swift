import Foundation
import HanCore
import SwiftData

/// Một mục cache dạng JSON blob (khoá → dữ liệu). Giữ mô hình lưu đơn giản: toàn bộ cấu trúc dữ liệu
/// đã được `HanCore` định nghĩa là `Codable`, SwiftData chỉ làm chỗ chứa bền vững.
@Model
final class CacheEntry {
    @Attribute(.unique) var key: String
    var data: Data

    init(key: String, data: Data) {
        self.key = key
        self.data = data
    }
}

/// Lưu trữ trên máy: cache nội dung, lịch sử học, hàng đợi gửi lên server, nháp lần học.
/// Cài `LocalStore` cho `SyncEngine`.
@ModelActor
actor Persistence: LocalStore {
    private enum Key {
        static let content = "content"
        static let history = "history"
        static let flags = "pendingFlags"
        static let sessions = "pendingSessions"
        static let draft = "draft"
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        if let c = try? ModelContainer(for: CacheEntry.self, configurations: config) { return c }
        // Ổ đĩa lỗi: vẫn chạy được (không lưu) thay vì chết ngay lúc mở app.
        return try! ModelContainer(
            for: CacheEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: Đọc/ghi blob

    private func read<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
        let descriptor = FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == key })
        guard let entry = try? modelContext.fetch(descriptor).first else { return nil }
        return try? HanJSON.makeDecoder().decode(T.self, from: entry.data)
    }

    private func write<T: Encodable>(_ key: String, _ value: T?) {
        let descriptor = FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == key })
        let existing = try? modelContext.fetch(descriptor).first
        guard let value, let data = try? HanJSON.makeEncoder().encode(value) else {
            if let existing { modelContext.delete(existing) }
            try? modelContext.save()
            return
        }
        if let existing {
            existing.data = data
        } else {
            modelContext.insert(CacheEntry(key: key, data: data))
        }
        try? modelContext.save()
    }

    // MARK: Ngoài LocalStore (AppModel dùng)

    func loadContent() -> ContentSnapshot? { read(Key.content) }
    func loadHistory() -> [StudySessionRecord] { read(Key.history) ?? [] }
    func loadDraft() -> StudySessionRecord? { read(Key.draft) }
    func saveDraft(_ draft: StudySessionRecord?) { write(Key.draft, draft) }

    func enqueue(flag: FlagChange) {
        write(Key.flags, (read(Key.flags, as: [FlagChange].self) ?? []) + [flag])
    }

    func enqueue(session: StudySessionRecord) {
        write(Key.sessions, (read(Key.sessions, as: [StudySessionRecord].self) ?? []) + [session])
    }

    // MARK: LocalStore

    func pendingFlags() -> [FlagChange] { read(Key.flags) ?? [] }

    func removePendingFlags(_ sent: [FlagChange]) {
        var all = read(Key.flags, as: [FlagChange].self) ?? []
        for s in sent {
            if let i = all.firstIndex(of: s) { all.remove(at: i) }
        }
        write(Key.flags, all)
    }

    func pendingSessions() -> [StudySessionRecord] { read(Key.sessions) ?? [] }

    func removePendingSessions(ids: [String]) {
        let all = read(Key.sessions, as: [StudySessionRecord].self) ?? []
        write(Key.sessions, all.filter { !ids.contains($0.id) })
    }

    func saveContent(_ content: ContentSnapshot) { write(Key.content, content) }
    func saveSessions(_ sessions: [StudySessionRecord]) { write(Key.history, sessions) }
}
