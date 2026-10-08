# RigRoom — Implementation Plan

Oct 6, 2026 · @Mark

## Summary

R0 Pilot ships to about 10 testers in March 2027 and passes its accuracy gate by April 18, 2027; R1 public beta follows in September 2027, timed for the fall snowbird migration when Cracker Barrel overnights peak. The plan assumes 15–20 hours a week of solo development alongside a full-time job, with Claude Code doing most of the implementation.

Three sequencing bets shape the order of work:

- **Data before app.** The pipeline and scoring are built first (Oct–Dec), because the R0 gate measures AI accuracy, not app polish. The MAUI app is built on top of real pilot data (Jan–Mar).
- **Ground truth early.** A field trip on US-50 in November collects measured sites before the classifier is tuned, so accuracy can be tested against a holdout set rather than sites the prompts were tuned on.
- **Kill the two platform risks in week 1.** Mapsui offline rendering and Valhalla on Container Apps are spiked before any app code is written, so a fallback costs days, not months.

[embedded content: release roadmap · 4 releases, 3 gates]

R0 and R1 are planned in detail below; R2 and R3 dates are placeholders until the R1 gate has real renewal data.

## Assumptions and defaults

The plan picks a working default for each open question that blocks R0, so work can start now; any default can be overturned at the date listed under Decisions.

| Topic | Default this plan assumes | Why |
| --- | --- | --- |
| Capacity | 15–20 h/week, solo, Claude Code in VS Code on Mac | Day job continues; dates scale linearly if hours change |
| Launch wedge | Corridors first in R0, Cracker Barrel first in R1 | Follows the PRD release order |
| Brand | Standalone app; 360° video footage reused as field evidence only | Keeps R0 scope tight; merge decision deferred to R1 |
| Utah corridors | I-15 and I-80 (to be confirmed) | Named as examples in the brief; both connect to US-50 trips |
| Classifier | Vision LLM on tiles first, segmentation model later | Matches brief; no labels exist yet to train on |
| Routing | Self-hosted Valhalla; Azure Maps truck routing if the spike fails | PRD decision |
| Auth0 timing | In R0, not R1 | The PRD lists FR-02 as R0 but the scope table lists accounts in R1; check-ins and the admin queue need identities, so R0 wins |
| Store-list source | ScrapeHero, pending license check | Only needed in R1 |
| Rig-fit margin | 10 ft, user-adjustable later | PRD proposal |
| Environments | dev and prod only until R1 | Cost; staging added before public beta |

## Solution and repo structure

One monorepo holds the .NET solution, the Python pipeline, dbt, and Bicep, so Claude Code sees the whole system and one PR can change a contract and both its producer and consumer.

```text
rigroom/
  src/
    RigRoom.Domain/        rig profile, rig-fit rule, confidence labels, linear referencing (NTS)
    RigRoom.Contracts/     DTOs + validation shared by API, MAUI, Blazor
    RigRoom.ApiClient/     typed HTTP client, offline outbox interfaces
    RigRoom.Data/          EF Core + NetTopologySuite, migrations
    RigRoom.Api/           minimal APIs, route groups per feature
    RigRoom.Mobile/        .NET MAUI, XAML + CommunityToolkit.Mvvm, Mapsui
    RigRoom.Web/           Blazor WASM: trip planner + admin queue, MapLibre via JS interop
  pipeline/
    ingest/               Python: HPMS, NTAD, state DOT layers -> evidence
    candidates/           Python: corridor buffers, lay-bys, wide shoulders
    imagery/              Python: NAIP / commercial tiles, vision classification
    terrain/              Python: 3DEP slope and cross-slope
    packs/                Planetiler basemap + SQLite site pack per corridor
    dbt/                  evidence -> attribute values -> scores
  infra/                  Bicep modules + per-environment parameter files
  tests/                  .NET unit + integration (Testcontainers PostGIS)
  docs/                   ADRs, CLAUDE.md, field protocol
```

Three design choices keep the pieces decoupled:

- **The database is the contract between pipeline and app.** Python jobs and dbt write `evidence` and `scores`; the API only reads them. Neither side calls the other.
- **Corridor packs are two files.** A basemap tile pack (format chosen by the Mapsui spike) plus a SQLite site pack holding sites, scores, evidence summaries, thumbnails, and the route line with each site's distance along it. Drive mode only needs NetTopologySuite and SQLite on the device.
- **Check-ins use an outbox.** Each check-in gets a client GUID, is written to local SQLite first, and is retried until the API confirms; photos upload to Blob through short-lived SAS URLs. The GUID makes retries idempotent.

A `CLAUDE.md` at the repo root records conventions (minimal API style, EF migration rules, dbt naming, never import OSM-derived data into resale tables) so every Claude Code session starts with them.

## R0 Pilot plan

R0 runs 27 weeks, from October 12, 2026 to the accuracy gate on April 18, 2027, with a two-week holiday gap. Each milestone ends with something runnable, so a slip shows up within two weeks.

[embedded content: R0 pilot timeline · 8 milestones, 1 gate]

Work after the holiday break runs in sequence, so any slip from January on moves the gate by the same amount; the November trip overlaps ingest and scoring.

| Milestone | Deliverables | Exit criteria | FRs |
| --- | --- | --- | --- |
| M0 Foundations and spikes | Repo, CI, dev environment in Bicep, PostGIS, Auth0 tenant; Mapsui offline spike; Valhalla spike | Mapsui renders an offline US-50 pack on a real phone in airplane mode; Valhalla returns a truck route Reno–Ely sized for a 60 ft rig | — |
| M1 Data core and ingest | Site, Evidence, Source, Score, Check-in, Approach tables; HPMS, NTAD, NDOT and UDOT layers ingested for pilot corridors; LLM schema mapper | Every pilot-corridor segment has shoulder evidence; source license flags set on every row | — |
| M1b Ground-truth trip 1 | Drive US-50 Reno–Ely with the 360° camera; log every pullout with GPS, measured length, surface, photos | 50+ measured sites, split into tuning and holdout sets | — |
| M2 Candidates, AI and scoring | Candidate generation, NAIP classification, 3DEP slope, commercial strip purchase, dbt scoring models | Every candidate on the three corridors has both scores; first accuracy read on the tuning set | — |
| M3 API, routing and packs | Minimal API (rigs, routes, sites, check-ins), Valhalla deployed, pack builder job | A route request returns fitting stops in under 2 s; a pack downloads and opens offline | FR-03, FR-04, FR-05, FR-06 |
| M4 MAUI app | Sign-in, rig profile, plan route, stops list and map, site detail, download, drive mode, check-in, add site | TestFlight and Play internal builds in testers' hands | FR-01, FR-02, FR-07, FR-09, FR-11 |
| M5 Admin queue | Blazor WASM queue: review sites, check-ins, AI results; approve, correct, reject as evidence | Mark clears the full pilot queue in the web app | FR-12 |
| M6 Field validation | Mark plus testers drive pilot corridors; holdout sites re-measured; battery and pack sizes recorded | Gate: AI size and surface agree with field checks on 80% of holdout sites | — |

The Utah corridors join M1b only if weather allows in November; otherwise they are measured during M6 in spring, and the gate is evaluated on US-50 first.

## Data pipeline build order

The pipeline is built in the order evidence flows, and each stage writes Evidence rows before the next stage starts, so scoring works (badly) from week 5 and improves as stages land.

