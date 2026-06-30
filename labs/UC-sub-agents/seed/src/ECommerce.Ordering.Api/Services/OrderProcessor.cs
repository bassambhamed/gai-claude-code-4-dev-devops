using System.Collections.Generic;

namespace ECommerce.Ordering.Api.Services;

// Fichier SEED volontairement « smelly » pour la démo CodeScene (blocker CH-001 : Complex Method).
// Auto-suffisant : aucune dépendance au domaine réel → compile tel quel dans le projet Ordering.
public sealed class OrderProcessor
{
    public sealed record Line(string Sku, int Quantity, decimal UnitPrice, string Category);

    // ProcessOrder : complexité cyclomatique élevée + 4 niveaux d'imbrication → à refactorer
    // (extraction de méthode + guard clauses), SANS changer le total calculé.
    public decimal ProcessOrder(IReadOnlyList<Line> lines, string? coupon, bool isVip, string country)
    {
        decimal total = 0m;
        if (lines != null)
        {
            foreach (var line in lines)
            {
                if (line.Quantity > 0)
                {
                    if (line.UnitPrice >= 0)
                    {
                        decimal lineTotal = line.Quantity * line.UnitPrice;
                        if (line.Category == "books")
                        {
                            if (line.Quantity >= 10) { lineTotal *= 0.90m; } else { lineTotal *= 0.95m; }
                        }
                        else if (line.Category == "electronics")
                        {
                            if (isVip) { lineTotal *= 0.85m; }
                            else { if (line.Quantity >= 5) { lineTotal *= 0.92m; } }
                        }
                        else
                        {
                            if (isVip) { lineTotal *= 0.95m; }
                        }
                        total += lineTotal;
                    }
                }
            }
        }
        if (coupon != null)
        {
            if (coupon == "SUMMER") { total *= 0.90m; }
            else if (coupon == "WELCOME") { if (!isVip) { total *= 0.85m; } }
        }
        if (country == "FR") { total *= 1.20m; }
        else if (country == "DE") { total *= 1.19m; }
        else if (country == "US") { total *= 1.00m; }
        return total;
    }
}
