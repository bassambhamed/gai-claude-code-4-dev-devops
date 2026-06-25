# Corrigé — UC1 (Git & GitHub)

Fichiers de référence pour `UC1-git.md`.
Pendant la formation, les participants les créent **en temps réel** ; ce dossier sert de
**corrigé** en cas de blocage.

## Contenu
```
.claude/
├── settings.json                  # câble le hook (PreToolUse → Bash)
├── hooks/secret-scan.sh           # bloque un commit contenant un secret
└── skills/
    ├── init-repo/SKILL.md         # /init-repo : git init + repo GitHub + push main
    ├── git-commit/SKILL.md        # /git-commit : commit Conventional Commits
    └── open-pr/SKILL.md           # /open-pr : push + Pull Request documentée
```

## Pour appliquer le corrigé dans le projet
```bash
cp -r UC1/.claude ecommerce-app/
chmod +x ecommerce-app/.claude/hooks/secret-scan.sh
```
