import AVFoundation

/// Biên độ RMS theo cột thời gian của một file âm thanh (mono hoá bằng kênh 0).
struct Waveform: Sendable {
    /// Số cột mỗi giây — đủ mịn để zoom tới ~5 giây trên màn hình rộng.
    static let columnsPerSecond = 50
    var peaks: [Float]
    var duration: TimeInterval
}

enum WaveformExtractor {
    /// Đọc tuần tự theo khối, chạy trên luồng nền (không chặn UI). Ném lỗi nếu không mở được file.
    static func extract(url: URL) async throws -> Waveform {
        try await Task.detached(priority: .userInitiated) {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let rate = format.sampleRate
            let total = file.length
            guard total > 0, rate > 0 else { return Waveform(peaks: [], duration: 0) }

            let framesPerColumn = max(1, Int(rate) / Waveform.columnsPerSecond)
            let chunk: AVAudioFrameCount = 1 << 16
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else {
                throw CocoaError(.fileReadUnknown)
            }

            var peaks: [Float] = []
            peaks.reserveCapacity(Int(total) / framesPerColumn + 1)
            var sum: Float = 0
            var count = 0
            while file.framePosition < total {
                try Task.checkCancellation()
                try file.read(into: buffer, frameCount: chunk)
                let n = Int(buffer.frameLength)
                if n == 0 { break }
                guard let data = buffer.floatChannelData?[0] else { break }
                for i in 0..<n {
                    let v = data[i]
                    sum += v * v
                    count += 1
                    if count == framesPerColumn {
                        peaks.append((sum / Float(count)).squareRoot())
                        sum = 0
                        count = 0
                    }
                }
            }
            if count > 0 { peaks.append((sum / Float(count)).squareRoot()) }
            return Waveform(peaks: peaks, duration: Double(total) / rate)
        }.value
    }
}
