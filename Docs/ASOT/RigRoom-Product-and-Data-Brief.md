# RigRoom — Product & Data Brief

Oct 6, 2026 · @Mark

## Summary

Build a verified dataset of RV-safe stops for rigs of every size, with big rigs as the primary audience (roadside pullouts, turnouts, and RV-friendly lots such as Cracker Barrel) and an app that shows them along a planned route, offline. Each site carries two confidence scores: **physical fit** (size, surface, grade, approach) and **permission** (is stopping or overnighting allowed). Free federal data seeds the map, paid imagery and paid field verification raise quality, and user check-ins keep it fresh. The long-term asset is the dataset itself, licensable to RV navigation apps and rental fleets.

This brief captures the research and decisions so far, as input for an implementation plan.

## Problem and users

On desolate routes like US-50 from Reno to Ely, NV, a big rig often passes a pullout before the driver can tell whether it is paved, long enough, or safe to re-enter from. By the time a usable spot appears, it is too late to slow down. Drivers need to plan stops in advance, and to know the next safe one while driving with no cell signal.

**Primary users:** full-time and long-haul RVers in 35–45 ft motorhomes and fifth wheels, especially when towing (60+ ft combined).

**Secondary users:** first-time renters of large RVs, who are the least experienced big-rig drivers on the road. Owners of smaller trailers and motorhomes use the same app; each rig gets its own fit results.

**Data buyers (later):** RV navigation and trip-planning apps, RV rental fleets, and possibly fleet or insurance partners.

## Competitive landscape

No product maps informal pullouts at big-rig detail (surface, length, distance off the travel lane, re-entry visibility), ordered along a route and available offline. RVers currently combine several apps to get partway there.

