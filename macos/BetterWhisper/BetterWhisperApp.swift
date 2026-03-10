import SwiftUI

// Pure AppKit entry point — no SwiftUI App protocol needed.
// NSStatusItem + NSPopover for the menu bar, NSWindow for Settings/History.

@main
enum BetterWhisperApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)  // No dock icon
        app.run()
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    let appController = AppController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clickOutsideMonitor: Any?

    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "BetterWhisper")
            }
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 340)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                appController: appController,
                onOpenSettings: { [weak self] in self?.openSettings() },
                onOpenHistory: { [weak self] in self?.openHistory() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Windows

    func openSettings() {
        popover.performClose(nil)

        // Always recreate so permission checks are fresh
        settingsWindow?.close()

        let view = SettingsView(
            settings: appController.settings,
            hotkeyManager: appController.hotkeyManager,
            apiClient: appController.apiClient
        )
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    func openHistory() {
        popover.performClose(nil)

        if let window = historyWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryView(historyStore: appController.historyStore)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        historyWindow = window
    }

}

// MARK: - Popover Content

struct PopoverContentView: View {
    let appController: AppController
    let onOpenSettings: () -> Void
    let onOpenHistory: () -> Void
    let onQuit: () -> Void

    var body: some View {
        MenuBarView(
            settings: appController.settings,
            historyStore: appController.historyStore,
            status: appController.status,
            recordingDuration: appController.audioRecorder.recordingDuration,
            lastTranscription: appController.lastTranscription,
            availableUpdate: appController.availableUpdate,
            onToggleRecording: { appController.toggleRecording() },
            onDismissError: { appController.dismissError() },
            onModeChanged: { mode in appController.settings.processingMode = mode },
            onOpenHistory: onOpenHistory,
            onOpenSettings: onOpenSettings,
            onQuit: onQuit
        )
    }
}

// MARK: - App Controller

@Observable
final class AppController {
    let settings: AppSettings
    let audioRecorder: AudioRecorder
    let hotkeyManager: HotkeyManager
    let apiClient: APIClient
    let pasteManager: PasteManager
    let historyStore: HistoryStore
    let soundPlayer: SoundPlayer

    private(set) var status: AppStatus = .idle
    private(set) var lastTranscription: String?
    private(set) var availableUpdate: UpdateChecker.Release?

    private let recordingOverlay = RecordingOverlayController()

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.audioRecorder = AudioRecorder()
        self.hotkeyManager = HotkeyManager(config: settings.hotkeyConfig)
        self.apiClient = APIClient(settings: settings)
        self.pasteManager = PasteManager()
        self.historyStore = HistoryStore()
        self.soundPlayer = SoundPlayer()

        setupHotkey()
        setupHotkeyRecorder()
        requestPermissionsIfNeeded()
        if HotkeyManager.hasAccessibilityPermission {
            hotkeyManager.startListening()
        }
        audioRecorder.prepareEngine()
        checkForUpdates()
    }

    private func setupHotkey() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.settings.recordingMode == .toggleRecord {
                    self.toggleRecording()
                } else {
                    self.startRecording()
                }
            }
        }
        hotkeyManager.onHotkeyUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.settings.recordingMode == .holdToRecord {
                    self.stopRecordingAndTranscribe()
                }
            }
        }
    }

    private func setupHotkeyRecorder() {
        hotkeyManager.onHotkeyRecorded = { [weak self] config in
            guard let self else { return }
            self.settings.hotkeyConfig = config
            self.hotkeyManager.updateConfig(config)
            self.hotkeyManager.startListening()
        }
    }

    private func requestPermissionsIfNeeded() {
        Task { await AudioRecorder.requestMicrophonePermission() }
    }

    private func checkForUpdates() {
        Task {
            if let release = await UpdateChecker.checkForUpdate() {
                await MainActor.run { self.availableUpdate = release }
            }
        }
    }

    @MainActor
    func toggleRecording() {
        if status == .recording { stopRecordingAndTranscribe() }
        else { startRecording() }
    }

    @MainActor
    func dismissError() {
        if case .error = status { status = .idle }
    }

    @MainActor
    private func startRecording() {
        guard status == .idle || status.isError else { return }
        guard settings.isConfigured else {
            status = .error("Not configured — open Settings to add your server URL and auth token.")
            return
        }
        do {
            try audioRecorder.startRecording()
            status = .recording
            if settings.playSound { soundPlayer.playStartSound() }
            recordingOverlay.show()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func stopRecordingAndTranscribe() {
        guard status == .recording else { return }
        recordingOverlay.dismiss()
        guard let result = audioRecorder.stopRecording() else { status = .idle; return }
        if settings.playSound { soundPlayer.playStopSound() }
        let wavURL = result.url
        let duration = result.duration
        guard duration >= 0.3 else {
            audioRecorder.cleanupTempFile(at: wavURL)
            status = .idle
            return
        }
        status = .transcribing
        Task { @MainActor in
            let audioURL = await audioRecorder.compressAudio(wavURL: wavURL)
            await transcribeAndProcess(audioURL: audioURL, duration: duration)
        }
    }

    @MainActor
    private func transcribeAndProcess(audioURL: URL, duration: Double) async {
        status = .transcribing
        do {
            let transcriptionResponse = try await apiClient.transcribe(audioURL: audioURL)
            audioRecorder.cleanupTempFile(at: audioURL)
            let rawText = transcriptionResponse.text
            var processedText: String? = nil
            if settings.processingMode != .raw {
                status = .processing
                let processResponse = try await apiClient.process(
                    text: rawText, mode: settings.processingMode,
                    customPrompt: settings.processingMode == .custom ? settings.customPrompt : nil
                )
                processedText = processResponse.text
            }
            let finalText = processedText ?? rawText
            historyStore.save(record: TranscriptionRecord(
                rawText: rawText, processedText: processedText,
                mode: settings.processingMode.rawValue, duration: duration
            ))
            lastTranscription = finalText
            if settings.autoPaste { pasteManager.paste(text: finalText) }
            else { pasteManager.copyToClipboard(text: finalText) }
            status = .idle
        } catch {
            audioRecorder.cleanupTempFile(at: audioURL)
            status = .error(error.localizedDescription)
        }
    }
}
