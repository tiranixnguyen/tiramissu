import SwiftUI
import DesignSystem
import HanCore

/// App Mac — nơi học chính + soạn, nhập, cắt clip. Khung rỗng; các màn được dựng theo `docs/tasks.md` (GĐ2).
@main
struct TiramissuMacApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup("Tiramissu") {
            MainWindow()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 700)
                .task { await model.start() }
        }
        .windowToolbarStyle(.unified)
    }
}

/// Các màn trong sidebar, theo thứ tự `⌘1…⌘5`.
enum MacScreen: String, CaseIterable, Identifiable {
    case today = "Hôm nay"
    case study = "Học"
    case library = "Thư viện"
    case importAI = "Nhập từ AI"
    case audioClip = "Cắt clip âm thanh"

    var id: String { rawValue }
}

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var screen: MacScreen? = .today

    var body: some View {
        NavigationSplitView {
            List(MacScreen.allCases, selection: $screen) { item in
                Text(item.rawValue).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ContentUnavailableView(
                screen?.rawValue ?? "Tiramissu",
                systemImage: "hammer",
                description: Text(
                    "Màn này chưa được dựng — xem docs/tasks.md\n"
                        + "Dữ liệu: \(model.content.groups.count) nhóm · \(model.content.decks.count) bộ · "
                        + "\(model.content.decks.reduce(0) { $0 + $1.cards.count }) thẻ")
            )
        }
    }
}
