# UC6 — Étapes à appliquer (Helm + skill `helm-package`)

Guide pratique à dérouler, de l'installation de **Helm** (Windows / Linux / macOS) jusqu'à
l'utilisation du skill `/helm-package`, **avec les commandes bash manuelles** pour **vérifier ce que
ce skill fait réellement**.

> Objectif : faire transformer par Claude Code les **manifests Kubernetes de l'UC5** en un **chart
> Helm paramétrable** (values dev / preprod), puis déployer l'`ecommerce-app` via
> `helm upgrade --install` (skill `helm-package`) — et savoir **rejouer à la main** chaque étape
> pour comprendre — et contrôler — ce que Claude exécute.

---

## Helm en 30 secondes

| Terme | En clair |
|---|---|
| **Helm** | le **gestionnaire de paquets** de Kubernetes (comme `apt` pour Ubuntu). |
| **chart** | un **paquet** : des templates de manifests + des valeurs paramétrables. |
| **template** | un manifest K8s avec des **trous** (`{{ .Values.xxx }}`) remplis au déploiement. |
| **values** | les **valeurs** qui remplissent les trous (image, réplicas, ressources, host…). |
| **release** | une **instance installée** d'un chart dans le cluster (ici nommée `ecommerce`). |
| **`helm template`** | rend les manifests **en local** pour les lire — sans rien appliquer (dry-run). |
| **`helm upgrade --install`** | installe **ou** met à jour la release (idempotent). |

> Image mentale : en UC5 on écrivait **un manifest par service, en dur**. Avec Helm : **un seul** jeu
> de templates + **un fichier de values par environnement**. Changer d'env = changer de values.

---

## Étape 0 — Pré-requis

Un terminal, un **cluster k3d** opérationnel (UC5) et les **images** importées (UC4). On vérifie
tout à l'Étape 2. Helm **remplace** les `kubectl apply -f k8s/` de l'UC5 par un déploiement paramétré.

---

## Étape 1 — Installer Helm (une seule fois, selon ton OS)

### macOS (avec Homebrew)
```bash
brew install helm
```

### Linux (Ubuntu/Debian)
```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | \
  sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update && sudo apt install helm
```
> Alternative universelle : `curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`

### Windows
```powershell
winget install Helm.Helm
```
> Ou avec Chocolatey : `choco install kubernetes-helm`.

> 💡 Après l'install, **ferme et rouvre** le terminal pour que `helm` soit dans le PATH.

---

## Étape 2 — Vérifier l'installation

```bash
helm version                       # version de Helm → l'install est OK
kubectl get nodes                  # le cluster k3d (UC5) répond et les nœuds sont "Ready"
```

