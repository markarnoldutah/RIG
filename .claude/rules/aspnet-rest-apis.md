---
description: 'Guidelines for building REST APIs with ASP.NET Core minimal APIs'
# Claude Code reads `paths`; GitHub Copilot reads `applyTo` (via the symlink in .github/instructions/).
paths:
  - "src/BigRig.Api/**/*.cs"
  - "src/BigRig.Api/**/*.json"
  - "tests/BigRig.Api*/**/*.cs"
applyTo: 'src/BigRig.Api/**/*.cs, src/BigRig.Api/**/*.json, tests/BigRig.Api*/**/*.cs'
---

# ASP.NET Core API Development

The API (`BigRig.Api`) uses ASP.NET Core 10 **minimal APIs**, not controllers. Project-specific patterns are in `CLAUDE.md` (mirrored in `.github/copilot-instructions.md`); this file covers general API practice.

## API Design

- Resource-oriented, kebab-case URLs with correct HTTP verbs and status codes.
- Organize endpoints with route groups (`MapGroup`), one group per feature, in a static `Map{Feature}Endpoints` extension method.
- Return `TypedResults` so OpenAPI metadata is inferred from the handler signature.
- Use parameter binding attributes (`[FromRoute]`, `[FromBody]`, `[AsParameters]`) only where inference is ambiguous.

## Authentication and Authorization

- Auth0 JWT Bearer; validate audience and issuer.
- Authorization policies are per-permission (`permissions` claim). Apply `.RequireAuthorization(policy)` on the group; opt out explicitly with `.AllowAnonymous()`.
- Admin endpoints (verification queue) require an admin permission, never a client-side flag.
- Every endpoint gets an integration test asserting it rejects an unauthenticated caller.

## Validation and Error Handling

- Validate request DTOs with the shared validators in `BigRig.Contracts`.
- One global `IExceptionHandler` with `AddProblemDetails()` produces RFC 7807 responses; handlers contain no `try/catch`.
- Never leak stack traces or internal messages outside Development.

## Idempotency

- Check-in and other offline-outbox writes carry a client GUID. A repeat of a GUID already stored returns success with the existing resource, not 409.

## Documentation

- Built-in OpenAPI (`AddOpenApi` / `MapOpenApi`) in Development; document parameters, responses, and auth requirements.
- XML doc comments on DTOs flow into the OpenAPI description.

## Logging and Monitoring

- Structured logging via `ILogger` with message templates (no string interpolation in log calls).
- Correlation ID per request in the log scope.
- Application Insights through OpenTelemetry, registered only when the connection string is present. Filter PII (precise GPS, photos, emails) from telemetry.

## Performance

- Async throughout; pass `CancellationToken` from the handler to the data layer.
- Paginate, filter and sort server-side; page size cap 100.
- Response compression for JSON; corridor packs are served from Blob, not through the API.

## Deployment

- Containerize with .NET's built-in container publishing; deploy to Azure Container Apps.
- Health checks (`/health`) are anonymous and excluded from auth and rate limiting.
- Environment-specific configuration comes from Bicep-injected settings and Key Vault, never from committed appsettings.
