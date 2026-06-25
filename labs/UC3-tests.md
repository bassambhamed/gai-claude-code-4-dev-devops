# UC3 — Tests automatisés (skill `gen-tests`)

Guide pratique à dérouler, de l'installation du **.NET SDK** (Windows / Linux / macOS) jusqu'aux
**tests qui tournent sur la PR**, **avec les commandes bash manuelles** pour **vérifier ce que le
skill fait réellement**.

> **Ce qu'on développe dans ce lab :** on fait écrire à Claude des **tests d'intégration** pour les
> **vrais endpoints** du service `Catalog` de l'`ecommerce-app`, on les **rattache à la solution**,
> on les **lance**, on mesure la **couverture**, puis on demande les **cas manquants** — via le
> skill `gen-tests`. À la fin, le CI (UC2) **rejoue ces tests automatiquement** à chaque PR.

> **Garde-fou central :** Claude écrit vite beaucoup de tests, mais c'est **l'ingénieur** qui juge
> s'ils testent les **bons** comportements. On ne **jamais** affaiblit un test pour le faire passer.

> Suite de **UC1 + UC2** : dépôt, repo GitHub et CI (`ci.yml` qui lance déjà `dotnet test`) existent.

---

## Les tests en 30 secondes

| Terme | En clair |
|---|---|
| **test unitaire** | teste **un petit bout** de code isolé (une règle métier pure). |
| **test d'intégration** | teste **plusieurs morceaux ensemble** (un vrai appel HTTP à l'API). |
| **xUnit** | le framework de test .NET (`[Fact]` = un cas, `[Theory]` = plusieurs jeux de données). |
| **`WebApplicationFactory`** | démarre l'API **en mémoire** pour tester ses **vrais endpoints**. |
| **Arrange / Act / Assert** | la structure d'un test : préparer → exécuter → vérifier. |
| **couverture** | le **% de code** exécuté par les tests (un indicateur, **pas** un but). |

> Image mentale : l'**unitaire** vérifie une brique seule ; l'**intégration** vérifie que les briques
> s'emboîtent. Ici, l'app `Catalog` est volontairement **fine** (endpoints + EF), donc les tests
> naturels sont des **tests d'intégration** sur ses vrais endpoints.

---

## Étape 0 — Pré-requis

UC1 + UC2 terminés. Il faut le **.NET SDK 10** pour compiler et lancer les tests en local. Si
`dotnet --version` affiche déjà `10.x` → passe à l'Étape 3.

---

## Étape 1 — Installer le .NET SDK 10 (une seule fois, selon ton OS)

### macOS (avec Homebrew)
```bash
brew install dotnet-sdk
```
> Sur certaines machines le SDK est installé dans `/usr/local/share/dotnet` mais **pas dans le PATH**.
> Si `dotnet` est introuvable, ajoute-le (à refaire dans chaque shell, ou à mettre dans `~/.zshrc`) :
> ```bash
> export PATH="/usr/local/share/dotnet:$PATH"
> ```

### Linux (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install dotnet-sdk-10.0
# si le paquet est introuvable : ajouter d'abord le dépôt Microsoft (packages.microsoft.com)
```

### Windows
```powershell
winget install Microsoft.DotNet.SDK.10
```
> Ferme et rouvre le terminal après l'install pour que `dotnet` soit dans le PATH.

---

## Étape 2 — Vérifier l'installation

```bash
cd ecommerce-app
dotnet --version          # attendu : 10.x
dotnet build ECommerce.slnx   # la solution compile (base saine avant d'ajouter des tests)
```

**Ce qui se passe :** si `dotnet --version` affiche `10.x` et que la solution compile, on peut
écrire et lancer des tests. ✅

---

## Étape 3 — Lancer Claude Code & vérifier le skill

```bash
claude
```
```text
> /skills        # 'gen-tests' doit apparaître (relance `claude` s'il manque)
```

> Dans la session, `!dotnet test ECommerce.slnx` exécute les tests sur l'hôte sans quitter Claude.

---

## Étape 4 — Se placer sur une branche de travail

```text
> crée une branche feat/tests-catalog
```
ce qui correspond, **à la main**, à :
```bash
git switch -c feat/tests-catalog
```
### ✅ Vérifier
```bash
git branch --show-current        # feat/tests-catalog
```

---

## Étape 5 — Le skill `/gen-tests` : générer les tests d'intégration

**Ce qui est réellement testable ici.** Le service `Catalog` n'a **pas** de logique métier isolée
(pas de `StockService` ni de repository à mocker). On teste donc directement ses **vrais endpoints** :

| Endpoint réel | Cas à tester |
|---|---|
| `GET /api/health` | renvoie **200** |
| `GET /api/products` | renvoie la **liste** (4 produits seedés) |
| `GET /api/products/{id}` | **404** si l'id n'existe pas |
| `POST /api/products` | crée un produit → **201** |

Dans la session Claude :
```text
> /gen-tests écris des tests d'intégration pour les endpoints /api/products et /api/health du Catalog (200, 404, liste seedée)
```

**Ce que le skill fait (selon `SKILL.md`) :** crée un projet de test xUnit, écrit les tests sur les
vrais endpoints via `WebApplicationFactory`, et **explique** chaque cas.

> 💡 Pas besoin de **Testcontainers** : la base est déjà **en mémoire** (`UseInMemoryDatabase`),
> donc `WebApplicationFactory` démarre l'API complète et **seedée**, sans conteneur ni vraie base.

---

## Étape 6 — Rattacher le projet de test à la solution ⚠️ (sinon rien ne tourne)

Deux pièges que Claude doit gérer — et que tu dois comprendre :

**a) Le projet de test doit être DANS `ECommerce.slnx`**, sinon `dotnet test ECommerce.slnx`
(et donc **le CI**) ne le voit pas :
```bash
dotnet new xunit -o tests/ECommerce.Catalog.Tests
dotnet add tests/ECommerce.Catalog.Tests reference src/ECommerce.Catalog.Api/ECommerce.Catalog.Api.csproj
dotnet add tests/ECommerce.Catalog.Tests package Microsoft.AspNetCore.Mvc.Testing
dotnet sln ECommerce.slnx add tests/ECommerce.Catalog.Tests/ECommerce.Catalog.Tests.csproj   # ← l'étape qu'on oublie
```

**b) `WebApplicationFactory<Program>` a besoin d'accéder à `Program`.** Avec les *top-level
statements*, `Program` est **interne** → on l'expose en ajoutant **à la fin** de
`src/ECommerce.Catalog.Api/Program.cs` :
```csharp
public partial class Program { }   // rend Program visible pour les tests d'intégration
```

### ✅ Vérifier le rattachement
```bash
dotnet sln ECommerce.slnx list | grep Tests     # le projet de test apparaît dans la solution
dotnet build ECommerce.slnx                      # tout compile, y compris les tests
```

---

## Étape 7 — Comprendre un test d'intégration

```csharp
using System.Net;
using System.Net.Http.Json;
using ECommerce.Catalog.Api.Models;
using Microsoft.AspNetCore.Mvc.Testing;

