import SwiftUI
import AppKit

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var selectedSection: SettingsSection? = .schedule

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar

            Divider()

            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsHeader(section: currentSection)

                        switch currentSection {
                        case .schedule:
                            ScheduleSettingsView(prefs: prefs)
                        case .rest:
                            ThemeSettingsView(prefs: prefs)
                        case .sound:
                            SoundSettingsView(prefs: prefs)
                        case .behavior:
                            BehaviorSettingsView(prefs: prefs)
                        case .stats:
                            StatsView(prefs: prefs)
                        case .about:
                            AboutSettingsView()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 760, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private var currentSection: SettingsSection {
        selectedSection ?? .schedule
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(currentSection == section ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(currentSection == section ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 190)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case schedule, rest, sound, behavior, stats, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "tab_schedule".l10n
        case .rest: return "tab_rest".l10n
        case .sound: return "tab_sound".l10n
        case .behavior: return "tab_behavior".l10n
        case .stats: return "tab_stats".l10n
        case .about: return "about".l10n
        }
    }

    var subtitle: String {
        switch self {
        case .schedule: return "section_schedule_subtitle".l10n
        case .rest: return "section_rest_subtitle".l10n
        case .sound: return "section_sound_subtitle".l10n
        case .behavior: return "section_behavior_subtitle".l10n
        case .stats: return "section_stats_subtitle".l10n
        case .about: return "section_about_subtitle".l10n
        }
    }

    var icon: String {
        switch self {
        case .schedule: return "clock"
        case .rest: return "sparkles"
        case .sound: return "waveform"
        case .behavior: return "switch.2"
        case .stats: return "chart.bar.xaxis"
        case .about: return "info.circle"
        }
    }
}

struct SettingsHeader: View {
    let section: SettingsSection

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: section.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 46, height: 46)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.system(size: 28, weight: .semibold))
                Text(section.subtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 132, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Schedule

struct ScheduleSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var newTimePoint: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("schedule_mode".l10n, subtitle: "schedule_mode_hint".l10n) {
                Picker("", selection: $prefs.scheduleConfig.mode) {
                    ForEach(ScheduleMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if prefs.scheduleConfig.mode == .pomodoro {
                    SliderSettingRow(
                        "work_duration".l10n,
                        value: Binding(
                            get: { Double(prefs.scheduleConfig.pomodoroWorkMinutes) },
                            set: { prefs.scheduleConfig.pomodoroWorkMinutes = Int($0) }
                        ),
                        range: 1...120,
                        suffix: "minutes".l10n
                    )
                } else {
                    timePointEditor
                }
            }

            SettingsCard("break_duration".l10n, subtitle: "break_duration_hint".l10n) {
                SliderSettingRow(
                    "break_duration".l10n,
                    value: Binding(
                        get: { Double(prefs.scheduleConfig.breakDurationMinutes) },
                        set: { prefs.scheduleConfig.breakDurationMinutes = Int($0) }
                    ),
                    range: 1...30,
                    suffix: "minutes".l10n
                )
            }

            SettingsCard("pre_reminder".l10n, subtitle: "pre_reminder_hint".l10n) {
                Toggle("enable_pre_reminder".l10n, isOn: $prefs.scheduleConfig.preReminderEnabled)
                if prefs.scheduleConfig.preReminderEnabled {
                    SettingsDivider()
                    SliderSettingRow(
                        "pre_n_sec".l10n,
                        value: Binding(
                            get: { Double(prefs.scheduleConfig.preReminderSeconds) },
                            set: { prefs.scheduleConfig.preReminderSeconds = Int($0) }
                        ),
                        range: 5...120,
                        suffix: "seconds".l10n
                    )
                }
            }
        }
    }

    private var timePointEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(prefs.scheduleConfig.timePoints, id: \.self) { timePoint in
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(timePoint)
                            .font(.system(.callout, design: .monospaced))
                        Spacer(minLength: 4)
                        Button {
                            prefs.scheduleConfig.timePoints.removeAll { $0 == timePoint }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                TextField("HH:mm", text: $newTimePoint)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("add".l10n) { addTimePoint() }
                    .disabled(!validTP(newTimePoint))
            }
        }
    }

    private func addTimePoint() {
        let time = newTimePoint.trimmingCharacters(in: .whitespaces)
        guard validTP(time), !prefs.scheduleConfig.timePoints.contains(time) else { return }
        prefs.scheduleConfig.timePoints.append(time)
        prefs.scheduleConfig.timePoints.sort()
        newTimePoint = ""
    }

    private func validTP(_ value: String) -> Bool {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return false }
        return true
    }

}

