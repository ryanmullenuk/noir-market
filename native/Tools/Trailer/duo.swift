import AVFoundation
import AppKit
import CoreText
import QuartzCore

// Cuts a 30-second landscape promo for the iPhone Duo from the inner-screen tour recording.
// Record first:  UDID=<duo> REC_DISPLAY=3 OUT_NAME=tour-duo Tools/record_tour.sh clean
// Then from native/:  swiftc -O Tools/Trailer/duo.swift -o /tmp/duotrailer && /tmp/duotrailer
// Writes AppStore/video/duo-promo.mp4 (1920×1080, 30s).

let dir = "AppStore/video"
let res = "NoirMarket/Resources"

for url in (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "\(res)/Fonts"), includingPropertiesForKeys: nil)) ?? [] {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

struct Recording {
    let asset: AVURLAsset
    let scenes: [String: Double]   // scene → seconds into the video
    init(_ name: String) {
        asset = AVURLAsset(url: URL(fileURLWithPath: "\(dir)/\(name).mp4"))
        let start = Double(try! String(contentsOfFile: "\(dir)/\(name).start", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
        let timeline = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(name).timeline.json"))) as! [[String: Any]]
        // The recorder starts about a second before the start time is written.
        var s: [String: Double] = [:]
        for e in timeline { s[e["scene"] as! String] = (e["at"] as! Double) - start + 1.0 }
        scenes = s
    }
}

struct Cut {
    let from: Double      // seconds into the recording
    let length: Double
    var caption: String? = nil
    var sub: String? = nil
    var colour: UInt32 = 0x29FF85
    var sfx: (String, Double, Float)? = nil   // effect, seconds into this cut, volume
}

func cg(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// Draws centred lines of text into a context, with an optional neon glow. y is from the top.
func drawText(_ ctx: CGContext, _ text: String, font: String, size: CGFloat, colour: CGColor, glow: CGColor?, centreX: CGFloat, top: CGFloat, height: CGFloat, lineGap: CGFloat = 0.95) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let lines = text.components(separatedBy: "\n")
    for (i, line) in lines.enumerated() {
        var fit = size
        var l = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [.font: f, .foregroundColor: colour]))
        while CTLineGetTypographicBounds(l, nil, nil, nil) > CGFloat(ctx.width) * 0.9, fit > 10 {
            fit -= 2
            l = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [.font: CTFontCreateWithName(font as CFString, fit, nil), .foregroundColor: colour]))
        }
        let w = CTLineGetTypographicBounds(l, nil, nil, nil)
        let baselineFromTop = top + fit * 0.9 + CGFloat(i) * fit * lineGap
        ctx.saveGState()
        if let glow { ctx.setShadow(offset: .zero, blur: fit * 0.45, color: glow) }
        ctx.textPosition = CGPoint(x: centreX - w / 2, y: height - baselineFromTop)
        CTLineDraw(l, ctx)
        ctx.restoreGState()
    }
}

func bitmap(_ size: CGSize, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}

func imageLayer(_ image: CGImage, frame: CGRect) -> CALayer {
    let l = CALayer()
    l.contents = image
    l.frame = frame
    l.contentsGravity = .resize
    return l
}

/// Fades a layer in and out over [start, start+length] in the composition.
func show(_ layer: CALayer, at start: Double, for length: Double) {
    layer.opacity = 0
    let a = CAKeyframeAnimation(keyPath: "opacity")
    let fade = min(0.25, length / 4)
    a.values = [0, 1, 1, 0]
    a.keyTimes = [0, NSNumber(value: fade / length), NSNumber(value: (length - fade) / length), 1]
    a.beginTime = AVCoreAnimationBeginTimeAtZero + start
    a.duration = length
    a.isRemovedOnCompletion = false
    a.fillMode = .both
    layer.add(a, forKey: "show")
}


