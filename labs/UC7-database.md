# UC7 — Création de base de données (skill `catalog-database`)

Guide pratique à dérouler, de l'installation des **outils EF Core** (Windows / Linux / macOS) jusqu'à
une **vraie base PostgreSQL** déployée et requêtée, **avec les commandes bash manuelles** pour
**vérifier ce que le skill fait réellement**.

> **Ce qu'on développe dans ce lab :** on fait passer le service `Catalog` d'une base **EF Core
> in-memory** (qui s'efface à chaque redémarrage) à une **vraie base PostgreSQL** : on **conçoit le
> schéma** (produits, catégories, stock), on **branche Postgres via Aspire**, on **génère les
> migrations EF Core**, on **seed** des données **synthétiques**, puis on **optimise** une requête —
> via le skill `catalog-database`.

> **Garde-fou central :** **aucune donnée client réelle / PII** dans le seed, **aucun secret en
> clair**, et l'application d'une migration en **preprod/prod** (`alter`, `drop`) reste une
> **décision humaine**. L'IA propose le schéma et les migrations ; l'ingénieur **valide** le modèle.

> Suite logique du fil rouge : **UC4** (Docker, qu'Aspire réutilise pour lancer Postgres) et **UC3**
> (.NET SDK installé). Alimente le **capstone** (étape 2 : base + migrations + seed).

---

## Les bases de données en 30 secondes

| Terme | En clair |
|---|---|
| **provider** | le pilote SQL d'EF Core : ici **Npgsql** (PostgreSQL) en remplacement de **in-memory**. |
| **`DbContext`** | la classe C# qui **mappe** les entités aux tables (`OnModelCreating`). |
| **migration** | un fichier **versionné** décrivant un **changement de schéma** (`create`/`alter table`). |
| **EF Core** | l'ORM .NET : on écrit des **classes C#**, il **génère le SQL** des migrations. |
| **`dotnet ef`** | l'outil CLI qui **génère** (`migrations add`) et **applique** (`database update`) les migrations. |
| **seed** | un **jeu de données initial** inséré dans la base (ici via `HasData`). |
| **`EXPLAIN ANALYZE`** | demande à Postgres le **plan d'exécution réel** d'une requête (Seq Scan vs Index Scan). |

> Image mentale : **in-memory** = données qui **disparaissent** au redémarrage (pratique en démo,
> inutilisable en vrai). **Postgres** = données **persistées**, **requêtables** (`psql`), **indexées**
> et dont on peut **lire le plan**. UC7 fait ce passage **sans réécrire les endpoints** : c'est le
> même `DbContext`, on change juste de **provider** et on **versionne** le schéma.

---

## Étape 0 — Pré-requis

UC3 (.NET SDK 10) et UC4 (Docker) terminés. Aspire utilise **Docker** pour démarrer Postgres dans un
**conteneur** — rien à installer côté base. On vérifie tout à l'Étape 2.

---

## Étape 1 — Installer l'outil `dotnet ef` (une seule fois)

`dotnet ef` est un **outil global .NET** (indépendant de l'OS une fois le SDK présent) :
```bash
dotnet tool install --global dotnet-ef     # première install
dotnet tool update  --global dotnet-ef     # si déjà installé (mise à jour)
```
> 💡 Si `dotnet ef` est introuvable après l'install, ajoute le dossier des outils globaux au PATH :
> `export PATH="$PATH:$HOME/.dotnet/tools"` (à mettre dans `~/.zshrc` pour le rendre permanent).
> Sur Windows, **ferme et rouvre** le terminal.

---

## Étape 2 — Vérifier l'installation

```bash
cd ecommerce-app
dotnet --version                  # attendu : 10.x (sinon UC3)
dotnet ef --version               # l'outil EF Core répond
docker version                    # Docker tourne → Aspire pourra lancer Postgres
dotnet build ECommerce.slnx       # base saine avant de toucher au DbContext
```

**Ce qui se passe :** SDK + `dotnet ef` + Docker disponibles et la solution compile → on peut
concevoir le schéma et générer des migrations. ✅

---

## Étape 3 — Lancer Claude Code & vérifier le skill

```bash
claude
```
```text
> /skills        # 'catalog-database' doit apparaître (relance `claude` s'il manque)
```

> Dans la session, on exécute une commande de l'hôte en la préfixant par `!`
> (ex. `!dotnet ef migrations list`, `!docker ps`). Pratique pour vérifier **sans quitter** Claude.

---

## Étape 4 — Se placer sur une branche de travail

```text
> crée une branche feat/catalog-postgres
```
ce qui correspond, **à la main**, à :
```bash
git switch -c feat/catalog-postgres
```
### ✅ Vérifier
```bash
git branch --show-current        # feat/catalog-postgres
```

---

## Étape 5 — Le skill `/catalog-database` : concevoir le schéma & brancher Postgres

Dans la session Claude :
```text
> /catalog-database conçois le schéma Postgres du Catalog (produits, catégories, stock), branche Postgres via Aspire et prépare le seed synthétique
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. modélise `Category` + `Product` (relation `Product → Category`, `Sku` unique, `stock`) ;
2. branche **Postgres** dans l'AppHost et **remplace** le provider in-memory du Catalog par Npgsql ;
3. ajoute les paquets NuGet nécessaires ;
4. prépare le **seed synthétique** dans `OnModelCreating` (`HasData`) — **aucune** donnée client réelle.

Concrètement, Claude propose ces changements (vérifiables ensuite par `cat`) :

**`src/ECommerce.AppHost/AppHost.cs`** — déclarer Postgres et le référencer depuis Catalog :
```csharp
var postgres   = builder.AddPostgres("postgres").WithDataVolume();  // persiste entre redémarrages
var catalogDb  = postgres.AddDatabase("catalogdb");

var catalog = builder.AddProject<Projects.ECommerce_Catalog_Api>("catalog")
    .WithReference(catalogDb)
    .WaitFor(catalogDb);
```

**`src/ECommerce.Catalog.Api/Program.cs`** — changer de provider et appliquer les migrations au boot :
```csharp
// AVANT : builder.Services.AddDbContext<CatalogDbContext>(o => o.UseInMemoryDatabase("catalog"));
builder.AddNpgsqlDbContext<CatalogDbContext>("catalogdb");          // APRÈS (Aspire + Npgsql)

// AVANT (au démarrage) : db.Database.EnsureCreated();
db.Database.Migrate();                                              // APRÈS : applique les migrations
```

Et les paquets (à la main si besoin) :
```bash
dotnet add src/ECommerce.Catalog.Api package Aspire.Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/ECommerce.Catalog.Api package Microsoft.EntityFrameworkCore.Design
dotnet add src/ECommerce.AppHost     package Aspire.Hosting.PostgreSQL
```

### ✅ Vérifier à la main (lecture seule)
```bash
cat src/ECommerce.Catalog.Api/Models/Product.cs        # Sku + CategoryId + stock
cat src/ECommerce.Catalog.Api/Models/Category.cs       # nouvelle entité
cat src/ECommerce.Catalog.Api/Data/CatalogDbContext.cs # relations, index, CHECK, HasData
grep -n "AddNpgsqlDbContext\|Migrate" src/ECommerce.Catalog.Api/Program.cs
grep -n "AddPostgres\|catalogdb" src/ECommerce.AppHost/AppHost.cs
```

---

## Étape 6 — Générer la migration ⚠️ (le piège design-time)

Dans Claude :
```text
> /catalog-database génère la migration InitialCreate
```
ce qui correspond, **à la main**, à :
```bash
dotnet ef migrations add InitialCreate --project src/ECommerce.Catalog.Api
```

> **Le piège.** `dotnet ef` instancie le `DbContext` **hors Aspire** : la chaîne de connexion
> `catalogdb` (fournie par l'AppHost à l'exécution) **n'existe pas** au design-time → erreur
> *« Unable to create a 'DbContext'… »*. La solution propre est une **fabrique design-time** qui donne
> une chaîne **localhost** (non sensible), utilisée **uniquement** pour générer les migrations :

**`src/ECommerce.Catalog.Api/Data/CatalogDbContextFactory.cs`** :
```csharp
public class CatalogDbContextFactory : IDesignTimeDbContextFactory<CatalogDbContext>
{
    public CatalogDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<CatalogDbContext>()
            .UseNpgsql("Host=localhost;Port=5432;Database=catalogdb;Username=postgres;Password=postgres")
            .Options);
}
```
> On **ne génère pas** la migration à la main : EF la **dérive** de `OnModelCreating`. Le DDL résultant
> est repris, en version lisible, dans `UC7/sql/schema.sql`.

### ✅ Vérifier
```bash
ls src/ECommerce.Catalog.Api/Migrations/             # *_InitialCreate.cs + CatalogDbContextModelSnapshot.cs
dotnet ef migrations list --project src/ECommerce.Catalog.Api   # InitialCreate (Pending)
```

---

## Étape 7 — Appliquer & vérifier dans Postgres (`psql`)

Le plus simple : lancer toute l'app — Aspire **démarre Postgres** (conteneur) et le `Migrate()` au boot
**applique** la migration.
```text
> lance l'app et confirme que la base est créée
```
ce qui correspond, **à la main**, à :
```bash
dotnet run --project src/ECommerce.AppHost     # ouvre l'URL "Login" affichée (dashboard Aspire)
```

### ✅ Vérifier dans la base (lecture seule)
```bash
docker ps --filter "name=postgres" --format "{{.Names}}\t{{.Ports}}"   # le conteneur Postgres d'Aspire
docker exec -it <postgres-container> psql -U postgres -d catalogdb
```
Puis dans `psql` :
```sql
\dt                                  -- tables : Categories, Products, __EFMigrationsHistory
\d "Products"                        -- colonnes, index (Sku, CategoryId), FK, contraintes CHECK
SELECT COUNT(*) FROM "Products";     -- 4  (le seed HasData)
SELECT "Name" FROM "Categories";     -- Peripherals / Displays / Accessories
```

| Ce qu'on voit | Ce que ça prouve |
|---|---|
| `__EFMigrationsHistory` contient `InitialCreate` | la migration a bien été **appliquée**. |
| `\d "Products"` montre `IX_Products_Sku`, FK, CHECK | le **schéma** conçu est en base. |
| `COUNT = 4` | le **seed** synthétique est inséré. |

> Les endpoints (`GET /api/products`) **n'ont pas changé** : ils lisent désormais Postgres au lieu de
> la mémoire. Au redémarrage, **les données persistent** (volume Aspire) — contrairement à l'in-memory.

---

## Étape 8 — Le seed (synthétique, jamais de donnée client)

Le seed vit dans `OnModelCreating` via `HasData(...)` → EF l'**embarque dans la migration**. Pour la
voie **psql / MCP base de données**, l'équivalent SQL est fourni dans `UC7/sql/seed.sql` :
```bash
docker exec -i <postgres-container> psql -U postgres -d catalogdb < UC7/sql/seed.sql
```
> ⚠️ **Garde-fou données.** Le catalogue est **synthétique** (pas de PII). Si on étendait le schéma à
> des tables clients, le seed devrait être **anonymisé** (faux noms, e-mails masqués) — **jamais** un
> export de prod. C'est le cœur du livrable « **seed anonymisé** ».

---

## Étape 9 — Optimiser une requête & lire son plan

Dans Claude :
```text
> optimise la requête "produits d'une catégorie triés par prix" et montre-moi le plan d'exécution
```
ce qui correspond, **à la main** (dans `psql`), à :
```sql
EXPLAIN ANALYZE
SELECT "Id", "Name", "Price", "AvailableStock"
FROM   "Products"
WHERE  "CategoryId" = 1
ORDER  BY "Price";
```

| Dans le plan | Lecture |
|---|---|
| `Index Scan using "IX_Products_CategoryId"` | l'index sur la FK est **utilisé** → pas de balayage complet. |
| `Seq Scan on "Products"` | la table est **balayée entièrement** → index manquant (à créer si volumineux). |
| `actual time=…` / `rows=…` | coût **réel** mesuré (≠ estimation) grâce à `ANALYZE`. |

> ⚠️ `EXPLAIN ANALYZE` **exécute** la requête : sûr sur un `SELECT`, **dangereux** sur un
> `UPDATE/DELETE` (il modifie vraiment). Pour ceux-là, utiliser `EXPLAIN` **sans** `ANALYZE`.

> **Option — MCP base de données.** On peut connecter un **MCP Postgres** (`/mcp`) pour que Claude
> **inspecte le schéma** et **lance des requêtes en lecture seule** directement. Garde-fou : scoper le
> connecteur en **lecture seule**, **jamais** d'écriture automatique sur une base preprod/prod.

---

## Étape 10 — Revue & nettoyage

Dans Claude :
```text
> /code-review revois le DbContext, la migration et les index (sécurité, données en dur, perf)
```

Nettoyage **à la main** :
```bash
# Annuler la DERNIÈRE migration TANT QU'ELLE N'EST PAS appliquée/partagée :
dotnet ef migrations remove --project src/ECommerce.Catalog.Api

# Repartir d'une base vierge en local (⚠️ supprime les données du volume Postgres d'Aspire) :
docker volume ls | grep postgres
```
> ⚠️ `migrations remove` (après application) et la suppression du **volume** sont **destructifs** : le
> skill **affiche la commande et attend ton accord**. Une migration **déjà partagée** ne se réécrit
> pas — on **ajoute** une nouvelle migration corrective.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1–2 | `dotnet tool install -g dotnet-ef` | `dotnet ef --version`, Docker OK, solution compile |
| 3 | `/skills` | `catalog-database` disponible |
| 4 | « crée une branche feat/… » | `git switch -c` |
| 5 | `/catalog-database conçois le schéma…` | modèles + DbContext + Postgres dans l'AppHost (vérif : `cat`) |
| 6 | `/catalog-database génère la migration` | `dotnet ef migrations add` (+ fabrique design-time) |
| 7 | « lance l'app » | Aspire démarre Postgres + `Migrate()` (vérif : `psql \dt`, `COUNT`) |
| 8 | seed via `HasData` / `seed.sql` | données synthétiques en base |
| 9 | « optimise cette requête » | `EXPLAIN ANALYZE` (Index Scan vs Seq Scan) |
| 10 | `/code-review` puis nettoyage | revue ; `migrations remove` / volume (confirmation) |

> **Message clé :** le skill `catalog-database` traduit en commandes EF Core / `psql` une procédure
> qu'on peut **rejouer à la main** — conception du schéma, `migrations add`, application, plan
> d'exécution. EF et Claude **accélèrent** ; l'ingénieur **valide le modèle**, **relit la migration**,
> garde la main sur l'application en **prod**, et n'y met **jamais** de donnée client réelle.
