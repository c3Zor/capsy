# ASSETS.md — Higgsfield asset pipeline log

All visual assets were generated live through the **Higgsfield MCP**
(`generate_image`, model `nano_banana_pro`, 1024×1024 PNG). The liquid
animation is deliberately procedural (SceneKit / SwiftUI Canvas) — it reacts
to live sensor data at up to 120 fps.

Style — the **gyva tyla V4.5 design book**: matte clay, coral `#E8865C` on
cream sand `#EDE4D6`, one hard cartoon shadow, soft-voxel (not retro).

**Locked character description** (repeated verbatim in every mascot prompt —
so all poses are one character):

> Capsy, a cute minimal voxel-art water droplet character made of small matte clay
> cubes in warm coral (#E8865C), rounded teardrop silhouette, two large dark square
> eyes (#2B2620), tiny mouth, soft warm studio lighting, one single hard flat cartoon
> shadow beneath, plain warm cream background (#EDE4D6), centered, no text,
> soft-voxel not retro.

| File | Format | Pose prompt suffix |
|---|---|---|
| `AppIcon.appiconset/icon.png` | 1024×1024 PNG, RGB (alpha stripped — App Store requirement) | *(separate prompt)* "Minimal voxel art iOS app icon: a small transparent glass bucket filled with calm warm coral clay-colored liquid (#E8865C) with a gentle wave surface, one tiny coral droplet falling above it, one single hard flat cartoon shadow beneath, plain warm cream background (#EDE4D6), soft warm studio lighting, isometric 3D soft-voxel style (not retro), extremely clean calm Baltic minimal 'living silence' aesthetic, no text, no border, centered composition" |
| `MascotCalm.imageset/MascotCalm.png` | 1024×1024 PNG | "Pose: calm and content, gentle happy smile, relaxed upright posture" |
| `MascotBusy.imageset/MascotBusy.png` | 1024×1024 PNG | "Pose: slightly worried expression, one small sweat cube on forehead, tiny lean to the side" |
| `MascotHeavy.imageset/MascotHeavy.png` | 1024×1024 PNG | "Pose: sad and heavy expression, drooping downward, eyes half closed, slightly darker muted clay cubes" |
| `MascotRelief.imageset/MascotRelief.png` | 1024×1024 PNG | "Pose: blissful relief, eyes closed happily as gentle arcs, big relieved smile, a few tiny clay sparkle cubes floating around" |

All paths — `Capsy/Assets.xcassets/`. The code looks poses up via
`MascotMood.rawValue` (`Capsy/Views/MascotView.swift`); if an imageset is
missing, a vector fallback renders — the app works without the PNGs.

*History: v1 assets were teal `#5FD4C4` on dark moss `#0E1512`; v2 was
regenerated to match the gyva-tyla-v45 design book (clay/coral/sand).*
