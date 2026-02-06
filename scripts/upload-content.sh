#!/bin/bash
set -e

# Load deployment outputs
if [ ! -f scripts/.deployment-outputs.env ]; then
    echo "Error: Deployment outputs not found. Run deploy-infrastructure.sh first."
    exit 1
fi

source scripts/.deployment-outputs.env

echo "============================================"
echo "Uploading Content to Blob Storage"
echo "============================================"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo ""

# Check if CSV file exists
if [ ! -f "birds_india_50.csv" ]; then
    echo "Error: birds_india_50.csv not found in current directory"
    exit 1
fi

# Upload CSV file using Managed Identity (no secrets!)
echo "Uploading birds_india_50.csv..."
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --file "birds_india_50.csv" \
  --name "birds_india_50.csv" \
  --auth-mode login \
  --overwrite

echo ""
echo "============================================"
echo "Content upload complete!"
echo "============================================"
echo "File: birds_india_50.csv"
echo "Location: $STORAGE_URL/$CONTAINER_NAME/birds_india_50.csv"
echo ""
echo "Next step: Run ./scripts/deploy-service.sh"
