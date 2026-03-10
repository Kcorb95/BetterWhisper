import SwiftUI

// MARK: - App Status

enum AppStatus: Equatable {
    case idle
    case recording
    case transcribing
    case processing
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .processing: return "Processing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .processing: return "brain"
        case .error: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .recording: return .red
        case .transcribing: return .blue
        case .processing: return .purple
        case .error: return .orange
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @Bindable var settings: AppSettings
    let historyStore: HistoryStore
    let status: AppStatus
    let recordingDuration: Double
    let lastTranscription: String?
    let availableUpdate: UpdateChecker.Release?

    var onToggleRecording: (() -> Void)?
    var onDismissError: (() -> Void)?
    var onModeChanged: ((ProcessingMode) -> Void)?
    var onOpenHistory: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Update banner
            if let update = availableUpdate {
                Button {
                    UpdateChecker.openReleasePage(update)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Update available")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("View on GitHub")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .padding(8)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            }

            // Header: status + record button
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(status.color)
                        .symbolEffect(.pulse, isActive: status == .recording)
                        .frame(width: 16)

                    Text(status.isError ? "Error" : status.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(status == .idle ? .secondary : status.color)

                    if status == .recording {
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !settings.isConfigured {
                        Text("Not configured")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }

                // Error banner — persistent, dismissable
                if case .error(let message) = status {
                    HStack(alignment: .top, spacing: 6) {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            onDismissError?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button {
                    onToggleRecording?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: status == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 10))
                        Text(status == .recording ? "Stop" : "Record")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(status == .recording ? .red : .accentColor)
                .disabled(status == .transcribing || status == .processing)
            }
            .padding(10)

            Divider()

            // Last transcription
            if let lastText = lastTranscription {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last result")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(lastText, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    Text(lastText.prefix(120).description + (lastText.count > 120 ? "..." : ""))
                        .font(.system(size: 11))
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                }
                .padding(10)

                Divider()
            }

            // Mode picker
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                ForEach(ProcessingMode.allCases) { mode in
                    MenuRow(
                        title: mode.displayName,
                        subtitle: mode.description,
                        isSelected: mode == settings.processingMode
                    ) {
                        settings.processingMode = mode
                        onModeChanged?(mode)
                    }
                }
            }
            .padding(.bottom, 4)

            Divider()

            // Footer actions
            VStack(spacing: 0) {
                MenuRow(title: "History", icon: "clock") {
                    onOpenHistory?()
                }
                MenuRow(title: "Settings...", icon: "gear") {
                    onOpenSettings?()
                }
                Divider().padding(.horizontal, 10).padding(.vertical, 2)
                MenuRow(title: "Quit", icon: "power") {
                    onQuit?()
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 260)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        }
        return String(format: "%d.%ds", seconds, tenths)
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(isSelected ? Color.accentColor : .clear)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        )
                        .frame(width: 14)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : .clear)
                    .opacity(isHovered ? 1 : 0)
                    .padding(.horizontal, 4)
            )
            .foregroundStyle(isHovered ? .white : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
