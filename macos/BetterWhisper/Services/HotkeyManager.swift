import Carbon
import Cocoa
import Foundation

@Observable
final class HotkeyManager {
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    /// Whether the hotkey is currently held down.
    private(set) var isHotkeyPressed = false

    /// Whether we're in "recording a new hotkey" mode.
    private(set) var isRecordingHotkey = false

    /// Callback when a new hotkey is recorded in settings.
    var onHotkeyRecorded: ((HotkeyConfig) -> Void)?

    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var flagsChangedGlobalMonitor: Any?
    private var flagsChangedLocalMonitor: Any?

    private var hotkeyConfig: HotkeyConfig

    init(config: HotkeyConfig = .defaultHotkey) {
        self.hotkeyConfig = config
    }

    deinit {
        stopListening()
    }

    // MARK: - Accessibility Permissions

    /// Check if the app has accessibility permissions (needed for global event monitoring).
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permissions.
    /// Opens System Settings to the appropriate pane.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Configuration

    /// Update the hotkey configuration.
    func updateConfig(_ config: HotkeyConfig) {
        let wasListening = globalKeyDownMonitor != nil || flagsChangedGlobalMonitor != nil
        if wasListening {
            stopListening()
        }
        self.hotkeyConfig = config
        if wasListening {
            startListening()
        }
    }

    // MARK: - Listening

    /// Start listening for the configured hotkey globally.
    func startListening() {
        stopListening()

        // Determine if the hotkey is a modifier-only key (Option, Shift, Control, Command)
        let isModifierOnlyKey = Self.isModifierKeyCode(hotkeyConfig.keyCode)

        if isModifierOnlyKey {
            startModifierKeyListening()
        } else {
            startRegularKeyListening()
        }
    }

    /// Stop listening for hotkey events.
    func stopListening() {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyUpMonitor = nil
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyUpMonitor = nil
        }
        if let monitor = flagsChangedGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedGlobalMonitor = nil
        }
        if let monitor = flagsChangedLocalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedLocalMonitor = nil
        }

        isHotkeyPressed = false
    }

    // MARK: - Modifier-Only Key Listening (e.g., Right Option)

    private func startModifierKeyListening() {
        let targetFlag = Self.modifierFlagForKeyCode(hotkeyConfig.keyCode)

        flagsChangedGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, targetFlag: targetFlag)
        }

        flagsChangedLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, targetFlag: targetFlag)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, targetFlag: NSEvent.ModifierFlags) {
        if isRecordingHotkey {
            handleRecordingFlagsChanged(event)
            return
        }

        let pressed = event.modifierFlags.contains(targetFlag)

        // Always match on the specific keyCode to distinguish left/right modifiers
        if event.keyCode == hotkeyConfig.keyCode && pressed && !isHotkeyPressed {
            isHotkeyPressed = true
            onHotkeyDown?()
        } else if !pressed && isHotkeyPressed {
            isHotkeyPressed = false
            onHotkeyUp?()
        }
    }

    // MARK: - Regular Key Listening (e.g., Ctrl+Shift+Space)

    private func startRegularKeyListening() {
        let requiredModifiers = NSEvent.ModifierFlags(rawValue: hotkeyConfig.modifierFlags)
            .intersection(.deviceIndependentFlagsMask)

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event, requiredModifiers: requiredModifiers)
        }

        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event, requiredModifiers: requiredModifiers)
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event, requiredModifiers: requiredModifiers)
            return event
        }

        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event, requiredModifiers: requiredModifiers)
            return event
        }
    }

    private func handleKeyDown(_ event: NSEvent, requiredModifiers: NSEvent.ModifierFlags) {
        if isRecordingHotkey {
            handleRecordingKeyDown(event)
            return
        }

        guard !event.isARepeat else { return }
        guard event.keyCode == hotkeyConfig.keyCode else { return }

        let currentModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard currentModifiers == requiredModifiers else { return }

        guard !isHotkeyPressed else { return }
        isHotkeyPressed = true
        onHotkeyDown?()
    }

    private func handleKeyUp(_ event: NSEvent, requiredModifiers: NSEvent.ModifierFlags) {
        guard event.keyCode == hotkeyConfig.keyCode else { return }
        guard isHotkeyPressed else { return }

        isHotkeyPressed = false
        onHotkeyUp?()
    }

    // MARK: - Hotkey Recording

    /// Enter hotkey recording mode. The next key press will be captured as the new hotkey.
    func startRecordingHotkey() {
        isRecordingHotkey = true

        // Add temporary monitors if not already listening
        if globalKeyDownMonitor == nil && flagsChangedGlobalMonitor == nil {
            globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleRecordingKeyDown(event)
            }
            localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleRecordingKeyDown(event)
                return nil  // Consume the event
            }
            flagsChangedGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleRecordingFlagsChanged(event)
            }
            flagsChangedLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleRecordingFlagsChanged(event)
                return event
            }
        }
    }

    /// Cancel hotkey recording mode and clean up any temporary monitors.
    func cancelRecordingHotkey() {
        isRecordingHotkey = false
        stopListening()
        if Self.hasAccessibilityPermission {
            startListening()
        }
    }

    private func handleRecordingKeyDown(_ event: NSEvent) {
        guard isRecordingHotkey else { return }

        // Escape cancels recording
        if event.keyCode == 53 {
            isRecordingHotkey = false
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let config = HotkeyConfig(keyCode: event.keyCode, modifierFlags: modifiers.rawValue)

        isRecordingHotkey = false
        onHotkeyRecorded?(config)
    }

    private func handleRecordingFlagsChanged(_ event: NSEvent) {
        guard isRecordingHotkey else { return }

        // Only record modifier-only keys if the key was just pressed (flag appeared)
        let keyCode = event.keyCode
        guard Self.isModifierKeyCode(keyCode) else { return }

        // Check if this modifier was just pressed (flag is now set)
        let flag = Self.modifierFlagForKeyCode(keyCode)
        guard event.modifierFlags.contains(flag) else { return }

        let config = HotkeyConfig(keyCode: keyCode, modifierFlags: 0)
        isRecordingHotkey = false
        onHotkeyRecorded?(config)
    }

    // MARK: - Helpers

    private static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55:  // Left/Right Command
            return true
        case 56, 60:  // Left/Right Shift
            return true
        case 58, 61:  // Left/Right Option
            return true
        case 59, 62:  // Left/Right Control
            return true
        case 63:      // fn
            return true
        default:
            return false
        }
    }

    private static func modifierFlagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 54, 55: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        case 63: return .function
        default: return []
        }
    }
}
