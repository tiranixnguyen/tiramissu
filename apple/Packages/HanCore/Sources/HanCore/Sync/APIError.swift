/// Mọi lỗi gọi API đều quy về đây (kể cả lỗi giải mã) — UI/SyncEngine chỉ cần bắt một kiểu.
public enum APIError: Error, Sendable, Hashable {
    /// Không có mạng / không tới được máy chủ / quá thời gian.
    case offline
    /// 401 — thiếu hoặc sai mã truy cập.
    case unauthorized
    /// Máy chủ trả lỗi; chuỗi là `error` trong body (tiếng Việt) hoặc mô tả HTTP.
    case server(String)
    /// Phản hồi 2xx nhưng không đọc được (vd. trang HTML của proxy).
    case decoding

    /// Thông báo hiển thị cho người dùng.
    public var message: String {
        switch self {
        case .offline: "Không có kết nối tới máy chủ."
        case .unauthorized: "Thiếu hoặc sai mã truy cập."
        case .server(let m): m
        case .decoding: "Phản hồi từ máy chủ không đọc được."
        }
    }
}
