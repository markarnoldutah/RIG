---
description: 'Guidelines for building C# applications'
applyTo: '**/*.cs'
---

# C# Development

## General

- Always use the latest C# version, currently C# 14.
- Make only high-confidence suggestions when reviewing code changes.
- Write maintainable code, with comments explaining **why** a design decision was made — not what the code does.
- Handle edge cases and write clear exception handling.
- For libraries or external dependencies, note their purpose in a comment where they are wired up.

## Naming Conventions

- PascalCase for types, methods, and public members.
- camelCase for private fields and local variables.
- Prefix interface names with `I` (e.g. `IRigService`).

## Formatting

- Apply the code-formatting style defined in `.editorconfig`.
- Prefer file-scoped namespace declarations and single-line using directives.
- Insert a newline before the opening curly brace of any code block (after `if`, `for`, `while`, `foreach`, `using`, `try`, etc.).
- Put the final return statement of a method on its own line.
- Use pattern matching and switch expressions wherever possible.
- Use `nameof` instead of string literals when referring to member names.
- Create XML doc comments for public APIs. Include `<example>` and `<code>` where useful.

## Nullable Reference Types

- Declare variables non-nullable, and check for `null` at entry points.
- Always use `is null` / `is not null` instead of `== null` / `!= null`.
- Trust the null annotations — don't add null checks when the type system says a value cannot be null.

## Async

- Async all the way down; no `.Result` or `.Wait()`.
- Every I/O method takes a `CancellationToken` and passes it through.
- Suffix async methods with `Async`.

## Data Access — EF Core + NetTopologySuite

- Use EF Core with the Npgsql provider and NetTopologySuite for PostGIS geometry.
- Keep spatial and along-route queries server-side (translated to PostGIS), never by loading rows into memory to filter.
- Use `AsNoTracking()` for read-only queries.
- Migrations are generated with `dotnet ef migrations add`, committed, and never edited once applied to a shared environment.
- Avoid N+1 queries: project to DTO shapes with `Select` or use explicit `Include`.

## Shared Code Across API, MAUI and Blazor

- Code in `BigRig.Domain` and `BigRig.Contracts` must not reference ASP.NET Core, EF Core, or MAUI types — it runs on the server, the phone, and in the browser.
- Validators in `BigRig.Contracts` are the single source of validation rules; clients and the API both call them.

## Performance

- Paginate list endpoints (cap 100), filter and sort server-side.
- Use `IMemoryCache` for small, slowly-changing reference data.
- Measure before optimizing; route queries have a 2 s target (PRD).

## Containers

- API and pipeline jobs ship as containers to Azure Container Apps. Prefer .NET's built-in container publishing (`dotnet publish --os linux --arch x64 -p:PublishProfile=DefaultContainer`) over a hand-written Dockerfile unless the image needs extra native dependencies.
- Expose health and readiness endpoints for every service.
