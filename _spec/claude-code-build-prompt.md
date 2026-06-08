# Build Prompt — "REACH" (working title): a calm number-merge puzzle (Flutter MVP)

You are building a complete, production-quality MVP of a mobile puzzle game in **Flutter** for **iOS + Android**. Read this whole brief before writing code. An HTML prototype (`reach-prototype.html`) is attached — it demonstrates the **feel, the fuse interaction, and the visual language**, plus a working 1D solvable generator. Use it as reference for tone and interaction, **not** as code to port. v1 generalizes the mechanic from a 1D row to a 2D grid as specified below.

---

## 1. The game in one paragraph
A small grid of number tiles. The player taps a tile, then taps an orthogonally-adjacent tile; the two **fuse** into one tile whose value is their **sum** (the fused tile stays in one cell, the other cell empties — tiles do **not** slide or fall). The goal is to build a tile whose value lands **exactly on a target number**, shown at the top. Arithmetic is **implicit**: never show "+" or equations — fusing should feel like merging tokens, not doing math. Overshooting the target is a soft state (the tile is marked), never a hard fail. There are two modes: a **Daily Challenge** (one shared, deterministic puzzle per day, with a streak and a spoiler-free shareable result) and **Zen** (endless procedural puzzles, gently rising difficulty, chasing a "par" of fewest fuses). Monetization is gentle: free to play with **optional** rewarded-ad hints, plus a single one-time **Premium** purchase that removes ads and unlocks unlimited hints + cosmetic themes.

## 2. Non-negotiable design principles
- **Calm & mass-market.** Older/relaxed puzzle audience. No timers required, no punishment, no frustration loops.
- **Language-independent.** No words in core gameplay. Controls are iconographic. This game must ship internationally with zero localization of gameplay.
- **No lives / no energy / no gates.** Nothing blocks the player from playing the next puzzle. Hints are optional aid, never the only way forward.
- **Every puzzle is guaranteed solvable.** Enforced by the generator (see §5).
- **Monetization never gates progress** — it only removes friction (ads) and offers optional help/cosmetics.

## 3. Tech stack
- Flutter (latest stable), Dart, null-safe.
- State management: **Riverpod** (or Provider if simpler) — keep it clean and testable.
- Packages: `google_mobile_ads` (ads), `in_app_purchase` (IAP), `shared_preferences` or `hive` (local persistence), `share_plus` (share result), optional `audioplayers` for subtle SFX.
- **No backend in v1.** The daily puzzle is generated on-device from a date seed (reproducible across all devices). (A VPS exists for a future leaderboard/sync milestone — design persistence so this can be added later, but do not build it now.)

## 4. Architecture (important)
Separate **pure-Dart game logic** from Flutter UI so the logic is unit-testable and the daily seed is reproducible:
- `lib/engine/` — pure Dart, no Flutter imports:
  - `models/` — `Tile`, `Grid`, `Puzzle`, `GameState`
  - `generator.dart` — seedable, solvable puzzle generation
  - `solver.dart` — win check, par computation, connected-region enumeration
  - `difficulty.dart` — difficulty tiers/config
- `lib/game/` — Flutter widgets, screens, animations
- `lib/services/` — `AdService`, `PurchaseService`, `StorageService` behind interfaces (so they can be mocked and the game runs in a no-ads dev stub)
- `test/` — unit tests for engine, widget tests for core interaction

## 5. Core mechanic (precise)
- Grid of R×C cells; each cell holds a positive integer tile or is empty.
- **Interaction:** tap a tile to select (it lifts/highlights); tap an orthogonally-adjacent tile to fuse → the two values sum into one tile occupying one of the two cells; the other cell becomes empty. Tapping the selected tile again deselects; tapping a non-adjacent tile reselects.
- **No gravity / no sliding.** The grid is static between fuses.
- **Win:** any tile's value equals the target exactly.
- **Overshoot:** a tile whose value exceeds the target is visually marked (icon + shape, not color alone) but is **not** a fail; the player can undo or use other regions.
- **Controls:** Undo (full history), Restart puzzle, New/Next puzzle. Move counter + par display.
- **Reachable values** are sums of **connected regions** of original tiles (because sequential adjacent fusion contracts a connected region into one tile). This is the source of depth: planning which connected region to build, avoiding overshoot, and minimizing fuses.

## 6. Generator + solvability (precise — do not invent a different scheme)
Guarantee solvability by construction:
1. Seed the RNG: **Daily** = deterministic hash of the local date (e.g., `YYYYMMDD`), so every device gets the same daily puzzle. **Zen** = fresh random seed each puzzle.
2. Fill the grid with small positive integers (range per difficulty, §7).
3. Choose the **target** = sum of a randomly **grown connected region** of cells, region size ≥ 2 and < total cells. (Grow a region by starting at a random cell and repeatedly adding a random orthogonal neighbor.)
   - *Why this guarantees a solution:* any connected region can be collapsed to a single tile equal to its sum, by contracting the edges of a spanning tree of the region one fuse at a time (each contraction fuses two currently-adjacent members; the merged tile remains adjacent to the rest because the region is connected).
