import Foundation

/// Khoảng cách ôn lại (ngày) sau mỗi lần học tốt liên tiếp.
public let reviewIntervalsDays = [1, 3, 7, 14, 30, 60]

/// Tỉ lệ đúng tối thiểu để một lần học được tính là "tốt".
public let goodAccuracy = 0.8

public enum ReviewState: Sendable, Hashable {
    /// Chưa từng học hết bộ này.
    case neverStudied
    /// Tới hạn hôm nay hoặc đã quá hạn.
    case due
    /// Chưa tới hạn.
    case upcoming
}

public struct ReviewStatus: Sendable, Hashable {
    public var state: ReviewState
    /// Ngày nên ôn (00:00 giờ địa phương).
    public var dueDay: Date?
    /// Âm = quá hạn bao nhiêu ngày, 0 = hôm nay, dương = còn bao nhiêu ngày.
    public var daysUntilDue: Int
    /// Lần học gần nhất (kể cả lần học dở).
    public var lastStudiedAt: Date?
    /// Số lần học tốt liên tiếp đang được tính — bậc trong `reviewIntervalsDays`.
    public var level: Int

    public init(
        state: ReviewState, dueDay: Date? = nil, daysUntilDue: Int = 0, lastStudiedAt: Date? = nil,
        level: Int = 0
    ) {
        self.state = state
        self.dueDay = dueDay
        self.daysUntilDue = daysUntilDue
        self.lastStudiedAt = lastStudiedAt
        self.level = level
    }

    /// Nhãn ngắn gắn sau tên bộ trong danh sách chọn bộ.
    public var shortLabel: String {
        switch state {
        case .neverStudied: "chưa học"
        case .due where daysUntilDue < 0: "quá hạn \(-daysUntilDue) ngày"
        case .due: "nên ôn hôm nay"
        case .upcoming where daysUntilDue == 1: "ôn lại ngày mai"
        case .upcoming: "ôn lại sau \(daysUntilDue) ngày"
        }
    }
}

/// Gợi ý ôn lại một bộ từ lịch sử các lần học của nó (mọi máy gộp chung).
///
/// - Chỉ lần học **hết bộ** mới ảnh hưởng lịch; học dở chỉ ghi vào lịch sử.
/// - Hết bộ, tỉ lệ đúng ≥ 80%, đúng hoặc sau ngày hẹn: lên một bậc (1 → 3 → 7 → 14 → 30 → 60 ngày).
/// - Ôn **trước** ngày hẹn mà vẫn tốt: giữ nguyên bậc và ngày hẹn (học dồn không làm giãn lịch).
/// - Tỉ lệ đúng < 80%: về bậc đầu, hẹn ngày mai.
///
/// So theo ngày lịch của `calendar`, không theo giờ.
public func computeReviewStatus(
    _ sessionsOfDeck: some Sequence<StudySessionRecord>, now: Date,
    calendar: DayCalendar = .gregorian()
) -> ReviewStatus {
    let cal = calendar.calendar
    let sorted = sessionsOfDeck.sorted { $0.endedAt < $1.endedAt }
    let lastStudiedAt = sorted.last?.endedAt

    var level = 0
    var dueDay: Date?
    for s in sorted where s.completed {
        let day = calendar.startOfDay(s.endedAt)
        if s.accuracy < goodAccuracy {
            level = 0
            dueDay = cal.date(byAdding: .day, value: 1, to: day)
        } else if dueDay == nil || day >= dueDay! {
            level = min(max(level + 1, 1), reviewIntervalsDays.count)
            dueDay = cal.date(byAdding: .day, value: reviewIntervalsDays[level - 1], to: day)
        }
    }

    guard let dueDay else {
        return ReviewStatus(state: .neverStudied, lastStudiedAt: lastStudiedAt)
    }
    let daysUntil = cal.dateComponents([.day], from: calendar.startOfDay(now), to: dueDay).day ?? 0
    return ReviewStatus(
        state: daysUntil <= 0 ? .due : .upcoming, dueDay: dueDay, daysUntilDue: daysUntil,
        lastStudiedAt: lastStudiedAt, level: level)
}
