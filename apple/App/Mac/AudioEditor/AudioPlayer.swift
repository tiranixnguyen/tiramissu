import AVFoundation
import Observation

/// Phát một đoạn A–B của file âm thanh, có lặp và đổi tốc độ (giữ cao độ).
@MainActor @Observable
final class AudioPlayer {
    static let rates: [Float] = [0.5, 0.75, 1]

    private(set) var isPlaying = false
    /// Vị trí hiện tại (giây). Kéo/nhấp lên dạng sóng đặt qua `seek`.
    private(set) var position: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var pointA: TimeInterval?
    var pointB: TimeInterval?
    var loops = false
    var rate: Float = 1 {
        didSet { timePitch.rate = rate }
    }
    private(set) var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let node = AVAudioPlayerNode()
    @ObservationIgnored private let timePitch = AVAudioUnitTimePitch()
    @ObservationIgnored private var file: AVAudioFile?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var segmentStart: TimeInterval = 0
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init() {
        engine.attach(node)
        engine.attach(timePitch)
    }

    var hasFile: Bool { file != nil }
    /// Đoạn đang chọn; thiếu A/B thì lấy đầu/cuối file.
    var rangeStart: TimeInterval { pointA ?? 0 }
    var rangeEnd: TimeInterval { pointB ?? duration }
    var hasRange: Bool { pointA != nil && pointB != nil }

    // MARK: Nạp

    func load(_ url: URL) {
        stopPlayback()
        do {
            let f = try AVAudioFile(forReading: url)
            file = f
            duration = Double(f.length) / f.processingFormat.sampleRate
            engine.disconnectNodeOutput(node)
            engine.disconnectNodeOutput(timePitch)
            engine.connect(node, to: timePitch, format: f.processingFormat)
            engine.connect(timePitch, to: engine.mainMixerNode, format: f.processingFormat)
            timePitch.rate = rate
            position = 0
            pointA = nil
            pointB = nil
            error = nil
        } catch {
            file = nil
            duration = 0
            self.error = "Không mở được file để phát."
        }
    }

    func unload() {
        stopPlayback()
        file = nil
        duration = 0
        position = 0
        pointA = nil
        pointB = nil
    }

    // MARK: Điều khiển

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard file != nil, !isPlaying else { return }
        // Đang ngoài đoạn A–B thì phát từ A.
        if position < rangeStart || position >= rangeEnd - 0.02 { position = rangeStart }
        start(from: position)
    }

    func pause() {
        guard isPlaying else { return }
        position = currentPosition()
        stopPlayback()
    }

    func seek(to time: TimeInterval) {
        position = min(max(0, time), duration)
        if isPlaying { start(from: position) }
    }

    func skip(_ delta: TimeInterval) {
        seek(to: (isPlaying ? currentPosition() : position) + delta)
    }

    func setA() {
        let t = isPlaying ? currentPosition() : position
        pointA = t
        if let b = pointB, b <= t { pointB = nil }
    }

    func setB() {
        let t = isPlaying ? currentPosition() : position
        if let a = pointA, t <= a { return }
        pointB = t
    }

    /// B ± 0,1 s để tinh chỉnh điểm cắt.
    func nudgeB(_ delta: TimeInterval) {
        guard let b = pointB else { return }
        let next = min(max(b + delta, (pointA ?? 0) + 0.1), duration)
        pointB = next
    }

    func setRate(_ r: Float) { rate = r }

    // MARK: Phát

    private func start(from time: TimeInterval) {
        guard let file else { return }
        let end = rangeEnd
        guard end > time else { return }
        generation += 1
        let gen = generation
        node.stop()
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frames = AVAudioFrameCount(max(1, (end - time) * sampleRate))
        segmentStart = time
        node.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil,
            completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finished(gen) }
        }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            self.error = "Không phát được âm thanh."
            return
        }
        node.play()
        isPlaying = true
        position = time
        startTicker()
    }

    private func finished(_ gen: Int) {
        guard gen == generation, isPlaying else { return }
        if loops {
            start(from: rangeStart)
        } else {
            stopPlayback()
            position = rangeStart
        }
    }

    private func stopPlayback() {
        generation += 1
        ticker?.cancel()
        ticker = nil
        node.stop()
        isPlaying = false
    }

    private func currentPosition() -> TimeInterval {
        guard let file, let nodeTime = node.lastRenderTime, let t = node.playerTime(forNodeTime: nodeTime) else {
            return position
        }
        let played = Double(t.sampleTime) / file.processingFormat.sampleRate
        return min(segmentStart + max(0, played), duration)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self, self.isPlaying else { return }
                self.position = self.currentPosition()
            }
        }
    }
}
