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
                Button("Đổi sáng/tối") { themes.cycleAppearance() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }
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
