import Foundation

/// Bộ lọc bảng xem trước ở màn Nhập từ AI.
public enum ImportFilter: Sendable, Hashable, CaseIterable {
    case all, new, existing
}

/// Chọn từ nào sẽ được thêm khi nhập JSON từ AI.
///
/// Từ đã có trong thư viện (so mặt sau qua `AnswerMatcher.normalize`, toàn bộ các bộ) mặc định
/// **bỏ tick**, từ mới mặc định tick. Chỉ các từ đã tick được gửi lên server.
public struct ImportSelection: Sendable, Hashable {
    public let words: [ImportedWord]
    /// Tên bộ đã chứa từ thứ i, `nil` nếu là từ mới.
    public let existingIn: [String?]
    /// Chỉ số các từ đang được tick.
    public private(set) var checked: Set<Int>

    public init(words: [ImportedWord], library: ContentSnapshot) {
        var deckOf: [String: String] = [:]
        for deck in library.decks {
            for card in deck.cards {
                let key = AnswerMatcher.normalize(card.back)
                if deckOf[key] == nil { deckOf[key] = deck.name }
            }
        }
        let found = words.map { deckOf[AnswerMatcher.normalize($0.back)] }
        self.words = words
        existingIn = found
        checked = Set(found.indices.filter { found[$0] == nil })
    }

    public func isExisting(_ i: Int) -> Bool { existingIn[i] != nil }
    public func isChecked(_ i: Int) -> Bool { checked.contains(i) }

    /// Chỉ số các từ hiện ra với bộ lọc, giữ thứ tự trong JSON.
    public func indices(_ filter: ImportFilter) -> [Int] {
        words.indices.filter {
            switch filter {
            case .all: true
            case .new: !isExisting($0)
            case .existing: isExisting($0)
            }
        }
    }

    public func count(_ filter: ImportFilter) -> Int { indices(filter).count }

    public var selectedCount: Int { checked.count }
    /// Số từ đã có mà đang bỏ qua (không tick).
    public var skippedExistingCount: Int { indices(.existing).filter { !isChecked($0) }.count }

    /// Từ sẽ gửi, theo thứ tự trong JSON.
    public var selectedWords: [ImportedWord] { words.indices.filter(isChecked).map { words[$0] } }

    /// Mọi từ đang hiện đều đã tick (rỗng thì `false`).
    public func allChecked(_ filter: ImportFilter) -> Bool {
        let shown = indices(filter)
        return !shown.isEmpty && shown.allSatisfy(isChecked)
    }

    public mutating func toggle(_ i: Int) {
        guard words.indices.contains(i) else { return }
        if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
    }

    /// Tick/bỏ tick mọi từ đang hiện; từ bị lọc ẩn giữ nguyên.
    public mutating func setAll(_ on: Bool, _ filter: ImportFilter) {
        let shown = indices(filter)
        if on { checked.formUnion(shown) } else { checked.subtract(shown) }
    }
}
