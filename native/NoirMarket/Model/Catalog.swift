import Foundation

// Static game data. Numbers trace back to the V9.7 web game unless noted as a rebalance.

struct Good: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let symbol: String   // SF Symbol, monochrome to suit the noir look
    let low: Int
    let high: Int
    var mid: Double { Double(low + high) / 2 }
}

enum Catalog {
    static let goods: [Good] = [
        Good(id: 0, name: "Cocaine", symbol: "snowflake", low: 1200, high: 9000),
        Good(id: 1, name: "Crack", symbol: "cube.fill", low: 800, high: 5200),
        Good(id: 2, name: "Ecstasy", symbol: "pills.fill", low: 200, high: 2800),
        Good(id: 3, name: "Hashish", symbol: "square.fill", low: 300, high: 2500),
        Good(id: 4, name: "Heroin", symbol: "syringe.fill", low: 900, high: 6000),
        Good(id: 5, name: "Ice", symbol: "diamond.fill", low: 700, high: 4200),
        Good(id: 6, name: "Kat", symbol: "laurel.leading", low: 40, high: 800),
        Good(id: 7, name: "LSD", symbol: "ticket.fill", low: 120, high: 1600),
        Good(id: 8, name: "MDA", symbol: "capsule.fill", low: 200, high: 1800),
        Good(id: 9, name: "Morphine", symbol: "drop.fill", low: 500, high: 2600),
        Good(id: 10, name: "Mushrooms", symbol: "umbrella.fill", low: 60, high: 900),
        Good(id: 11, name: "Peyote", symbol: "camera.macro", low: 80, high: 1200),
        Good(id: 12, name: "Pot", symbol: "leaf.fill", low: 80, high: 900),
        Good(id: 13, name: "Speed", symbol: "bolt.fill", low: 160, high: 1800),
    ]

    static func good(named name: String) -> Good? {
        let alias = ["Weed": "Pot", "Ketamine": "Kat", "MDMA": "Ecstasy"][name] ?? name
        return goods.first { $0.name == alias }
    }

    static let cities: [City] = [
        City(id: 0, name: "London", region: "England", lat: 51.507, lon: -0.128, cheap: [2, 8], dear: [0, 4],
             blurb: ["club demand is moving through central London", "airport heat is visible around Heathrow", "street stock is unstable around main terminals"]),
        City(id: 1, name: "Manchester", region: "England", lat: 53.48, lon: -2.24, cheap: [2, 13], dear: [12, 5],
             blurb: ["student demand is active", "north west routes are moving bulk supply", "police attention is up around the city centre"]),
        City(id: 2, name: "Birmingham", region: "England", lat: 52.48, lon: -1.90, cheap: [3, 12], dear: [1, 2],
             blurb: ["Midlands supply lines are moving fast", "BHX traffic is drawing attention", "prices are volatile after a quiet week"]),
        City(id: 3, name: "Liverpool", region: "England", lat: 53.41, lon: -2.98, cheap: [0, 4], dear: [6, 7],
             blurb: ["port rumours are moving the market", "nightlife demand is lifting weekend prices", "cheap stock is appearing near the docks"]),
        City(id: 4, name: "Leeds", region: "England", lat: 53.80, lon: -1.55, cheap: [13, 12], dear: [10, 9],
             blurb: ["student demand is lifting party stock", "supply is moving through west Yorkshire", "street prices look soft today"]),
        City(id: 5, name: "Newcastle", region: "England", lat: 54.98, lon: -1.61, cheap: [5, 1], dear: [3, 13],
             blurb: ["nightlife demand is strong", "scarce stock is moving north", "airport movement is quiet"]),
        City(id: 6, name: "Bristol", region: "England", lat: 51.45, lon: -2.59, cheap: [7, 10], dear: [0, 5],
             blurb: ["south west supply is tightening", "festival demand is moving prices", "police heat is low for now"]),
        City(id: 7, name: "Cardiff", region: "Wales", lat: 51.48, lon: -3.18, cheap: [10, 11], dear: [4, 13],
             blurb: ["weekend demand is rising", "stock looks thin across the centre", "cheap supply is rumoured near the docks"]),
        City(id: 8, name: "Glasgow", region: "Scotland", lat: 55.86, lon: -4.25, cheap: [6, 9], dear: [2, 0],
             blurb: ["city centre demand is volatile", "bulk supply is moving through Scotland", "police pressure is unpredictable"]),
        City(id: 9, name: "Edinburgh", region: "Scotland", lat: 55.95, lon: -3.19, cheap: [4, 11], dear: [7, 8],
             blurb: ["tourist demand is lifting prices", "festival rumours are affecting stock", "street supply is tight"]),
        City(id: 10, name: "Aberdeen", region: "Scotland", lat: 57.15, lon: -2.09, cheap: [9, 3], dear: [0, 1],
             blurb: ["remote supply makes prices unpredictable", "oil money is lifting demand", "stock may be scarce tomorrow"]),
        City(id: 11, name: "Belfast", region: "Northern Ireland", lat: 54.60, lon: -5.93, cheap: [3, 1], dear: [10, 6],
             blurb: ["port movement is changing supply", "police heat is rising", "market demand is uneven"]),
        City(id: 12, name: "Dublin", region: "Ireland", lat: 53.35, lon: -6.26, cheap: [8, 0], dear: [12, 11],
             blurb: ["airport movement is busy", "city centre demand is strong", "rumours suggest supply pressure"]),
        City(id: 13, name: "Cork", region: "Ireland", lat: 51.90, lon: -8.47, cheap: [6, 7], dear: [4, 8],
             blurb: ["port supply is inconsistent", "prices may soften tomorrow", "local demand is quiet"]),
    ]

