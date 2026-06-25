# UC2 — CI/CD avec GitHub Actions (skill `ci-pipeline`)

Guide pratique à dérouler, de la branche de travail jusqu'au **pipeline qui tourne sur la PR**,
**avec les commandes bash manuelles** pour **vérifier ce que le skill fait réellement**.

> **Ce qu'on développe dans ce lab :** on génère, avec le skill `ci-pipeline`, deux workflows
> GitHub Actions pour l'`ecommerce-app` :
> - un **CI** (`ci.yml`) qui, à chaque push/PR, **compile → teste → scanne l'image (Trivy)** ;
> - un **CD** (`cd.yml`) qui **déploie** automatiquement en **pré-prod**, puis en **production**
>   uniquement **après approbation humaine** (un *gate*).
>
> On apprend aussi à **lire** chaque workflow et à **ranger les secrets** hors du YAML.

> **Garde-fou central :** aucune mise en production sans **validation explicite** (environnement
> protégé + approbation).

> Suite de **UC1** : le dépôt Git et le repo GitHub existent déjà.

---

## CI/CD en 30 secondes

| Terme | En clair |
|---|---|
| **CI** (intégration continue) | à chaque changement : **compile + teste + scanne** automatiquement. |
| **CD** (déploiement continu) | **déploie** le résultat (pré-prod auto, puis prod). |
| **workflow** | un fichier **YAML** dans `.github/workflows/` décrivant les étapes. |
| **job** | un groupe d'étapes exécuté sur un runner (machine éphémère). |
| **gate** | un **point d'arrêt** qui exige une **approbation humaine** avant la prod. |
| **Trivy** | un scanner qui détecte les **vulnérabilités** d'une image Docker. |
| **GitHub Secrets** | coffre pour les valeurs sensibles (jamais en clair dans le YAML). |

> Image mentale : **je pousse → GitHub vérifie tout seul (CI) → si tout est vert, il déploie (CD),
> mais s'arrête et demande mon autorisation avant la PROD.**

---

## Étape 0 — Pré-requis

UC1 terminé : dépôt initialisé + repo GitHub relié. **Aucun outil local supplémentaire à installer**
— le pipeline s'exécute **sur GitHub** (runners hébergés). On a juste besoin de `git` + `gh` (UC1).

---

## Étape 1 — Vérifier l'environnement (les 3 OS utilisent `gh`)

```bash
cd ecommerce-app
gh --version          # GitHub CLI dispo (installée en UC1 : brew / apt / winget)
gh auth status        # connecté à GitHub
git remote -v         # le repo distant 'origin' est bien là
```

**Ce qui se passe :** si `gh auth status` et `git remote -v` répondent, le repo est prêt à
recevoir des workflows. ✅

---

## Étape 2 — Lancer Claude Code & vérifier le skill

```bash
claude
```
```text
> /skills        # 'ci-pipeline' doit apparaître dans la liste
```

> 💡 Si le skill manque, **quitte et relance `claude`** : les skills sont chargés au démarrage.
> Dans la session, `!gh run list` exécute la commande sur l'hôte sans quitter Claude.

---

## Étape 3 — Se placer sur une branche de travail

On ne travaille **jamais** sur `main`.
```text
> crée une branche feat/ci-cd-pipeline
```
ce qui correspond, **à la main**, à :
```bash
git switch -c feat/ci-cd-pipeline
```
### ✅ Vérifier
```bash
git branch --show-current        # feat/ci-cd-pipeline
```

---

## Étape 4 — Le skill `/ci-pipeline` : générer les workflows

```text
> /ci-pipeline génère le CI (build, tests, scan Trivy) et le CD (pré-prod auto + prod avec gate) pour l'ecommerce-app
```

**Ce que le skill fait (selon `SKILL.md`) :** crée `.github/workflows/ci.yml` et `cd.yml`,
**explique chaque étape**, et range toute valeur sensible dans des **GitHub Secrets**.

### ✅ Vérifier à la main (lecture seule)
```bash
ls .github/workflows/            # ci.yml et cd.yml présents
cat .github/workflows/ci.yml     # relire le CI
cat .github/workflows/cd.yml     # relire le CD
```
```text
> /diff                          # relecture des deux workflows avant commit
```

---

## Étape 5 — Comprendre le CI — `.github/workflows/ci.yml`

