import Foundation

/// Trạng thái đồng bộ hiển thị ở chân sidebar.
public enum SyncStatus: Sendable, Hashable {
    case idle
    case syncing
    case synced(Date)
    case offline
    case unauthorized
    case failed(String)
}

/// Thứ `SyncEngine` báo cho lớp trên (AppModel).
public enum SyncUpdate: Sendable, Hashable {
    case status(SyncStatus)
    /// Nội dung mới từ server, đã áp lại cờ còn chờ.
    case content(ContentSnapshot)
    /// Lịch sử học của mọi máy.
    case sessions([StudySessionRecord])
}

/// Đồng bộ nền: gửi hàng đợi (cờ, lần học) → tải `/content` → tải `/sessions`.
/// `syncNow()` không bao giờ ném — chỉ phát `SyncUpdate.status`. Gọi chồng lúc đang chạy thì chạy
/// thêm đúng một vòng sau khi vòng hiện tại xong.
public actor SyncEngine {
    private let api: any ContentAPI
    private let store: any LocalStore
    private let clock: Clock
    private let observer: @Sendable (SyncUpdate) -> Void

    private var running = false
    private var rerun = false
    public private(set) var status: SyncStatus = .idle

    static let flagBatch = 1000
    static let sessionBatch = 500

    public init(
        api: any ContentAPI, store: any LocalStore, clock: @escaping Clock = systemClock,
        observer: @escaping @Sendable (SyncUpdate) -> Void = { _ in }
    ) {
        self.api = api
        self.store = store
        self.clock = clock
        self.observer = observer
    }

    public func syncNow() async {
        if running {
            rerun = true
            return
        }
        running = true
        defer { running = false }
        repeat {
            rerun = false
            await runRound()
        } while rerun
    }

    private func set(_ s: SyncStatus) {
        status = s
        observer(.status(s))
    }

    private func runRound() async {
        set(.syncing)
        do {
            try await flush()
            let content = try await api.content()
            let merged = applyingPendingFlags(await store.pendingFlags(), to: content)
            await store.saveContent(merged)
            observer(.content(merged))

            let sessions = try await api.sessions()
            await store.saveSessions(sessions)
            observer(.sessions(sessions))
            set(.synced(clock()))
        } catch let error as APIError {
            switch error {
            case .offline: set(.offline)
            case .unauthorized: set(.unauthorized)
            case .server, .decoding: set(.failed(error.message))
            }
        } catch {
            set(.failed("Lỗi không xác định."))
        }
    }

    /// Gửi hết hàng đợi theo lô; lô nào lỗi thì dừng, phần chưa gửi vẫn nằm trong hàng đợi.
    private func flush() async throws {
        let flags = await store.pendingFlags()
        for start in stride(from: 0, to: flags.count, by: Self.flagBatch) {
            let batch = Array(flags[start..<min(start + Self.flagBatch, flags.count)])
            _ = try await api.sendFlags(batch)
            await store.removePendingFlags(batch)
        }
        let sessions = await store.pendingSessions()
        for start in stride(from: 0, to: sessions.count, by: Self.sessionBatch) {
            let batch = Array(sessions[start..<min(start + Self.sessionBatch, sessions.count)])
            _ = try await api.sendSessions(batch)
            await store.removePendingSessions(ids: batch.map(\.id))
        }
    }
}
