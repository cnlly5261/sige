import Foundation

/// 定时模式
enum ScheduleMode: String, Codable, CaseIterable {
    case pomodoro   // 番茄钟（UI 显示为"间隔模式"）
    case timePoints // 按具体时间点
}

/// 定时休息配置
struct ScheduleConfig: Codable {
    /// 当前调度模式
    var mode: ScheduleMode = .pomodoro

    // MARK: - 间隔模式
    /// 工作间隔（分钟），默认 45 分钟（TODO: 恢复为 45，Slider min 恢复为 15）
    var workIntervalMinutes: Int = 45
    /// 休息时长（分钟），默认 5 分钟
    var breakDurationMinutes: Int = 5

    // MARK: - 时间点模式
    /// 具体休息时间点（HH:mm 格式，如 ["10:00", "11:30"]），已排序
    var timePoints: [String] = ["10:00", "12:00", "15:00", "17:00"]

    // MARK: - 间隔模式（原番茄钟，去掉长短休息区分）
    /// 番茄钟工作时长（分钟），默认 40
    var pomodoroWorkMinutes: Int = 40
    /// 番茄钟休息时长（分钟），默认 5
    var pomodoroShortBreakMinutes: Int = 5

    // MARK: - 通用
    /// 提前提醒秒数，0 表示不提前提醒
    var preReminderSeconds: Int = 30
    /// 是否启用提前提醒
    var preReminderEnabled: Bool = true

    // MARK: - 计算属性

    /// 工作间隔秒数
    var workIntervalSeconds: TimeInterval {
        TimeInterval(workIntervalMinutes * 60)
    }

    /// 休息时长秒数
    var breakDurationSeconds: TimeInterval {
        TimeInterval(breakDurationMinutes * 60)
    }

    /// 提前提醒秒数
    var preReminderInterval: TimeInterval {
        TimeInterval(preReminderSeconds)
    }

    /// 将 "HH:mm" 字符串解析为当天的 Date
    func nextTimePoint(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        for timeStr in timePoints {
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }

            var dateComponents = todayComponents
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0

            if let date = calendar.date(from: dateComponents), date > now {
                return date
            }
        }

        // 如果今天所有时间点都已过，返回明天的第一个时间点
        if let firstTime = timePoints.first {
            let parts = firstTime.split(separator: ":")
            if parts.count == 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]) {
                var tomorrowComponents = todayComponents
                tomorrowComponents.day = (tomorrowComponents.day ?? 0) + 1
                tomorrowComponents.hour = hour
                tomorrowComponents.minute = minute
                tomorrowComponents.second = 0
                return calendar.date(from: tomorrowComponents)
            }
        }
        return nil
    }
}
