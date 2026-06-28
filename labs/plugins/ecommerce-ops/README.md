# ecommerce-ops — plugin Claude Code

Plugin qui empaquette le **chemin vers la prod** de l'`ecommerce-app` (.NET 10 / Aspire) :
**conteneuriser → déployer sur Kubernetes (k3d) → diagnostiquer**, avec des **garde-fous
déterministes** appliqués par le harnais (et non « décidés » par l'IA).

> **Pourquoi un plugin ?** Au lieu d'éparpiller skills, hooks et commandes dans `.claude/`,
> on les **distribue d'un bloc**. Un coéquipier l'installe en deux commandes et obtient
> exactement les mêmes capacités **et** les mêmes garde-fous.

---

## 1. Contenu du plugin

```
ecommerce-ops/
├── .claude-plugin/plugin.json     # manifeste (nom, version, auteur, mots-clés)
├── skills/                        # capacités déclenchées AUTOMATIQUEMENT par Claude
│   ├── containerize/SKILL.md      #   Dockerfiles multi-étapes + scan Trivy
│   ├── k8s-bootstrap/SKILL.md     #   cluster k3d + déploiement des manifests
│   └── k8s-debug-pod/SKILL.md     #   diagnostic d'un pod en échec
├── commands/                      # slash-commands EXPLICITES (tapées par l'utilisateur)
│   ├── ship.md                    #   /ship       → conteneuriser puis déployer
│   └── ops-doctor.md              #   /ops-doctor → check santé (lecture seule)
├── agents/
│   └── ops-engineer.md            # sous-agent Ops (read-only par défaut)
├── hooks/                         # règles DÉTERMINISTES exécutées par le harnais
│   ├── hooks.json                 #   câblage des hooks
│   ├── secret-scan.sh             #   PreToolUse(Bash) : bloque un commit avec secret
│   ├── guard-destructive.sh       #   PreToolUse(Bash) : confirmation sur commande destructive
│   └── session-start.sh           #   SessionStart : rappel d'environnement
├── plugin.html                    # présentation visuelle (à ouvrir dans un navigateur)
└── plugin.md                      # présentation + scénario détaillé
```

| Type | Élément | Déclenchement |
|------|---------|---------------|
| **Skill** | `containerize`, `k8s-bootstrap`, `k8s-debug-pod` | **automatique** — Claude juge la pertinence d'après la `description` |
| **Command** | `/ship`, `/ops-doctor` | **explicite** — tapé par l'utilisateur |
| **Agent** | `ops-engineer` | **délégation** d'une investigation Ops |
| **Hook** | `secret-scan`, `guard-destructive`, `session-start` | **déterministe** — le harnais l'exécute, pas l'IA |

---

## 2. Prérequis

Claude Code et les commandes `/plugin` sont **identiques sur les trois OS**. Ce qui change,
ce sont les outils Ops sous-jacents et — sur Windows — le shell qui exécute les hooks (`.sh`).

### 🍎 macOS
```bash
npm install -g @anthropic-ai/claude-code      # ou: brew install claude-code
brew install git docker k3d kubectl trivy
brew install --cask dotnet-sdk                 # .NET 10
# bash est déjà présent → les hooks .sh tournent nativement
```

### 🐧 Linux (Debian/Ubuntu)
```bash
npm install -g @anthropic-ai/claude-code
sudo apt update && sudo apt install -y git bash curl docker.io dotnet-sdk-10.0 trivy
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
sudo snap install kubectl --classic
# bash natif → hooks .sh OK
```

### 🪟 Windows
```powershell
npm install -g @anthropic-ai/claude-code
winget install Git.Git Docker.DockerDesktop Kubernetes.kubectl AquaSecurity.Trivy Microsoft.DotNet.SDK.10
choco install k3d            # k3d : Chocolatey ou binaire GitHub
```
> ⚠️ **Hooks sur Windows.** Les hooks sont des scripts `bash` (`.sh`). Installe
> **Git for Windows** (fournit `bash`) ou active **WSL2**, et lance Claude Code depuis
> Git Bash / WSL. En CMD ou PowerShell pur, les `.sh` ne s'exécutent pas.

**Vérifier les prérequis** (tous OS) :
```bash
git --version && docker --version && k3d version && kubectl version --client && trivy --version && dotnet --version
```

---

## 3. Installation (marketplace local)

Le repo expose un marketplace local (`.claude-plugin/marketplace.json` à la racine).
Ouvre Claude Code **à la racine du repo**, puis dans le prompt :

```text
/plugin marketplace add .
/plugin install ecommerce-ops@ecommerce-ops-marketplace
```

**Vérifier :**
```text
/plugin     # ecommerce-ops apparaît "enabled"
/help       # /ship et /ops-doctor sont listés
```
Redémarre la session si demandé : les hooks et le `SessionStart` se chargent au démarrage.

> Pour distribuer à toute l'équipe, pousse le repo sur GitHub et remplace `.` par
> `owner/ecommerce-app` dans `/plugin marketplace add`. L'installation devient identique
> pour tous, quel que soit l'OS.

---

## 4. Les étapes d'utilisation (de zéro à déployé)

```
┌──────────────┐   ┌─────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ 0. session   │ → │ 1. /ops-    │ → │ 2. /ship catalog │ → │ 3. diagnostic    │
│    démarre   │   │    doctor   │   │  (build+déploie) │   │  si un pod plante│
│ (hook rappel)│   │ (lecture)   │   │                  │   │ (agent + skill)  │
└──────────────┘   └─────────────┘   └──────────────────┘   └──────────────────┘
        garde-fous actifs en continu : secret-scan + guard-destructive
```

1. **Ouvre une session** dans le repo → le hook `session-start` injecte les rappels d'env.
2. **`/ops-doctor`** → état des lieux (outils, cluster, pods) en lecture seule.
3. **`/ship catalog`** (ou `/ship` pour les 4 services) → conteneurise, importe dans k3d,
   `kubectl apply`, vérifie `/health`.
4. **Un pod plante ?** → délègue à l'agent `ops-engineer`, qui s'appuie sur le skill
   `k8s-debug-pod` pour trouver la cause racine et proposer un correctif.

| Je veux… | Je tape… | Ce qui se passe |
|----------|----------|-----------------|
| Un check santé | `/ops-doctor` | Inventaire outils + cluster + pods, lecture seule |
| Déployer un service | `/ship catalog` | `containerize` → import k3d → `kubectl apply` → `/health` |
| Tout déployer | `/ship` | Idem pour `catalog`, `ordering`, `gateway`, `web` |
| Diagnostiquer un pod | « utilise l'agent **ops-engineer** pour le pod ordering » | Investigation read-only + correctif proposé |
| Conteneuriser à la demande | « écris-moi un Dockerfile pour gateway » | Le skill **containerize** se déclenche tout seul |

---

## 5. Les Commands (`/...`)

Les commands sont **explicites** : tu les tapes dans le prompt. Elles orchestrent les skills
dans un ordre défini et montrent chaque commande avant de l'exécuter.

### `/ship [service]`
Déroule le chemin vers la prod : **conteneuriser → importer dans k3d → déployer → vérifier `/health`**.
- Argument : `catalog` \| `ordering` \| `gateway` \| `web`. Sans argument → les **4 services**.
- Étapes : `containerize` (build + scan Trivy) → vérif/création du cluster (`k8s-bootstrap`) →
  `k3d image import` → `kubectl apply -f k8s/` → `rollout status` → `curl /health`.
- S'arrête à la moindre erreur ; aucune commande destructive sans confirmation.

### `/ops-doctor`
Diagnostic d'environnement **strictement en lecture seule**, rendu sous forme de tableau ✅/⚠️/❌ :
1. **Outils** — versions de `docker`, `k3d`, `kubectl`, `trivy`, `dotnet` ;
2. **Cluster** — `kubectl cluster-info`, nœuds `Ready` ;
3. **App** — pods/svc/ingress/hpa du namespace `ecommerce` ;
4. **Santé** — `curl /health` via l'ingress.

Termine par : ce qui est OK, ce qui manque, et la prochaine action recommandée. N'applique **aucune** modification.

---

## 6. L'Agent (`ops-engineer`)

Sous-agent Ops/SRE que tu invoques par délégation (« utilise l'agent ops-engineer pour… »).
Il tourne dans son propre contexte avec un jeu d'outils restreint : `Bash, Read, Grep, Glob, Skill`.

**Principes intégrés :**
- **Diagnostiquer avant d'agir** — démarre toujours en lecture seule (`get`/`describe`/`logs`).
- **Montrer les commandes** avant de les lancer.
- **Jamais de destructif sans validation** — il ne cherche pas à contourner `guard-destructive`.
- **Aucun secret en clair** dans un manifest, Dockerfile, commit ou log.
- **Livrable** : constat → hypothèses classées → correctif proposé, appliqué seulement après accord humain.

Quand l'utiliser : investiguer un incident infra ou préparer un déploiement, sans polluer la session principale.

---

## 7. Les Hooks (les garde-fous)

Les hooks sont câblés dans `hooks/hooks.json` et **exécutés par le harnais**, indépendamment
du « jugement » du modèle. C'est ce qui rend les garde-fous **fiables**.

| Hook | Événement | Effet |
|------|-----------|-------|
| `secret-scan` | `PreToolUse(Bash)` | **Bloque** (`exit 2`) un `git commit` si un secret est détecté dans l'index |
| `guard-destructive` | `PreToolUse(Bash)` | Renvoie une décision **`ask`** → confirmation humaine avant une commande destructive |
| `session-start` | `SessionStart` | Injecte un **rappel d'environnement** dans le contexte au démarrage |

### `secret-scan.sh`
Sur un `git commit`, scanne `git diff --cached` à la recherche de motifs sensibles
(`password`, `api_key`, `token`, clés privées, `connectionstring`, `aws_secret_access_key`…).
Si une ligne ajoutée correspond → **commit bloqué** (code de sortie `2`), lignes fautives affichées.
> Démo simplifiée ; en production, brancher `gitleaks` ou `trufflehog`.

### `guard-destructive.sh`
Détecte les commandes irréversibles / coûteuses à récupérer
(`k3d cluster delete`, `kubectl delete ns`, `kubectl delete -f`, `terraform destroy`,
`docker system prune`, `docker volume rm`, `rm -rf`, `multipass delete`).
Au lieu de bloquer sèchement, renvoie `permissionDecision: "ask"` → **l'utilisateur garde la main**
et valide (ou non) en connaissance de cause.

### `session-start.sh`
Le `stdout` d'un hook `SessionStart` est ajouté au contexte de Claude. Ici il rappelle :
le SDK .NET 10 absent du PATH par défaut (`export PATH="/usr/local/share/dotnet:$PATH"`),
la commande pour tout lancer, les skills dispo et les garde-fous actifs.

---

## 8. Les Skills (déclenchement automatique)

Claude mobilise un skill **tout seul** quand la demande correspond à sa `description` —
pas besoin de l'invoquer explicitement.

| Skill | Rôle |
|-------|------|
| `containerize` | Dockerfiles multi-étapes (runtime chiselé non-root, port 8080), build, **scan Trivy** (HIGH/CRITICAL), docker-compose dev |
| `k8s-bootstrap` | Cluster k3d reproductible, `k3d image import`, `kubectl apply` des manifests, vérif rollout + `/health` |
| `k8s-debug-pod` | Diagnostic méthodique d'un pod (CrashLoopBackOff, ImagePullBackOff, OOMKilled, probes), hypothèse de cause racine + correctif |

Chaque skill embarque ses propres garde-fous (montrer les commandes, lecture seule par défaut,
pas de destructif sans validation, pas de secret en clair).

---

## 9. Le point clé : skills/commands/agent vs hooks

- **Skills / commands / agent** = capacités que **l'IA mobilise** quand c'est pertinent.
  Souples et contextuelles — mais c'est le modèle qui décide.
- **Hooks** = règles que **le harnais applique** systématiquement, quel que soit le jugement
  du modèle. C'est ce qui rend un garde-fou *fiable* : `secret-scan` bloquera **toujours**
  un commit avec secret, `guard-destructive` demandera **toujours** confirmation avant un `delete`.

Le plugin combine les deux : la **productivité** des skills, la **fiabilité** des hooks.

---

## Aller plus loin
- `plugin.md` — présentation et **scénario de bout en bout** (nouvel arrivant qui déploie `catalog`).
- `plugin.html` — la même présentation, en version visuelle (ouvrir dans un navigateur).
