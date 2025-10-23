import Foundation

public final class AppGroupManager {
    public static let shared = AppGroupManager()

    public let appGroupID = "group.com.DaraConsultingInc.LGTVRemoteWidget"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    public func set<T: Codable>(_ value: T?, forKey key: String) {
        guard let defaults else { return }
        if let value {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(value) {
                defaults.set(data, forKey: key)
            }
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }

    public func setString(_ value: String?, forKey key: String) {
        guard let defaults else { return }
        defaults.set(value, forKey: key)
    }

    public func getString(forKey key: String) -> String? {
        guard let defaults else { return nil }
        return defaults.string(forKey: key)
    }
}
