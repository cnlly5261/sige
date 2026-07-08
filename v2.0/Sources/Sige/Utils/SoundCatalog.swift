import Foundation

// MARK: - 曲目元数据 + 来源

/// 音效来源类型
enum SoundSource {
    case builtIn    // 内置合成（DLS 采样器 + 混响）
    case localMP3   // 用户放入的本地 MP3 文件
}

struct SoundTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let source: SoundSource
    var displayName: String { title }

    /// 本地 MP3 文件名（相对于 sounds 目录）
    var localFileName: String? {
        switch source {
        case .builtIn: return nil
        case .localMP3: return "\(id).mp3"
        }
    }
}

// MARK: - 曲目目录

struct SoundCatalog {
    /// 全部可用曲目 — 内置 + 用户自定义
    static var allTracks: [SoundTrack] {
        var tracks: [SoundTrack] = builtInTracks
        // 扫描用户放入的本地 MP3
        for mp3 in userMP3Files() {
            let name = (mp3 as NSString).deletingPathExtension
            let track = SoundTrack(id: "user-\(name)", title: "📁 \(name)", source: .localMP3)
            if !tracks.contains(where: { $0.id == track.id }) {
                tracks.append(track)
            }
        }
        return tracks
    }

    /// 内置曲目（DLS 采样器 + 混响实时合成，音质大幅提升）
    static let builtInTracks: [SoundTrack] = [
        SoundTrack(id: "builtin-ambient-piano", title: "🎹 空灵钢琴", source: .builtIn),
        SoundTrack(id: "builtin-warm-pad",     title: "🌅 温暖铺底", source: .builtIn),
        SoundTrack(id: "builtin-harp",         title: "🪈 竖琴流水", source: .builtIn),
        SoundTrack(id: "builtin-flute",        title: "🎵 长笛冥想", source: .builtIn),
        SoundTrack(id: "builtin-music-box",    title: "🎼 八音盒", source: .builtIn),
        SoundTrack(id: "builtin-bells",        title: "🔮 水晶铃音", source: .builtIn),
        SoundTrack(id: "builtin-guitar",       title: "🎸 木吉他", source: .builtIn),
        SoundTrack(id: "builtin-strings",      title: "🎻 温暖弦乐", source: .builtIn),
    ]

    /// 用户自定义 MP3 目录
    static var userSoundsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("Sige/sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 扫描用户 MP3 文件
    static func userMP3Files() -> [String] {
        let dir = userSoundsDir
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return contents.filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".m4a") || $0.hasSuffix(".wav") }
    }
}
