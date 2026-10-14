# Noir Market: Extracted Game Design Specification (V9.7)

Extracted from `game.js` (6,105 lines), `index.html`, `styles.css`, `sw.js`, `manifest.json`, `scripts/prepare-ios.mjs` and `ios/NoirMarket/*.swift` as of commit `9269cf3`.

This document describes how the game **actually behaves at runtime**, not what older comments or dead code say. `game.js` is a stack of about 25 release "layers" (V1.6 to V9.7). Each layer reassigns global functions and wraps earlier ones. Section 0 explains how this resolves, and every rule below cites the layer that wins. Section 16 lists bugs, dead code and balance problems.

---

## 0. How the runtime resolves (read this first)

### 0.1 Boot sequencing quirk
1. Lines 1-13 load polyfills.
2. The V9.5 block (lines 17-281) registers `installV95` on `DOMContentLoaded` using the **native** `addEventListener`.
3. Lines 324-346 install a "legacy boot filter". While `window.__NOIR_FILTER_LEGACY_BOOT === true`:
   - `setTimeout` and `setInterval` return 0 and never run their callbacks.
   - `document.addEventListener` drops `DOMContentLoaded` and `visibilitychange`.
   - `window.addEventListener` drops `load`, `pageshow`, `scroll` and `resize`.
4. Lines 347-5556 are the legacy layers. All their top-level timers and boot listeners are swallowed, including `initialiseNoirMarket`, `setupSplashLoaderV27`, the V3.3 informant scheduler, the 15-second news `setInterval`, every `vXXSelfTest` call and every `initV66`/`initV73`/V8.8 `init`. Function **reassignments** in those layers still take effect.
5. Line 5559 turns the filter off and restores the native timers and listeners.
6. The V9.5 music layer (5569-5832) and the V9.3 renderer (5837-5983) register boot listeners normally.
7. `DOMContentLoaded` handlers run in this order: `installV95`, then `initV92Mobile`, then V9.5 music `init`, then `initRendererV93`.

### 0.2 Final ("winning") implementations

| Function | Winning layer (line) | Notes |
|---|---|---|
| `draw` | V9.5 wrapper (270) → `renderGameV93` (5871) | Older draw wrappers (V3.7 cash prompt, V3.8 contact-call scheduler) never run. |
| `save` | V9.5 wrapper (268) → V9.5-music `save` (5780) | Writes only `noir_market_v9_7`. |
| `load` | V9.5 wrapper → `loadGameV93` (5849) | Startup calls `loadGameV93` directly. |
| `baseState` | V9.5 → V9.1 → V8.8 → V7.3 → V6.6 → V5.0 → V4.2 → V4.1 → V4.0 → V3.8 → V3.7 → V3.4 → V3.3 → original (2332) | |
| `newGame` | V6.6 wrapper (5133) → original (1068) | |
| `modal`, `done`, `closeModalV22` | V3.4/3.5 (2976-3011) | |
| `showWelcome` | V9.5 (202) | |
| `showMenu` | V9.5 wrapper (265) → `showMenuV91` (5750) | |
| `nextDay` | V9.5 wrapper (104) → V3.7 (3361) | |
| `newRumour`, `rumourHtml` | V9.5 (73, 94) | |
| `genPrices`, `generateNewsEvent` | V3.3 (2583, 2566) | |
| `randomEvent` | V7.3 wrapper (5264) → original (1246) | |
| `maybeArrest` | V7.3 → V4.1 → V3.4 | |
| `showArrestModal` | V8.8 (5484) | Replaces V7.3 and V4.2 entirely. |
| `applyArrestPenalty` | V8.8 (5508) → V4.2 (4585) → V3.7 (3146) | |
| `showFightChoice` | V8.8 (5513) | |
| `resolveFight`, `maybeFight`, `attacker`, `endGame` | Original (569, 543, 531, 653) | |
| `handleDueLoans`, `missDueLoans` | Original (1569, 1573) | |
| `chooseLoan` | V1.8 (1786) | |
| `bank` | V4.1 (4269) | |
| `payDebtAmount`, `paySpecificLoan`, `payAnyDebtFromModal` | V3.7 (3208-3309) | |
| `shop` | V3.8 "Black Market" (3588) | |
| `contacts` | V3.8 (3621) | |
| `hustle` | V6.6 (5086) | |
| `sellModal` | V4.0 (3960) | |
| `buyModal` | Original (1161) | |
| `dump` (Storage/Vault) | Original (1366) | |
| `travel` | V3.7 (3473) | |
| `showTravelFlights` | V9.5 (214) | |
| `airportWarning`, `performFlightV22`, `boardFlightWithSeizure` | V4.1 (4217-4260) | |
| `showShippingHub`, `showShippingImport` | Original (1613, 1626) | |
| `showShippingExport` | V4.1 (4309) | |
| `validShipDestV20`, `shippingDestinationTilesV20` | V9.5 (232, 243) | |
| `stay` | Original → `performStayV22` (2202) | |
| `toast`, `hustle` informant list | Original / V6.6 | |

---

## 1. Starting state

Defined by `baseState()` at line 2332, extended by later layers.

| Field | Value |
|---|---|
| `cash` | £1,000 |
| `bank` | £0 |
| `debt` | £0 (derived from `loans[]`) |
| `health` | 100 |
| `heat` | 0 (0-100) |
| `reputation` | 50 (0-100) |
| `day` / `maxDay` | 1 / 30 |
| `city` | 0 (London) until the start picker sets it |
| Carry capacity | 20 units base (see `totalSpace()`) |
| `inv` | 0 of every commodity |
| `supply` | `rand(0,1000)` per commodity |
| `owned` (storage upgrades), `weapons`, `loans`, `shipments` | Empty arrays |
| `vaults` / `weaponVaults` | One per city, empty; vault level 'Basic' (100 slots) |
| `rankState` | `{current:'Wannabe', days:0, pending:null, pendingDays:0}` |
| `avatar` | 'male' |
| `allCitiesUnlocked` | false |
| `accessMode` | 'free' |
| `notice` | "You start in London with £1,000 cash, £0 in the bank and a clean slate." |
| `v38.burnerPhones` | 0 |
| `stats` | Counters, all 0 (see §13). `bestNet` starts at 1000 and `bestRank` at 'Wannabe'. |
| `playerName` | '' (backfilled from `localStorage.noir_market_player_name`) |

**Starting city options (V9.5).**
- **Free Play:** London, Manchester, Birmingham (indices 0-2, `FREE_CITY_COUNT = 3`).
- **Full Game:** any of the 14 cities. The picker preselects index 0.
- The V6.6 14-city picker with a RANDOM CITY button (lines 4885-5000) is dead code. V9.5 replaced it.

`newGame()` runs these steps in order: `baseState()`, `ensureStats()`, `genPrices()`, `newRumour()`, `updateRankProgress()`, `save()`, `draw()`.

---

## 2. Commodities

There are 14 commodities (`drugs`, line 356). Every city draws prices from the **same** range. There are **no per-city base-price modifiers**. Cities differ only through events, rumours, tips and their own independent price walks.

