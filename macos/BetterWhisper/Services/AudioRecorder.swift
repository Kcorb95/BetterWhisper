import AVFoundation
import Foundation

@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var recordingDuration: Double = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempWavURL: URL?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var converter: AVAudioConverter?

    /// Requests microphone permission. Returns true if granted.
    @discardableResult
    static func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Checks if microphone permission is currently granted.
    static var hasMicrophonePermission: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // MARK: - Engine Lifecycle

    /// Warm up the audio engine so recording starts instantly.
    func prepareEngine() {
        // No-op — engine is created fresh per recording to avoid stale hardware state
    }

    /// Start recording audio from the default input device.
    func startRecording() throws {
        guard !isRecording else { return }

        guard Self.hasMicrophonePermission else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        // Always create a fresh engine to avoid stale CoreAudio state
        tearDownEngine()
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioRecorderError.noInputDevice
        }

        // 16kHz mono WAV — ideal for Whisper
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatError
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "betterwhisper_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: recordingFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
        guard let conv = converter else {
            throw AudioRecorderError.formatError
        }

        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * recordingFormat.sampleRate / inputFormat.sampleRate
            )
            guard frameCount > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordingFormat,
                frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            let status = conv.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, convertedBuffer.frameLength > 0 {
                try? file.write(from: convertedBuffer)
            }
        }

        if !engine.isRunning {
            try engine.start()
        }

        self.audioFile = file
        self.tempWavURL = fileURL
        self.recordingStartTime = Date()
        self.isRecording = true
        self.recordingDuration = 0

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.durationTimer = timer
    }

    /// Stop recording and return the URL of the recorded WAV file.
    @discardableResult
    func stopRecording() -> (url: URL, duration: Double)? {
        guard isRecording else { return nil }

        durationTimer?.invalidate()
        durationTimer = nil

        let duration: Double
        if let start = recordingStartTime {
            duration = Date().timeIntervalSince(start)
        } else {
            duration = recordingDuration
        }

        tearDownEngine()
        audioFile = nil

        isRecording = false
        recordingStartTime = nil
        self.recordingDuration = duration

        guard let wavURL = tempWavURL else { return nil }
        tempWavURL = nil

        return (url: wavURL, duration: duration)
    }

    private func tearDownEngine() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }
        converter = nil
    }

    /// Clean up a temporary recording file after it's been uploaded.
    func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Compression

    /// Compress WAV to m4a for smaller upload size. Call after stopRecording().
    func compressAudio(wavURL: URL) async -> URL {
        let m4aURL = wavURL.deletingPathExtension().appendingPathExtension("m4a")
        let asset = AVAsset(url: wavURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return wavURL
        }
        session.outputURL = m4aURL
        session.outputFileType = .m4a

        await session.export()

        if session.status == .completed {
            cleanupTempFile(at: wavURL)
            return m4aURL
        }
        cleanupTempFile(at: m4aURL)
        return wavURL
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied
    case noInputDevice
    case formatError
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Please grant permission in System Settings > Privacy & Security > Microphone."
        case .noInputDevice:
            return "No audio input device found. Please check your microphone connection."
        case .formatError:
            return "Failed to configure audio format for recording."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        }
    }
}
