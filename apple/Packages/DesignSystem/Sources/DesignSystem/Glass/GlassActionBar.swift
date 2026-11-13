#if canImport(SwiftUI)
    import SwiftUI

    /// Một nút trên thanh nổi: nhãn + phím tắt hiển thị.
    public struct GlassAction: Identifiable {
        public let id: String
        public let title: String
        public let shortcut: String?
        public let isPrimary: Bool
        public let key: KeyboardShortcut?
        public let isEnabled: Bool
        public let action: () -> Void

        public init(id: String, title: String, shortcut: String? = nil, isPrimary: Bool = false,
            key: KeyboardShortcut? = nil, isEnabled: Bool = true, action: @escaping () -> Void
        ) {
            self.id = id
            self.title = title
            self.shortcut = shortcut
            self.isPrimary = isPrimary
            self.key = key
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    private struct OptionalShortcut: ViewModifier {
        let key: KeyboardShortcut?
        func body(content: Content) -> some View {
            if let key { content.keyboardShortcut(key) } else { content }
        }
    }

    /// Thanh nút kính nổi phía dưới màn Học/Cắt clip. Chỉ lớp điều khiển dùng kính.
    public struct GlassActionBar: View {
        @Environment(\.theme) private var theme
        private let actions: [GlassAction]

        public init(_ actions: [GlassAction]) { self.actions = actions }

        public var body: some View {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(actions) { a in
                        Button(action: a.action) {
                            HStack(spacing: 8) {
                                Text(a.title)
                                if let s = a.shortcut { Kbd(s) }
                            }
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.glass)
                        .tint(a.isPrimary ? theme?.accent : nil)
                        .disabled(!a.isEnabled)
                        .modifier(OptionalShortcut(key: a.key))
                    }
                }
            }
        }
    }
#endif
