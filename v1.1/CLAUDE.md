# Sige — Mac 休息提醒助手

> **Slogan**: 息止屏幕，界守双眼 / Rest the screen. Shield the eyes.
>
> **产品页**: https://sige-break-reminder.surge.sh

## 项目概述

Sige 是一款 macOS 菜单栏应用，定时提醒用户休息眼睛。纯原生 SwiftUI + AppKit 实现，零第三方依赖。支持间隔/时间点两种调度模式，小型浮动预告弹窗（不打断操作），全屏休息覆盖界面，8 种内置音效，中英文切换。

| 属性 | 值 |
|------|-----|
| 语言 | Swift 5.9+ |
| 框架 | SwiftUI + AppKit |
| 最低系统 | macOS 14.0 Sonoma |
| 构建工具 | Swift Package Manager (`swift build` / `swift run`) |
| 安装包 | DMG (2.1 MB) |
| 架构 | arm64 (Apple Silicon) + Intel (Universal) |
| 许可证 | 免费使用 |
| 图标 | 蓝紫渐变圆角背景 + 白色咖啡杯 SF Symbol |
| 联系方式 | caoruihua@gmail.com |

## 项目结构

```
prototypes/sige/
├── Package.swift                     # SPM 包定义 (macOS .v14 target)
├── CLAUDE.md                         # 本文档
├── Resources/
│   └── Info.plist                    # LSUIElement=true, bundle ID
├── Sources/Sige/
│   ├── main.swift                    # 入口：纯 AppKit NSApplication 启动
│   ├── SigeApp.swift                 # @main 占位（实际由 main.swift 启动）
│   ├── AppDelegate.swift             # NSApplicationDelegate，持有设置窗口和休息窗口引用
│   ├── MenuBar/
│   │   └── MenuBarManager.swift      # NSStatusItem 菜单栏图标+倒计时+下拉菜单
│   ├── Timer/
│   │   ├── BreakScheduler.swift      # 定时调度引擎（间隔模式/时间点模式）
│   │   └── BreakTimer.swift          # 休息倒计时 + BreakOverlayCoordinator
│   ├── Windows/
│   │   ├── SettingsView.swift        # 设置面板（4 个标签页）
│   │   ├── BreakOverlayView.swift    # 全屏休息覆盖视图
│   │   ├── BreakWindow.swift         # 全屏 NSWindow + IOPMAssertion 屏幕保护阻止
│   │   └── PreReminderPanel.swift    # 提前提醒浮动弹窗（NSPanel，不打断操作）
│   ├── Models/
│   │   ├── ScheduleConfig.swift      # 定时配置（间隔模式/时间点模式）
│   │   ├── BreakTheme.swift          # 休息界面主题（背景/文字/颜色/字体/进度环）
│   │   └── AppPreferences.swift      # 全局偏好（UserDefaults 持久化）
│   └── Utils/
│       ├── L10n.swift                # 中英文国际化（运行时切换）
│       ├── SoundManager.swift        # DLS 采样器 + 混响音效引擎 + MP3 播放
│       ├── SoundCatalog.swift        # 内置曲目 + 用户自定义 MP3 目录
│       ├── LaunchAtLogin.swift       # SMAppService 开机启动
│       └── NotificationManager.swift # UNUserNotificationCenter 系统通知
├── build/
│   ├── Sige-1.1.dmg                 # 最终 DMG 安装包
│   └── product-page/
│       ├── index.html                # 产品介绍 H5 页面（中英文）
│       └── Sige-1.1.dmg              # 下载用的 DMG 副本
└── .claude/settings.json             # 项目权限配置
```

## 架构设计

### 启动流程

```
main.swift → NSApplication.shared
          → AppDelegate.applicationDidFinishLaunching()
              ├── MenuBarManager.setup()     // 创建 NSStatusItem
              ├── BreakScheduler.start()     // 启动定时器
              └── NotificationManager.setup()
          → app.run()
```

### 核心数据流

```
设置面板 (SettingsView)
  ↓ UserDefaults + @Published
AppPreferences / ScheduleConfig / BreakTheme
  ↓ 读取
BreakScheduler (每秒 tick 检查)
  ↓ 提前提醒
PreReminderPanel (小型浮动弹窗，不播音乐)
  ↓ 用户点击开始 / 倒计时归零
BreakWindow (全屏 NSWindow)
  ↓ 用户跳过 / 倒计时归零
BreakTimer.stopBreak() → 关闭窗口 → 记录统计
```

