import Foundation

/// Lỗi nhập theme — `message` là tiếng Việt, nêu rõ khoá/giá trị sai.
public struct ThemeError: Error, Hashable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

/// Đọc / kiểm / ghi theme người dùng (Application Support/Themes).
public enum ThemeLibrary {
    static let paletteKeys = ["bg", "surface", "ink", "ink2", "accent", "line", "onAccent", "ok", "bad", "flag"]
    static let typographyKeys = ["cardKoreanFont", "uiFont", "cardScale"]

    /// Thư mục mặc định của app: `~/Library/Application Support/Tiramissu/Themes`.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Tiramissu").appending(path: "Themes")
    }

    /// Kiểm và giải mã một file theme. `existingIDs` = id đã có (built-in + đã nhập): trùng thì đổi id
    /// thêm hậu tố `-2`, `-3`… (và tên thêm ` (2)`…).
    public static func parse(_ data: Data, existingIDs: Set<String> = []) throws -> Theme {
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: data) } catch {
            throw ThemeError("File không phải JSON hợp lệ.")
        }
        guard let root = object as? [String: Any] else { throw ThemeError("Theme phải là một object JSON.") }

        try requireKeys(["id", "name", "light", "dark", "typography"], in: root, where: "theme")
        try requireKeys(typographyKeys, in: root["typography"] as? [String: Any], where: "typography")
        for mode in ["light", "dark"] {
            let palette = root[mode] as? [String: Any]
            try requireKeys(paletteKeys, in: palette, where: mode)
            for key in paletteKeys {
                let value = palette?[key] as? String ?? ""
                guard RGB(hex: value) != nil, value.hasPrefix("#") else {
                    throw ThemeError("\(mode).\(key) phải là mã màu dạng #RRGGBB (đang là \"\(value)\").")
                }
            }
        }

        // Cho phép thiếu các trường phụ: điền mặc định trước khi giải mã.
        var filled = root
        filled["schemaVersion"] = filled["schemaVersion"] ?? 1
        filled["description"] = filled["description"] ?? ""
        filled["useSystemAccent"] = filled["useSystemAccent"] ?? false

        var theme: Theme
        do {
            theme = try JSONDecoder().decode(Theme.self, from: JSONSerialization.data(withJSONObject: filled))
        } catch {
            throw ThemeError("Theme sai định dạng: \(error.localizedDescription)")
        }
        guard !theme.id.trimmingCharacters(in: .whitespaces).isEmpty else { throw ThemeError("Khoá id không được trống.") }

        if existingIDs.contains(theme.id) {
            let base = theme.id
            var n = 2
            while existingIDs.contains("\(base)-\(n)") { n += 1 }
            theme.id = "\(base)-\(n)"
            theme.name = "\(theme.name) (\(n))"
        }
        return theme
    }

    /// Xuất theme ra JSON dễ đọc để sửa tay.
    public static func export(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(theme)
    }

    /// Nhập file theme: kiểm, đổi id nếu trùng, ghi vào `directory/<id>.json`.
    @discardableResult
    public static func install(
        _ data: Data, into directory: URL = defaultDirectory(), existingIDs: Set<String>
    ) throws -> Theme {
        let theme = try parse(data, existingIDs: existingIDs)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try export(theme).write(to: directory.appending(path: "\(theme.id).json"), options: .atomic)
        return theme
    }

    /// Đọc mọi theme người dùng; file hỏng được bỏ qua và trả kèm lỗi (tên file → lý do).
    public static func loadUserThemes(
        from directory: URL = defaultDirectory(), builtInIDs: Set<String> = Set(ThemeCatalog.builtInIDs)
    ) -> (themes: [Theme], errors: [String: ThemeError]) {
        let files =
            (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        var themes: [Theme] = []
        var errors: [String: ThemeError] = [:]
        var taken = builtInIDs
        for file in files {
            do {
                let theme = try parse(Data(contentsOf: file), existingIDs: taken)
                taken.insert(theme.id)
                themes.append(theme)
            } catch let error as ThemeError {
                errors[file.lastPathComponent] = error
            } catch {
                errors[file.lastPathComponent] = ThemeError("Không đọc được file.")
            }
        }
        return (themes, errors)
    }

    private static func requireKeys(_ keys: [String], in dict: [String: Any]?, where place: String) throws {
        guard let dict else { throw ThemeError("Thiếu khoá \"\(place)\".") }
        let missing = keys.filter { dict[$0] == nil }
        if !missing.isEmpty {
            let list = missing.map { place == "theme" ? $0 : "\(place).\($0)" }.joined(separator: ", ")
            throw ThemeError("Thiếu khoá: \(list).")
        }
    }
}
