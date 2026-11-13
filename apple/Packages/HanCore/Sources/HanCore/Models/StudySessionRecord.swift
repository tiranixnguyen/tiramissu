import Foundation

/// Một lần học một bộ, trên bất kỳ máy nào — khớp bảng `StudySession` trên server. Chỉ thêm, không sửa.
public struct StudySessionRecord: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let deckId: String
    /// "macos" | "ios" | … — chỉ để hiển thị lịch sử.
    public let device: String
    public let startedAt: Date
    public var endedAt: Date
    public var attempted: Int
    public var correct: Int
    public var masteredCount: Int
    public var totalCards: Int
    public var completed: Bool

    public init(
        id: String, deckId: String, device: String, startedAt: Date, endedAt: Date, attempted: Int,
        correct: Int, masteredCount: Int, totalCards: Int, completed: Bool
    ) {
        self.id = id
        self.deckId = deckId
        self.device = device
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.attempted = attempted
        self.correct = correct
        self.masteredCount = masteredCount
        self.totalCards = totalCards
        self.completed = completed
    }

    /// Tỉ lệ đúng; chưa trả lời lần nào (chỉ bấm "Đã thuộc") coi như 100%.
    public var accuracy: Double { attempted == 0 ? 1 : Double(correct) / Double(attempted) }
}
