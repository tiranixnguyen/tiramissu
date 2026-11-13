import Foundation

/// Đồng hồ tiêm được: trả "bây giờ". Mặc định dùng giờ hệ thống; test truyền giờ cố định.
public typealias Clock = @Sendable () -> Date

/// Đồng hồ hệ thống.
public let systemClock: Clock = { Date() }

/// Ngày (theo lịch) dùng cho lịch ôn — tiêm `Calendar` để test không phụ thuộc múi giờ máy.
public struct DayCalendar: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Lịch Gregorian theo múi giờ cho trước (mặc định Việt Nam).
    public static func gregorian(timeZoneIdentifier: String = "Asia/Ho_Chi_Minh") -> DayCalendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return DayCalendar(calendar: cal)
    }

    /// 00:00 của ngày chứa `date`.
    public func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
}
