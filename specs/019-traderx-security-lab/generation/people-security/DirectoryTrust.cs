using System.Globalization;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

namespace PeopleService.WebApi.Security;

public sealed class DirectoryTrust
{
    public static readonly HashSet<string> Routes = new(StringComparer.Ordinal)
        { "/People/GetPerson", "/People/GetMatchingPeople", "/People/ValidatePerson", "/health/alive" };
    public required RsaSecurityKey Key { get; init; }
    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required DateTimeOffset Until { get; init; }
    public required Dictionary<string, string> Roles { get; init; }

    static string Required(string name) => Environment.GetEnvironmentVariable(name)
        ?? throw new InvalidOperationException("Missing trusted identity configuration");

    static string Read(string name)
    {
        var path = Required(name);
        if (!Path.IsPathFullyQualified(path) || new FileInfo(path).Length > 65536)
            throw new InvalidOperationException("Invalid identity file");
        return File.ReadAllText(path);
    }

    public static DirectoryTrust Load()
    {
        var issuer = Required("LAB_IDENTITY_ISSUER");
        var audience = Required("LAB_IDENTITY_AUDIENCE");
        if (!Uri.TryCreate(issuer, UriKind.Absolute, out var uri) || uri.Scheme != "https" ||
            string.IsNullOrEmpty(uri.Host) || uri.UserInfo != "" || uri.Query != "" || uri.Fragment != "" ||
            string.IsNullOrWhiteSpace(audience)) throw new InvalidOperationException("Invalid trusted issuer");
        var until = DateTimeOffset.Parse(Required("LAB_IDENTITY_KEY_NOT_AFTER"), CultureInfo.InvariantCulture);
        if (until <= DateTimeOffset.UtcNow) throw new InvalidOperationException("Expired key snapshot");
        var rsa = RSA.Create(); rsa.ImportFromPem(Read("LAB_IDENTITY_PUBLIC_KEY_FILE"));
        if (rsa.KeySize < 2048) throw new InvalidOperationException("Invalid signing key");
        using var document = JsonDocument.Parse(Read("LAB_IDENTITY_DIRECTORY_ROLES_FILE"));
        var roles = new Dictionary<string, string>(StringComparer.Ordinal);
        if (document.RootElement.ValueKind != JsonValueKind.Object) throw new InvalidOperationException("Invalid role map");
        foreach (var property in document.RootElement.EnumerateObject())
        {
            var role = property.Value.GetString();
            if (string.IsNullOrWhiteSpace(property.Name) || role is not ("operator" or "trader" or "read-only") ||
                !roles.TryAdd(property.Name, role)) throw new InvalidOperationException("Invalid role map");
        }
        if (roles.Count == 0) throw new InvalidOperationException("Empty role map");
        return new DirectoryTrust { Key = new RsaSecurityKey(rsa), Issuer = issuer, Audience = audience, Until = until, Roles = roles };
    }

    public bool ValidClaims(ClaimsPrincipal? principal)
    {
        var now = DateTimeOffset.UtcNow;
        var subject = principal?.FindFirst("sub")?.Value;
        return now < Until && !string.IsNullOrWhiteSpace(subject)
            && long.TryParse(principal?.FindFirst("iat")?.Value, out var issued)
            && long.TryParse(principal?.FindFirst("exp")?.Value, out var expires)
            && issued <= now.ToUnixTimeSeconds() && expires > now.ToUnixTimeSeconds() && expires > issued;
    }

    public bool IsOperator(ClaimsPrincipal principal) => ValidClaims(principal)
        && Roles.TryGetValue(principal.FindFirst("sub")!.Value, out var role) && role == "operator";
}
