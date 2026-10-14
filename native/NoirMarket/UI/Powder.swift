import SwiftUI

/// A depth-layered powder fall for the title screen.
/// Far dust is fine and sharp, mid specks are soft, near flakes are large out-of-focus bokeh
/// drifting past the lens. Far and mid grains settle into a glittering drift along the bottom.
final class PowderSim: @unchecked Sendable {
    struct Grain { var x, y, vy, size, alpha, phase: Double; var layer: Int }

    var grains: [Grain] = []
    var size: CGSize = .zero
    var ground: [Double] = []
    private var glints: [(x: Double, dy: Double, size: Double, freq: Double, phase: Double)] = []
    private var specks: [(x: Double, dy: Double, size: Double, a: Double)] = []
    private var rng = SplitMix(seed: 1947)
    private var last: Date?
    private var debt = [0.0, 0.0, 0.0]
    var time = 0.0
    static let cell = 3.0

    private func r(_ lo: Double, _ hi: Double) -> Double { rng.uniform(lo, hi) }

    // Spawn rates and caps per layer: far, mid, near.
    private let rate = [420.0, 80.0, 5.0]
    private let cap = [2400, 460, 26]

    func resize(_ s: CGSize) {
        guard s != size, s.width > 0 else { return }
        size = s
        let n = Int(s.width / Self.cell) + 2
        // Start with a settled drift so the screen opens mid-snowfall.
        ground = (0..<n).map { i in
            let x = Double(i) / Double(n)
            // Low in the middle, banked up towards the corners, with soft rolling bumps.
            let edge = pow(abs(x - 0.5) * 2, 3) * 40
            return 30 + edge + sin(x * 7.3) * 5 + sin(x * 17 + 1.3) * 2.5 + sin(x * 3.1 + 0.4) * 6
        }
        glints = (0..<600).map { _ in (r(0, s.width), r(0, 1), r(0.8, 2.8), r(0.6, 3.2), r(0, 6.28)) }
        specks = (0..<2600).map { _ in (r(0, s.width), pow(r(0, 1), 0.7), r(0.5, 1.6), r(0.15, 0.95)) }
        grains = []
        for layer in 0..<3 {
            let count = [1700, 300, 16][layer]
            for _ in 0..<count { grains.append(make(layer, y: r(-20, s.height))) }
        }
    }

    private func make(_ layer: Int, y: Double? = nil) -> Grain {
        switch layer {
        case 0: Grain(x: r(-10, size.width + 10), y: y ?? r(-20, -2), vy: r(9, 20), size: r(0.4, 1.2), alpha: r(0.25, 0.85), phase: r(0, 6.28), layer: 0)
        case 1: Grain(x: r(-10, size.width + 10), y: y ?? r(-30, -4), vy: r(22, 40), size: r(1.3, 3.0), alpha: r(0.35, 0.9), phase: r(0, 6.28), layer: 1)
        default: Grain(x: r(-30, size.width + 30), y: y ?? r(-80, -30), vy: r(45, 95), size: r(12, 38), alpha: r(0.18, 0.45), phase: r(0, 6.28), layer: 2)
        }
    }

    /// Advances the simulation once per frame (safe to call from several draws).
    func step(now: Date) {
        if let last, now.timeIntervalSince(last) < 0.001 { return }
        let dt = min(1.0 / 20, last.map { now.timeIntervalSince($0) } ?? 1.0 / 60)
        last = now
        time += dt
        guard size.width > 0 else { return }
        var counts = [0, 0, 0]
        for g in grains { counts[g.layer] += 1 }
        for layer in 0..<3 {
            debt[layer] += rate[layer] * dt
            while debt[layer] >= 1 && counts[layer] < cap[layer] { debt[layer] -= 1; grains.append(make(layer)); counts[layer] += 1 }
            debt[layer] = min(debt[layer], 3)
        }
        let wind = sin(time * 0.3) * 8 + sin(time * 1.1) * 3
        var i = 0
        while i < grains.count {
            var g = grains[i]
            let depth = [0.5, 1.0, 1.8][g.layer]
            g.y += g.vy * dt
            g.x += (wind + sin(time * (0.9 + g.phase * 0.15) + g.phase) * (4 + g.phase)) * depth * dt
            var gone = g.y > size.height + 40
            if g.layer < 2, let top = groundTop(at: g.x), g.y >= top {
                deposit(at: g.x, amount: g.size * (g.layer == 0 ? 0.05 : 0.12))
                gone = true
            }
            if gone { grains.swapAt(i, grains.count - 1); grains.removeLast(); continue }
            grains[i] = g
            i += 1
        }
    }

    private func groundTop(at x: Double) -> Double? {
        guard !ground.isEmpty else { return nil }
        let i = Int(x / Self.cell)
        guard i >= 0, i < ground.count else { return nil }
        return size.height - ground[i]
    }

