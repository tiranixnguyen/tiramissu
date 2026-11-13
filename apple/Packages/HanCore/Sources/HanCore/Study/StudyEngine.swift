/// Bộ máy học kiểu Leitner **trong một lượt học**, Swift thuần. Đặc tả: `docs/study-algorithm.md`.
///
/// Không lưu tiến trình giữa các lượt: mỗi lần vào một bộ là một lượt mới. Engine là lớp tham chiếu
/// thay đổi tại chỗ (thuật toán xoay quanh chèn/rút thẻ khỏi hàng đợi); UI chỉ thấy `snapshot()`.
public final class StudyEngine {
    /// Số lần đúng liên tiếp để coi là "đã thuộc".
    public static let masteryStreak = 3
    /// Trả lời sai → thẻ quay lại sau 2 thẻ.
    public static let wrongOffset = 2
    /// Trả lời đúng → giãn cách xa dần theo bậc box.
    public static let boxOffsets = [3, 5, 9, 15]

    public private(set) var decks: [StudyDeck]
    public private(set) var vocabGroups: [VocabGroup]
    private var random: any RandomNumberGenerator
    private var markedIds: Set<String>
    private var hanjaIds: Set<String>
    private var passageIds: Set<String>
    private var virtualDecks: [String: StudyDeck] = [:]

    private var runtime: DeckRuntime?
    public private(set) var currentVocabGroup: String
    public private(set) var currentDeckId: String?
    public private(set) var currentIndex: Int?

    public private(set) var outcome: AnswerOutcome = .pending
    public private(set) var canOverride = false
    public private(set) var overridden = false
    public private(set) var flipped = false
    private var answerSnapshot: CardProgress?
    public private(set) var cardSerial = 0

    public init(
        decks: [StudyDeck], vocabGroups: [VocabGroup], markedIds: Set<String> = [],
        hanjaIds: Set<String> = [], passageIds: Set<String> = [],
        random: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.decks = decks
        self.vocabGroups = vocabGroups
        self.markedIds = markedIds
        self.hanjaIds = hanjaIds
        self.passageIds = passageIds
        self.random = random
        currentVocabGroup = vocabGroups.first?.id ?? ""
    }

    // MARK: Truy vấn

    public var answered: Bool { outcome != .pending }
    public var visibleDecks: [StudyDeck] { decks.filter { $0.group == currentVocabGroup } }
    public var currentDeck: StudyDeck? { deck(byId: currentDeckId) }

    public func deck(byId id: String?) -> StudyDeck? {
        guard let id else { return nil }
        if let virtual = virtualDecks[id] { return virtual }
        return decks.first { $0.id == id }
    }

    public var currentWord: StudyWord? {
        guard let deck = currentDeck, let i = currentIndex, deck.words.indices.contains(i) else { return nil }
        return deck.words[i]
    }

    public var currentProgress: CardProgress? {
        guard let i = currentIndex, let rt = runtime, rt.cardState.indices.contains(i) else { return nil }
        return rt.cardState[i]
    }

    public var currentIsMarked: Bool { currentWord.map { markedIds.contains($0.id) } ?? false }
    public var currentIsHanja: Bool { currentWord.map { hanjaIds.contains($0.id) } ?? false }
    public var currentIsPassage: Bool { currentWord.map { passageIds.contains($0.id) } ?? false }
    public var markedCount: Int { flaggedWords(markedIds).count }
    public var hanjaCount: Int { flaggedWords(hanjaIds).count }
    public var passageCount: Int { flaggedWords(passageIds).count }

    public var correctCount: Int { runtime?.correctCount ?? 0 }
    public var attemptedCount: Int { runtime?.attemptedCount ?? 0 }
    public var masteredCount: Int { runtime?.masteredCount ?? 0 }
    public var totalCount: Int { currentDeck?.words.count ?? 0 }
    public var remainingInRound: Int { (runtime?.activeQueue.count ?? 0) + 1 }
    public var progress: Double { totalCount == 0 ? 0 : Double(masteredCount) / Double(totalCount) }

    /// Hết thẻ để hỏi: bộ rỗng, hoặc đã thuộc hết.
    public var isCompleted: Bool {
        totalCount == 0 || masteredCount >= totalCount || currentIndex == nil
    }

