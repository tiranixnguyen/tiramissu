/// Tiến trình một thẻ — **chỉ sống trong lượt học**, không lưu.
public struct CardProgress: Sendable, Hashable {
    public var box: Int
    public var streak: Int
    public var mastered: Bool

    public init(box: Int = 0, streak: Int = 0, mastered: Bool = false) {
        self.box = box
        self.streak = streak
        self.mastered = mastered
    }
}

/// Kết quả của thẻ vừa trả lời.
public enum AnswerOutcome: Sendable, Hashable {
    /// Chưa trả lời — đang chờ nhập (thẻ tự chấm: chờ lật / chờ tự chấm).
    case pending
    /// Gõ đúng, hoặc thẻ tự chấm bấm "Nhớ".
    case correct
    /// Gõ sai / "Xem đáp án", hoặc thẻ tự chấm bấm "Chưa nhớ".
    case wrong
    /// Người học tự bấm "Đã thuộc" thay vì gõ đáp án.
    case known
}

/// Lượt học của bộ đang mở (chỉ một lượt tại một thời điểm).
struct DeckRuntime {
    var cardState: [CardProgress]
    /// Chỉ số thẻ chờ hỏi. Thẻ đang hiển thị đã bị lấy ra khỏi hàng đợi.
    var activeQueue: [Int]
    var correctCount = 0
    var attemptedCount = 0
    var masteredCount = 0
}
