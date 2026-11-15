import AVFoundation
import AppKit
import CoreText
import QuartzCore

// The TikTok cut: 1080×1920, ~22s, every cut on a beat of Tools/Trailer/make_beat.py (128 BPM).
// Hook in the first second, a drop on the logo slam, punch-in zooms, flashes, shakes, and a second
// drop on the case-file reveal. Captions sit in TikTok's safe zone (clear of the top bar and the
// caption/buttons area along the bottom and right).
// Run from native/:  swiftc -O Tools/Trailer/tiktok.swift -o /tmp/tiktok && /tmp/tiktok

let dir = "AppStore/video"
let res = "NoirMarket/Resources"
let W: CGFloat = 1080, H: CGFloat = 1920
let beat = 60.0 / 128.0

for url in (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "\(res)/Fonts"), includingPropertiesForKeys: nil)) ?? [] {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func cg(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// MARK: Sources

let clean = AVURLAsset(url: URL(fileURLWithPath: "\(dir)/tour-clean.mp4"))
let scenes: [String: Double] = {
    let start = Double(try! String(contentsOfFile: "\(dir)/tour-clean.start", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
    let timeline = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "\(dir)/tour-clean.timeline.json"))) as! [[String: Any]]
    var s: [String: Double] = [:]
    for e in timeline { s[e["scene"] as! String] = (e["at"] as! Double) - start + 1.0 }
    return s
}()
func clip(_ name: String) -> AVURLAsset { AVURLAsset(url: URL(fileURLWithPath: "\(dir)/clip-\(name).mp4")) }
let fight = clip("fight"), win = clip("win"), quit = clip("quit")
func at(_ scene: String, _ offset: Double = 0.9) -> Double { scenes[scene]! + offset }

// MARK: The edit

struct Caption { let text: String; var accent: UInt32 = 0x29FF85; var atBeat: Double = 0; var beats: Double? = nil; var y: CGFloat = 0.36 }

struct Cut {
    let asset: AVURLAsset
    let from: Double
    let beats: Double
    var focus: CGFloat = 0.45      // vertical point of interest in the recording, 0 top … 1 bottom
    var zoom: CGFloat = 1.08       // on top of filling the frame
    var captions: [Caption] = []
    var sfx: [(String, Double, Float)] = []   // name, beats into the cut, volume
    var flash: UInt32? = nil
    var shake = false
}

let cuts: [Cut] = [
    // Hook: the police stop, siren wailing.
    Cut(asset: clean, from: at("police", 0.3), beats: 4, focus: 0.5, zoom: 1.0,
        captions: [Caption(text: "THE COPS\nJUST PULLED UP", accent: 0xFF4D4D, atBeat: 0, beats: 2),
                   Caption(text: "BRIBE. RUN.\nOR FIGHT?", accent: 0xFF4D4D, atBeat: 2)],
        sfx: [("siren", 0, 0.55)]),
    // DROP: the Redhead brain slams together.
    Cut(asset: clean, from: 2.78, beats: 2, focus: 0.47, zoom: 1.05, sfx: [("squish", 0.25, 1.0)], flash: 0xFFFFFF, shake: true),
    Cut(asset: clean, from: at("title", 0.6), beats: 2, focus: 0.33, zoom: 1.12,
        captions: [Caption(text: "30 NIGHTS.\nGET RICH.", accent: 0xFF4D4D)]),
    Cut(asset: clean, from: at("market"), beats: 2, focus: 0.45, zoom: 1.18, captions: [Caption(text: "BUY\nCHEAP")]),
    Cut(asset: win, from: 2.45, beats: 2, focus: 0.33, zoom: 1.25, captions: [Caption(text: "SELL\nDEAR")],
        sfx: [("cash", 0.15, 0.8)], flash: 0x29FF85),
    Cut(asset: clean, from: at("travel"), beats: 2, focus: 0.3, zoom: 1.12, captions: [Caption(text: "14\nCITIES", accent: 0xF5BD4D)],
        sfx: [("train", 0, 0.5)]),
    Cut(asset: clean, from: at("call"), beats: 2, focus: 0.42, zoom: 1.12, captions: [Caption(text: "SNITCHES\nCALL YOU", accent: 0xF5BD4D)],
        sfx: [("ring", 0, 0.55)]),
    Cut(asset: clean, from: at("noirnet", 1.5), beats: 2, focus: 0.25, zoom: 1.18, captions: [Caption(text: "HALF THE NEWS\nIS FAKE")]),
    Cut(asset: fight, from: 3.2, beats: 2, focus: 0.3, zoom: 1.12, captions: [Caption(text: "WATCH\nYOUR BACK", accent: 0xFF4D4D)],
        sfx: [("knuckles", 0.1, 0.9), ("thud", 1.0, 0.8)], shake: true),
    Cut(asset: clean, from: at("raid"), beats: 2, focus: 0.5, zoom: 1.06, captions: [Caption(text: "RAID\nINCOMING", accent: 0xFFE600)],
        sfx: [("siren", 0, 0.4)], flash: 0xFFE600),
    Cut(asset: clean, from: at("money"), beats: 2, focus: 0.45, zoom: 1.12, captions: [Caption(text: "WASH\nTHE CASH")]),
    Cut(asset: clean, from: at("street"), beats: 2, focus: 0.35, zoom: 1.12, captions: [Caption(text: "BUILD AN\nEMPIRE")]),
    // Build-up into the second drop.
    Cut(asset: clean, from: at("ending"), beats: 6, focus: 0.4, zoom: 1.04,
        captions: [Caption(text: "HOW DOES\nIT END?", accent: 0xF5BD4D, atBeat: 0, beats: 4),
                   Caption(text: "RETIRE\nA LEGEND…", accent: 0x29FF85, atBeat: 4)]),
    // DROP 2: the case file.
    Cut(asset: clean, from: at("caseFile", 0.8), beats: 3, focus: 0.16, zoom: 1.28, sfx: [("win", 0, 0.7)], flash: 0x29FF85, shake: true),
    Cut(asset: quit, from: 2.7, beats: 3, focus: 0.14, zoom: 1.28, captions: [Caption(text: "…OR\nBOTTLE IT.", accent: 0xFF4D4D, y: 0.6)],
        sfx: [("lose", 0.1, 0.7)]),
    // End card over the neon title.
    Cut(asset: clean, from: at("finish", 0.8), beats: 8, focus: 0.36, zoom: 1.0, flash: 0xFFFFFF),
]

// MARK: Drawing helpers

func bitmap(_ size: CGSize, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}

/// A TikTok-style caption: heavy white type with a thick black outline; the last line in the accent colour with a glow.
func captionImage(_ text: String, accent: UInt32) -> CGImage {
    let size = CGSize(width: W, height: 520)
    return bitmap(size) { ctx in
        let lines = text.components(separatedBy: "\n")
        let base: CGFloat = 150
        var y: CGFloat = size.height / 2 + CGFloat(lines.count) * base * 0.46 - base * 0.78
        for (i, line) in lines.enumerated() {
            let last = i == lines.count - 1
            let colour = last ? cg(accent) : cg(0xFFFFFF)
            var fs = base
            func make(_ stroke: Bool) -> CTLine {
                let font = CTFontCreateWithName("MonaSans-Black" as CFString, fs, nil)
                var attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: -2]
                if stroke { attrs[.strokeColor] = cg(0x000000); attrs[.strokeWidth] = 18 } else { attrs[.foregroundColor] = colour }
                return CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attrs))
            }
            while CTLineGetTypographicBounds(make(false), nil, nil, nil) > W * 0.86, fs > 40 { fs -= 6 }
            let fill = make(false), outline = make(true)
            let w = CTLineGetTypographicBounds(fill, nil, nil, nil)
            let pos = CGPoint(x: (W - w) / 2, y: y)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: cg(0x000000, 0.85))
            ctx.textPosition = pos; CTLineDraw(outline, ctx)
            ctx.restoreGState()
            ctx.saveGState()
            if last { ctx.setShadow(offset: .zero, blur: 40, color: cg(accent, 0.95)) }
            ctx.textPosition = pos; CTLineDraw(fill, ctx)
            ctx.restoreGState()
            y -= base * 0.92
        }
    }
}