**Ce qui se passe :** `helm version` confirme le binaire ; `kubectl get nodes` confirme que le
cluster cible est joignable (sinon, relance l'UC5). ✅

---

## Étape 3 — Lancer Claude Code dans le projet

```bash
cd ecommerce-app
claude
```

> Dans la session Claude, on exécute une commande de l'hôte en la préfixant par `!`
> (ex. `!helm list -n ecommerce`, `!kubectl get pods -n ecommerce`). Pratique pour vérifier
> **sans quitter** Claude.

---

## Étape 4 — Le skill `/helm-package` : générer le chart

Dans la session Claude :
```text
> /helm-package transforme les manifests k8s/ en un chart Helm paramétrable, avec des values dev et preprod
```

**Ce que le skill fait (selon `SKILL.md`) :**
1. identifie ce qui **varie** par env (image, réplicas, ressources, host, autoscaling) ;
2. crée `helm/ecommerce/` : `Chart.yaml`, `values.yaml`, `templates/` (resources paramétrées) ;
3. externalise les variations dans `values-dev.yaml` / `values-preprod.yaml` ;
4. valide avec `helm lint` + `helm template` (dry-run) ;
5. **ne déploie rien** sans validation ; recommande un `/code-review` des templates.

### ✅ Vérifier à la main (lecture seule)

```bash
cat helm/ecommerce/Chart.yaml
cat helm/ecommerce/values.yaml          # la liste des services (le cœur du paramétrage)
cat helm/ecommerce/values-dev.yaml      # ce qui change en dev
cat helm/ecommerce/values-preprod.yaml  # ce qui change en preprod
ls helm/ecommerce/templates/            # deployment / service / hpa / ingress / _helpers
```

| Fichier | Ce qu'il prouve |
|---|---|
| `values.yaml` | les services sont **listés une fois** ; les templates **bouclent** dessus. |
| `values-<env>.yaml` | les différences d'env sont **isolées** (pas de copier-coller de YAML). |
| `templates/deployment.yaml` | **un seul** template génère les 4 Deployments (`range`). |

---

## Étape 5 — Valider le chart (dry-run : `lint` + `template`)

Dans Claude :
```text
> vérifie le chart puis montre-moi le rendu pour l'environnement dev
```
ce qui correspond, **à la main**, à :
```bash
helm lint helm/ecommerce                                            # forme + bonnes pratiques
helm template ecommerce helm/ecommerce -f helm/ecommerce/values-dev.yaml | less   # rendu LOCAL
```

| Commande | Rôle |
|---|---|
| `helm lint` | détecte les **erreurs de chart** (templates invalides, valeurs manquantes). |
| `helm template … -f values-dev.yaml` | **rend** les manifests finaux pour les **lire** — rien d'appliqué. |

> Ces deux commandes sont en **lecture seule** (aucun envoi au cluster) → rejouables sans risque.
> C'est le dry-run de Helm, équivalent d'un `terraform plan` ou d'un `--check` Ansible.

---

## Étape 6 — Déployer en dev (`helm upgrade --install`)

Dans Claude :
```text
> installe le chart en dev sur le cluster
```
ce qui correspond, **à la main**, à :
```bash
helm upgrade --install ecommerce helm/ecommerce \
  -n ecommerce --create-namespace -f helm/ecommerce/values-dev.yaml
```

### ✅ Vérifier le déploiement (lecture seule)

```bash
helm list -n ecommerce                         # la release "ecommerce" est déployée
helm status ecommerce -n ecommerce             # révision + ressources
kubectl -n ecommerce get pods,svc,hpa          # pods "Running", services et HPA créés
curl -H "Host: ecommerce.localhost" http://localhost:8080      # le frontend répond
```

| Commande | Ce qu'elle prouve |
|---|---|
| `helm list` / `status` | la **release** existe et sa dernière révision a réussi. |
| `kubectl get pods,svc,hpa` | les ressources du chart sont bien créées. |
| `curl -H "Host: …"` | l'ingress route vers le Web → déploiement réussi. |

> `helm upgrade --install` est **idempotent** : relancer après un changement de values applique
> juste le **delta**. C'est sûr à rejouer (contrairement à une création de cluster, cf. UC5).

---

## Étape 7 — Multi-environnement : un seul chart, plusieurs values

Dans Claude :
```text
> redéploie la même app en preprod
```
ce qui correspond, **à la main**, à :
```bash
helm upgrade --install ecommerce helm/ecommerce \
  -n ecommerce -f helm/ecommerce/values-preprod.yaml
```

### ✅ Vérifier la différence (lecture seule)

```bash
# Comparer le rendu des deux environnements SANS rien appliquer
helm template ecommerce helm/ecommerce -f helm/ecommerce/values-dev.yaml     | grep -E "replicas|host:"
helm template ecommerce helm/ecommerce -f helm/ecommerce/values-preprod.yaml | grep -E "replicas|host:"
```

> Helm **fusionne en profondeur** `values.yaml` + `values-<env>.yaml` : on ne surcharge que ce qui
> change (réplicas, ressources, autoscaling, host), le reste est **hérité**. Zéro duplication.
>
> ⚠️ Dans cette app, `env` reste **Development** même en preprod : `/health` et `/alive` ne sont
> mappés qu'en Development (`MapDefaultEndpoints`).

---

## Étape 8 — Revue & nettoyage

Dans Claude :
```text
> /code-review fais une revue des templates Helm (sécurité, valeurs en dur, bonnes pratiques)
```

Nettoyage **à la main** :
```bash
helm uninstall ecommerce -n ecommerce          # ⚠️ retire toute la release (confirmation)
```

> ⚠️ `helm uninstall` et `helm rollback` sont **destructifs** : le skill **affiche la commande et
> attend ton accord** avant exécution.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1 | install selon l'OS (`brew` / `apt` / `winget`) | Helm installé |
| 2 | `!helm version`, `!kubectl get nodes` | Helm + cluster vérifiés |
| 4 | `/helm-package …` | chart `helm/ecommerce/` + values dev/preprod (vérif : `cat`) |
| 5 | « vérifie le chart, montre le rendu dev » | `helm lint` + `helm template` (lecture seule) |
| 6 | « installe en dev » | `helm upgrade --install … -f values-dev.yaml` (vérif : `helm status`, `kubectl get`) |
| 7 | « redéploie en preprod » | même chart, `-f values-preprod.yaml` |
| 8 | `/code-review …` puis « désinstalle » | revue des templates ; `helm uninstall` (confirmation) |

> **Message clé :** le skill `helm-package` n'est qu'un **mode d'emploi** traduit en commandes
> `helm`. On peut **tout rejouer à la main** pour comprendre — `lint`/`template` en lecture seule,
> `upgrade --install` idempotent — et les actions **destructives** (`uninstall`, `rollback`) restent
> une **décision humaine**. L'IA accélère le packaging ; l'ingénieur garde la main.
