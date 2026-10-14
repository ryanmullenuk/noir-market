import Foundation

// All the newsprint: city stories (half true), price events and the ticker headlines.

enum StoryKind: String, Codable, Sendable { case shortage, collapse, crackdown }

struct StoryTemplate: Sendable {
    let kind: StoryKind
    let text: String
}

struct PriceEventTemplate: Sendable {
    let title: String
    let text: String
    let good: String
    let pct: Int
    let days: Int
}

enum Press {
    static let stories: [StoryTemplate] = [
        .init(kind: .shortage, text: "A hen party in {city} has mistaken {drug} for table decorations. Dealers expect demand to climb tomorrow."),
        .init(kind: .collapse, text: "A delivery driver in {city} has taken three crates of {drug} to the wrong Premier Inn. Street prices may fall tomorrow."),
        .init(kind: .crackdown, text: "Police in {city} ordered extra evidence bags after somebody labelled a van “Definitely Not {drug}”. Expect attention tomorrow."),
        .init(kind: .shortage, text: "A wedding in {city} has booked a DJ, a magician and rather too much {drug}. Demand could jump tomorrow."),
        .init(kind: .collapse, text: "A dog walker found {drug} scattered across {city}; half the city is pretending not to notice. Prices may sink tomorrow."),
        .init(kind: .crackdown, text: "Officers in {city} are practising suspiciously cheerful stop-and-search drills. Travel light tomorrow."),
        .init(kind: .shortage, text: "A stag do in {city} bought the wrong kind of party bags. {drug} supply may tighten tomorrow."),
        .init(kind: .collapse, text: "A bargain shipment of {drug} is circling {city} because the driver refuses to ask directions. Prices could tumble tomorrow."),
        .init(kind: .crackdown, text: "A local paper in {city} printed a map of the quietest alleys. Police bought every copy. A crackdown may follow tomorrow."),
        .init(kind: .shortage, text: "Someone in {city} has launched an “artisan” {drug} subscription box. Demand may rise tomorrow."),
    ]