func endCardImage() -> CGImage {
    bitmap(CGSize(width: W, height: H)) { ctx in
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [cg(0x000000, 0.2), cg(0x000000, 0.35), cg(0x000000, 0.94), cg(0x000000, 0.97)] as CFArray, locations: [0, 0.5, 0.62, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
        func line(_ s: String, font: String, size: CGFloat, colour: UInt32, glow: CGFloat, yFromTop: CGFloat) {
            let l = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
                .font: CTFontCreateWithName(font as CFString, size, nil), .foregroundColor: cg(colour)]))
            let w = CTLineGetTypographicBounds(l, nil, nil, nil)
            ctx.saveGState()
            if glow > 0 { ctx.setShadow(offset: .zero, blur: glow, color: cg(colour, 0.95)) }
            ctx.textPosition = CGPoint(x: (W - w) / 2, y: H - yFromTop); CTLineDraw(l, ctx)
            ctx.restoreGState()
        }
        line("FREE ON THE", font: "JetBrainsMono-Bold", size: 52, colour: 0xEDEDED, glow: 0, yFromTop: 1290)
        line("APP STORE", font: "MonaSans-Black", size: 130, colour: 0x29FF85, glow: 36, yFromTop: 1430)
        line("Search “Noir Market”", font: "JetBrainsMono-Bold", size: 44, colour: 0xEDEDED, glow: 0, yFromTop: 1530)
        line("fiction · 18+ · entertainment only", font: "JetBrainsMono-Bold", size: 28, colour: 0x8A8A8A, glow: 0, yFromTop: 1610)
    }
}

