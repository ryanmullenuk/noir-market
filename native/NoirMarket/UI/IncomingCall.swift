import SwiftUI

/// Ringing phone card: name, tag, secure line, voice bars, two big buttons.
struct IncomingCallView: View {
    let call: IncomingCall
    let city: String
    @Environment(GameStore.self) private var store
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    Circle().fill(Noir.amber).frame(width: 9, height: 9)
                        .opacity(call.answered || pulse ? 1 : 0.3)
                        .shadow(color: Noir.amber, radius: 4)
                    Text(call.answered ? "ON THE LINE" : "INCOMING CALL")
                        .font(Noir.label(13)).tracking(3)
                    Rectangle().fill(Noir.amber.opacity(0.6)).frame(width: 1, height: 14)
                    Image(systemName: "phone.fill").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Noir.amber)

                VStack(spacing: 10) {
                    Text(Engine.callerName(call)).font(Noir.display(28)).foregroundStyle(Noir.paper)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    Text(Engine.callerTag(call)).font(Noir.label(12)).tracking(2.4).foregroundStyle(Noir.amber)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Noir.amber, lineWidth: 1.2))
                    Text("Secure line · \(city)").font(Noir.ui(13)).foregroundStyle(Noir.silver)
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
                    VStack(spacing: 12) {
                        Waveform()
                        Text("ENCRYPTED CONNECTION").font(Noir.label(11)).tracking(2.2).foregroundStyle(Noir.silver)
                    }
                    .padding(.vertical, 4)
                    Rectangle().fill(Noir.amber.opacity(0.5)).frame(height: 1).padding(.horizontal, 6)
                    HStack(spacing: 12) {
                        callButton("Decline", "phone.down.fill", Noir.red) { decline() }
                        callButton("Answer", "phone.fill", Noir.green, filled: true) {
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
            .padding(.horizontal, 24).frame(maxWidth: 520)
        }
        .task {
            guard !call.answered else { return }
            while !Task.isCancelled, store.state?.call?.answered == false {
                Audio.shared.play(.calltone, volume: 0.55)
                Audio.shared.ringBuzz()
                try? await Task.sleep(for: .seconds(2.6))
            }
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } } }
    }

    private var offer: String {
        let pct = Int((call.trust * 100).rounded())
        if call.caller < 3 {
            return "\(Engine.callerName(call).components(separatedBy: " ").first ?? "They") wants \(Money.gbp(call.fee)), half the usual, because they’re desperate. Odds it’s right: about \(pct)%."
        }
        if call.contact != nil {
            return "They want \(Money.gbp(call.fee)). You saved this number once and can’t remember why. They reckon it’s \(pct)% solid."
        }
        return "They want \(Money.gbp(call.fee)). No idea who this is. They reckon it’s \(pct)% solid, which is exactly what a liar would say."
    }

    private func callButton(_ title: String, _ symbol: String, _ tint: Color, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(Noir.label(13)).tracking(2).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(filled ? Noir.paper : tint)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(filled ? 0.28 : 0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.85), lineWidth: 1.2))
            .shadow(color: tint.opacity(0.35), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private func accept() {
        var out: Outcome?
        let fee = call.fee
        if store.act({ out = try Engine.acceptCall(&$0) }), let out {
            store.flash(out.good ? "Tip in" : out.title, out.good ? "\(Engine.callerName(call)) talks. The tip’s on the call card." : out.text,
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

/// Animated voice bars fading into dots at the edges.
private struct Waveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<29) { i in
                    let d = abs(Double(i) - 14) / 14
                    let amp = max(0, 1 - d * 1.15)
                    let wobble = 0.45 + 0.55 * abs(sin(t * 6 + Double(i) * 1.7) * cos(t * 2.3 + Double(i) * 0.6))
                    Capsule().fill(Noir.green.opacity(0.4 + 0.6 * amp))
                        .frame(width: 3, height: max(3, 4 + amp * 54 * wobble))
                }
            }
            .frame(height: 60)
            .shadow(color: Noir.green.opacity(0.7), radius: 5)
        }
        .accessibilityHidden(true)
    }
}
