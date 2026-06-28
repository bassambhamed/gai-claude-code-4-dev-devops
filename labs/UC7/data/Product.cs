namespace ECommerce.Catalog.Api.Models;

public class Product
{
    public int Id { get; set; }
    public required string Sku { get; set; }          // référence produit, unique (UC7)
    public required string Name { get; set; }
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int AvailableStock { get; set; }           // stock disponible

    // Relation N-1 vers Category (UC7).
    public int CategoryId { get; set; }
    public Category? Category { get; set; }
}
