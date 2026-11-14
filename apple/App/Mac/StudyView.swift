import DesignSystem
import HanCore
import SwiftUI

/// Màn Học — thẻ gõ đáp án. View chỉ đọc `model.state` và gọi hàm của `AppModel`.
///
/// Bàn phím Hàn: macOS không tự đổi bộ gõ theo ô nhập. Hãy thêm "Korean (2-Set)" trong
/// Cài đặt hệ thống › Bàn phím › Nguồn nhập, rồi chuyển bằng phím Caps Lock hoặc ⌃Space.
struct StudyView: View {
    @Environment(AppModel.self) private var model
    @Environment(TTS.self) private var tts
    @Environment(Navigation.self) private var nav
    @Environment(\.theme) private var theme

    /// Cửa sổ học gọn (`⌥⌘L`): chỉ thẻ + ô trả lời, không thanh trên, không cột phải.
    var compact = false

    @State private var input = ""
    @State private var clipPlayer = ClipPlayer()
    @FocusState private var fieldFocused: Bool

    private var state: StudySessionState { model.state }

    var body: some View {
        Group {
            if compact {
                base
            } else {
                base.screenTopBar { header } actions: { PaletteButton() }
            }
        }
        .onChange(of: state.cardSerial) {
            input = ""
            focusField()
            autoPlayClip()
        }
        .onDisappear { clipPlayer.stop() }
        .onAppear {
            focusField()
            autoPlayClip()
        }
    }

    private func clipAudioId(_ word: StudyWord?) -> String? {
        if case .clip(let id) = word?.kind { return id }
        return nil
    }

    /// Thẻ clip tự phát khi hiện ra.
    private func autoPlayClip() {
        if let id = clipAudioId(state.currentWord) { clipPlayer.play(audioId: id, model: model) } else { clipPlayer.stop() }
    }

