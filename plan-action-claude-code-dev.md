# Claude Code pour les Dev / DevOps — Plan d'action & formation

**Public :** ingénieurs Dev et DevOps.
**Format :** atelier pratique, déroulé **en direct dans un terminal** (≈30 % théorie / 70 % labs).
**Fil rouge :** l'app de démo `ecommerce-app` (.NET Aspire — microservices `Catalog`, `Ordering`, `Gateway`, `Web`) que l'on va **conteneuriser, déployer, tester et observer** de bout en bout.
**Pré-requis pédagogique :** avoir suivi `02-claude-code-intro.md` (installation, lancement, commandes de base, préfixes `@ ! # /`).

> **Garde-fous (rappel permanent)**
> - Jamais de **secret** ni de **donnée client** non anonymisée dans un prompt.
> - Les actions **destructives / prod** (`apply`, `destroy`, `delete`, `merge`, `helm upgrade` prod) passent **toujours** par une validation humaine — voir `/permissions` et les **hooks** de garde.
> - L'IA **propose**, l'ingénieur **décide**. Revue humaine systématique de l'IaC générée.

---

## 0. Pré-requis techniques (à installer avant J1)

| Outil | Usage dans la formation | Vérif |
|---|---|---|
| Claude Code | l'agent | `claude --version` · `claude doctor` |
| Git + GitHub CLI (`gh`) | versioning, PR, CI | `git --version` · `gh auth status` |
| Docker / Podman | conteneurs, build images | `docker version` |
| kubectl + **k3d** (ou kind/minikube) | cluster Kubernetes local | `kubectl version --client` · `k3d version` |
| Helm | packaging Kubernetes | `helm version` |
| k6 (Grafana) | load generator | `k6 version` |
| .NET 8 SDK | builder l'app fil rouge | `dotnet --version` |

> Sur poste verrouillé : prévoir un **conteneur / VM bac à sable** avec tous ces outils, pour ne rien installer sur le poste hôte.

---

# Partie A — Maîtriser les briques Claude Code (dans l'ordre)

Progression du plus simple au plus puissant. Chaque brique ajoute une couche d'**automatisation** et de **capitalisation** d'équipe. Ordre recommandé et justification :

| # | Brique | Ce que ça apporte | Pourquoi à ce moment |
|---|---|---|---|
| 1 | **Commandes** (`/…`) | piloter l'agent en session | base, déjà vue en intro |
| 2 | **Skills** (+ sous-agents) | capitaliser une procédure réutilisable | on transforme un bon prompt en actif d'équipe |
| 3 | **Hooks** | automatiser sur événement (déterministe) | on encadre l'agent : garde-fous, formatage, audit |
| 4 | **MCP** | connecter des outils/données externes | on ouvre l'agent sur GitHub, monitoring, BdD… |
| 5 | **Plugins** | packager + distribuer tout le reste | on industrialise et on partage à toute l'équipe |

### A1 — Commandes (`/`)
**Quoi :** instructions en session (`/init`, `/model`, `/plan`, `/permissions`, `/context`, `/diff`, `/review`…).
**Lab express (5 min) :**
```bash
cd ecommerce-app && claude
> /init                 # génère un CLAUDE.md décrivant la stack
> /plan conteneurise le service Catalog (Dockerfile multi-stage) et ajoute un docker-compose
```
**À retenir Dev / DevOps :** `/plan` avant toute action sensible, `/permissions` pour cadrer ce que l'agent peut lancer seul.

### A2 — Skills (compétences réutilisables) + sous-agents
**Quoi :** une procédure d'équipe écrite une fois (Markdown dans `.claude/skills/`) et rejouable par `/<nom>`. Les **sous-agents** (`/agents`) délèguent une tâche à un agent spécialisé (ex. agent « revue de manifests Kubernetes »).
**Lab (15 min) — créer un skill `runbook` :**
```
.claude/skills/restart-service/SKILL.md
```
```markdown
---
name: restart-service
description: Redémarre proprement un microservice de l'ecommerce-app (drain, restart, healthcheck).
---
1. Vérifier l'état du pod/conteneur du service ciblé.
2. Drainer le trafic (scale down progressif ou cordon).
3. Redémarrer, attendre le healthcheck `/health`.
4. Restaurer le trafic, confirmer 200 OK, journaliser l'action.
```
→ utilisable ensuite par `/restart-service ordering-api`.
**Idées de skills Dev / DevOps :** `k8s-bootstrap`, `k8s-debug-pod`, `postmortem`, `load-test`, `ci-pipeline`.

