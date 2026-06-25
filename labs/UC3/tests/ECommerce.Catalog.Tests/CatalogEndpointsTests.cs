// EXEMPLE ILLUSTRATIF (corrigé UC3) — à adapter aux vrais types de l'ecommerce-app.
// Montre les deux familles de tests : unitaire (xUnit + Moq) et intégration (WebApplicationFactory).
using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Moq;
using Xunit;

namespace ECommerce.Catalog.Tests;

// ─────────────────────────────────────────────────────────────
// 1) TEST UNITAIRE — on teste UNE règle métier, dépendances mockées
// ─────────────────────────────────────────────────────────────
public class StockServiceTests
{
    [Theory]                                   // plusieurs jeux de données
    [InlineData(5, 3, true)]                    // stock 5, demande 3 -> ok
    [InlineData(2, 5, false)]                   // stock 2, demande 5 -> refusé
    [InlineData(0, 1, false)]                   // stock 0 -> refusé
    public void EstDisponible_SelonStock_RetourneAttendu(int stock, int demande, bool attendu)
    {
        // Arrange
        var repo = new Mock<IProductRepository>();
        repo.Setup(r => r.GetStock(It.IsAny<int>())).Returns(stock);
        var service = new StockService(repo.Object);

        // Act
        var resultat = service.EstDisponible(productId: 1, quantite: demande);

        // Assert
        Assert.Equal(attendu, resultat);
    }
}

// ─────────────────────────────────────────────────────────────
// 2) TEST D'INTÉGRATION — on appelle le vrai endpoint HTTP
// ─────────────────────────────────────────────────────────────
public class CatalogApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public CatalogApiTests(WebApplicationFactory<Program> factory) => _client = factory.CreateClient();

    [Fact]
    public async Task GET_Products_RetourneListe_200()
    {
        var reponse = await _client.GetAsync("/products");
        Assert.Equal(HttpStatusCode.OK, reponse.StatusCode);

        var produits = await reponse.Content.ReadFromJsonAsync<List<ProductDto>>();
        Assert.NotNull(produits);
    }

    [Fact]
    public async Task GET_Product_Inexistant_Retourne_404()
    {
        var reponse = await _client.GetAsync("/products/999999");
        Assert.Equal(HttpStatusCode.NotFound, reponse.StatusCode);
    }
}
