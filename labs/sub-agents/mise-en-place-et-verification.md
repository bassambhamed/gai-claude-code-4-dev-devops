# Mise en place & vérification — système multi-agents sur `ecommerce-app-dev`

Marche à suivre, **étape par étape**, pour : **(1) nettoyer** la copie de travail (table rase),
**(2) installer** le système multi-agents en **copiant** les dossiers/fichiers de `UC-sub-agents`,
**(3) lancer** l'orchestration des trois sous-agents et **(4) vérifier** qu'ils fonctionnent —
ensemble — sur le dépôt `ecommerce-app-dev`.

> L'architecture et les rôles (orchestrateur + `dotnet-reviewer` / `test-runner` / `devops-engineer`)
> sont décrits dans
> [`systeme-multi-agents-ecommerce-app-dev.md`](systeme-multi-agents-ecommerce-app-dev.md).

Tout se déroule **dans la copie de travail** `ecommerce-app/` (le code, les Dockerfiles, la CI et les
tests vivent là). On y lance Claude Code à la racine. On suppose que `UC-sub-agents` est accessible
en `../labs/UC-sub-agents` (à adapter à ton arborescence).

---

## 0. Prérequis

| Élément | Vérification |
|---|---|
| Claude Code (récent, panneau des sous-agents) | `claude --version` |
| .NET 10 SDK | `dotnet --version` (sinon `export PATH="/usr/local/share/dotnet:$PATH"`) |
| Git, dépôt initialisé | `git status` répond |
| `jq` (hooks, Linux/macOS/WSL) | `jq --version` |
| Docker / k3d / kubectl *(pour le nettoyage infra)* | `docker version` · `k3d version` · `kubectl version --client` |
| CodeScene CLI `cs` *(optionnel)* | `cs --version` — sinon on utilise `.codescene/blockers.json` |
| La copie de travail `ecommerce-app/` | `ls ECommerce.slnx` |

---

## Étape 0 — (recommandé) Créer une branche dédiée

Ce n'est **pas obligatoire** — les sous-agents s'exécutent sur n'importe quelle branche — mais c'est
**fortement recommandé** : le nettoyage (§1), le seed et les modifications des agents sont nombreux
et destructifs. Une branche dédiée garde `main` **intacte** et rend toute la démo **réversible**.

```bash
git switch -c demo/multi-agents       # ou : git checkout -b demo/multi-agents
```

- L'orchestrateur s'appuie sur `git diff main...HEAD` : ce contexte n'a de sens que sur une branche
  **partant de `main`** (sur `main` lui-même, `main...HEAD` est vide).
- **Tout annuler** à la fin de la démo :
  ```bash
  git switch main && git branch -D demo/multi-agents
  ```

> **Conseil (diff propre).** Après l'installation (§2), tu peux **committer la base** —
> `git add -A && git commit -m "chore: table rase + système multi-agents + seed"` — pour que les
> changements **des agents** apparaissent ensuite comme un diff **séparé et lisible** : `git diff`
> (§9) ne montrera alors que leur travail, pas le setup.

---

## Étape 1 — Nettoyer (table rase) : le prompt de départ

Première action de la démo : demander à Claude de **repartir d'une base propre**. Colle ce **prompt**
dans la session Claude Code ouverte à la racine de `ecommerce-app/` :

```text
Tu vas préparer une TABLE RASE sur cette copie de travail ecommerce-app, avant d'installer un
système multi-agents. Procède étape par étape, en me DEMANDANT confirmation avant chaque
suppression destructive, et SANS jamais toucher au dossier labs/ ni au code applicatif.

À SUPPRIMER :
1. Les personnalisations Claude héritées des UC précédents : le dossier .claude/ de l'app
   (skills, hooks, commands, agents, settings.json).
2. Les Dockerfiles et fichiers compose : src/*/Dockerfile et docker-compose*.yml / compose*.yml.
3. Les images et conteneurs Docker du projet : ceux nommés « ecommerce* »
   (docker rm -f … puis docker rmi -f … ; NE FAIS PAS de prune global).
4. Le Kubernetes local du lab : namespaces et cluster k3d nommés « ecommerce » ou « lab »
   (kubectl delete ns … / k3d cluster delete …).

À PRÉSERVER absolument : src/**/*.cs (le code), tests/, *.csproj, ECommerce.slnx, et tout le
dossier labs/. En cas de doute, demande-moi avant d'agir.

Termine par un récapitulatif de ce qui a été réellement supprimé.
```

