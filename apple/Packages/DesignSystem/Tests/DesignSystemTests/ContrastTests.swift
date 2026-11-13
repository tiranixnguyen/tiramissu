import Testing

@testable import DesignSystem

@Suite("Độ tương phản")
struct ContrastTests {
    @Test func hexDocDuoc() {
        #expect(RGB(hex: "#FFFFFF")?.luminance == 1)
        #expect(RGB(hex: "000000")?.luminance == 0)
        #expect(RGB(hex: "#GGGGGG") == nil)
        #expect(RGB(hex: "#FFF") == nil)
    }

    @Test func trangTrenDenLa21() {
        let c = RGB(hex: "#FFFFFF")!.contrast(with: RGB(hex: "#000000")!)
        #expect(abs(c - 21) < 0.001)
    }

    @Test("6 theme × 2 chế độ: mọi cặp chữ/nền ≥ 4.5:1")
    func moiCapDatChuan() throws {
        var failures: [String] = []
        for theme in try ThemeCatalog.allBuiltIn() {
            for (mode, p) in [("sáng", theme.light), ("tối", theme.dark)] {
                // Theme "Hệ thống" lấy accent từ hệ điều hành lúc chạy → không kiểm cặp accent.
                var pairs: [(String, String, String)] = [
                    ("ink/bg", p.ink, p.bg), ("ink/surface", p.ink, p.surface),
                    ("ink2/surface", p.ink2, p.surface), ("ok/surface", p.ok, p.surface),
                    ("bad/surface", p.bad, p.surface), ("flag/surface", p.flag, p.surface),
                ]
                if !theme.useSystemAccent { pairs.append(("onAccent/accent", p.onAccent, p.accent)) }
                for (name, fg, bg) in pairs {
                    let ratio = try #require(RGB(hex: fg)).contrast(with: try #require(RGB(hex: bg)))
                    if ratio < 4.5 { failures.append("\(theme.id) \(mode) \(name) = \(ratio)") }
                }
            }
        }
        #expect(failures.isEmpty, "\(failures)")
    }
}
