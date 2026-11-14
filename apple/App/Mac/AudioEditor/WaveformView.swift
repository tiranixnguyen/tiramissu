import DesignSystem
import SwiftUI

/// Dạng sóng vẽ bằng `Canvas`. Hiện một cửa sổ `[start, start + length]` giây; kéo ngang để cuộn.
/// (Vùng A–B và đầu phát được thêm ở T3.03.)
struct WaveformView: View {
    let waveform: Waveform
    @Binding var windowStart: TimeInterval
    let windowLength: TimeInterval
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            let perSecond = Double(Waveform.columnsPerSecond)
            let barWidth: CGFloat = 3, gap: CGFloat = 1.5
            let bars = max(1, Int(size.width / (barWidth + gap)))
            let secondsPerBar = windowLength / Double(bars)
            let mid = size.height / 2
            let peaks = waveform.peaks
            // Chuẩn hoá theo đỉnh cao nhất để file nhỏ tiếng vẫn nhìn rõ.
            let top = max(peaks.max() ?? 0, 0.0001)
            let colour = theme?.accent ?? .accentColor

            for bar in 0..<bars {
                let t0 = windowStart + Double(bar) * secondsPerBar
                let t1 = t0 + secondsPerBar
                let c0 = max(0, Int(t0 * perSecond))
                let c1 = min(peaks.count, max(c0 + 1, Int(t1 * perSecond)))
                guard c0 < peaks.count, c0 < c1 else { continue }
                var m: Float = 0
                for c in c0..<c1 { m = max(m, peaks[c]) }
                let h = max(2, CGFloat(m / top) * (size.height - 8))
                let rect = CGRect(x: CGFloat(bar) * (barWidth + gap), y: mid - h / 2, width: barWidth, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colour.opacity(0.85)))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { drag in
                    if panOrigin == nil { panOrigin = windowStart }
                    guard let origin = panOrigin, width > 0 else { return }
                    let shift = -Double(drag.translation.width / width) * windowLength
                    windowStart = clamp(origin + shift)
                }
                .onEnded { _ in panOrigin = nil }
        )
        .background(GeometryReader { geo in Color.clear.onAppear { width = geo.size.width }
            .onChange(of: geo.size.width) { _, w in width = w } })
        .accessibilityLabel("Dạng sóng âm thanh")
    }

    @State private var panOrigin: TimeInterval?
    @State private var width: CGFloat = 0

    private func clamp(_ start: TimeInterval) -> TimeInterval {
        min(max(0, start), max(0, waveform.duration - windowLength))
    }
}
