#if canImport(SwiftUI)
    import SwiftUI

    /// Xếp mọi component + chọn theme/chế độ để soát bằng mắt (Xcode Preview).
    public struct ComponentGallery: View {
        @State private var store = ThemeStore(defaults: UserDefaults(suiteName: "tiramissu.gallery") ?? .standard)
        @State private var text = "학생"
        @State private var marked = true

        public init() {}

        public var body: some View {
            let theme = store.resolved(colorScheme: .light)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Picker("Theme", selection: $store.themeID) {
                            ForEach(store.themes) { Text($0.name).tag($0.id) }
                        }
                        Picker("Chế độ", selection: $store.appearance) {
                            ForEach(AppearanceMode.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    CardSurface {
                        VStack(spacing: 8) {
                            Text("học sinh").font(.largeTitle)
                            Text("gợi ý: 명사").foregroundStyle(theme?.ink2 ?? .secondary)
                        }
                    }
                    HStack(alignment: .top, spacing: 16) {
                        AnswerField(text: $text, state: .idle)
                        AnswerField(text: $text, state: .correct)
                        AnswerField(text: $text, state: .wrong)
                        AnswerField(text: $text, state: .revealed)
                    }
                    HStack {
                        FlagChip(.marked, isOn: marked) { marked.toggle() }
                        FlagChip(.hanja, isOn: false)
                        FlagChip(.passage, isOn: true)
                        FlagChip(.clip, isOn: false)
                        Spacer()
                        ProgressRing(value: 0.66)
                    }
                    VStack {
                        DeckRow(title: "Bài 1 · Chào hỏi", meta: "24 thẻ", badge: "읽기", dueLabel: "nên ôn hôm nay", isDue: true)
                        Divider()
                        DeckRow(title: "Bài 2 · Gia đình", meta: "18 thẻ", badge: "듣기", dueLabel: "ôn lại sau 3 ngày")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                        ForEach(store.themes) { ThemePreviewTile(theme: $0, isSelected: $0.id == store.themeID) }
                    }
                    HStack(spacing: 8) { Kbd("⌘K"); Kbd("↵"); Kbd("⌘/") }
                    GlassActionBar([
                        GlassAction(id: "reveal", title: "Xem đáp án", shortcut: "⌘/") {},
                        GlassAction(id: "known", title: "Đã thuộc", shortcut: "⌘↵") {},
                        GlassAction(id: "check", title: "Chấm", shortcut: "↵", isPrimary: true) {},
                    ])
                }
                .padding(24)
            }
            .background(theme?.bg ?? .clear)
            .themed(store)
        }
    }

    #Preview("Component Gallery") { ComponentGallery().frame(width: 900, height: 800) }
#endif
