#!/bin/bash
set -e

# Load deployment outputs
if [ ! -f scripts/.deployment-outputs.env ]; then
    echo "Error: Deployment outputs not found. Run deploy-infrastructure.sh first."
    exit 1
fi

source scripts/.deployment-outputs.env

echo "============================================"
echo "Deploying Semantic Search Service"
echo "============================================"
echo "ACR: $ACR_LOGIN_SERVER"
echo "AKS: $AKS_NAME"
echo ""

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing

# Build and push Docker image
echo ""
echo "Building Docker image..."
IMAGE_TAG="$ACR_LOGIN_SERVER/semantic-search:latest"

az acr build \
  --registry "${ACR_LOGIN_SERVER%%.*}" \
  --image "semantic-search:latest" \
  --file Dockerfile \
  .

echo ""
echo "Docker image built and pushed: $IMAGE_TAG"

# Setup workload identity
echo ""
echo "Setting up workload identity..."
./scripts/setup-workload-identity.sh

# Update K8s manifests with actual values
echo ""
echo "Updating Kubernetes manifests..."

# Update configmap
sed -i "s|YOUR_STORAGE_ACCOUNT.blob.core.windows.net|${STORAGE_URL#https://}|g" k8s/configmap.yaml
sed -i "s|YOUR_OPENAI_RESOURCE.openai.azure.com/|${OPENAI_ENDPOINT#https://}|g" k8s/configmap.yaml

# Update serviceaccount
sed -i "s|YOUR_MANAGED_IDENTITY_CLIENT_ID|$MANAGED_IDENTITY_CLIENT_ID|g" k8s/serviceaccount.yaml

# Update deployment
sed -i "s|YOUR_ACR_NAME.azurecr.io|$ACR_LOGIN_SERVER|g" k8s/deployment.yaml

# Deploy to Kubernetes
echo ""
echo "Deploying to Kubernetes..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/semantic-search -n semantic-search

echo ""
echo "============================================"
echo "Service deployment complete!"
echo "============================================"

# Get service endpoint
echo ""
echo "Getting service endpoint..."
kubectl get svc semantic-search -n semantic-search

echo ""
echo "Check pod status:"
echo "  kubectl get pods -n semantic-search"
echo ""
echo "View logs:"
echo "  kubectl logs -n semantic-search -l app=semantic-search --follow"
echo ""
echo "Test health endpoint:"
echo "  kubectl port-forward -n semantic-search svc/semantic-search 8080:80"
echo "  curl http://localhost:8080/health"
