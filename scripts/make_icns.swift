import AppKit

let rootDir = FileManager.default.currentDirectoryPath
let sourcePath = "\(rootDir)/appicon.png"

guard let rawImage = NSImage(contentsOfFile: sourcePath) else {
    print("Failed to load icon image from \(sourcePath)")
    exit(1)
}

let iconsetDir = "/tmp/AppIcon_Native.iconset"
let xcassetsDir = "\(rootDir)/BarBoss/Resources/Assets.xcassets"
let appiconsetDir = "\(xcassetsDir)/AppIcon.appiconset"

try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: appiconsetDir, withIntermediateDirectories: true)

// 1. Root Assets.xcassets Contents.json
let rootContentsJson = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try? rootContentsJson.write(to: URL(fileURLWithPath: "\(xcassetsDir)/Contents.json"), atomically: true, encoding: .utf8)

// 2. Full-bleed standard macOS iconset files (Apple HIG compliant, no artificial transparent insets)
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
    rawImage.draw(
        in: NSRect(x: 0, y: 0, width: px, height: px),
        from: NSRect(x: 0, y: 0, width: rawImage.size.width, height: rawImage.size.height),
        operation: .copy,
        fraction: 1.0
    )
    resized.unlockFocus()
    if let tiff = resized.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
        try? png.write(to: URL(fileURLWithPath: "\(appiconsetDir)/\(name)"))
    }
}

// 3. AppIcon.appiconset Contents.json
let appiconContentsJson = """
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
try? appiconContentsJson.write(to: URL(fileURLWithPath: "\(appiconsetDir)/Contents.json"), atomically: true, encoding: .utf8)

// 4. Compile AppIcon.icns
let icnsOutput = "\(rootDir)/BarBoss/Resources/AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icnsOutput]
try? proc.run()
proc.waitUntilExit()

print("Full-bleed AppIcon set and AppIcon.icns created successfully!")
