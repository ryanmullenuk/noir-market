import AVFoundation
import AppKit
import CoreText
import QuartzCore

// Cuts trailers and the walkthrough video from the tour recordings (Tools/record_tour.sh).
// Run from native/:  swiftc -O Tools/Trailer/main.swift -o /tmp/trailer && /tmp/trailer
// Writes AppStore/video/: app-preview.mp4 (886×1920, ≤30s, for the App Store),
// trailer-social.mp4 (1080×1920, ~40s, for Reels/TikTok/Shorts) and walkthrough.mp4 (the full captioned tour).

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

func render(_ rec: Recording, cuts: [Cut], size: CGSize, endCard: (String, String)?, music: Bool, out: String) async {
    let comp = AVMutableComposition()
    let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let src = try! await rec.asset.loadTracks(withMediaType: .video)[0]
    let natural = try! await src.load(.naturalSize)
    var t = 0.0
    var placed: [(Cut, Double)] = []
    for c in cuts {
        let range = CMTimeRange(start: CMTime(seconds: c.from, preferredTimescale: 600), duration: CMTime(seconds: c.length, preferredTimescale: 600))
        try! vTrack.insertTimeRange(range, of: src, at: CMTime(seconds: t, preferredTimescale: 600))
        placed.append((c, t))
        t += c.length
    }
    let endLength = endCard == nil ? 0.0 : 3.0
    if endCard != nil {
        // Hold the final frame under the end card.
        let last = cuts.last!
        let hold = CMTimeRange(start: CMTime(seconds: last.from + last.length - 0.05, preferredTimescale: 600), duration: CMTime(seconds: 0.05, preferredTimescale: 600))
        try! vTrack.insertTimeRange(hold, of: src, at: CMTime(seconds: t, preferredTimescale: 600))
        vTrack.scaleTimeRange(CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 600), duration: CMTime(seconds: 0.05, preferredTimescale: 600)),
                              toDuration: CMTime(seconds: endLength, preferredTimescale: 600))
    }
    let total = t + endLength

    // Audio: the game's theme, plus effects on the beats.
    var params: [AVMutableAudioMixInputParameters] = []
    if music {
        let musicAsset = AVURLAsset(url: URL(fileURLWithPath: "\(res)/game-music.mp3"))
        let mTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let msrc = try! await musicAsset.loadTracks(withMediaType: .audio)[0]
        let mdur = try! await musicAsset.load(.duration).seconds
        var at = 0.0
        while at < total {
            let len = min(mdur, total - at)
            try! mTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: len, preferredTimescale: 600)), of: msrc, at: CMTime(seconds: at, preferredTimescale: 600))
            at += len
        }
        let p = AVMutableAudioMixInputParameters(track: mTrack)
        p.setVolume(0.75, at: .zero)
        p.setVolumeRamp(fromStartVolume: 0.75, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: total - 1.8, preferredTimescale: 600), duration: CMTime(seconds: 1.8, preferredTimescale: 600)))
        params.append(p)
    }
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

    // Picture: fit the phone recording to the frame height, centred, on black.
    let vc = AVMutableVideoComposition()
    vc.renderSize = size
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    let scale = size.height / natural.height
    let x = (size.width - natural.width * scale) / 2
    let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
    li.setTransform(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: x, y: 0)), at: .zero)
    let ins = AVMutableVideoCompositionInstruction()
    ins.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: total, preferredTimescale: 600))
    ins.layerInstructions = [li]
    ins.backgroundColor = cg(0x000000)
    vc.instructions = [ins]

    // Captions and end card.
    let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: size); parent.isGeometryFlipped = true
    let video = CALayer(); video.frame = parent.frame
    parent.addSublayer(video)
    let w = size.width
    for (c, start) in placed {
        guard let caption = c.caption else { continue }
        let bandSize = CGSize(width: w, height: (size.height * 0.30).rounded())
        let img = bitmap(bandSize) { ctx in
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [cg(0x000000, 0.92), cg(0x000000, 0.75), cg(0x000000, 0)] as CFArray, locations: [0, 0.6, 1])!
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: bandSize.height), end: CGPoint(x: 0, y: 0), options: [])
            drawText(ctx, caption, font: "MonaSans-Black", size: w * 0.105, colour: cg(c.colour), glow: cg(c.colour, 0.9),
                     centreX: w / 2, top: size.height * 0.07, height: bandSize.height)
            if let sub = c.sub {
                let lines = CGFloat(caption.components(separatedBy: "\n").count)
                drawText(ctx, sub, font: "JetBrainsMono-Bold", size: w * 0.036, colour: cg(0xEDEDED, 0.92), glow: nil,
                         centreX: w / 2, top: size.height * 0.07 + w * 0.105 * (lines * 0.95 + 0.35), height: bandSize.height)
            }
        }
        let band = imageLayer(img, frame: CGRect(origin: .zero, size: bandSize))
        show(band, at: start + 0.1, for: c.length - 0.15)
        parent.addSublayer(band)
    }
    if let (line1, line2) = endCard {
        let img = bitmap(size) { ctx in
            ctx.setFillColor(cg(0x000000, 0.8)); ctx.fill(CGRect(origin: .zero, size: size))
            let top = size.height * 0.34
            drawText(ctx, "NOIR", font: "MonaSans-Black", size: w * 0.26, colour: cg(0xFFFFFF), glow: cg(0xFFFFFF, 0.6), centreX: w / 2, top: top, height: size.height)
            drawText(ctx, "MARKET", font: "MonaSans-Black", size: w * 0.18, colour: cg(0xFF4D4D), glow: cg(0xFF4D4D, 0.95), centreX: w / 2, top: top + w * 0.25, height: size.height)
            drawText(ctx, line1, font: "JetBrainsMono-Bold", size: w * 0.038, colour: cg(0xEDEDED), glow: nil, centreX: w / 2, top: top + w * 0.5, height: size.height)
            drawText(ctx, line2, font: "MonaSans-Black", size: w * 0.064, colour: cg(0x29FF85), glow: cg(0x29FF85, 0.8), centreX: w / 2, top: top + w * 0.62, height: size.height)
        }
        let card = imageLayer(img, frame: parent.frame)
        show(card, at: t, for: endLength + 0.2)
        parent.addSublayer(card)
    }
    vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)

    let url = URL(fileURLWithPath: "\(dir)/\(out)")
    try? FileManager.default.removeItem(at: url)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = vc
    ex.audioMix = mix
    do {
        try await ex.export(to: url, as: .mp4)
        print("wrote \(out): \(String(format: "%.1f", total))s, \(Int(size.width))×\(Int(size.height))")
    } catch {
        print("failed \(out): \(error)")
    }
}

