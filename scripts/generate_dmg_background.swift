import AppKit

let width: CGFloat = 660 * 2
let height: CGFloat = 400 * 2
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// 1. User's requested Beige/Golden Gradient:
// linear-gradient(180deg, #FFC757 0%, #DC8A32 100%)
let topColor = NSColor(red: 255.0/255.0, green: 199.0/255.0, blue: 87.0/255.0, alpha: 1.0)
let bottomColor = NSColor(red: 220.0/255.0, green: 138.0/255.0, blue: 50.0/255.0, alpha: 1.0)

let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
let bgGradient = NSGradient(starting: topColor, ending: bottomColor)!
// In Cocoa NSGradient, 270 angle draws top-to-bottom
bgGradient.draw(in: bgRect, angle: 270)

// 2. Subtle soft warm glow in center
let center = CGPoint(x: width / 2, y: height / 2)
let glowColors = [
    NSColor(white: 1.0, alpha: 0.18).cgColor,
    NSColor.clear.cgColor
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(radialGrad, startCenter: center, startRadius: 20, endCenter: center, endRadius: width * 0.45, options: [])
}

// 3. Arrow pointing from Left (BarBoss) to Right (Applications)
// create-dmg coordinates are from top-left, Cocoa lockFocus is from bottom-left.
// y=190 from top in 400px window -> y = 210 in Cocoa coordinates (x2 = 420)
let arrowCenterY: CGFloat = 210 * 2
let arrowStartX: CGFloat = 275 * 2
let arrowEndX: CGFloat = 385 * 2

// Arrow shadow
let arrowShadow = NSShadow()
arrowShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
arrowShadow.shadowOffset = NSSize(width: 0, height: -3)
arrowShadow.shadowBlurRadius = 8
arrowShadow.set()

// Arrow path
let arrowPath = NSBezierPath()
// Arrow shaft
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX - 20, y: arrowCenterY))

// Arrow head
arrowPath.move(to: NSPoint(x: arrowEndX - 42, y: arrowCenterY + 22))
arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX - 42, y: arrowCenterY - 22))

let darkBrown = NSColor(red: 45.0/255.0, green: 26.0/255.0, blue: 8.0/255.0, alpha: 0.88)
darkBrown.setStroke()
arrowPath.lineWidth = 7.0
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

// Reset shadow
let noShadow = NSShadow()
noShadow.set()

// 4. Subtle pedestals beneath icons
let leftPedestal = NSBezierPath(roundedRect: NSRect(x: 175 * 2 - 80, y: arrowCenterY - 95, width: 160, height: 16), xRadius: 8, yRadius: 8)
let rightPedestal = NSBezierPath(roundedRect: NSRect(x: 485 * 2 - 80, y: arrowCenterY - 95, width: 160, height: 16), xRadius: 8, yRadius: 8)
NSColor(red: 45.0/255.0, green: 26.0/255.0, blue: 8.0/255.0, alpha: 0.12).setFill()
leftPedestal.fill()
rightPedestal.fill()

// 5. Instruction text at bottom
let text = "Drag BarBoss into the Applications folder"
let font = NSFont.systemFont(ofSize: 26, weight: .semibold)
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(red: 45.0/255.0, green: 26.0/255.0, blue: 8.0/255.0, alpha: 0.85)
]
let textSize = (text as NSString).size(withAttributes: textAttributes)
let textX = (width - textSize.width) / 2
let textY: CGFloat = 55 * 2
(text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

image.unlockFocus()

// Save to png
let outputPath = "scripts/dmg_background.png"
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outputPath))
    print("New Beige DMG background successfully created at \(outputPath)")
}
