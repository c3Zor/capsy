# TestFlight — internal team test (≈30 min of your time)

## 1. Bundle ID under your team (once)

Change two lines in `project.yml` and re-run the generator:

```yaml
# targets.Capsy.settings.base:
PRODUCT_BUNDLE_IDENTIFIER: com.getcapsy.app              # already set — just add the team
DEVELOPMENT_TEAM: XXXXXXXXXX                             # Team ID from developer.apple.com/account
# targets.CapsyWidget.settings.base:
PRODUCT_BUNDLE_IDENTIFIER: com.getcapsy.app.widget
DEVELOPMENT_TEAM: XXXXXXXXXX
```

```bash
xcodegen generate && open Capsy.xcodeproj
```

Xcode → for both targets, Signing & Capabilities → "Automatically manage signing" ✓.
(The App Group is `group.com.getcapsy.shared` — already consistent in
`project.yml` and `Shared/SharedState.swift`. Register it as-is in the portal.)

## 2. App Store Connect record (once)

1. appstoreconnect.apple.com → My Apps → "+" → New App
   - Platform iOS · Name: **Capsy: Stress Relief Pet** ("Capsy" alone is taken; full metadata + fallbacks in `ASO.md`) · Bundle ID `com.getcapsy.app` · SKU `capsy-001`
   - Subtitle: **Breathe, Calm Anxiety & Habits** · Keyword field: see `ASO.md` (copy-paste ready)
2. In-App Purchases → create 3 products with EXACTLY these IDs:
   - `com.capsy.plus.monthly` — Auto-Renewable, group "Capsy Plus", €2.99, 7-day free trial
   - `com.capsy.plus.yearly` — Auto-Renewable, same group, €19.99, 7-day trial
   - `com.capsy.plus.lifetime` — Non-Consumable, €49.99
   (Note: even if you change the bundle ID prefix, the product IDs can stay
   as-is — they are independent of the bundle.)
3. Agreements → sign the Paid Applications agreement (if not signed yet).

## 3. Upload (each build, ~5 min)

Xcode: select **Any iOS Device (arm64)** → Product → **Archive** →
Organizer → **Distribute App** → App Store Connect → Upload (all defaults).

## 4. TestFlight distribution

App Store Connect → Capsy → TestFlight → Internal Testing → "+" group
"Team" → add your teammates' Apple ID emails (up to 100 internal testers,
no Apple review needed) → tick the uploaded build. The team gets the invite
in the TestFlight app within ~5 min.

## 5. What to ask testers to try (week-one script)

1. Onboarding → body choice → Plus intro (skip it or try the trial — StoreKit sandbox, no money moves)
2. 3–4 drops a day (different intensities, with notes)
3. The RELEASE ritual in the evening (sound on!)
4. Widgets: Home Screen (with the + button) and Lock Screen
5. Shop: earn gold, buy a hat
6. Habits: tap at least 2 a day
7. Tilt the iPhone — the slosh

Collect feedback via TestFlight "Send Feedback" (screenshot + comment lands
straight in App Store Connect).
