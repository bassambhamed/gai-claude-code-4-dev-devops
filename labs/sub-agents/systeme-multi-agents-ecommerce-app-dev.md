# Système multi-agents Claude Code — auditer, corriger et fiabiliser `ecommerce-app-dev`

> Une **équipe d'agents** Claude Code qui travaille sur le dépôt `ecommerce-app-dev`
> (l'`ecommerce-app` : microservices **.NET 10 / Aspire**). Un **orchestrateur** délègue à **trois
> sous-agents spécialisés** qui s'exécutent **ensemble**, chacun avec son périmètre, ses outils et
> ses compétences. À la fin, l'orchestrateur **rédige un rapport Markdown** décrivant ce que chaque
> sous-agent a réalisé.

Ce document décrit **l'architecture et les rôles**. Les **étapes de mise en place et de
vérification** sont dans [`mise-en-place-et-verification.md`](mise-en-place-et-verification.md).

---

## 1. Vue d'ensemble

Trois spécialistes complémentaires, pilotés par un orchestrateur, sur un même objectif de livraison :

| Agent | Rôle en une phrase | Écrit ? | Périmètre de fichiers | Modèle |
|---|---|---|---|---|
| 🎼 **orchestrateur** (`/audit-fix-ship`) | décompose, délègue **en parallèle**, synthétise, **écrit le rapport** | rapport `.md` uniquement | `rapport-multi-agents.md` | `opus` |
| 🟦 **`dotnet-reviewer`** | lit les **blockers CodeScene** et les **corrige** dans le code | **oui** | `src/**/*.cs` | `sonnet` |
| 🟩 **`test-runner`** | exécute `dotnet test`, ne remonte que les échecs | non (lecture seule) | — | `haiku` |
| 🟧 **`devops-engineer`** | revoit/améliore Dockerfile, CI, k8s/Helm | **oui** | infra (Dockerfile, `.github/`, `k8s/`, `helm/`) | `sonnet` |

Le découpage des **outils** et des **périmètres** n'est pas cosmétique : il est garanti par le
harnais (outils restreints + hooks de garde), pas par la bonne volonté du modèle. C'est ce qui
permet aux trois de travailler **en même temps sans se marcher dessus** : leurs zones d'écriture
sont **disjointes** (`dotnet-reviewer` ↦ code `.cs`, `devops-engineer` ↦ infra, `test-runner` ↦
rien).

```
                         ┌──────────────────────────────────────────────┐
                         │   ORCHESTRATEUR  ·  /audit-fix-ship           │
                         │   (session principale · modèle opus)          │
                         │   décompose → délègue → synthétise → RAPPORT  │
                         └───────────────────────┬──────────────────────┘
        fan-out (UN SEUL message → 3 Task en parallèle)  │  fan-in + rapport .md
        ┌──────────────────────────┬─────────────────────┴──────────────────┐
        ▼                          ▼                                         ▼
 ┌────────────────────┐   ┌────────────────────┐                 ┌────────────────────┐
 │ 🟦 dotnet-reviewer │   │ 🟩 test-runner     │                 │ 🟧 devops-engineer │
 │  sonnet            │   │  haiku             │                 │  sonnet            │
 │  Read Edit Write   │   │  Bash Read         │                 │  Read Edit Write   │
 │  Bash Grep Glob    │   │  (lecture seule)   │                 │  Bash Grep Glob    │
 │                    │   │                    │                 │                    │
 │  CORRIGE les       │   │  dotnet test       │                 │  Dockerfile · CI   │
 │  blockers CodeScene│   │  → échecs only     │                 │  k8s · Helm        │
 └─────────┬──────────┘   └─────────┬──────────┘                 └─────────┬──────────┘
  périmètre : src/**.cs     périmètre : aucun (RO)                périmètre : infra
  skills :                  skill :                               skill :
   codescene-blockers        dotnet-test-runner                   docker-ci-review
   csharp-refactoring
  hook : guard-src-only     hook : validate-readonly              hook : guard-infra-only
```

> **Pourquoi cette séparation ?** Celui qui **corrige** le code n'est pas celui qui le **teste**, et
> ni l'un ni l'autre ne touche à l'**infra**. Aucun agent ne valide son propre travail, et deux
> agents n'écrivent **jamais** le même fichier. La fiabilité vient de la séparation des pouvoirs.

---

## 2. Le dépôt support : `ecommerce-app-dev`

`ecommerce-app-dev` est le dépôt Git de l'`ecommerce-app`, une application e-commerce en
microservices **.NET 10** orchestrée par **.NET Aspire**. C'est aussi le **référentiel analysé par
CodeScene** (santé du code / quality gate). Structure de travail :

```
ecommerce-app/                       # copie de travail (= le dépôt ecommerce-app-dev)
├─ ECommerce.slnx                    # solution
├─ src/
│  ├─ ECommerce.Catalog.Api/         # service Catalogue
│  ├─ ECommerce.Ordering.Api/        # service Commandes
│  ├─ ECommerce.Gateway/             # passerelle (YARP)
│  ├─ ECommerce.Web/                 # front
│  ├─ ECommerce.AppHost/             # orchestration Aspire
│  └─ ECommerce.ServiceDefaults/     # défauts partagés (santé, télémétrie)
├─ src/<Service>/Dockerfile          # 1 Dockerfile par service (contexte de build = racine)
├─ docker-compose.yml                # dev hors Aspire
├─ .github/workflows/*.yml           # CI GitHub Actions (build/test/Trivy/gate)
├─ k8s/ , helm/                      # manifests / chart (si présents — UC5/UC6)
└─ .codescene/blockers.json          # export des blockers CodeScene (ou via la CLI `cs`)
```

> Convention `.NET` du dépôt : .NET 10, nullable activé, *warnings as errors*, tests **xUnit**
> (`WebApplicationFactory` + base in-memory), aucun secret en dur. Si `dotnet` est introuvable :
> `export PATH="/usr/local/share/dotnet:$PATH"`.

---

## 3. Briques Claude Code utilisées (rappel court)

- **Sous-agent** — un *worker* isolé, dans **sa propre fenêtre de contexte**, avec son prompt
  système, ses **outils restreints** et son modèle. Il fait son travail et ne renvoie qu'un
  **résumé**. C'est l'unité de parallélisme. Fichiers : `.claude/agents/<nom>.md`.
- **Skill** — une **connaissance/procédure réutilisable** préchargée dans un sous-agent (via
  `skills:` dans le frontmatter). Fichiers : `.claude/skills/<nom>/SKILL.md`.
- **Hook** — une **commande shell déterministe** déclenchée par un évènement (avant/après un outil).
  Aucune intelligence : `exit 2` **bloque** l'opération et renvoie le message à Claude ; `exit 0`
  laisse passer. C'est ce qui transforme une *consigne* en *garantie*.
- **Command** — une **recette** déclenchée par `/<nom>`. C'est la couche d'orchestration : elle peut
  lancer plusieurs sous-agents. Fichiers : `.claude/commands/<nom>.md`.

Arborescence `.claude/` du système (créée dans la copie de travail `ecommerce-app/`) :

```
.claude/
├─ commands/
│  ├─ audit-fix-ship.md            # 🎼 l'orchestrateur (session principale)
│  └─ reset-lab.md                 # 🧹 nettoyage « table rase » contrôlé
├─ agents/
│  ├─ dotnet-reviewer.md           # 🟦
│  ├─ test-runner.md               # 🟩
│  └─ devops-engineer.md           # 🟧
├─ skills/
│  ├─ codescene-blockers/SKILL.md
│  ├─ csharp-refactoring/SKILL.md
│  ├─ dotnet-test-runner/SKILL.md
│  └─ docker-ci-review/SKILL.md
├─ scripts/
│  ├─ guard-src-only.sh            # dotnet-reviewer : interdit d'écrire hors du code
│  ├─ guard-infra-only.sh          # devops-engineer : interdit d'écrire du .cs
│  ├─ validate-readonly.sh         # test-runner : interdit toute mutation
│  └─ reset-lab.sh                 # nettoyage sûr (dry-run par défaut, --yes pour exécuter)
└─ run/
   ├─ timeline.log                 # horodatages START/END (preuve de simultanéité, généré)
   └─ verify-parallel.sh           # vérifie le chevauchement temporel des agents
```

---

## 4. L'orchestrateur — rôle et méthode

**Incarnation : la command `/audit-fix-ship`, lancée depuis la session principale.** On orchestre
depuis la session principale (et non depuis un sous-agent) car un sous-agent ne peut, en général,
**pas** lancer lui-même d'autres sous-agents : c'est la session principale qui sait émettre
**plusieurs appels `Task` dans un seul message** — la condition pour que les trois spécialistes
tournent **réellement en même temps**.

### Rôle
L'orchestrateur **ne code pas, ne teste pas, ne touche pas à l'infra**. Il :

1. **Cadre** l'objectif et les critères d'acceptation (blockers à zéro, tests verts, infra saine).
2. **Délègue en parallèle** (fan-out) aux trois sous-agents, en **un seul message**.
3. **Converge** (fan-in) : il fait re-vérifier les tests **après** les corrections de code.
4. **Synthétise et rédige le rapport** Markdown final décrivant ce que chaque sous-agent a fait.

### Méthode (3 phases)
- **Phase 1 — fan-out parallèle.** Dans **un seul message**, lance les **trois** délégations `Task`
  *simultanées* :
  - `dotnet-reviewer` → lit les **blockers CodeScene** et les **corrige** dans `src/` ;
  - `devops-engineer` → revoit/améliore l'**infra** (Dockerfile, CI, k8s/Helm) ;
  - `test-runner` → établit la **baseline** (lance `dotnet test` sur l'état courant).
  > Ces trois tâches portent sur des **fichiers disjoints** → elles peuvent s'exécuter de front
  > sans conflit. C'est cette étape qui rend les trois agents visibles **ensemble**.
- **Phase 2 — convergence.** Re-délègue à `test-runner` une **vérification finale** (`dotnet test`
  **après** les corrections de `dotnet-reviewer`) pour garantir l'absence de régression. Récupère un
  **verdict** `PASS`/`FAIL`. Si `FAIL` : renvoie les findings à `dotnet-reviewer`, re-teste (≤ 3
  tours), sinon remonte à l'humain.
- **Phase 3 — rapport.** Écrit `rapport-multi-agents.md` (voir §8) : ce que **chaque** sous-agent a
  réalisé + le verdict global.

### Outils & garanties
`allowed-tools: Agent, Bash(git*), Read, Write`. L'orchestrateur n'a **pas** `Edit` : il ne peut pas
modifier le code. Son seul `Write` sert au **rapport**. Tout ce qui est destructif/irréversible reste
soumis à validation humaine.

### Définition — `.claude/commands/audit-fix-ship.md`
```markdown
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
      echo "<agent> END $(date +%s)" >> .claude/run/timeline.log
  (remplace <agent> par dotnet-reviewer | devops-engineer | test-runner).

### Phase 2 — convergence (fan-in)
Re-délègue à test-runner une vérification finale : relance dotnet test APRÈS les corrections
de dotnet-reviewer. Récupère un verdict PASS/FAIL. Si FAIL, renvoie les findings bloquants à
dotnet-reviewer puis re-teste (au plus 3 tours) ; au-delà, remonte le blocage à l'humain.

### Phase 3 — rapport
Quand le verdict est PASS (ou après 3 tours), écris le fichier rapport-multi-agents.md à la
racine du dépôt, en suivant le gabarit du système (une section par sous-agent : ce qu'il a
réalisé, avec preuves). Termine par un verdict global : LIVRABLE / À CORRIGER.
```

---

## 5. Sous-agent 🟦 `dotnet-reviewer` — corriger les blockers CodeScene

### Rôle
Éliminer la **dette de qualité signalée par CodeScene**. CodeScene mesure la **santé du code**
(*Code Health*) et applique une **quality gate** ; une violation qui fait **échouer la gate** (en
absolu, ou en *delta* sur une PR : santé qui se dégrade) est un **blocker** qui empêche la fusion.
`dotnet-reviewer` lit ces blockers, ouvre les fonctions fautives et les **refactore** — **à
comportement constant** — jusqu'à ce que les blockers disparaissent.

### Compétences (skills préchargées)
- **`codescene-blockers`** : ce qu'est un blocker, comment le récupérer (CLI `cs` ou rapport
  `.codescene/blockers.json`), et la remédiation **par catégorie** (Complex Method, Deep Nested
  Logic, Bumpy Road, Brain Method, God Class, Many Function Arguments…).
- **`csharp-refactoring`** : techniques sûres (*Extract Method*, *Guard Clauses*, *Parameter
  Object*…) appliquées au C#, en s'appuyant sur les tests pour garantir l'invariance.

### Périmètre & garde-fou
Outils : `Read, Edit, Write, Bash, Grep, Glob, Skill`. Il a le droit d'**écrire**, mais **uniquement
du code applicatif** (`src/**/*.cs`). Un hook `PreToolUse` (`guard-src-only.sh`) **bloque** toute
écriture sur l'infra (Dockerfile, `.github/`, `k8s/`, `helm/`, `*.yml`) → il ne peut pas empiéter
sur `devops-engineer`.

### Définition — `.claude/agents/dotnet-reviewer.md`
```markdown
---
name: dotnet-reviewer
description: Corrige les blockers CodeScene (Code Health) du code C#/.NET de ecommerce-app-dev. Lit l'analyse CodeScene, refactore les fonctions fautives dans src/ à comportement constant, puis re-vérifie. À utiliser pour traiter la dette signalée par la quality gate CodeScene.
tools: Read, Edit, Write, Bash, Grep, Glob, Skill
model: sonnet
color: blue
skills:
  - codescene-blockers
  - csharp-refactoring
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./.claude/scripts/guard-src-only.sh"
---
Tu es relecteur/refactoreur senior .NET. Mission : faire disparaître les *blockers* CodeScene.

Méthode :
1. Récupère les blockers : `cs check --output-format json` (analyse locale) ou la delta-analysis
   CI ; à défaut, lis `.codescene/blockers.json`. Garde ceux de sévérité « blocker ».
2. Pour chaque blocker (Complex Method, Deep Nested Logic, Bumpy Road, Brain Method, Large
   Method, God Class, Many Function Arguments…) : ouvre le fichier:fonction, comprends le
   comportement, puis refactore SANS changer le comportement observable (extraction de méthode,
   guard clauses / early return pour aplatir l'imbrication, objet-paramètre…).
3. Compile au fil de l'eau : `dotnet build`.
4. Re-vérifie : relance `cs check` (ou recoupe `.codescene/blockers.json`) → le blocker doit
   disparaître / le Code Health remonter.

Périmètre STRICT : tu n'édites QUE du code sous src/ (fichiers .cs). Tu ne touches JAMAIS à
l'infra (Dockerfile, CI, k8s, helm) — c'est devops-engineer (un hook te l'interdit de toute
façon). Si une zone à corriger n'est pas couverte par des tests, signale-le.

Rends un résumé : blockers traités (fichier:ligne, catégorie, correctif appliqué), blockers
restants, et la preuve (sortie `dotnet build` OK, re-check CodeScene).
```

---

## 6. Sous-agent 🟩 `test-runner` — exécuter la suite et remonter les échecs

### Rôle
Donner la **vérité terrain** sur l'état des tests, deux fois : en **baseline** (avant/pendant les
corrections, en parallèle des deux autres) puis en **vérification finale** (après les corrections,
à la convergence). Il ne renvoie que l'essentiel : les **tests rouges** et le compte.

