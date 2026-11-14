import AVFoundation

enum ClipExportError: LocalizedError {
    case failed
    case tooLarge
    var errorDescription: String? {
        switch self {
        case .failed: "Không xuất được đoạn âm thanh."
        case .tooLarge: "Đoạn cắt quá lớn để tải lên (tối đa 2 MB)."
        }
    }
}

enum ClipExporter {
    static let maxBytes = 2_000_000

    /// Cắt `[start, end]` (giây) của `source` ra M4A (AAC) và trả về bytes.
    static func exportM4A(from source: URL, start: TimeInterval, end: TimeInterval) async throws -> Data {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ClipExportError.failed
        }
        let timescale: CMTimeScale = 600
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: timescale),
            end: CMTime(seconds: end, preferredTimescale: timescale))
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: out) }
        do {
            try await session.export(to: out, as: .m4a)
        } catch {
            throw ClipExportError.failed
        }
        guard let data = try? Data(contentsOf: out), !data.isEmpty else { throw ClipExportError.failed }
        guard data.count <= maxBytes else { throw ClipExportError.tooLarge }
        return data
    }
}
