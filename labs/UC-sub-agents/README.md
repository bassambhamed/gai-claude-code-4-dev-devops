# UC-sub-agents — corrigé prêt à l'emploi (système multi-agents)

Ce dossier contient **tout le nécessaire**, autonome et prêt à copier, pour faire tourner le système
multi-agents sur `ecommerce-app-dev` : l'**orchestrateur** (command), les **3 sous-agents**, leurs
**skills**, les **hooks** (scripts), un **vérificateur** de parallélisme, une commande de
**nettoyage** (`/reset-lab`) et un **cas blocker concret** (`seed/`).

> Tout est **indépendant** des skills/hooks déjà présents ailleurs (UCx, plugin `ecommerce-ops`,
> lab `multi-agents`) : ce dossier embarque ses **propres** copies. On peut le copier tel quel.

Explications complètes :
[`../sub-agents/systeme-multi-agents-ecommerce-app-dev.md`](../sub-agents/systeme-multi-agents-ecommerce-app-dev.md)
(architecture/rôles) et
[`../sub-agents/mise-en-place-et-verification.md`](../sub-agents/mise-en-place-et-verification.md)
(marche à suivre + dépannage).

---

## Contenu

```
UC-sub-agents/
├─ .codescene/
│  └─ blockers.json                       # exemple de blockers CodeScene (à adapter / ou CLI `cs`)
├─ seed/                                  # cas blocker CONCRET + tests de caractérisation
│  ├─ src/
│  │  ├─ ECommerce.Ordering.Api/Services/OrderProcessor.cs   # CH-001 Complex Method
│  │  └─ ECommerce.Catalog.Api/Services/ProductQuery.cs      # CH-002 Many Function Arguments
│  └─ tests/
│     └─ ECommerce.SubAgents.Tests/                          # xUnit (10 tests) : fige le comportement
└─ .claude/
   ├─ commands/
   │  ├─ audit-fix-ship.md                # 🎼 orchestrateur (session principale, opus)
   │  └─ reset-lab.md                     # 🧹 nettoyage « table rase » contrôlé
   ├─ agents/
   │  ├─ dotnet-reviewer.md               # 🟦 corrige les blockers CodeScene (src/**.cs)
   │  ├─ test-runner.md                   # 🟩 dotnet test, lecture seule
   │  └─ devops-engineer.md               # 🟧 crée/fiabilise Dockerfile · CI · k8s · Helm
   ├─ skills/
   │  ├─ codescene-blockers/SKILL.md      # préchargée dans dotnet-reviewer
   │  ├─ csharp-refactoring/SKILL.md      # préchargée dans dotnet-reviewer
   │  ├─ dotnet-test-runner/SKILL.md      # préchargée dans test-runner
   │  └─ docker-ci-review/SKILL.md        # préchargée dans devops-engineer
   ├─ scripts/
   │  ├─ guard-src-only.sh                # hook : dotnet-reviewer n'écrit que du .cs
   │  ├─ guard-infra-only.sh              # hook : devops-engineer n'écrit pas de .cs
   │  ├─ validate-readonly.sh             # hook : test-runner ne mute rien
   │  └─ reset-lab.sh                     # nettoyage sûr (dry-run par défaut, --yes pour exécuter)
   └─ run/
      └─ verify-parallel.sh               # preuve du travail simultané (timeline.log généré au runtime)
```

| Agent | Rôle | Écrit ? | Périmètre | Modèle |
|---|---|---|---|---|
| 🎼 orchestrateur (`/audit-fix-ship`) | délègue en parallèle, synthétise, **écrit le rapport** | rapport `.md` | `rapport-multi-agents.md` | opus |
| 🟦 `dotnet-reviewer` | corrige les **blockers CodeScene** | oui | `src/**/*.cs` | sonnet |
| 🟩 `test-runner` | `dotnet test`, n'affiche que les échecs | non | — | haiku |
| 🟧 `devops-engineer` | **crée** (table rase) ou fiabilise l'infra | oui | Dockerfile, `.github/`, `k8s/`, `helm/` | sonnet |

---

## Installation & démarrage sur table rase (ordre recommandé)

Tout se passe dans la copie de travail `ecommerce-app/` (adapter le chemin `../labs/...`).

