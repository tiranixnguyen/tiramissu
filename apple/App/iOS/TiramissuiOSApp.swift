import AVFoundation
import DesignSystem
import HanCore
import SwiftUI

/// App iPhone — chỉ học và ôn (GĐ4). Dùng chung `AppModel`, `ThemeStore`, cấu hình server với Mac.
@main
struct TiramissuiOSApp: App {
    @State private var model = AppModel.live()
    @State private var themes: ThemeStore
    @State private var server = ServerSettings()
    @State private var nav = PhoneNav()
    @State private var tts = TTS()

    init() {
        // Theme có sẵn + theme người dùng đã nhập (Application Support/Tiramissu/Themes).
        let builtIn = (try? ThemeCatalog.allBuiltIn()) ?? []
        _themes = State(initialValue: ThemeStore(themes: builtIn + ThemeLibrary.loadUserThemes().themes))
        // Clip và TTS vẫn phát khi gạt nút im lặng.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .environment(model)
                .environment(themes)
                .environment(nav)
                .environment(tts)
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

/// Điều hướng chung để màn này chuyển tab màn kia (vd "Bắt đầu ôn" → tab Học).
@MainActor @Observable
final class PhoneNav {
    var tab: PhoneTab = .today
}

struct PhoneRoot: View {
    @Environment(\.theme) private var theme
    @Environment(PhoneNav.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            Tab("Hôm nay", systemImage: "house", value: .today) {
                PhoneTodayView()
            }
            Tab("Học", systemImage: "rectangle.on.rectangle", value: .study) {
                PhoneStudyView()
            }
            Tab("Nghe", systemImage: "headphones", value: .listen) {
                PhoneListenView()
            }
        }
        .tint(theme?.accent)
    }
}
