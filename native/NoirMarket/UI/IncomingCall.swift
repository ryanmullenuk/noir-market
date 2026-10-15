import SwiftUI

/// A backlit head-and-shoulders silhouette, male or female.
struct PersonSilhouette: Shape {
    var female: Bool

    func path(in r: CGRect) -> Path {
        let w = r.width / 100, h = r.height / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var path = Path()
        if female {
            // Head.
            path.addEllipse(in: CGRect(x: r.minX + 36 * w, y: r.minY + 18 * h, width: 28 * w, height: 34 * h))
            // Long hair: a crown over the head that falls in two locks past the shoulders.
            path.move(to: p(50, 11))
            path.addCurve(to: p(30, 32), control1: p(38, 11), control2: p(30, 20))
            path.addCurve(to: p(26, 70), control1: p(30, 46), control2: p(24, 58))
            path.addCurve(to: p(36, 80), control1: p(27, 76), control2: p(31, 80))
            path.addLine(to: p(38, 52))
            path.addCurve(to: p(50, 24), control1: p(36, 36), control2: p(42, 24))
            path.addCurve(to: p(62, 52), control1: p(58, 24), control2: p(64, 36))
            path.addLine(to: p(64, 80))
            path.addCurve(to: p(74, 70), control1: p(69, 80), control2: p(73, 76))
            path.addCurve(to: p(70, 32), control1: p(76, 58), control2: p(70, 46))
            path.addCurve(to: p(50, 11), control1: p(70, 20), control2: p(62, 11))
            path.closeSubpath()
            // Slim neck and narrower, sloping shoulders.
            path.move(to: p(45, 48)); path.addLine(to: p(55, 48)); path.addLine(to: p(56, 66)); path.addLine(to: p(44, 66)); path.closeSubpath()
            path.move(to: p(12, 104))
            path.addCurve(to: p(32, 74), control1: p(13, 88), control2: p(21, 77))
            path.addLine(to: p(44, 66))
            path.addQuadCurve(to: p(56, 66), control: p(50, 72))
            path.addLine(to: p(68, 74))
            path.addCurve(to: p(88, 104), control1: p(79, 77), control2: p(87, 88))
            path.closeSubpath()
        } else {
            // Head with short hair, a neck, and broad shoulders in a jacket.
            path.addEllipse(in: CGRect(x: r.minX + 34 * w, y: r.minY + 16 * h, width: 32 * w, height: 38 * h))
            path.move(to: p(42, 50))
            path.addLine(to: p(58, 50))
            path.addLine(to: p(60, 66))
            path.addLine(to: p(40, 66))
            path.closeSubpath()
            path.move(to: p(2, 104))
            path.addCurve(to: p(26, 70), control1: p(4, 86), control2: p(12, 74))
            path.addLine(to: p(40, 64))
            path.addLine(to: p(50, 74))
            path.addLine(to: p(60, 64))
            path.addLine(to: p(74, 70))
            path.addCurve(to: p(98, 104), control1: p(88, 74), control2: p(96, 86))
            path.closeSubpath()
        }
        return path
    }
}

/// Jacket lapels, drawn as a faint detail line on the male figure.
private struct Lapels: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width / 100, h = r.height / 100
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 40 * w, y: r.minY + 64 * h))
        p.addLine(to: CGPoint(x: r.minX + 46 * w, y: r.minY + 92 * h))
        p.move(to: CGPoint(x: r.minX + 60 * w, y: r.minY + 64 * h))
        p.addLine(to: CGPoint(x: r.minX + 54 * w, y: r.minY + 92 * h))
        return p
    }
}

/// The caller portrait: smoke-lit backdrop, black figure, green rim light.
struct CallerPortrait: View {
    var female: Bool
    var unknown: Bool

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Noir.green.opacity(0.45), Noir.green.opacity(0.08), .black],
                                         center: .init(x: 0.5, y: 0.42), startRadius: 2, endRadius: 78))
            // Drifting smoke behind the figure.
            ForEach(0..<3) { i in
                Ellipse().fill(Color.white.opacity(0.05))
                    .frame(width: 90, height: 26)
                    .blur(radius: 8)
                    .offset(x: CGFloat(i * 18 - 18), y: CGFloat(-30 + i * 14))
            }
            PersonSilhouette(female: female)
                .fill(LinearGradient(colors: [Color(white: 0.04), .black], startPoint: .top, endPoint: .bottom), style: FillStyle(eoFill: false))
                .overlay(PersonSilhouette(female: female).stroke(Noir.green.opacity(0.75), lineWidth: 1.4).blur(radius: 0.8))
                .overlay { if !female { Lapels().stroke(Noir.green.opacity(0.18), lineWidth: 1) } }
                .frame(width: 132, height: 128)
                .offset(y: 16)
            if unknown {
                Text("?").font(Noir.title(30)).foregroundStyle(Noir.green.opacity(0.35)).offset(y: -8)
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
    }
}

/// Ringing phone card, in the game's style.
struct IncomingCallView: View {
    let call: IncomingCall
    let city: String
    @Environment(GameStore.self) private var store
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(call.answered ? "ON THE LINE" : "INCOMING CALL")
                    .font(Noir.label(13)).tracking(3)
                    .foregroundStyle(Noir.amber)

                avatar