| # | Name | Icon | Low £ | High £ | Midpoint £ |
|---|---|---|---|---|---|
| 1 | Cocaine | ⚪ | 1,200 | 9,000 | 5,100 |
| 2 | Crack | 🪨 | 800 | 5,200 | 3,000 |
| 3 | Ecstasy | 🟢 | 200 | 2,800 | 1,500 |
| 4 | Hashish | 🧱 | 300 | 2,500 | 1,400 |
| 5 | Heroin | 💉 | 900 | 6,000 | 3,450 |
| 6 | Ice | 💎 | 700 | 4,200 | 2,450 |
| 7 | Kat | 🌿 | 40 | 800 | 420 |
| 8 | LSD | 🎟️ | 120 | 1,600 | 860 |
| 9 | MDA | 🟣 | 200 | 1,800 | 1,000 |
| 10 | Morphine | 🧴 | 500 | 2,600 | 1,550 |
| 11 | Mushrooms | 🍄 | 60 | 900 | 480 |
| 12 | Peyote | 🌵 | 80 | 1,200 | 640 |
| 13 | Pot | 🍃 | 80 | 900 | 490 |
| 14 | Speed | ▱ | 160 | 1,800 | 980 |

Event text uses aliases, which `cleanDrug` maps to real commodities: `Weed → Pot`, `Ketamine → Kat`, `MDMA → Ecstasy`.

### 2.1 Daily price model (`genPrices`, V3.3)
This runs for **every city** and every commodity on each day advance:
```
old    = m.prices[d] || rand(lo,hi)
target = rand(lo,hi)
mult   = rand(88,118)/100
if crash active: mult *= crash.factor; crash.factor = min(.96, f + (1-f)*.38); crash.days--
price  = max(1, round(((old*2 + target)/3) * mult))
trend  = price >= old              (↑ green / ↓ red)
supply = clamp(round(supply * rand(80,120)/100) + rand(-80,90), 0, 1200)
```
- **Volatility.** Each day is a one-third pull towards a fresh uniform draw, times a ±15% multiplier.
- **Upward drift.** `E[mult] = 1.03`, so long-run prices settle about 9-10% above the midpoint.

After the walk, these steps run in order:
1. `applyRumourResult(yesterday's rumour)` (§8.2).
2. `tickExistingEvents()`, which applies active price events (§8.3).
3. **Elite supply:** if reputation ≥ 81, current-city supply becomes `min(1500, supply*1.12 + 25)`.
4. `generateNewsEvent()`.

### 2.2 Large-sale crash (`depressMarketAfterSale`)
- **Trigger:** a sale of `q ≥ 50` units, or value ≥ £100,000, or `q ≥ max(20, 18% of local supply)`.
- **Effect:** the local price is multiplied by `rand(42,72)/100` straight away, the trend is set to down, and a crash runs for `rand(1,3)` days. The crash factor recovers by 38% of the remaining gap each day, capped at 0.96.
- The seller is paid the **pre-crash** price.

### 2.3 Buying and selling
- **Buy (original `buyModal`).** Each tile shows price, available supply and units owned, with a −/+ quantity control, BUY and BUY MAX.
  - BUY MAX = `min(floor(cash/price), free space, supply)`.
  - A purchase is validated against stock, funds and storage. It reduces local supply.
  - Every purchase gives **+1 reputation**.
  - Clicking any market row on the main screen also opens Buy.
  - At reputation ≥ 81 a line reads: "Elite suppliers unlocked".
- **Sell (V4.0 `sellModal`).** Drugs sell **all-or-nothing**:
  - "SELL ALL" sells carried stock.
  - "SELL ALL FROM SAFE" sells the current city's vault stock.
  - Weapons sell by quantity (or SELL ALL) at **50% of purchase price**.
  - Every drug sale gives +1 reputation and can trigger the large-sale crash.
  - Selling does not add to local supply.

---

## 3. Cities, access and travel

### 3.1 Cities (`places`, line 357)

| # | City | Region | Airport label | Base fare £ | Free? |
|---|---|---|---|---|---|
| 0 | London | UK | Heathrow / City | 120 | **Free** |
| 1 | Manchester | UK | Manchester Airport | 90 | **Free** |
| 2 | Birmingham | UK | BHX | 80 | **Free** |
| 3 | Liverpool | UK | John Lennon | 110 | Locked |
| 4 | Leeds | UK | Leeds Bradford | 120 | Locked |
| 5 | Newcastle | UK | NCL | 160 | Locked |
| 6 | Bristol | UK | Bristol Airport | 110 | Locked |
| 7 | Cardiff | Wales | Cardiff Airport | 120 | Locked |
| 8 | Glasgow | Scotland | GLA | 190 | Locked |
| 9 | Edinburgh | Scotland | EDI | 190 | Locked |
| 10 | Aberdeen | Scotland | ABZ | 260 | Locked |
| 11 | Belfast | Northern Ireland | BFS | 220 | Locked |
| 12 | Dublin | Ireland | DUB | 210 | Locked |
| 13 | Cork | Ireland | ORK | 250 | Locked |

**Access rule.** `availableCityV95(i) = (allCitiesUnlocked && accessMode==='full') || i < 3`.

Locked cities still show in the Travel list. They have a dashed amber border, show the fare as "FULL GAME" and add "· Unlock all cities". Tapping one triggers the unlock request. Shipping destination tiles for locked cities are disabled and read "Full game".

### 3.2 Fares (`travelFare`)
```
fare = round10( base[to] + |toIndex - fromIndex| * 18 + rand(-45, 95) )   // round10 = max(10, nearest 10)
```
- The fare is cached per `day:from:to` in `s.travelFares`, so it stays stable within a day. The cache is never pruned.
- "Distance" is the **list-index gap**, not geography.
- Cash must cover the fare.
- **Every trip takes exactly one day.** There are no variable travel times.

### 3.3 Travel flow
1. Main **Travel & Shipping** button: a modal with TRAVEL and SHIPPING tabs.
2. **TRAVEL tab:** a city list with fares, plus a STAY HERE button.
3. Picking a city when carrying **weapons** opens "YOU ARE CARRYING WEAPONS" (V4.1) with four choices:
   - CARRY THEM (sets a flag)
   - STASH IN CURRENT CITY (moves all weapons into the vault; fails if the vault is full)
   - DITCH WEAPONS (deletes them)
   - CANCEL TRAVEL
4. The **Airport Check** modal follows. It shows drugs carried, weapons carried and heat.
   - Clean (no contraband and heat ≤ 75): "you should get through", button BOARD.
   - Otherwise: BOARD ANYWAY.
   - Other buttons: Store in Vault (opens Storage) and Cancel.
5. **Boarding (`performFlightV22`, V4.1):**
   - If weapons were carried with the CARRY flag, `weaponTravelOutcomeV41` runs (§9.4).
   - Fare deducted, `stats.flights++`.
   - `s.v34.lastAirport = {hadDrugs, hadWeapons: weaponArrest, hadContraband: hadDrugs||weaponArrest, heatAtBoard}`.
   - City changes, then `nextDay("You land in X. Travel cost £Y. <risk line>", false)`.
6. **Drugs are not automatically seized at boarding.** The 92% auto-seizure in V2.2 is overridden. Seizure happens only through an airport arrest (§9).

### 3.4 Shipping
- **Hub:** shows counts of incoming shipments and those sent from the current city, plus EXPORT and IMPORT buttons.
- **Export (V4.1):**
  - Choose a destination tile, which must be another city and available under the access rule.
  - Ship from **carried** stock or the **current city's vault**.
  - Quantity is any amount up to what is held.
  - Cost = `ceil(5% × qty × current local price) + £200`.
  - The stock is removed straight away.
  - The record is `{id, from, to, source, items:{drug:qty}, value, cost, day}`.
- **Transit:** there is **no transit time and no risk**. The shipment simply waits at the destination.
- **Import:** only in the destination city, and only into **that city's vault**. It needs enough free vault capacity; otherwise "VAULT FULL". Each import is all-or-nothing per shipment.
- **Weapons cannot be shipped.**

