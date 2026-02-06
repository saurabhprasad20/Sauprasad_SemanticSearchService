param location string
param identityName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output identityId string = managedIdentity.id
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
