# STARTER PACK — MCP-Driven Closed-Loop Development

A reusable setup for running a product the way Capsy is run: **the AI agent
(Claude Code) reads real usage data, proposes what to build, builds it, ships
it to TestFlight, and reads the results again.** Humans decide; the agent
executes and reports.

Total cost: **$0/month** on free tiers (plus the $99/yr Apple Developer
Program you already have). Verified July 2026.

---

## 0. The loop (what you're setting up)

```
users → analytics events + in-app surveys ─┐
TestFlight → crashes + tester screenshots  ├─→ Claude (weekly cron):
Slack #beta → [+]/[–]/[?] one-liners       ┘   reads all three via MCP/API
                                                ↓
                                       insight report → Slack
                                                ↓
                                       proposed backlog → GitHub Issues
                                                ↓  (human approves)
                                       Claude builds → CI → TestFlight
                                                ↓
                                       …loop repeats
```

Two rules make this work:
1. **Every data source must be agent-readable** (official MCP server or a
   plain token API). No dashboards-only tools.
2. **The agent never ships without a human approval gate** (PR review or an
   explicit "go" in Slack).

---

## 1. Accounts checklist (one-time, ~1 hour total)

| # | Account | Plan | Who | Time | Needed for |
|---|---|---|---|---|---|
| 1 | GitHub org/repo | Free | — | done | code, issues, CI |
| 2 | Apple Developer Program | $99/yr | owner | done | TestFlight, Xcode Cloud |
| 3 | PostHog (EU cloud: eu.posthog.com) | Free — 1M events, 1.5k survey responses, flags | anyone | 10 min | analytics + in-app surveys + feature flags |
| 4 | Tally.so | Free — unlimited responses | anyone | 5 min | longer surveys / NPS |
| 5 | App Store Connect API key | included | Admin in ASC | 5 min | TestFlight data for the agent |
| 6 | Slack channel `#<app>-beta` | Free | anyone | 2 min | human feedback intake |
| 7 | (later, at public beta) Sentry | Free — 5k errors/mo | dev | 15 min | crash triage with AI root-cause |
| 8 | (later, at revenue) RevenueCat | Free to $2.5k MTR | dev | 30 min | subscription metrics |

**ASC API key (step 5):** App Store Connect → Users and Access →
Integrations → App Store Connect API → Team Keys → "+". Role: **Developer**
(read is enough for the loop). Download the `.p8` once (it can't be
re-downloaded), note the **Key ID** and **Issuer ID**. Hand all three to the
agent operator as secrets — never commit them.

---

## 2. Wire the MCP connections (agent side, ~15 min)

In the Claude Code environment (or claude.ai connector settings):

```bash
# PostHog — official hosted MCP (OAuth in browser on first use)
claude mcp add --transport http posthog https://mcp.posthog.com/mcp

# Sentry — when you add it (phase 2)
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# RevenueCat — when you add it (phase 3)
claude mcp add --transport http revenuecat https://mcp.revenuecat.ai/mcp

# GitHub MCP — usually already present in Claude Code environments
```

**App Store Connect has no official MCP** — use the 10-line JWT script
instead (the agent runs it itself). Store `ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_P8` as environment secrets, then:

```python
# asc_token.py — mint a 20-min ASC API token
import jwt, time, os
token = jwt.encode(
    {"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()),
     "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
    os.environ["ASC_P8"], algorithm="ES256",
    headers={"kid": os.environ["ASC_KEY_ID"]})
print(token)
```

Key endpoints the loop reads:
- `GET /v1/builds/{id}/metrics/betaBuildUsages` — installs, sessions, crashes per build
- `GET /v1/betaFeedbackScreenshotSubmissions` — tester screenshots + comments + device/OS
- `GET /v1/betaFeedbackCrashSubmissions` (+ `/crashLog`) — crash feedback with logs

---

## 3. Event tracking plan (put this in the app before public beta)

Naming: `object_verb`, lowercase, snake_case. **Never send:** note text,
health values, emails, names — IDs are anonymous. Keep the whole plan at
~12 events; more means nobody looks at any of them.

