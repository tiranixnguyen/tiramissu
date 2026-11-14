import AppKit
import DesignSystem
import HanCore
import SwiftUI

/// Màn Nhập từ AI: chép prompt → dán JSON → xem trước → tạo bộ (`POST /decks`, cần mạng).
struct ImportView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(\.theme) private var theme

    @State private var kind: PromptKind = .vocab
    @State private var tool: AITool = .gemini
    @State private var copied = false
    @State private var json = ""
    @State private var name = ""
    @State private var groupId = ""
    @State private var busy = false
    @State private var error: String?
    @State private var createdName: String?

    private var parsed: DeckImport { parseDeckImport(json) }
    private var groups: [ContentGroup] { model.content.groups.sorted { $0.position < $1.position } }
    private var known: Set<String> { model.content.allKorean }
    private var canCreate: Bool {
        parsed.ok && !busy && !name.trimmed.isEmpty && groups.contains { $0.id == groupId }
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 1000 {
                // Rộng: ba cột như prototype.
                HStack(alignment: .top, spacing: 10) { steps(tall: false) }
                    .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
            } else {
                // Hẹp: xếp dọc, cuộn được — mỗi bước đủ rộng để đọc.
                ScrollView {
                    VStack(spacing: 10) { steps(tall: true) }
                        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
                }
            }
        }
        .onAppear { if groupId.isEmpty { groupId = groups.first?.id ?? "" } }
        .onChange(of: json) { if name.isEmpty || name == lastAutoName { name = parsed.name ?? ""; lastAutoName = name } }
    }

    @State private var lastAutoName = ""

    @ViewBuilder private func steps(tall: Bool) -> some View {
        step(1, "Chép prompt", tall: tall) { promptStep }
        step(2, "Dán kết quả", tall: tall) { pasteStep }
        step(3, "Xem trước & tạo bộ", tall: tall) { previewStep }
    }

    // MARK: Bước 1

    private var promptStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 6) {
                ForEach(PromptKind.allCases, id: \.self) { k in
                    Button(label(k)) { kind = k; copied = false }
                        .buttonStyle(.bordered).tint(k == kind ? theme?.accent : nil)
                        .controlSize(.small)
                }
            }
            Picker("Công cụ", selection: $tool) {
                Text("Gemini").tag(AITool.gemini)
                Text("NotebookLM").tag(AITool.notebookLM)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            ScrollView {
                Text(Prompts.text(kind: kind, tool: tool))
                    .font(.system(size: 12, design: .monospaced)).lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill((theme?.ink ?? .primary).opacity(0.05)))
            Button { copyPrompt() } label: {
                Text(copied ? "Đã chép ✓" : "Chép prompt  ⇧⌘C").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.large)
            .keyboardShortcut("c", modifiers: [.command, .shift])
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

    // MARK: Bước 2

    private var pasteStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $json)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(theme?.surface ?? .clear)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1.5)))
            Text(status).font(.system(size: 13, weight: .semibold)).foregroundStyle(statusColor)
            if !json.isEmpty && !parsed.errors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(parsed.errors, id: \.self) { Text("• \($0)").font(.system(size: 12)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 90).foregroundStyle(theme?.bad ?? .red)
            }
        }
    }

    private var borderColor: Color {
        if json.trimmed.isEmpty { return theme?.line ?? .gray }
        return parsed.ok ? (theme?.ok ?? .green) : (theme?.bad ?? .red)
    }

    private var status: String {
        if json.trimmed.isEmpty { return "Dán JSON từ AI vào ô trên (⌘V)." }
        if parsed.ok { return "✓ Hợp lệ — \(parsed.words.count) thẻ (\(parsed.typeAnswerCount) gõ đáp án)" }
        return "✗ Chưa hợp lệ"
    }

    private var statusColor: Color {
        json.trimmed.isEmpty ? (theme?.ink2 ?? .secondary) : (parsed.ok ? (theme?.ok ?? .green) : (theme?.bad ?? .red))
    }

    // MARK: Bước 3

    private var previewStep: some View {
        let dupSet = Set(parsed.duplicatesOf(known))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tên bộ").font(.system(size: 12)).foregroundStyle(ink2)
                    TextField("Tên bộ", text: $name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nhóm").font(.system(size: 12)).foregroundStyle(ink2)
                    Picker("Nhóm", selection: $groupId) {
                        ForEach(groups) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                }
            }
            List(Array(parsed.words.enumerated()), id: \.offset) { _, w in
                HStack(spacing: 10) {
                    Text(w.front).frame(maxWidth: .infinity, alignment: .leading)
                    Text(w.back).font(.system(size: 13, weight: .semibold))
                    if dupSet.contains(w.back.trimmed) {
                        Text("Trùng").font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill((theme?.flag ?? .orange).opacity(0.2)))
                    }
                }
                .font(.system(size: 13))
            }
            .listStyle(.plain)
            .overlay { if parsed.words.isEmpty { Text("Chưa có thẻ nào").foregroundStyle(ink2) } }
            if groups.isEmpty {
                Text("Chưa có nhóm nào — tạo nhóm trước (hoặc đồng bộ với server).").font(.callout).foregroundStyle(theme?.bad ?? .red)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(theme?.bad ?? .red) }
            if let createdName {
                Label("Đã tạo “\(createdName)”.", systemImage: "checkmark.circle").font(.callout).foregroundStyle(theme?.ok ?? .green)
            }
            Button { create() } label: {
                Text(busy ? "Đang tạo…" : "Tạo bộ  ⌘↵").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canCreate)
        }
    }

    private func create() {
        busy = true
        error = nil
        let new = NewDeck(
            groupId: groupId, name: name.trimmed, type: deckTypeForKind, words: parsed.words)
        Task {
            do {
                let deck = try await model.createDeck(new)
                createdName = deck.name
                json = ""
                name = ""
                lastAutoName = ""
            } catch {
                self.error = (error as? APIError)?.message ?? error.localizedDescription  // giữ nguyên JSON
            }
            busy = false
        }
    }

    // MARK: Chung

    private var ink2: Color { theme?.ink2 ?? .secondary }

    private func step<C: View>(_ n: Int, _ title: String, tall: Bool, @ViewBuilder _ body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(n)").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme?.onAccent ?? .white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(theme?.accent ?? .accentColor))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            body()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: tall ? 420 : nil, maxHeight: tall ? nil : .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme?.line ?? .clear)))
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