    static let freeCityCount = 3
    static let cheapFactor = 0.62
    static let dearFactor = 1.45

    static let weapons: [Weapon] = [
        Weapon(id: 0, name: "Knife", price: 500, escape: 0.10, win: 0.18, heat: 2, singleUse: false, note: "Concealable, low police attention"),
        Weapon(id: 1, name: "Baseball Bat", price: 1_000, escape: 0.15, win: 0.22, heat: 3, singleUse: false, note: "Cheap and honest about it"),
        Weapon(id: 2, name: "Machete", price: 2_500, escape: 0.30, win: 0.34, heat: 6, singleUse: false, note: "High intimidation"),
        Weapon(id: 3, name: "Revolver", price: 7_500, escape: 0.35, win: 0.40, heat: 10, singleUse: false, note: "Reliable but slow"),
        Weapon(id: 4, name: "Handgun", price: 12_500, escape: 0.60, win: 0.52, heat: 14, singleUse: false, note: "Standard sidearm"),
        Weapon(id: 5, name: "Sawed-Off Shotgun", price: 25_000, escape: 0.65, win: 0.62, heat: 18, singleUse: false, note: "Powerful at close range"),
        Weapon(id: 6, name: "SMG", price: 50_000, escape: 0.72, win: 0.70, heat: 22, singleUse: false, note: "Good against gangs"),
        Weapon(id: 7, name: "Assault Rifle", price: 100_000, escape: 0.78, win: 0.78, heat: 35, singleUse: false, note: "Draws serious attention"),
        Weapon(id: 8, name: "Machine Gun", price: 250_000, escape: 0.84, win: 0.84, heat: 45, singleUse: false, note: "Rare. Loud. Regrettable."),
        Weapon(id: 9, name: "Molotov Cocktail", price: 5_000, escape: 0.55, win: 0.58, heat: 25, singleUse: true, note: "Single use"),
        Weapon(id: 10, name: "Grenade", price: 15_000, escape: 0.75, win: 0.80, heat: 35, singleUse: true, note: "Single use"),
        Weapon(id: 11, name: "Rocket Launcher", price: 1_000_000, escape: 0.95, win: 0.96, heat: 70, singleUse: false, note: "Massive. Absolutely unnecessary."),
    ]

    static let bags: [Bag] = [
        Bag(id: 0, name: "Bigger Backpack", price: 5_000, slots: 25),
        Bag(id: 1, name: "Sports Bag", price: 20_000, slots: 50),
        Bag(id: 2, name: "Car Boot", price: 100_000, slots: 100),
        Bag(id: 3, name: "Transit Van", price: 1_000_000, slots: 500),
    ]

    static let baseCarry = 30
    static let vaultLevels: [(name: String, capacity: Int, cost: Int)] = [
        ("Lock-up", 100, 0), ("Secure", 250, 100_000), ("Fortress", 500, 500_000),
    ]

