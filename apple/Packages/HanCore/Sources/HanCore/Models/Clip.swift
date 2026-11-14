import Foundation

/// Một clip nghe cắt từ file âm thanh dài (`GET /content` → `clips`). Âm thanh nằm ở `/audio/:audioId`.
public struct Clip: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public var audioId: String
    public var sourceName: String
    public var startMs: Int
    public var endMs: Int
    /// Câu Hàn — đáp án khi chép chính tả.
    public var transcript: String
    public var translation: String?
    public var note: String?
    /// Bộ mà clip thuộc về (nếu có); clip nào cũng nằm trong bộ ảo 🎧.
    public var deckId: String?
    public var marked: Bool
    public var createdAt: Date

    public init(
        id: String, audioId: String, sourceName: String = "", startMs: Int, endMs: Int, transcript: String,
        translation: String? = nil, note: String? = nil, deckId: String? = nil, marked: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.audioId = audioId
        self.sourceName = sourceName
        self.startMs = startMs
        self.endMs = endMs
        self.transcript = transcript
        self.translation = translation
        self.note = note
        self.deckId = deckId
        self.marked = marked
        self.createdAt = createdAt
    }

    public var durationMs: Int { endMs - startMs }

    private enum CodingKeys: String, CodingKey {
        case id, audioId, sourceName, startMs, endMs, transcript, translation, note, deckId, marked, createdAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        audioId = try c.decode(String.self, forKey: .audioId)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName) ?? ""
        startMs = try c.decode(Int.self, forKey: .startMs)
        endMs = try c.decode(Int.self, forKey: .endMs)
        transcript = try c.decode(String.self, forKey: .transcript)
        translation = try c.decodeIfPresent(String.self, forKey: .translation)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        deckId = try c.decodeIfPresent(String.self, forKey: .deckId)
        marked = try c.decodeIfPresent(Bool.self, forKey: .marked) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

/// Body `POST /clips`.
public struct NewClip: Sendable, Hashable {
    public var audioId: String
    public var sourceName: String
    public var startMs: Int
    public var endMs: Int
    public var transcript: String
    public var translation: String?
    public var note: String?
    public var deckId: String?

    public init(
        audioId: String, sourceName: String, startMs: Int, endMs: Int, transcript: String,
        translation: String? = nil, note: String? = nil, deckId: String? = nil
    ) {
        self.audioId = audioId
        self.sourceName = sourceName
        self.startMs = startMs
        self.endMs = endMs
        self.transcript = transcript
        self.translation = translation
        self.note = note
        self.deckId = deckId
    }
}

/// Body `PATCH /clips/:id` — trường `.keep` không gửi.
public struct ClipPatch: Sendable, Hashable {
    public var startMs: Int?
    public var endMs: Int?
    public var transcript: String?
    public var translation: FieldUpdate<String> = .keep
    public var note: FieldUpdate<String> = .keep
    public var deckId: FieldUpdate<String> = .keep
    public var marked: Bool?

    public init(
        startMs: Int? = nil, endMs: Int? = nil, transcript: String? = nil,
        translation: FieldUpdate<String> = .keep, note: FieldUpdate<String> = .keep,
        deckId: FieldUpdate<String> = .keep, marked: Bool? = nil
    ) {
        self.startMs = startMs
        self.endMs = endMs
        self.transcript = transcript
        self.translation = translation
        self.note = note
        self.deckId = deckId
        self.marked = marked
    }
}

// MARK: Chép chính tả — so từng từ

/// Kết quả so một từ giữa câu đã chép và câu đúng.
public struct WordDiff: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        /// Từ đúng (text = từ trong câu đúng).
        case correct
        /// Gõ sai từ này: `text` = từ đã gõ, `expected` = từ đúng.
        case wrong(expected: String)
        /// Thiếu từ (text = từ đúng bị bỏ sót).
        case missing
        /// Thừa từ (text = từ đã gõ mà câu đúng không có).
        case extra
    }

    public let text: String
    public let kind: Kind

    public init(_ text: String, _ kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

extension AnswerMatcher {
    /// So từng từ (đã chuẩn hoá NFC + gộp khoảng trắng) bằng chuỗi con chung dài nhất. Đoạn khác nhau mà
    /// cả hai bên đều có từ thì ghép đôi theo thứ tự thành `.wrong`; phần dư là `.missing` / `.extra`.
    public static func wordDiff(answer: String, target: String) -> [WordDiff] {
        let a = normalize(answer).split(separator: " ").map(String.init)
        let t = normalize(target).split(separator: " ").map(String.init)

        // LCS
        var table = Array(repeating: Array(repeating: 0, count: t.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: t.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == t[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }

        var result: [WordDiff] = []
        var i = 0, j = 0
        var gapA: [String] = [], gapT: [String] = []
        func flush() {
            let pairs = min(gapA.count, gapT.count)
            for k in 0..<pairs { result.append(WordDiff(gapA[k], .wrong(expected: gapT[k]))) }
            for w in gapT.dropFirst(pairs) { result.append(WordDiff(w, .missing)) }
            for w in gapA.dropFirst(pairs) { result.append(WordDiff(w, .extra)) }
            gapA = []
            gapT = []
        }
        while i < a.count || j < t.count {
            if i < a.count, j < t.count, a[i] == t[j] {
                flush()
                result.append(WordDiff(t[j], .correct))
                i += 1
                j += 1
            } else if j < t.count, i == a.count || table[i][j + 1] >= table[i + 1][j] {
                gapT.append(t[j])
                j += 1
            } else {
                gapA.append(a[i])
                i += 1
            }
        }
        flush()
        return result
    }
}
