import Foundation
import Testing

@testable import HanCore

/// Đồng hồ chỉnh tay cho test (lớp tham chiếu để Clock `@Sendable` đọc được giá trị mới).
final class FakeNow: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ s: TimeInterval) { date.addTimeInterval(s) }
}

@Suite("SessionRecorder")
struct SessionRecorderTests {
    func make(_ now: FakeNow) -> SessionRecorder {
        let counter = Counter()
        return SessionRecorder(device: "macos", clock: { now.date }, makeId: { counter.next() })
    }

    @Test func moBoRoiDoiNgayKhongGhi() {
        let r = make(FakeNow())
        #expect(r.abandon() == nil)
        #expect(r.draft == nil)
    }

    @Test func hocHetBoLaCompleted() {
        let now = FakeNow()
        let r = make(now)
        let e = buildEngine([RawWord(front: "học sinh", back: "학생")])
        var done: StudySessionRecord?
        for _ in 0..<StudyEngine.masteryStreak {
            now.advance(10)
            answerCurrentCorrectly(e)
            done = r.didAnswer(e.snapshot())
            e.nextCard()
        }
        #expect(done?.completed == true)
        #expect(done?.deckId == "d1")
        #expect(done?.attempted == 3)
        #expect(done?.correct == 3)
        #expect(done?.masteredCount == 1)
        #expect(done?.endedAt.timeIntervalSince(done!.startedAt) == 20)
        #expect(r.draft == nil)
        #expect(r.abandon() == nil)
    }

    @Test func boDoKhongCompletedVaKetThucOCauCuoi() {
        let now = FakeNow()
        let r = make(now)
        let e = buildEngine()
        let start = now.date
        now.advance(5)
        answerCurrentCorrectly(e)
        #expect(r.didAnswer(e.snapshot()) == nil)
        #expect(r.draft?.startedAt == now.date)
        now.advance(60)
        e.nextCard()
        e.checkAnswer("sai")
        r.didAnswer(e.snapshot())
        now.advance(1000)  // nghỉ lâu rồi mới đổi bộ

        let rec = r.abandon()
        #expect(rec?.completed == false)
        #expect(rec?.attempted == 2)
        #expect(rec?.correct == 1)
        #expect(rec?.endedAt == start.addingTimeInterval(65))
        #expect(r.draft == nil)
    }

    @Test func boAoKhongGhi() {
        let r = make(FakeNow())
        let e = engineFor(contentOf([contentDeck("d1", threeWords, marked: [0])]))
        e.switchDeck(markedDeckId)
        e.markKnown()
        #expect(r.didAnswer(e.snapshot()) == nil)
        #expect(r.draft == nil)
    }

    @Test func nhapChotDungGio() {
        let draft = StudySessionRecord(
            id: "x", deckId: "d1", device: "macos", startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 50), attempted: 2, correct: 1, masteredCount: 0,
            totalCards: 3, completed: true)
        let last = Date(timeIntervalSince1970: 42)
        let r = SessionRecorder.finalizeDraft(draft, lastAnswerAt: last)
        #expect(r.endedAt == last)
        #expect(!r.completed)
        #expect(r.attempted == 2)
    }

    @Test func idLa128BitHexVaKhongTrung() {
        let a = newSessionId()
        let b = newSessionId()
        #expect(a.count == 32)
        #expect(a.allSatisfy { $0.isHexDigit })
        #expect(a != b)
    }

    @Test func traLoiLaiSauOverrideCapNhatCungMotLanHoc() {
        let r = make(FakeNow())
        let e = buildEngine()
        e.checkAnswer("sai")
        r.didAnswer(e.snapshot())
        let id = r.draft?.id
        e.overrideAsCorrect()
        r.didAnswer(e.snapshot())
        #expect(r.draft?.id == id)
        #expect(r.draft?.correct == 1)
        #expect(r.draft?.attempted == 1)
    }
}

final class Counter: @unchecked Sendable {
    private var n = 0
    func next() -> String { n += 1; return "id\(n)" }
}
