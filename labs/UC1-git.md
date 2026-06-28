# UC1 — Git & GitHub (skills `init-repo`, `git-commit`, `open-pr` + hook anti-secret)

Guide pratique à dérouler, de l'installation de **Git** et **GitHub CLI** (Windows / Linux / macOS)
jusqu'à l'ouverture d'une **Pull Request**, **avec les commandes bash manuelles** pour **vérifier ce
que les skills font réellement**.

> **Ce qu'on développe dans ce lab :** on part de l'`ecommerce-app` (sans historique Git), on en
> fait un **dépôt propre** publié sur GitHub, puis on déroule un **workflow Git complet assisté par
> Claude Code** : créer une branche → modifier un bout de code (un endpoint `GET /health`) →
> faire un **commit propre** (Conventional Commits) → ouvrir une **Pull Request** documentée.
> Le tout encadré par des **garde-fous** : 3 skills réutilisables (`init-repo`, `git-commit`,
> `open-pr`) et un **hook** qui bloque automatiquement tout commit contenant un secret.

> **Garde-fou central :** l'IA **propose**, l'ingénieur **valide** avant tout `commit`, `push` ou
> `merge`. Jamais de secret dans un commit.

---

## Git & GitHub en 30 secondes

| Terme | En clair |
|---|---|
| **dépôt (repo)** | le dossier de votre projet suivi par Git (ici `ecommerce-app`). |
| **commit** | une *photo* de vos changements, avec un message qui explique quoi/pourquoi. |
| **branche (branch)** | une *ligne de travail* parallèle pour ne pas casser `main`. |
| **`main`** | la branche principale, celle qui doit toujours rester saine. |
| **push** | envoyer vos commits locaux vers GitHub (le serveur distant). |
| **Pull Request (PR)** | une **demande de fusion** d'une branche vers `main`, *à faire relire et approuver* avant d'intégrer le code. C'est le point de revue d'équipe. |
| **merge** | fusionner la PR dans `main` une fois approuvée. |
| **`gh`** | la **CLI officielle GitHub** : crée des repos, ouvre des PR… depuis le terminal. |

> Image mentale : on **travaille sur une branche** → on **prend des photos (commits)** →
> on **envoie (push)** → on **demande la fusion (PR)** → un humain **relit et merge**.

---

## Étape 0 — Pré-requis

Un terminal, les droits d'installer un logiciel, et un **compte GitHub**. Si **Git et `gh` sont
déjà installés et connectés** (`gh auth status` répond OK) → passe à l'Étape 3.

---

## Étape 1 — Installer Git & GitHub CLI (une seule fois, selon ton OS)

### macOS (avec Homebrew)
```bash
brew install git gh
```

### Linux (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install git
# GitHub CLI (dépôt officiel)
sudo apt install gh        # si indisponible : voir cli.github.com/manual/installation
```

### Windows
```powershell
winget install Git.Git GitHub.cli
```
> Ferme et rouvre le terminal après l'install pour que `git` et `gh` soient dans le PATH.

---

## Étape 2 — Se connecter à GitHub & vérifier l'installation

```bash
git --version            # Git est installé
gh --version             # GitHub CLI est installée
gh auth login            # GitHub.com → HTTPS → login via le navigateur (une seule fois)
gh auth status           # confirme que la machine est bien autorisée
```

**Ce qui se passe :** `gh auth login` autorise ta machine auprès de GitHub une fois pour toutes ;
`gh auth status` doit afficher ton compte connecté. ✅

---

## Étape 3 — Lancer Claude Code dans le projet

```bash
cd ecommerce-app
claude
```
```text
> /init           # (option) génère/met à jour CLAUDE.md = contexte permanent du projet
```

> Dans la session Claude, on exécute une commande de l'hôte en la préfixant par `!`
> (ex. `!git status`, `!git log --oneline`) : le résultat est réinjecté dans la session.
> Pratique pour vérifier **sans quitter** Claude.

---

## Étape 4 — Le skill `/init-repo` : initialiser le dépôt et le publier

Dans la session Claude :
```text
> /init-repo
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. refuse si le dossier est **déjà** un dépôt relié à un remote (rien à initialiser) ;
2. `git init` → `git branch -M main` → `git add .` → commit initial ;
3. ⚠️ **demande confirmation**, puis crée le repo distant **privé** et pousse `main`
   (`gh repo create … --private --source=. --remote=origin --push`) ;
4. affiche l'URL du repo créé.

ce qui correspond, **à la main**, à :
```bash
git init                          # crée le dépôt git local (dossier caché .git)
git branch -M main                # nomme la branche principale "main"
git status                        # ⚠️ contrôle : aucun secret / .env ne doit apparaître
git add .                         # indexe tout le projet (.claude/ inclus)
git commit -m "chore: commit initial de l'app ecommerce"
gh repo create ecommerce-app-dev --private --source=. --remote=origin --push
```

### ✅ Vérifier à la main

```bash
git remote -v                     # 'origin' pointe vers le nouveau repo ecommerce-app
git log --oneline                 # le commit initial est présent
gh repo view --web                # ouvre le repo dans le navigateur
```

