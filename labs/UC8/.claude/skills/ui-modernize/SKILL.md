---
name: ui-modernize
description: Améliore une page de l'interface Blazor de l'ecommerce-app (ECommerce.Web) — responsive (mobile-first, Bootstrap), états de chargement (skeletons/spinners), états vide/erreur, et accessibilité (a11y : HTML sémantique, aria-*, labels, contraste, focus). Propose d'abord une maquette via le skill intégré artifact-design + Artifact, puis applique les changements sans casser l'interactivité Blazor Server, et recommande une revue /code-review.
---

# Skill : ui-modernize

Objectif : moderniser une page de `ECommerce.Web` (Blazor Server + Bootstrap) sur 4 axes —
**responsive**, **états** (chargement / vide / erreur), **accessibilité (a11y)**, et **maquette**.

## Étapes à suivre
1. Lire la page cible (ex. `Components/Pages/Products.razor`) et repérer les manques : table non
   responsive, « Loading… » en texte brut, pas d'état vide/erreur, `label` non associé au champ,
   action sans libellé accessible, statut codé par la **couleur seule**.
2. **Proposer une maquette d'abord** : invoquer le skill intégré **`artifact-design`** et produire
   un **Artifact HTML autonome** (la « maquette ») pour validation visuelle **AVANT** de toucher au
   code.
3. Appliquer les améliorations en gardant les conventions du projet :
   - **Responsive** : `table-responsive`, grilles `row`/`col-*`, mobile-first.
   - **États** : skeletons (`placeholder-glow`) au chargement, `spinner` sur action, états **vide**
     et **erreur** explicites (avec bouton *Retry*).
   - **a11y** : HTML sémantique (`<caption>`, `scope`, `<section aria-labelledby>`), `aria-label` sur
     les actions, `label for`/`id`, `role="alert"`/`aria-live`, statut = **couleur + texte**.
4. **Ne pas casser Blazor Server** : conserver `@rendermode InteractiveServer`, les `@bind`, les
   handlers `@onclick` et la logique du bloc `@code` existant.
5. Recommander une revue `/code-review` du diff et une vérification visuelle (lancer l'app).

## Garde-fous
- **Ne pas altérer le comportement métier** (panier, passage de commande) : on améliore la **forme**,
  pas les règles.
- **a11y non négociable** : jamais d'information par la **couleur seule** ; tout contrôle interactif
  doit avoir un **nom accessible**.
- **Maquette ≠ prod** : l'Artifact sert à **valider le design** ; le rendu réel reste le composant
  Blazor (mêmes données, mêmes endpoints).
- Revue humaine du rendu (desktop + mobile) avant merge ; pas de dépendance front externe ajoutée
  sans accord (l'app utilise déjà Bootstrap).