> **Pourquoi maintenant ?** On nettoie **avant** d'installer le système multi-agents : il n'y a donc
> rien à préserver côté `.claude/` (on le recrée à l'étape 2). Le code et les tests, eux, restent.
>
> **Note :** si le plugin `ecommerce-ops` est actif, son hook `guard-destructive` demandera
> confirmation sur `rm -rf`, `kubectl delete`, `k3d cluster delete`… — c'est voulu (sécurité).

---

## Étape 2 — Copier `UC-sub-agents` vers l'app

On installe le système **en copiant** les dossiers prêts à l'emploi. Voici **quoi va où** :

| Source (`../labs/UC-sub-agents/`) | Destination (dans `ecommerce-app/`) | Contenu |
|---|---|---|
| `.claude/` | `.claude/` | orchestrateur + 3 agents + 4 skills + hooks + `reset-lab` + `run/` |
| `.codescene/` | `.codescene/` | `blockers.json` (source des blockers, option hors-ligne) |
| `seed/src/.` | `src/` | code « smelly » ciblé par les blockers (`OrderProcessor.cs`, `ProductQuery.cs`) |
| `seed/tests/.` | `tests/` | projet xUnit de caractérisation (10 tests) |

```bash
# Depuis la racine de ecommerce-app/
cp -r ../labs/UC-sub-agents/.claude    .            # agents, commands, skills, scripts, run/
cp -r ../labs/UC-sub-agents/.codescene .            # blockers.json
cp -r ../labs/UC-sub-agents/seed/src/.   src/       # code ciblé par blockers.json
cp -r ../labs/UC-sub-agents/seed/tests/. tests/     # tests de caractérisation

# Ajouter le projet de test à la solution (sinon dotnet test ne le voit pas)
export PATH="/usr/local/share/dotnet:$PATH"
dotnet sln ECommerce.slnx add tests/ECommerce.SubAgents.Tests/ECommerce.SubAgents.Tests.csproj

# Rendre les hooks et le vérificateur exécutables (sinon les hooks ne bloquent rien)
chmod +x .claude/scripts/*.sh .claude/run/verify-parallel.sh
```

Après copie, l'app contient :

```
ecommerce-app/
├─ ECommerce.slnx
├─ src/…                                  # + seed : OrderProcessor.cs, ProductQuery.cs
├─ tests/ECommerce.SubAgents.Tests/       # projet de test de caractérisation
├─ .codescene/blockers.json
└─ .claude/
   ├─ commands/   audit-fix-ship.md · reset-lab.md
   ├─ agents/     dotnet-reviewer.md · test-runner.md · devops-engineer.md
   ├─ skills/     codescene-blockers · csharp-refactoring · dotnet-test-runner · docker-ci-review
   ├─ scripts/    guard-src-only.sh · guard-infra-only.sh · validate-readonly.sh · reset-lab.sh
   └─ run/        verify-parallel.sh
```

> Les agents `.md` copiés à la main sont chargés au **démarrage de session** : **relance Claude Code**
> à la racine après la copie (ou crée-les via `/agents` pour un effet immédiat).
>
> **Variante outillée du nettoyage (étape 1).** Une fois `.claude/` copié, tu disposes aussi de la
> commande **`/reset-lab`** (nettoyage scripté, *dry-run* par défaut, qui **préserve** le système
> multi-agents) pour rejouer une table rase de façon contrôlée et reproductible.

---

## Étape 3 — Source des blockers CodeScene

`dotnet-reviewer` lit les blockers de deux façons (par ordre de préférence) :

- **Option A — CLI CodeScene** (analyse réelle de `ecommerce-app-dev`) :
  ```bash
  cs check --output-format json        # violations Code Health + résultat de la quality gate
  ```
- **Option B — rapport `.codescene/blockers.json`** (déjà copié à l'étape 2). Il pointe vers les
  fichiers **seed** plantés dans `src/` (`OrderProcessor.cs` → *Complex Method*, `ProductQuery.cs` →
  *Many Function Arguments*) : `dotnet-reviewer` a donc un blocker **réel** à corriger, et les **tests
  de caractérisation** garantissent que la correction reste **à comportement constant**.

---

## Étape 4 — Vérifier que tout est reconnu

À la racine de `ecommerce-app/`, dans Claude Code :

```text
/agents             # doit lister : dotnet-reviewer, test-runner, devops-engineer
/audit-fix-ship     # doit apparaître dans l'autocomplétion des commandes
```

---

## Étape 5 — Préparer la zone de preuve (parallélisme)

Le journal `.claude/run/timeline.log` matérialise **qui tourne quand**. Repars d'un journal propre :

```bash
rm -f .claude/run/timeline.log
```

---

## Étape 6 — Lancer l'orchestration

Place-toi sur la branche à auditer, puis lance l'orchestrateur :

```text
/audit-fix-ship feature/ma-branche
```

Si la commande n'est pas prise en compte, déclenche l'orchestrateur **par un prompt** équivalent :

```text
Joue l'orchestrateur : corrige les blockers CodeScene, vérifie les tests et fiabilise l'infra de
ecommerce-app-dev.

PHASE PARALLÈLE — dans UN SEUL message, lance EN MÊME TEMPS trois sous-agents :
  • dotnet-reviewer : récupère les blockers CodeScene et CORRIGE le code fautif (src/) ;
  • devops-engineer : crée/améliore l'infra (Dockerfile, .github/workflows, k8s, helm) ;
  • test-runner     : établit la baseline (dotnet test sur l'état courant).

Pour CHAQUE sous-agent :
  - tout premier geste, en Bash : echo "<agent> START $(date +%s)" >> .claude/run/timeline.log
  - tout dernier geste, en Bash : echo "<agent> END   $(date +%s)" >> .claude/run/timeline.log

Ensuite : convergence (test-runner relance dotnet test APRÈS les corrections), boucle si FAIL
(max 3 tours), puis écris le rapport rapport-multi-agents.md (une section par sous-agent).
```

---

## Étape 7 — Vérification n°1 : voir les trois agents *ensemble* (à l'œil)

Pendant l'exécution, dans l'interface Claude Code :

- **trois tâches d'agent apparaissent et tournent en même temps** (🟦 `dotnet-reviewer`,
  🟩 `test-runner`, 🟧 `devops-engineer`) au lieu d'une seule ;
- chacune affiche sa propre activité ; `↑/↓` pour naviguer, `Entrée` pour ouvrir une transcription,
  `Esc` pour revenir ;
- elles se terminent **indépendamment**, puis l'orchestrateur enchaîne convergence et rapport.

> Si tu ne vois **qu'une** tâche active à la fois : voir le **dépannage** (§10, « pas de parallélisme »).

---

## Étape 8 — Vérification n°2 : prouver la simultanéité (horodatage)

```bash
bash .claude/run/verify-parallel.sh
```

- ✅ `CHEVAUCHEMENT … EN MÊME TEMPS pendant Ns` → preuve que les agents ont tourné de front (code `0`).
- ⚠️ `Aucun chevauchement` → exécution séquentielle (code `2`) → §10.

Le journal brut confirme la signature du parallélisme (les `START` **avant** le premier `END`) :

```bash
sort -k3 -n .claude/run/timeline.log
```
```
dotnet-reviewer START 1751142601
test-runner     START 1751142603     ◄─ démarre alors que reviewer n'a pas fini
devops-engineer START 1751142604     ◄─ et le troisième aussi
test-runner     END   1751142690
devops-engineer END   1751142705
dotnet-reviewer END   1751142720
```

---

## Étape 9 — Vérification n°3 : le résultat est bon (ne pas croire l'IA sur parole)

```bash
# a) Qui a touché quoi ? (périmètres disjoints : code ↔ infra)
git diff --stat
#   → dotnet-reviewer : uniquement des fichiers src/**/*.cs
#   → devops-engineer : uniquement Dockerfile / .github/ / k8s / helm

# b) Le code compile et les tests passent (dont les 10 tests de caractérisation du seed)
export PATH="/usr/local/share/dotnet:$PATH"
dotnet build && dotnet test ECommerce.slnx --nologo
#   → les tests du seed restent VERTS après refactoring = correction « à comportement constant »

# c) Les blockers CodeScene ont disparu
cs check --output-format json        # ou inspecte que ProcessOrder/Search sont bien refactorés

# d) Le rapport de l'orchestrateur existe et décrit CHAQUE sous-agent
sed -n '1,40p' rapport-multi-agents.md
```

Le **rapport** `rapport-multi-agents.md` doit contenir une section par sous-agent (🟦 / 🟩 / 🟧)
avec preuves (fichier:ligne des blockers traités, sortie de tests, changements d'infra) et un
**verdict global**.

### Tester aussi les garde-fous (les hooks bloquent bien)
```text
# dotnet-reviewer qui modifie un Dockerfile → REFUSÉ par guard-src-only
> Utilise dotnet-reviewer pour ajouter une ligne à src/ECommerce.Web/Dockerfile.

# devops-engineer qui modifie un .cs → REFUSÉ par guard-infra-only
> Utilise devops-engineer pour éditer src/ECommerce.Catalog.Api/Program.cs.

# test-runner qui commit → REFUSÉ par validate-readonly
> Utilise test-runner pour faire git commit -am "x".
```
Chacune doit échouer avec le message du hook correspondant.

---

## 10. Dépannage

| Symptôme | Cause probable | Remède |
|---|---|---|
| Un agent n'apparaît pas dans `/agents` | `.md` chargé au démarrage de session | Relancer la session, ou créer via `/agents` |
| « Pas de parallélisme » (1 seule tâche) | Orchestrateur trop prudent / lancement en série | Réexiger : « émets les **3 appels Task dans un SEUL message** » puis re-vérifier (§8) |
| `verify-parallel.sh` → « Aucun chevauchement » | Agents lancés séquentiellement | Relancer la phase parallèle (prompt §6) |
| `Journal introuvable` | `timeline.log` non écrit | Vérifier la consigne d'instrumentation (echo START/END) du prompt/command |
| Le hook ne bloque rien | Script non exécutable / mauvais `exit` | `chmod +x .claude/scripts/*.sh` ; `exit 2` pour bloquer ; Windows → `shell: powershell` |
| `dotnet introuvable` | PATH | `export PATH="/usr/local/share/dotnet:$PATH"` |
| `dotnet test` ne voit pas le seed | projet non ajouté à la solution | `dotnet sln ECommerce.slnx add tests/ECommerce.SubAgents.Tests/ECommerce.SubAgents.Tests.csproj` |
| Build KO après copie du seed | fichiers liés absents (`src/`) | Copier **aussi** `seed/src/.` dans `src/` (le test lie ces fichiers) |
| Pas de blockers à corriger | ni CLI `cs`, ni `.codescene/blockers.json` | Fournir l'un des deux (§3) |
| Deux agents modifient le même fichier | Périmètres mal gardés | Vérifier que les hooks `guard-*` sont attachés et exécutables |

---

## 11. Critère de bon fonctionnement

Le système fonctionne quand, après le nettoyage (§1) et l'installation (§2), **une** exécution de
`/audit-fix-ship` donne :

1. les **trois** sous-agents **actifs en même temps** (panneau) ;
2. `verify-parallel.sh` ✅ (**chevauchement** prouvé, code `0`) ;
3. `git diff --stat` à **périmètres disjoints** (code ↔ infra) ;
4. `dotnet build && dotnet test` **verts**, **dont les 10 tests de caractérisation** (refactor « à
   comportement constant ») ;
5. les **blockers CodeScene** visés **disparus** (re-check) ;
6. `rapport-multi-agents.md` **généré** et décrivant **ce que chaque sous-agent a réalisé**, avec un
   verdict global.