4. Reject degenerate puzzles and regenerate (bounded retries):
   - reject if the target equals any single existing tile value (trivial),
   - reject if the target equals the whole-grid sum (trivial "fuse everything"),
   - reject if no connected region sums to the target (shouldn't happen given step 3, but assert it).
5. **Par** = minimum number of fuses across **all** connected regions whose sum equals the target = (size of the smallest such region − 1). Compute via a pruned DFS over connected regions (stop growing a region once its partial sum exceeds the target). If exhaustive search is too costly at large grid sizes, cap region-size search and document the cap; correctness of *solvability* must never depend on this — par is advisory only.
6. Difficulty tiers control grid size, integer range, and target-region size (§7).
- Port the spirit of the prototype's stress test: a unit test that generates tens of thousands of puzzles per difficulty and asserts **zero unsolvable** and **zero degenerate**.

## 7. Difficulty
- Define ~3 tiers, e.g. Easy (4×4, values 1–6), Medium (5×5, values 1–8), Hard (6×6, values 1–9) — tune by playtest.
- **Zen** starts easy and ramps gently with each solve (e.g., every N solves nudges grid size / value range / region size).
- **Daily** uses a fixed moderate difficulty (or a light weekday ramp), same for everyone that day.

## 8. Modes
- **Daily Challenge:** one puzzle/day from the date seed; track current streak, longest streak, and per-day completion (keyed by date). Provide a **spoiler-free shareable result** via `share_plus` (a compact line conveying moves vs par with neutral symbols — no numbers/positions that reveal the solution). Roll over at local midnight.
- **Zen:** endless; auto-advance to the next puzzle on solve; show par and the player's personal best (fewest fuses) for the current tier.

## 9. Hints (optional aid)
- A hint highlights one tile of a valid target region, or highlights a recommended next fuse.
- Cost model: **free users watch a rewarded ad** to get a hint; **Premium users get unlimited hints, no ads.** Hints are never required to finish a puzzle.

## 10. Monetization (full MVP, integrated behind services)
- `google_mobile_ads`:
  - **Rewarded ad** → grants a hint (free users).
  - Optional **interstitial** every N Zen puzzles (configurable constant, conservative default, e.g. every 6–8 solves). **No interstitials in Daily.**
  - Use Google **test ad unit IDs** in a single `ad_config.dart` with a clear `// TODO: replace with real ad unit IDs` and instructions in the README.
- `in_app_purchase`:
  - One **non-consumable "Premium"** product (~US$3.99) → removes all ads + unlimited hints + unlocks cosmetic themes.
  - Implement **Restore Purchases**. Use a placeholder product ID in config with a `// TODO` and README note on store setup.
- Abstract both behind `AdService` and `PurchaseService` interfaces with a **no-op dev implementation** so the game runs fully without store/ad accounts during development.
- **No gems/virtual currency in v1.** Themes unlock directly via Premium. No lives/energy anywhere.

## 11. Persistence (local)
Store: Premium entitlement (re-verified via `in_app_purchase` restore on launch), daily streak data + per-date completion, Zen tier progress + personal bests, settings (sound on/off, selected theme, colorblind mode). Design the storage layer so a future cloud-sync can replace/augment it without touching game logic.

## 12. UX & visual language (reuse the prototype's aesthetic)
- Calm, tactile, "premium toy" feel. Paper/cream background, **terracotta** accent, deep ink text. Display font **Fraunces**, tile numbers in **DM Mono** (bundle the fonts). Soft tiles with a subtle bottom "physical" shadow; a satisfying **fuse pop** animation; a gentle **win pulse** (no harsh effects — calm tone).
- Portrait orientation; one-hand reachable; large tap targets.
- **Colorblind-safe:** overshoot/hit/selected states must differ by **icon/shape**, not color alone; include a colorblind toggle.
- Minimal/iconographic UI text so the app is effectively language-independent. Screens: Home (Daily / Zen / Settings), Game screen, Win sheet (moves, par, streak, share, next), Settings (sound, theme, colorblind, restore purchases, privacy link).

## 13. Engineering hygiene & deliverables
- Analyzer clean, null-safe, sensible folder structure as in §4.
- **Tests:** generator stress test (solvable + non-degenerate across many seeds), solver/par tests, a couple of widget tests for select→fuse→win and undo.
- A **README** covering: how to run, how to run tests, where to put real ad unit IDs and the IAP product ID, and store-setup notes.
- Suggested build order: (1) engine + tests, (2) game screen + fuse interaction + undo, (3) Zen mode, (4) Daily + streak + share, (5) ads/IAP behind services, (6) settings + polish.

## 14. Explicitly out of scope for v1
Backend, accounts, global leaderboards, cloud sync, multiplayer, extra game modes, virtual currency. (Note: a VPS is available for a later leaderboard/sync milestone — leave clean seams, build none of it now.)

---

**Goal:** a polished, shippable single-player MVP that feels calm and tactile, runs on iOS and Android from one codebase, guarantees every puzzle is solvable, and has gentle, non-gating monetization wired in behind mockable services. Prioritize a clean, tested engine and a great-feeling core interaction over feature breadth.
