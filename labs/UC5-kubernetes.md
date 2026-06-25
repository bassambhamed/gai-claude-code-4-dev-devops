# UC5 — Étapes à appliquer (Kubernetes/k3d + skills `k8s-bootstrap` & `k8s-debug-pod`)

Guide pratique à dérouler, de l'installation de **k3d** et **kubectl** (Windows / Linux / macOS)
jusqu'à l'utilisation des skills `/k8s-bootstrap` et `/k8s-debug-pod`, **avec les commandes bash
manuelles** pour **vérifier ce que ces skills font réellement**.

> Objectif : faire créer par Claude Code un **cluster Kubernetes local** avec k3d, y **déployer
> l'`ecommerce-app`** (Deployments, Services, Ingress, probes, HPA), puis **diagnostiquer un pod en
> échec** — et savoir **rejouer à la main** chaque étape pour comprendre — et contrôler — ce que
> Claude exécute.

---

## Kubernetes / k3d en 30 secondes

| Terme | En clair |
|---|---|
| **Kubernetes (K8s)** | l'orchestrateur qui **fait tourner et maintient** des conteneurs sur plusieurs machines. |
| **k3d** | lance un **cluster K8s léger (k3s) dans Docker** — idéal pour un lab local. |
| **kubectl** | la **CLI** pour parler au cluster (créer, lister, inspecter les ressources). |
| **pod** | la plus petite unité déployable (un ou plusieurs conteneurs). |
| **Deployment / Service** | combien de pods + comment les maintenir / une **adresse DNS stable** pour les joindre. |
| **Ingress** | la **porte d'entrée HTTP** depuis l'extérieur. |
| **probe** | test de santé : **readiness** (prêt ?) / **liveness** (vivant ?). |
| **HPA** | autoscaler : ajoute/retire des pods selon la **charge CPU**. |

> Image mentale : **Docker fabrique les conteneurs (UC4) ; Kubernetes les orchestre** — garde le bon
> nombre de pods, redémarre ce qui tombe, répartit le trafic. C'est **déclaratif** (les manifests).

---

## Étape 0 — Pré-requis

Un terminal et **Docker qui tourne** (k3d crée le cluster *dans* Docker). Les **images** de l'app
proviennent de l'**UC4** (`ecommerce-catalog/ordering/gateway/web:latest`). On vérifie tout à l'Étape 2.

---

## Étape 1 — Installer k3d & kubectl (une seule fois, selon ton OS)

### macOS (avec Homebrew)
```bash
brew install k3d kubectl
```

### Linux (Ubuntu/Debian)
```bash
# k3d (script officiel)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# kubectl
sudo snap install kubectl --classic     # ou via le dépôt apt de Kubernetes
```

### Windows
```powershell
winget install k3d.k3d
winget install Kubernetes.kubectl
```
> k3d s'appuie sur **Docker Desktop** (WSL2). Lance Docker avant de créer un cluster.

> 💡 Après l'install, **ferme et rouvre** le terminal pour que `k3d` et `kubectl` soient dans le PATH.

---

## Étape 2 — Vérifier l'installation

```bash
docker info                      # le démon Docker tourne (k3d en a besoin)
k3d version                      # k3d (+ version k3s) → OK
kubectl version --client         # client kubectl → OK
docker images | grep ecommerce   # les images de l'UC4 sont présentes localement
```