struct SliderSettingRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) {
        self.label = label
        self._value = value
        self.range = range
        self.suffix = suffix
    }

    var body: some View {
        SettingsRow(label: label) {
            HStack(spacing: 14) {
                Slider(value: $value, in: range, step: 1)
                Text("\(Int(value)) \(suffix)")
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 88, alignment: .trailing)
            }
        }
    }
}

extension ScheduleMode {
    var displayName: String {
        switch self {
        case .pomodoro: return "interval_mode".l10n
        case .timePoints: return "timepoint_mode".l10n
        }
    }
}

// MARK: - Rest Appearance

struct ThemeSettingsView: View {
    @ObservedObject var prefs: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("background".l10n, subtitle: "background_hint".l10n) {
                Picker("bg_type".l10n, selection: $prefs.breakTheme.backgroundType) {
                    Text("solid_color".l10n).tag(BreakTheme.BackgroundType.solidColor)
                    Text("gradient".l10n).tag(BreakTheme.BackgroundType.gradient)
                    Text("image".l10n).tag(BreakTheme.BackgroundType.image)
                }
                .pickerStyle(.segmented)

                switch prefs.breakTheme.backgroundType {
                case .solidColor:
                    ColorPickerRow(label: "select_color".l10n, color: Binding(
                        get: { prefs.breakTheme.solidColor.nsColor },
                        set: { prefs.breakTheme.solidColor = .from(nsColor: $0) }
                    ))
                case .gradient:
                    ColorPickerRow(label: "gradient_start".l10n, color: Binding(
                        get: { prefs.breakTheme.gradientStartColor.nsColor },
                        set: { prefs.breakTheme.gradientStartColor = .from(nsColor: $0) }
                    ))
                    ColorPickerRow(label: "gradient_end".l10n, color: Binding(
                        get: { prefs.breakTheme.gradientEndColor.nsColor },
                        set: { prefs.breakTheme.gradientEndColor = .from(nsColor: $0) }
                    ))
                case .image:
                    imagePickerRow
                }
            }

            SettingsCard("text_style".l10n, subtitle: "text_style_hint".l10n) {
                SettingsRow(label: "title_text".l10n) {
                    TextField("title_text".l10n, text: $prefs.breakTheme.displayText)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsRow(label: "subtitle_text".l10n) {
                    TextField("subtitle_text".l10n, text: $prefs.breakTheme.subtitleText)
                        .textFieldStyle(.roundedBorder)
                }
                FontPickerRow(label: "font_style".l10n, selection: $prefs.breakTheme.textFontName)
                SizeSettingRow("title_size".l10n, value: $prefs.breakTheme.fontSize, range: 20...64, step: 2)
                SizeSettingRow("subtitle_size".l10n, value: $prefs.breakTheme.subtitleFontSize, range: 12...36, step: 2)
                SizeSettingRow("countdown_size".l10n, value: $prefs.breakTheme.countdownFontSize, range: 36...120, step: 4)
            }

            SettingsCard("preview".l10n, subtitle: "preview_hint".l10n) {
                ZStack {
                    prefs.breakTheme.backgroundView()
                    VStack(spacing: 8) {
                        Text(prefs.breakTheme.displayText)
                            .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: min(prefs.breakTheme.fontSize, 24), weight: .semibold))
                            .foregroundColor(prefs.breakTheme.textColor.color)
                        Text("08:42")
                            .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: 42, weight: .bold))
                            .foregroundColor(prefs.breakTheme.textColor.color)
                        Text(prefs.breakTheme.subtitleText)
                            .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: min(prefs.breakTheme.subtitleFontSize, 15)))
                            .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.72))
                    }
                    .padding()
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var imagePickerRow: some View {
        HStack {
            Text(prefs.breakTheme.backgroundImagePath.isEmpty ? "no_image".l10n : (prefs.breakTheme.backgroundImagePath as NSString).lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(prefs.breakTheme.backgroundImagePath.isEmpty ? .secondary : .primary)
            Spacer()
            Button("choose_image".l10n) { chooseImage() }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                prefs.breakTheme.backgroundImagePath = url.path
            }
        }
    }

}

