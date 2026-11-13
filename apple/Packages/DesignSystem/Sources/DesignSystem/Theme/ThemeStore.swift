#if canImport(SwiftUI)
    import Observation
    import SwiftUI

    /// Giữ theme + chế độ sáng/tối đang dùng, lưu `UserDefaults`.
    @MainActor @Observable
    public final class ThemeStore {
        public private(set) var themes: [Theme]
        public var themeID: String { didSet { defaults.set(themeID, forKey: Keys.theme) } }
        public var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }

        @ObservationIgnored private let defaults: UserDefaults

        private enum Keys {
            static let theme = "tiramissu.themeID"
            static let appearance = "tiramissu.appearance"
        }

        public init(themes: [Theme]? = nil, defaults: UserDefaults = .standard) {
            let loaded = themes ?? ((try? ThemeCatalog.allBuiltIn()) ?? [])
            self.themes = loaded
            self.defaults = defaults
            let saved = defaults.string(forKey: Keys.theme)
            themeID = loaded.contains { $0.id == saved } ? saved! : ThemeCatalog.defaultID
            appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init) ?? .system
        }

        public var current: Theme? { themes.first { $0.id == themeID } ?? themes.first }

        /// Thêm (hoặc thay) theme người dùng nhập.
        public func add(_ theme: Theme) {
            if let i = themes.firstIndex(where: { $0.id == theme.id }) {
                themes[i] = theme
            } else {
                themes.append(theme)
            }
        }

        /// Theme kế tiếp trong danh sách (nút xoay vòng trên toolbar).
        public func cycleTheme() {
            guard !themes.isEmpty, let i = themes.firstIndex(where: { $0.id == themeID }) else { return }
            themeID = themes[(i + 1) % themes.count].id
        }

        /// Xoay vòng Theo hệ thống → Sáng → Tối.
        public func cycleAppearance() {
            let all = AppearanceMode.allCases
            appearance = all[((all.firstIndex(of: appearance) ?? 0) + 1) % all.count]
        }

        /// Chế độ sáng/tối thực tế cho `colorScheme` của môi trường.
        public func resolved(colorScheme: ColorScheme) -> ResolvedTheme? {
            guard let theme = current else { return nil }
            let scheme = appearance.colorScheme ?? colorScheme
            return ResolvedTheme(theme: theme, dark: scheme == .dark)
        }
    }

    private struct ThemeKey: EnvironmentKey {
        static let defaultValue: ResolvedTheme? = nil
    }

    extension EnvironmentValues {
        /// Theme đã resolve cho cây view hiện tại; `nil` nếu chưa gắn `.themed(store:)`.
        public var theme: ResolvedTheme? {
            get { self[ThemeKey.self] }
            set { self[ThemeKey.self] = newValue }
        }
    }

    private struct ThemedModifier: ViewModifier {
        let store: ThemeStore
        @Environment(\.colorScheme) private var systemScheme

        func body(content: Content) -> some View {
            let scheme = store.appearance.colorScheme ?? systemScheme
            content
                .environment(\.theme, store.resolved(colorScheme: systemScheme))
                .preferredColorScheme(store.appearance.colorScheme)
                .tint(store.resolved(colorScheme: scheme)?.accent)
        }
    }

    extension View {
        /// Gắn theme + chế độ sáng/tối vào cây view.
        @MainActor public func themed(_ store: ThemeStore) -> some View {
            modifier(ThemedModifier(store: store))
        }
    }
#endif
