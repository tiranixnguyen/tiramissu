import AppKit
import DesignSystem
import HanCore
import SwiftUI

/// Màn Nhập từ AI: chép prompt → dán JSON → tick từ cần thêm → thêm vào bộ có sẵn
/// (`POST /decks/:id/cards`) hoặc bộ mới (`POST /decks`). Cần mạng.
struct ImportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    private enum Target: Hashable { case existing, new }

    // Bước 1
    @State private var kind: PromptKind = .vocab
    @State private var tool: AITool = .gemini
    @State private var copied = false
    // Bước 2
    @State private var json = ""
    // Bước 3
    @State private var target: Target = .existing
    @State private var deckId = ""
    @State private var newName = ""
    @State private var lastAutoName = ""
    @State private var groupId = ""
    @State private var selection = ImportSelection(words: [], library: ContentSnapshot())
    @State private var filter: ImportFilter = .all
    @State private var focusedRow: Int?
    @FocusState private var tableFocused: Bool
    @State private var busy = false
    @State private var width: CGFloat = 1000
    @State private var error: String?
    @State private var done: String?

    private var parsed: DeckImport { parseDeckImport(json) }
    private var groups: [ContentGroup] { model.content.groups.sorted { $0.position < $1.position } }
    private var decksInGroup: [ContentDeck] {
        model.content.decks.filter { $0.groupId == groupId }.sorted { $0.position < $1.position }
    }
    private var targetDeck: ContentDeck? { model.content.decks.first { $0.id == deckId } }
    private var targetName: String? {
        switch target {
        case .existing: targetDeck?.name
        case .new: newName.trimmed.isEmpty ? nil : newName.trimmed
        }
    }
    private var leftWidth: CGFloat { min(340, max(260, (width - 30) * 0.36)) }
    /// Cột phải hẹp (cửa sổ nhỏ): bảng bỏ cột #, nhãn trạng thái rút gọn.
    private var compact: Bool { width - 30 - leftWidth < 520 }

    private var canAdd: Bool {
        guard parsed.ok, !busy, selection.selectedCount > 0 else { return false }
        switch target {
        case .existing: return targetDeck != nil
        case .new: return !newName.trimmed.isEmpty && groups.contains { $0.id == groupId }
        }
    }

    var body: some View {
        // Luôn hai cột như prototype: trái = bước 1 + 2, phải = bước 3. Cửa sổ hẹp thì cột trái co
        // từ 340 xuống 260 pt và các hàng trong thẻ tự xuống hai dòng (ViewThatFits).
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                promptCard
                pasteCard.frame(maxHeight: .infinity)
            }
            .frame(width: leftWidth)
            pickCard.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .screenTopBar {
            TopBarTitle(
                main: "Nhập từ AI",
                detail: "Doc → chép prompt → Gemini / NotebookLM → dán JSON → tick “Đã đưa vào app”",
                detailSize: 13)
        }
        .onAppear {
            if groupId.isEmpty { groupId = groups.first?.id ?? "" }
            if targetDeck == nil { deckId = decksInGroup.first?.id ?? "" }
            if model.content.decks.isEmpty { target = .new }
            resetSelection()
        }
        .onChange(of: json) {
            resetSelection()
            if !json.isEmpty { done = nil; error = nil }
            if newName.isEmpty || newName == lastAutoName {
                newName = parsed.name ?? ""
                lastAutoName = newName
            }
        }
        .onChange(of: groupId) {
            if targetDeck?.groupId != groupId { deckId = decksInGroup.first?.id ?? "" }
        }
    }

    /// Sửa JSON → lựa chọn về mặc định (từ đã có bỏ tick).
    private func resetSelection() {
        selection = ImportSelection(words: parsed.words, library: model.content)
        filter = .all
        focusedRow = nil
    }

    // MARK: Bước 1 — Chép prompt

    private var promptCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        stepHeader(1, "Chép prompt")
                        Spacer(minLength: 8)
                        toolPicker
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        stepHeader(1, "Chép prompt")
                        toolPicker
                    }
                }
                FlowLayout(spacing: 6) {
                    ForEach(PromptKind.allCases, id: \.self) { k in
                        chip(label(k), on: k == kind, height: 30) { kind = k; copied = false }
                    }
                }
                ScrollView {
                    Text(Prompts.text(kind: kind, tool: tool))
                        .font(.system(size: 12, design: .monospaced)).lineSpacing(3)
                        .foregroundStyle(ink2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .frame(height: 118)
                .background(RoundedRectangle(cornerRadius: 12).fill(ink.opacity(0.05)))
                Button(copied ? "Đã chép ✓" : "Chép prompt ⌘⇧C", action: copyPrompt)
                    .buttonStyle(FilledButtonStyle(height: 40, fontSize: 13.5))
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .padding(16)
        }
    }

    private var toolPicker: some View {
        segmented([(AITool.gemini, "Gemini"), (AITool.notebookLM, "NotebookLM")], selection: tool, height: 28) {
            tool = $0; copied = false
        }
    }

    private func label(_ k: PromptKind) -> String {
        switch k {
        case .vocab: "Từ vựng"
        case .grammar: "Ngữ pháp"
        case .fix: "Chữa bài tập"
        case .listen: "Câu nghe"
        }
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Prompts.text(kind: kind, tool: tool), forType: .string)
        copied = true
    }

    private var deckTypeForKind: DeckType? {
        switch kind {
        case .vocab: nil
        case .grammar: .grammar
        case .fix: .writing
        case .listen: .listening
        }
    }

    // MARK: Bước 2 — Dán kết quả

    private var pasteCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    stepHeader(2, "Dán kết quả")
                    Spacer(minLength: 8)
                    kbd("⌘V")
                }
                TextEditor(text: $json)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(theme?.surface ?? .clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(jsonColor(neutral: line), lineWidth: 1.5)))
                HStack(spacing: 8) {
                    Circle().fill(jsonColor(neutral: ink2)).frame(width: 8, height: 8)
                    Text(status).lineLimit(1).truncationMode(.tail)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(jsonColor(neutral: ink2))
                if !json.trimmed.isEmpty && !parsed.errors.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(parsed.errors, id: \.self) { Text("• \($0)") }
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 80)
                    .foregroundStyle(theme?.bad ?? .red)
                }
            }
            .padding(16)
        }
    }

    private func jsonColor(neutral: Color) -> Color {
        if json.trimmed.isEmpty { return neutral }
        return parsed.ok ? (theme?.ok ?? .green) : (theme?.bad ?? .red)
    }

    private var status: String {
        if json.trimmed.isEmpty { return "Dán JSON từ AI vào ô trên" }
        if parsed.ok {
            let dup = selection.count(.existing)
            return "JSON hợp lệ · \(parsed.words.count) từ" + (dup > 0 ? " · \(dup) từ đã có" : "")
        }
        return "JSON chưa hợp lệ · \(parsed.errors.count) lỗi"
    }

    // MARK: Bước 3 — Chọn từ để thêm vào bộ

    private var pickCard: some View {
        card {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            stepHeader(3, "Chọn từ để thêm vào bộ")
                            Spacer(minLength: 8)
                            HStack(spacing: 6) {
                                kbd("Space")
                                Text("chọn / bỏ")
                                kbd("⌘A").padding(.leading, 6)
                                Text("tất cả")
                            }
                            .font(.system(size: 12)).foregroundStyle(ink2)
                            .fixedSize()
                        }
                        stepHeader(3, "Chọn từ để thêm vào bộ")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    targetRow
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
                separator
                selectionBar
                separator
                table
                separator
                footer
            }
        }
    }

    /// Thêm vào · Bộ có sẵn / Tên bộ mới · Nhóm — một hàng; hẹp thì ô bộ xuống hàng dưới.
    private var targetRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                targetField
                deckField.frame(minWidth: 180)
                groupField.frame(width: 120)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 10) {
                    targetField
                    groupField.frame(minWidth: 100)
                }
                deckField
            }
        }
    }

    private var targetField: some View {
        field("Thêm vào") {
            segmented([(Target.existing, "Bộ có sẵn"), (Target.new, "Bộ mới")], selection: target, height: 36) {
                target = $0
            }
        }
        .fixedSize()
    }

    @ViewBuilder private var deckField: some View {
        switch target {
        case .existing:
            field("Bộ có sẵn") {
                dropdown(
                    decksInGroup.map { ($0.id, $0.name) }, selection: $deckId, placeholder: "Nhóm này chưa có bộ")
            }
        case .new:
            field("Tên bộ mới") {
                TextField("Tên bộ", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(ink)
                    .padding(.horizontal, 10).frame(height: 36)
                    .background(inputBox)
            }
        }
    }

    private var groupField: some View {
        field("Nhóm") {
            dropdown(groups.map { ($0.id, $0.name) }, selection: $groupId, placeholder: "Chưa có nhóm")
        }
    }

    private var inputBox: some View {
        RoundedRectangle(cornerRadius: 10).fill(theme?.surface ?? .clear)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(line))
    }

    /// Ô chọn kiểu `<select>` của prototype: nền `surface`, viền `line`, cao 36.
    private func dropdown(_ items: [(String, String)], selection: Binding<String>, placeholder: String) -> some View {
        Menu {
            ForEach(items, id: \.0) { id, title in
                Button { selection.wrappedValue = id } label: {
                    if id == selection.wrappedValue { Label(title, systemImage: "checkmark") } else { Text(title) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(items.first { $0.0 == selection.wrappedValue }?.1 ?? placeholder)
                    .foregroundStyle(items.isEmpty ? ink2 : ink)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(ink2)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10).frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(inputBox)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
        .disabled(items.isEmpty)
    }

    private var selectionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                selectAllToggle
                Spacer(minLength: 8)
                filterChips
            }
            VStack(alignment: .leading, spacing: 8) {
                selectAllToggle
                filterChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var selectAllToggle: some View {
            Toggle(isOn: Binding(
                get: { selection.allChecked(filter) },
                set: { selection.setAll($0, filter) }
            )) {
                Text("Đã chọn \(selection.selectedCount)/\(selection.count(.all))")
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            .toggleStyle(.checkbox)
            .disabled(selection.count(filter) == 0)
            .fixedSize()
    }

    private var filterChips: some View {
        HStack(spacing: 6) {
            filterChip(.all, "Tất cả")
            filterChip(.new, "Mới")
            filterChip(.existing, "Đã có")
        }
        .fixedSize()
    }

    private func filterChip(_ f: ImportFilter, _ title: String) -> some View {
        chip("\(title)  \(selection.count(f))", on: filter == f, height: 28) {
            filter = f
            if let row = focusedRow, !selection.indices(f).contains(row) { focusedRow = nil }
        }
    }

    // MARK: Bảng

    private var table: some View {
        let shown = selection.indices(filter)
        return VStack(spacing: 0) {
            tableRow {
                Color.clear
            } num: {
                Text("#")
            } front: {
                Text("MẶT TRƯỚC · VIỆT")
            } back: {
                Text("MẶT SAU · HÀN")
            } state: {
                Text(compact ? "" : "TRẠNG THÁI")
            }
            .font(.system(size: 11, weight: .semibold)).kerning(0.5)
            .foregroundStyle(ink2)
            .frame(height: 36)
            separator
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(shown, id: \.self) { i in
                            row(i).id(i)
                        }
                    }
                }
                .onChange(of: focusedRow) { if let focusedRow { proxy.scrollTo(focusedRow) } }
            }
            .overlay {
                if shown.isEmpty {
                    Text(emptyText).font(.system(size: 13)).foregroundStyle(ink2)
                        .multilineTextAlignment(.center).padding(24)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .focusable()
        .focusEffectDisabled()
        .focused($tableFocused)
        .onKeyPress(.space) {
            guard let i = focusedRow ?? shown.first else { return .ignored }
            focusedRow = i
            selection.toggle(i)
            return .handled
        }
        .onKeyPress(.downArrow) { moveFocus(1, in: shown) }
        .onKeyPress(.upArrow) { moveFocus(-1, in: shown) }
        .background {
            // ⌘A chỉ chọn tất cả khi đang ở bảng — ở ô JSON vẫn là chọn hết chữ.
            if tableFocused {
                Button("Chọn tất cả") { selection.setAll(!selection.allChecked(filter), filter) }
                    .keyboardShortcut("a", modifiers: .command)
                    .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
            }
        }
    }

    private func moveFocus(_ step: Int, in shown: [Int]) -> KeyPress.Result {
        guard !shown.isEmpty else { return .ignored }
        guard let cur = focusedRow, let pos = shown.firstIndex(of: cur) else {
            focusedRow = step > 0 ? shown.first : shown.last
            return .handled
        }
        focusedRow = shown[min(max(pos + step, 0), shown.count - 1)]
        return .handled
    }

    private var emptyText: String {
        if json.trimmed.isEmpty { return "Dán JSON ở bước 2 để xem trước các từ." }
        if parsed.words.isEmpty { return "Chưa đọc được từ nào — xem lỗi ở bước 2." }
        return filter == .new ? "Không có từ mới." : "Không có từ nào đã có trong thư viện."
    }

    private func row(_ i: Int) -> some View {
        let w = selection.words[i]
        let on = selection.isChecked(i)
        let rowInk = on ? ink : ink2
        return tableRow {
            Image(systemName: on ? "checkmark.square.fill" : "square")
                .font(.system(size: 17))
                .foregroundStyle(on ? (theme?.accent ?? .accentColor) : ink2)
        } num: {
            Text("\(i + 1)").font(.system(size: 12)).monospacedDigit().foregroundStyle(ink2)
        } front: {
            Text(w.front).font(.system(size: 14)).foregroundStyle(rowInk).lineLimit(compact ? 2 : 1)
        } back: {
            Text(w.back).font(.system(size: 14, weight: .semibold)).foregroundStyle(rowInk).lineLimit(compact ? 2 : 1)
        } state: {
            if let deck = selection.existingIn[i] {
                badge(compact ? "Đã có" : "Đã có · \(deck)", tint: theme?.flag ?? .orange, opacity: 0.18)
                    .help("Đã có trong «\(deck)»")
            } else {
                badge("Mới", tint: theme?.accent ?? .accentColor, opacity: 0.14)
            }
        }
        .frame(minHeight: 48)
        .background(on ? (theme?.accent ?? .accentColor).opacity(0.06) : .clear)
        .overlay {
            if tableFocused && focusedRow == i {
                Rectangle().stroke(theme?.accent ?? .accentColor, lineWidth: 1.5).padding(1)
            }
        }
        .overlay(alignment: .bottom) { separator }
        .contentShape(Rectangle())
        .onTapGesture {
            tableFocused = true
            focusedRow = i
            selection.toggle(i)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(on ? "Đã chọn" : "Chưa chọn")
    }

    /// Một hàng bảng: ô tick 24 · # 32 · trước · sau · trạng thái.
    private func tableRow<A: View, B: View, C: View, D: View, E: View>(
        @ViewBuilder check: () -> A, @ViewBuilder num: () -> B, @ViewBuilder front: () -> C,
        @ViewBuilder back: () -> D, @ViewBuilder state: () -> E
    ) -> some View {
        HStack(spacing: compact ? 10 : 14) {
            check().frame(width: 24)
            if !compact { num().frame(width: 32, alignment: .center) }
            front().frame(maxWidth: .infinity, alignment: .leading)
            back().frame(maxWidth: .infinity, alignment: .leading)
            if compact {
                state().frame(width: 64, alignment: .leading)
            } else {
                state().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, compact ? 6 : 0)
    }

    private func badge(_ text: String, tint: Color, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(ink)
            .lineLimit(1).truncationMode(.tail)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(opacity)))
    }

    // MARK: Chân

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary).font(.system(size: 13.5, weight: .semibold))
                if let error {
                    Text(error).foregroundStyle(theme?.bad ?? .red)
                } else if let done {
                    Text(done).foregroundStyle(theme?.ok ?? .green)
                } else if let summary2 {
                    Text(summary2).foregroundStyle(ink2)
                }
            }
            .font(.system(size: 12))
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(busy ? "Đang thêm…" : "Thêm \(selection.selectedCount) thẻ ⌘↵", action: add)
                .buttonStyle(FilledButtonStyle(height: 42, fontSize: 14))
                .fixedSize()
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canAdd)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(ink.opacity(0.03))
    }

    private var summary: String {
        guard parsed.ok else { return "Chưa có từ nào để thêm" }
        let n = selection.selectedCount
        if n == 0 { return "Chưa chọn từ nào" }
        let into = targetName.map { "«\($0)»" } ?? (target == .new ? "bộ mới (chưa đặt tên)" : "bộ chưa chọn")
        return "Sẽ thêm \(n) thẻ vào \(into)" + (target == .new ? " · bộ mới" : "")
    }

    private var summary2: String? {
        guard parsed.ok else { return nil }
        let skipped = selection.count(.all) - selection.selectedCount
        let dup = selection.skippedExistingCount
        if skipped == 0 { return "Thêm tất cả từ trong JSON" }
        return skipped == dup ? "Bỏ qua \(dup) từ đã có" : "Bỏ qua \(skipped) từ (\(dup) từ đã có)"
    }

    private func add() {
        guard canAdd else { return }
        busy = true
        error = nil
        let words = selection.selectedWords
        let target = target, deckId = deckId, groupId = groupId, name = newName.trimmed
        let type = deckTypeForKind
        Task {
            do {
                let into: String
                switch target {
                case .existing:
                    try await model.addCards(deckId: deckId, words: words)
                    into = targetDeck?.name ?? ""
                case .new:
                    let deck = try await model.createDeck(
                        NewDeck(groupId: groupId, name: name, type: type, words: words))
                    into = deck.name
                }
                json = ""
                newName = ""
                lastAutoName = ""
                done = "Đã thêm \(words.count) thẻ vào «\(into)» — nhớ tick “Đã đưa vào app” trong Doc."
            } catch {
                // Giữ nguyên JSON và lựa chọn để thử lại.
                self.error = (error as? APIError)?.message ?? error.localizedDescription
            }
            busy = false
        }
    }

    // MARK: Chung

    private var ink: Color { theme?.ink ?? .primary }
    private var ink2: Color { theme?.ink2 ?? .secondary }
    private var line: Color { theme?.line ?? .gray }
    private var separator: some View { Rectangle().fill(line).frame(height: 1) }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(line))
    }

    private func stepHeader(_ n: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)").font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme?.surface ?? .white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ink))
            Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(ink2)
            content()
        }
    }

    private func kbd(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(ink2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(line))
    }

    /// Nút viên: đang chọn = nền `ink`, chữ `surface`; không = viền `line`.
    private func chip(_ title: String, on: Bool, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).monospacedDigit().lineLimit(1)
                .foregroundStyle(on ? (theme?.surface ?? .white) : ink)
                .padding(.horizontal, 11).frame(height: height)
                .background(Capsule().fill(on ? ink : .clear))
                .overlay(Capsule().stroke(on ? .clear : line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    /// Nhóm nút liền viền; mục đang chọn tô `ink` 8%.
    private func segmented<T: Hashable>(
        _ items: [(T, String)], selection: T, height: CGFloat, pick: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { value, title in
                Button { pick(value) } label: {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                        .padding(.horizontal, 12).frame(height: height)
                        .background(value == selection ? ink.opacity(0.08) : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(line))
        .fixedSize()
    }
}

/// Nút chính nền `accent`, chữ `onAccent`, bo 12.
private struct FilledButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat
    var fontSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold)).lineLimit(1)
            .foregroundStyle(theme?.onAccent ?? .white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(RoundedRectangle(cornerRadius: 12).fill(theme?.accent ?? .accentColor))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Xếp các nút theo hàng, tự xuống dòng khi hết chỗ.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var origins: [CGPoint] = []
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowH = max(rowH, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), origins)
    }
}
