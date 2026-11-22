import Foundation

final class MedicineStore {
    static let maximumLogEntries = 20_000

    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = applicationSupport.appendingPathComponent("EyeRest", isDirectory: true)
                .appendingPathComponent("medicine-v1.json")
        }
    }

    func load() -> MedicineData {
        guard fileManager.fileExists(atPath: fileURL.path) else { return MedicineData() }
        do {
            var data = try JSONDecoder().decode(MedicineData.self, from: Data(contentsOf: fileURL))
            let originalCount = data.log.count
            prune(&data)
            if data.schemaVersion != MedicineData.currentSchemaVersion || data.log.count != originalCount {
                data.schemaVersion = MedicineData.currentSchemaVersion
                try? save(data)
            }
            return data
        } catch {
            if let bytes = try? Data(contentsOf: fileURL) {
                try? bytes.write(to: fileURL.appendingPathExtension("corrupt"), options: .atomic)
            }
            let empty = MedicineData()
            try? save(empty)
            return empty
        }
    }

    func save(_ value: MedicineData) throws {
        var value = value
        value.schemaVersion = MedicineData.currentSchemaVersion
        prune(&value)
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: fileURL, options: .atomic)
    }

    private func prune(_ data: inout MedicineData) {
        guard data.log.count > Self.maximumLogEntries else { return }
        data.log = Array(data.log.sorted {
            if $0.markedAt == $1.markedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.markedAt < $1.markedAt
        }.suffix(Self.maximumLogEntries))
    }
}
