#!/usr/bin/env bash
# Hook PreToolUse(Bash) — demande une confirmation explicite avant une commande Ops destructive.
# Reçoit l'appel d'outil en JSON sur stdin.
#
# Plutôt que de bloquer sèchement (exit 2), on renvoie une décision "ask" au harnais :
# l'utilisateur garde la main et valide (ou non) la commande dangereuse.
# Doc du format : hookSpecificOutput.permissionDecision = allow | deny | ask

set -euo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | grep -o '"command"[^,]*' | head -1 || true)"

# Commandes Ops irréversibles ou coûteuses à récupérer
destructive='(k3d cluster delete|kubectl delete (ns|namespace)|kubectl delete -f|terraform destroy|docker system prune|docker volume rm|rm -rf|multipass delete)'

if printf '%s' "$cmd" | grep -qiE "$destructive"; then
  reason="Commande destructive détectée par le plugin ecommerce-ops. Vérifie la cible (cluster/namespace/volume) avant de valider."
  cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "$reason"
  }
}
JSON
  exit 0
fi

exit 0
