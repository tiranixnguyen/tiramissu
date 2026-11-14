import Foundation

/// Nội dung học lấy từ server (`GET /content`), cũng là định dạng cache trên máy.
public struct ContentSnapshot: Codable, Sendable, Hashable {
    public var groups: [ContentGroup]
    public var decks: [ContentDeck]
    public var clips: [Clip]

    public init(groups: [ContentGroup] = [], decks: [ContentDeck] = [], clips: [Clip] = []) {
        self.groups = groups
        self.decks = decks
        self.clips = clips
    }

    private enum CodingKeys: String, CodingKey { case groups, decks, clips }

    /// Cache/server cũ chưa có `clips` → rỗng.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = try c.decode([ContentGroup].self, forKey: .groups)
        decks = try c.decode([ContentDeck].self, forKey: .decks)
        clips = try c.decodeIfPresent([Clip].self, forKey: .clips) ?? []
    }

    /// Thay (hoặc thêm) một clip theo id.
    public func upsertingClip(_ clip: Clip) -> ContentSnapshot {
        var copy = self
        if let i = copy.clips.firstIndex(where: { $0.id == clip.id }) {
            copy.clips[i] = clip
        } else {
            copy.clips.append(clip)
        }
        return copy
    }

    public func removingClip(_ clipId: String) -> ContentSnapshot {
        var copy = self
        copy.clips.removeAll { $0.id == clipId }
        return copy
    }

    /// Thay (hoặc thêm) một nhóm theo id.
    public func upsertingGroup(_ group: ContentGroup) -> ContentSnapshot {
        var copy = self
        if let i = copy.groups.firstIndex(where: { $0.id == group.id }) {
            copy.groups[i] = group
        } else {
            copy.groups.append(group)
        }
        return copy
    }

    /// Thay (hoặc thêm) một bộ theo id.
    public func upsertingDeck(_ deck: ContentDeck) -> ContentSnapshot {
        var copy = self
        if let i = copy.decks.firstIndex(where: { $0.id == deck.id }) {
            copy.decks[i] = deck
        } else {
            copy.decks.append(deck)
        }
        return copy
    }

    /// Sửa một thẻ ở bất kỳ bộ nào.
    public func updatingCard(_ cardId: String, _ update: (inout ContentCard) -> Void) -> ContentSnapshot {
        var copy = self
        for d in copy.decks.indices {
            if let c = copy.decks[d].cards.firstIndex(where: { $0.id == cardId }) {
                update(&copy.decks[d].cards[c])
            }
        }
        return copy
    }

    /// Xoá một thẻ.
    public func removingCard(_ cardId: String) -> ContentSnapshot {
        var copy = self
        for d in copy.decks.indices {
            copy.decks[d].cards.removeAll { $0.id == cardId }
        }
        return copy
    }

    /// Mọi mặt sau (từ tiếng Hàn) đang có — để báo trùng khi tạo bộ mới.
    public var allKorean: Set<String> {
        Set(decks.flatMap { $0.cards.map { $0.back.trimmingCharacters(in: .whitespacesAndNewlines) } })
    }
}

public struct ContentGroup: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public var name: String
    public var position: Int

    public init(id: String, name: String, position: Int) {
        self.id = id
        self.name = name
        self.position = position
    }
}

public struct ContentDeck: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public var groupId: String
    public var name: String
    public var position: Int
    /// Giá trị lạ hoặc thiếu → `nil`.
    public var type: DeckType?
    /// Tài liệu — chuỗi tự do (≤ 40 ký tự); cache cũ dạng enum (`snu4a`) vẫn đọc được như chuỗi.
    public var source: String?
    public var description: String?
    public var cards: [ContentCard]

    public init(
        id: String, groupId: String, name: String, position: Int, type: DeckType? = nil,
        source: String? = nil, description: String? = nil, cards: [ContentCard] = []
    ) {
        self.id = id
        self.groupId = groupId
        self.name = name
        self.position = position
        self.type = type
        self.source = source
        self.description = description
        self.cards = cards
    }

    private enum CodingKeys: String, CodingKey {
        case id, groupId, name, position, type, source, description, cards
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        groupId = try c.decode(String.self, forKey: .groupId)
        name = try c.decode(String.self, forKey: .name)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        type = DeckType(key: try? c.decodeIfPresent(String.self, forKey: .type))
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        cards = try c.decodeIfPresent([ContentCard].self, forKey: .cards) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(groupId, forKey: .groupId)
        try c.encode(name, forKey: .name)
        try c.encode(position, forKey: .position)
        try c.encode(type?.rawValue, forKey: .type)
        try c.encode(source, forKey: .source)
        try c.encode(description, forKey: .description)
        try c.encode(cards, forKey: .cards)
    }
}

