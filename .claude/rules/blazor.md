---
description: 'Blazor component and application patterns'
# Claude Code reads `paths`; GitHub Copilot reads `applyTo` (via the symlink in .github/instructions/).
paths:
  - "**/*.razor"
  - "**/*.razor.cs"
  - "**/*.razor.css"
applyTo: '**/*.razor, **/*.razor.cs, **/*.razor.css'
---

## Blazor Code Style and Structure

- Write idiomatic and efficient Blazor and C# code following .NET and Blazor conventions.
- Prefer inline `@code` for small components; move complex logic into code-behind or service classes.
- Use async/await for all API calls and UI actions that could block.

## Naming Conventions

- PascalCase for component names, methods, and public members.
- camelCase for private fields and local variables.
- Prefix interface names with `I`.

## Blazor Guidelines

- Use lifecycle methods appropriately (`OnInitializedAsync`, `OnParametersSetAsync`).
- Use `@bind` for data binding and `EventCallback` for child-to-parent events, passing minimal data.
- Use dependency injection for services; call the API only through the typed client in `BigRig.ApiClient`.
- Reduce unnecessary renders; use `ShouldRender()` where it measurably helps, and call `StateHasChanged()` deliberately.

## Maps (MapLibre via JS Interop)

- Keep all JS interop for MapLibre behind one C# wrapper service/component; components never call `IJSRuntime` for map work directly.
- Dispose `IJSObjectReference` and `DotNetObjectReference` instances (`IAsyncDisposable`).
- Pass GeoJSON or compact DTOs across the interop boundary, not large entity graphs.

## Error Handling and Validation

- Wrap page content in `ErrorBoundary`; show user-facing feedback on API failures.
- Validate forms with the shared validators from `BigRig.Contracts` so client and API rules cannot drift.

## State

- Use cascading parameters and `EventCallback` for simple state sharing; a scoped state-container service when state spans pages.
- Use `localStorage`/`sessionStorage` only for per-browser conveniences, never as the source of truth.

## Accessibility

- Every icon-only button has an `aria-label`.
- Never convey status (error, verified, unverified) by color alone — pair it with an icon or text.
- Check WCAG AA contrast for any custom colors.

## Security

- Auth0 OIDC with PKCE for the web app; tokens attached by the typed client's delegating handler.
- HTTPS only; the API's CORS policy names the web origins explicitly.

## Testing and Debugging

- Test components and view logic with xUnit (bUnit if component rendering needs testing).
- Mock interfaces only.
- Debug UI issues with browser developer tools and the VS Code debugger.