```bash
cd ecommerce-app
git switch -c demo/multi-agents       # (recommandé) branche dédiée : main reste intacte, démo réversible

# 1) Installer le système d'agents (+ exemple de blockers)
cp -r ../labs/UC-sub-agents/.claude .
cp -r ../labs/UC-sub-agents/.codescene .
chmod +x .claude/scripts/*.sh .claude/run/verify-parallel.sh
```

```text
# 2) (re)lancer Claude Code à la racine, puis NETTOYER (table rase) :
/reset-lab          # montre un APERÇU (dry-run) → tu confirmes → suppression
```
`/reset-lab` supprime les **skills/hooks hérités** des UC précédents, les **Dockerfiles**, les
**images/conteneurs Docker** et le **cluster/namespaces k8s** « ecommerce|lab » — en **préservant**
le code (`src/**/*.cs`), les tests, la solution **et le système multi-agents lui-même**. Il **ne
touche jamais `labs/`**.

```bash
# 3) (recommandé) Cas blocker CONCRET + tests de caractérisation (preuve « refactor sûr ») :
cp -r ../labs/UC-sub-agents/seed/src/.   src/      # OrderProcessor.cs + ProductQuery.cs (ciblés par blockers.json)
cp -r ../labs/UC-sub-agents/seed/tests/. tests/    # projet xUnit qui FIGE leur comportement
export PATH="/usr/local/share/dotnet:$PATH"
dotnet sln ECommerce.slnx add tests/ECommerce.SubAgents.Tests/ECommerce.SubAgents.Tests.csproj
```
> Le projet de test **lie** (`<Compile Include="../../src/...">`) les fichiers seed : il reste **vert
> avant ET après** le refactoring de `dotnet-reviewer` → preuve que la correction est **à comportement
> constant**. Bonus : `test-runner` a toujours du vert à exécuter, même si la démo passe avant UC3.

```text
# 4) Vérifier le chargement, puis lancer l'orchestration :
/agents                         # dotnet-reviewer, test-runner, devops-engineer, + commandes
/audit-fix-ship feature/ma-branche
```

L'orchestrateur lance les **trois** sous-agents **dans un seul message** (donc en parallèle) :
`dotnet-reviewer` corrige le blocker, `devops-engineer` **(re)crée** l'infra (table rase) et
`test-runner` teste. Il converge (re-test) puis écrit **`rapport-multi-agents.md`**.

> Sur table rase, `devops-engineer` **crée** les Dockerfiles/CI/manifests s'ils manquent (sinon il
> revoit/améliore l'existant). Le hook `guard-infra-only` l'autorise à créer de l'infra mais lui
> interdit de toucher au `.cs`.

---

## Vérifier le bon fonctionnement

```bash
# preuve de simultanéité (intervalles START..END qui se chevauchent)
bash .claude/run/verify-parallel.sh

# contrôle manuel
git diff --stat                                  # périmètres disjoints : code ↔ infra
export PATH="/usr/local/share/dotnet:$PATH"
dotnet build && dotnet test ECommerce.slnx --nologo   # inclut les 10 tests de caractérisation du seed
sed -n '1,40p' rapport-multi-agents.md           # le rapport décrit chaque sous-agent
```

Détails et dépannage :
[`../sub-agents/mise-en-place-et-verification.md`](../sub-agents/mise-en-place-et-verification.md).

## Notes & prérequis

- **Ordre important** : installe le système **avant** de lancer `/reset-lab` (le reset **préserve**
  le système ; il ne se supprime pas lui-même). Ne lance jamais le nettoyage dans `labs/`.
- **`reset-lab.sh`** est **dry-run par défaut** ; il n'agit qu'avec `--yes`. Docker/k8s sont **ciblés**
  sur `ecommerce|lab` (pas de `prune` global).
- Si le plugin `ecommerce-ops` est actif, son hook `guard-destructive` demandera confirmation sur
  certaines commandes destructives — c'est voulu (sécurité).
- **Prérequis** : Claude Code (récent) · .NET 10 SDK · Git · `jq` (hooks, Linux/macOS/WSL) ·
  CodeScene CLI `cs` *(optionnel — sinon `.codescene/blockers.json`)*. Sous Windows pur : réécrire
  les hooks `.sh` en PowerShell et ajouter `shell: powershell` à l'entrée du hook.
