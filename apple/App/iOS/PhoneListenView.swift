import DesignSystem
import HanCore
import SwiftUI

/// Nghe (iPhone) — theo artboard "iPhone · Nghe": phát clip, tốc độ, lặp, chép chính tả, chấm từng từ.
///
/// Luyện tại chỗ, không đụng lượt học của tab Học (hai tab dùng chung `StudyEngine` — mở bộ 🎧 ở đây sẽ
/// cắt ngang bộ đang học). Muốn ghi kết quả vào lịch sử thì học bộ ảo "Clip nghe" ở tab Học.
struct PhoneListenView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var player = ClipPlayer()
    @State private var currentId: String?
    @State private var input = ""
    @State private var checked = false
    @State private var revealed = false
    @State private var practiced: Set<String> = []
    @FocusState private var fieldFocused: Bool

    /// Clip đánh dấu ⭐ trước, rồi mới nhất trước.
    private var clips: [Clip] {
        model.content.clips.sorted { a, b in
            a.marked != b.marked ? a.marked : a.createdAt > b.createdAt
        }
    }

    private var current: Clip? {
        clips.first { $0.id == currentId } ?? clips.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let clip = current {
                    playerCard(clip)
                    dictation(clip)
                    upNext(after: clip)
                } else {
                    ContentUnavailableView(
                        "Chưa có clip", systemImage: "headphones",
                        description: Text("Cắt clip ở màn “Cắt clip âm thanh” trên Mac rồi đồng bộ."))
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme?.bg ?? .clear)
        .onDisappear { player.stop() }
        .refreshable { await model.syncNow() }
    }

    // MARK: Đầu trang

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Nghe").font(.system(size: 26, weight: .bold)).kerning(-0.5).foregroundStyle(ink)
            Spacer()
            if !clips.isEmpty {
                Text("Clip \(min(practiced.count + 1, clips.count))/\(clips.count)")
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(ink2)
            }
        }
    }

    // MARK: Trình phát

    private func playerCard(_ clip: Clip) -> some View {
        VStack(spacing: 0) {
            ZStack {
                waveform(clip).padding(.horizontal, 14).padding(.vertical, 44)
                Button { player.toggle(audioId: clip.audioId, model: model) } label: {
                    Group {
                        if player.isLoading {
                            ProgressView().tint(theme?.bg ?? .white)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 22))
                        }
                    }
                    .foregroundStyle(theme?.bg ?? .white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(ink))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Tạm dừng" : "Phát")
                VStack {
                    Text("\(clip.sourceName) · clip \(seconds(clip.durationMs))")
                        .font(.system(size: 12)).foregroundStyle(ink2).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text("\(clock(clip.startMs)) → \(clock(clip.endMs))")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(surface))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .frame(height: 150)
            .background(ink.opacity(0.05))

            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Capsule().fill(ink.opacity(0.06)).frame(height: 8)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule().fill(green).frame(width: g.size.width * player.position)
                            }
                        }
                    HStack {
                        Text(seconds(Int(Double(clip.durationMs) * player.position)))
                        Spacer()
                        Text(seconds(clip.durationMs))
                    }
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(ink2)
                }
                if player.failed {
                    Text("Không tải được âm thanh (cần mạng lần đầu).").font(.caption).foregroundStyle(bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    ForEach([Float(0.5), 0.75, 1], id: \.self) { r in
                        pill(String(format: "%g×", r), on: player.rate == r) { player.rate = r }
                    }
                    Spacer(minLength: 8)
                    Button { player.loops.toggle() } label: {
                        Label("Lặp A-B", systemImage: "repeat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(player.loops ? green : ink)
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(Capsule().fill(player.loops ? green.opacity(0.12) : .clear))
                            .overlay(Capsule().stroke(player.loops ? green : line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(player.loops ? "Bật" : "Tắt")
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(surface))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(line))
    }

    /// Cột sóng trang trí (không phải biên độ thật) — dựng ổn định từ id clip để mỗi clip một dáng.
    private func waveform(_ clip: Clip) -> some View {
        var seed = UInt64(truncatingIfNeeded: clip.id.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) })
        let bars: [CGFloat] = (0..<48).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return 0.2 + 0.8 * CGFloat(seed >> 40 & 0xFFFF) / 65535
        }
        return GeometryReader { g in
            HStack(alignment: .center, spacing: 3) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(green.opacity(0.55))
                        .frame(height: g.size.height * bars[i])
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    // MARK: Chép chính tả

    private func dictation(_ clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chép chính tả — gõ lại câu bạn nghe được").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
            TextField("", text: $input, prompt: Text("듣고 쓰세요…"), axis: .vertical)
                .lineLimit(3...5)
                .font(.system(size: 17, weight: .medium)).foregroundStyle(ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($fieldFocused)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(line, lineWidth: 1.5))
            if checked || revealed {
                result(clip)
            }
            HStack(spacing: 10) {
                if checked || revealed {
                    bigButton("Nghe lại", primary: false) { player.play(audioId: clip.audioId, model: model) }
                    bigButton("Clip tiếp", primary: true) { next(after: clip) }
                } else {
                    bigButton("Xem câu gốc", primary: false) { revealed = true; fieldFocused = false }
                    bigButton("Chấm", primary: true) { checked = true; fieldFocused = false }
                        .layoutPriority(1)
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    /// Câu gốc, tô từng từ theo bài chép (đúng / sai / thiếu / thừa) + nghĩa + điểm.
    private func result(_ clip: Clip) -> some View {
        let diffs = AnswerMatcher.wordDiff(answer: checked ? input : "", target: clip.transcript)
        let correct = diffs.filter { if case .correct = $0.kind { true } else { false } }.count
        let total = diffs.filter { if case .extra = $0.kind { false } else { true } }.count
        return VStack(alignment: .leading, spacing: 8) {
            if checked {
                diffText(diffs).font(.system(size: 18, weight: .semibold, design: .serif))
            } else {
                Text(clip.transcript).font(.system(size: 18, weight: .semibold, design: .serif)).foregroundStyle(ink)
            }
            let meaning = [clip.translation, checked ? "Đúng \(correct)/\(total)" : nil].compactMap { $0 }
            if !meaning.isEmpty {
                Text(meaning.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(ink2)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(surface).overlay(RoundedRectangle(cornerRadius: 14).stroke(line)))
    }

    private func diffText(_ diffs: [WordDiff]) -> Text {
        var text = Text("")
        for (i, d) in diffs.enumerated() {
            let sep = i == 0 ? "" : " "
            switch d.kind {
            case .correct: text = text + Text(sep + d.text).foregroundColor(green)
            case .wrong(let expected):
                text = text + Text(sep + d.text).foregroundColor(bad).strikethrough() + Text(" " + expected).foregroundColor(green)
            case .missing: text = text + Text(sep + d.text).foregroundColor(bad).underline()
            case .extra: text = text + Text(sep + d.text).foregroundColor(bad).strikethrough()
            }
        }
        return text
    }

    private func next(after clip: Clip) {
        practiced.insert(clip.id)
        let list = clips
        let i = list.firstIndex { $0.id == clip.id } ?? 0
        select(list[(i + 1) % list.count])
        if practiced.count >= list.count { practiced = [] }  // hết vòng → đếm lại
    }

    private func select(_ clip: Clip) {
        player.stop()
        currentId = clip.id
        input = ""
        checked = false
        revealed = false
        player.play(audioId: clip.audioId, model: model)
    }

    // MARK: Tiếp theo

    @ViewBuilder private func upNext(after clip: Clip) -> some View {
        let list = clips
        let start = (list.firstIndex { $0.id == clip.id } ?? 0) + 1
        let rest = (0..<min(3, list.count - 1)).map { list[(start + $0) % list.count] }
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tiếp theo").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                ForEach(rest) { c in
                    Button { select(c) } label: { queueRow(c) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func queueRow(_ c: Clip) -> some View {
        HStack(spacing: 12) {
            Text(seconds(c.durationMs))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(theme?.bg ?? .white)
                .frame(width: 52, height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(ink))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.transcript).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                Text(queueMeta(c)).font(.system(size: 12)).foregroundStyle(ink2).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(surface).overlay(RoundedRectangle(cornerRadius: 14).stroke(line)))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private func queueMeta(_ c: Clip) -> String {
        var parts: [String] = []
        if let t = c.translation, !t.isEmpty { parts.append(t) } else { parts.append(c.sourceName) }
        if c.marked { parts.append("★") }
        return parts.joined(separator: " · ")
    }

    // MARK: Chung

    private var ink: Color { theme?.ink ?? .primary }
    private var ink2: Color { theme?.ink2 ?? .secondary }
    private var line: Color { theme?.line ?? .gray }
    private var surface: Color { theme?.surface ?? .clear }
    private var bad: Color { theme?.bad ?? .red }
    /// Màn Nghe dùng màu `ok` làm màu nhấn như artboard.
    private var green: Color { theme?.ok ?? .green }

    /// "4.5s".
    private func seconds(_ ms: Int) -> String { String(format: "%.1fs", Double(ms) / 1000) }

    /// "0:42.5".
    private func clock(_ ms: Int) -> String {
        let s = Double(ms) / 1000
        return String(format: "%d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private func pill(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? (theme?.bg ?? .white) : ink)
                .frame(minWidth: 52).frame(height: 40)
                .background(Capsule().fill(on ? ink : .clear))
                .overlay(Capsule().stroke(on ? .clear : line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Nút to cao 50: chính = nền `ok`; phụ = nền `surface` viền `line`.
    private func bigButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                .foregroundStyle(primary ? (theme?.surface ?? .white) : ink)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(primary ? green : surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(primary ? .clear : line))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
