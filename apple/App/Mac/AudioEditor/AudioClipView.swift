import DesignSystem
import HanCore
import SwiftUI
import UniformTypeIdentifiers

/// Màn "Cắt clip âm thanh": mở file → dạng sóng. (Phát A–B ở T3.03, lưu clip ở T3.04.)
struct AudioClipView: View {
    @Environment(AudioDocument.self) private var doc
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var windowStart: TimeInterval = 0
    @State private var windowLength: TimeInterval = 30
    @State private var dropTargeted = false
    @State private var transcript = ""
    @State private var translation = ""
    @State private var deckId = ""
    @State private var saving = false
    @State private var message: (text: String, ok: Bool)?
    @FocusState private var typing: Bool

    private static let minWindow: TimeInterval = 4

    var body: some View {
        @Bindable var doc = doc
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                waveCard
                if doc.waveform != nil { form }
                Spacer(minLength: 0)
                if doc.waveform != nil { playerBar.padding(.bottom, 4) }
            }
            .frame(maxWidth: .infinity)
            clipsColumn.frame(width: 260)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
        .fileImporter(isPresented: $doc.requestImport, allowedContentTypes: Self.contentTypes) { result in
            if case .success(let url) = result { doc.open(url) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            doc.open(url)
            return true
        } isTargeted: { dropTargeted = $0 }
        .onChange(of: doc.player.position) { _, p in
            // Đầu phát chạy ra ngoài khung đang xem → cuộn theo.
            guard doc.player.isPlaying, p < windowStart || p > windowStart + windowLength else { return }
            windowStart = min(max(0, p - windowLength * 0.1), max(0, doc.duration - windowLength))
        }
        .onDisappear { doc.player.pause() }
        .onChange(of: doc.duration) { _, d in
            windowStart = 0
            windowLength = d > 0 ? min(30, d) : 30
        }
        .overlay { dropOverlay }
        .background {
            // ⌘O luôn dùng được, kể cả khi sidebar ẩn và đã mở file (nút trên thanh trên chỉ hiện lúc chưa mở).
            Button("") { doc.requestImport = true }
                .keyboardShortcut("o", modifiers: .command).opacity(0).frame(width: 0, height: 0)
        }
        .screenTopBar { topBarTitle } actions: {
            if doc.url == nil {
                Button { doc.requestImport = true } label: {
                    HStack(spacing: 6) {
                        Text("Mở file…")
                        Kbd("⌘O")
                    }
                }
                .buttonStyle(TopBarButtonStyle())
                .help("Mở file âm thanh (⌘O)")
            }
        }
    }

    private static let contentTypes: [UTType] =
        AudioDocument.allowedExtensions.compactMap { UTType(filenameExtension: $0) }

    // MARK: Phần chính

