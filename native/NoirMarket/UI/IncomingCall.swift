import SwiftUI

/// The caller portrait: a hooded or capped figure on a glitching green screen.
struct CallerPortrait: View {
    var female: Bool
    var unknown: Bool
    @State private var glitch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(female ? "CallerFemale" : "CallerMale")
            .resizable()
            .scaledToFill()
            .scaleEffect(1.12)
            .offset(x: glitch ? 2 : 0)
            .overlay(Color(red: 0.2, green: 1, blue: 0.5).opacity(glitch ? 0.12 : 0))
            .frame(width: 140, height: 140)
            .clipShape(Circle())
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 1.2...3.5)))
                    glitch = true
                    try? await Task.sleep(for: .milliseconds(70))
                    glitch = false
                }
            }
            .accessibilityHidden(true)
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
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Noir.surface))
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
