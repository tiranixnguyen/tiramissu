import Foundation
import Testing

@testable import HanCore

/// API giả: ghi lại các lần gọi, có thể bật "offline" và làm chậm `content()`.
actor FakeAPI: ContentAPI {
    var online = true
    var remoteContent = ContentSnapshot()
    var remoteSessions: [StudySessionRecord] = []
    var contentDelayNs: UInt64 = 0
    var duringContent: (@Sendable () async -> Void)?
    private(set) var contentCalls = 0
    private(set) var sentFlags: [[FlagChange]] = []
    private(set) var sentSessions: [[StudySessionRecord]] = []

    func setOnline(_ v: Bool) { online = v }
    func setContent(_ c: ContentSnapshot) { remoteContent = c }
    func setDelay(_ ns: UInt64) { contentDelayNs = ns }
    func setDuringContent(_ f: @escaping @Sendable () async -> Void) { duringContent = f }

    func health() async throws { if !online { throw APIError.offline } }
    func content() async throws -> ContentSnapshot {
        contentCalls += 1
        if contentDelayNs > 0 { try? await Task.sleep(nanoseconds: contentDelayNs) }
        await duringContent?()
        if !online { throw APIError.offline }
        return remoteContent
    }
    func sendFlags(_ changes: [FlagChange]) async throws -> FlagResult {
        if !online { throw APIError.offline }
        sentFlags.append(changes)
        return FlagResult(applied: changes.count, ignored: 0)
    }
    func sendSessions(_ sessions: [StudySessionRecord]) async throws -> SessionsResult {
        if !online { throw APIError.offline }
        sentSessions.append(sessions)
        return SessionsResult(received: sessions.count, inserted: sessions.count, unknownDeck: 0)
    }
    func sessions() async throws -> [StudySessionRecord] {
        if !online { throw APIError.offline }
        return remoteSessions
    }

    func createGroup(name: String) async throws -> ContentGroup { throw APIError.offline }
    func renameGroup(id: String, name: String) async throws -> ContentGroup { throw APIError.offline }
    func createDeck(_ deck: NewDeck) async throws -> ContentDeck { throw APIError.offline }
    func updateDeck(id: String, patch: DeckPatch) async throws -> ContentDeck { throw APIError.offline }
    func appendCards(deckId: String, words: [ImportedWord]) async throws -> ContentDeck { throw APIError.offline }
    func updateCard(id: String, edit: CardEdit) async throws -> ContentCard { throw APIError.offline }
    func deleteCard(id: String) async throws { throw APIError.offline }
    func uploadAudio(_ bytes: Data, contentType: String) async throws -> AudioUpload { throw APIError.offline }
    func downloadAudio(id: String) async throws -> Data { throw APIError.offline }
}

final class Events: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [SyncUpdate] = []
    func add(_ u: SyncUpdate) { lock.lock(); items.append(u); lock.unlock() }
    var all: [SyncUpdate] { lock.lock(); defer { lock.unlock() }; return items }
    var statuses: [SyncStatus] {
        all.compactMap { if case .status(let s) = $0 { s } else { nil } }
    }
}

private let at = Date(timeIntervalSince1970: 1_700_000_000)

private func record(_ id: String) -> StudySessionRecord {
    StudySessionRecord(
        id: id, deckId: "d1", device: "macos", startedAt: at, endedAt: at, attempted: 1, correct: 1,
        masteredCount: 1, totalCards: 1, completed: true)
}

@Suite("SyncEngine")
struct SyncEngineTests {
    @Test func offlineGiuHangDoiVaBaoOffline() async {
        let api = FakeAPI()
        await api.setOnline(false)
        let store = InMemoryLocalStore()
        await store.enqueue(flag: FlagChange(cardId: "d1-0", changedAt: at, marked: true))
        await store.enqueue(session: record("s1"))
        let events = Events()
        let sync = SyncEngine(api: api, store: store, observer: { events.add($0) })

        await sync.syncNow()

        #expect(await store.pendingFlags().count == 1)
        #expect(await store.pendingSessions().count == 1)
        #expect(await sync.status == .offline)
        #expect(events.statuses.last == .offline)
    }

    @Test func coMangGuiHetRoiTaiVe() async {
        let api = FakeAPI()
        await api.setContent(contentOf([contentDeck("d1", threeWords)]))
        let store = InMemoryLocalStore()
        await store.enqueue(flag: FlagChange(cardId: "d1-0", changedAt: at, marked: true))
        await store.enqueue(session: record("s1"))
        let sync = SyncEngine(api: api, store: store, clock: { at })

        await sync.syncNow()

        #expect(await store.pendingFlags().isEmpty)
        #expect(await store.pendingSessions().isEmpty)
        #expect(await api.sentFlags.count == 1)
        #expect(await api.sentSessions.first?.map(\.id) == ["s1"])
        #expect(await store.content?.decks.count == 1)
        #expect(await sync.status == .synced(at))
    }

    @Test func coChoDeNoiDungVuaTai() async {
        let api = FakeAPI()
        await api.setContent(contentOf([contentDeck("d1", threeWords)]))
        let store = InMemoryLocalStore()
        // Người dùng bấm ⭐ đúng lúc đang tải /content → cờ còn chờ phải đè bản server.
        await api.setDuringContent {
            await store.enqueue(flag: FlagChange(cardId: "d1-1", changedAt: at, marked: true))
        }
        let sync = SyncEngine(api: api, store: store)
        await sync.syncNow()
        #expect(await store.content?.decks[0].cards[1].marked == true)
        #expect(await store.content?.decks[0].cards[0].marked == false)
    }

    @Test func coCuaLanBamMuonHonThang() {
        let content = contentOf([contentDeck("d1", threeWords)])
        let later = FlagChange(cardId: "d1-0", changedAt: at.addingTimeInterval(10), marked: false)
        let earlier = FlagChange(cardId: "d1-0", changedAt: at, marked: true)
        #expect(!applyingPendingFlags([later, earlier], to: content).decks[0].cards[0].marked)
    }

    @Test func goiChongNhauChayDungHaiVong() async {
        let api = FakeAPI()
        await api.setDelay(50_000_000)
        let store = InMemoryLocalStore()
        let sync = SyncEngine(api: api, store: store)

        async let a: Void = sync.syncNow()
        try? await Task.sleep(nanoseconds: 10_000_000)
        async let b: Void = sync.syncNow()
        async let c: Void = sync.syncNow()
        _ = await (a, b, c)

        #expect(await api.contentCalls == 2)
    }

    @Test func matMangRoiCoLaiThiGuiBuHangDoi() async {
        let api = FakeAPI()
        await api.setOnline(false)
        let store = InMemoryLocalStore()
        await store.enqueue(session: record("s1"))
        let sync = SyncEngine(api: api, store: store)
        await sync.syncNow()
        #expect(await store.pendingSessions().count == 1)

        await api.setOnline(true)
        await sync.syncNow()
        #expect(await store.pendingSessions().isEmpty)
    }
}