public class CatalogApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public CatalogApiTests(WebApplicationFactory<Program> f) => _client = f.CreateClient();

    [Fact]                                   // un seul cas
    public async Task GET_health_retourne_200()
    {
        var r = await _client.GetAsync("/api/health");           // Act
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);           // Assert
    }

    [Fact]
    public async Task GET_product_inexistant_retourne_404()
    {
        var r = await _client.GetAsync("/api/products/999999");
        Assert.Equal(HttpStatusCode.NotFound, r.StatusCode);
    }

    [Fact]
    public async Task GET_products_retourne_les_4_produits_seedes()
    {
        var produits = await _client.GetFromJsonAsync<List<Product>>("/api/products");
        Assert.NotNull(produits);
        Assert.Equal(4, produits!.Count);    // 4 produits dans le seed (HasData)
    }
}
```

| Élément | Rôle |
|---|---|
| `WebApplicationFactory<Program>` | démarre l'API **en mémoire** → on teste les **vrais endpoints**. |
| `[Fact]` / `[Theory]` | un cas unique / un test rejoué avec plusieurs jeux de données. |
| **Arrange / Act / Assert** | préparer → exécuter → vérifier (visible dans chaque `[Fact]`). |

---

## Étape 8 — Lancer les tests et mesurer la couverture

```text
> lance les tests et montre-moi le résultat
```
ce qui correspond, **à la main**, à :
```bash
dotnet test ECommerce.slnx                                    # exécute tous les tests
dotnet test ECommerce.slnx --collect:"XPlat Code Coverage"   # + couverture (Coverlet)
```

### ✅ Vérifier
```bash
# attendu : "Passed!  - Failed: 0" et le nombre de tests exécutés
```

Puis demander les manques :
```text
> quels cas ne sont pas couverts ? propose les tests manquants les plus utiles
```

> Garde-fou : on vise les **cas utiles** (limites, erreurs 400/404), pas à gonfler le pourcentage.

---

## Étape 9 — Commiter et voir les tests tourner sur la PR

Le `ci.yml` (UC2) lance déjà `dotnet test ECommerce.slnx` à chaque PR → **rien à modifier côté CI**.
```text
> /git-commit        # commit du projet de test
> /open-pr           # pousse + ouvre/maj la PR ; le CI rejoue les tests
```
### ✅ Vérifier
```bash
gh pr checks         # le check 'build-test' (qui inclut dotnet test) doit être vert
```

Si un test casse le CI :
```text
> le job build-test a échoué : lis les logs et corrige le test ou le code en cause
```

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1–2 | install .NET (`brew`/`apt`/`winget`) | `dotnet --version` = 10.x, la solution compile |
| 3 | `/skills` | `gen-tests` disponible |
| 4 | « crée une branche feat/… » | `git switch -c` |
| 5 | `/gen-tests …` | tests d'intégration sur les **vrais** endpoints |
| 6 | `dotnet sln add …` + `Program` partial | projet de test **vu** par la solution et le CI |
| 7 | `/diff` | relecture des tests (Arrange/Act/Assert) |
| 8 | « lance les tests » | `dotnet test` + couverture (vérif : Passed, Failed: 0) |
| 9 | `/git-commit` puis `/open-pr` | le CI rejoue les tests (vérif : `gh pr checks`) |

> **Message clé :** Claude écrit vite beaucoup de tests, mais c'est **l'ingénieur** qui juge s'ils
> testent les **bons** comportements. L'IA accélère, elle ne remplace pas le jugement.
