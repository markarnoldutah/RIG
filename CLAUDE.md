# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Authoritative Docs

**Product canon** lives in [Docs/ASOT/](Docs/ASOT/):

| Document | Use it when |
| --- | --- |
| [RigRoom-Product-and-Data-Brief.md](Docs/ASOT/RigRoom-Product-and-Data-Brief.md) | You need to remember what this is, the data sources, or the scoring model |
| [RigRoom-PRD.md](Docs/ASOT/RigRoom-PRD.md) | You're writing code. **If a requirement isn't here, it isn't in scope** — and an FR is only in scope for the release it is tagged with (R0, R1, …) |
| [RigRoom-Implementation-Plan.md](Docs/ASOT/RigRoom-Implementation-Plan.md) | You're deciding what to do next, sequencing milestones, or need a default for an open decision |

One authoritative home per fact. A document earns its place by answering a question someone actually asks; register a new one in this table and in `.github/copilot-instructions.md` on the same commit.

**Architecture decisions** are ADRs in [Docs/ADR/](Docs/ADR/), one per stack decision, named `adr-NNNN-title-slug.md` (template: the `create-architectural-decision-record` skill). A new stack decision gets a new ADR; a reversed one is marked Superseded, not rewritten.

| ADR | Decision |
| --- | --- |
| [0001](Docs/ADR/adr-0001-native-maui-mobile-app.md) | Native .NET MAUI (XAML + MVVM), iOS and Android only, Mapsui maps |
| [0002](Docs/ADR/adr-0002-postgresql-postgis-over-cosmos-db.md) | PostgreSQL Flexible Server + PostGIS, not Cosmos DB |
| [0003](Docs/ADR/adr-0003-valhalla-truck-routing.md) | Self-hosted Valhalla truck costing; Azure Maps as fallback |
| [0004](Docs/ADR/adr-0004-auth0-identity-provider.md) | Auth0, per-permission policies |
| [0005](Docs/ADR/adr-0005-azure-container-apps-hosting.md) | Azure Container Apps for API, Valhalla, and pipeline jobs |
| [0006](Docs/ADR/adr-0006-stripe-web-checkout.md) | Stripe web checkout for subscriptions (R1; nothing built in R0) |

