# Capsy — The Stress Bucket · Master Build Prompt (Voxel Art / Gyva Tyla)

You are building **Capsy**, a premium, native iOS wellness game that turns invisible stress into a visible, physical thing — liquid in a transparent vessel that lives on your phone and your Lock Screen — rendered in a calm **voxel art** style guided by the **gyva tyla** ("living silence") design book. Your output must be a **complete, production-quality, App Store–ready app that compiles and runs on the first try** — no stubs, no TODOs, no placeholder logic, no "left as an exercise." Every feature described below must actually function. Treat this as a flagship app someone would pay to download. **This is a home run on the first run or it is nothing.**

## The concept

Your mind is a vessel. Stress is liquid. It accumulates drop by drop, it *sloshes* like real water when you tilt the phone, and it never disappears by itself — you must consciously pour it out. Capsy's loop: feel stress → log a drop (3-second interaction) → watch the vessel physically react → when heavy, run the **Release ritual** (guided breathing where the liquid visibly drains as you exhale) → advance the calm **journey of stillness** (Ramybės kelias) → glance at the Lock Screen widget to stay aware. **Design principle: reward release, not accumulation.** No guilt, no streak-shaming — the app is a quiet companion, not a coach. Target audience: adults **29–55** — every visual must read calm and premium, never childish. UI language: **Lithuanian** (short, warm microcopy).

## Tech stack & hard constraints

- **Swift 5.9 + SwiftUI + SwiftData only. Zero third-party dependencies.** No CocoaPods, no SPM packages.
- Only Apple system frameworks: SwiftUI, SwiftData, **WidgetKit** (Lock Screen accessoryCircular/accessoryRectangular + Home Screen systemSmall), **CoreMotion** (real device-tilt liquid physics), **Swift Charts**, AVFoundation, Foundation.
- **App Group** (`group.com.capsy.shared`) shares vessel state with the widget; fall back to standard UserDefaults when the group is unavailable so an unsigned build never crashes.
- Target **iOS 17+**, iPhone-first. Project defined with **XcodeGen (`project.yml`)**: `xcodegen generate && open Capsy.xcodeproj`, pick a signing team, **Cmd+R** — nothing else. Works in the Simulator (no accelerometer → liquid gracefully degrades to ambient waves).
- **All sound is synthesized in code** (AVAudioEngine sine tones with soft envelopes; `.ambient` session) — zero audio asset files. Haptics via UIFeedbackGenerator on every meaningful event.
- All liquid motion is **procedural** (SwiftUI Canvas + TimelineView) — it must react to live sensor data at up to 120 fps, which pre-rendered assets cannot do.
- **All progress persists in SwiftData and survives restarts.**

## Visual & design direction (make it gorgeous)

Reference: the **gyva tyla** design book — Baltic calm minimalism + voxel accents. The app should feel like a held breath.

- **Palette:** deep moss-black `#0E1512` background; liquid teal `#5FD4C4` with depth gradient to `#2E8C80`; warm sand `#E8DCC8` for text; muted stone `#7A8B85` secondary. One accent, never more.
- **Voxel language:** the liquid is a field of small rounded cubes under a live wave surface; the classic bucket is a blocky silhouette; the mascot is built of glossy teal cubes. Everything else is quiet, flat, generous whitespace.
- **Typography:** SF Rounded, few words, large calm numerals.
- A cohesive system: defined color tokens, soft spring motion curves, consistent corner radii. Every screen intentional and finished — a real shipping product, not a prototype.

## Motion & interactivity bar (this is weighted heavily)

- **Sloshing liquid:** two superimposed sine waves with animated phase; the surface tilts with real device roll; a **damped-spring slosh oscillator** gives the water inertia — tilt the phone and it keeps swinging after you stop.
- **Drop event:** a voxel droplet falls, splash particles burst, the surface takes a slosh impulse, the level rises on a spring, a soft haptic + synthesized "plop" land exactly on impact.
- **Release ritual:** breathing circle expands/contracts (4 s in / 6 s out × 4), the vessel drains **only during exhale**, rising/falling breath tones, a two-note chime and floating voxel sparkles at the finale.
- **Ambient life:** bubbles occasionally rise; the surface never freezes; the mascot idly bobs and blinks. At 100 % the vessel visibly **trembles**.
- **Every state change is animated.** Nothing snaps. Springs everywhere, tuned soft.

## The Capsy Mascot Pipeline (Higgsfield MCP — generate live)

You have the **Higgsfield MCP available**. Generate **Capsy** — a cute-but-calm voxel water-droplet character (glossy teal cubes, teardrop silhouette, large dark square eyes) — as a **locked character reference** reused verbatim in every prompt so all poses are one character:

