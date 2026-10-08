---
title: "ADR-0003: Self-Hosted Valhalla for Rig-Aware Routing"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "routing"]
supersedes: ""
superseded_by: ""
---

# ADR-0003: Self-Hosted Valhalla for Rig-Aware Routing

## Status

**Accepted**

## Context

FR-03 requires routes computed for the active rig's height, length, width, and weight, avoiding roads posted below its dimensions. The route line is also the spine for stop placement: sites are projected onto it to get distance along the route, and it is stored in each corridor pack. The app routes only for planning and stop placement. Drivers keep their own navigation app.
R0 covers Nevada and Utah, and hosting must stay around $50–100 a month.

## Decision

Run Valhalla in a container on Azure Container Apps, using truck costing parameterized by rig dimensions. Routing tiles for Nevada and Utah are built from OSM extracts, stored on Azure Files, and mounted into the container. A monthly `valhalla.yml` workflow rebuilds them. The API calls Valhalla through a typed client with a standard resilience handler and a mock behind the same interface.

## Consequences

### Positive

- **POS-001**: Open source, with no per-request fees. Truck costing takes height, length, width, and weight directly.
- **POS-002**: Full control of costing options, including how "no trucks" roads are penalized for RVs (an open PRD question).
- **POS-003**: Route geometry is returned in full and can be stored in packs without a provider's caching restrictions.

### Negative

- **NEG-001**: Tile builds and monthly refreshes are ours to run.
- **NEG-002**: Valhalla's memory footprint and cold start may not fit scale-to-zero, which could force a warm replica and raise cost.
- **NEG-003**: Tiles are OSM-derived (ODbL). Route geometry must never flow into resale tables; it is used for planning and packs only.

## Alternatives Considered

### Azure Maps truck routing

- **ALT-001**: **Description**: Managed Route Directions API with vehicle dimension parameters.
- **ALT-002**: **Rejection Reason**: Per-request cost, less control over costing, and terms on storing results. Kept as the fallback if the Valhalla spike fails.

### OSRM or GraphHopper

- **ALT-003**: **Description**: Other open-source routing engines.
- **ALT-004**: **Rejection Reason**: OSRM has no runtime dimension-based truck costing. GraphHopper's truck profiles need custom models, and the full feature set is commercial.

## Implementation Notes

- **IMP-001**: M0 spike: measure cold start and memory with Nevada and Utah tiles on Container Apps, and return a truck route Reno–Ely sized for a 60 ft rig. Decide by Oct 25, 2026.
- **IMP-002**: Fallbacks in order: keep one warm replica, then switch to Azure Maps truck routing behind the same `IRoutingClient` interface.
- **IMP-003**: Choose the routing implementation explicitly in config and log which one was registered at startup. Never fall back silently to a mock.

## References

- **REF-001**: [PRD, FR-03](../ASOT/Big-Rig-Pullout-Map-PRD.md#functional-requirements)
- **REF-002**: [Implementation Plan, Risks, spikes and fallbacks](../ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#risks-spikes-and-fallbacks)
- **REF-003**: [ADR-0005: Azure Container Apps hosting](adr-0005-azure-container-apps-hosting.md)
