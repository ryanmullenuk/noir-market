# Noir Market: native rebuild notes

The `native/` folder is a ground-up SwiftUI rebuild of the V9.7 web game. The
web game in the repository root is unchanged and still deploys as before.
`SPEC_EXTRACTED.md` is the full audit of V9.7 that this rebuild was based on.

## Kept from V9.7

- **Core loop:** 30 days, 14 commodities with the same price ranges, 14 UK and
  Ireland cities, and three free cities with a single "Unlock All Cities"
  purchase under the same product ID.
- **Characters:** the five lenders, the three informants, the weapons list,
  burner phones, lock-ups, shipping and the six ranks.
- **Writing:** the city stories with the 5-true/5-false truth deck, all 20
  price events, the city headlines, the lender and informant lines, and the
  Redhead Games intro and the original music.

## New

- **Noir identity:**
  - Didot display type, typewriter body text and one neon-red accent.
  - Rain, film grain, a procedural skyline with lit windows, lightning on the title, and a new app icon.
  - The *Evening Ledger* morning paper each day.
  - Full-screen encounters: flashing police lights, a flickering street lamp in alleys.
- **One-screen layout:**
  - Header, stats, a news wire and the market on one screen.
  - Tap any good to trade with a slider.
  - A five-button dock and a "Stay the night / Lie low" button. No long scrolling dashboard.
- **Travel map:** a drawn map of Great Britain and Ireland with fares and routes. Each city shows its specialities.
- **City identity:** every city sells two goods cheap and pays dear for two others, so routes matter, even in the free three.
- **Market depth (slippage):** big orders move the price against you. This replaces the old "sell 50+ and the price crashes" rule.
- **Encounters as choices with visible odds:**
  - Police: bribe, let them "lose" half your stock, run, go quietly, or fight.
  - Street trouble: run, fight, or hand over.
  - Debt collectors: pay, or take a beating.
- **Lie low:** staying without trading cools heat.
- **Customs:** flights between islands raise the stop risk when you're carrying.
- **Shipping:** goods now arrive overnight and can be intercepted. The risk is shown before you send.
- **Informant tips:** a tip names a city, a good and a direction for tomorrow, and comes true at the informant's reliability.
- **Records table**, a "Case Closed" or obituary ending, and lifetime stats.
- **Haptics and music** controls, with mute for both.

## V9.7 bugs and exploits fixed by design

| V9.7 issue | Native behaviour |
|---|---|
| Every reload wiped the save | JSON save in Application Support, written after every action and on backgrounding |
| Clean police stop fined you £500–5,000 | Clean stop costs nothing and lowers heat |
| Informant tips never moved prices | Tips schedule a real price shock for tomorrow |
| Price-event headlines never shown | They're the news wire and the morning paper |
| City picker teleported a resumed game | Continue resumes; the picker is only for new games |
| New Game dropped the city unlock | The entitlement comes from StoreKit, not the save |
| Story truth leaked after travel | Never revealed |
| Closing a modal skipped police or debt | Encounters are full-screen and must be answered; they're saved, so a relaunch doesn't skip them |
| Unlimited stacked loans | One loan per lender |
| £1 payment reset loan interest | Part payments keep accrued interest |
| Contact deals were a money pump | One call a day, odds shown, and a modestly positive expected value |
| Reputation farming with 1-unit trades | At most +3 rep a day from trades, and only for trades of £1,000+ |
| Death and day 31 not saved | Finished games are filed in records and can't be resumed |
| Score ignored lock-up stock | Score and rank both use full net worth: cash, bank, carried, stashed, in transit and weapons, minus debt |
| GODMODE cheat name | Gone |
| Free web unlock | Not applicable (StoreKit only) |

## Balance

`native/Tools/BalanceSim` plays 600 bot games per configuration.

- **Free play:** a naive bot (buys anything under 80% of its usual price and wanders at random) has a median of about £200k ("Hustler"). Its 90th percentile is around £650k, and about 2% finish as Wannabe.
- **Encounters:** about nine per game.
- **Deaths:** almost only from choosing to fight.

A player who learns the city specialities, reads the paper and uses tips should reach Kingpin or Legend. Drug Lord (£10M) is meant to be rare.

## Before TestFlight

1. In App Store Connect, create the app record for `games.redhead.noirmarket` if it isn't there. Then add the non-consumable `games.redhead.noirmarket.unlockallcities` at £1.99.
2. Age rating: answer the questionnaire honestly (frequent drug references, realistic violence references, simulated gambling: none). Expect **18+**.
3. Make sure `https://redhead.games/noir-market/support.html` and `privacy.html` are live. The app links to them.
4. Archive in Xcode (Product > Archive) with team `82XX49T84C`, then upload.
5. App Review note to include: "A fictional crime-trading strategy game in the Dope Wars tradition. It does not encourage drug use; there is no consumption mechanic."
