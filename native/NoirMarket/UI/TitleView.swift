import SwiftUI

/// Redhead Games logo, then NOIR MARKET under falling powder that settles on the buttons.
struct TitleView: View {
    var hasSave: Bool
    /// "DAY 12 · LONDON · £8,450" for the save waiting to continue.
    var saveSummary: String? = nil
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onHowTo: () -> Void
    var onSettings: () -> Void
    var onRecords: () -> Void

    /// 0 logo, 1 black, 2 disclaimer, 3 black, 4 title.
    @State private var phase = 0
    @State private var titleIn = false
    @State private var noirOn = false
    @State private var marketOn = false
    @State private var buttonsIn = false
    @State private var sequence: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Pure black so the Redhead logo (on black) blends with no visible box.
            Color.black.ignoresSafeArea()
            switch phase {
            case 0:
                Image("RedheadLogo")
                    .resizable().scaledToFit()
                    .frame(width: 240)
                    .transition(.opacity)
                    .accessibilityLabel("Redhead Games")
            case 2:
                Disclaimer().transition(.opacity)
            case 4:
                ZStack {
                    Noir.ink.ignoresSafeArea()
                    title
                }
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .onAppear { run(from: 0) }
        .onTapGesture {
            // Tapping skips to the next card: logo → disclaimer → title.
            if phase < 2 { run(from: 1) } else if phase < 4 { run(from: 3) }
        }
    }

