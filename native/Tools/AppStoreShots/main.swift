import AppKit
import CoreText

// Builds the captioned App Store screenshots from AppStore/raw.
// Run from native/: swiftc -O Tools/AppStoreShots/main.swift -o /tmp/shots && /tmp/shots
// Output: AppStore/screenshots (6.9", 1320×2868) and AppStore/screenshots-6.3 (1206×2622).

struct Shot { let file: String; let headline: [String]; let sub: String; let colour: UInt32 }

let green: UInt32 = 0x29FF85, red: UInt32 = 0xFF4D4D, amber: UInt32 = 0xF5BD4D, yellow: UInt32 = 0xFFE600

let shots: [Shot] = [
    Shot(file: "01_title", headline: ["TRADE SMART.", "PLAY DIRTY."], sub: "Thirty nights to come out on top.", colour: red),
    Shot(file: "02_market", headline: ["READ THE", "MARKET"], sub: "14 cities. Prices move every night.", colour: green),
    Shot(file: "03_trade", headline: ["BUY LOW.", "SELL HIGH."], sub: "Know your margin before you deal.", colour: green),
    Shot(file: "04_travel", headline: ["KEEP", "MOVING"], sub: "Carry stock to where it sells dear.", colour: amber),
    Shot(file: "05_noirnet", headline: ["HALF THE NEWS", "IS TRUE"], sub: "Nobody tells you which half.", colour: green),
    Shot(file: "06_raid", headline: ["THE HEAT", "IS COMING"], sub: "Stash it, run, or chance it.", colour: yellow),
    Shot(file: "07_police", headline: ["BRIBE. RUN.", "FIGHT."], sub: "Every stop is a gamble.", colour: red),
    Shot(file: "08_call", headline: ["TRUST", "NO ONE"], sub: "Informants sell tips. And you.", colour: amber),
    Shot(file: "09_street", headline: ["BUILD AN", "EMPIRE"], sub: "Contracts, crew, fronts and turf.", colour: green),
    Shot(file: "10_ending", headline: ["HOW DOES", "IT END?"], sub: "Retire, score big, or walk away.", colour: amber),
]

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

for url in (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "NoirMarket/Resources/Fonts"), includingPropertiesForKeys: nil)) ?? [] {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func line(_ text: String, font: String, size: CGFloat, colour c: CGColor, tracking: CGFloat = 0) -> CTLine {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: c, .kern: tracking]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
}

func draw(_ l: CTLine, in ctx: CGContext, centreX: CGFloat, baseline: CGFloat) {
    let w = CTLineGetTypographicBounds(l, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centreX - w / 2, y: baseline)
    CTLineDraw(l, ctx)
}

func render(_ shot: Shot, width W: Int, height H: Int, to out: URL) {
    guard let img = NSImage(contentsOfFile: "AppStore/raw/\(shot.file).png"),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("missing \(shot.file)"); return }
    let s = CGFloat(W) / 1320
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let h = CGFloat(H), w = CGFloat(W)

    // Background: ink black with a glow in the shot's colour behind the headline.
    ctx.setFillColor(colour(0x070707)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [colour(shot.colour, 0.30), colour(shot.colour, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: w / 2, y: h - 300 * s), startRadius: 0, endCenter: CGPoint(x: w / 2, y: h - 300 * s), endRadius: 900 * s, options: [])

    // Headline: two lines of Mona Sans Black with a neon glow, then a mono subline.
    let size: CGFloat = 132 * s
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40 * s, color: colour(shot.colour, 0.85))
    for (i, text) in shot.headline.enumerated() {
        var l = line(text, font: "MonaSans-Black", size: size, colour: colour(shot.colour))
        var fit = size
        while CTLineGetTypographicBounds(l, nil, nil, nil) > w - 120 * s, fit > 60 { fit -= 4; l = line(text, font: "MonaSans-Black", size: fit, colour: colour(shot.colour)) }
        draw(l, in: ctx, centreX: w / 2, baseline: h - (230 + CGFloat(i) * 150) * s)
    }
    ctx.restoreGState()
    draw(line(shot.sub, font: "JetBrainsMono-Medium", size: 46 * s, colour: colour(0xE8EAE8, 0.9)), in: ctx, centreX: w / 2, baseline: h - 560 * s)

    // The screen itself, scaled into a rounded phone-shaped frame.
    let top: CGFloat = 640 * s, bottom: CGFloat = 70 * s
    let sh = h - top - bottom
    let sw = sh * CGFloat(cg.width) / CGFloat(cg.height)
    let rect = CGRect(x: (w - sw) / 2, y: bottom, width: sw, height: sh)
    let radius = 78 * s
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 60 * s, color: colour(shot.colour, 0.35))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(colour(0x000000)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: rect)
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: -3 * s, dy: -3 * s), cornerWidth: radius + 3 * s, cornerHeight: radius + 3 * s, transform: nil))
    ctx.setStrokeColor(colour(0xFFFFFF, 0.22)); ctx.setLineWidth(4 * s); ctx.strokePath()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])!.write(to: out)
}

for (dir, W, H) in [("AppStore/screenshots", 1320, 2868), ("AppStore/screenshots-6.3", 1206, 2622)] {
    try? FileManager.default.removeItem(atPath: dir)
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    for shot in shots { render(shot, width: W, height: H, to: URL(fileURLWithPath: "\(dir)/\(shot.file).jpg")) }
    print("wrote \(shots.count) to \(dir)")
}
