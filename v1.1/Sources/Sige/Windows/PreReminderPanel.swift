import SwiftUI
import AppKit

/// 提前提醒小弹窗 — 不打断桌面操作的小型浮动窗口
final class PreReminderPanel {
    static let shared = PreReminderPanel()

    private var window: NSWindow?
    private var countdownSeconds: Int = 30
    private var countdownTimer: Timer?

    private var prefs: AppPreferences { AppPreferences.shared }

    private init() {}

    // MARK: - Show / Hide

    func show(seconds: Int) {
        hide()
        countdownSeconds = seconds

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 210),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .alertPanel
        panel.center()

        let hosting = NSHostingView(rootView: PreReminderView(
            countdown: countdownSeconds,
            onStartBreak: { [weak self] in
                self?.hide()
                BreakScheduler.shared.triggerBreakNow()
            },
            onCancel: { [weak self] in
                self?.hide()
                // 跳过本次休息，重新按工作时长计时
                let mins = AppPreferences.shared.scheduleConfig.pomodoroWorkMinutes
                BreakScheduler.shared.postpone(minutes: mins)
            }
        ))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: 340, height: 210))
        panel.contentView = hosting
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)

        self.window = panel

        // 倒计时自动递减
        startCountdown()
    }

    func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        window?.close()
        window = nil
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self, self.countdownSeconds >= 0 else {
                t.invalidate()
                return
            }
            if self.countdownSeconds <= 0 {
                t.invalidate()
                // 倒计时归零 → 自动进入休息
                DispatchQueue.main.async {
                    self.hide()
                    BreakScheduler.shared.triggerBreakNow()
                }
                return
            }
            self.countdownSeconds -= 1
        }
    }
}

// MARK: - 预览弹窗 SwiftUI 视图

struct PreReminderView: View {
    let countdown: Int
    let onStartBreak: () -> Void
    let onCancel: () -> Void

    @State private var remaining: Int

    init(countdown: Int, onStartBreak: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.countdown = countdown
        self.onStartBreak = onStartBreak
        self.onCancel = onCancel
        self._remaining = State(initialValue: countdown)
    }

    var body: some View {
        ZStack {
            // 背景
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 18) {
                // 图标
                Image(systemName: "clock.badge")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)

                // 标题
                Text("break_soon".l10n)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                // 倒计时
                Text("\(remaining) \("seconds".l10n)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())

                // 按钮
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("cancel".l10n)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 100, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .keyboardShortcut(.escape, modifiers: [])

                    Button(action: onStartBreak) {
                        Text("start_break_now".l10n)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(24)
        }
        .frame(width: 340, height: 210)
        .fixedSize()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            if remaining > 0 { remaining -= 1 }
            else {
                // auto-triggered by parent
            }
        }
    }
}

// MARK: - 毛玻璃背景辅助

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
