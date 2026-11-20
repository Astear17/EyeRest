import Foundation
final class PersistenceService {
    private let defaults: UserDefaults
    private let preferencesKey = "EyeRest.preferences.v1", completionKey = "EyeRest.completions.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func loadPreferences() -> AppPreferences { guard let data = defaults.data(forKey: preferencesKey), let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return .makeDefault() }; return value }
    func save(_ value: AppPreferences) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: preferencesKey)
    }
    func loadCompletions() -> [Completion] { guard let data = defaults.data(forKey: completionKey), let value = try? JSONDecoder().decode([Completion].self, from: data) else { return [] }; return value }
    func save(completions: [Completion]) {
        guard let data = try? JSONEncoder().encode(Array(completions.suffix(500))) else { return }
        defaults.set(data, forKey: completionKey)
    }
}
