#if canImport(SwiftUI)
    import SwiftUI

    extension Color {
        /// `#RRGGBB`; sai định dạng → màu hồng đậm để lộ lỗi ngay (không crash).
        public init(hex: String) {
            let rgb = RGB(hex: hex) ?? RGB(r: 1, g: 0, b: 1)
            self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
        }
    }

    /// Theme đã dựng thành `Color` cho một chế độ sáng/tối. View chỉ lấy màu/chữ từ đây.
    public struct ResolvedTheme: Sendable {
        public let id: String
        public let bg: Color
        public let surface: Color
        public let ink: Color
        public let ink2: Color
        public let accent: Color
        public let line: Color
        public let onAccent: Color
        public let ok: Color
        public let bad: Color
        public let flag: Color
        public let typography: Theme.Typography

        public init(theme: Theme, dark: Bool) {
            let p = theme.palette(dark: dark)
            id = theme.id
            bg = Color(hex: p.bg)
            surface = Color(hex: p.surface)
            ink = Color(hex: p.ink)
            ink2 = Color(hex: p.ink2)
            accent = theme.useSystemAccent ? Color.accentColor : Color(hex: p.accent)
            line = Color(hex: p.line)
            onAccent = Color(hex: p.onAccent)
            ok = Color(hex: p.ok)
            bad = Color(hex: p.bad)
            flag = Color(hex: p.flag)
            typography = theme.typography
        }

        /// Màu nhạt dẫn xuất: `color` trộn `fraction` (0…1) trên `base`.
        public static func mix(_ color: Color, over base: Color, _ fraction: Double) -> Color {
            color.mix(with: base, by: 1 - fraction)
        }
    }

    /// Chế độ sáng/tối người dùng chọn.
    public enum AppearanceMode: String, CaseIterable, Sendable {
        case system, light, dark

        public var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }

        public var symbol: String {
            switch self {
            case .system: "circle.lefthalf.filled"
            case .light: "sun.max"
            case .dark: "moon"
            }
        }

        public var label: String {
            switch self {
            case .system: "Theo hệ thống"
            case .light: "Sáng"
            case .dark: "Tối"
            }
        }
    }
#endif