1. **Schema and sources (M1).** Create `site`, `evidence` (append-only), `source` (license, weight, share-alike flag), `score`, `check_in`, `approach`. Seed `source` with the weights from the brief and `attr_half_life` with the half-lives.
2. **Ingest (M1).** One Container Apps Job per source, writing raw rows to a staging schema. The LLM mapper proposes a column mapping per state layer; Mark approves it once and it is stored as config, not re-prompted on every run.
3. **Candidates (M2).** Buffer each corridor centerline, then union OSM lay-bys, DOT points, HPMS wide-shoulder segments, and NAIP detections. Deduplicate into `site` by distance and road side. Compare against the ground-truth trip log to measure recall: pullouts Mark saw that the pipeline missed.
4. **Imagery classification (M2).** Cut NAIP tiles from Planetary Computer around each candidate; prompt a vision model for usable length bucket, width, surface, and lane separation, returning JSON with its own confidence. Buy SkyWatch 30 cm strips only around candidates, then re-run classification on those tiles.
5. **Terrain (M2).** Compute slope and cross-slope inside each site polygon from 3DEP 1 m DEMs.
6. **Scoring in dbt (M2).** Models in three layers: `evidence_aged` applies the half-life decay, `attribute_value` picks the winning value per attribute, `site_score` rolls attributes into the two scores plus the maximum rig length each site fits, so short pullouts still show for small rigs. dbt tests assert both scores stay in 0–1 and every score has evidence behind it.
7. **Packs (M3).** A job rebuilds packs for corridors whose scores changed, and the API serves the latest pack version per corridor.
8. **Feedback loop (M5–M6).** Admin decisions and check-ins land as Evidence; the nightly run re-scores and rebuilds affected packs.

In SQL the combining formula becomes a sum of logs, so it runs as one aggregate:

```latex
C = 1 - \exp\left(\sum_i \ln\left(1 - w_{\text{src}(i)} f_i\right)\right)
```

The brief does not say how attribute confidences roll up into one physical-fit score. This plan proposes the minimum across length, surface, grade, and lane separation, so one weak attribute marks the whole site unverified; the permission score uses signage and policy the same way. Contested attributes, where the two sides score within 0.15 of each other, go to the verification queue (threshold to tune in M6).

## R1 Beta plan

R1 runs from April 19 to a public store launch in mid-September 2027, and starts only if R0 passes its gate. Two things must be settled before R1 code starts: the price survey in RV groups and the legal review of terms and in-app wording.

| Milestone | Deliverables | Exit criteria | FRs |
| --- | --- | --- | --- |
| R1-a Cracker Barrel data | Store list purchased and license confirmed; 1 km² imagery per lot; lot classification; 1-mile approach scoring from road geometry and clearances | All US locations have both scores and an approach score | FR-13 |
| R1-b Background driving | Automatic stop detection; background next-stop alerts with low-power location; store purpose strings | Alerts fire with the screen off on both platforms in a field test | FR-08, FR-10 |
| R1-c Accounts and billing | Stripe web checkout, entitlement sync via API, Free vs Pro gating, IAP fallback kept buildable | A tester buys Pro on the web and the phone unlocks offline packs | FR-15 |
| R1-d Web planner and reports | Blazor trip planner synced to phone; report-a-problem flow | A trip planned on desktop appears on the phone | FR-14, FR-16 |
| R1-e Launch readiness | Staging environment, face and plate blurring, account deletion, store listings, privacy policy, App Review submission | Both stores approve the background-location build | — |

The Supreme Court ruling on Apple link-out commissions is expected by June 2027, which lands mid-R1. Keep Stripe as the default and decide in July whether IAP needs to ship at launch.

## R2 and R3 outline

R2 and R3 are sketched only; each gets its own detailed plan once the previous gate has real numbers behind it.

**R2 Corridors (about Oct 2027 – Mar 2028).** Extend the pipeline to more western corridors, launch the paid verifier program (FR-18) with GPS and timestamp checks and spot audits, and add AI reading of check-in photos (FR-17). Train a segmentation model once verified labels number in the hundreds. Gate: 70% of sites on target corridors verified.

**R3 Expansion (from about Apr 2028).** Add more brands such as Walmart, build the resale-clean licensing export or API (FR-19) from rows whose sources carry no share-alike flag, and evaluate CarPlay and Android Auto (FR-20). Gate: one signed data license.

Two R3 needs should be built cheaply earlier: the share-alike flag is enforced in the schema from M1, and a nightly test in R2 counts records that would leave the export, so licensing never needs a data cleanup.

## Infrastructure and CI/CD

