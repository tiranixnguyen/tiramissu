import Foundation

/// Một lần bật/tắt ⭐/漢/📖 chờ gửi lên server. `changedAt` là lúc bấm — server lấy lần muộn nhất.
public struct FlagChange: Codable, Sendable, Hashable {
    public let cardId: String
    public let changedAt: Date
    public var marked: Bool?
    public var hanja: Bool?
    public var passage: Bool?

    public init(cardId: String, changedAt: Date, marked: Bool? = nil, hanja: Bool? = nil, passage: Bool? = nil) {
        self.cardId = cardId
        self.changedAt = changedAt
        self.marked = marked
        self.hanja = hanja
        self.passage = passage
    }
}
