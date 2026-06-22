#!/usr/bin/swift
// Genera el icono de Guardias en todas las resoluciones y lo convierte a .icns
// Uso: swift scripts/generate_icon.swift
import AppKit
import CoreGraphics

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Render
// ─────────────────────────────────────────────────────────────────────────────

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
    ctx.interpolationQuality = .high

    let cs = CGColorSpaceCreateDeviceRGB()

    // ── 1. Background rounded rect ────────────────────────────────────────
    let r     = s * 0.225
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: r, cornerHeight: r, transform: nil)

    // Gradient: rich blue (top) → deep indigo (bottom)
    let gradColors = [
        CGColor(red: 0/255,  green: 122/255, blue: 255/255, alpha: 1),   // #007AFF
        CGColor(red: 60/255, green: 54/255,  blue: 230/255, alpha: 1),   // #3C36E6
    ] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: s),
                           end:   CGPoint(x: s, y: 0),
                           options: [])

    // Subtle depth shadow at bottom
    let shadowColors = [
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.22),
    ] as CFArray
    let shadowGrad = CGGradient(colorsSpace: cs, colors: shadowColors, locations: [0.55, 1.0])!
    ctx.drawLinearGradient(shadowGrad,
                           start: CGPoint(x: s * 0.5, y: s * 0.45),
                           end:   CGPoint(x: s * 0.5, y: 0),
                           options: [])
    ctx.restoreGState()

    // ── 2. Shield shape ───────────────────────────────────────────────────
    let shCX  = s * 0.50
    let shTop = s * 0.89
    let shW   = s * 0.62
    let shH   = s * 0.74

    func shieldPath(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        let path  = CGMutablePath()
        let left  = cx - w / 2
        let right = cx + w / 2
        let cr    = w * 0.18

        path.move(to: CGPoint(x: left + cr, y: top))
        path.addLine(to: CGPoint(x: right - cr, y: top))
        path.addArc(center: CGPoint(x: right - cr, y: top - cr),
                    radius: cr, startAngle: .pi / 2, endAngle: 0, clockwise: true)
        let midY = top - h * 0.42
        path.addLine(to: CGPoint(x: right, y: midY))
        path.addCurve(
            to:       CGPoint(x: cx, y: top - h),
            control1: CGPoint(x: right,         y: top - h * 0.70),
            control2: CGPoint(x: cx + w * 0.28, y: top - h * 0.89)
        )
        path.addCurve(
            to:       CGPoint(x: left, y: midY),
            control1: CGPoint(x: cx - w * 0.28, y: top - h * 0.89),
            control2: CGPoint(x: left,           y: top - h * 0.70)
        )
        path.addLine(to: CGPoint(x: left, y: top - cr))
        path.addArc(center: CGPoint(x: left + cr, y: top - cr),
                    radius: cr, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        path.closeSubpath()
        return path
    }

    let outerShield = shieldPath(cx: shCX, top: shTop, w: shW, h: shH)

    // Shield white fill (subtle)
    ctx.saveGState()
    ctx.addPath(outerShield)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.fillPath()
    ctx.restoreGState()

    // Shield white stroke
    ctx.saveGState()
    ctx.addPath(outerShield)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.88))
    ctx.setLineWidth(s * 0.028)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // ── 3. Calendar card inside shield ───────────────────────────────────
    let calW  = shW  * 0.74
    let calH  = shH  * 0.67
    let calL  = shCX - calW / 2
    let calT  = shTop - shH * 0.14
    let calB  = calT - calH
    let calRect = CGRect(x: calL, y: calB, width: calW, height: calH)
    let calR    = calW * 0.10
    let calPath = CGPath(roundedRect: calRect, cornerWidth: calR, cornerHeight: calR, transform: nil)

    // Card drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.018),
                  blur: s * 0.04,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(calPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Card clip region
    ctx.saveGState()
    ctx.addPath(calPath)
    ctx.clip()

    // White background
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(calRect)

    // Header gradient
    let headerH = calH * 0.26
    let headerRect = CGRect(x: calL, y: calT - headerH, width: calW, height: headerH)
    let hdrColors = [
        CGColor(red: 0/255,  green: 122/255, blue: 255/255, alpha: 1),
        CGColor(red: 48/255, green: 46/255,  blue: 220/255, alpha: 1),
    ] as CFArray
    let hdrGrad = CGGradient(colorsSpace: cs, colors: hdrColors, locations: [0, 1])!
    ctx.drawLinearGradient(hdrGrad,
                           start: CGPoint(x: calL,        y: calT),
                           end:   CGPoint(x: calL + calW, y: calT - headerH),
                           options: [])

    // Ring dots
    let ringR = calW * 0.042
    let ringY = calT - headerH * 0.52
    for cx in [shCX - calW * 0.22, shCX, shCX + calW * 0.22] {
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.90))
        ctx.fillEllipse(in: CGRect(x: cx - ringR, y: ringY - ringR,
                                   width: ringR * 2, height: ringR * 2))
    }

    // Week rows
    let rowCount = 5
    let gridTop  = calT - headerH - calH * 0.03
    let gridBot  = calB + calH * 0.06
    let rowH     = (gridTop - gridBot) / CGFloat(rowCount)
    let padX     = calW * 0.08
    let padY     = rowH * 0.13

    let palette: [(CGFloat, CGFloat, CGFloat)] = [
        (0/255,  199/255, 190/255),
        (255/255, 149/255, 0/255),
        (52/255,  199/255, 89/255),
        (88/255,  86/255, 214/255),
        (255/255,  45/255, 85/255),
    ]

    for i in 0..<rowCount {
        let ry    = gridBot + CGFloat(rowCount - 1 - i) * rowH + padY
        let rh    = rowH - padY * 2
        let (rr, rg, rb) = palette[i % palette.count]

        // Row background (alternating)
        if i % 2 == 0 {
            ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1))
            ctx.fill(CGRect(x: calL, y: ry - padY, width: calW, height: rowH))
        }

        // Colored pill
        let pillW = calW * 0.085
        let pillRect = CGRect(x: calL + padX, y: ry + rh * 0.1, width: pillW, height: rh * 0.80)
        ctx.setFillColor(CGColor(red: rr, green: rg, blue: rb, alpha: 1.0))
        ctx.addPath(CGPath(roundedRect: pillRect,
                           cornerWidth: pillRect.width / 2,
                           cornerHeight: pillRect.height / 2, transform: nil))
        ctx.fillPath()

        // Name bar
        let barX = calL + padX + pillW + calW * 0.055
        let barW = calW * 0.52
        let barRect = CGRect(x: barX, y: ry + rh * 0.25, width: barW, height: rh * 0.50)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
        ctx.addPath(CGPath(roundedRect: barRect,
                           cornerWidth: barRect.height / 2,
                           cornerHeight: barRect.height / 2, transform: nil))
        ctx.fillPath()

        // Short date bar on right
        let dateX = barX + barW + calW * 0.04
        let dateW = calW * 0.14
        let dateRect = CGRect(x: dateX, y: ry + rh * 0.25, width: dateW, height: rh * 0.50)
        ctx.setFillColor(CGColor(red: rr, green: rg, blue: rb, alpha: 0.25))
        ctx.addPath(CGPath(roundedRect: dateRect,
                           cornerWidth: dateRect.height / 2,
                           cornerHeight: dateRect.height / 2, transform: nil))
        ctx.fillPath()
    }

    ctx.restoreGState()

    // Card border
    ctx.saveGState()
    ctx.addPath(calPath)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.07))
    ctx.setLineWidth(s * 0.007)
    ctx.strokePath()
    ctx.restoreGState()

    // ── 4. Top gloss ──────────────────────────────────────────────────────
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let glossColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.13),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let glossGrad = CGGradient(colorsSpace: cs, colors: glossColors, locations: [0, 1])!
    ctx.drawLinearGradient(glossGrad,
                           start: CGPoint(x: s * 0.5, y: s),
                           end:   CGPoint(x: s * 0.5, y: s * 0.5),
                           options: [])
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Export
// ─────────────────────────────────────────────────────────────────────────────

