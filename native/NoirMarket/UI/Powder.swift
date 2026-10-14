import SwiftUI

/// Fine powder drifting down a night sky, settling on anything marked `.powderCollider(id)`
/// and on the ground. Each surface keeps a height map; grains slump to an angle of repose and
/// spill over the edges, so piles grow into soft drifts along the tops of the buttons.
final class PowderSim: @unchecked Sendable {
    struct Grain { var x, y, vx, vy, size, alpha, phase: Double }

    struct Surface {
        var rect: CGRect
        var heights: [Double]
        static let cell = 2.0
        var maxHeight: Double
        var catchRate = 1.0
        init(rect: CGRect, maxHeight: Double, catchRate: Double = 1) {
            self.rect = rect
            self.maxHeight = maxHeight
            self.catchRate = catchRate
            heights = Array(repeating: 0, count: max(1, Int(rect.width / Self.cell) + 1))
        }
        func top(at x: Double) -> Double? {
            guard x >= rect.minX, x <= rect.maxX else { return nil }
            let i = min(heights.count - 1, max(0, Int((x - rect.minX) / Self.cell)))
            return rect.minY - heights[i]
        }
    }

    var grains: [Grain] = []
    var surfaces: [String: Surface] = [:]
    var ground: Surface?
    var size: CGSize = .zero
    private var rng = SplitMix(seed: 1947)
    private var spawnDebt = 0.0
    private var last: Date?
    var time = 0.0

    let maxGrains = 900
    let spawnRate = 150.0   // grains per second

    func setColliders(_ frames: [String: CGRect]) {
        for (id, rect) in frames {
            // Only the top edge matters; keep the existing pile if the frame barely moved.
            if let old = surfaces[id], abs(old.rect.minY - rect.minY) < 1, abs(old.rect.width - (rect.width - 8)) < 1 { continue }
            // Title letters only catch some of the powder so the buttons below still get their share.
            let title = id.hasPrefix("letter")
            surfaces[id] = Surface(rect: rect.insetBy(dx: 4, dy: 0), maxHeight: title ? 12 : 16, catchRate: title ? 0.4 : 1)
        }
        for id in surfaces.keys where frames[id] == nil { surfaces[id] = nil }
    }

    func resize(_ s: CGSize) {
        guard s != size else { return }
        size = s
        ground = Surface(rect: CGRect(x: 0, y: s.height, width: s.width, height: 1), maxHeight: 70)
    }

    private func r(_ lo: Double, _ hi: Double) -> Double { rng.uniform(lo, hi) }

    func step(now: Date) {
        let dt = min(1.0 / 20, last.map { now.timeIntervalSince($0) } ?? 1.0 / 60)
        last = now
        time += dt
        guard size.width > 0 else { return }

        spawnDebt += spawnRate * dt
        while spawnDebt >= 1, grains.count < maxGrains {
            spawnDebt -= 1
            let s = r(0.7, 2.6)
            grains.append(Grain(x: r(-20, size.width + 20), y: r(-30, -4), vx: 0, vy: r(18, 34) + s * 6,
                                size: s, alpha: r(0.35, 0.95), phase: r(0, 6.28)))
        }
        spawnDebt = min(spawnDebt, 4)

        let wind = sin(time * 0.35) * 9 + sin(time * 1.3) * 3
        var i = 0
        while i < grains.count {
            var g = grains[i]
            g.vx = wind + sin(time * 1.7 + g.phase) * 7
            g.y += g.vy * dt
            g.x += g.vx * dt
            if landed(&g) || g.y > size.height + 10 {
                grains.swapAt(i, grains.count - 1)
                grains.removeLast()
                continue
            }
            grains[i] = g
            i += 1
        }
    }

    /// Settles a grain on whatever it hits. Returns true when the grain is absorbed.
    private func landed(_ g: inout Grain) -> Bool {
        for id in surfaces.keys {
            guard let top = surfaces[id]!.top(at: g.x), g.y >= top, g.y <= top + 6 else { continue }
            // Grains that miss a partial catcher fall past it (decided once, by their phase).
            if surfaces[id]!.catchRate < 1, g.phase / 6.28 > surfaces[id]!.catchRate { continue }
            deposit(on: &surfaces[id]!, x: g.x, amount: g.size * 0.55)
            return true
        }
        if var floor = ground, let top = floor.top(at: g.x), g.y >= top {
            deposit(on: &floor, x: g.x, amount: g.size * 0.35)
            ground = floor
            return true
        }
        return false
    }

