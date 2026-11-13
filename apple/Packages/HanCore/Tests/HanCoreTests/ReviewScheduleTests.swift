import Foundation
import Testing

@testable import HanCore

@Suite("ReviewSchedule")
struct ReviewScheduleTests {
    let cal = DayCalendar.gregorian(timeZoneIdentifier: "Asia/Ho_Chi_Minh")
    let d1: Date

    init() {
        d1 = cal.calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    }

    func day(_ offset: Int) -> Date { cal.calendar.date(byAdding: .day, value: offset, to: d1)! }

    /// Một lần học kết thúc lúc 20h ngày `day`.
    func session(
        _ day: Date, attempted: Int = 10, correct: Int = 10, completed: Bool = true
    ) -> StudySessionRecord {
        let end = cal.calendar.date(byAdding: .hour, value: 20, to: cal.startOfDay(day))!
        return StudySessionRecord(
            id: UUID().uuidString, deckId: "d1", device: "ios", startedAt: end.addingTimeInterval(-600),
            endedAt: end, attempted: attempted, correct: correct, masteredCount: 5, totalCards: 5,
            completed: completed)
    }

    func status(_ s: [StudySessionRecord], _ now: Date) -> ReviewStatus {
        computeReviewStatus(s, now: now, calendar: cal)
    }

    @Test func chuaHocHetLanNaoKeCaCoLanHocDo() {
        let r = status([session(d1, completed: false)], day(0))
        #expect(r.state == .neverStudied)
        #expect(r.shortLabel == "chưa học")
        #expect(r.lastStudiedAt != nil)
    }

    @Test func lanTotDauTienOnLaiSau1Ngay() {
        let r = status([session(d1)], day(0))
        #expect(r.state == .upcoming)
        #expect(r.dueDay == day(1))
        #expect(r.level == 1)
        #expect(r.shortLabel == "ôn lại ngày mai")
    }

    @Test func onDungHenLienTucGianCach() {
        var sessions: [StudySessionRecord] = []
        var t = 0
        var gaps: [Int] = []
        for _ in 0..<7 {
            sessions.append(session(day(t)))
            let r = status(sessions, day(t))
            gaps.append(r.daysUntilDue)
            t += r.daysUntilDue
        }
        #expect(gaps == [1, 3, 7, 14, 30, 60, 60])
    }

    @Test func tiLeDungDuoi80VeBacDau() {
        let r = status([session(day(0)), session(day(1)), session(day(4), correct: 7)], day(4))
        #expect(r.level == 0)
        #expect(r.dueDay == day(5))
    }

    @Test func dung80VanLaTot() {
        #expect(status([session(d1, correct: 8)], day(0)).level == 1)
    }

    @Test func onSomTruocHenVanTotGiuNguyenHen() {
        let r = status([session(day(0)), session(day(1)), session(day(2)), session(day(3))], day(3))
        #expect(r.level == 2)
        #expect(r.dueDay == day(4))
    }

    @Test func onSomMaKemVanTutVeBacDau() {
        let r = status([session(day(0)), session(day(1)), session(day(2), correct: 5)], day(2))
        #expect(r.level == 0)
        #expect(r.dueDay == day(3))
    }

    @Test func lanHocDoKhongAnhHuongLich() {
        let base = [session(day(0))]
        let withPartial = base + [session(day(1), correct: 1, completed: false)]
        #expect(status(withPartial, day(1)).dueDay == status(base, day(1)).dueDay)
    }

    @Test func quaHanDemSoNgay() {
        let r = status([session(d1)], day(4))
        #expect(r.state == .due)
        #expect(r.daysUntilDue == -3)
        #expect(r.shortLabel == "quá hạn 3 ngày")
    }

    @Test func dungNgayHenSoTheoNgayKhongTheoGio() {
        let now = cal.calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 7))!
        let r = status([session(d1)], now)
        #expect(r.state == .due)
        #expect(r.shortLabel == "nên ôn hôm nay")
    }

    @Test func thuTuDauVaoKhongQuanTrong() {
        let a = session(day(0))
        let b = session(day(1))
        #expect(status([b, a], day(1)).dueDay == status([a, b], day(1)).dueDay)
    }

    @Test func chiBamDaThuocCoiNhu100() {
        #expect(status([session(d1, attempted: 0, correct: 0)], day(0)).level == 1)
    }

    @Test func idLanHoc32KyTuHexKhongTrung() {
        let ids = Set((0..<1000).map { _ in newSessionId() })
        #expect(ids.count == 1000)
        #expect(ids.first!.count == 32)
    }
}