| Event | Properties | Answers |
|---|---|---|
| `app_opened` | source (icon/widget/notification) | DAU, notification effectiveness |
| `onboarding_completed` | vessel_chosen | activation rate |
| `onboarding_abandoned` | page | where onboarding leaks |
| `drop_logged` | intensity, source (app/widget) | core action frequency |
| `ritual_started` | fill_fraction | do people release early or full? |
| `ritual_completed` | breaths, duration_s | core loop completion |
| `ritual_abandoned` | at_breath | where the ritual loses people |
| `quest_chest_opened` | reward | reward loop engagement |
| `shop_item_bought` | item_id, price | economy sink usage |
| `paywall_shown` | source (onboarding/shop/habits) | funnel top |
| `trial_started` | plan | conversion mid-funnel |
| `purchase_completed` | plan | revenue |

North-star weekly readout: **D1/D7 retention · ritual completion % ·
paywall→trial % · rituals per active user**.

In-app survey (PostHog, iOS SDK): one question, shown after the 3rd
completed ritual — *"Did that actually calm you down?"* (1–5 + optional
line). 1,500 responses/mo free is plenty.

---

## 4. CI/CD lanes

- **TestFlight lane → Xcode Cloud** (25 free compute h/mo, included with the
  Apple membership). Configure once in Xcode: Product → Xcode Cloud → Create
  Workflow → branch = main, Action = Archive + TestFlight (internal). Every
  merged PR auto-lands in testers' hands. No certificates, no Fastlane.
- **PR checks → GitHub Actions**, but remember **macOS minutes bill at 10×**
  (2,000 free min = ~200 macOS min/mo). Keep the heavy visual-matrix job
  `workflow_dispatch` (on-demand) + before releases, not on every push.
- Screenshots/visual QA: the committed-screenshots pattern from this repo's
  `.github/workflows/build.yml` — agent reads the images and critiques its
  own UI.

---

## 5. The weekly loop ritual (cron the agent runs)

Create a scheduled routine (Claude Code cron / Routine) — every Monday 09:00:

> Pull the last 7 days: (1) PostHog — DAU, D1/D7 retention, ritual
> completion funnel, paywall→trial conversion, survey responses;
> (2) App Store Connect — new TestFlight crashes and screenshot feedback;
> (3) Slack #capsy-beta — new [+]/[–]/[?] messages. Synthesize a report:
> 5 headline numbers with week-over-week deltas, top 3 user complaints
> verbatim, 1 anomaly worth investigating. Post it to #capsy-beta. Then
> propose up to 5 backlog items as DRAFT GitHub issues labeled
> `loop-proposed`, each with evidence (which metric/quote motivates it) and
> an effort guess (S/M/L). Do NOT start building anything.

Human ritual (10 min): read the report, promote 1–3 issues from
`loop-proposed` to `approved`. A second routine (or a message to the agent)
picks up `approved` issues → branch → build → PR → CI green → merge →
Xcode Cloud → TestFlight. The PR review is the safety gate.

---

## 6. Rules for the agent (put in the repo's CLAUDE.md)

```markdown
## Loop rules
- Autonomous: reading analytics/feedback, drafting reports, opening
  `loop-proposed` issues, building `approved` issues, fixing red CI.
- Needs human approval: merging to main, changing prices/paywall,
  changing the privacy policy, deleting data, posting anywhere public.
- Every feature PR must state which metric it is expected to move.
- Never add tracking of personal content (notes, health values).
- New third-party SDK = explicit human sign-off (privacy stance).
```

---

## 7. Reusing this pack on a new project

1. Copy this file into the new repo; do steps 1–2 (30 min).
2. Write the 12-event plan first — before building features.
3. Ship the smallest possible build to TestFlight, wire the Monday cron.
4. From then on the rhythm is fixed: **ship Thursday, measure the weekend,
   read Monday, decide, build.** One loop per week.

## Phase gates (don't over-instrument early)

| Phase | Users | Stack |
|---|---|---|
| Internal test | ~10 | TestFlight only + moderated sessions + Slack. NO SDKs — 10 people is not data, talk to them instead |
| Public beta | 100+ | + PostHog (events + 1 survey) + Tally NPS + privacy policy update |
| Launch/scale | 1k+ | + Sentry, + RevenueCat, + ASO rank cron, + Firecrawl competitor monitors |
