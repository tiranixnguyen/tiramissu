import DesignSystem
import HanCore
import SwiftUI

/// App Mac — nơi học chính + soạn, nhập, cắt clip.
@main
struct TiramissuMacApp: App {
    @State private var model = AppModel.live()
    @State private var nav = Navigation()
    @State private var themes: ThemeStore
    @State private var server = ServerSettings()
    @State private var tts = TTS()
    @Environment(\.openWindow) private var openWindow

    init() {
        // Theme có sẵn + theme người dùng đã nhập (Application Support/Tiramissu/Themes).
        let builtIn = (try? ThemeCatalog.allBuiltIn()) ?? []
        _themes = State(initialValue: ThemeStore(themes: builtIn + ThemeLibrary.loadUserThemes().themes))
    }

    var body: some Scene {
        WindowGroup("Tiramissu") {
            MainWindow()
                .environment(model)
                .environment(nav)
                .environment(themes)
                .environment(tts)
                .themed(themes)
                .task {
                    model.configureAPI(baseURL: server.baseURL, token: { ServerSettings.currentToken() })
                    await model.start()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Màn hình") {
                ForEach(Array(MacScreen.allCases.enumerated()), id: \.element) { index, screen in
                    Button(screen.rawValue) { nav.screen = screen }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Bảng lệnh") { nav.showPalette.toggle() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Cửa sổ học gọn") { openWindow(id: "compact") }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                Button("Đổi sáng/tối") { themes.cycleAppearance() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }
        // Cửa sổ học gọn: nổi trên mọi cửa sổ, dùng chung lượt học với cửa sổ chính.
        Window("Học gọn", id: "compact") {
            StudyView(compact: true)
                .environment(model)
                .environment(themes)
                .environment(tts)
                .themed(themes)
                .frame(minWidth: 420, minHeight: 360)
                .background(.clear)
        }
        .windowLevel(.floating)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 460, height: 420)
        Settings {
            SettingsView()
                .environment(model)
                .environment(themes)
                .environment(server)
                .environment(tts)
                .themed(themes)
        }
    }
}
