using System.Reflection;
using AwesomeAssertions;

namespace RigRoom.Domain.Tests;

/// <summary>
/// Guards the rule that RigRoom.Domain has zero infrastructure dependencies: it runs on the phone in
/// drive mode with only NetTopologySuite and SQLite, so EF Core, ASP.NET Core, and Azure SDKs must
/// never leak in.
/// </summary>
public sealed class DomainDependencyTests
{
    private static readonly string[] AllowedPrefixes = ["System", "Microsoft.CSharp", "netstandard", "NetTopologySuite"];

    [Fact]
    public void DomainAssembly_References_ShouldOnlyIncludeBclAndNetTopologySuite()
    {
        // Arrange
        var domain = Assembly.Load(new AssemblyName("RigRoom.Domain"));

        // Act
        var disallowed = domain.GetReferencedAssemblies()
            .Select(reference => reference.Name ?? string.Empty)
            .Where(name => !AllowedPrefixes.Any(prefix => name == prefix || name.StartsWith(prefix + ".", StringComparison.Ordinal)))
            .ToList();

        // Assert
        disallowed.Should().BeEmpty("RigRoom.Domain must stay free of infrastructure dependencies");
    }

    [Fact]
    public void DomainProject_ProjectReferences_ShouldBeEmpty()
    {
        // Arrange
        var csproj = Path.Combine(RepoRoot(), "src", "RigRoom.Domain", "RigRoom.Domain.csproj");

        // Act
        var text = File.ReadAllText(csproj);

        // Assert
        text.Should().NotContain("<ProjectReference", "RigRoom.Domain sits at the bottom of the dependency graph");
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "RigRoom.slnx")))
        {
            dir = dir.Parent;
        }

        return dir?.FullName ?? throw new InvalidOperationException("RigRoom.slnx not found above the test output directory.");
    }
}
