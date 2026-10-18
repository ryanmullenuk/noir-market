import AppKit

// 512×512 Game Center achievement badges: a neon ring and SF Symbol on ink black.
// Run from native/: swiftc -O Tools/AchievementArt/main.swift -o /tmp/ach && /tmp/ach
let items: [(String, String, UInt32)] = [
    ("first_sale", "sterlingsign", 0x29FF85), ("big_sale", "banknote.fill", 0x29FF85), ("customs_bribe", "airplane.arrival", 0xF5BD4D),
    ("bare_knuckle", "hand.raised.fill", 0xFF4D4D), ("first_ship", "shippingbox.fill", 0xF5BD4D), ("every_city", "map.fill", 0xF5BD4D),
    ("tip_right", "ear.fill", 0x29FF85), ("answered", "phone.fill", 0x29FF85), ("debt_free", "checkmark.seal.fill", 0x29FF85),
    ("jailbird", "lock.fill", 0xFF4D4D), ("legend", "crown.fill", 0xF5BD4D), ("drug_lord", "star.fill", 0xF5BD4D),
    ("clean_hands", "hands.sparkles.fill", 0x29FF85), ("survive_sprint", "bolt.fill", 0x29FF85), ("survive_standard", "calendar", 0x29FF85),
    ("survive_long", "calendar.badge.plus", 0x29FF85), ("daily_done", "sun.max.fill", 0xF5BD4D), ("tutorial", "graduationcap.fill", 0x29FF85),
    ("turf_war", "flag.fill", 0xFF4D4D), ("front", "storefront.fill", 0xF5BD4D), ("contract", "doc.text.fill", 0xF5BD4D),
    ("spain", "sun.horizon.fill", 0xF5BD4D), ("last_score", "suitcase.fill", 0xFF4D4D), ("raided", "light.beacon.max.fill", 0xFFE600),
]
func col(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a)
}
let dir = "AppStore/achievements"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (id, symbol, hex) in items {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    col(0x0A0A0A).setFill(); NSRect(x: 0, y: 0, width: 512, height: 512).fill()
    let glow = NSGradient(colors: [col(hex, 0.35), col(hex, 0)])!
    glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 480, height: 480)), relativeCenterPosition: .zero)
    let shadow = NSShadow(); shadow.shadowColor = col(hex, 0.9); shadow.shadowBlurRadius = 28; shadow.set()
    let ring = NSBezierPath(ovalIn: NSRect(x: 70, y: 70, width: 372, height: 372)); ring.lineWidth = 14; col(hex).setStroke(); ring.stroke()
    let cfg = NSImage.SymbolConfiguration(pointSize: 170, weight: .bold)
    if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: img.size, flipped: false) { r in
            img.draw(in: r); col(hex).set(); r.fill(using: .sourceAtop); return true
        }
        let s = img.size, scale = min(220 / s.width, 220 / s.height)
        let w = s.width * scale, h = s.height * scale
        tinted.draw(in: NSRect(x: 256 - w / 2, y: 256 - h / 2, width: w, height: h))
    }
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/\(id).png"))
}
print("wrote \(items.count) badges")