    static let events: [PriceEventTemplate] = [
        .init(title: "Rats in the Shrooms", text: "A dealer’s lock-up had a rat problem. The rats got into a batch of mushrooms and are now apparently having the best night of their lives.", good: "Mushrooms", pct: 35, days: 2),
        .init(title: "Warehouse Raid", text: "Police hit a local storage unit after someone labelled the boxes “definitely not drugs”. Subtle.", good: "Cocaine", pct: 45, days: 3),
        .init(title: "Sniffer Dog Sweep", text: "Sniffer dogs were brought into the festival site. Half the crowd suddenly remembered they left something in the car.", good: "Ecstasy", pct: 30, days: 2),
        .init(title: "Dodgy Batch Warning", text: "Word is there’s a bad batch going round. Nobody knows who made it, but everyone agrees they should probably stop.", good: "Heroin", pct: 25, days: 2),
        .init(title: "Supplier Van Clamped", text: "A supplier’s van was clamped outside a kebab shop. Stock is trapped, driver is fuming, prices are climbing.", good: "Pot", pct: 20, days: 1),
        .init(title: "Customs Got Lucky", text: "Customs opened the one crate everyone hoped they wouldn’t. Apparently “ceramic plant pots” was not convincing.", good: "Cocaine", pct: 50, days: 3),
        .init(title: "Mouldy Stash", text: "Someone stored a big stash in a damp garage. It now smells like a wet dog in a compost bin.", good: "Pot", pct: 25, days: 2),
        .init(title: "Dealer Panic", text: "A paranoid dealer flushed half his stock after seeing a police car. It was just parked outside Greggs.", good: "Kat", pct: 35, days: 2),
        .init(title: "Boat Delay", text: "A shipment is stuck offshore because the skipper got lost, seasick, and emotionally overwhelmed.", good: "Cocaine", pct: 40, days: 2),
        .init(title: "Loose Lips", text: "Someone bragged too loudly in the pub. Everyone is suddenly “just here for a quiet pint”.", good: "Ecstasy", pct: 25, days: 2),
        .init(title: "Overstocked Dealer", text: "A local dealer bought too much stock and needs cash fast. Classic business planning.", good: "Pot", pct: -25, days: 1),
        .init(title: "Festival Drop-Off", text: "A festival supplier overestimated demand after half the crowd spent their money on £14 noodles.", good: "Ecstasy", pct: -30, days: 2),
        .init(title: "Lucky Dock Arrival", text: "A shipment landed clean after customs got distracted by a bloke importing 400 fake designer belts.", good: "Cocaine", pct: -35, days: 2),
        .init(title: "Student Loan Day", text: "Students are buying everything in sight, but one supplier has flooded the market early to get ahead.", good: "Kat", pct: -20, days: 1),
        .init(title: "Grow House Harvest", text: "A grow house had a bumper crop. The neighbours thought the electric bill was just “one of those things”.", good: "Pot", pct: -30, days: 3),
        .init(title: "Quiet Police Week", text: "Police are busy with town centre chaos, leaving dealers unusually relaxed and weirdly confident.", good: "Mushrooms", pct: -20, days: 2),
        .init(title: "Bad Weather, Big Supply", text: "Rain ruined the weekend trade. Dealers are stuck with stock and blaming the Met Office like everyone else.", good: "Ecstasy", pct: -25, days: 1),
        .init(title: "Supplier Clearance", text: "A supplier is clearing stock before disappearing to Spain for “personal reasons”.", good: "Heroin", pct: -30, days: 2),
        .init(title: "Wrong Delivery Address", text: "A bulk order went to the wrong flat. The new “owner” is selling cheap before anyone asks questions.", good: "Cocaine", pct: -25, days: 1),
        .init(title: "Market Flood", text: "Too many dealers turned up with the same product. Everyone is undercutting each other and calling it strategy.", good: "Pot", pct: -35, days: 2),
        // Rebalance: a few events for goods the original table never touched.
        .init(title: "Lab Fire", text: "A kitchen chemist in a rented semi set fire to the curtains, the kitchen and his career.", good: "Ice", pct: 40, days: 2),
        .init(title: "Pharmacy Audit", text: "A hospital audit found the morphine cupboard “mostly vibes”. Supply has dried up overnight.", good: "Morphine", pct: 35, days: 2),
        .init(title: "Gap Year Returns", text: "A minibus of gap-year students came home with rucksacks that rattle. Nobody is asking.", good: "LSD", pct: -30, days: 2),
        .init(title: "Gym Season", text: "January gym memberships have created sudden, inexplicable demand for staying awake.", good: "Speed", pct: 30, days: 2),
    ]