func layer(_ image: CGImage, _ frame: CGRect) -> CALayer {
    let l = CALayer(); l.contents = image; l.frame = frame; l.contentsGravity = .resize; return l
}

func anim(_ key: String, values: [Any], times: [Double], at start: Double, length: Double, fill: CAMediaTimingFillMode = .forwards) -> CAKeyframeAnimation {
    let a = CAKeyframeAnimation(keyPath: key)
    a.values = values
    a.keyTimes = times.map { NSNumber(value: $0) }
    a.beginTime = AVCoreAnimationBeginTimeAtZero + start
    a.duration = length
    a.isRemovedOnCompletion = false
    // Forwards only: holding the first value backwards would show every flash and caption from time zero.
    a.fillMode = fill
    return a
}

// MARK: Render

func render() async {
    let comp = AVMutableComposition()
    let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
    var t = 0.0
    var starts: [Double] = []
    let ts: (Double) -> CMTime = { CMTime(seconds: $0, preferredTimescale: 6000) }

    for c in cuts {
        let src = try! await c.asset.loadTracks(withMediaType: .video)[0]
        let nat = try! await src.load(.naturalSize)
        let len = c.beats * beat
        try! vTrack.insertTimeRange(CMTimeRange(start: ts(c.from), duration: ts(len)), of: src, at: ts(t))
        // Fill the frame, centre on the point of interest, and push in over the cut.
        func transform(_ z: CGFloat) -> CGAffineTransform {
            let s = W / nat.width * c.zoom * z
            let h = nat.height * s, w = nat.width * s
            let ty = min(0, max(H - h, H * 0.5 - c.focus * h))
            let tx = (W - w) / 2
            return CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: tx, y: ty))
        }
        li.setTransformRamp(fromStart: transform(1.0), toEnd: transform(1.07), timeRange: CMTimeRange(start: ts(t), duration: ts(len)))
        starts.append(t)
        t += len
    }
    let total = t

    // Audio: the beat, plus effects on the hits.
    var params: [AVMutableAudioMixInputParameters] = []
    let beatAsset = AVURLAsset(url: URL(fileURLWithPath: "\(dir)/beat.wav"))
    let bTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try! bTrack.insertTimeRange(CMTimeRange(start: .zero, duration: ts(total)), of: try! await beatAsset.loadTracks(withMediaType: .audio)[0], at: .zero)
    let bp = AVMutableAudioMixInputParameters(track: bTrack)
    bp.setVolume(0.95, at: .zero)
    bp.setVolumeRamp(fromStartVolume: 0.95, toEndVolume: 0, timeRange: CMTimeRange(start: ts(total - 1.2), duration: ts(1.2)))
    params.append(bp)
    for (c, start) in zip(cuts, starts) {
        for (name, b, vol) in c.sfx {
            let a = AVURLAsset(url: URL(fileURLWithPath: "\(res)/\(name).wav"))
            guard let s = try? await a.loadTracks(withMediaType: .audio).first else { continue }
            let d = try! await a.load(.duration)
            let tr = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            let room = min(d.seconds, total - (start + b * beat))
            try? tr.insertTimeRange(CMTimeRange(start: .zero, duration: ts(room)), of: s, at: ts(start + b * beat))
            let p = AVMutableAudioMixInputParameters(track: tr); p.setVolume(vol, at: .zero); params.append(p)
        }
    }
    let mix = AVMutableAudioMix(); mix.inputParameters = params

    let vc = AVMutableVideoComposition()
    vc.renderSize = CGSize(width: W, height: H)
    vc.frameDuration = CMTime(value: 1, timescale: 30)
    let ins = AVMutableVideoCompositionInstruction()
    ins.timeRange = CMTimeRange(start: .zero, duration: ts(total))
    ins.layerInstructions = [li]
    ins.backgroundColor = cg(0x000000)
    vc.instructions = [ins]

    let parent = CALayer(); parent.frame = CGRect(x: 0, y: 0, width: W, height: H); parent.isGeometryFlipped = true
    let video = CALayer(); video.frame = parent.frame
    parent.addSublayer(video)

    for (c, start) in zip(cuts, starts) {
        let len = c.beats * beat
        // Screen shake on impacts.
        if c.shake {
            let offsets: [CGFloat] = [0, -22, 18, -14, 10, -6, 3, 0]
            video.add(anim("transform.translation.x", values: offsets, times: (0..<offsets.count).map { Double($0) / Double(offsets.count - 1) }, at: start, length: 0.32), forKey: "sx\(start)")
            video.add(anim("transform.translation.y", values: offsets.map { -$0 * 0.6 }, times: (0..<offsets.count).map { Double($0) / Double(offsets.count - 1) }, at: start, length: 0.32), forKey: "sy\(start)")
        }
        // Colour flash on the cut.
        if let f = c.flash {
            let flash = CALayer(); flash.frame = parent.frame; flash.backgroundColor = cg(f); flash.opacity = 0
            flash.add(anim("opacity", values: [0.85, 0.35, 0], times: [0, 0.35, 1], at: start, length: 0.22), forKey: "flash")
            parent.addSublayer(flash)
        }
        // Captions pop in on the beat.
        for cap in c.captions {
            let begin = start + cap.atBeat * beat
            let dur = (cap.beats ?? (c.beats - cap.atBeat)) * beat
            let img = captionImage(cap.text, accent: cap.accent)
            let l = layer(img, CGRect(x: 0, y: H * cap.y - 260, width: W, height: 520))
            l.opacity = 0
            let pop = min(0.14, dur * 0.25)
            l.add(anim("opacity", values: [0, 1, 1, 0], times: [0, pop / dur, (dur - 0.06) / dur, 1], at: begin, length: dur), forKey: "o")
            l.add(anim("transform.scale", values: [1.45, 0.94, 1.0, 1.03], times: [0, pop / dur, (pop + 0.08) / dur, 1], at: begin, length: dur), forKey: "s")
            parent.addSublayer(l)
        }
    }
    // End card over the last cut, after a beat of the neon title.
    let lastStart = starts.last!
    let card = layer(endCardImage(), parent.frame)
    card.opacity = 0
    let cardLen = total - lastStart - beat
    card.add(anim("opacity", values: [0, 1, 1], times: [0, 0.12, 1], at: lastStart + beat, length: cardLen), forKey: "o")
    parent.addSublayer(card)

    vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)

    let url = URL(fileURLWithPath: "\(dir)/trailer-tiktok.mp4")
    try? FileManager.default.removeItem(at: url)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = vc
    ex.audioMix = mix
    do {
        try await ex.export(to: url, as: .mp4)
        print("wrote trailer-tiktok.mp4: \(String(format: "%.1f", total))s, 1080×1920")
    } catch {
        print("failed: \(error)")
    }
}

await render()
