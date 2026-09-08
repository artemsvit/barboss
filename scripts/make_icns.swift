import AppKit

let inputPath = "/Users/artsvit/.gemini/antigravity/brain/7175be0c-0d73-495b-af61-441fa1c75d84/.user_uploaded/media_1788855900161.png"
let altInputPath = "/Users/artsvit/.gemini/antigravity/brain/7175be0c-0d73-495b-af61-441fa1c75d84/.user_uploaded/media_1788855101075.png"

let chosenPath = FileManager.default.fileExists(atPath: altInputPath) ? altInputPath : inputPath
guard let rawImage = NSImage(contentsOfFile: chosenPath) else {
    print("Failed to load icon image from \(chosenPath)")
    exit(1)
}

// Prepare iconset folder
let iconsetDir = "/tmp/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Render squircle for macOS
let canvasSize: CGFloat = 1024
let squircle = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
squircle.lockFocus()

let rect = NSRect(x: 80, y: 80, width: 864, height: 864)
let clip = NSBezierPath(roundedRect: rect, xRadius: 195, yRadius: 195)

// Shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.shadowBlurRadius = 24
shadow.set()
NSColor.black.setFill()
clip.fill()

// Draw image
NSGraphicsContext.current?.saveGraphicsState()
clip.addClip()
rawImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

// Subtle border
NSColor.white.withAlphaComponent(0.2).setStroke()
clip.lineWidth = 4
clip.stroke()
NSGraphicsContext.current?.restoreGraphicsState()

squircle.unlockFocus()

// Standard iconset files
let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in iconSizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    squircle.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    if let tiff = resized.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
    }
}

print("Iconset created successfully at \(iconsetDir)")
