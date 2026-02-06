targetScope = 'resourceGroup'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (e.g., dev, test, prod)')
param environment string = 'dev'

@description('The base name for all resources')
param baseName string = 'semanticsearch'

@description('Your object ID for initial Key Vault access')
param userObjectId string

// Variables
var uniqueSuffix = uniqueString(resourceGroup().id)
// Storage account name must be 3-24 chars, lowercase letters and numbers only
// uniqueString always returns 13 chars, so 'semsearch' (9) + 13 = 22 chars total
var storageAccountName = 'semsearch${uniqueSuffix}'
var openAiName = '${baseName}-openai-${environment}'
var aksName = '${baseName}-aks-${environment}'
var acrName = '${baseName}acr${uniqueSuffix}'
var logAnalyticsName = '${baseName}-logs-${environment}'
var appInsightsName = '${baseName}-ai-${environment}'
var managedIdentityName = '${baseName}-identity-${environment}'
var vnetName = '${baseName}-vnet-${environment}'

// Log Analytics Workspace
module logAnalytics 'modules/monitoring.bicep' = {
  name: 'logAnalytics-deployment'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
  }
}

// Managed Identity
module identity 'modules/identity.bicep' = {
  name: 'identity-deployment'
  params: {
    location: location
    identityName: managedIdentityName
  }
}

// Virtual Network
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    vnetName: vnetName
  }
}

// Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: storageAccountName
    managedIdentityPrincipalId: identity.outputs.principalId
    subnetId: network.outputs.storageSubnetId
    userObjectId: userObjectId
  }
}

// Azure OpenAI
module openai 'modules/openai.bicep' = {
  name: 'openai-deployment'
  params: {
    location: location
    openAiName: openAiName
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Azure Container Registry
module acr 'modules/acr.bicep' = {
  name: 'acr-deployment'
  params: {
    location: location
    acrName: acrName
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// AKS Cluster
module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  params: {
    location: location
    aksName: aksName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    vnetSubnetId: network.outputs.aksSubnetId
    managedIdentityId: identity.outputs.identityId
    acrId: acr.outputs.acrId
  }
}

// Outputs
output storageAccountName string = storage.outputs.storageAccountName
output storageAccountUrl string = storage.outputs.storageAccountUrl
output containerName string = storage.outputs.containerName
output openAiEndpoint string = openai.outputs.endpoint
output openAiName string = openai.outputs.name
output aksName string = aks.outputs.aksName
output acrLoginServer string = acr.outputs.loginServer
output managedIdentityClientId string = identity.outputs.clientId
output managedIdentityPrincipalId string = identity.outputs.principalId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
