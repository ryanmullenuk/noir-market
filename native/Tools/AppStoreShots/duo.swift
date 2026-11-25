import AppKit
import CoreText

// Builds the captioned iPhone Duo (unfolded, landscape 2853×2007) App Store screenshots from AppStore/raw-duo.
// Run from native/: swiftc -O Tools/AppStoreShots/duo.swift -o /tmp/duoshots && /tmp/duoshots
// Output: AppStore/screenshots-duo

struct Shot { let file: String; let headline: String; let sub: String; let colour: UInt32 }

let green: UInt32 = 0x29FF85, red: UInt32 = 0xFF4D4D, amber: UInt32 = 0xF5BD4D

let shots: [Shot] = [
    Shot(file: "01_title", headline: "NOW ON iPHONE DUO", sub: "Unfold it for the whole underworld.", colour: red),
    Shot(file: "02_market", headline: "THE WHOLE MARKET", sub: "Your stats and bag on the left, every price on the right.", colour: green),
    Shot(file: "03_travel", headline: "KEEP MOVING", sub: "A big map and every city, side by side.", colour: amber),
    Shot(file: "08_trade", headline: "BUY LOW. SELL HIGH.", sub: "Know your margin before you deal.", colour: green),
    Shot(file: "04_noirnet", headline: "HALF THE NEWS IS TRUE", sub: "Nobody tells you which half.", colour: green),
    Shot(file: "05_police", headline: "BRIBE. RUN. FIGHT.", sub: "Every stop is a gamble.", colour: red),
    Shot(file: "06_call", headline: "TRUST NO ONE", sub: "Kebab Kev has a tip. Probably.", colour: amber),
    Shot(file: "07_street", headline: "BUILD AN EMPIRE", sub: "Contracts, crew, fronts and turf.", colour: green),
]

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

for url in (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "NoirMarket/Resources/Fonts"), includingPropertiesForKeys: nil)) ?? [] {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func line(_ text: String, font: String, size: CGFloat, colour c: CGColor) -> CTLine {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: f, .foregroundColor: c]))
}

func draw(_ l: CTLine, in ctx: CGContext, centreX: CGFloat, baseline: CGFloat) {
    let w = CTLineGetTypographicBounds(l, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centreX - w / 2, y: baseline)
    CTLineDraw(l, ctx)
}

let W = 2853, H = 2007
let outDir = URL(fileURLWithPath: "AppStore/screenshots-duo")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for (i, shot) in shots.enumerated() {
    guard let img = NSImage(contentsOfFile: "AppStore/raw-duo/\(shot.file).png"),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("missing \(shot.file)"); continue }
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let w = CGFloat(W), h = CGFloat(H)

    // Ink black with a glow in the shot's colour behind the headline.
    ctx.setFillColor(colour(0x070707)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [colour(shot.colour, 0.28), colour(shot.colour, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: w / 2, y: h - 200), startRadius: 0, endCenter: CGPoint(x: w / 2, y: h - 200), endRadius: 1100, options: [])

    // Headline in Mona Sans Black with a neon glow, then a mono subline.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 44, color: colour(shot.colour, 0.85))
    var size: CGFloat = 150
    var l = line(shot.headline, font: "MonaSans-Black", size: size, colour: colour(shot.colour))
    while CTLineGetTypographicBounds(l, nil, nil, nil) > w - 300, size > 80 { size -= 4; l = line(shot.headline, font: "MonaSans-Black", size: size, colour: colour(shot.colour)) }
    draw(l, in: ctx, centreX: w / 2, baseline: h - 230)
    ctx.restoreGState()
    draw(line(shot.sub, font: "JetBrainsMono-Medium", size: 54, colour: colour(0xE8EAE8, 0.9)), in: ctx, centreX: w / 2, baseline: h - 350)

    // The unfolded screen, scaled into a rounded frame below.
    let top: CGFloat = 450, bottom: CGFloat = 70
    let sh = h - top - bottom
    let sw = sh * CGFloat(cg.width) / CGFloat(cg.height)
    let rect = CGRect(x: (w - sw) / 2, y: bottom, width: sw, height: sh)
    let path = CGPath(roundedRect: rect, cornerWidth: 70, cornerHeight: 70, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 70, color: colour(shot.colour, 0.35))
    ctx.addPath(path); ctx.setFillColor(colour(0x000000)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: rect)
    ctx.restoreGState()
    ctx.addPath(path); ctx.setStrokeColor(colour(0xFFFFFF, 0.18)); ctx.setLineWidth(4); ctx.strokePath()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let out = outDir.appendingPathComponent(String(format: "%02d_%@.jpg", i + 1, String(shot.file.dropFirst(3))))
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])!.write(to: out)
    print(out.lastPathComponent)
}
