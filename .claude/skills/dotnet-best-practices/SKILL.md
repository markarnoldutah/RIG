---
name: dotnet-best-practices
description: Review .NET/C# code against this repo's conventions (minimal APIs, sealed services, mappers, DTOs, EF Core/PostGIS, DI lifetimes, validation, testing, C# 14 idioms) and fix or report issues. Use when the user asks to check, review, clean up, or bring C# code in line with best practices.
argument-hint: "[file, folder, or 'diff']"
---

# .NET/C# Best Practices Review

Review the scope in `$ARGUMENTS` (a file, folder, or `diff`). With no argument, review the uncommitted changes (`git diff` plus untracked `.cs` files).

The authoritative conventions are in `CLAUDE.md` and `.github/instructions/*.instructions.md` — read them first. This skill is the checklist; those files win if they disagree.

## Checklist

### Structure & layering
- `BigRig.Domain` / `BigRig.Contracts` reference no ASP.NET Core, EF Core, or MAUI types.
- Endpoint handlers are thin (caller → sealed service → mapper → `TypedResults`), grouped with `MapGroup` per feature, no `try/catch`.
- Services are `sealed`, scoped, use `IUserContextAccessor` (never `HttpContext`), start with guard clauses, return entities.
- Mappers are static extension classes, pure, start with `ArgumentNullException.ThrowIfNull()`.
- Entities never leave the API; DTOs are `record`s with the standard naming.

### Ownership & security
- Every group has `.RequireAuthorization(...)`; anonymous endpoints are explicit.
- User-owned data filtered by the caller's user id from the token.
- No string-built SQL; free-text inputs validated; page size ≤ 100; no secrets in code or committed config; no PII in logs.

### Data access
- Spatial filtering runs in PostGIS; reads use `AsNoTracking()`; no N+1; no in-memory filtering of large sets.
- Migrations are additive; none edited after being applied to a shared environment.
- The API never writes pipeline-owned tables; `evidence` is append-only.

### DI & configuration
- Lifetimes per CLAUDE.md (SDK clients singleton; `DbContext`, services, user context scoped).
- Primary constructors for DI where they don't obscure guard clauses.
- Strongly-typed options (`IOptions<T>`) with `ValidateDataAnnotations().ValidateOnStart()`.
- External clients use `AddStandardResilienceHandler`; mock implementations are selected explicitly and logged.

### Async
- Async end-to-end with `CancellationToken` propagated (see the `csharp-async` skill).

### C# 14 / .NET 10 idioms
- File-scoped namespaces, `is null` / `is not null`, pattern matching and switch expressions, `nameof`, collection expressions, `required`/`init` members.
- Nullable annotations are trusted — no redundant null checks.
- XML docs on public APIs (see the `csharp-docs` skill).

### Logging
- `ILogger` message templates (or `[LoggerMessage]` source-generated methods on hot paths), never string interpolation.
- Meaningful scopes (correlation id, user id), no PII.

### Tests
- New behavior has tests written first, in the mirrored test folder, named `MethodName_Scenario_ExpectedResult`.
- Service tests cover null/empty user id, not-found, null DTO, and another user's resource.
- xUnit v3 + Moq on interfaces only; no `try/catch` or `Thread.Sleep` in tests.

## Output

Group findings as **Critical / Major / Minor**, each with `file:line`, the rule, and a concrete fix. If the user asked for fixes, apply them, then run the affected tests (`dotnet test --project <project> -- --filter-class "*.<Name>Tests"`) and report the result. Don't commit.