struct SizeSettingRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat

    init(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        SettingsRow(label: label) {
            HStack(spacing: 14) {
                Slider(value: $value, in: range, step: step)
                Text("\(Int(value))pt")
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }
}

// MARK: - Sound

struct SoundSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var previewSound: BreakSound? = nil
    @State private var isPreviewPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("sound_system".l10n, subtitle: "sound_system_hint".l10n) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(BreakSound.builtInCases, id: \.self) { sound in
                        soundRow(sound)
                    }
                }
            }

            SettingsCard("custom_sound".l10n, subtitle: "custom_sound_hint".l10n) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    Text("drop_mp3_hint".l10n)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("open_folder".l10n) {
                        NSWorkspace.shared.open(SoundCatalog.userSoundsDir)
                    }
                }
            }
        }
    }

    private func soundRow(_ sound: BreakSound) -> some View {
        let isSelected = prefs.breakSound == sound
        let isCached = SoundManager.shared.isCached(sound)
        let isPreviewing = isPreviewPlaying && previewSound == sound

        return HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.45))

            VStack(alignment: .leading, spacing: 2) {
                Text(sound.displayName)
                    .fontWeight(isSelected ? .semibold : .regular)
                if sound != .none && !isCached {
                    Text("click_to_download".l10n)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if sound != .none {
                Button {
                    togglePreview(sound)
                } label: {
                    Image(systemName: isPreviewing ? "stop.fill" : "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isPreviewing ? .orange : .accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            prefs.breakSound = sound
            SoundManager.shared.stop()
            isPreviewPlaying = false
            previewSound = nil
        }
    }

    private func togglePreview(_ sound: BreakSound) {
        if isPreviewPlaying && previewSound == sound {
            SoundManager.shared.stop()
            isPreviewPlaying = false
            previewSound = nil
        } else {
            SoundManager.shared.stop()
            SoundManager.shared.preview(sound)
            isPreviewPlaying = true
            previewSound = sound
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                if previewSound == sound {
                    isPreviewPlaying = false
                    previewSound = nil
                }
            }
        }
    }
}

// MARK: - Behavior

struct BehaviorSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("startup".l10n, subtitle: "startup_hint".l10n) {
                Toggle("launch_at_login".l10n, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, isEnabled in LaunchAtLogin.setEnabled(isEnabled) }
                    .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
            }

            SettingsCard("behavior".l10n, subtitle: "behavior_hint".l10n) {
                Toggle("enforce_break".l10n, isOn: $prefs.enforceBreak)
                Toggle("skip_fullscreen".l10n, isOn: $prefs.skipWhenFullscreen)
                Toggle("prevent_screensaver".l10n, isOn: $prefs.preventScreenSaver)
                Text("screensaver_hint".l10n)
                    .font(.caption)
                    .foregroundColor(.secondary)
                SettingsDivider()
                Stepper("\("daily_goal".l10n): \(prefs.dailyBreakGoal) \("break_count".l10n)", value: $prefs.dailyBreakGoal, in: 1...50)
            }

            SettingsCard("language".l10n, subtitle: "language_hint".l10n) {
                Picker("language".l10n, selection: $prefs.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Stats

struct StatsView: View {
    @ObservedObject var prefs: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("today_stats".l10n, subtitle: "today_stats_hint".l10n) {
                HStack(spacing: 14) {
                    StatTile(icon: "cup.and.saucer.fill", label: "break_times".l10n, value: "\(prefs.todayBreakCount)", suffix: "break_count".l10n)
                    StatTile(icon: "clock.fill", label: "total_break".l10n, value: fmtDur(prefs.todayTotalBreakSeconds), suffix: "")
                    StatTile(icon: "deskclock.fill", label: "worked".l10n, value: workedDuration, suffix: "")
                }

                if prefs.dailyBreakGoal > 0 {
                    SettingsDivider()
                    HStack(spacing: 18) {
                        goalRing
                        VStack(alignment: .leading, spacing: 4) {
                            Text("goal_progress".l10n)
                                .font(.headline)
                            Text(goalDescription)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            SettingsCard("recent_records".l10n, subtitle: "recent_records_hint".l10n) {
                if prefs.historyRecords.isEmpty {
                    Text("no_history".l10n)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 0) {
                        ForEach(prefs.historyRecords.sorted(by: { $0.date > $1.date }).prefix(7)) { record in
                            HStack {
                                Text(record.formattedDate)
                                Spacer()
                                Text("\(record.breakCount) \("break_count".l10n)")
                                    .foregroundColor(.secondary)
                                Text(record.formattedTotalDuration)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .font(.callout)
                            .padding(.vertical, 9)
                            if record.id != prefs.historyRecords.sorted(by: { $0.date > $1.date }).prefix(7).last?.id {
                                SettingsDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var workedDuration: String {
        guard let start = prefs.todayWorkStartTime else { return "--" }
        return fmtDur(Date().timeIntervalSince(start))
    }

    private var goalDescription: String {
        let remaining = max(prefs.dailyBreakGoal - prefs.todayBreakCount, 0)
        if remaining == 0 { return "goal_done".l10n }
        return String(format: "goal_remaining".l10n, remaining)
    }

    private var goalRing: some View {
        let progress = prefs.dailyBreakGoal > 0 ? min(CGFloat(prefs.todayBreakCount) / CGFloat(prefs.dailyBreakGoal), 1) : 0

        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                .frame(width: 92, height: 92)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(prefs.todayBreakCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("/ \(prefs.dailyBreakGoal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func fmtDur(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds)) \("seconds".l10n)" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title3)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - About

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("about".l10n, subtitle: "about_hint".l10n) {
                HStack(spacing: 16) {
                    AppIconView(size: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sige")
                            .font(.system(size: 26, weight: .semibold))
                        Text("about_tagline".l10n)
                            .foregroundColor(.secondary)
                        Text("Sige v2.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                SettingsDivider()
                infoRow("version".l10n, value: "Sige v2.0")
                infoRow("sys_req".l10n, value: "macOS 14.0+")
                infoRow("privacy_mode".l10n, value: "privacy_mode_value".l10n)

                SettingsDivider()
                Button {
                    if let url = URL(string: "https://sige-break-reminder.surge.sh") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("open_product_page".l10n, systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let image = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? "") {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24)
                    .fill(LinearGradient(colors: [Color.accentColor, Color.cyan.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Shared controls

struct ColorPickerRow: View {
    let label: String
    @Binding var color: NSColor

    var body: some View {
        SettingsRow(label: label) {
            ColorPicker("", selection: Binding(
                get: { Color(color) },
                set: { color = NSColor($0) }
            ))
            .labelsHidden()
        }
    }
}

struct FontPickerRow: View {
    let label: String
    @Binding var selection: String
    private let fonts: [String] = { ["system".l10n] + NSFontManager.shared.availableFontFamilies }()

    var body: some View {
        SettingsRow(label: label) {
            Picker("", selection: $selection) {
                ForEach(fonts, id: \.self) { name in
                    Text(display(name))
                        .font(font(name))
                        .tag(name == "system".l10n ? "" : name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220)
        }
    }

    private func display(_ name: String) -> String {
        name == "system".l10n ? "system".l10n : name
    }

    private func font(_ name: String) -> Font? {
        if name == "system".l10n || name.isEmpty { return nil }
        return .custom(name, size: 13)
    }
}