### 3.5 Unlock All Cities purchase
- **Web:** `requestUnlockV95` shows a modal: "Unlock all 14 cities…" with **UNLOCK WEB PREVIEW** (free, local) and BACK TO FREE PLAY.
- **iOS:** posts `{productId}` to the native `noirPurchase` handler (§14).
- `NOIR_MARKET_UNLOCK_ALL_CITIES()` sets `allCitiesUnlocked=true` and `accessMode='full'`, then runs the pending callback (re-opens the start picker or Travel).
- `NOIR_MARKET_RESTORE_UNLOCK(bool)` sets or clears access.
- The unlock flag is stored **inside the save**, so a New Game resets it to false (see bugs).

---

## 4. Storage and vaults

### 4.1 Carry capacity
`totalSpace() = 20 + Σ capacity of owned storage items`. Only drugs use space. Weapons take no space.

| Item | Price | Capacity | Type |
|---|---|---|---|
| Bigger Backpack | £5,000 | +25 | person |
| Sports Bag | £20,000 | +50 | person |
| Trunk Upgrade | £100,000 | +100 | offsite |
| Warehouse | £1,000,000 | +500 | offsite |

- Each item can be bought once; its button is disabled when owned. The maximum is 695 units.
- "person" and "offsite" only differed in the old Surrender fight option, which V8.8 removed. Both now count as carried stock.
- The storage label shows the best item owned ("Pocket" if none).

### 4.2 City vaults (`dump()`, the "Storage" button)
- Each city has its own vault for drugs and weapons, and they share capacity:

| Level | Capacity | Upgrade cost |
|---|---|---|
| Basic | 100 | n/a |
| Secure | 250 | £100,000 |
| Fortress | 500 | £500,000 |

- Actions: STORE, STORE ALL and DUMP (destroy) for carried drugs and weapons. TAKE and TAKE ALL from the vault (pocket space applies to drugs).
- Vault stock is immune to raids, muggings and seizures, which only touch `s.inv` and `s.weapons`.
- Each city has a flavour line, e.g. "London stock stays in London…".

---

## 5. Finances

### 5.1 Bank (V4.1 `bank()`)
- Shows cash held and bank balance, with an amount input.
- Buttons: Deposit, Withdraw, Deposit All, Withdraw All and Pay General Debt (blank amount pays the full debt).
- **No bank interest.** Banked money is safe from muggings and fights.

### 5.2 Lenders (`lenders`, line 358)

| Lender | Max £ | Term (days) | Full-term interest |
|---|---|---|---|
| SPAMMER | 10,000 | 3 | 25% |
| TOMMY | 20,000 | 5 | 30% |
| SMUDGER | 50,000 | 5 | 50% |
| BAZZER | 75,000 | 3 | 50% |
| GRIFF | 100,000 | 3 | 70% |

- **Reputation scaling (`adjustedLenderMax`):** ×1.25 at rep ≥ 51, then a further ×1.5 at rep ≥ 81 (×1.875 total, so GRIFF lends up to £187,500).
- **Taking a loan (`chooseLoan`):** shows the bio, an amount input and BORROW MAXIMUM AMOUNT. Confirm with "ARE YOU SURE?". Asking above the max gives "Loan Declined".
  - Loan record: `{id, name, principal, interestRate, startDay, due: day+term, termDays}`.
  - **There is no limit on the number of concurrent loans**, including several from the same lender.
- **Settlement value (`loanPayoff`):**
  ```
  fullInterest = round(principal*rate)
  minInterest  = max(1, round(fullInterest*0.10))
  elapsed      = day - startDay
  interestDue  = elapsed<=0 ? minInterest : max(minInterest, round(fullInterest*elapsed/term))
  payoff       = principal + min(fullInterest, interestDue)
  ```
  The game says "Pay early to reduce the interest charged". Interest stops growing after the term; it is capped at full-term interest.
- **Pay specific loan:** must pay the full payoff. Gives +5 rep.
- **Pay general debt (V3.7):**
  - Paying ≥ the total clears all loans (+5 rep).
  - Otherwise each loan is cleared in list order where affordable. The remainder cuts the next loan's principal by `principal × amount/payoff` **and resets that loan's `startDay` to today** (see exploits).
- **PAY DEBT £X:** a button appended to *every* modal while debt > 0. It pays `min(cash, total)`.

### 5.3 Due dates (`handleDueLoans`, after every day's Continue)
- A loan is due when `due ≤ day`. The **DEBT DUE** modal lists each due loan with PAY OFF DEBT, plus "Do not pay".
- **Do not pay (`missDueLoans`)** applies to each due loan:
  - `principal = payoff × 1.25`, `interestRate = 0.25`, `termDays = 1`, `due = tomorrow`.
  - Player: health −15 (min 1), heat +10, rep −10. A further rep −25 if `netWorth < −0.5 × debt`.
  - Then `maybeFight()`.
  - Net effect: each missed day multiplies the debt by about 1.5625, not the 25% the text states.
- There is no repossession, no lender violence beyond the health hit, and no game over for debt.

---

## 6. Black Market (V3.8 `shop`)

### 6.1 Storage
See §4.1.

### 6.2 Weapons (`weapons`, line 361)
- You can buy any number of each weapon.
- **Buying** adds `ceil(heat/3)` to heat immediately.
- **Using** one in a fight adds its full heat (§10).
- Weapons resell at 50%.

| Weapon | Price £ | escape | win | Damage label | Heat | Single-use |
|---|---|---|---|---|---|---|
| Knife | 500 | .10 | .18 | Low | 2 | no |
| Baseball Bat | 1,000 | .15 | .22 | Low-Medium | 3 | no |
| Machete | 2,500 | .30 | .34 | Medium | 6 | no |
| Revolver | 7,500 | .35 | .40 | Medium | 10 | no |
| Handgun | 12,500 | .60 | .52 | Medium | 14 | no |
| Sawed-Off Shotgun | 25,000 | .65 | .62 | High | 18 | no |
| SMG | 50,000 | .72 | .70 | High | 22 | no |
| Assault Rifle | 100,000 | .78 | .78 | Very High | 35 | no |
| Machine Gun | 250,000 | .84 | .84 | Extreme | 45 | no |
| Grenade | 15,000 | .75 | .80 | Area Damage | 35 | **yes** |
| Molotov Cocktail | 5,000 | .55 | .58 | Fire Damage | 25 | **yes** |
| Rocket Launcher | 1,000,000 | .95 | .96 | Massive | 70 | no |

### 6.3 Burner Phone
- £500 each. One use each in Contacts (§7.2).

### 6.4 Recovery (hospital)

| Treatment | Price | Effect |
|---|---|---|
| +25% Health | £25,000 | +25 (cap 100) |
| +50% Health | £50,000 | +50 |
| Full Health (100%) | £100,000 | Set to 100 |

These options also appear inside fight result modals when health is below 100.

---

## 7. Hustle, Contacts and Stay Here

### 7.1 Hustle (V6.6)
Three informants are **re-rolled every time the modal opens**:

| Informant | Trust | Normal cost | "Desperate" cost (24% chance) | Cost if trust > 0.80 |
|---|---|---|---|---|
| Simon the Snitch | 42-82% | £80-180 | £25-75 | £260-520 |
| Lucy Loose Lips | 58-86% | £180-360 | £60-140 | £475-900 |
| Pistol Pete | 89-97% | £1,000-2,500 | never desperate | n/a |

