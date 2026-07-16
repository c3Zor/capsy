# ASSETS.md — Higgsfield asset pipeline log

Visi vizualiniai asset'ai sugeneruoti gyvai per **Higgsfield MCP** (`generate_image`).
Skysčio animacija sąmoningai procedūrinė (SwiftUI Canvas) — ji reaguoja į gyvus
sensorių duomenis 120 fps, ko iš anksto sugeneruoti asset'ai negali.

**Užrakintas personažo aprašymas** (naudotas pažodžiui kiekviename maskoto prompt'e,
kad visos pozos būtų vienas personažas):

> Capsy, a cute minimal voxel-art water droplet character made of small glossy teal
> cubes (#5FD4C4), rounded teardrop silhouette, two large dark square eyes, tiny mouth,
> soft ambient lighting, plain dark moss-green background (#0E1512), centered, no text.

| Failas | Dydis / formatas | Modelis | Pozos prompt'o priedas |
|---|---|---|---|
| `Capsy/Assets.xcassets/AppIcon.appiconset/icon.png` | 1024×1024 PNG (RGB, alpha nuimta pagal App Store reikalavimą) | nano_banana_pro | *(atskiras prompt'as)* „Minimal voxel art iOS app icon: a small cute wooden bucket filled with calm glowing teal liquid with a gentle wave surface, one tiny teal droplet falling above it, soft dark moss-green background, soft ambient lighting, isometric 3D voxel style, extremely clean calm 'living silence' aesthetic, no text, no border, centered composition" |
| `Capsy/Assets.xcassets/MascotCalm.imageset/MascotCalm.png` | 1024×1024 PNG | nano_banana_pro | „Pose: calm and content, gentle happy smile, relaxed upright posture" |
| `Capsy/Assets.xcassets/MascotBusy.imageset/MascotBusy.png` | 1024×1024 PNG | nano_banana_pro | „Pose: slightly worried expression, one small sweat cube on forehead, tiny lean to the side" |
| `Capsy/Assets.xcassets/MascotHeavy.imageset/MascotHeavy.png` | 1024×1024 PNG | nano_banana_pro | „Pose: sad and heavy expression, drooping downward, eyes half closed, slightly darker desaturated teal cubes" |
| `Capsy/Assets.xcassets/MascotRelief.imageset/MascotRelief.png` | 1024×1024 PNG | nano_banana_pro | „Pose: blissful relief, eyes closed happily as gentle arcs, big relieved smile, a few tiny sparkle cubes floating around" |

Kodas pozas pasiima pagal pavadinimus per `MascotMood.rawValue`
(`Capsy/Views/MascotView.swift`); jei imageset'o nėra, rodomas vektorinis fallback'as —
programa kompiliuojasi ir veikia ir be šių PNG.
