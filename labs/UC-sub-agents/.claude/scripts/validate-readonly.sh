#!/usr/bin/env bash
# test-runner = lecture seule : autorise build/test + l'horodatage d'instrumentation,
# bloque toute mutation du projet.
# Hook PreToolUse (matcher Bash) : exit 2 = bloque la commande et renvoie le message à Claude.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$CMD" | grep -iE '\bdotnet[[:space:]]+(add|remove|new|publish|nuget)\b|\bgit[[:space:]]+(commit|push|checkout|reset|merge|rebase)\b|\brm[[:space:]]+-' >/dev/null; then
  echo "Bloqué : test-runner est en lecture seule (build/test uniquement, pas de mutation)." >&2
  exit 2
fi
exit 0
