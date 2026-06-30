---
name: csharp-refactoring
description: Techniques de refactoring C#/.NET sûres (comportement constant). À charger lors de la correction de dette ou de blockers de qualité.
---
## Principes
- Refactoring = améliorer la **structure** sans changer le **comportement**. Compiler
  (`dotnet build`) après chaque étape ; s'appuyer sur les tests.
- Préférer de petites transformations réversibles, une à la fois.

## Catalogue
- **Extract Method** : isoler un bloc cohérent dans une méthode privée nommée par l'intention.
- **Guard Clauses** : remplacer un `if (ok) { … }` profond par `if (!ok) return …;` → imbrication
  aplatie.
- **Parameter Object** : remplacer une longue liste de paramètres par un `record`.
- **Introduce Variable/Method** : nommer une sous-expression complexe.
- **Replace Nested Conditional with Strategy/Polymorphism** quand un `switch` grossit.

## Conventions à respecter
- `async` jusqu'au bout (jamais `.Result`/`.Wait()`), nullabilité annotée (pas de `!` gratuit),
  injection de dépendances plutôt que `new`, `CancellationToken` propagé sur l'async public.
