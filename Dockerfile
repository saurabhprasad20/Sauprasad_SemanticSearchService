# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["src/SemanticSearchApi/SemanticSearchApi.csproj", "SemanticSearchApi/"]
RUN dotnet restore "SemanticSearchApi/SemanticSearchApi.csproj"

# Copy source code and build
COPY src/SemanticSearchApi/ SemanticSearchApi/
WORKDIR "/src/SemanticSearchApi"
RUN dotnet build "SemanticSearchApi.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "SemanticSearchApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080

# Set non-root user for security
USER $APP_UID

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "SemanticSearchApi.dll"]