public struct ContentCard: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public var position: Int
    public var front: String
    public var back: String
    public var hint: String?
    public var note: String?
    public var altAnswers: [String]
    public var typeAnswer: Bool
    public var marked: Bool
    public var hanja: Bool
    /// 📖 Đoạn văn ngắn — cờ người học tự gắn, giống ⭐/漢.
    public var passage: Bool
    public var audio: CardAudio

    public init(
        id: String, position: Int, front: String, back: String, hint: String? = nil, note: String? = nil,
        altAnswers: [String] = [], typeAnswer: Bool = false, marked: Bool = false, hanja: Bool = false,
        passage: Bool = false, audio: CardAudio = .none
    ) {
        self.id = id
        self.position = position
        self.front = front
        self.back = back
        self.hint = hint
        self.note = note
        self.altAnswers = altAnswers
        self.typeAnswer = typeAnswer
        self.marked = marked
        self.hanja = hanja
        self.passage = passage
        self.audio = audio
    }

    private enum CodingKeys: String, CodingKey {
        case id, position, front, back, hint, note, altAnswers, typeAnswer, marked, hanja, passage
        case frontAudioId, backAudioId, hintAudioId, noteAudioId
        // Định dạng cũ (cache trước bản có thẻ tự chấm): `vi` = mặt trước, `kr` = mặt sau.
        case vi, kr
    }

    /// Còn đọc được định dạng cũ `kr`/`vi` (thẻ cũ đều là thẻ gõ đáp án). `parentId` cũ bị bỏ qua.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        guard let front = try c.decodeIfPresent(String.self, forKey: .front)
            ?? c.decodeIfPresent(String.self, forKey: .vi),
            let back = try c.decodeIfPresent(String.self, forKey: .back)
            ?? c.decodeIfPresent(String.self, forKey: .kr)
        else {
            throw DecodingError.keyNotFound(
                CodingKeys.front, .init(codingPath: c.codingPath, debugDescription: "Thiếu front/back"))
        }
        self.front = front
        self.back = back
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        altAnswers = try c.decodeIfPresent([String].self, forKey: .altAnswers) ?? []
        typeAnswer = try c.decodeIfPresent(Bool.self, forKey: .typeAnswer) ?? c.contains(.kr)
        marked = try c.decodeIfPresent(Bool.self, forKey: .marked) ?? false
        hanja = try c.decodeIfPresent(Bool.self, forKey: .hanja) ?? false
        passage = try c.decodeIfPresent(Bool.self, forKey: .passage) ?? false
        audio = CardAudio(
            front: try c.decodeIfPresent(String.self, forKey: .frontAudioId),
            back: try c.decodeIfPresent(String.self, forKey: .backAudioId),
            hint: try c.decodeIfPresent(String.self, forKey: .hintAudioId),
            note: try c.decodeIfPresent(String.self, forKey: .noteAudioId))
    }

    /// Luôn ghi đủ bốn trường audio (`null` = không có) để server hiểu là "gỡ file".
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(position, forKey: .position)
        try c.encode(front, forKey: .front)
        try c.encode(back, forKey: .back)
        try c.encode(hint, forKey: .hint)
        try c.encode(note, forKey: .note)
        try c.encode(altAnswers, forKey: .altAnswers)
        try c.encode(typeAnswer, forKey: .typeAnswer)
        try c.encode(marked, forKey: .marked)
        try c.encode(hanja, forKey: .hanja)
        try c.encode(passage, forKey: .passage)
        try c.encode(audio.front, forKey: .frontAudioId)
        try c.encode(audio.back, forKey: .backAudioId)
        try c.encode(audio.hint, forKey: .hintAudioId)
        try c.encode(audio.note, forKey: .noteAudioId)
    }
}
