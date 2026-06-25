# Corrigé — UC6 (Packaging Helm du déploiement)

Fichiers de référence pour `UC6-helm.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.claude/skills/
└── helm-package/SKILL.md              # /helm-package : transforme les manifests en chart Helm
helm/ecommerce/
├── Chart.yaml                         # métadonnées du chart (nom, versions)
├── values.yaml                        # valeurs PAR DÉFAUT (la liste des services)
├── values-dev.yaml                    # surcharge DEV (1 réplica, pas d'autoscaling)
├── values-preprod.yaml               # surcharge PREPROD (réplicas + ressources + autoscaling)
└── templates/
    ├── _helpers.tpl                   # labels communs
    ├── deployment.yaml                # 1 Deployment par service (range sur .Values.services)
    ├── service.yaml                   # 1 Service par service
    ├── hpa.yaml                       # 1 HPA par service (si autoscaling activé)
    └── ingress.yaml                   # expose le Web
```

> Pré-requis : le **cluster k3d** et les **images** existent (UC4 + UC5). Helm **remplace** les
> `kubectl apply -f k8s/` de l'UC5 par un déploiement **paramétré et versionné**.

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC6/.claude   ecommerce-app/         # fusionne avec le .claude existant
cp -r UC6/helm      ecommerce-app/
```

## Pré-requis outils
- **Helm** : `helm version` (macOS : `brew install helm`)
- **kubectl** + un **cluster k3d** opérationnel (UC5)

## Dérouler
```bash
# 1) Vérifier le chart (forme + rendu local, RIEN n'est appliqué)
helm lint helm/ecommerce
helm template ecommerce helm/ecommerce -f helm/ecommerce/values-dev.yaml | less

# 2) Installer / mettre à jour en DEV
helm upgrade --install ecommerce helm/ecommerce \
  -n ecommerce --create-namespace -f helm/ecommerce/values-dev.yaml

# 3) Vérifier
helm status ecommerce -n ecommerce
kubectl -n ecommerce get pods,svc,hpa
curl -H "Host: ecommerce.localhost" http://localhost:8080

# 4) Basculer en PREPROD = juste un autre fichier de values
helm upgrade --install ecommerce helm/ecommerce \
  -n ecommerce -f helm/ecommerce/values-preprod.yaml
```

## Nettoyage
```bash
helm uninstall ecommerce -n ecommerce      # ⚠️ retire tout le release (confirmation)
```

> Rappels : `helm lint` + `helm template` (dry-run) **avant** `helm upgrade --install` ; un **seul**
> jeu de templates, les différences d'env vivent dans les `values-<env>.yaml` ; **aucun secret en
> clair**. `env` reste **Development** même en preprod car `/health` et `/alive` ne sont mappés
> qu'en Development dans cette app de démo. Versions, hosts et ressources sont **illustratifs**.
