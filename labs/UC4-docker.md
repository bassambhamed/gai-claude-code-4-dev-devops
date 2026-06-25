# UC4 — Étapes à appliquer (Docker + skill `containerize`)

Guide pratique à dérouler, de l'installation de **Docker** (Windows / Linux / macOS) jusqu'à
l'utilisation du skill `/containerize`, **avec les commandes bash manuelles** pour **vérifier ce que
ce skill fait réellement**.

> Objectif : faire écrire à Claude Code des **Dockerfiles multi-étapes** pour les microservices de
> l'`ecommerce-app` (images **petites, non-root, scannées**), puis un **docker-compose** pour lancer
> la stack en dev (skill `containerize`) — et savoir **rejouer à la main** chaque étape pour
> comprendre — et contrôler — ce que Claude exécute.

---

## Docker en 30 secondes

| Terme | En clair |
|---|---|
| **image** | un **modèle** figé (OS minimal + app) à partir duquel on lance des conteneurs. |
| **conteneur** | une **instance** en cours d'exécution d'une image (isolée, jetable). |
| **Dockerfile** | la **recette** qui décrit comment construire l'image. |
| **build multi-étapes** | compiler dans une image **SDK**, ne garder que le **runtime** → image plus petite. |
| **chiselé / distroless** | image **sans shell ni gestionnaire de paquets** → petite + moins de surface d'attaque. |
| **non-root** | le conteneur tourne sous un utilisateur **sans privilèges** (sécurité). |
| **docker-compose** | un YAML qui lance **plusieurs conteneurs ensemble** (dev). |
| **Trivy** | un scanner qui détecte les **vulnérabilités** d'une image. |

> Image mentale : le **Dockerfile = la recette**, l'**image = le plat préparé**, le **conteneur =
> l'assiette servie**. Une bonne image est **petite, non-root et scannée**.

---

## Étape 0 — Pré-requis

Un terminal, les droits d'installer un logiciel, et **Docker qui tourne**. Si **Docker est déjà
installé** sur ton poste → passe à l'Étape 2.

---

## Étape 1 — Installer Docker (si nécessaire, selon ton OS)

### macOS
```bash
brew install --cask docker        # Docker Desktop
```
> Lance **Docker Desktop** une fois pour démarrer le démon.

