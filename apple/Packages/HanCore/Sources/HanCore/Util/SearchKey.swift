import Foundation

/// Khoá tìm kiếm không dấu: bỏ dấu tiếng Việt (kể cả đ/Đ), hạ chữ thường, gộp khoảng trắng.
public func searchKey(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
        .replacingOccurrences(of: "đ", with: "d")
        .split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

/// Lọc theo truy vấn không dấu: mọi từ trong truy vấn phải xuất hiện. Khớp ở đầu chuỗi xếp trước,
/// còn lại giữ nguyên thứ tự ban đầu. Truy vấn rỗng → giữ nguyên.
public func filterBySearch<T>(_ items: [T], query: String, key: (T) -> String) -> [T] {
    let terms = searchKey(query).split(separator: " ").map(String.init)
    guard !terms.isEmpty else { return items }
    let keyed = items.map { (item: $0, key: searchKey(key($0))) }
    let hits = keyed.filter { k in terms.allSatisfy { k.key.contains($0) } }
    let first = terms[0]
    return hits.filter { $0.key.hasPrefix(first) }.map(\.item) + hits.filter { !$0.key.hasPrefix(first) }.map(\.item)
}