func writePNG(image: NSImage, size: Int, to url: URL) {
    guard let tiff   = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png    = bitmap.representation(using: .png, properties: [:]) else {
        fputs("✗ Failed PNG \(size)\n", stderr); return
    }
    do {
        try png.write(to: url)
        print("  ✓ \(url.lastPathComponent) (\(size)×\(size))")
    } catch {
        fputs("✗ \(error)\n", stderr)
    }
}

let fm = FileManager.default

let iconsetDir = URL(fileURLWithPath: "build/Guardias.iconset")
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let xcassetsDir = URL(fileURLWithPath:
    "Guardias/Resources/Assets.xcassets/AppIcon.appiconset")
try? fm.createDirectory(at: xcassetsDir, withIntermediateDirectories: true)

let iconsetSizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

print("Generando iconos Guardias…")
var cache: [Int: NSImage] = [:]

for (size, name) in iconsetSizes {
    let img = cache[size] ?? makeIcon(size: size)
    cache[size] = img
    writePNG(image: img, size: size, to: iconsetDir.appendingPathComponent(name))
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let img = cache[size] ?? makeIcon(size: size)
    cache[size] = img
    writePNG(image: img, size: size,
             to: xcassetsDir.appendingPathComponent("AppIcon_\(size).png"))
}

print("\nConvirtiendo a .icns…")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", "build/Guardias.iconset", "-o", "build/AppIcon.icns"]
try task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✓ build/AppIcon.icns generado")
} else {
    fputs("✗ iconutil falló (status \(task.terminationStatus))\n", stderr)
    exit(1)
}
