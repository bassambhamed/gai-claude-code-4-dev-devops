# Claude Code — installation & commandes de base (démo)

**Pour ingénieurs IT — Dev / DevOps**
Support de démonstration à dérouler **en direct dans un terminal**.
Progression : **installer → lancer → commandes de base → saisies spéciales**.

> **Qu'est-ce que Claude Code ?** Un **agent de coding dans le terminal** : il lit votre
> dépôt, édite des fichiers, exécute des commandes (build, tests, `git`, `kubectl`…) et itère.
> On le pilote par des **prompts** en langage naturel et par des **commandes** qui commencent
> par `/`.

> Jamais de **secret** ni de **donnée sensible** non anonymisée. Les actions sensibles (merge,
> `apply`, prod) passent par une validation humaine — voir `/permissions`.

---

## 1. Installation

### Prérequis
- **OS** : macOS 13+, Windows 11, Ubuntu 20.04+ / Debian 10+.
- **Matériel** : 8 Go de RAM minimum.
- **Compte** : un abonnement **Pro, Max, Team, Enterprise** ou **Console** (le plan gratuit
  Claude.ai ne donne pas accès à Claude Code). Alternative : fournisseurs API
  (Amazon Bedrock, Google Vertex AI, Microsoft Foundry).

### Installer (choisir UNE méthode)

**macOS / Linux / WSL — installeur natif (recommandé)**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows — PowerShell**
```powershell
irm https://claude.ai/install.ps1 | iex
```

**macOS — Homebrew**
```bash
brew install --cask claude-code
```

**Windows — WinGet**
```powershell
winget install Anthropic.ClaudeCode
```

**Multiplateforme — npm** (nécessite **Node.js 18+**)
```bash
npm install -g @anthropic-ai/claude-code
```

> L'installeur natif (et le paquet npm) installent le **même binaire** et se **mettent à jour
> automatiquement** en arrière-plan. Homebrew / WinGet : mise à jour manuelle.
> ⚠️ Ne **jamais** faire `sudo npm install -g` (risques de permissions/sécurité).

### Vérifier l'installation
```bash
claude --version       # affiche la version installée
claude doctor          # diagnostic complet (install, config, connectivité)
```

### Lancer & se connecter
```bash
claude                 # ouvre une session interactive dans le dossier courant
```
Au premier lancement, Claude ouvre le navigateur pour la **connexion**. À l'intérieur d'une
session, on peut (re)gérer le compte avec `/login` et `/logout`.

### Mettre à jour
```bash
claude update          # applique tout de suite la dernière version disponible
```

---

## 2. Lancer Claude Code — les modes

`claude` se lance de plusieurs façons selon le besoin :

| Commande | Ce qu'elle fait |
|---|---|
| `claude` | Démarre une **session interactive** (le mode normal). |
| `claude "ta consigne"` | Démarre en exécutant tout de suite ce prompt. |
| `claude -p "ta consigne"` | Mode **non interactif** (*headless*) : exécute, imprime le résultat, et rend la main. Idéal en **script / CI**. |
| `claude -c` | **Continue** la conversation la plus récente du dossier courant. |
| `claude -r` | **Reprend** une session précédente (ouvre un sélecteur). |
| `claude --help` | Liste toutes les options de lancement. |

Quelques **sous-commandes** utiles (hors session) :
```bash
claude mcp             # configurer/gérer les serveurs MCP
claude doctor          # vérifier l'installation
claude update          # mettre à jour
claude install         # (ré)installer le binaire natif
```

---

## 3. Les commandes de base (dans une session)

À l'intérieur d'une session, tapez `/` pour voir le menu, ou `/` + lettres pour filtrer.
Une commande n'est reconnue qu'**en début de message** ; le texte qui suit lui est passé en
argument.

### 3.1 Se repérer & diagnostiquer
| Commande | Ce qu'elle fait |
|---|---|
| `/help` | Affiche l'aide et la liste des commandes disponibles. |
| `/status` | Ouvre l'état : **version, modèle, compte, connectivité**. |
| `/doctor` | Diagnostique l'installation et la config (appuyer sur `f` pour laisser Claude corriger). |
| `/release-notes` | Affiche le changelog (nouveautés par version). |
| `/exit` | **Quitte** le CLI. *(alias : `/quit`)* |

### 3.2 Démarrer un projet & gérer le contexte
| Commande | Ce qu'elle fait |
|---|---|
| `/init` | **Analyse le dépôt et génère un `CLAUDE.md`** de départ (le fichier de contexte permanent du projet : stack, conventions, commandes). À faire en tout premier sur un repo. |
| `/memory` | **Éditer les fichiers mémoire** `CLAUDE.md` (projet et perso) pour affiner le contexte. |
| `/add-dir <chemin>` | Ajoute un **dossier supplémentaire** accessible aux outils pendant la session. |
| `/context` | **Visualise l'usage du contexte** (fenêtre) sous forme de grille + suggestions. |
| `/compact [consignes]` | **Résume** la conversation pour **libérer du contexte** sans tout perdre. |
| `/clear` | **Repart d'une conversation vide** (nouvelle tâche), en gardant la mémoire projet. |

