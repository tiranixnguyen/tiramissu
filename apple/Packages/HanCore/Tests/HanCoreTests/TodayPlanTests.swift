import Foundation
import Testing

@testable import HanCore

@Suite("TodayPlan")
struct TodayPlanTests {
    let cal = DayCalendar.gregorian()
    var now: Date { cal.calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 10))! }

    func day(_ back: Int, hour: Int = 9) -> Date {
        let d = cal.calendar.date(byAdding: .day, value: -back, to: cal.startOfDay(now))!
        return cal.calendar.date(byAdding: .hour, value: hour, to: d)!
    }

    func session(_ deck: String, back: Int, attempted: Int = 10, correct: Int = 9, completed: Bool = true) -> StudySessionRecord {
        StudySessionRecord(
            id: UUID().uuidString, deckId: deck, device: "macos", startedAt: day(back), endedAt: day(back),
            attempted: attempted, correct: correct, masteredCount: 3, totalCards: 3, completed: completed)
    }

    let decks = [contentDeck("a", threeWords), contentDeck("b", threeWords), contentDeck("c", threeWords)]

    @Test func boChuaHocVaDenHanDuocLietKe_boChuaToiHanThiKhong() {
        // a: học hôm qua tốt → hẹn 1 ngày → đến hạn hôm nay; b: học hôm nay → hẹn ngày mai (không liệt kê); c: chưa học
        let h = [session("a", back: 1), session("b", back: 0)]
        let p = computeTodayPlan(decks: decks, history: h, now: now)
        #expect(p.dueDecks.map(\.id) == ["a", "c"])
        #expect(p.doneTodayCount == 1)
        #expect(p.dueCardCount == 6)
        #expect(p.estimatedMinutes == 3)
        #expect(p.firstDue?.id == "a")
    }

    @Test func quaHanNhieuNhatLenDau() {
        let h = [session("a", back: 1), session("b", back: 5)]
        let p = computeTodayPlan(decks: decks, history: h, now: now)
        #expect(p.dueDecks.map(\.id) == ["b", "a", "c"])
    }

    @Test func chuoiNgayGiuKhiHomNayChuaHoc() {
        let h = [session("a", back: 1), session("a", back: 2), session("a", back: 3), session("a", back: 5)]
        #expect(computeTodayPlan(decks: decks, history: h, now: now).streakDays == 3)
        let withToday = h + [session("b", back: 0)]
        #expect(computeTodayPlan(decks: decks, history: withToday, now: now).streakDays == 4)
    }

    @Test func heatDu14NgayCuDenMoi() {
        let h = [session("a", back: 0, attempted: 7), session("a", back: 13, attempted: 4), session("a", back: 14, attempted: 99)]
        let p = computeTodayPlan(decks: decks, history: h, now: now)
        #expect(p.heat.count == 14)
        #expect(p.heat.first?.attempted == 4)
        #expect(p.heat.last?.attempted == 7)
    }

    @Test func boRongKhongDuocLietKe() {
        let p = computeTodayPlan(decks: [contentDeck("x", [])], history: [], now: now)
        #expect(p.dueDecks.isEmpty && p.progress == 0 && p.streakDays == 0)
    }
}