Each card shows a mood line: "Desperate price today.", "Pushing their luck today." or "Standard street price."

**Resolution after paying** (`stats.informants++`):
1. Scam: Pete 2%, others 10%. Lose the money. Lucy −1 rep, Pete −2 rep.
2. Otherwise, with probability `trust`, a **real tip**: pick from that informant's three tips and call `applyPriceModifier`.
   - Simon: London Cocaine +28%/2 days; Cardiff Mushrooms +26%/2d; Manchester Ecstasy +22%/2d (+5 heat if you are in Manchester).
   - Lucy: Bristol Ecstasy −24%/2d; Leeds Pot −22%/1d; Birmingham Pot −26%/2d.
   - Pete: Liverpool Cocaine −30%/1d; Glasgow Kat +30%/2d (+8 heat if in Glasgow); Dublin Ecstasy +32%/2d.
   - **The price effect never happens.** See bug B3.
3. Otherwise 55% a false tip (two canned lines per informant), else a vague line.

The result shows in an "Informant Result" modal. A "Businesses: COMING SOON" card sits underneath.

### 7.2 Contacts (V3.8)
- The modal shows the burner-phone count. With 0 phones it offers "Open Black Market".
- "Use Burner Phone" consumes one phone and generates a **deal**:
  ```
  drug = random, city = random of 14 (lock not checked; flavour only)
  base = that city's current price (or rand(lo,hi))
  qty  = base>6000 ? 2-8 : base>2500 ? 5-18 : base>1000 ? 10-35 : 25-120
  buyUnit  = base × 55-82%;  saleUnit = max(buyUnit+1, base × 115-175%)
  buyCost  = buyUnit×qty; grossSale = saleUnit×qty; contactCut = 10% of gross
  projectedProfit = gross − buyCost − cut
  if projectedProfit < max(250, 8% of buyCost): saleUnit = buyUnit × 1.38 (recomputed)
  ```
- Choose TAKE DEAL (needs `cash ≥ buyCost`) or HANG UP (the phone is lost anyway). The deal resolves **instantly**, does not use a day and takes no storage.
- Outcome odds by reputation:

| Rep | success | bad | arrest | scam | jackpot |
|---|---|---|---|---|---|
| < 30 | 35% | 25% | 20% | 15% | 5% |
| 30-70 | 50% | 20% | 15% | 10% | 5% |
| > 70 | 65% | 15% | 10% | 5% | 5% |

- Outcomes:
  - **success:** receive `gross − cut`, +2 rep.
  - **bad:** receive `buyCost × rand(70,112)% × 0.9`, −1 rep if net is negative.
  - **arrest:** lose the buy-in, heat +12..28, −2 rep.
  - **scam:** lose the buy-in, −2 rep.
  - **jackpot:** receive `gross × rand(135,180)% × 0.9`, +4 rep.
- A SUCCESS or FAILURE banner shows the figures.
- Incoming "UNKNOWN NUMBER" calls (45-90 s timer, 65% chance, 3-5 day cooldown) exist in code but are **never scheduled** (dead; §16).

### 7.3 Stay Here
- From the main button or the Travel panel. Runs `stats.stays++` then `nextDay("You stay in X.", true)`.
- Same day-advance as travel, but the arrest context is `'stay'`. The result modal title is "Stay Here" and includes "Yesterday's Story".

---

## 8. Day advance, news and stories

### 8.1 `nextDay(base, isStay)` (V3.7 wrapped by V9.5)
1. Snapshot yesterday's rumour. `day++`. Recompute debt.
2. `heat = clamp(heat + rand(−8, +13), 0, 100)`. The mean is **+2.5/day**.
3. `rep +1`.
4. `genPrices(old)`: price walk, rumour resolution, events tick, elite supply, news (§2.1).
5. `newRumour()`: today's city story (§8.2).
6. `randomEvent(base)`: dangerous event, cash mugging, friend drop-by (§9.1).
7. `updateRankProgress()`. Debt recomputed.
8. If `day > maxDay (30)`, run `endGame()` (no save first).
9. `save()` and `draw()`.
10. Build the result modal: notice, rumour block, "Loan Status" debt reminder.
11. `maybeArrest(isStay ? 'stay' : 'travel')`. If there is an arrest, show the arrest modal (§9.2).
12. Otherwise show the result modal. **Continue** leads to `handleDueLoans()`, which runs the debt check or else `maybeFight()` (20%).

V9.5 then relabels the "Rumour Result" heading to "Yesterday's Story" and replaces TRUE/FALSE with UNCONFIRMED.

### 8.2 City stories / the truth deck (V9.5 `newRumour`)
- Each day one story is picked from 10 templates (no immediate repeat) for a random city (any of 14) and a random drug.
- Template types: 4 × shortage, 3 × collapse, 3 × crackdown.
- **Truth deck:** a shuffled deck of 5 `true` and 5 `false` cards. One card is popped per story and the deck reshuffles when empty, so exactly 50% are true per 10 stories.
- The story becomes the main-screen rumour line ("Stories are unreliable.") **and replaces the ticker text** for the day.
- Next day, if true (`applyRumourResult`):
  - **shortage:** price ×1.60-2.60, supply ×0.35, trend up.
  - **collapse:** price ×0.30-0.60, supply +100..400, trend down.
  - **crackdown:** heat +8..20, but **only if you are in that city**.
- **Templates:** for example, a hen party in {city} mistaking {drug} for table decorations (shortage), or a delivery driver taking crates of {drug} to the wrong Premier Inn (collapse). All 10 are listed at lines 31-42.

### 8.3 Price events and the news ticker (V3.3 `generateNewsEvent`)
Each day one of 20 events is applied to a random city through `applyPriceModifier`:
- **Immediate effect:** price ×(1+pct).
  - If pct > 0: supply ×45-78%, and heat +2..8 if it is your city.
  - Otherwise: supply ×122-172% + 30..180 (cap 1600), and heat −1..5 if your city.
- **Daily tick for `duration` days:** price ×(1 + pct×0.55). Supply ×0.72 (up events) or ×1.18 + 60 (down events). At most 12 active events.

| Event | Product | pct | Days |
|---|---|---|---|
| Rats in the Shrooms | Mushrooms | +35 | 2 |
| Warehouse Raid | Cocaine | +45 | 3 |
| Festival Sniffer Dog Sweep | Ecstasy | +30 | 2 |
| Dodgy Batch Warning | Heroin | +25 | 2 |
| Supplier Van Clamped | Pot | +20 | 1 |
| Customs Got Lucky | Cocaine | +50 | 3 |
| Mouldy Stash | Pot | +25 | 2 |
| Dealer Panic | Kat | +35 | 2 |
| Boat Delay | Cocaine | +40 | 2 |
| Loose Lips | Ecstasy | +25 | 2 |
| Overstocked Dealer | Pot | −25 | 1 |
| Festival Drop-Off | Ecstasy | −30 | 2 |
| Lucky Dock Arrival | Cocaine | −35 | 2 |
| Student Loan Day | Kat | −20 | 1 |
| Grow House Harvest | Pot | −30 | 3 |
| Quiet Police Week | Mushrooms | −20 | 2 |
| Bad Weather, Big Supply | Ecstasy | −25 | 1 |
| Supplier Clearance | Heroin | −30 | 2 |
| Wrong Delivery Address | Cocaine | −25 | 1 |
| Market Flood | Pot | −35 | 2 |

