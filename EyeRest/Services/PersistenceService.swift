import Foundation
final class PersistenceService {
    private let defaults: UserDefaults
    private let preferencesKey = "EyeRest.preferences.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func loadPreferences() -> AppPreferences {
        guard let data = defaults.data(forKey: preferencesKey) else { return .makeDefault() }
        do {
            var preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
            if preferences.schemaVersion < AppPreferences.currentSchemaVersion {
                preferences.schemaVersion = AppPreferences.currentSchemaVersion
                preferences.hasCompletedWelcome = true
                save(preferences)
            }
            return preferences
        }
        catch {
            defaults.set(data, forKey: preferencesKey + ".corrupt")
            var preferences = AppPreferences.makeDefault()
            preferences.hasCompletedWelcome = true
            return preferences
        }
    }
    func save(_ value: AppPreferences) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: preferencesKey)
    }
}