### Compétence (skill préchargée)
- **`dotnet-test-runner`** : les commandes exactes sur `ECommerce.slnx`, le filtrage par service,
  le format de sortie (échecs uniquement + compte vert/rouge), et le rappel du `PATH` `dotnet`.

### Périmètre & garde-fou
Outils : `Bash, Read` — **pas** d'`Edit`/`Write` : il lui est **matériellement impossible** de
modifier le code qu'il juge. Un hook `PreToolUse` (`validate-readonly.sh`) **bloque** toute commande
**mutante** (`dotnet add/remove/new/publish`, `git commit/push/checkout/reset/merge`, `rm -…`) tout
en laissant passer `dotnet build`/`dotnet test` et l'horodatage d'instrumentation.

### Définition — `.claude/agents/test-runner.md`
```markdown
---
name: test-runner
description: Exécute la suite de tests (xUnit / WebApplicationFactory) de ecommerce-app-dev et ne remonte que les échecs avec leur message. Lecture seule. Sert de baseline puis de vérification après corrections.
tools: Bash, Read
model: haiku
color: green
skills:
  - dotnet-test-runner
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./.claude/scripts/validate-readonly.sh"
---
Tu exécutes les tests, rien d'autre.

1. Si `dotnet` est introuvable : `export PATH="/usr/local/share/dotnet:$PATH"`.
2. Lance `dotnet test ECommerce.slnx --nologo`.
3. Ne renvoie QUE les tests en échec : nom complet, message, fichier:ligne.
4. Termine par le compte : « X passés / Y échoués / Z ignorés ». Si tout passe : une seule ligne.

Tu n'écris AUCUN fichier de projet (lecture seule, garanti par un hook).
```

