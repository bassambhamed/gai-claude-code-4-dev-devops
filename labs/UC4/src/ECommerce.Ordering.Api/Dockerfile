# Dockerfile du service Ordering — version optimisée (UC4).
# Build multi-étapes : on compile avec le SDK, on n'embarque que le runtime CHISELÉ (distroless-like).
# ⚠️ Contexte de build = racine du repo (voir `docker build -f … .`), donc les COPY commencent par `src/`.

# ---- Étape 1 : build (SDK .NET 10) ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# .csproj d'abord (Ordering + sa dépendance ServiceDefaults) → cache Docker : restore rejoué
# seulement si un .csproj change.
COPY src/ECommerce.Ordering.Api/ECommerce.Ordering.Api.csproj src/ECommerce.Ordering.Api/
COPY src/ECommerce.ServiceDefaults/ECommerce.ServiceDefaults.csproj src/ECommerce.ServiceDefaults/
RUN dotnet restore src/ECommerce.Ordering.Api/ECommerce.Ordering.Api.csproj

# Puis le code source, et publication en Release.
COPY src/ECommerce.Ordering.Api/ src/ECommerce.Ordering.Api/
COPY src/ECommerce.ServiceDefaults/ src/ECommerce.ServiceDefaults/
RUN dotnet publish src/ECommerce.Ordering.Api/ECommerce.Ordering.Api.csproj \
    --configuration Release --no-restore -o /app/publish

# ---- Étape 2 : image finale (runtime chiselé, non-root) ----
# L'image "chiseled" ne contient ni shell ni gestionnaire de paquets → plus petite, plus sûre.
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled AS final
WORKDIR /app
COPY --from=build /app/publish .

# $APP_UID est défini par l'image .NET : on exécute en utilisateur NON-root.
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "ECommerce.Ordering.Api.dll"]
