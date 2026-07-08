import SwiftUI
import AppKit

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared

    enum Tab: String, CaseIterable {
        case schedule, theme, general, stats
        var key: String {
            switch self {
            case .schedule: return "tab_schedule"
            case .theme:    return "tab_theme"
            case .general:  return "tab_general"
            case .stats:    return "tab_stats"
            }
        }
        var icon: String {
            switch self {
            case .schedule: return "clock"
            case .theme:    return "paintpalette"
            case .general:  return "gear"
            case .stats:    return "chart.bar"
            }
        }
    }

    @State private var selectedTab: Tab = .schedule

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleSettingsView(prefs: prefs)
                .tabItem { Label(Tab.schedule.key.l10n, systemImage: Tab.schedule.icon) }
                .tag(Tab.schedule)

            ThemeSettingsView(prefs: prefs)
                .tabItem { Label(Tab.theme.key.l10n, systemImage: Tab.theme.icon) }
                .tag(Tab.theme)

            GeneralSettingsView(prefs: prefs)
                .tabItem { Label(Tab.general.key.l10n, systemImage: Tab.general.icon) }
                .tag(Tab.general)

            StatsView(prefs: prefs)
                .tabItem { Label(Tab.stats.key.l10n, systemImage: Tab.stats.icon) }
                .tag(Tab.stats)
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}

// MARK: - Schedule

