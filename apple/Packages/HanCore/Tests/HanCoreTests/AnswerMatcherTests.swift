import Testing
@testable import HanCore

@Suite("AnswerMatcher")
struct AnswerMatcherTests {
    @Test("Bỏ khoảng trắng hai đầu và gộp khoảng trắng giữa")
    func collapsesWhitespace() {
        #expect(AnswerMatcher.normalize("  제작   비용이\t적게 들다 ") == "제작 비용이 적게 들다")
    }

    @Test("Jamo tách rời (NFD) được ghép lại thành âm tiết (NFC)")
    func composesHangulJamo() {
        let decomposed = "재활용하다".decomposedStringWithCanonicalMapping
        #expect(decomposed.unicodeScalars.count > "재활용하다".unicodeScalars.count)
        #expect(AnswerMatcher.normalize(decomposed) == "재활용하다")
    }
}
