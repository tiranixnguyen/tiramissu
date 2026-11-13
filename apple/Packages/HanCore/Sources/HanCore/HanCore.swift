import Foundation

/// Điểm vào của package. Các module con sẽ được thêm theo `docs/tasks.md` (GĐ2):
/// `Models/`, `Study/`, `Review/`, `Import/`, `Sync/`, `Util/` — xem `docs/architecture.md`.
public enum HanCore {
    /// Phiên bản định dạng dữ liệu `GET /content` mà package hiểu.
    public static let contentFormatVersion = 1
}

/// Chuẩn hoá câu trả lời trước khi so: Unicode NFC, bỏ khoảng trắng hai đầu, gộp khoảng trắng giữa.
/// Bản Dart gốc: `StudyEngine.normalize` (`reference/flutter/domain/study_engine.dart`) — bản Swift
/// thêm bước NFC vì bàn phím Hàn trên macOS/iOS có thể sinh Jamo tách rời (NFD).
public enum AnswerMatcher {
    public static func normalize(_ input: String) -> String {
        input.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