    private var base: some View {
        content
            .padding(.leading, 2).padding(.trailing, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        Group {
            if state.currentDeckId == nil {
                ContentUnavailableView(
                    "Chưa có bộ để học", systemImage: "rectangle.on.rectangle",
                    description: Text("Thêm bộ từ ở Thư viện hoặc Nhập từ AI, rồi đồng bộ."))
            } else if state.isCompleted {
                completed
            } else if let word = state.currentWord {
                HStack(alignment: .top, spacing: 0) {
                    card(word)
                    // Cột "Lượt học" chỉ ở cửa sổ ≥ 1100 pt; hẹp hơn thì thống kê nằm trên thanh trên.
                    if !compact && nav.widthClass == .wide {
                        sidebarColumn.padding(.top, 8).padding(.bottom, 12)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            } else {
                ContentUnavailableView("Bộ này chưa có thẻ", systemImage: "tray")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Thanh tiến độ

    private var deckTitle: String {
        let name = model.visibleDecks.first { $0.id == state.currentDeckId }?.name ?? "Bộ ảo"
        let group = state.vocabGroups.first { $0.id == state.currentVocabGroup }?.name
        return group.map { "\(name) · \($0)" } ?? name
    }

    /// Phần tiêu đề thanh trên: tên bộ + tiến độ + thống kê (khung kính do `screenTopBar` lo).
    private var header: some View {
        // Đủ chỗ: thống kê đầy đủ → rút gọn (bản 820) → ẩn hẳn; chữ không bao giờ xuống dòng.
        ViewThatFits(in: .horizontal) {
            headerRow(stats: fullStats)
            headerRow(stats: shortStats)
            headerRow(stats: nil)
        }
    }

    private var fullStats: String {
        "\(state.masteredCount)/\(state.totalCount) thuộc · đúng \(state.correctCount)/\(state.attemptedCount)"
    }

    private var shortStats: String {
        "\(state.masteredCount)/\(state.totalCount) · \(state.correctCount)/\(state.attemptedCount) đúng"
    }

    private func headerRow(stats: String?) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                (Text(deckTitleMain).fontWeight(.semibold)
                    + Text(deckTitleGroup).fontWeight(.medium).foregroundColor(theme?.ink2 ?? .secondary))
                    .font(.system(size: 14))
                    .lineLimit(1).truncationMode(.tail)
                Capsule().fill((theme?.ink ?? .primary).opacity(0.12))
                    .frame(height: 5).frame(maxWidth: 360)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(theme?.accent ?? .accentColor)
                                .frame(width: g.size.width * state.progress)
                        }
                    }
            }
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            if let stats {
                Text(stats)
                    .font(.system(size: 12)).monospacedDigit().lineLimit(1)
                    .foregroundStyle(theme?.ink2 ?? .secondary)
                    .fixedSize()
            }
        }
    }

    private var deckTitleMain: String {
        model.visibleDecks.first { $0.id == state.currentDeckId }?.name ?? "Bộ ảo"
    }

    private var deckTitleGroup: String {
        state.vocabGroups.first { $0.id == state.currentVocabGroup }.map { " · \($0.name)" } ?? ""
    }

    // MARK: Thẻ

    private func card(_ word: StudyWord) -> some View {
        VStack(spacing: 12) {
            CardSurface {
                VStack(spacing: 0) {
                    HStack {
                        Text(clipAudioId(word) != nil ? "NGHE → CHÉP CHÍNH TẢ" : word.typeAnswer ? "VIỆT → HÀN · GÕ ĐÁP ÁN" : "HÀN → VIỆT · TỰ CHẤM")
                            .font(.caption.weight(.semibold)).tracking(1)
                            .foregroundStyle(theme?.ink2 ?? .secondary)
                        Spacer()
                        flagChip("star.fill", on: state.currentIsMarked, help: "Từ khó nhớ (⇧⌘8)", key: "8") { model.toggleMark() }
                        flagChip(nil, on: state.currentIsHanja, help: "Hán Hàn (⇧⌘H)", key: "h") { model.toggleHanja() }
                    }
                    Spacer(minLength: 8)
                    VStack(spacing: 10) {
                        if let audioId = clipAudioId(word) {
                            clipControls(audioId)
                            if showBack, word.front != "🎧 Nghe và chép lại" {
                                Text(word.front).font(.title3).foregroundStyle(theme?.ink2 ?? .secondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            // Thẻ gõ: mặt trước tiếng Việt (sans 40); thẻ tự chấm: mặt trước tiếng Hàn (phông thẻ 28).
                            Text(word.front)
                                .font(word.typeAnswer ? latinFont(size: 40, weight: .semibold) : cardFont(size: 28))
                                .foregroundStyle(theme?.ink ?? .primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .frame(maxWidth: 620)
                                .textSelection(.enabled)
                        }
                        if let hint = word.hint, !hint.isEmpty {
                            Text(hint).font(.callout).foregroundStyle(theme?.ink2 ?? .secondary)
                        }
                        if showBack {
                            HStack(spacing: 12) {
                                if clipAudioId(word) != nil {
                                    diffText(word)
                                } else {
                                    Text(word.back)
                                        .font(word.typeAnswer ? cardFont(size: 44, weight: .bold) : latinFont(size: 22, weight: .bold))
                                        .foregroundStyle(state.outcome == .wrong ? (theme?.bad ?? .red) : (theme?.ink ?? .primary))
                                        .multilineTextAlignment(.center)
                                        .textSelection(.enabled)
                                }
                                Button {
                                    if let id = clipAudioId(word) { clipPlayer.play(audioId: id, model: model) } else { tts.speak(word.back) }
                                } label: {
                                    Image(systemName: "play.fill").font(.system(size: 14))
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill((theme?.accent ?? .accentColor).opacity(0.16)))
                                }
                                .buttonStyle(.plain)
                                .keyboardShortcut(".", modifiers: .command)
                                .help("Đọc (⌘.)")
                            }
                            if let note = word.note, !note.isEmpty {
                                Text(.init(note)).font(.callout)
                                    .foregroundStyle(theme?.ink2 ?? .secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill((theme?.ink ?? .primary).opacity(0.05)))
                                    .frame(maxWidth: 560)
                            }
                        }
                    }
                    Spacer(minLength: 16)
                    if word.typeAnswer {
                        AnswerField(text: $input, state: answerState, onSubmit: submit)
                            .focused($fieldFocused)
                    } else {
                        Text(state.answered ? "" : state.flipped ? "Bạn nhớ từ này không?  1 = Chưa nhớ · 2 = Nhớ" : "Nghĩ đáp án rồi bấm Space để lật")
                            .font(.callout).foregroundStyle(theme?.ink2 ?? .secondary)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            GlassActionBar(actions(for: word))
                .padding(.bottom, 12)
        }
        .padding(.leading, 6).padding(.trailing, 8)
        .padding(.top, 8)
    }

    /// Nút nghe thay mặt trước thẻ clip: phát/dừng, lặp, tốc độ.
    private func clipControls(_ audioId: String) -> some View {
        HStack(spacing: 14) {
            Button { clipPlayer.toggle(audioId: audioId, model: model) } label: {
                Image(systemName: clipPlayer.isPlaying ? "stop.fill" : "play.fill").font(.system(size: 30))
                    .frame(width: 84, height: 84)
                    .background(Circle().fill((theme?.accent ?? .accentColor).opacity(0.16)))
            }
            .buttonStyle(.plain).help("Nghe lại (⌘.)")
            VStack(alignment: .leading, spacing: 8) {
                Button { clipPlayer.loops.toggle() } label: {
                    Label("Lặp", systemImage: "repeat").foregroundStyle(clipPlayer.loops ? (theme?.accent ?? .accentColor) : (theme?.ink2 ?? .secondary))
                }
                .buttonStyle(.plain)
                Button { clipPlayer.cycleRate() } label: {
                    Label(String(format: "%g×", clipPlayer.rate), systemImage: "speedometer").foregroundStyle(theme?.ink2 ?? .secondary)
                }
                .buttonStyle(.plain)
                if clipPlayer.isLoading { ProgressView().controlSize(.small) }
                if clipPlayer.failed {
                    Text("Không tải được âm thanh (cần mạng lần đầu).").font(.caption).foregroundStyle(theme?.bad ?? .red)
                }
            }
        }
    }

    /// Câu đúng, tô theo so sánh từng từ với câu đã chép (đúng/sai/thiếu/thừa).
    private func diffText(_ word: StudyWord) -> some View {
        let ok = theme?.ok ?? .green, bad = theme?.bad ?? .red
        let diffs = AnswerMatcher.wordDiff(answer: input, target: word.back)
        var text = Text("")
        for (i, d) in diffs.enumerated() {
            let sep = i == 0 ? "" : " "
            switch d.kind {
            case .correct: text = text + Text(sep + d.text).foregroundColor(ok)
            case .wrong(let expected):
                text = text + Text(sep + d.text).foregroundColor(bad).strikethrough()
                    + Text(" " + expected).foregroundColor(ok)
            case .missing: text = text + Text(sep + d.text).foregroundColor(bad).underline()
            case .extra: text = text + Text(sep + d.text).foregroundColor(bad).strikethrough()
            }
        }
        return text.font(cardFont(size: 34)).multilineTextAlignment(.center).textSelection(.enabled)
    }

    private var showBack: Bool { state.answered || state.flipped }

    /// Nút vuông nhỏ góc thẻ: ⭐ (symbol) hoặc 漢 (symbol == nil).
    private func flagChip(_ symbol: String?, on: Bool, help: String, key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol { Image(systemName: on ? symbol : "star") } else { Text("漢").font(.system(size: 15, weight: .bold, design: .serif)) }
            }
            .frame(width: 36, height: 36)
            .foregroundStyle(on ? (theme?.accent ?? .accentColor) : (theme?.ink ?? .primary))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(on ? (theme?.accent ?? .accentColor).opacity(0.16) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke((theme?.ink ?? .primary).opacity(0.15)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: [.command, .shift])
        .help(help)
    }

    // MARK: Cột phải

    /// Cột phải (chỉ cửa sổ ≥ 1100 pt): "Lượt học này" + "Sắp hỏi" + gợi ý cửa sổ học gọn.
    private var sidebarColumn: some View {
        VStack(spacing: 12) {
            panel(spacing: 10) {
                Text("Lượt học này").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 8) {
                    stat(state.masteredCount, "đã thuộc")
                    stat(state.correctCount, "đúng")
                    stat(max(state.attemptedCount - state.correctCount, 0), "sai")
                }
            }
            panel(spacing: 8) {
                Text("Sắp hỏi").font(.system(size: 13, weight: .semibold))
                VStack(spacing: 0) {
                    ForEach(state.upcoming) { q in
                        HStack(spacing: 8) {
                            Text(q.title).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(q.isNew ? "mới" : "hộp \(q.box + 1)")
                                .font(.system(size: 12)).foregroundStyle(theme?.ink2 ?? .secondary)
                                .lineLimit(1).fixedSize()
                        }
                        .font(.system(size: 13))
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(theme?.line ?? .secondary.opacity(0.2)).frame(height: 1)
                        }
                    }
                }
                Spacer(minLength: 8)
                (Text("Cửa sổ học gọn: ") + Text("⌥⌘L").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    + Text(" — nổi trên mọi cửa sổ để vừa học vừa làm việc khác."))
                    .font(.system(size: 12)).foregroundStyle(theme?.ink2 ?? .secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 268)
        .padding(.trailing, 2)
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(n)").font(.system(size: 22, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 11)).foregroundStyle(theme?.ink2 ?? .secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func panel<C: View>(spacing: CGFloat, @ViewBuilder _ body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: spacing) { body() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme?.line ?? .clear)))
    }

    private var completed: some View {
        VStack(spacing: 16) {
            ProgressRing(value: 1).frame(width: 96, height: 96)
            Text("Xong bộ này").font(.title.bold())
            Text("Đúng \(state.correctCount)/\(state.attemptedCount) lượt trả lời")
                .foregroundStyle(theme?.ink2 ?? .secondary)
            GlassActionBar([
                GlassAction(id: "restart", title: "Học lại", isPrimary: true) { model.restartDeck() }
            ])
        }
    }

    // MARK: Hành động

    private var answerState: AnswerState {
        switch state.outcome {
        case .pending: .idle
        case .correct, .known: .correct
        case .wrong: state.canOverride ? .wrong : .revealed
        }
    }

    private func actions(for word: StudyWord) -> [GlassAction] {
        if state.answered {
            var list: [GlassAction] = []
            if state.canOverride {
                list.append(
                    GlassAction(
                        id: "override", title: "Đã trả lời đúng?", shortcut: "⌘Z",
                        key: .init("z", modifiers: .command)
                    ) { model.overrideAsCorrect() })
            }
            list.append(
                GlassAction(id: "next", title: "Thẻ tiếp", shortcut: "↵", isPrimary: true, key: KeyboardShortcut(.return, modifiers: [])) {
                    model.nextCard()
                })
            return list
        }
        if !word.typeAnswer {
            if !state.flipped {
                return [
                    GlassAction(id: "known", title: "Đã thuộc", shortcut: "⌘↵", key: .init(.return, modifiers: .command)) { model.markKnown() },
                    GlassAction(id: "flip", title: "Lật thẻ", shortcut: "Space", isPrimary: true, key: KeyboardShortcut(.space, modifiers: [])) { model.flipCard() },
                ]
            }
            return [
                GlassAction(id: "forgot", title: "Chưa nhớ", shortcut: "1", key: KeyboardShortcut("1", modifiers: [])) { model.gradeSelf(remembered: false) },
                GlassAction(id: "known", title: "Đã thuộc", shortcut: "⌘↵", key: .init(.return, modifiers: .command)) { model.markKnown() },
                GlassAction(id: "remembered", title: "Nhớ", shortcut: "2", isPrimary: true, key: KeyboardShortcut("2", modifiers: [])) { model.gradeSelf(remembered: true) },
            ]
        }
        return [
            GlassAction(
                id: "reveal", title: "Xem đáp án", shortcut: "⌘/", key: .init("/", modifiers: .command),
                isEnabled: word.typeAnswer
            ) { model.revealAnswer() },
            GlassAction(
                id: "known", title: "Đã thuộc", shortcut: "⌘↵", key: .init(.return, modifiers: .command)
            ) { model.markKnown() },
            GlassAction(id: "check", title: "Chấm bài", shortcut: "↵", isPrimary: true, isEnabled: word.typeAnswer, action: submit),
        ]
    }

    private func submit() {
        guard !state.answered else { return }
        model.checkAnswer(input)
    }

    private func focusField() {
        DispatchQueue.main.async { fieldFocused = true }
    }

    /// Phông chữ Hàn trên thẻ — theo theme (serif/sans, hệ số cỡ).
    private func cardFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let scale = theme?.typography.cardScale ?? 1
        let isSerif = theme?.typography.cardKoreanFont != "sans"
        return .system(size: size * scale, weight: weight, design: isSerif ? .serif : .default)
    }

    /// Phông chữ Việt trên thẻ — luôn sans, vẫn theo hệ số cỡ của theme.
    private func latinFont(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size * (theme?.typography.cardScale ?? 1), weight: weight)
    }
}
