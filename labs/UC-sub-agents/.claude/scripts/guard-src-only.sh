#!/usr/bin/env bash
# dotnet-reviewer ne corrige QUE le code applicatif (src/**/*.cs). Pas l'infra.
# Hook PreToolUse (matcher Edit|Write) : exit 2 = bloque l'écriture et renvoie le message à Claude.
INPUT=$(cat)
P=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$P" in
  *Dockerfile|*/.github/*|*docker-compose*|*/k8s/*|*/helm/*|*.yml|*.yaml)
    echo "Bloqué : dotnet-reviewer ne touche pas l'infra ($P). Périmètre = src/ (.cs). L'infra est gérée par devops-engineer." >&2
    exit 2 ;;
esac
exit 0
