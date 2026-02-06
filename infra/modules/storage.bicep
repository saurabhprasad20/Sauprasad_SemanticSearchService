param location string
param storageAccountName string
param managedIdentityPrincipalId string
param subnetId string
param userObjectId string

// Storage Account with SFI compliance
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false  // SFI: No SAS tokens
    publicNetworkAccess: 'Enabled'  // Allow for initial deployment
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow'  // Allow for initial setup
      bypass: 'AzureServices'
    }
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Content container
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'content'
  properties: {
    publicAccess: 'None'
  }
}

// RBAC: Grant Storage Blob Data Reader to Managed Identity
var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityPrincipalId, storageBlobDataReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC: Grant Storage Blob Data Contributor to User (for uploads)
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource userRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, userObjectId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: userObjectId
    principalType: 'User'
  }
}

// Private endpoint for blob storage (disabled for initial deployment)
// resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
//   name: '${storageAccountName}-pe'
//   location: location
//   properties: {
//     subnet: {
//       id: subnetId
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${storageAccountName}-plsc'
//         properties: {
//           privateLinkServiceId: storageAccount.id
//           groupIds: [
//             'blob'
//           ]
//         }
//       }
//     ]
//   }
// }

output storageAccountName string = storageAccount.name
output storageAccountUrl string = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
output containerName string = container.name
