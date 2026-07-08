import Foundation
import UserNotifications

/// 系统通知管理
/// 注意：UNUserNotificationCenter.current() 需要完整的 .app bundle 才能工作，
/// 在 swift run 裸运行时会退化处理，不影响菜单栏和休息窗口的核心功能。
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private var center: UNUserNotificationCenter?
    private var isAuthorized: Bool = false

    private override init() {
        super.init()
        // 延迟到 AppDelegate 中调用 setup()
    }

    // MARK: - Setup（在 applicationDidFinishLaunching 之后调用）

    func setup() {
        // UNUserNotificationCenter.current() 在无 bundle 时可能崩溃，做保护
        center = safeCurrentNotificationCenter()
        requestAuthorization()
    }

    // MARK: - 授权

    func requestAuthorization() {
        guard let center = center else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            self?.isAuthorized = granted
            if let error = error {
                print("[Sige] Notification auth error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 通知

    /// 发送即将休息预告通知
    func sendPreReminderNotification() {
        guard isAuthorized, let center = center else { return }

        let prefs = AppPreferences.shared
        let seconds = prefs.scheduleConfig.preReminderSeconds

        let content = UNMutableNotificationContent()
        content.title = "即将休息"
        content.body = "\(seconds) 秒后开始休息，请保存当前工作"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "sige.pre-reminder-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    /// 发送休息开始通知
    func sendBreakNotification() {
        guard isAuthorized, let center = center else { return }

        let prefs = AppPreferences.shared
        let minutes = prefs.scheduleConfig.breakDurationMinutes

        let content = UNMutableNotificationContent()
        content.title = "休息时间到"
        content.body = "休息 \(minutes) 分钟吧，站起来活动一下 ☕"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        content.categoryIdentifier = "BREAK_CATEGORY"

        let request = UNNotificationRequest(
            identifier: "sige.break-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    // MARK: - 通知类别注册

    func registerNotificationCategories() {
        guard let center = center else { return }

        let skipAction = UNNotificationAction(
            identifier: "SKIP_BREAK",
            title: "跳过",
            options: .destructive
        )

        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_BREAK",
            title: "推迟 5 分钟",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "BREAK_CATEGORY",
            actions: [postponeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    // MARK: - 安全获取 notification center

    private func safeCurrentNotificationCenter() -> UNUserNotificationCenter? {
        // 检查是否有可用的 bundle 标识符
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Sige] ⚠️ No bundle identifier — notifications disabled (running via swift run)")
            return nil
        }
        return UNUserNotificationCenter.current()
    }
}
