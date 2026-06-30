#!/usr/bin/env bash
# Prouve, à partir de .claude/run/timeline.log, qu'au moins deux agents ont travaillé EN MÊME
# TEMPS (intervalles START..END qui se chevauchent).
# Format de chaque ligne : "<agent> <START|END> <epoch_seconds>"
# Usage : bash .claude/run/verify-parallel.sh [chemin/timeline.log]
set -euo pipefail
LOG="${1:-$(cd "$(dirname "$0")" && pwd)/timeline.log}"

[ -f "$LOG" ] || { echo "❌ Journal introuvable : $LOG (lance d'abord l'orchestration)"; exit 1; }

echo "── Journal des agents ($LOG) ──"; sort -k3 -n "$LOG"; echo
agents=$(awk 'NF>=3{print $1}' "$LOG" | sort -u)
n=$(printf '%s\n' "$agents" | sed '/^$/d' | wc -l | tr -d ' ')
[ "$n" -ge 2 ] || { echo "❌ Moins de deux agents ont journalisé."; exit 1; }
now=$(date +%s)
field() { local v; v=$(awk -v a="$1" -v t="$2" '$1==a && $2==t {print $3}' "$LOG" | sort -n);
          if [ "$3" = head ]; then printf '%s\n' "$v" | head -1; else printf '%s\n' "$v" | tail -1; fi; }
overlap=0
for a in $agents; do for b in $agents; do
  [[ "$a" < "$b" ]] || continue
  aS=$(field "$a" START head); aE=$(field "$a" END tail); aE=${aE:-$now}
  bS=$(field "$b" START head); bE=$(field "$b" END tail); bE=${bE:-$now}
  [ -n "$aS" ] && [ -n "$bS" ] || continue
  if [ "$aS" -lt "$bE" ] && [ "$bS" -lt "$aE" ]; then
    s=$(( aS > bS ? aS : bS )); e=$(( aE < bE ? aE : bE )); d=$(( e > s ? e - s : 0 ))
    echo "✅ CHEVAUCHEMENT : '$a' et '$b' ont tourné EN MÊME TEMPS pendant ${d}s."; overlap=1
  fi
done; done
echo
if [ "$overlap" -eq 1 ]; then
  echo "✅ Preuve établie : au moins deux sous-agents ont travaillé SIMULTANÉMENT."; exit 0
else
  echo "⚠️ Aucun chevauchement : exécution séquentielle. Relance en exigeant 3 appels Task dans UN message."; exit 2
fi
