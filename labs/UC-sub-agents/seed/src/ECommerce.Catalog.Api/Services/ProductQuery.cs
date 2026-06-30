using System.Collections.Generic;
using System.Linq;

namespace ECommerce.Catalog.Api.Services;

// Fichier SEED volontairement « smelly » (blocker CH-002 : Many Function Arguments — 8 paramètres).
// Auto-suffisant : aucune dépendance au domaine réel → compile tel quel dans le projet Catalog.
public sealed class ProductQuery
{
    public sealed record Product(string Name, string Category, decimal Price, bool InStock, double Rating, string Brand);

    private readonly List<Product> _catalog;
    public ProductQuery(List<Product> catalog) => _catalog = catalog;

    // Search : 8 paramètres positionnels → à remplacer par un objet-paramètre
    // (record ProductSearchCriteria), SANS changer le résultat du filtrage.
    public IEnumerable<Product> Search(string? name, string? category, decimal? minPrice, decimal? maxPrice,
                                       bool? inStockOnly, double? minRating, string? brand, int take)
    {
        var q = _catalog.AsEnumerable();
        if (name != null) q = q.Where(p => p.Name.Contains(name));
        if (category != null) q = q.Where(p => p.Category == category);
        if (minPrice != null) q = q.Where(p => p.Price >= minPrice);
        if (maxPrice != null) q = q.Where(p => p.Price <= maxPrice);
        if (inStockOnly == true) q = q.Where(p => p.InStock);
        if (minRating != null) q = q.Where(p => p.Rating >= minRating);
        if (brand != null) q = q.Where(p => p.Brand == brand);
        return q.Take(take);
    }
}
