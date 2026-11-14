import DesignSystem
import HanCore
import SwiftUI

/// Màn Hôm nay: vòng tiến độ, bộ cần ôn, clip hôm nay (rỗng tới G3), heatmap 14 ngày.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var nav
    @Environment(\.theme) private var theme

    private var plan: TodayPlan {
        computeTodayPlan(decks: model.content.decks, history: model.history, now: Date())
    }

    /// Độ rộng vùng nội dung — để chia cột 1.35 : 1 ở bản vừa.
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        let plan = plan
        Group {
            switch nav.widthClass {
            case .wide: wideLayout(plan)
            case .medium: mediumLayout(plan)
            case .narrow: narrowLayout(plan)
            }
        }
        .screenTopBar {
            TopBarTitle(main: dayTitle, detail: plan.streakDays > 0 ? "chuỗi \(plan.streakDays) ngày" : nil)
        } actions: {
            PaletteButton()
        }
    }

    // MARK: Bố cục theo độ rộng cửa sổ

    /// ≥ 1100 pt: hai cột — (tóm tắt + bộ cần ôn) | (clip + 14 ngày).
    private func wideLayout(_ plan: TodayPlan) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                summary(plan)
                dueList(plan, scrolls: true)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 10) {
                clips
                heatmap(plan)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
    }

    /// 900–1100 pt: tóm tắt trải ngang; dưới là bộ cần ôn : (clip + 14 ngày) = 1.35 : 1.
    private func mediumLayout(_ plan: TodayPlan) -> some View {
        let spacing: CGFloat = 10
        let leftWidth = max(0, (contentWidth - spacing) * 1.35 / 2.35)
        return VStack(spacing: spacing) {
            summary(plan)
            HStack(alignment: .top, spacing: spacing) {
                dueList(plan, scrolls: true).frame(width: leftWidth)
                VStack(spacing: spacing) {
                    clips
                    heatmap(plan)
                }
                .frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
    }

    /// < 900 pt: một cột cuộn dọc — tóm tắt → bộ cần ôn → (clip · 14 ngày).
    private func narrowLayout(_ plan: TodayPlan) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                summary(plan)
                dueList(plan, scrolls: false)
                HStack(alignment: .top, spacing: 10) {
                    clips
                    heatmap(plan, fills: false)
                }
            }
            .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
        }
    }

    // MARK: Tóm tắt

    /// "Thứ Sáu, 13/11".
    private var dayTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEEE, dd/MM"
        return f.string(from: Date()).capitalized
    }

    private func summary(_ plan: TodayPlan) -> some View {
        card {
            HStack(spacing: 18) {
                ProgressRing(value: plan.progress, lineWidth: 10).frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Đến hạn ôn hôm nay").font(.system(size: 13)).foregroundStyle(ink2)
                    Text("\(plan.dueDecks.count) bộ · \(plan.dueCardCount) thẻ")
                        .font(.system(size: 26, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(plan.dueDecks.isEmpty
                        ? "Hôm nay không còn gì để ôn 🎉"
                        : "Ước tính \(plan.estimatedMinutes) phút · đã xong \(plan.doneTodayCount)/\(plan.doneTodayCount + plan.dueDecks.count)")
                        .font(.system(size: 13)).foregroundStyle(ink2).lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 8)
                if let first = plan.firstDue {
                    Button { open(first.id) } label: {
                        HStack(spacing: 8) {
                            Text("Bắt đầu ôn").fontWeight(.semibold)
                            Text("↵").font(.system(size: 11, design: .monospaced)).opacity(0.8)
                        }
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
    }

    // MARK: Bộ cần ôn

    /// `scrolls == false` (bản hẹp): liệt kê thẳng, để `ScrollView` ngoài cuộn — không lồng hai lớp cuộn.
    private func dueList(_ plan: TodayPlan, scrolls: Bool) -> some View {
        card(padding: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Bộ cần ôn").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 8)
                if plan.dueDecks.isEmpty {
                    Text("Chưa có bộ nào đến hạn.").font(.callout).foregroundStyle(ink2).padding(10)
                } else if scrolls {
                    ScrollView { dueRows(plan) }
                } else {
                    dueRows(plan)
                }
                if scrolls { Spacer(minLength: 0) }
            }
        }
        .frame(maxHeight: scrolls ? .infinity : nil)
    }

    private func dueRows(_ plan: TodayPlan) -> some View {
        VStack(spacing: 0) {
            ForEach(plan.dueDecks) { d in
                Button { open(d.id) } label: { row(d) }.buttonStyle(.plain)
            }
        }
    }

    private func row(_ d: DueDeck) -> some View {
        HStack(spacing: 12) {
            Text(d.type?.label ?? "·")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill((theme?.accent ?? .accentColor).opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(meta(d)).font(.system(size: 12)).foregroundStyle(ink2).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(dueLabel(d)).font(.system(size: 12, weight: .semibold)).foregroundStyle(dueColor(d))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func meta(_ d: DueDeck) -> String {
        var parts = ["\(d.cardCount) thẻ"]
        if d.status.level > 0 { parts.append("bậc \(d.status.level) (\(reviewIntervalsDays[d.status.level - 1]) ngày)") }
        if let a = d.lastAccuracy { parts.append("lần trước \(Int((a * 100).rounded()))%") }
        if d.status.state == .neverStudied { parts.append("chưa học") }
        return parts.joined(separator: " · ")
    }

    private func dueLabel(_ d: DueDeck) -> String {
        switch d.status.state {
        case .neverStudied: "Mới"
        case .due where d.status.daysUntilDue < 0: "Trễ \(-d.status.daysUntilDue) ngày"
        default: "Hôm nay"
        }
    }

    private func dueColor(_ d: DueDeck) -> Color {
        switch d.status.state {
        case .neverStudied: theme?.ok ?? .green
        case .due where d.status.daysUntilDue < 0: theme?.bad ?? .red
        default: theme?.accent ?? .accentColor
        }
    }

    // MARK: Cột phải

    private var clips: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clip nghe hôm nay").font(.system(size: 14, weight: .semibold))
                if model.content.clips.isEmpty {
                    Text("Chưa có clip — cắt ở màn “Cắt clip âm thanh”.").font(.callout).foregroundStyle(ink2)
                } else {
                    ForEach(model.content.clips.prefix(3)) { clip in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clip.translation ?? "🎧 Nghe và chép lại").font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(String(format: "%.1fs · %@", Double(clip.durationMs) / 1000, clip.sourceName))
                                .font(.caption).foregroundStyle(ink2).lineLimit(1)
                        }
                    }
                    Button { open(clipsDeckId) } label: {
                        Text("Luyện \(model.content.clips.count) clip").fontWeight(.semibold)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    /// `fills == false` (bản hẹp, trong ScrollView): cao vừa nội dung thay vì giãn hết chiều cao.
    private func heatmap(_ plan: TodayPlan, fills: Bool = true) -> some View {
        let peak = max(plan.heat.map(\.attempted).max() ?? 0, 1)
        return card {
            VStack(alignment: .leading, spacing: 10) {
                Text("14 ngày qua").font(.system(size: 14, weight: .semibold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(plan.heat, id: \.day) { h in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(h.attempted == 0
                                ? (theme?.line ?? .gray.opacity(0.3))
                                : (theme?.accent ?? .accentColor).opacity(0.25 + 0.75 * Double(h.attempted) / Double(peak)))
                            .aspectRatio(1, contentMode: .fit)
                            .help("\(h.day.formatted(.dateTime.day().month())): \(h.attempted) thẻ")
                    }
                }
                if fills { Spacer(minLength: 0) }
            }
        }
        .frame(maxHeight: fills ? .infinity : nil)
    }

    // MARK: Chung

    private var ink2: Color { theme?.ink2 ?? .secondary }

    private func open(_ deckId: String) {
        model.switchDeck(deckId)
        nav.screen = .study
    }

    private func card<C: View>(padding: CGFloat = 16, @ViewBuilder _ body: () -> C) -> some View {
        body()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(theme?.surface ?? .clear)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme?.line ?? .clear)))
    }
}