### A3 — Hooks (automatisation déterministe)
**Quoi :** scripts déclenchés **automatiquement** sur un événement d'outil (avant/après un `Bash`, à la fin d'une réponse…). C'est le harnais qui exécute, pas l'IA → idéal pour les **garde-fous**.
**Cas Dev / DevOps à fort intérêt :**
- **Bloquer** toute commande contenant `kubectl delete ns`, `helm uninstall`, `rm -rf` → demande de confirmation.
- **Auto-format** : lancer `hadolint` (Dockerfile) / `helm lint` après chaque édition de conteneur ou de chart.
- **Audit** : logguer chaque commande shell exécutée par l'agent dans un fichier traçable (conformité DORA).
- **Secret-scan** : refuser un commit si `gitleaks` détecte un secret.
**Lab :** `/hooks` pour voir les hooks actifs, puis ajouter un hook `PreToolUse` qui intercepte les commandes destructives.

### A4 — MCP (connecteurs externes)
**Quoi :** le **Model Context Protocol** branche l'agent sur des outils/données externes (GitHub, Atlassian/Jira, bases de données, monitoring, fichiers…). Géré par `/mcp` ou `claude mcp`.
**Connecteurs utiles Dev / DevOps :**
- **GitHub** : issues, PR, Actions, releases.
- **Atlassian (Jira/Confluence)** : tickets d'incident, runbooks.
- **Base de données** (Postgres/SQL Server) : inspecter un schéma, proposer une migration.
- **Observabilité** (selon dispo) : requêter des métriques/logs.
**Lab :** connecter le MCP GitHub puis demander : *« liste les PR ouvertes sur ecommerce-app et résume les changements d'infra »*.
**Sécurité bancaire :** privilégier les modes Enterprise/Business, scoper les permissions, jamais de prod sans validation.

### A5 — Plugins (industrialisation)
**Quoi :** un **plugin** package ensemble commandes + skills + hooks + serveurs MCP + sous-agents, et se distribue via un **marketplace** interne. C'est le moyen de **standardiser** l'usage sur toute l'équipe Dev / DevOps.
**Lab :** `/plugin` pour explorer ; concevoir le plugin **« ODDO-DevOps-Toolkit »** qui embarque les skills `k8s-bootstrap`, `k8s-debug-pod`, `postmortem`, les hooks de garde et le MCP GitHub. Livrable de fin de formation.

---

# Partie B — Cas d'usage Dev / DevOps (labs progressifs)

Chaque lab = **objectif · briques Claude Code mobilisées · prompts types · livrable · garde-fous**. Les blocs s'enchaînent et alimentent le **capstone** (Partie C).

## Bloc 1 — Code, collaboration & qualité

### UC1 — Git & GitHub
- **Objectif :** workflow Git assisté + automatisation GitHub.
- **Briques :** commandes (`/diff`, `/review`), MCP GitHub, hook secret-scan.
- **Prompts :** *« crée une branche `feat/healthcheck`, génère un message de commit conventionnel, ouvre une PR avec description et checklist »* ; *« résume cette PR et signale les risques d'infra »*.
- **Livrable :** PR propre + template de PR + hook anti-secret.

### UC2 — CI/CD
- **Objectif :** pipeline de build/test/scan/déploiement.
- **Briques :** skill `ci-pipeline`, MCP GitHub (Actions).
- **Prompts :** *« génère un workflow GitHub Actions : build .NET, tests, scan Trivy de l'image, push GHCR, déploiement sur le cluster k3d »* ; *« ajoute un gate manuel avant l'étape prod »*.
- **Livrable :** `.github/workflows/ci.yml` + `cd.yml` avec gating.
- **Garde-fous :** environnement prod protégé, déploiement = action validée.

### UC3 — Tests
- **Objectif :** tests unitaires/intégration + tests d'infra.
- **Briques :** sous-agent « tests », `/code-review`.
- **Prompts :** *« génère des tests xUnit pour Catalog.Api et des tests d'intégration Testcontainers (Postgres) »* ; *« écris des tests de contrat entre Gateway et Ordering »*.
- **Livrable :** suite de tests + couverture ciblée.

## Bloc 2 — Conteneurs & orchestration

### UC4 — Docker / images
- **Objectif :** conteneuriser les microservices proprement.
- **Briques :** commandes, hook scan d'image.
- **Prompts :** *« écris des Dockerfiles multi-stage pour Catalog/Ordering/Gateway, non-root, image distroless, et un docker-compose pour le dev »* ; *« réduis la taille de l'image et corrige les findings Trivy »*.
- **Livrable :** Dockerfiles optimisés + `docker-compose.yml`.

### UC5 — Création d'un cluster Kubernetes
- **Objectif :** cluster local k3d/kind opérationnel.
- **Briques :** skill `k8s-bootstrap`, sous-agent `k8s-debug-pod`.
- **Prompts :** *« crée un cluster k3d à 3 nœuds avec un registre local et un ingress »* ; *« déploie l'ecommerce-app : Deployments, Services, Ingress, probes liveness/readiness, HPA »* ; *« le pod ordering-api crashe : analyse logs + events + describe et propose un correctif »*.
- **Livrable :** cluster + manifests + diagnostic de pod.

