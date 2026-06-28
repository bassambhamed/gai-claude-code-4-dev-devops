# Scénario : les 3 agents en action + preuve du travail simultané

Objectif de ce scénario : faire **réellement** travailler les 3 agents sur l'`ecommerce-app`,
avec **au moins deux sous-agents qui tournent EN MÊME TEMPS**, et **vérifier** ce parallélisme
de deux façons (visuelle + preuve horodatée).

> **La tâche fil rouge.** Ajouter un endpoint **`GET /catalog/stats`** au service
> `ECommerce.Catalog.Api` qui renvoie `{ "count": <nb de produits>, "version": "<version>" }`,
> avec un test, et le **valider** avant de conclure.

---

## Comment le parallélisme se produit (à comprendre avant de lancer)

Deux sous-agents tournent **en même temps** uniquement si l'orchestrateur émet **deux appels
`Task` dans le MÊME message**. C'est le mécanisme de Claude Code : plusieurs tâches lancées dans
un seul tour s'exécutent **concurremment**.

```
        ┌──────────────────────── un seul message de l'orchestrateur ────────────────────────┐
        │                                                                                     │
        ▼                                                                                     ▼
┌───────────────────┐                                                       ┌───────────────────┐
│ 🔨 feature-builder │  implémente /catalog/stats        ║  EN MÊME TEMPS    │ 🔍 quality-gate    │  baseline : tests
│  (écrit le code)   │  + le test                        ║                   │  (lecture seule)   │  actuels + checklist
└─────────┬─────────┘                                                       └─────────┬─────────┘
          │  résumé des fichiers modifiés                                              │  baseline + risques
          └───────────────────────────────► 🎼 release-conductor ◄─────────────────────┘
                                              (convergence : revue + verdict, puis boucle si FAIL)
```

> ⚠️ **Important (limite de Claude Code).** Un sous-agent ne peut en général **pas** lancer
> lui-même d'autres sous-agents. Pour garantir le parallélisme **visible**, on pilote
> l'orchestration **depuis la session principale** en suivant le playbook `release-conductor`.
> La session principale joue le chef d'orchestre et lance les deux spécialistes en parallèle.

---

## Étapes à suivre

### Étape 1 — Installer les agents
```bash
mkdir -p .claude/agents
cp labs/multi-agents/agents/*.md .claude/agents/
```
Ouvre Claude Code **à la racine du repo** et vérifie qu'ils sont chargés :
```text
/agents      # doit lister : release-conductor, feature-builder, quality-gate
```

### Étape 2 — Préparer la zone de preuve
Le journal `timeline.log` est généré à l'exécution (il est ignoré par git) :
```bash
mkdir -p labs/multi-agents/run
rm -f labs/multi-agents/run/timeline.log     # repart d'un journal propre
```

### Étape 3 — Lancer le scénario (avec instrumentation parallèle)
Colle **ce prompt** dans la session principale. Il demande explicitement d'orchestrer, de
**lancer les deux sous-agents dans le même message**, et de les **horodater** :

```text
Joue le rôle de l'orchestrateur release-conductor pour cette tâche :
ajouter un endpoint GET /catalog/stats à ECommerce.Catalog.Api renvoyant
{ count, version }, avec un test, puis valider.

PHASE PARALLÈLE — dans UN SEUL message, lance EN MÊME TEMPS deux sous-agents :
  • feature-builder : implémente l'endpoint + le test ;
  • quality-gate   : établit la baseline (lance les tests actuels, liste les
                     critères d'acceptation et les zones à risque), en lecture seule.

Consigne d'instrumentation pour CHAQUE sous-agent :
  - Tout premier geste : exécute en Bash
      echo "<nom-agent> START $(date +%s)" >> labs/multi-agents/run/timeline.log
  - Tout dernier geste : exécute en Bash
      echo "<nom-agent> END $(date +%s)" >> labs/multi-agents/run/timeline.log
  (remplace <nom-agent> par feature-builder ou quality-gate).

Ensuite : convergence (quality-gate relit le diff + lance dotnet test), boucle si FAIL
(max 3 tours), puis rends une synthèse finale.
```