    static let lenders: [Lender] = [
        Lender(id: 0, name: "Spammer", limit: 10_000, term: 3, rate: 0.25,
               bio: "Spammer looks friendly, which is normally the first warning. He lends small, smiles wide, and allegedly keeps a little box labelled “late payment fingers”."),
        Lender(id: 1, name: "Tommy", limit: 20_000, term: 5, rate: 0.30,
               bio: "Tommy wears a tracksuit, calls everyone “chief”, and has never once accepted “I forgot” as a payment plan. His dog is somehow on the payroll."),
        Lender(id: 2, name: "Smudger", limit: 50_000, term: 5, rate: 0.50,
               bio: "Smudger does not shout. That is the problem. He just nods, writes your name down, and lets compound interest do the violence first."),
        Lender(id: 3, name: "Bazzer", limit: 75_000, term: 3, rate: 0.50,
               bio: "Bazzer lends like a mate and collects like a horror film. Three days sounds generous until you realise he counts lunch breaks as separate days."),
        Lender(id: 4, name: "Griff", limit: 100_000, term: 3, rate: 0.70,
               bio: "Griff is the last door you knock on when every sensible option has already locked itself. His reminders come with tyre irons and poor spelling."),
    ]

    static let informants: [Informant] = [
        Informant(id: 0, name: "Simon the Snitch", bio: "Cheap, twitchy and usually hiding behind the bins. Knows a bit, guesses a lot.",
                  cost: 100...220, trust: 0.55, scamChance: 0.10,
                  scam: "Simon takes the cash, says “back in two minutes”, and is last seen sprinting through a car park.",
                  vague: "Simon says: “Something’s happening somewhere soon.” You are now poorer and none the wiser."),
        Informant(id: 1, name: "Lucy Loose Lips", bio: "Gossipy, confident and chaotic. Talks too much, hears too much and occasionally remembers which bit was true.",
                  cost: 300...600, trust: 0.72, scamChance: 0.08,
                  scam: "Lucy pockets the cash, winks, and gets into a taxi she clearly cannot afford.",
                  vague: "Lucy says: “I’m hearing movement.” She refuses to explain whether she means stock, police, or her stomach."),
        Informant(id: 2, name: "Pistol Pete", bio: "Serious, expensive and usually plugged into something worth knowing.",
                  cost: 1_500...2_500, trust: 0.94, scamChance: 0.02,
                  scam: "Pistol Pete takes the money, stares at you for three seconds, then says: “Bad investment.” He leaves.",
                  vague: "Pistol Pete says: “Keep your eyes open.” For that money, this feels legally close to robbery."),
    ]

    static let ranks: [(name: String, threshold: Int)] = [
        ("Wannabe", Int.min), ("Street Dealer", 10_000), ("Hustler", 50_000),
        ("Kingpin", 500_000), ("Legend", 1_000_000), ("Drug Lord", 10_000_000),
    ]

    static func rank(for worth: Int) -> Int {
        ranks.lastIndex { worth >= $0.threshold } ?? 0
    }

    static let attackers: [Attacker] = [
        Attacker(name: "a lone addict", weight: 0.36, damage: 6, loot: 0.25, rounds: 1, cap: 800),
        Attacker(name: "a small group of lads", weight: 0.31, damage: 12, loot: 0.35, rounds: 2, cap: 5_000),
        Attacker(name: "a small gang", weight: 0.22, damage: 20, loot: 0.50, rounds: 3, cap: 25_000),
        Attacker(name: "a large gang", weight: 0.11, damage: 34, loot: 0.70, rounds: 3, cap: 250_000),
    ]
}

struct City: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let region: String
    let lat: Double
    let lon: Double
    let cheap: [Int]
    let dear: [Int]
    let blurb: [String]

    func factor(for good: Int) -> Double {
        if cheap.contains(good) { return Catalog.cheapFactor }
        if dear.contains(good) { return Catalog.dearFactor }
        return 1
    }

    func distanceKm(to other: City) -> Double {
        let r = 6371.0
        let dLat = (other.lat - lat) * .pi / 180, dLon = (other.lon - lon) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat * .pi / 180) * cos(other.lat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }

    /// Crossing water or a border means an airport, with customs.
    func needsFlight(to other: City) -> Bool {
        let island: (String) -> Int = { $0 == "Northern Ireland" || $0 == "Ireland" ? 1 : 0 }
        return island(region) != island(other.region)
    }
}

struct Weapon: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let price: Int
    let escape: Double
    let win: Double
    let heat: Int
    let singleUse: Bool
    let note: String
}

struct Bag: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let price: Int
    let slots: Int
}

struct Lender: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let limit: Int
    let term: Int
    let rate: Double
    let bio: String
}

struct Informant: Identifiable, Sendable {
    let id: Int
    let name: String
    let bio: String
    let cost: ClosedRange<Int>
    let trust: Double
    let scamChance: Double
    let scam: String
    let vague: String
}

struct Attacker: Sendable {
    let name: String
    let weight: Double
    let damage: Int
    let loot: Double
    let rounds: Int
    let cap: Int

    func take(from cash: Int, fraction: Double) -> Int { min(cap, Int(Double(cash) * fraction)) }
}