### UC6 — Helm / packaging
- **Objectif :** packager le déploiement.
- **Briques :** skill, `/code-review` sur les charts.
- **Prompts :** *« transforme ces manifests en chart Helm paramétrable (values par environnement dev/preprod) »*.
- **Livrable :** chart Helm + values multi-env.

## Bloc 3 — Données & application

### UC7 — Création de base de données
- **Objectif :** schéma, migrations, données de seed.
- **Briques :** MCP base de données, sous-agent SQL.
- **Prompts :** *« conçois le schéma Postgres du Catalog (produits, catégories, stock), génère les migrations EF Core et un jeu de données de seed anonymisé »* ; *« optimise cette requête et lis son plan d'exécution »*.
- **Livrable :** migrations + schéma + seed.

### UC8 — UI / frontend à améliorer
- **Objectif :** améliorer l'IHM de l'app (`ECommerce.Web`).
- **Briques :** commandes, skill `artifact-design`, `/code-review`.
- **Prompts :** *« modernise la page catalogue : responsive, états de chargement, accessibilité (a11y), et propose une maquette »* ; *« améliore le tableau de bord ops (santé des services) »*.
- **Livrable :** UI améliorée + capture/artifact de la maquette.

## Bloc 4 — Performance & fiabilité

### UC9 — Load generator (test de charge)
- **Objectif :** générer de la charge et trouver les limites.
- **Briques :** skill `load-test`, MCP observabilité.
- **Prompts :** *« écris un scénario k6 qui monte à 500 VUs sur l'API Catalog avec paliers, seuils p95 < 300 ms, et exporte les métriques »* ; *« analyse ce rapport k6 et identifie le goulot »*.
- **Livrable :** scénario k6 + rapport + analyse.

### UC10 — Observabilité
- **Objectif :** métriques, logs, traces, dashboards, alerting.
- **Briques :** skill, MCP observabilité.
- **Prompts :** *« déploie Prometheus + Grafana sur le cluster, génère un dashboard pour l'app, des requêtes PromQL et des règles d'alerte (latence, taux d'erreur, saturation) »*.
- **Livrable :** dashboards + alertes + requêtes (PromQL/Loki).

### UC11 — Gestion d'incident & analyse de logs
- **Objectif :** triage, cause racine, post-mortem.
- **Briques :** skill `postmortem`, MCP Jira, hook audit.
- **Prompts :** *« voici 50k lignes de logs : clusterise les erreurs, propose 3 hypothèses de cause racine classées »* ; *« rédige un post-mortem blameless à partir de cette timeline »*.
- **Livrable :** runbook + template post-mortem.
- **Garde-fous :** en astreinte, **aucune action destructive** sans validation humaine.

### Use cases additionnels (bonus / approfondissement)
- **Networking** : génération de configs Nginx/HAProxy, règles firewall, certificats TLS (cert-manager).
- **Backup & restore** : scripts/CronJobs de sauvegarde BdD + procédure de restauration testée.
- **GitOps** : structuration repo ArgoCD/Flux (app-of-apps), promotion entre environnements.
- **Migration** : aide à la modernisation d'une charge VMware vers OpenShift/Kubernetes.
- **FinOps** : analyse de coûts cloud et suggestions d'optimisation.
- **Capacity planning** : modélisation de capacité à partir de profils de perf.
- **Documentation** : génération de runbooks, ADR, diagrammes d'architecture (Mermaid).

---

# Partie C — Capstone end-to-end (fil rouge complet)

**Objectif :** enchaîner les briques pour livrer l'`ecommerce-app` de la conteneurisation à la prod observée, en n'utilisant que Claude Code + les skills/hooks/MCP construits.

1. **Conteneuriser** (UC4) puis créer le **cluster Kubernetes** (UC5) et packager en **Helm** (UC6).
2. **Base de données** + migrations + seed anonymisé (UC7).
3. **Déployer** via **CI/CD** GitHub Actions (UC2) avec gate manuel.
4. **Tester** : unitaires/intégration (UC3) + **charge k6** (UC9).
5. **Observer** : Prometheus/Grafana + alerting (UC10).
6. **Simuler un incident**, diagnostiquer et produire un **post-mortem** (UC11).
7. **Packager** le tout dans le **plugin ODDO-DevOps-Toolkit** (A5) et le partager.

**Restitution :** chaque binôme présente sa chaîne, ses garde-fous (hooks), et 3 cas d'usage prioritaires + KPI fiabilité (DORA) (MTTR, MTTD, change failure rate) + plan 30/60/90 jours.

---


