# Plugin `ecommerce-ops` — présentation & scénario d'utilisation

Plugin Claude Code qui empaquette le **chemin vers la prod** de l'`ecommerce-app`
(.NET 10 / Aspire) : conteneuriser → déployer sur Kubernetes (k3d) → diagnostiquer,
le tout avec des **garde-fous déterministes**.

> Pourquoi un plugin ? Plutôt que d'éparpiller des skills, hooks et commandes dans
> `.claude/`, on les **distribue d'un bloc** : un coéquipier l'installe en deux commandes
> et obtient exactement les mêmes capacités et garde-fous.

---

## Ce que contient le plugin

```
plugins/ecommerce-ops/
├── .claude-plugin/plugin.json     # manifeste (nom, version, auteur)
├── skills/                        # capacités déclenchées au besoin par Claude
│   ├── containerize/SKILL.md      #   Dockerfiles multi-étapes + scan Trivy
│   ├── k8s-bootstrap/SKILL.md     #   cluster k3d + déploiement des manifests
│   └── k8s-debug-pod/SKILL.md     #   diagnostic d'un pod en échec
├── commands/                      # slash-commands explicites
│   ├── ship.md                    #   /ship  → conteneuriser puis déployer
│   └── ops-doctor.md              #   /ops-doctor → check santé (lecture seule)
├── agents/
│   └── ops-engineer.md            # sous-agent Ops (read-only par défaut)
└── hooks/
    ├── hooks.json                 # câblage des hooks
    ├── secret-scan.sh             # PreToolUse(Bash) : bloque un commit avec secret
    ├── guard-destructive.sh       # PreToolUse(Bash) : confirmation sur commande destructive
    └── session-start.sh           # SessionStart : rappel d'environnement
```

