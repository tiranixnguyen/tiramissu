import Foundation
import HanCore
import Observation

/// Cấu hình server: URL (UserDefaults) + token (Keychain).
@MainActor @Observable
final class ServerSettings {
    nonisolated private static let urlKey = "tiramissu.serverURL"
    nonisolated private static let tokenAccount = "apiToken"

    var urlText: String
    var token: String

    init() {
        urlText = UserDefaults.standard.string(forKey: Self.urlKey) ?? ""
        token = Keychain.read(Self.tokenAccount) ?? ""
    }

    /// URL hợp lệ (http/https, có host) hoặc `nil`.
    var baseURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil
        else { return nil }
        return url
    }

    /// Lưu cấu hình hiện tại. Trả `false` nếu Keychain không ghi được token.
    @discardableResult
    func save() -> Bool {
        UserDefaults.standard.set(urlText.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.urlKey)
        return Keychain.write(Self.tokenAccount, token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Đọc token mới nhất từ Keychain (closure cho `URLSessionContentAPI`).
    nonisolated static func currentToken() -> String? { Keychain.read(tokenAccount) }

    /// Kiểm tra kết nối: `/health` rồi `/content` (cần token). Trả thông báo tiếng Việt.
    func test() async -> Result<String, APIError> {
        guard let url = baseURL else { return .failure(.server("URL không hợp lệ (cần dạng https://…).")) }
        let token = self.token.trimmingCharacters(in: .whitespacesAndNewlines)
        let api = URLSessionContentAPI(baseURL: url, token: { token })
        do {
            try await api.health()
            let content = try await api.content()
            let cards = content.decks.reduce(0) { $0 + $1.cards.count }
            return .success("Kết nối tốt: \(content.groups.count) nhóm · \(content.decks.count) bộ · \(cards) thẻ.")
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.offline)
        }
    }
}
