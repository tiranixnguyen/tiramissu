import DesignSystem
import HanCore
import AppKit
import SwiftUI

/// Màn Thư viện: nhóm → bộ → bảng thẻ. Sửa/thêm/xoá cần mạng; lỗi thì giữ nguyên chữ đang sửa.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(\.theme) private var theme
    @FocusState private var searchFocused: Bool
    @FocusState private var tableFocused: Bool

    @State private var deckId: String?
    @State private var search = ""
    @State private var selection: Set<String> = []
    @State private var editing: CellID?
    @State private var draft = ""
    @State private var showAddCard = false
    @State private var showEditDeck = false
    @State private var tableWidth: CGFloat = 800
    @State private var pendingDelete: [String] = []
    @State private var error: String?

    struct CellID: Equatable {
        enum Field { case front, back }
        var card: String
        var field: Field
    }

    // MARK: Thanh trên (như prototype: ô tìm bên trái; "+ Bộ mới từ AI", theme, sáng/tối bên phải)

    /// Ô tìm — mục toolbar thật (phải gõ được), nằm đè lên khung kính của `screenTopBar`.
    @ToolbarContentBuilder private var searchToolbar: some ToolbarContent {
        // .navigation: hệ thống xếp sát bên trái (cạnh nút sidebar), không căn giữa như .principal.
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                TextField("Tìm bộ, từ Hàn hoặc nghĩa…  ⌘F", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(ink2)
                }
                Button("") { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command).opacity(0).frame(width: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: 320, height: 30, alignment: .leading)
            // Viền/nền giống `TopBarButtonStyle`: ink pha trong suốt, không nền đặc.
            .background(RoundedRectangle(cornerRadius: 10).fill(ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.2)))
            // Hệ thống đặt mục .navigation sát mép trái thanh kính → lùi vào để hai viền không chồng nhau.
            .padding(.leading, 10)
        }
        .sharedBackgroundVisibility(.hidden)
    }

    // MARK: Dữ liệu

    private var groups: [ContentGroup] { model.content.groups.sorted { $0.position < $1.position } }
    private var effectiveGroup: String? { nav.libraryGroupId ?? groups.first?.id }

    private var decks: [ContentDeck] {
        let q = search.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let all = model.content.decks.sorted { $0.position < $1.position }
        if q.isEmpty { return all.filter { $0.groupId == effectiveGroup } }
        // Đang tìm: tìm trên mọi nhóm (tên bộ, mặt trước/sau của thẻ).
        return all.filter { d in
            func match(_ s: String) -> Bool { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(q) }
            return match(d.name) || d.cards.contains { match($0.front) || match($0.back) }
        }
    }

    private var deck: ContentDeck? { model.content.decks.first { $0.id == deckId } }

    // MARK: Thân

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            deckColumn.frame(width: 280)
            cardsPanel
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
        .screenTopBar { EmptyView() } actions: {
            Button { nav.screen = .importAI } label: { Text("+ Bộ mới từ AI") }
                .buttonStyle(TopBarButtonStyle(prominent: true))
        }
        .toolbar { searchToolbar }
        .onAppear { if deckId == nil { deckId = decks.first?.id } }
        .onChange(of: effectiveGroup) { deckId = decks.first?.id }
        .alert("Không thực hiện được", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng") { error = nil }
        } message: { Text(error ?? "") }
        .confirmationDialog(
            "Xoá \(pendingDelete.count) thẻ?", isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } }), titleVisibility: .visible
        ) {
            Button("Xoá", role: .destructive) { deleteCards(pendingDelete); pendingDelete = [] }
            Button("Huỷ", role: .cancel) { pendingDelete = [] }
        } message: { Text("Thẻ bị xoá khỏi server, không hoàn tác được.") }
        .sheet(isPresented: $showAddCard) {
            if let deck { AddCardSheet(deck: deck) }
        }
        .sheet(isPresented: $showEditDeck) {
            if let deck { EditDeckSheet(deck: deck) }
        }
    }

    // MARK: Cột bộ

    private var deckColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(search.isEmpty ? (groups.first { $0.id == effectiveGroup }?.name ?? "") : "Kết quả tìm: \(decks.count) bộ")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 4).padding(.top, 2)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(decks) { d in
                        Button { selectDeck(d.id) } label: { deckRow(d) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Sửa bộ…") { selectDeck(d.id); showEditDeck = true }
                            }
                    }
                    if decks.isEmpty {
                        Text("Chưa có bộ nào.").font(.callout).foregroundStyle(ink2).padding(.top, 20)
                    }
                }
            }
        }
    }

    private func selectDeck(_ id: String) {
        if deckId != id { selection = []; editing = nil }
        deckId = id
    }

    private func deckRow(_ d: ContentDeck) -> some View {
        let selected = d.id == deckId
        let clips = d.cards.filter { $0.audio.front != nil }.count
        var meta = ["\(d.cards.count) thẻ"]
        if clips > 0 { meta.append("\(clips) clip") }
        meta.append(model.reviewStatus(deckId: d.id).shortLabel)
        return VStack(alignment: .leading, spacing: 6) {
            Text(d.name).font(.system(size: 15, weight: .semibold)).lineLimit(2)
            HStack(spacing: 6) {
                if let t = d.type {
                    Text(t.label).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(ink.opacity(0.08)))
                }
                Text(meta.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(theme?.surface ?? .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? (theme?.accent ?? .accentColor) : (theme?.line ?? .clear), lineWidth: selected ? 1.5 : 1)))
        .contentShape(Rectangle())
    }

    // MARK: Bảng thẻ

    @ViewBuilder private var cardsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let deck {
                panelHeader(deck)
                    .padding(.horizontal, 24).padding(.vertical, 20)
                cardTable(deck)
            } else {
                ContentUnavailableView("Chọn một bộ", systemImage: "books.vertical")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme?.line ?? .clear)))
    }

    /// Tên bộ + dòng nguồn, nút bên phải. Panel hẹp (tên không vừa một dòng cạnh nút) → nút xuống dưới,
    /// tên được cả bề ngang để xuống dòng thay vì bị bóp còn vài chữ.
    private func panelHeader(_ deck: ContentDeck) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name).font(.system(size: 26, weight: .bold))
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    Text(subtitle(deck)).font(.system(size: 13)).foregroundStyle(ink2)
                }
                Spacer(minLength: 16)
                panelActions(deck)
            }
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name).font(.system(size: 24, weight: .bold)).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle(deck)).font(.system(size: 13)).foregroundStyle(ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                panelActions(deck)
            }
        }
    }

    private func panelActions(_ deck: ContentDeck) -> some View {
        HStack(spacing: 8) {
            Button("Sửa bộ…") { showEditDeck = true }
                .buttonStyle(TopBarButtonStyle())
            Button("Học bộ này ↵") {
                model.switchDeck(deck.id)
                nav.screen = .study
            }
            .buttonStyle(PanelButtonStyle())
            .keyboardShortcut(.return, modifiers: [])
        }
        .fixedSize()
    }

    private func subtitle(_ d: ContentDeck) -> String {
        var parts: [String] = []
        if let s = d.source, !s.isEmpty { parts.append("Nguồn: \(s)") }
        if let desc = d.description, !desc.isEmpty { parts.append(desc) }
        parts.append(model.reviewStatus(deckId: d.id).shortLabel)
        return parts.joined(separator: " · ")
    }

    /// Bảng thẻ tự vẽ (không dùng `Table`: NSTableView tự thêm lề né toolbar và vẽ đè phần tiêu đề panel).
    private func cardTable(_ deck: ContentDeck) -> some View {
        let cards = deck.cards.sorted { $0.position < $1.position }
        return VStack(spacing: 0) {
            tableRow {
                Text("Mặt trước")
            } back: {
                Text("Mặt sau")
            } kind: {
                Text("Kiểu")
            } flags: {
                Text("Cờ")
            }
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(ink2)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { separator }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cards) { c in cardRow(c) }
                    Button { showAddCard = true } label: {
                        Text("+ Thêm thẻ (⌘N) · bấm đúp một ô để sửa ngay trong bảng")
                            .font(.system(size: 13)).foregroundStyle(ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("n", modifiers: .command)
                    .overlay(alignment: .bottom) { separator }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tableWidth = $0 }
        .focusable()
        .focusEffectDisabled()
        .focused($tableFocused)
        .onDeleteCommand { if !selection.isEmpty, editing == nil { pendingDelete = Array(selection) } }
    }

    private func cardRow(_ c: ContentCard) -> some View {
        let selected = selection.contains(c.id)
        return tableRow {
            cell(c, .front)
        } back: {
            cell(c, .back)
        } kind: {
            Text((c.typeAnswer ? "Gõ đáp án" : "Tự chấm") + (c.passage ? " · đoạn văn" : ""))
                .font(.system(size: 13)).foregroundStyle(ink2).lineLimit(2)
        } flags: {
            Text((c.marked ? "★" : "") + (c.hanja ? "漢" : "") + (c.passage ? "📖" : ""))
                .font(.system(size: 15))
        }
        .padding(.vertical, 12)
        .background((theme?.accent ?? .accentColor).opacity(selected ? 0.12 : 0))
        .overlay(alignment: .bottom) { separator }
        .contentShape(Rectangle())
        // Đồng thời với bấm đúp trong ô: chọn ngay, không chờ xem có phải bấm đúp không.
        .simultaneousGesture(TapGesture().onEnded { tap(c.id) })
        .contextMenu {
            let ids = selection.contains(c.id) ? Array(selection) : [c.id]
            Button("Xoá \(ids.count) thẻ", role: .destructive) { pendingDelete = ids }
        }
    }

    /// Bấm: chọn một thẻ; ⌘-bấm: thêm/bỏ khỏi vùng chọn.
    private func tap(_ id: String) {
        tableFocused = true
        if NSEvent.modifierFlags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }

    /// Cột Kiểu: ~18% bề rộng bảng (96…150pt); bảng hẹp thì ẩn để nhường chỗ cho Mặt trước/Mặt sau.
    private var kindWidth: CGFloat? {
        tableWidth < 560 ? nil : min(150, max(96, tableWidth * 0.18))
    }

    /// Một hàng bảng: Mặt trước/Mặt sau chia đều phần còn lại, Kiểu theo `kindWidth`, Cờ 44.
    private func tableRow<A: View, B: View, C: View, D: View>(
        @ViewBuilder front: () -> A, @ViewBuilder back: () -> B,
        @ViewBuilder kind: () -> C, @ViewBuilder flags: () -> D
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            front().frame(maxWidth: .infinity, alignment: .leading)
            back().frame(maxWidth: .infinity, alignment: .leading)
            if let kindWidth { kind().frame(width: kindWidth, alignment: .leading) }
            flags().frame(width: 44, alignment: .center)
        }
        .padding(.horizontal, 20)
    }

    private var separator: some View {
        Rectangle().fill(theme?.line ?? .secondary).frame(height: 1)
    }

    @ViewBuilder private func cell(_ c: ContentCard, _ field: CellID.Field) -> some View {
        let id = CellID(card: c.id, field: field)
        let text = field == .front ? c.front : c.back
        if editing == id {
            TextField("", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
                .onSubmit { commit(c, field) }
                .onExitCommand { editing = nil }
        } else {
            Text((field == .front && c.audio.front != nil ? "▶ " : "") + text)
                .font(field == .back ? .system(size: 15, weight: .semibold) : .system(size: 15))
                .foregroundStyle(ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { draft = text; editing = id }
        }
    }

    // MARK: Hành động

    private func commit(_ c: ContentCard, _ field: CellID.Field) {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = field == .front ? c.front : c.back
        guard !value.isEmpty, value != old else { editing = nil; return }
        var edit = CardEdit(
            front: c.front, back: c.back, hint: c.hint, note: c.note, altAnswers: c.altAnswers,
            typeAnswer: c.typeAnswer)
        if field == .front { edit.front = value } else { edit.back = value }
        Task {
            do {
                try await model.updateCard(id: c.id, edit: edit)
                editing = nil
            } catch {
                // Giữ ô ở chế độ sửa + chữ đang gõ, chỉ báo lỗi.
                self.error = Self.message(error)
            }
        }
    }

    private func deleteCards(_ ids: [String]) {
        Task {
            for id in ids {
                do { try await model.deleteCard(id: id) } catch {
                    self.error = Self.message(error)
                    return
                }
            }
            selection = []
        }
    }

    static func message(_ error: Error) -> String {
        (error as? APIError)?.message ?? error.localizedDescription
    }

    private var ink: Color { theme?.ink ?? .primary }
    private var ink2: Color { theme?.ink2 ?? .secondary }
}

/// Nút chính trong panel (như "Học bộ này ↵" ở prototype): nền `ink`, chữ `bg`.
private struct PanelButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(theme?.bg ?? .white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(theme?.ink ?? .primary))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.75 : isEnabled ? 1 : 0.45)
    }
}

