import AppKit

let width: CGFloat = 660 * 2
let height: CGFloat = 400 * 2
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// 1. Dark Gradient Background
let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
let bgGradient = NSGradient(
    starting: NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0),
    ending: NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0)
)!
bgGradient.draw(in: bgRect, angle: 270)

// 2. Subtle radial spotlight in the center
let center = CGPoint(x: width / 2, y: height / 2)
let colors = [
    NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.12).cgColor,
    NSColor.clear.cgColor
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(radialGrad, startCenter: center, startRadius: 10, endCenter: center, endRadius: width * 0.45, options: [])
}

// 3. Arrow pointing from Left (BarBoss) to Right (Applications)
// create-dmg coordinates are from top-left, Cocoa lockFocus is from bottom-left.
// y=190 from top means in Cocoa y = 400 - 190 = 210 (scaled * 2 = 420)
let arrowCenterY: CGFloat = 210 * 2
let arrowStartX: CGFloat = 275 * 2
let arrowEndX: CGFloat = 385 * 2

let arrowPath = NSBezierPath()
// Arrow shaft
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX - 24, y: arrowCenterY))

// Arrow head
arrowPath.move(to: NSPoint(x: arrowEndX - 44, y: arrowCenterY + 22))
arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX - 44, y: arrowCenterY - 22))

let arrowGradient = NSGradient(
    starting: NSColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 0.35),
    ending: NSColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.8)
)!
NSColor(red: 0.7, green: 0.75, blue: 0.9, alpha: 0.6).setStroke()
arrowPath.lineWidth = 7.0
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

// 4. Instructions text at the bottom
let text = "Drag BarBoss into the Applications folder"
let font = NSFont.systemFont(ofSize: 26, weight: .medium)
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(white: 0.65, alpha: 1.0)
]
let textSize = (text as NSString).size(withAttributes: textAttributes)
let textX = (width - textSize.width) / 2
let textY: CGFloat = 55 * 2
(text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

// 5. Subtle target docks / pedestals beneath the icons
let leftPedestal = NSBezierPath(roundedRect: NSRect(x: 175 * 2 - 80, y: arrowCenterY - 95, width: 160, height: 16), xRadius: 8, yRadius: 8)
let rightPedestal = NSBezierPath(roundedRect: NSRect(x: 485 * 2 - 80, y: arrowCenterY - 95, width: 160, height: 16), xRadius: 8, yRadius: 8)
NSColor(white: 1.0, alpha: 0.05).setFill()
leftPedestal.fill()
rightPedestal.fill()

image.unlockFocus()

// Save to png
let outputPath = "scripts/dmg_background.png"
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outputPath))
    print("DMG background saved to \(outputPath)")
}
