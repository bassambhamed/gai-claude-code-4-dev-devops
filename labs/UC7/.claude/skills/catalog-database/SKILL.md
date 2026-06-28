---
name: catalog-database
description: Fait passer la base du service Catalog de l'ecommerce-app d'EF Core in-memory à une vraie base PostgreSQL. Conçoit le schéma (produits, catégories, stock), branche Postgres via Aspire, génère les migrations EF Core (dotnet ef), produit un jeu de données de seed synthétique/anonymisé, et aide à optimiser les requêtes (index, EXPLAIN ANALYZE). N'applique jamais une migration en preprod/prod sans validation humaine et ne met aucun secret ni donnée client réelle dans le code ou le seed.
---

# Skill : catalog-database

Objectif : remplacer la base **in-memory** du `Catalog` par **PostgreSQL**, avec un schéma propre,
des **migrations EF Core** versionnées et un **seed synthétique**.

## Étapes à suivre
1. Modéliser le domaine : entités `Category` et `Product` (produits, catégories, stock). Relation
   `Product → Category` (FK `CategoryId`), `Sku` unique, contraintes (`Price >= 0`,
   `AvailableStock >= 0`).
2. Brancher PostgreSQL via Aspire : `builder.AddPostgres("postgres").AddDatabase("catalogdb")` dans
   l'AppHost ; côté Catalog, remplacer `UseInMemoryDatabase(...)` par
   `builder.AddNpgsqlDbContext<CatalogDbContext>("catalogdb")`.
3. Ajouter les paquets : `Aspire.Npgsql.EntityFrameworkCore.PostgreSQL` (Catalog),
   `Aspire.Hosting.PostgreSQL` (AppHost), `Microsoft.EntityFrameworkCore.Design` (pour `dotnet ef`).
4. Générer la migration : `dotnet ef migrations add InitialCreate` (le schéma est **dérivé** de
   `OnModelCreating`). Ne **PAS** écrire la migration à la main. Prévoir une fabrique design-time
   (`IDesignTimeDbContextFactory`) pour que `dotnet ef` fonctionne hors Aspire.
5. Définir le seed **synthétique** dans `OnModelCreating` via `HasData(...)` (catégories + produits) —
   **jamais** de donnée client réelle. La migration embarque le seed.
6. Appliquer en local : `dotnet ef database update`, ou `db.Database.Migrate()` au démarrage (dev).
7. Optimiser : proposer les **index** utiles (FK `CategoryId`, `Sku`), lire un plan avec
   `EXPLAIN ANALYZE`, expliquer le coût (Seq Scan vs Index Scan).
8. Proposer une revue `/code-review` du `DbContext`, de la migration et des index.

## Garde-fous
- **Aucune donnée client réelle ni PII** dans le seed ou les migrations : uniquement des données
  **synthétiques / anonymisées**.
- **Aucun secret en clair** : la chaîne de connexion vient d'Aspire / d'un `Secret`, jamais codée en
  dur — sauf la chaîne **localhost de design-time** (non sensible) utilisée par `dotnet ef`.
- `dotnet ef migrations add` → **revue humaine** → `database update`. En **preprod/prod**,
  l'application d'une migration (`alter`, `drop`) est une **action validée** par un humain.
- Une migration **partagée est immuable** : pour corriger, on **ajoute** une nouvelle migration, on
  ne réécrit pas l'historique.
- Analyse en **lecture seule** : `EXPLAIN ANALYZE` sur un `SELECT` est sûr ; sur un `UPDATE/DELETE`
  il **exécute** réellement la requête → ne pas le lancer tel quel.
