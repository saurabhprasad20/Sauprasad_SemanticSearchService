#!/bin/bash
set -e

# Configuration
RG_NAME="rg-semantic-search-dev"
LOCATION="eastus"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

echo "============================================"
echo "Deploying Semantic Search Infrastructure"
echo "============================================"
echo "Resource Group: $RG_NAME"
echo "Location: $LOCATION"
echo "User Object ID: $USER_OBJECT_ID"
echo ""

# Create resource group
echo "Creating resource group..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --tags "environment=dev" "project=semantic-search"

# Deploy infrastructure
echo ""
echo "Deploying infrastructure (this may take 15-20 minutes)..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json \
  --parameters userObjectId="$USER_OBJECT_ID" \
  --query properties.outputs \
  --output json)

# Extract outputs
STORAGE_ACCOUNT=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.storageAccountName.value')
STORAGE_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.storageAccountUrl.value')
CONTAINER_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.containerName.value')
OPENAI_ENDPOINT=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.openAiEndpoint.value')
OPENAI_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.openAiName.value')
AKS_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.aksName.value')
ACR_LOGIN_SERVER=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.acrLoginServer.value')
MANAGED_IDENTITY_CLIENT_ID=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.managedIdentityClientId.value')

# Save outputs to file for other scripts
cat > scripts/.deployment-outputs.env <<EOF
RESOURCE_GROUP=$RG_NAME
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
STORAGE_URL=$STORAGE_URL
CONTAINER_NAME=$CONTAINER_NAME
OPENAI_ENDPOINT=$OPENAI_ENDPOINT
OPENAI_NAME=$OPENAI_NAME
AKS_NAME=$AKS_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
MANAGED_IDENTITY_CLIENT_ID=$MANAGED_IDENTITY_CLIENT_ID
EOF

echo ""
echo "============================================"
echo "Infrastructure deployment complete!"
echo "============================================"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Storage URL: $STORAGE_URL"
echo "Container: $CONTAINER_NAME"
echo "OpenAI Endpoint: $OPENAI_ENDPOINT"
echo "AKS Cluster: $AKS_NAME"
echo "ACR: $ACR_LOGIN_SERVER"
echo "Managed Identity: $MANAGED_IDENTITY_CLIENT_ID"
echo ""
echo "Outputs saved to: scripts/.deployment-outputs.env"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/upload-content.sh"
echo "2. Run: ./scripts/deploy-service.sh"
