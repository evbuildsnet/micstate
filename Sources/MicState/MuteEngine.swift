import CoreAudio
import Foundation

/// Owns the hardware mute flag of the default input device. The device flag is the single source of truth.
@MainActor
final class MuteEngine {
    private(set) var isMuted = false
    private(set) var deviceName = "No input"
    var onChange: ((Bool) -> Void)?

    private var device: AudioDeviceID?
    private var defaultDeviceToken: CoreAudio.ListenerToken?
    private var muteToken: CoreAudio.ListenerToken?

    private static let muteAddress = CoreAudio.address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)

    init() {
        defaultDeviceToken = CoreAudio.listen(CoreAudio.system, CoreAudio.address(kAudioHardwarePropertyDefaultInputDevice)) { [weak self] in
            self?.attachToDefaultDevice()
        }
        attachToDefaultDevice()
    }

    func set(muted: Bool) {
        guard let device else { return }
        CoreAudio.set(device, Self.muteAddress, UInt32(muted ? 1 : 0))
        refresh()
    }

    func toggle() { set(muted: !isMuted) }

    private func attachToDefaultDevice() {
        device = CoreAudio.get(CoreAudio.system, CoreAudio.address(kAudioHardwarePropertyDefaultInputDevice), as: AudioDeviceID.self)
            .flatMap { $0 == 0 ? nil : $0 }
        muteToken = nil
        guard let device else {
            deviceName = "No input"
            refresh()
            return
        }
        deviceName = CoreAudio.getString(device, CoreAudio.address(kAudioObjectPropertyName)) ?? "Input"
        if CoreAudio.isSettable(device, Self.muteAddress) {
            muteToken = CoreAudio.listen(device, Self.muteAddress) { [weak self] in self?.refresh() }
        } else {
            Log.info("\(deviceName) has no settable input mute flag")
        }
        refresh()
    }

    private func refresh() {
        let now = device.flatMap { CoreAudio.get($0, Self.muteAddress, as: UInt32.self) }.map { $0 != 0 } ?? false
        guard now != isMuted else { return }
        isMuted = now
        onChange?(now)
    }
}
