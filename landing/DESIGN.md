# DESIGN.md — Capsy landing

Direction: warm consumer calm — "gyva tyla" Baltic minimal with soft-voxel 3D accents (Habitica's
structure, none of its noise)

Palette (day): bg #EDE4D6, surface #F4EDE2, text #2B2620, muted #8A7E6E, primary #E8865C,
accent #C4633C, border rgba(43,38,32,.12)
Palette (night): bg #191511, surface #211B15, text #EDE4D6, muted #9C8F7D, primary #F0A06E
Mode: both (prefers-color-scheme + manual ☾ toggle)

Type: display — system black, font-stretch condensed, ALL CAPS, clamp(44px→96px); heading — 700
condensed caps; body — 17/1.6 regular; mono — ui-monospace 12px letter-spacing .18em for labels;
scale ~1.25

Spacing: base 4px; section padding 96–128px; card padding 28px
Radius: 20px cards, 999px pills   Shadow: one hard cartoon shadow (0 18px 0 -6px rgba(43,38,32,.14))
— no soft blur stacks

Motion: 150/250/400ms ease-out; floating voxel cubes drift upward and dissolve (the app's
"stress evaporates" moment); breathing scale (12/min) on the hero mascot; respect reduced-motion

Components: buttons — coral pill, ink outline secondary; cards — surface + hard shadow + 1px border;
nav — transparent → surface on scroll

Signature detail: CSS 3D voxel cubes (real 6-face transforms) rising through sections like steam;
mono ALL-CAPS haiku microcopy ("CALM." · "FILLING UP…" · "THE WAVE HAS PASSED.")
