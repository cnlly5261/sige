# Sige — Mac 休息提醒助手

> 息止屏幕，界守双眼 / Rest the screen. Shield the eyes.

Sige 是一个常驻 macOS 菜单栏的休息提醒工具。它使用原生 SwiftUI + AppKit 实现，支持间隔提醒、时间点提醒、提前预告、全屏休息界面、音效、统计和中英文切换。

## 当前版本状态

- 当前工作目录：`v2.0/`
- 旧版本归档：`../v1.1/`
- 产品页：https://sige-break-reminder.surge.sh
- 下载包：`build/Sige-2.0.dmg`
- H5 发布目录：`build/product-page/`
- 最新已知 SHA256：`52493e3bd6e84ccfb1fce154dcec498aadf934ad00b94887c8e4b7559e3e8486`

## 功能

- **菜单栏常驻**：显示倒计时，可立即休息、暂停、恢复、打开设置。
- **定时提醒**：支持间隔模式和固定时间点模式。
- **提前预告**：休息前弹出轻量浮窗，允许立即开始或推迟。
- **全屏休息**：可自定义背景、文字、字体、字号、进度环和音效。
- **行为控制**：支持强制休息、全屏应用自动推迟、开机启动。
- **统计面板**：记录今日休息次数、累计休息、工作时长和最近历史。
- **本地隐私**：无账号、无网络请求、无第三方 SDK。

## 开发运行

```bash
cd /Users/peter/Documents/Workspace/Product/sige/v2.0
swift build
swift run
```

如果 SwiftPM 在 Codex 或受限环境里遇到缓存权限问题，可使用：

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build --disable-sandbox
```

`swift run` 不会生成完整 `.app` Bundle，因此通知和安装包相关行为需要通过 DMG 测试。

## 打包发布

1. 构建 release：

```bash
cd /Users/peter/Documents/Workspace/Product/sige/v2.0
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift build -c release --disable-sandbox
```

2. 生成 DMG：

```bash
bash build/build-dmg.sh
```

脚本会：

- 复制 release 二进制到 `build/staging/Sige.app`
- 写入 `Info.plist`
- 清理扩展属性
- 对 App 做 ad-hoc 签名
- 验证签名结构
- 生成 `build/Sige-2.0.dmg`
- 复制到 `build/product-page/Sige-2.0.dmg`

3. 更新 H5 中的包大小和 SHA256：

```bash
ls -lh build/Sige-2.0.dmg build/product-page/Sige-2.0.dmg
shasum -a 256 build/Sige-2.0.dmg build/product-page/Sige-2.0.dmg
```

把结果同步到 `build/product-page/index.html` 的下载区。

4. 部署 H5：

```bash
surge build/product-page sige-break-reminder.surge.sh
```

5. 线上校验：

```bash
curl -I https://sige-break-reminder.surge.sh/Sige-2.0.dmg
```

确认 `etag` 与本地 SHA256 一致，`content-length` 与安装包大小接近。

## 签名与 Gatekeeper

当前安装包使用 ad-hoc 签名，只能保证 Bundle 内部签名结构有效，不能通过 Apple Gatekeeper 的开发者验证。

用户从网页下载后，浏览器会添加 `com.apple.quarantine` 隔离属性，因此 macOS 可能提示：

- “无法验证开发者”
- “未打开 Sige”

临时打开方式：

- 右键 Sige，选择“打开”
- 或执行：

```bash
xattr -dr com.apple.quarantine /Applications/Sige.app
```

公开分发要彻底消除提示，需要 Apple Developer ID 签名和 notarize 公证。本机目前没有可用签名证书，`security find-identity -v -p codesigning` 显示 `0 valid identities found`。

## 正式公证流程占位

拿到 Apple Developer ID 后，发布流程应升级为：

```bash
codesign --force --deep --options runtime --sign "Developer ID Application: <Name> (<TeamID>)" build/staging/Sige.app
hdiutil create -srcfolder build/staging -volname "Sige" -format UDZO -o build/Sige-2.0.dmg
xcrun notarytool submit build/Sige-2.0.dmg --apple-id "<apple-id>" --team-id "<team-id>" --password "<app-specific-password>" --wait
xcrun stapler staple build/Sige-2.0.dmg
spctl --assess --type open --verbose build/Sige-2.0.dmg
```

## 目录结构

```text
v2.0/
├── Package.swift
├── README.md
├── CLAUDE.md
├── Resources/
│   └── Info.plist
├── Sources/Sige/
│   ├── AppDelegate.swift
│   ├── MenuBar/
│   ├── Models/
│   ├── Timer/
│   ├── Utils/
│   └── Windows/
└── build/
    ├── build-dmg.sh
    ├── icon-gen/
    ├── product-page/
    │   ├── index.html
    │   ├── AppIcon.png
    │   └── Sige-2.0.dmg
    └── Sige-2.0.dmg
```

## 持续迭代注意

- `v1.1/` 只作为历史归档，后续不要修改。
- 客户端 UI 文案统一在 `Sources/Sige/Utils/L10n.swift`。
- H5 文案和样式集中在 `build/product-page/index.html`。
- 预提醒取消应调用 `BreakScheduler.restartWorkCycle()`，避免把工作时长叠加两次。
- 短时推迟使用 `postponedUntil`，不要通过移动 `lastBreakEndTime` 实现。
- 电脑合盖/睡眠后再次唤醒会重置工作周期，避免倒计时长期停在 0。
- 每次客户端改动后都要重新跑 release build 和 DMG 打包。
- 每次 DMG 更新后都要同步 H5 的大小和 SHA256，再部署 Surge。
