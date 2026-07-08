# Sige — Mac 定时休息提醒客户端

> 一只栖息在菜单栏的休息小助手 ☕

## 功能

- **定时提醒**：支持间隔模式（每 N 分钟）、时间点模式、🍅 番茄钟模式
- **全屏休息界面**：自定义背景（纯色/渐变/图片）、文字和样式
- **提前预告**：休息前可弹出预告，允许推迟
- **菜单栏常驻**：显示距下次休息的倒计时，单击展开菜单
- **强制休息模式**：休息时不可跳过
- **智能推迟**：检测全屏应用（会议/演示）时自动推迟
- **开机启动**：通过 SMAppService 注册登录项
- **统计面板**：每日休息次数、累计时长、历史记录

## 系统要求

- macOS 14 Sonoma 或更高版本
- Swift 5.9+

## 构建

```bash
cd prototypes/sige
swift build
```

## 运行

```bash
swift run
```

应用启动后，菜单栏会出现 ☕ 图标和倒计时。

## 项目结构

```
prototypes/sige/
├── Package.swift
├── Resources/Info.plist
├── Sources/Sige/
│   ├── SigeApp.swift              # 入口
│   ├── AppDelegate.swift          # 生命周期 & 通知代理
│   ├── MenuBar/MenuBarManager.swift  # 菜单栏
│   ├── Timer/BreakScheduler.swift    # 调度引擎
│   ├── Timer/BreakTimer.swift        # 休息倒计时
│   ├── Windows/BreakWindow.swift     # 全屏窗口
│   ├── Windows/BreakOverlayView.swift # 休息界面
│   ├── Windows/SettingsView.swift    # 设置面板
│   ├── Models/ScheduleConfig.swift   # 调度配置
│   ├── Models/BreakTheme.swift       # 主题配置
│   ├── Models/AppPreferences.swift   # 全局偏好 & 统计
│   └── Utils/
│       ├── LaunchAtLogin.swift       # 开机启动
│       └── NotificationManager.swift # 系统通知
└── README.md
```

## 许可

MIT
