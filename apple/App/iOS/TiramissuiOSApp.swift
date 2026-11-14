import DesignSystem
import HanCore
import SwiftUI

/// App iPhone — chỉ học và ôn (GĐ4). Dùng chung `AppModel`, `ThemeStore`, cấu hình server với Mac.
@main
struct TiramissuiOSApp: App {
    @State private var model = AppModel.live()
    @State private var themes: ThemeStore
    @State private var server = ServerSettings()

    init() {
        // Theme có sẵn + theme người dùng đã nhập (Application Support/Tiramissu/Themes).
        let builtIn = (try? ThemeCatalog.allBuiltIn()) ?? []
        _themes = State(initialValue: ThemeStore(themes: builtIn + ThemeLibrary.loadUserThemes().themes))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .environment(model)
                .environment(themes)
                .themed(themes)
                .task {
                    model.configureAPI(baseURL: server.baseURL, token: { ServerSettings.currentToken() })
                    await model.start()
                }
        }
    }
}

/// Tab trên iPhone. Tab bar kính của hệ thống (iOS 26) — không tự vẽ.
enum PhoneTab: Hashable {
    case today, study, listen
}

struct PhoneRoot: View {
    @Environment(\.theme) private var theme
    @State private var tab: PhoneTab = .today

    var body: some View {
        TabView(selection: $tab) {
            Tab("Hôm nay", systemImage: "house", value: .today) {
                placeholder("Hôm nay", task: "T4.02")
            }
            Tab("Học", systemImage: "rectangle.on.rectangle", value: .study) {
                placeholder("Học", task: "T4.03")
            }
            Tab("Nghe", systemImage: "headphones", value: .listen) {
                placeholder("Nghe", task: "T4.04")
            }
        }
        .tint(theme?.accent)
    }

    private func placeholder(_ title: String, task: String) -> some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("Làm ở \(task)"))
            .foregroundStyle(theme?.ink ?? .primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme?.bg ?? .clear)
    }
}
