#!/usr/bin/env bash
# Hook PreToolUse(Bash) — bloque un `git commit` si un secret est détecté dans l'index.
# Reçoit l'appel d'outil en JSON sur stdin. Code de sortie 2 => la commande est BLOQUÉE.
#
# Pédagogie : un hook impose un garde-fou DÉTERMINISTE. Ce n'est pas l'IA qui « décide »
# de ne pas committer un secret : c'est le harnais qui exécute ce script et bloque.

set -euo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | grep -o '"command"[^,]*' | head -1 || true)"

# On ne s'intéresse qu'aux commits
if ! printf '%s' "$cmd" | grep -qi 'git commit'; then
  exit 0
fi

# Motifs de secrets fréquents (simplifié pour la démo ; en vrai : gitleaks/trufflehog)
patterns='(password|passwd|secret|api[_-]?key|token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|connectionstring|aws_secret_access_key)'

hits="$(git diff --cached -U0 2>/dev/null | grep -iE "^\+.*$patterns" || true)"

if [ -n "$hits" ]; then
  echo "⛔ COMMIT BLOQUÉ par le hook secret-scan : un secret potentiel a été détecté." >&2
  echo "Lignes suspectes :" >&2
  printf '%s\n' "$hits" | head -5 >&2
  echo "Retire le secret (coffre / variable d'environnement) puis recommence." >&2
  exit 2
fi

exit 0