---

## 7. Sous-agent 🟧 `devops-engineer` — fiabiliser l'infra

### Rôle
Mettre en place et **fiabiliser l'infrastructure** de `ecommerce-app-dev`, en parallèle des
corrections de code : Dockerfiles, pipeline CI et manifests d'orchestration. **Sur table rase**
(infra absente après nettoyage), il **crée** ces fichiers ; sinon il **revoit et améliore**
l'existant. Il explique chaque changement avant de l'appliquer.

### Compétence (skill préchargée)
- **`docker-ci-review`** : checklist Dockerfile (multi-stage, runtime **chiselé**, **non-root**,
  ordre des `COPY` pour le cache de layers), CI GitHub Actions (restore/build/test/publish, cache
  NuGet, scan **Trivy**, **gate manuel** avant prod), k8s/Helm (probes, requests/limits, HPA).

### Périmètre & garde-fou
Outils : `Read, Edit, Write, Bash, Grep, Glob, Skill`. Il a le droit d'écrire, mais **uniquement
l'infra**. Un hook `PreToolUse` (`guard-infra-only.sh`) **bloque** toute écriture de fichier `.cs` →
il ne peut pas empiéter sur `dotnet-reviewer`.

### Définition — `.claude/agents/devops-engineer.md`
```markdown
---
name: devops-engineer
description: Met en place et fiabilise l'infra de ecommerce-app-dev — Dockerfiles multi-stage/chiselés/non-root, pipeline CI GitHub Actions, manifests k8s et chart Helm. Crée l'infra si elle est absente (table rase), sinon la revoit et l'améliore. Édite UNIQUEMENT les fichiers d'infra (jamais le code .cs).
tools: Read, Edit, Write, Bash, Grep, Glob, Skill
model: sonnet
color: orange
skills:
  - docker-ci-review
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./.claude/scripts/guard-infra-only.sh"
---
Tu es ingénieur DevOps. Tu prends en charge l'infra de l'ecommerce-app et tu expliques chaque
changement AVANT de l'appliquer.

D'abord, fais l'état des lieux : l'infra existe-t-elle ? (`ls src/*/Dockerfile`, `.github/workflows/`,
`k8s/`, `helm/`).

## Cas « table rase » (infra absente — repo nettoyé)
Si les Dockerfiles / workflows / manifests n'existent pas, tu les **crées** (containerisation) :
- un `src/<Service>/Dockerfile` multi-stage, runtime **chiselé**, **non-root** pour chaque service
  exécutable : `ECommerce.Catalog.Api`, `ECommerce.Ordering.Api`, `ECommerce.Gateway`,
  `ECommerce.Web` (pas `AppHost` ni `ServiceDefaults`). Contexte de build = racine du repo,
  `COPY` des `.csproj` d'abord (cache du `restore`) ;
- un `docker-compose.yml` de dev qui relie les services ;
- un `.github/workflows/ci.yml` : restore → build → test → publish, cache NuGet, scan **Trivy** ;
- si demandé : un squelette `k8s/` (Deployments/Services/Ingress, probes `/health`) ou un chart
  `helm/` paramétrable.

## Cas « infra présente »
Tu revois et améliores l'existant :
- `src/<Service>/Dockerfile` : multi-stage, runtime chiselé, non-root (`USER $APP_UID`), ordre des
  `COPY` pour le cache de layers ;
- `.github/workflows/*.yml` : étapes complètes, cache NuGet, Trivy, **gate manuel** avant prod ;
- `k8s/` / `helm/` : probes liveness/readiness, requests/limits, HPA, values multi-environnements.

Périmètre STRICT : tu ne touches QUE l'infra. Tu ne modifies JAMAIS le code applicatif (.cs) —
c'est dotnet-reviewer (un hook te l'interdit de toute façon).

Rends un résumé : fichiers d'infra créés/modifiés, nature de chaque choix, et le « pourquoi ».
```

---

## 8. Le rapport final de l'orchestrateur

À la fin, l'orchestrateur écrit `rapport-multi-agents.md` à la racine du dépôt. C'est le **livrable
de traçabilité** : il décrit, **pour chaque sous-agent**, ce qui a été réalisé, avec des preuves
(diffs, sortie de tests, re-check CodeScene). Gabarit :

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
| CH-001 | src/ECommerce.Ordering.Api/...:42 | Complex Method | extraction de méthode + guard clauses |
| ...    | ...                               | ...            | ... |
- Re-check CodeScene : <résultat>. Build : <OK/KO>.

## 🟩 test-runner — vérification
- **Baseline** (phase parallèle) : <résumé : verts/rouges>.
- **Après corrections** (convergence) : <verdict PASS/FAIL>, <passés>/<total>.
- Sortie clé : <extrait de la sortie de tests>.

## 🟧 devops-engineer — infrastructure
- Dockerfile(s) : <changements + pourquoi>.
- CI : <changements>.
- k8s / Helm : <changements>.

## Prochaines actions
- <ce qui reste à faire / risques résiduels / décisions à prendre par un humain>
```

> Le rapport est rédigé **par l'orchestrateur**, à partir des **résumés** que chaque sous-agent lui
> a renvoyés — pas à partir de leurs milliers de lignes de logs. Chaque sous-agent a travaillé dans
> **son propre contexte** ; seul l'essentiel remonte.

---

## 9. Les garde-fous (hooks) en détail

Trois petits scripts shell garantissent la **séparation des pouvoirs**. Règle : `exit 2` **bloque**
l'opération et renvoie le message à Claude ; `exit 0` laisse passer. (Sous Windows pur : réécrire en
PowerShell et ajouter `shell: powershell` à l'entrée du hook ; `jq` est requis sous Linux/macOS/WSL.)

**`.claude/scripts/guard-src-only.sh`** — `dotnet-reviewer` n'écrit que du code :
```bash
#!/usr/bin/env bash
# dotnet-reviewer ne corrige QUE le code applicatif (src/**/*.cs). Pas l'infra.
INPUT=$(cat)
P=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$P" in
  *Dockerfile|*/.github/*|*docker-compose*|*/k8s/*|*/helm/*|*.yml|*.yaml)
    echo "Bloqué : dotnet-reviewer ne touche pas l'infra ($P). Périmètre = src/ (.cs). L'infra est gérée par devops-engineer." >&2
    exit 2 ;;
esac
exit 0
```

**`.claude/scripts/guard-infra-only.sh`** — `devops-engineer` n'écrit pas de `.cs` :
```bash
#!/usr/bin/env bash
# devops-engineer ne touche QUE l'infra. Pas le code applicatif (.cs).
INPUT=$(cat)
P=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$P" in
  *.cs)
    echo "Bloqué : devops-engineer ne modifie pas le code .cs ($P). Périmètre = infra (Dockerfile, CI, k8s, helm). Le code est géré par dotnet-reviewer." >&2
    exit 2 ;;
esac
exit 0
```

**`.claude/scripts/validate-readonly.sh`** — `test-runner` ne mute rien :
```bash
#!/usr/bin/env bash
# test-runner = lecture seule : autorise build/test + l'horodatage, bloque toute mutation du projet.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$CMD" | grep -iE '\bdotnet[[:space:]]+(add|remove|new|publish|nuget)\b|\bgit[[:space:]]+(commit|push|checkout|reset|merge|rebase)\b|\brm[[:space:]]+-' >/dev/null; then
  echo "Bloqué : test-runner est en lecture seule (build/test uniquement, pas de mutation)." >&2
  exit 2
fi
exit 0
```

> Effet net : même si un modèle « voulait » sortir de son rôle, il **ne peut pas**. La sécurité ne
> repose pas sur la politesse du prompt mais sur le harnais.

---

## 10. Les compétences (skills) en détail

**`.claude/skills/codescene-blockers/SKILL.md`**
```markdown
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
```

**`.claude/skills/csharp-refactoring/SKILL.md`**
```markdown
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
```

**`.claude/skills/dotnet-test-runner/SKILL.md`**
```markdown
---
name: dotnet-test-runner
description: Lancer la suite de tests de ecommerce-app-dev et n'en remonter que l'essentiel.
---
## Commandes
- PATH si besoin : `export PATH="/usr/local/share/dotnet:$PATH"`.
- Toute la suite : `dotnet test ECommerce.slnx --nologo`.
- Filtrer par service : `dotnet test --filter "FullyQualifiedName~Ordering"`.
## Sortie attendue
- Ne renvoyer QUE les tests rouges : nom complet, message, `fichier:ligne`.
- Terminer par le compte : « X passés / Y échoués / Z ignorés ».
- Si tout est vert : une seule ligne « ✅ N tests, tous verts ».
```

**`.claude/skills/docker-ci-review/SKILL.md`**
```markdown
---
name: docker-ci-review
description: Checklist DevOps pour ecommerce-app-dev — Dockerfile, CI GitHub Actions, k8s/Helm. À charger pour revoir/améliorer l'infra.
---
## Dockerfile (src/<Service>/Dockerfile, contexte de build = racine du repo)
- Multi-stage : `sdk:10.0` pour build, runtime **chiselé** (`aspnet:10.0-noble-chiseled`) en final.
- `COPY` des `.csproj` AVANT le code → `restore` mis en cache (rejoué seulement si un csproj change).
- Non-root : `USER $APP_UID`. `EXPOSE 8080`. `dotnet publish -c Release --no-restore`.
## CI (.github/workflows/*.yml)
- Étapes : restore → build → test → publish. Cache NuGet. Scan **Trivy** des images.
  **Gate manuel** (environnement protégé) avant la prod.
## k8s / Helm
- Probes `liveness`/`readiness` sur `/health`, `requests`/`limits`, **HPA**. Values multi-env
  (dev/preprod).
```

---

## 11. Pourquoi cette architecture (et pas un seul agent)

| Un seul agent | Orchestrateur + 3 spécialistes |
|---|---|
| Mélange corriger / tester / déployer → angle mort sur ses propres erreurs | Le **testeur** est indépendant du **correcteur** ; l'**infra** est isolée du **code** |
| Un gros prompt fourre-tout | Chaque agent a un **rôle net**, des **outils restreints**, une **compétence** dédiée |
| Droits difficiles à borner | `test-runner` **ne peut pas** écrire ; chacun **ne peut pas** sortir de son périmètre (hooks) |
| Contexte unique qui gonfle | Chaque sous-agent travaille dans **son propre contexte** ; seul le résumé remonte |
| Tout en série | Trois tâches à **périmètres disjoints** → exécutables **en même temps** |

Le principe : **séparer les compétences**, **restreindre les outils et les périmètres par rôle**, et
laisser un **orchestrateur** faire converger correction ↔ vérification, puis **tracer** le tout dans
un rapport.

---

## 12. Annexe — récapitulatif des chemins

```
.claude/commands/audit-fix-ship.md   # orchestrateur (session principale, opus)
.claude/commands/reset-lab.md        # nettoyage « table rase » contrôlé (avant la démo)
.claude/agents/dotnet-reviewer.md     # 🟦 corrige les blockers CodeScene (src/**.cs)
.claude/agents/test-runner.md         # 🟩 dotnet test, lecture seule
.claude/agents/devops-engineer.md     # 🟧 Dockerfile/CI/k8s/helm
.claude/skills/<nom>/SKILL.md         # codescene-blockers, csharp-refactoring, dotnet-test-runner, docker-ci-review
.claude/scripts/*.sh                  # guard-src-only, guard-infra-only, validate-readonly, reset-lab
.claude/run/timeline.log              # horodatages START/END (preuve de simultanéité)
.claude/run/verify-parallel.sh        # vérifie le chevauchement temporel
rapport-multi-agents.md               # ← écrit par l'orchestrateur (livrable)
.codescene/blockers.json              # source des blockers (ou CLI `cs`)
```

> Mise en place pas-à-pas et vérifications du bon fonctionnement :
> [`mise-en-place-et-verification.md`](mise-en-place-et-verification.md).
>
> **Démarrer sur table rase :** le corrigé [`../UC-sub-agents/`](../UC-sub-agents/) fournit aussi la
> commande `/reset-lab` (nettoyage sûr : skills/hooks/Dockerfiles hérités + images/conteneurs Docker
> + cluster k8s, en préservant le code, les tests et le système multi-agents — `labs/` jamais touché)
> et un dossier `seed/` (code volontairement complexe ciblé par `blockers.json`, pour un blocker
> **réel** à corriger en démo — avec un projet de test **xUnit de caractérisation** qui prouve que le
> refactoring reste **à comportement constant**).
