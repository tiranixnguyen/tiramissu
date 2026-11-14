import DesignSystem
import HanCore
import SwiftUI

/// Học (iPhone) — theo artboard "iPhone · Học": thanh tiến độ, thẻ lớn, ô trả lời, hai nút to.
/// View chỉ đọc `model.state` và gọi hàm của `AppModel`, giống bản Mac.
///
/// Bàn phím Hàn: iOS không cho app ép ngôn ngữ bàn phím (`.keyboardType` chỉ chọn kiểu phím).
/// Thêm bàn phím "Tiếng Hàn – Bàn phím chuẩn" trong Cài đặt › Cài đặt chung › Bàn phím, rồi giữ 🌐 để
/// chuyển; iOS nhớ bàn phím dùng lần trước cho từng ô nhập.
struct PhoneStudyView: View {
    @Environment(AppModel.self) private var model
    @Environment(PhoneNav.self) private var nav
    @Environment(TTS.self) private var tts
    @Environment(\.theme) private var theme

    @State private var input = ""
    @State private var clipPlayer = ClipPlayer()
    @FocusState private var fieldFocused: Bool

    private var state: StudySessionState { model.state }

    var body: some View {
        VStack(spacing: 16) {
            topBar
            content
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
        .background(theme?.bg ?? .clear)
        .onChange(of: state.cardSerial) {
            input = ""
            autoPlayClip()
        }
        .onAppear(perform: autoPlayClip)
        .onDisappear { clipPlayer.stop() }
    }

    // MARK: Thanh trên

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { nav.tab = .today } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(surface).overlay(RoundedRectangle(cornerRadius: 14).stroke(line)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Về Hôm nay")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    deckMenu
                    Spacer(minLength: 4)
                    Text("\(state.masteredCount)/\(state.totalCount) đã thuộc")
                        .font(.system(size: 13)).monospacedDigit().foregroundStyle(ink2)
                        .lineLimit(1).fixedSize()
                }
                Capsule().fill(line).frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(accent).frame(width: g.size.width * state.progress)
                        }
                    }
            }
        }
    }

    /// Bấm tên bộ để đổi bộ (bộ thật + bộ ảo).
    private var deckMenu: some View {
        Menu {
            ForEach(model.visibleDecks) { d in
                Button { model.switchDeck(d.id) } label: {
                    if d.id == state.currentDeckId { Label(d.name, systemImage: "checkmark") } else { Text(d.name) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(deckTitle).lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(ink2)
            }
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
        }
    }

    private var deckTitle: String {
        model.visibleDecks.first { $0.id == state.currentDeckId }?.name ?? "Chọn bộ"
    }

    // MARK: Nội dung

    @ViewBuilder private var content: some View {
        if state.currentDeckId == nil {
            ContentUnavailableView(
                "Chưa có bộ để học", systemImage: "rectangle.on.rectangle",
                description: Text("Thêm bộ từ trên Mac rồi đồng bộ."))
                .frame(maxHeight: .infinity)
        } else if state.isCompleted {
            completed
        } else if let word = state.currentWord {
            card(word)
            answerArea(word)
        } else {
            ContentUnavailableView("Bộ này chưa có thẻ", systemImage: "tray").frame(maxHeight: .infinity)
        }
    }

    private func card(_ word: StudyWord) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(cardLabel(word))
                    .font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(ink2)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                flagChip(on: state.currentIsMarked, label: "Từ khó nhớ") {
                    Image(systemName: state.currentIsMarked ? "star.fill" : "star")
                } action: { model.toggleMark() }
                flagChip(on: state.currentIsHanja, label: "Hán Hàn") {
                    Text("漢").font(.system(size: 17, weight: .bold, design: .serif))
                } action: { model.toggleHanja() }
            }
            ScrollView {
                VStack(spacing: 12) {
                    if let audioId = clipAudioId(word) {
                        clipControls(audioId)
                        if showBack, word.front != "🎧 Nghe và chép lại" {
                            Text(word.front).font(.system(size: 17)).foregroundStyle(ink2).multilineTextAlignment(.center)
                        }
                    } else {
                        Text(word.front)
                            .font(word.typeAnswer ? latinFont(size: 30, weight: .semibold) : cardFont(size: 26))
                            .foregroundStyle(ink).multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                    if let hint = word.hint, !hint.isEmpty {
                        Text("Gợi ý: \(hint)").font(.system(size: 15)).foregroundStyle(ink2).multilineTextAlignment(.center)
                    }
                    if showBack { back(word) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .frame(minHeight: 260)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 26).fill(surface).overlay(RoundedRectangle(cornerRadius: 26).stroke(line)))
    }

    private func cardLabel(_ word: StudyWord) -> String {
        if clipAudioId(word) != nil { return "NGHE → CHÉP CHÍNH TẢ" }
        return word.typeAnswer ? "VIỆT → HÀN · GÕ ĐÁP ÁN" : "HÀN → VIỆT · TỰ CHẤM"
    }

    @ViewBuilder private func back(_ word: StudyWord) -> some View {
        Rectangle().fill(line).frame(height: 1).padding(.vertical, 4)
        HStack(spacing: 10) {
            if clipAudioId(word) != nil {
                diffText(word)
            } else {
                Text(word.back)
                    .font(word.typeAnswer ? cardFont(size: 34, weight: .bold) : latinFont(size: 20, weight: .bold))
                    .foregroundStyle(state.outcome == .wrong ? bad : ink)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Button { tts.speak(word.back) } label: {
                    Image(systemName: "play.fill").font(.system(size: 14)).foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(accent.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Đọc")
            }
        }
        if let note = word.note, !note.isEmpty {
            Text(.init(note)).font(.callout).foregroundStyle(ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(ink.opacity(0.05)))
        }
    }

    // MARK: Trả lời

    @ViewBuilder private func answerArea(_ word: StudyWord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if word.typeAnswer || clipAudioId(word) != nil {
                Text(answerLabel).font(.system(size: 13, weight: .semibold)).foregroundStyle(answerTint)
                TextField("", text: $input, prompt: Text(clipAudioId(word) != nil ? "Chép lại câu vừa nghe…" : "Gõ tiếng Hàn…"))
                    .font(.system(size: 22)).foregroundStyle(ink)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .disabled(state.answered)
                    .onSubmit(submit)
                    .padding(.horizontal, 18).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(surface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(state.answered ? answerTint : line, lineWidth: state.answered ? 1.5 : 1))
            } else if !state.answered {
                Text(state.flipped ? "Bạn nhớ từ này không?" : "Nghĩ đáp án rồi lật thẻ")
                    .font(.system(size: 14)).foregroundStyle(ink2)
                    .frame(maxWidth: .infinity)
            }
            buttons(word)
            HStack {
                Text("Đúng \(state.correctCount)/\(state.attemptedCount)")
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(ink2)
                Spacer()
                if !state.answered {
                    Button("Đã thuộc thẻ này") { model.markKnown() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private func buttons(_ word: StudyWord) -> some View {
        HStack(spacing: 10) {
            if state.answered {
                if state.canOverride {
                    bigButton("Đã trả lời đúng?", primary: false) { model.overrideAsCorrect() }
                }
                bigButton("Thẻ tiếp", primary: true) { model.nextCard() }
            } else if word.typeAnswer || clipAudioId(word) != nil {
                bigButton("Xem đáp án", primary: false) { model.revealAnswer() }
                bigButton("Chấm bài", primary: true, action: submit)
            } else if !state.flipped {
                bigButton("Lật thẻ", primary: true) { model.flipCard() }
            } else {
                bigButton("Chưa nhớ", primary: false) { model.gradeSelf(remembered: false) }
                bigButton("Nhớ", primary: true) { model.gradeSelf(remembered: true) }
            }
        }
    }

    private var answerLabel: String {
        switch state.outcome {
        case .pending: "Câu trả lời"
        case .correct, .known: "Đúng"
        case .wrong: state.canOverride ? "Chưa đúng" : "Đáp án"
        }
    }

    private var answerTint: Color {
        switch state.outcome {
        case .pending: ink2
        case .correct, .known: theme?.ok ?? .green
        case .wrong: state.canOverride ? bad : ink2
        }
    }

    private func submit() {
        guard !state.answered else { return }
        model.checkAnswer(input)
        fieldFocused = true  // giữ bàn phím để gõ thẻ sau
    }

    private var completed: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(theme?.ok ?? .green)
            Text("Xong bộ này").font(.system(size: 26, weight: .bold)).foregroundStyle(ink)
            Text("Đúng \(state.correctCount)/\(state.attemptedCount) lượt trả lời").foregroundStyle(ink2)
            Spacer()
            HStack(spacing: 10) {
                bigButton("Về Hôm nay", primary: false) { nav.tab = .today }
                bigButton("Học lại", primary: true) { model.restartDeck() }
            }
        }
    }

    // MARK: Clip

    private func clipAudioId(_ word: StudyWord?) -> String? {
        if case .clip(let id) = word?.kind { return id }
        return nil
    }

    private func autoPlayClip() {
        if let id = clipAudioId(state.currentWord) { clipPlayer.play(audioId: id, model: model) } else { clipPlayer.stop() }
    }

    private func clipControls(_ audioId: String) -> some View {
        VStack(spacing: 12) {
            Button { clipPlayer.toggle(audioId: audioId, model: model) } label: {
                Image(systemName: clipPlayer.isPlaying ? "stop.fill" : "play.fill").font(.system(size: 30)).foregroundStyle(accent)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(accent.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(clipPlayer.isPlaying ? "Dừng" : "Nghe")
            HStack(spacing: 18) {
                Button { clipPlayer.loops.toggle() } label: {
                    Label("Lặp", systemImage: "repeat").foregroundStyle(clipPlayer.loops ? accent : ink2)
                }
                Button { clipPlayer.cycleRate() } label: {
                    Label(String(format: "%g×", clipPlayer.rate), systemImage: "speedometer").foregroundStyle(ink2)
                }
            }
            .buttonStyle(.plain).font(.system(size: 14, weight: .medium))
            if clipPlayer.isLoading { ProgressView() }
            if clipPlayer.failed {
                Text("Không tải được âm thanh (cần mạng lần đầu).").font(.caption).foregroundStyle(bad)
            }
        }
    }

    /// Câu đúng, tô theo so sánh từng từ với câu đã chép.
    private func diffText(_ word: StudyWord) -> some View {
        let ok = theme?.ok ?? .green
        var text = Text("")
        for (i, d) in AnswerMatcher.wordDiff(answer: input, target: word.back).enumerated() {
            let sep = i == 0 ? "" : " "
            switch d.kind {
            case .correct: text = text + Text(sep + d.text).foregroundColor(ok)
            case .wrong(let expected):
                text = text + Text(sep + d.text).foregroundColor(bad).strikethrough() + Text(" " + expected).foregroundColor(ok)
            case .missing: text = text + Text(sep + d.text).foregroundColor(bad).underline()
            case .extra: text = text + Text(sep + d.text).foregroundColor(bad).strikethrough()
            }
        }
        return text.font(cardFont(size: 24)).multilineTextAlignment(.center)
    }

    // MARK: Chung

    private var showBack: Bool { state.answered || state.flipped }
    private var ink: Color { theme?.ink ?? .primary }
    private var ink2: Color { theme?.ink2 ?? .secondary }
    private var line: Color { theme?.line ?? .gray }
    private var surface: Color { theme?.surface ?? .clear }
    private var accent: Color { theme?.accent ?? .accentColor }
    private var bad: Color { theme?.bad ?? .red }

    private func flagChip<L: View>(
        on: Bool, label: String, @ViewBuilder icon: () -> L, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            icon()
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(on ? accent : ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(on ? accent.opacity(0.16) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "Bật" : "Tắt")
    }

    /// Nút to cao 50: chính = nền `accent`; phụ = nền `surface` viền `line`.
    private func bigButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(primary ? (theme?.onAccent ?? .white) : ink)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16).fill(primary ? accent : surface))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(primary ? .clear : line))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    /// Phông chữ Hàn trên thẻ — theo theme (serif/sans, hệ số cỡ).
    private func cardFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let scale = theme?.typography.cardScale ?? 1
        let isSerif = theme?.typography.cardKoreanFont != "sans"
        return .system(size: size * scale, weight: weight, design: isSerif ? .serif : .default)
    }

    private func latinFont(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size * (theme?.typography.cardScale ?? 1), weight: weight)
    }
}
