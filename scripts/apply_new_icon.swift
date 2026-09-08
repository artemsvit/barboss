import AppKit

let inputPath = "/Users/artsvit/.gemini/antigravity/brain/7175be0c-0d73-495b-af61-441fa1c75d84/.user_uploaded/media_1788855101075.png"
guard let rawImage = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load input image")
    exit(1)
}

// 1. Create macOS squircle version for AppIcon
let canvasSize: CGFloat = 1024
let iconCanvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
iconCanvas.lockFocus()

let iconRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let clipPath = NSBezierPath(roundedRect: iconRect, xRadius: 198, yRadius: 198)

// Subtle shadow behind squircle
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 24
shadow.set()

NSColor.black.setFill()
clipPath.fill()

// Reset shadow and draw clipped pug image
NSGraphicsContext.current?.saveGraphicsState()
clipPath.addClip()
rawImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

// Subtle inner border/stroke
NSColor.white.withAlphaComponent(0.2).setStroke()
clipPath.lineWidth = 4
clipPath.stroke()

NSGraphicsContext.current?.restoreGraphicsState()
iconCanvas.unlockFocus()

let appiconDir = "BarBoss/Resources/Assets.xcassets/AppIcon.appiconset"

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

for (filename, px) in sizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    iconCanvas.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    
    if let tiff = resized.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(appiconDir)/\(filename)"))
    }
}

// Copy raw image to landing/appicon.png and root appicon.png
if let tiff = rawImage.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "landing/appicon.png"))
    try? png.write(to: URL(fileURLWithPath: "appicon.png"))
}

print("New Pug icon successfully applied to AppIcon set and landing page!")
