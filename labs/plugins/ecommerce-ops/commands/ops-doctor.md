---
description: Check santé de l'environnement Ops (outils installés, cluster k3d, état des pods de l'ecommerce-app).
---

# /ops-doctor — diagnostic d'environnement Ops

Fais un état des lieux **en lecture seule** et présente un tableau de synthèse (✅ / ⚠️ / ❌).

1. **Outils** — versions de : `docker`, `k3d`, `kubectl`, `trivy`, `dotnet`
   (rappel : `export PATH="/usr/local/share/dotnet:$PATH"` si `dotnet` est introuvable).
2. **Cluster** — `kubectl cluster-info` et `kubectl get nodes` (tous `Ready` ?).
3. **App** — `kubectl -n ecommerce get pods,svc,ingress,hpa` : pods `Running`/`Ready`,
   redémarrages anormaux, HPA.
4. **Santé** — `curl` l'endpoint `/health` via l'ingress si l'app est déployée.

Termine par : ce qui est OK, ce qui manque, et la prochaine action recommandée
(ex. lancer `/ship` ou le skill `k8s-debug-pod`). N'applique aucune modification.