Everything is defined in Bicep from M0 and deployed by GitHub Actions; nothing is created by hand in the portal, so a staging environment in R1 is one new parameter file.

| Resource | R0 setting | Changes in R1 |
| --- | --- | --- |
| Container Apps environment | API (min 0 replicas), Valhalla (min 0), pipeline jobs on cron | API min 1 replica for cold-start latency |
| Container Registry | Basic tier | — |
| PostgreSQL Flexible Server + PostGIS | Burstable tier, dev and prod | Larger tier if route queries miss the 2 s target |
| Blob Storage | Packs, imagery tiles, photos (private, SAS access) | — |
| Front Door | Deferred; packs served from Blob directly | Added for public pack delivery |
| Azure Files | Valhalla routing tiles, mounted into its container | — |
| Key Vault, Application Insights | From M0 | — |

GitHub Actions workflows:

- **ci.yml** on every PR: .NET build and tests (Testcontainers PostGIS), Python lint and tests, `dbt build` against a throwaway database, Bicep `what-if`.
- **deploy.yml** on merge to main: build container images to ACR, deploy Bicep, run EF migrations, deploy API and jobs to dev; prod by manual approval.
- **mobile.yml** on tag: Android build on an Ubuntu runner to Play internal testing; iOS build on a macOS runner to TestFlight via the App Store Connect API.
- **valhalla.yml** monthly: rebuild routing tiles for Nevada and Utah from OSM extracts and swap them onto Azure Files.

## Testing and validation

The R0 gate is measured only on holdout sites the classifier never saw during tuning; otherwise an 80% pass would say more about prompt tuning than about new corridors.

**Gate protocol**

1. Ground truth: for each measured site record usable length (measuring wheel or laser rangefinder), surface class (paved, gravel, dirt), GPS of both ends, and photos. Write it up once in `docs/field-protocol.md` so testers measure the same way.
2. Split the measured sites about 40% tuning and 60% holdout, by site, before any prompt work.
3. A site passes when the surface class matches exactly and the length falls in the same bucket. Proposed buckets: under 25 ft, 25–40 ft, 40–60 ft, 60+ ft. The first three follow the PRD's small-site buckets; the PRD's 40+ bucket is split at 60 ft so towing rigs can be told apart.
4. Gate passes at 80% of holdout sites. With about 30 holdout sites a single site moves the result by over 3 points, so aim for 50 or more measured sites in total.

**Automated tests**

| Layer | What is tested | Tool |
| --- | --- | --- |
| Domain | Rig-fit rule, confidence labels, distance-along-route projection | xUnit |
| Scoring | Half-life decay, combining formula, contested-value flag, scores in 0–1 | dbt tests + pytest fixtures with known answers |
| API | Stops-along-route query, check-in idempotency, auth on every endpoint | xUnit + Testcontainers PostGIS |
| Pipeline | Each state mapper on a saved sample of real layer output | pytest |
| Mobile | View models and outbox retry logic | xUnit on the shared libraries |

**Field tests on device.** Every TestFlight build is driven at least once in airplane mode: download, drive mode, check-in, then sync on reconnect. Battery drain per hour, pack sizes, and GPS-to-screen update time are logged in M6 to set the PRD targets left open.

## Spend schedule

No large purchase happens before the step that justifies it: R0 spends about $2–3K, and the R1 Cracker Barrel spend waits for the R0 gate. Figures come from the brief's budget unless marked approximate.

| When | Milestone | Item | Cost |
| --- | --- | --- | --- |
| Oct 2026 | M0 | Apple Developer Program, Google Play registration | about $99/yr + $25 once (approximate) |
| Oct 2026 onward | M0 | Azure hosting, dev + prod | $50–100/month |
| Nov–Dec 2026 | M2 | AI processing for pilot corridors | ~$200 |
| Dec 2026 | M2 | SkyWatch 30 cm strips around NAIP candidates, after license check | ~$600 |
| Mar–Apr 2027 | M6 | Field verification of 100–200 pilot sites (tester bounties) | ~$1–2K |
| Apr 2027 | Before R1 | Legal review of terms, wording, data licenses | ~$2–5K |
| May 2027 | R1-a | Cracker Barrel store list | $85 + quarterly refresh |
| May–Jun 2027 | R1-a | Imagery for ~658 lots | ~$12.5K |
| Jun–Aug 2027 | R1-a | AI processing, national | ~$2K |
| Jun–Sep 2027 | R1 | Verification bounties, about 2,000 sites | ~$10–20K |
| From Sep 2027 | R1 | Azure hosting with staging and Front Door | $150–300/month |

