namespace ECommerce.Catalog.Api.Models;

// Nouvelle entité (UC7) : une catégorie regroupe plusieurs produits.
public class Category
{
    public int Id { get; set; }
    public required string Name { get; set; }

    // Relation 1-N : une catégorie possède plusieurs produits.
    public List<Product> Products { get; set; } = [];
}
