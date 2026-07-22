# ASO.md — App Store metadata (copy-paste into App Store Connect)

Final metadata, decided 2026-07-20 after keyword research (Appfigures, AppTweak,
ASOMobile, SplitMetrics, iTunes Search API teardowns). Rationale at the bottom.

## The three indexed fields (one 160-char keyword pool, zero repeated words)

**App Name** (30 max — heaviest ranking weight):

```
Capsy: Stress Relief Pet
```

**Subtitle** (30 max — medium weight, disjoint keyword cluster):

```
Breathe, Calm Anxiety & Habits
```

**Keyword field** (100 max, comma-separated, no spaces after commas — safety net):

```
self care,mood,relax,mindfulness,worry,tension,panic,mental health,unwind,breathing,burnout,sleep
```

**Primary category:** Health & Fitness (the category word indexes automatically —
never spend characters on "wellness"/"health" elsewhere).

**On-device display name** stays `Capsy` (short under the icon); the long name is
App Store-only.

## Why exactly this (evidence-backed)

- **`Brand: Keyword Keyword` colon formula** is the wellness-category standard
  and what every character-based app uses: "Finch: Self-Care Pet",
  "Headspace: Sleep & Meditation", "Rootd: Panic Attacks & Anxiety".
- **"stress relief"** appears in 8/10 of the top results for that query yet is
  not brand-locked (the top slots are fidget games and giants ranking via
  subtitle) — clear-intent head term, winnable.
- **"pet"** claims the Finch-created "self-care pet" demand without colliding
  with the contested exact string "Self-Care Pet" (Finch #1 + 4 verbatim
  clones). Nobody owns the exact phrase "stress relief pet" — Capsy becomes
  the only exact match.
- **"anxiety"** is the one battleground term multiple sources flag as
  high-traffic but under-competed below the Calm/Headspace duopoly — it gets
  the subtitle's strongest slot. "breathe" + "habits" complete the cluster
  (Balance's subtitle "Breathe, calm anxiety & stress" validates the pattern).
- **Name and subtitle share zero words** — Apple gives no weight to repetition,
  so every character indexes something new. Keyword field avoids all
  name/subtitle words, plurals, "app", and the category name.
- **Not spent on:** "calm" as a name word (branded traffic owned by Calm app),
  "meditation" (difficulty ~100), "wellness"/"self care" in the name (head-term
  demand declining since 2024; "self care" sits in the keyword field instead).
- Title keywords rank ~2× better than keyword-field ones (Incipia study:
  keyword moved from field to title jumped #23 → #3), and ~65% of App Store
  downloads start from search (Apple's own figure) — the name is the single
  highest-leverage ASO asset.

## Screenshot captions (indexed via OCR since Apple's 2025 update)

Put a keyword-bearing caption at the TOP of each App Store screenshot:

1. "Your stress, poured into a pet" (home)
2. "Breathe out — watch it evaporate" (ritual)
3. "Gentle streaks, no guilt" (HUD/quest)
4. "Earn calm rewards" (shop)
5. "Your week, in stillness" (journey)

## Fallback names (if ASC rejects the primary — reserved names aren't publicly checkable)

1. `Capsy: Stress Relief Buddy`
2. `Capsy — Stress Relief Pet`
3. `Capsy: Anti-Stress Pet`

Bundle ID `com.getcapsy.app` never changes regardless of display/store name.
