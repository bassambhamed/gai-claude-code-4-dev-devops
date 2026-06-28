# Multi-agents — un orchestrateur + deux spécialistes

Lab qui montre un **scénario multi-agents** sur l'`ecommerce-app` (.NET 10 / Aspire) : un agent
**chef d'orchestre** pilote une livraison en **déléguant** à deux sous-agents aux compétences
distinctes, puis **synthétise** le résultat.

> **L'idée clé.** Au lieu d'un seul agent qui fait tout (et qui mélange « écrire du code » et
> « juger ce code »), on **sépare les rôles**. Celui qui implémente n'est pas celui qui valide —
> exactement comme un dev et un relecteur. L'orchestrateur garde la vue d'ensemble et fait boucler
> les deux jusqu'à ce que la qualité passe.

---

## Les agents en 30 secondes

| Agent | Rôle | Compétence | Écrit ? | Outils |
|-------|------|-----------|---------|--------|
| 🎼 **`release-conductor`** | **Orchestrateur** : décompose, délègue, fait boucler, synthétise | Coordination | non | `Task, Read, Grep, Glob, TodoWrite` |
| 🔨 **`feature-builder`** | Sous-agent **développeur** : implémente le changement | Implémentation .NET | **oui** | `Read, Write, Edit, Bash, Grep, Glob, Skill` |
| 🔍 **`quality-gate`** | Sous-agent **qualité** : relit le diff + lance les tests | Revue + tests | non (lecture seule) | `Read, Grep, Glob, Bash` |

Le découpage des **outils** n'est pas cosmétique : `quality-gate` n'a **ni `Write` ni `Edit`**,
il lui est donc *matériellement impossible* de modifier le code qu'il juge. La séparation des
pouvoirs est garantie par le harnais, pas par la bonne volonté du modèle.

---

## Le flux d'orchestration

```
                          ┌───────────────────────┐
   Demande utilisateur ─► │  🎼 release-conductor  │  (cadre, planifie)
                          └───────────┬───────────┘
                                      │ 1. délègue l'implémentation
                                      ▼
                          ┌───────────────────────┐
                          │  🔨 feature-builder    │  → modifie le code, fait compiler
                          └───────────┬───────────┘
                                      │ rend la liste des fichiers modifiés
                                      ▼
                          ┌───────────────────────┐
                          │  🎼 release-conductor  │  2. délègue la validation
                          └───────────┬───────────┘
                                      ▼
                          ┌───────────────────────┐
                          │  🔍 quality-gate       │  → relit le diff, lance dotnet test
                          └───────────┬───────────┘
                                      │ verdict PASS / FAIL + findings
                                      ▼
                  FAIL ◄──── 🎼 release-conductor ────► PASS
                   │  (renvoie les findings              │
                   │   bloquants à feature-builder)      ▼
                   └────────── boucle (≤ 3 tours) ── 📋 synthèse finale
```

- **Implémentation et validation sont séparées** : aucun agent ne valide son propre travail.
- **La boucle** s'arrête dès que `quality-gate` rend `PASS`, ou après 3 tours (remontée à l'humain).
- L'orchestrateur **ne code pas et ne teste pas** lui-même : il route et synthétise.

---

## Ressources du lab

```
multi-agents/
├── README.md                       # ce fichier (présentation + architecture)
├── SCENARIO.md                     # ▶ scénario pas-à-pas + preuve du travail simultané
├── agents/
│   ├── release-conductor.md        # 🎼 orchestrateur (tools = Task, Read, Grep, Glob, TodoWrite)
│   ├── feature-builder.md          # 🔨 sous-agent développeur (peut écrire)
│   └── quality-gate.md             # 🔍 sous-agent qualité (lecture seule)
└── run/
    └── verify-parallel.sh          # vérifie via timeline.log que ≥ 2 agents ont tourné EN MÊME TEMPS
```

> **▶ Pour un scénario concret où les 3 agents fonctionnent, avec deux sous-agents qui
> travaillent EN MÊME TEMPS et comment le vérifier, voir [`SCENARIO.md`](SCENARIO.md).**

Chaque fichier `.md` est une **définition d'agent Claude Code** : un frontmatter
(`name`, `description`, `tools`) + un prompt système qui décrit le rôle, la méthode et les garde-fous.
La `description` est ce qui permet à l'orchestrateur (et à Claude) de **choisir le bon spécialiste**.

> Ce lab se combine avec le plugin **`ecommerce-ops`** (`labs/plugins/ecommerce-ops/`) :
> `feature-builder` peut appeler ses skills (`containerize`, `k8s-bootstrap`), et les hooks
> (`secret-scan`, `guard-destructive`) protègent **tous** les agents de la même façon.

---

## Étapes à suivre

### 1. Installer les agents
Copie les définitions là où Claude Code les charge — au niveau **projet** (partagé via git) :
```bash
mkdir -p .claude/agents
cp labs/multi-agents/agents/*.md .claude/agents/
```
> Variante **personnelle** (non partagée) : `~/.claude/agents/`.
> Variante **plugin** : déposer les `.md` dans le dossier `agents/` d'un plugin.

### 2. Vérifier qu'ils sont reconnus
Ouvre Claude Code à la racine du repo et lance :
```text
/agents      # release-conductor, feature-builder et quality-gate doivent apparaître
```

### 3. Lancer le scénario
Donne une tâche bornée à l'orchestrateur :
```text
> Utilise l'agent release-conductor pour ajouter un endpoint /health enrichi
  au service Catalog (statut + version), avec un test, et valide avant de conclure.
```
L'orchestrateur va :
1. **cadrer** l'objectif et les critères d'acceptation ;
2. **déléguer à `feature-builder`** l'écriture du endpoint + du test ;
3. **déléguer à `quality-gate`** la revue + `dotnet test` ;
4. **boucler** si le verdict est `FAIL` ;
5. **synthétiser** quand c'est `PASS`.

### 4. Observer la séparation des rôles
Pendant le déroulé, remarque que :
- seul **`feature-builder`** touche aux fichiers ;
- **`quality-gate`** ne fait que lire et tester (il *ne peut pas* écrire) ;
- l'**orchestrateur** ne fait qu'orchestrer et résumer.

### 5. Vérification manuelle (garder la main sur l'IA)
Ne fais pas confiance sur parole — contrôle le résultat toi-même :
```bash
git diff --stat                                   # quels fichiers ont vraiment changé ?
export PATH="/usr/local/share/dotnet:$PATH"
dotnet build && dotnet test                        # les tests passent-ils chez toi ?
```

---

## Pourquoi cette architecture (et pas un seul agent)

| Un seul agent | Orchestrateur + spécialistes |
|---------------|------------------------------|
| Mélange écrire et juger → angle mort sur ses propres erreurs | Le validateur est **indépendant** de l'auteur |
| Un seul gros prompt fourre-tout | Chaque agent a un **rôle net** et des **outils restreints** |
| Difficile de borner les droits | `quality-gate` **ne peut pas** écrire : garanti par le harnais |
| Contexte unique qui gonfle | Chaque sous-agent travaille dans **son propre contexte** |

C'est le principe du lab : **séparer les compétences**, **restreindre les outils par rôle**, et
laisser un **orchestrateur** faire boucler implémentation ↔ validation jusqu'à un résultat fiable.
