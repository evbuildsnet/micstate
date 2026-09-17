import AppKit
import SwiftUI

/// A one-second, click-through "Mic on / Mic off" notice hanging under the notch.
@MainActor
final class NotchToast {
    private let panel: NSPanel
    private let host = NSHostingView(rootView: ToastView(muted: false))
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = host
        panel.alphaValue = 0
    }

    func show(muted: Bool) {
        hideWork?.cancel()
        host.rootView = ToastView(muted: muted)
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let size = host.fittingSize
        let hasNotch = screen.safeAreaInsets.top > 0
        let width = hasNotch
            ? max(size.width, screen.auxiliaryTopRightArea.map { $0.minX }.flatMap { right in screen.auxiliaryTopLeftArea.map { right - $0.maxX } } ?? size.width)
            : size.width
        let top = screen.frame.maxY - (hasNotch ? screen.safeAreaInsets.top : NSStatusBar.system.thickness + 6)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: top - size.height, width: width, height: size.height)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        let work = DispatchWorkItem { [panel] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0
            } completionHandler: {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}

private struct ToastView: View {
    let muted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(muted ? Color.white.opacity(0.85) : Color.red)
            Text(muted ? "Mic off" : "Mic on")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
    }
}
