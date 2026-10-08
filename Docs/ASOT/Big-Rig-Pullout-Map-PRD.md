# Big-Rig Pullout Map — PRD

Oct 6, 2026 · @Mark

## Overview

A native mobile app that shows RV drivers of any rig size, with big rigs as the primary audience, which pullouts, turnouts, and RV-friendly lots along their route fit their rig, and tells them the next safe stop ahead, even with no cell signal. Each site carries a physical-fit score and a permission score, built from public data, AI imagery analysis, and verified field reports.

**Problem.** On remote highways like US-50 between Reno and Ely, drivers of 35–45 ft rigs often see a pullout too late to judge whether it is paved, long enough, or safe to re-enter from. Existing RV apps cover campgrounds and rig-safe routing, but not roadside stops at this level of detail.

**Goals**

- Let a driver see every stop along a planned route that fits their rig, before they leave.
- Show the next safe stop ahead while driving, fully offline.
- Build a verified, licensable dataset that improves with every check-in.
- Reach a paid consumer base and at least one data-licensing customer.

**Non-goals (for now)**

- Turn-by-turn navigation. The app routes for planning and stop placement; drivers keep their preferred navigation app.
- Campground booking or reviews.
- Coverage outside the US.
- CarPlay and Android Auto (revisit after Phase 2).

## Users and personas

The app works for any rig size. The primary paying market is the roughly 1.7–2.3 million US households with fifth wheels, Class A motorhomes, or larger Class C rigs; owners of smaller trailers and motorhomes are a secondary market and a large source of check-ins.

| Persona | Rig | Need | What they do in the app |
| --- | --- | --- | --- |
| Full-timer | 40 ft fifth wheel or Class A, often towing; 60+ ft combined | Plan long travel days on remote routes; stop safely for breaks, fuel, fatigue | Plans routes, downloads corridors, checks in often, earns bounties |
| Seasonal traveler | 35–40 ft rig, a few long trips a year | Confidence on unfamiliar roads | Plans before trips, uses drive mode, occasional check-ins |
| Small-rig owner | 18–30 ft travel trailer, Class B, or small Class C | Quick, safe stops, including small pullouts big rigs skip | Uses the free tier, checks in, may upgrade for offline packs |
| First-time renter | Rented 30–35 ft Class C | Avoid getting stuck or blocking traffic | Mostly drive mode; reached through rental partners later |
| Verifier | Any rig | Earn bounty payments for verifying sites | Accepts verification tasks near their route, submits photo sets |
| Data buyer (later) | n/a | Licensed, verified stop data for their own app or fleet | Consumes a licensed export or API |

## Platform decisions

The mobile app is native .NET MAUI from day one, and every server component runs as a container on Azure Container Apps.

| Area | Decision | Why | Not chosen |
| --- | --- | --- | --- |
| Mobile app | .NET MAUI with native XAML UI and MVVM (CommunityToolkit.Mvvm), iOS and Android | Native controls and gestures for a map-heavy app; direct access to background location, geofencing, and local notifications | MAUI Blazor Hybrid (UI renders in a WebView, weaker scroll and gesture feel); PWA (no background location) |
| Map control | Mapsui native MAUI control with offline tile packs | Pure .NET, works offline from a local file | MapLibre Native bindings, if the Mapsui spike falls short |
| Web | Blazor WebAssembly for trip planning and the admin verification queue | Usual stack; desktop-friendly planning | |
| Shared code | .NET class libraries for models, API client, and validation, used by MAUI and Blazor | Shares logic even though UI is not shared | |
| API | ASP.NET Core minimal APIs, .NET 10 | Small, thin API; route groups and built-in validation | Controllers |
| Hosting | Azure Container Apps for the API, Valhalla, and pipeline jobs | Managed containers with no Kubernetes to operate; scale to zero; scheduled jobs | App Service (no jobs, no Valhalla image); AKS (Kubernetes to run); ACI (no autoscaling or scheduled jobs) |
| Database | Azure Database for PostgreSQL Flexible Server + PostGIS; EF Core with NetTopologySuite | Spatial queries along routes are the core workload | Cosmos DB |
| Routing | Valhalla in a container, truck costing by rig dimensions | Open source, rig-aware, self-hosted | Azure Maps truck routing (fallback) |
| Identity | Auth0 | Preferred IdP; SDKs for ASP.NET Core and MAUI | Entra External ID |
| Payments | Stripe web checkout, linked out from the app for US users | Avoids store commission on subscriptions | In-app purchase only |
| Offline maps | Planetiler-built tile packs per corridor, stored in Blob behind Front Door | One download per corridor | Whole-state downloads |
| Infra and CI | Bicep, GitHub Actions, Application Insights | Matches existing work | |

