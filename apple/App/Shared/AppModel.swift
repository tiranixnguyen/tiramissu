import Foundation
import HanCore
import Observation

/// Cầu nối giữa `HanCore` (thuần) và SwiftUI: cầm `StudyEngine`, `SessionRecorder`, `SyncEngine`,
/// phát `StudySessionState` sau mỗi hành động. View **không** cầm engine — chỉ đọc `state` và gọi hàm ở đây.
@MainActor @Observable
final class AppModel {
    private(set) var state: StudySessionState
    private(set) var content: ContentSnapshot
    private(set) var history: [StudySessionRecord] = []
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var isLoaded = false

    @ObservationIgnored private var engine: StudyEngine
    @ObservationIgnored private let recorder: SessionRecorder
    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var sync: SyncEngine?
    @ObservationIgnored private var api: (any ContentAPI)?

    static var deviceName: String {
        #if os(macOS)
            "macos"
        #else
            "ios"
        #endif
    }

    init(persistence: Persistence, clock: @escaping Clock = systemClock) {
        self.persistence = persistence
        recorder = SessionRecorder(device: Self.deviceName, clock: clock)
        content = ContentSnapshot()
        engine = StudyEngine(decks: [], vocabGroups: [])
        state = engine.snapshot()
    }

    /// Bản chạy thật: lưu trên ổ đĩa.
    static func live() -> AppModel {
        AppModel(persistence: Persistence(modelContainer: Persistence.makeContainer()))
    }

    // MARK: Khởi động

    /// Mở app: cache → không có thì bản đóng gói → học được ngay; chốt nháp còn sót; rồi đồng bộ nền.
    func start() async {
        guard !isLoaded else { return }
        content = await persistence.loadContent() ?? Self.bundledSample() ?? ContentSnapshot()
        history = await persistence.loadHistory()
        rebuildEngine()

        if let draft = await persistence.loadDraft() {
            let done = SessionRecorder.finalizeDraft(draft, lastAnswerAt: draft.endedAt)
            await persistence.enqueue(session: done)
            await persistence.saveDraft(nil)
        }
        isLoaded = true
        await syncNow()
    }

