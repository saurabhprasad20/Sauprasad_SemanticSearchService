# Semantic Search API - Mini-RAG Service

A Kubernetes-based semantic search service that provides RAG (Retrieval-Augmented Generation) capabilities over content stored in Azure Blob Storage. Built with .NET 8, Azure OpenAI embeddings, and in-process vector search.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                      │
│  ┌────────────────────────────────────────────────────┐ │
│  │       Semantic Search Pod (ASP.NET Core)          │ │
│  │  • /health - Readiness & liveness probes          │ │
│  │  • /search - Semantic search endpoint             │ │
│  │  • In-Memory Vector Store (cosine similarity)     │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        ↓ Managed Identity
            ┌──────────────────────────┐
            │   Azure Services         │
            │  • Blob Storage          │ ← Content files
            │  • Azure OpenAI          │ ← Embeddings
            │  • Log Analytics         │ ← Logs
            │  • Azure Monitor         │ ← Metrics
            └──────────────────────────┘
```

## Features

- **Semantic Search**: Natural language queries using Azure OpenAI embeddings
- **In-Process Vector Search**: Fast cosine similarity search in memory
- **SFI Compliant**: No secrets, Managed Identity auth, private endpoints
- **Kubernetes Native**: Health checks, readiness probes, autoscaling
- **Automated Deployment**: Single-click infrastructure and service deployment

## Quick Start

### Prerequisites

- Azure subscription
- Azure CLI installed and logged in
- kubectl installed
- Bash shell (WSL, Git Bash, or Linux/macOS)
- jq installed (`choco install jq` or `brew install jq`)

### Deployment

```bash
# 1. Deploy infrastructure (AKS, Storage, OpenAI, etc.)
./scripts/deploy-infrastructure.sh

# 2. Upload content files to blob storage
./scripts/upload-content.sh

# 3. Deploy service to Kubernetes
./scripts/deploy-service.sh

# 4. Run end-to-end tests
./scripts/end-to-end-test.sh
```

### Test the Service

```bash
# Port forward to access locally
kubectl port-forward -n semantic-search svc/semantic-search 8080:80

# Health check
curl http://localhost:8080/health

# Search query
curl "http://localhost:8080/search?query=migratory+ducks"
```

## API Endpoints

### GET /health

Health check endpoint for readiness and liveness probes.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "service": "semantic-search-api",
  "ready": true
}
```

### GET /search

Semantic search endpoint.

**Parameters:**
- `query` (required): Search query text
- `topK` (optional, default=5): Number of results to return (1-50)

**Example:**
```bash
curl "http://localhost:8080/search?query=winter+birds&topK=3"
```

**Response:**
```json
{
  "query": "winter birds",
  "resultsCount": 3,
  "results": [
    {
      "name": "Northern Pintail",
      "scientificName": "Anas acuta",
      "presence": "W",
      "order": "ANSERIFORMES",
      "family": "Anatidae",
      "score": 0.87,
      "content": "Northern Pintail (Anas acuta) - W - Order: ANSERIFORMES, Family: Anatidae"
    }
  ]
}
```

### POST /search

Alternative POST endpoint for complex queries.

**Request Body:**
```json
{
  "query": "migratory ducks",
  "topK": 5
}
```

## Project Structure

```
aisessions/
├── src/SemanticSearchApi/       # ASP.NET Core Web API
│   ├── Controllers/              # API controllers
│   ├── Services/                 # Business logic services
│   ├── Models/                   # Data models
│   └── Program.cs                # Application entry point
├── infra/                        # Bicep infrastructure code
│   ├── main.bicep                # Main template
│   └── modules/                  # Resource modules
├── k8s/                          # Kubernetes manifests
│   ├── deployment.yaml           # Pod deployment
│   ├── service.yaml              # LoadBalancer service
│   ├── configmap.yaml            # Configuration
│   └── serviceaccount.yaml       # Workload identity
├── scripts/                      # Deployment scripts
│   ├── deploy-infrastructure.sh  # Provision Azure resources
│   ├── upload-content.sh         # Upload content to blob
│   ├── deploy-service.sh         # Deploy to K8s
│   └── end-to-end-test.sh        # Run all tests
├── Dockerfile                    # Container image
└── birds_india_50.csv            # Sample data
```

## SFI Compliance

This service meets SFI (Secure Future Initiative) requirements:

- ✅ **No Shared Key Access**: Storage SAS tokens disabled
- ✅ **No Secret-Based Auth**: Managed Identity for all Azure services
- ✅ **Private Endpoints**: Storage accessible only from VNet
- ✅ **1P IPs Only**: Uses /NonProd tag, no default outbound IPs
- ✅ **No Public Internet**: Storage has public network access disabled

## Test Cases

The `end-to-end-test.sh` script validates all requirements:

1. ✓ Health endpoint returns 200 OK
2. ✓ Search API responds with relevant content
3. ✓ Storage has SAS disabled
4. ✓ Azure Search auth keys disabled (N/A for in-process)
5. ✓ Container logs searchable
6. ✓ Container metrics visible
7. ✓ Readiness probe shows "Ready"
8. ✓ Single-click deployment scripts work

## Development

### Local Testing

To test locally (requires Azure OpenAI and Storage Account):

```bash
cd src/SemanticSearchApi

# Update appsettings.Development.json with your Azure resources
dotnet run
```

### Build Docker Image

```bash
docker build -t semantic-search:dev .
docker run -p 8080:8080 semantic-search:dev
```

### View Logs

```bash
kubectl logs -n semantic-search -l app=semantic-search --follow
```

### Scale Deployment

```bash
kubectl scale deployment semantic-search -n semantic-search --replicas=3
```

## Technologies

- **.NET 8**: Modern C# with minimal APIs
- **Azure OpenAI**: Text embeddings (text-embedding-3-small)
- **Azure Blob Storage**: Content storage with private endpoints
- **Azure Kubernetes Service (AKS)**: Container orchestration
- **Azure Workload Identity**: Pod-level managed identity
- **Bicep**: Infrastructure as Code
- **System.Numerics.Tensors**: Vector operations

## Dataset

The sample dataset (`birds_india_50.csv`) contains 47 bird species found in India:
- 20 resident species (breed in India)
- 27 winter visitors (migratory)

Fields: name, scientific name, presence (R/W), order, family

## Monitoring

### View Metrics

```bash
# Pod metrics
kubectl top pods -n semantic-search

# View in Azure Portal
# Navigate to: AKS cluster > Insights > Containers
```

### View Logs

```bash
# Container logs
kubectl logs -n semantic-search -l app=semantic-search

# Log Analytics queries
# Navigate to: Log Analytics > Logs > Query ContainerLog table
```

## Troubleshooting

### Pod not starting

```bash
kubectl describe pod -n semantic-search -l app=semantic-search
kubectl logs -n semantic-search -l app=semantic-search
```

### Service not accessible

```bash
kubectl get svc -n semantic-search
kubectl get endpoints -n semantic-search
```

### Authentication issues

```bash
# Check workload identity setup
kubectl describe serviceaccount semantic-search-sa -n semantic-search

# Verify federated credential
az identity federated-credential list \
  --resource-group rg-semantic-search-dev \
  --identity-name <identity-name>
```

## License

This is a demo project for learning purposes.

## Support

For issues or questions, please check the CLAUDE.md file for development guidelines.