// MARK: Thêm thẻ

private struct AddCardSheet: View {
    let deck: ContentDeck
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var front = ""
    @State private var back = ""
    @State private var hint = ""
    @State private var note = ""
    @State private var typeAnswer = true
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Thẻ mới trong “\(deck.name)”") {
                TextField("Mặt trước (tiếng Việt)", text: $front)
                TextField("Mặt sau (tiếng Hàn)", text: $back)
                TextField("Gợi ý (tuỳ chọn)", text: $hint)
                TextField("Ghi chú Markdown (tuỳ chọn)", text: $note, axis: .vertical).lineLimit(2...5)
                Toggle("Thẻ gõ đáp án", isOn: $typeAnswer)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Huỷ", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Thêm") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || front.trimmed.isEmpty || back.trimmed.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private func add() {
        busy = true
        let word = ImportedWord(
            front: front.trimmed, back: back.trimmed, typeAnswer: typeAnswer,
            hint: hint.trimmed.isEmpty ? nil : hint.trimmed, note: note.trimmed.isEmpty ? nil : note)
        Task {
            do {
                try await model.addCard(deckId: deck.id, word: word)
                dismiss()
            } catch {
                self.error = LibraryView.message(error)  // giữ nguyên chữ đang nhập
                busy = false
            }
        }
    }
}

