# TestFlight — vidinis team testas (≈30 min tavo laiko)

## 1. Bundle ID į tavo team'ą (vieną kartą)

`project.yml` pakeisk dvi eilutes ir perleisk generatorių:

```yaml
# targets.Capsy.settings.base:
PRODUCT_BUNDLE_IDENTIFIER: com.TAVODOMENAS.capsy        # pasirink savo
DEVELOPMENT_TEAM: XXXXXXXXXX                             # Team ID iš developer.apple.com/account
# targets.CapsyWidget.settings.base:
PRODUCT_BUNDLE_IDENTIFIER: com.TAVODOMENAS.capsy.widget
DEVELOPMENT_TEAM: XXXXXXXXXX
```

```bash
xcodegen generate && open Capsy.xcodeproj
```

Xcode → abiem target'ams Signing & Capabilities → „Automatically manage signing" ✓.
(App Group `group.com.capsy.shared` pervadink į `group.com.TAVODOMENAS.capsy` project.yml
faile IR `Shared/SharedState.swift` konstantoje — jie turi sutapti.)

## 2. App Store Connect įrašas (vieną kartą)

1. appstoreconnect.apple.com → My Apps → „+" → New App
   - Platform iOS · Name **Capsy** · Bundle ID (tas pats) · SKU `capsy-001`
2. In-App Purchases → sukurk 3 produktus TIKSLIAI šiais ID:
   - `com.capsy.plus.monthly` — Auto-Renewable, grupė „Capsy Plus", €2.99, 7 d. free trial
   - `com.capsy.plus.yearly` — Auto-Renewable, ta pati grupė, €19.99, 7 d. trial
   - `com.capsy.plus.lifetime` — Non-Consumable, €49.99
   (Pastaba: jei keiti bundle ID prefiksą, produktų ID gali likti tokie — jie nepriklauso nuo bundle.)
3. Agreements → Paid Applications sutartis (jei dar nepasirašyta).

## 3. Upload (kiekvienam build'ui, ~5 min)

Xcode: pasirink **Any iOS Device (arm64)** → Product → **Archive** →
Organizer → **Distribute App** → App Store Connect → Upload (viskas default).

## 4. TestFlight paskirstymas

App Store Connect → Capsy → TestFlight → Internal Testing → „+" grupė
„Team" → pridėk teamo Apple ID email'us (iki 100 vidinių testuotojų,
be Apple review) → pažymėk įkeltą build'ą. Komanda gauna kvietimą
TestFlight app'e per ~5 min.

## 5. Ką testuotojams duoti išbandyti (pirmos savaitės scenarijus)

1. Onboarding → kūno pasirinkimas → Plus intro (praleisti ar pabandyti trial — StoreKit sandbox, pinigai nejuda)
2. 3–4 lašai per dieną (skirtingi intensyvumai, su pastabom)
3. Vakare RELEASE ritualas (garsas įjungtas!)
4. Widget'ai: Home Screen (su + mygtuku) ir Lock Screen
5. Parduotuvė: uždirbti aukso, nusipirkti kepurę
6. Habits: pažymėti bent 2/dieną
7. iPhone pakreipimas — teliuskavimas

Feedback rinkti tiesiog TestFlight „Send Feedback" (screenshot + komentaras
atkeliauja tiesiai į App Store Connect).
