import CoreAudio
import Foundation

struct Recorder: Hashable {
    let pid: pid_t
    let bundleID: String
}

/// Tracks which other processes currently capture audio input, using CoreAudio process objects.
@MainActor
final class MicPresence {
    private(set) var recorders: [Recorder] = []
    var onChange: (([Recorder]) -> Void)?

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var listToken: CoreAudio.ListenerToken?
    private var processTokens: [AudioObjectID: CoreAudio.ListenerToken] = [:]

    private static let listAddress = CoreAudio.address(kAudioHardwarePropertyProcessObjectList)
    private static let runningInputAddress = CoreAudio.address(kAudioProcessPropertyIsRunningInput)

    init() {
        listToken = CoreAudio.listen(CoreAudio.system, Self.listAddress) { [weak self] in self?.rescan() }
        rescan()
    }

    func rescan() {
        let objects = CoreAudio.getArray(CoreAudio.system, Self.listAddress, of: AudioObjectID.self)
        let live = Set(objects)
        processTokens = processTokens.filter { live.contains($0.key) }
        for object in objects where processTokens[object] == nil {
            processTokens[object] = CoreAudio.listen(object, Self.runningInputAddress) { [weak self] in self?.rescan() }
        }

        let found = objects.compactMap { object -> Recorder? in
            guard let running = CoreAudio.get(object, Self.runningInputAddress, as: UInt32.self), running != 0,
                  let pid = CoreAudio.get(object, CoreAudio.address(kAudioProcessPropertyPID), as: pid_t.self),
                  pid != ownPID
            else { return nil }
            let bundleID = CoreAudio.getString(object, CoreAudio.address(kAudioProcessPropertyBundleID)) ?? "pid \(pid)"
            return Recorder(pid: pid, bundleID: bundleID)
        }
        guard found != recorders else { return }
        recorders = found
        onChange?(found)
    }
}
