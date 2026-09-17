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
        statusItem.onToggle = { [unowned self] in
            Log.info("toggle from status item")
            mute.toggle()
        }
        statusItem.onOpenSettings = { [unowned self] in settingsWindow.show() }
        statusItem.statusLine = { [unowned self] in statusLine() }

        mute.onChange = { [unowned self] muted in
            Log.info("mute flag -> \(muted) on \(mute.deviceName)")
            if isLive {
                if Prefs.isSoundOn { chime.play(muted: muted) }
                if Prefs.isToastOn { toast.show(muted: muted) }
            }
            render()
        }
        stem.onGesture = { [unowned self] shouldMute in
            Log.info("gesture wants muted=\(shouldMute), device muted=\(mute.isMuted)")
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
        Log.info("recorders=[\(recorders.map(\.bundleID).joined(separator: ", "))] live=\(isLive) yielding=\(isYielding) muted=\(mute.isMuted)")

        if !isLive, wasLive {
            mute.set(muted: false)
        }
        // Debug aid: `defaults write net.evbuilds.micstate alwaysEngage -bool true` keeps the stream open even when idle.
        let alwaysEngage = UserDefaults.standard.bool(forKey: "alwaysEngage")
        if (isLive || alwaysEngage), !isYielding {
            stem.engage()
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