func renderDuo(_ rec: Recording, cuts: [Cut], size: CGSize, out: String) async {
    let comp = AVMutableComposition()
    let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let src = try! await rec.asset.loadTracks(withMediaType: .video)[0]
    let natural = try! await src.load(.naturalSize)
    var t = 0.0
    var placed: [(Cut, Double)] = []
    for c in cuts {
        try! vTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: c.from, preferredTimescale: 600), duration: CMTime(seconds: c.length, preferredTimescale: 600)),
                                    of: src, at: CMTime(seconds: t, preferredTimescale: 600))
        placed.append((c, t)); t += c.length
    }
    // Hold the last frame under the end card.
    let endLength = 3.0, last = cuts.last!
    try! vTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: last.from + last.length - 0.05, preferredTimescale: 600), duration: CMTime(seconds: 0.05, preferredTimescale: 600)),
                                of: src, at: CMTime(seconds: t, preferredTimescale: 600))
    vTrack.scaleTimeRange(CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 600), duration: CMTime(seconds: 0.05, preferredTimescale: 600)),
                          toDuration: CMTime(seconds: endLength, preferredTimescale: 600))
    let total = t + endLength

    // Audio: the theme with a fade out, plus effects.
    var params: [AVMutableAudioMixInputParameters] = []
    let musicAsset = AVURLAsset(url: URL(fileURLWithPath: "\(res)/game-music.mp3"))
    let mTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let msrc = try! await musicAsset.loadTracks(withMediaType: .audio)[0]
    try! mTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: total, preferredTimescale: 600)), of: msrc, at: .zero)
    let mp = AVMutableAudioMixInputParameters(track: mTrack)
    mp.setVolume(0.8, at: .zero)
    mp.setVolumeRamp(fromStartVolume: 0.8, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: total - 2, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600)))
    params.append(mp)
    for (c, start) in placed {
        guard let (name, offset, vol) = c.sfx else { continue }
        let a = AVURLAsset(url: URL(fileURLWithPath: "\(res)/\(name).wav"))
        guard let s = try? await a.loadTracks(withMediaType: .audio).first else { continue }
        let d = try! await a.load(.duration)
        let tr = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try? tr.insertTimeRange(CMTimeRange(start: .zero, duration: d), of: s, at: CMTime(seconds: start + offset, preferredTimescale: 600))
        let p = AVMutableAudioMixInputParameters(track: tr); p.setVolume(vol, at: .zero); params.append(p)
    }
    let mix = AVMutableAudioMix(); mix.inputParameters = params

    // Picture: the inner screen is recorded in its native portrait orientation; turn it upright, then fit the height.
    let landscapeW = natural.height, landscapeH = natural.width
    let scale = size.height / landscapeH
    let x = (size.width - landscapeW * scale) / 2
    let upright = CGAffineTransform(rotationAngle: .pi / 2).concatenating(CGAffineTransform(translationX: natural.height, y: 0))
    let vc = AVMutableVideoComposition()
    vc.renderSize = size
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
    li.setTransform(upright.concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: x, y: 0)), at: .zero)
    let ins = AVMutableVideoCompositionInstruction()
    ins.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: total, preferredTimescale: 600))
    ins.layerInstructions = [li]
    ins.backgroundColor = cg(0x000000)
    vc.instructions = [ins]

    let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: size); parent.isGeometryFlipped = true
    let video = CALayer(); video.frame = parent.frame
    parent.addSublayer(video)
    let w = size.width, h = size.height
    // Lower-third captions over a dark gradient.
    for (c, start) in placed {
        guard let caption = c.caption else { continue }
        let band = CGSize(width: w, height: (h * 0.36).rounded())
        let img = bitmap(band) { ctx in
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [cg(0x000000, 0), cg(0x000000, 0.8), cg(0x000000, 0.94)] as CFArray, locations: [0, 0.45, 1])!
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: band.height), end: CGPoint(x: 0, y: 0), options: [])
            let size: CGFloat = h * 0.115
            drawText(ctx, caption, font: "MonaSans-Black", size: size, colour: cg(c.colour), glow: cg(c.colour, 0.9),
                     centreX: w / 2, top: band.height - (c.sub == nil ? h * 0.20 : h * 0.245), height: band.height)
            if let sub = c.sub {
                drawText(ctx, sub, font: "JetBrainsMono-Bold", size: h * 0.036, colour: cg(0xEDEDED, 0.92), glow: nil,
                         centreX: w / 2, top: band.height - h * 0.085, height: band.height)
            }
        }
        let l = imageLayer(img, frame: CGRect(x: 0, y: h - band.height, width: w, height: band.height))
        show(l, at: start + 0.1, for: c.length - 0.15)
        parent.addSublayer(l)
    }
    // End card.
    let card = bitmap(size) { ctx in
        ctx.setFillColor(cg(0x000000, 0.86)); ctx.fill(CGRect(origin: .zero, size: size))
        drawText(ctx, "NOIR", font: "MonaSans-Black", size: h * 0.24, colour: cg(0xFFFFFF), glow: cg(0xFFFFFF, 0.6), centreX: w / 2, top: h * 0.12, height: h)
        drawText(ctx, "MARKET", font: "MonaSans-Black", size: h * 0.17, colour: cg(0xFF4D4D), glow: cg(0xFF4D4D, 0.95), centreX: w / 2, top: h * 0.35, height: h)
        drawText(ctx, "NOW ON iPHONE DUO", font: "MonaSans-Black", size: h * 0.08, colour: cg(0x29FF85), glow: cg(0x29FF85, 0.8), centreX: w / 2, top: h * 0.62, height: h)
        drawText(ctx, "Trade smart · Play dirty · Come out on top", font: "JetBrainsMono-Bold", size: h * 0.034, colour: cg(0xEDEDED), glow: nil, centreX: w / 2, top: h * 0.76, height: h)
        drawText(ctx, "OUT NOW ON THE APP STORE", font: "JetBrainsMono-Bold", size: h * 0.03, colour: cg(0xF5BD4D), glow: nil, centreX: w / 2, top: h * 0.84, height: h)
    }
    let cardLayer = imageLayer(card, frame: parent.frame)
    show(cardLayer, at: t, for: endLength + 0.2)
    parent.addSublayer(cardLayer)
    vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)

    let url = URL(fileURLWithPath: "\(dir)/\(out)")
    try? FileManager.default.removeItem(at: url)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = vc; ex.audioMix = mix
    do { try await ex.export(to: url, as: .mp4); print("wrote \(out): \(String(format: "%.1f", total))s, \(Int(w))×\(Int(h))") }
    catch { print("failed \(out): \(error)") }
}

