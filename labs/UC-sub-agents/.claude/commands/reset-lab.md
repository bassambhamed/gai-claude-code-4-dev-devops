---
description: Remet la copie de travail ecommerce-app à plat avant la démo multi-agents — supprime skills/hooks hérités, Dockerfiles, images/conteneurs et namespaces Docker/k8s « ecommerce|lab », en PRÉSERVANT le code, les tests et le système multi-agents. Ne touche jamais labs/.
allowed-tools: Bash
---
# Reset du lab — table rase contrôlée

Aperçu (DRY-RUN, rien n'est supprimé) :
!`bash .claude/scripts/reset-lab.sh`

## Ta mission
1. Montre à l'utilisateur ce qui serait supprimé (sortie ci-dessus).
2. Rappelle ce qui est **PRÉSERVÉ** : `src/**/*.cs`, `tests/`, `*.csproj`, `ECommerce.slnx`, et le
   système multi-agents (`.claude/agents`, `.claude/commands`, les 4 skills, les scripts de garde
   `guard-*`/`validate-readonly`/`reset-lab`, `.claude/run`). Et que **`labs/` n'est JAMAIS touché**.
3. Demande une **confirmation explicite**. Si l'utilisateur confirme, exécute :
   `bash .claude/scripts/reset-lab.sh --yes`
4. Termine en listant ce qui a réellement été retiré.

Ne supprime rien d'autre. Ne touche pas au code applicatif ni aux tests.
