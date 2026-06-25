# Corrigé — UC5 (Création d'un cluster Kubernetes avec k3d)

Fichiers de référence pour `UC5-kubernetes.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.claude/skills/
├── k8s-bootstrap/SKILL.md         # /k8s-bootstrap : crée le cluster k3d + déploie l'app
└── k8s-debug-pod/SKILL.md         # /k8s-debug-pod : diagnostique un pod en échec
k8s/
├── k3d-cluster.yaml               # config k3d : 3 nœuds + registre local + ingress
├── namespace.yaml                 # namespace "ecommerce"
├── catalog.yaml                   # Deployment + Service + HPA
├── ordering.yaml                  # idem (appelle Catalog directement)
├── gateway.yaml                   # idem (route vers Catalog + Ordering)
├── web.yaml                       # idem (frontend, exposé via l'ingress)
└── ingress.yaml                   # expose le Web sur http://ecommerce.localhost:8080
```

> Pré-requis : les **images** sont construites en **UC4** (`ecommerce-catalog/ordering/gateway/web:latest`).

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC5/.claude   ecommerce-app/        # fusionne avec le .claude existant
cp -r UC5/k8s       ecommerce-app/
```

## Pré-requis outils
- **k3d** : `k3d version` (macOS : `brew install k3d`)
- **kubectl** : `kubectl version --client`
- **Docker** qui tourne (k3d crée le cluster dans Docker)

## Dérouler
```bash
# 1) Créer le cluster (3 nœuds + registre + ingress)
k3d cluster create --config k8s/k3d-cluster.yaml
kubectl get nodes                                   # tous "Ready"

# 2) Importer les images (construites en UC4) dans le cluster
k3d image import ecommerce-catalog:latest ecommerce-ordering:latest \
  ecommerce-gateway:latest ecommerce-web:latest -c ecommerce

# 3) Déployer
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

# 4) Vérifier
kubectl -n ecommerce get pods,svc,hpa
kubectl -n ecommerce rollout status deploy/web
curl -H "Host: ecommerce.localhost" http://localhost:8080      # le frontend répond
```

## Nettoyage
```bash
k3d cluster delete ecommerce        # ⚠️ supprime le cluster (confirmation)
```

> Rappels : probes **readiness** (`/health`) et **liveness** (`/alive`) sur chaque service,
> `requests/limits` définis (nécessaires au **HPA**), **aucun secret en clair** dans un manifest.
> Versions, hosts et ressources sont **illustratifs** — à adapter. Le `/health` et `/alive` ne sont
> mappés qu'en **Development** (d'où `ASPNETCORE_ENVIRONMENT=Development` dans les Deployments).
