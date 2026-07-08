import AVFoundation
import Foundation
import CoreAudio

// MARK: - 音效选择

enum BreakSound: String, CaseIterable, Codable {
    case none
    case builtinAmbientPiano
    case builtinWarmPad
    case builtinHarp
    case builtinFlute
    case builtinMusicBox
    case builtinBells
    case builtinGuitar
    case builtinStrings
    // 用户自定义曲目 ID 前缀: "user-{filename}"

    var displayName: String {
        // 优先查找 SoundTrack 的标题
        if let track = SoundCatalog.builtInTracks.first(where: { $0.id == trackID }) {
            return track.displayName
        }
        switch self {
        case .none: return "无"
        default:    return rawValue
        }
    }

    /// 对应的 SoundTrack ID
    var trackID: String {
        switch self {
        case .none:                 return ""
        case .builtinAmbientPiano:  return "builtin-ambient-piano"
        case .builtinWarmPad:       return "builtin-warm-pad"
        case .builtinHarp:          return "builtin-harp"
        case .builtinFlute:         return "builtin-flute"
        case .builtinMusicBox:      return "builtin-music-box"
        case .builtinBells:         return "builtin-bells"
        case .builtinGuitar:        return "builtin-guitar"
        case .builtinStrings:       return "builtin-strings"
        }
    }

    /// 内置曲目的 MIDI 乐器编号
    var midiProgram: UInt8 {
        switch self {
        case .builtinAmbientPiano: return 0   // Grand Piano
        case .builtinWarmPad:      return 91  // Warm Pad
        case .builtinHarp:         return 46  // Harp
        case .builtinFlute:        return 73  // Flute
        case .builtinMusicBox:     return 10  // Music Box
        case .builtinBells:        return 14  // Tubular Bells
        case .builtinGuitar:       return 24  // Nylon Guitar
        case .builtinStrings:      return 48  // String Ensemble
        default:                   return 0
        }
    }

    /// 所有内置选项（不含用户自定义）
    static let builtInCases: [BreakSound] = [
        .none, .builtinAmbientPiano, .builtinWarmPad, .builtinHarp,
        .builtinFlute, .builtinMusicBox, .builtinBells,
        .builtinGuitar, .builtinStrings,
    ]
}

// MARK: - 音效管理器

/// 使用 DLS 采样器 + 混响效果器 生成高质量舒缓背景音乐
/// + 支持用户自定义 MP3 文件
final class SoundManager: NSObject {
    static let shared = SoundManager()

    // MARK: - DLS 引擎

    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var reverb: AVAudioUnitReverb?
    /// 音符定时器
    private var noteTimer: DispatchSourceTimer?
    private var isPlaying = false
    private var currentSound: BreakSound = .none
    private var isPreview = false
    private var previewDeadline: DispatchWorkItem?

    // MARK: - MP3 播放器

    private var mp3Player: AVAudioPlayer?

    /// 系统音量（0.0…1.0），由 CoreAudio 监听实时更新
    private var systemVolume: Float = 1.0
    /// 基准衰减比例 — 相对系统音量的缩放（0.30 = 系统音量的 30%）
    private let baseLevel: Float = 0.30

    private override init() {
        super.init()
        systemVolume = readSystemVolume()
        startVolumeListener()
    }

    /// 当前有效输出音量 = 系统音量 × 基准比例
    private func volumeFactor() -> Float {
        systemVolume * baseLevel
    }

    // MARK: - Play / Stop

    func play(_ sound: BreakSound) {
        guard sound != .none else { return }
        stop()
        currentSound = sound
        isPreview = false
        startSound(sound)
    }