- The ticker text is the event headline plus two per-city joke headlines (5 per city, lines 2530-2543). It is stored in `s.economy.news`.
- **But `newRumour()` runs immediately afterwards and overwrites `s.economy.news`**, so the player never sees the price-event headlines or city headlines. The ticker shows only the day's city story; the events still move prices silently.
- The event text lands in `s.economy.history`, which is never displayed.
- **Ticker:** an upper-cased marquee. Duration is `clamp((trackWidth+textWidth)/38, 28, 72)` seconds.

### 8.4 Main-screen market-info line
`"<City>: <random cityText line>.<br><story> Stories are unreliable."`. `cityText` has 3 lines per city and is **re-rolled on every redraw**.

---

## 9. Random events, police and heat

### 9.1 `randomEvent` (every day advance, stay or travel)
The base `dangerousEventText()` makes one roll `r`:

| r range | Prob | Event | Effect |
|---|---|---|---|
| < .16 | 16% | Police raid | Each carried drug loses 25-100% (min 1 unit); each weapon type loses 10-70%; heat +18..35 |
| .16-.31 | 15% | Stash discovery | Each carried drug loses 10-50%; heat +5..18 |
| .31-.43 | 12% | Supplier arrested | Random drug, local: supply ×0.25, price ×1.6-3.0; heat +8..22 |
| .43-.55 | 12% | Customs seizure | Each carried drug loses 5-40%; heat +12..28 (happens even when staying) |
| .55-.68 | 13% | Festival demand spike | Local price ×1.8-3.6, supply ×0.5 |
| .68-.80 | 12% | Rodents in stashes | Local price ×2.2-4.8, supply ×0.35 |
| .80-.90 | 10% | Mugged | Lose 10-65% of cash (15-75% if rep ≤ 20), up to 35% of each drug, health −3..15 (min 5) |
| ≥ .90 | 10% | Quiet day | None |

Then:
- **`maybeCashMugging`:** if cash > £20,000, 12% chance (24% if rep ≤ 20) of losing 5-25% of cash.
- **Friend drop-by (V7.3):** 9% chance a mate gives 1-20 units of a random drug. They go to pockets first, then the city vault; any that fit nowhere are lost.

Simulated: **about 54% of days reduce carried drug stock.** Vaults are immune.

### 9.2 Arrest chance (`maybeArrest`, V7.3 → V4.1 → V3.4)
- **Stay:** no arrest if you are clean (no drugs or weapons carried) and heat ≤ 75. Otherwise:
  - Chance = `min(.55, .025 + (heat>75 ? (heat−75)/140 : 0) + (carrying ? .05 : 0))`.
  - Major chance = `.22 + heat/300 + (carrying ? .12 : 0)`.
  - Fine £500-5,000; jail 1-7 days.
- **Clean stop (V7.3):** a stay arrest while clean is flagged `cleanStopV73` (no fine, no jail). The V7.3 modal that should show is dead; see bug B2.
- **Travel (airport):** eligible only if the boarding record had contraband or heat at boarding > 75.
  - Chance = `.24` (contraband) or `.16`, then +.10 for drugs, +.16 for weapons, + `min(.34,(heat−75)/70)` if heat > 75. Capped at .82.
  - Major if weapons were carried, or heat > 88, or (drugs and a 45% roll).
  - Flagged `airport:true`.
- **Forced weapon arrest:** if the V4.1 weapon-travel roll returned "arrest", the arrest is forced (major, jail 1-7, fine £1,000-6,500).

### 9.3 Arrest modal (V8.8 `showArrestModal`)
- `stats.arrests++`.
- **Bribe offered?** Only if you carry contraband. Chance = `clamp(.28 + rep/300 − .12·airport + .06·major + .06·(heat>75), .18, .72)`.
- **Not offered:** title is the base title, "The officer is not interested in talking", and a single **Take Penalty** button.
- **Offered:** title "THE OFFICER LEAVES A GAP IN THE CONVERSATION", with PAY BRIBE (disabled if unaffordable) and TAKE THE CHARGE.
  - Bribe cost = `clamp(900 + major·jail·1250 + airport·3500 + drugUnits·45 + weapons·700 + heat·35, 500, 50000)`.
  - Success chance: rep < 20 → .18, < 50 → .34, < 80 → .58, else .74. Then subtract `min(heat/1000, .12)`, .08 if major, .12 if airport, .05 if weapons. Clamp .08-.88. The percentage is shown.
  - **Success:** pay the bribe, heat −3, rep +1, keep everything.
  - **Failure:** **no money taken**; all carried drugs and weapons seized; the original jail (day += jail) or fine applies; heat +10; rep −3.
- **Take penalty / charge (V3.7 via V4.2):**
  - rep −15. If airport, seize all carried drugs and weapons.
  - If major: `day += jail`, `stats.jailDays += jail`, cash −£500-5,000.
  - Otherwise: fine `min(cash, arrest.fine || rand(500,5000))`.
  - "Police Outcome" modal; Continue leads to `handleDueLoans`.
- **GODMODE:** a player name of exactly `GODMODE` makes bribes free and always affordable.

### 9.4 Weapon travel (V4.1, only if CARRY THEM was chosen)
- **Route type:** "airport" if the countries differ (UK / Wales / Scotland / Northern Ireland / Ireland), else "road/train".
- **Weapon risk score** = Σ per weapon of `heat + min(35, 5·log10(price))`.
- **Risk** = `(.34 airport | .14 road) + .045·qty + score/420 + (heat>75 ? min(.22,(heat−75)/120) : 0)`. Clamped to [.36 | .18, .88].
- If triggered, severity = `rand + min(.35, score/260) + (qty>2 ? .12 : 0) + (airport ? .16 : 0)`:
  - **> .98:** forced major arrest.
  - **> .56:** fine £500-4,500 and heat +4..12.
  - **Otherwise:** all weapons seized and heat +6..16.

### 9.5 Heat summary
- **Rises with:**
  - the daily drift (+2.5 average)
  - buying a weapon (ceil(heat/3))
  - using a weapon in a fight (its full heat)
  - raids, customs and supplier arrests
  - true crackdown stories, and up-events in your city
  - missed debt (+10)
  - failed bribes (+10)
  - contact-deal arrests
  - weapon travel stops
- **Falls with:** the daily drift (down to −8), successful bribes (−3) and down-events in your city (−1..5).
- **Thresholds:** heat > 75 unlocks clean-pocket stops; > 88 makes airport arrests major. The display classes are low < 8, mid < 25, high otherwise.

---

## 10. Fights, health and death

- **Trigger:** `maybeFight()` has a 20% chance on every `handleDueLoans` pass with no due loans, and runs after every missed-debt choice.
- **Attackers:**

| Attacker | Weight | Damage | Loot % | Max rounds |
|---|---|---|---|---|
| single addict | .36 | 2 | 25% | 1 |
| small group of lads | .31 | 10 | 35% | 2 |
| small gang | .22 | 20 | 50% | 3 |
| large gang | .11 | 50 | 75% | 4 |

- **Modal "Trouble" (V8.8):** shows health and "Threat round n of up to N", with RUN and FIGHT buttons. FIGHT automatically uses the best weapon (highest `win`). The × is hidden and Escape is blocked. Surrender was removed.
- **RUN:**
  - Success chance = `min(.98, .50 + bestWeapon.escape)`.
  - **Success:** heat + rand(1,6) + weapon heat; single-use weapons are consumed even when running.
  - **Fail:** health −rand(max(2,⌊dmg/2⌋), max(3,dmg)) (min 1), cash −rand(5, loot%)%.
  - Running never kills you.
