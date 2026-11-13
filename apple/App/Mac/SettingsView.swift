import AVFoundation
import DesignSystem
import HanCore
import SwiftUI
import UniformTypeIdentifiers

/// Cài đặt (`⌘,`): Server · Giao diện · Giọng đọc.
struct SettingsView: View {
    var body: some View {
        TabView {
            ServerTab().tabItem { Label("Server", systemImage: "externaldrive.connected.to.line.below") }
            AppearanceTab().tabItem { Label("Giao diện", systemImage: "paintpalette") }
            VoiceTab().tabItem { Label("Giọng đọc", systemImage: "speaker.wave.2") }
        }
        .frame(width: 560, height: 440)
    }
}

// MARK: Server

private struct ServerTab: View {
    @Environment(AppModel.self) private var model
    @Environment(ServerSettings.self) private var server
    @State private var testing = false
    @State private var message: (text: String, ok: Bool)?

    var body: some View {
        @Bindable var server = server
        Form {
            Section {
                TextField("URL server", text: $server.urlText, prompt: Text("https://tiramissu.onrender.com"))
                    .autocorrectionDisabled()
                SecureField("Mã truy cập (API token)", text: $server.token)
            } footer: {
                Text("Token lưu trong Keychain, không lưu trong UserDefaults. Để trống URL = chỉ dùng offline.")
            }
            Section {
                HStack {
                    Button("Kiểm tra") { Task { await test() } }
                        .disabled(testing || server.baseURL == nil)
                    Button("Lưu và đồng bộ") { apply() }
                        .keyboardShortcut(.defaultAction)
                    if testing { ProgressView().controlSize(.small) }
                }
                if let message {
                    Label(message.text, systemImage: message.ok ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundStyle(message.ok ? Color.green : Color.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func test() async {
        testing = true
        defer { testing = false }
        switch await server.test() {
        case .success(let text): message = (text, true)
        case .failure(let error): message = (error.message, false)
        }
    }

    private func apply() {
        if !server.save() { message = ("Không ghi được token vào Keychain.", false); return }
        model.configureAPI(baseURL: server.baseURL, token: { ServerSettings.currentToken() })
        message = (server.baseURL == nil ? "Đã lưu — chạy offline." : "Đã lưu — đang đồng bộ.", true)
        Task { await model.syncNow() }
    }
}

// MARK: Giao diện

private struct JSONFile: FileDocument {
    static let readableContentTypes = [UTType.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct AppearanceTab: View {
    @Environment(ThemeStore.self) private var themes
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDoc = JSONFile(data: Data())
    @State private var error: String?

    var body: some View {
        @Bindable var themes = themes
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Chế độ", selection: $themes.appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(themes.themes) { t in
                        ThemePreviewTile(theme: t, isSelected: t.id == themes.themeID)
                            .onTapGesture { themes.themeID = t.id }
                    }
                }

                HStack {
                    Button("Nhập file .json…") { importing = true }
                    Button("Xuất theme đang dùng…") { export() }
                }
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
            }
            .padding(20)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: themes.current?.id ?? "theme") { _ in }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        error = nil
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let theme = try ThemeLibrary.install(
                Data(contentsOf: url), existingIDs: Set(themes.themes.map(\.id)))
            themes.add(theme)
            themes.themeID = theme.id
        } catch let e as ThemeError {
            error = e.message
        } catch {
            self.error = "Không đọc được file."
        }
    }

    private func export() {
        guard let theme = themes.current, let data = try? ThemeLibrary.export(theme) else { return }
        exportDoc = JSONFile(data: data)
        exporting = true
    }
}

// MARK: Giọng đọc

private struct VoiceTab: View {
    @Environment(TTS.self) private var tts

    var body: some View {
        @Bindable var tts = tts
        let voices = TTS.koreanVoices
        Form {
            if voices.isEmpty {
                Text("Máy chưa có giọng tiếng Hàn. Cài thêm ở Cài đặt hệ thống › Trợ năng › Nội dung đọc.")
            } else {
                Picker("Giọng", selection: $tts.voiceID) {
                    Text("Mặc định").tag("")
                    ForEach(voices, id: \.identifier) { Text($0.name).tag($0.identifier) }
                }
            }
            Slider(value: $tts.rate, in: 0.2...0.7) { Text("Tốc độ") }
            Button("Đọc thử") { tts.speak("안녕하세요. 만나서 반갑습니다.") }
        }
        .formStyle(.grouped)
    }
}
