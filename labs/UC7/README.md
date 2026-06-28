# Corrigé — UC7 (Création de la base de données du Catalog)

Fichiers de référence pour `UC7-database.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

> Objectif : faire passer le service `Catalog` d'**EF Core in-memory** à une **vraie base
> PostgreSQL**, avec un **schéma** (produits, catégories, stock), des **migrations EF Core**
> versionnées et un **seed synthétique** (aucune donnée client réelle).

## Contenu
```
.claude/skills/
└── catalog-database/SKILL.md      # /catalog-database : schéma + migrations EF Core + seed + optim
data/                              # les ENTRÉES C# d'où EF dérive la migration
├── Category.cs                    # nouvelle entité (catégorie)
├── Product.cs                     # produit enrichi (Sku, CategoryId, stock)
├── CatalogDbContext.cs            # relations, index, contraintes CHECK, seed via HasData
└── CatalogDbContextFactory.cs     # fabrique design-time (pour `dotnet ef`, hors Aspire)
sql/
├── schema.sql                     # DDL Postgres cible (équivalent lisible de `ef migrations script`)
└── seed.sql                       # seed synthétique (voie psql / MCP base de données)
```

> Important : la **migration** elle-même (`Migrations/*.cs` + `ModelSnapshot`) est **générée** par
> `dotnet ef migrations add` à partir des fichiers `data/` — on ne l'écrit **jamais** à la main.
> `sql/schema.sql` est la **référence de lecture** de ce que cette migration produit.

## Pour appliquer le corrigé dans le projet
```bash
cp UC7/data/Category.cs                 ecommerce-app/src/ECommerce.Catalog.Api/Models/
cp UC7/data/Product.cs                  ecommerce-app/src/ECommerce.Catalog.Api/Models/
cp UC7/data/CatalogDbContext.cs         ecommerce-app/src/ECommerce.Catalog.Api/Data/
cp UC7/data/CatalogDbContextFactory.cs  ecommerce-app/src/ECommerce.Catalog.Api/Data/
cp -r UC7/.claude                       ecommerce-app/        # fusionne avec le .claude existant
```
> Puis adapter `AppHost.cs` et le `Program.cs` du Catalog (voir `UC7-database.md`, Étape 5),
> ajouter les paquets NuGet, et **générer** la migration.

## Pré-requis outils
- **.NET SDK 10** : `dotnet --version` (sinon UC3, Étape 1)
- **Docker** : Aspire démarre Postgres dans un **conteneur** automatiquement (sinon UC4)
- **dotnet-ef** : `dotnet tool install --global dotnet-ef`

## Dérouler (résumé)
```bash
# 1) Paquets
dotnet add src/ECommerce.Catalog.Api package Aspire.Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/ECommerce.Catalog.Api package Microsoft.EntityFrameworkCore.Design
dotnet add src/ECommerce.AppHost     package Aspire.Hosting.PostgreSQL

# 2) Générer la migration (le schéma est DÉRIVÉ du DbContext)
dotnet ef migrations add InitialCreate --project src/ECommerce.Catalog.Api

# 3) Lancer l'app : Aspire démarre Postgres + applique la migration au boot (db.Database.Migrate())
dotnet run --project src/ECommerce.AppHost
```

## Garde-fous
- **Aucune donnée client réelle ni PII** dans le seed / les migrations : uniquement du **synthétique**.
- **Aucun secret en clair** : la connexion vient d'Aspire ; la chaîne du `DbContextFactory` est une
  chaîne **localhost de design-time**, non sensible.
- `dotnet ef migrations add` → **revue** → `database update`. En **preprod/prod**, l'application d'une
  migration (`alter`, `drop`) est une **décision humaine**.
- Une migration partagée est **immuable** : on corrige en **ajoutant** une migration, jamais en
  réécrivant l'historique. Versions de paquets, SKU et prix sont **illustratifs**.
