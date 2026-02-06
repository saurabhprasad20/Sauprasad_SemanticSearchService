#!/bin/bash
set -e

# Load deployment outputs
source scripts/.deployment-outputs.env

echo "Setting up Azure Workload Identity..."

# Get AKS OIDC issuer
OIDC_ISSUER=$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --query oidcIssuerProfile.issuerUrl \
  -o tsv)

echo "OIDC Issuer: $OIDC_ISSUER"

# Get managed identity name
IDENTITY_NAME=$(az identity list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?contains(name, 'identity')].name" \
  -o tsv)

echo "Managed Identity: $IDENTITY_NAME"

# Create federated credential
FEDERATED_CREDENTIAL_NAME="semantic-search-federated-credential"

# Check if credential already exists
EXISTING=$(az identity federated-credential list \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$IDENTITY_NAME" \
  --query "[?name=='$FEDERATED_CREDENTIAL_NAME'].name" \
  -o tsv)

if [ -z "$EXISTING" ]; then
  echo "Creating federated credential..."
  az identity federated-credential create \
    --resource-group "$RESOURCE_GROUP" \
    --identity-name "$IDENTITY_NAME" \
    --name "$FEDERATED_CREDENTIAL_NAME" \
    --issuer "$OIDC_ISSUER" \
    --subject "system:serviceaccount:semantic-search:semantic-search-sa" \
    --audiences "api://AzureADTokenExchange"

  echo "Federated credential created successfully"
else
  echo "Federated credential already exists, skipping..."
fi
