# Noir Market

The Noir Market browser edition is retired. The public index is an information page; support.html and privacy.html remain available. The iOS game shell is preserved in ios/game-shell.html.template and packaged by scripts/prepare-ios.mjs.

## Run locally

Requirements: Node.js 22+ and Python 3.

```bash
npm ci
npm run serve
```

Open `http://localhost:4173/index.html` to preview the retirement page.

## Regression checks

```bash
npm run check
```

This validates JavaScript syntax, release metadata, packaged assets, the runtime-size budget, title-screen startup, the intro/city flow, buy and travel screens, and migration of older saves. GitHub Actions runs the same checks for every push to `main` and every pull request.

## Runtime structure

- `ios/game-shell.html.template` and `styles.css` contain the native app shell and responsive UI.
- `game.js` contains game state, features, save migrations and the single active V9.7 renderer.
- `sw.js` retires existing browser installations by clearing only Noir Market app caches and unregistering itself. Saved game data is preserved.
- `manifest.json` and the icon files define the installable PWA.
- Browser saves use `localStorage`. V9.7 writes `noir_market_v9_7` and migrates earlier supported keys.

## iOS preparation

Native SwiftUI/WebKit source and StoreKit 2 purchase handling are in `ios/`.
Run `npm run ios:prepare` to bundle the game offline. See [ios/RELEASE.md](ios/RELEASE.md)
for Mac setup, signing, remaining release blockers and the native test matrix.
This is preparation source, not a signed or submitted App Store build.

On a Mac with Node.js 22+, Xcode 26+ and XcodeGen installed, run
`npm run ios:setup`. It installs dependencies, checks the game, packages the
offline resources, generates the project and opens it in Xcode.

The **iOS simulator checks** GitHub Actions workflow builds with Xcode 26.3 and
runs native startup/free-play and privacy-sheet UI tests. Its
**NoirMarket-Xcode-project** artifact contains ready-to-open sources and bundled
game files. A 1024px opaque app icon uses the existing plain white title on black.
The simulator job does not sign, archive, upload or certify the app for release.

## Maintenance commands

```bash
npm run clean:legacy
npm run check
```

Before a release, align the version in `package.json`, `ios/game-shell.html.template`, `manifest.json`, the metadata controller in `game.js`, and the regression assertions. Never remove an older save key from the migration list without an explicit data-retention decision.
