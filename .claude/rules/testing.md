---
description: 'Testing guidelines: xUnit v3, Moq, Testcontainers, TDD'
# Claude Code reads `paths`; GitHub Copilot reads `applyTo` (via the symlink in .github/instructions/).
paths:
  - "tests/**/*.cs"
applyTo: 'tests/**/*.cs'
---

# Big-Rig Testing Guidelines — xUnit v3 + Moq

## Stack

- **Framework**: xUnit v3 4.x (net10.0) on Microsoft.Testing.Platform (MTP) v2. Test assemblies are self-executing MTP apps (`OutputType=Exe`, set in `tests/Directory.Build.props`). `dotnet test` uses MTP only because `global.json` sets `"test": { "runner": "Microsoft.Testing.Platform" }`. MTP v2 dropped the `TestingPlatformDotnetTestSupport` VSTest bridge, so don't add it back. `--minimum-expected-tests 1` makes a project with zero discovered tests fail.
- **Mocking**: Moq 4.x — interfaces only.
- **Assertions**: AwesomeAssertions (Apache-2.0 fork of FluentAssertions; same `Should()` API). FluentAssertions 8+ needs a paid commercial license, so don't add it.
- **Integration**: `WebApplicationFactory` + Testcontainers (PostgreSQL with PostGIS image).
- **Coverage**: `Microsoft.Testing.Extensions.CodeCoverage` — `dotnet test --project <csproj> --no-build -- --coverage --coverage-output-format cobertura`.
- **Filtering**: MTP simple filters after `--`, e.g. `-- --filter-class "*.RigFitRuleTests"` or `-- --filter-method "*.Foo.Bar"` (wildcard `*` only at start/end). VSTest `--filter "FullyQualifiedName~..."` does not work.
- Keep `Microsoft.Testing.Extensions.*` package versions aligned with the MTP major version that `xunit.v3` pulls in, or extensions fail with `TypeLoadException`.

## TDD Cycle — Non-Negotiable Order

1. 🔴 RED — Write a failing test in the correct project first. No implementation yet.
2. 🟢 GREEN — Write the minimal implementation to pass. Do not over-engineer.
3. 🔵 REFACTOR — Clean up per `CLAUDE.md` / `.github/copilot-instructions.md`. All tests stay green.

## Test File Placement

- Mirror the source folder inside the test project, e.g. `src/BigRig.Api/Services/CheckInService.cs` → `tests/BigRig.Api.Tests/Services/CheckInServiceTests.cs`.
- Shared test data lives in `tests/*/Fakes/`.

## Naming Convention

`MethodName_Scenario_ExpectedResult`:

- `Fits_WhenSiteShorterThanRigPlusMargin_ShouldReturnFalse`
- `CreateAsync_WhenClientIdAlreadyStored_ShouldReturnExistingCheckIn`
- `ToEntity_WhenRequestIsNull_ShouldThrowArgumentNullException`

## Test Structure (AAA)

```csharp
[Fact]
public async Task MethodName_Scenario_ExpectedResult()
{
    // Arrange
    var repo = new Mock<ICheckInRepository>();
    repo.Setup(...).ReturnsAsync(...);
    var sut = new CheckInService(repo.Object, userContext.Object);

    // Act
    var result = await sut.CreateAsync(..., TestContext.Current.CancellationToken);

    // Assert
    result.Should().NotBeNull();
}
```

## Layer Rules

- **Domain / Contracts tests**: zero mocks — pure inputs and outputs (rig-fit rule, confidence labels, distance-along-route projection, mappers, validators).
- **Service tests**: mock repository interfaces and `IUserContextAccessor`.
- **Middleware / exception-handler tests**: use `DefaultHttpContext` directly — no hosting.
- **Integration tests**: `WebApplicationFactory` + Testcontainers PostGIS for spatial queries, idempotent check-ins, and auth on every endpoint. Real SQL, not the EF in-memory provider (it cannot run PostGIS functions).

## Fakes Pattern

Static `*Fakes` classes per entity in `tests/*/Fakes/`:

```csharp
internal static class RigFakes
{
    public static Rig ValidRig(string id = "r1", string userId = "u1") => new() { ... };
    public static RigCreateRequestDto ValidCreateRequest() => new() { ... };
}
```

## Guard Clause Tests — Always Include

Every service test class covers:

- Null/empty user id → `ArgumentException`
- Not-found entity → `KeyNotFoundException`
- Null request DTO → `ArgumentNullException`
- Another user's resource → not returned (ownership is enforced, not just authentication)

## Forbidden

- No `try/catch` in tests — let exceptions propagate to xUnit.
- No `Thread.Sleep` — use `async/await` throughout.
- No `Assert.True(x == y)` — use fluent assertions.
- No mocking concrete classes — only interfaces.
- Never modify a failing test to make it pass — fix the implementation.
