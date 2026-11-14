import DesignSystem
import HanCore
import SwiftUI

/// Một lệnh trong bảng lệnh.
private struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let hint: String
    let run: () -> Void
}

/// Bảng lệnh `⌘K`: overlay kính, tìm không dấu. ↑↓ chọn · ↵ chạy · esc đóng.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(ThemeStore.self) private var themes
    @Environment(\.theme) private var theme
    @Environment(\.openSettings) private var openSettings

    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var all: [PaletteCommand] {
        var list: [PaletteCommand] = []
        for t in themes.themes {
            list.append(.init(id: "theme-\(t.id)", title: "Theme: \(t.name)", hint: t.id == themes.themeID ? "đang dùng" : "") {
                themes.themeID = t.id
            })
        }
        list.append(.init(id: "dark", title: "Bật/tắt chế độ tối", hint: "⌥⌘D") { themes.cycleAppearance() })
        list.append(.init(id: "import-theme", title: "Nhập theme từ file .json…", hint: "Cài đặt") { openSettings() })
        for d in model.content.decks.sorted(by: { $0.position < $1.position }) {
            list.append(.init(id: "deck-\(d.id)", title: "Học: \(d.name)", hint: "\(d.cards.count) thẻ") {
                model.switchDeck(d.id)
                nav.screen = .study
            })
        }
        for (i, s) in MacScreen.allCases.enumerated() {
            list.append(.init(id: "go-\(s.id)", title: "Đi tới: \(s.rawValue)", hint: "⌘\(i + 1)") { nav.screen = s })
        }
        return list
    }

    private var results: [PaletteCommand] { filterBySearch(all, query: query, key: \.title) }

    var body: some View {
        let results = results
        ZStack(alignment: .top) {
            Color.black.opacity(0.22).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 6) {
                TextField("Gõ lệnh… (vd: theme, học, cắt clip)", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 14).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill((theme?.surface ?? .clear).opacity(0.7)))
                    .focused($focused)
                    .onSubmit { run(results) }
                    .onKeyPress(.upArrow) { index = max(index - 1, 0); return .handled }
                    .onKeyPress(.downArrow) { index = min(index + 1, max(results.count - 1, 0)); return .handled }
                    .onKeyPress(.escape) { close(); return .handled }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { i, c in
                                row(c, selected: i == index).id(c.id)
                                    .onTapGesture { index = i; run(results) }
                            }
                            if results.isEmpty {
                                Text("Không có lệnh phù hợp").foregroundStyle(theme?.ink2 ?? .secondary).padding(14)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: index) { if results.indices.contains(index) { proxy.scrollTo(results[index].id) } }
                }
                HStack {
                    Text("↵ chạy · ↑↓ chọn · esc đóng")
                    Spacer()
                    Button("Đóng") { close() }.buttonStyle(.plain)
                }
                .font(.system(size: 11)).foregroundStyle(theme?.ink2 ?? .secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
            }
            .padding(10)
            .frame(width: 560)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(.top, 120)
        }
        .onAppear { focused = true }
        .onChange(of: query) { index = 0 }
    }

    private func row(_ c: PaletteCommand, selected: Bool) -> some View {
        HStack {
            Text(c.title)
            Spacer()
            Text(c.hint).font(.system(size: 12)).foregroundStyle(theme?.ink2 ?? .secondary)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 12).frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? (theme?.accent ?? .accentColor).opacity(0.18) : .clear))
        .contentShape(Rectangle())
    }

    private func run(_ results: [PaletteCommand]) {
        guard results.indices.contains(index) else { return }
        let command = results[index]
        close()
        command.run()
    }

    private func close() { nav.showPalette = false }
}
