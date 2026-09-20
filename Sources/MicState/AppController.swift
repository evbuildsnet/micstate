import AppKit
import Foundation

/// Wires the pieces together and holds the policy.
@MainActor
final class AppController {
    // Declaration order matters: `stem` registers the mute handler before any CoreAudio access.
    private let stem = StemGesture()
    private let mute = MuteEngine()
    private let presence = MicPresence()
    private let chime = Chime()
    private let toast = NotchToast()
    private let statusItem = StatusItemController()
    private let settingsModel = SettingsModel()
    private lazy var settingsWindow = SettingsWindow(model: settingsModel)

    private var isLive = false
    private var isYielding = false
    private var pendingDisengage: DispatchWorkItem?
    private var appliedPrefs = Prefs.snapshot()

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
            } else if muted {
                // Nobody is recording, so a muted device only hides silence from the next app that opens the mic.
                Log.info("unmuting idle device")
                mute.set(muted: false)
            }
            render()
        }
        // A new default device carries its own mute flag; re-run the policy so it is not left muted while idle.
        mute.onDeviceChange = { [unowned self] in apply(recorders: presence.recorders) }
        stem.onGesture = { [unowned self] shouldMute in
            Log.info("gesture wants muted=\(shouldMute), device muted=\(mute.isMuted)")
            if shouldMute != mute.isMuted { mute.set(muted: shouldMute) }
        }
        presence.onChange = { [unowned self] recorders in
            settingsModel.recorders = recorders
            apply(recorders: recorders)
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, Prefs.snapshot() != self.appliedPrefs else { return }
                self.appliedPrefs = Prefs.snapshot()
                self.apply(recorders: self.presence.recorders)
            }
        }

        apply(recorders: presence.recorders)
    }

    func shutdown() {
        stem.disengage()
        mute.set(muted: false)
    }

    private func apply(recorders allRecorders: [Recorder]) {
        let recorders = allRecorders.filter { !Prefs.ignores($0.bundleID) }
        isLive = !recorders.isEmpty
        isYielding = recorders.contains { Prefs.yields(to: $0.bundleID) }
        Log.info("recorders=[\(recorders.map(\.bundleID).joined(separator: ", "))] live=\(isLive) yielding=\(isYielding) muted=\(mute.isMuted)")

        if !isLive, mute.isMuted {
            mute.set(muted: false)
        }
        if isLive, !isYielding {
            pendingDisengage?.cancel()
            pendingDisengage = nil
            stem.engage()
        } else if stem.isEngaged, pendingDisengage == nil {
            // Meeting apps briefly drop their input stream when they reconfigure it. Restarting the
            // capture engine on every blip glitches the shared device, so hold on for a moment.
            let work = DispatchWorkItem { [weak self] in
                self?.pendingDisengage = nil
                self?.stem.disengage()
            }
            pendingDisengage = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
        }
        settingsModel.deviceName = mute.deviceName
        render()
    }

    private func render() {
        statusItem.render(isLive ? .live(muted: mute.isMuted) : .idle(muted: mute.isMuted))
    }

    private func statusLine() -> String {
        guard isLive else { return "Microphone idle · \(mute.deviceName)" }
        let who = presence.recorders.filter { !Prefs.ignores($0.bundleID) }.map { $0.bundleID.split(separator: ".").last.map(String.init) ?? $0.bundleID }.joined(separator: ", ")
        let owner = isYielding ? " · AirPods button handled by app" : ""
        return "\(mute.isMuted ? "Muted" : "Live") · \(who)\(owner)"
    }
}
