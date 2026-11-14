import DesignSystem
import HanCore
import SwiftUI

/// Hôm nay (iPhone) — theo artboard "iPhone · Hôm nay": thẻ đến hạn + "Bắt đầu ôn", bộ cần ôn,
/// ô clip / từ khó nhớ, cột 7 ngày qua. Cùng `computeTodayPlan` với bản Mac.
struct PhoneTodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PhoneNav.self) private var nav
    @Environment(\.theme) private var theme

    private var plan: TodayPlan {
        computeTodayPlan(decks: model.content.decks, history: model.history, now: Date())
    }

    var body: some View {
        let plan = plan
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(plan)
                summary(plan)
                dueSection(plan)
                tiles
                week(plan)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
        }
        .background(theme?.bg ?? .clear)
        .refreshable { await model.syncNow() }
    }

    // MARK: Đầu trang

    private func header(_ plan: TodayPlan) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle).font(.system(size: 13, weight: .medium)).foregroundStyle(ink2)
                Text("Hôm nay").font(.system(size: 30, weight: .bold)).kerning(-0.6).foregroundStyle(ink)
            }
            Spacer(minLength: 8)
            if plan.streakDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame").foregroundStyle(theme?.flag ?? .orange)
                    Text("\(plan.streakDays) ngày").foregroundStyle(ink)
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(surface).overlay(Capsule().stroke(line)))
                .accessibilityLabel("Chuỗi \(plan.streakDays) ngày")
            }
        }
    }

    /// "Thứ Sáu, 13/11".
    private var dayTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEEE, dd/MM"
        return f.string(from: Date()).capitalized
    }

    // MARK: Đến hạn ôn

    /// Thẻ nền `ink`, chữ `bg` — đảo màu để nổi bật như artboard (tối thì thành thẻ sáng).
    private func summary(_ plan: TodayPlan) -> some View {
        let fg = theme?.bg ?? .white
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Đến hạn ôn").font(.system(size: 13)).foregroundStyle(fg.opacity(0.7))
                    Text(plan.dueDecks.isEmpty ? "Đã xong 🎉" : "\(plan.dueDecks.count) bộ · \(plan.dueCardCount) thẻ")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(fg)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                ring(plan.progress, track: fg.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .accessibilityLabel("Đã xong \(Int((plan.progress * 100).rounded())) phần trăm")
            }
            if let first = plan.firstDue {
                Button { open(first.id) } label: {
                    HStack(spacing: 8) {
                        Text("Bắt đầu ôn")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(ink)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(surface))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Text("Hôm nay không còn bộ nào đến hạn.").font(.system(size: 14)).foregroundStyle(fg.opacity(0.7))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22).fill(ink))
    }

    private func ring(_ value: Double, track: Color) -> some View {
        ZStack {
            Circle().stroke(track, lineWidth: 7)
            Circle().trim(from: 0, to: min(max(value, 0), 1))
                .stroke(theme?.accent ?? .accentColor, style: .init(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(3.5)
    }

    // MARK: Bộ cần ôn

    private func dueSection(_ plan: TodayPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bộ cần ôn").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
            if plan.dueDecks.isEmpty {
                Text("Chưa có bộ nào đến hạn.").font(.system(size: 14)).foregroundStyle(ink2)
            }
            ForEach(plan.dueDecks) { d in
                Button { open(d.id) } label: { dueRow(d) }.buttonStyle(.plain)
            }
        }
    }

    private func dueRow(_ d: DueDeck) -> some View {
        HStack(spacing: 12) {
            Text(d.type?.label ?? "·")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill((theme?.accent ?? .accentColor).opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(d.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                Text(meta(d)).font(.system(size: 12)).foregroundStyle(ink2).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(dueLabel(d)).font(.system(size: 12, weight: .semibold)).foregroundStyle(dueColor(d))
                .lineLimit(1).fixedSize()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(surface).overlay(RoundedRectangle(cornerRadius: 16).stroke(line)))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private func meta(_ d: DueDeck) -> String {
        var parts = ["\(d.cardCount) thẻ"]
        if d.status.level > 0 { parts.append("bậc \(d.status.level) (\(reviewIntervalsDays[d.status.level - 1]) ngày)") }
        if let a = d.lastAccuracy { parts.append("lần trước \(Int((a * 100).rounded()))% đúng") }
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

    // MARK: Clip · Từ khó nhớ

    private var tiles: some View {
        HStack(spacing: 10) {
            Button { nav.tab = .listen } label: {
                tile("headphones", "\(model.content.clips.count) clip", "Luyện nghe hôm nay", tint: theme?.ok ?? .green)
            }
            .buttonStyle(.plain)
            Button { open(markedDeckId) } label: {
                tile("star", "\(model.state.markedCount) thẻ", "Từ khó nhớ", tint: theme?.flag ?? .orange)
            }
            .buttonStyle(.plain)
            .disabled(model.state.markedCount == 0)
        }
    }

    private func tile(_ icon: String, _ value: String, _ caption: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium))
            Text(value).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 13, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(tint.opacity(0.13)))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 7 ngày qua

    private func week(_ plan: TodayPlan) -> some View {
        let days = Array(plan.heat.suffix(7))
        let peak = max(days.map(\.attempted).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("7 ngày qua").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
            HStack(alignment: .bottom) {
                ForEach(days, id: \.day) { h in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(h.attempted == 0 ? line : (theme?.accent ?? .accentColor)
                                .opacity(0.35 + 0.65 * Double(h.attempted) / Double(peak)))
                            .frame(width: 22, height: max(6, 40 * CGFloat(h.attempted) / CGFloat(peak)))
                        Text(weekday(h.day)).font(.system(size: 11)).foregroundStyle(ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(weekday(h.day)): \(h.attempted) thẻ")
                }
            }
            .frame(height: 56, alignment: .bottom)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(surface).overlay(RoundedRectangle(cornerRadius: 16).stroke(line)))
        }
    }

    /// "T2" … "T7", "CN".
    private func weekday(_ day: Date) -> String {
        let w = Calendar(identifier: .gregorian).component(.weekday, from: day)  // 1 = Chủ nhật
        return w == 1 ? "CN" : "T\(w)"
    }

    // MARK: Chung

    private var ink: Color { theme?.ink ?? .primary }
    private var ink2: Color { theme?.ink2 ?? .secondary }
    private var line: Color { theme?.line ?? .gray }
    private var surface: Color { theme?.surface ?? .clear }

    private func open(_ deckId: String) {
        model.switchDeck(deckId)
        nav.tab = .study
    }
}
