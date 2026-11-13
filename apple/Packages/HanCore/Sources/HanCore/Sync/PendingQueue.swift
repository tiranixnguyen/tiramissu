/// Áp các lần bật/tắt cờ còn chờ gửi lên nội dung vừa tải — để cờ bấm offline không bị bản cũ trên
/// server đè mất. Áp theo thứ tự `changedAt` (lần muộn nhất thắng).
public func applyingPendingFlags(_ flags: [FlagChange], to content: ContentSnapshot) -> ContentSnapshot {
    var result = content
    for change in flags.enumerated().sorted(by: { ($0.element.changedAt, $0.offset) < ($1.element.changedAt, $1.offset) })
    .map(\.element) {
        result = result.updatingCard(change.cardId) { card in
            if let v = change.marked { card.marked = v }
            if let v = change.hanja { card.hanja = v }
            if let v = change.passage { card.passage = v }
        }
    }
    return result
}

/// `LocalStore` trong bộ nhớ — cho test và preview.
public actor InMemoryLocalStore: LocalStore {
    public private(set) var flags: [FlagChange] = []
    public private(set) var sessionQueue: [StudySessionRecord] = []
    public private(set) var content: ContentSnapshot?
    public private(set) var history: [StudySessionRecord] = []

    public init() {}

    public func enqueue(flag: FlagChange) { flags.append(flag) }
    public func enqueue(session: StudySessionRecord) { sessionQueue.append(session) }

    public func pendingFlags() -> [FlagChange] { flags }
    public func removePendingFlags(_ sent: [FlagChange]) {
        for s in sent {
            if let i = flags.firstIndex(of: s) { flags.remove(at: i) }
        }
    }
    public func pendingSessions() -> [StudySessionRecord] { sessionQueue }
    public func removePendingSessions(ids: [String]) { sessionQueue.removeAll { ids.contains($0.id) } }
    public func saveContent(_ content: ContentSnapshot) { self.content = content }
    public func saveSessions(_ sessions: [StudySessionRecord]) { history = sessions }
}