    static let headlines: [String: [String]] = [
        "London": ["POLICE RAID STORAGE UNITS AFTER NEIGHBOURS REPORT “TOO MANY MEN WITH SPORTS BAGS”", "CLUB NIGHT CANCELLED AFTER DJ FORGETS USB AND EVERYONE BLAMES SECURITY", "SNIFFER DOG RETIRES EARLY AFTER “VERY CONFUSING” NIGHT IN SOHO", "FESTIVAL CROWD SPENDS MORE ON CHIPS THAN PILLS"],
        "Manchester": ["WAREHOUSE PARTY SHUT DOWN AFTER SOMEONE INVITES THEIR ENTIRE CONTACT LIST", "POLICE PRESENCE UP AFTER DEALERS START USING BRANDED HOODIES", "STUDENTS DECLARE THEMSELVES “ABSOLUTELY FINE”", "LOCAL DEALER LOSES STASH AFTER HIDING IT “SOMEWHERE SAFE”"],
        "Birmingham": ["CUSTOMS TIP-OFF SENDS DEALERS INTO PANIC, MOSTLY VIA BADLY SPELLED GROUP CHATS", "MAIN SUPPLIER STUCK ON THE M6", "POLICE HELICOPTER SPOTTED, HALF THE CITY SUDDENLY “JUST OUT FOR MILK”", "TWO CREWS ACCIDENTALLY ORDER THE SAME PRODUCT"],
        "Liverpool": ["NEW SHIPMENT LANDED WITHOUT ANYONE FALLING IN THE MERSEY", "SUSPECT HIDES STASH IN DOG FOOD BAG, DOG UNIMPRESSED", "EVERYONE CLAIMS THEY’RE ONLY HAVING “A QUIET ONE”", "FAKE PRODUCT DESCRIBED AS “MAINLY DISAPPOINTMENT”"],
        "Leeds": ["LOAN PAYMENTS HIT ACCOUNTS AND COMMON SENSE LEAVES", "DEALER ORDERS DOUBLE AND CALLS IT “EXPANSION”", "COURIER LOST, REFUSES TO ASK FOR DIRECTIONS", "DOORMAN FINDS STASH IN A TUB OF HAIR GEL"],
        "Newcastle": ["BIGG MARKET GETS LOUD, THEN SUDDENLY QUIET WHEN THE VAN DOORS OPEN", "COURIER BLAMES THE TYNE, SATNAV AND SOCIETY", "DEALER USES SAME PUFFER JACKET FOR EVERY DROP", "CLUBBERS PROMISE A SMALL ONE, IMMEDIATELY RUIN PLAN"],
        "Bristol": ["THREE PEOPLE WITH DREADLOCKS DECLARE IT “BASICALLY SUMMER”", "LOCK-UP FLOODS AND EVERYTHING STARTS GROWING SOMETHING ELSE", "TIP-OFF FROM AN OVERCONFIDENT TAXI DRIVER", "NEW SUPPLIER ARRIVING BY VAN, BOAT, OR POSSIBLY JUST VIBES"],
        "Cardiff": ["FANS PROMISE THEY’RE “JUST OUT FOR THE RUGBY”", "DEALER USES SAME BENCH FOR EVERY MEET", "SUPPLIER HIDES GOODS TOO WELL AND FORGETS WHERE", "CLUB RAID FINDS THREE LOST PHONES AND A MAN ASLEEP IN A TOILET"],
        "Glasgow": ["OFFICERS ARGUE OVER WHICH CLOSE IS THE RIGHT CLOSE", "SOMEONE SAYS “WE’LL JUST HAVE ONE”", "PRODUCT DESCRIBED AS “A PURE LIBERTY”", "BAGGIE FOUND IN A PIE WRAPPER"],
        "Edinburgh": ["FESTIVAL CROWD PRETENDS THIS IS CULTURAL", "TOURIST DESCRIBES “A VERY QUIET FIREWORK”", "OLD TOWN LOCK-UP RAIDED AFTER “ODD BAGPIPE HOURS”", "CLEAN SHIPMENT BY TRAIN SENDS DEALERS INTO A POLITE PANIC"],
        "Aberdeen": ["DEALERS BLAME THE WIND LIKE IT HAS A PERSONAL AGENDA", "POLICE RAID WRONG LOCK-UP, FIND THREE TYRES AND A VERY ANGRY CAT", "COURIER DECIDES THE A90 IS “NOT FOR HIM TODAY”", "VAN FAILS ANOTHER MOT"],
        "Belfast": ["GROUP CHAT LEAKS TO THE WORLD’S NOSIEST COUSIN", "FRESH STOCK ENTERS QUIETLY FOR ONCE", "EVERYONE NOW SEARCHING A SHED", "“ONE QUICK PINT” BECOMES A CIVIC EVENT"],
        "Dublin": ["TEMPLE BAR PRICES OUTRUN COMMON SENSE", "CUSTOMS CHASE A LAD WITH FAKE WATCHES", "DEALER STARTS TAKING VOICE NOTES IN PUBLIC", "BAGGIE FOUND IN A PHONE CASE WITH NO PHONE"],
        "Cork": ["NOBODY CAN AGREE WHO LANDED WHAT", "SUPPLIER CALLS OVERSTOCK “A STRATEGIC POSITION”", "COURIER PARKS OUTSIDE THE SAME CHIPPER THREE TIMES", "ONE LAD ON A BIKE WITH TERRIBLE JUDGEMENT"],
    ]

    static let friendGifts = [
        "An old mate from school turns up, says “don’t ask”, and leaves {qty} {drug} on the table.",
        "A cousin you forgot you had is “clearing out the loft”. You inherit {qty} {drug}.",
        "Someone owes you a favour and pays it back in {drug}. {qty} of them.",
    ]

    static let deaths = [
        "Found face down in a canal, still clutching a receipt for a sports bag.",
        "The last thing anyone heard was “I know a shortcut.”",
        "Gone. The pigeons in the square were the only witnesses, and they’re not talking.",
    ]

