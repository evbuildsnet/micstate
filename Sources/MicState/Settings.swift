import Foundation

/// UserDefaults-backed preferences. Keys double as the `@AppStorage` names in `SettingsView`.
enum Prefs {
    static let playSound = "playSound"
    static let showToast = "showToast"
    static let yieldBundleIDs = "yieldBundleIDs"
    static let ignoreBundleIDs = "ignoreBundleIDs"

    static let defaultYieldBundleIDs = """
    com.microsoft.teams
    """

    /// Background recorders that are not meetings, such as dictation tools.
    static let defaultIgnoreBundleIDs = """
    com.electron.wispr-flow
    com.apple.CoreSpeech
    com.apple.assistantd
    """

    static func register() {
        UserDefaults.standard.register(defaults: [
            playSound: true,
            showToast: true,
            yieldBundleIDs: defaultYieldBundleIDs,
            ignoreBundleIDs: defaultIgnoreBundleIDs,
        ])
    }

    static var isSoundOn: Bool { UserDefaults.standard.bool(forKey: playSound) }
    static var isToastOn: Bool { UserDefaults.standard.bool(forKey: showToast) }

    /// Apps that own the AirPods gesture themselves. While one of them records, MicState steps aside.
    /// Matched by prefix, because apps usually record from a helper process such as `com.microsoft.teams2.helper`.
    static func yields(to bundleID: String) -> Bool {
        prefixes(yieldBundleIDs).contains { bundleID.hasPrefix($0) }
    }

    static func ignores(_ bundleID: String) -> Bool {
        prefixes(ignoreBundleIDs).contains { bundleID.hasPrefix($0) }
    }

    private static func prefixes(_ key: String) -> [String] {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        return raw.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
