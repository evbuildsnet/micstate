import AVFAudio
import Foundation

/// Makes this process eligible for the AirPods mute gesture by holding a silent input stream
/// and registering the macOS input-mute handler.
@MainActor
final class StemGesture {
    private(set) var isEngaged = false
    var onGesture: ((Bool) -> Void)?

    private let engine = AVAudioEngine()
    private var configToken: NSObjectProtocol?

    init() {
        configToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restartIfEngaged() }
        }
    }

    func engage(muted: Bool) {
        guard !isEngaged else { return }
        isEngaged = true
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, granted, self.isEngaged else {
                    if !granted { NSLog("MicState: microphone permission denied, AirPods gesture unavailable") }
                    return
                }
                self.start(muted: muted)
            }
        }
    }

    func disengage() {
        guard isEngaged else { return }
        isEngaged = false
        try? AVAudioApplication.shared.setInputMuteStateChangeHandler(nil)
        stopEngine()
    }

    /// Keeps the system's notion of mute aligned with the hardware flag, so the next press flips the right way.
    func sync(muted: Bool) {
        guard isEngaged, AVAudioApplication.shared.isInputMuted != muted else { return }
        try? AVAudioApplication.shared.setInputMuted(muted)
    }

    private func start(muted: Bool) {
        let app = AVAudioApplication.shared
        try? app.setInputMuted(muted)
        do {
            try app.setInputMuteStateChangeHandler { [weak self] shouldMute in
                Task { @MainActor in self?.onGesture?(shouldMute) }
                return true
            }
        } catch {
            NSLog("MicState: cannot register mute handler: \(error)")
        }
        startEngine()
    }

    private func startEngine() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
        do { try engine.start() } catch { NSLog("MicState: input engine failed: \(error)") }
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func restartIfEngaged() {
        guard isEngaged else { return }
        stopEngine()
        startEngine()
    }
}
