import Foundation

/// Mặt sau tối đa bấy nhiêu từ thì coi là "ngắn".
public let shortAnswerMaxWords = 3

/// Mặc định của SERVER khi request không ghi `typeAnswer`: đáp án ngắn (≤ 3 từ) thì gõ đáp án,
/// dài hơn là thẻ tự chấm. Phải giống `defaultTypeAnswer` bên backend (`wordInput.ts`).
/// App luôn gửi rõ `typeAnswer` (xem `parseDeckImport`) nên chỉ fixture test cần tới.
public func defaultTypeAnswer(_ back: String) -> Bool {
    back.split(whereSeparator: \.isWhitespace).count <= shortAnswerMaxWords
}

/// Một từ hợp lệ, đúng định dạng gửi lên server. Mỗi từ một thẻ.
public struct ImportedWord: Sendable, Hashable, Codable {
    public var front: String
    public var back: String
    /// Luôn có sẵn: ghi rõ trong JSON thì giữ, không thì `true` (thẻ gõ đáp án).
    public var typeAnswer: Bool
    public var hint: String?
    /// Markdown, giữ nguyên thụt lề/xuống dòng (server tự dọn hai đầu).
    public var note: String?
    public var altAnswers: [String]?

    public init(
        front: String, back: String, typeAnswer: Bool = true, hint: String? = nil,
        note: String? = nil, altAnswers: [String]? = nil
    ) {
        self.front = front
        self.back = back
        self.typeAnswer = typeAnswer
        self.hint = hint
        self.note = note
        self.altAnswers = altAnswers
    }
}

/// Kết quả đọc JSON người dùng dán vào.
public struct DeckImport: Sendable, Hashable {
    /// Tên bộ nếu JSON có trường `name`.
    public var name: String?
    public var words: [ImportedWord]
    /// Có lỗi thì không cho gửi, tránh tạo bộ thiếu từ.
    public var errors: [String]

    public init(name: String? = nil, words: [ImportedWord] = [], errors: [String] = []) {
        self.name = name
        self.words = words
        self.errors = errors
    }

    public var ok: Bool { errors.isEmpty && !words.isEmpty }

    /// Số thẻ gõ đáp án (còn lại là thẻ tự chấm).
    public var typeAnswerCount: Int { words.filter(\.typeAnswer).count }

    /// Mặt sau đã có trong `known` (cảnh báo trùng, không chặn).
    public func duplicatesOf(_ known: Set<String>) -> [String] {
        words.map(\.back).filter { known.contains($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

/// JSON tối thiểu để kiểm kiểu chặt như Dart (`is bool`, `is String`…).
private enum JSONValue: Decodable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
}

private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

/// Chuỗi không rỗng sau khi trim, ngược lại `nil`.
private func str(_ v: JSONValue?) -> String? {
    if case .string(let s)? = v, !trimmed(s).isEmpty { return trimmed(s) }
    return nil
}

/// Giải thích là Markdown: giữ nguyên thụt lề/xuống dòng — trim sẽ phá khối code thụt lề ở dòng đầu.
private func note(_ v: JSONValue?) -> String? {
    if case .string(let s)? = v, !trimmed(s).isEmpty { return s }
    return nil
}

private func isPresent(_ v: JSONValue?) -> Bool {
    if let v, case .null = v { return false }
    return v != nil
}

/// Đọc JSON dạng `{"name": ..., "words": [...]}` hoặc chỉ mảng `[...]`.
/// Chấp nhận cả khi còn bọc trong khối ```json … ``` như AI hay trả về.
public func parseDeckImport(_ text: String) -> DeckImport {
    var raw = trimmed(text)
    if let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)```"),
        let m = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
        let r = Range(m.range(at: 1), in: raw)
    {
        raw = trimmed(String(raw[r]))
    }
    if raw.isEmpty { return DeckImport() }

    let json: JSONValue
    do {
        json = try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
    } catch {
        return DeckImport(errors: ["JSON không hợp lệ: \(describe(error))"])
    }

    var name: String?
    var list: JSONValue?
    if case .object(let o) = json {
        name = str(o["name"])
        list = o["words"]
    } else {
        list = json
    }
    guard case .array(let items)? = list else {
        return DeckImport(name: name, errors: ["Cần một mảng từ, hoặc object có trường \"words\"."])
    }
    if items.count > 500 {
        return DeckImport(name: name, errors: ["Tối đa 500 từ mỗi lần."])
    }

    var errors: [String] = []
    var words: [ImportedWord] = []
    for (i, item) in items.enumerated() {
        let label = "Từ thứ \(i + 1)"
        guard case .object(let w) = item else {
            errors.append("\(label): không phải object.")
            continue
        }
        guard let front = str(w["front"]), let back = str(w["back"]) else {
            errors.append("\(label): thiếu \"front\" hoặc \"back\".")
            continue
        }
        var typeAnswer = true
        if case .bool(let b)? = w["typeAnswer"] { typeAnswer = b }
        var out = ImportedWord(front: front, back: back, typeAnswer: typeAnswer)
        out.hint = str(w["hint"])
        out.note = note(w["note"])
        if case .array(let alts)? = w["altAnswers"] {
            let clean = alts.compactMap { str($0) }
            if !clean.isEmpty { out.altAnswers = clean }
        }
        // Thẻ ngữ cảnh đã bỏ: báo lỗi thay vì lặng lẽ vứt mất (server cũng vậy).
        if isPresent(w["followUp"]) || isPresent(w["followUps"]) {
            errors.append("\(label): không còn hỗ trợ \"followUp\"/\"followUps\" — tách thành từ riêng.")
            continue
        }
        words.append(out)
    }
    return DeckImport(name: name, words: words, errors: errors)
}

private func describe(_ error: Error) -> String {
    if let e = error as? DecodingError, case .dataCorrupted(let ctx) = e {
        return ctx.debugDescription
    }
    return error.localizedDescription
}