1. **Pose set** (nano_banana_pro, 1:1, dark moss background): `MascotCalm` (gentle smile), `MascotBusy` (slightly worried, sweat cube), `MascotHeavy` (drooping, darker teal), `MascotRelief` (eyes closed blissfully, sparkle cubes).
2. The **app icon** derived from the same visual language (voxel vessel with teal liquid).
3. Wire poses into the asset catalog at the exact names the code references; the home screen shows the mood matching the current fill level, and the ritual finale shows relief. If a generation call fails, fall back to a tasteful **vector droplet** drawn in code — never emoji as shipped art.

Keep a running log in **`ASSETS.md`**: for each asset — path, dimensions/format, model, and the full Higgsfield prompt used — so the pipeline is reproducible.

## Creative autonomy & ambition (spec is a floor, not a ceiling)

You have full creative and technical autonomy. Improve any decision where you see a better interaction, animation, or model. Add thoughtful empty states, micro-interactions, accessibility labels, edge-case handling. The one boundary: the **hard constraints** and the **listed core systems must all be present and working**. Never add complexity that costs clarity — **ultra simple, extremely readable code and UI is itself a feature.** Surprise me within the silence.

## Feature spec — build ALL of it (this is the floor)

1. **Onboarding** — warm 3-page first run: the concept in one sentence, vessel choice, how the loop works. Sets `hasOnboarded`; never shown again.
2. **Vessel home screen** — live liquid, fill %, contextual state line ("Ramu." → "Kaupiasi…" → "Laikas išpilti."), the mascot reacting to the level, `+ Lašas`, and `Išleisti` appearing when not empty.
3. **Vessel choice** — three transparent glass vessels: voxel bucket, round "mana potion" flask (drops fall through its narrow neck), simple tumbler. Persisted; used everywhere the liquid appears.
4. **Log a drop** — 3 intensities (Lengvas/Vidutinis/Sunkus → 2/4/6 units, capacity 24) + optional one-line note. One sheet, two taps total.
5. **Release ritual** — full-screen guided breathing; drains only on exhale; cancelling keeps every drop; completion marks drops released, records a ReleaseSession, celebrates quietly.
6. **Journey (Ramybės kelias)** — milestones at 1/3/7/15/30 releases with names and voxel medals; shows the next goal.
7. **History & insight** — last-7-days bar chart of logged units + recent drops with notes.
8. **Widgets** — Lock Screen circular gauge + rectangular (fill % + state line), Home Screen mini vessel; refreshed via WidgetCenter on every mutation.
9. **Share card** — a gorgeous post-ritual card (vessel, "Paleista.", stats, journey milestone) rendered with ImageRenderer, shared via the system share sheet. This is marketing — make it beautiful.
10. **Synthesized sound** — plop on drop impact, breath tones during the ritual, completion chime; a mute toggle; `.ambient` so it never interrupts the user's audio.
11. **Overflow state** — at 100 % the vessel trembles and the app gently insists on a release.

## Data model (persist all of it in SwiftData)

```swift
@Model StressDrop     { date, intensity(1–3), units, note, released }
@Model ReleaseSession { date, cycles, drainedUnits }
```

Derived, never stored: current level = Σ units of unreleased drops capped at 24; journey progress = ReleaseSession count. Widget state (fill fraction + state line) mirrored to the App Group on every mutation. Small preferences (vessel style, sound on, onboarded) in AppStorage.

## Deliverables & output format

1. The complete runnable project: `project.yml`, all Swift sources (app + widget), asset catalog with generated art.
2. **`ASSETS.md`** — the Higgsfield asset log (path, spec, prompt), as described above.
3. **`README.md`** — how to open, run, and where everything lives.
4. This **`MASTER_PROMPT.md`** kept in the repo as the product's source of truth.

## Non-negotiables (self-check before you finish)

- [ ] Compiles after `xcodegen generate` + signing team, first Cmd+R, simulator included.
- [ ] No TODO / stub / placeholder anywhere; every listed feature works and persists.
- [ ] The liquid sloshes with device tilt AND keeps momentum (damped spring) — not a looping GIF-style animation.
- [ ] Haptics + synthesized sound on drop impact, breathing transitions, and completion.
- [ ] Widgets show the live fill level after every mutation.
- [ ] Mascot poses are real Higgsfield art (vector fallback only on generation failure), logged in ASSETS.md.
- [ ] UI reads like a whisper: minimal Lithuanian microcopy, calm motion, one accent color, premium for a 29–55 audience.

Build the entire thing now. Do not ask clarifying questions — use your full creative and technical judgment, make excellent opinionated choices, and ship the best complete app you're capable of.
