import SwiftUI
import AppKit
import IOKit.pwr_mgt

/// 休息窗口控制器：管理全屏覆盖窗口 + 屏幕保护抑制 + 音效
final class BreakWindowController: NSObject {
    private var window: NSWindow?
    /// IOKit 电源断言 — 阻止显示器休眠
    private var sleepAssertionID: IOPMAssertionID = 0
    private let assertionReason = "Sige - 休息中，阻止屏幕保护" as CFString

    func showWindow() {
        // 阻止屏幕保护
        takeScreenSaverAssertion()
        // 播放音效
        let sound = AppPreferences.shared.breakSound
        SoundManager.shared.play(sound)

        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            window?.alphaValue = 1.0
            refreshContent()
            return
        }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("[Sige] ❌ 无法获取屏幕")
            return
        }

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.isReleasedWhenClosed = false
        win.alphaValue = 0.0
        win.title = "Sige Break"

        let hosting = makeHostingView(for: screen)
        win.contentView = hosting
        win.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            win.animator().alphaValue = 1.0
        }

        self.window = win
        print("[Sige] ✅ 休息窗口已显示")
    }

    func updateToFullBreak() {
        refreshContent()
    }

    func closeWindow() {
        // 释放屏幕保护断言
        releaseScreenSaverAssertion()
        // 停止音效
        SoundManager.shared.stop()

        guard let win = window else { return }
        window = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0.0
        }, completionHandler: {
            win.orderOut(nil)
            win.close()
        })
        print("[Sige] 🚪 休息窗口已关闭")
    }

    // MARK: - 屏幕保护抑制

    private func takeScreenSaverAssertion() {
        guard AppPreferences.shared.preventScreenSaver else { return }
        releaseScreenSaverAssertion()

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionReason,
            &sleepAssertionID
        )
        if result == kIOReturnSuccess {
            print("[Sige] 🔒 屏幕保护已阻止")
        } else {
            print("[Sige] ⚠️ 屏幕保护断言失败: \(result)")
        }
    }

    private func releaseScreenSaverAssertion() {
        guard sleepAssertionID != 0 else { return }
        IOPMAssertionRelease(sleepAssertionID)
        sleepAssertionID = 0
    }

    // MARK: - Private

    private func refreshContent() {
        guard let win = window,
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let hosting = makeHostingView(for: screen)
        win.contentView = hosting
    }

    private func makeHostingView(for screen: NSScreen) -> NSView {
        let view = BreakOverlayView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        return hosting
    }
}
