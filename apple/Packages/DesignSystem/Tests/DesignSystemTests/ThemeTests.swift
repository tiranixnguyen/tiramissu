import Testing
@testable import DesignSystem

@Suite("Theme")
struct ThemeTests {
    @Test("Cả 6 theme có sẵn giải mã được, id khớp tên file")
    func decodesAllBuiltIns() throws {
        let themes = try ThemeCatalog.allBuiltIn()
        #expect(themes.map(\.id) == ThemeCatalog.builtInIDs)
    }

    @Test("Mọi token là mã hex #RRGGBB")
    func tokensAreHex() throws {
        for theme in try ThemeCatalog.allBuiltIn() {
            for palette in [theme.light, theme.dark] {
                let values = [palette.bg, palette.surface, palette.ink, palette.ink2, palette.accent,
                              palette.line, palette.onAccent, palette.ok, palette.bad, palette.flag]
                for hex in values {
                    #expect(hex.count == 7 && hex.first == "#" && hex.dropFirst().allSatisfy(\.isHexDigit),
                            "\(theme.id): \(hex)")
                }
            }
        }
    }
}
