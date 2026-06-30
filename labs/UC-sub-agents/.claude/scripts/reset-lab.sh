#!/usr/bin/env bash
# reset-lab.sh — remet la copie de travail ecommerce-app à plat AVANT la démo multi-agents.
# PRÉSERVE : le code (src/**/*.cs), les tests, *.csproj, ECommerce.slnx, et le système
# multi-agents (agents, commands, les 4 skills + scripts de garde, run/). Ne touche JAMAIS labs/.
# Par défaut : DRY-RUN. Ajoute --yes pour exécuter. Docker/k8s ciblés "ecommerce|lab" (pas de prune global).
set -euo pipefail

DRY=1
case "${1:-}" in --yes|-y) DRY=0 ;; "") ;; *) echo "Usage: $0 [--yes]"; exit 2 ;; esac

# Garde-fous d'emplacement : jamais dans labs/, toujours à la racine de l'app.
case "$PWD" in
  */labs/*|*/labs) echo "❌ Refus : tu es dans labs/ (corrigés). Lance depuis la copie de travail ecommerce-app/."; exit 1 ;;
esac
[ -f ECommerce.slnx ] || { echo "❌ ECommerce.slnx introuvable. Place-toi à la racine de ecommerce-app/."; exit 1; }

act(){ if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else echo "  + $*"; eval "$@"; fi; }
hdr(){ printf '\n── %s ──\n' "$*"; }

# Système multi-agents à CONSERVER (ne pas supprimer)
KEEP_SKILLS=" codescene-blockers csharp-refactoring dotnet-test-runner docker-ci-review "
KEEP_SCRIPTS=" guard-src-only.sh guard-infra-only.sh validate-readonly.sh reset-lab.sh "

hdr "1) Skills hérités des UC précédents (le système multi-agents est conservé)"
if [ -d .claude/skills ]; then
  for d in .claude/skills/*/; do
    [ -e "$d" ] || continue
    n="$(basename "$d")"
    case "$KEEP_SKILLS" in *" $n "*) echo "  = garde $n"; continue ;; esac
    act "rm -rf '$d'"
  done
fi

hdr "2) Hooks & scripts hérités"
[ -d .claude/hooks ] && act "rm -rf .claude/hooks" || true
if [ -d .claude/scripts ]; then
  for f in .claude/scripts/*; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    case "$KEEP_SCRIPTS" in *" $n "*) echo "  = garde $n"; continue ;; esac
    act "rm -f '$f'"
  done
fi
[ -f .claude/settings.json ] && act "mv .claude/settings.json .claude/settings.json.bak" || true

hdr "3) Dockerfiles & docker-compose (le code src/**/*.cs reste intact)"
if [ -d src ]; then
  while IFS= read -r f; do act "rm -f '$f'"; done < <(find src -name Dockerfile 2>/dev/null)
fi
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [ -f "$f" ] && act "rm -f '$f'" || true
done

hdr "4) Images & conteneurs Docker 'ecommerce-*' (ciblé — pas de prune global)"
if command -v docker >/dev/null 2>&1; then
  ids="$(docker ps -aq --filter 'name=ecommerce' 2>/dev/null || true)"
  [ -n "$ids" ] && act "docker rm -f $ids" || echo "  (aucun conteneur ecommerce)"
  imgs="$(docker images 'ecommerce-*' -q 2>/dev/null | sort -u || true)"
  [ -n "$imgs" ] && act "docker rmi -f $imgs" || echo "  (aucune image ecommerce-*)"
else
  echo "  (docker absent — ignoré)"
fi

hdr "5) Kubernetes — namespaces & clusters k3d 'ecommerce|lab' (ciblé)"
if command -v kubectl >/dev/null 2>&1; then
  ns="$(kubectl get ns -o name 2>/dev/null | grep -iE 'ecommerce|lab' || true)"
  [ -n "$ns" ] && act "kubectl delete $ns" || echo "  (aucun namespace ecommerce|lab)"
fi
if command -v k3d >/dev/null 2>&1; then
  for c in $(k3d cluster list 2>/dev/null | awk 'NR>1{print $1}' | grep -iE 'ecommerce|lab' || true); do
    act "k3d cluster delete '$c'"
  done
fi

printf '\n'
if [ "$DRY" -eq 1 ]; then
  echo "ℹ️  DRY-RUN — rien supprimé. Pour exécuter : bash .claude/scripts/reset-lab.sh --yes"
else
  echo "✅ Nettoyage terminé. Code, tests et système multi-agents préservés ; labs/ intact."
fi