struct ScheduleSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var newTimePoint: String = ""

    var body: some View {
        Form {
            Section("schedule_mode".l10n) {
                Picker("", selection: $prefs.scheduleConfig.mode) {
                    ForEach(ScheduleMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            if prefs.scheduleConfig.mode == .timePoints { timePointSection }
            if prefs.scheduleConfig.mode == .pomodoro { pomodoroSection }

            Section("break_duration".l10n) {
                sliderRow("break_duration".l10n, value: Binding(get: { Double(prefs.scheduleConfig.breakDurationMinutes) }, set: { prefs.scheduleConfig.breakDurationMinutes = Int($0) }), range: 1...30, suffix: "minutes".l10n)
            }

            Section("pre_reminder".l10n) {
                Toggle("enable_pre_reminder".l10n, isOn: $prefs.scheduleConfig.preReminderEnabled)
                if prefs.scheduleConfig.preReminderEnabled {
                    sliderRow("pre_n_sec".l10n, value: Binding(get: { Double(prefs.scheduleConfig.preReminderSeconds) }, set: { prefs.scheduleConfig.preReminderSeconds = Int($0) }), range: 5...120, suffix: "seconds".l10n)
                }
            }
        }
        .formStyle(.grouped).padding()
    }

    private var timePointSection: some View {
        Section("rest_time_points".l10n) {
            ForEach(prefs.scheduleConfig.timePoints, id: \.self) { tp in
                HStack {
                    Image(systemName: "clock").foregroundColor(.secondary)
                    Text(tp)
                    Spacer()
                    Button { prefs.scheduleConfig.timePoints.removeAll { $0 == tp } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                TextField("HH:mm", text: $newTimePoint).frame(width: 140)
                Button("add".l10n) { addTimePoint() }.disabled(!validTP(newTimePoint))
            }
        }
    }

    private func addTimePoint() {
        let t = newTimePoint.trimmingCharacters(in: .whitespaces)
        guard validTP(t), !prefs.scheduleConfig.timePoints.contains(t) else { return }
        prefs.scheduleConfig.timePoints.append(t); prefs.scheduleConfig.timePoints.sort(); newTimePoint = ""
    }
    private func validTP(_ s: String) -> Bool {
        let p = s.split(separator: ":"); guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]), (0...23).contains(h), (0...59).contains(m) else { return false }; return true
    }

    private var pomodoroSection: some View {
        Section("work_duration".l10n) {
            sliderRow("work_duration".l10n, value: Binding(get: { Double(prefs.scheduleConfig.pomodoroWorkMinutes) }, set: { prefs.scheduleConfig.pomodoroWorkMinutes = Int($0) }), range: 1...120, suffix: "minutes".l10n)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(label); Slider(value: value, in: range, step: 1)
            Text("\(Int(value.wrappedValue)) \(suffix)").frame(width: 80, alignment: .trailing).monospacedDigit()
        }
    }
}

extension ScheduleMode {
    var displayName: String {
        switch self {
        case .pomodoro:   return "pomodoro_mode".l10n
        case .timePoints: return "timepoint_mode".l10n
        }
    }
}

// MARK: - Theme

struct ThemeSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var previewSound: BreakSound? = nil
    @State private var isPreviewPlaying = false

    var body: some View {
        Form {
            backgroundSection
            textSection
            soundSection
            Section("progress_indicator".l10n) {
                Toggle("show_progress_ring".l10n, isOn: $prefs.breakTheme.showProgressRing)
            }
            previewSection
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: Background

    private var backgroundSection: some View {
        Section("background".l10n) {
            Picker("bg_type".l10n, selection: $prefs.breakTheme.backgroundType) {
                Text("solid_color".l10n).tag(BreakTheme.BackgroundType.solidColor)
                Text("gradient".l10n).tag(BreakTheme.BackgroundType.gradient)
                Text("image".l10n).tag(BreakTheme.BackgroundType.image)
            }

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
                HStack {
                    Text(prefs.breakTheme.backgroundImagePath.isEmpty ? "no_image".l10n : (prefs.breakTheme.backgroundImagePath as NSString).lastPathComponent)
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundColor(prefs.breakTheme.backgroundImagePath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("choose_image".l10n) { chooseImage() }
                }
            }
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

    // MARK: Text

    private var textSection: some View {
        Section("text_style".l10n) {
            TextField("title_text".l10n, text: $prefs.breakTheme.displayText)
            TextField("subtitle_text".l10n, text: $prefs.breakTheme.subtitleText)
            FontPickerRow(label: "font_style".l10n, selection: $prefs.breakTheme.textFontName)
            sliderRow("title_size".l10n, value: $prefs.breakTheme.fontSize, range: 20...64, step: 2)
            sliderRow("subtitle_size".l10n, value: $prefs.breakTheme.subtitleFontSize, range: 12...36, step: 2)
            sliderRow("countdown_size".l10n, value: $prefs.breakTheme.countdownFontSize, range: 36...120, step: 4)
        }
    }

    // MARK: Sound

    private var soundSection: some View {
        Section("sound_system".l10n) {
            ForEach(BreakSound.builtInCases, id: \.self) { sound in
                soundRow(sound)
            }

            Divider()

            //  添加自定义音乐提示
            HStack {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(.secondary)
                Text("drop_mp3_hint".l10n)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let dir = SoundCatalog.userSoundsDir
                    NSWorkspace.shared.open(dir)
                } label: {
                    Text("open_folder".l10n).font(.caption)
                }
            }

            Toggle("prevent_screensaver".l10n, isOn: $prefs.preventScreenSaver)
            Text("screensaver_hint".l10n).font(.caption).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func soundRow(_ sound: BreakSound) -> some View {
        let isSelected = prefs.breakSound == sound
        let isCached = SoundManager.shared.isCached(sound)
        let isPreviewing = isPreviewPlaying && previewSound == sound

        HStack(spacing: 10) {
            //  选中指示 — 实心圆 / 空心圆
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))

            // 曲目名称 + 缓存状态
            VStack(alignment: .leading, spacing: 2) {
                Text(sound.displayName)
                    .fontWeight(isSelected ? .semibold : .regular)
                if sound != .none && !isCached {
                    Text("click_to_download".l10n)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // 试听按钮
            if sound != .none {
                Button {
                    if isPreviewing {
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
                } label: {
                    Image(systemName: isPreviewing ? "stop.fill" : "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isPreviewing ? .orange : .accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        //  选中高亮背景
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击整行 → 选中
            prefs.breakSound = sound
            SoundManager.shared.stop()
            isPreviewPlaying = false
            previewSound = nil
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        Section("preview".l10n) {
            ZStack {
                prefs.breakTheme.backgroundView().frame(height: 100).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(spacing: 2) {
                    Text(prefs.breakTheme.displayText)
                        .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: min(prefs.breakTheme.fontSize, 20)))
                        .foregroundColor(prefs.breakTheme.textColor.color)
                    Text(prefs.breakTheme.subtitleText)
                        .font(prefs.breakTheme.font(name: prefs.breakTheme.textFontName, size: min(prefs.breakTheme.subtitleFontSize, 12)))
                        .foregroundColor(prefs.breakTheme.textColor.color.opacity(0.7))
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range, step: step)
            Text("\(Int(value.wrappedValue))pt").frame(width: 40, alignment: .trailing).monospacedDigit()
        }
    }
}

// MARK: - Color Picker

struct ColorPickerRow: View {
    let label: String
    @Binding var color: NSColor

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(color) },
                set: { color = NSColor($0) }
            ))
            .labelsHidden()
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var prefs: AppPreferences
    @State private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("startup".l10n) {
                Toggle("launch_at_login".l10n, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in LaunchAtLogin.setEnabled(v) }
                    .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
            }
            Section("behavior".l10n) {
                Toggle("enforce_break".l10n, isOn: $prefs.enforceBreak)
                Toggle("skip_fullscreen".l10n, isOn: $prefs.skipWhenFullscreen)
                Stepper("\("daily_goal".l10n) \(prefs.dailyBreakGoal) \("break_count".l10n)", value: $prefs.dailyBreakGoal, in: 1...50)
            }
            Section("language".l10n) {
                Picker("language".l10n, selection: $prefs.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { l in Text(l.displayName).tag(l) }
                }
            }
            Section("about".l10n) {
                HStack { Text("version".l10n); Spacer(); Text("Sige v1.1").foregroundColor(.secondary) }
                HStack { Text("sys_req".l10n); Spacer(); Text("macOS 14.0+").foregroundColor(.secondary) }
            }
        }
        .formStyle(.grouped).padding()
    }
}

// MARK: - Stats

struct StatsView: View {
    @ObservedObject var prefs: AppPreferences

    var body: some View {
        Form {
            Section("today_stats".l10n) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        statRow(icon: "cup.and.saucer", label: "break_times".l10n, val: "\(prefs.todayBreakCount) \("break_count".l10n)")
                        statRow(icon: "clock", label: "total_break".l10n, val: fmtDur(prefs.todayTotalBreakSeconds))
                        if let st = prefs.todayWorkStartTime {
                            statRow(icon: "deskclock", label: "worked".l10n, val: fmtDur(Date().timeIntervalSince(st)))
                        }
                    }
                    Spacer()
                    if prefs.dailyBreakGoal > 0 {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6).frame(width: 80, height: 80)
                            Circle().trim(from: 0, to: min(CGFloat(prefs.todayBreakCount)/CGFloat(prefs.dailyBreakGoal), 1))
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                            VStack { Text("\(prefs.todayBreakCount)").font(.title2.bold()); Text("/ \(prefs.dailyBreakGoal)").font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }.padding(.vertical, 8)
            }
            Section("recent_records".l10n) {
                if prefs.historyRecords.isEmpty {
                    Text("no_history".l10n).foregroundColor(.secondary)
                } else {
                    ForEach(prefs.historyRecords.sorted(by: { $0.date > $1.date }).prefix(7)) { r in
                        HStack {
                            Text(r.formattedDate); Spacer()
                            Text("\(r.breakCount) \("break_count".l10n)").foregroundColor(.secondary)
                            Text("·").foregroundColor(.secondary)
                            Text(r.formattedTotalDuration).foregroundColor(.secondary)
                        }.font(.callout)
                    }
                }
            }
        }
        .formStyle(.grouped).padding()
    }

    private func statRow(icon: String, label: String, val: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 20).foregroundColor(.accentColor)
            Text(label + ":").foregroundColor(.secondary); Text(val).fontWeight(.medium)
        }
    }

    private func fmtDur(_ s: TimeInterval) -> String {
        if s < 60 { return "\(Int(s)) \("seconds".l10n)" }
        let h = Int(s)/3600, m = (Int(s)%3600)/60
        if h > 0 { return "\(h)h \(m)min" }
        return "\(m) min"
    }
}

// MARK: - Font Picker

struct FontPickerRow: View {
    let label: String
    @Binding var selection: String
    private let fonts: [String] = { ["system".l10n] + NSFontManager.shared.availableFontFamilies }()

    var body: some View {
        HStack {
            Text(label); Spacer()
            Picker("", selection: $selection) {
                ForEach(fonts, id: \.self) { n in
                    Text(display(n)).font(font(n)).tag(n == "system".l10n ? "" : n)
                }
            }.pickerStyle(.menu).frame(width: 180)
        }
    }

    private func display(_ n: String) -> String { n == "system".l10n ? "system".l10n : n }
    private func font(_ n: String) -> Font? {
        if n == "system".l10n || n.isEmpty { return nil }
        return .custom(n, size: 13)
    }
}