| Product | What it does | Gap for this use |
| --- | --- | --- |
| [iOverlander](https://app.ioverlander.com) | User-posted camp spots, including some roadside pullouts | Camping focus, free-text notes, not ordered along a route, no rig-size filters |
| [Trucker Path](https://truckerpath.com) | Crowdsourced truck stops, rest areas, parking availability | Formal stops only; the crowd model to copy |
| RV LIFE / Trip Wizard, CoPilot RV, [EZRV](https://apps.apple.com/app/id6791214932) | Routing by rig dimensions, campgrounds, fuel stops | No turnout layer |
| [Low Clearance Map](https://lowclearancemap.com/) | Subscription bridge-clearance dataset and navigation | Not a competitor; proof RVers pay for one narrow verified dataset |
| Campendium, The Dyrt, Roadtrippers | Reviews of campgrounds and overnight lots, incl. Cracker Barrel | Reviews, not measured site geometry or approach scoring |

## Core data model

Every fact about a site is stored as a separate piece of evidence with its source and observation date; scores are derived from evidence, never typed in by hand. This keeps the confidence score explainable and lets old evidence age out.

| Entity | Holds | Notes |
| --- | --- | --- |
| Site | Polygon or point, site type (pullout, turnout, rest area, chain-up, brake check, business lot), road + mile marker, side of road | One row per physical place, deduplicated across sources |
| Evidence | Site, source, attribute (length, width, surface, grade, signage, policy), value, observed date, ingested date | Append-only; the raw material for scoring |
| Approach | Site + road segments within ~1 mile: turn angles, roundabouts, clearances, entrance width | Mainly for business lots like Cracker Barrel |
| Score | Physical-fit score, permission score, max rig length supported, last computed | Recomputed when evidence changes or ages |
| Check-in | User, site, timestamp, rig length, photos, quick ratings, signage seen | Crowd evidence; user grants resale rights in ToS |
| Source | Name, license, reliability weight, update cadence, share-alike flag | The share-alike flag keeps OSM-type data out of resale exports |

## Confidence scoring

Each site gets two independent scores from 0 to 1: **physical fit** and **permission**. A lot can fit a 45 ft rig perfectly and still post "No Overnight Parking", so the two are never blended.

Each piece of evidence contributes its source's reliability weight, discounted by age with a half-life set by the kind of fact. Agreeing evidence combines so that independent confirmations raise confidence:

```latex
f_i = 2^{-\text{age}_i / h_{\text{attr}}} \qquad C = 1 - \prod_i \left(1 - w_{\text{src}(i)} \cdot f_i\right)
```

Evidence that contradicts the current value (a photo showing gravel where imagery said paved) is scored the same way against it; the attribute takes whichever side is stronger, and close contests flag the site for verification.

Starting values to tune later:

| Source type | Weight w |
| --- | --- |
| Paid field verifier with photos | 0.9 |
| User check-in with photo | 0.7 |
| Commercial 30 cm imagery + AI | 0.6 |
| State DOT asset layer | 0.6 |
| NAIP imagery + AI | 0.45 |
| User rating without photo | 0.4 |
| OSM / NTAD | 0.3 |

| Fact type | Half-life h |
| --- | --- |
| Grade (from lidar) | 10 years |
| Size, surface | 5 years |
| Signage | 18 months |
| Overnight policy | 12 months |
| Shoulder type and width (HPMS) | until the road is rebuilt |

A site below about 0.5 on either score is shown as "unverified" and pushed into the check-in and bounty queues.

## Recommended data sources

A free federal backbone covers the whole highway network; paid imagery and store lists cover the sites that matter most. Costs are data costs only.

| Source | What it gives | Freshness | License | Cost |
| --- | --- | --- | --- | --- |
| [HPMS shoulders](https://www.fhwa.dot.gov/policyinformation/tables/performancenetwork) (FHWA + state live layers) | Shoulder type (asphalt, concrete, earth) and width per segment | Changes only when a road is rebuilt | Public | $0 |
| [NTAD Truck Stop Parking](https://catalog.data.gov/dataset/truck-stop-parking) | 8,000+ truck parking locations | Stale; last modified 2017 | US gov work | $0 |
| State DOT asset layers (e.g. [UDOT facilities](https://maps.udot.utah.gov/central/rest/services/Maintenance/Facility_Inventory_OMS/MapServer), [CDOT chain stations](https://services.arcgis.com/yzB9WM8W0BO3Ql7d/ArcGIS/rest/services/Chain_Stations/FeatureServer)) | Brake checks, chain-up areas, view areas, rest areas | Varies; UDOT as needed, CDOT 2019 | Varies by state | $0 |
| National Bridge Inventory + state clearance layers | Vertical clearances on approaches | Annual (approximate) | Public | $0 |
| [NAIP imagery](https://catalog.data.gov/dataset/national-agriculture-imagery-program-naip-imagery) | 30–60 cm aerial photos, CONUS | Each state at least every 3 years; leaf-on | Public domain, attribution requested | $0 (also on Microsoft Planetary Computer) |
| [USGS 3DEP lidar](https://catalog.data.gov/dataset/usgs-1-meter-digital-elevation-model) | 1 m elevation: slope and levelness | Project-based vintages; most of CONUS covered | Public domain | $0 |
| OpenStreetMap / Overture Maps | Road geometry, turn restrictions, some lay-bys and POIs | Continuous | OSM is ODbL share-alike; keep in a separate layer | $0 |
| [ScrapeHero store lists](https://www.scrapehero.com/store/product/cracker-barrel-store-locations-in-the-usa/) | 657 Cracker Barrel locations, geocoded; other brands sold separately | Re-buy quarterly | Commercial | $85 per brand |
| [SkyWatch archive imagery](https://skywatch.com/data-pricing/) | 30–49 cm satellite imagery | Archive; tasking available | Commercial; confirm derived-data resale rights | From $19/km², 1 km² minimum |
| [Mapillary](https://en.wikipedia.org/wiki/Mapillary) | Street-level photos | Crowd, uneven | CC BY-SA; internal spot-checks only | $0 |
| [Low Clearance Map](https://lowclearancemap.com/) | 27,500+ verified bridge clearances | Maintained | Ask about licensing | Later, if needed |

**Excluded:** Google imagery and Street View. Google's terms forbid tracing features from satellite imagery and using Maps content to train or test AI models.

## AI pipeline

AI does two jobs: normalizing messy public data, and estimating site geometry from imagery and lidar. Human-verified labels feed back in so the model improves as the dataset grows.

1. **Ingest and normalize.** Pull federal and state layers on a schedule. Use an LLM to map each state's schema to the Evidence model and flag fields it can't map.
2. **Generate candidates.** Along target corridors, find widened areas of any size next to the travel lane: OSM lay-bys, DOT points, HPMS wide-shoulder segments, and imagery detections.
3. **Classify from imagery.** Cut a tile around each candidate (NAIP first, commercial 30 cm for priority sites). Estimate usable length and width (in size buckets that cover small sites too), surface (paved, gravel, dirt), and separation from the travel lane. At 60 cm, a 40 ft rig spans about 20 pixels, so size estimates are realistic. Buy commercial imagery as a ~60 m strip (30 m each side of the centerline) on two-lane roads, with wider buffers at divided highways, rest areas, and DOT turnouts. Where possible, find candidates in NAIP first and buy 30 cm imagery only around them.
4. **Add terrain.** Compute slope and cross-slope from 3DEP lidar, which imagery cannot show.
5. **Score the approach** (business lots). From road geometry: turn angles, roundabouts, entrance width, and clearances within about 1 mile.
6. **Score and route.** Write Evidence rows and recompute both scores. Low-confidence sites go to the verification queue.
7. **Learn from verification.** Each paid or user-verified site becomes a labeled example. Retrain or re-prompt the classifier and re-score the corridor.

**Known blind spots:** pavement-edge drop-offs, soft gravel, tree cover in leaf-on imagery, and anything that changed since the image date. These are exactly what field verification covers.

## Crowd and paid verification

Verified field data is the part of the dataset nobody can download for free, so it gets the largest share of the quality budget.

- **Stop-triggered check-ins.** When the app detects the rig stopped at or near a known site, it asks for a 10-second check-in: photo, surface, room to spare, signage seen. Trucker Path uses the same prompt-on-arrival pattern.
- **Photo reading.** A vision model reads each photo for surface type, rough size, and posted signs such as "No Overnight Parking". It records the photo's GPS and timestamp as evidence.
- **Paid bounties.** Pay vetted RVers about $5–10 per site verified with a photo set, targeted at low-confidence sites on high-traffic corridors. Spot-audit a sample against imagery to catch bad submissions.
- **Own field capture.** Mount a 360° camera on Mark's rig for corridors he drives. The same footage serves the big-rig site video idea.
- **Contributor rewards.** Free premium months for users whose check-ins verify a site.
- **Rights.** Terms of service give the company a perpetual, transferable license to user photos and ratings, including for resale.

## Licensing and legal constraints

Resale value depends on owning clean rights to every record in the export, so license tracking is built into the data model from day one. Have a lawyer review this before selling anything.

- **Share-alike sources stay out of resale exports.** OSM (ODbL) and Mapillary (CC BY-SA) can inform the app, but records derived from them are flagged and excluded from licensed datasets.
- **Commercial imagery.** Confirm the SkyWatch provider license allows publishing and reselling vector data derived from the imagery. Redistributing the imagery itself is usually restricted.
- **No Google content.** Google Maps terms forbid digitizing features from its satellite imagery and using its content for AI training or testing.
- **Store lists.** ScrapeHero data is sourced from brand store locators; confirm its license permits use in a commercial app and derived products.
- **Liability.** Show conditions as user- and data-reported, never as a guarantee a rig will fit or that parking is permitted. Signage and posted limits always win.
- **User content.** Terms grant resale rights to check-ins and photos; strip faces and plates from published photos.

## Recommended tech stack

Stay on .NET 10, Blazor, native MAUI, and Azure Container Apps, with one deliberate change: PostgreSQL with PostGIS as the main store instead of Cosmos DB. Finding sites along a route is a spatial join (buffers, distance along a line, polygon overlap), which PostGIS does natively and Cosmos DB's geospatial queries handle poorly.

[embedded content: system architecture · 8 components]

The pipeline writes evidence and scores to PostGIS. The API serves routes and sites to the web portal and the app; the app also downloads corridor packs for offline use and sends check-ins back.

| Layer | Choice | Why |
| --- | --- | --- |
| Mobile | .NET MAUI with native XAML UI and MVVM (iOS, Android), Mapsui map with offline tile packs | Native controls and gestures for a map-heavy driving app; background location and local notifications; business logic shared with the web app through .NET class libraries |
| Web | Blazor WebAssembly with MapLibre GL JS via JS interop | Trip planning and the admin verification queue |
| API | ASP.NET Core minimal APIs, .NET 10, on Azure Container Apps | Usual stack; scales to zero while small |
| Database | Azure Database for PostgreSQL Flexible Server + PostGIS; EF Core with NetTopologySuite | Spatial joins along routes are the core query |
| Pipeline | Python jobs (GDAL, rasterio, PDAL) on Container Apps Jobs; dbt-postgres for evidence to scores | Raster and lidar tooling lives in Python; scoring is SQL you already write in dbt |
| Imagery access | NAIP and 3DEP via Microsoft Planetary Computer; commercial tiles in Blob Storage | Reads public data without bulk copying |
| AI | Vision model via Azure AI Foundry or the Anthropic API; custom segmentation on Azure ML later | Prompt first, train once verified labels exist |
| Routing | Valhalla in a container, truck costing by height, length, and weight | Self-hosted; Azure Maps truck routing as a fallback |
| Offline tiles | Planetiler or tippecanoe to PMTiles corridor packs, served from Blob + Azure Front Door | One download per corridor |
| Auth | Auth0 | Preferred IdP; consumer sign-in with social logins, works with ASP.NET Core and MAUI |
| Infra and CI | Bicep, GitHub Actions, Application Insights | Matches existing Bicep work |
| Dev | Claude Code in VS Code on Mac | Current workflow |

## Budget estimates

A corridor pilot costs about $2–3K in data and services; a national Cracker Barrel launch about $27–40K. Imagery figures use SkyWatch's $19/km² archive rate; the rest are estimates to firm up with quotes.

| Item | Pilot (US-50 + 2 Utah corridors) | National Cracker Barrel launch |
| --- | --- | --- |
| Store location lists | $85 | $85 + quarterly refresh |
| Commercial imagery | ~$600 (US-50: ~515 km × 60 m strip ≈ 31 km²) | ~$12.5K (658 lots × 1 km²) |
| Paid verification bounties | ~$1–2K (100–200 sites) | ~$10–20K (2,000 sites) |
| AI processing | ~$200 | ~$2K |
| Legal review | defer | ~$2–5K |
| Azure hosting | ~$50–100/month | ~$150–300/month |
| **Total (one-time)** | **~$2–3K** | **~$27–40K** |

Azure hosting and AI processing figures are rough estimates, not quotes.

## Phased rollout

Four phases, each gated on proof from the one before: the pilot proves the AI, Cracker Barrel proves users will pay, corridors build the hard-to-copy dataset, and licensing sells it.

[embedded content: rollout · 4 phases, 3 gates]

Dates and team capacity belong in the implementation plan; budget figures match the estimates above.

## Open decisions

These need answers before or during the implementation plan.

- [ ] Standalone app, or merged with the big-rig 360° site video idea under one brand?
- [ ] Launch wedge: Cracker Barrel lots first, or desolate-corridor pullouts first?
- [ ] Revenue model: consumer subscription, data licensing (B2B), or both from the start?
- [ ] Which pilot corridors besides US-50 (e.g. I-80 and I-15 in Utah and Nevada)? Confirm whether SkyWatch prices narrow strips by exact polygon or enforces a minimum strip width.
- [ ] Imagery classifier approach: vision LLM on tiles, or a trained segmentation model, or LLM first then train on labels?
- [ ] Routing engine: self-hosted Valhalla, or Azure Maps truck routing?
- [ ] Bounty program mechanics: payment rails, verifier vetting, fraud checks.
- [ ] Store lists: confirm ScrapeHero license terms or source from Overture/OSM brand tags.

## Sources

- [FHWA Highway Performance Network: HPMS shoulder data items](https://www.fhwa.dot.gov/policyinformation/tables/performancenetwork)
- [HPMS Field Manual: update cycle for shoulder items](https://www.fhwa.dot.gov/ohim/hpmsmanl/word/chap6.doc)
- [Idaho ITD HPMS Shoulders live layer](https://gisp.itd.idaho.gov/server/rest/services/GDWarehouse/HPMS/MapServer/19)
- [NTAD Truck Stop Parking (data.gov)](https://catalog-beta.data.gov/dataset/truck-stop-parking)
- [USDOT NTAD release with 8,000+ truck parking locations](https://www.transportation.gov/briefing-room/dot9217)
- [UDOT Facility Inventory layer](https://maps.udot.utah.gov/central/rest/services/Maintenance/Facility_Inventory_OMS/MapServer)
- [CDOT Chain Stations layer](https://services.arcgis.com/yzB9WM8W0BO3Ql7d/ArcGIS/rest/services/Chain_Stations/FeatureServer)
- [KDOT Vertical Clearances layer](https://kanplan.ksdot.gov/arcgis_web_adaptor/rest/services/Structures/Vertical_Clearances/MapServer/info/iteminfo)
- [NAIP imagery (data.gov)](https://catalog.data.gov/dataset/national-agriculture-imagery-program-naip-imagery)
- [NAIP on AWS](https://registry.opendata.aws/naip/index.html)
- [USGS 1 m DEM (data.gov)](https://catalog.data.gov/dataset/usgs-1-meter-digital-elevation-model)
- [Land Info: 3DEP lidar coverage](https://landinfo.com/usgs-3dep-lidar/)
- [SkyWatch data pricing](https://skywatch.com/data-pricing/)
- [ScrapeHero Cracker Barrel locations](https://www.scrapehero.com/store/product/cracker-barrel-store-locations-in-the-usa/)
- [Mapillary licensing (Wikipedia)](https://en.wikipedia.org/wiki/Mapillary)
- [Google Maps Platform terms: AI training prohibition (summary)](https://conductatlas.com/platform/google-maps/google-maps-platform-terms-of-service/ai-and-ml-training-data-prohibition/)
- [European OSM-derived truck parking dataset](https://doaj.org/article/475c0a37fea142bd94226206798fd637)
- [Trucker Path crowdsourced parking (Fleet Owner)](https://fleetowner.com/technology/article/21692143/crowd-sourcing-helps-app-get-around-parking-data-limitations)
- [Cracker Barrel overnight policy reports (CamperFAQs)](https://camperfaqs.com/cracker-barrel-camping)
- [Cracker Barrel location count (RVtravel)](https://www.rvtravel.com/video-overnight-parking-cracker-barrel-2592/)
