# Pipeline

Python jobs and dbt models that turn public data, imagery, and field reports into `evidence` and `score` rows in PostGIS. Each stage runs as an Azure Container Apps Job. The API never calls the pipeline, and the pipeline never calls the API: the database is the contract between them.

| Folder | Stage | Writes |
| --- | --- | --- |
| `ingest/` | HPMS, NTAD, and state DOT layers, mapped once per layer by the LLM schema mapper | Staging schema, then `evidence` |
| `candidates/` | Corridor buffers, lay-bys, wide shoulders, NAIP detections, deduplicated by distance and road side | `site` |
| `imagery/` | NAIP and commercial tiles, vision classification of length bucket, width, surface, lane separation | `evidence` |
| `terrain/` | 3DEP slope and cross-slope inside each site polygon | `evidence` |
| `packs/` | Planetiler basemap pack plus SQLite site pack per corridor | Blob Storage |
| `dbt/` | `evidence` to attribute values to scores | `score` |

Build order, stage contracts, and the scoring formula are in the [Implementation Plan](../Docs/ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md#data-pipeline-build-order). dbt naming rules are in [CLAUDE.md](../CLAUDE.md#dbt-conventions).

**Never write OSM-derived (share-alike) data into resale tables.** Every row keeps the license of its `source`.
