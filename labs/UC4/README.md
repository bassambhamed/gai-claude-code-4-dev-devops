# Corrigé — UC4 (Conteneurisation Docker des microservices)

Fichiers de référence pour `UC4-docker.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.claude/skills/
└── containerize/SKILL.md             # /containerize : génère/optimise les Dockerfiles + compose + scan
src/
├── ECommerce.Ordering.Api/Dockerfile # image optimisée (chiselée, non-root)
├── ECommerce.Gateway/Dockerfile      # image optimisée (chiselée, non-root)
└── ECommerce.Web/Dockerfile          # image optimisée (chiselée, non-root)
docker-compose.yml                     # lance les 4 services ensemble (dev, hors Aspire)
```

> Le `Dockerfile` du **Catalog** existe déjà dans `src/ECommerce.Catalog.Api/Dockerfile`
> (construit en UC2/UC5) ; ce corrigé fournit les **trois autres** + le `docker-compose.yml`.

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC4/.claude            ecommerce-app/        # fusionne avec le .claude existant
cp UC4/src/ECommerce.Ordering.Api/Dockerfile  ecommerce-app/src/ECommerce.Ordering.Api/
cp UC4/src/ECommerce.Gateway/Dockerfile       ecommerce-app/src/ECommerce.Gateway/
cp UC4/src/ECommerce.Web/Dockerfile           ecommerce-app/src/ECommerce.Web/
cp UC4/docker-compose.yml    ecommerce-app/
```

## Pré-requis
- **Docker** qui tourne : `docker version` / `docker info`
- (Optionnel) **Trivy** pour scanner les images : `brew install trivy`

## Dérouler
```bash
# Build d'un service (contexte = racine du repo)
docker build -t ecommerce-ordering:latest -f src/ECommerce.Ordering.Api/Dockerfile .

# Scanner l'image
trivy image --severity HIGH,CRITICAL ecommerce-ordering:latest

# Lancer toute la stack en dev
docker compose up --build           # web exposé sur http://localhost:8080
docker compose down                 # arrêt + nettoyage des conteneurs
```

> Rappels : contexte de build = **racine** (`.`), images **runtime-only non-root** (chiselées),
> **aucun secret en clair** dans un Dockerfile/compose. Les données sont **in-memory** : tout est
> perdu à l'arrêt. Versions et ports sont **illustratifs** — à adapter.
