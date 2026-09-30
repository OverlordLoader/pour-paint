## 2026-09-30 — Unsigned native simulator verification

Added a free public macOS compile/startup workflow, evidence capture, and a shared Xcode scheme where missing. Supports opening the existing game on Henry's MacBook without App Store submission. No paid service, signing or purchase. Build status is reported separately from full gameplay acceptance.

# Changelog

## 2026-09-29 — Initial build (milestone 1 + monetization)

- New game: **Pour Paint** (`app.pourpaint.game`), native SwiftUI + SpriteKit,
  iOS 17+, portrait only.
- Gameplay: replicate the target artwork's color bands by tapping supply tubes
  to pour bands into the canvas tube, within a pour limit. Unlimited undo,
  restart, "reveal next band" hint.
- `PaintLevelGenerator`: 50 seeded, certified-solvable levels — solution
  pour-sequence generated first, target derived from it, certified by replaying
  the solution through the real game rules; discard-and-regenerate on failure.
  Difficulty ramp: bands 3→6, colors 3→8, pour slack 3→2→1.
- Star rating: 3★ within par, 2★ over par, 1★ with hints/extra pours.
- Juice: glossy tubes, animated pour streams, splash particles, wobble,
  confetti, synthesized SFX (SoundManager), haptics — no assets needed.
- Monetization in from day one:
  - Google Mobile Ads via SPM (rewarded: +2 pours / reveal next band;
    interstitial at most every 3rd win, never mid-level, never first 3 wins;
    test IDs in DEBUG, `// TODO(Henry)` real IDs for release).
  - StoreKit 2: `app.pourpaint.game.removeads` ($4.99, non-consumable),
    `app.pourpaint.game.boosters.extrapours10` ($0.99, consumable 10-pack,
    each refill +2 pours). Verification, `Transaction.finish()`,
    `Transaction.updates`, `AppStore.sync()` restore, refund revocation.
  - Settings screen: Remove Ads row (live price → "Owned"), Extra Pours row
    (price + owned count), Restore Purchases. No dead buttons.
- Privacy: `PrivacyInfo.xcprivacy` declares Device ID for third-party
  advertising (tracking=false, no IDFA).
- Release tooling: `tools/gen_pbxproj.py` (deterministic .xcodeproj with GMA
  SPM wiring + Resources phase for privacy manifest and asset catalog),
  `scripts/generate_icons.py` (9-icon set), `scripts/apple-release-check.py`
  (safety gates), `scripts/apple-release.py` (macOS sign + validate + upload).
  Release workflow saved to `~/workspace/your_files/pourpaint-apple-release.yml`
  for Henry to upload (uses the dedicated `app-store-release-pourpaint`
  environment).


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.
Fixed unquoted spaced display names in both the Xcode project and its generator.
Added the missing pinned, manually dispatched release workflow with upload off by default and a dedicated release environment. No workflow dispatched.
