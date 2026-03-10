import SwiftUI

// MARK: - Recording Overlay

/// A small floating recording indicator window that appears on screen during recording.
final class RecordingOverlayController {
    private var window: NSWindow?

    func show() {
        guard window == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 36),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false

        let hostingView = NSHostingView(rootView: RecordingIndicatorView())
        panel.contentView = hostingView

        // Position at top-center of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 60
            let y = screenFrame.maxY - 50
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.window = panel
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}

// MARK: - Recording Indicator View

struct RecordingIndicatorView: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .opacity(isPulsing ? 1.0 : 0.6)

            Text("Recording")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.red.opacity(0.85))
        .clipShape(Capsule())
        .shadow(color: .red.opacity(0.3), radius: 8, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Sound Player

import AVFoundation

final class SoundPlayer {
    private let startSound = NSSound(named: "Tink")
    private let stopSound = NSSound(named: "Pop")

    func playStartSound() {
        startSound?.play()
    }

    func playStopSound() {
        stopSound?.play()
    }
}
