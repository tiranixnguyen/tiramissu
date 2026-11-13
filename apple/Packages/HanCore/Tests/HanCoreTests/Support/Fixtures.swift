@testable import HanCore

/// Một từ thô như JSON nhập bộ.
struct RawWord {
    var front: String
    var back: String
    var hint: String? = nil
    var note: String? = nil
    var altAnswers: [String] = []
    var typeAnswer: Bool? = nil
    var audio: CardAudio = .none
}

/// Dựng một bộ giống server làm từ JSON nhập bộ: mỗi từ một thẻ, không ghi `typeAnswer` thì theo
/// `defaultTypeAnswer`, id `<deckId>-<vị trí>`.
func contentDeck(
    _ id: String, _ words: [RawWord], groupId: String = "g1", name: String? = nil, position: Int = 0,
    type: DeckType? = nil, source: String? = nil, description: String? = nil,
    marked: Set<Int> = [], hanja: Set<Int> = [], passage: Set<Int> = []
) -> ContentDeck {
    let cards = words.enumerated().map { i, w in
        ContentCard(
            id: "\(id)-\(i)", position: i, front: w.front, back: w.back, hint: w.hint, note: w.note,
            altAnswers: w.altAnswers, typeAnswer: w.typeAnswer ?? defaultTypeAnswer(w.back),
            marked: marked.contains(i), hanja: hanja.contains(i), passage: passage.contains(i),
            audio: w.audio)
    }
    return ContentDeck(
        id: id, groupId: groupId, name: name ?? "Bộ \(id)", position: position, type: type,
        source: source, description: description, cards: cards)
}

func contentOf(
    _ decks: [ContentDeck], groups: [ContentGroup] = [ContentGroup(id: "g1", name: "Sep1", position: 0)]
) -> ContentSnapshot {
    ContentSnapshot(groups: groups, decks: decks)
}

let threeWords = [
    RawWord(front: "học sinh", back: "학생"),
    RawWord(front: "giáo viên", back: "선생님"),
    RawWord(front: "trường học", back: "학교"),
]

extension ContentSnapshot {
    /// Sửa một thẻ theo id (test).
    func updateCard(_ id: String, _ change: (inout ContentCard) -> Void) -> ContentSnapshot {
        var copy = self
        for d in copy.decks.indices {
            for c in copy.decks[d].cards.indices where copy.decks[d].cards[c].id == id {
                change(&copy.decks[d].cards[c])
            }
        }
        return copy
    }

    /// Xoá một thẻ theo id (test).
    func removeCard(_ id: String) -> ContentSnapshot {
        var copy = self
        for d in copy.decks.indices { copy.decks[d].cards.removeAll { $0.id == id } }
        return copy
    }
}
