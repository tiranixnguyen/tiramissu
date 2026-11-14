/// Một thẻ trong lúc học. Bất biến về nội dung: đổi nội dung → dựng lại danh sách rồi đưa vào
/// `StudyEngine.replaceContent`.
public struct StudyWord: Sendable, Hashable, Identifiable {
    /// Thẻ chữ thường, hay thẻ nghe (clip: nghe rồi chép chính tả câu Hàn).
    public enum Kind: Sendable, Hashable {
        case card
        case clip(audioId: String)
    }

    /// Id thẻ trên server. Thẻ trong bộ ảo giữ id của thẻ gốc.
    public let id: String
    /// Mặt trước — câu hỏi (thường là nghĩa tiếng Việt).
    public let front: String
    /// Mặt sau — đáp án (thường là từ tiếng Hàn).
    public let back: String
    public let hint: String?
    /// Giải thích (Markdown), hiện sau khi lộ mặt sau.
    public let note: String?
    public let altAnswers: [String]?
    /// `true` = gõ đáp án rồi chấm; `false` = thẻ tự chấm.
    public let typeAnswer: Bool
    public let audio: CardAudio
    public let kind: Kind

    public init(
        id: String, front: String, back: String, hint: String? = nil, note: String? = nil,
        altAnswers: [String]? = nil, typeAnswer: Bool = false, audio: CardAudio = .none, kind: Kind = .card
    ) {
        self.kind = kind
        self.id = id
        self.front = front
        self.back = back
        self.hint = hint
        self.note = note
        self.altAnswers = altAnswers
        self.typeAnswer = typeAnswer
        self.audio = audio
    }

    /// So khớp thô (chưa chuẩn hoá) — việc chấm thật nằm ở `StudyEngine` + `AnswerMatcher`.
    public func matches(_ answer: String) -> Bool {
        answer == back || (altAnswers?.contains(answer) ?? false)
    }
}
