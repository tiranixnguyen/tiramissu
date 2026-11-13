#if canImport(SwiftUI)
    import SwiftUI

    /// Khung mặt thẻ: nền đặc `surface`, viền `line`, bo 22. Không dùng kính.
    public struct CardSurface<Content: View>: View {
        @Environment(\.theme) private var theme
        private let content: Content

        public init(@ViewBuilder content: () -> Content) { self.content = content() }

        public var body: some View {
            content
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(theme?.surface ?? .clear, in: .rect(cornerRadius: 22))
                .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(theme?.line ?? .clear) }
        }
    }

    /// Trạng thái ô trả lời.
    public enum AnswerState: Sendable, Hashable {
        case idle, correct, wrong, revealed

        var label: String {
            switch self {
            case .idle: "Câu trả lời"
            case .correct: "Đúng"
            case .wrong: "Chưa đúng"
            case .revealed: "Đáp án"
            }
        }
    }

    /// Ô gõ tiếng Hàn 3 trạng thái + nhãn phía trên. Nền đặc.
    public struct AnswerField: View {
        @Environment(\.theme) private var theme
        @Binding private var text: String
        private let state: AnswerState
        private let onSubmit: () -> Void

        public init(text: Binding<String>, state: AnswerState = .idle, onSubmit: @escaping () -> Void = {}) {
            _text = text
            self.state = state
            self.onSubmit = onSubmit
        }

        private var tint: Color {
            switch state {
            case .idle: theme?.accent ?? .accentColor
            case .correct: theme?.ok ?? .green
            case .wrong: theme?.bad ?? .red
            case .revealed: theme?.ink2 ?? .secondary
            }
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(state.label).font(.caption.weight(.semibold)).foregroundStyle(tint)
                TextField("", text: $text, prompt: Text("Gõ tiếng Hàn rồi Enter…"))
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .foregroundStyle(theme?.ink ?? .primary)
                    .disabled(state != .idle)
                    .onSubmit(onSubmit)
                    .padding(16)
                    .background(theme?.surface ?? .clear, in: .rect(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(tint, lineWidth: 1.5) }
            }
        }
    }

    /// Nhãn phím tắt (`⌘K`, `↵`).
    public struct Kbd: View {
        @Environment(\.theme) private var theme
        private let key: String
        public init(_ key: String) { self.key = key }

        public var body: some View {
            Text(key)
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(theme?.ink2 ?? .secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(theme?.line ?? .secondary) }
        }
    }

    /// Cờ ⭐ · 漢 · 📖 · 🎧.
    public enum FlagKind: Sendable, CaseIterable {
        case marked, hanja, passage, clip

        var symbol: String {
            switch self {
            case .marked: "⭐"
            case .hanja: "漢"
            case .passage: "📖"
            case .clip: "🎧"
            }
        }

        var title: String {
            switch self {
            case .marked: "Khó nhớ"
            case .hanja: "Hán Hàn"
            case .passage: "Đoạn văn"
            case .clip: "Clip"
            }
        }
    }

    public struct FlagChip: View {
        @Environment(\.theme) private var theme
        private let kind: FlagKind
        private let isOn: Bool
        private let action: () -> Void

        public init(_ kind: FlagKind, isOn: Bool, action: @escaping () -> Void = {}) {
            self.kind = kind
            self.isOn = isOn
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(kind.symbol)
                    Text(kind.title).font(.caption.weight(.medium))
                }
                .foregroundStyle(isOn ? (theme?.flag ?? .orange) : (theme?.ink2 ?? .secondary))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    isOn ? (theme?.flag ?? .orange).opacity(0.14) : .clear, in: .capsule)
                .overlay { Capsule().strokeBorder(isOn ? (theme?.flag ?? .orange) : (theme?.line ?? .secondary)) }
            }
            .buttonStyle(.plain)
        }
    }

    /// Vòng tiến độ 0…1.
    public struct ProgressRing: View {
        @Environment(\.theme) private var theme
        private let value: Double
        private let lineWidth: CGFloat

        public init(value: Double, lineWidth: CGFloat = 6) {
            self.value = min(max(value, 0), 1)
            self.lineWidth = lineWidth
        }

        public var body: some View {
            ZStack {
                Circle().stroke(theme?.line ?? .secondary, lineWidth: lineWidth)
                Circle().trim(from: 0, to: value)
                    .stroke(theme?.accent ?? .accentColor, style: .init(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme?.ink ?? .primary)
            }
            .frame(width: 48, height: 48)
            .accessibilityLabel("Tiến độ \(Int((value * 100).rounded())) phần trăm")
        }
    }

    /// Hàng bộ từ: badge kỹ năng, tên, meta, hạn ôn.
    public struct DeckRow: View {
        @Environment(\.theme) private var theme
        private let title: String
        private let meta: String
        private let badge: String?
        private let dueLabel: String?
        private let isDue: Bool

        public init(title: String, meta: String, badge: String? = nil, dueLabel: String? = nil, isDue: Bool = false) {
            self.title = title
            self.meta = meta
            self.badge = badge
            self.dueLabel = dueLabel
            self.isDue = isDue
        }

        public var body: some View {
            HStack(spacing: 12) {
                if let badge {
                    Text(badge).font(.caption.weight(.semibold))
                        .foregroundStyle(theme?.onAccent ?? .white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme?.accent ?? .accentColor, in: .rect(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(theme?.ink ?? .primary)
                    Text(meta).font(.caption).foregroundStyle(theme?.ink2 ?? .secondary)
                }
                Spacer()
                if let dueLabel {
                    Text(dueLabel).font(.caption.weight(.medium))
                        .foregroundStyle(isDue ? (theme?.bad ?? .red) : (theme?.ink2 ?? .secondary))
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// Thẻ xem trước theme: 4 dải màu + tên + mô tả.
    public struct ThemePreviewTile: View {
        private let theme: Theme
        private let isSelected: Bool
        @Environment(\.colorScheme) private var scheme

        public init(theme: Theme, isSelected: Bool) {
            self.theme = theme
            self.isSelected = isSelected
        }

        public var body: some View {
            let p = ResolvedTheme(theme: theme, dark: scheme == .dark)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    ForEach([p.bg, p.surface, p.accent, p.ink], id: \.self) { $0.frame(height: 28) }
                }
                .clipShape(.rect(cornerRadius: 8))
                Text(theme.name).font(.headline).foregroundStyle(p.ink)
                Text(theme.description).font(.caption).foregroundStyle(p.ink2).lineLimit(2)
            }
            .padding(12)
            .background(p.surface, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? p.accent : p.line, lineWidth: isSelected ? 2 : 1)
            }
        }
    }
#endif
