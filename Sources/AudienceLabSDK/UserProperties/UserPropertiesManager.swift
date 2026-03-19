import CryptoKit
import Foundation

final class UserPropertiesManager {
    private let keyWhitelist = "AudienceLabSDK_UserProps_Whitelisted"
    private let keyBlacklist = "AudienceLabSDK_UserProps_Blacklisted"
    private let hashedBlacklistedKeys: Set<String> = ["email", "phone"]
    private let maxProps = 50
    private let maxKeyLength = 64
    private let maxValueLength = 256
    private let maxSerializedBytes = 2048

    private(set) var whitelisted: [String: String]
    private(set) var blacklisted: [String: String]

    init() {
        whitelisted = PersistenceManager.shared.dictionary(for: keyWhitelist) as? [String: String] ?? [:]
        blacklisted = PersistenceManager.shared.dictionary(for: keyBlacklist) as? [String: String] ?? [:]
    }

    func set(key: String, value: String, in set: AudienceLabUserPropertySet) -> Bool {
        let normalizedKey = normalizeKey(key, in: set)
        let normalizedValue = normalizeValue(value, key: normalizedKey, in: set)
        if set == .whitelisted && isReservedWhitelistedKey(normalizedKey) {
            Logger.debug("Reserved whitelisted key rejected: \(normalizedKey)")
            return false
        }
        guard validate(key: normalizedKey), validate(value: normalizedValue) else { return false }
        var target = set == .whitelisted ? whitelisted : blacklisted
        let isNew = target[normalizedKey] == nil
        if isNew && target.count >= maxProps {
            Logger.debug("User property set is full: \(maxProps)")
            return false
        }
        target[normalizedKey] = normalizedValue
        guard serializedSize(of: target) <= maxSerializedBytes else {
            Logger.debug("User property payload exceeds \(maxSerializedBytes) bytes")
            return false
        }
        if set == .whitelisted {
            whitelisted = target
        } else {
            blacklisted = target
        }
        persist()
        return true
    }

    func unset(key: String, from set: AudienceLabUserPropertySet) {
        let normalizedKey = normalizeKey(key, in: set)
        if set == .whitelisted && isReservedWhitelistedKey(normalizedKey) {
            Logger.debug("Reserved whitelisted key preserved: \(normalizedKey)")
            return
        }
        if set == .whitelisted {
            whitelisted.removeValue(forKey: normalizedKey)
        } else {
            blacklisted.removeValue(forKey: normalizedKey)
        }
        persist()
    }

    func clear(_ set: AudienceLabUserPropertySet) {
        if set == .whitelisted {
            whitelisted = whitelisted.filter { isReservedWhitelistedKey($0.key) }
        } else {
            blacklisted = [:]
        }
        persist()
    }

    func mergeServerWhitelistedProperties(_ props: [String: String]) {
        var merged = whitelisted
        for (key, value) in props where validate(key: key) && validate(value: value) {
            merged[key] = value
        }
        if merged.count > maxProps {
            let limitedEntries = merged
                .sorted(by: { $0.key < $1.key })
                .prefix(maxProps)
                .map { ($0.key, $0.value) }
            merged = Dictionary(uniqueKeysWithValues: limitedEntries)
        }
        while serializedSize(of: merged) > maxSerializedBytes, let first = merged.keys.sorted().last {
            merged.removeValue(forKey: first)
        }
        whitelisted = merged
        persist()
    }

    private func validate(key: String) -> Bool {
        !key.isEmpty && key.count <= maxKeyLength
    }

    private func validate(value: String) -> Bool {
        value.count <= maxValueLength
    }

    private func serializedSize(of properties: [String: String]) -> Int {
        let data = try? JSONSerialization.data(withJSONObject: properties, options: [])
        return data?.count ?? .max
    }

    private func persist() {
        PersistenceManager.shared.set(whitelisted, for: keyWhitelist)
        PersistenceManager.shared.set(blacklisted, for: keyBlacklist)
    }

    private func normalizeKey(_ key: String, in set: AudienceLabUserPropertySet) -> String {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if set == .blacklisted && requiresHashedBlacklistedValue(for: normalized) {
            return normalized.lowercased()
        }
        return normalized
    }

    private func normalizeValue(_ value: String, key: String, in set: AudienceLabUserPropertySet) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard set == .blacklisted, requiresHashedBlacklistedValue(for: key) else {
            return normalized
        }

        let prepared: String
        switch key.lowercased() {
        case "email":
            prepared = normalized.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case "phone":
            prepared = normalized.filter(\.isNumber)
        default:
            prepared = normalized
        }

        guard !prepared.isEmpty else {
            return prepared
        }

        if looksLikeSHA256(prepared) {
            return prepared.lowercased()
        }

        return sha256(prepared)
    }

    private func requiresHashedBlacklistedValue(for key: String) -> Bool {
        hashedBlacklistedKeys.contains(key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private func looksLikeSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }

    private func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func isReservedWhitelistedKey(_ key: String) -> Bool {
        key.hasPrefix("_")
    }
}
