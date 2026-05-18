#!/usr/bin/env swift
// Run with: swift generate-icon.swift
// Outputs: Resources/icon.png (1024×1024)
import AppKit
import Foundation

let canvasSize: CGFloat = 1024

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: false) { bounds in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // ── Squircle background ──────────────────────────────────────────
    let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 220, yRadius: 220)
    bgPath.addClip()

    ctx.drawLinearGradient(
        CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(red: 0.22, green: 0.48, blue: 1.00, alpha: 1).cgColor,
                NSColor(red: 0.42, green: 0.16, blue: 0.88, alpha: 1).cgColor,
            ] as CFArray,
            locations: [0, 1]
        )!,
        start: CGPoint(x: 0, y: canvasSize),
        end: CGPoint(x: canvasSize, y: 0),
        options: []
    )

    // ── Calendar card ────────────────────────────────────────────────
    let cardX: CGFloat = 112
    let cardW: CGFloat = canvasSize - cardX * 2
    let cardH: CGFloat = 680
    let cardY: CGFloat = (canvasSize - cardH) / 2 - 16
    let cardCorner: CGFloat = 60
    let cardRect = NSRect(x: cardX, y: cardY, width: cardW, height: cardH)
    let headerH: CGFloat = 210

    // Card drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 90,
                  color: NSColor.black.withAlphaComponent(0.40).cgColor)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: cardRect, xRadius: cardCorner, yRadius: cardCorner).fill()
    ctx.restoreGState()

    // Clip all card contents to card shape
    ctx.saveGState()
    NSBezierPath(roundedRect: cardRect, xRadius: cardCorner, yRadius: cardCorner).addClip()

    // Header
    NSColor(red: 0.22, green: 0.48, blue: 1.00, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: cardX, y: cardY + cardH - headerH, width: cardW, height: headerH)).fill()

    // Month label
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let monthStr = NSAttributedString(string: "MAY", attributes: [
        .font: NSFont.systemFont(ofSize: 96, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ])
    let mSize = monthStr.size()
    monthStr.draw(at: NSPoint(
        x: cardX + (cardW - mSize.width) / 2,
        y: cardY + cardH - headerH + (headerH - mSize.height) / 2
    ))

    // ── Day grid ─────────────────────────────────────────────────────
    let gridPad: CGFloat = 52
    let gridX = cardX + gridPad
    let gridW = cardW - gridPad * 2
    let gridTop = cardY + cardH - headerH - 20
    let cellW = gridW / 7
    let cellH: CGFloat = 78
    let numRows = 5

    for row in 0..<numRows {
        for col in 0..<7 {
            let cx = gridX + (CGFloat(col) + 0.5) * cellW
            let cy = gridTop - CGFloat(row) * cellH - cellH / 2

            let isToday = (row == 2 && col == 3)
            let isDOWHeader = (row == 0)

            if isToday {
                // Accent circle + date number
                let r: CGFloat = 44
                NSColor(red: 0.22, green: 0.48, blue: 1.00, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
                let numStr = NSAttributedString(string: "15", attributes: [
                    .font: NSFont.systemFont(ofSize: 42, weight: .bold),
                    .foregroundColor: NSColor.white,
                    .paragraphStyle: para,
                ])
                let nSize = numStr.size()
                numStr.draw(at: NSPoint(x: cx - nSize.width / 2, y: cy - nSize.height / 2))
            } else {
                let r: CGFloat = isDOWHeader ? 7 : 11
                NSColor(white: isDOWHeader ? 0.72 : 0.86, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
            }
        }
    }

    ctx.restoreGState()
    return true
}

// ── Write PNG ────────────────────────────────────────────────────────────────
let outputPath = "Resources/icon.png"
try? FileManager.default.createDirectory(atPath: "Resources",
                                          withIntermediateDirectories: true)
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else { print("❌ Failed to generate image"); exit(1) }

try! png.write(to: URL(fileURLWithPath: outputPath))
print("✅ Saved \(outputPath) (\(Int(canvasSize))×\(Int(canvasSize)))")
print("   Run ./build-macos-app.sh to bundle it into Glimpse.app")
