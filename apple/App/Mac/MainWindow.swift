import DesignSystem
import HanCore
import Observation
import SwiftUI

/// Các màn trong sidebar, theo thứ tự `⌘1…⌘5`.
enum MacScreen: String, CaseIterable, Identifiable {
    case today = "Hôm nay"
    case study = "Học"
    case library = "Thư viện"
    case importAI = "Nhập từ AI"
    case audioClip = "Cắt clip âm thanh"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .study: "rectangle.on.rectangle"
        case .library: "books.vertical"
        case .importAI: "sparkles"
        case .audioClip: "waveform"
        }
    }
}

/// Màn đang mở — để menu lệnh (`⌘1…5`) và sidebar dùng chung.
@MainActor @Observable
final class Navigation {
    var screen: MacScreen = .today
    var showPalette = false
}

/// Bộ ảo hiện ở sidebar, trên cùng nhóm bộ thật.
private struct VirtualDeckItem: Identifiable {
    let id: String
    let title: String
    let count: Int?
}

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(ThemeStore.self) private var themes
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var nav = nav
        NavigationSplitView {
            sidebar(selection: $nav.screen)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            detail
                .frame(minWidth: 700, minHeight: 600)
                .background(theme?.bg ?? .clear)
                .navigationTitle(nav.screen.rawValue)
        }
        .toolbar { toolbar }
        .overlay {
            if nav.showPalette { CommandPalette() }
        }
    }

    // MARK: Sidebar

    private var virtualDecks: [VirtualDeckItem] {
        [
            .init(id: markedDeckId, title: "⭐ Từ khó nhớ", count: model.state.markedCount),
            .init(id: hanjaDeckId, title: "漢 Hán Hàn", count: model.state.hanjaCount),
            .init(id: passageDeckId, title: "📖 Đoạn văn", count: model.state.passageCount),
            .init(id: randomDeckId, title: "🔀 Ngẫu nhiên 20", count: nil),
        ]
    }

    private func sidebar(selection: Binding<MacScreen>) -> some View {
        List(selection: Binding<MacScreen?>(get: { selection.wrappedValue }, set: { if let v = $0 { selection.wrappedValue = v } })) {
            Section {
                ForEach(MacScreen.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol).tag(item)
                }
            }
            Section("Bộ ảo") {
                ForEach(virtualDecks) { item in
                    Button {
                        model.switchDeck(item.id)
                        nav.screen = .study
                    } label: {
                        HStack {
                            Text(item.title)
                            Spacer()
                            if let c = item.count { Text("\(c)").foregroundStyle(.secondary).monospacedDigit() }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Label("🎧 Clip nghe", systemImage: "headphones")
                    .foregroundStyle(.tertiary)
                    .help("Có ở giai đoạn 3")
            }
        }
        .safeAreaInset(edge: .bottom) { SyncFooter(status: model.syncStatus) }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if nav.screen == .study {
            StudyView()
        } else if nav.screen == .today {
            TodayView()
        } else if nav.screen == .library {
            LibraryView()
        } else if nav.screen == .importAI {
            ImportView()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ContentUnavailableView(
            nav.screen.rawValue, systemImage: nav.screen.symbol,
            description: Text(
                "Màn này chưa được dựng — xem docs/tasks.md\n"
                    + "Dữ liệu: \(model.content.groups.count) nhóm · \(model.content.decks.count) bộ · "
                    + "\(model.content.decks.reduce(0) { $0 + $1.cards.count }) thẻ"))
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if nav.screen != .study {
                Button {
                    themes.cycleTheme()
                } label: {
                    Label("Đổi theme", systemImage: "paintpalette")
                }
                .help("Theme: \(themes.current?.name ?? "") — bấm để đổi")
                Button {
                    themes.cycleAppearance()
                } label: {
                    Label("Sáng/tối", systemImage: themes.appearance.symbol)
                }
                .help("Giao diện: \(themes.appearance.label) (⌥⌘D)")
            }
        }
    }
}

/// Trạng thái đồng bộ ở chân sidebar.
private struct SyncFooter: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text).font(.caption)
            Spacer()
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .help("Cài đặt (⌘,)")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var symbol: String {
        switch status {
        case .idle: "circle.dashed"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.circle"
        case .offline: "wifi.slash"
        case .unauthorized: "key.slash"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var text: String {
        switch status {
        case .idle: "Chưa đồng bộ"
        case .syncing: "Đang đồng bộ…"
        case .synced(let d): "Đã đồng bộ \(d.formatted(date: .omitted, time: .shortened))"
        case .offline: "Ngoại tuyến"
        case .unauthorized: "Sai mã truy cập"
        case .failed(let m): m
        }
    }
}
