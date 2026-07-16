# ASSETS.md — Higgsfield asset pipeline log

Visi vizualiniai asset'ai sugeneruoti gyvai per **Higgsfield MCP** (`generate_image`,
modelis `nano_banana_pro`, 1024×1024 PNG). Skysčio animacija sąmoningai procedūrinė
(SwiftUI Canvas) — ji reaguoja į gyvus sensorių duomenis 120 fps.

Stilius — **gyva tyla V4.5 design book**: matinis molis, koralas `#E8865C` ant
kreminio smėlio `#EDE4D6`, vienas kietas cartoon šešėlis, soft-voxel (ne retro).

**Užrakintas personažo aprašymas** (pažodžiui kiekviename maskoto prompt'e — visos
pozos yra vienas personažas):

> Capsy, a cute minimal voxel-art water droplet character made of small matte clay
> cubes in warm coral (#E8865C), rounded teardrop silhouette, two large dark square
> eyes (#2B2620), tiny mouth, soft warm studio lighting, one single hard flat cartoon
> shadow beneath, plain warm cream background (#EDE4D6), centered, no text,
> soft-voxel not retro.

| Failas | Formatas | Pozos prompt'o priedas |
|---|---|---|
| `AppIcon.appiconset/icon.png` | 1024×1024 PNG, RGB (alpha nuimta — App Store reikalavimas) | *(atskiras prompt'as)* „Minimal voxel art iOS app icon: a small transparent glass bucket filled with calm warm coral clay-colored liquid (#E8865C) with a gentle wave surface, one tiny coral droplet falling above it, one single hard flat cartoon shadow beneath, plain warm cream background (#EDE4D6), soft warm studio lighting, isometric 3D soft-voxel style (not retro), extremely clean calm Baltic minimal 'living silence' aesthetic, no text, no border, centered composition" |
| `MascotCalm.imageset/MascotCalm.png` | 1024×1024 PNG | „Pose: calm and content, gentle happy smile, relaxed upright posture" |
| `MascotBusy.imageset/MascotBusy.png` | 1024×1024 PNG | „Pose: slightly worried expression, one small sweat cube on forehead, tiny lean to the side" |
| `MascotHeavy.imageset/MascotHeavy.png` | 1024×1024 PNG | „Pose: sad and heavy expression, drooping downward, eyes half closed, slightly darker muted clay cubes" |
| `MascotRelief.imageset/MascotRelief.png` | 1024×1024 PNG | „Pose: blissful relief, eyes closed happily as gentle arcs, big relieved smile, a few tiny clay sparkle cubes floating around" |

Visi keliai — `Capsy/Assets.xcassets/`. Kodas pozas pasiima pagal
`MascotMood.rawValue` (`Capsy/Views/MascotView.swift`); jei imageset'o nėra,
rodomas vektorinis fallback'as — programa veikia ir be PNG.

*Istorija: v1 asset'ai buvo teal `#5FD4C4` ant tamsios samanos `#0E1512`; v2
pergeneruoti pagal gautą gyva-tyla-v45 design book (molis/koralas/smėlis).*
