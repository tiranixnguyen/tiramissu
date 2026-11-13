/// Loại bộ từ (kỹ năng). `rawValue` là giá trị lưu trên server/cache, `label` là nhãn hiển thị.
public enum DeckType: String, Codable, Sendable, Hashable, CaseIterable {
    case listening, speaking, reading, writing, grammar

    public var label: String {
        switch self {
        case .listening: "듣기"
        case .speaking: "말하기"
        case .reading: "읽기"
        case .writing: "쓰기"
        case .grammar: "문법"
        }
    }

    /// Giá trị lạ (server mới hơn app) hoặc thiếu → `nil`, coi như chưa phân loại.
    public init?(key: String?) {
        guard let key, let value = DeckType(rawValue: key) else { return nil }
        self = value
    }
}
