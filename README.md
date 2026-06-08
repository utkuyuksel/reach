# REACH

> Working title. **REACH** is a calm, language-independent number puzzle for iOS & Android, built in Flutter.

Drag across orthogonally-adjacent tiles whose values add up **exactly** to the target — the traced path clears. Clear the whole board to win. There is no fail state: any valid clear is accepted, undo is unlimited, and you are only ever "stuck" when no clearing path remains anywhere on the board (peg-solitaire style), which the game detects and surfaces gently. Two modes — a deterministic **Daily Challenge** with streaks and spoiler-free sharing, and endless **Zen** with a gentle difficulty ramp. Boards earn **stars** for efficiency (fewer wrong traces) and a separate **clean** badge for finishing without hints.

Every puzzle is **guaranteed solvable by construction** (see [The engine](#the-engine)).

---

## Quick start

```bash
flutter pub get
flutter run            # runs with no-op dev ad/IAP/sound stubs — no accounts needed
```

The game runs fully without any AdMob or store account: ads, purchases, and sound default to no-op dev stubs (rewarded "ads" grant coins instantly; "buy" flips the Premium flag / credits coins). To exercise the real `google_mobile_ads` / `in_app_purchase` / `audioplayers` integrations on a configured build:

```bash
flutter run --dart-define=REACH_REAL_SERVICES=true
```

### Tests

```bash
flutter test                                  # everything (engine + state + widget)
flutter test test/engine                      # engine only
flutter test test/engine/generator_stress_test.dart   # the solvable-generator stress test
```

The headline guarantee — **every generated puzzle is solvable and non-degenerate** — is enforced by `test/engine/generator_stress_test.dart`, which generates **15,000 puzzles per difficulty** across all shipped configs (the 3 named tiers + every Zen-ladder rung), and for each one independently verifies non-degeneracy, that the solution groups cover every cell exactly once as connected target-summing paths, **and replays them to a win through the real `GameState.submitPath` clear mechanic**. It must pass with zero failures.

> Note: in this environment `flutter analyze` may crash inside its analysis-server wrapper. Use **`dart analyze lib test`** instead — it is the working equivalent and reports clean.

---

## Architecture

Pure-Dart game logic is fully separated from Flutter UI so it is unit-testable and the daily seed is reproducible.

```
lib/
  config/            app identity + ad/IAP/economy config in single files (see "Renaming")
  engine/            PURE DART — no Flutter imports
    models/          Tile, Grid, Puzzle, GameState
    rng.dart         deterministic splitmix64 PRNG (cross-device reproducible)
    difficulty.dart  named tiers + Zen ramp ladder (size / group size / decoy band)
    generator.dart   seedable, solvable-by-construction generation (+ generateTuned)
    solver.dart      clear check, partition search, dead-end (hasMove) + decoy metrics
  services/          Storage / Ad / Purchase / Analytics / RemoteConfig / Sound behind
                     interfaces, each with a no-op (dev) impl + a real impl
  game/
    state/           Riverpod controllers (game, wallet, settings, daily, zen, entitlement)
    theme/           palettes (free + coin/Premium cosmetic themes) + bundled fonts
    widgets/         tiles, board (drag-trace), target, controls, coin chip, win sheet
    screens/         home, game, settings, shop
  util/              date helpers
  main.dart          bootstraps services and wires Riverpod overrides
test/
  engine/            generator stress test, solver, GameState, generator determinism
  state/             game controller, shop / wallet
  services/          persisted-model round-trips
  widget/            drag → clear → win, undo
```

State management is **Riverpod**. Services are provided via `ProviderScope` overrides in `main()`, so they're trivially mockable in tests.

### The engine

A board is a grid of valued tiles. A move is a **connected path** of orthogonally-adjacent tiles whose values sum **exactly** to the target; submitting it clears those tiles. The board has no gravity — cleared cells leave empty slots. You win by clearing every tile.

**Solvability is structural, not searched.** The generator builds each board *from* a partition of the grid into connected paths that each already sum to the target — so a complete winning solution exists by construction before the player ever sees the board. `Solver.findPartition` recovers such a partition (backtracking with a traceability check); the stress test replays it through the real `GameState.submitPath` mechanic to prove each board is winnable.

**No dead-ends are hidden, none are invented.** `Solver.hasMove` is a cheap "is any clearing path still available?" check; the game flags "stuck" only when it returns false (peg-solitaire model — a wrong-but-legal clear is never bounced). **Hints** are always safe: `Solver.hint` returns a partition group that provably keeps the board solvable.

**Difficulty is tunable, not just bigger.** Named tiers plus a Zen ladder (`Difficulty.endlessForLevel`) grow the board size and group size, and raise a **decoy band** — the number of distinct target-summing paths on the board, measured by `Solver.countTargetPaths` — so later levels feel denser and trickier without ever becoming unwinnable. `Generator.generateTuned` deterministically searches seeds to land a board inside the level's decoy band.

---

## Monetization

Gentle and non-gating — coins only remove friction (hints) and buy optional cosmetics; nothing gates progress, and hints are never required to finish (a safe hint always exists by construction).

- **Coins** — the single soft currency. Start with `GameConfig.startingCoins` (60). Earn `coinsPerClear` (12) per board, a `dailyClearBonus` (30) for the Daily, and `coinsPerRewardedAd` (25) per rewarded ad. A hint costs `hintCost` (20). All knobs live in `GameConfig` so generosity can be tuned live.
- **Coin packs** — consumable IAP: 250 / 700 / 2000 coins (`IapConfig.coinPacks`).
- **Premium** — a single non-consumable (~US$3.99): removes ads, **unlimited free hints**, unlocks all cosmetic themes. Includes **Restore Purchases**.
- **Interstitial** every `GameConfig.interstitialEveryNClears` (7) Zen board clears. **Never in Daily.** Never for Premium.
- **Stars & clean badge** — boards earn 1–3 stars for *efficiency* (fewer rejected/wrong traces; see `GameConfig.starsForWrong`). Hints do **not** reduce stars; a separate **clean** badge marks boards finished with no hints.
- **Themes** — `Clay` is free; `Sage` (150), `Dusk` (250), and `Ink` (400) are bought with coins, or all unlocked with Premium.

### Sound

SFX (clear / win / tap / invalid) plus a looping ambient pad. All audio is **synthesized offline** (pure-Python stdlib, soft sine tones; see `_spec/synth_sfx.py`) and bundled as WAVs under `assets/sounds/`, so there is no network dependency or licensing concern. **Sound effects** and **Music** toggle independently in Settings, behind `SoundService` (no-op dev impl + an `audioplayers` impl).

### Ads & IAP setup

All IDs live in single files with `// TODO` markers:

| What | File | Replace |
| --- | --- | --- |
| Ad unit IDs | `lib/config/ad_config.dart` | Google **test** IDs → your real rewarded/interstitial unit IDs |
| AdMob App ID (Android) | `android/app/src/main/AndroidManifest.xml` | `com.google.android.gms.ads.APPLICATION_ID` meta-data |
| AdMob App ID (iOS) | `ios/Runner/Info.plist` | `GADApplicationIdentifier` |
| IAP product IDs | `lib/config/iap_config.dart` | placeholders → your Premium + coin-pack product IDs |

Store setup:
1. **Google Play Console / App Store Connect:** create a non-consumable Premium product (`IapConfig.premiumProductId`) and the three consumable coin packs (`IapConfig.coinPacks`) — use the *same* IDs in both stores. Set prices in the consoles.
2. **AdMob:** create the app + rewarded and interstitial ad units; paste the unit IDs into `ad_config.dart` and the App IDs into the native files above.
3. Build with `--dart-define=REACH_REAL_SERVICES=true` and test on a real device with a test account.

The Google **test** ad unit IDs and AdMob App IDs are committed so the real-services path works out of the box during development. They earn no revenue — replace before release.

---

## Renaming / rebranding

The user-facing name and store identifier live in **one Dart file**: `lib/config/app_constants.dart` (`kAppName`, `kBundleId`). Everything in the Dart/Flutter layer reads from there.

Two values are unavoidably mirrored in native build files (which can't read Dart at build time). When you rebrand, also update:

- **Android display name:** `android/app/src/main/AndroidManifest.xml` (`android:label`)
- **Android package id:** `android/app/build.gradle.kts` (`applicationId`, `namespace`) + the Kotlin package directory under `android/app/src/main/kotlin/...` + `MainActivity`
- **iOS display name:** `ios/Runner/Info.plist` (`CFBundleDisplayName`)
- **iOS bundle id:** `ios/Runner.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`, all build configs)

The placeholder bundle id is `com.reach.reach`.

## Fonts

**Fraunces** (variable serif, display/numbers) and **DM Mono** (UI labels) are **bundled** under `assets/fonts/` and declared in `pubspec.yaml`, so the app needs no network for fonts. Fraunces is driven by `FontVariation`s for precise weight/optical-size control (see `lib/game/theme/app_text.dart`).

## Accessibility

State is conveyed by shape/motion as well as colour — selected/path tiles **lift**, a match-ready trace always carries a **✓**, and a hint adds a **ring** — so the core signals are colourblind-safe by default (reinforced by the running-sum chip, which shows the literal number). Settings → *Colourblind marks* makes the ✓ more prominent and adds an **✕** to rejected traces. Core gameplay has **no words**, so it ships internationally with no localization.

## Persistence

Local only (`shared_preferences`), behind `StorageService` with clean domain shapes — `Settings` (haptics, SFX, music, colourblind, selected + owned themes, onboarding), `DailyRecord` (streaks + per-day results with stars/clean), `ZenRecord` (boards cleared / level), and `WalletRecord` (coins) — so a future cloud sync can replace/augment it without touching game logic. A VPS-backed leaderboard/sync is intentionally **out of scope for v1** — the seams are left clean.

## Out of scope for v1

Backend, accounts, global leaderboards, cloud sync, multiplayer, extra modes.