// MARK: Sửa bộ

private struct EditDeckSheet: View {
    let deck: ContentDeck
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: DeckType?
    @State private var source = ""
    @State private var desc = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Sửa bộ") {
                TextField("Tên bộ", text: $name)
                Picker("Loại", selection: $type) {
                    Text("Chưa phân loại").tag(DeckType?.none)
                    ForEach(DeckType.allCases, id: \.self) { Text($0.label).tag(DeckType?.some($0)) }
                }
                TextField("Nguồn (≤ 40 ký tự)", text: $source)
                TextField("Mô tả (có thể chứa link)", text: $desc, axis: .vertical).lineLimit(2...5)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Huỷ", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu") { save() }.keyboardShortcut(.defaultAction).disabled(busy || name.trimmed.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            name = deck.name
            type = deck.type
            source = deck.source ?? ""
            desc = deck.description ?? ""
        }
    }

    private func save() {
        busy = true
        let patch = DeckPatch(
            name: name.trimmed,
            type: type.map { .set($0) } ?? .clear,
            source: source.trimmed.isEmpty ? .clear : .set(source.trimmed),
            description: desc.trimmed.isEmpty ? .clear : .set(desc.trimmed))
        Task {
            do {
                try await model.updateDeck(id: deck.id, patch: patch)
                dismiss()
            } catch {
                self.error = LibraryView.message(error)
                busy = false
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
