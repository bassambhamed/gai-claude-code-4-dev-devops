# UC8 — UI / frontend à améliorer (skill `ui-modernize` + `artifact-design`)

Guide pratique à dérouler, du **repérage des manques** de l'IHM jusqu'à une **page catalogue
modernisée** et un **tableau de bord ops**, **avec les vérifications manuelles** (rendu, responsive,
accessibilité) pour **contrôler ce que le skill fait réellement**.

> **Ce qu'on développe dans ce lab :** on améliore l'interface de `ECommerce.Web` (Blazor Server +
> Bootstrap). D'abord la **page catalogue** : **responsive**, **états** (chargement / vide / erreur)
> et **accessibilité (a11y)** — avec une **maquette** produite via le skill intégré
> `artifact-design`. Ensuite un **tableau de bord ops** affichant la **santé des services**.

> **Garde-fou central :** on améliore la **forme**, jamais les **règles métier** (panier, commande
> restent identiques). L'**a11y** n'est pas optionnelle : aucune information par la **couleur seule**,
> tout contrôle a un **nom accessible**. La **maquette** sert à **décider**, pas à livrer.

> Suite du fil rouge : l'app tourne déjà (UC3 / Aspire). UC8 ne touche **que** la couche `Web`.

---

## L'UI en 30 secondes

| Terme | En clair |
|---|---|
| **Blazor Server** | l'UI .NET : composants `.razor` rendus **côté serveur**, interactifs via WebSocket (`@rendermode InteractiveServer`). |
| **responsive** | une mise en page qui **s'adapte** à l'écran (mobile → desktop). |
| **a11y (accessibilité)** | rendre l'UI utilisable par **tous** : lecteurs d'écran, clavier, daltoniens. |
| **état de chargement** | ce qu'on montre **pendant** que les données arrivent (skeleton, spinner), au lieu d'un écran figé. |
| **skill `artifact-design`** | un skill **intégré** de Claude Code : principes de design pour produire une **maquette**. |
| **Artifact** | une **page web autonome** publiée par Claude (la maquette à montrer / partager). |

> Image mentale : la page catalogue **fonctionne** mais reste « brute » (table qui déborde sur
> mobile, « Loading… » en texte, pas d'état d'erreur, stock = nombre brut). UC8 garde **les mêmes
> données et endpoints**, mais soigne l'**expérience** et l'**accessibilité** — validées par une
> **maquette d'abord**.

---

## Étape 0 — Pré-requis

L'app fil rouge se lance (UC3 / Aspire). On vérifie le rendu dans un **navigateur**. Aucune install
spécifique : `ui-modernize` est un skill du dépôt, `artifact-design` est **intégré** à Claude Code.

---

## Étape 1 — Lancer l'app et repérer les manques (baseline)

```bash
cd ecommerce-app
dotnet run --project src/ECommerce.AppHost     # ouvrir l'URL "Login" affichée, puis la ressource "web"
```
Ouvrir la page **Catalog** (`/products`) et observer le code actuel
(`src/ECommerce.Web/Components/Pages/Products.razor`) :

| Constat (code actuel) | Problème |
|---|---|
| `Loading products…` en texte | pas de **skeleton** ; l'écran « saute » à l'arrivée des données |
| `<table class="table">` sans wrapper | **déborde** sur mobile (pas de scroll horizontal) |
| `<label>Customer name</label>` non lié à l'`input` | **a11y** : le label ne cible pas le champ (`for`/`id`) |
| bouton `Add` sans libellé | **a11y** : pour un lecteur d'écran, tous les boutons disent juste « Add » |
| catalogue vide **vs** erreur réseau indistinguables | pas d'**état d'erreur** (un échec ressemble à « vide ») |
| `Stock` = nombre brut | pas de **statut visuel** (rupture vs disponible) |

> Ces constats sont la **liste de courses** de l'amélioration. On les corrige à l'Étape 5.

---

## Étape 2 — Lancer Claude Code & vérifier les skills

