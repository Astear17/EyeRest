import Foundation
final class PersistenceService {
    private let defaults: UserDefaults
    private let preferencesKey = "EyeRest.preferences.v1", completionKey = "EyeRest.completions.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func loadPreferences() -> AppPreferences {
        guard let data = defaults.data(forKey: preferencesKey) else { return .makeDefault() }
        do { return try JSONDecoder().decode(AppPreferences.self, from: data) }
        catch {
            defaults.set(data, forKey: preferencesKey + ".corrupt")
            return .makeDefault()
        }
    }
    func save(_ value: AppPreferences) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: preferencesKey)
    }
    func loadCompletions() -> [Completion] {
        guard let data = defaults.data(forKey: completionKey) else { return [] }
        do { return try JSONDecoder().decode([LossyCompletion].self, from: data).compactMap(\.value) }
        catch {
            defaults.set(data, forKey: completionKey + ".corrupt")
            return []
        }
    }
    func save(completions: [Completion]) {
        guard let data = try? JSONEncoder().encode(Array(completions.suffix(500))) else { return }
        defaults.set(data, forKey: completionKey)
    }

    private struct LossyCompletion: Decodable {
        let value: Completion?
        init(from decoder: Decoder) throws { value = try? Completion(from: decoder) }
    }
}