    static let lenderQuips: [String: [String]] = [
        "Spammer": [
            "“{amount}. Lovely. I’ve written your name in my little book. In pen.”",
            "“Day {day}, sunshine. I’d hate for your fingers to become a talking point.”",
            "“Pleasure doing business. I hope it stays a pleasure. For you, mainly.”",
            "“No rush. Well, a bit of a rush. Day {day}. I’ve got a box for fingers, you know.”",
        ],
        "Tommy": [
            "“Sorted, chief. Day {day}. The dog remembers faces.”",
            "“{amount}, no paperwork. Paperwork’s for people who pay back late. Don’t be paperwork.”",
            "“I trust you, chief. The dog doesn’t, but I do.”",
            "“Day {day}. Not day {day} and a bit. Day {day}.”",
        ],
        "Smudger": [
            "He nods once, writes something down, and underlines it twice.",
            "“Day {day}.” He doesn’t say anything else. He doesn’t need to.",
            "“Interest is a kind of weather. You don’t want to be out in it.”",
            "He shakes your hand slightly too long, then smiles slightly too little.",
        ],
        "Bazzer": [
            "“Easy, mate. Three days. I count Sundays twice, mind.”",
            "“{amount}! Party! Day {day}, or I bring the party round yours.”",
            "“Mates rates, mate. Mates who don’t pay become former mates. Former everything.”",
            "“My nan used to say a debt is a promise. She also broke a man’s jaw over £40.”",
        ],
        "Griff": [
            "“Day {day}. Bring it in a bag. Not a carrier bag. A proper bag.”",
            "He counts the money out slowly, the way a dentist counts teeth.",
            "“You’ll pay. Everyone pays. Some of them still have both knees.”",
            "“If you’re thinking of leaving the country, I’ve got cousins in all of them.”",
        ],
    ]

    /// What callers open with, by caller (0 Simon, 1 Lucy, 2 Pete, 3 unknown).
    static let callOpeners: [[String]] = [
        ["“It’s Simon. Don’t hang up. Please. I’ve got something and I’ve got a parking fine.”",
         "“Are you alone? Good. I’m not. Long story. Listen, I’ve got a tip.”",
         "“Simon here. I’m calling from a phone box. Do you know how hard those are to find?”"],
        ["“Babe, it’s Lucy. You will not BELIEVE what I heard in the queue at Greggs.”",
         "“Lucy. Quick one. Well, not quick, I never am. But it’s good.”",
         "“I shouldn’t be telling you this. I’ve told four people already, but still.”"],
        ["“Pete. I don’t ring people. I’m ringing you. Think about that.”",
         "“Pete. Don’t say my name on this line. Yes, I just did. Listen.”",
         "“It’s Pete. Rent’s due, so you’re getting mates’ rates. Once.”"],
        ["Heavy breathing, then: “You’re the one moving stock in town, yeah? I’ve got something.”",
         "“Wrong number. Unless you want a tip. Then it’s the right number.”",
         "A voice run through a toy voice-changer: “I KNOW THINGS.” Then, normally: “Sorry, it’s stuck.”"],
    ]

    static let intelTrue = [
        "The rumour mill grinds slow, but it grinds.",
        "Even a stopped clock, et cetera.",
        "Somebody on the street owes the hen party a thank-you card.",
        "Fact-checked by three blokes in a pub. All agreed.",
    ]

    static let intelFalse = [
        "Turns out it was a man in a pub doing an impression of a man in a pub.",
        "Sources have been demoted to ‘some lad’.",
        "The crates were full of decorative pebbles. Nobody is sure why.",
        "Our correspondent has been sacked, rehired and sacked again.",
    ]

    static let tipRight = [
        "{who} wants it known they’re ‘basically psychic now’.",
        "{who} is insufferable about it already.",
        "{who} has asked for a bonus. In cash. In a sock.",
        "{who} says the next one costs double. They’re joking. They’re not joking.",
    ]

    static let tipWrong = [
        "{who} blames Mercury being in retrograde, or possibly Rotherham.",
        "{who} says you must have heard it wrong. You didn’t.",
        "{who} has changed their number. Again.",
        "{who} insists it was right ‘spiritually’.",
    ]

    static func fill(_ text: String, city: String, good: String) -> String {
        text.replacingOccurrences(of: "{city}", with: city).replacingOccurrences(of: "{drug}", with: good)
    }
}
