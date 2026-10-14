import Foundation

struct Market: Codable, Sendable, Equatable {
    var price: [Int]
    var supply: [Int]
    var previous: [Int]
}

struct Loan: Codable, Sendable, Identifiable, Equatable {
    var id: Int
    var lender: Int
    var principal: Int
    var rate: Double
    var startDay: Int
    var due: Int
    var term: Int
    var missed: Int = 0
}

struct Shipment: Codable, Sendable, Identifiable, Equatable {
    var id: Int
    var from: Int
    var to: Int
    var goods: [Int]
    var arrives: Int
    var intercepted: Bool
}

struct ActiveEvent: Codable, Sendable, Equatable {
    var city: Int
    var good: Int
    var pct: Int
    var startsDay: Int
    var daysLeft: Int
    var title: String
}

struct Story: Codable, Sendable, Equatable {
    var city: Int
    var good: Int
    var kind: StoryKind
    var text: String
    var isTrue: Bool
}

struct DealOffer: Codable, Sendable, Equatable {
    var good: Int
    var city: Int
    var qty: Int
    var buyCost: Int
    var payout: Int
    var odds: [Double] // success, bad, arrest, scam, jackpot
}

enum Encounter: Codable, Sendable, Equatable {
    case police(PoliceStop)
    case trouble(Trouble)
    case collector(Collector)
}

struct PoliceStop: Codable, Sendable, Equatable {
    var airport: Bool
    var bribe: Int
    var bribeChance: Double
    var runChance: Double
    var fightChance: Double
    var jail: Int
    var fine: Int
}

struct Trouble: Codable, Sendable, Equatable {
    var attacker: Int
    var round: Int
    var runChance: Double
    var fightChance: Double
    var handOver: Int
}

struct Collector: Codable, Sendable, Equatable {
    var loan: Int
    var owed: Int
}

struct DayReport: Codable, Sendable, Equatable {
    var day: Int
    var city: Int
    var travelled: Bool
    var headline: String
    var story: String
    var lines: [String]
    /// Next-day verdicts on yesterday's intel and tips. Optional so older saves still load.
    var checks: [String]?
}

struct PendingTip: Codable, Sendable, Equatable {
    var informant: Int
    var city: Int
    var good: Int
    var up: Bool
    var price: Int
    var due: Int
}

struct Outcome: Codable, Sendable, Equatable {
    var title: String
    var text: String
    var good: Bool
}

struct Stats: Codable, Sendable, Equatable {
    var trips = 0, nightsIn = 0, unitsBought = 0, unitsSold = 0, biggestSale = 0
    var arrests = 0, bribesPaid = 0, fightsWon = 0, fightsLost = 0, escapes = 0
    var mugged = 0, loansTaken = 0, jailDays = 0, tipsBought = 0, dealsDone = 0
    var shipmentsSent = 0, shipmentsLost = 0, bestWorth = 0
}

struct GameOver: Codable, Sendable, Equatable {
    var worth: Int
    var rank: Int
    var died: Bool
    var epitaph: String
}

struct GameState: Codable, Sendable, Equatable {
    var version = 1
    var seed: UInt64
    var rng: SplitMix
    var playerName = ""
    var fullAccess = false

    var day = 1
    var maxDay = 30
    var city = 0
    var cash = 2_500
    var bank = 0
    var health = 100
    var heat = 0
    var rep = 50

    var carry: [Int]
    var carryCost: [Int]
    var bags: [Int] = []
    var weapons: [Int]
    var vault: [[Int]]
    var vaultLevel: [Int]
    var loans: [Loan] = []
    var shipments: [Shipment] = []
    var nextID = 1

    var markets: [Market] = []
    var events: [ActiveEvent] = []
    var story: Story?
    var storyDeck: [Bool] = []
    var ticker: [String] = []

    var informantPrice: [Int] = [0, 0, 0]
    var informantUsed: [Bool] = [false, false, false]
    var phones = 0
    var pendingTips: [PendingTip]?
    /// Test mode: unlimited cash and every city, enabled by the name GODMODE. Never counts for records.
    var godMode: Bool?
    var calledToday = false
    var deal: DealOffer?
    var tradedToday = false
    var repFromTradesToday = 0

    var encounters: [Encounter] = []
    var outcome: Outcome?
    var report: DayReport?
    var notice: String

    var rankIndex = 0
    var rankPending = 0
    var rankDays = 0
    var stats = Stats()
    var over: GameOver?

    init(seed: UInt64, city: Int, name: String, fullAccess: Bool) {
        self.seed = seed
        rng = SplitMix(seed: seed)
        self.city = city
        playerName = name
        self.fullAccess = fullAccess
        let n = Catalog.goods.count
        carry = Array(repeating: 0, count: n)
        carryCost = Array(repeating: 0, count: n)
        weapons = Array(repeating: 0, count: Catalog.weapons.count)
        vault = Array(repeating: Array(repeating: 0, count: n), count: Catalog.cities.count)
        vaultLevel = Array(repeating: 0, count: Catalog.cities.count)
        notice = "\(Catalog.cities[city].name). £2,500 in your pocket, nothing in the bank and a conscience you’re hoping to sell."
        Engine.setUp(&self)
    }
}
