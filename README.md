# Capsy: Stress Relief Pet 🪣

> App Store metadata lives in [`ASO.md`](ASO.md) · distribution runbook in [`TESTFLIGHT.md`](TESTFLIGHT.md)

Stress is a liquid. It accumulates drop by drop, sloshes when you tilt the
phone, and never disappears on its own — you have to consciously pour it out
with a breathing ritual. A transparent voxel vessel with living water, in the
**gyva tyla V4.5** ("living silence") style: clay and coral `#E8865C` on cream
sand `#EDE4D6`, day/night (auto 21:00–7:00 + a ☾/☀ toggle), compressed poster
typography, mono digits, spring 90/16, "a wave, not an explosion", a Tibetan
bowl tone and a garden of stillness.

## Run it (2 commands)

```bash
brew install xcodegen        # if you don't have it yet
xcodegen generate && open Capsy.xcodeproj
```

Xcode: pick your *Signing Team* for both targets (Capsy and CapsyWidget) — and Run.
Works in the Simulator too (without tilt the water just waves calmly).

## What's inside

| Feature | Where |
|---|---|
| Live 3D character-vessel (SceneKit voxel liquid, damped-spring slosh, breathing, vapor) | `Capsy/Views/CapsySceneView.swift` |
| 3 transparent vessels to choose from: bucket / potion flask / glass (persisted) | `Capsy/Views/BucketView.swift` (styles), `CapsySceneView.swift` (3D) |
| Home screen: fill %, `DROP`, `RELEASE`, gamification HUD, daily quest | `Capsy/Views/HomeView.swift`, `ProgressHUD.swift` |
| Release ritual — breathing 4 s in / 6 s out × 4, the vessel drains on exhale | `Capsy/Views/ReleaseView.swift` |
| Economy: gold, XP, levels, gentle streak with freezes, chest rewards | `Capsy/Game.swift` |
| Calm habits (Habitica-style taps that earn gold) | `Capsy/Views/HabitsView.swift` |
| Rewards shop: vessel bodies and hats | `Capsy/Views/ShopView.swift` |
| Capsy Plus paywall (StoreKit 2: monthly / yearly / lifetime, 7-day trial) | `Capsy/Plus.swift`, `Views/PaywallView.swift` |
| Path of Stillness (milestones), weekly chart, drop history | `Capsy/Views/JourneyView.swift` |
| Apple Health: mindful minutes written, HRV read as a quiet body signal | `Capsy/Health.swift` |
| Morning/evening notifications in Capsy's voice | `Capsy/Reminders.swift` |
| Lock Screen + Home Screen widgets with a 1-tap quick drop | `CapsyWidget/CapsyWidget.swift` |
| SwiftData models + bucket logic | `Capsy/Models.swift` |
| State shared with the widget (App Group) | `Shared/SharedState.swift` |
| Pure-logic unit tests (run in CI) | `CapsyTests/CapsyTests.swift` |

Capacity: 24 units. A drop: light 2 / medium 4 / heavy 6 units.
Widgets refresh after every mutation (`WidgetCenter.reloadAllTimelines`).

Full product description — [`MASTER_PROMPT.md`](MASTER_PROMPT.md).
TestFlight distribution guide — [`TESTFLIGHT.md`](TESTFLIGHT.md).

## CI

Every push builds the app on a macOS runner, runs the unit tests, boots a
simulator, captures an 8-screenshot gallery (`/screenshots`) and commits the
generated project + screenshots back to the branch.

## Tech

Swift 5.9 · SwiftUI · SwiftData · SceneKit · WidgetKit + AppIntents ·
StoreKit 2 · HealthKit · Swift Charts · AVAudioEngine (all sound synthesized
in code) · XcodeGen. Zero third-party dependencies. Minimum iOS: 17.0.
