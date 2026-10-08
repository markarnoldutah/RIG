# Copilot Instructions — Big-Rig Pullout Map

## Working an Issue

When the user says **"Execute Issue #abc"** (where `abc` is a valid GitHub Issue number), before doing any work:

1. Create a new branch off the current base branch (usually `main`) named `abc-some-meaningful-identifier` — `abc` is the issue number, followed by a short kebab-case slug describing the issue (e.g. `42-mapsui-offline-spike`).
2. Check out that branch, then perform the work for the issue on it.

Do not commit issue work directly to `main`. If the branch already exists, check it out and continue on it rather than creating a duplicate.

**Never commit or push automatically.** Do the work, leave the changes in the working tree, and stop. Run `git commit` or `git push` only when the user explicitly asks for it in that same message — creating a branch or being told to "execute" an issue is not permission to commit.

## Project Documentation

- Product canon is in `Docs/ASOT/`: `Big-Rig-Pullout-Map-Product-and-Data-Brief.md` (what this is, data sources, scoring), `Big-Rig-Pullout-Map-PRD.md` (**if a requirement isn't there, it isn't in scope**; each FR is scoped to its tagged release), `Big-Rig-Pullout-Map-Implementation-Plan.md` (milestones, sequencing, defaults for open decisions).
- One authoritative home per fact. A new canon doc is registered here and in `CLAUDE.md` on the same commit.
- Bicep under `infra/` is the source of truth for Azure resources. Nothing is created by hand in the portal.
- Build the current release only (R0 now). Do not build R1+ features early unless the Implementation Plan says so.

## Project Structure

- `src/BigRig.Domain` — rig-fit rule, confidence labels, linear referencing (NetTopologySuite). Zero infra dependencies.
- `src/BigRig.Contracts` — DTOs + validators shared by API, MAUI, Blazor.
- `src/BigRig.ApiClient` — typed HTTP client, offline outbox interfaces.
- `src/BigRig.Data` — EF Core + NetTopologySuite (PostgreSQL + PostGIS), migrations.
- `src/BigRig.Api` — ASP.NET Core 10 minimal APIs, one route group per feature.
- `src/BigRig.Mobile` — .NET MAUI, CommunityToolkit.Mvvm, Mapsui.
- `src/BigRig.Web` — Blazor WASM admin queue / trip planner, MapLibre via JS interop.
- `pipeline/` (Python + dbt), `infra/` (Bicep), `tests/`.
- Target: .NET 10, C# 14, nullable enabled, implicit usings enabled. Always check current Microsoft documentation for .NET 10 changes, via the `microsoft-learn` MCP server.

## Architecture Rules

- The database is the contract between pipeline and app: pipeline/dbt write `evidence` and `scores`; the API only reads them.
- `evidence` is append-only. Admin decisions and check-ins become new evidence.
- Every record keeps its source license. Never import OSM-derived (share-alike) data into resale tables.
- Check-ins use a client-GUID outbox; the API treats a repeated GUID as success (idempotent).
- Photos go to private Blob Storage via short-lived SAS URLs.
- Auth0 tokens validated on every call; policies are per-permission (`permissions` claim), not per-role.
- User-owned data is filtered by the caller's user id from the token — never an owner id from the route or body.

## Endpoints (Minimal APIs)

- One `Map{Feature}Endpoints` extension per feature using `MapGroup(...)` + `.RequireAuthorization()`; anonymous endpoints opt out explicitly.
- Kebab-case noun routes nested under parent IDs: `api/rigs/{rigId}/...`.
- Thin handlers: resolve caller → sealed service → map entity to DTO → `TypedResults`.
- Complex searches use `POST .../search` with a request DTO.
- Never put `try/catch` in handlers — the global exception handler owns exceptions.

## Services