- **FIGHT:**
  - Win chance = weapon ? (single addict ? .75 : min(.96, .10 + win)) : .25.
  - **Win:** heat + rand(5,15) + weapon heat; consume single-use; `fightsWon++`.
  - **Lose:**
    - Damage reduction `r = min(.85, weapon.escape)`.
    - Health −rand(max(2,⌊dmg(1−r)/2⌋), max(3, round(dmg(1−r)))); health can reach 0.
    - Consume single-use.
    - If health ≤ 0: **death**, then `endGame()`.
    - Otherwise, if round < max and a 65% roll succeeds, go to the next round ("Next Move"); else "You break away".
- Result modals offer hospital treatments.
- **Health floors elsewhere:** debt beating min 1, street mugging min 5. **Death is only possible in a lost FIGHT.**
- **Health colours:** ≤ 30 bad (red), ≤ 85 warn, otherwise good (green).

---

## 11. Reputation and rank

### 11.1 Reputation (0-100, start 50)

| Change | Source |
|---|---|
| +1 | each day; each buy transaction; each sell transaction; bribe success |
| +2 | contact success |
| +4 | contact jackpot |
| +5 | paying off a loan / clearing debt |
| −1 | bad contact deal (net negative); Lucy scam |
| −2 | contact arrest or scam; Pete scam |
| −3 | failed bribe |
| −10 | missed debt (−25 more if deeply underwater) |
| −15 | taking a police penalty |

**Effects:**
- Lender limits (≥ 51, ≥ 81).
- Elite supply (≥ 81).
- Mugging severity (≤ 20).
- Contact odds (< 30, > 70).
- Bribe offer and success.

### 11.2 Rank
Rank is based on **net worth** = cash + bank + carried stock at local prices + **all vault stock at each city's price** + vaulted weapons at 50% − debt.

| Rank | Net worth ≥ |
|---|---|
| Wannabe | £0 |
| Street Dealer | £10,000 |
| Hustler | £50,000 |
| Kingpin | £500,000 |
| Legend | £1,000,000 |
| Drug Lord | £10,000,000 |

- **Days Held** (`updateRankProgress`, once per day advance):
  - **Promotion:** you must qualify for a higher rank for **5 consecutive day advances**. The display shows "n/5 to <Rank>".
  - **Demotion:** immediate, also enforced on every `rank()` call.
  - At a steady rank the counter climbs to 5/5.
- `stats.bestRank` and `stats.bestNet` track the session best.

---

## 12. End of game and scoring

- The game ends when `day` passes 30 (after the 30th day advance), or on death.
- **`endGame()` score** = cash + bank + carried stock × current local price − debt. **This excludes vault stock, shipments and weapons**, unlike rank net worth.
- The modal "Game Over" shows "Final net worth £X" and the rank, with a **New Game** button. That button starts in London, Free Play, with no How-to-Play.
- **There is no high-score table or leaderboard.** Only `stats.bestNet` and `stats.bestRank` exist inside the current save, and both reset on New Game.

---

## 13. Save system, settings, menu, avatars, music

### 13.1 localStorage keys

| Key | Purpose |
|---|---|
| `noir_market_v9_7` | Active save (JSON of `s`). Written by `save()`. |
| `noir_market_v9_6 … v9_0, v8_9 … v1_2, v13, v12, v9, v6, v5, v4` | Migration sources, read in that order by `loadGameV93`. The first one that parses wins. |
| `noir_market_sound` | 'on'/'off' sound effects |
| `noir_market_music` | 'on'/'off' (legacy mirror) |
| `noir_market_v9_7_music_preference` | Music preference (falls back to `…v9_6_music_preference`) |
| `noir_market_player_name` | Remembered name (max 24 characters) |

Save state is written after almost every action. The main extra namespaces in `s` are: `economy{cities{prices,supply,trends,crashes},news,history}`, `v33.priceEvents`, `v34.lastAirport`, `v37` (cash-prompt fields, unused), `v38` (burner phones), `v41.carryWeaponsOnNextTravel`, `v42.lastArrestDay`, `v95.storyTruthDeck`, `rankState`, `vaults`, `weaponVaults`, `vaultLevels`, `shipments`, `loans`, `stats`, `meta`.

### 13.2 Stats (Menu → Stats)
The screen shows:
- Player, current rank, best rank, days held, reputation, days survived, net worth, best net worth, city, storage type.
- Shipments exported/imported, flights, stays, arrests, jail days, bribes, informants.
- Fights won/lost, times mugged, loans taken, drugs bought/sold (units), largest single trade, heat.

Hidden counters (not shown): `vaultSales`, `burnerPhonesBought/Used`, `contactDeals`, `bribeAttempts/Accepted/Rejected`, `friendDropBys`, `cleanPoliceStops`.

### 13.3 Menu (☰, V9.5 on top of V9.1)
- Player name input + SAVE NAME.
- **Player avatar:** Male or Female silhouette (stored in `s.avatar`; shown **only** in this menu).
- UNLOCK ALL CITIES (if locked).
- SOUNDS: ON/OFF, MUSIC: ON/OFF.
- Instructions, Stats, New Game (asks to confirm: "Your current save will be lost." Cancel/New Game; then How to Play).

### 13.4 Audio
- **Sound effects:** WebAudio oscillator blips.
  - positive: 660 Hz then 990 Hz
  - negative: 170 Hz then 105 Hz sawtooth
  - travel: 740 Hz then 554 Hz
- **Haptics:** `navigator.vibrate` [18] or [45,25,45].
- **Music:** `assets/game-music.mp3`, looped, `preload=none`.
  - Starts on the ENTER tap (or the first touch/click on the title) at **100% volume**.
  - When PLAY is pressed in the start picker, it fades to **50%** over 15 × 80 ms.
  - Pauses on `visibilitychange` hidden and resumes when visible.
  - The old synth-music fallback is dead.
- **Toasts:** upper-case, top-centre, 2.2 s, ok (green) or bad (red).

---

## 14. iOS shell

- **App:** SwiftUI + `WKWebView`, iOS 16+, portrait, iPhone only, dark mode. Bundle `games.redhead.noirmarket`.
- **Bundled files:** `npm run ios:prepare` copies `game.js`, `index.html`, `styles.css`, the logo and the MP3 into `ios/Generated/Web`. The WebView loads `index.html` from the bundle, and navigation outside the bundle is cancelled.
- **Packaging patches** (`scripts/prepare-ios.mjs`):
  - `ensureV95` forces `state.allCitiesUnlocked = window.__NOIR_IOS_ENTITLED === true` (and `accessMode='free'` when false). The native app is the source of truth.
  - `requestUnlockV95` always posts to `window.webkit.messageHandlers.noirPurchase`. On failure it shows "Purchase unavailable". The web-preview unlock is removed, and the build fails if it leaks.
  - Service-worker registration is disabled.
- **StoreKit 2 (`CityStore`):**
  - Product ID **`games.redhead.noirmarket.unlockallcities`**, non-consumable.
  - Price comes from StoreKit's `displayPrice` and is not hard-coded. `ios/RELEASE.md` records an agreed **£1.99 GBP** price, not yet set in App Store Connect.
  - Entitled = any verified, non-revoked `currentEntitlements` transaction for that product.
  - `Transaction.updates` is observed. Purchase handles verified, pending, cancelled and unknown outcomes with user messages.
  - Restore uses `AppStore.sync()`.
