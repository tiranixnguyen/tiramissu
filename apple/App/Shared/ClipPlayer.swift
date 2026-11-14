import AVFoundation
import Observation

/// Phát clip nghe trong màn Học: tải file từ server (có cache đĩa), lặp, đổi tốc độ.
@MainActor @Observable
final class ClipPlayer {
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var failed = false
    /// Vị trí đang phát, 0…1 (cập nhật ~10 lần/giây khi đang phát).
    private(set) var position: Double = 0
    var loops = false {
        didSet { player?.numberOfLoops = loops ? -1 : 0 }
    }
    var rate: Float = 1 {
        didSet { player?.rate = rate }
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var loadedId: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Nạp (nếu chưa) rồi phát từ đầu.
    func play(audioId: String, model: AppModel) {
        task?.cancel()
        if loadedId == audioId, let player {
            restart(player)
            return
        }
        stop()
        isLoading = true
        failed = false
        task = Task { [weak self] in
            do {
                let url = try await model.audioFile(id: audioId)
                let p = try AVAudioPlayer(contentsOf: url)
                guard !Task.isCancelled, let self else { return }
                p.enableRate = true
                p.numberOfLoops = self.loops ? -1 : 0
                p.rate = self.rate
                p.prepareToPlay()
                self.player = p
                self.loadedId = audioId
                self.isLoading = false
                self.restart(p)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isLoading = false
                self.failed = true
            }
        }
    }

    func toggle(audioId: String, model: AppModel) {
        if isPlaying { stop() } else { play(audioId: audioId, model: model) }
    }

    func stop() {
        task?.cancel()
        player?.stop()
        isPlaying = false
        position = 0
    }

    func cycleRate() {
        rate = rate == 1 ? 0.75 : rate == 0.75 ? 0.5 : 1
    }

    private func restart(_ p: AVAudioPlayer) {
        p.currentTime = 0
        p.play()
        isPlaying = true
        Task { [weak self] in
            // Theo dõi tới khi hết (AVAudioPlayer không có closure — hỏi nhẹ 10 lần/giây).
            while let self, let player = self.player, player === p, self.isPlaying {
                try? await Task.sleep(for: .milliseconds(100))
                self.position = p.duration > 0 ? p.currentTime / p.duration : 0
                if !p.isPlaying {
                    self.isPlaying = false
                    self.position = 0
                }
            }
        }
    }
}