                VStack(spacing: 4) {
                    Text(Engine.callerName(call.caller)).font(Noir.display(26)).foregroundStyle(Noir.paper)
                    Text(call.caller < 3 ? "INFORMANT" : "NO CALLER ID").font(Noir.label(11)).tracking(2).foregroundStyle(Noir.amber)
                    Text("Secure line · \(city)").font(Noir.ui(12)).foregroundStyle(Noir.silver)
                }

                if let result = call.result {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title.uppercased()).font(Noir.label(11)).tracking(1.4).foregroundStyle(result.good ? Noir.green : Noir.red)
                        Text(result.text).font(Noir.ui(14)).foregroundStyle(Noir.paper).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("End call") { close() }.buttonStyle(.noir)
                } else if call.answered {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(call.line).font(Noir.ui(14)).foregroundStyle(Noir.paper).fixedSize(horizontal: false, vertical: true)
                        Text(offer).font(Noir.ui(13)).foregroundStyle(Noir.amber).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) {
                        callButton("Hang up", "phone.down.fill", Noir.red) { decline() }
                        if call.caller < 3 {
                            callButton("On tick", "hand.raised.fill", Noir.amber) { stiff() }
                        }
                        callButton("Pay \(Money.gbp(call.fee))", "sterlingsign", Noir.green) { accept() }
                            .disabled((store.state?.cash ?? 0) < call.fee)
                    }
                    if call.caller < 3 {
                        let l = store.state.map { Engine.loyalty($0, call.caller) } ?? 50
                        Text("Loyalty: \(Engine.loyaltyWord(l)). Stiff them and they may sell you out.")
                            .font(Noir.ui(11)).foregroundStyle(Noir.rag(l, highIsGood: true))
                    }
                } else {
                    Waveform()
                    HStack(spacing: 12) {
                        callButton("Decline", "phone.down.fill", Noir.red) { decline() }
                        callButton("Answer", "phone.fill", Noir.green) {
                            Audio.shared.play(.click, volume: 0.6)
                            store.act { Engine.answerCall(&$0) }
                        }
                    }
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(white: 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Noir.amber.opacity(0.85), lineWidth: 1.2))
            .shadow(color: Noir.amber.opacity(0.25), radius: 24)
            .padding(.horizontal, 24)
        }
        .task {
            guard !call.answered else { return }
            while !Task.isCancelled, store.state?.call?.answered == false {
                Audio.shared.play(.ring, volume: 0.45)
                Audio.shared.buzz(.tap)
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } } }
    }

    private var offer: String {
        let pct = Int((call.trust * 100).rounded())
        if call.caller < 3 {
            return "\(Engine.callerName(call.caller).components(separatedBy: " ").first ?? "They") wants \(Money.gbp(call.fee)), half the usual, because they’re desperate. Odds it’s right: about \(pct)%."
        }
        return "They want \(Money.gbp(call.fee)). No idea who this is. They reckon it’s \(pct)% solid, which is exactly what a liar would say."
    }

    private var avatar: some View {
        ZStack {
            // Ringing arcs either side.
            ForEach([-1.0, 1.0], id: \.self) { side in
                ForEach(0..<2) { i in
                    Circle()
                        .trim(from: side < 0 ? 0.37 : 0.87, to: side < 0 ? 0.63 : 1.13)
                        .stroke(Noir.green.opacity(call.answered ? 0.25 : (pulse ? 0.95 : 0.35)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 168 + CGFloat(i) * 34, height: 168 + CGFloat(i) * 34)
                        .shadow(color: Noir.green.opacity(0.7), radius: 6)
                }
            }
            CallerPortrait(female: call.female ?? (call.caller == 1), unknown: call.caller == 3)
            Circle().strokeBorder(Noir.amber, lineWidth: 2).frame(width: 140, height: 140)
        }
        .frame(width: 210, height: 210)
        .accessibilityHidden(true)
    }

    private func callButton(_ title: String, _ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                Text(title).font(Noir.label(12)).tracking(1.2).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.85), lineWidth: 1.2))
            .shadow(color: tint.opacity(0.35), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private func accept() {
        var out: Outcome?
        let fee = call.fee
        if store.act({ out = try Engine.acceptCall(&$0) }), let out {
            store.flash(out.good ? "Tip in" : out.title, out.good ? "\(Engine.callerName(call.caller)) talks. The tip’s on the call card." : out.text,
                        good: out.good, amount: out.good ? nil : -fee)
        }
    }

    private func stiff() {
        var out: Outcome?
        if store.act({ out = try Engine.stiffCall(&$0) }), out != nil {
            store.flash("On tick", "You take the tip and promise to settle up. They know you won’t.", good: false)
        }
    }

    private func decline() {
        Audio.shared.play(.click, volume: 0.6)
        store.act { Engine.declineCall(&$0) }
    }

    private func close() {
        Audio.shared.play(.click, volume: 0.6)
        store.act { Engine.declineCall(&$0) }
    }
}

/// Little animated voice bars.
private struct Waveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<13) { i in
                    let d = abs(Double(i) - 6)
                    let h = 4 + (1 - d / 7) * 26 * (0.5 + 0.5 * sin(t * 7 + Double(i) * 0.9))
                    Capsule().fill(Noir.amber).frame(width: 3, height: max(3, h))
                }
            }
            .frame(height: 34)
            .shadow(color: Noir.amber.opacity(0.6), radius: 4)
        }
        .accessibilityHidden(true)
    }
}
