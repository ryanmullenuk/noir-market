import Foundation

/// Deterministic PRNG shared by visuals and the game engine.
struct SplitMix: RandomNumberGenerator, Codable, Sendable, Equatable {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum Money {
    static func gbp(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let s = f.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        return (value < 0 ? "−£" : "£") + s
    }

    static func short(_ value: Int) -> String {
        let v = abs(value)
        let sign = value < 0 ? "−" : ""
        switch v {
        case 1_000_000...: return "\(sign)£\(String(format: v >= 10_000_000 ? "%.0f" : "%.1f", Double(v) / 1_000_000))M"
        case 100_000...: return "\(sign)£\(v / 1000)k"
        default: return sign + gbp(v)
        }
    }
}
