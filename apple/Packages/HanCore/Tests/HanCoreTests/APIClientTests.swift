import Foundation
import Testing

@testable import HanCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Stub mạng: mỗi test dùng một host riêng nên chạy song song không lẫn.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    struct Reply {
        var status = 200
        var body = Data()
        var error: URLError?
    }
    nonisolated(unsafe) static var handlers: [String: @Sendable (URLRequest) -> Reply] = [:]
    nonisolated(unsafe) static var seen: [String: [URLRequest]] = [:]
    static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        Self.lock.lock()
        let handler = Self.handlers[host]
        var req = request
        if req.httpBody == nil, let stream = req.httpBodyStream {
            stream.open()
            var data = Data()
            var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                data.append(buf, count: n)
            }
            stream.close()
            req.httpBody = data
        }
        Self.seen[host, default: []].append(req)
        Self.lock.unlock()

        let reply = handler?(req) ?? Reply(status: 500)
        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeAPI(
    _ host: String, token: String? = "tok", _ handler: @escaping @Sendable (URLRequest) -> StubProtocol.Reply
) -> URLSessionContentAPI {
    StubProtocol.lock.lock()
    StubProtocol.handlers[host] = handler
    StubProtocol.seen[host] = []
    StubProtocol.lock.unlock()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    return URLSessionContentAPI(
        baseURL: URL(string: "https://\(host)/api")!, session: URLSession(configuration: config),
        token: { token })
}

private func requests(_ host: String) -> [URLRequest] {
    StubProtocol.lock.lock()
    defer { StubProtocol.lock.unlock() }
    return StubProtocol.seen[host] ?? []
}

private func json(_ text: String, status: Int = 200) -> StubProtocol.Reply {
    .init(status: status, body: Data(text.utf8))
}

@Suite("APIClient")
struct APIClientTests {
    @Test func parseContentVaGuiBearerToken() async throws {
        let api = makeAPI("t1.test") { _ in
            json(
                #"{"groups":[{"id":"g1","name":"Sep1","position":0}],"decks":[{"id":"d1","groupId":"g1","name":"B","position":0,"cards":[]}]}"#
            )
        }
        let content = try await api.content()
        #expect(content.groups.count == 1)
        #expect(content.decks.first?.id == "d1")
        let req = try #require(requests("t1.test").first)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(req.url?.path == "/api/content")
    }

    @Test func healthKhongGuiToken() async throws {
        let api = makeAPI("t2.test") { _ in json("{}") }
        try await api.health()
        #expect(requests("t2.test").first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func status401LaUnauthorized() async {
        let api = makeAPI("t3.test") { _ in json(#"{"error":"Thiếu hoặc sai mã truy cập."}"#, status: 401) }
        await #expect(throws: APIError.unauthorized) { try await api.content() }
    }

    @Test func bodyHtmlLaDecoding() async {
        let api = makeAPI("t4.test") { _ in json("<html>proxy</html>") }
        await #expect(throws: APIError.decoding) { try await api.content() }
    }

    @Test func matMangLaOffline() async {
        let api = makeAPI("t5.test") { _ in .init(error: URLError(.notConnectedToInternet)) }
        await #expect(throws: APIError.offline) { try await api.content() }
    }

    @Test func loiServerDocThongBaoTuBody() async {
        let api = makeAPI("t6.test") { _ in json(#"{"error":"Tên bộ không được trống."}"#, status: 400) }
        await #expect(throws: APIError.server("Tên bộ không được trống.")) {
            try await api.createGroup(name: "")
        }
    }

    @Test func loiServerKhongCoBodyJsonVanLaServer() async {
        let api = makeAPI("t7.test") { _ in json("oops", status: 502) }
        await #expect(throws: APIError.server("Máy chủ trả lỗi (HTTP 502).")) { try await api.content() }
    }

    @Test func guiCoBangBodyDungDinhDang() async throws {
        let api = makeAPI("t8.test") { _ in json(#"{"applied":1,"ignored":0}"#) }
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let result = try await api.sendFlags([FlagChange(cardId: "c1", changedAt: at, marked: true)])
        #expect(result == FlagResult(applied: 1, ignored: 0))
        let req = try #require(requests("t8.test").first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/api/cards/flags")
        let body = try #require(req.httpBody)
        let obj = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let change = try #require((obj["changes"] as? [[String: Any]])?.first)
        #expect(change["cardId"] as? String == "c1")
        #expect(change["marked"] as? Bool == true)
        #expect(change["changedAt"] as? String == "2023-11-14T22:13:20.000Z")
        #expect(change["hanja"] == nil)
    }

    @Test func suaBoChiGuiTruongCoVaClearLaNull() async throws {
        let api = makeAPI("t9.test") { _ in
            json(#"{"id":"d1","groupId":"g1","name":"Mới","position":0,"cards":[]}"#)
        }
        _ = try await api.updateDeck(id: "d1", patch: DeckPatch(name: "Mới", type: .set(.reading), source: .clear))
        let req = try #require(requests("t9.test").first)
        #expect(req.httpMethod == "PATCH")
        let obj = try #require(try JSONSerialization.jsonObject(with: req.httpBody!) as? [String: Any])
        #expect(obj["name"] as? String == "Mới")
        #expect(obj["type"] as? String == "reading")
        #expect(obj["source"] is NSNull)
        #expect(obj["description"] == nil)
    }

    @Test func uploadAudioGuiBytesThoKemContentType() async throws {
        let api = makeAPI("t10.test") { _ in json(#"{"id":"a1","size":3}"#) }
        let up = try await api.uploadAudio(Data([1, 2, 3]), contentType: "audio/mpeg")
        #expect(up == AudioUpload(id: "a1", size: 3))
        let req = try #require(requests("t10.test").first)
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "audio/mpeg")
        #expect(req.httpBody == Data([1, 2, 3]))
    }

    @Test func layLichSuHoc() async throws {
        let api = makeAPI("t11.test") { _ in
            json(
                #"{"sessions":[{"id":"s1","deckId":"d1","device":"ios","startedAt":"2026-09-01T10:00:00.000Z","endedAt":"2026-09-01T10:10:00.000Z","attempted":4,"correct":3,"masteredCount":2,"totalCards":2,"completed":true}]}"#
            )
        }
        let s = try await api.sessions()
        #expect(s.count == 1)
        #expect(s[0].completed)
    }

    @Test func xoaTheTra204VanThanhCong() async throws {
        let api = makeAPI("t12.test") { _ in .init(status: 204) }
        try await api.deleteCard(id: "c1")
        #expect(requests("t12.test").first?.httpMethod == "DELETE")
    }
}