- **Bridge:**
  - At document start the app injects `window.__NOIR_IOS_ENTITLED = false;`.
  - **JS → native:** `webkit.messageHandlers.noirPurchase.postMessage({productId})`. Native accepts it only from the bundled main frame with a matching ID.
    - If already unlocked, native calls `syncEntitlement(true, completeStart:true)`.
    - Otherwise it shows `PurchaseView`: "Unlock All Cities". "One purchase unlocks all 14 cities…"; buttons "Unlock for <price>", "Restore purchases" and Close. If the product is unavailable: "…You can still play the three free cities." with "Try again".
  - **Native → JS:**
    - `window.__NOIR_IOS_ENTITLED=<bool>;` followed by either `window.NOIR_MARKET_UNLOCK_ALL_CITIES();` (after a purchase or restore that unlocked)
    - or `window.NOIR_MARKET_RESTORE_UNLOCK(<bool>);` (on page load `didFinish`, and whenever the app becomes active).
- **Native chrome:** a bar under the WebView with "Restore purchases" and "Privacy & support". The sheet covers a fictional-game disclaimer, data stored on-device, no ads, analytics or accounts, the support email `ryanmullenuk@yahoo.co.uk`, and links to `redhead.games/support.html` and `/privacy.html`.
- If the web content process crashes, the WebView reloads.

---

## 15. UI flow and screens

### 15.1 Boot sequence
1. **Pre-intro.** A black full-screen overlay shows `assets/redhead-games-logo.png` (Redhead Games).
   - `initRendererV93` reveals the title after **1,250 ms**. An inline safeguard does it at 2,200 ms if the script fails.
   - The logo fades out over 620 ms.
2. **Splash / title.**
   - Background `#0d0c12`, with a canvas of "depth snow" (52-92 flakes, scaled by area). The flakes settle into a bottom pile up to 28% of the screen height, and the effect respects reduced motion.
   - Stacked title "NOIR / MARKET".
   - Loader button: LOADING (disabled), then **ENTER**.
   - Tapping ENTER starts the music, then after 240 ms shows How to Play and hides the splash (the snow stops).
3. **How to Play (V9.5).**
   - Copy: "You start with £1,000, no debt and questionable judgement." "News stories may point towards tomorrow's opportunity. Half are useful. Half are complete nonsense." Disclaimer: "for entertainment purposes only".
   - Buttons: **FREE PLAY**, **UNLOCK ALL CITIES** (or PLAY ALL CITIES once unlocked) and **INSTRUCTIONS**.
   - This screen appears on **every launch**, including when resuming a save.
4. **Instructions (V5.0).** Sections: Market, Storage/Vault, Travel, Shipping/Export, Finances, Black Market, Hustle, Contacts, Loans, News/Rumours, Reputation/Rank, Heat, and a Tip. Ends with "Back to How to Play" or "Back to Menu".
5. **City select (V9.5).**
   - "Free Play includes London, Manchester and Birmingham." or "Choose any starting city."
   - City grid, BACK, and PLAY FREE / PLAY FULL GAME.
   - PLAY sets the city and notice, saves, closes all overlays, and fades the music to 50%.
6. **Main screen**, top to bottom:
   - News ticker ("NEWS").
   - Top bar: ☰ menu, "NOIR MARKET", tagline, DAY n/30.
   - Stat cards: Cash, Finances (bank), Debt (red), Health.
   - Location card: "City Region", cityText and story.
   - Information (latest notice).
   - The Market: Drug / Qty / Price / ↑↓. Rows are clickable and open Buy.
   - Storage n/N: carried drugs with value, then weapons held.
   - Action grid: Buy, Sell, Storage, Finances, Travel & Shipping, Black Market, Hustle, Contacts, Stay Here.
   - Status: health bar, Location, Rank, Days Held, Reputation, Storage, Heat.

### 15.2 Modal screens
All modals share one `<dialog id="modal">`, styled full-screen, with a × (close without side effects) and an appended "PAY DEBT £X" while in debt.

| Screen | Purpose |
|---|---|
| How to Play | Free / Unlock / Instructions |
| Instructions | Rules text |
| Free Play / Full Game | Start-city picker |
| Unlock All Cities | Web preview purchase / Purchase unavailable (iOS) |
| Buy | Commodity tiles |
| Sell | Pocket, safe, weapons |
| Storage | Vault and upgrades |
| Finances | Bank, loans and lenders |
| [Lender name] | Loan terms |
| Loan Declined | Request above lender max |
| Debt Payment | Result of a debt payment |
| DEBT DUE | Pay or "Do not pay" |
| Travel & Shipping | Travel / Shipping tabs, with Export and Import sub-panels |
| YOU ARE CARRYING WEAPONS | Carry / stash / ditch / cancel |
| Airport Check | Board / store / cancel |
| Travel Result / Stay Here | Day summary, story, Loan Status |
| Police Stop variants | "THE OFFICER LEAVES A GAP IN THE CONVERSATION", Police Bribe (SUCCESS/FAILURE), Police Outcome |
| Trouble | Fight choice |
| Fight Outcome / Run Outcome | Fight result |
| Hospital Treatment | Health purchase |
| Game Over | Final score |
| Black Market | Storage, weapons, burner phone, recovery |
| Hustle | Informants |
| Informant Result | Tip outcome |
| Contacts | Burner phones |
| Contact Deal | Deal offer |
| Contact Deal Result | Deal outcome |
| Menu | Name, avatar, settings, links |
| Stats | Lifetime counters |
| New Game | Confirmation |

### 15.3 Visual style
- **Colours:** background `#050505`, panels `#111` and `#181818`, line `#303030`, text `#f2f2f2`, muted `#9a9a9a`, green `#43d736` (buy/up/money), red `#ff5148` (sell/down/debt), amber `#d8b85b` (locked).
- **Type and layout:** system sans; title in Arial Black. Square buttons with upper-case labels and 1.2px letter-spacing. Layout max width 920px, collapsing to one column under 560px.

---

## 16. Bugs, dead code, inconsistencies and balance problems

### 16.1 Confirmed bugs (reproduced in jsdom unless noted)
- **B1. Every reload wipes the current V9.7 save (critical).**
  - **Cause:** `installV95` runs first on `DOMContentLoaded`, while `s` is still `undefined`. Its `initV95()` calls `persistV95()`, then the V9.1 `save()`, which writes `localStorage.noir_market_v9_7 = JSON.stringify(undefined)`, i.e. the string "undefined".
  - **Effect:** `loadGameV93` then fails to parse it and falls back to an *older* key, or starts a fresh game. Verified: save cash £77,777 on day 12, reload, and you are back on day 1 with £1,000.
  - The migration test passes only because it seeds `noir_market_v8_8`. This also affects iOS.
  - **Fix:** guard `persistV95`/`save` against `!s`, or install V9.5 after load.
- **B2. A "clean" police stop fines you.**
  - V8.8 `showArrestModal` replaced V7.3's clean-stop handler without delegating to it.
  - A clean stop (heat > 75, nothing carried) gets "Take Penalty". V3.7 then computes `fine = min(cash, arrest.fine || rand(500,5000))` with `arrest.fine = 0`, so it charges £500-5,000 and −15 rep.
  - Verified: £10,000 → £7,551, rep 50 → 35.
  - The intended outcome was no fine and +10 heat.
- **B3. Hustle informant tips never move prices.**
  - V6.6 calls `applyPriceModifier`, which is a private function inside the V3.3 closure (`typeof applyPriceModifier === 'undefined'` globally). The ReferenceError is swallowed by `try{}catch{}`.
  - Paid "accurate" tips are pure flavour text.
