import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let hotkeyManager: HotkeyManager
    let apiClient: APIClient

    @State private var selectedTab: SettingsTab = .server
    @State private var connectionStatus: ConnectionTestStatus = .idle
    @State private var hasAccessibility = HotkeyManager.hasAccessibilityPermission
    @State private var hasMicrophone = AudioRecorder.hasMicrophonePermission

    enum SettingsTab: String, CaseIterable, Identifiable {
        case server = "Server"
        case general = "General"
        case processing = "Processing"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .server: return "globe"
            case .general: return "gear"
            case .processing: return "wand.and.stars"
            }
        }
    }

    enum ConnectionTestStatus: Equatable {
        case idle, testing, success
        case failure(String)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .server: serverContent
                    case .general: generalContent
                    case .processing: processingContent
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 400)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = HotkeyManager.hasAccessibilityPermission
            hasMicrophone = AudioRecorder.hasMicrophonePermission
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 1) {
            ForEach(SettingsTab.allCases) { tab in
                SidebarRow(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                ) { selectedTab = tab }
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 150)
    }

    // MARK: - Server

    @ViewBuilder
    private var serverContent: some View {
        SettingsGroup("Connection") {
            FieldRow(label: "Server URL") {
                TextField("", text: $settings.serverURL, prompt: Text("https://your-app.vercel.app"))
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow(label: "Auth Token") {
                SecureField("", text: $settings.authToken, prompt: Text("Shared secret"))
                    .textFieldStyle(.roundedBorder)
            }
            HelpText("Enter the URL of your Vercel deployment and the AUTH_TOKEN you configured as an environment variable.")
        }

        SettingsGroup("Test") {
            HStack {
                Button("Test Connection") { testConnection() }
                    .disabled(!settings.isConfigured || connectionStatus == .testing)
                Spacer()
                connectionStatusLabel
            }
        }
    }

    @ViewBuilder
    private var connectionStatusLabel: some View {
        switch connectionStatus {
        case .idle: EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Testing...").font(.caption).foregroundStyle(.secondary)
            }
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(.red).lineLimit(1)
        }
    }

    // MARK: - Processing

    @ViewBuilder
    private var processingContent: some View {
        SettingsGroup("Mode") {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ProcessingMode.allCases) { mode in
                    ProcessingModeRow(
                        mode: mode,
                        isSelected: settings.processingMode == mode
                    ) {
                        settings.processingMode = mode
                    }
                }
            }
        }

        if settings.processingMode == .custom {
            SettingsGroup("Custom Prompt") {
                TextEditor(text: $settings.customPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                HelpText("This system prompt is sent to the AI along with your transcription.")
            }
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalContent: some View {
        SettingsGroup("Hotkey") {
            HStack {
                Text("Current hotkey")
                    .font(.system(size: 13))
                Spacer()
                Text(settings.hotkeyConfig.displayString)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            hotkeyButtons

            Divider().padding(.vertical, 2)

            HStack {
                Text("Recording mode")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $settings.recordingMode) {
                    ForEach(RecordingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            Text(settings.recordingMode.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }

        SettingsGroup("Behavior") {
            Toggle("Auto-paste after transcription", isOn: $settings.autoPaste)
                .font(.system(size: 13))
            Toggle("Play sounds", isOn: $settings.playSound)
                .font(.system(size: 13))
            HelpText("Auto-paste simulates Cmd+V into the active app. Sounds play a brief cue when recording starts and stops.")
        }

        SettingsGroup("Permissions") {
            permissionRow(
                title: "Accessibility",
                description: "Required for global hotkey and auto-paste into other apps.",
                granted: hasAccessibility,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            permissionRow(
                title: "Microphone",
                description: "Required to record audio for transcription.",
                granted: hasMicrophone,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )

        }

        SettingsGroup("About") {
            HStack {
                Text("Version").font(.system(size: 13))
                Spacer()
                Text(UpdateChecker.currentVersion).font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var hotkeyButtons: some View {
        if hotkeyManager.isRecordingHotkey {
            HStack {
                Label("Press any key or modifier...", systemImage: "circle.fill")
                    .font(.system(size: 12)).foregroundStyle(.orange).symbolEffect(.pulse)
                Spacer()
                Button("Cancel") { hotkeyManager.cancelRecordingHotkey() }.controlSize(.small)
            }
        } else {
            HStack {
                Button("Record New Hotkey") { hotkeyManager.startRecordingHotkey() }.controlSize(.small)
                Spacer()
                Button("Reset to Default") {
                    let config = HotkeyConfig.defaultHotkey
                    settings.hotkeyConfig = config
                    hotkeyManager.updateConfig(config)
                }.controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, description: String, granted: Bool, settingsURL: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                if granted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Button("Open Settings...") {
                        if let url = URL(string: settingsURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            }
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func testConnection() {
        connectionStatus = .testing
        Task {
            do {
                let response = try await apiClient.healthCheck()
                await MainActor.run {
                    connectionStatus = response.status == "ok" || response.status == "healthy"
                        ? .success : .failure("Unexpected: \(response.status)")
                }
            } catch {
                await MainActor.run { connectionStatus = .failure(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Components

private struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).frame(width: 16)
                Text(title).font(.system(size: 12))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : isHovered ? Color.primary.opacity(0.05) : .clear)
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
            content
        }
    }
}

private struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            content
        }
    }
}

private struct HelpText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }
}

private struct ProcessingModeRow: View {
    let mode: ProcessingMode
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                    )
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text(mode.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.05) : isSelected ? Color.accentColor.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
