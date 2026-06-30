---
name: dotnet-test-runner
description: Lancer la suite de tests de ecommerce-app-dev et n'en remonter que l'essentiel.
---
## Commandes
- PATH si besoin : `export PATH="/usr/local/share/dotnet:$PATH"`.
- Toute la suite : `dotnet test ECommerce.slnx --nologo`.
- Filtrer par service : `dotnet test --filter "FullyQualifiedName~Ordering"`.

## Sortie attendue
- Ne renvoyer QUE les tests rouges : nom complet, message, `fichier:ligne`.
- Terminer par le compte : « X passés / Y échoués / Z ignorés ».
- Si tout est vert : une seule ligne « ✅ N tests, tous verts ».
