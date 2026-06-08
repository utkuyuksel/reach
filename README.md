# REACH

> Working title. **REACH** is a calm, language-independent number-merge puzzle for iOS & Android, built in Flutter.

Tap a tile, then an orthogonally-adjacent tile — they **fuse** into one tile equal to their sum (no gravity, no sliding). Build a tile that lands **exactly** on the target. Overshooting is a soft, undoable state, never a failure. Two modes — a deterministic **Daily Challenge** with streaks and spoiler-free sharing, and endless **Zen** with a gentle difficulty ramp and a fewest-fuses "par".

Every puzzle is **guaranteed solvable by construction** (see [The engine](#the-engine)).

---

## Quick start

```bash
flutter pub get
flutter run            # runs with no-op dev ad/IAP stubs — no accounts needed
```

The game runs fully without any AdMob or store account: ads and purchases default to no-op dev stubs (rewarded "ads" grant a hint instantly; "buy" flips the Premium flag). To exercise the real `google_mobile_ads` / `in_app_purchase` integrations on a configured build:

```bash
flutter run --dart-define=REACH_REAL_SERVICES=true
```

### Tests

```bash
flutter test                                  # everything (engine + widget)
flutter test test/engine                      # engine only
flutter test test/engine/generator_stress_test.dart   # the solvable-generator stress test
```

The headline guarantee — **every generated puzzle is solvable and non-degenerate** — is enforced by `test/engine/generator_stress_test.dart`, which generates **20,000 puzzles per difficulty** across all shipped configs (the 3 named tiers + every Zen-ladder rung), and for each one independently verifies non-degeneracy, that the solution region is connected and sums to the target, **and replays it to a win through the real `GameState` tap/fuse mechanic**. It must pass with zero failures.

> Note: in this environment `flutter analyze` may crash inside its analysis-server wrapper. Use **`dart analyze lib test`** instead — it is the working equivalent and reports clean.

---

## Architecture

Pure-Dart game logic is fully separated from Flutter UI so it is unit-testable and the daily seed is reproducible.

```
lib/
  config/            app identity + ad/IAP config in single files (see "Renaming")
  engine/            PURE DART — no Flutter imports
    models/          Tile, Grid, Puzzle, GameState
    rng.dart         deterministic splitmix64 PRNG (cross-device reproducible)
    difficulty.dart  tiers + Zen ramp ladder
    generator.dart   seedable, solvable-by-construction generation
    solver.dart      win check, par, connected-region search, contraction sequence
  services/          StorageService / AdService / PurchaseService behind interfaces,
                     each with a no-op dev impl + a real impl
  game/
    state/           Riverpod controllers (game, settings, daily, zen, entitlement)
    theme/           palette (default + Premium cosmetic palettes) + fonts
    widgets/         tiles, board, target, controls, win sheet
    screens/         home, game, settings
  util/              date helpers
  main.dart          bootstraps services and wires Riverpod overrides
test/
  engine/            generator stress test, solver/par, GameState, generator determinism
  widget/            select → fuse → win, undo, non-adjacent reselect
```

State management is **Riverpod**. Services are provided via `ProviderScope` overrides in `main()`, so they're trivially mockable in tests.

### The engine

The mechanic generalizes a 1D row to a 2D grid: reachable values are the sums of **connected regions** of original tiles, because sequential adjacent fusion contracts a connected region into one tile.

**Solvability is structural, not searched.** The generator picks the target as the sum of a randomly *grown connected region*. Any connected region can be collapsed into a single tile equal to its sum by building a spanning tree and fusing every leaf into its parent (deepest-first): the parent never moves, so every tree edge remains a physical orthogonal adjacency at the moment it's used. `Solver.contractionSequence` produces exactly that move list — and the stress test replays it through the real game mechanic to prove each puzzle is winnable.

**Par** (advisory, fewest fuses) = size of the smallest connected region summing to the target, minus one. Found by a sum-pruned, size-ordered BFS over connected cell sets (bitmasks). The search is capped at the grown region's size as a pure optimization — solvability never depends on the cap, and a test confirms the cap never changes the answer.

---

## Monetization

Gentle and non-gating — it only removes friction (ads) and offers optional help/cosmetics. No lives, energy, gates, or virtual currency.

- **Rewarded ad → one hint** (free users). Premium users get unlimited hints, no ads. Hints are never required to finish.
- **Interstitial** every `AdConfig.interstitialEveryNZenSolves` (default 7) Zen solves. **Never in Daily.** Never for Premium.
- **Premium** — a single non-consumable (~US$3.99): removes ads, unlimited hints, unlocks cosmetic palettes. Includes **Restore Purchases**.

### Ads & IAP setup

All IDs live in single files with `// TODO` markers:

| What | File | Replace |
| --- | --- | --- |
| Ad unit IDs | `lib/config/ad_config.dart` | Google **test** IDs → your real rewarded/interstitial unit IDs |
| AdMob App ID (Android) | `android/app/src/main/AndroidManifest.xml` | `com.google.android.gms.ads.APPLICATION_ID` meta-data |
| AdMob App ID (iOS) | `ios/Runner/Info.plist` | `GADApplicationIdentifier` |
| IAP product ID | `lib/config/iap_config.dart` | placeholder → your product ID |

Store setup:
1. **Google Play Console / App Store Connect:** create a non-consumable product with the ID in `IapConfig.premiumProductId` (use the *same* ID in both stores). Set the ~US$3.99 price in the console.
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

State is conveyed by shape/motion as well as colour — selected tiles **lift**, overshoot tiles carry an **up-chevron** badge, and target hits carry a **✓** badge — so the game is colourblind-safe by default. Settings → *Colourblind marks* makes the badges always-prominent. Core gameplay has **no words**, so it ships internationally with no localization.

## Persistence

Local only (`shared_preferences`), behind `StorageService` with clean domain shapes (`Settings`, `DailyRecord`, `ZenRecord`) so a future cloud sync can replace/augment it without touching game logic. A VPS-backed leaderboard/sync is intentionally **out of scope for v1** — the seams are left clean.

## Out of scope for v1

Backend, accounts, global leaderboards, cloud sync, multiplayer, extra modes, virtual currency.
