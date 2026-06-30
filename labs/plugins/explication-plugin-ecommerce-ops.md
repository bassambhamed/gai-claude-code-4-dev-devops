# Explication : Qu'est-ce qu'un Plugin Claude Code et comment fonctionne `ecommerce-ops` ?

---

## 1. Qu'est-ce qu'un Plugin Claude Code ?

Un **plugin Claude Code** est un **paquet réutilisable** qui regroupe en un seul bloc :
- des **skills** (capacités automatiques de Claude),
- des **commands** (commandes slash tapées par l'utilisateur),
- des **agents** (sous-agents spécialisés),
- des **hooks** (garde-fous déterministes exécutés par le harnais).

### Pourquoi un plugin plutôt qu'un simple `.claude/` ?

Sans plugin, chaque développeur doit configurer manuellement ses propres skills, hooks et commandes dans son dossier `.claude/`. Avec un plugin :

| Sans plugin | Avec plugin |
|-------------|-------------|
| Chaque dev configure manuellement | Installation en 2 commandes |
| Risque d'oubli ou d'écart de config | Tout le monde a exactement les mêmes capacités ET garde-fous |
| Difficile à distribuer à une équipe | Distribuable via un marketplace (local ou GitHub) |

> **Résumé** : un plugin = un dossier versionné et installable qui donne à toute l'équipe les mêmes outils intelligents (skills/commands/agents) et les mêmes filets de sécurité (hooks).

---

## 2. Le plugin `ecommerce-ops` — Vue d'ensemble

`ecommerce-ops` est le plugin Ops de l'application `ecommerce-app` (.NET 10 / Aspire).  
Il couvre le **chemin vers la prod** : **conteneuriser → déployer sur Kubernetes → diagnostiquer**.

### Structure des fichiers

```
plugins/ecommerce-ops/
├── .claude-plugin/plugin.json        ← manifeste (nom, version, auteur)
├── skills/
│   ├── containerize/SKILL.md         ← Dockerfiles multi-étapes + scan Trivy
│   ├── k8s-bootstrap/SKILL.md        ← cluster k3d + déploiement des manifests
│   └── k8s-debug-pod/SKILL.md        ← diagnostic d'un pod en échec
├── commands/
│   ├── ship.md                       ← /ship  → conteneuriser + déployer
│   └── ops-doctor.md                 ← /ops-doctor → check santé (lecture seule)
├── agents/
│   └── ops-engineer.md               ← sous-agent Ops (read-only par défaut)
└── hooks/
    ├── hooks.json                    ← câblage des hooks
    ├── secret-scan.sh                ← bloque un commit avec secret
    ├── guard-destructive.sh          ← confirmation avant commande destructive
    └── session-start.sh              ← rappel d'environnement au démarrage
```

### Tableau de déclenchement

| Type | Élément | Qui déclenche |
|------|---------|---------------|
| **Skill** | `containerize`, `k8s-bootstrap`, `k8s-debug-pod` | Claude automatiquement, selon la pertinence |
| **Command** | `/ship`, `/ops-doctor` | L'utilisateur (tapé explicitement) |
| **Agent** | `ops-engineer` | L'utilisateur par délégation |
| **Hook** | `secret-scan`, `guard-destructive`, `session-start` | Le harnais (toujours, sans intervention de l'IA) |

---

## 3. Le manifeste — `plugin.json`

```json
{
  "name": "ecommerce-ops",
  "version": "0.1.0",
  "description": "Boîte à outils Ops pour l'ecommerce-app ...",
  "author": { "name": "Bassem Ben Hamed", "email": "..." },
  "keywords": ["ops", "devops", "kubernetes", "docker", "dotnet", "aspire"],
  "license": "MIT"
}
```

C'est la **carte d'identité** du plugin. Claude Code s'en sert pour identifier et installer le plugin via le marketplace.

---

## 4. Les Hooks — Les garde-fous déterministes

Les hooks sont la partie la plus importante du plugin : ce ne sont **pas des suggestions à l'IA**, mais des **règles imposées par le harnais**. Qu'importe ce que Claude "décide", les hooks s'exécutent toujours.

### Câblage — `hooks.json`

```json
{
  "hooks": {
    "PreToolUse": [                          ← avant chaque commande Bash
      {
        "matcher": "Bash",
        "hooks": [
          { "command": "secret-scan.sh" },   ← vérifie les secrets
          { "command": "guard-destructive.sh" } ← vérifie si la commande est dangereuse
        ]
      }
    ],
    "SessionStart": [                        ← au démarrage de la session
      { "hooks": [{ "command": "session-start.sh" }] }
    ]
  }
}
```

---

### Hook 1 — `session-start.sh` (événement : `SessionStart`)

**Quand ?** Dès l'ouverture d'une session Claude Code.

**Ce qu'il fait :** Injecte un rappel d'environnement dans le contexte de Claude.

```bash
# Ce que Claude reçoit au démarrage :
[ecommerce-ops] Rappels environnement :
- SDK .NET 10 pas sur le PATH par défaut : export PATH="/usr/local/share/dotnet:$PATH"
- Lancer tout le système : dotnet run --project src/ECommerce.AppHost
- Skills Ops dispo : containerize, k8s-bootstrap, k8s-debug-pod
- Garde-fous actifs : secret-scan, guard-destructive
```

**Pourquoi ?** Le développeur n'a rien à mémoriser. Claude sait dès le début comment est configuré l'environnement.

---

### Hook 2 — `secret-scan.sh` (événement : `PreToolUse(Bash)`)

**Quand ?** Avant chaque exécution d'un `git commit`.

**Ce qu'il fait :** Scanne `git diff --cached` pour détecter des motifs de secrets :
- `password`, `passwd`, `secret`
- `api_key`, `token`
- `BEGIN RSA PRIVATE KEY`, `BEGIN OPENSSH PRIVATE KEY`
- `connectionstring`, `aws_secret_access_key`

**Si un secret est trouvé :** exit code `2` → le commit est **bloqué**. Claude affiche les lignes suspectes.

```bash
# Exemple de sortie :
⛔ COMMIT BLOQUÉ par le hook secret-scan : un secret potentiel a été détecté.
Lignes suspectes :
+  "password": "my-super-secret"
Retire le secret (coffre / variable d'environnement) puis recommence.
```

**Point clé :** C'est le harnais qui bloque, **pas Claude**. Même si Claude voulait committer, il ne peut pas.

---

### Hook 3 — `guard-destructive.sh` (événement : `PreToolUse(Bash)`)

**Quand ?** Avant chaque commande Bash qui ressemble à une opération irréversible.

**Commandes détectées :**
```
k3d cluster delete | kubectl delete ns | kubectl delete -f
terraform destroy  | docker system prune | docker volume rm
rm -rf             | multipass delete
```

**Ce qu'il fait :** Au lieu de bloquer sèchement, il retourne `permissionDecision: "ask"` → Claude **demande une confirmation à l'utilisateur** avant d'exécuter.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Commande destructive détectée..."
  }
}
```

**Différence avec `secret-scan` :**
- `secret-scan` → bloque (`exit 2`), l'utilisateur doit corriger.
- `guard-destructive` → pause (`ask`), l'utilisateur valide ou non.

---

## 5. Les Skills — Capacités automatiques

Les skills sont des instructions que Claude charge **automatiquement** quand il juge que la demande correspond à la description du skill. L'utilisateur n'a pas besoin de les invoquer.

### Skill 1 — `containerize`

**Description :** Génère des Dockerfiles multi-étapes, build l'image, la scanne avec Trivy.

**Étapes internes :**
1. Identifier le service cible (`.csproj` + dépendances)
2. Générer un `Dockerfile` multi-étapes :
   - Étape `sdk` : build + publish
   - Étape `runtime` : image chiselée non-root (port 8080)
3. Construire : `docker build -t ecommerce/<service>:dev -f src/<Service>/Dockerfile .`
4. Scanner : `trivy image --severity HIGH,CRITICAL ecommerce/<service>:dev`
5. Générer/mettre à jour `docker-compose.yml` pour le dev

**Garde-fous intégrés :**
- Jamais de secret dans un Dockerfile
- Image finale = runtime only, jamais le SDK
- Confirmation avant `docker rmi`, `docker system prune`

**Exemple de déclenchement automatique :**
> "Écris-moi un Dockerfile pour le service gateway"
> → Claude charge et applique le skill `containerize` sans que tu le demandes.

---

### Skill 2 — `k8s-bootstrap`

**Description :** Crée un cluster Kubernetes local avec k3d et déploie les manifests.

**Étapes internes :**
1. `k3d cluster create --config k8s/k3d-cluster.yaml`
2. Vérifier : `kubectl cluster-info` + `kubectl get nodes`
3. Importer les images : `k3d image import ecommerce/<service>:dev -c <cluster>`
4. Appliquer : `kubectl apply -f k8s/`
5. Vérifier le rollout : `kubectl -n ecommerce rollout status deploy/<service>`
6. Tester : `curl` l'ingress + endpoint `/health`

**Garde-fous intégrés :**
- Afficher chaque commande AVANT de l'exécuter
- Confirmation avant `k3d cluster delete`, `kubectl delete ns`
- Probes `readiness`/`liveness` sur chaque service
- Jamais de secret en clair dans un manifest

---

### Skill 3 — `k8s-debug-pod`

**Description :** Diagnostique un pod en échec (CrashLoopBackOff, OOMKilled, etc.).

**Étapes internes :**
1. `kubectl -n <ns> get pods -o wide` → repérer le statut
2. `kubectl -n <ns> describe pod <pod>` → events, probes, ressources
3. `kubectl -n <ns> logs <pod> --previous` → logs du conteneur crashé
4. `kubectl -n <ns> get events --sort-by=.lastTimestamp`
5. Formuler 1-3 hypothèses de cause racine avec preuves
6. Proposer un correctif (manifest, ressources, image, probe) — appliqué seulement après validation

**Garde-fous intégrés :**
- Lecture seule par défaut (get/describe/logs)
- Toute modification passe par validation humaine
- Ne jamais exposer de secret dans les logs

---

## 6. Les Commands — Slash-commands explicites

Les commands sont tapées par l'utilisateur. Elles **orchestrent plusieurs skills** dans un ordre défini.

### Command `/ship [service]`

**Usage :** `/ship catalog` ou `/ship` (les 4 services)

**Ce qu'elle orchestre :**

```
┌──────────────────────────────────────────────────────────┐
│  /ship catalog                                           │
│                                                          │
│  1. containerize  → Dockerfile + build + scan Trivy      │
│  2. k8s-bootstrap → créer cluster k3d si absent          │
│  3. k3d image import ecommerce/catalog:dev -c <cluster>  │
│  4. kubectl apply -f k8s/                                │
│  5. kubectl -n ecommerce rollout status deploy/catalog   │
│  6. curl /health                → si KO → k8s-debug-pod  │
└──────────────────────────────────────────────────────────┘
```

**Comportement :** s'arrête à la moindre erreur. Montre chaque commande avant de l'exécuter. Aucune commande destructive sans confirmation (le hook `guard-destructive` l'imposera de toute façon).

---

### Command `/ops-doctor`

**Usage :** `/ops-doctor`

**Ce qu'elle fait :** Un état des lieux **strictement en lecture seule**, rendu sous forme de tableau :

```
✅ docker 24.0.5
✅ k3d v5.6.0
✅ kubectl v1.28
⚠️ trivy 0.45 (version ancienne)
❌ dotnet → introuvable (penser à exporter le PATH)