```bash
claude
```
```text
> /skills        # 'ui-modernize' (dépôt) ET 'artifact-design' (intégré) doivent apparaître
```

> Dans la session, `!open …` (macOS) ouvre un fichier local, et on relance l'app via `!dotnet run …`.

---

## Étape 3 — Se placer sur une branche de travail

```text
> crée une branche feat/ui-catalog
```
ce qui correspond, **à la main**, à :
```bash
git switch -c feat/ui-catalog
```
### ✅ Vérifier
```bash
git branch --show-current        # feat/ui-catalog
```

---

## Étape 4 — Le skill `/ui-modernize` : la **maquette d'abord**

Dans la session Claude :
```text
> /ui-modernize modernise la page catalogue (responsive, états de chargement, a11y) et propose-moi d'abord une maquette
```

**Ce que le skill fait (selon `SKILL.md`) :** il invoque le skill intégré **`artifact-design`** et
publie une **maquette** sous forme d'**Artifact** (page HTML **autonome**) — **avant** toute
modification de code. On **valide le design** visuellement, puis on applique.

La maquette de référence est fournie dans le dépôt :
```bash
open UC8/mockup/catalog-mockup.html      # macOS  (Linux : xdg-open · Windows : start)
```

| Sur la maquette | Ce qu'on valide |
|---|---|
| cartes empilées sur mobile, en colonnes sur desktop | la stratégie **responsive** |
| badge `50 in stock` / `Out of stock` | statut = **couleur + texte** (a11y) |
| bloc « skeleton » | l'**état de chargement** |
| `aria-label="Add … to cart"`, focus visible | l'**accessibilité** des actions |

> 💡 La maquette est **jetable** : elle aide à **décider** la direction visuelle. Le rendu livré
> restera le **composant Blazor**, branché sur les **vraies** données.

---

## Étape 5 — Appliquer : page catalogue responsive + états + a11y

Dans Claude :
```text
> applique la maquette à Products.razor sans changer la logique du panier ni du passage de commande
```

**Ce que Claude modifie** dans `Components/Pages/Products.razor` (cf. `UC8/web/.../Products.razor`) :
- **Responsive** : table enveloppée dans `table-responsive`.
- **États** : `placeholder-glow` (skeleton) au chargement, état **vide** (« No products available »),
  état **erreur** avec bouton **Retry** (via un `try/catch` autour de `GetProductsAsync`), `spinner`
  sur « Place order ».
- **a11y** : `<caption class="visually-hidden">`, `scope="col"/"row"`, `aria-label` sur « Add »,
  `<label for="customer">` lié à l'`input`, `role="alert"`/`aria-live` sur les messages, statut stock
  en **badge couleur + texte**.
- **Sans régression** : `@rendermode InteractiveServer`, `@bind`, `@onclick` et le bloc `@code`
  métier sont **conservés**.

### ✅ Vérifier à la main (lecture seule)
```bash
grep -n "table-responsive\|placeholder-glow\|aria-label\|visually-hidden\|role=\"alert\"\|for=\"customer\"" \
  src/ECommerce.Web/Components/Pages/Products.razor
git diff src/ECommerce.Web/Components/Pages/Products.razor    # le panier / PlaceOrder restent intacts
```

---

## Étape 6 — Vérifier le rendu (desktop, mobile, a11y)

```text
> relance l'app et ouvre la page catalogue
```
ce qui correspond, **à la main**, à :
```bash
dotnet run --project src/ECommerce.AppHost     # ouvrir le frontend "web", page /products
```

| Quoi vérifier | Comment |
|---|---|
| **responsive** | devtools → mode mobile (≈375 px) : la table **scrolle**, rien ne déborde |
| **chargement** | devtools → *Network: Slow 3G* puis recharger : le **skeleton** s'affiche |
| **a11y clavier** | naviguer en **Tab** : focus visible, boutons atteignables |
| **a11y libellés** | devtools → *Accessibility tree* : les boutons « Add » ont un **nom unique** |
| **statut stock** | un produit à 0 affiche **« Out of stock »** (texte, pas juste une couleur) |