**Native MAUI vs. MAUI Blazor Hybrid.** Native XAML gives the better driving experience: smoother map panning, platform-standard lists and sheets, better accessibility, and a cleaner path to CarPlay later. The cost is two UI stacks (XAML on mobile, Razor on web), so shared class libraries carry the business logic.

## Scope by release

The MVP is Release 0: a private pilot on three western corridors, used by Mark and a handful of testers, that proves the AI estimates hold up against field checks.

| Release | Audience | Includes | Gate to next |
| --- | --- | --- | --- |
| R0 Pilot | Mark + ~10 testers (TestFlight, Play internal) | Rig profile, route planning on US-50 and 2 Utah corridors, corridor download, offline drive mode, manual check-ins with photos, admin verification queue | AI size and surface estimates match field checks on most pilot sites |
| R1 Beta | Public beta, iOS and Android stores | Cracker Barrel lots and approaches nationwide, Auth0 accounts, automatic stop detection, background "next stop" alerts, subscriptions via web checkout, web trip planner | Users keep checking in and renew |
| R2 Corridors | General release | Pullout coverage across western corridors, paid verifier program, AI reading of check-in photos | Dataset quality a buyer would pay for |
| R3 Expansion | Consumers + data buyers | More brands (e.g. Walmart), licensing export or API, CarPlay and Android Auto evaluation | n/a |

## Functional requirements

R0 needs only the P0 rows marked R0; everything else waits for its release.

| ID | Requirement | Acceptance criteria | Release | Priority |
| --- | --- | --- | --- | --- |
| FR-01 | Rig profile | User saves one or more rigs (length, height, width, weight, towing); one is active; routes and site filters use the active rig | R0 | P0 must |
| FR-02 | Sign-in with Auth0 | Apple, Google, and email sign-in; tokens validated by the API; works after a period offline | R0 | P0 must |
| FR-03 | Route planning | User enters start, end, and waypoints; route comes from Valhalla truck costing for the active rig and avoids roads posted below its dimensions | R0 | P0 must |
| FR-04 | Stops along route | Map and list of sites within a set distance of the route, filtered by rig length, sorted by distance, showing both scores and a confidence label | R0 | P0 must |
| FR-05 | Site detail | Photos, size, surface, grade, signage, approach notes, evidence sources with dates, and last-verified date | R0 | P0 must |
| FR-06 | Corridor download | User downloads a pack for a planned route or a predefined corridor; size shown before download; map, sites, and detail work with no signal | R0 | P0 must |
| FR-07 | Drive mode | Shows the next three fitting stops ahead with distance and side of road; updates from GPS with no signal | R0 | P0 must |
| FR-08 | Background next-stop alerts | Local notification when a fitting stop is a user-set distance ahead, while the app is in the background or the screen is off | R1 | P0 must |
| FR-09 | Manual check-in | Photos, surface, room to spare, signage, quick rating; saved offline and synced later | R0 | P0 must |
| FR-10 | Automatic stop detection | Detects a stop of a few minutes near a known site and prompts a quick check-in | R1 | P1 should |
| FR-11 | Add a new site | Drop a pin on an unmapped pullout with photos; enters the verification queue | R0 | P1 should |
| FR-12 | Admin verification queue (web) | Review low-confidence sites, check-ins, and AI results; approve, correct, or reject; every decision becomes evidence | R0 | P0 must |
| FR-13 | Cracker Barrel lots and approaches | All US locations scored for lot fit and 1-mile approach | R1 | P0 must |
| FR-14 | Web trip planner | Plan on desktop in Blazor; trips sync to the phone | R1 | P1 should |
| FR-15 | Subscriptions | Free tier plus paid annual plan via Stripe web checkout; entitlement synced through the API | R1 | P0 must |
| FR-16 | Report a problem | Flag a closed, unsafe, or wrongly scored site | R1 | P1 should |
| FR-17 | AI reading of check-in photos | Extracts surface, rough size, and posted signs from photos as evidence | R2 | P1 should |
| FR-18 | Verifier program | Tasks near the user's route, payout per verified site, GPS and timestamp checks, spot audits | R2 | P0 must |
| FR-19 | Licensing export | Resale-clean dataset that excludes share-alike sources | R3 | P1 should |
| FR-20 | CarPlay and Android Auto | Next-stop view on the vehicle screen | R3 | P2 could |

