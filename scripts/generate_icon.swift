#!/usr/bin/swift
// Generates Guardias.app icon at multiple sizes using AppKit / Core Graphics.
// Usage: swift scripts/generate_icon.swift
import AppKit

let outputDir = "Guardias/Resources/Assets.xcassets/AppIcon.appiconset"

func makeIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // ── Background gradient (blue → indigo) ──────────────────────────────
    let cs = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1),   // #007AFF
        CGColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1)    // #5856D6
    ] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s * 0.2, y: s),
                           end: CGPoint(x: s * 0.8, y: 0),
                           options: [])

    // ── Calendar card (white rounded rect) ───────────────────────────────
    let margin = s * 0.12
    let cardRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let cardRadius = s * 0.10

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    ctx.addPath(cardPath)
    ctx.fillPath()

    // ── Calendar header bar ───────────────────────────────────────────────
    let headerH = s * 0.22
    let headerRect = CGRect(x: margin, y: s - margin - headerH, width: s - margin * 2, height: headerH)
    let headerColor = CGColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
    ctx.setFillColor(headerColor)
    // Top-rounded only (clip with card path, then fill header)
    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()
    ctx.fill(headerRect)
    ctx.restoreGState()

    // ── Calendar ring (top attachment dots) ───────────────────────────────
    let ringRadius = s * 0.035
    let ringY = s - margin - headerH * 0.5
    for cx in [s * 0.32, s * 0.5, s * 0.68] {
        let ringRect = CGRect(x: cx - ringRadius, y: ringY - ringRadius,
                              width: ringRadius * 2, height: ringRadius * 2)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        ctx.fillEllipse(in: ringRect)
    }

    // ── Week grid ─────────────────────────────────────────────────────────
    let gridTop = s - margin - headerH - s * 0.04
    let gridBottom = margin + s * 0.06
    let gridLeft = margin + s * 0.06
    let gridRight = s - margin - s * 0.06
    let gridH = gridTop - gridBottom
    let rowH = gridH / 5
    let colW = (gridRight - gridLeft) / 4

    let workerColors: [(CGFloat, CGFloat, CGFloat)] = [
        (0/255, 199/255, 190/255),   // teal
        (255/255, 149/255, 0/255),   // orange
        (52/255, 199/255, 89/255),   // green
        (88/255, 86/255, 214/255),   // indigo
    ]

    for row in 0..<5 {
        let ry = gridBottom + CGFloat(4 - row) * rowH + rowH * 0.15
        let rh = rowH * 0.6
        let colorIdx = row % workerColors.count
        let (r, g, b) = workerColors[colorIdx]

        // Colored dot
        let dotRadius = rh * 0.45
        let dotX = gridLeft + colW * 0.3
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.9))
        ctx.fillEllipse(in: CGRect(x: dotX - dotRadius, y: ry + rh * 0.1,
                                   width: dotRadius * 2, height: dotRadius * 2))

        // Gray bar (worker name placeholder)
        let barX = gridLeft + colW * 0.7
        let barW = colW * 2.6
        let alpha: CGFloat = 0.13
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: alpha))
        let barRect = CGRect(x: barX, y: ry + rh * 0.2, width: barW, height: rh * 0.55)
        ctx.addPath(CGPath(roundedRect: barRect, cornerWidth: barRect.height / 2,
                           cornerHeight: barRect.height / 2, transform: nil))
        ctx.fillPath()
    }

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func save(image: NSImage, size: Int, name: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiff),
          let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        return
    }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
    do {
        try pngData.write(to: url)
        print("✓ \(name) (\(size)×\(size))")
    } catch {
        print("✗ Failed to write \(name): \(error)")
    }
}

let sizes: [(Int, String)] = [
    (1024, "AppIcon_1024.png"),
    (512,  "AppIcon_512.png"),
    (256,  "AppIcon_256.png"),
    (128,  "AppIcon_128.png"),
    (64,   "AppIcon_64.png"),
    (32,   "AppIcon_32.png"),
    (16,   "AppIcon_16.png"),
]

print("Generating Guardias app icons…")
for (size, name) in sizes {
    save(image: makeIcon(size: size), size: size, name: name)
}
print("Done!")