let clean = Recording("tour-clean")
func at(_ scene: String, _ offset: Double = 0.9) -> Double { clean.scenes[scene]! + offset }

// The logo slam sits a few seconds into the recording, before the tour starts.
let logo = Cut(from: 2.45, length: 2.3, sfx: ("squish", 0.45, 1.0))
let titleCut = Cut(from: at("title", 0.4), length: 2.6, caption: "TRADE SMART.\nPLAY DIRTY.", colour: 0xFF4D4D)

let preview: [Cut] = [
    logo,
    titleCut,
    Cut(from: at("market"), length: 2.6, caption: "READ THE MARKET", sub: "14 cities. Prices move every night."),
    Cut(from: at("trade"), length: 2.3, caption: "BUY LOW.\nSELL HIGH.", sfx: ("cash", 0.9, 0.7)),
    Cut(from: at("travel"), length: 2.4, caption: "KEEP MOVING", colour: 0xF5BD4D, sfx: ("train", 0.2, 0.5)),
    Cut(from: at("noirnet", 0.6), length: 2.6, caption: "HALF THE NEWS\nIS TRUE"),
    Cut(from: at("police"), length: 2.4, caption: "BRIBE. RUN.\nFIGHT.", colour: 0xFF4D4D, sfx: ("siren", 0.0, 0.45)),
    Cut(from: at("raid"), length: 2.6, caption: "THE HEAT\nIS COMING", colour: 0xFFE600),
    Cut(from: at("street"), length: 2.4, caption: "BUILD AN EMPIRE"),
    Cut(from: at("ending"), length: 2.3, caption: "HOW DOES\nIT END?", colour: 0xF5BD4D),
    Cut(from: at("caseFile", 1.2), length: 2.6, sfx: ("win", 0.0, 0.6)),
    Cut(from: at("finish", 1.2), length: 1.6),
]

let social: [Cut] = [
    logo,
    titleCut,
    Cut(from: at("market"), length: 3.0, caption: "READ THE MARKET", sub: "14 cities. Prices move every night."),
    Cut(from: at("trade"), length: 2.6, caption: "BUY LOW.\nSELL HIGH.", sfx: ("cash", 1.0, 0.7)),
    Cut(from: at("stats"), length: 2.4, caption: "MIND THE HEAT", colour: 0xFF4D4D),
    Cut(from: at("travel"), length: 2.6, caption: "KEEP MOVING", colour: 0xF5BD4D, sfx: ("train", 0.2, 0.5)),
    Cut(from: at("noirnet", 0.6), length: 3.0, caption: "HALF THE NEWS\nIS TRUE", sub: "Nobody tells you which half."),
    Cut(from: at("call"), length: 2.6, caption: "TRUST NO ONE", colour: 0xF5BD4D, sfx: ("ring", 0.0, 0.55)),
    Cut(from: at("police"), length: 2.6, caption: "BRIBE. RUN.\nFIGHT.", colour: 0xFF4D4D, sfx: ("siren", 0.0, 0.45)),
    Cut(from: at("raid"), length: 3.0, caption: "THE HEAT\nIS COMING", colour: 0xFFE600),
    Cut(from: at("money"), length: 2.6, caption: "WASH THE MONEY"),
    Cut(from: at("street"), length: 2.6, caption: "BUILD AN EMPIRE"),
    Cut(from: at("ending"), length: 2.6, caption: "HOW DOES\nIT END?", colour: 0xF5BD4D),
    Cut(from: at("caseFile", 1.2), length: 3.0, sfx: ("win", 0.0, 0.6)),
]

let walk = Recording("walkthrough-raw")
let walkLength = walk.scenes["end"]! + 1.0

await render(clean, cuts: preview, size: CGSize(width: 886, height: 1920), endCard: nil, music: true, out: "app-preview.mp4")
await render(clean, cuts: social, size: CGSize(width: 1080, height: 1920),
             endCard: ("Trade smart · Play dirty · Come out on top", "OUT NOW ON THE APP STORE"), music: true, out: "trailer-social.mp4")
await render(walk, cuts: [Cut(from: 2.0, length: walkLength - 2.0, sfx: ("squish", 0.9, 1.0))], size: CGSize(width: 886, height: 1920),
             endCard: nil, music: true, out: "walkthrough.mp4")
