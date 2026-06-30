#!/usr/bin/env bash
# devops-engineer ne touche QUE l'infra. Pas le code applicatif (.cs).
# Hook PreToolUse (matcher Edit|Write) : exit 2 = bloque l'écriture et renvoie le message à Claude.
INPUT=$(cat)
P=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$P" in
  *.cs)
    echo "Bloqué : devops-engineer ne modifie pas le code .cs ($P). Périmètre = infra (Dockerfile, CI, k8s, helm). Le code est géré par dotnet-reviewer." >&2
    exit 2 ;;
esac
exit 0
