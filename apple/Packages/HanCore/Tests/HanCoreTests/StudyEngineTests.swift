import Testing

@testable import HanCore

@Suite("StudyEngine")
struct StudyEngineTests {
    @Suite("dựng dữ liệu (buildStudyCatalog)")
    struct Catalog {
        @Test func sapTheoPositionKhongTheoThuTuTrongJson() {
            var deck = contentDeck("d1", threeWords)
            deck.cards.reverse()
            let c = contentOf([deck]).buildStudyCatalog()
            #expect(c.decks.first?.words.map(\.back) == ["학생", "선생님", "학교"])
        }

        @Test func gomCoTheoIdThe() {
            let c = contentOf([
                contentDeck("d1", threeWords, marked: [1], hanja: [0, 2], passage: [2])
            ]).buildStudyCatalog()
            #expect(c.markedIds == ["d1-1"])
            #expect(c.hanjaIds == ["d1-0", "d1-2"])
            #expect(c.passageIds == ["d1-2"])
        }

        @Test func sapNhomVaBoTheoPosition() {
            let content = contentOf(
                [
                    contentDeck("b", threeWords, position: 1),
                    contentDeck("a", threeWords, position: 0),
                ],
                groups: [
                    ContentGroup(id: "g2", name: "Sep2", position: 1),
                    ContentGroup(id: "g1", name: "Sep1", position: 0),
                ])
            let c = content.buildStudyCatalog()
            #expect(c.decks.map(\.id) == ["a", "b"])
            #expect(c.vocabGroups.map(\.id) == ["g1", "g2"])
        }
    }
}