- **Infra source of truth** will be the Bicep modules under `infra/`. Do not trust hand-drawn diagrams or older docs for Azure resource configuration. Nothing is created by hand in the portal.
- Frozen snapshots (an `ARCHIVE/` or `Obsolete/` folder, if one is added) are **never** cited as current.
- Path-scoped rules (C#, ASP.NET, Blazor, Markdown, Testing) live in [.claude/rules/](.claude/rules/) and load when matching files are touched. Edit them there: `.github/instructions/*.instructions.md` are symlinks to the same files for Copilot.
- Claude Code skills live in [.claude/skills/](.claude/skills/): `dotnet-best-practices`, `csharp-async`, `csharp-docs`, `appinsights-instrumentation`, `az-cost-optimize`, `frontend-design`.
  Copilot-format agents and remaining skills live in [.github/agents/](.github/agents/) and [.github/skills/](.github/skills/) (e.g. `code-review`, `bicep-plan`, `dotnet-maui`, `create-architectural-decision-record`).
  Output locations: ADRs in `Docs/ADR/`, implementation plans in `Docs/Plans/`, epic breakdowns in `Docs/Epics/`, Claude Code plans in `Docs/Claude_Plans/`.

**Scope discipline.** Build the current release only. R0 is: rig profile, route planning on US-50 and two Utah corridors, corridor download, offline drive mode, manual check-ins with photos, admin verification queue.
R1+ features (Cracker Barrel, background alerts, Stripe, web trip planner) are not built early unless the Implementation Plan says so (e.g. the share-alike flag is enforced in the schema from M1).

## Working an Issue

When the user says **"Execute Issue #abc"** (where `abc` is a valid GitHub Issue number), before doing any work:

1. Create a new branch off the current base branch (usually `main`) named `abc-some-meaningful-identifier` — `abc` is the issue number, followed by a short kebab-case slug describing the issue (e.g. `42-mapsui-offline-spike`).
2. Check out that branch, then perform the work for the issue on it.

Do not commit issue work directly to `main`. If the branch already exists, check it out and continue on it rather than creating a duplicate.

## Committing

**Never commit or push automatically.** Do the work, leave the changes in the working tree, and stop there. Run `git commit` or `git push` only when I explicitly ask for it in that same message. Creating a branch, "executing" an issue, or being told to "make the change" is **not** permission to commit — wait for an explicit "commit this" / "push it" instruction.

## Repo Layout

One monorepo holds the .NET solution, the Python pipeline, dbt, and Bicep, so one PR can change a contract and both its producer and consumer. The repo root is the plan's `rigroom/` folder, and the plan's `docs/` is `Docs/`. Use the **SLNX** solution format (`dotnet` CLI handles it; older `dotnet sln` subcommands may not).

| Path | Role | References |
| --- | --- | --- |
| `src/RigRoom.Domain` | Rig profile, rig-fit rule, confidence labels, linear referencing (NetTopologySuite). **Zero infra dependencies** (guarded by `DomainDependencyTests`). | — |
| `src/RigRoom.Contracts` | DTOs + validation shared by API, MAUI, and Blazor | — |
| `src/RigRoom.ApiClient` | Typed HTTP client, offline outbox interfaces | Contracts |
| `src/RigRoom.Data` | EF Core + NetTopologySuite, migrations | Domain |
| `src/RigRoom.Api` | ASP.NET Core 10 **minimal APIs**, one route group per feature | Domain, Contracts, Data |
| `src/RigRoom.Mobile` | .NET MAUI, XAML + CommunityToolkit.Mvvm, Mapsui; `net10.0-android` + `net10.0-ios` | Domain, Contracts, ApiClient |
| `src/RigRoom.Web` | Blazor WASM: admin queue (R0), trip planner (R1); MapLibre via JS interop | Contracts, ApiClient |
| `pipeline/` | Python: `ingest/`, `candidates/`, `imagery/`, `terrain/`, `packs/`; `dbt/` for scoring | — |
| `infra/` | Bicep modules + per-environment parameter files | — |
| `tests/` | .NET unit + integration tests (Testcontainers PostGIS); `RigRoom.{Project}.Tests` | Project under test |
| `Docs/` | `ASOT/` canon, `ADR/`, field protocol, plans | — |

Root build files: `RigRoom.slnx` (everything), `RigRoom.NoMobile.slnf` (everything except `RigRoom.Mobile`, for CI and machines without the `maui` workload), `global.json` (SDK pin + MTP test runner), `Directory.Build.props` (nullable, implicit usings, C# 14, code style enforced in build). Target frameworks stay in each csproj because Mobile multi-targets.

Mobile references Domain because drive mode runs the rig-fit rule and route projection on the device with no network.

## Architecture Rules Already Decided

- **The database is the contract between pipeline and app.** Python jobs and dbt write `evidence` and `scores`; the API only reads them. Neither side calls the other.
- **`evidence` is append-only.** Admin decisions and check-ins land as new evidence rows; nothing overwrites evidence.
- **Licensing hygiene.** Every record keeps its source license. **Never import OSM-derived (share-alike) data into resale tables** — the `source` share-alike flag is enforced in the schema from M1.
- **Corridor packs are two files:** a basemap tile pack plus a SQLite site pack. Drive mode needs only NetTopologySuite and SQLite on the device — no network.
- **Check-ins use an outbox.** Client-generated GUID, written to local SQLite first, retried until the API confirms. The GUID makes retries idempotent; the API must treat a repeat GUID as success, not a conflict.
- **Photos** upload to private Blob Storage through short-lived SAS URLs; never public containers.
- **Auth0** is the IdP. Tokens are validated on every API call; authorization policies are **per-permission** (Auth0 `permissions` claim), not per-role.
- **User-owned data** (rigs, trips, check-ins) is always filtered by the caller's user id from the token. Never accept an owner id from the route or body.

## Coding Patterns (Backend)

Target: .NET 10, C# 14, nullable enabled, implicit usings enabled. Always check current Microsoft documentation for .NET 10 changes before relying on older patterns — use the `microsoft-learn` MCP server (search docs, fetch a page, search code samples) rather than memory or web search.

### Endpoints (minimal APIs)

- One static `Map{Feature}Endpoints(this IEndpointRouteBuilder)` per feature, using `MapGroup("api/{feature}")` with `.RequireAuthorization()` on the group. Anonymous endpoints opt out explicitly.
- Routes are kebab-case nouns, nested under parent IDs: `api/rigs/{rigId}/...`.
- Handlers stay thin: resolve the caller from the user context, delegate to a sealed service, map entity → DTO. Return `TypedResults` (`Ok`, `Created`, `NoContent`, `NotFound`).
- Search endpoints that need a complex filter use `POST .../search` with a request DTO body.
- **Never put `try/catch` in endpoint handlers.** The global exception handler owns all exceptions.

### Services

- Always `sealed` and scoped. Inject repository/DbContext abstractions and `IUserContextAccessor` — never `HttpContext`.
- Guard clauses first: `ArgumentException.ThrowIfNullOrWhiteSpace()`, `ArgumentNullException.ThrowIfNull()`.
- Existence checks: fetch, throw `KeyNotFoundException` if null.
- Create via `requestDto.ToEntity(userId)`; update via `entity.ApplyUpdate(request, userId)`.
- Return domain entities, not DTOs.

### Mappers

- One `public static class` per aggregate using extension methods; every method starts with `ArgumentNullException.ThrowIfNull()`.
- Entity → DTO: `ToDetailDto()`, `ToSummaryDto()`, `ToDto()`. Create: `ToEntity(...)`. Update: `ApplyUpdate(...)` mutates in place, then calls `entity.MarkAsUpdated(userId)`.
- Partial updates apply only non-null DTO fields. Trim name-like strings.
- **Pure data transforms only** — no repository or service calls.

### Entities and DTOs

- Entities inherit an abstract `EntityBase`. Identity fields are `init`-only (`Id`, `CreatedAtUtc`, `CreatedByUserId`); `MarkAsUpdated(userId)` stamps `UpdatedAtUtc` / `UpdatedByUserId`.
- DTOs live in `RigRoom.Contracts`; use `record` types. Naming: `{Entity}CreateRequestDto`, `{Entity}UpdateRequestDto`, `{Entity}SearchRequestDto`, `{Entity}DetailResponseDto`, `{Entity}SummaryResponseDto`.
- `PagedResult<T>` is a sealed record (`Page`, `PageSize`, `TotalCount`, `Items`).
- **Never expose entity types in API responses.**

### Interfaces

- Repository-style lookups return nullable (`Site?`) and always take a `CancellationToken`.
- Service methods return non-nullable (existence already validated).
- Public interfaces carry XML doc comments.

### Data Access (EF Core + PostGIS)

- Migrations are generated with `dotnet ef migrations add` and committed. **Never edit a migration that has been applied to any shared environment** — add a new one.
- Migrations run from the deploy pipeline, not at app startup.
- Tables written by the pipeline/dbt are read-only from the API's point of view.

### dbt Conventions

dbt lives in `pipeline/dbt/` (dbt-postgres) and turns `evidence` into scores. It reads `evidence` and `source` and never writes them.

- **Three model layers, one folder each.** `models/staging/` holds one `stg_<source>__<entity>` view per raw table (rename, cast, and filter only; no joins or business logic). `models/intermediate/` holds `evidence_aged` (half-life decay) and `attribute_value` (winning value per attribute, contested flag).
  `models/marts/` holds `site_score` (physical-fit and permission scores plus the maximum rig length each site fits). Model names in the Implementation Plan are canon; don't rename them.
- **Names** are `snake_case`, singular nouns matching the app tables (`site`, `evidence`, `score`, not `sites`). Keys are `<entity>_id`; timestamps end `_at_utc`; lengths carry their unit (`usable_length_ft`); booleans start `is_` or `has_`; confidences in 0–1 end `_confidence` or `_score`.
- **Seeds** in `seeds/` hold reference data the brief defines: source weights and `attr_half_life`. Changing a seed changes scores, so it goes through a PR like code.
- **Every model** has a YAML entry with a description, `unique` + `not_null` on its key, and `relationships` to its parents. Score columns get a 0–1 range test, and every `site_score` row must have evidence behind it.
- **Licensing:** models that feed resale or export tables filter out sources with the share-alike flag set. Never import OSM-derived data into resale tables.

### Validation

- Guard clauses in every service method for required parameters.
- Static validator classes for complex multi-field rules (in `RigRoom.Contracts` so MAUI and Blazor share them).
- Block dangerous characters (`<`, `>`, `;`, `'`, `"`, `\`, `\0`) in free-text search inputs. Enforce max string lengths; page size cap is **100**.
- **422** for validation errors, **400** for unparsable input.

### Exception Handling

- One global handler (`IExceptionHandler` + `AddProblemDetails()`). Mapping: `ArgumentException` → **400**, `UnauthorizedAccessException` → **401**, `KeyNotFoundException` → **404**, `ConflictException` → **409**, everything else → **500**.
- Responses carry a safe message and an `errorId` (GUID) that is also logged. Dev adds exception detail; never expose internals outside Development.
- Log full details (exception, userId, path, errorId) via `ILogger`.

### Middleware Pipeline Order

Order is load-bearing:

1. Dev-only endpoints (OpenAPI)
2. HTTPS redirection (non-dev)
3. CORS — environment-specific named policy, **never** `AllowAnyOrigin`
4. Rate limiter (anonymous endpoints)
5. Exception handler
6. Authentication → Authorization
7. Correlation logging (after auth so claims are populated)
8. Health endpoints (no auth)
9. Endpoint mapping

### DI Lifetimes

- SDK clients (Blob, HTTP factories): **singleton**. `DbContext`, repositories, services, `IUserContextAccessor`: **scoped**. `IMiddleware` types: **singleton**.

### External Integrations

- Every external client (Valhalla, vision LLM, Auth0 management, Stripe later) uses `AddStandardResilienceHandler` with per-client timeouts and `IOptions<T>` config.
- Each integration has a mock/no-op implementation behind the same interface for dev and tests. **Choose the implementation explicitly in config and log which one was registered at startup** — RVS learned the hard way that a silent "endpoint unset → fall back to mock" path hides misconfiguration in deployed environments.
- Disable automatic retries on non-idempotent calls (sends, charges) unless the call carries an idempotency key.

### Secrets & Telemetry

- **Development**: `appsettings.Development.json` (git-ignored) + `dotnet user-secrets`.
- **Azure**: Key Vault, loaded at startup when `KeyVault:VaultUri` is set (injected by Bicep). `DefaultAzureCredential` → Managed Identity in Azure. In local dev prefer `AzureCliCredential` directly to skip the slow managed-identity probe.
- Application Insights registers only when `APPLICATIONINSIGHTS_CONNECTION_STRING` is present (injected by Bicep; absent locally = no telemetry). Treat precise GPS traces and photos as PII — filter them out of telemetry.

### New-Feature Checklist

1. Entity + domain logic in **Domain**; DTOs + validators in **Contracts**.
2. EF configuration + migration in **Data**.
3. Mapper, sealed service, endpoint group in **Api**; register in `Program.cs`.
4. Typed client method in **ApiClient** if MAUI/Blazor consume it.
5. Tests written **first** (below).

## Testing — TDD Is Mandatory

Full rules in [.claude/rules/testing.md](.claude/rules/testing.md).

**Red → Green → Refactor, in this order for every issue:**

1. Domain/Contracts tests first — pure logic, zero mocks (rig-fit rule, confidence labels, distance-along-route projection, validators, mappers).
2. Service tests second — mock interfaces only.
3. API integration tests with `WebApplicationFactory` + Testcontainers PostGIS for spatial queries, check-in idempotency, and **auth on every endpoint**.
4. Implementation code **only** after failing tests exist.

Naming: `MethodName_Scenario_ExpectedResult`. **Never:** write production code before a failing test; modify a failing test to make it pass; skip Refactor; use `try/catch` or `Thread.Sleep` in tests; mock concrete classes.

Pipeline and scoring: pytest for each state mapper (against saved real layer samples) and for scoring fixtures with known answers; dbt tests assert scores stay in 0–1 and every score has evidence behind it.

**Microsoft.Testing.Platform gotcha (from RVS, updated for MTP v2):** xUnit v3 4.x runs on MTP v2, which removed the VSTest bridge (`TestingPlatformDotnetTestSupport`). `dotnet test` reaches the tests only because `global.json` sets `"test": { "runner": "Microsoft.Testing.Platform" }`; never remove it.
In this mode, pass a project with `--project` and a solution with `--solution` (a bare path argument no longer works), and put MTP options after `--` (`-- --coverage`, `-- --filter-class "*.FooTests"`). `tests/Directory.Build.props` sets `OutputType=Exe` and `--minimum-expected-tests 1`, so a project that discovers zero tests fails instead of passing green.

## Common Commands

Development is on macOS (zsh, VS Code).

```bash
dotnet restore RigRoom.slnx
dotnet build RigRoom.slnx --configuration Release              # needs the maui workload + platform SDKs
dotnet build RigRoom.NoMobile.slnf --configuration Release     # everything except Mobile
dotnet test --solution RigRoom.NoMobile.slnf --configuration Release
dotnet test --project tests/<Project>/<Project>.csproj --configuration Release --no-build -- --coverage --coverage-output-format cobertura
dotnet test --project tests/<Project>/<Project>.csproj --configuration Release --no-build -- --filter-class "*.SomeTests"
```

Blazor WASM builds without extra workloads; `wasm-tools` is needed only for AOT or IL relinking on publish. MAUI needs the `maui` workload, a JDK and Android SDK for Android, and for iOS a current Xcode, which needs a recent macOS.

## CI/CD Methodology

Everything is deployed by GitHub Actions from Bicep; nothing is created by hand.

- **ci.yml** — PR gate on every push/PR: .NET build + tests (Testcontainers PostGIS), Python lint + pytest, `dbt build` against a throwaway DB, Bicep `what-if`. **Never deploys.**
- **deploy.yml** — on merge to `main`. **The only place that builds deployable artifacts** (container images to ACR). Deploys Bicep, runs EF migrations, deploys API and jobs to dev. Every deploy job `needs:` the test job, so a red suite blocks the deploy.
- **Production promotes, never rebuilds.** Prod deploys the exact image digests dev validated, behind a GitHub environment with **required reviewers**.
- **mobile.yml** on tag: Android → Play internal testing (Ubuntu runner); iOS → TestFlight via App Store Connect API (macOS runner).
- **valhalla.yml** monthly: rebuild routing tiles from OSM extracts and swap onto Azure Files.
- **Auth:** Azure OIDC with federated credentials per GitHub environment (`repo:<owner>/<repo>:environment:<env>`) — no long-lived Azure secrets. Environment-scoped values go in GitHub environment **variables**; only true secrets go in environment **secrets**.
- Keep a runbook at `.github/workflows/README.md` (environment setup, federated credentials, troubleshooting) once workflows exist.
