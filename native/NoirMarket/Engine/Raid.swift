import Foundation

extension Engine {
    /// Nights in a row in one city before a raid becomes likely.
    static let raidStreak = 5

    /// After the night's events, maybe tip the player off that a raid is coming. Rare on the move,
    /// likely once you've sat in one city for five nights or more.
    static func maybeRaidAlert(_ s: inout GameState) {
        guard mode(s) != .tutorial, s.raid == nil, s.encounters.isEmpty, s.day < s.maxDay, s.over == nil else { return }
        let streak = s.streak ?? 0
        let exposed = carried(s) > 0 || hasWeapons(s)
        let chance = streak >= raidStreak ? 0.6 : streak >= 3 ? (exposed ? 0.1 : 0.03) : (exposed ? 0.025 : 0)
        if s.rng.chance(chance) { s.raid = RaidAlert(city: s.city, day: s.day, seen: false) }
    }

    static func stashedWeapons(_ s: GameState, _ city: Int) -> [Int] {
        s.vaultWeapons?[city] ?? Array(repeating: 0, count: Catalog.weapons.count)
    }

    /// Every weapon you carry goes into this city's lock-up. Weapons take no lock-up space.
    static func stashWeapons(_ s: inout GameState) {
        var all = s.vaultWeapons ?? Array(repeating: Array(repeating: 0, count: Catalog.weapons.count), count: Catalog.cities.count)
        for w in s.weapons.indices where s.weapons[w] > 0 {
            all[s.city][w] += s.weapons[w]
            s.weapons[w] = 0
        }
        s.vaultWeapons = all
    }

    static func retrieveWeapons(_ s: inout GameState) throws {
        try idle(s)
        guard var all = s.vaultWeapons, all[s.city].contains(where: { $0 > 0 }) else { throw Failure.invalid("No hardware in this lock-up.") }
        for w in all[s.city].indices where all[s.city][w] > 0 {
            s.weapons[w] += all[s.city][w]
            all[s.city][w] = 0
        }
        s.vaultWeapons = all
    }

    /// The Breaking News response: stock and weapons into the lock-up. Returns the units that didn't fit.
    @discardableResult
    static func goToGround(_ s: inout GameState) -> Int {
        stashAll(&s)
        stashWeapons(&s)
        s.raid?.seen = true
        let left = carried(s)
        s.notice = left > 0
            ? "Your hardware and as much stock as fits are in the lock-up. \(left) units are still on you: the lock-up’s full."
            : "Everything’s in the lock-up. If they come tonight, they’ll find nothing on you."
        return left
    }
}
