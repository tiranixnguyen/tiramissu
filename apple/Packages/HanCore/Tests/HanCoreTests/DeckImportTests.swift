import Foundation
import Testing

@testable import HanCore

@Suite("DeckImport")
struct DeckImportTests {
    @Test func docObjectVaBoKhoangTrang() {
        let r = parseDeckImport(
            """
            {"name": " Sức khoẻ ", "words": [
              {"back": " 치아 ", "front": "răng", "hint": "  "},
              {"back": "건강", "front": "sức khoẻ", "hint": "kiện khang"}
            ]}
            """)
        #expect(r.ok)
        #expect(r.name == "Sức khoẻ")
        #expect(
            r.words == [
                ImportedWord(front: "răng", back: "치아"),
                ImportedWord(front: "sức khoẻ", back: "건강", hint: "kiện khang"),
            ])
    }

    @Test func noteGiuNguyenThutLe() throws {
        let md = "    code\n\n- **ý 1**\n  - ý lồng\n"
        let arr: [[String: String]] = [
            ["back": "가다", "front": "đi", "note": md],
            ["back": "오다", "front": "đến", "note": " \n "],
        ]
        let data = try JSONSerialization.data(withJSONObject: arr)
        let r = parseDeckImport(String(decoding: data, as: UTF8.self))
        #expect(r.ok)
        #expect(r.words[0].note == md)
        #expect(r.words[1].note == nil)
    }

    @Test func mangTranVaKhoiJson() {
        let r = parseDeckImport(
            """
            Đây là kết quả:
            ```json
            [{"back": "학교", "front": "trường học"}]
            ```
            """)
        #expect(r.ok)
        #expect(r.name == nil)
        #expect(r.words.first?.back == "학교")
    }

    @Test func khoiJsonCoBangMarkdownPhiaSau() {
        let r = parseDeckImport(
            """
            ```json
            {"name": "Chữa bài", "words": [{"back": "학교", "front": "trường học"}]}
            ```

            | Lỗi | Sửa |
            |---|---|
            | 학꼬 | 학교 |
            """)
        #expect(r.ok)
        #expect(r.name == "Chữa bài")
        #expect(r.words.count == 1)
    }

    @Test func theNguCanhBiTuChoi() {
        let r = parseDeckImport(
            """
            [{"back": "가다", "front": "đi", "followUp": {"front": "đi học"}},
             {"back": "오다", "front": "đến", "followUps": []},
             {"back": "학교", "front": "trường học"}]
            """)
        #expect(!r.ok)
        #expect(r.errors.count == 2)
        #expect(r.errors[0].hasPrefix("Từ thứ 1: không còn hỗ trợ"))
        #expect(r.words.count == 1)
        #expect(r.words[0].back == "학교")
    }

    @Test func thieuFrontBack() {
        let r = parseDeckImport(#"[{"back": "학교"}, {"back": "학생", "front": "học sinh"}]"#)
        #expect(!r.ok)
        #expect(r.errors == ["Từ thứ 1: thiếu \"front\" hoặc \"back\"."])
        #expect(r.words.count == 1)
    }

    @Test func dinhDangCuKrViKhongNhan() {
        #expect(!parseDeckImport(#"[{"kr": "학교", "vi": "trường học"}]"#).ok)
    }

    @Test func jsonHongVaSaiKieu() {
        #expect(parseDeckImport("{không phải json").errors.first?.hasPrefix("JSON") == true)
        #expect(!parseDeckImport(#"{"words": 3}"#).ok)
        #expect(!parseDeckImport("").ok)
        #expect(parseDeckImport("").errors.isEmpty)
    }

    @Test func canhBaoTrung() {
        let r = parseDeckImport(
            #"[{"back": "학교", "front": "trường"}, {"back": "새", "front": "chim"}]"#)
        #expect(r.duplicatesOf(["학교", "학생"]) == ["학교"])
        #expect(r.ok)
    }

    @Test func gioiHan500() {
        let many = (0..<501).map { #"{"back": "k\#($0)", "front": "v"}"# }
        #expect(!parseDeckImport("[" + many.joined(separator: ",") + "]").ok)
        let ok = (0..<500).map { #"{"back": "k\#($0)", "front": "v"}"# }
        #expect(parseDeckImport("[" + ok.joined(separator: ",") + "]").ok)
    }

    @Test func typeAnswerMacDinhLaTrue() {
        let r = parseDeckImport(
            """
            [{"back": "간 이식 수술", "front": "ghép gan"},
             {"back": "1일 2회, 1회 1정 복용", "front": "liều dùng"}]
            """)
        #expect(r.words.map(\.typeAnswer) == [true, true])
        #expect(r.typeAnswerCount == 2)
    }

    @Test func typeAnswerGhiRoThiGiu() {
        let r = parseDeckImport(
            """
            [{"back": "가다", "front": "đi", "typeAnswer": false},
             {"back": "학교에 가서 공부를 하다", "front": "đi học", "typeAnswer": true}]
            """)
        #expect(r.words.map(\.typeAnswer) == [false, true])
    }

    @Test func defaultTypeAnswerDemTu() {
        #expect(defaultTypeAnswer("가다"))
        #expect(defaultTypeAnswer("  학교에   가다  "))
        #expect(defaultTypeAnswer("1일 2회 복용"))
        #expect(!defaultTypeAnswer("1일 2회, 1회 1정 복용"))
    }
}
