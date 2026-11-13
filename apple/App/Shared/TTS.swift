import AVFoundation
import Foundation
import Observation

/// Đọc tiếng Hàn bằng `AVSpeechSynthesizer` (ko-KR).
@MainActor @Observable
final class TTS {
    private static let voiceKey = "tiramissu.ttsVoice"
    private static let rateKey = "tiramissu.ttsRate"

    var voiceID: String { didSet { UserDefaults.standard.set(voiceID, forKey: Self.voiceKey) } }
    /// 0…1 (mặc định của hệ thống ≈ 0.5).
    var rate: Double { didSet { UserDefaults.standard.set(rate, forKey: Self.rateKey) } }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    init() {
        voiceID = UserDefaults.standard.string(forKey: Self.voiceKey) ?? ""
        let saved = UserDefaults.standard.object(forKey: Self.rateKey) as? Double
        rate = saved ?? Double(AVSpeechUtteranceDefaultSpeechRate)
    }

    /// Các giọng ko-KR cài sẵn trên máy, chất lượng cao xếp trước.
    static var koreanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ko-KR" }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = Float(rate)
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
