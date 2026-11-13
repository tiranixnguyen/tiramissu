import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Client HTTP của backend (`docs/architecture.md` §4). Chỉ ném `APIError`.
/// Token lấy qua closure (app đọc từ Keychain) để đổi token không cần dựng lại client.
public struct URLSessionContentAPI: ContentAPI {
    private let baseURL: URL
    private let session: URLSession
    private let token: @Sendable () -> String?

    public init(baseURL: URL, session: URLSession = .shared, token: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.token = token
    }

    // MARK: ContentAPI

    public func health() async throws {
        _ = try await send("GET", "health", auth: false)
    }

    public func content() async throws -> ContentSnapshot {
        try decode(try await send("GET", "content"))
    }

    public func createGroup(name: String) async throws -> ContentGroup {
        try decode(try await send("POST", "groups", json: ["name": name]))
    }

    public func renameGroup(id: String, name: String) async throws -> ContentGroup {
        try decode(try await send("PATCH", "groups/\(id)", json: ["name": name]))
    }

    public func createDeck(_ deck: NewDeck) async throws -> ContentDeck {
        var body: [String: Any] = ["groupId": deck.groupId, "name": deck.name, "words": try wordsJSON(deck.words)]
        if let t = deck.type { body["type"] = t.rawValue }
        if let s = deck.source { body["source"] = s }
        if let d = deck.description { body["description"] = d }
        return try decode(try await send("POST", "decks", json: body))
    }

    public func updateDeck(id: String, patch: DeckPatch) async throws -> ContentDeck {
        var body: [String: Any] = [:]
        if let n = patch.name { body["name"] = n }
        apply(patch.type.map(\.rawValue), to: &body, key: "type")
        apply(patch.source, to: &body, key: "source")
        apply(patch.description, to: &body, key: "description")
        return try decode(try await send("PATCH", "decks/\(id)", json: body))
    }

    public func appendCards(deckId: String, words: [ImportedWord]) async throws -> ContentDeck {
        try decode(try await send("POST", "decks/\(deckId)/cards", json: ["words": try wordsJSON(words)]))
    }

    public func updateCard(id: String, edit: CardEdit) async throws -> ContentCard {
        var body: [String: Any] = [
            "front": edit.front, "back": edit.back, "altAnswers": edit.altAnswers,
            "typeAnswer": edit.typeAnswer,
            "hint": edit.hint as Any? ?? NSNull(), "note": edit.note as Any? ?? NSNull(),
        ]
        for (field, value) in edit.audio { body[field.rawValue] = value ?? NSNull() }
        return try decode(try await send("PATCH", "cards/\(id)", json: body))
    }

    public func deleteCard(id: String) async throws {
        _ = try await send("DELETE", "cards/\(id)")
    }

    public func sendFlags(_ changes: [FlagChange]) async throws -> FlagResult {
        try decode(try await send("POST", "cards/flags", body: try encode(["changes": changes])))
    }

    public func sendSessions(_ sessions: [StudySessionRecord]) async throws -> SessionsResult {
        try decode(try await send("POST", "sessions", body: try encode(["sessions": sessions])))
    }

    public func sessions() async throws -> [StudySessionRecord] {
        struct Reply: Decodable { let sessions: [StudySessionRecord] }
        return try decode(try await send("GET", "sessions"), as: Reply.self).sessions
    }

    public func uploadAudio(_ bytes: Data, contentType: String) async throws -> AudioUpload {
        try decode(try await send("POST", "audio", body: bytes, contentType: contentType))
    }

    public func downloadAudio(id: String) async throws -> Data {
        try await send("GET", "audio/\(id)")
    }

    // MARK: Hạ tầng

    private func send(
        _ method: String, _ path: String, json: [String: Any]? = nil, body: Data? = nil,
        contentType: String = "application/json", auth: Bool = true
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 30
        if auth, let token = token(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let json {
            guard let data = try? JSONSerialization.data(withJSONObject: json) else { throw APIError.decoding }
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        default:
            struct Failure: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error
            throw APIError.server(message ?? "Máy chủ trả lỗi (HTTP \(http.statusCode)).")
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type = T.self) throws -> T {
        do { return try HanJSON.makeDecoder().decode(T.self, from: data) } catch { throw APIError.decoding }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try HanJSON.makeEncoder().encode(value) } catch { throw APIError.decoding }
    }

    private func wordsJSON(_ words: [ImportedWord]) throws -> Any {
        do { return try JSONSerialization.jsonObject(with: HanJSON.makeEncoder().encode(words)) } catch {
            throw APIError.decoding
        }
    }

    private func apply<T>(_ update: FieldUpdate<T>, to body: inout [String: Any], key: String) {
        switch update {
        case .keep: break
        case .set(let v): body[key] = v
        case .clear: body[key] = NSNull()
        }
    }
}

extension FieldUpdate {
    func map<T: Sendable & Hashable>(_ transform: (Value) -> T) -> FieldUpdate<T> {
        switch self {
        case .keep: .keep
        case .set(let v): .set(transform(v))
        case .clear: .clear
        }
    }
}
