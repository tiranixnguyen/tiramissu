import Foundation

/// Một theme — giải mã từ `Resources/Themes/<id>.json` (hoặc file người dùng nhập).
/// Định dạng: xem `docs/design-system.md` › Theme JSON. Giá trị lấy từ prototype v2.
public struct Theme: Codable, Identifiable, Hashable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var description: String
    /// `true` = thay `accent` bằng màu nhấn hệ thống lúc chạy (theme "Hệ thống").
    public var useSystemAccent: Bool
    public var typography: Typography
    public var light: Palette
    public var dark: Palette

    public func palette(dark isDark: Bool) -> Palette { isDark ? dark : light }

    public struct Typography: Codable, Hashable, Sendable {
        /// `serif` (Noto Serif KR) hoặc `sans` cho chữ Hàn trên mặt thẻ.
        public var cardKoreanFont: String
        /// `system` = SF Pro / Apple SD Gothic Neo.
        public var uiFont: String
        /// Hệ số phóng chữ mặt thẻ (1.0 = mặc định).
        public var cardScale: Double
    }

    /// Token màu, mã hex `#RRGGBB`. Glass KHÔNG có token riêng — dùng vật liệu hệ thống,
    /// tô màu bằng `accent` khi cần (`.glassEffect(.regular.tint(...))`).
    public struct Palette: Codable, Hashable, Sendable {
        public var bg: String
        public var surface: String
        public var ink: String
        public var ink2: String
        public var accent: String
        public var line: String
        public var onAccent: String
        public var ok: String
        public var bad: String
        public var flag: String
    }
}

public enum ThemeCatalog {
    /// Thứ tự hiển thị trong ⌘K › Theme và Cài đặt › Giao diện.
    public static let builtInIDs = ["paper", "ink", "pine", "dusk", "contrast", "system"]
    public static let defaultID = "paper"

    /// Nạp một theme có sẵn trong bundle của package.
    public static func builtIn(_ id: String) throws -> Theme {
        guard let url = Bundle.module.url(forResource: id, withExtension: "json", subdirectory: "Themes") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Theme.self, from: Data(contentsOf: url))
    }

    public static func allBuiltIn() throws -> [Theme] {
        try builtInIDs.map(builtIn)
    }
}