Cluster : ❌ aucun cluster k3d trouvé
→ Action recommandée : /ship
```

**Les 4 vérifications :**
1. **Outils** — versions de `docker`, `k3d`, `kubectl`, `trivy`, `dotnet`
2. **Cluster** — `kubectl cluster-info`, `kubectl get nodes`
3. **App** — `kubectl -n ecommerce get pods,svc,ingress,hpa`
4. **Santé** — `curl /health` via l'ingress

**N'applique aucune modification.**

---

## 7. L'Agent `ops-engineer`

Un **sous-agent** est une instance de Claude qui tourne dans son propre contexte, avec un jeu d'outils restreint. On le délègue pour ne pas polluer la session principale.

**Invocation :**
> "Utilise l'agent ops-engineer pour trouver pourquoi le pod ordering crashe."

**Outils autorisés :** `Bash`, `Read`, `Grep`, `Glob`, `Skill` (accès aux 3 skills du plugin)

**Principes de l'agent :**
- Diagnostique avant d'agir (toujours commencer en lecture seule)
- Montre les commandes avant de les lancer
- Jamais de destructif sans validation humaine
- Jamais de secret en clair

**Livrable :** constat → hypothèses classées → correctif proposé, appliqué seulement après accord.

**Quand l'utiliser :** pour investiguer un incident infra ou préparer un déploiement, en isolant le travail de la session principale.

---

## 8. Installation du plugin

### Prérequis (vérification)

```bash
git --version && docker --version && k3d version && kubectl version --client && trivy --version && dotnet --version
```

### Installation via le marketplace local

```bash
# Dans Claude Code, à la racine du repo :
/plugin marketplace add .
/plugin install ecommerce-ops@ecommerce-ops-marketplace

