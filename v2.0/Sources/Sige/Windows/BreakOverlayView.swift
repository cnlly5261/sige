import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject private var coordinator = BreakOverlayCoordinator.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        ZStack {
            prefs.breakTheme.backgroundView()

            VStack(spacing: 0) {
                Spacer()

                if coordinator.isPreReminderPhase {
                    preReminderContent
                } else {
                    breakContent
                }

                Spacer()

                actionButtons
                    .padding(.bottom, 58)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Pre-reminder

    private var preReminderContent: some View {
        VStack(spacing: 22) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 52, weight: .medium))
                .foregroundColor(.yellow.opacity(0.95))

            Text("break_soon".l10n)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.fontSize, weight: .semibold))
                .foregroundColor(prefs.breakTheme.textColor.color)
                .multilineTextAlignment(.center)

            Text("\(Int(coordinator.remainingSeconds))")
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.countdownFontSize, weight: .bold))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Text("save_work".l10n)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.subtitleFontSize))
                .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 48)
        .animation(.easeInOut, value: coordinator.remainingSeconds)
    }

    // MARK: - Break content

    private var breakContent: some View {
        VStack(spacing: 30) {
            VStack(spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(prefs.breakTheme.progressColor.color)
                    .frame(width: 82, height: 82)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                Text(prefs.breakTheme.displayText)
                    .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.fontSize, weight: .semibold))
                    .foregroundColor(prefs.breakTheme.textColor.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 48)

                Text(prefs.breakTheme.subtitleText)
                    .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.subtitleFontSize))
                    .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 56)
            }

            if prefs.breakTheme.showProgressRing {
                adaptiveRing
            } else {
                Text(formatTime(coordinator.remainingSeconds))
                    .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.countdownFontSize, weight: .bold))
                    .foregroundColor(prefs.breakTheme.textColor.color)
                    .contentTransition(.numericText())
            }
        }
        .animation(.easeInOut, value: coordinator.remainingSeconds)
    }

    // MARK: - Adaptive ring

    private var adaptiveRing: some View {
        let ringDiameter: CGFloat = max(prefs.breakTheme.countdownFontSize * 2.15, 152)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.11), lineWidth: ringDiameter * 0.045)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: coordinator.totalSeconds > 0
                    ? coordinator.remainingSeconds / coordinator.totalSeconds : 0)
                .stroke(prefs.breakTheme.progressColor.color,
                        style: StrokeStyle(lineWidth: ringDiameter * 0.045, lineCap: .round))
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))
                .shadow(color: prefs.breakTheme.progressColor.color.opacity(0.35), radius: 16)
                .animation(.linear(duration: 1), value: coordinator.remainingSeconds)

            VStack(spacing: 4) {
                Text(formatTime(coordinator.remainingSeconds))
                    .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName,
                          size: ringDiameter * 0.30, weight: .bold))
                    .foregroundColor(prefs.breakTheme.textColor.color)
                    .contentTransition(.numericText())
                Text("remaining".l10n)
                    .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            if coordinator.isPreReminderPhase {
                overlayButton("start_break_now".l10n, icon: "forward.fill", prominence: .primary) {
                    BreakTimer.shared.stopTimerOnly()
                    BreakTimer.shared.startBreak()
                    BreakOverlayCoordinator.shared.transitionToFullBreak()
                }

                overlayButton("postpone_5min".l10n, icon: "clock.arrow.2.circlepath", prominence: .secondary) {
                    BreakTimer.shared.postponeBreak(minutes: 5)
                    BreakOverlayCoordinator.shared.hideOverlay()
                }
            }

            if !coordinator.isPreReminderPhase && !prefs.enforceBreak {
                overlayButton("skip_break".l10n, icon: "forward.end.fill", prominence: .secondary) {
                    BreakTimer.shared.skipBreak()
                    BreakOverlayCoordinator.shared.hideOverlay()
                }
            }
        }
        .foregroundColor(.white)
    }

    private enum ButtonProminence: Equatable {
        case primary, secondary
    }

    private func overlayButton(_ title: String, icon: String, prominence: ButtonProminence, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 15, weight: .semibold))
                .padding(.horizontal, prominence == .primary ? 24 : 20)
                .padding(.vertical, 11)
                .background(prominence == .primary ? Color.white.opacity(0.22) : Color.white.opacity(0.11), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
