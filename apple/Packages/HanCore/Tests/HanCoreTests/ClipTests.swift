import Foundation
import Testing

@testable import HanCore

@Suite("Clip — decode")
struct ClipDecodeTests {
    @Test func decodesClipsInContent() throws {
        let json = """
            {"groups":[],"decks":[],"clips":[{"id":"c1","audioId":"a1","sourceName":"ep1.mp3",
            "startMs":1000,"endMs":4500,"transcript":"안녕하세요","translation":null,"note":null,
            "deckId":null,"marked":true,"createdAt":"2026-05-01T10:00:00.123Z"}]}
            """
        let content = try HanJSON.makeDecoder().decode(ContentSnapshot.self, from: Data(json.utf8))
        #expect(content.clips.count == 1)
        let clip = content.clips[0]
        #expect(clip.audioId == "a1" && clip.durationMs == 3500 && clip.marked)
        #expect(clip.translation == nil)
    }

    @Test func oldContentWithoutClipsStillDecodes() throws {
        let content = try HanJSON.makeDecoder().decode(
            ContentSnapshot.self, from: Data(#"{"groups":[],"decks":[]}"#.utf8))
        #expect(content.clips.isEmpty)
    }

    @Test func roundTrip() throws {
        let clip = Clip(id: "c", audioId: "a", startMs: 0, endMs: 1000, transcript: "네")
        let data = try HanJSON.makeEncoder().encode(ContentSnapshot(clips: [clip]))
        let back = try HanJSON.makeDecoder().decode(ContentSnapshot.self, from: data)
        #expect(back.clips == [clip])
    }
}

@Suite("Clip — deck 🎧")
struct ClipDeckTests {
    private func content() -> ContentSnapshot {
        ContentSnapshot(
            groups: [ContentGroup(id: "g", name: "G", position: 0)],
            decks: [
                ContentDeck(
                    id: "d", groupId: "g", name: "Bộ", position: 0,
                    cards: [ContentCard(id: "k1", position: 0, front: "xin chào", back: "안녕")])
            ],
            clips: [
                Clip(id: "c1", audioId: "a1", startMs: 0, endMs: 2000, transcript: "안녕하세요", translation: "chào", deckId: "d"),
                Clip(id: "c2", audioId: "a2", startMs: 0, endMs: 2000, transcript: "감사합니다", marked: true),
            ])
    }

    @Test func clipWordIsTypedListeningCard() {
        let w = content().clips[0].studyWord
        #expect(w.typeAnswer && w.back == "안녕하세요" && w.front == "chào")
        #expect(w.kind == .clip(audioId: "a1"))
        #expect(content().clips[1].studyWord.front.contains("Nghe"))
    }

    @Test func catalogHasAllClipsAndDeckClipsAppendToTheirDeck() {
        let catalog = content().buildStudyCatalog()
        #expect(catalog.clipWords.map(\.id) == ["c1", "c2"])
        #expect(catalog.decks[0].words.map(\.id) == ["k1", "c1"])
        #expect(catalog.markedIds == ["c2"])
    }

    @Test func engineOpensClipsDeck() {
        let catalog = content().buildStudyCatalog()
        let engine = StudyEngine(
            decks: catalog.decks, vocabGroups: catalog.vocabGroups, clipWords: catalog.clipWords)
        engine.bootstrap()
        engine.switchDeck(clipsDeckId)
        #expect(engine.currentDeckId == clipsDeckId)
        #expect(engine.totalCount == 2)
        #expect(isVirtualDeckId(clipsDeckId))
        // Chép đúng câu → tính là đúng như thẻ gõ đáp án thường.
        let word = engine.currentWord!
        #expect(engine.checkAnswer(word.back))
    }

    @Test func replaceContentRebuildsClipsDeck() {
        let catalog = content().buildStudyCatalog()
        let engine = StudyEngine(decks: catalog.decks, vocabGroups: catalog.vocabGroups, clipWords: catalog.clipWords)
        engine.bootstrap()
        engine.switchDeck(clipsDeckId)
        var next = content()
        next.clips.append(Clip(id: "c3", audioId: "a3", startMs: 0, endMs: 1000, transcript: "네"))
        engine.replaceContent(next.buildStudyCatalog())
        #expect(engine.totalCount == 3)
    }
}

@Suite("AnswerMatcher.wordDiff")
struct WordDiffTests {
    private func diff(_ a: String, _ t: String) -> [WordDiff] { AnswerMatcher.wordDiff(answer: a, target: t) }

    @Test func allCorrect() {
        #expect(diff("저는 학생입니다", "저는 학생입니다").map(\.kind) == [.correct, .correct])
    }

    @Test func missingWord() {
        let d = diff("저는 학생입니다", "저는 한국 학생입니다")
        #expect(d == [WordDiff("저는", .correct), WordDiff("한국", .missing), WordDiff("학생입니다", .correct)])
    }

    @Test func extraWord() {
        let d = diff("저는 아주 학생입니다", "저는 학생입니다")
        #expect(d == [WordDiff("저는", .correct), WordDiff("아주", .extra), WordDiff("학생입니다", .correct)])
    }

    @Test func oneWrongWord() {
        let d = diff("저는 선생입니다", "저는 학생입니다")
        #expect(d == [WordDiff("저는", .correct), WordDiff("선생입니다", .wrong(expected: "학생입니다"))])
    }

    @Test func emptyAnswerMarksEverythingMissing() {
        #expect(diff("", "가 나").map(\.kind) == [.missing, .missing])
    }

    @Test func ignoresExtraSpacesAndNFD() {
        let nfd = "안녕하세요".decomposedStringWithCanonicalMapping
        #expect(diff("  \(nfd)   저는 ", "안녕하세요 저는").allSatisfy { $0.kind == .correct })
    }
}
