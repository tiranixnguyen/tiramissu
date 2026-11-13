import DesignSystem
import HanCore
import SwiftUI

/// Màn Học — thẻ gõ đáp án. View chỉ đọc `model.state` và gọi hàm của `AppModel`.
///
/// Bàn phím Hàn: macOS không tự đổi bộ gõ theo ô nhập. Hãy thêm "Korean (2-Set)" trong
/// Cài đặt hệ thống › Bàn phím › Nguồn nhập, rồi chuyển bằng phím Caps Lock hoặc ⌃Space.
struct StudyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    private var state: StudySessionState { model.state }

    var body: some View {
        Group {
            if state.currentDeckId == nil {
                ContentUnavailableView(
                    "Chưa có bộ để học", systemImage: "rectangle.on.rectangle",
                    description: Text("Thêm bộ từ ở Thư viện hoặc Nhập từ AI, rồi đồng bộ."))
            } else if state.isCompleted {
                completed
            } else if let word = state.currentWord {
                card(word)
            } else {
                ContentUnavailableView("Bộ này chưa có thẻ", systemImage: "tray")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) { progressBar }
        }
        .onChange(of: state.cardSerial) {
            input = ""
            focusField()
        }
        .onAppear { focusField() }
    }

    // MARK: Thanh tiến độ

    private var deckTitle: String {
        let name = model.visibleDecks.first { $0.id == state.currentDeckId }?.name ?? "Bộ ảo"
        let group = state.vocabGroups.first { $0.id == state.currentVocabGroup }?.name
        return group.map { "\(name) · \($0)" } ?? name
    }

    private var progressBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deckTitle).font(.callout.weight(.semibold)).foregroundStyle(theme?.ink ?? .primary)
                ProgressView(value: state.progress).tint(theme?.accent).frame(width: 260)
            }
            Text("\(state.masteredCount)/\(state.totalCount) thuộc · đúng \(state.correctCount)/\(state.attemptedCount)")
                .font(.caption).monospacedDigit()
                .foregroundStyle(theme?.ink2 ?? .secondary)
        }
    }

    // MARK: Thẻ

    private func card(_ word: StudyWord) -> some View {
        VStack(spacing: 20) {
            CardSurface {
                VStack(spacing: 0) {
                    Text(word.typeAnswer ? "VIỆT → HÀN · GÕ ĐÁP ÁN" : "HÀN → VIỆT · TỰ CHẤM")
                        .font(.caption.weight(.semibold)).tracking(1)
                        .foregroundStyle(theme?.ink2 ?? .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 16)
                    VStack(spacing: 14) {
                        Text(word.front)
                            .font(cardFont(size: 56))
                            .foregroundStyle(theme?.ink ?? .primary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                        if let hint = word.hint, !hint.isEmpty {
                            Text(hint).font(.callout).foregroundStyle(theme?.ink2 ?? .secondary)
                        }
                        if state.answered {
                            Text(word.back)
                                .font(cardFont(size: 40))
                                .foregroundStyle(theme?.accent ?? .accentColor)
                                .textSelection(.enabled)
                            if let note = word.note, !note.isEmpty {
                                Text(.init(note)).font(.callout)
                                    .foregroundStyle(theme?.ink2 ?? .secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    Spacer(minLength: 16)
                    if word.typeAnswer {
                        AnswerField(text: $input, state: answerState, onSubmit: submit)
                            .focused($fieldFocused)
                    } else {
                        Text("Thẻ tự chấm — dùng Đã thuộc ⌘↵ (chấm tay làm ở T2.35)")
                            .font(.callout).foregroundStyle(theme?.ink2 ?? .secondary)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            GlassActionBar(actions(for: word))
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
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

    private func cardFont(size: CGFloat) -> Font {
        let scale = theme?.typography.cardScale ?? 1
        let isSerif = theme?.typography.cardKoreanFont != "sans"
        return .system(size: size * scale, weight: .semibold, design: isSerif ? .serif : .default)
    }
}
