import Foundation

protocol InstallInstanceIDProviding {
    func loadOrCreate() throws -> String
}

final class InstallInstanceStore: InstallInstanceIDProviding {
    private let fileManager: FileManager
    private let customDirectoryURL: URL?
    private let lock = NSLock()

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.customDirectoryURL = directoryURL
    }

    func loadOrCreate() throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try excludeFromBackup(directoryURL)

        let fileURL = directoryURL.appendingPathComponent("install-instance-id", isDirectory: false)
        if let existing = try? String(contentsOf: fileURL, encoding: .utf8),
           let identifier = normalizedIdentifier(existing) {
            try excludeFromBackup(fileURL)
            return identifier
        }

        let identifier = UUID().uuidString.lowercased()
        try Data(identifier.utf8).write(to: fileURL, options: .atomic)
        try excludeFromBackup(fileURL)
        return identifier
    }

    private func storageDirectoryURL() throws -> URL {
        if let customDirectoryURL {
            return customDirectoryURL
        }

        return try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ai.audiencelab.sdk", isDirectory: true)
    }

    private func normalizedIdentifier(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: normalized) else { return nil }
        return uuid.uuidString.lowercased()
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
