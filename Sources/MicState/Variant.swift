import Foundation

/// Debug switches for bisecting AirPods gesture delivery.
/// `defaults write net.evbuilds.micstate stemVariant -int N` where N is a bitmask.
enum Variant {
    static let raw = UserDefaults.standard.integer(forKey: "stemVariant")
    /// 1: register the mute handler and start capture on the permission callback thread, not main.
    static let registerOffMain = raw & 1 != 0
    /// 2: run as a regular app with a Dock icon instead of a background-only accessory.
    static let regularApp = raw & 2 != 0
}