    /// Plays the intro from a given phase: logo, fade to black, disclaimer, fade to black, title.
    private func run(from start: Int) {
        sequence?.cancel()
        sequence = Task { @MainActor in
            if start <= 0 {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
            }
            if start <= 1 {
                withAnimation(.easeInOut(duration: 0.7)) { phase = 1 }
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.9)) { phase = 2 }
                try? await Task.sleep(for: .seconds(5.5))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.easeInOut(duration: 0.7)) { phase = 3 }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.9)) { phase = 4 }
            Audio.shared.play()
            // The signs hang dark for a beat, NOIR strikes on, then MARKET below it.
            try? await Task.sleep(for: .seconds(0.7))
            noirOn = true
            withAnimation(.easeOut(duration: 1.4)) { titleIn = true }
            try? await Task.sleep(for: .seconds(1.3))
            marketOn = true
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeOut(duration: 0.9)) { buttonsIn = true }
        }
    }

    private func press(_ id: String, _ action: @escaping () -> Void) -> () -> Void {
        {
            Audio.shared.buzz(.tap)
            action()
        }
    }

    private var title: some View {
        GeometryReader { outer in
        let insets = outer.safeAreaInsets
        GeometryReader { geo in
            ZStack {
                // Behind the powder: black with a faint cold glow and a vignette.
                RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .init(x: 0.5, y: 0.38), startRadius: 10, endRadius: 320)
                    .opacity(titleIn ? 1 : 0)
                PowderField()
                    .opacity(titleIn ? 1 : 0)
                RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 220, endRadius: 640)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer().frame(height: insets.top + geo.size.height * 0.15)
                    VStack(spacing: 6) {
                        NeonSign(text: "NOIR", style: .outline, font: NeonSign.condensed(.heavy), kern: 4,
                                 colour: Color(white: 0.92), core: .white, powered: noirOn, flickerEvery: 9...18)
                            .padding(.horizontal, 44)
                        NeonSign(text: "MARKET", font: NeonSign.rounded(.semibold),
                                 colour: Noir.neon, core: Color(hex: Theme.shared.palette.accentHex, lift: 0.55),
                                 powered: marketOn, broken: 4)
                            .padding(.horizontal, 40)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Noir Market")
                    .accessibilityAddTraits(.isHeader)

                    Text("TRADE SMART – PLAY DIRTY – COME OUT ON TOP")
                        .font(Noir.label(12)).tracking(1.4)
                        .foregroundStyle(Noir.paper.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .opacity(titleIn ? 1 : 0)

                    Spacer(minLength: 40)

                    VStack(spacing: 14) {
                        Button(action: press("main", hasSave ? onContinue : onNewGame)) {
                            HStack {
                                Spacer()
                                VStack(spacing: 5) {
                                    Text(hasSave ? "Continue" : "New Game")
                                    if hasSave, let saveSummary {
                                        Text(saveSummary)
                                            .font(Noir.label(11)).tracking(1.4)
                                            .foregroundStyle(Noir.paper.opacity(0.8))
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                }
                                .padding(.vertical, 8)
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.horizontal, 22)
                        }
                        .buttonStyle(NeonRedButton())
                        if hasSave {
                            Button("New Game", action: press("new", onNewGame)).buttonStyle(TitleOutlineButton())
                        }
                        HStack(spacing: 12) {
                            Button("How to Play", action: press("how", onHowTo)).buttonStyle(TitleOutlineButton())
                            Button("Records", action: press("records", onRecords)).buttonStyle(TitleOutlineButton())
                        }
                        Button(action: press("settings", onSettings)) {
                            HStack(spacing: 12) {
                                Image(systemName: "gearshape.fill").font(.system(size: 17))
                                Text("Settings").font(Noir.label(13)).tracking(2.2).textCase(.uppercase)
                            }
                            .foregroundStyle(Noir.silver)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                    .opacity(buttonsIn ? 1 : 0)
                    .offset(y: buttonsIn ? 0 : 10)
                    .allowsHitTesting(buttonsIn)

                    Text("a redhead games production · fiction · 18+ · entertainment only")
                        .font(Noir.ui(10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16)
                        .foregroundStyle(Noir.silver.opacity(0.7))
                        .opacity(buttonsIn ? 1 : 0)
                        .padding(.top, 36)
                        .padding(.bottom, insets.bottom + 62)
                }
            }
        }
        .ignoresSafeArea()
        }
    }
}

/// Red neon-outlined call to action, like a motel sign tube.
struct NeonRedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(Noir.label(17)).tracking(3).textCase(.uppercase)
            .foregroundStyle(Noir.neon)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(shape.fill(Color.black.opacity(0.55)))
            .background(shape.fill(Noir.neon.opacity(configuration.isPressed ? 0.16 : 0.03)))
            .overlay(shape.strokeBorder(Noir.neon, lineWidth: 1.6))
            .shadow(color: Noir.neon.opacity(configuration.isPressed ? 0.7 : 0.45), radius: configuration.isPressed ? 8 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// Quiet outlined title button.
struct TitleOutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(Noir.label(13)).tracking(2.2).textCase(.uppercase)
            .foregroundStyle(Noir.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(shape.fill(Color.black.opacity(configuration.isPressed ? 0.3 : 0.55)))
            .overlay(shape.strokeBorder(Color.white.opacity(configuration.isPressed ? 0.7 : 0.35), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// Shown between the Redhead logo and the title.
private struct Disclaimer: View {
    var body: some View {
        VStack(spacing: 22) {
            Text("DISCLAIMER")
                .font(Noir.title(30)).tracking(1)
                .foregroundStyle(Color(hex: 0xFF3B3B))
                .shadow(color: Color(hex: 0xFF3B3B).opacity(0.45), radius: 10)
            VStack(spacing: 18) {
                Text("THIS GAME IS FOR ENTERTAINMENT PURPOSES ONLY.")
                Text("REAL CITY NAMES ARE USED AS FICTIONAL SETTINGS. THEIR DEPICTION DOES NOT REPRESENT REAL CONDITIONS, COMMUNITIES OR ACTIVITIES.")
                Text("ALL CHARACTERS AND EVENTS ARE FICTIONAL. ANY RESEMBLANCE TO REAL PEOPLE OR EVENTS IS PURELY COINCIDENTAL.")
            }
            .font(Noir.ui(13, weight: .semibold)).tracking(0.6)
            .lineSpacing(4)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 34)
        .accessibilityElement(children: .combine)
    }
}

/// A neon sign drawn from glyph outlines. `.tube` fills each letter as a glowing glass tube (MARKET);
/// `.outline` runs a single bright tube around each letter's edge (NOIR). Starts dark, strikes on with
/// a stutter when `powered` turns true, then flickers now and then. One tired letter can misbehave on its own.
struct NeonSign: View {
    enum Style { case tube, outline }

    let text: String
    var style: Style = .tube
    var colour: Color
    var core: Color
    var powered: Bool
    /// The letter with the dodgy transformer, if any.
    var broken: Int? = nil
    /// How often the whole sign stutters once it's on.
    var flickerEvery: ClosedRange<Double> = 3...8

    @State private var on = false
    @State private var brokenOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let letters: [Path]
    private let bounds: CGRect

    init(text: String, style: Style = .tube, font: UIFont, kern: CGFloat = 6, colour: Color, core: Color, powered: Bool,
         broken: Int? = nil, flickerEvery: ClosedRange<Double> = 3...8) {
        self.text = text
        self.style = style
        self.colour = colour
        self.core = core
        self.powered = powered
        self.broken = broken
        self.flickerEvery = flickerEvery
        (letters, bounds) = Self.outline(text, font: font, kern: kern)
    }

    var body: some View {
        let pad = bounds.height * 0.06
        let bleed: CGFloat = 60
        let aspect = (bounds.width + pad * 2) / (bounds.height + pad * 2)
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { sign(pad: pad, bleed: bleed).padding(-bleed).allowsHitTesting(false) }
            .background {
                // Light spilling onto the wall behind the sign.
                // Fades to nothing well inside its frame, so no edge shows.
                RadialGradient(colors: [colour.opacity(on ? 0.16 : 0), .clear], center: .center, startRadius: 4, endRadius: 250)
                    .frame(width: 560, height: 560)
                    .scaleEffect(x: 1.2, y: 0.5)
                    .allowsHitTesting(false)
            }
            .accessibilityElement()
            .accessibilityLabel(text)
            .task(id: powered) {
                guard powered else { on = false; return }
                if reduceMotion { on = true; return }
                await strike()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await flickerSign() }
                    if broken != nil { group.addTask { await flickerLetter() } }
                }
            }
    }

    private func sign(pad: CGFloat, bleed: CGFloat) -> some View {
        Canvas { ctx, size in
            let scale = (size.width - bleed * 2) / (bounds.width + pad * 2)
            ctx.translateBy(x: bleed + (pad - bounds.minX) * scale, y: bleed + (pad - bounds.minY) * scale)
            ctx.scaleBy(x: scale, y: scale)
            let tube = 3.2 / scale
            let round = StrokeStyle(lineWidth: tube, lineCap: .round, lineJoin: .round)
            func wide(_ k: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: tube * k, lineCap: .round, lineJoin: .round) }
            for (i, letter) in letters.enumerated() {
                let lit = on && (i != broken || brokenOn)
                switch style {
                case .tube:
                    // The glass tube, visible even when it's off.
                    ctx.stroke(letter, with: .color(colour.opacity(0.22)), style: wide(1.4))
                    ctx.fill(letter, with: .color(Color(white: 0.06)))
                    guard lit else { continue }
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 26 / scale))
                        l.stroke(letter, with: .color(colour.opacity(0.75)), style: wide(5))
                    }
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 7 / scale))
                        l.fill(letter, with: .color(colour))
                        l.stroke(letter, with: .color(colour), style: wide(2))
                    }
                    ctx.fill(letter, with: .color(core))
                    ctx.stroke(letter, with: .color(colour), style: round)
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 1.5 / scale))
                        l.clip(to: letter)
                        l.stroke(letter.offsetBy(dx: 0, dy: -tube * 0.8), with: .color(.white.opacity(0.85)), style: wide(0.9))
                    }
                case .outline:
                    // Unlit: a faint glass line. Lit: halo, glow, then a hot white core.
                    ctx.stroke(letter, with: .color(colour.opacity(0.13)), style: wide(1.2))
                    guard lit else { continue }
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 18 / scale))
                        l.stroke(letter, with: .color(colour.opacity(0.55)), style: wide(4))
                    }
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 4 / scale))
                        l.stroke(letter, with: .color(colour.opacity(0.9)), style: wide(2.2))
                    }
                    ctx.stroke(letter, with: .color(core), style: wide(1.1))
                }
            }
        }
    }

    /// Switching on: a few hesitant flashes, then it holds.
    @MainActor private func strike() async {
        let pattern: [(Bool, Int)] = [(true, 60), (false, 140), (true, 40), (false, 260), (true, 90), (false, 70), (true, 50), (false, 120)]
        for (lit, ms) in pattern {
            guard !Task.isCancelled else { return }
            on = lit
            if lit { Audio.shared.play(.click, volume: 0.12) }
            try? await Task.sleep(for: .milliseconds(ms))
        }
        on = true
        Audio.shared.buzz(.tap)
    }

    @MainActor private func flickerSign() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: flickerEvery)))
            guard !Task.isCancelled else { return }
            for _ in 0..<Int.random(in: 1...4) {
                on = false
                try? await Task.sleep(for: .milliseconds(Int.random(in: 30...120)))
                on = true
                try? await Task.sleep(for: .milliseconds(Int.random(in: 30...100)))
            }
        }
    }

    @MainActor private func flickerLetter() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1...3.5)))
            guard !Task.isCancelled else { return }
            if Bool.random() {
                // A long dropout, then it buzzes back.
                brokenOn = false
                try? await Task.sleep(for: .milliseconds(Int.random(in: 500...1400)))
            }
            for _ in 0..<Int.random(in: 2...6) {
                brokenOn.toggle()
                try? await Task.sleep(for: .milliseconds(Int.random(in: 25...90)))
            }
            brokenOn = true
        }
    }

    /// Glyph outlines, one path per letter, in a y-down space.
    private static func outline(_ text: String, font: UIFont, kern: CGFloat) -> ([Path], CGRect) {
        let ct = font as CTFont
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .kern: kern]))
        var paths: [Path] = []
        var all = CGRect.null
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let n = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: n)
            var points = [CGPoint](repeating: .zero, count: n)
            CTRunGetGlyphs(run, CFRange(location: 0, length: n), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: n), &points)
            for i in 0..<n {
                var t = CGAffineTransform(translationX: points[i].x, y: 0).scaledBy(x: 1, y: -1)
                guard let g = CTFontCreatePathForGlyph(ct, glyphs[i], &t) else { continue }
                // Variable fonts build letters from overlapping shapes; merge them so the outline is clean.
                let p = Path(g.normalized())
                paths.append(p)
                all = all.union(p.boundingRect)
            }
        }
        return (paths, all.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : all)
    }

    /// SF Rounded at a weight, for MARKET's tubes.
    static func rounded(_ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: 100, weight: weight)
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 100) } ?? base
    }

    /// Tall condensed SF, for NOIR's outline.
    static func condensed(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: 100, weight: weight, width: .condensed)
    }
}
