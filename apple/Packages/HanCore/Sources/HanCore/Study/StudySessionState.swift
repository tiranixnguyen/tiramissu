/// Ảnh chụp bất biến của lượt học để UI vẽ — UI không cầm `StudyEngine`.
public struct StudySessionState: Sendable, Hashable {
    public var vocabGroups: [VocabGroup]
    public var currentVocabGroup: String
    public var currentDeckId: String?
    public var currentWord: StudyWord?
    public var currentProgress: CardProgress?
    public var outcome: AnswerOutcome
    public var canOverride: Bool
    public var overridden: Bool
    public var flipped: Bool
    /// Tăng mỗi lần nạp một lượt hỏi mới — UI dựa vào đây để dọn ô nhập.
    public var cardSerial: Int
    public var correctCount: Int
    public var attemptedCount: Int
    public var masteredCount: Int
    public var totalCount: Int
    public var remainingInRound: Int
    public var isCompleted: Bool
    public var currentIsMarked: Bool
    public var currentIsHanja: Bool
    public var currentIsPassage: Bool
    public var markedCount: Int
    public var hanjaCount: Int
    public var passageCount: Int

    public var answered: Bool { outcome != .pending }
    public var progress: Double { totalCount == 0 ? 0 : Double(masteredCount) / Double(totalCount) }
}
