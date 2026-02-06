param location string
param openAiName string
param managedIdentityPrincipalId string

resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAiName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiName
    publicNetworkAccess: 'Enabled'  // Can be set to 'Disabled' for stricter SFI
    networkAcls: {
      defaultAction: 'Allow'  // Change to 'Deny' with specific rules for production
    }
    disableLocalAuth: true  // SFI: No API key auth
  }
}

// Deploy embedding model
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAi
  name: 'text-embedding-3-small'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
  }
}

// RBAC: Grant Cognitive Services OpenAI User to Managed Identity
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, managedIdentityPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output endpoint string = openAi.properties.endpoint
output name string = openAi.name
output id string = openAi.id