> 💡 `git init` n'a de sens **qu'une fois** par projet. Si `ecommerce-app` est déjà initialisé,
> le skill s'arrête de lui-même.

---

## Étape 5 — Vérifier que skills et hook sont actifs

```text
> /skills         # doit lister : init-repo, git-commit, open-pr
> /hooks          # doit montrer le hook PreToolUse (Bash) → secret-scan.sh
```

Si les 3 skills apparaissent et que le hook est listé, le projet est prêt. ✅
*(Si un skill manque : quitte et relance `claude` — les skills sont chargés au démarrage.)*

---

## Étape 6 — Créer une branche de travail

On ne travaille **jamais** directement sur `main`. En langage naturel :
```text
> crée une branche feat/health-endpoint pour ajouter un endpoint /health
```
ce qui correspond, **à la main**, à :
```bash
git switch -c feat/health-endpoint     # convention : feat/… (fonctionnalité), fix/… (correctif)
```

### ✅ Vérifier
```bash
git branch --show-current              # doit afficher : feat/health-endpoint
```

---

## Étape 7 — Faire une petite modification

```text
> ajoute un endpoint GET /health qui renvoie 200 OK dans Catalog.Api
```

**Ce qui se passe :** Claude trouve le bon fichier (`src/ECommerce.Catalog.Api/…`), propose
l'édition et l'applique.

### ✅ Vérifier
```text
> /diff                                # relis les lignes ajoutées (vert) avant de commiter
```
```bash
git diff                               # même chose, à la main
```

---

## Étape 8 — Le skill `/git-commit` : un commit propre

```text
> /git-commit
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. lance `git status` + `git diff` et **résume** le changement en une phrase ;
2. indexe les bons fichiers (`git add`) — **jamais** un `.env` ni un secret ;
3. rédige un message **Conventional Commits**, ex. `feat(catalog): ajoute l'endpoint /health` ;
4. ⚠️ **affiche le message et demande validation** avant `git commit` ;
5. **jamais** de `git push` ici ; si un secret est repéré dans le diff, il **stoppe**.

ce qui correspond, **à la main**, à :
```bash
git add src/ECommerce.Catalog.Api/                       # indexer seulement le nécessaire
git commit -m "feat(catalog): ajoute l'endpoint /health pour les probes"
```

### ✅ Vérifier
```bash
git log -1 --oneline                   # le dernier commit, avec son message propre
```

---

## Étape 9 — Le skill `/open-pr` : pousser et ouvrir la Pull Request

> Pré-requis : `gh` connecté (Étape 2).

```text
> /open-pr
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. vérifie qu'on **n'est pas sur `main`** (sinon il refuse et propose une branche) ;
2. récapitule les commits : `git log --oneline main..HEAD` ;
3. ⚠️ **demande confirmation**, puis pousse la branche ;
4. rédige une **description structurée** : Contexte / Changements / Tests / Checklist ;
5. crée la PR et affiche **l'URL** — **ne merge jamais** automatiquement.

ce qui correspond, **à la main**, à :
```bash
git push -u origin feat/health-endpoint
gh pr create --title "feat(catalog): endpoint /health" \
  --body "Contexte… / Changements… / Tests… / Checklist…"
```

### ✅ Vérifier
```bash
gh pr view --web                       # ouvre la PR créée dans le navigateur
gh pr status                           # état des PR de la branche courante
```

---

## Étape 10 — Le hook anti-secret (garde-fou automatique)

Le hook `secret-scan.sh` s'exécute **automatiquement avant chaque commande shell** de l'agent
(via `PreToolUse` → `Bash` dans `.claude/settings.json`). Pour un `git commit`, si un **secret**
est détecté dans les fichiers indexés, le commit est **bloqué** (`exit 2`).

**Vérifier le garde-fou en live :**
```bash
# 1) Crée un faux secret et indexe-le
printf 'api_key = "sk-test-12345"\n' > demo-secret.txt
git add demo-secret.txt
```
```text
> /git-commit                          # le hook détecte le motif et REFUSE le commit
```
```bash
# 2) Nettoyage après la démo
git reset demo-secret.txt && rm -f demo-secret.txt
```

> Illustration clé : **le garde-fou ne dépend pas de l'IA** — c'est le harnais (le hook) qui
> l'impose, de façon déterministe.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1–2 | install (`brew`/`apt`/`winget`) + `gh auth login` | Git + `gh` installés et connectés |
| 4 | `/init-repo` | `git init … commit` + `gh repo create … --push` |
| 5 | `/skills`, `/hooks` | 3 skills + hook anti-secret actifs |
| 6 | « crée une branche feat/… » | `git switch -c` (vérif : `git branch --show-current`) |
| 7 | « ajoute l'endpoint /health » | édition + `/diff` |
| 8 | `/git-commit` | message propre + commit (vérif : `git log -1`) |
| 9 | `/open-pr` | `git push` + `gh pr create` (vérif : `gh pr view`) |
| 10 | *(automatique)* | hook qui bloque les secrets |

> **Message clé :** Claude Code accélère le workflow Git **sans retirer la décision à l'humain**
> — validation avant commit/push, et un hook qui impose les règles non négociables.
