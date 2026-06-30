using System;
using System.Linq;
using ECommerce.Catalog.Api.Services;
using ECommerce.Ordering.Api.Services;

namespace ECommerce.SubAgents.Tests;

// Tests de CARACTÉRISATION : ils figent le comportement actuel de ProcessOrder et Search.
// But : prouver que la correction des blockers CodeScene par dotnet-reviewer reste
// « à comportement constant » — ces tests doivent rester VERTS avant ET après refactoring.
public class OrderProcessorTests
{
    private static OrderProcessor.Line L(string category, int qty, decimal price)
        => new("SKU", qty, price, category);

    [Fact]
    public void Books_bulk_discount_then_FR_tax()
    {
        var total = new OrderProcessor().ProcessOrder(new[] { L("books", 10, 2.00m) }, null, false, "FR");
        Assert.Equal(21.60m, total); // 10*2 = 20 → *0.90 (qty>=10) = 18 → *1.20 (FR) = 21.60
    }

    [Fact]
    public void Electronics_vip_discount_US()
    {
        var total = new OrderProcessor().ProcessOrder(new[] { L("electronics", 5, 100m) }, null, true, "US");
        Assert.Equal(425.00m, total); // 500 → *0.85 (electronics+VIP) = 425 → *1.00 (US)
    }

    [Fact]
    public void Welcome_coupon_non_vip_then_DE_tax()
    {
        var total = new OrderProcessor().ProcessOrder(new[] { L("other", 2, 50m) }, "WELCOME", false, "DE");
        Assert.Equal(101.15m, total); // 100 → *0.85 (WELCOME, non-VIP) = 85 → *1.19 (DE) = 101.15
    }

    [Fact]
    public void Summer_coupon_books_small_qty_US()
    {
        var total = new OrderProcessor().ProcessOrder(new[] { L("books", 1, 10m) }, "SUMMER", false, "US");
        Assert.Equal(8.55m, total); // 10 → *0.95 (books qty<10) = 9.50 → *0.90 (SUMMER) = 8.55
    }

    [Fact]
    public void Empty_order_unknown_country_is_zero()
    {
        var total = new OrderProcessor().ProcessOrder(Array.Empty<OrderProcessor.Line>(), null, false, "ZZ");
        Assert.Equal(0m, total);
    }
}

public class ProductQueryTests
{
    private static ProductQuery NewSut() => new(new()
    {
        new("Widget",     "tools", 10m, true,  4.5, "Acme"),
        new("Gadget",     "tools", 25m, false, 4.0, "Acme"),
        new("Gizmo",      "toys",   5m, true,  3.5, "Globex"),
        new("Widget Pro", "tools", 40m, true,  4.8, "Globex"),
    });

    [Fact]
    public void Filter_by_name_substring()
        => Assert.Equal(2, NewSut().Search("Widget", null, null, null, null, null, null, 10).Count());

    [Fact]
    public void Tools_in_stock_only()
        => Assert.Equal(2, NewSut().Search(null, "tools", null, null, true, null, null, 10).Count());

    [Fact]
    public void Price_range_10_to_30()
        => Assert.Equal(2, NewSut().Search(null, null, 10m, 30m, null, null, null, 10).Count());

    [Fact]
    public void Brand_and_min_rating()
        => Assert.Single(NewSut().Search(null, null, null, null, null, 4.0, "Globex", 10));

    [Fact]
    public void Take_limits_results()
        => Assert.Equal(2, NewSut().Search(null, null, null, null, null, null, null, 2).Count());
}
