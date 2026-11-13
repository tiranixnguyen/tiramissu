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
        decks: [StudyDeck], vocabGroups: [VocabGroup],
        random: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.decks = decks
        self.vocabGroups = vocabGroups
        self.random = random
        currentVocabGroup = vocabGroups.first?.id ?? ""
    }

    // MARK: Truy vấn

    public var answered: Bool { outcome != .pending }
    public var visibleDecks: [StudyDeck] { decks.filter { $0.group == currentVocabGroup } }
    public var currentDeck: StudyDeck? { deck(byId: currentDeckId) }

    public func deck(byId id: String?) -> StudyDeck? {
        guard let id else { return nil }
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
            totalCount: totalCount, remainingInRound: remainingInRound, isCompleted: isCompleted)
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
}
