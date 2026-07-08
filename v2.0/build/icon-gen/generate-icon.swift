import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    // Rounded rect path with corner radius ~22.5% of width (macOS icon style)
    let cornerRadius: CGFloat = size.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    // Blue-purple gradient
    let gradient = NSGradient(colors: [
        NSColor(red: 0.30, green: 0.35, blue: 0.85, alpha: 1.0),  // top: vibrant blue-purple
        NSColor(red: 0.55, green: 0.35, blue: 0.90, alpha: 1.0),  // mid: purple
        NSColor(red: 0.70, green: 0.35, blue: 0.80, alpha: 1.0),  // bottom: pink-purple
    ])!
    gradient.draw(in: rect, angle: -90)

    // Draw white cup.and.saucer SF Symbol
    if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "rest") {
        let config = NSImage.SymbolConfiguration(pointSize: size.width * 0.48, weight: .regular)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
        let configured = symbol.withSymbolConfiguration(config)
        let symbolSize = configured?.size ?? .zero
        let symbolRect = NSRect(
            x: (size.width - symbolSize.width) / 2,
            y: (size.height - symbolSize.height) / 2 + size.height * 0.02,  // slight optical adjustment
            width: symbolSize.width,
            height: symbolSize.height
        )
        configured?.draw(in: symbolRect)
    }

    return true
}

// Save as PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: Failed to create PNG data")
    exit(1)
}

let outputURL = URL(fileURLWithPath: "/Users/peter/Desktop/Project/prototypes/sige/build/icon-gen/icon_1024.png")
try pngData.write(to: outputURL)
print("Generated: \(outputURL.path)")
