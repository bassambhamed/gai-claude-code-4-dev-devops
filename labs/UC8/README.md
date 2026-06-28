# Corrigé — UC8 (UI / frontend à améliorer)

Fichiers de référence pour `UC8-frontend.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

> Objectif : améliorer l'IHM de `ECommerce.Web` (Blazor Server + Bootstrap) — la **page catalogue**
> (responsive, états de chargement / vide / erreur, **a11y**) et un **tableau de bord ops** (santé
> des services) — en s'appuyant sur le skill intégré `artifact-design` pour la **maquette**.

## Contenu
```
.claude/skills/
└── ui-modernize/SKILL.md           # /ui-modernize : responsive + états + a11y + maquette (artifact-design)
web/
├── Components/Pages/Products.razor  # page catalogue MODERNISÉE (responsive, skeleton, états, a11y)
├── Components/Pages/Health.razor    # NOUVEAU : tableau de bord ops (santé des services)
└── Services/HealthApiClient.cs      # sonde /health de chaque service via la gateway
mockup/
└── catalog-mockup.html              # la MAQUETTE (Artifact HTML autonome) à présenter
```

> La maquette `catalog-mockup.html` est **autonome** (CSS inline, aucune dépendance externe) : c'est
> exactement la forme qu'un **Artifact** publié par le skill `artifact-design` prendrait.

## Pour appliquer le corrigé dans le projet
```bash
cp UC8/web/Components/Pages/Products.razor ecommerce-app/src/ECommerce.Web/Components/Pages/
cp UC8/web/Components/Pages/Health.razor   ecommerce-app/src/ECommerce.Web/Components/Pages/
cp UC8/web/Services/HealthApiClient.cs     ecommerce-app/src/ECommerce.Web/Services/
cp -r UC8/.claude                          ecommerce-app/      # fusionne avec le .claude existant
```
> Puis : enregistrer `HealthApiClient` dans `Program.cs` et ajouter le lien `Health` au `NavMenu`
> (voir `UC8-frontend.md`, Étape 7).

## Voir la maquette
```bash
open UC8/mockup/catalog-mockup.html        # macOS  (Linux : xdg-open · Windows : start)
```

## Pré-requis outils
- **.NET SDK 10** + **Aspire** pour lancer l'app : `dotnet run --project src/ECommerce.AppHost`
- Un **navigateur** pour vérifier le rendu (desktop + mobile via les devtools)

## Garde-fous
- On améliore la **forme**, pas les **règles métier** (panier et passage de commande inchangés).
- **a11y** : jamais d'information par la **couleur seule** ; tout contrôle a un **nom accessible**.
- La **maquette** (Artifact) sert à **valider le design** ; le rendu réel reste le composant Blazor.
- `/code-review` du diff + vérification visuelle desktop/mobile **avant** merge. Le dashboard utilise
  `/health`, **exposé en Development uniquement** (ServiceDefaults).
