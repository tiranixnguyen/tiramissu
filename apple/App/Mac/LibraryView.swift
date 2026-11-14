import DesignSystem
import HanCore
import SwiftUI

/// Màn Thư viện: nhóm → bộ → bảng thẻ. Sửa/thêm/xoá cần mạng; lỗi thì giữ nguyên chữ đang sửa.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(\.theme) private var theme

    @State private var deckId: String?
    @State private var search = ""
    @State private var selection: Set<String> = []
    @State private var editing: CellID?
    @State private var draft = ""
    @State private var showAddCard = false
    @State private var showEditDeck = false
    @State private var pendingDelete: [String] = []
    @State private var error: String?

    struct CellID: Equatable {
        enum Field { case front, back }
        var card: String
        var field: Field
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
        .searchable(text: $search, placement: .toolbar, prompt: "Tìm bộ, từ Hàn hoặc nghĩa…")
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
                        Button { deckId = d.id; selection = [] } label: { deckRow(d) }.buttonStyle(.plain)
                    }
                    if decks.isEmpty {
                        Text("Chưa có bộ nào.").font(.callout).foregroundStyle(ink2).padding(.top, 20)
                    }
                }
            }
        }
    }

    private func deckRow(_ d: ContentDeck) -> some View {
        let selected = d.id == deckId
        return VStack(alignment: .leading, spacing: 6) {
            Text(d.name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
            HStack(spacing: 6) {
                if let t = d.type {
                    Text(t.label).font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill((theme?.accent ?? .accentColor).opacity(0.14)))
                }
                Text("\(d.cards.count) thẻ · \(model.reviewStatus(deckId: d.id).shortLabel)")
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
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name).font(.system(size: 22, weight: .bold))
                        Text(subtitle(deck)).font(.system(size: 12)).foregroundStyle(ink2)
                    }
                    Spacer()
                    Button("Sửa bộ…") { showEditDeck = true }
                    Button { showAddCard = true } label: { Label("Thêm thẻ", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command)
                    Button("Học bộ này ↵") {
                        model.switchDeck(deck.id)
                        nav.screen = .study
                    }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
                table(deck)
                Text("Bấm đúp một ô để sửa ngay trong bảng · ⌫ xoá thẻ đang chọn")
                    .font(.system(size: 12)).foregroundStyle(ink2).padding(.horizontal, 20).padding(.vertical, 8)
            } else {
                ContentUnavailableView("Chọn một bộ", systemImage: "books.vertical")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme?.line ?? .clear)))
    }

    private func subtitle(_ d: ContentDeck) -> String {
        var parts: [String] = []
        if let s = d.source, !s.isEmpty { parts.append("Nguồn: \(s)") }
        if let desc = d.description, !desc.isEmpty { parts.append(desc) }
        parts.append(model.reviewStatus(deckId: d.id).shortLabel)
        return parts.joined(separator: " · ")
    }

    private func table(_ deck: ContentDeck) -> some View {
        Table(deck.cards.sorted { $0.position < $1.position }, selection: $selection) {
            TableColumn("Mặt trước") { c in cell(c, .front) }
            TableColumn("Mặt sau") { c in cell(c, .back) }
            TableColumn("Kiểu") { c in
                Text((c.typeAnswer ? "Gõ đáp án" : "Tự chấm") + (c.passage ? " · đoạn văn" : "")).font(.system(size: 12)).foregroundStyle(ink2)
            }
            .width(min: 90, ideal: 120)
            TableColumn("Cờ") { c in
                Text((c.marked ? "★" : "") + (c.hanja ? "漢" : "") + (c.passage ? "📖" : ""))
            }
            .width(60)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if !ids.isEmpty {
                Button("Xoá \(ids.count) thẻ", role: .destructive) { pendingDelete = Array(ids) }
            }
        }
        .onDeleteCommand { if !selection.isEmpty { pendingDelete = Array(selection) } }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private func cell(_ c: ContentCard, _ field: CellID.Field) -> some View {
        let id = CellID(card: c.id, field: field)
        let text = field == .front ? c.front : c.back
        if editing == id {
            TextField("", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit(c, field) }
                .onExitCommand { editing = nil }
        } else {
            Text(text)
                .font(field == .back ? .system(size: 14, weight: .medium) : .system(size: 14))
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

    private var ink2: Color { theme?.ink2 ?? .secondary }
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
