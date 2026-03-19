import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func set(_ value: Any?, for key: String) {
        defaults.set(value, forKey: key)
    }

    func string(for key: String) -> String? {
        defaults.string(forKey: key)
    }

    func bool(for key: String, defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    func integer(for key: String, defaultValue: Int) -> Int {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.integer(forKey: key)
    }

    func double(for key: String, defaultValue: Double) -> Double {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.double(forKey: key)
    }

    func dictionary(for key: String) -> [String: Any]? {
        defaults.dictionary(forKey: key)
    }

    func array(for key: String) -> [[String: Any]]? {
        defaults.array(forKey: key) as? [[String: Any]]
    }

    func object(for key: String) -> Any? {
        defaults.object(forKey: key)
    }

    func removeObject(for key: String) {
        defaults.removeObject(forKey: key)
    }

    func removeAll(withPrefix prefix: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