    /// Tiêu đề thanh trên: tên file + độ dài · thư mục · ghi chú (file gần đây nằm ở sidebar).
    private var topBarTitle: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(doc.url == nil ? "Cắt clip âm thanh" : doc.name)
                .font(.system(size: 14, weight: .semibold))
            Text(topBarDetail).font(.system(size: 12)).foregroundStyle(ink2)
        }
        .lineLimit(1).truncationMode(.tail)
    }

    private var topBarDetail: String {
        guard let url = doc.url else { return "Mở hoặc kéo thả file (mp3 · m4a · wav) để bắt đầu cắt clip" }
        let folder = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        let total = Int(doc.duration.rounded())
        let length = doc.duration > 0 ? String(format: "%d:%02d · ", total / 60, total % 60) : ""
        return "\(length)\(folder) · file gốc ở yên trên Mac, chỉ đoạn cắt được đồng bộ"
    }

    @ViewBuilder private var waveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let wave = doc.waveform {
                HStack {
                    Text(timeText(windowStart)).monospacedDigit()
                    Spacer()
                    Text("Đang xem \(Int(windowLength.rounded())) giây").foregroundStyle(ink2)
                    Button { zoom(in: true) } label: { Image(systemName: "plus.magnifyingglass") }
                        .keyboardShortcut("=", modifiers: .command).help("Phóng to (⌘+)")
                    Button { zoom(in: false) } label: { Image(systemName: "minus.magnifyingglass") }
                        .keyboardShortcut("-", modifiers: .command).help("Thu nhỏ (⌘−)")
                    Spacer()
                    Text(timeText(min(wave.duration, windowStart + windowLength))).monospacedDigit()
                }
                .font(.system(size: 12, design: .monospaced)).buttonStyle(.plain)
                WaveformView(
                    waveform: wave, windowStart: $windowStart, windowLength: windowLength,
                    pointA: doc.player.pointA, pointB: doc.player.pointB, playhead: doc.player.position,
                    onSeek: { doc.player.seek(to: $0) }
                )
                    .frame(height: 220)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme?.bg ?? .clear))
                if wave.duration > windowLength {
                    Slider(value: $windowStart, in: 0...max(0.1, wave.duration - windowLength))
                        .controlSize(.small)
                }
                HStack {
                    Text("Đầu \(timeText(doc.player.position))")
                    Spacer()
                    if doc.player.hasRange, let a = doc.player.pointA, let b = doc.player.pointB {
                        Text("A \(timeText(a)) → B \(timeText(b)) · dài \(String(format: "%.1f", b - a))s")
                    } else {
                        Text("Đặt A bằng [ và B bằng ]")
                    }
                }
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(ink2)
            } else if doc.isLoading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Đang đọc dạng sóng…") }
                    .foregroundStyle(ink2).frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Text(doc.error ?? "Dạng sóng sẽ hiện ở đây.")
                    .foregroundStyle(doc.error == nil ? ink2 : (theme?.bad ?? .red))
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .padding(16)
        .background(panel)
    }

    @ViewBuilder private var dropOverlay: some View {
        if dropTargeted {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(theme?.accent ?? .accentColor, lineWidth: 2).padding(4).allowsHitTesting(false)
        }
    }

    // MARK: Thanh nút

    /// Hai hàng nút kính, mỗi nút giữ nguyên kích thước (không bị nén thành "…").
    private var playerBar: some View {
        let p = doc.player
        let plain = !typing
        return GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    barButton("−2s", key: .init(.leftArrow, modifiers: .command)) { p.skip(-2) }
                    barButton(p.isPlaying ? "Dừng" : "Phát", kbd: "Space", prominent: true,
                        key: plain ? .init(.space, modifiers: []) : nil) { p.toggle() }
                    barButton("+2s", key: .init(.rightArrow, modifiers: .command)) { p.skip(2) }
                    barButton("Lặp", kbd: "L", prominent: p.loops,
                        key: plain ? .init("l", modifiers: []) : nil) { p.loops.toggle() }
                    barButton(String(format: "%g×", p.rate), kbd: "R",
                        key: plain ? .init("r", modifiers: []) : nil) {
                        p.setRate(p.rate == 1 ? 0.75 : p.rate == 0.75 ? 0.5 : 1)
                    }
                }
                HStack(spacing: 10) {
                    barButton("Đặt A", kbd: "[", key: plain ? .init("[", modifiers: []) : nil) { p.setA() }
                    barButton("Đặt B", kbd: "]", key: plain ? .init("]", modifiers: []) : nil) { p.setB() }
                    barButton("B −0.1s", kbd: "⌥←", enabled: p.pointB != nil,
                        key: .init(.leftArrow, modifiers: .option)) { p.nudgeB(-0.1) }
                    barButton("B +0.1s", kbd: "⌥→", enabled: p.pointB != nil,
                        key: .init(.rightArrow, modifiers: .option)) { p.nudgeB(0.1) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barButton(
        _ title: String, kbd: String? = nil, prominent: Bool = false, enabled: Bool = true,
        key: KeyboardShortcut? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).lineLimit(1)
                if let kbd { Kbd(kbd) }
            }
            .fixedSize()
            .padding(.horizontal, 4)
        }
        .buttonStyle(.glass)
        .tint(prominent ? theme?.accent : nil)
        .disabled(!enabled)
        .modifier(OptionalKey(key: key))
    }

    // MARK: Form lưu clip

    private var canSave: Bool {
        let p = doc.player
        guard let a = p.pointA, let b = p.pointB else { return false }
        return !saving && b > a && b - a <= 60
            && !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Câu nghe được (tiếng Hàn)").font(.system(size: 13, weight: .semibold))
            TextEditor(text: $transcript)
                .font(.system(size: 20)).scrollContentBackground(.hidden).focused($typing)
                .frame(height: 72).padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme?.bg ?? .clear)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(line)))
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nghĩa tiếng Việt").font(.system(size: 13, weight: .semibold))
                    TextField("Không bắt buộc", text: $translation).textFieldStyle(.roundedBorder).focused($typing)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gắn vào bộ").font(.system(size: 13, weight: .semibold))
                    Picker("", selection: $deckId) {
                        Text("Không gắn").tag("")
                        ForEach(model.content.decks.sorted { $0.position < $1.position }) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 200)
                }
                Button { Task { await save() } } label: {
                    HStack(spacing: 6) { Text("Lưu clip").fontWeight(.semibold); Kbd("⌘S") }
                }
                .buttonStyle(.glassProminent).tint(theme?.accent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!canSave)
            }
            Text(message?.text ?? "Lưu = xuất đoạn A–B thành M4A → tải lên server → có trên iPhone ở lần đồng bộ sau. Clip dài tối đa 60 giây.")
                .font(.caption).foregroundStyle(message.map { $0.ok ? (theme?.ok ?? .green) : (theme?.bad ?? .red) } ?? ink2)
        }
        .padding(16)
        .background(panel)
    }

    private func save() async {
        guard let url = doc.url, let a = doc.player.pointA, let b = doc.player.pointB else { return }
        saving = true
        defer { saving = false }
        do {
            let data = try await ClipExporter.exportM4A(from: url, start: a, end: b)
            let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            let new = NewClip(
                audioId: "", sourceName: doc.name, startMs: Int(a * 1000), endMs: Int(b * 1000),
                transcript: text, translation: meaning.isEmpty ? nil : meaning, deckId: deckId.isEmpty ? nil : deckId)
            try await model.createClip(audio: data, new)
            message = ("Đã lưu clip.", true)
            transcript = ""
            translation = ""
            doc.player.pointA = nil
            doc.player.pointB = nil
        } catch let error as ClipExportError {
            message = (error.localizedDescription, false)
        } catch let error as APIError {
            message = (error.message, false)
        } catch {
            message = ("Không lưu được clip.", false)
        }
    }

    // MARK: Cột clip đã cắt

    private var fileClips: [Clip] {
        model.content.clips.filter { $0.sourceName == doc.name }.sorted { $0.startMs < $1.startMs }
    }

    private var clipsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clip đã cắt · \(fileClips.count)").font(.system(size: 15, weight: .semibold))
                if fileClips.isEmpty {
                    Text(doc.url == nil ? "Mở file để xem các clip đã cắt." : "Chưa cắt clip nào từ file này.")
                        .font(.callout).foregroundStyle(ink2)
                }
                ForEach(fileClips) { clip in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(timeText(Double(clip.startMs) / 1000)) → \(timeText(Double(clip.endMs) / 1000))")
                            Spacer()
                            Text(String(format: "%.1fs", Double(clip.durationMs) / 1000))
                        }
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(ink2)
                        Text(clip.transcript).font(.system(size: 15, weight: .semibold))
                        if let t = clip.translation { Text(t).font(.system(size: 13)).foregroundStyle(ink2) }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(panel)
                    .onTapGesture {
                        doc.player.pointA = Double(clip.startMs) / 1000
                        doc.player.pointB = Double(clip.endMs) / 1000
                        doc.player.seek(to: Double(clip.startMs) / 1000)
                    }
                }
            }
        }
    }

    // MARK: Hỗ trợ

    private func zoom(in zoomIn: Bool) {
        let limit = max(Self.minWindow, doc.duration)
        let next = zoomIn ? windowLength / 2 : windowLength * 2
        let centre = windowStart + windowLength / 2
        windowLength = min(max(next, Self.minWindow), limit)
        windowStart = min(max(0, centre - windowLength / 2), max(0, doc.duration - windowLength))
    }

    private func timeText(_ t: TimeInterval) -> String {
        let total = max(0, t)
        return String(format: "%d:%04.1f", Int(total) / 60, total.truncatingRemainder(dividingBy: 60))
    }

    private var ink2: Color { theme?.ink2 ?? .secondary }
    private var line: Color { theme?.line ?? .secondary }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(line))
    }
}

private struct OptionalKey: ViewModifier {
    let key: KeyboardShortcut?
    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key) } else { content }
    }
}
