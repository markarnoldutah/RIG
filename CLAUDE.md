# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Authoritative Docs

**Product canon** lives in [Docs/ASOT/](Docs/ASOT/):

| Document | Use it when |
| --- | --- |
| [Big-Rig-Pullout-Map-Product-and-Data-Brief.md](Docs/ASOT/Big-Rig-Pullout-Map-Product-and-Data-Brief.md) | You need to remember what this is, the data sources, or the scoring model |
| [Big-Rig-Pullout-Map-PRD.md](Docs/ASOT/Big-Rig-Pullout-Map-PRD.md) | You're writing code. **If a requirement isn't here, it isn't in scope** — and an FR is only in scope for the release it is tagged with (R0, R1, …) |
| [Big-Rig-Pullout-Map-Implementation-Plan.md](Docs/ASOT/Big-Rig-Pullout-Map-Implementation-Plan.md) | You're deciding what to do next, sequencing milestones, or need a default for an open decision |

One authoritative home per fact. A document earns its place by answering a question someone actually asks; register a new one in this table and in `.github/copilot-instructions.md` on the same commit. Architecture decisions are recorded as ADRs (one per stack decision) once the repo structure exists.

- **Infra source of truth** will be the Bicep modules under `infra/`. Do not trust hand-drawn diagrams or older docs for Azure resource configuration. Nothing is created by hand in the portal.
- Frozen snapshots (an `ARCHIVE/` or `Obsolete/` folder, if one is added) are **never** cited as current.
- Path-scoped rules (C#, ASP.NET, Blazor, Markdown, Testing) live in [.claude/rules/](.claude/rules/) and load when matching files are touched. Edit them there: `.github/instructions/*.instructions.md` are symlinks to the same files for Copilot.
- Claude Code skills live in [.claude/skills/](.claude/skills/): `dotnet-best-practices`, `csharp-async`, `csharp-docs`, `appinsights-instrumentation`, `az-cost-optimize`, `frontend-design`. Copilot-format agents and remaining skills live in [.github/agents/](.github/agents/) and [.github/skills/](.github/skills/) (e.g. `code-review`, `bicep-plan`, `dotnet-maui`, `create-architectural-decision-record`). Output locations: ADRs in `Docs/ADR/`, implementation plans in `Docs/Plans/`, epic breakdowns in `Docs/Epics/`, Claude Code plans in `Docs/Claude_Plans/`.

**Scope discipline.** Build the current release only. R0 is: rig profile, route planning on US-50 and two Utah corridors, corridor download, offline drive mode, manual check-ins with photos, admin verification queue. R1+ features (Cracker Barrel, background alerts, Stripe, web trip planner) are not built early unless the Implementation Plan says so (e.g. the share-alike flag is enforced in the schema from M1).

## Working an Issue

When the user says **"Execute Issue #abc"** (where `abc` is a valid GitHub Issue number), before doing any work:

1. Create a new branch off the current base branch (usually `main`) named `abc-some-meaningful-identifier` — `abc` is the issue number, followed by a short kebab-case slug describing the issue (e.g. `42-mapsui-offline-spike`).
2. Check out that branch, then perform the work for the issue on it.

Do not commit issue work directly to `main`. If the branch already exists, check it out and continue on it rather than creating a duplicate.

## Committing

**Never commit or push automatically.** Do the work, leave the changes in the working tree, and stop there. Run `git commit` or `git push` only when I explicitly ask for it in that same message. Creating a branch, "executing" an issue, or being told to "make the change" is **not** permission to commit — wait for an explicit "commit this" / "push it" instruction.

## Repo Layout (planned)

One monorepo holds the .NET solution, the Python pipeline, dbt, and Bicep, so one PR can change a contract and both its producer and consumer. Use the **SLNX** solution format (`dotnet` CLI handles it; older `dotnet sln` subcommands may not).

| Path | Role |
| --- | --- |
| `src/BigRig.Domain` | Rig profile, rig-fit rule, confidence labels, linear referencing (NetTopologySuite). **Zero infra dependencies.** |
| `src/BigRig.Contracts` | DTOs + validation shared by API, MAUI, and Blazor |
| `src/BigRig.ApiClient` | Typed HTTP client, offline outbox interfaces |
| `src/BigRig.Data` | EF Core + NetTopologySuite, migrations |
| `src/BigRig.Api` | ASP.NET Core 10 **minimal APIs**, one route group per feature |
| `src/BigRig.Mobile` | .NET MAUI, XAML + CommunityToolkit.Mvvm, Mapsui |
| `src/BigRig.Web` | Blazor WASM: admin queue (R0), trip planner (R1); MapLibre via JS interop |
| `pipeline/` | Python: ingest, candidates, imagery, terrain, packs; `pipeline/dbt/` for scoring |
| `infra/` | Bicep modules + per-environment parameter files |
| `tests/` | .NET unit + integration tests (Testcontainers PostGIS) |

Update this table when the real layout lands.

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
- DTOs live in `BigRig.Contracts`; use `record` types. Naming: `{Entity}CreateRequestDto`, `{Entity}UpdateRequestDto`, `{Entity}SearchRequestDto`, `{Entity}DetailResponseDto`, `{Entity}SummaryResponseDto`.
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

### Validation

- Guard clauses in every service method for required parameters.
- Static validator classes for complex multi-field rules (in `BigRig.Contracts` so MAUI and Blazor share them).
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

**Microsoft.Testing.Platform gotcha (from RVS):** with xUnit v3, `dotnet test` must route through MTP. Set `TestingPlatformDotnetTestSupport` and `OutputType=Exe` in `tests/Directory.Build.props`, and pass coverage/trx/filter flags **after `--`** (`-- --coverage`, `-- --filter-class "*.FooTests"`). Without it, `dotnet test` takes the VSTest path, discovers nothing, and exits 0 — a green CI run with zero tests.

## Common Commands

Development is on macOS (zsh, VS Code). Fill in once projects exist.

```bash
dotnet restore BigRig.slnx
dotnet build BigRig.slnx --configuration Release
dotnet test tests/<Project>/<Project>.csproj --configuration Release --no-build -- --coverage --coverage-output-format cobertura
dotnet test tests/<Project>/<Project>.csproj --configuration Release --no-build -- --filter-class "*.SomeTests"
```

Blazor WASM needs `dotnet workload install wasm-tools`; MAUI needs the `maui` workload (iOS builds need Xcode).

## CI/CD Methodology

Everything is deployed by GitHub Actions from Bicep; nothing is created by hand.

- **ci.yml** — PR gate on every push/PR: .NET build + tests (Testcontainers PostGIS), Python lint + pytest, `dbt build` against a throwaway DB, Bicep `what-if`. **Never deploys.**
- **deploy.yml** — on merge to `main`. **The only place that builds deployable artifacts** (container images to ACR). Deploys Bicep, runs EF migrations, deploys API and jobs to dev. Every deploy job `needs:` the test job, so a red suite blocks the deploy.
- **Production promotes, never rebuilds.** Prod deploys the exact image digests dev validated, behind a GitHub environment with **required reviewers**.
- **mobile.yml** on tag: Android → Play internal testing (Ubuntu runner); iOS → TestFlight via App Store Connect API (macOS runner).
- **valhalla.yml** monthly: rebuild routing tiles from OSM extracts and swap onto Azure Files.
- **Auth:** Azure OIDC with federated credentials per GitHub environment (`repo:<owner>/<repo>:environment:<env>`) — no long-lived Azure secrets. Environment-scoped values go in GitHub environment **variables**; only true secrets go in environment **secrets**.
- Keep a runbook at `.github/workflows/README.md` (environment setup, federated credentials, troubleshooting) once workflows exist.
