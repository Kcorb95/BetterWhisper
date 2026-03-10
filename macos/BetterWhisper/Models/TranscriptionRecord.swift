import Foundation

struct TranscriptionRecord: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let rawText: String
    let processedText: String?
    let mode: String
    let createdAt: Date
    let duration: Double

    init(
        id: UUID = UUID(),
        rawText: String,
        processedText: String? = nil,
        mode: String,
        createdAt: Date = Date(),
        duration: Double
    ) {
        self.id = id
        self.rawText = rawText
        self.processedText = processedText
        self.mode = mode
        self.createdAt = createdAt
        self.duration = duration
    }

    /// The best available text: processed if available, otherwise raw.
    var displayText: String {
        processedText ?? rawText
    }

    /// A short preview of the display text, truncated to the given length.
    func preview(maxLength: Int = 100) -> String {
        let text = displayText
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        if firstLine.count <= maxLength {
            return firstLine
        }
        return String(firstLine.prefix(maxLength)) + "..."
    }

    /// Formatted duration string (e.g. "2.3s").
    var formattedDuration: String {
        String(format: "%.1fs", duration)
    }

    // MARK: - Date Formatting

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    /// Formatted date string for display.
    var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(createdAt) {
            return Self.timeFormatter.string(from: createdAt)
        } else if calendar.isDateInYesterday(createdAt) {
            return "Yesterday, " + Self.timeFormatter.string(from: createdAt)
        } else {
            return Self.dateTimeFormatter.string(from: createdAt)
        }
    }
}
