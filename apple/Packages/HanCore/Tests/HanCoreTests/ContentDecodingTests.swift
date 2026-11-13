import Foundation
import Testing
@testable import HanCore

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try HanJSON.makeDecoder().decode(type, from: Data(json.utf8))
}

@Suite("Giải mã /content")
struct ContentDecodingTests {
    private func sample() throws -> ContentSnapshot {
        let url = try #require(Bundle.module.url(forResource: "content.sample", withExtension: "json", subdirectory: "Resources"))
        return try HanJSON.makeDecoder().decode(ContentSnapshot.self, from: Data(contentsOf: url))
    }

    @Test func decodeSampleDungSoLuong() throws {
        let content = try sample()
        #expect(content.groups.count == 7)
        #expect(content.decks.count == 52)
        #expect(content.decks.reduce(0) { $0 + $1.cards.count } == 752)
    }

    @Test func roundTripGiuNguyen() throws {
        let content = try sample()
        let data = try HanJSON.makeEncoder().encode(content)
        let again = try HanJSON.makeDecoder().decode(ContentSnapshot.self, from: data)
        #expect(again == content)
    }

    @Test func theCuKrViThanhBackFrontVaTypeAnswer() throws {
        let card = try decode(ContentCard.self, #"{"id":"a","position":1,"kr":"안녕","vi":"Xin chào"}"#)
        #expect(card.back == "안녕")
        #expect(card.front == "Xin chào")
        #expect(card.typeAnswer)
    }

    @Test func thieuTruongDungMacDinh() throws {
        let card = try decode(ContentCard.self, #"{"id":"a","position":0,"front":"f","back":"b"}"#)
        #expect(!card.typeAnswer && !card.marked && !card.hanja && !card.passage)
        #expect(card.altAnswers.isEmpty && card.hint == nil && card.audio.isEmpty)
    }

    @Test func typeLaVaSourceTuDo() throws {
        let deck = try decode(ContentDeck.self,
            #"{"id":"d","groupId":"g","name":"n","position":0,"type":"future","source":"SNU 4A","cards":[]}"#)
        #expect(deck.type == nil)
        #expect(deck.source == "SNU 4A")
        let known = try decode(ContentDeck.self, #"{"id":"d","groupId":"g","name":"n","position":0,"type":"grammar","cards":[]}"#)
        #expect(known.type == .grammar)
        #expect(known.source == nil)
    }

    @Test func parentIdBiBoQua() throws {
        let card = try decode(ContentCard.self, #"{"id":"a","position":0,"front":"f","back":"b","parentId":"x"}"#)
        #expect(card.id == "a")
    }

    @Test func audioIdRongBiBo() throws {
        let card = try decode(ContentCard.self,
            #"{"id":"a","position":0,"front":"f","back":"b","backAudioId":"au1","frontAudioId":""}"#)
        #expect(card.audio[.back] == "au1")
        #expect(card.audio[.front] == nil)
    }

    @Test func ngayIsoCoVaKhongCoMiliGiay() throws {
        let a = try decode(FlagChange.self, #"{"cardId":"c","changedAt":"2026-11-13T10:20:30.123Z","marked":true}"#)
        let b = try decode(FlagChange.self, #"{"cardId":"c","changedAt":"2026-11-13T10:20:30Z"}"#)
        #expect(a.changedAt.timeIntervalSince(b.changedAt) > 0.12 && a.changedAt.timeIntervalSince(b.changedAt) < 0.13)
        #expect(a.marked == true && a.hanja == nil)
        let text = String(decoding: try HanJSON.makeEncoder().encode(a), as: UTF8.self)
        #expect(text.contains("2026-11-13T10:20:30.123Z"))
    }

    @Test func studySessionRecordRoundTripVaAccuracy() throws {
        let json = #"{"id":"s","deckId":"d","device":"macos","startedAt":"2026-11-13T10:00:00.000Z","endedAt":"2026-11-13T10:05:00.000Z","attempted":0,"correct":0,"masteredCount":3,"totalCards":3,"completed":true}"#
        let rec = try decode(StudySessionRecord.self, json)
        #expect(rec.accuracy == 1)
        let again = try HanJSON.makeDecoder().decode(StudySessionRecord.self, from: HanJSON.makeEncoder().encode(rec))
        #expect(again == rec)
    }
}
