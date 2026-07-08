import Foundation
import ServiceManagement

/// 开机启动管理
enum LaunchAtLogin {
    /// 是否已启用开机启动
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // 回退方案：检查 LaunchAgent plist
            return legacyIsEnabled()
        }
    }

    /// 设置开机启动
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Sige] SMAppService error: \(error.localizedDescription)")
                // 回退到 Legacy 方案
                legacySetEnabled(enabled)
            }
        } else {
            legacySetEnabled(enabled)
        }
    }

    // MARK: - Legacy Support (macOS < 13)

    private static let launchAgentPlist = "com.sige.breakreminder.plist"

    private static var launchAgentPath: URL? {
        let library = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        return library.appendingPathComponent(launchAgentPlist)
    }

    private static func legacyIsEnabled() -> Bool {
        guard let path = launchAgentPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    private static func legacySetEnabled(_ enabled: Bool) {
        guard let path = launchAgentPath else { return }

        if enabled {
            // 获取当前可执行文件路径
            let executablePath = Bundle.main.executablePath ?? ""
            guard !executablePath.isEmpty else { return }

            let plist: [String: Any] = [
                "Label": "com.sige.breakreminder",
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]

            try? (plist as NSDictionary).write(to: path)

        } else {
            try? FileManager.default.removeItem(at: path)
        }
    }
}
