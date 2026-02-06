param location string
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.0.0/20'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'storage-subnet'
        properties: {
          addressPrefix: '10.0.16.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output aksSubnetId string = vnet.properties.subnets[0].id
output storageSubnetId string = vnet.properties.subnets[1].id
