# Corrigé — UC2 (CI/CD)

Fichiers de référence pour `UC2-cicd.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.github/workflows/
├── ci.yml                         # build + tests + scan Trivy (à chaque push/PR)
└── cd.yml                         # déploiement pré-prod auto + prod avec gate manuel
.claude/skills/
└── ci-pipeline/SKILL.md           # /ci-pipeline : génère/maintient les workflows
```

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC2/.github  ecommerce-app/
cp -r UC2/.claude  ecommerce-app/    # fusionne avec le .claude existant
```

> Rappel : activer le gate prod côté GitHub (Settings > Environments > production >
> Required reviewers) — voir §5 de la démo.