    private func deposit(at x: Double, amount: Double) {
        var i = Int(x / Self.cell)
        guard i >= 0, i < ground.count else { return }
        ground[i] = min(ground[i] + amount, 120)
        for _ in 0..<6 {
            let l = i > 0 ? ground[i - 1] : .infinity, rr = i < ground.count - 1 ? ground[i + 1] : .infinity
            let j = l < rr ? i - 1 : i + 1
            guard j >= 0, j < ground.count, ground[i] - ground[j] > 1.2 else { break }
            let m = (ground[i] - ground[j]) / 3
            ground[i] -= m; ground[j] += m; i = j
        }
    }

    // MARK: Drawing

    func drawLayer(_ ctx: inout GraphicsContext, _ layer: Int) {
        switch layer {
        case 0:
            var bands = [Path(), Path(), Path()]
            for g in grains where g.layer == 0 {
                let b = g.alpha < 0.45 ? 0 : g.alpha < 0.7 ? 1 : 2
                bands[b].addRect(CGRect(x: g.x, y: g.y, width: g.size, height: g.size))
            }
            ctx.fill(bands[0], with: .color(.white.opacity(0.35)))
            ctx.fill(bands[1], with: .color(.white.opacity(0.6)))
            ctx.fill(bands[2], with: .color(.white.opacity(0.92)))
        case 1:
            for g in grains where g.layer == 1 {
                let flicker = 0.8 + 0.2 * sin(time * 3 + g.phase * 4)
                ctx.fill(Path(ellipseIn: CGRect(x: g.x, y: g.y, width: g.size, height: g.size)), with: .color(.white.opacity(g.alpha * flicker)))
            }
        default:
            for g in grains where g.layer == 2 {
                let rect = CGRect(x: g.x - g.size / 2, y: g.y - g.size / 2, width: g.size, height: g.size)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white.opacity(g.alpha), .white.opacity(g.alpha * 0.5), .clear]),
                                                                       center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: g.size / 2))
            }
        }
    }

    func drawGround(_ ctx: inout GraphicsContext) {
        guard !ground.isEmpty else { return }
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height))
        for (i, h) in ground.enumerated() { p.addLine(to: CGPoint(x: Double(i) * Self.cell, y: size.height - h)) }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        let top = size.height - (ground.max() ?? 0)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2.5))
            l.fill(p, with: .linearGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.25)]),
                                            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        }
        ctx.fill(p, with: .linearGradient(Gradient(colors: [Color(white: 0.6).opacity(0.0), Color(white: 0.3).opacity(0.5)]),
                                          startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        // Granular texture: thousands of grains across the surface of the drift.
        var bands = [Path(), Path(), Path()]
        for sp in specks {
            let i = min(ground.count - 1, max(0, Int(sp.x / Self.cell)))
            let y = size.height - ground[i] * (1 - sp.dy * 0.9)
            let b = sp.a < 0.4 ? 0 : sp.a < 0.7 ? 1 : 2
            bands[b].addRect(CGRect(x: sp.x, y: y, width: sp.size, height: sp.size))
        }
        ctx.fill(bands[0], with: .color(.white.opacity(0.3)))
        ctx.fill(bands[1], with: .color(.white.opacity(0.6)))
        ctx.fill(bands[2], with: .color(.white.opacity(0.95)))
        // A bright crust along the very top edge.
        var crest = Path()
        for (i, h) in ground.enumerated() {
            let pt = CGPoint(x: Double(i) * Self.cell, y: size.height - h)
            i == 0 ? crest.move(to: pt) : crest.addLine(to: pt)
        }
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 3))
            l.stroke(crest, with: .color(.white.opacity(0.6)), lineWidth: 4)
        }
        // Crystalline glints that catch the light.
        for gl in glints {
            let i = min(ground.count - 1, max(0, Int(gl.x / Self.cell)))
            let y = size.height - ground[i] * (1 - gl.dy * 0.8)
            let tw = 0.5 + 0.5 * sin(time * gl.freq + gl.phase)
            let a = 0.25 + 0.75 * tw * tw
            ctx.fill(Path(ellipseIn: CGRect(x: gl.x, y: y, width: gl.size, height: gl.size)), with: .color(.white.opacity(a)))
        }
    }
}

/// One rendered pass of the powder field: far dust, mid specks, the drift, then near bokeh.
private struct PowderCanvas: View {
    let sim: PowderSim
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            Canvas { ctx, size in
                sim.resize(size)
                if !paused { sim.step(now: tl.date) }
                sim.drawLayer(&ctx, 0)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 0.7))
                    var c = l
                    sim.drawLayer(&c, 1)
                }
                sim.drawGround(&ctx)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 4))
                    var c = l
                    sim.drawLayer(&c, 2)
                }
            }
        }
    }
}

/// The full title-screen powder: a sharp middle band and blurred top and bottom bands (tilt-shift).
struct PowderField: View {
    @State private var sim = PowderSim()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PowderCanvas(sim: sim, paused: reduceMotion)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0.08), .init(color: .black, location: 0.3),
                                             .init(color: .black, location: 0.93), .init(color: .clear, location: 1.0)],
                                     startPoint: .top, endPoint: .bottom))
            PowderCanvas(sim: sim, paused: reduceMotion)
                .blur(radius: 4)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .clear, location: 0.3),
                                             .init(color: .clear, location: 0.93), .init(color: .black, location: 1.0)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