- Always `sealed`, scoped. Inject abstractions and `IUserContextAccessor` (never `HttpContext`).
- Guard clauses first: `ArgumentException.ThrowIfNullOrWhiteSpace()`, `ArgumentNullException.ThrowIfNull()`.
- Fetch then throw `KeyNotFoundException` if missing.
- Create via `requestDto.ToEntity(userId)`; update via `entity.ApplyUpdate(request, userId)`.
- Return domain entities, not DTOs.

## Mappers

- One `public static class` per aggregate with extension methods; every method starts with `ArgumentNullException.ThrowIfNull()`.
- `ToDetailDto()`, `ToSummaryDto()`, `ToDto()`, `ToEntity(...)`, `ApplyUpdate(...)` (mutates in place, calls `MarkAsUpdated(userId)`).
- Partial updates apply only non-null fields; trim name-like strings.
- Pure data transforms only — no repository or service calls.

## Entities & DTOs

- Entities inherit abstract `EntityBase`; `init`-only `Id`, `CreatedAtUtc`, `CreatedByUserId`; `MarkAsUpdated(userId)` stamps update audit fields.
- DTOs are `record`s in `BigRig.Contracts`: `{Entity}CreateRequestDto`, `{Entity}UpdateRequestDto`, `{Entity}SearchRequestDto`, `{Entity}DetailResponseDto`, `{Entity}SummaryResponseDto`.
- `PagedResult<T>` sealed record: `Page`, `PageSize`, `TotalCount`, `Items`.
- Never expose entity types in API responses.

## Data Access

- EF Core migrations are generated and committed; never edit a migration already applied to a shared environment.
- Migrations run from the deploy pipeline, not at startup.
- Pipeline-owned tables are read-only to the API.

## Validation & Errors

- Guard clauses in every service method. Shared validators live in `BigRig.Contracts`.
- Block `<`, `>`, `;`, `'`, `"`, `\`, `\0` in free-text search; enforce max lengths; page size cap 100.
- 422 for validation errors, 400 for unparsable input.
- Global `IExceptionHandler` + ProblemDetails: `ArgumentException` → 400, `UnauthorizedAccessException` → 401, `KeyNotFoundException` → 404, `ConflictException` → 409, else 500. Include an `errorId` GUID that is also logged; never expose internals outside Development.

## Middleware Order

Dev OpenAPI → HTTPS redirection (non-dev) → CORS (named, environment-specific, never `AllowAnyOrigin`) → rate limiter → exception handler → authentication → authorization → correlation logging → health endpoints → endpoint mapping.

## DI & Integrations

- SDK clients singleton; `DbContext`, repositories, services, `IUserContextAccessor` scoped; `IMiddleware` singleton.
- Every external client uses `AddStandardResilienceHandler` with per-client timeouts and `IOptions<T>`.
- Each integration has a mock implementation behind the same interface; select it explicitly in config and log the choice at startup — never silently fall back.
- Secrets: user-secrets in dev; Key Vault + `DefaultAzureCredential` (Managed Identity) in Azure. App Insights only when its connection string is present. Treat GPS traces and photos as PII.

## TDD — Mandatory for All Issues

Red → Green → Refactor, not optional.

1. Domain/Contracts tests first — pure logic, no mocks.
2. Service tests — mock interfaces only.
3. API integration tests — `WebApplicationFactory` + Testcontainers PostGIS; cover auth on every endpoint.
4. Implementation only after failing tests exist.

- Never write production code without a failing test first.
- Never modify a failing test to make it pass — fix the implementation.
- Never skip Refactor.
- Python pipeline: pytest; scoring: dbt tests (scores in 0–1, every score has evidence).

## CI/CD

- `ci.yml` is the PR gate — build, test, dbt build, Bicep what-if. Never deploys.
- `deploy.yml` on merge to `main` is the only place that builds deployable artifacts; deploy jobs `needs:` the tests.
- Production promotes the exact artifacts dev validated (same image digests) behind required reviewers — never rebuilds from source.
- Azure auth via OIDC federated credentials per GitHub environment; no long-lived Azure secrets.
