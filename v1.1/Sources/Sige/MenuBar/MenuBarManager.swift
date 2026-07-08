import AppKit
import SwiftUI

/// 菜单栏管理器：状态栏图标、倒计时文字、下拉菜单
final class MenuBarManager: NSObject, NSMenuDelegate {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem!
    private var appMenu: NSMenu!

    @Published var countdownText: String = "--:--"
    @Published var isOnBreak: Bool = false

    private var prefs: AppPreferences { AppPreferences.shared }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            //  纯色 SF Symbol 图标 — 自动适配深色/浅色模式
            //  使用 "cup.and.saucer.fill" 作为默认图标
            let icon = NSImage(
                systemSymbolName: "cup.and.saucer.fill",
                accessibilityDescription: "Sige"
            )
            // template 模式让 macOS 自动根据菜单栏背景切换颜色
            icon?.isTemplate = true

            button.image = icon
            button.imagePosition = .imageLeft
            // 图标下方放倒计时文字（或只显示图标）
            button.title = prefs.showCountdown ? "--:--" : ""
            if let existingFont = button.font {
                button.font = NSFont.monospacedDigitSystemFont(
                    ofSize: existingFont.pointSize,
                    weight: .medium
                )
            }
            button.toolTip = "Sige - 定时休息提醒"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseUp])
        }

        buildMenu()
    }

    // MARK: - Menu Build

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // 状态显示
        let nextLabel = "next_break".l10n
        let title = isOnBreak ? "on_break".l10n : "\(nextLabel): \(countdownText)"
        let infoItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())

        // 立即休息
        let breakItem = NSMenuItem(title: "break_now".l10n, action: #selector(breakNowAction), keyEquivalent: "b")
        breakItem.target = self
        breakItem.isEnabled = !isOnBreak
        menu.addItem(breakItem)

        // 暂停
        let pauseItem = NSMenuItem(title: "pause".l10n, action: nil, keyEquivalent: "")
        let pauseSub = NSMenu()
        let pauseLabels = ["pause_30min", "pause_1hr", "pause_2hr", "pause_tomorrow"]
        let pauseDurations: [TimeInterval] = [1800, 3600, 7200, -1]
        for (i, label) in pauseLabels.enumerated() {
            let item = NSMenuItem(title: label.l10n, action: #selector(pauseAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pauseDurations[i]
            pauseSub.addItem(item)
        }
        if prefs.isPaused {
            pauseSub.addItem(.separator())
            let r = NSMenuItem(title: "resume_break".l10n, action: #selector(resumeAction), keyEquivalent: "")
            r.target = self
            pauseSub.addItem(r)
        }
        pauseItem.submenu = pauseSub
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        // 倒计时开关
        let countdownItem = NSMenuItem(
            title: prefs.showCountdown ? "toggle_countdown_hide".l10n : "toggle_countdown_show".l10n,
            action: #selector(toggleCountdownAction),
            keyEquivalent: ""
        )
        countdownItem.target = self
        menu.addItem(countdownItem)
        menu.addItem(.separator())

        // 设置
        let settingsItem = NSMenuItem(title: "settings_menu".l10n, action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(title: "quit".l10n, action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        appMenu = menu
    }

    private func refreshMenu() {
        buildMenu()
    }

    // MARK: - NSMenuDelegate

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.button?.isHighlighted = false
    }

    // MARK: - Icon Update

    /// 根据状态切换图标 — 休息中 vs 工作中
    private func updateIcon(isBreak: Bool) {
        let symbolName = isBreak ? "stopwatch" : "cup.and.saucer.fill"
        let icon = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isBreak ? "on_break".l10n : "Sige"
        )
        icon?.isTemplate = true
        statusItem?.button?.image = icon
    }

    // MARK: - Update Countdown

    func updateCountdown(seconds: TimeInterval) {
        guard seconds > 0 else {
            countdownText = "break_soon".l10n
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.button?.title = "⏱"
                self?.updateIcon(isBreak: false)
            }
            refreshMenu()
            return
        }

        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        countdownText = String(format: "%02d:%02d", mins, secs)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateIcon(isBreak: self.isOnBreak)
            self.statusItem?.button?.title = self.prefs.showCountdown
                ? self.countdownText
                : ""
        }
        refreshMenu()
    }

    func enterBreakState() {
        isOnBreak = true
        updateIcon(isBreak: true)
        let dur = TimeInterval(prefs.scheduleConfig.breakDurationMinutes * 60)
        updateCountdown(seconds: dur)
    }

    func exitBreakState() {
        isOnBreak = false
        updateIcon(isBreak: false)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusItem?.button?.title = self.prefs.showCountdown
                ? self.countdownText
                : ""
        }
        refreshMenu()
    }

    // MARK: - Countdown toggle

    func refreshTitle() {
        if isOnBreak {
            enterBreakState()
        } else {
            exitBreakState()
        }
    }

    // MARK: - Button Click

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let menu = appMenu else { return }
        refreshMenu()
        sender.isHighlighted = true
        let position = NSPoint(x: 0, y: sender.bounds.maxY + 2)
        menu.popUp(positioning: nil, at: position, in: sender)
    }

    // MARK: - Menu Actions

    @objc private func breakNowAction() {
        if !isOnBreak {
            BreakScheduler.shared.triggerBreakNow()
        }
    }

    @objc private func pauseAction(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        if duration == -1 {
            prefs.pauseUntilTomorrow()
        } else {
            prefs.pauseFor(duration: duration)
        }
    }

    @objc private func resumeAction() {
        prefs.resumeBreak()
    }

    @objc private func openSettingsAction() {
        appDelegate?.openSettings()
    }

    @objc private func toggleCountdownAction() {
        prefs.showCountdown.toggle()
        refreshTitle()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
