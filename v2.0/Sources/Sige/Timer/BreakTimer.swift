import Foundation
import Combine

/// 休息倒计时：管理休息阶段的倒计时逻辑
final class BreakTimer: ObservableObject {
    static let shared = BreakTimer()

    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var isActive: Bool = false
    @Published var isPreReminder: Bool = false
    @Published var progress: Double = 1.0

    private var timer: Timer?
    private var prefs: AppPreferences { AppPreferences.shared }

    private init() {}

    // MARK: - Start / Stop

    func startBreak(duration: TimeInterval? = nil) {
        let breakDuration = duration ?? prefs.scheduleConfig.breakDurationSeconds
        stopTimer()
        totalSeconds = breakDuration
        remainingSeconds = breakDuration
        progress = 1.0
        isActive = true
        isPreReminder = false

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        MenuBarManager.shared.enterBreakState()
    }

    func startPreReminder() {
        let preSeconds = TimeInterval(prefs.scheduleConfig.preReminderSeconds)
        guard preSeconds > 0 else { return }
        stopTimer()
        totalSeconds = preSeconds
        remainingSeconds = preSeconds
        progress = 1.0
        isActive = true
        isPreReminder = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickPreReminder()
        }
    }

    /// 停止休息 — 记录统计，关闭窗口，重置调度器
    func stopBreak() {
        let elapsedBreak = isActive && !isPreReminder ? totalSeconds - remainingSeconds : 0
        stopTimer()

        if isActive && !isPreReminder {
            prefs.recordBreakCompleted(duration: elapsedBreak)
        }

        isActive = false
        isPreReminder = false
        remainingSeconds = 0
        totalSeconds = 0
        progress = 1.0

        // 关键：关闭休息覆盖窗口
        BreakOverlayCoordinator.shared.hideOverlay()
        MenuBarManager.shared.exitBreakState()
        BreakScheduler.shared.resetAfterBreak()
    }

    /// 跳过当前休息
    func skipBreak() {
        guard !prefs.enforceBreak else { return }
        stopBreak()
    }

    /// 推迟休息
    func postponeBreak(minutes: Int = 5) {
        stopTimer()
        isActive = false
        isPreReminder = false
        BreakOverlayCoordinator.shared.hideOverlay()
        MenuBarManager.shared.exitBreakState()
        BreakScheduler.shared.postpone(minutes: minutes)
    }

    /// 仅停止计时器（不记录、不关闭窗口），用于预告 → 正式休息的切换
    func stopTimerOnly() {
        stopTimer()
    }

    // MARK: - Internal

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            stopBreak()  // 倒计时归零 → 自动结束（包含 hideOverlay）
            return
        }
        remainingSeconds -= 1
        progress = remainingSeconds / max(totalSeconds, 1)
        MenuBarManager.shared.updateCountdown(seconds: remainingSeconds)
        BreakOverlayCoordinator.shared.updateRemaining(remainingSeconds)
    }

    private func tickPreReminder() {
        guard remainingSeconds > 0 else {
            stopTimer()
            startBreak()
            BreakOverlayCoordinator.shared.transitionToFullBreak()
            return
        }
        remainingSeconds -= 1
        progress = remainingSeconds / max(totalSeconds, 1)
        MenuBarManager.shared.updateCountdown(seconds: remainingSeconds)
        BreakOverlayCoordinator.shared.updatePreReminder(remainingSeconds)
    }
}

// MARK: - 休息界面协调器

final class BreakOverlayCoordinator: ObservableObject {
    static let shared = BreakOverlayCoordinator()

    @Published var showOverlay: Bool = false
    @Published var isPreReminderPhase: Bool = false
    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0

    private var windowController: BreakWindowController?
    private var prefs: AppPreferences { AppPreferences.shared }

    private init() {}

    func showPreReminder() {
        isPreReminderPhase = true
        remainingSeconds = TimeInterval(prefs.scheduleConfig.preReminderSeconds)
        totalSeconds = remainingSeconds
        showOverlay = true
        ensureWindow().showWindow()
    }

    func showBreakOverlay() {
        isPreReminderPhase = false
        remainingSeconds = prefs.scheduleConfig.breakDurationSeconds
        totalSeconds = remainingSeconds
        showOverlay = true
        ensureWindow().showWindow()
    }

    func transitionToFullBreak() {
        isPreReminderPhase = false
        remainingSeconds = prefs.scheduleConfig.breakDurationSeconds
        totalSeconds = remainingSeconds
        windowController?.updateToFullBreak()
    }

    func updateRemaining(_ seconds: TimeInterval) { remainingSeconds = seconds }
    func updatePreReminder(_ seconds: TimeInterval) { remainingSeconds = seconds }

    func hideOverlay() {
        showOverlay = false
        isPreReminderPhase = false
        remainingSeconds = 0
        windowController?.closeWindow()
        windowController = nil
    }

    private func ensureWindow() -> BreakWindowController {
        if let wc = windowController { return wc }
        let wc = BreakWindowController()
        windowController = wc
        return wc
    }
}
