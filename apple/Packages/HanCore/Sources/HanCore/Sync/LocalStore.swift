/// Nơi lưu hàng đợi offline + cache trên máy. App cài bằng SwiftData; test dùng `InMemoryLocalStore`.
/// Mọi hàm không ném: lỗi lưu là việc của lớp cài đặt (ghi log), đồng bộ cứ chạy tiếp.
public protocol LocalStore: Sendable {
    func pendingFlags() async -> [FlagChange]
    func removePendingFlags(_ sent: [FlagChange]) async
    func pendingSessions() async -> [StudySessionRecord]
    func removePendingSessions(ids: [String]) async
    /// Cache nội dung vừa tải (đã áp lại cờ còn chờ).
    func saveContent(_ content: ContentSnapshot) async
    /// Lịch sử học của mọi máy vừa tải về.
    func saveSessions(_ sessions: [StudySessionRecord]) async
}