**Ce qui se passe :** si `docker info` répond et que `k3d`/`kubectl` affichent leur version,
tout est prêt. Les 4 images `ecommerce-*:latest` doivent apparaître (sinon, refais l'UC4). ✅

---

## Étape 3 — Lancer Claude Code dans le projet

```bash
cd ecommerce-app
claude
```

> Dans la session Claude, on exécute une commande de l'hôte en la préfixant par `!`
> (ex. `!kubectl get nodes`, `!k3d cluster list`). Pratique pour vérifier **sans quitter** Claude.

---

## Étape 4 — Le skill `/k8s-bootstrap` : créer le cluster

Dans la session Claude :
```text
> /k8s-bootstrap crée un cluster k3d "ecommerce" à 3 nœuds avec un registre local et un ingress, puis montre-moi l'état du cluster
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. écrit `k8s/k3d-cluster.yaml` et crée le cluster (`k3d cluster create --config …`) ;
2. vérifie (`kubectl cluster-info`, `kubectl get nodes`) ;
3. importe les images dans le cluster ;
4. applique les manifests (`kubectl apply -f k8s/`) ;
5. vérifie le rollout et l'accès via l'ingress ;
6. **affiche chaque commande avant de l'exécuter** ; confirmation avant toute suppression.

### ✅ Vérifier à la main (lecture seule — après le skill)

Le skill a **déjà créé** le cluster. Ces commandes ne font que **constater** l'état (rejouables sans risque) :

```bash
cat k8s/k3d-cluster.yaml                 # la "recette" du cluster (3 nœuds, registre, ingress)
k3d cluster list                          # le cluster "ecommerce" apparaît
kubectl cluster-info                      # l'API du cluster répond
kubectl get nodes                         # 3 nœuds, tous "Ready"
```

| Commande | Ce qu'elle prouve |
|---|---|
| `cat k8s/k3d-cluster.yaml` | le cluster est **décrit par un fichier** (reproductible). |
| `k3d cluster list` | le cluster `ecommerce` existe bien. |
| `kubectl get nodes` | 3 nœuds `Ready` → le cluster est opérationnel. |

> ⚠️ **Ne relance pas** `k3d cluster create` après le skill : le cluster existe déjà, la commande
> échoue (`Cluster 'ecommerce' already exists!`). C'est précisément la commande **que le skill a
> exécutée** — tu ne la lances toi-même que si tu fais l'étape **à la place** du skill (cluster absent).
> Pour repartir de zéro : `k3d cluster delete ecommerce` puis recréer.

---

## Étape 5 — Déployer l'app : importer les images & appliquer les manifests

Dans Claude :
```text
> importe les images de l'ecommerce-app dans le cluster puis déploie l'app (Deployments, Services, Ingress, probes, HPA)
```
ce qui correspond, **à la main**, à :
```bash
# k3d est isolé : il faut INJECTER les images locales dans le cluster
k3d image import ecommerce-catalog:latest ecommerce-ordering:latest \
  ecommerce-gateway:latest ecommerce-web:latest -c ecommerce

kubectl apply -f k8s/namespace.yaml       # crée le namespace "ecommerce"
kubectl apply -f k8s/                      # Deployments + Services + Ingress + HPA
```

### ✅ Vérifier le déploiement

```bash
kubectl -n ecommerce get pods,svc,hpa     # pods "Running", services et HPA créés
kubectl -n ecommerce rollout status deploy/web        # le rollout du Web est terminé
curl -H "Host: ecommerce.localhost" http://localhost:8080    # le frontend répond
```

| Commande | Ce qu'elle prouve |
|---|---|
| `k3d image import …` | les images locales sont **visibles** par le cluster (sinon `ImagePullBackOff`). |
| `kubectl get pods` | tous les pods passent **Running** et **Ready** (probes OK). |
| `curl -H "Host: …"` | l'**ingress** route bien vers le Web → déploiement réussi. |

> ⚠️ Sans `k3d image import`, les pods restent en **ImagePullBackOff** — c'est l'erreur n°1, qu'on
> diagnostique justement à l'étape suivante.

---

## Étape 6 — Le skill `/k8s-debug-pod` : diagnostiquer un pod en échec

Dans la session Claude :
```text
> /k8s-debug-pod le pod ordering est en CrashLoopBackOff : analyse logs + events + describe et propose un correctif
```

**Ce que le skill fait (selon `SKILL.md`) :** collecte **en lecture seule** l'état, le `describe`,
les logs et les events, formule 1 à 3 **hypothèses de cause racine** classées, puis propose un
**correctif expliqué** — appliqué **seulement après validation**.

### ✅ Vérifier / reproduire à la main

```bash
kubectl -n ecommerce get pods -o wide                 # repérer le statut (CrashLoopBackOff…)
kubectl -n ecommerce describe pod <pod-ordering>      # events, probes, raison du redémarrage
kubectl -n ecommerce logs <pod-ordering> --previous   # logs du conteneur qui a crashé
kubectl -n ecommerce get events --sort-by=.lastTimestamp
```

| Commande | Rôle |
|---|---|
| `get pods -o wide` | le **statut** du pod (et sur quel nœud). |
| `describe pod` | les **events** + l'état des probes + les ressources. |
| `logs --previous` | les logs de l'instance **précédente** (celle qui a planté). |
| `get events` | la chronologie des problèmes du namespace. |

> Garde-fou : le skill **diagnostique d'abord** (lecture seule). Toute correction (`apply`, `scale`,
> `rollout restart`) passe par une **validation humaine**.

---

## Étape 7 — Nettoyage

Dans Claude :
```text
> supprime le cluster k3d
```
ce qui correspond, **à la main**, à :
```bash
kubectl delete -f k8s/                    # (optionnel) retire les ressources de l'app
k3d cluster delete ecommerce              # ⚠️ supprime DÉFINITIVEMENT le cluster
```

> ⚠️ `k3d cluster delete` et `kubectl delete ns` sont **destructifs** : le skill **affiche la
> commande et attend ton accord** avant exécution.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1 | install selon l'OS (`brew` / script / `winget`) | k3d + kubectl installés |
| 2 | `!docker info`, `!k3d version`, `!kubectl version --client` | outils + images UC4 vérifiés |
| 4 | `/k8s-bootstrap …` | `k3d cluster create` + `kubectl get nodes` (3 Ready) |
| 5 | « importe les images puis déploie » | `k3d image import` + `kubectl apply -f k8s/` |
| 5 | (vérif) | `kubectl get pods,svc,hpa` + `curl -H "Host: …"` |
| 6 | `/k8s-debug-pod …` | `describe` + `logs --previous` + `events` → cause racine |
| 7 | « supprime le cluster » | `k3d cluster delete` (avec confirmation) |

> **Message clé :** les skills `k8s-bootstrap` et `k8s-debug-pod` ne sont que des **modes d'emploi**
> traduits en commandes `k3d`/`kubectl`. On peut **tout rejouer à la main** pour comprendre — et les
> actions **destructives** (supprimer le cluster/namespace) restent une **décision humaine**.
> L'IA accélère l'orchestration ; l'ingénieur garde la main.
