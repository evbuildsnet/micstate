import AppKit
import Foundation

/// Wires the pieces together and holds the policy.
@MainActor
final class AppController {
    private let mute = MuteEngine()
    private let presence = MicPresence()
    private let stem = StemGesture()
    private let chime = Chime()
    private let toast = NotchToast()
    private let statusItem = StatusItemController()
    private let settingsModel = SettingsModel()
    private lazy var settingsWindow = SettingsWindow(model: settingsModel)

    private var isLive = false
    private var isYielding = false

    init() {
        statusItem.onToggle = { [unowned self] in mute.toggle() }
        statusItem.onOpenSettings = { [unowned self] in settingsWindow.show() }
        statusItem.statusLine = { [unowned self] in statusLine() }

        mute.onChange = { [unowned self] muted in
            NSLog("MicState: mute flag -> %d on %@", muted, mute.deviceName)
            stem.sync(muted: muted)
            if isLive {
                if Prefs.isSoundOn { chime.play(muted: muted) }
                if Prefs.isToastOn { toast.show(muted: muted) }
            }
            render()
        }
        stem.onGesture = { [unowned self] shouldMute in
            if shouldMute != mute.isMuted { mute.set(muted: shouldMute) }
        }
        presence.onChange = { [unowned self] recorders in
            settingsModel.recorders = recorders
            apply(recorders: recorders)
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.apply(recorders: self?.presence.recorders ?? []) }
        }

        apply(recorders: presence.recorders)
    }

    func shutdown() {
        stem.disengage()
        mute.set(muted: false)
    }

    private func apply(recorders allRecorders: [Recorder]) {
        let recorders = allRecorders.filter { !Prefs.ignores($0.bundleID) }
        let wasLive = isLive
        isLive = !recorders.isEmpty
        isYielding = recorders.contains { Prefs.yields(to: $0.bundleID) }
        NSLog("MicState: recorders=%@ live=%d yielding=%d muted=%d", recorders.map(\.bundleID).joined(separator: ","), isLive, isYielding, mute.isMuted)

        if !isLive, wasLive {
            mute.set(muted: false)
        }
        if isLive, !isYielding {
            stem.engage(muted: mute.isMuted)
        } else {
            stem.disengage()
        }
        settingsModel.deviceName = mute.deviceName
        render()
    }

    private func render() {
        statusItem.render(isLive ? .live(muted: mute.isMuted) : .idle)
    }

    private func statusLine() -> String {
        guard isLive else { return "Microphone idle · \(mute.deviceName)" }
        let who = presence.recorders.filter { !Prefs.ignores($0.bundleID) }.map { $0.bundleID.split(separator: ".").last.map(String.init) ?? $0.bundleID }.joined(separator: ", ")
        let owner = isYielding ? " · AirPods button handled by app" : ""
        return "\(mute.isMuted ? "Muted" : "Live") · \(who)\(owner)"
    }
}
