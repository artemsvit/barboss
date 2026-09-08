import AppKit

// Finder window is 660x400; draw @2x so the DMG stays sharp on Retina.
let scale: CGFloat = 2
let windowWidth: CGFloat = 660
let windowHeight: CGFloat = 400
let width = windowWidth * scale
let height = windowHeight * scale

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to create bitmap")
}
rep.size = NSSize(width: width, height: height)

let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(rep)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Warm gold gradient — matches the BarBoss brand
let topColor = NSColor(red: 255.0/255.0, green: 199.0/255.0, blue: 87.0/255.0, alpha: 1.0)
let bottomColor = NSColor(red: 220.0/255.0, green: 138.0/255.0, blue: 50.0/255.0, alpha: 1.0)
let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(starting: topColor, ending: bottomColor)!.draw(in: bgRect, angle: 270)

// Soft center glow
let center = CGPoint(x: width / 2, y: height / 2)
let glowColors = [
    NSColor(white: 1.0, alpha: 0.20).cgColor,
    NSColor.clear.cgColor
] as CFArray
if let radialGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(radialGrad, startCenter: center, startRadius: 20, endCenter: center, endRadius: width * 0.45, options: [])
}

// create-dmg icon positions are from the top-left of the 660x400 window.
// Cocoa drawing is from the bottom-left of the @2x canvas.
let iconCenterYFromTop: CGFloat = 190
let leftIconX: CGFloat = 175
let rightIconX: CGFloat = 485
let iconCenterY = (windowHeight - iconCenterYFromTop) * scale

// Pedestals under the app + Applications icons
func pedestal(atX x: CGFloat) -> NSBezierPath {
    let w: CGFloat = 168
    let h: CGFloat = 18
    return NSBezierPath(
        roundedRect: NSRect(x: x * scale - w / 2, y: iconCenterY - 98, width: w, height: h),
        xRadius: 9,
        yRadius: 9
    )
}
NSColor(red: 45.0/255.0, green: 26.0/255.0, blue: 8.0/255.0, alpha: 0.16).setFill()
pedestal(atX: leftIconX).fill()
pedestal(atX: rightIconX).fill()

// Bold drag arrow from BarBoss.app → Applications
let arrowStartX = (leftIconX + 78) * scale
let arrowEndX = (rightIconX - 78) * scale
let arrowY = iconCenterY
let shaftThickness: CGFloat = 16
let headLength: CGFloat = 36
let headWidth: CGFloat = 46

let shaft = NSBezierPath(roundedRect: NSRect(
    x: arrowStartX,
    y: arrowY - shaftThickness / 2,
    width: arrowEndX - arrowStartX - headLength + 8,
    height: shaftThickness
), xRadius: shaftThickness / 2, yRadius: shaftThickness / 2)

let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEndX, y: arrowY))
head.line(to: NSPoint(x: arrowEndX - headLength, y: arrowY + headWidth / 2))
head.line(to: NSPoint(x: arrowEndX - headLength, y: arrowY - headWidth / 2))
head.close()

let arrow = NSBezierPath()
arrow.append(shaft)
arrow.append(head)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 10, color: NSColor.black.withAlphaComponent(0.22).cgColor)
NSColor.white.setFill()
arrow.fill()
ctx.restoreGState()

NSColor(red: 45.0/255.0, green: 26.0/255.0, blue: 8.0/255.0, alpha: 0.18).setStroke()
arrow.lineWidth = 1.5
arrow.lineJoinStyle = .round
arrow.stroke()

// Instruction
let text = "Drag BarBoss into the Applications folder"
let font = NSFont.systemFont(ofSize: 28, weight: .semibold)
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white.withAlphaComponent(0.94),
    .shadow: {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 3
        return shadow
    }()
]
let textSize = (text as NSString).size(withAttributes: textAttributes)
(text as NSString).draw(
    at: NSPoint(x: (width - textSize.width) / 2, y: 52 * scale),
    withAttributes: textAttributes
)

NSGraphicsContext.restoreGraphicsState()

func writePNG(_ rep: NSBitmapImageRep, path: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
}

writePNG(rep, path: "scripts/dmg_background.png")
writePNG(rep, path: "scripts/dmg_bg_1x@2x.png")

guard let oneX = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(windowWidth),
    pixelsHigh: Int(windowHeight),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to create 1x bitmap")
}
oneX.size = NSSize(width: windowWidth, height: windowHeight)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: oneX)
image.draw(
    in: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
    from: .zero,
    operation: .copy,
    fraction: 1.0
)
NSGraphicsContext.restoreGraphicsState()
writePNG(oneX, path: "scripts/dmg_bg_1x.png")
