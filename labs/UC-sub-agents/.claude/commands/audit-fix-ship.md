---
description: Orchestre 3 sous-agents (dotnet-reviewer, test-runner, devops-engineer) pour corriger les blockers CodeScene, vérifier les tests et fiabiliser l'infra de ecommerce-app-dev, puis écrit un rapport markdown.
argument-hint: "[branche]"
allowed-tools: Agent, Bash(git*), Read, Write
model: opus
---
# Orchestration — auditer, corriger & fiabiliser ecommerce-app-dev — $ARGUMENTS

Contexte des changements :
- Statut : !`git status -sb`
- Diff vs main : !`git diff --stat main...HEAD`

## Ton rôle (orchestrateur)
Tu coordonnes 3 spécialistes. Tu NE codes pas, NE testes pas, NE touches pas à l'infra
toi-même : tu délègues, tu fais converger, puis tu écris le rapport.

### Phase 1 — fan-out PARALLÈLE (un seul message, 3 appels Task simultanés)
Émets dans CE message les TROIS délégations en même temps (pas l'une après l'autre) :
  • dotnet-reviewer : récupère les blockers CodeScene et CORRIGE le code fautif dans src/ ;
  • devops-engineer : revoit et améliore l'infra (Dockerfile, .github/workflows, k8s, helm) ;
  • test-runner     : établit la BASELINE (lance dotnet test sur l'état courant, liste les échecs).

Consigne d'instrumentation pour CHAQUE sous-agent (preuve de simultanéité) :
  - tout premier geste, en Bash :
      echo "<agent> START $(date +%s)" >> .claude/run/timeline.log
  - tout dernier geste, en Bash :
      echo "<agent> END   $(date +%s)" >> .claude/run/timeline.log
  (remplace <agent> par dotnet-reviewer | devops-engineer | test-runner).

### Phase 2 — convergence (fan-in)
Re-délègue à test-runner une vérification finale : relance dotnet test APRÈS les corrections
de dotnet-reviewer. Récupère un verdict PASS/FAIL. Si FAIL, renvoie les findings bloquants à
dotnet-reviewer puis re-teste (au plus 3 tours) ; au-delà, remonte le blocage à l'humain.

### Phase 3 — rapport
Quand le verdict est PASS (ou après 3 tours), écris le fichier rapport-multi-agents.md à la
racine du dépôt, en suivant le gabarit ci-dessous (une section par sous-agent : ce qu'il a
réalisé, avec preuves). Termine par un verdict global : LIVRABLE / À CORRIGER.

```markdown
# Rapport d'exécution — système multi-agents · ecommerce-app-dev
_Généré le <date> · branche `<branche>` · commit `<sha>`_

## Synthèse
- **Verdict global** : ✅ LIVRABLE  /  ⛔ À CORRIGER
- **Blockers CodeScene** : <n> traités / <m> restants
- **Tests** : <vert|rouge> — <passés>/<total>
- **Infra** : <k> améliorations appliquées

## 🟦 dotnet-reviewer — correction des blockers CodeScene
| Blocker | Fichier:ligne | Catégorie Code Health | Correctif appliqué |
|---|---|---|---|
| <id> | <fichier:ligne> | <catégorie> | <correctif> |
- Re-check CodeScene : <résultat>. Build : <OK/KO>.

## 🟩 test-runner — vérification
- **Baseline** (phase parallèle) : <verts/rouges>.
- **Après corrections** (convergence) : <verdict>, <passés>/<total>.
- Sortie clé : <extrait>.

## 🟧 devops-engineer — infrastructure
- Dockerfile(s) : <changements + pourquoi>.
- CI : <changements>.
- k8s / Helm : <changements>.

## Prochaines actions
- <reste à faire / risques / décisions humaines>
```

## Règles
- Ne contourne aucun spécialiste : pas d'écriture de code ni de test par toi-même.
- Chaque délégation doit être autonome (le sous-agent ne voit pas toute la conversation).
- Tout ce qui est destructif/irréversible reste soumis à validation humaine.
