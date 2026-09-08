import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background rounded rect
let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
let bezier = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)

let gradient = NSGradient(
    starting: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0),
    ending: NSColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0)
)!
gradient.draw(in: bezier, angle: 270)

NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 0.5).setStroke()
bezier.lineWidth = 12
bezier.stroke()

// Center diamond / bowtie shape
let center_x: CGFloat = 512.0
let center_y: CGFloat = 512.0
let diamond = NSBezierPath()
diamond.move(to: NSPoint(x: center_x, y: center_y + 200))
diamond.line(to: NSPoint(x: center_x + 200, y: center_y))
diamond.line(to: NSPoint(x: center_x, y: center_y - 200))
diamond.line(to: NSPoint(x: center_x - 200, y: center_y))
diamond.close()

let diamondGrad = NSGradient(
    starting: NSColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1.0),
    ending: NSColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1.0)
)!
diamondGrad.draw(in: diamond, angle: 45)

// Center dot
let centerDot = NSBezierPath(ovalIn: NSRect(x: center_x - 36, y: center_y - 36, width: 72, height: 72))
NSColor.white.setFill()
centerDot.fill()

// Top bar line
let barRect = NSRect(x: 200, y: 780, width: 624, height: 28)
let barPath = NSBezierPath(roundedRect: barRect, xRadius: 14, yRadius: 14)
NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.85).setFill()
barPath.fill()

image.unlockFocus()

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let appiconDir = "BarBoss/Resources/Assets.xcassets/AppIcon.appiconset"

for (filename, px) in sizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    
    if let tiff = resized.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(appiconDir)/\(filename)"))
    }
}

// Update Contents.json with filenames
let contentsJson = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try? contentsJson.write(to: URL(fileURLWithPath: "\(appiconDir)/Contents.json"), atomically: true, encoding: .utf8)
print("Icons generated successfully!")
