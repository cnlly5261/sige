import SwiftUI

/// 休息界面主题
struct BreakTheme: Codable {
    enum BackgroundType: String, Codable, CaseIterable {
        case solidColor
        case gradient
        case image
    }

    // MARK: - 颜色存储

    struct CodableColor: Codable, Equatable {
        var r: Double; var g: Double; var b: Double; var a: Double

        static let white   = CodableColor(r: 1, g: 1, b: 1, a: 0.9)
        static let accent  = CodableColor(r: 0.3, g: 0.7, b: 1, a: 1)
        static let darkBg  = CodableColor(r: 0.08, g: 0.08, b: 0.14, a: 1)
        static let darkGradStart = CodableColor(r: 0.06, g: 0.06, b: 0.20, a: 1)
        static let darkGradEnd   = CodableColor(r: 0.15, g: 0.04, b: 0.12, a: 1)

        var color: Color {
            Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
        var nsColor: NSColor {
            NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
        }
        static func from(nsColor: NSColor) -> CodableColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            (nsColor.usingColorSpace(.sRGB) ?? nsColor).getRed(&r, green: &g, blue: &b, alpha: &a)
            return CodableColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        }
    }

    // MARK: - 背景

    var backgroundType: BackgroundType = .gradient
    var solidColor: CodableColor = .darkBg
    var gradientStartColor: CodableColor = .darkGradStart
    var gradientEndColor: CodableColor   = .darkGradEnd
    var backgroundImagePath: String = ""

    // MARK: - 文字

    var displayText: String = "该休息了，看看窗外吧 🌿"
    var subtitleText: String = "保护眼睛，站起来活动一下"
    var textColor: CodableColor = .white
    var textFontName: String = ""
    var fontSize: CGFloat = 36
    var subtitleFontSize: CGFloat = 18
    var countdownFontSize: CGFloat = 72

    func font(name: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if name.isEmpty { return .system(size: size, weight: weight) }
        if NSFont(name: name, size: size) != nil { return .custom(name, size: size) }
        return .system(size: size, weight: weight)
    }

    // MARK: - 布局

    var showProgressRing: Bool = true
    var progressColor: CodableColor = .accent
}

// MARK: - 背景 ViewBuilder

extension BreakTheme {
    @ViewBuilder
    func backgroundView() -> some View {
        switch backgroundType {
        case .solidColor:
            solidColor.color.ignoresSafeArea()

        case .gradient:
            LinearGradient(
                gradient: Gradient(colors: [gradientStartColor.color, gradientEndColor.color]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

        case .image:
            if !backgroundImagePath.isEmpty,
               let nsImg = NSImage(contentsOfFile: backgroundImagePath) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.35))
            } else {
                // fallback gradient
                LinearGradient(
                    gradient: Gradient(colors: [CodableColor.darkGradStart.color, CodableColor.darkGradEnd.color]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}