let duo = Recording("tour-duo")
func at(_ scene: String, _ offset: Double = 0.9) -> Double { duo.scenes[scene]! + offset }

let cuts: [Cut] = [
    Cut(from: 3.4, length: 2.4, sfx: ("squish", 0.8, 1.0)),
    Cut(from: at("title", 1.4), length: 2.6, caption: "NOW ON iPHONE DUO", colour: 0xFF4D4D),
    Cut(from: at("market"), length: 2.8, caption: "THE WHOLE MARKET", sub: "Unfold it: your stats on the left, every price on the right."),
    Cut(from: at("trade"), length: 2.2, caption: "BUY LOW. SELL HIGH.", sfx: ("cash", 0.9, 0.7)),
    Cut(from: at("travel"), length: 2.4, caption: "KEEP MOVING", sub: "14 cities across the UK and Ireland.", colour: 0xF5BD4D, sfx: ("train", 0.2, 0.5)),
    Cut(from: at("noirnet", 0.6), length: 2.4, caption: "HALF THE NEWS IS TRUE"),
    Cut(from: at("call"), length: 2.0, caption: "TRUST NO ONE", colour: 0xF5BD4D, sfx: ("calltone", 0.0, 0.5)),
    Cut(from: at("police"), length: 2.0, caption: "BRIBE. RUN. FIGHT.", colour: 0xFF4D4D, sfx: ("siren", 0.0, 0.45)),
    Cut(from: at("raid"), length: 2.2, caption: "THE HEAT IS COMING", colour: 0xFFE600),
    Cut(from: at("street"), length: 2.0, caption: "BUILD AN EMPIRE"),
    Cut(from: at("ending"), length: 2.0, caption: "HOW DOES IT END?", colour: 0xF5BD4D),
    Cut(from: at("caseFile", 1.2), length: 2.0, sfx: ("win", 0.0, 0.6)),
]

await renderDuo(duo, cuts: cuts, size: CGSize(width: 1920, height: 1080), out: "duo-promo.mp4")