### Linux (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER       # éviter sudo (reconnecte-toi ensuite)
```

### Windows
```powershell
winget install Docker.DockerDesktop
```
> Docker Desktop s'appuie sur **WSL2** (ou Hyper-V). Lance-le une fois après l'install.

> 💡 Optionnel mais utile pour cet UC : **Trivy** (scanner d'images).
> macOS : `brew install trivy` · Linux : voir la doc Aqua · Windows : `winget install AquaSecurity.Trivy`.

---

## Étape 2 — Vérifier l'installation

```bash
docker version       # client + serveur (démon) → l'install est OK
docker info          # confirme que le démon tourne
trivy --version      # (optionnel) le scanner est dispo
```

**Ce qui se passe :** `docker info` doit répondre sans erreur — sinon aucun build ne marchera. ✅

---

## Étape 3 — Lancer Claude Code dans le projet

```bash
cd ecommerce-app
claude
```

> Dans la session Claude, on exécute une commande de l'hôte en la préfixant par `!`
> (ex. `!docker images`, `!docker ps`). Pratique pour vérifier **sans quitter** Claude.

> Le `Dockerfile` du **Catalog** existe déjà (`src/ECommerce.Catalog.Api/Dockerfile`) ; on va
> générer ceux des **trois autres** services (Ordering, Gateway, Web).

---

## Étape 4 — Le skill `/containerize` : générer les Dockerfiles

Dans la session Claude :
```text
> /containerize écris des Dockerfiles multi-étapes pour Ordering, Gateway et Web : image runtime chiselée, non-root, port 8080
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. identifie le service et son `.csproj` (+ la dépendance `ECommerce.ServiceDefaults`) ;
2. génère un `src/<Service>/Dockerfile` **multi-étapes** (SDK pour build, runtime **chiselé** pour l'exécution) ;
3. exécute en **non-root** (`USER $APP_UID`) et expose le port `8080` ;
4. peut **construire** puis **scanner** l'image (Trivy) et proposer des correctifs ;
5. **n'exécute aucune commande destructive** (`rmi`, `prune`) sans confirmation.

### ✅ Vérifier à la main ce que le skill a produit

```bash
cat src/ECommerce.Ordering.Api/Dockerfile
cat src/ECommerce.Gateway/Dockerfile
cat src/ECommerce.Web/Dockerfile
```

| À vérifier dans le Dockerfile | Pourquoi c'est important |
|---|---|
| deux blocs `FROM … AS build` puis `FROM …-chiseled AS final` | **multi-étapes** : le SDK ne finit **pas** dans l'image finale → image petite. |
| `COPY *.csproj` **avant** `dotnet restore` | profite du **cache Docker** (restore rejoué seulement si un `.csproj` change). |
| `USER $APP_UID` | exécution **non-root** (sécurité). |
| `EXPOSE 8080` | les images aspnet .NET 8+ écoutent sur **8080** par défaut. |

---

## Étape 5 — Construire et scanner une image (à la main)

Dans Claude :
```text
> construis l'image Ordering puis scanne-la avec Trivy et explique les findings
```
ce qui correspond, **à la main**, à :
```bash
# ⚠️ Contexte de build = RACINE du repo (le point final). Le Dockerfile est désigné par -f.
docker build -t ecommerce-ordering:latest -f src/ECommerce.Ordering.Api/Dockerfile .

# Taille de l'image (l'image chiselée est nettement plus petite qu'une aspnet classique)
docker images ecommerce-ordering:latest

# Scanner les vulnérabilités HIGH/CRITICAL
trivy image --severity HIGH,CRITICAL ecommerce-ordering:latest
```

| Commande | Ce qu'elle prouve |
|---|---|
| `docker build … .` | l'image se construit ; le **`.`** = contexte de build (la **racine**). |
| `docker images …` | la **taille** de l'image (runtime-only chiselé = compact). |
| `trivy image …` | les **CVE** présentes ; le skill propose ensuite des correctifs. |

> ⚠️ Lance le build depuis la **racine** `ecommerce-app/`, jamais depuis `src/ECommerce.Ordering.Api/` :
> les `COPY src/...` du Dockerfile ne trouveraient rien et le build échouerait.

---

## Étape 6 — Lancer toute la stack en dev (docker-compose)

Dans Claude :
```text
> /containerize génère un docker-compose qui lance Catalog, Ordering, Gateway et Web ensemble, web exposé sur 8080
```

### ✅ Vérifier à la main

```bash
cat docker-compose.yml                  # 4 services, web exposé, service discovery par variables d'env

docker compose up --build               # build + lance toute la stack
curl http://localhost:8080              # le frontend Web répond → stack OK
docker compose ps                       # liste les conteneurs et leur état
```

| Élément du compose | Rôle |
|---|---|
| `build.context: .` | contexte = **racine** (cohérent avec les Dockerfiles). |
| `services__<nom>__http__0=http://<nom>:8080` | **service discovery manuel** : remplace le `WithReference(...)` d'Aspire hors AppHost. |
| `ports: ["8080:8080"]` sur `web` | seul le **frontend** est exposé sur l'hôte ; les autres restent internes. |

> Note : ce compose est un **substitut de dev** à Aspire (qui orchestre tout via `dotnet run`).
> Les données sont **in-memory** → tout est perdu à l'arrêt.

---

## Étape 7 — Nettoyage (le réflexe « jetable »)

Dans Claude :
```text
> explique comment arrêter et nettoyer les conteneurs et images
```
ce qui correspond, **à la main**, à :
```bash
docker compose down                     # arrête + supprime les conteneurs du compose
docker rmi ecommerce-ordering:latest    # ⚠️ supprime une image (confirmation)
docker system prune                     # ⚠️ nettoie tout l'inutilisé (confirmation)
```

> ⚠️ `docker rmi` / `docker system prune` / `docker volume rm` sont **destructifs** : le skill
> **affiche la commande et attend ton accord** avant exécution.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1 | install si besoin (`brew` / `apt` / `winget`) | Docker installé |
| 2 | `!docker info`, `!trivy --version` | démon Docker (+ scanner) vérifiés |
| 4 | `/containerize …` | `src/<Service>/Dockerfile` générés et expliqués |
| 5 | « construis puis scanne Ordering » | `docker build -f … .` + `docker images` + `trivy image` |
| 6 | « génère un docker-compose … » | `docker compose up --build` + `curl localhost:8080` |
| 7 | « comment nettoyer ? » | `compose down` / `rmi` / `prune` (avec confirmation) |

> **Message clé :** le skill `containerize` n'est qu'un **mode d'emploi** traduit en commandes
> `docker`. On peut **tout rejouer à la main** pour comprendre — images **petites, non-root et
> scannées** — et les actions **destructives** (`rmi`, `prune`) restent une **décision humaine**.
> L'IA accélère ; l'ingénieur garde la main.