## Key user flows

Three flows carry the product: plan, drive, and check in.

**Plan a travel day**

1. Pick the active rig.
2. Enter start, destination, and any waypoints, on the phone or the web planner.
3. Review the route and the fitting stops along it; star the ones to aim for.
4. Download the corridor pack before leaving signal.

**Drive with no signal**

1. Start drive mode, or let the app run in the background alongside the driver's navigation app.
2. The app tracks position against the downloaded route and shows the next three fitting stops.
3. A notification fires when a starred or high-scoring stop is the set distance ahead.
4. Tapping it shows size, surface, side of road, and the last-verified date.

**Check in after stopping**

1. The app notices the rig has stopped near a site (R1) or the driver taps Check in (R0).
2. Driver takes photos and answers three quick questions: surface, room to spare, signage seen.
3. The check-in is saved on the phone and syncs when signal returns.
4. The nightly pipeline turns it into evidence, re-scores the site, and rebuilds affected packs.

## Non-functional requirements

Offline reliability and driver safety come first; numeric targets below are proposals to confirm during R0.

| Area | Requirement |
| --- | --- |
| Offline | Everything in plan review, drive mode, site detail, and check-in works with no signal once a pack is downloaded; packs stay on the device until the user deletes them |
| Driver safety | No typing while the vehicle is moving; drive mode uses large touch targets and glanceable text; alerts are audible and short |
| Performance | Stops along a 500-mile route load in under 2 seconds online; drive mode updates within 1 second of a GPS fix |
| Battery | Background tracking uses low-power location modes; battery cost measured in R0 and a target set from the pilot |
| Pack size | Size shown before download; per-corridor size measured in R0 and a target set from the pilot |
| Data durability | Check-ins are never lost: queued on the device and retried until the API confirms |
| Privacy | Background location is opt-in with a clear explanation; continuous location traces are not stored on the server, only check-in points; account deletion removes personal data |
| Security | Auth0 tokens validated on every API call; secrets in Key Vault; faces and plates blurred before photos are shown to other users |
| Platforms | iOS and Android, current and previous major OS versions |
| Observability | Application Insights for the API and jobs; crash and error reporting in the app |
| Cost | Container Apps scale to zero; R0 hosting about $50–100 a month |

## Data and scoring requirements

The data model, sources, scoring formula, and AI pipeline are defined in the product and data brief; the PRD holds the product-facing rules.

- **Two scores per site.** Physical fit and permission are shown separately and never blended into one number.
- **Explainable scores.** Site detail lists the evidence behind each score, with source and date.
- **Confidence labels.** Sites below about 0.5 on either score show as "Unverified" and are never shown as safe for the rig.
- **Rig fit.** A site is shown as fitting only if its estimated usable length exceeds the active rig's length plus a margin (proposed: 10 ft).
  - **All sizes.** Sites of every size are kept and scored, each with the maximum rig length it fits, so short pullouts still show for smaller rigs. AI size estimates use buckets that cover small sites (e.g. under 25 ft, 25–40 ft, 40+ ft).
- **Freshness.** Evidence ages by fact type; policy facts expire fastest.
- **Coverage for R0.** US-50 Reno to Ely plus two Utah corridors, every candidate site scored.
- **Coverage for R1.** All US Cracker Barrel locations, lot and 1-mile approach.
- **Licensing hygiene.** Every record keeps its source license; share-alike data never enters the licensing export.
- **Imagery.** NAIP for screening; commercial 30 cm imagery in about 60 m strips on two-lane roads and around priority sites.

## Monetization

A free tier drives check-ins; a paid annual plan at about $30 unlocks offline packs and alerts. The price is a hypothesis to test before R1.

