import Foundation
import Testing

@testable import DesignSystem

@Suite("ThemeLibrary")
struct ThemeLibraryTests {
    func paperData() throws -> Data {
        try ThemeLibrary.export(ThemeCatalog.builtIn("paper"))
    }

    func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "tiramissu-themes-\(UUID().uuidString)")
    }

    @Test func roundTripGiuNguyen() throws {
        let original = try ThemeCatalog.builtIn("ink")
        let back = try ThemeLibrary.parse(ThemeLibrary.export(original))
        #expect(back == original)
    }

    @Test func fileHongBaoLoiRo() {
        #expect(throws: ThemeError("File không phải JSON hợp lệ.")) {
            try ThemeLibrary.parse(Data("không phải json".utf8))
        }
    }

    @Test func thieuKhoaNeuTenKhoa() throws {
        var obj = try #require(try JSONSerialization.jsonObject(with: paperData()) as? [String: Any])
        var light = obj["light"] as! [String: Any]
        light.removeValue(forKey: "accent")
        obj["light"] = light
        obj.removeValue(forKey: "name")
        let data = try JSONSerialization.data(withJSONObject: obj)
        #expect(throws: ThemeError("Thiếu khoá: name.")) { try ThemeLibrary.parse(data) }

        obj["name"] = "X"
        let data2 = try JSONSerialization.data(withJSONObject: obj)
        #expect(throws: ThemeError("Thiếu khoá: light.accent.")) { try ThemeLibrary.parse(data2) }
    }

    @Test func maMauSaiNeuKhoa() throws {
        var obj = try #require(try JSONSerialization.jsonObject(with: paperData()) as? [String: Any])
        var dark = obj["dark"] as! [String: Any]
        dark["ink"] = "xanh"
        obj["dark"] = dark
        let data = try JSONSerialization.data(withJSONObject: obj)
        #expect(throws: ThemeError("dark.ink phải là mã màu dạng #RRGGBB (đang là \"xanh\").")) {
            try ThemeLibrary.parse(data)
        }
    }

    @Test func idTrungBuiltInThiDoiId() throws {
        let theme = try ThemeLibrary.parse(paperData(), existingIDs: ["paper"])
        #expect(theme.id == "paper-2")
        #expect(theme.name.hasSuffix("(2)"))
        let third = try ThemeLibrary.parse(paperData(), existingIDs: ["paper", "paper-2"])
        #expect(third.id == "paper-3")
    }

    @Test func installGhiFileVaLoadDocLai() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let installed = try ThemeLibrary.install(paperData(), into: dir, existingIDs: Set(ThemeCatalog.builtInIDs))
        #expect(installed.id == "paper-2")

        try Data("{ hỏng".utf8).write(to: dir.appending(path: "hong.json"))
        let loaded = ThemeLibrary.loadUserThemes(from: dir)
        #expect(loaded.themes.map(\.id) == ["paper-2"])
        #expect(loaded.errors["hong.json"] != nil)
    }

    @Test func thuMucChuaCoThiRong() {
        let loaded = ThemeLibrary.loadUserThemes(from: tempDir())
        #expect(loaded.themes.isEmpty)
        #expect(loaded.errors.isEmpty)
    }
}