    public func snapshot() -> StudySessionState {
        StudySessionState(
            vocabGroups: vocabGroups, currentVocabGroup: currentVocabGroup, currentDeckId: currentDeckId,
            currentWord: currentWord, currentProgress: currentProgress, outcome: outcome,
            canOverride: canOverride, overridden: overridden, flipped: flipped, cardSerial: cardSerial,
            correctCount: correctCount, attemptedCount: attemptedCount, masteredCount: masteredCount,
            totalCount: totalCount, remainingInRound: remainingInRound, isCompleted: isCompleted,
            currentIsMarked: currentIsMarked, currentIsHanja: currentIsHanja, currentIsPassage: currentIsPassage,
            markedCount: markedCount, hanjaCount: hanjaCount, passageCount: passageCount)
    }

    // MARK: Khởi động

    /// Mở bộ đầu tiên của nhóm đầu tiên và nạp thẻ đầu.
    public func bootstrap() {
        openDeck(visibleDecks.first?.id)
    }

    /// Bắt đầu lượt mới cho `deckId` (bỏ lượt đang có).
    func openDeck(_ deckId: String?) {
        currentDeckId = deckId
        if let deck = deck(byId: deckId) {
            runtime = DeckRuntime(
                cardState: Array(repeating: CardProgress(), count: deck.words.count),
                activeQueue: shuffled(Array(deck.words.indices)))
        } else {
            runtime = nil
        }
        loadCard()
    }

    // MARK: Vòng đời thẻ

    public func loadCard() {
        cardSerial += 1
        pruneUnflagged()
        guard let deck = currentDeck, var rt = runtime else {
            currentIndex = nil
            return
        }
        let total = deck.words.count
        if total == 0 || rt.masteredCount >= total {
            currentIndex = nil
            return
        }
        if rt.activeQueue.isEmpty {
            // Lưới an toàn: có thẻ lệch khỏi hàng đợi → nạp lại mọi thẻ chưa thuộc.
            rt.activeQueue = shuffled(deck.words.indices.filter { !rt.cardState[$0].mastered })
            if rt.activeQueue.isEmpty {
                runtime = rt
                currentIndex = nil
                return
            }
        }
        let id = rt.activeQueue.removeFirst()
        currentIndex = id
        outcome = .pending
        canOverride = false
        overridden = false
        flipped = false
        answerSnapshot = rt.cardState[id]
        runtime = rt
    }

    public func nextCard() { loadCard() }

    /// Chấm bài. Trả `true` nếu đúng. Không làm gì nếu thẻ đã trả lời, là thẻ tự chấm, hoặc đáp án rỗng.
    @discardableResult
    public func checkAnswer(_ input: String) -> Bool {
        guard runtime != nil, let word = currentWord, word.typeAnswer, !answered else { return false }
        let answer = AnswerMatcher.normalize(input)
        guard !answer.isEmpty else { return false }

        let isCorrect = matches(answer, word)
        runtime!.attemptedCount += 1
        if isCorrect { runtime!.correctCount += 1 }
        applySchedule(isCorrect)
        outcome = isCorrect ? .correct : .wrong
        canOverride = !isCorrect
        return isCorrect
    }

    /// "Xem đáp án": tính là một lần trả lời sai, nhưng không cho tự xác nhận đúng.
    /// Chỉ cho thẻ gõ đáp án — thẻ tự chấm dùng `flipCard`.
    public func revealAnswer() {
        guard runtime != nil, let word = currentWord, word.typeAnswer, !answered else { return }
        runtime!.attemptedCount += 1
        applySchedule(false)
        outcome = .wrong
        canOverride = false
    }

    /// Thẻ tự chấm: lật sang mặt sau. Lật **không** phải trả lời — chưa tính đúng/sai, chưa đụng hàng đợi.
    public func flipCard() {
        guard let word = currentWord, !word.typeAnswer, !answered else { return }
        flipped = true
    }

    /// Thẻ tự chấm, sau khi lật: "Nhớ" đi đúng nhánh gõ đúng, "Chưa nhớ" đúng nhánh gõ sai.
    /// Không có "Đã trả lời đúng?" (tự chấm rồi thì không còn gì để sửa).
    public func gradeSelf(remembered: Bool) {
        guard runtime != nil, let word = currentWord, !word.typeAnswer, flipped, !answered else { return }
        runtime!.attemptedCount += 1
        if remembered { runtime!.correctCount += 1 }
        applySchedule(remembered)
        outcome = remembered ? .correct : .wrong
        canOverride = false
    }

