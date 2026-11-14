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
    /// Nhóm đang chọn ở màn Thư viện (hiện ở sidebar); `nil` = nhóm đầu tiên.
    var libraryGroupId: String?
    /// Lớp độ rộng cửa sổ hiện tại (do `MainWindow` đo).
    var widthClass: WindowWidthClass = .wide
    /// Sidebar đang hiện hay ẩn — thanh trên chừa chỗ cho đèn giao thông + nút sidebar khi ẩn.
    var columnVisibility: NavigationSplitViewVisibility = .all
}

/// Lớp độ rộng cửa sổ — quyết định bố cục màn Hôm nay và việc tự ẩn sidebar.
/// Tính theo **cửa sổ** (không phải cột detail): ngưỡng trong issue #3 / prototype `Mac-Today-{1000,820}`
/// đo theo cửa sổ, và cùng ngưỡng đó quyết định ẩn sidebar — đo detail sẽ nhảy lớp khi sidebar ẩn/hiện.
enum WindowWidthClass: Equatable {
    case wide, medium, narrow

    /// Ngưỡng (pt) — sửa một chỗ này.
    static let wideMin: CGFloat = 1100
    static let mediumMin: CGFloat = 900

    static func from(_ width: CGFloat) -> WindowWidthClass {
        width >= wideMin ? .wide : width >= mediumMin ? .medium : .narrow
    }
}

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(AudioDocument.self) private var audioDoc
    @Environment(\.theme) private var theme
    /// Bộ thật học gần nhất — giữ ở sidebar kể cả khi đang mở bộ ảo.
    @State private var lastRealDeckId: String?

    var body: some View {
        @Bindable var nav = nav
        NavigationSplitView(columnVisibility: $nav.columnVisibility) {
            sidebar(selection: $nav.screen)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            detail
                .frame(minWidth: 620, minHeight: 600)
                .background(theme?.bg ?? .clear)
                .navigationTitle(nav.screen.rawValue)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            let next = WindowWidthClass.from(width)
            guard next != nav.widthClass else { return }
            withAnimation(.smooth) { nav.widthClass = next }
        }
        .onChange(of: model.state.currentDeckId, initial: true) { _, id in
            if let id, !isVirtualDeckId(id) { lastRealDeckId = id }
        }
        .onChange(of: nav.widthClass) { old, new in
            // Chỉ đổi lúc chuyển lớp — giữa chừng người dùng tự bật/tắt bằng ⌃⌘S / nút toolbar.
            if new == .narrow {
                nav.columnVisibility = .detailOnly
            } else if old == .narrow {
                nav.columnVisibility = .all
            }
        }
        .overlay {
            if nav.showPalette { CommandPalette() }
        }
    }

    // MARK: Sidebar

    private var dueCardCount: Int {
        computeTodayPlan(decks: model.content.decks, history: model.history, now: Date()).dueCardCount
    }

    private var sortedGroups: [ContentGroup] { model.content.groups.sorted { $0.position < $1.position } }

    private func sidebar(selection: Binding<MacScreen>) -> some View {
        // Không dùng selection gốc của List: màn Học chuyển focus bàn phím sang ô trả lời,
        // List mất focus thì highlight chuyển xám. Tự vẽ nền xanh để không phụ thuộc focus.
        List {
            ForEach(MacScreen.allCases) { item in
                mainRow(item, selection: selection)
                switch item {
                case .study: studyChildren
                case .library where nav.screen == .library: libraryChildren
                case .audioClip where nav.screen == .audioClip: audioChildren
                default: EmptyView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) { SyncFooter(status: model.syncStatus) }
    }

    @ViewBuilder private func mainRow(_ item: MacScreen, selection: Binding<MacScreen>) -> some View {
        let selected = selection.wrappedValue == item
        let chevron: String? = switch item {
        case .study: "chevron.down"
        case .library, .audioClip: selected ? "chevron.down" : "chevron.right"
        default: nil
        }
        Button { selection.wrappedValue = item } label: {
            HStack(spacing: 8) {
                Image(systemName: item.symbol).frame(width: 18)
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                Text(item.rawValue).lineLimit(1).truncationMode(.tail)
                    .fontWeight(selected ? .semibold : .regular)
                Spacer(minLength: 4)
                if item == .today {
                    Text("\(dueCardCount)").monospacedDigit().lineLimit(1)
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
                }
                if let chevron {
                    Image(systemName: chevron).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
                }
            }
            .foregroundStyle(selected ? Color.white : .primary)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
        .selectionDisabled()
    }

    // MARK: Mục con

    /// Học — luôn mở: bộ thật đang học (nếu có) + các bộ ảo.
    @ViewBuilder private var studyChildren: some View {
        let state = model.state
        let current = nav.screen == .study ? state.currentDeckId : nil
        if let id = lastRealDeckId,
           let deck = model.content.decks.first(where: { $0.id == id }) {
            let isCurrent = current == id
            subButton(.dot, deck.name, count: isCurrent ? "\(state.masteredCount)/\(state.totalCount)" : nil,
                selected: isCurrent) { openDeck(id) }
        }
        subButton(.symbol("star.fill"), "Từ khó nhớ", count: "\(state.markedCount)",
            selected: current == markedDeckId) { openDeck(markedDeckId) }
        subButton(.text("漢"), "Hán Hàn", count: "\(state.hanjaCount)",
            selected: current == hanjaDeckId) { openDeck(hanjaDeckId) }
        subButton(.symbol("text.alignleft"), "Đoạn văn", count: "\(state.passageCount)",
            selected: current == passageDeckId) { openDeck(passageDeckId) }
        subButton(.symbol("shuffle"), "Ngẫu nhiên", count: "20",
            selected: current == randomDeckId) { openDeck(randomDeckId) }
        subButton(.symbol("headphones"), "Clip nghe", count: "\(model.content.clips.count)",
            selected: current == clipsDeckId) { openDeck(clipsDeckId) }
            .disabled(model.content.clips.isEmpty)
    }

    /// Thư viện — các nhóm, chỉ hiện khi đang ở màn Thư viện.
    @ViewBuilder private var libraryChildren: some View {
        let groups = sortedGroups
        let currentId = nav.libraryGroupId ?? groups.first?.id
        ForEach(groups) { g in
            subButton(.dot, g.name,
                count: "\(model.content.decks.filter { $0.groupId == g.id }.count)",
                selected: currentId == g.id) { nav.libraryGroupId = g.id }
        }
    }

    /// Cắt clip — file gần đây + "Mở file…", chỉ hiện khi đang ở màn Cắt clip.
    @ViewBuilder private var audioChildren: some View {
        ForEach(audioDoc.recent) { item in
            subButton(.symbol("waveform"), item.name, count: nil,
                selected: item.name == audioDoc.name) { audioDoc.open(item) }
        }
        subButton(.symbol("folder"), "Mở file…", count: "⌘O", selected: false) {
            audioDoc.requestImport = true
        }
    }

    private func subButton(
        _ glyph: SidebarSubRow.Glyph, _ title: String, count: String?, selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SidebarSubRow(glyph: glyph, title: title, count: count, selected: selected)
        }
        .buttonStyle(.plain)
        // Mục con không phải đích chọn của List — bấm vào không được làm mất highlight của mục cha.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    private func openDeck(_ id: String) {
        model.switchDeck(id)
        nav.screen = .study
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
        } else if nav.screen == .audioClip {
            AudioClipView()
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
}

/// Mục con trong sidebar dạng cây: thụt lề, đường dọc mảnh thẳng tâm icon cha;
/// đang chọn → nền `ink` 6% + vạch `accent` 2pt đè lên đường dọc.
struct SidebarSubRow: View {
    enum Glyph {
        case symbol(String)
        case text(String)
        /// Chấm tròn — bộ thật đang học.
        case dot
    }

    let glyph: Glyph
    let title: String
    let count: String?
    let selected: Bool

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    /// Tâm icon của mục cha (tính từ mép trái hàng List).
    private static let guideX: CGFloat = 18

    var body: some View {
        let ink = theme?.ink ?? .primary
        HStack(spacing: 8) {
            glyphView.frame(width: 16).foregroundStyle(selected ? ink : (theme?.ink2 ?? .secondary))
            Text(title).lineLimit(1).truncationMode(.tail)
                .fontWeight(selected ? .semibold : .regular)
            Spacer(minLength: 4)
            if let count {
                Text(count).monospacedDigit().foregroundStyle(theme?.ink2 ?? .secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? ink.opacity(0.06) : .clear))
        .padding(.leading, Self.guideX + 10).padding(.trailing, 2).padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            ZStack {
                Rectangle().fill(ink.opacity(0.14)).frame(width: 1)
                if selected {
                    RoundedRectangle(cornerRadius: 1).fill(theme?.accent ?? .accentColor)
                        .frame(width: 2).padding(.vertical, 4)
                }
            }
            .frame(width: 2)
            .offset(x: Self.guideX - 1)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var glyphView: some View {
        switch glyph {
        case .symbol(let name): Image(systemName: name).font(.system(size: 11))
        case .text(let t): Text(t).font(.system(size: 12))
        case .dot: Circle().frame(width: 5, height: 5)
        }
    }
}

/// Trạng thái đồng bộ ở chân sidebar: chấm màu + chữ + thời gian tương đối căn phải.
private struct SyncFooter: View {
    let status: SyncStatus
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            Text(text).font(.caption).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if case .synced(let date) = status {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.relative(date, now: context.date)).font(.caption).monospacedDigit().lineLimit(1)
                }
            }
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .help("Cài đặt (⌘,)")
        }
        .foregroundStyle(theme?.ink2 ?? .secondary)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var dotColor: Color {
        switch status {
        case .synced: theme?.ok ?? .green
        case .syncing: theme?.accent ?? .accentColor
        case .idle: theme?.ink2 ?? .secondary
        case .offline, .unauthorized, .failed: theme?.bad ?? .red
        }
    }

    private var text: String {
        switch status {
        case .idle: "Chưa đồng bộ"
        case .syncing: "Đang đồng bộ…"
        case .synced: "Đã đồng bộ"
        case .offline: "Ngoại tuyến"
        case .unauthorized: "Sai mã truy cập"
        case .failed(let m): m
        }
    }

    /// "2 phút", "3 giờ"… — bỏ chữ "trước" cho gọn ở chân sidebar.
    static func relative(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "vừa xong" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.unitsStyle = .full
        f.dateTimeStyle = .numeric
        return f.localizedString(for: date, relativeTo: now)
            .replacingOccurrences(of: " trước", with: "")
    }
}
