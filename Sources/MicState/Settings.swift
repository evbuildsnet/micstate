import Foundation

/// UserDefaults-backed preferences. Keys double as the `@AppStorage` names in `SettingsView`.
enum Prefs {
    static let playSound = "playSound"
    static let showToast = "showToast"
    static let muteOnMeetingStart = "muteOnMeetingStart"
    static let yieldBundleIDs = "yieldBundleIDs"

    static let defaultYieldBundleIDs = """
    com.microsoft.teams2
    com.microsoft.teams
    """

    static func register() {
        UserDefaults.standard.register(defaults: [
            playSound: true,
            showToast: true,
            muteOnMeetingStart: true,
            yieldBundleIDs: defaultYieldBundleIDs,
        ])
    }

    static var isSoundOn: Bool { UserDefaults.standard.bool(forKey: playSound) }
    static var isToastOn: Bool { UserDefaults.standard.bool(forKey: showToast) }
    static var mutesOnMeetingStart: Bool { UserDefaults.standard.bool(forKey: muteOnMeetingStart) }

    /// Apps that own the AirPods gesture themselves. While one of them records, MicState steps aside.
    static var yieldSet: Set<String> {
        let raw = UserDefaults.standard.string(forKey: yieldBundleIDs) ?? ""
        return Set(raw.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}