# Vérifier :
/plugin       # ecommerce-ops apparaît "enabled"
/help         # /ship et /ops-doctor sont listés
```

Redémarre la session → les hooks et le `session-start` se chargent.

---

## 9. Scénario complet — De zéro à déployé

```
┌──────────────────┐   ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ 0. Démarrage     │ → │ 1. /ops-     │ → │ 2. /ship catalog │ → │ 3. Pod plante     │
│ session-start    │   │    doctor    │   │  (build+déploie) │   │  → ops-engineer   │
│ injecte contexte │   │ (lecture)    │   │                  │   │  + k8s-debug-pod  │
└──────────────────┘   └──────────────┘   └──────────────────┘   └──────────────────┘
              garde-fous actifs en continu : secret-scan + guard-destructive
```

**Étape 0 — Démarrage :** le hook `session-start` injecte le rappel d'environnement (.NET PATH, skills dispo, garde-fous actifs).

**Étape 1 — `/ops-doctor` :** Claude inspecte en lecture seule et produit un tableau ✅/⚠️/❌. Verdict : cluster absent → recommandation : `/ship`.

**Étape 2 — `/ship catalog` :** `containerize` → build + scan Trivy → `k8s-bootstrap` crée le cluster → import image → `kubectl apply` → vérif `/health`.

**Étape 3 — Pod en CrashLoopBackOff :** délégation à l'agent `ops-engineer` qui utilise `k8s-debug-pod` → hypothèse : `limits.memory` trop bas (OOMKilled) → correctif proposé → appliqué après accord.

**Étape 4 — Commit avec secret (par mégarde) :** `secret-scan` détecte le token, **bloque le commit** (exit 2), affiche la ligne fautive. Le dev corrige, recommit → passe.

**Étape 5 — Nettoyage :** `k3d cluster delete ...` → `guard-destructive` renvoie `ask` → Claude demande confirmation → le dev valide en connaissance de cause.

---

## 10. Le point clé : Skills vs Hooks

| | Skills / Commands / Agent | Hooks |
|---|---|---|
| **Qui décide** | L'IA (Claude) | Le harnais (système) |
| **Fiabilité** | Contextuelle — Claude peut se tromper | Déterministe — s'exécute TOUJOURS |
| **Flexibilité** | Haute — adapté au contexte | Faible — règle stricte |
| **Exemple** | Claude choisit d'utiliser `containerize` | `secret-scan` bloque TOUJOURS un commit avec secret |

> Le plugin combine les deux : la **productivité** des skills (IA flexible et contextuelle) avec la **fiabilité** des hooks (règles imposées par le système, indépendamment du modèle).

---

## Résumé en une phrase

Le plugin `ecommerce-ops` est une boîte à outils Ops **packagée et distribuable** qui donne à toute l'équipe les mêmes capacités (skills `containerize`/`k8s-bootstrap`/`k8s-debug-pod`, commands `/ship`/`ops-doctor`, agent `ops-engineer`) et les mêmes garde-fous déterministes (hooks `secret-scan`, `guard-destructive`, `session-start`), installables en deux commandes.
