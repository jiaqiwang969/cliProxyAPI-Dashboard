import Foundation
import Security

struct APIKeyEntry: Identifiable, Equatable {
    let id: String
    let masked: String
}

enum APIKeyStoreError: LocalizedError {
    case configNotFound
    case keyAlreadyExists
    case emptyKey

    var errorDescription: String? {
        switch self {
        case .configNotFound:
            return "未找到 config.yaml"
        case .keyAlreadyExists:
            return "该 Key 已存在"
        case .emptyKey:
            return "Key 不能为空"
        }
    }
}

enum APIKeyStore {
    static func loadEntries(configPath: String?) throws -> [APIKeyEntry] {
        let keys = try loadKeys(configPath: configPath)
        return keys.map { value in
            APIKeyEntry(id: value, masked: mask(value))
        }
    }

    static func addKey(configPath: String?, rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw APIKeyStoreError.emptyKey
        }

        var keys = try loadKeys(configPath: configPath)
        guard !keys.contains(key) else {
            throw APIKeyStoreError.keyAlreadyExists
        }
        keys.append(key)
        try saveKeys(keys, configPath: configPath)
    }

    static func removeKey(configPath: String?, keyToRemove: String) throws {
        var keys = try loadKeys(configPath: configPath)
        keys.removeAll { $0 == keyToRemove }
        try saveKeys(keys, configPath: configPath)
    }

    static func generateKey() -> String {
        let alphabet = Array("0123456789abcdef")
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        let suffix = bytes.flatMap { byte -> [Character] in
            let high = Int(byte >> 4)
            let low = Int(byte & 0x0f)
            return [alphabet[high], alphabet[low]]
        }

        return "sk-" + String(suffix)
    }

    private static func loadKeys(configPath: String?) throws -> [String] {
        guard let configPath else {
            throw APIKeyStoreError.configNotFound
        }
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw APIKeyStoreError.configNotFound
        }

        let raw = try String(contentsOfFile: configPath, encoding: .utf8)
        let lines = raw.components(separatedBy: .newlines)

        guard let block = apiKeysBlock(in: lines) else {
            return []
        }

        return lines[block.start + 1 ..< block.end]
            .compactMap(parseKeyLine)
    }

    private static func saveKeys(_ keys: [String], configPath: String?) throws {
        guard let configPath else {
            throw APIKeyStoreError.configNotFound
        }

        let raw = try String(contentsOfFile: configPath, encoding: .utf8)
        var lines = raw.components(separatedBy: .newlines)
        let blockLines = ["api-keys:"] + keys.map { "  - \"\($0)\"" }

        if let block = apiKeysBlock(in: lines) {
            lines.replaceSubrange(block.start ..< block.end, with: blockLines)
        } else {
            if let last = lines.last, !last.isEmpty {
                lines.append("")
            }
            lines.append(contentsOf: blockLines)
        }

        let updated = lines.joined(separator: "\n")
        try updated.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    private static func apiKeysBlock(in lines: [String]) -> (start: Int, end: Int)? {
        var start: Int?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if start == nil {
                if trimmed == "api-keys:" {
                    start = index
                }
                continue
            }

            if line.hasPrefix(" ") || line.hasPrefix("\t") || trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            return (start: start!, end: index)
        }

        if let start {
            return (start: start, end: lines.count)
        }

        return nil
    }

    private static func parseKeyLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else {
            return nil
        }

        let rawValue = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        let unquoted = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return unquoted.isEmpty ? nil : unquoted
    }

    private static func mask(_ value: String) -> String {
        if value.count <= 14 {
            return value
        }
        return "\(value.prefix(7))...\(value.suffix(4))"
    }
}
