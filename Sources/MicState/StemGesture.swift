import AVFAudio
import CoreAudio
import Foundation

/// Makes this process eligible for the AirPods mute gesture by holding a silent input stream
/// and registering the macOS input-mute handler.
///
/// The stream is torn down and rebuilt whenever the default input device changes, because the
/// engine bound to the old device stops capturing and macOS then reports "Cannot Control Mic".
@MainActor
final class StemGesture {
    private(set) var isEngaged = false
    var onGesture: ((Bool) -> Void)?

    private var engine: AVAudioEngine?
    private var lastMuted = false
    private var configToken: NSObjectProtocol?
    private var deviceToken: CoreAudio.ListenerToken?
    private var pendingRestart: DispatchWorkItem?

    init() {
        configToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRestart(reason: "engine configuration change") }
        }
        deviceToken = CoreAudio.listen(CoreAudio.system, CoreAudio.address(kAudioHardwarePropertyDefaultInputDevice)) { [weak self] in
            self?.scheduleRestart(reason: "default input changed")
        }
    }

    func engage(muted: Bool) {
        lastMuted = muted
        guard !isEngaged else { return }
        isEngaged = true
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, self.isEngaged else { return }
                guard granted else {
                    Log.info("microphone permission denied, AirPods gesture unavailable")
                    return
                }
                self.start()
            }
        }
    }

    func disengage() {
        guard isEngaged else { return }
        isEngaged = false
        pendingRestart?.cancel()
        try? AVAudioApplication.shared.setInputMuteStateChangeHandler(nil)
        stopEngine()
        Log.info("stem: disengaged")
    }

    /// Keeps the system's notion of mute aligned with the hardware flag, so the next press flips the right way.
    func sync(muted: Bool) {
        lastMuted = muted
        guard isEngaged, AVAudioApplication.shared.isInputMuted != muted else { return }
        try? AVAudioApplication.shared.setInputMuted(muted)
    }

    private func start() {
        let app = AVAudioApplication.shared
        try? app.setInputMuted(lastMuted)
        do {
            try app.setInputMuteStateChangeHandler { [weak self] shouldMute in
                Task { @MainActor in self?.onGesture?(shouldMute) }
                return true
            }
        } catch {
            Log.info("stem: cannot register mute handler: \(error)")
        }
        startEngine()
    }

    private func startEngine() {
        stopEngine()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Log.info("stem: input format not ready, retrying")
            scheduleRestart(reason: "input format not ready")
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
        do {
            try engine.start()
            self.engine = engine
            Log.info("stem: engaged, capturing at \(Int(format.sampleRate)) Hz")
        } catch {
            Log.info("stem: input engine failed: \(error)")
            scheduleRestart(reason: "engine start failed")
        }
    }

    private func stopEngine() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    private func scheduleRestart(reason: String) {
        guard isEngaged else { return }
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isEngaged else { return }
            Log.info("stem: restarting (\(reason))")
            self.start()
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
