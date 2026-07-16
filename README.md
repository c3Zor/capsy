# Capsy — streso kibirėlis 🪣

Stresas — tai skystis. Jis kaupiasi lašas po lašo, teliuskuoja pakreipus telefoną
ir niekur nedingsta pats — jį reikia sąmoningai išpilti kvėpavimo ritualu.
Permatomas voxel indas su gyvu vandeniu, „gyva tyla“ stiliumi.

## Paleidimas (2 komandos)

```bash
brew install xcodegen        # jei dar neturi
xcodegen generate && open Capsy.xcodeproj
```

Xcode: pasirink savo *Signing Team* abiem target'ams (Capsy ir CapsyWidget) — ir Run.
Veikia ir simuliatoriuje (be tilt'o vanduo tiesiog ramiai banguoja).

## Kas viduje

| Funkcija | Kur |
|---|---|
| Gyvas teliuskuojantis skystis (CoreMotion tilt + slopinama spyruoklė, lašai, purslai, burbulai) | `Capsy/Views/BucketView.swift` |
| Pagrindinis ekranas: lygis %, `+ Lašas`, `Išleisti` | `Capsy/Views/HomeView.swift` |
| Išleidimo ritualas — kvėpavimas 4 s įkvėpk / 6 s iškvėpk × 4, indas tuštėja iškvepiant | `Capsy/Views/ReleaseView.swift` |
| Ramybės kelias (etapai), savaitės grafikas, lašų istorija | `Capsy/Views/JourneyView.swift` |
| Lock Screen + Home Screen widget'ai (užpildymo lygis) | `CapsyWidget/CapsyWidget.swift` |
| SwiftData modeliai + kibirėlio logika | `Capsy/Models.swift` |
| Bendra būsena su widget'u (App Group) | `Shared/SharedState.swift` |

Talpa: 24 vnt. Lašas: lengvas 2 / vidutinis 4 / sunkus 6 vnt.
Widget'ai atsinaujina po kiekvieno pakeitimo (`WidgetCenter.reloadAllTimelines`).

Pilnas produkto aprašymas — [`MASTER_PROMPT.md`](MASTER_PROMPT.md).

## Technologijos

Swift 5.9 · SwiftUI · SwiftData · WidgetKit · CoreMotion · Swift Charts ·
Canvas + TimelineView (procedūrinė voxel animacija, jokių priklausomybių) ·
XcodeGen. Minimalus iOS: 17.0.