- **B4. The price-event and city headline ticker is never shown.** `newRumour()` (V9.5) overwrites `s.economy.news` right after `generateNewsEvent()`. The 20 price events still change prices invisibly.
- **B5. The rumour block is duplicated in arrest modals.** `nextDay` passes `body` (which already contains the rumour block) *and* `rumourBlock` to `showArrestModal`, and V8.8 appends both.
- **B6. Story truth leaks after travel.** `rumourTravelBlockV37` prints lines like "The cocaine rumour was true/false…". V9.5 only masks the `<strong>TRUE/FALSE</strong>` label, defeating the "hidden accuracy" design.
- **B7. RUN success counts as both a won and a lost fight** (`fightsWon++` and `fightsLost++`, lines 596-598).
- **B8. Starting-city choice on resume teleports the player.**
  - How to Play and the city picker show on every launch, even with a loaded save.
  - PLAY moves the existing character to the chosen city for free, with no day passing.
  - It also rewrites the notice to "You start in X with £1,000 cash…".
- **B9. New Game drops the city unlock.** `baseState()` → `ensureV95` sets `allCitiesUnlocked=false`.
  - On the web, the preview unlock is lost.
  - On iOS, a paying user sees "UNLOCK ALL CITIES" until a native re-sync (it works after one tap, but looks like an upsell).
  - The entitlement should live outside the save.
- **B10. Possible softlock (code reading, not reproduced).**
  - During a forced fight, the appended PAY DEBT button stays clickable.
  - With cash 0 it opens a "Debt Payment" modal whose × is still blocked by the leftover `data-forced-choice="fight"` guard, leaving only PAY DEBT, which reopens the same modal.
  - With cash > 0 it closes the fight entirely, which is an escape.
- **B11. Death and end-game don't save.**
  - `endGame()` is reached without `save()` (both from `nextDay` at day 31 and from death). Reloading restores the pre-death or day-30 state.
  - The Game Over modal's × also lets you keep trading on day 31.
- **B12. Jail can push `day` past 30 without ending the game** until the next day advance. Jail days also skip that day's processing (prices, events and loan checks are not re-run per day).
- **B13. Missed-debt growth contradicts its text.** The text says "+25%". It actually applies `payoff×1.25` and then sets a 25% one-day interest rate, so about ×1.56 per missed day.
- **B14. Misleading UI text:**
  - Instructions say "shipments carry cost and risk", but shipping has **no risk**.
  - Travel is always called a "flight", yet V4.1 treats same-country trips as road/train.
- **B15. Hard-coded copy.** `index.html` hard-codes `/30` and "You start in London…". `cityText()` is re-rolled on every redraw, so the location line flickers between descriptions after any action.

### 16.2 Dead or unreachable code
These features are never reached because their boot or draw hooks are filtered or replaced:
- V3.3 timed **"INFORMANT OFFER"** pop-ups (PAY / SLAP AWAY, 4 time windows).
- V3.8 incoming **"UNKNOWN NUMBER"** contact calls.
- V3.7 **"Deposit Warning"** cash prompt (cash > £15k, ignore for 10 days).
- 15-second news `setInterval`.
- `initialiseNoirMarket`, `setupTilt`, splash dust and snow, the V2.7/V3.3 splash loaders, and synth music.
- V6.6 14-city selector with RANDOM CITY.
- V4.0 Businesses text (Deliverude, Uber Yeats, Karen & Sharon).
- V4.2 bribe system and V7.3 clean-stop modal.
- `showShadyChoice`, `showLoanIntro`, `checkLoans` (empty), `particles()` (no-op).
- `reputationStopV74` (never set).
- About 30 `vXXSelfTest` console loggers.
- About 20 duplicated `save`/`load`/`baseState` wrappers with their own `FALLBACK_KEYS` lists. V7.3's list even skips `v3_4`-`v3_9`; that list is harmless now because V9.3 owns loading.
- The "person/offsite" storage distinction (meaningful only for the removed Surrender option).
- The avatar (cosmetic; shown nowhere outside the Menu).
- `window.noirNativePurchase` hook.
- `s.economy.history`.
- The legacy `window.addEventListener('load', register sw)` at line 775 is swallowed. V9.3 re-registers the service worker, so the PWA still works.
- `styles.css` carries about 760 `!important` rules and keyframes for about 20 obsolete versions.

### 16.3 Exploits
- **E1. Modal × escapes consequences.**
  - Closing **DEBT DUE** skips the miss penalty; the loan is chased again only after the next day.
  - Closing any **police** modal skips the arrest entirely (only fights are guarded).
  - Escape does the same (V3.4 cancel handler).
- **E2. Unlimited stacked loans.** No cap on concurrent loans; GRIFF can be borrowed from repeatedly.
- **E3. Interest reset.** A partial "Pay General Debt" of £1 resets that loan's `startDay`, dropping accrued interest back to the 10% minimum.
- **E4. Contact deals are a positive-EV money pump.**
  - Expected return ≈ +26% of buy-in at mid rep and ≈ +50% at rep > 70, plus +EV reputation.
  - Instant, no day cost, no storage, unlimited at £500 per phone.
  - Combined with E2/E3 (borrow, flip, repay same day at a 10% minimum-interest charge), money is effectively unbounded.
- **E5. Reputation farming.** +1 rep per buy/sell *transaction*, so buying 1 unit repeatedly reaches 100 rep in minutes. That unlocks ×1.875 lender limits, elite supply and the best contact and bribe odds.
- **E6. Hustle re-roll.** Informant price and trust re-roll on every open; reopen until a cheap, high-trust "desperate" offer appears. This is moot while B3 stands.
- **E7. Reload to undo bad outcomes.** Death and day-31 are not saved (B11). B1 currently masks this by destroying saves anyway.
- **E8. GODMODE player name** gives free bribes (debug cheat left in production).
- **E9. Free web unlock.** "UNLOCK WEB PREVIEW" grants all cities at no cost on redhead.games. It is stripped for iOS.

### 16.4 Balance problems
- **Daily attrition is brutal and unavoidable for carried stock.** Simulated: 54% of day advances shave carried drugs (raid 25-100%, stash 10-50%, "customs" 5-40% even when *staying*, plus mugging). Combined with 20% fight odds per day and +2.5 average heat per day, the only viable play is vault everything and ship. Shipping is risk-free at 5% + £200.
- **No per-city price identity.** All 14 cities share identical ranges, so the £1.99 unlock adds routes but no distinct markets. Cities are flavour plus independent random walks.
- **Score and rank disagree.** Rank counts vault stock; the final score does not. Players who vault (the optimal play) see their final score collapse.
- **Starting cash is mismatched to costs.** £1,000 start versus hospital at £25k-100k and a Backpack at £5k. Large-gang fights deal up to 50 health per round.
- **Bribes are often worse than the charge.** A failed bribe seizes everything (non-airport), while "Take the charge" on a minor non-airport stop only fines. Bribe success at rep < 50 is ≤ 34%.
- **Heat creeps upward** (+2.5/day average) with few ways to bring it down. Heat > 75 makes even clean travel risky.
- **Reputation:** the passive +1/day plus +1 per transaction makes the high-rep tiers trivial (see E5).
- **Sell is all-or-nothing** while Buy has quantity controls. Selling 50+ units always triggers the large-sale crash, so you cannot drip-sell to avoid it.
- **Free Play hint mismatches.** Informant tips, stories and contact deals frequently reference locked cities (e.g. all three of Pete's tips), so they are useless to Free Play users.
- **Price drift.** Long-run equilibrium sits about 10% above the range midpoint because the multiplier averages 1.03.
- **Unpruned fare cache.** `travelFares` grows by every viewed day:from:to and is never pruned (save-size creep).
