param location string
param acrName string
param managedIdentityPrincipalId string

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false  // SFI: No admin user
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// RBAC: Grant AcrPull to Managed Identity
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentityPrincipalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output acrId string = acr.id
output loginServer string = acr.properties.loginServer
output acrName string = acr.name
