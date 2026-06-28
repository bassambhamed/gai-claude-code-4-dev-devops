using System.Net;

namespace ECommerce.Web.Services;

/// <summary>
/// Sonde l'endpoint /health de chaque service À TRAVERS la gateway.
/// (/health et /alive ne sont exposés qu'en Development, via ServiceDefaults.)
/// </summary>
public class HealthApiClient(HttpClient httpClient)
{
    // Routes gateway : "/health" = la gateway elle-même ;
    // "/catalog/health" → Catalog ; "/ordering/health" → Ordering (PathRemovePrefix).
    public static readonly IReadOnlyList<(string Name, string Path)> Targets =
    [
        ("Gateway", "/health"),
        ("Catalog", "/catalog/health"),
        ("Ordering", "/ordering/health"),
    ];

    public async Task<List<ServiceHealth>> CheckAllAsync(CancellationToken ct = default)
    {
        var checks = Targets.Select(async t =>
        {
            try
            {
                using var resp = await httpClient.GetAsync(t.Path, ct);
                return new ServiceHealth(t.Name, t.Path,
                    resp.StatusCode == HttpStatusCode.OK ? "Healthy" : "Unhealthy");
            }
            catch
            {
                return new ServiceHealth(t.Name, t.Path, "Unhealthy");
            }
        });

        return [.. await Task.WhenAll(checks)];
    }
}

public record ServiceHealth(string Name, string Path, string State);
