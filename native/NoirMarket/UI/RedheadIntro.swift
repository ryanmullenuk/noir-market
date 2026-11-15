import SwiftUI

/// The Redhead Games "brain freeze to boom" logo: the two halves of the brain slam together,
/// it squashes and shakes, a red glow and two shockwave rings burst out, then "redhead" punches
/// in and "games" opens up underneath. A native take on the studio's web animation.
struct RedheadIntro: View {
    @State private var halvesIn = false
    @State private var impact = false
    @State private var squash = false
    @State private var shake: CGFloat = 0
    @State private var ring1 = false
    @State private var ring2 = false
    @State private var glow = false
    @State private var wordIn = false
    @State private var gamesIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let red = Color(hex: 0xFF1A1A)

    var body: some View {
        GeometryReader { geo in
            let width = min(480, geo.size.width * 0.78)
            let brainW = width * 0.62
            VStack(spacing: 0) {
                ZStack {
                    // Red glow and shockwave rings behind the brain.
                    Circle()
                        .fill(RadialGradient(colors: [red.opacity(0.55), red.opacity(0)], center: .center, startRadius: 0, endRadius: brainW * 0.75 * 0.65))
                        .frame(width: brainW * 1.5, height: brainW * 1.5)
                        .scaleEffect(glow ? 1.2 : 0.4)
                        .opacity(glow ? 0 : (impact ? 1 : 0))
                    ring(on: ring1, size: brainW * 2.6)
                    ring(on: ring2, size: brainW * 2.6)

                    ZStack {
                        half(left: true, width: brainW)
                        half(left: false, width: brainW)
                    }
                    .frame(width: brainW, height: brainW * 630 / 597)
                    .scaleEffect(x: squash ? 1.12 : 1, y: squash ? 0.86 : 1)
                    .offset(x: shake * 6, y: -shake * 3)
                    .rotationEffect(.degrees(Double(shake) * -1.5))
                }
                .frame(width: brainW, height: brainW * 630 / 597)

                Image("RHWord").resizable().scaledToFit()
                    .frame(width: width)
                    .padding(.top, width * 0.033)
                    .scaleEffect(wordIn ? 1 : 2.4)
                    .blur(radius: wordIn ? 0 : 10)
                    .opacity(wordIn ? 1 : 0)

                Image("RHGames").resizable().scaledToFit()
                    .frame(width: width * 0.484)
                    .padding(.top, width * 0.017)
                    .mask(Rectangle().scaleEffect(x: gamesIn ? 1 : 0.001, y: 1))
                    .offset(y: gamesIn ? 0 : width * 0.484 * 72 / 466 * 0.3)
                    .opacity(gamesIn ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Redhead Games")
        .task { await play() }
    }

    private func half(left: Bool, width: CGFloat) -> some View {
        Image("RHBrain").resizable().scaledToFit()
            .mask(alignment: left ? .leading : .trailing) {
                Rectangle().frame(width: width * (left ? 0.502 : 0.498))
            }
            .offset(x: halvesIn ? 0 : (left ? -1.4 : 1.4) * width)
            .rotationEffect(.degrees(halvesIn ? 0 : (left ? -18 : 18)))
            .opacity(halvesIn ? 1 : 0)
    }

    private func ring(on: Bool, size: CGFloat) -> some View {
        Circle()
            .stroke(red, lineWidth: on ? 1 : 14 * size / 100 / 2.6)
            .frame(width: size * 0.96, height: size * 0.96)
            .scaleEffect(on ? 1 : 0.15)
            .opacity(on ? 0 : (impact ? 1 : 0))
    }

    @MainActor private func play() async {
        if reduceMotion {
            halvesIn = true; wordIn = true; gamesIn = true
            return
        }
        try? await Task.sleep(for: .milliseconds(200))
        // 0.00s: the halves fly in and meet.
        withAnimation(.timingCurve(0.55, 0, 1, 0.45, duration: 0.55)) { halvesIn = true }
        try? await Task.sleep(for: .milliseconds(550))
        // 0.55s: impact.
        impact = true
        squash = true
        Audio.shared.play(.thud, volume: 0.55)
        Audio.shared.buzz(.danger)
        withAnimation(.timingCurve(0.3, 1.6, 0.5, 1, duration: 0.45)) { squash = false }
        withAnimation(.easeOut(duration: 0.8)) { glow = true }
        withAnimation(.timingCurve(0.1, 0.7, 0.3, 1, duration: 0.9)) { ring1 = true }
        Task {
            for (dx, ms) in [(1.0, 50), (-0.85, 50), (0.7, 50), (-0.5, 50), (0.25, 70), (0.0, 80)] as [(CGFloat, Int)] {
                withAnimation(.linear(duration: Double(ms) / 1000)) { shake = dx }
                try? await Task.sleep(for: .milliseconds(ms))
            }
        }
        try? await Task.sleep(for: .milliseconds(130))
        withAnimation(.timingCurve(0.1, 0.7, 0.3, 1, duration: 1.0)) { ring2 = true }
        try? await Task.sleep(for: .milliseconds(120))
        // 0.80s: "redhead" punches in.
        withAnimation(.timingCurve(0.2, 1.5, 0.4, 1, duration: 0.6)) { wordIn = true }
        try? await Task.sleep(for: .milliseconds(350))
        // 1.15s: "games" opens from the centre.
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.55)) { gamesIn = true }
    }
}
