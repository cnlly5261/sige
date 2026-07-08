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
        static let accent  = CodableColor(r: 0.36, g: 0.78, b: 0.78, a: 1)
        static let darkBg  = CodableColor(r: 0.05, g: 0.06, b: 0.08, a: 1)
        static let darkGradStart = CodableColor(r: 0.04, g: 0.07, b: 0.10, a: 1)
        static let darkGradEnd   = CodableColor(r: 0.12, g: 0.16, b: 0.18, a: 1)

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

    var displayText: String = "该休息了，看看远方"
    var subtitleText: String = "离开屏幕片刻，让眼睛和身体重新舒展"
    var textColor: CodableColor = .white
    var textFontName: String = ""
    var fontSize: CGFloat = 42
    var subtitleFontSize: CGFloat = 19
    var countdownFontSize: CGFloat = 76

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
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [gradientStartColor.color, gradientEndColor.color]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    gradient: Gradient(colors: [CodableColor.accent.color.opacity(0.24), Color.clear]),
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 620
                )
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.10), Color.clear]),
                    center: .bottomLeading,
                    startRadius: 80,
                    endRadius: 680
                )
            }
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
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [CodableColor.darkGradStart.color, CodableColor.darkGradEnd.color]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [CodableColor.accent.color.opacity(0.22), Color.clear]),
                        center: .topTrailing,
                        startRadius: 40,
                        endRadius: 620
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
}
