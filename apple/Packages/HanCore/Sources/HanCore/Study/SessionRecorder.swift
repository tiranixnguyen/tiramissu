import Foundation

/// Id ngẫu nhiên 128 bit dạng hex — do máy sinh để gửi lại nhiều lần không tạo bản ghi trùng.
public func newSessionId() -> String {
    var rng = SystemRandomNumberGenerator()
    return (0..<16).map { _ in
        let byte = UInt8.random(in: 0...255, using: &rng)
        return (byte < 16 ? "0" : "") + String(byte, radix: 16)
    }.joined()
}

/// Ghi lại các lần học một bộ (`StudySessionRecord`). Không biết gì về `StudyEngine`: lớp bọc ngoài
/// (AppModel) gọi `didAnswer` sau mỗi câu trả lời và `abandon` khi đổi bộ/nhóm/học lại.
///
/// - Lần học bắt đầu ở **câu trả lời đầu tiên** (mở bộ rồi đổi đi ngay thì không ghi gì).
/// - Kết thúc khi thuộc hết bộ (`completed`) hoặc bị bỏ dở (đổi bộ/nhóm/học lại/tắt app).
/// - Bộ ảo (⭐/漢/📖/🔀) không ghi.
/// - `draft` là bản nháp sau mỗi câu để lưu xuống máy; lần mở app sau chốt bằng `finalizeDraft`.
public final class SessionRecorder {
    public private(set) var draft: StudySessionRecord?

    private let device: String
    private let clock: Clock
    private let makeId: @Sendable () -> String

    public init(device: String, clock: @escaping Clock = systemClock, makeId: @escaping @Sendable () -> String = newSessionId) {
        self.device = device
        self.clock = clock
        self.makeId = makeId
    }

    /// Gọi sau mỗi câu trả lời (kể cả "Đã thuộc", "Xem đáp án", tự chấm, "Đã trả lời đúng?").
    /// Trả bản ghi **hoàn tất** nếu câu này làm thuộc hết bộ — lúc đó `draft` được xoá.
    @discardableResult
    public func didAnswer(_ state: StudySessionState) -> StudySessionRecord? {
        guard let deckId = state.currentDeckId, !isVirtualDeckId(deckId) else { return nil }
        let now = clock()

        var record =
            if let d = draft, d.deckId == deckId {
                d
            } else {
                StudySessionRecord(
                    id: makeId(), deckId: deckId, device: device, startedAt: now, endedAt: now,
                    attempted: 0, correct: 0, masteredCount: 0, totalCards: state.totalCount, completed: false)
            }
        record.endedAt = now
        record.attempted = state.attemptedCount
        record.correct = state.correctCount
        record.masteredCount = state.masteredCount
        record.totalCards = state.totalCount

        if state.totalCount > 0 && state.masteredCount >= state.totalCount {
            record.completed = true
            draft = nil
            return record
        }
        draft = record
        return nil
    }

    /// Đổi bộ/nhóm/học lại: chốt lần học đang dở (nếu có) thành "bỏ dở", kết thúc ở câu trả lời cuối.
    @discardableResult
    public func abandon() -> StudySessionRecord? {
        defer { draft = nil }
        guard let d = draft else { return nil }
        return Self.finalizeDraft(d, lastAnswerAt: d.endedAt)
    }

    /// Chốt nháp còn sót (tắt app giữa chừng) thành "học dở" với giờ kết thúc = câu trả lời cuối.
    public static func finalizeDraft(_ draft: StudySessionRecord, lastAnswerAt: Date) -> StudySessionRecord {
        var r = draft
        r.endedAt = lastAnswerAt
        r.completed = false
        return r
    }
}
