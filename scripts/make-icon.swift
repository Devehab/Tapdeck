// Renders the Tapdeck mark: a graphite tile with a 2×2 deck of keys, one lit amber.
// Usage:
//   swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
//   swift scripts/make-icon.swift --png site/assets/icon.png 512
import AppKit

let graphiteTop = NSColor(srgbRed: 0.17, green: 0.18, blue: 0.20, alpha: 1)
let graphiteBottom = NSColor(srgbRed: 0.08, green: 0.09, blue: 0.10, alpha: 1)
let keyColor = NSColor(srgbRed: 0.86, green: 0.87, blue: 0.88, alpha: 1)
let amber = NSColor(srgbRed: 0.96, green: 0.65, blue: 0.14, alpha: 1)

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024

    // macOS icon grid: an 824pt rounded square centered on a 1024pt canvas.
    let body = NSBezierPath(
        roundedRect: NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale),
        xRadius: 185 * scale, yRadius: 185 * scale
    )
    NSGradient(starting: graphiteTop, ending: graphiteBottom)!.draw(in: body, angle: -90)
    NSColor(white: 1, alpha: 0.08).setStroke()
    body.lineWidth = 4 * scale
    body.stroke()

    let key: CGFloat = 250, gap: CGFloat = 56
    let origin = (1024 - (key * 2 + gap)) / 2
    for row in 0..<2 {
        for column in 0..<2 {
            let rect = NSRect(
                x: (origin + CGFloat(column) * (key + gap)) * scale,
                y: (origin + CGFloat(row) * (key + gap)) * scale,
                width: key * scale, height: key * scale
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 64 * scale, yRadius: 64 * scale)
            let isLit = row == 1 && column == 1
            NSGraphicsContext.saveGraphicsState()
            if isLit {
                let glow = NSShadow()
                glow.shadowColor = amber.withAlphaComponent(0.55)
                glow.shadowBlurRadius = 60 * scale
                glow.set()
            }
            (isLit ? amber : keyColor).setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let arguments = CommandLine.arguments
if arguments.count == 4, arguments[1] == "--png" {
    let output = URL(fileURLWithPath: arguments[2])
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try renderIcon(pixels: Int(arguments[3])!).write(to: output)
    exit(0)
}

let outputDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let filename = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try renderIcon(pixels: points * factor).write(to: outputDir.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(factor)x", "size": "\(points)x\(points)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: outputDir.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: outputDir.deletingLastPathComponent().appendingPathComponent("Contents.json"))
