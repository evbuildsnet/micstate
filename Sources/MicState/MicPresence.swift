import CoreAudio
import Foundation

struct Recorder: Hashable {
    let pid: pid_t
    let bundleID: String
}

/// Tracks which other processes currently capture audio input, using CoreAudio process objects.
///
/// Triggers: the process list changing, and the default input device starting or stopping "somewhere".
/// The list change arrives before a new process actually starts capturing, so every trigger also
/// schedules a delayed rescan.
@MainActor
final class MicPresence {
    private(set) var recorders: [Recorder] = []
    var onChange: (([Recorder]) -> Void)?

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var listToken: CoreAudio.ListenerToken?
    private var defaultDeviceToken: CoreAudio.ListenerToken?
    private var runningToken: CoreAudio.ListenerToken?
    private var delayedRescan: DispatchWorkItem?

    private static let listAddress = CoreAudio.address(kAudioHardwarePropertyProcessObjectList)
    private static let runningInputAddress = CoreAudio.address(kAudioProcessPropertyIsRunningInput)
    private static let defaultInputAddress = CoreAudio.address(kAudioHardwarePropertyDefaultInputDevice)
    private static let runningSomewhereAddress = CoreAudio.address(kAudioDevicePropertyDeviceIsRunningSomewhere)

    init() {
        listToken = CoreAudio.listen(CoreAudio.system, Self.listAddress) { [weak self] in self?.trigger() }
        defaultDeviceToken = CoreAudio.listen(CoreAudio.system, Self.defaultInputAddress) { [weak self] in
            self?.attachToDefaultDevice()
            self?.trigger()
        }
        attachToDefaultDevice()
        rescan()
    }

    private func attachToDefaultDevice() {
        runningToken = nil
        guard let device = CoreAudio.get(CoreAudio.system, Self.defaultInputAddress, as: AudioDeviceID.self), device != 0 else { return }
        runningToken = CoreAudio.listen(device, Self.runningSomewhereAddress) { [weak self] in self?.trigger() }
    }

    private func trigger() {
        rescan()
        delayedRescan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescan() }
        delayedRescan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func rescan() {
        let objects = CoreAudio.getArray(CoreAudio.system, Self.listAddress, of: AudioObjectID.self)
        let found = objects.compactMap { object -> Recorder? in
            guard let running = CoreAudio.get(object, Self.runningInputAddress, as: UInt32.self), running != 0,
                  let pid = CoreAudio.get(object, CoreAudio.address(kAudioProcessPropertyPID), as: pid_t.self),
                  pid != ownPID
            else { return nil }
            let bundleID = CoreAudio.getString(object, CoreAudio.address(kAudioProcessPropertyBundleID)).flatMap { $0.isEmpty ? nil : $0 } ?? "pid \(pid)"
            return Recorder(pid: pid, bundleID: bundleID)
        }
        guard found != recorders else { return }
        recorders = found
        onChange?(found)
    }
}
