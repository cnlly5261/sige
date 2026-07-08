import Foundation
import Combine
import AppKit

/// 定时调度引擎：管理何时触发休息提醒
final class BreakScheduler: ObservableObject {
    static let shared = BreakScheduler()

    /// 距下次休息的剩余秒数
    @Published var secondsUntilNextBreak: TimeInterval = 2700 // 默认 45 分钟
    /// 是否正在工作中（计时中）
    @Published var isWorking: Bool = true

    private var timer: Timer?
    private var prefs: AppPreferences { AppPreferences.shared }
    private var lastBreakEndTime: Date = Date()
    private var lastTickTime: Date = Date()
    private var postponedUntil: Date?
    /// 预告弹窗显示中时阻止 tick 触发全屏休息
    var preReminderPanelShowing = false

    private init() {}

    // MARK: - Start / Stop

    func start() {
        lastBreakEndTime = Date()
        lastTickTime = Date()
        postponedUntil = nil
        isWorking = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Tick

    private func tick() {
        let now = Date()
        if shouldResetAfterLongIdle(now: now) {
            restartWorkCycle()
            lastTickTime = now
            return
        }
        lastTickTime = now

        // 检查暂停状态
        if prefs.isPaused {
            secondsUntilNextBreak = 9999
            MenuBarManager.shared.updateCountdown(seconds: 9999)
            return
        }

        // 如果正在休息中，不计算
        guard !BreakTimer.shared.isActive else { return }

        // 计算距下一次休息的秒数
        let nextBreak = calculateNextBreakTime(from: now)
        let remaining = nextBreak.timeIntervalSince(now)

        if remaining <= 0 {
            // 如果预告弹窗正在显示，等待用户决策，不直接全屏
            if preReminderPanelShowing { return }
            triggerBreak()
        } else {
            secondsUntilNextBreak = remaining
            MenuBarManager.shared.updateCountdown(seconds: remaining)

            // 检查是否需要提前提醒
            checkPreReminder(remaining: remaining)
        }
    }

    // MARK: - 计算下次休息时间

    private func calculateNextBreakTime(from now: Date) -> Date {
        let config = prefs.scheduleConfig

        if let postponedUntil {
            if postponedUntil > now {
                return postponedUntil
            }
            self.postponedUntil = nil
        }

        switch config.mode {
        case .timePoints:
            if let nextPoint = config.nextTimePoint(from: now) {
                return nextPoint
            }
            return now.addingTimeInterval(3600)

        case .pomodoro:
            let next = lastBreakEndTime.addingTimeInterval(
                TimeInterval(config.pomodoroWorkMinutes * 60)
            )
            return next > now ? next : now.addingTimeInterval(1)
        }
    }

    // MARK: - 提前提醒检查

    private func checkPreReminder(remaining: TimeInterval) {
        guard prefs.scheduleConfig.preReminderEnabled else { return }
        let preSeconds = TimeInterval(prefs.scheduleConfig.preReminderSeconds)

        // 剩余时间正好进入预告窗口
        if remaining <= preSeconds && remaining > preSeconds - 1 {
            // 检查是否在全屏应用中
            if prefs.skipWhenFullscreen && isFullscreenAppActive() {
                // 推迟检查
                return
            }
            triggerPreReminder()
        }
    }

    // MARK: - 触发休息

    private func triggerPreReminder() {
        preReminderPanelShowing = true
        NotificationManager.shared.sendPreReminderNotification()
        let preSeconds = prefs.scheduleConfig.preReminderSeconds
        PreReminderPanel.shared.show(seconds: preSeconds)
    }

    func triggerBreakNow() {
        preReminderPanelShowing = false
        PreReminderPanel.shared.hide()
        triggerBreak()
    }

    private func triggerBreak() {
        // 检查全屏
        if prefs.skipWhenFullscreen && isFullscreenAppActive() {
            // 推迟 5 分钟
            postpone(minutes: 5)
            return
        }

        // 发送通知
        NotificationManager.shared.sendBreakNotification()

        // 显示休息界面
        BreakOverlayCoordinator.shared.showBreakOverlay()
        BreakTimer.shared.startBreak()
    }

    // MARK: - Reset & Postpone

    func resetAfterBreak() {
        lastBreakEndTime = Date()
        postponedUntil = nil
        isWorking = true
        preReminderPanelShowing = false
    }

    func postpone(minutes: Int) {
        postponedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        isWorking = true
        preReminderPanelShowing = false
        BreakOverlayCoordinator.shared.hideOverlay()
        PreReminderPanel.shared.hide()
    }

    /// 取消预提醒或系统唤醒后，重新从完整工作时长开始倒计时。
    func restartWorkCycle() {
        lastBreakEndTime = Date()
        postponedUntil = nil
        isWorking = true
        preReminderPanelShowing = false
        BreakOverlayCoordinator.shared.hideOverlay()
        PreReminderPanel.shared.hide()

        let nextBreak = calculateNextBreakTime(from: Date())
        let remaining = max(nextBreak.timeIntervalSinceNow, 1)
        secondsUntilNextBreak = remaining
        MenuBarManager.shared.updateCountdown(seconds: remaining)
    }

    @objc private func handleSystemWake() {
        DispatchQueue.main.async { [weak self] in
            self?.restartWorkCycle()
        }
    }

    private func shouldResetAfterLongIdle(now: Date) -> Bool {
        guard !BreakTimer.shared.isActive else { return false }
        let idleGap = now.timeIntervalSince(lastTickTime)
        let workSeconds = TimeInterval(prefs.scheduleConfig.pomodoroWorkMinutes * 60)
        let threshold = max(300, min(workSeconds, 1800))
        return idleGap > threshold
    }

    // MARK: - 全屏检测

    private func isFullscreenAppActive() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let appPID = frontApp.processIdentifier

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  pid == appPID else { continue }

            // 获取窗口 bounds
            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
               let width = bounds["Width"],
               let height = bounds["Height"] {

                // 检查是否为全屏（与屏幕尺寸相近）
                if let screen = NSScreen.main {
                    let screenRect = screen.frame
                    if abs(width - screenRect.width) < 10 && abs(height - screenRect.height) < 10 {
                        return true
                    }
                }
            }
        }

        return false
    }
}