| Bloc | Rôle |
|---|---|
| `on: push / pull_request` (`main`) | déclenche le pipeline à chaque changement. |
| job `build-test` | `checkout` → `setup-dotnet` → `restore` → `build` (Release) → `test`. |
| job `image-scan` (`needs: build-test`) | ne tourne **que si** le build/test a réussi. |
| `docker build` | construit l'image du service Catalog. |
| `trivy-action` (`CRITICAL,HIGH`, `exit-code: 1`) | **échoue** la chaîne si une faille critique est trouvée. |

> Point clé : `needs:` crée une **dépendance** — la sécurité ne tourne pas si le code ne compile même pas.

---

## Étape 6 — Comprendre le CD — `.github/workflows/cd.yml`

| Bloc | Rôle |
|---|---|
| `on: workflow_run … CI … completed` | se déclenche **après** un CI terminé sur `main`. |
| `if: …conclusion == 'success'` | ne déploie **que** si le CI a réussi. |
| job `deploy-preprod` (`environment: preprod`) | déploiement **automatique** en pré-prod. |
| job `deploy-prod` (`environment: production`) | déploiement **prod**, derrière un **gate**. |
| `needs: deploy-preprod` | la prod attend que la pré-prod soit passée. |

### Activer le gate manuel (côté GitHub)

1. Repo GitHub → **Settings** → **Environments** → créer `production`.
2. Cocher **Required reviewers** et s'ajouter comme approbateur.
3. Désormais le job `deploy-prod` **se met en pause** et attend une **approbation humaine**.

> ⚠️ **Pas d'option « Required reviewers » ?** Les règles de protection d'environnement ne sont
> **pas disponibles sur un dépôt privé en plan gratuit** : il faut un dépôt **public** (tous les
> plans) **ou** privé en plan **GitHub Pro / Team / Enterprise**. Le repo UC1 ayant été créé en
> `--private`, le plus simple pour la démo est de le rendre public :
> ```bash
> gh repo edit --visibility public --accept-visibility-change-consequences
> ```

> Le garde-fou central : **aucune mise en prod sans validation explicite.**

---

## Étape 7 — Les secrets, jamais en clair

Un mot de passe / token (registre Docker, kubeconfig…) ne s'écrit **jamais** dans le YAML.
On le range dans **Settings → Secrets and variables → Actions**, puis on le référence :

```yaml
password: ${{ secrets.REGISTRY_PASSWORD }}
```
```text
> repère toute valeur sensible dans mes workflows et remplace-la par un GitHub Secret
```
### ✅ Vérifier qu'il ne reste aucun secret en clair
```bash
grep -nE "password|token|secret|api[_-]?key" .github/workflows/*.yml
# attendu : uniquement des références ${{ secrets.XXX }}, aucune valeur en dur
```

---

## Étape 8 — Commiter et voir le pipeline tourner

```text
> /git-commit        # commit propre des nouveaux workflows (skill UC1)
> /open-pr           # pousse la branche + ouvre la PR ; le CI se lance dessus
```

### ✅ Vérifier l'exécution du pipeline
```bash
gh pr checks                    # statut des checks (CI) de la PR courante
gh run list --limit 5          # les dernières exécutions de workflows
gh run view --log              # logs détaillés de la dernière exécution
```

En cas d'échec :
```text
> le job image-scan a échoué : lis les logs de la dernière exécution et propose un correctif
```

> Rappel garde-fous : `/git-commit` et `/open-pr` **demandent toujours validation** avant
> `commit`/`push`, et ne **mergent jamais** automatiquement.

---

## Récapitulatif — du skill à la commande

| Étape | Dans Claude | Ce que ça fait (vérifiable à la main) |
|---|---|---|
| 1 | `gh auth status`, `git remote -v` | pré-requis UC1 OK |
| 2 | `/skills` | `ci-pipeline` disponible |
| 3 | « crée une branche feat/… » | `git switch -c` |
| 4 | `/ci-pipeline …` | `ci.yml` + `cd.yml` créés (vérif : `ls`/`cat`/`/diff`) |
| 5–6 | lecture des workflows | comprendre CI (`needs`) et CD (gate) |
| 7 | « remplace les valeurs sensibles » | `grep` → aucun secret en clair |
| (GitHub) | Settings → Environments → `production` | gate = approbation humaine |
| 8 | `/git-commit` puis `/open-pr` | CI se lance (vérif : `gh pr checks`, `gh run view`) |

> **Message clé :** Claude Code écrit et explique vos pipelines, mais la **mise en production
> reste une décision humaine** (environnement protégé + approbation).
