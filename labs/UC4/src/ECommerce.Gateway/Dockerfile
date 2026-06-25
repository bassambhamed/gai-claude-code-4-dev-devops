# Dockerfile du service Gateway (YARP) — version optimisée (UC4).
# Build multi-étapes : SDK pour compiler, runtime CHISELÉ non-root pour l'exécution.
# ⚠️ Contexte de build = racine du repo, donc les COPY commencent par `src/`.

# ---- Étape 1 : build (SDK .NET 10) ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/ECommerce.Gateway/ECommerce.Gateway.csproj src/ECommerce.Gateway/
COPY src/ECommerce.ServiceDefaults/ECommerce.ServiceDefaults.csproj src/ECommerce.ServiceDefaults/
RUN dotnet restore src/ECommerce.Gateway/ECommerce.Gateway.csproj

COPY src/ECommerce.Gateway/ src/ECommerce.Gateway/
COPY src/ECommerce.ServiceDefaults/ src/ECommerce.ServiceDefaults/
RUN dotnet publish src/ECommerce.Gateway/ECommerce.Gateway.csproj \
    --configuration Release --no-restore -o /app/publish

# ---- Étape 2 : image finale (runtime chiselé, non-root) ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled AS final
WORKDIR /app
COPY --from=build /app/publish .

USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "ECommerce.Gateway.dll"]
