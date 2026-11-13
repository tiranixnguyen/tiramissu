import Foundation
import Testing
@testable import HanCore

@Suite("Util")
struct UtilTests {
    @Test func cungSeedCungDay() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        #expect((0..<20).map { _ in a.next() } == (0..<20).map { _ in b.next() })
    }

    @Test func khacSeedKhacDay() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect((0..<5).map { _ in a.next() } != (0..<5).map { _ in b.next() })
    }

    @Test func splitMix64GiaTriChuan() {
        // Vector chuẩn của SplitMix64 với seed 0.
        var g = SeededGenerator(seed: 0)
        #expect(g.next() == 0xE220_A839_7B1D_CDAF)
    }

    @Test func shuffleXacDinhTheoSeed() {
        var a = SeededGenerator(seed: 7)
        var b = SeededGenerator(seed: 7)
        #expect(Array(0..<30).shuffled(using: &a) == Array(0..<30).shuffled(using: &b))
    }

    @Test func clockTiemDuoc() {
        let fixed = Date(timeIntervalSince1970: 1_000)
        let clock: Clock = { fixed }
        #expect(clock() == fixed)
        #expect(systemClock().timeIntervalSinceNow > -5)
    }

    @Test func startOfDayTheoMuiGio() {
        let cal = DayCalendar.gregorian(timeZoneIdentifier: "Asia/Ho_Chi_Minh")
        // 2026-11-13T18:00:00Z = 01:00 ngày 14/11 giờ VN.
        let t = Date(timeIntervalSince1970: 1_794_679_200)
        let start = cal.startOfDay(t)
        #expect(start == Date(timeIntervalSince1970: 1_794_679_200 - 3_600))
    }
}
