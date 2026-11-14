import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// Màn "Cắt clip âm thanh": mở file → dạng sóng. (Phát A–B ở T3.03, lưu clip ở T3.04.)
struct AudioClipView: View {
    @Environment(AudioDocument.self) private var doc
    @Environment(\.theme) private var theme
    @State private var importing = false
    @State private var windowStart: TimeInterval = 0
    @State private var windowLength: TimeInterval = 30
    @State private var dropTargeted = false

    private static let minWindow: TimeInterval = 4

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            filesColumn.frame(width: 240)
            VStack(spacing: 10) {
                header
                waveCard
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
        .fileImporter(isPresented: $importing, allowedContentTypes: Self.contentTypes) { result in
            if case .success(let url) = result { doc.open(url) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            doc.open(url)
            return true
        } isTargeted: { dropTargeted = $0 }
        .onChange(of: doc.duration) { _, d in
            windowStart = 0
            windowLength = d > 0 ? min(30, d) : 30
        }
        .overlay { dropOverlay }
        .navigationTitle("Cắt clip âm thanh")
    }

    private static let contentTypes: [UTType] =
        AudioDocument.allowedExtensions.compactMap { UTType(filenameExtension: $0) }

    // MARK: Cột file

    private var filesColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { importing = true } label: {
                Label("Mở file…", systemImage: "folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .keyboardShortcut("o", modifiers: .command)

            Text("FILE GẦN ĐÂY").font(.system(size: 11, weight: .semibold)).foregroundStyle(ink2)
            if doc.recent.isEmpty {
                Text("Chưa có file nào.").font(.callout).foregroundStyle(ink2)
            }
            ForEach(doc.recent) { item in
                Button { doc.open(item) } label: {
                    Text(item.name).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(item.name == doc.name ? (theme?.accent ?? .accentColor).opacity(0.18) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("Kéo thả file âm thanh vào cửa sổ\nmp3 · m4a · wav")
                .font(.caption).foregroundStyle(ink2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(14)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(line))
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(panel)
    }

    // MARK: Phần chính

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(doc.url == nil ? "Chưa mở file" : doc.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
            Text(doc.url == nil
                ? "Mở hoặc kéo thả file để bắt đầu cắt clip"
                : "\(timeText(doc.duration)) · file gốc ở yên trên Mac, chỉ đoạn cắt được đồng bộ")
                .font(.system(size: 13)).foregroundStyle(ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(panel)
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
                WaveformView(waveform: wave, windowStart: $windowStart, windowLength: windowLength)
                    .frame(height: 220)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme?.bg ?? .clear))
                if wave.duration > windowLength {
                    Slider(value: $windowStart, in: 0...max(0.1, wave.duration - windowLength))
                        .controlSize(.small)
                }
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
