import Foundation
import Combine

/// 全局应用偏好设置
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    // MARK: - 发布属性

    @Published var scheduleConfig: ScheduleConfig {
        didSet { saveScheduleConfig() }
    }

    @Published var breakTheme: BreakTheme {
        didSet { saveBreakTheme() }
    }

    // MARK: - 统计

    /// 今日休息次数
    @Published var todayBreakCount: Int {
        didSet { defaults.set(todayBreakCount, forKey: Keys.todayBreakCount) }
    }

    /// 今日累计休息时间（秒）
    @Published var todayTotalBreakSeconds: TimeInterval {
        didSet { defaults.set(todayTotalBreakSeconds, forKey: Keys.todayTotalBreakSeconds) }
    }

    /// 今日工作开始时间
    @Published var todayWorkStartTime: Date? {
        didSet { defaults.set(todayWorkStartTime, forKey: Keys.todayWorkStartTime) }
    }

    /// 强制休息模式（休息时不可跳过）
    @Published var enforceBreak: Bool {
        didSet { defaults.set(enforceBreak, forKey: Keys.enforceBreak) }
    }

    /// 全屏应用时自动推迟
    @Published var skipWhenFullscreen: Bool {
        didSet { defaults.set(skipWhenFullscreen, forKey: Keys.skipWhenFullscreen) }
    }

    /// 菜单栏是否显示倒计时
    @Published var showCountdown: Bool {
        didSet { defaults.set(showCountdown, forKey: Keys.showCountdown) }
    }

    /// 休息时阻止屏幕保护 / 显示器休眠（默认开启）
    @Published var preventScreenSaver: Bool {
        didSet { defaults.set(preventScreenSaver, forKey: Keys.preventScreenSaver) }
    }

    /// 界面语言
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    /// 休息时播放的音效
    @Published var breakSound: BreakSound {
        didSet { defaults.set(breakSound.rawValue, forKey: Keys.breakSound) }
    }

    /// 暂停直到指定时间 (nil = 未暂停)
    @Published var pausedUntil: Date? {
        didSet { defaults.set(pausedUntil, forKey: Keys.pausedUntil) }
    }

    /// 番茄钟已完成次数（当前轮）
    @Published var pomodoroCompletedCount: Int {
        didSet { defaults.set(pomodoroCompletedCount, forKey: Keys.pomodoroCompletedCount) }
    }

    /// 每日目标休息次数
    @Published var dailyBreakGoal: Int {
        didSet { defaults.set(dailyBreakGoal, forKey: Keys.dailyBreakGoal) }
    }

    /// 统计记录（最近7天）
    @Published var historyRecords: [DailyStats] {
        didSet { saveHistory() }
    }

    // MARK: - 初始化

    private init() {
        // 加载调度配置
        if let data = defaults.data(forKey: Keys.scheduleConfig),
           let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.scheduleConfig = config
        } else {
            self.scheduleConfig = ScheduleConfig()
        }

        // 加载主题
        if let data = defaults.data(forKey: Keys.breakTheme),
           let theme = try? JSONDecoder().decode(BreakTheme.self, from: data) {
            self.breakTheme = theme
        } else {
            self.breakTheme = BreakTheme()
        }

        // 加载统计
        self.todayBreakCount = defaults.integer(forKey: Keys.todayBreakCount)
        self.todayTotalBreakSeconds = defaults.double(forKey: Keys.todayTotalBreakSeconds)
        self.todayWorkStartTime = defaults.object(forKey: Keys.todayWorkStartTime) as? Date
        self.enforceBreak = defaults.bool(forKey: Keys.enforceBreak)
        self.skipWhenFullscreen = defaults.bool(forKey: Keys.skipWhenFullscreen)
        self.showCountdown = defaults.object(forKey: Keys.showCountdown) == nil
            ? true
            : defaults.bool(forKey: Keys.showCountdown)
        self.preventScreenSaver = defaults.object(forKey: Keys.preventScreenSaver) == nil
            ? true
            : defaults.bool(forKey: Keys.preventScreenSaver)
        let langRaw = defaults.string(forKey: Keys.language) ?? ""
        self.language = AppLanguage(rawValue: langRaw) ?? .chinese
        let soundRaw = defaults.string(forKey: Keys.breakSound) ?? ""
        self.breakSound = BreakSound(rawValue: soundRaw) ?? .none
        self.pausedUntil = defaults.object(forKey: Keys.pausedUntil) as? Date
        self.pomodoroCompletedCount = defaults.integer(forKey: Keys.pomodoroCompletedCount)
        self.dailyBreakGoal = defaults.integer(forKey: Keys.dailyBreakGoal)

        if let data = defaults.data(forKey: Keys.historyRecords),
           let records = try? JSONDecoder().decode([DailyStats].self, from: data) {
            self.historyRecords = records
        } else {
            self.historyRecords = []
        }

        // 如果日期变化则重置每日统计
        checkAndResetDailyStats()
    }

    // MARK: - 保存方法

    private func saveScheduleConfig() {
        if let data = try? JSONEncoder().encode(scheduleConfig) {
            defaults.set(data, forKey: Keys.scheduleConfig)
        }
    }

    private func saveBreakTheme() {
        if let data = try? JSONEncoder().encode(breakTheme) {
            defaults.set(data, forKey: Keys.breakTheme)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyRecords) {
            defaults.set(data, forKey: Keys.historyRecords)
        }
    }

    // MARK: - 每日重置

    private func checkAndResetDailyStats() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: Keys.lastDailyReset) as? Date ?? Date.distantPast

        if Calendar.current.compare(lastReset, to: today, toGranularity: .day) != .orderedSame {
            // 保存昨天的统计
            let yesterdayStats = DailyStats(
                date: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                breakCount: todayBreakCount,
                totalBreakSeconds: todayTotalBreakSeconds
            )

            // 保留最近 30 天
            var records = historyRecords.filter {
                Calendar.current.dateComponents([.day], from: $0.date, to: today).day ?? 0 <= 30
            }
            records.append(yesterdayStats)
            historyRecords = records
            saveHistory()

            // 重置当日
            todayBreakCount = 0
            todayTotalBreakSeconds = 0
            todayWorkStartTime = nil
            defaults.set(today, forKey: Keys.lastDailyReset)
        }

        if todayWorkStartTime == nil {
            todayWorkStartTime = Date()
        }
    }

    // MARK: - 便捷方法

    /// 记录一次休息完成
    func recordBreakCompleted(duration: TimeInterval) {
        todayBreakCount += 1
        todayTotalBreakSeconds += duration

        if scheduleConfig.mode == .pomodoro {
            pomodoroCompletedCount += 1
        }
    }

    /// 是否处于暂停状态
    var isPaused: Bool {
        guard let pausedUntil = pausedUntil else { return false }
        return pausedUntil > Date()
    }

    /// 取消暂停
    func resumeBreak() {
        pausedUntil = nil
    }

    /// 暂停指定时长（秒）
    func pauseFor(duration: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(duration)
    }

    /// 暂停到明天
    func pauseUntilTomorrow() {
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
        pausedUntil = tomorrow
    }
}

