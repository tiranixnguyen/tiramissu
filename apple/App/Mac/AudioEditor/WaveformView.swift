import DesignSystem
import SwiftUI

/// Dạng sóng vẽ bằng `Canvas`. Hiện một cửa sổ `[start, start + length]` giây; kéo ngang để cuộn.
/// (Vùng A–B và đầu phát được thêm ở T3.03.)
struct WaveformView: View {
    let waveform: Waveform
    @Binding var windowStart: TimeInterval
    let windowLength: TimeInterval
    var pointA: TimeInterval?
    var pointB: TimeInterval?
    var playhead: TimeInterval?
    /// Nhấp lên dạng sóng → đặt vị trí phát.
    var onSeek: (TimeInterval) -> Void = { _ in }
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
        .overlay { markers }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { point in
            guard width > 0 else { return }
            onSeek(windowStart + Double(point.x / width) * windowLength)
        }
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

    /// Vùng A–B, đầu phát (vẽ bằng Shape để không phải vẽ lại cả dạng sóng mỗi khung hình).
    private var markers: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                if let a = pointA, let b = pointB, b > a {
                    let x0 = max(0, x(a, w)), x1 = min(w, x(b, w))
                    if x1 > x0 {
                        Rectangle().fill((theme?.ok ?? .green).opacity(0.22))
                            .frame(width: x1 - x0).offset(x: x0)
                    }
                }
                if let a = pointA, (0...w).contains(x(a, w)) { pin("A", at: x(a, w), height: geo.size.height) }
                if let b = pointB, (0...w).contains(x(b, w)) { pin("B", at: x(b, w), height: geo.size.height) }
                if let p = playhead, (0...w).contains(x(p, w)) {
                    Rectangle().fill(theme?.bad ?? .red).frame(width: 2).offset(x: x(p, w) - 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func x(_ t: TimeInterval, _ w: CGFloat) -> CGFloat { CGFloat((t - windowStart) / windowLength) * w }

    private func pin(_ label: String, at x: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(theme?.ok ?? .green).frame(width: 2, height: height)
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(theme?.onAccent ?? .white)
                .frame(width: 20, height: 18)
                .background(RoundedRectangle(cornerRadius: 5).fill(theme?.ok ?? .green))
        }
        .offset(x: x - 10)
    }

    @State private var panOrigin: TimeInterval?
    @State private var width: CGFloat = 0

    private func clamp(_ start: TimeInterval) -> TimeInterval {
        min(max(0, start), max(0, waveform.duration - windowLength))
    }
}
