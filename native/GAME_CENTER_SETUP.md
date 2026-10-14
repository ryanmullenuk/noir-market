# Game Center setup (App Store Connect › Noir Market › Game Center)

The app already reports to these IDs. Create them exactly as written.

## Leaderboards (score format: Money, sort High to Low)

| Reference name | Leaderboard ID | Type |
|---|---|---|
| Daily Challenge | `noir.daily` | Recurring, starts 15 Oct 01:00 UK (00:00 UTC), duration 1 day, restarts every 1 day |
| Standard | `noir.standard` | Classic |
| Long Game | `noir.long` | Classic |
| Sprint | `noir.sprint` | Classic |

Add an English localisation to each (display name as above; format "Money", GBP).

## Achievements (100 points shared across them is fine; each needs a 512×512 image)

| Achievement ID | Title | Description |
|---|---|---|
| `noir.ach.first_sale` | Open for Business | Make your first sale. |
| `noir.ach.big_sale` | Wholesale | Make a single sale worth £50,000 or more. |
| `noir.ach.customs_bribe` | Smooth Operator | Bribe your way through customs. |
| `noir.ach.bare_knuckle` | Bare Knuckle | See off a large gang with your fists. |
| `noir.ach.first_ship` | Logistics | Ship a crate ahead. |
| `noir.ach.every_city` | Nationwide | Ship to every city in the UK and Ireland. |
| `noir.ach.tip_right` | Good Intel | Buy a tip that pays off. |
| `noir.ach.answered` | Pick Up | Pay a caller for a tip. |
| `noir.ach.debt_free` | Square with Griff | Pay Griff back in full. |
| `noir.ach.jailbird` | Jailbird | Spend three or more nights in a cell. |
| `noir.ach.legend` | Legend | Reach a net worth of £1,000,000. |
| `noir.ach.drug_lord` | Drug Lord | Reach a net worth of £10,000,000. |
| `noir.ach.clean_hands` | Clean Hands | Finish a game without a single arrest or bribe. |
| `noir.ach.survive_sprint` | Sprinter | Finish a Sprint alive. |
| `noir.ach.survive_standard` | Thirty Days | Finish a Standard game alive. |
| `noir.ach.survive_long` | The Long Game | Finish a Long Game alive. |
| `noir.ach.daily_done` | Daily Grind | Finish a Daily Challenge. |
| `noir.ach.tutorial` | Graduate | Complete the tutorial. |
| `noir.ach.turf_war` | Turf War | Fight off a rival crew on its own streets. |
| `noir.ach.front` | Legitimate Businessman | Buy a front business. |
| `noir.ach.contract` | Reliable Supplier | Complete a contract. |
| `noir.ach.spain` | Costa del Crime | Retire to Spain. |
| `noir.ach.last_score` | One Last Job | Pull off the final big score. |
| `noir.ach.raided` | Dawn Raid | Get raided on your last night. |

Achievements also show in-game (Records › Achievements) whether or not Game Center is set up.
