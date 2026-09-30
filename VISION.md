# VISION.md — Pour Paint

## Vision

Pour Paint is a calm, tactile pouring puzzle: study a target artwork, then
recreate its color bands one pour at a time. No timers, no fail states — the
satisfaction comes from planning the pour order and watching glossy paint land
exactly where you meant it to. A 2-minute level that leaves your brain quieter
than it found it.

## Philosophy

- **Free tier is the whole game.** All 50 levels are fully playable without
  paying anything. Monetization (ads, boosters, remove-ads) buys convenience,
  never access.
- **Help first, convert second.** Ads never interrupt a level; the rewarded
  placements (+2 pours, reveal next band) exist to rescue a stuck player, not
  to farm impressions. Interstitials only at level transitions, paced and
  skippable by purchase.
- **No accounts, no tracking.** Progress lives in UserDefaults. The only
  third-party code is Google Mobile Ads (declared in the privacy manifest,
  tracking=false, no IDFA). No analytics SDKs, no external billing, no web
  links, no http:// URLs — ever.
- **Juice is the product.** Glossy tubes, liquid streams, splash particles,
  wobble, confetti, synthesized SFX, haptics. Every interaction should feel
  physical.

## Pricing

| Item | Type | Price | Product ID |
|---|---|---|---|
| Remove Ads | Non-consumable | $4.99 | `app.pourpaint.game.removeads` |
| Extra Pours 10-pack | Consumable | $0.99 | `app.pourpaint.game.boosters.extrapours10` |

Each Extra Pours refill adds +2 pours to the current level. Rewarded ads grant
+2 pours or a "reveal next band" hint for free. StoreKit 2 only.

## Current state (2026-09-29)

- Milestone 1 (gameplay) + milestone 2 (monetization) built in one pass:
  50 certified-solvable levels, full game loop, ads + IAP wired, settings
  store screen, app icon, privacy manifest, release tooling.
- Code is hand-reviewed for API correctness (GMA 11.x, StoreKit 2, Swift 6
  patterns mirrored from the shipped Tidy Up! codebase). **Not yet compiled**
  — no Swift toolchain on this machine; first compile happens on the macOS
  release runner / Henry's Xcode.
- Local repo at `~/workspace/pour-paint`, committed to `main`.
- GitHub repo `OverlordLoader/pour-paint` **not yet created** (no GitHub auth
  on this machine) — Henry creates it, then the local repo can be pushed.
- Release workflow file staged at `~/workspace/your_files/pourpaint-apple-release.yml`
  for Henry to upload via the GitHub web UI (subagents can't push workflows).
- Still needed from Henry/Hermes: App Store Connect IAP products (table above),
  AdMob account + 1 Rewarded + 1 Interstitial ad unit (paste into the
  `// TODO(Henry)` spots + real App ID into Info.plist), provisioning profile
  for `app.pourpaint.game`, `app-store-release-pourpaint` environment secrets,
  banking/tax forms, app preview video + submission.

## Conventions (for Henry and any AI tool working in this repo)

- **Review branches only. Never merge to the default branch without Henry.**
- **No secrets in code.** API keys, ad unit IDs for release, and signing
  material live in GitHub secrets / Henry's hands, never in the repo.
  Debug builds use Google's official test IDs.
- **One purchase flow per platform.** All purchases go through StoreKit 2.
  No external billing, no web links, no `UIApplication.shared.open`.
- **Rules live in one place.** `Game/Models.swift` is the single source of
  truth for pour legality; the generator's certification replays through it.
- **Deterministic everything.** Level N is identical on every device
  (seeded RNG); `tools/gen_pbxproj.py` regenerates the Xcode project
  byte-deterministically — never hand-edit the .pbxproj.
- **Update this file's changelog with every change.**

## Changelog

- 2026-09-29: Repo created. Initial build: gameplay (certified-solvable
  50-level generator, canvas pouring, undo/hint/restart, star ratings),
  juice (pour streams, particles, SFX, haptics), monetization (AdMob rewarded
  + interstitial, StoreKit 2 Remove Ads + Extra Pours 10-pack, settings
  store), icon set, privacy manifest, release scripts + workflow.
