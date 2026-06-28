using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace ECommerce.Catalog.Api.Data;

// Utilisée UNIQUEMENT par `dotnet ef` (design-time), pour construire le modèle HORS Aspire.
// En exécution, la vraie chaîne de connexion vient d'Aspire (ressource "catalogdb"), pas d'ici.
// Sans cette fabrique, `dotnet ef migrations add` échoue : "Unable to create a 'DbContext'…".
public class CatalogDbContextFactory : IDesignTimeDbContextFactory<CatalogDbContext>
{
    public CatalogDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            // Chaîne locale NON sensible : sert à générer les migrations, pas à se connecter en prod.
            .UseNpgsql("Host=localhost;Port=5432;Database=catalogdb;Username=postgres;Password=postgres")
            .Options;

        return new CatalogDbContext(options);
    }
}