// MARK: - UserDefaults Keys

private enum Keys {
    static let scheduleConfig = "ScheduleConfig"
    static let breakTheme = "BreakTheme"
    static let todayBreakCount = "TodayBreakCount"
    static let todayTotalBreakSeconds = "TodayTotalBreakSeconds"
    static let todayWorkStartTime = "TodayWorkStartTime"
    static let enforceBreak = "EnforceBreak"
    static let skipWhenFullscreen = "SkipWhenFullscreen"
    static let showCountdown = "ShowCountdown"
    static let preventScreenSaver = "PreventScreenSaver"
    static let language = "Language"
    static let breakSound = "BreakSound"
    static let pausedUntil = "PausedUntil"
    static let pomodoroCompletedCount = "PomodoroCompletedCount"
    static let dailyBreakGoal = "DailyBreakGoal"
    static let historyRecords = "HistoryRecords"
    static let lastDailyReset = "LastDailyReset"
}

// MARK: - 每日统计

/// 每日统计记录
struct DailyStats: Codable, Identifiable {
    var id: String { Self.dateFormatter.string(from: date) }
    var date: Date
    var breakCount: Int
    var totalBreakSeconds: TimeInterval

    var formattedDate: String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }

    var formattedTotalDuration: String {
        let minutes = Int(totalBreakSeconds / 60)
        return "\(minutes) 分钟"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
