# Capsy — The Stress Bucket · Master Build Prompt

> **High-level idea (one paragraph):** Capsy turns invisible stress into a visible, physical thing — a small voxel bucket of liquid that lives on your phone and your Lock Screen. Every stressful moment you log is a drop that falls into the bucket; the liquid rises and *sloshes* like real water when you tilt the phone. When the bucket gets heavy, you empty it — not with a tap, but with a guided breathing ritual where the liquid visibly drains as you exhale. Every release advances you along a calm "journey of stillness" (Ramybės kelias) with unlockable milestones. The Lock Screen widget shows the current fill level at a glance, so your stress state is always one glance away — and so is the invitation to let it go.

You are building a premium, native iOS game-like wellness app that turns stress into a visual representation — a bucket with liquid that sloshes (skystis kuris teliuskuoja) — visible on the Lock Screen, wrapped into a gentle adventure, rendered in the **gyva tyla** ("living silence") style. Your output must be a complete, production-quality, App Store–ready app that compiles and runs on the first try — no stubs, no TODOs, no placeholder logic. Every feature below must actually function. This is a home run on the first run or it is nothing.

---

## 1. The concept

- **Metaphor:** your mind is a bucket. Stress is liquid. It accumulates drop by drop; it never disappears by itself — you must consciously pour it out.
- **Core loop:** feel stress → log a drop (3-second interaction) → watch the bucket physically react → when heavy, run the **Release ritual** (guided breathing that drains the bucket) → advance the journey → glance at the Lock Screen widget to stay aware.
- **Tone:** calm, warm, wordless where possible. No guilt, no streak-shaming. The app is a quiet companion, not a coach.
- **Name:** Capsy. UI language: Lithuanian (short, warm microcopy).

## 2. Tech stack & hard constraints

- **Swift 5.9+, SwiftUI only.** iOS 17.0 minimum. No third-party dependencies whatsoever.
- **SwiftData** for all persistence. **WidgetKit** for Lock Screen (accessoryCircular, accessoryRectangular) + Home Screen (systemSmall) widgets. **App Group** (`group.com.capsy.shared`) to share bucket state with the widget; fall back to standard UserDefaults if the group is unavailable so the app never crashes unsigned.
- **CoreMotion** for real device-tilt liquid physics. **Core Haptics / UIFeedbackGenerator** for tactile feedback on every meaningful interaction.
- Liquid rendering via **SwiftUI Canvas + TimelineView(.animation)** — procedural, 60–120 fps, zero image assets required for motion.
- Project defined with **XcodeGen (`project.yml`)** — one command (`xcodegen generate`) produces the .xcodeproj with app + widget targets, generated Info.plists and entitlements. It must build with zero manual Xcode surgery beyond selecting a signing team.

## 3. Visual & design direction (make it gorgeous)

Reference: the **gyva tyla** design book (calm Baltic minimalism + voxel accents).

- **Palette:** deep moss-black background `#0E1512`; liquid teal `#5FD4C4` with darker depth gradient `#2E8C80`; warm sand text/accents `#E8DCC8`; muted stone secondary `#7A8B85`. One accent, never more.
- **Voxel style:** the liquid is drawn as a field of small rounded squares (voxels) under a live wave surface; the bucket is a blocky, chunky silhouette. Everything else is quiet, flat, generous whitespace.
- **Typography:** SF Rounded, few words, large calm numerals.
- **Dark, silent atmosphere by default** — the app should feel like a held breath.

## 4. Motion & interactivity bar (weighted heavily)

This is the soul of the app. All of it must ship:

