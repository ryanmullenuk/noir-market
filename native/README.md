# Noir Market (native iOS)

A native SwiftUI rebuild of Noir Market for iPhone. No web view, no third-party code.

## Open and run

Open `NoirMarket.xcodeproj` in Xcode 27, pick an iPhone simulator, and press Run.
The project uses folder-synchronised groups, so new Swift files dropped into
`NoirMarket/` are picked up automatically. No XcodeGen is needed.

- Bundle ID: `games.redhead.noirmarket`
- In-app purchase: `games.redhead.noirmarket.unlockallcities` (non-consumable).
  `Products.storekit` is wired into the shared scheme, so purchases work in the
  simulator without App Store Connect.
- Minimum iOS: 17.0. Portrait, iPhone only.

## Layout

| Folder | What lives there |
|---|---|
| `NoirMarket/Model` | Static data (`Catalog`, `Press`), `GameState`, utilities. No UI imports. |
| `NoirMarket/Engine` | All rules, as pure functions over `GameState`: trading, finance, day cycle, encounters. Deterministic for a seed. |
| `NoirMarket/App` | App entry, `GameStore` (save/load/records), audio and haptics. |
| `NoirMarket/Store` | StoreKit 2 unlock. The entitlement lives with StoreKit, never inside the save. |
| `NoirMarket/UI` | SwiftUI screens and the noir theme. |
| `NoirMarketTests` | Engine unit tests and a balance check (Swift Testing). |
| `NoirMarketUITests` | A playthrough that taps through start, trade, travel and a week of nights. |
| `Tools/BalanceSim` | Fast command-line balance harness (see below). |
| `Tools/shot.sh` | Relaunches the simulator app with debug arguments and saves a screenshot. |

## Tests

```bash
xcodebuild -project NoirMarket.xcodeproj -scheme NoirMarket -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## Balance harness

Runs thousands of bot games in seconds and prints the spread of final net worth:

```bash
swiftc -O NoirMarket/Model/*.swift NoirMarket/Engine/*.swift Tools/BalanceSim/main.swift -o /tmp/noir-sim && /tmp/noir-sim
```

## Debug launch arguments (Debug builds only)

`-demo` starts a London game. `-days N` plays N nights. `-holding` buys some
stock. `-encounter police|trouble|collector` forces an encounter. `-panel
travel|stash|money|shop|street|settings` opens a panel. `-trade N` opens the
trade sheet for good N. `-keepOverlay` leaves the last morning paper up.
`-unlockAll` grants the city unlock. `-resetSave` deletes the save on launch.
`-musicOff` mutes the music.

## What changed from the web V9.7

See `../NATIVE_REBUILD.md`.
