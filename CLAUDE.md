# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Kubernetes-based semantic search service** (mini-RAG) that provides natural language search over content stored in Azure Blob Storage. The service uses Azure OpenAI for embeddings and performs in-memory vector search with cosine similarity.

**Key Components:**
1. ASP.NET Core Web API (.NET 8) - Semantic search service
2. Azure Infrastructure (Bicep) - Storage, OpenAI, AKS, monitoring
3. Kubernetes Manifests - Deployment with health checks and workload identity
4. Deployment Scripts - Automated infrastructure and service provisioning
5. Python Analysis Tools - Bird dataset analysis (legacy)

## Architecture

```
Kubernetes Pod (ASP.NET Core)
  ├─ /health → Readiness/liveness probes
  ├─ /search?query=... → Semantic search API
  └─ In-Memory Vector Store → Cosine similarity search
         ↓ Managed Identity
Azure Services
  ├─ Blob Storage (private endpoint, no SAS)
  ├─ Azure OpenAI (text-embedding-3-small)
  ├─ AKS (workload identity enabled)
  └─ Log Analytics + Application Insights
```

## Common Commands

### Deployment (Full Stack)

```bash
# 1. Deploy all Azure infrastructure
./scripts/deploy-infrastructure.sh

# 2. Upload content to blob storage
./scripts/upload-content.sh

# 3. Deploy service to Kubernetes
./scripts/deploy-service.sh

# 4. Run end-to-end tests (validates all 8 requirements)
./scripts/end-to-end-test.sh
```

### Development

Build and test locally:
```bash
cd src/SemanticSearchApi
dotnet build
dotnet run
```

Build Docker image:
```bash
docker build -t semantic-search:dev .
```

### Kubernetes Operations

```bash
# View pods
kubectl get pods -n semantic-search

# View logs
kubectl logs -n semantic-search -l app=semantic-search --follow

# Port forward for local testing
kubectl port-forward -n semantic-search svc/semantic-search 8080:80

# Scale deployment
kubectl scale deployment semantic-search -n semantic-search --replicas=3

# Check readiness probe status
kubectl get pods -n semantic-search -o wide
```

### Azure CLI

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-semantic-search-dev --name <aks-name>

# Upload file to blob (using Managed Identity)
az storage blob upload \
  --account-name <storage-account> \
  --container-name content \
  --file birds_india_50.csv \
  --name birds_india_50.csv \
  --auth-mode login

# Check storage SAS setting
az storage account show --name <storage> --query allowSharedKeyAccess

# View Azure OpenAI deployment
az cognitiveservices account deployment list \
  --resource-group rg-semantic-search-dev \
  --name <openai-name>
