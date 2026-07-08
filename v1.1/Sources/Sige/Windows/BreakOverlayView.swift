import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject private var coordinator = BreakOverlayCoordinator.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        ZStack {
            prefs.breakTheme.backgroundView()

            VStack(spacing: 30) {
                Spacer()
                if coordinator.isPreReminderPhase { preReminderContent }
                else { breakContent }
                Spacer()
                actionButtons.padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Pre-reminder

    private var preReminderContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            Text("break_soon".l10n)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.fontSize, weight: .medium))
                .foregroundColor(prefs.breakTheme.textColor.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("\(Int(coordinator.remainingSeconds)) \("break_start_soon".l10n)")
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.countdownFontSize, weight: .bold))
                .foregroundColor(.yellow)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("save_work".l10n)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.subtitleFontSize))
                .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut, value: coordinator.remainingSeconds)
    }

    // MARK: - Break content

    private var breakContent: some View {
        VStack(spacing: 28) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text(prefs.breakTheme.displayText)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.fontSize, weight: .medium))
                .foregroundColor(prefs.breakTheme.textColor.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)

            Text(prefs.breakTheme.subtitleText)
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: prefs.breakTheme.subtitleFontSize))
                .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

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
        let ringDiameter: CGFloat = max(prefs.breakTheme.countdownFontSize * 2.2, 140)

        return ZStack {
            Circle()
                .stroke(prefs.breakTheme.textColor.color.opacity(0.12), lineWidth: ringDiameter * 0.04)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: coordinator.totalSeconds > 0
                    ? coordinator.remainingSeconds / coordinator.totalSeconds : 0)
                .stroke(prefs.breakTheme.progressColor.color,
                        style: StrokeStyle(lineWidth: ringDiameter * 0.04, lineCap: .round))
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: coordinator.remainingSeconds)

            Text(formatTime(coordinator.remainingSeconds))
                .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName,
                      size: ringDiameter * 0.34, weight: .bold))
                .foregroundColor(prefs.breakTheme.textColor.color)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 20) {
            if coordinator.isPreReminderPhase {
                Button {
                    BreakTimer.shared.stopTimerOnly(); BreakTimer.shared.startBreak()
                    BreakOverlayCoordinator.shared.transitionToFullBreak()
                } label: {
                    Label("start_break_now".l10n, systemImage: "forward.fill")
                        .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 15))
                        .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.plain).background(Color(white: 1).opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    BreakTimer.shared.postponeBreak(minutes: 5); BreakOverlayCoordinator.shared.hideOverlay()
                } label: {
                    Label("postpone_5min".l10n, systemImage: "clock.arrow.2.circlepath")
                        .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 15))
                        .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.plain).background(Color(white: 1).opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !coordinator.isPreReminderPhase && !prefs.enforceBreak {
                Button {
                    BreakTimer.shared.skipBreak(); BreakOverlayCoordinator.shared.hideOverlay()
                } label: {
                    Label("skip_break".l10n, systemImage: "forward.end.fill")
                        .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 14))
                        .padding(.horizontal, 20).padding(.vertical, 8)
                }
                .buttonStyle(.plain).background(Color(white: 1).opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .foregroundColor(.white.opacity(0.8))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