| Plan | Price | Includes |
| --- | --- | --- |
| Free | $0 | Route planning, stops along route online, site detail, check-ins |
| Pro | ~$30/year (test $25–40) | Corridor downloads, offline drive mode, background next-stop alerts, web planner |
| Verifier | Paid per verified site | Verification tasks and payouts (R2) |
| Data license | Negotiated | Licensed export or API for navigation apps and rental fleets (R3) |

**Billing.** Stripe web checkout, linked from the app for US users, with entitlements synced through the API. Apple's commission on link-out purchases is unsettled: none is collected today, Apple has proposed 5–15%, and a Supreme Court ruling is expected by June 2027. Keep in-app purchase as a fallback.

**Comparables.** RV LIFE Pro is $65/year and Campendium RV PRO has sold for $30–42/year on promotion; both bundle routing and campgrounds, so this app is priced as an add-on.

## Success metrics

Each release has one gate metric; the targets are proposals to firm up once R0 data exists.

| Release | Gate metric | Proposed target | Supporting metrics |
| --- | --- | --- | --- |
| R0 | AI size and surface agree with field checks | 80% of pilot sites | Sites scored per corridor; check-ins per tester per trip |
| R1 | Paid users renew | 60% annual renewal | Free-to-paid conversion; check-ins per active user; packs downloaded per trip |
| R2 | Verified share of corridor sites | 70% verified on target corridors | Bounty cost per verified site; audit pass rate |
| R3 | Data revenue | 1 signed license | Licensed records; buyer-reported accuracy issues |

## Risks

The two biggest risks are whether RVers pay for this as a standalone app and whether offline maps work well in native MAUI; both get tested in R0.

| Risk | Impact | Mitigation |
| --- | --- | --- |
| RVers see pullouts as a feature, not a product | Consumer revenue stays small | Price survey in RV groups before R1; pursue data licensing early |
| Mapsui offline vector rendering is slow or limited | Poor map experience | Spike in week 1 of R0; fall back to MapLibre Native bindings or raster packs |
| Vision models measure size poorly | Wrong fit scores | Size buckets first; train a segmentation model on verified labels; never show unverified sites as safe |
| App store rejects background location use | No background alerts | Clear purpose strings, opt-in, visible user benefit; drive mode works in the foreground without it |
| RV LIFE or Campendium add a pullout layer | Lost differentiation | Compete on verified data quality and scoring; offer them a license |
| Liability if a rig gets stuck | Legal and reputation risk | Terms and in-app wording present data as reported, not guaranteed; posted signs always win; legal review before R1 |
| Bounty fraud | Bad data | GPS and timestamp checks, photo forensics, spot audits against imagery |
| Solo developer capacity | Slow releases | Tight R0 scope; Claude Code for implementation; pipeline before polish |

## Open questions

- [ ] Product name and brand: avoid "big-rig" so owners of smaller rigs see the app as theirs; standalone or combined with the 360° site video idea?
- [ ] Free tier boundary: are corridor downloads paid-only, or is one free corridor allowed?
- [ ] Rig-fit margin: is 10 ft beyond rig length right, and should users adjust it?
- [ ] How "no trucks" roads are treated for RVs in Valhalla (penalty value, state rules).
- [ ] Which two Utah corridors join US-50 for R0?
- [ ] Does SkyWatch price narrow strips by exact polygon or enforce a minimum width?
- [ ] Store-list source: ScrapeHero license terms, or Overture/OSM brand tags?
- [ ] Verifier payouts: payment rails, tax reporting, and vetting.
- [ ] Minimum iOS and Android versions for .NET 10 MAUI.

## References

- Big-Rig Pullout Map — Product & Data Brief: data sources, scoring model, AI pipeline, architecture, and budget
- [RVIA 2025 RV Owner Demographic Profile summary](https://camperfaqs.com/rv-statistics-trends-facts): 8.1M RV households and ownership by RV type
- [RV LIFE Pro pricing](https://support.rvlife.com/hc/en-us/articles/16298434564247-What-is-the-price-for-the-RV-LIFE-Pro-subscription)
- [Campendium RV PRO promotion](https://campendium.com/laborday2026/)
- [Apple link-out commission status](https://thenextweb.com/news/supreme-court-apple-epic-contempt-app-store-commission)
- [Apple's proposed 5–15% link-out fees](https://www.gadgetscout.co.uk/articles/apple-seeks-5-15-cut-on-external-app-payments.html)