- **Sloshing liquid:** two superimposed sine waves with animated phase; surface tilts with real device roll (CoreMotion); a damped-spring slosh oscillator gives the liquid inertia — tilt the phone and the water keeps swinging after you stop.
- **Drop event:** a voxel droplet falls from the top, splash particles burst on impact, the surface receives a slosh impulse, the level rises with a spring animation, and a soft haptic thud lands exactly on impact.
- **Release ritual:** breathing circle expands/contracts (4 s in / 6 s out × 4 cycles); the bucket drains only during exhale, synced to the animation; gentle rising haptic pattern; finale of floating voxel particles.
- **Ambient life:** occasional bubble rises through the liquid; the surface never freezes — even "idle" water breathes.
- **Every state change is animated.** Nothing snaps. Springs everywhere, tuned soft.

## 5. Generate every asset live via the Higgsfield MCP

- The **app icon** (1024×1024, voxel bucket with teal liquid, gyva-tyla calm) is generated live via Higgsfield `generate_image` (nano_banana_pro, 1:1), downloaded and placed into `Assets.xcassets/AppIcon.appiconset`.
- All **in-app motion visuals are procedural by design** (Canvas voxels) — this is deliberate: liquid must react to live sensor data at 120 fps, which pre-rendered assets cannot do. Higgsfield is used for static brand assets (icon, optional marketing shots), code is used for everything that moves.

## 6. Creative autonomy & ambition (spec is a floor, not a ceiling)

Where the spec is silent, choose the more delightful option. Add texture: idle bubbles, microcopy that changes with fill level ("Ramu." → "Kaupiasi…" → "Laikas išpilti."), milestone names with personality. Never add complexity that costs clarity — **ultra simple, extremely readable code and UI is itself a feature.**

## 7. Feature spec — build ALL of it (this is the floor)

1. **Bucket home screen** — live liquid, fill %, contextual state line, big `+ Lašas` button, `Išleisti` button that appears when the bucket isn't empty.
2. **Log a drop** — 3 intensities (Lengvas 🟢 / Vidutinis 🟡 / Sunkus 🔴 → 2/4/6 units, capacity 24) + optional one-line note. One sheet, two taps total.
3. **Release ritual** — full-screen guided breathing, bucket drains on exhale, all unreleased drops are marked released, a ReleaseSession is recorded, journey advances.
4. **Journey (Ramybės kelias)** — milestone path driven by total releases (1, 3, 7, 15, 30…), each with a name and voxel medal; shows the next goal.
5. **History & insight** — last-7-days bar chart (Swift Charts) of logged units + list of recent drops with notes; simple weekly summary line.
6. **Widgets** — Lock Screen circular gauge (fill %), rectangular (fill % + state line), Home Screen small (mini static bucket). Refreshed by the app via WidgetCenter on every change.
7. **Overflow state** — at 100% the bucket visibly trembles and the app gently insists on a release.

## 8. Data model (persist all of it in SwiftData)

```swift
@Model StressDrop     { date, intensity(1–3), units, note, released }
@Model ReleaseSession { date, cycles, drainedUnits }
```

Derived (never stored): current level = Σ units of unreleased drops, capped at 24; journey progress = count of ReleaseSessions. Widget state (fill fraction + state line) mirrored to App Group UserDefaults on every mutation.

## 9. Deliverables & output format

- Complete repo: `project.yml`, all Swift sources (app + widget), assets, `README.md` with exact build steps (`brew install xcodegen && xcodegen generate && open Capsy.xcodeproj`), and this master prompt.
- Code organised for readability: one concern per file, short files, section comments only where the code can't speak for itself.

## 10. Non-negotiables (self-check before you finish)

- [ ] Compiles with zero errors/warnings after `xcodegen generate` + signing team selection.
- [ ] No TODO / stub / placeholder anywhere.
- [ ] Liquid sloshes with device tilt AND keeps momentum (damped spring), not just a looping animation.
- [ ] Haptics fire on drop impact and breathing transitions.
- [ ] Widget shows live fill level after every app mutation.
- [ ] Works on simulator (tilt gracefully degrades to ambient waves).
- [ ] All data survives relaunch (SwiftData).
- [ ] UI reads like a whisper: minimal words, calm motion, one accent color.