The $10–20K bounty line is the largest discretionary cost. It can be phased by state after launch rather than paid up front, since the PRD places the verifier program itself in R2.

## Risks, spikes and fallbacks

Each risk below has a test that answers it and a date by which the fallback is chosen, so no risk stays open longer than one milestone.

| Risk | Test | Decide by | Fallback |
| --- | --- | --- | --- |
| Mapsui offline vector rendering too slow or unsupported for the chosen tile format | M0 spike: render a US-50 pack offline on a mid-range Android phone and an iPhone | Oct 25, 2026 | Raster MBTiles packs (bigger files), or MapLibre Native bindings |
| Valhalla too heavy for scale-to-zero on Container Apps | M0 spike: cold start and memory with Nevada + Utah tiles | Oct 25, 2026 | Keep one warm replica, or Azure Maps truck routing |
| Vision model measures length poorly at 60 cm | First accuracy read on the tuning set | Dec 20, 2026 | Length buckets only; commercial 30 cm on all pilot sites; segmentation model earlier |
| SkyWatch license blocks reselling derived vectors | Written confirmation before purchase | Dec 1, 2026 | Mark commercial-derived evidence non-resale; NAIP-only for the export |
| Winter blocks field work in Utah | Weather check before M1b | Nov 9, 2026 | Run the gate on US-50 first; Utah corridors in spring |
| Stores reject background location | Submission with clear purpose strings in R1-e | Aug 2027 | Foreground drive mode at launch; alerts in a later update |
| Solo capacity slips the schedule | Milestone review every two weeks | Ongoing | Cut FR-11 and admin polish from R0; never cut the gate |

## Decisions and first-week actions

Only two decisions block R0 work this month: which Utah corridors, and whether a November field trip is possible. Everything else can wait for its milestone.

| Decision | Needed by | Default if undecided |
| --- | --- | --- |
| Utah corridors for R0 | Nov 1, 2026 | I-15 and I-80 |
| November US-50 ground-truth trip | Nov 1, 2026 | Spring trip; gate moves about 4 weeks later |
| Physical-fit rollup rule and length buckets | Nov 15, 2026 | Minimum across attributes; buckets above |
| SkyWatch strip pricing and derived-data license | Dec 1, 2026 | NAIP-only for pilot |
| Free tier boundary (one free corridor?) | Mar 2027 | Downloads paid-only |
| Standalone app or merged with 360° video brand | Apr 2027 | Standalone |
| Price point from RV group survey | Apr 2027 | $30/year |
| Store-list source (ScrapeHero vs Overture/OSM brand tags) | May 2027 | ScrapeHero, if license allows |
| IAP at launch | Jul 2027 | Stripe only |
| Verifier payment rails and tax reporting | R2 planning | — |

First week, Oct 12–18:

- [ ] Create the monorepo, `CLAUDE.md`, and an ADR for each stack decision
- [ ] Bicep for dev: Container Apps environment, ACR, PostgreSQL + PostGIS, Blob, Key Vault, App Insights
- [ ] ci.yml with .NET build and Bicep what-if
- [ ] Build a test US-50 basemap pack with Planetiler (MBTiles and PMTiles)
- [ ] Start the Mapsui spike on a real Android phone and iPhone
- [ ] Download Nevada and Utah OSM extracts and build Valhalla tiles locally
- [ ] Create the Auth0 tenant with Apple and Google connections
- [ ] Email SkyWatch about strip pricing and derived-data resale rights