### 关键设计决策

1. **纯 AppKit 启动**：`main.swift` 手动初始化 `NSApplication` 并调用 `finishLaunching()` + `run()`，而非使用 SwiftUI `@main App` 协议。这是因为 SwiftUI `Settings` Scene 会干扰 `NSStatusItem` 的点击事件路由（macOS 14 已知问题）。

2. **菜单栏手动弹出**：不依赖 `statusItem.menu`（macOS 14 bug），改为 `button.action` + `menu.popUp()` 手动弹出。

3. **单例模式**：`MenuBarManager`、`BreakScheduler`、`BreakTimer`、`BreakOverlayCoordinator`、`SoundManager`、`AppPreferences` 均使用 `static let shared` 单例。

4. **DLS 音源**：使用 macOS 内置 Roland GS Sound Set (`/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls`) + `AVAudioUnitSampler` + `AVAudioUnitReverb` (.largeHall) 实时合成音乐，无需外部音频文件。

5. **系统音量跟随**：通过 CoreAudio `AudioObjectGetPropertyData` 读取默认输出设备音量 + `AudioObjectAddPropertyListenerBlock` 实时监听音量变化。

6. **预告弹窗防全屏**：`BreakScheduler.preReminderPanelShowing` 标记在预提醒弹窗显示期间阻止 `tick()` 触发全屏休息，避免弹窗等待用户决策时被全屏覆盖。

7. **Data Race 保护**：所有 UI 更新通过 `DispatchQueue.main.async` 派发到主线程。

## 构建与运行

```bash
# 开发调试
cd prototypes/sige
swift build          # 编译
swift run            # 运行（菜单栏应用）

# Release 构建
swift build -c release
cp .build/arm64-apple-macosx/release/Sige build/dmg/Sige.app/Contents/MacOS/Sige

# 打包 DMG
# 1. 复制 Sige.app 到 build/staging/
# 2. ln -s /Applications build/staging/Applications
# 3. hdiutil create -srcfolder build/staging -format UDZO -o build/Sige-1.1.dmg
```

`swift run` 时通知功能不可用（无 `.app` Bundle），但菜单栏、休息窗口、设置面板等核心功能正常。

## 功能模块详解

### 调度模式
- **间隔模式** (pomodoro)：工作 N 分钟 → 休息 M 分钟，默认 40 分钟工作 + 5 分钟休息，可调 1–120 分钟
- **时间点模式** (timePoints)：指定具体时间点，如 10:00、14:00
- 无长短休息区分，每轮工作→休息→工作循环一致

### 提前提醒
- PreReminderPanel: 小型浮动 NSPanel (nonactivatingPanel)，不抢焦点不打断操作
- 可拖拽移动，毛玻璃背景
- 按键支持: Enter = 开始休息，Esc = 取消
- 提醒期间不播放音乐
- 点「取消」则按工作时长重新倒数，跳过本次休息

### 休息界面
- 全屏覆盖窗口（`CGWindowLevelForKey(.maximumWindow) + 1`）
- 自定义背景（纯色/渐变/本地图片）
- 自定义文字、字体、字号、颜色
- 进度环自适应大小（环直径 = 倒计时字号 × 2.2）
- IOKit `IOPMAssertion` 阻止显示器休眠

### 音效
- 8 种内置乐器：钢琴、铺底、竖琴、长笛、八音盒、铃音、吉他、弦乐
- 每首有独特的和声进行（五声音阶 + 自然和弦）
- 混响效果器 `.largeHall`，wetDryMix 35%
- 支持 MP3/M4A/WAV 自定义音频文件
- 试听按钮（4 秒预览自动停止）
- 音量实时跟随系统音量

### 菜单栏
- 纯色 SF Symbol 图标（`isTemplate = true`），自动适配深色/浅色模式
- 图标旁显示倒计时（可隐藏）
- 下拉菜单：立即休息、暂停、倒计时开关、设置、退出

### 国际化
- `AppLanguage` 枚举：`.chinese` / `.english`
- 字典查找模式 `"key".l10n`，覆盖菜单、设置面板、休息界面
- 运行时切换无需重启

## 安全与隐私

- 纯本地运行，无网络请求
- 无数据收集，无第三方 SDK
- UserDefaults 仅存储用户偏好
- SMAppService 仅用于开机启动

## 外部资源

| 资源 | URL |
|------|-----|
| H5 产品页 | https://sige-break-reminder.surge.sh |
| 联系方式 | caoruihua@gmail.com |
