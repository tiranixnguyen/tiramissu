/// Nhóm bộ từ (Sep1/Sep2/… hoặc nhóm người học tự tạo).
public struct VocabGroup: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Một bộ từ trong lúc học.
public struct StudyDeck: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let group: String?
    /// Chỉ bộ thật mới có loại; `nil` = chưa phân loại.
    public let type: DeckType?
    /// Tài liệu (chuỗi tự do); `nil` = chưa chọn.
    public let source: String?
    /// Mô tả ngắn, có thể chứa link `http(s)://`.
    public let description: String?
    /// Deck ảo (⭐, 漢, 📖, 🔀) dựng động từ deck gốc: không có trên server, không ghi lịch sử học.
    public let isVirtual: Bool
    public let words: [StudyWord]

    public init(
        id: String, name: String, words: [StudyWord], group: String? = nil, type: DeckType? = nil,
        source: String? = nil, description: String? = nil, isVirtual: Bool = false
    ) {
        self.id = id
        self.name = name
        self.words = words
        self.group = group
        self.type = type
        self.source = source
        self.description = description
        self.isVirtual = isVirtual
    }
}

/// Dữ liệu đã dựng sẵn cho `StudyEngine`.
public struct StudyCatalog: Sendable, Hashable {
    public var decks: [StudyDeck]
    public var vocabGroups: [VocabGroup]
    public var markedIds: Set<String>
    public var hanjaIds: Set<String>
    public var passageIds: Set<String>
    /// Mọi clip nghe, dựng sẵn thành thẻ — nguồn của bộ ảo 🎧.
    public var clipWords: [StudyWord]

    public init(
        decks: [StudyDeck] = [], vocabGroups: [VocabGroup] = [], markedIds: Set<String> = [],
        hanjaIds: Set<String> = [], passageIds: Set<String> = [], clipWords: [StudyWord] = []
    ) {
        self.clipWords = clipWords
        self.decks = decks
        self.vocabGroups = vocabGroups
        self.markedIds = markedIds
        self.hanjaIds = hanjaIds
        self.passageIds = passageIds
    }
}

extension Clip {
    /// Thẻ nghe: mặt trước là nghĩa (hoặc lời nhắc), mặt sau là câu Hàn cần chép lại.
    public var studyWord: StudyWord {
        StudyWord(
            id: id, front: translation ?? "🎧 Nghe và chép lại", back: transcript, note: note,
            typeAnswer: true, kind: .clip(audioId: audioId))
    }
}

extension ContentSnapshot {
    /// Dựng dữ liệu cho engine: sắp nhóm/bộ/thẻ theo `position` (ổn định khi trùng).
    public func buildStudyCatalog() -> StudyCatalog {
        var catalog = StudyCatalog()
        catalog.vocabGroups = sortedStable(groups, by: \.position).map { VocabGroup(id: $0.id, name: $0.name) }

        let sortedClips = clips.enumerated()
            .sorted { ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset) }
            .map(\.element)
        catalog.clipWords = sortedClips.map(\.studyWord)
        for c in sortedClips where c.marked { catalog.markedIds.insert(c.id) }

        for d in sortedStable(decks, by: \.position) {
            var words: [StudyWord] = []
            for c in sortedStable(d.cards, by: \.position) {
                if c.marked { catalog.markedIds.insert(c.id) }
                if c.hanja { catalog.hanjaIds.insert(c.id) }
                if c.passage { catalog.passageIds.insert(c.id) }
                words.append(
                    StudyWord(
                        id: c.id, front: c.front, back: c.back, hint: c.hint, note: c.note,
                        altAnswers: c.altAnswers.isEmpty ? nil : c.altAnswers,
                        typeAnswer: c.typeAnswer, audio: c.audio))
            }
            words.append(contentsOf: sortedClips.filter { $0.deckId == d.id }.map(\.studyWord))
            catalog.decks.append(
                StudyDeck(
                    id: d.id, name: d.name, words: words, group: d.groupId, type: d.type,
                    source: d.source, description: d.description))
        }
        return catalog
    }
}

/// `sort` của Swift không đảm bảo ổn định → sắp theo (khoá, vị trí gốc).
private func sortedStable<T>(_ items: [T], by key: KeyPath<T, Int>) -> [T] {
    items.enumerated()
        .sorted { ($0.element[keyPath: key], $0.offset) < ($1.element[keyPath: key], $1.offset) }
        .map(\.element)
}
