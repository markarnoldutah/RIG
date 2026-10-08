---
title: "ADR-0002: PostgreSQL + PostGIS Instead of Cosmos DB"
status: "Accepted"
date: "2026-10-07"
authors: "Mark Arnold (product owner, developer)"
tags: ["architecture", "decision", "data"]
supersedes: ""
superseded_by: ""
---

# ADR-0002: PostgreSQL + PostGIS Instead of Cosmos DB

## Status

**Accepted**

## Context

The developer's existing product (RVS) runs on Cosmos DB. This product's core query is spatial: find every site within a set distance of a 500-mile route, order sites by distance along the line, and filter by rig fit, in under 2 seconds. The pipeline also does polygon overlap (slope inside a site polygon), corridor buffers, and deduplication by distance and road side.
Scoring runs in dbt as SQL aggregates over an append-only `evidence` table, and the database is the contract between the Python pipeline and the .NET API.

## Decision

Use Azure Database for PostgreSQL Flexible Server with the PostGIS extension as the main store. The API uses EF Core with the Npgsql provider and NetTopologySuite. The pipeline writes with Python (GDAL, psycopg) and dbt-postgres. Start on the Burstable tier in dev and prod.

## Consequences

### Positive

- **POS-001**: Buffers, distance along a line (`ST_LineLocatePoint`), and polygon overlap are native PostGIS functions with spatial indexes.
- **POS-002**: dbt-postgres runs scoring as SQL. The combining formula becomes one sum-of-logs aggregate.
- **POS-003**: Python GIS tooling (GDAL, rasterio, geopandas) and .NET (NetTopologySuite) both speak PostGIS geometry natively, so the database can be the contract.
- **POS-004**: Relational constraints enforce the licensing rules in the schema, for example the `source` share-alike flag and foreign keys from `evidence` to `source`.

### Negative

- **NEG-001**: A second database technology to learn and operate alongside the RVS Cosmos experience. Patterns from RVS repositories do not carry over.
- **NEG-002**: A Flexible Server bills while running and does not scale to zero like Cosmos serverless, which raises the hosting floor.
- **NEG-003**: Integration tests need Testcontainers with a PostGIS image. The EF in-memory provider cannot run spatial functions.

## Alternatives Considered

### Cosmos DB (NoSQL API)

- **ALT-001**: **Description**: Reuse the RVS stack, storing sites as GeoJSON documents with geospatial indexes.
- **ALT-002**: **Rejection Reason**: Cosmos geospatial queries handle along-route spatial joins, distance along a line, and polygon overlap poorly, and dbt cannot target it for scoring.

### Azure SQL with spatial types

- **ALT-003**: **Description**: SQL Server `geography` types through EF Core and NetTopologySuite.
- **ALT-004**: **Rejection Reason**: A thinner spatial function set than PostGIS, weaker Python GIS and dbt support, and higher cost at the same tier.

## Implementation Notes

- **IMP-001**: EF Core migrations are committed and run from the deploy pipeline, never at app startup. Never edit a migration that has reached a shared environment.
- **IMP-002**: Tables written by the pipeline and dbt (`evidence`, `score`) are read-only to the API. Admin decisions and check-ins land as new `evidence` rows.
- **IMP-003**: Success criterion: a route request returns fitting stops in under 2 s (M3). If it misses, move to a larger tier before changing the design.

## References

- **REF-001**: [Product and Data Brief, architecture section](../ASOT/Big-Rig-Pullout-Map-Product-and-Data-Brief.md)
- **REF-002**: [PRD, Platform decisions](../ASOT/Big-Rig-Pullout-Map-PRD.md#platform-decisions)
- **REF-003**: [Implementation Plan, Data pipeline build order](../ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#data-pipeline-build-order)
