@description('Storage Account para prontuários médicos da Contoso Healthcare')
param location string = resourceGroup().location
param storageName string = 'sachprontuarios'

@description('Resource Group da VNet')
param vnetResourceGroup string = 'rg-ch-network'
param vnetName string = 'vnet-ch-spoke-web'
param subnetName string = 'snet-web'

// Referência a recurso EXISTENTE em outro RG
// keyword "existing" = não cria, apenas referencia
// "scope: resourceGroup(name)" = busca em outro RG
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: '${vnetName}/${subnetName}'
  scope: resourceGroup(vnetResourceGroup)
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: {
    Projeto: 'ContosoHealth'
    CostCenter: 'CC-CLINICO'
    Compliance: 'LGPD'
  }
  sku: {
    name: 'Standard_GRS' // Geo-redundant para DR
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    // Firewall: negar por padrão, permitir apenas da VNet e Azure Services
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices' // Permite Backup, Monitor, etc.
      virtualNetworkRules: [
        {
          id: existingSubnet.id
          action: 'Allow'
        }
      ]
    }
    // Criptografia com infrastructure encryption (dupla camada)
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
    }
  }
}

// Child resource: configurações do Blob Service
// parent: define relação hierárquica com a storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30 // Soft delete: blobs deletados ficam 30 dias
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7 // Containers deletados ficam 7 dias
    }
    isVersioningEnabled: true // Cada modificação cria nova versão
    changeFeed: {
      enabled: true // Necessário para Object Replication
    }
  }
}

// Outputs para uso em outros deploys
output storageId string = storageAccount.id
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
