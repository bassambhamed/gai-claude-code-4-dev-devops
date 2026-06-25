# Corrigé — UC3 (Tests)

Fichiers de référence pour `UC3-tests.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.claude/skills/
└── gen-tests/SKILL.md                       # /gen-tests : génère tests unitaires + intégration
tests/ECommerce.Catalog.Tests/
└── CatalogEndpointsTests.cs                 # EXEMPLE illustratif (unitaire xUnit/Moq + intégration)
```

> ⚠️ `CatalogEndpointsTests.cs` est un **exemple pédagogique** : les types (`IProductRepository`,
> `StockService`, `ProductDto`…) sont à adapter aux vrais noms de l'ecommerce-app. Il sert à
> montrer la **structure** (Arrange/Act/Assert, `[Fact]`/`[Theory]`, `WebApplicationFactory`).

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC3/.claude ecommerce-app/      # fusionne avec le .claude existant
# le projet de test se crée plutôt en live : dotnet new xunit -o tests/ECommerce.Catalog.Tests
```
