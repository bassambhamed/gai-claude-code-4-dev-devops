#!/usr/bin/env bash
# Hook SessionStart — injecte un rappel d'environnement au démarrage de session.
# Le stdout d'un hook SessionStart est ajouté au contexte de Claude.
#
# Sur cette machine le SDK .NET 10 n'est pas sur le PATH par défaut : on le rappelle
# une fois pour toutes, pour éviter les "command not found: dotnet".

set -euo pipefail

cat <<'CTX'
[ecommerce-ops] Rappels environnement :
- SDK .NET 10 pas sur le PATH par défaut : export PATH="/usr/local/share/dotnet:$PATH"
- Lancer tout le système : dotnet run --project src/ECommerce.AppHost
- Skills Ops dispo : containerize, k8s-bootstrap, k8s-debug-pod
- Garde-fous actifs : secret-scan (bloque les commits avec secret), guard-destructive (confirmation sur k3d/terraform/docker destructifs).
CTX

exit 0
