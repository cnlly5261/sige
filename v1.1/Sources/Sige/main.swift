import AppKit

// Sige — 纯菜单栏应用
// 手动控制 NSApplication 生命周期，避免 SwiftUI Scene / NSApplicationMain 干扰

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// 手动完成启动流程
app.finishLaunching()
app.run()