---

## Étape 7 — Tableau de bord ops (santé des services)

Le 2ᵉ prompt du cas d'usage : *« améliore le tableau de bord ops (santé des services) »*. Il n'existe
pas encore → on le **crée**. Les services exposent `/health` (en **Development**) via ServiceDefaults,
joignable **à travers la gateway** : `/health` (gateway), `/catalog/health`, `/ordering/health`.

Dans Claude :
```text
> /ui-modernize crée une page /health-dashboard qui affiche la santé de Gateway, Catalog et Ordering via la gateway
```

**Ce que Claude ajoute** (cf. dossier `UC8/web/`) :
1. `Services/HealthApiClient.cs` — sonde les trois `/health` via la gateway (200 ⇒ *Healthy*).
2. `Components/Pages/Health.razor` — cartes responsive, badge **couleur + texte**, auto-refresh 10 s.
3. Enregistrement du client dans `Program.cs` :
   ```csharp
   builder.Services.AddHttpClient<HealthApiClient>(client =>
       client.BaseAddress = new Uri("https+http://gateway"));
   ```
4. Lien dans `Components/Layout/NavMenu.razor` :
   ```razor
   <div class="nav-item px-3">
       <NavLink class="nav-link" href="health-dashboard">Health</NavLink>
   </div>
   ```

### ✅ Vérifier
```bash
grep -n "AddHttpClient<HealthApiClient>" src/ECommerce.Web/Program.cs
# Tester les sondes à la main (port de la gateway = voir le dashboard Aspire) :
curl -k https://localhost:<gatewayPort>/health
curl -k https://localhost:<gatewayPort>/catalog/health
```
Puis ouvrir **`/health-dashboard`** : trois cartes **Healthy**. Arrêter `ordering` → la carte passe
**Unhealthy** au refresh.

> ⚠️ `/health` n'est mappé qu'en **Development** (`MapDefaultEndpoints`). En preprod/prod, exposer un
> health check dédié et **protégé** plutôt que d'ouvrir ces endpoints tels quels.

---

## Étape 8 — Revue & accessibilité

Dans Claude :
```text
> /code-review revois Products.razor, Health.razor et HealthApiClient.cs (a11y, responsive, pas de régression Blazor)
> liste les problèmes d'accessibilité restants (contraste, focus, lecteurs d'écran) et corrige-les
```

> Garde-fou : l'**ingénieur** juge le rendu réel (desktop + mobile) et l'accessibilité. On ne fusionne
> pas une « jolie » page qui aurait **cassé** le panier ou dégradé l'a11y.

---

## Récapitulatif — du skill à la vérification

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1 | (lancer l'app) | repérer les manques de `Products.razor` (baseline) |
| 2 | `/skills` | `ui-modernize` + `artifact-design` disponibles |
| 3 | « crée une branche feat/… » | `git switch -c` |
| 4 | `/ui-modernize … propose une maquette` | **Artifact** HTML (maquette) — `open UC8/mockup/catalog-mockup.html` |
| 5 | « applique la maquette à Products.razor » | responsive + états + a11y (vérif : `grep`, `git diff`) |
| 6 | « relance l'app » | rendu desktop/mobile + a11y (devtools) |
| 7 | « crée /health-dashboard » | dashboard ops + `HealthApiClient` (vérif : `curl /health`) |
| 8 | `/code-review` + audit a11y | revue du diff, corrections d'accessibilité |

> **Message clé :** `ui-modernize` s'appuie sur `artifact-design` pour **proposer une maquette
> d'abord**, puis applique des améliorations **responsive / états / a11y** au vrai composant Blazor.
> L'IA accélère le design et l'accessibilité ; l'**ingénieur valide le rendu réel**, vérifie l'a11y,
> et garde le **comportement métier intact**.
