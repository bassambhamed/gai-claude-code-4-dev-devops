---
description: Déroule le chemin vers la prod de l'ecommerce-app — conteneurise un service, l'importe dans k3d et le déploie, puis vérifie /health.
argument-hint: "[service: catalog|ordering|gateway|web] (défaut : tous)"
---

# /ship — conteneuriser puis déployer sur k3d

Cible : `$1` (si vide, traiter les 4 services : `catalog`, `ordering`, `gateway`, `web`).

Déroule ces étapes dans l'ordre, en t'appuyant sur les skills du plugin. **Montre chaque
commande avant de l'exécuter** et arrête-toi à la moindre erreur.

1. **Conteneuriser** — utilise le skill `containerize` pour (re)générer le Dockerfile de la cible,
   construire l'image `ecommerce/<service>:dev` et la scanner avec Trivy (HIGH,CRITICAL).
2. **Cluster** — vérifie qu'un cluster k3d existe (`kubectl cluster-info`). S'il manque, utilise
   le skill `k8s-bootstrap` pour le créer.
3. **Importer** — `k3d image import ecommerce/<service>:dev -c <cluster>`.
4. **Déployer** — `kubectl apply -f k8s/` puis `kubectl -n ecommerce rollout status deploy/<service>`.
5. **Vérifier** — `curl` l'ingress et l'endpoint `/health` ; si un pod échoue, enchaîne sur le
   skill `k8s-debug-pod`.

Garde-fous : aucune commande destructive sans confirmation (le hook `guard-destructive` la
réclamera de toute façon), aucun secret en clair.
