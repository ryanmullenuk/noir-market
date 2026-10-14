import SwiftUI

/// A tiny line of the last few closing prices.
struct Sparkline: View {
    let values: [Int]
    var colour: Color? = nil

    var body: some View {
        let up = (values.last ?? 0) >= (values.first ?? 0)
        let c = colour ?? (up ? Noir.green : Noir.red)
        Canvas { ctx, size in
            guard values.count > 1, let lo = values.min(), let hi = values.max() else { return }
            let span = Double(max(1, hi - lo))
            var p = Path()
            for (i, v) in values.enumerated() {
                let pt = CGPoint(x: size.width * Double(i) / Double(values.count - 1),
                                 y: size.height - (Double(v - lo) / span) * (size.height - 2) - 1)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            if let last = p.currentPoint {
                ctx.fill(Path(ellipseIn: CGRect(x: last.x - 1.8, y: last.y - 1.8, width: 3.6, height: 3.6)), with: .color(c))
            }
        }
        .shadow(color: c.opacity(0.5), radius: 3)
        .accessibilityLabel("Seven-day trend \(up ? "up" : "down")")
    }
}

/// Banner that drops in when an achievement is earned.
struct AchievementToast: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let a = store.toast {
            HStack(spacing: 12) {
                GlowIcon(symbol: a.symbol, color: Noir.amber, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACHIEVEMENT UNLOCKED").font(Noir.label(10)).tracking(1.4).foregroundStyle(Noir.amber)
                    Text(a.title).font(Noir.display(19)).foregroundStyle(Noir.paper)
                    Text(a.detail).font(Noir.ui(11)).foregroundStyle(Noir.silver)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Noir.amber.opacity(0.8), lineWidth: 1.1))
            .shadow(color: Noir.amber.opacity(0.35), radius: 16)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { withAnimation { store.toast = nil } }
            .task(id: a.id) {
                Audio.shared.play(.bingbong, volume: 0.35)
                Audio.shared.buzz(.success)
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeIn(duration: 0.3)) { if store.toast?.id == a.id { store.toast = nil } }
            }
        }
    }
}

/// The slow-motion moment on a big win: the screen dims, the figure drifts up slowly and glows.
struct BigWinMoment: View {
    let amount: Int
    var done: () -> Void
    @State private var phase = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55 * (1 - max(0, phase - 0.75) * 4)).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("BIG WIN").font(Noir.label(14)).tracking(6).foregroundStyle(Noir.amber)
                Text("+" + Money.gbp(amount))
                    .font(Noir.title(54))
                    .foregroundStyle(Noir.green)
                    .shadow(color: Noir.green.opacity(0.8), radius: 18)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .scaleEffect(0.85 + phase * 0.25)
            .offset(y: 20 - phase * 30)
            .blur(radius: phase < 0.1 ? 6 * (1 - phase * 10) : 0)
            .opacity(phase < 0.8 ? 1 : 1 - (phase - 0.8) * 5)
        }
        .allowsHitTesting(false)
        .task {
            Audio.shared.play(.cash, volume: 0.7)
            Audio.shared.buzz(.success)
            // Slow motion: a long, eased drift rather than a snap.
            withAnimation(.timingCurve(0.1, 0.8, 0.2, 1, duration: 2.4)) { phase = 1 }
            try? await Task.sleep(for: .seconds(2.5))
            done()
        }
    }
}

/// Achievements list in the game's style.
struct AchievementsList: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            Text("\(store.achievements.count) of \(Achievement.all.count) earned")
                .font(Noir.ui(12)).foregroundStyle(Noir.silver)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Achievement.all) { a in
                let got = store.achievements.contains(a.id)
                HStack(spacing: 12) {
                    GlowIcon(symbol: got ? a.symbol : "lock.fill", color: Noir.amber, size: 36, lit: got)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title.uppercased()).font(Noir.label(12)).tracking(1).foregroundStyle(got ? Noir.amber : Noir.silver)
                        Text(a.detail).font(Noir.ui(12)).foregroundStyle(got ? Noir.paper : Noir.dim)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(got ? Noir.amber.opacity(0.08) : Color.white.opacity(0.03)))
            }
        }
    }
}
