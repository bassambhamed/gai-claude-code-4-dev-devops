---
name: codescene-blockers
description: Lire les blockers d'une analyse CodeScene (Code Health) et les corriger en C#. À charger pour traiter la dette signalée par la quality gate CodeScene.
---
## Qu'est-ce qu'un « blocker » CodeScene
CodeScene évalue le **Code Health** et applique une **quality gate**. Une violation qui fait
échouer la gate — en absolu, ou en *delta* sur une PR (santé qui se dégrade) — est un **blocker** :
la CI bloque la fusion.

Catégories fréquentes côté C# : **Complex Method** (complexité cyclomatique élevée), **Deep,
Nested Logic** (imbrication profonde), **Bumpy Road Ahead** (plusieurs blocs profonds dans une
fonction), **Brain Method** (longue + complexe + beaucoup de variables), **Large Method**,
**God Class**, **Code Duplication**, **Many Function Arguments**, **Primitive Obsession**,
**Constructor Over-Injection**.

## Récupérer les blockers
1. CLI CodeScene : `cs check --output-format json` (analyse locale) ou `cs delta` (PR). Garde les
   entrées de sévérité « blocker » / qui font échouer la gate.
2. À défaut (hors-ligne) : lis le rapport exporté `.codescene/blockers.json` (artefact de la
   delta-analysis de la CI).

## Remédiation par catégorie (à COMPORTEMENT CONSTANT)
- Complex Method / Deep Nested Logic → **Extract Method** + **guard clauses** (early return) pour
  aplatir l'imbrication.
- Bumpy Road → extraire chaque « bosse » dans une méthode nommée par l'intention.
- Brain Method / Large Method → découper en étapes ; une responsabilité par méthode.
- God Class → séparer les responsabilités (SRP), extraire des services injectés.
- Many Function Arguments → **objet-paramètre** (`record`) regroupant les arguments cohérents.
- Code Duplication → factoriser dans une méthode/helper commun.
> Règle d'or : refactoring **sans** changer le comportement observable. On s'appuie sur les tests
> (test-runner) pour le garantir. Si une zone n'est pas couverte, le signaler dans le résumé.
