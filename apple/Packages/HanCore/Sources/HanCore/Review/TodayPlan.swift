import Foundation

/// Một bộ cần ôn trong màn Hôm nay.
public struct DueDeck: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var type: DeckType?
    public var cardCount: Int
    public var status: ReviewStatus
    /// Tỉ lệ đúng của lần học gần nhất (0…1), nếu có.
    public var lastAccuracy: Double?
}

/// Số thẻ đã trả lời trong một ngày (cho heatmap).
public struct DayActivity: Sendable, Hashable {
    public var day: Date
    public var attempted: Int
}

/// Tóm tắt "Hôm nay": bộ đến hạn, tiến độ trong ngày, chuỗi ngày, heatmap.
public struct TodayPlan: Sendable, Hashable {
    /// Bộ đến hạn hoặc quá hạn (quá hạn nhiều nhất trước), rồi bộ chưa học lần nào.
    public var dueDecks: [DueDeck]
    /// Số bộ đã học **hết** trong hôm nay.
    public var doneTodayCount: Int
    public var dueCardCount: Int
    /// Ước tính theo ~30 giây/thẻ, làm tròn lên.
    public var estimatedMinutes: Int
    /// Số ngày liên tiếp có học; hôm nay chưa học vẫn giữ chuỗi của hôm qua.
    public var streakDays: Int
    /// `heatDays` ngày gần nhất, cũ → mới (ngày cuối là hôm nay).
    public var heat: [DayActivity]

    /// Bộ nên mở khi bấm "Bắt đầu ôn".
    public var firstDue: DueDeck? { dueDecks.first }
    public var progress: Double {
        let total = doneTodayCount + dueDecks.count
        return total == 0 ? 0 : Double(doneTodayCount) / Double(total)
    }
}

public let heatDays = 14

public func computeTodayPlan(
    decks: [ContentDeck], history: [StudySessionRecord], now: Date,
    calendar: DayCalendar = .gregorian()
) -> TodayPlan {
    let cal = calendar.calendar
    let today = calendar.startOfDay(now)
    let byDeck = Dictionary(grouping: history, by: \.deckId)

    var due: [DueDeck] = []
    for deck in decks where !deck.cards.isEmpty {
        let sessions = byDeck[deck.id] ?? []
        let status = computeReviewStatus(sessions, now: now, calendar: calendar)
        guard status.state != .upcoming else { continue }
        let last = sessions.max { $0.endedAt < $1.endedAt }
        due.append(
            DueDeck(
                id: deck.id, name: deck.name, type: deck.type, cardCount: deck.cards.count,
                status: status, lastAccuracy: last.map(\.accuracy)))
    }
    due.sort {
        // Đến hạn trước (quá hạn nhiều nhất lên đầu), chưa học sau; cùng loại giữ thứ tự gốc.
        let a = $0.status.state == .due, b = $1.status.state == .due
        if a != b { return a }
        return a && $0.status.daysUntilDue < $1.status.daysUntilDue
    }

    let doneToday = Set(
        history.filter { $0.completed && calendar.startOfDay($0.endedAt) == today }.map(\.deckId)
    ).count

    var perDay: [Date: Int] = [:]
    for s in history { perDay[calendar.startOfDay(s.endedAt), default: 0] += s.attempted }
    let heat = (0..<heatDays).reversed().map { back -> DayActivity in
        let day = cal.date(byAdding: .day, value: -back, to: today) ?? today
        return DayActivity(day: day, attempted: perDay[day] ?? 0)
    }

    let activeDays = Set(history.map { calendar.startOfDay($0.endedAt) })
    var streak = 0
    var cursor = activeDays.contains(today) ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
    while activeDays.contains(cursor) {
        streak += 1
        cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }

    let cards = due.reduce(0) { $0 + $1.cardCount }
    return TodayPlan(
        dueDecks: due, doneTodayCount: doneToday, dueCardCount: cards,
        estimatedMinutes: (cards + 1) / 2, streakDays: streak, heat: heat)
}