```

## Code Structure

### ASP.NET Core Service (src/SemanticSearchApi/)

**Controllers:**
- `HealthController.cs` - Health check endpoint, returns 503 if not initialized
- `SearchController.cs` - GET/POST /search endpoints with query validation

**Services:**
- `EmbeddingService.cs` - Azure OpenAI client, generates embeddings with DefaultAzureCredential
- `BlobStorageService.cs` - Loads CSV from blob storage using Managed Identity
- `VectorSearchService.cs` - In-memory vector store with cosine similarity search
  - Loads data on startup
  - Generates embeddings for all records
  - Performs similarity search for queries

**Models:**
- `BirdRecord.cs` - CSV data model with GetSearchableText() for embeddings
- `SearchRequest.cs` - API request DTO
- `SearchResult.cs` - API response DTO with similarity score

**Key Flow:**
1. Startup: Program.cs initializes VectorSearchService in background
2. VectorSearchService loads CSV from blob → generates embeddings → stores in memory
3. Health endpoint returns 503 until initialization complete
4. Search queries: compute embedding → cosine similarity → return top-K results

### Infrastructure (infra/)

**Main Template (main.bicep):**
- Orchestrates all resource modules
- Outputs deployment values to .deployment-outputs.env

**Modules:**
- `storage.bicep` - Storage account with SFI compliance (no SAS, private endpoint, Managed Identity RBAC)
- `openai.bicep` - Azure OpenAI with text-embedding-3-small deployment, disableLocalAuth=true
- `aks.bicep` - AKS with workload identity, VNet integration, Log Analytics
- `acr.bicep` - Container Registry with Managed Identity pull access
- `network.bicep` - VNet with subnets for AKS and storage private endpoint
- `monitoring.bicep` - Log Analytics + Application Insights
- `identity.bicep` - User-assigned Managed Identity with RBAC for all services

**SFI Compliance:**
- `allowSharedKeyAccess: false` - No SAS tokens
- `publicNetworkAccess: 'Disabled'` - No public internet (storage)
- `disableLocalAuth: true` - No API keys (OpenAI)
- Workload Identity - No secrets in pods
- Private endpoints - VNet-only access

### Kubernetes (k8s/)

**Manifests:**
- `namespace.yaml` - semantic-search namespace
- `serviceaccount.yaml` - SA with azure.workload.identity/client-id annotation
- `configmap.yaml` - Non-secret configuration (endpoints, container names)
- `deployment.yaml` - Pod spec with readiness/liveness probes
  - Readiness: /health every 10s after 15s initial delay
  - Liveness: /healthz every 15s after 30s initial delay
  - Resources: 512Mi-1Gi memory, 250m-500m CPU
- `service.yaml` - LoadBalancer service on port 80→8080

**Workload Identity:**
1. AKS OIDC issuer enabled
2. Federated credential links Managed Identity → K8s ServiceAccount
3. Pod labels: `azure.workload.identity/use: "true"`
4. Azure SDK automatically picks up token from projected volume

### Deployment Scripts (scripts/)

**deploy-infrastructure.sh:**
- Creates resource group
- Deploys Bicep template
- Saves outputs to .deployment-outputs.env (used by other scripts)

**upload-content.sh:**
- Uploads birds_india_50.csv to blob storage using `az storage blob upload --auth-mode login`

**deploy-service.sh:**
- Builds Docker image with `az acr build`
- Configures workload identity (calls setup-workload-identity.sh)
- Updates K8s manifests with actual values (sed)
- Deploys to Kubernetes
- Waits for deployment readiness

**setup-workload-identity.sh:**
- Gets AKS OIDC issuer URL
- Creates federated credential linking Managed Identity to K8s ServiceAccount
- Idempotent (checks if already exists)

**end-to-end-test.sh:**
- Runs all 8 test cases from requirements
- Tests health, search API, SFI compliance, logs, metrics, readiness
- Outputs pass/fail summary

## Configuration

### Environment Variables

Set via ConfigMap in K8s:
- `AzureOpenAI__Endpoint` - OpenAI endpoint URL
- `AzureOpenAI__EmbeddingDeployment` - Model deployment name (text-embedding-3-small)
- `BlobStorage__Url` - Storage account URL
- `BlobStorage__ContainerName` - Blob container name (content)
- `BlobStorage__FileName` - CSV file name (birds_india_50.csv)

### Secrets

**None!** All authentication uses Managed Identity via DefaultAzureCredential.

In local development, DefaultAzureCredential uses Azure CLI credentials.

## Development Notes

### Adding New Content

1. Upload new CSV/files to blob storage
2. Restart pod to reload: `kubectl rollout restart deployment semantic-search -n semantic-search`
3. Service generates embeddings on startup (takes ~1-2 minutes for 50 records)

### Modifying Search Logic

Key file: `src/SemanticSearchApi/Services/VectorSearchService.cs`
- `InitializeAsync()` - Loads data and generates embeddings
- `SearchAsync()` - Performs search
- `CosineSimilarity()` - Uses System.Numerics.Tensors for performance

### Updating Infrastructure

Edit Bicep files in `infra/modules/`, then:
```bash
az deployment group create \
  --resource-group rg-semantic-search-dev \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json
```

### Vector Store Alternatives

Current implementation uses in-memory List<float[]>. For production scale:
- Add Redis with vector search (RedisStack)
- Add Qdrant or other vector DB
- Use Azure Cosmos DB for MongoDB vCore with vector search

### Debugging Workload Identity Issues

```bash
# Check service account annotation
kubectl describe sa semantic-search-sa -n semantic-search

# Check pod labels
kubectl get pod -n semantic-search -o yaml | grep -A5 labels

# Check federated credential
az identity federated-credential list \
  --resource-group rg-semantic-search-dev \
  --identity-name <identity-name>

# Check pod logs for auth errors
kubectl logs -n semantic-search -l app=semantic-search | grep -i auth
```

## Test Cases

All validated by `scripts/end-to-end-test.sh`:

1. Health endpoint returns 200 OK
2. Search API responds with relevant content (semantic similarity)
3. Storage account has `allowSharedKeyAccess: false`
4. Azure Search auth keys disabled (N/A for in-process search)
5. Container logs searchable via `kubectl logs`
6. Container metrics visible via `kubectl top` and Azure Monitor
7. Readiness probe shows pod as Ready
8. Deployment scripts are executable and idempotent

## Data Structure

### birds_india_50.csv
- 47 species (20 resident, 27 winter visitors)
- Columns: name, scientific name, presence, order, family
- Presence codes: R (resident), W (winter visitor)
- Used for semantic search testing

## Legacy Components

### Python Analysis Scripts (Root Directory)
- `analyze_birds.py` - Statistical analysis of bird data
- `filter_birds.py` - CLI tool for filtering/exporting subsets
- Not used by main service, kept for data exploration

### Azure Functions Stub (Root Directory)
- `PerformSymanticSearch.cs` - Original Functions stub (now obsolete)
- Replaced by ASP.NET Core service in src/SemanticSearchApi/

## Critical Files for Implementation

**Service Code:**
- `src/SemanticSearchApi/Program.cs` - Entry point, DI configuration
- `src/SemanticSearchApi/Services/VectorSearchService.cs` - Core search logic
- `src/SemanticSearchApi/Services/EmbeddingService.cs` - Azure OpenAI integration

**Infrastructure:**
- `infra/main.bicep` - Orchestration template
- `infra/modules/storage.bicep` - SFI-compliant storage
- `infra/modules/aks.bicep` - K8s cluster with workload identity

**Deployment:**
- `scripts/deploy-service.sh` - Main deployment orchestrator
- `k8s/deployment.yaml` - Pod specification with health checks
