import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var settingsWindow: NSWindow?
    private var breakController: BreakWindowController?

    // MARK: - 窗口尺寸持久化

    private enum WindowKeys {
        static let settingsFrame = "SettingsWindowFrame"
    }

    private var savedSettingsFrame: NSRect? {
        guard let str = UserDefaults.standard.string(forKey: WindowKeys.settingsFrame) else { return nil }
        return NSRectFromString(str)
    }

    private func saveSettingsFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: WindowKeys.settingsFrame)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarManager.shared.setup()
        BreakScheduler.shared.start()
        NotificationManager.shared.setup()
        NotificationManager.shared.registerNotificationCategories()
        NSApp.setActivationPolicy(.accessory)
        print("[Sige] ✅ 应用已启动")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前保存窗口大小
        if let win = settingsWindow {
            saveSettingsFrame(win.frame)
        }
        BreakScheduler.shared.stop()
    }

    // MARK: - 设置窗口

    func openSettings() {
        // 已有可见窗口 → 前置
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 恢复上次保存的窗口大小，或使用默认值
        let frame = savedSettingsFrame
            ?? NSRect(x: 0, y: 0, width: 900, height: 620)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sige 设置"
        window.isReleasedWhenClosed = false

        // 设置最小尺寸限制
        window.contentMinSize = NSSize(width: 820, height: 560)

        let hostingView = NSHostingView(
            rootView: SettingsView()
        )
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        // 居中显示（首次打开时）
        if savedSettingsFrame == nil {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        // 监听窗口尺寸变化，实时保存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }

    @objc private func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveSettingsFrame(window.frame)
    }

    // MARK: - 休息窗口

    func showBreakWindow() {
        DispatchQueue.main.async { [weak self] in
            let controller = BreakWindowController()
            controller.showWindow()
            self?.breakController = controller
        }
    }

    func hideBreakWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.breakController?.closeWindow()
            self?.breakController = nil
        }
    }
}