### 3.3 Piloter le modèle & le raisonnement
| Commande | Ce qu'elle fait |
|---|---|
| `/model [modèle]` | **Change le modèle** (ex. Opus / Sonnet / Haiku) et l'enregistre par défaut. Sans argument : ouvre un sélecteur. |
| `/effort [niveau]` | Règle le **niveau d'effort de raisonnement** (`low`, `medium`, `high`, `xhigh`, `max`…). Plus d'effort = plus de réflexion (et de coût). |
| `/config [clé=valeur]` | Ouvre les **réglages** (thème, modèle, mode d'édition Vim, etc.). *(alias : `/settings`)* |
| `/plan [description]` | Passe en **mode Plan** : Claude propose un plan que vous validez **avant** d'agir. |

### 3.4 Travailler en sécurité (permissions)
| Commande | Ce qu'elle fait |
|---|---|
| `/permissions` | Gère les règles **allow / ask / deny** des outils (quelles commandes Claude peut lancer sans demander). *(alias : `/allowed-tools`)* |
| `/hooks` | Affiche les **hooks** configurés (scripts déclenchés automatiquement sur certains événements d'outils). |

### 3.5 Revue & qualité (avant de livrer)
| Commande | Ce qu'elle fait |
|---|---|
| `/diff` | Ouvre un **visualiseur de diff** des changements non commités. |
| `/code-review [niveau] [--fix]` | **Revue du diff** (bugs + simplifications). `--fix` applique les corrections ; `ultra` lance une revue multi-agents dans le cloud. |
| `/review [PR]` | **Revue d'une pull request** en local dans la session. |
| `/security-review` | Analyse les changements pour des **failles de sécurité** (injection, auth, fuite de données). |

### 3.6 Gérer les sessions
| Commande | Ce qu'elle fait |
|---|---|
| `/resume [session]` | **Reprend** une conversation (par nom/ID, ou via un sélecteur). *(alias : `/continue`)* |
| `/rewind` | **Revient à un point antérieur** (code et/ou conversation) — *checkpoint*. *(alias : `/undo`)* |
| `/export [fichier]` | **Exporte** la conversation en texte (presse-papier ou fichier). |
| `/rename [nom]` | **Renomme** la session courante. |

### 3.7 Extensions & intégrations
| Commande | Ce qu'elle fait |
|---|---|
| `/mcp` | Gère les **serveurs MCP** (connecteurs vers des outils/données externes) et leur auth. |
| `/agents` | Gère les **sous-agents** (agents spécialisés à qui déléguer des tâches). |
| `/skills` | Liste les **skills** (procédures/compétences réutilisables, dont vos commandes perso). |
| `/plugin` | Gère les **plugins** Claude Code. |

### 3.8 Coûts & usage
| Commande | Ce qu'elle fait |
|---|---|
| `/usage` | Affiche le **coût de session**, les **limites du plan** et des stats. *(alias : `/cost`, `/stats`)* |

> **Note version** : sur les versions récentes (2.1.x), `/vim` a été retiré — le **mode Vim**
> se règle via `/config` → *Editor mode*. `/pr-comments` a aussi été retiré : demandez
> directement à Claude de lire les commentaires d'une PR.

---

## 4. Saisies spéciales (préfixes)

En plus des commandes `/`, trois préfixes accélèrent le travail :

| Préfixe | Effet | Exemple |
|---|---|---|
| `@` | **Référencer un fichier / dossier** dans le prompt (Claude le lit). | `Explique-moi @src/Program.cs` |
| `!` | **Exécuter une commande shell** directement (le résultat entre dans la session). | `!git status` |
| `#` | **Ajouter une note à la mémoire** (`CLAUDE.md`) pour les prochaines fois. | `# toujours lancer les tests avant un commit` |
| `/` | Ouvre le **menu des commandes**. | `/model` |

---

## 5. Commandes personnalisées (pour aller plus loin)

On peut créer ses **propres commandes** `/` : un fichier Markdown dans `.claude/commands/`
(ou un *skill* dans `.claude/skills/`). Exemple : un fichier `.claude/commands/deploy.md`
crée la commande `/deploy`. Pratique pour **capitaliser** les procédures d'équipe (revue,
release, runbook) — l'équivalent outillé d'une bibliothèque de prompts.

---

## 6. Récapitulatif — le minimum à connaître

| Étape | Commande |
|---|---|
| Installer (macOS/Linux) | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Vérifier | `claude --version` · `claude doctor` |
| Lancer | `claude` |
| Initialiser le projet | `/init` |
| Choisir le modèle | `/model` |
| Mode plan (gros changement) | `/plan` |
| Gérer les permissions | `/permissions` |
| Libérer / repartir | `/compact` · `/clear` |
| Reprendre une session | `claude -c` ou `/resume` |
| Coûts | `/usage` |
| Quitter | `/exit` |

> **Astuce démo** : tapez simplement `/` dans une session pour montrer **en direct** le menu
> complet des commandes, puis `/help` pour l'aide. Tout le reste (skills, MCP, hooks, plugins)
> se découvre à partir de ces commandes de base.