| Type | Élément | Déclenchement |
|------|---------|---------------|
| Skill | `containerize`, `k8s-bootstrap`, `k8s-debug-pod` | **automatique** (Claude juge la pertinence selon la description) |
| Command | `/ship`, `/ops-doctor` | **explicite** (tapé par l'utilisateur) |
| Agent | `ops-engineer` | délégation d'une investigation Ops |
| Hook | `secret-scan`, `guard-destructive`, `session-start` | **déterministe** (le harnais l'exécute, pas l'IA) |

---

## Prérequis par OS

Claude Code et les commandes `/plugin` sont **identiques sur les trois OS**. Ce qui change,
ce sont les outils Ops sous-jacents et — sur Windows — le shell qui exécute les hooks
(des scripts `bash`).

### 🍎 macOS
```bash
# Claude Code
npm install -g @anthropic-ai/claude-code      # ou: brew install claude-code
# Outils Ops
brew install git docker k3d kubectl trivy
brew install --cask dotnet-sdk                 # .NET 10
# bash est déjà présent → les hooks .sh tournent nativement
```

### 🐧 Linux (Debian/Ubuntu)
```bash
# Claude Code
npm install -g @anthropic-ai/claude-code
# Outils Ops
sudo apt update && sudo apt install -y git bash curl
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
sudo snap install kubectl --classic
sudo apt install -y trivy docker.io dotnet-sdk-10.0
# bash natif → hooks .sh OK
```

### 🪟 Windows
```powershell
# Claude Code (PowerShell)
npm install -g @anthropic-ai/claude-code
# Outils Ops via winget
winget install Git.Git Docker.DockerDesktop Kubernetes.kubectl AquaSecurity.Trivy Microsoft.DotNet.SDK.10
choco install k3d            # (k3d : Chocolatey ou binaire GitHub)
```
> ⚠️ **Hooks sur Windows.** Les hooks du plugin sont des scripts `bash` (`.sh`). Claude Code
> les exécute via le **shell par défaut** : installe **Git for Windows** (fournit `bash`) ou
> active **WSL2**, et lance Claude Code depuis Git Bash / WSL pour que `secret-scan`,
> `guard-destructive` et `session-start` fonctionnent. En CMD/PowerShell pur, les `.sh` ne
> s'exécutent pas.

**Vérifier les prérequis** (sur tous les OS) :
```bash
git --version && docker --version && k3d version && kubectl version --client && trivy --version && dotnet --version
```

---

## Installation du plugin (marketplace local — identique Win/Linux/Mac)

Le repo expose un marketplace local (`.claude-plugin/marketplace.json` à la racine).
Ouvre Claude Code **à la racine du repo**, puis dans le prompt :

```text
/plugin marketplace add .
/plugin install ecommerce-ops@ecommerce-ops-marketplace
```

**Vérifier l'installation :**
```text
/plugin     # ecommerce-ops apparaît "enabled"
/help       # /ship et /ops-doctor sont listés
```
Redémarre la session si demandé (les hooks et le `SessionStart` se chargent au démarrage).

> Pour distribuer largement, pousse ce repo sur GitHub et remplace `.` par
> `owner/ecommerce-app` dans `/plugin marketplace add` — l'installation devient
> identique pour toute l'équipe, quel que soit l'OS.

---

## Utilisation au quotidien

| Je veux… | Je tape… | Ce qui se passe |
|----------|----------|-----------------|
| Un check santé de l'environnement | `/ops-doctor` | Inventaire outils + cluster + pods, en lecture seule |
| Conteneuriser + déployer un service | `/ship catalog` | `containerize` → import k3d → `kubectl apply` → `/health` |
| Tout déployer | `/ship` | Idem pour les 4 services |
| Diagnostiquer un pod qui plante | « utilise l'agent **ops-engineer** pour le pod ordering » | Investigation read-only + correctif proposé |
| (rien) conteneuriser à la demande | « écris-moi un Dockerfile pour gateway » | Le skill **containerize** se déclenche tout seul |

- Les **commands** (`/ship`, `/ops-doctor`) sont explicites : tu les tapes.
- Les **skills** (`containerize`, `k8s-bootstrap`, `k8s-debug-pod`) se déclenchent **automatiquement**
  quand Claude juge la demande pertinente — pas besoin de les invoquer.
- Les **hooks** tournent en arrière-plan à chaque commande Bash / au démarrage de session.

---

## Scénario d'utilisation de bout en bout

**Contexte** — Bob, nouvel arrivant dans l'équipe, doit déployer le service `catalog`
sur un cluster local et le voir tourner.

### 0. Démarrage de session — le hook `session-start`
Dès l'ouverture, le hook `SessionStart` injecte le rappel : SDK .NET 10 à exporter,
commande de lancement, skills dispo, garde-fous actifs. Bob n'a rien à mémoriser.

### 1. `/ops-doctor` — état des lieux
```
> /ops-doctor
```
Claude inspecte (en lecture seule) docker, k3d, kubectl, trivy, dotnet, l'état du cluster
et des pods, puis rend un tableau ✅/⚠️/❌. Verdict : outils OK, **aucun cluster** → action
recommandée : `/ship`.

### 2. `/ship catalog` — conteneuriser puis déployer
```
> /ship catalog
```
La command orchestre les skills :
1. `containerize` génère le `Dockerfile` (multi-étapes, runtime chiselé, non-root),
   build l'image `ecommerce/catalog:dev` et la **scanne** (Trivy HIGH/CRITICAL) ;
2. `k8s-bootstrap` crée le cluster k3d (il n'existait pas), importe l'image, applique `k8s/` ;
3. vérification du rollout + `curl /health`.

### 3. Le garde-fou `guard-destructive` entre en jeu
Bob veut repartir de zéro et tape une commande de nettoyage :
```
> supprime le cluster et recommence    →  k3d cluster delete ...
```
Le hook `PreToolUse` intercepte, renvoie une décision **`ask`** et Claude **demande
confirmation** avant de détruire quoi que ce soit. Bob valide en connaissance de cause.

### 4. Un pod plante → le sous-agent `ops-engineer` + skill `k8s-debug-pod`
Le pod `ordering` est en `CrashLoopBackOff`. Bob délègue :
```
> Utilise l'agent ops-engineer pour trouver pourquoi le pod ordering crashe.
```
L'agent travaille **en lecture seule** (`describe`, `logs --previous`, `events`), via le skill
`k8s-debug-pod`, formule une hypothèse (ex. `limits.memory` trop bas → OOMKilled) et
**propose** un correctif — qu'il n'applique qu'après l'accord de Bob.

### 5. Commit protégé — le garde-fou `secret-scan`
Bob corrige le manifest et commit. Par mégarde il a collé un token :
```
> commit ce changement     →  git commit -m "fix ordering limits"
```
Le hook `secret-scan` détecte le motif dans l'index, **bloque le commit** (exit 2) et indique
la ligne fautive. Bob retire le secret (variable d'env), recommit → ça passe.

---

## Le point clé : skills vs hooks

- **Skills / commands / agent** = capacités que **l'IA mobilise** quand c'est pertinent.
  Souples, contextuels, mais c'est le modèle qui décide.
- **Hooks** = règles que **le harnais applique** systématiquement, quel que soit le « jugement »
  du modèle. C'est ce qui rend un garde-fou *fiable* : `secret-scan` bloquera **toujours** un
  commit avec secret, `guard-destructive` demandera **toujours** confirmation avant un `delete`.

Le plugin combine les deux : la productivité des skills, la fiabilité des hooks.
