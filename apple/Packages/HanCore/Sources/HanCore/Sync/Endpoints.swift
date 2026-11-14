import Foundation

/// Cập nhật một trường có thể xoá: giữ nguyên / đặt giá trị / xoá (`null`).
public enum FieldUpdate<Value: Sendable & Hashable>: Sendable, Hashable {
    case keep
    case set(Value)
    case clear
}

/// Body `POST /decks`.
public struct NewDeck: Sendable, Hashable {
    public var groupId: String
    public var name: String
    public var type: DeckType?
    public var source: String?
    public var description: String?
    public var words: [ImportedWord]

    public init(
        groupId: String, name: String, type: DeckType? = nil, source: String? = nil,
        description: String? = nil, words: [ImportedWord]
    ) {
        self.groupId = groupId
        self.name = name
        self.type = type
        self.source = source
        self.description = description
        self.words = words
    }
}

/// Body `PATCH /decks/:id` — trường `.keep` không gửi.
public struct DeckPatch: Sendable, Hashable {
    public var name: String?
    public var type: FieldUpdate<DeckType> = .keep
    public var source: FieldUpdate<String> = .keep
    public var description: FieldUpdate<String> = .keep

    public init(
        name: String? = nil, type: FieldUpdate<DeckType> = .keep, source: FieldUpdate<String> = .keep,
        description: FieldUpdate<String> = .keep
    ) {
        self.name = name
        self.type = type
        self.source = source
        self.description = description
    }
}

/// Body `PATCH /cards/:id`. `audio`: trường có mặt → đặt id (`nil` = gỡ file nghe); thiếu → giữ nguyên.
public struct CardEdit: Sendable, Hashable {
    public var front: String
    public var back: String
    public var hint: String?
    public var note: String?
    public var altAnswers: [String]
    public var typeAnswer: Bool
    public var audio: [CardField: String?]

    public init(
        front: String, back: String, hint: String? = nil, note: String? = nil, altAnswers: [String] = [],
        typeAnswer: Bool, audio: [CardField: String?] = [:]
    ) {
        self.front = front
        self.back = back
        self.hint = hint
        self.note = note
        self.altAnswers = altAnswers
        self.typeAnswer = typeAnswer
        self.audio = audio
    }
}

public struct FlagResult: Codable, Sendable, Hashable {
    public let applied: Int
    public let ignored: Int
}

public struct SessionsResult: Codable, Sendable, Hashable {
    public let received: Int
    public let inserted: Int
    public let unknownDeck: Int
}

public struct AudioUpload: Codable, Sendable, Hashable {
    public let id: String
    public let size: Int
}

/// Giao diện API cho `SyncEngine`/AppModel — test cài bản giả.
public protocol ContentAPI: Sendable {
    func health() async throws
    func content() async throws -> ContentSnapshot
    func createGroup(name: String) async throws -> ContentGroup
    func renameGroup(id: String, name: String) async throws -> ContentGroup
    func createDeck(_ deck: NewDeck) async throws -> ContentDeck
    func updateDeck(id: String, patch: DeckPatch) async throws -> ContentDeck
    func appendCards(deckId: String, words: [ImportedWord]) async throws -> ContentDeck
    func updateCard(id: String, edit: CardEdit) async throws -> ContentCard
    func deleteCard(id: String) async throws
    func sendFlags(_ changes: [FlagChange]) async throws -> FlagResult
    func sendSessions(_ sessions: [StudySessionRecord]) async throws -> SessionsResult
    func sessions() async throws -> [StudySessionRecord]
    func uploadAudio(_ bytes: Data, contentType: String) async throws -> AudioUpload
    func downloadAudio(id: String) async throws -> Data
    func createClip(_ clip: NewClip) async throws -> Clip
    func updateClip(id: String, patch: ClipPatch) async throws -> Clip
    func deleteClip(id: String) async throws
}
