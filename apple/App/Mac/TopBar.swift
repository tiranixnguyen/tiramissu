import DesignSystem
import SwiftUI

// Thanh trên các màn Mac (như prototype): MỘT thanh kính trải ngang màn, tiêu đề bên trái,
// nút viền mảnh bên phải (nút riêng của màn → theme → sáng/tối).
//
// Cách dựng — không đo vị trí gì (đo toạ độ mục toolbar không tin được: lúc mở app chưa có số):
// - Toolbar hệ thống vẫn giữ đèn giao thông, nút sidebar, hoạt ảnh ẩn/hiện sidebar, và các NÚT bên phải
//   (mục toolbar thật → bấm được). Nút bỏ nền kính riêng (`sharedBackgroundVisibility(.hidden)`) để
//   nằm gọn trong thanh. Một mục `.principal` vô hình giữ cụm nút dạt sát phải.
// - Khung kính + tiêu đề vẽ trong nội dung, nằm dưới vùng toolbar, không bắt chuột. Toolbar macOS
//   chốt kích thước mục ngay lần đầu và căn `.principal` vào giữa nên tiêu đề không đặt trong toolbar được.
// - Sidebar ẩn: thanh chạy từ mép trái cửa sổ (bọc cả đèn giao thông + nút sidebar như prototype 820),
//   tiêu đề lùi vào sau nút sidebar.

extension View {
    /// Gắn thanh trên chuẩn cho một màn. `title`: chỉ hiển thị (không bấm được).
    /// `actions`: nút riêng của màn, đứng trước nút theme — nên dùng `TopBarButtonStyle`.
    func screenTopBar<Title: View, Actions: View>(
        @ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        modifier(ScreenTopBar(title: title(), actions: actions()))
    }
}

enum TopBarMetrics {
    /// Cao thanh — tâm dọc trùng tâm đèn giao thông / nút sidebar của toolbar hệ thống.
    static let height: CGFloat = 44
    static let top: CGFloat = 4
    static let sideInset: CGFloat = 6
    /// Lề trái tiêu đề khi sidebar ẩn: chừa đèn giao thông + nút sidebar của hệ thống.
    static let leadingWhenSidebarHidden: CGFloat = 140
    /// Khoảng hở giữa các mục toolbar + khoảng lùi phải mà bản sao giữ chỗ không có.
    static let trailingSlack: CGFloat = 24
    static let leading: CGFloat = 16
}

private struct ScreenTopBar<Title: View, Actions: View>: ViewModifier {
    @Environment(Navigation.self) private var nav
    let title: Title
    let actions: Actions

    @ViewBuilder private var trailingButtons: some View {
        actions
        ThemeCycleButton()
        AppearanceButton()
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                TopBarGlass(leading: nav.columnVisibility == .detailOnly
                    ? TopBarMetrics.leadingWhenSidebarHidden : TopBarMetrics.leading) {
                    HStack(spacing: 12) {
                        title.frame(maxWidth: .infinity, alignment: .leading)
                        // Bản sao vô hình của cụm nút toolbar: giữ chỗ để tiêu đề không chui dưới nút
                        // (cùng view → cùng bề rộng, tính ngay lần layout đầu, không cần đo toạ độ).
                        HStack(spacing: 6) { trailingButtons }
                            .padding(.trailing, TopBarMetrics.trailingSlack)
                            .hidden()
                            .accessibilityHidden(true)
                    }
                }
                    .padding(.horizontal, TopBarMetrics.sideInset)
                    .padding(.top, TopBarMetrics.top)
                    .ignoresSafeArea(edges: .top)
                    // Không bắt chuột: vùng này vẫn kéo được cửa sổ như toolbar.
                    .allowsHitTesting(false)
            }
            .navigationTitle("")
            .toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItemGroup(placement: .primaryAction) { trailingButtons }
                .sharedBackgroundVisibility(.hidden)
                // Lùi cụm nút khỏi mép phải thanh.
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}

/// Khung kính của thanh trên (chỉ hiển thị).
struct TopBarGlass<Content: View>: View {
    var leading: CGFloat = TopBarMetrics.leading
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, leading).padding(.trailing, 10)
            .frame(height: TopBarMetrics.height)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .animation(.smooth, value: leading)
    }
}

/// Nút trên thanh trên: cao 34, bo 10, viền `ink` 20% (thường) hoặc nền `accent` (nổi bật).
struct TopBarButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(prominent ? (theme?.onAccent ?? .white) : (theme?.ink ?? .primary))
            .padding(.horizontal, 12)
            .frame(minWidth: 34, minHeight: 34)
            // Viền/nền lấy từ `ink` pha trong suốt thay vì `line`: trên nền kính tối, `line` gần như
            // trùng màu kính nên nút trông mờ.
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(prominent ? (theme?.accent ?? .accentColor) : (theme?.ink ?? .primary).opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(prominent ? .clear : (theme?.ink ?? .primary).opacity(0.2)))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : isEnabled ? 1 : 0.45)
            .padding(.horizontal, 3)
    }
}

/// Tiêu đề một dòng: phần chính đậm + phần phụ "· …" màu `ink2`; dài thì cắt "…".
struct TopBarTitle: View {
    @Environment(\.theme) private var theme
    let main: String
    var detail: String?
    var detailSize: CGFloat = 15

    var body: some View {
        (Text(main).font(.system(size: 15, weight: .semibold))
            + Text(detail.map { " · \($0)" } ?? "")
            .font(.system(size: detailSize, weight: .medium))
            .foregroundColor(theme?.ink2 ?? .secondary))
            .lineLimit(1).truncationMode(.tail)
    }
}

/// "Lệnh ⌘K" — mở bảng lệnh. Phím ⌘K đã nằm ở menu, nút không gán lại.
struct PaletteButton: View {
    @Environment(Navigation.self) private var nav

    var body: some View {
        Button { nav.showPalette.toggle() } label: {
            HStack(spacing: 8) {
                Text("Lệnh")
                Kbd("⌘K")
            }
        }
        .buttonStyle(TopBarButtonStyle())
        .help("Bảng lệnh (⌘K)")
    }
}

/// Chấm màu nhấn + tên theme; bấm để đổi theme kế tiếp.
struct ThemeCycleButton: View {
    @Environment(ThemeStore.self) private var themes
    @Environment(\.theme) private var theme

    var body: some View {
        Button { themes.cycleTheme() } label: {
            HStack(spacing: 6) {
                Circle().fill(theme?.accent ?? .accentColor).frame(width: 12, height: 12)
                Text(themes.current?.name ?? "")
            }
        }
        .buttonStyle(TopBarButtonStyle())
        .help("Đổi theme")
    }
}

/// Sáng / tối / theo hệ thống (⌥⌘D nằm ở menu).
struct AppearanceButton: View {
    @Environment(ThemeStore.self) private var themes

    var body: some View {
        Button { themes.cycleAppearance() } label: {
            Image(systemName: themes.appearance.symbol).font(.system(size: 14)).padding(.horizontal, -4)
        }
            .buttonStyle(TopBarButtonStyle())
            .help("Giao diện: \(themes.appearance.label) (⌥⌘D)")
    }
}
