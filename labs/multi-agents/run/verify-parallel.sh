#!/usr/bin/env bash
# verify-parallel.sh — prouve, à partir de run/timeline.log, qu'au moins deux agents
# ont travaillé EN MÊME TEMPS (intervalles START..END qui se chevauchent).
#
# Format attendu de chaque ligne du journal : "<agent> <START|END> <epoch_seconds>"
# Exemple : feature-builder START 1751142601
#           quality-gate    START 1751142603
#           quality-gate    END   1751142690
#           feature-builder END   1751142720
#
# Usage : bash labs/multi-agents/run/verify-parallel.sh [chemin/timeline.log]

set -euo pipefail

LOG="${1:-$(cd "$(dirname "$0")" && pwd)/timeline.log}"

if [ ! -f "$LOG" ]; then
  echo "❌ Aucun journal trouvé : $LOG"
  echo "   Lance d'abord le scénario (étape 3) : les sous-agents y écrivent leurs horodatages."
  exit 1
fi

echo "── Journal des agents ($LOG) ──"
sort -k3 -n "$LOG"
echo

agents=$(awk 'NF>=3{print $1}' "$LOG" | sort -u)
n=$(printf '%s\n' "$agents" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$n" -lt 2 ]; then
  echo "❌ Moins de deux agents ont journalisé — impossible de prouver une exécution simultanée."
  exit 1
fi

now=$(date +%s)

# field <agent> <START|END> <head|tail>
field() {
  local val
  val=$(awk -v a="$1" -v t="$2" '$1==a && $2==t {print $3}' "$LOG" | sort -n)
  if [ "$3" = head ]; then printf '%s\n' "$val" | head -1; else printf '%s\n' "$val" | tail -1; fi
}

overlap=0
for a in $agents; do
  for b in $agents; do
    [[ "$a" < "$b" ]] || continue          # chaque paire une seule fois
    aS=$(field "$a" START head); aE=$(field "$a" END tail); aE=${aE:-$now}
    bS=$(field "$b" START head); bE=$(field "$b" END tail); bE=${bE:-$now}
    [ -n "$aS" ] && [ -n "$bS" ] || continue
    if [ "$aS" -lt "$bE" ] && [ "$bS" -lt "$aE" ]; then
      s=$(( aS > bS ? aS : bS )); e=$(( aE < bE ? aE : bE ))
      d=$(( e > s ? e - s : 0 ))
      echo "✅ CHEVAUCHEMENT : '$a' et '$b' ont tourné EN MÊME TEMPS pendant ${d}s."
      overlap=1
    fi
  done
done

echo
if [ "$overlap" -eq 1 ]; then
  echo "✅ Preuve établie : au moins deux sous-agents ont travaillé SIMULTANÉMENT."
  exit 0
else
  echo "⚠️ Aucun chevauchement détecté : les agents se sont succédé (exécution séquentielle)."
  echo "   → Relance en demandant à l'orchestrateur d'émettre les DEUX appels Task dans le MÊME message."
  exit 2
fi
