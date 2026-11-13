/// Trường của thẻ gắn được file nghe.
public enum CardField: String, Sendable, Hashable, CaseIterable {
    case front = "frontAudioId"
    case back = "backAudioId"
    case hint = "hintAudioId"
    case note = "noteAudioId"

    public var label: String {
        switch self {
        case .front: "mặt trước"
        case .back: "mặt sau"
        case .hint: "gợi ý"
        case .note: "giải thích"
        }
    }
}

/// Id file nghe của từng trường (rỗng = không có).
public struct CardAudio: Sendable, Hashable {
    public var front: String?
    public var back: String?
    public var hint: String?
    public var note: String?

    public static let none = CardAudio()

    public init(front: String? = nil, back: String? = nil, hint: String? = nil, note: String? = nil) {
        self.front = Self.clean(front)
        self.back = Self.clean(back)
        self.hint = Self.clean(hint)
        self.note = Self.clean(note)
    }

    public var isEmpty: Bool { self == .none }

    public subscript(field: CardField) -> String? {
        switch field {
        case .front: front
        case .back: back
        case .hint: hint
        case .note: note
        }
    }

    private static func clean(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return id
    }
}
