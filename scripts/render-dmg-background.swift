import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? {
    fputs("usage: swift render-dmg-background.swift <output-path>\n", stderr)
    exit(1)
}()

let canvasSize = NSSize(width: 720, height: 420)
let rect = NSRect(origin: .zero, size: canvasSize)

let image = NSImage(size: canvasSize)
image.lockFocus()

let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.88, green: 0.93, blue: 0.98, alpha: 1.0),
])!
backgroundGradient.draw(in: rect, angle: 0)

let panelRect = NSRect(x: 28, y: 28, width: canvasSize.width - 56, height: canvasSize.height - 56)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 26, yRadius: 26)
NSColor(calibratedWhite: 1.0, alpha: 0.82).setFill()
panelPath.fill()

NSColor(calibratedRed: 0.75, green: 0.84, blue: 0.92, alpha: 0.45).setStroke()
panelPath.lineWidth = 1.5
panelPath.stroke()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 32, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.32, alpha: 1.0),
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.29, green: 0.38, blue: 0.50, alpha: 1.0),
]
let helperAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.49, blue: 0.59, alpha: 1.0),
]

NSString(string: "Install Cowork-Switch").draw(at: NSPoint(x: 56, y: 322), withAttributes: titleAttributes)
NSString(string: "Drag the app into Applications to install it.").draw(at: NSPoint(x: 56, y: 286), withAttributes: subtitleAttributes)
NSString(string: "The app will live in your Applications folder and remain notarized.").draw(at: NSPoint(x: 56, y: 258), withAttributes: helperAttributes)

let badgePath = NSBezierPath(roundedRect: NSRect(x: 56, y: 80, width: 208, height: 110), xRadius: 22, yRadius: 22)
NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.97, alpha: 0.82).setFill()
badgePath.fill()

NSString(string: "CoworkSwitch.app").draw(at: NSPoint(x: 76, y: 138), withAttributes: subtitleAttributes)
NSString(string: "Menu bar app").draw(at: NSPoint(x: 76, y: 110), withAttributes: helperAttributes)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 280, y: 145))
arrow.line(to: NSPoint(x: 470, y: 145))
arrow.lineWidth = 10
arrow.lineCapStyle = .round
NSColor(calibratedRed: 0.31, green: 0.52, blue: 0.84, alpha: 0.92).setStroke()
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 470, y: 145))
arrowHead.line(to: NSPoint(x: 438, y: 170))
arrowHead.line(to: NSPoint(x: 438, y: 120))
arrowHead.close()
NSColor(calibratedRed: 0.31, green: 0.52, blue: 0.84, alpha: 0.92).setFill()
arrowHead.fill()

let destinationPath = NSBezierPath(roundedRect: NSRect(x: 500, y: 80, width: 164, height: 110), xRadius: 22, yRadius: 22)
NSColor(calibratedRed: 0.87, green: 0.94, blue: 0.87, alpha: 0.90).setFill()
destinationPath.fill()

NSString(string: "Applications").draw(at: NSPoint(x: 520, y: 138), withAttributes: subtitleAttributes)
NSString(string: "Drop here").draw(at: NSPoint(x: 520, y: 110), withAttributes: helperAttributes)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to render dmg background image\n", stderr)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