### Étape 4 — Visualiser le parallélisme (méthode 1, à l'œil)
Pendant l'exécution, dans l'interface Claude Code :
- **deux tâches d'agent apparaissent et tournent en même temps** (deux entrées actives avec
  spinner : `feature-builder` et `quality-gate`), au lieu d'une seule à la fois ;
- chacune affiche sa propre activité (outils appelés, sortie) en parallèle ;
- elles se terminent indépendamment, puis l'orchestrateur enchaîne sur la convergence.

> Si tu ne vois **qu'une** tâche active à la fois, l'orchestrateur les a lancées en séquence :
> redemande explicitement « lance les deux dans le même message » (voir étape 6).

### Étape 5 — Vérifier le parallélisme (méthode 2, preuve horodatée)
À la fin, lance le vérificateur :
```bash
bash labs/multi-agents/run/verify-parallel.sh
```
- ✅ **`CHEVAUCHEMENT … EN MÊME TEMPS pendant Ns`** → les intervalles `START..END` des deux
  agents se chevauchent : **preuve** qu'ils ont tourné simultanément (code de sortie `0`).
- ⚠️ **`Aucun chevauchement`** → ils se sont succédé (séquentiel, code `2`) : passe à l'étape 6.

Le journal brut est lisible directement :
```bash
sort -k3 -n labs/multi-agents/run/timeline.log
```
Tu dois voir les deux `START` **avant** le premier `END` — c'est la signature du parallélisme :
```
feature-builder START 1751142601
quality-gate    START 1751142603     ◄─ démarre alors que builder n'a pas fini
quality-gate    END   1751142690
feature-builder END   1751142720
```

### Étape 6 — Si c'était séquentiel, forcer le parallélisme
Relance en insistant :
```text
Recommence la phase parallèle : émets les DEUX appels Task (feature-builder et
quality-gate) dans un SEUL et même message, pas l'un après l'autre.
```
Puis re-vérifie (étape 5).

### Étape 7 — Observer la collaboration et la convergence
Une fois la phase parallèle finie, l'orchestrateur :
1. transmet le **diff** de `feature-builder` **et** la **checklist** de `quality-gate` ;
2. fait relire/tester par `quality-gate` → **verdict `PASS`/`FAIL`** ;
3. **boucle** si `FAIL` (renvoie les findings à `feature-builder`), max 3 tours ;
4. rend une **synthèse** finale.
C'est là que la **collaboration** est visible : la checklist produite en parallèle sert à juger
le code, et les findings repartent vers le développeur.

### Étape 8 — Contrôle manuel du résultat (ne pas croire l'IA sur parole)
```bash
git diff --stat                                    # quels fichiers ont vraiment changé ?
export PATH="/usr/local/share/dotnet:$PATH"
dotnet build && dotnet test                         # les tests passent-ils chez toi ?
# si l'app tourne :
curl -s http://localhost:<port>/catalog/stats       # le endpoint répond-il { count, version } ?
```

---

## Récapitulatif : qui fait quoi, et la preuve

| Quand | Agent(s) actif(s) | Mode | Comment le voir |
|-------|-------------------|------|-----------------|
| Étape 3, phase parallèle | 🔨 `feature-builder` **+** 🔍 `quality-gate` | **simultané** | 2 tâches actives (UI) + chevauchement dans `timeline.log` |
| Convergence (étape 7) | 🔍 `quality-gate` puis boucle vers 🔨 | séquentiel | verdict `PASS`/`FAIL` + findings |
| De bout en bout | 🎼 `release-conductor` | coordination | annonce chaque délégation + synthèse finale |

> **Ce que prouve `verify-parallel.sh` :** que deux sous-agents avaient leurs intervalles
> d'exécution **superposés dans le temps** — la définition même de « travailler en même temps ».
