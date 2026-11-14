import Foundation
import Testing

@testable import HanCore

@Suite("ImportSelection")
struct ImportSelectionTests {
    /// Thư viện có 재활용하다 (bộ Plastic) và 일회용품 (bộ Môi trường, ghi ở dạng NFD + thừa khoảng trắng).
    private let library = ContentSnapshot(
        groups: [ContentGroup(id: "g", name: "Oct1", position: 0)],
        decks: [
            ContentDeck(
                id: "d1", groupId: "g", name: "Plastic", position: 0,
                cards: [ContentCard(id: "c1", position: 0, front: "tái chế", back: "재활용하다")]),
            ContentDeck(
                id: "d2", groupId: "g", name: "Môi trường", position: 1,
                cards: [
                    ContentCard(
                        id: "c2", position: 0, front: "đồ dùng một lần",
                        back: " \("일회용품".decomposedStringWithCanonicalMapping)  ")
                ]),
        ])

    private let words = [
        ImportedWord(front: "tái chế", back: "재활용하다"),
        ImportedWord(front: "rác thải nhựa", back: "플라스틱   쓰레기"),
        ImportedWord(front: "đồ dùng một lần", back: "일회용품"),
        ImportedWord(front: "bị phân huỷ", back: "분해되다"),
    ]

    @Test func tuTrungMacDinhBoTick() {
        let s = ImportSelection(words: words, library: library)
        #expect(s.existingIn == ["Plastic", nil, "Môi trường", nil])
        #expect(s.checked == [1, 3])
        #expect(s.selectedCount == 2)
        #expect(s.skippedExistingCount == 2)
        #expect(s.selectedWords.map(\.back) == ["플라스틱   쓰레기", "분해되다"])
    }

    @Test func demVaLoc() {
        let s = ImportSelection(words: words, library: library)
        #expect(s.indices(.all) == [0, 1, 2, 3])
        #expect(s.indices(.new) == [1, 3])
        #expect(s.indices(.existing) == [0, 2])
        #expect(s.count(.all) == 4 && s.count(.new) == 2 && s.count(.existing) == 2)
        #expect(s.allChecked(.new))
        #expect(!s.allChecked(.all))
        #expect(!s.allChecked(.existing))
    }

    @Test func tickTungTu() {
        var s = ImportSelection(words: words, library: library)
        s.toggle(0)
        #expect(s.isChecked(0) && s.selectedCount == 3 && s.skippedExistingCount == 1)
        s.toggle(1)
        #expect(!s.isChecked(1))
        s.toggle(99)  // ngoài phạm vi → bỏ qua
        #expect(s.selectedCount == 2)
        // Thứ tự gửi theo JSON, không theo thứ tự tick.
        #expect(s.selectedWords.map(\.front) == ["tái chế", "bị phân huỷ"])
    }

    @Test func chonTatCaChiTacDongTuDangHien() {
        var s = ImportSelection(words: words, library: library)
        s.setAll(true, .existing)
        #expect(s.checked == [0, 1, 2, 3])
        s.setAll(false, .new)
        #expect(s.checked == [0, 2])
        s.setAll(false, .all)
        #expect(s.selectedCount == 0 && s.selectedWords.isEmpty)
        #expect(!s.allChecked(.all))
    }

    @Test func rongKhongCoGiDeChon() {
        let s = ImportSelection(words: [], library: library)
        #expect(s.count(.all) == 0)
        #expect(!s.allChecked(.all))
    }
}
