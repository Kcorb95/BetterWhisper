import Foundation

@Observable
final class HistoryStore {
    private(set) var records: [TranscriptionRecord] = []

    private let maxRecords = 100
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let historyFileURL: URL
    private let saveQueue = DispatchQueue(label: "com.betterwhisper.history.save")

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("BetterWhisper", isDirectory: true)
        self.historyFileURL = appDir.appendingPathComponent("history.json")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureDirectoryExists()
        records = loadFromDisk()
    }

    // MARK: - Public Methods

    /// Save a new transcription record. Auto-prunes to keep the last 100.
    func save(record: TranscriptionRecord) {
        records.insert(record, at: 0)
        pruneIfNeeded()
        saveToDisk()
    }

    /// Load all records (already loaded at init, but can force-reload).
    func loadAll() -> [TranscriptionRecord] {
        records = loadFromDisk()
        return records
    }

    /// Delete a record by ID.
    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        saveToDisk()
    }

    /// Clear all history.
    func clear() {
        records.removeAll()
        saveToDisk()
    }

    /// Search records by text content.
    func search(query: String) -> [TranscriptionRecord] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return records
        }
        let lowercased = query.lowercased()
        return records.filter { record in
            record.rawText.lowercased().contains(lowercased) ||
            (record.processedText?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() {
        let dir = historyFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func loadFromDisk() -> [TranscriptionRecord] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try decoder.decode([TranscriptionRecord].self, from: data)
            return loaded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("HistoryStore: Failed to load history: \(error)")
            return []
        }
    }

    private func saveToDisk() {
        let snapshot = records
        let url = historyFileURL
        saveQueue.async { [encoder] in
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: url.path
                )
            } catch {
                print("HistoryStore: Failed to save history: \(error)")
            }
        }
    }

    private func pruneIfNeeded() {
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
    }
}
