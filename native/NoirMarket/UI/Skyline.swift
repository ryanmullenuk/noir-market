import SwiftUI

/// A procedurally drawn city skyline with a few lit windows, seeded so it is stable.
struct Skyline: View {
    var seed: UInt64 = 42
    var tint: Color = .black

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix(seed: seed)
            func r(_ lo: Double, _ hi: Double) -> Double {
                lo + Double(rng.next() % 10_000) / 10_000 * (hi - lo)
            }
            // Back layer: hazy grey towers.
            var x = -10.0
            while x < size.width {
                let w = r(26, 60), h = r(size.height * 0.35, size.height * 0.8)
                ctx.fill(Path(CGRect(x: x, y: size.height - h, width: w, height: h)), with: .color(Color(white: 0.09)))
                x += w + r(-6, 4)
            }
            // Front layer: black blocks with windows, a spire and a water tower.
            x = -6
            while x < size.width {
                let w = r(34, 78), h = r(size.height * 0.2, size.height * 0.62)
                let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                ctx.fill(Path(rect), with: .color(tint))
                if r(0, 1) < 0.25 {
                    var spire = Path()
                    spire.move(to: CGPoint(x: rect.midX - 5, y: rect.minY))
                    spire.addLine(to: CGPoint(x: rect.midX, y: rect.minY - r(16, 40)))
                    spire.addLine(to: CGPoint(x: rect.midX + 5, y: rect.minY))
                    ctx.fill(spire, with: .color(tint))
                } else if r(0, 1) < 0.2 {
                    ctx.fill(Path(CGRect(x: rect.minX + 8, y: rect.minY - 14, width: 14, height: 14)), with: .color(tint))
                    ctx.fill(Path(CGRect(x: rect.minX + 10, y: rect.minY - 4, width: 1.5, height: 4)), with: .color(tint))
                }
                var wy = rect.minY + 8
                while wy < size.height - 8 {
                    var wx = rect.minX + 5
                    while wx < rect.maxX - 6 {
                        if r(0, 1) < 0.09 {
                            let warm = r(0, 1) < 0.15
                            let colour = warm ? Color(red: 0.95, green: 0.75, blue: 0.45) : Color(white: 0.85)
                            ctx.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 4)), with: .color(colour.opacity(r(0.35, 0.8))))
                        }
                        wx += 7
                    }
                    wy += 9
                }
                x += w + r(0, 3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Occasional lightning: a quick white flash over the sky.
struct Lightning: View {
    @State private var flash = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.white.opacity(flash)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 5...11)))
                    withAnimation(.easeOut(duration: 0.06)) { flash = 0.22 }
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(.easeIn(duration: 0.1)) { flash = 0.02 }
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(.easeOut(duration: 0.05)) { flash = 0.14 }
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation(.easeIn(duration: 0.6)) { flash = 0 }
                }
            }
    }
}

/// Flickering red neon text.
struct NeonText: View {
    let text: String
    var size: CGFloat = 16
    var tracking: CGFloat? = nil
    var font: Font? = nil
    @State private var on = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font ?? Noir.title(size))
            .tracking(tracking ?? size * 0.55)
            .foregroundStyle(Noir.neon.opacity(on ? 1 : 0.25))
            .shadow(color: Noir.neon.opacity(on ? 0.9 : 0), radius: 8)
            .shadow(color: Noir.neon.opacity(on ? 0.6 : 0), radius: 18)
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 1.5...5)))
                    for _ in 0..<Int.random(in: 1...3) {
                        on = false
                        try? await Task.sleep(for: .milliseconds(Int.random(in: 40...110)))
                        on = true
                        try? await Task.sleep(for: .milliseconds(Int.random(in: 40...90)))
                    }
                }
            }
    }
}