    func preview(_ sound: BreakSound) {
        guard sound != .none else { return }
        stop()
        currentSound = sound
        isPreview = true
        startSound(sound)

        let d = DispatchWorkItem { [weak self] in self?.stop() }
        previewDeadline = d
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: d)
    }

    func stop() {
        previewDeadline?.cancel(); previewDeadline = nil
        noteTimer?.cancel(); noteTimer = nil
        mp3Player?.stop(); mp3Player = nil
        sampler?.stopNote(0, onChannel: 0)
        engine?.stop(); engine = nil
        sampler = nil; reverb = nil
        isPlaying = false
    }

    /// 检查曲目是否可直接播放（内置总是 ready，MP3 需文件存在）
    func isCached(_ sound: BreakSound) -> Bool {
        guard sound != .none else { return true }
        let trackID = sound.trackID
        // 内置曲目 → 总是可用
        if SoundCatalog.builtInTracks.contains(where: { $0.id == trackID }) { return true }
        // 用户 MP3 → 检查文件
        let url = SoundCatalog.userSoundsDir.appendingPathComponent("\(sound.rawValue).mp3")
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Start Sound

    private func startSound(_ sound: BreakSound) {
        let trackID = sound.trackID

        // 判断是内置还是用户 MP3
        if SoundCatalog.builtInTracks.contains(where: { $0.id == trackID }) {
            startBuiltIn(sound)
        } else {
            let url = SoundCatalog.userSoundsDir.appendingPathComponent("\(sound.rawValue).mp3")
            if FileManager.default.fileExists(atPath: url.path) {
                startMP3(url)
            } else {
                print("[Sige] ❌ 找不到文件: \(url.path)")
            }
        }
    }

    // MARK: - 内置 DLS + 混响引擎

    private func startBuiltIn(_ sound: BreakSound) {
        let audioEngine = AVAudioEngine()

        //  采样器
        let avSampler = AVAudioUnitSampler()
        audioEngine.attach(avSampler)

        //  混响效果器 — 大幅提升空间感和氛围感
        let avReverb = AVAudioUnitReverb()
        avReverb.loadFactoryPreset(.largeHall)  // 大音乐厅混响
        avReverb.wetDryMix = 35  // 35% 湿信号，保持清晰度同时增加空间感
        audioEngine.attach(avReverb)

        // 信号链路: sampler → reverb → mainMixer
        audioEngine.connect(avSampler, to: avReverb, format: nil)
        audioEngine.connect(avReverb, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.mainMixerNode.outputVolume = volumeFactor()

        // 加载内置 DLS 音源
        loadBuiltInSoundFont(into: avSampler, program: sound.midiProgram)

        do { try audioEngine.start() } catch {
            print("[Sige] ❌ AudioEngine: \(error)"); return
        }

        self.engine = audioEngine
        self.sampler = avSampler
        self.reverb = avReverb
        self.isPlaying = true

        // 调度音符序列
        schedulePattern(for: sound, sampler: avSampler)
    }

    // MARK: - MP3 播放器

    private func startMP3(_ url: URL) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            print("[Sige] ❌ 无法播放: \(url.path)"); return
        }
        player.numberOfLoops = isPreview ? 0 : -1
        player.volume = volumeFactor()
        player.prepareToPlay()
        player.play()
        mp3Player = player
        isPlaying = true
    }

    // MARK: - 加载系统音源

    private func loadBuiltInSoundFont(into sampler: AVAudioUnitSampler, program: UInt8) {
        let path = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
        let url = URL(fileURLWithPath: path, isDirectory: false)
        guard FileManager.default.fileExists(atPath: path) else {
            print("[Sige] ❌ 找不到系统音源"); return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url, program: program, bankMSB: 0x79, bankLSB: 0x00)
            print("[Sige] 🎵 加载乐器 program=\(program)")
        } catch {
            print("[Sige] ❌ 加载音源失败: \(error)")
        }
    }

    // MARK: - 音乐片段

    private typealias Note = (delay: Double, midi: UInt8, velocity: UInt8, duration: Double)
    private typealias Chord = (delay: Double, midis: [UInt8], velocity: UInt8, duration: Double)

    private func makePattern(for sound: BreakSound) -> [Note] {
        switch sound {
        case .builtinAmbientPiano:
            //  Cmaj7 → Am9 → Fmaj7 和弦进行，极低力度 + 长延音
            let chords: [Chord] = [
                (0.0, [48, 55, 60, 64, 71], 42, 6.0),  // Cmaj7
                (4.5, [45, 52, 57, 64, 69], 38, 5.5),  // Am9
                (9.0, [41, 48, 53, 60, 65], 40, 5.5),  // Fmaj7
                (13.5, [43, 47, 55, 62, 67], 36, 6.0), // Gadd9
            ]
            return chordsToNotes(chords)

        case .builtinWarmPad:
            //  极慢速大和弦堆叠，每音间隔 0.5s 缓慢叠加
            let chords: [Chord] = [
                (0.0, [36, 43, 48, 55, 64], 48, 10.0),
                (5.0, [41, 48, 53, 60, 65], 44, 10.0),
                (10.0, [38, 45, 50, 57, 62], 46, 10.0),
                (15.0, [43, 50, 55, 62, 67], 42, 10.0),
            ]
            return chordsToNotes(chords)

        case .builtinHarp:
            //  上行+下行琶音
            let seq: [UInt8] = [48, 52, 55, 60, 64, 67, 72, 76, 79, 84, 79, 76, 72, 67, 64, 60, 55, 52]
            return seq.enumerated().map { (Double($0) * 0.3, $1, 50, 4.0) }

        case .builtinFlute:
            return [
                (0.0, 72, 52, 6.0), (4.0, 74, 48, 4.0),
                (7.0, 76, 50, 5.0), (10.0, 79, 46, 4.0),
                (13.0, 81, 48, 5.0), (16.0, 79, 44, 4.0),
                (19.0, 76, 50, 8.0),
            ]

        case .builtinMusicBox:
            let melody: [UInt8] = [72, 76, 79, 76, 72, 79, 81, 79, 76, 74, 72, 74, 76, 72, 67, 72]
            return melody.enumerated().map { (Double($0) * 0.5, $1, 54, 2.0) }

        case .builtinBells:
            return [
                (0.0, 84, 44, 6.0), (3.0, 79, 40, 5.0),
                (6.0, 81, 42, 5.5), (9.0, 76, 38, 5.0),
                (12.0, 79, 40, 6.0), (15.0, 84, 42, 8.0),
            ]

        case .builtinGuitar:
            //  Cmaj7 → Am → F → G 分解
            let prog: [(Double, [UInt8])] = [
                (0.0, [48, 52, 55, 60, 64]),
                (4.0, [45, 48, 52, 57, 64]),
                (8.0, [41, 48, 53, 57, 65]),
                (12.0, [43, 47, 50, 55, 67]),
            ]
            var notes: [Note] = []
            for (start, midis) in prog {
                for (j, m) in midis.enumerated() {
                    notes.append((start + Double(j) * 0.4, m, 52, 4.5))
                }
            }
            return notes

        case .builtinStrings:
            //  温暖弦乐 — 缓慢大和弦 + 渐强渐弱
            let chords: [Chord] = [
                (0.0, [48, 55, 60, 64], 38, 8.0),
                (5.0, [45, 52, 57, 64], 34, 7.0),
                (10.0, [41, 48, 53, 60], 36, 7.5),
                (15.0, [43, 47, 55, 62], 32, 8.0),
            ]
            return chordsToNotes(chords)

        default: return []
        }
    }

    /// 将和弦转为分散音符（每个音间隔 0.35s）
    private func chordsToNotes(_ chords: [Chord]) -> [Note] {
        var notes: [Note] = []
        for chord in chords {
            for (j, midi) in chord.midis.enumerated() {
                notes.append((chord.delay + Double(j) * 0.35, midi, chord.velocity, chord.duration))
            }
        }
        return notes
    }

    // MARK: - 调度播放

    private func schedulePattern(for sound: BreakSound, sampler: AVAudioUnitSampler) {
        let pattern = makePattern(for: sound)
        guard !pattern.isEmpty else { return }

        let maxDelay = pattern.map(\.delay).max() ?? 0
        let cycleDuration = maxDelay + 6.0

        func playOnce() {
            for note in pattern {
                DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) { [weak self] in
                    guard self?.isPlaying == true else { return }
                    sampler.startNote(note.midi, withVelocity: note.velocity, onChannel: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + note.duration) {
                        sampler.stopNote(note.midi, onChannel: 0)
                    }
                }
            }
        }

        playOnce()

        if !isPreview {
            let queue = DispatchQueue(label: "com.sige.sound-loop", qos: .background)
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + cycleDuration, repeating: cycleDuration)
            timer.setEventHandler { [weak self] in
                guard self?.isPlaying == true else { return }
                DispatchQueue.main.async { playOnce() }
            }
            timer.resume()
            noteTimer = timer
        }
    }

    // MARK: - 系统音量跟踪

    /// 读取 macOS 默认输出设备的系统音量
    private func readSystemVolume() -> Float {
        var defaultDevice: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultDevice
        )
        guard status == noErr, defaultDevice != 0 else { return 1.0 }

        address.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        address.mScope = kAudioDevicePropertyScopeOutput

        var volume: Float = 1.0
        size = UInt32(MemoryLayout<Float>.size)
        let volStatus = AudioObjectGetPropertyData(
            defaultDevice, &address, 0, nil, &size, &volume
        )
        guard volStatus == noErr else {
            //  某些设备不支持 VirtualMainVolume（如 HDMI），回退到各声道取平均
            return readChannelVolume(device: defaultDevice)
        }
        return max(0, min(1, volume))
    }

    /// 回退方案：读取立体声左右声道音量取平均
    private func readChannelVolume(device: AudioDeviceID) -> Float {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1  // 左声道
        )
        var left: Float = 1.0
        var size = UInt32(MemoryLayout<Float>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &left)

        address.mElement = 2  // 右声道
        var right: Float = 1.0
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &right)

        return (left + right) / 2
    }

    /// 注册系统音量变化监听 — 每当用户按键盘音量键时自动同步
    private func startVolumeListener() {
        var defaultDevice: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultDevice
        ) == noErr, defaultDevice != 0 else { return }

        // 监听 VirtualMainVolume 变化
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            defaultDevice, &volAddress, DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self, self.isPlaying else { return }
            let newVol = self.readSystemVolume()
            self.systemVolume = newVol
            let factor = self.volumeFactor()
            //  实时更新正在播放的音量
            if let eng = self.engine {
                eng.mainMixerNode.outputVolume = factor
            }
            if let mp3 = self.mp3Player {
                mp3.volume = factor
            }
        }
    }
}
