---
name: csharp-async
description: Review or write C# async/await code against best practices (Task/ValueTask, cancellation, ConfigureAwait, deadlocks, async void, MAUI/Blazor UI threads). Use when writing or reviewing async C# code or when the user asks about async patterns.
---

# C# Async Programming Best Practices

Apply these when writing async C# code, and when reviewing it, report violations with file:line and a suggested fix. If the user names files or a scope, review those; otherwise review the current git diff.

## Naming

- Use the `Async` suffix for all async methods.
- Match the synchronous counterpart's name when one exists (`GetSite()` → `GetSiteAsync()`).

## Return Types

- `Task<T>` when returning a value, `Task` when not.
- `ValueTask<T>` only for hot paths that usually complete synchronously, and never await a `ValueTask` twice.
- `IAsyncEnumerable<T>` for streaming sequences (e.g. reading pipeline output, paging large queries).
- No `async void` except event handlers.

## Cancellation

- Every I/O method accepts a `CancellationToken` and passes it to every awaited call (EF Core, `HttpClient`, Blob SDK).
- Minimal API handlers take a `CancellationToken` parameter (bound to `HttpContext.RequestAborted`).
- Don't swallow `OperationCanceledException`.

## Exceptions

- Let exceptions propagate. In this repo, endpoint handlers and services have **no** `try/catch`; the global exception handler maps them. Catch only where you can actually handle or translate the failure (e.g. outbox retry logic).
- In an `async` method, `throw` directly — the exception is captured in the returned task.
- In a **non-async** method that returns `Task`, return `Task.FromException(...)` / `Task.FromCanceled(...)` rather than throwing synchronously, so callers observe the failure consistently.
- Guard-clause argument validation may throw synchronously before the first `await`.

## ConfigureAwait

- ASP.NET Core has no synchronization context: `ConfigureAwait(false)` is unnecessary in `BigRig.Api`.
- Use `ConfigureAwait(false)` in shared library code consumed by UI apps (`BigRig.ApiClient`, `BigRig.Domain`, `BigRig.Contracts`).
- **Never** in MAUI view models or Blazor components where the continuation touches UI state.

## UI Apps (MAUI and Blazor WASM)

- Blazor WASM is single-threaded: any `.Result`/`.Wait()` deadlocks or freezes the app.
- MAUI: use CommunityToolkit.Mvvm `[RelayCommand]` on `async Task` methods (generates `AsyncRelayCommand`) instead of `async void` handlers; it exposes `IsRunning` and supports cancellation.
- Marshal back to the UI thread with `MainThread.BeginInvokeOnMainThread` only when a continuation runs off the UI thread (e.g. GPS/location callbacks).
- Drive mode GPS and background sync loops must honour cancellation and not leak timers.

## Performance

- `Task.WhenAll` for independent concurrent work; bound concurrency (`Parallel.ForEachAsync` with `MaxDegreeOfParallelism`) when calling external services.
- `Task.WhenAny` / `CancellationTokenSource.CancelAfter` / `Task.WaitAsync(timeout)` for timeouts.
- Don't share one `DbContext` across concurrent tasks — EF Core contexts are not thread-safe.
- Elide `async`/`await` only for pure pass-throughs with no `using`/`try` around them.

## Pitfalls

- Never `.Wait()`, `.Result`, or `.GetAwaiter().GetResult()` on async code.
- No fire-and-forget `Task`s without an owner that observes failures; use a hosted service or background queue instead.
- Always await (or deliberately return) every Task-returning call.
- `Task.Run` is for CPU-bound work in UI apps, not for wrapping I/O in ASP.NET Core.
