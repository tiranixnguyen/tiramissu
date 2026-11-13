import DesignSystem
import HanCore
import SwiftUI

/// App Mac — nơi học chính + soạn, nhập, cắt clip.
@main
struct TiramissuMacApp: App {
    @State private var model = AppModel.live()
    @State private var nav = Navigation()
    @State private var themes = ThemeStore()

    var body: some Scene {
        WindowGroup("Tiramissu") {
            MainWindow()
                .environment(model)
                .environment(nav)
                .environment(themes)
                .themed(themes)
                .task { await model.start() }
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
                Button("Bảng lệnh") { nav.showPalette.toggle() }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