    private func deposit(on s: inout Surface, x: Double, amount: Double) {
        var i = min(s.heights.count - 1, max(0, Int((x - s.rect.minX) / Surface.cell)))
        s.heights[i] += amount
        // Slump downhill until the slope is stable.
        for _ in 0..<12 {
            let left = i > 0 ? s.heights[i - 1] : -Double.infinity
            let right = i < s.heights.count - 1 ? s.heights[i + 1] : -Double.infinity
            let lower = left < right ? i - 1 : i + 1
            let edge = lower < 0 || lower >= s.heights.count
            let neighbour = edge ? 0.0 : s.heights[lower]
            let excess = s.heights[i] - neighbour - (edge ? 1.6 : 1.1)
            guard excess > 0 else { break }
            let move = excess / 2
            s.heights[i] -= move
            if edge {
                // Spill over the side as a falling grain.
                let side = lower < 0 ? s.rect.minX - 1 : s.rect.maxX + 1
                grains.append(Grain(x: side, y: s.rect.minY - s.heights[i], vx: 0, vy: 12, size: max(0.8, move * 1.6),
                                    alpha: 0.8, phase: r(0, 6.28)))
                break
            }
            s.heights[lower] += move
            i = lower
        }
        s.heights[i] = min(s.heights[i], s.maxHeight)
    }

    /// Knocks a pile loose, e.g. when its button is pressed.
    func disturb(_ id: String) {
        guard var s = surfaces[id] else { return }
        for (i, h) in s.heights.enumerated() where h > 0.4 {
            let x = s.rect.minX + Double(i) * Surface.cell
            for _ in 0..<Int(min(4, h)) {
                grains.append(Grain(x: x + r(-2, 2), y: s.rect.minY - r(0, h), vx: 0, vy: r(-60, -10),
                                    size: r(0.8, 2.2), alpha: r(0.5, 0.9), phase: r(0, 6.28)))
            }
            s.heights[i] = 0
        }
        surfaces[id] = s
        // Thrown grains fall back under gravity.
        for k in grains.indices where grains[k].vy < 0 { grains[k].vy = abs(grains[k].vy) * 0.3 + 10 }
    }

    /// Pre-settles piles for a still frame (reduce motion).
    func settleInstantly() {
        for id in surfaces.keys {
            for i in surfaces[id]!.heights.indices {
                let n = Double(i) / Double(max(1, surfaces[id]!.heights.count - 1))
                surfaces[id]!.heights[i] = 5 + sin(n * .pi) * 5
            }
        }
        if var g = ground {
            for i in g.heights.indices { g.heights[i] = 26 + sin(Double(i) * 0.08) * 6 }
            ground = g
        }
    }

    func draw(_ ctx: GraphicsContext) {
        for g in grains {
            let rect = CGRect(x: g.x - g.size / 2, y: g.y - g.size / 2, width: g.size, height: g.size)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(g.alpha)))
        }
        for s in surfaces.values { drawPile(ctx, s) }
        if let ground { drawPile(ctx, ground) }
    }

    private func drawPile(_ ctx: GraphicsContext, _ s: Surface) {
        guard s.heights.contains(where: { $0 > 0.2 }) else { return }
        var p = Path()
        p.move(to: CGPoint(x: s.rect.minX, y: s.rect.minY))
        for (i, h) in s.heights.enumerated() {
            p.addLine(to: CGPoint(x: s.rect.minX + Double(i) * Surface.cell, y: s.rect.minY - h))
        }
        p.addLine(to: CGPoint(x: s.rect.maxX, y: s.rect.minY))
        p.closeSubpath()
        let top = s.rect.minY - (s.heights.max() ?? 0)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [.white.opacity(0.97), Color(white: 0.82)]),
                                          startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: s.rect.minY)))
    }
}

struct PowderColliderKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Lets falling powder settle on this view's top edge.
    func powderCollider(_ id: String, topInset: CGFloat = 0, sideInset: CGFloat = 0) -> some View {
        background(GeometryReader { g in
            let f = g.frame(in: .named("powder"))
            Color.clear.preference(key: PowderColliderKey.self,
                                   value: [id: CGRect(x: f.minX + sideInset, y: f.minY + topInset, width: f.width - sideInset * 2, height: f.height - topInset)])
        })
    }
}

/// The falling-powder layer. Put it in a ZStack above the content, with the content using
/// `.coordinateSpace(name: "powder")` and `.powderCollider(_:)` on things to land on.
struct PowderFall: View {
    let colliders: [String: CGRect]
    var sim: PowderSim
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: reduceMotion)) { context in
                Canvas { ctx, size in
                    sim.resize(size)
                    sim.setColliders(colliders)
                    if reduceMotion { sim.settleInstantly() } else { sim.step(now: context.date) }
                    sim.draw(ctx)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
