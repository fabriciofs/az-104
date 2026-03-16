@description('VNet Hub da Contoso Healthcare com subnets especiais')
param location string = resourceGroup().location

resource vnetHub 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-ch-hub'
  location: location
  tags: {
    Projeto: 'ContosoHealth'
    CostCenter: 'CC-TI'
  }
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        // AzureBastionSubnet: nome EXATO obrigatório, mínimo /26
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/26'
        }
      }
      {
        // GatewaySubnet: nome EXATO obrigatório, mínimo /27, NÃO pode ter NSG
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/27'
        }
      }
      {
        // Subnet para NVA/DNS Forwarder
        name: 'snet-shared'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnetHub.id
output vnetName string = vnetHub.name
output bastionSubnetId string = vnetHub.properties.subnets[0].id
output gatewaySubnetId string = vnetHub.properties.subnets[1].id
output sharedSubnetId string = vnetHub.properties.subnets[2].id
