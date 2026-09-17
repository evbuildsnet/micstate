import AppKit

enum MicIndicator: Equatable {
    case idle
    case live(muted: Bool)
}

/// Icon-only status item. Left click toggles, right click opens the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var statusLine: () -> String = { "" }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem()
    private let toggleMenuItem = NSMenuItem(title: "Mute", action: #selector(toggle), keyEquivalent: "")
    private var indicator: MicIndicator = .idle

    override init() {
        super.init()
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(click)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusMenuItem.isEnabled = false
        toggleMenuItem.target = self
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.items = [
            statusMenuItem,
            toggleMenuItem,
            .separator(),
            settings,
            NSMenuItem(title: "Quit MicState", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]
        menu.delegate = self
        render(.idle)
    }

    func render(_ indicator: MicIndicator) {
        self.indicator = indicator
        guard let button = item.button else { return }
        let symbol: String
        let color: NSColor?
        switch indicator {
        case .idle: (symbol, color) = ("mic", nil)
        case .live(muted: true): (symbol, color) = ("mic.slash.fill", nil)
        case .live(muted: false): (symbol, color) = ("mic.fill", .systemRed)
        }
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Microphone")!
        if let color {
            button.image = base.withSymbolConfiguration(.init(paletteColors: [color]))
            button.image?.isTemplate = false
        } else {
            button.image = base
            button.image?.isTemplate = true
        }
        button.appearsDisabled = indicator == .idle
        button.toolTip = indicator == .idle ? "Microphone idle" : "Click to toggle microphone"
    }

    @objc private func click() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            item.menu = menu
            item.button?.performClick(nil)
        } else {
            onToggle?()
        }
    }

    @objc private func toggle() { onToggle?() }
    @objc private func openSettings() { onOpenSettings?() }

    func menuWillOpen(_: NSMenu) {
        statusMenuItem.title = statusLine()
        if case .live(let muted) = indicator {
            toggleMenuItem.isHidden = false
            toggleMenuItem.title = muted ? "Unmute" : "Mute"
        } else {
            toggleMenuItem.isHidden = true
        }
    }

    func menuDidClose(_: NSMenu) { item.menu = nil }
}