    /// "Đã thuộc": đánh dấu thuộc ngay, vẫn hiện đáp án để đối chiếu.
    public func markKnown() {
        guard var rt = runtime, currentWord != nil, let id = currentIndex, !answered else { return }
        if !rt.cardState[id].mastered {
            rt.cardState[id].mastered = true
            rt.cardState[id].streak = Self.masteryStreak
            rt.masteredCount += 1
            runtime = rt
        }
        outcome = .known
        canOverride = false
    }

    /// Gõ sai chính tả nhưng thực chất biết từ: hoàn tác nhánh "sai", khôi phục box/streak trước khi
    /// trả lời rồi áp lại lịch theo hướng "đúng" (streak nối tiếp, không khởi động lại từ 0).
    public func overrideAsCorrect() {
        guard var rt = runtime, let id = currentIndex, canOverride else { return }
        rt.activeQueue.removeAll { $0 == id }
        if let snap = answerSnapshot {
            rt.cardState[id].box = snap.box
            rt.cardState[id].streak = snap.streak
        }
        rt.correctCount += 1
        runtime = rt
        applySchedule(true)
        outcome = .correct
        canOverride = false
        overridden = true
    }

    private func matches(_ answer: String, _ word: StudyWord) -> Bool {
        answer == AnswerMatcher.normalize(word.back)
            || (word.altAnswers ?? []).contains { AnswerMatcher.normalize($0) == answer }
    }

    // MARK: Lịch

    func applySchedule(_ isCorrect: Bool) {
        guard var rt = runtime, let id = currentIndex, currentWord != nil else { return }
        var cs = rt.cardState[id]
        if isCorrect {
            cs.streak += 1
            cs.box = min(cs.box + 1, Self.boxOffsets.count - 1)
            if cs.streak >= Self.masteryStreak {
                cs.mastered = true
                rt.masteredCount += 1
                rt.cardState[id] = cs
            } else {
                rt.cardState[id] = cs
                insert(id, offset: Self.boxOffsets[cs.box], into: &rt)
            }
        } else {
            cs.box = 0
            cs.streak = 0
            rt.cardState[id] = cs
            insert(id, offset: Self.wrongOffset, into: &rt)
        }
        runtime = rt
    }

    private func insert(_ id: Int, offset: Int, into rt: inout DeckRuntime) {
        rt.activeQueue.insert(id, at: min(offset, rt.activeQueue.count))
    }

    func shuffled<T>(_ items: [T]) -> [T] {
        var copy = items
        copy.shuffle(using: &random)
        return copy
    }

    // MARK: Cờ ⭐/漢/📖

    /// Bật/tắt ⭐ cho thẻ hiện tại, trả giá trị mới (`nil` nếu không có thẻ).
    @discardableResult public func toggleMark() -> Bool? { toggleFlag(\.markedIds) }
    @discardableResult public func toggleHanja() -> Bool? { toggleFlag(\.hanjaIds) }
    @discardableResult public func togglePassage() -> Bool? { toggleFlag(\.passageIds) }

    /// Bỏ cờ ngay trong deck ảo tương ứng thì thẻ vẫn ở lại tới khi sang thẻ tiếp (xem `pruneUnflagged`).
    private func toggleFlag(_ keyPath: ReferenceWritableKeyPath<StudyEngine, Set<String>>) -> Bool? {
        guard let word = currentWord else { return nil }
        if self[keyPath: keyPath].remove(word.id) != nil { return false }
        self[keyPath: keyPath].insert(word.id)
        return true
    }

    private func flagKeyPath(_ deckId: String?) -> KeyPath<StudyEngine, Set<String>>? {
        switch deckId {
        case markedDeckId: \.markedIds
        case hanjaDeckId: \.hanjaIds
        case passageDeckId: \.passageIds
        default: nil
        }
    }

