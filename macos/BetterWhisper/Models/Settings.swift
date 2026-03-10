import Foundation
import SwiftUI

// MARK: - Processing Mode

enum ProcessingMode: String, CaseIterable, Codable, Identifiable {
    case raw = "raw"
    case clean = "clean"
    case format = "format"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .clean: return "Clean"
        case .format: return "Format"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .raw: return "No AI processing"
        case .clean: return "Fix grammar and filler words"
        case .format: return "Rewrite as structured prose"
        case .custom: return "Your own AI prompt"
        }
    }

    var longDescription: String {
        switch self {
        case .raw:
            return "The transcription is returned exactly as Whisper outputs it. No AI post-processing is applied. Best for when you want verbatim output or are debugging."
        case .clean:
            return "Fixes punctuation, capitalization, and removes filler words like \"um\", \"uh\", \"like\", \"you know\". Preserves your original meaning and tone. Best for everyday dictation."
        case .format:
            return "Rewrites your speech as clear, well-structured prose with proper paragraphs and formatting. May use markdown (headers, lists) where appropriate. Best for writing emails, docs, or notes."
        case .custom:
            return "Your custom system prompt is sent to the AI along with the transcription. Use this for specialized formatting, translation, summarization, or any other transformation."
        }
    }
}

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Codable, Identifiable {
    case holdToRecord = "hold"
    case toggleRecord = "toggle"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .holdToRecord: return "Push to Talk"
        case .toggleRecord: return "Toggle"
        }
    }

    var description: String {
        switch self {
        case .holdToRecord: return "Hold hotkey to record, release to stop"
        case .toggleRecord: return "Press once to start, press again to stop"
        }
    }
}

// MARK: - Hotkey Configuration

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt

    static let defaultHotkey = HotkeyConfig(
        keyCode: 61,  // Right Option key
        modifierFlags: 0
    )

    var displayString: String {
        var parts: [String] = []

        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control) { parts.append("^") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }

        let keyName = Self.keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 54: return "Right \u{2318}"
        case 55: return "Left \u{2318}"
        case 56: return "Left \u{21E7}"
        case 57: return "CapsLock"
        case 58: return "Left \u{2325}"
        case 59: return "Left ^"
        case 60: return "Right \u{21E7}"
        case 61: return "Right \u{2325}"
        case 62: return "Right ^"
        case 63: return "fn"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "\u{2190}"  // Left arrow
        case 124: return "\u{2192}"  // Right arrow
        case 125: return "\u{2193}"  // Down arrow
        case 126: return "\u{2191}"  // Up arrow
        default: return "Key(\(keyCode))"
        }
    }
}

// MARK: - App Settings

@Observable
final class AppSettings {
    private static let serverURLKey = "serverURL"
    private static let authTokenKey = "authToken"
    private static let processingModeKey = "processingMode"
    private static let customPromptKey = "customPrompt"
    private static let autoPasteKey = "autoPaste"
    private static let playSoundKey = "playSound"
    private static let hotkeyConfigKey = "hotkeyConfig"
    private static let recordingModeKey = "recordingMode"

    private let defaults = UserDefaults.standard

    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Self.serverURLKey) }
    }

    var authToken: String {
        didSet { defaults.set(authToken, forKey: Self.authTokenKey) }
    }

    var processingMode: ProcessingMode {
        didSet { defaults.set(processingMode.rawValue, forKey: Self.processingModeKey) }
    }

    var customPrompt: String {
        didSet { defaults.set(customPrompt, forKey: Self.customPromptKey) }
    }

    var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Self.autoPasteKey) }
    }

    var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Self.playSoundKey) }
    }

    var hotkeyConfig: HotkeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeyConfig) {
                defaults.set(data, forKey: Self.hotkeyConfigKey)
            }
        }
    }

    var recordingMode: RecordingMode {
        didSet { defaults.set(recordingMode.rawValue, forKey: Self.recordingModeKey) }
    }

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        self.authToken = UserDefaults.standard.string(forKey: Self.authTokenKey) ?? ""

        if let modeString = UserDefaults.standard.string(forKey: Self.processingModeKey),
           let mode = ProcessingMode(rawValue: modeString) {
            self.processingMode = mode
        } else {
            self.processingMode = .clean
        }

        self.customPrompt = UserDefaults.standard.string(forKey: Self.customPromptKey) ?? ""

        if UserDefaults.standard.object(forKey: Self.autoPasteKey) != nil {
            self.autoPaste = UserDefaults.standard.bool(forKey: Self.autoPasteKey)
        } else {
            self.autoPaste = true
        }

        if UserDefaults.standard.object(forKey: Self.playSoundKey) != nil {
            self.playSound = UserDefaults.standard.bool(forKey: Self.playSoundKey)
        } else {
            self.playSound = true
        }

        if let data = UserDefaults.standard.data(forKey: Self.hotkeyConfigKey),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            self.hotkeyConfig = config
        } else {
            self.hotkeyConfig = HotkeyConfig.defaultHotkey
        }

        if let modeStr = UserDefaults.standard.string(forKey: Self.recordingModeKey),
           let mode = RecordingMode(rawValue: modeStr) {
            self.recordingMode = mode
        } else {
            self.recordingMode = .holdToRecord
        }
    }

    var isConfigured: Bool {
        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !token.isEmpty else { return false }

        // Require HTTPS in production (allow http for localhost/loopback dev)
        if let parsed = URL(string: url),
           parsed.scheme == "http" {
            let host = parsed.host ?? ""
            let localHosts: Set = ["localhost", "127.0.0.1", "::1", "0.0.0.0"]
            if !localHosts.contains(host) { return false }
        }
        return true
    }

    var normalizedServerURL: String {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
}