    /// Bản `content.sample.json` đóng gói trong app (xem `project.yml`).
    static func bundledSample() -> ContentSnapshot? {
        guard let url = Bundle.main.url(forResource: "content.sample", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? HanJSON.makeDecoder().decode(ContentSnapshot.self, from: data)
    }

    /// Thay nội dung hiện có bằng bản mẫu đóng gói (để thử khi server còn trống). Đồng bộ lần sau sẽ ghi đè.
    @discardableResult
    func loadBundledSample() -> Bool {
        guard let sample = Self.bundledSample() else { return false }
        content = sample
        rebuildEngine()
        let snapshot = sample
        Task { await persistence.saveContent(snapshot) }
        return true
    }

    private func rebuildEngine() {
        let catalog = content.buildStudyCatalog()
        engine = StudyEngine(
            decks: catalog.decks, vocabGroups: catalog.vocabGroups, markedIds: catalog.markedIds,
            hanjaIds: catalog.hanjaIds, passageIds: catalog.passageIds,
            clipWords: catalog.clipWords)
        engine.bootstrap()
        publish()
    }

    private func publish() { state = engine.snapshot() }

    // MARK: Đồng bộ

    /// Gắn server (gọi lại khi đổi URL/token trong Cài đặt). Chưa gọi → app chạy offline hoàn toàn.
    func configureAPI(baseURL: URL?, token: @escaping @Sendable () -> String?) {
        guard let baseURL else {
            sync = nil
            api = nil
            return
        }
        let api = URLSessionContentAPI(baseURL: baseURL, token: token)
        self.api = api
        sync = SyncEngine(
            api: api, store: persistence,
            observer: { [weak self] update in Task { @MainActor in self?.handle(update) } })
    }

    func syncNow() async { await sync?.syncNow() }

    private func handle(_ update: SyncUpdate) {
        switch update {
        case .status(let s): syncStatus = s
        case .sessions(let s): history = s
        case .content(let c):
            content = c
            engine.replaceContent(c.buildStudyCatalog())
            publish()
        }
    }

    // MARK: Sửa thư viện (cần mạng — ghi thẳng lên server rồi cập nhật bản sao trên máy)

    /// Ném `APIError.offline` khi chưa cấu hình server; lỗi mạng cũng ném ra để UI giữ nguyên chữ đang sửa.
    private func online() throws -> any ContentAPI {
        guard let api else { throw APIError.offline }
        return api
    }

    private func apply(_ new: ContentSnapshot) {
        content = new
        engine.replaceContent(new.buildStudyCatalog())
        publish()
        let snapshot = new
        Task { await persistence.saveContent(snapshot) }
    }

    @discardableResult
    func createDeck(_ new: NewDeck) async throws -> ContentDeck {
        let deck = try await online().createDeck(new)
        apply(content.upsertingDeck(deck))
        return deck
    }

    func updateCard(id: String, edit: CardEdit) async throws {
        let card = try await online().updateCard(id: id, edit: edit)
        apply(content.updatingCard(id) { $0 = card })
    }

    func deleteCard(id: String) async throws {
        try await online().deleteCard(id: id)
        apply(content.removingCard(id))
    }

    func addCard(deckId: String, word: ImportedWord) async throws {
        let deck = try await online().appendCards(deckId: deckId, words: [word])
        apply(content.upsertingDeck(deck))
    }

    /// Tải đoạn M4A lên rồi tạo clip trỏ tới nó. Cần mạng.
    @discardableResult
    func createClip(audio: Data, _ new: NewClip) async throws -> Clip {
        let api = try online()
        let upload = try await api.uploadAudio(audio, contentType: "audio/mp4")
        var body = new
        body.audioId = upload.id
        let clip = try await api.createClip(body)
        apply(content.upsertingClip(clip))
        return clip
    }

    /// File nghe đã tải về đĩa (cache); chưa có thì tải từ server. Cần mạng lần đầu.
    func audioFile(id: String) async throws -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tiramissu/audio", isDirectory: true)
        let file = dir.appendingPathComponent("\(id).m4a")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let data = try await online().downloadAudio(id: id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }

    func deleteClip(id: String) async throws {
        try await online().deleteClip(id: id)
        apply(content.removingClip(id))
    }

    func updateDeck(id: String, patch: DeckPatch) async throws {
        let deck = try await online().updateDeck(id: id, patch: patch)
        // Server có thể trả bộ không kèm thẻ → giữ thẻ đang có nếu rỗng.
        var merged = deck
        if merged.cards.isEmpty, let old = content.decks.first(where: { $0.id == id }) { merged.cards = old.cards }
        apply(content.upsertingDeck(merged))
    }

    // MARK: Hành động học

    func checkAnswer(_ input: String) {
        perform { $0.checkAnswer(input) }
    }

    func revealAnswer() { perform { $0.revealAnswer() } }
    func flipCard() { perform(records: false) { $0.flipCard() } }
    func gradeSelf(remembered: Bool) { perform { $0.gradeSelf(remembered: remembered) } }
    func markKnown() { perform { $0.markKnown() } }

    func overrideAsCorrect() {
        perform(allowAfterAnswered: true) { $0.overrideAsCorrect() }
    }

    func nextCard() { perform(records: false) { $0.nextCard() } }

    private func perform(
        records: Bool = true, allowAfterAnswered: Bool = false, _ action: (StudyEngine) -> Void
    ) {
        let wasAnswered = engine.answered
        action(engine)
        publish()
        if records, engine.answered, !wasAnswered || allowAfterAnswered { didAnswer() }
    }

    private func didAnswer() {
        let finished = recorder.didAnswer(state)
        let draft = recorder.draft
        Task {
            if let finished {
                await persistence.enqueue(session: finished)
                await persistence.saveDraft(nil)
                await syncNow()
            } else {
                await persistence.saveDraft(draft)
            }
        }
    }

    // MARK: Cờ

    func toggleMark() { toggleFlag(engine.currentWord, engine.toggleMark()) { FlagChange(cardId: $0, changedAt: $1, marked: $2) } }
    func toggleHanja() { toggleFlag(engine.currentWord, engine.toggleHanja()) { FlagChange(cardId: $0, changedAt: $1, hanja: $2) } }
    func togglePassage() { toggleFlag(engine.currentWord, engine.togglePassage()) { FlagChange(cardId: $0, changedAt: $1, passage: $2) } }

    private func toggleFlag(_ word: StudyWord?, _ newValue: Bool?, _ make: (String, Date, Bool) -> FlagChange) {
        publish()
        guard let word, let newValue else { return }
        let change = make(word.id, Date(), newValue)
        // Cache nội dung phản ánh cờ ngay để mở lại app vẫn thấy.
        content = content.updatingCard(word.id) { card in
            if let v = change.marked { card.marked = v }
            if let v = change.hanja { card.hanja = v }
            if let v = change.passage { card.passage = v }
        }
        let snapshot = content
        Task {
            await persistence.enqueue(flag: change)
            await persistence.saveContent(snapshot)
            await syncNow()
        }
    }

    // MARK: Chuyển bộ / nhóm (bỏ dở lần học đang có)

    func switchDeck(_ id: String) { leaveSession { $0.switchDeck(id) } }
    func switchGroup(_ id: String) { leaveSession { $0.switchVocabGroup(id) } }
    func restartDeck() { leaveSession { $0.restartCurrentDeck() } }

    private func leaveSession(_ action: (StudyEngine) -> Void) {
        let abandoned = recorder.abandon()
        action(engine)
        publish()
        Task {
            if let abandoned { await persistence.enqueue(session: abandoned) }
            await persistence.saveDraft(nil)
            if abandoned != nil { await syncNow() }
        }
    }

    // MARK: Truy vấn cho UI

    var visibleDecks: [StudyDeck] { engine.visibleDecks }

    /// Gợi ý ôn lại của một bộ thật, từ lịch sử mọi máy.
    func reviewStatus(deckId: String, now: Date = Date()) -> ReviewStatus {
        computeReviewStatus(history.filter { $0.deckId == deckId }, now: now)
    }
}
