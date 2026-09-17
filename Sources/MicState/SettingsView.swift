import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var recorders: [Recorder] = []
    @Published var deviceName = ""
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @AppStorage(Prefs.playSound) private var playSound = true
    @AppStorage(Prefs.showToast) private var showToast = true
    @AppStorage(Prefs.muteOnMeetingStart) private var muteOnMeetingStart = true
    @AppStorage(Prefs.yieldBundleIDs) private var yieldBundleIDs = Prefs.defaultYieldBundleIDs
    @AppStorage(Prefs.ignoreBundleIDs) private var ignoreBundleIDs = Prefs.defaultIgnoreBundleIDs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Play sound on toggle", isOn: $playSound)
                Toggle("Show notice under the notch", isOn: $showToast)
            }
            Section("Behavior") {
                Toggle("Mute automatically when a meeting starts", isOn: $muteOnMeetingStart)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
            }
            Section {
                TextEditor(text: $yieldBundleIDs)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 70)
            } header: {
                Text("Apps that handle the AirPods button themselves")
            } footer: {
                Text("One bundle ID per line. While one of these apps records, MicState leaves the AirPods button to it.")
            }
            Section {
                TextEditor(text: $ignoreBundleIDs)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 70)
            } header: {
                Text("Apps that are not meetings")
            } footer: {
                Text("One bundle ID prefix per line. Dictation tools and system services that record in the background go here.")
            }
            Section("Now") {
                LabeledContent("Input device", value: model.deviceName)
                LabeledContent("Recording", value: model.recorders.isEmpty ? "nobody" : model.recorders.map(\.bundleID).joined(separator: ", "))
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    private let model: SettingsModel

    init(model: SettingsModel) { self.model = model }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            w.title = "MicState Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
