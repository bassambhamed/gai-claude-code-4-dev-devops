---
name: docker-ci-review
description: Checklist DevOps pour ecommerce-app-dev — Dockerfile, CI GitHub Actions, k8s/Helm. À charger pour revoir/améliorer l'infra.
---
## Dockerfile (src/<Service>/Dockerfile, contexte de build = racine du repo)
- Multi-stage : `sdk:10.0` pour build, runtime **chiselé** (`aspnet:10.0-noble-chiseled`) en final.
- `COPY` des `.csproj` AVANT le code → `restore` mis en cache (rejoué seulement si un csproj change).
- Non-root : `USER $APP_UID`. `EXPOSE 8080`. `dotnet publish -c Release --no-restore`.

## CI (.github/workflows/*.yml)
- Étapes : restore → build → test → publish. Cache NuGet. Scan **Trivy** des images.
  **Gate manuel** (environnement protégé) avant la prod.

## k8s / Helm
- Probes `liveness`/`readiness` sur `/health`, `requests`/`limits`, **HPA**. Values multi-env
  (dev/preprod).