    /// Gỡ khỏi deck ⭐/漢/📖 đang mở những thẻ đã bị bỏ cờ trong lượt này. Gọi lúc nạp thẻ mới nên thẻ
    /// vừa bỏ cờ không quay lại và tổng số thẻ giảm theo — không thì lượt học không bao giờ hoàn thành.
    private func pruneUnflagged() {
        guard let deckId = currentDeckId, let kp = flagKeyPath(deckId), let deck = currentDeck,
            let rt = runtime
        else { return }
        let flags = self[keyPath: kp]
        if deck.words.allSatisfy({ flags.contains($0.id) }) { return }
        let pruned = StudyDeck(
            id: deck.id, name: deck.name, words: deck.words.filter { flags.contains($0.id) }, isVirtual: true)
        virtualDecks[deckId] = pruned
        runtime = carryRuntime(from: deck, runtime: rt, to: pruned)
    }

    /// Thẻ có cờ trong nhóm đang mở, theo thứ tự bộ/thẻ.
    private func flaggedWords(_ flags: Set<String>) -> [StudyWord] {
        visibleDecks.flatMap { $0.words.filter { flags.contains($0.id) } }
    }

    // MARK: Chuyển bộ / nhóm

    /// Mở bộ khác — luôn là một lượt mới, kể cả khi quay lại bộ vừa học dở.
    public func switchDeck(_ deckId: String) {
        if deckId == currentDeckId { return }
        if deckId == randomDeckId {
            buildRandomDeck()
        } else if flagKeyPath(deckId) != nil {
            buildFlaggedDeck(deckId)
        }
        openDeck(deckId)
    }

    public func switchVocabGroup(_ groupId: String) {
        if groupId == currentVocabGroup { return }
        currentVocabGroup = groupId
        openDeck(visibleDecks.first?.id)
    }

    private func buildFlaggedDeck(_ id: String) {
        guard let kp = flagKeyPath(id), let name = flaggedDeckNames[id] else { return }
        virtualDecks[id] = StudyDeck(
            id: id, name: name, words: flaggedWords(self[keyPath: kp]), isVirtual: true)
    }

    /// 20 thẻ ngẫu nhiên rút từ mọi bộ đang hiển thị.
    private func buildRandomDeck() {
        let pool = visibleDecks.flatMap(\.words)
        setRandomDeck(Array(shuffled(pool).prefix(20)))
    }

    private func setRandomDeck(_ words: [StudyWord]) {
        virtualDecks[randomDeckId] = StudyDeck(
            id: randomDeckId, name: "🔀 Deck ngẫu nhiên (\(words.count))", words: words, isVirtual: true)
    }

    /// Mang lượt đang học từ `old` sang `new` theo id thẻ: thẻ còn thì giữ box/streak/đã thuộc và vị trí
    /// trong hàng đợi, thẻ bị bỏ thì rơi ra, thẻ mới xếp (xáo) vào cuối hàng đợi.
    func carryRuntime(from old: StudyDeck, runtime oldRuntime: DeckRuntime, to new: StudyDeck) -> DeckRuntime {
        let oldIndexOf = Dictionary(old.words.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let newIndexOf = Dictionary(new.words.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let cardState: [CardProgress] = new.words.map { w in
            if let o = oldIndexOf[w.id], oldRuntime.cardState.indices.contains(o) { return oldRuntime.cardState[o] }
            return CardProgress()
        }
        var queue = oldRuntime.activeQueue.compactMap { newIndexOf[old.words[$0].id] }
        let added = new.words.indices.filter { oldIndexOf[new.words[$0].id] == nil }
        queue.append(contentsOf: shuffled(added))
        return DeckRuntime(
            cardState: cardState, activeQueue: queue, correctCount: oldRuntime.correctCount,
            attemptedCount: oldRuntime.attemptedCount, masteredCount: cardState.filter(\.mastered).count)
    }
}

public let markedDeckId = "marked"
public let hanjaDeckId = "hanja"
public let passageDeckId = "passage"
public let randomDeckId = "random20"

public func isVirtualDeckId(_ id: String?) -> Bool {
    id == markedDeckId || id == hanjaDeckId || id == passageDeckId || id == randomDeckId
}

private let flaggedDeckNames = [
    markedDeckId: "⭐ Từ khó nhớ",
    hanjaDeckId: "漢 Ôn từ Hán Hàn",
    passageDeckId: "📖 Đoạn văn ngắn",
]
