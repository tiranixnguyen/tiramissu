import AVFoundation
import Foundation
import Observation

/// File âm thanh gần đây — nhớ bằng security-scoped bookmark để mở lại sau khi khởi động lại app.
struct RecentAudio: Codable, Identifiable, Hashable {
    var id: String { name + String(bookmark.hashValue) }
    var name: String
    var bookmark: Data
}

/// File đang mở trong màn Cắt clip + danh sách file gần đây.
@MainActor @Observable
final class AudioDocument {
    static let allowedExtensions = ["mp3", "m4a", "wav"]
    private static let recentKey = "audio.recent"
    private static let maxRecent = 8

    let player = AudioPlayer()
    private(set) var url: URL?
    var name: String { url?.lastPathComponent ?? "" }
    private(set) var waveform: Waveform?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var recent: [RecentAudio] = []

    @ObservationIgnored private var scopedURL: URL?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() { recent = Self.loadRecent() }

    var duration: TimeInterval { waveform?.duration ?? 0 }

    /// Mở file người dùng vừa chọn / kéo thả.
    func open(_ url: URL) {
        guard Self.allowedExtensions.contains(url.pathExtension.lowercased()) else {
            error = "Chỉ mở được mp3, m4a, wav."
            return
        }
        load(url, scoped: url.startAccessingSecurityScopedResource())
        if let data = try? url.bookmarkData(options: .withSecurityScope) {
            remember(RecentAudio(name: url.lastPathComponent, bookmark: data))
        }
    }

    /// Mở lại từ danh sách gần đây.
    func open(_ item: RecentAudio) {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: item.bookmark, options: .withSecurityScope, relativeTo: nil,
            bookmarkDataIsStale: &stale)
        else {
            error = "Không tìm thấy “\(item.name)” — file đã bị đổi chỗ hoặc xoá."
            recent.removeAll { $0 == item }
            Self.saveRecent(recent)
            return
        }
        load(url, scoped: url.startAccessingSecurityScopedResource())
        if stale, let data = try? url.bookmarkData(options: .withSecurityScope) {
            remember(RecentAudio(name: item.name, bookmark: data))
        }
    }

    func close() {
        loadTask?.cancel()
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        url = nil
        waveform = nil
        isLoading = false
        player.unload()
    }

    private func load(_ url: URL, scoped: Bool) {
        loadTask?.cancel()
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = scoped ? url : nil
        self.url = url
        waveform = nil
        error = nil
        player.load(url)
        isLoading = true
        loadTask = Task { [weak self] in
            do {
                let result = try await WaveformExtractor.extract(url: url)
                guard !Task.isCancelled, let self, self.url == url else { return }
                self.waveform = result
                self.isLoading = false
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.url == url else { return }
                self.error = "Không đọc được file âm thanh này."
                self.isLoading = false
                self.waveform = nil
            }
        }
    }

    // MARK: Gần đây

    private func remember(_ item: RecentAudio) {
        recent.removeAll { $0.name == item.name }
        recent.insert(item, at: 0)
        recent = Array(recent.prefix(Self.maxRecent))
        Self.saveRecent(recent)
    }

    private static func loadRecent() -> [RecentAudio] {
        guard let data = UserDefaults.standard.data(forKey: recentKey) else { return [] }
        return (try? JSONDecoder().decode([RecentAudio].self, from: data)) ?? []
    }

    private static func saveRecent(_ items: [RecentAudio]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: recentKey)
    }
}
