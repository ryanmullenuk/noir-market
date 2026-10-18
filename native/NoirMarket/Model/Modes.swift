import Foundation

enum GameMode: String, CaseIterable, Identifiable, Sendable {
    case standard, long, sprint, daily, tutorial
    var id: String { rawValue }

    /// Long Game and Sprint come with the Full Game; Standard, Daily and the Tutorial are free.
    var premium: Bool { self == .long || self == .sprint }

    var days: Int {
        switch self {
        case .standard, .daily: 30
        case .long: 60
        case .sprint: 7
        case .tutorial: 3
        }
    }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .long: "Long Game"
        case .sprint: "Sprint"
        case .daily: "Daily Challenge"
        case .tutorial: "Tutorial"
        }
    }

    var blurb: String {
        switch self {
        case .standard: "Thirty days. The classic."
        case .long: "Sixty days to build an empire, or lose one."
        case .sprint: "Seven days. No time to be careful."
        case .daily: "Same city, same seed, same luck for everyone today. Free-play cities, no perks."
        case .tutorial: "Three guided days: buying, travel, a police stop and NOIRNET."
        }
    }

    var symbol: String {
        switch self {
        case .standard: "calendar"
        case .long: "calendar.badge.plus"
        case .sprint: "bolt.fill"
        case .daily: "sun.max.fill"
        case .tutorial: "graduationcap.fill"
        }
    }

    /// Game Center leaderboard for this mode, if it has one.
    var leaderboard: String? {
        switch self {
        case .standard: "noir.standard"
        case .long: "noir.long"
        case .sprint: "noir.sprint"
        case .daily: "noir.daily"
        case .tutorial: nil
        }
    }

    /// The shared seed for today's Daily Challenge.
    static func dailySeed(for date: Date = .now) -> UInt64 {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return UInt64(c.year! * 10_000 + c.month! * 100 + c.day!) &* 2_654_435_761
    }
}

enum Perk: String, CaseIterable, Identifiable, Sendable {
    case copper, student, docker
    var id: String { rawValue }

    var title: String {
        switch self {
        case .copper: "Ex-Copper"
        case .student: "Student"
        case .docker: "Dock Worker"
        }
    }

    var blurb: String { pro }

    var pro: String {
        switch self {
        case .copper: "Old colleagues look the other way: 30% fewer police stops, and bribes cost 25% less and land more often."
        case .student: "Railcard, coach pass, a mate with a car. Travel costs 40% less, and you’re quick on your feet: running away works 12% more often."
        case .docker: "Knows which crates customs never open. Shipping is cheaper and far safer."
        }
    }

    var con: String {
        switch self {
        case .copper: "Nobody trusts an ex-copper. You start with 25 respect: worse deals, more trouble."
        case .student: "The street sees you as a kid. You start with 35 respect: worse prices, fewer jobs, more chancers."
        case .docker: "Customs know your face. You start with 12% heat, and 45 respect."
        }
    }

    /// Starting cash, respect and heat for this background.
    var start: (cashDelta: Int, respect: Int, heat: Int) {
        switch self {
        case .copper: (0, 25, 0)
        case .student: (0, 35, 0)
        case .docker: (0, 45, 12)
        }
    }

    var symbol: String {
        switch self {
        case .copper: "shield.lefthalf.filled"
        case .student: "backpack.fill"
        case .docker: "shippingbox.and.arrow.backward.fill"
        }
    }
}

struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [Achievement] = [
        .init(id: "first_sale", title: "Open for Business", detail: "Make your first sale.", symbol: "sterlingsign"),
        .init(id: "big_sale", title: "Wholesale", detail: "Make a single sale worth £50,000 or more.", symbol: "banknote.fill"),
        .init(id: "customs_bribe", title: "Smooth Operator", detail: "Bribe your way through customs.", symbol: "airplane.arrival"),
        .init(id: "bare_knuckle", title: "Bare Knuckle", detail: "See off a large gang with your fists.", symbol: "hand.raised.fill"),
        .init(id: "first_ship", title: "Logistics", detail: "Ship a crate ahead.", symbol: "shippingbox.fill"),
        .init(id: "every_city", title: "Nationwide", detail: "Ship to every city in the UK and Ireland.", symbol: "map.fill"),
        .init(id: "tip_right", title: "Good Intel", detail: "Buy a tip that pays off.", symbol: "ear.fill"),
        .init(id: "answered", title: "Pick Up", detail: "Pay a caller for a tip.", symbol: "phone.fill"),
        .init(id: "debt_free", title: "Square with Griff", detail: "Pay Griff back in full.", symbol: "checkmark.seal.fill"),
        .init(id: "jailbird", title: "Jailbird", detail: "Spend three or more nights in a cell.", symbol: "lock.fill"),
        .init(id: "legend", title: "Legend", detail: "Reach a net worth of £1,000,000.", symbol: "crown.fill"),
        .init(id: "drug_lord", title: "Drug Lord", detail: "Reach a net worth of £10,000,000.", symbol: "star.fill"),
        .init(id: "clean_hands", title: "Clean Hands", detail: "Finish a game without a single arrest or bribe.", symbol: "hands.sparkles.fill"),
        .init(id: "survive_sprint", title: "Sprinter", detail: "Finish a Sprint alive.", symbol: "bolt.fill"),
        .init(id: "survive_standard", title: "Thirty Days", detail: "Finish a Standard game alive.", symbol: "calendar"),
        .init(id: "survive_long", title: "The Long Game", detail: "Finish a Long Game alive.", symbol: "calendar.badge.plus"),
        .init(id: "daily_done", title: "Daily Grind", detail: "Finish a Daily Challenge.", symbol: "sun.max.fill"),
        .init(id: "tutorial", title: "Graduate", detail: "Complete the tutorial.", symbol: "graduationcap.fill"),
        .init(id: "turf_war", title: "Turf War", detail: "Fight off a rival crew on its own streets.", symbol: "flag.fill"),
        .init(id: "front", title: "Legitimate Businessman", detail: "Buy a front business.", symbol: "storefront.fill"),
        .init(id: "contract", title: "Reliable Supplier", detail: "Complete a contract.", symbol: "doc.text.fill"),
        .init(id: "spain", title: "Costa del Crime", detail: "Retire to Spain.", symbol: "sun.horizon.fill"),
        .init(id: "last_score", title: "One Last Job", detail: "Pull off the final big score.", symbol: "suitcase.fill"),
        .init(id: "raided", title: "Dawn Raid", detail: "Get raided on your last night.", symbol: "light.beacon.max.fill"),
    ]
}
