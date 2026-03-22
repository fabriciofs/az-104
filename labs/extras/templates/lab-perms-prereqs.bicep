// Pre-requisitos do Lab Extra - Permissoes
// Cria: Storage Account + 2 containers + VM Ubuntu B1s (sem IP publico)

@description('Sufixo para nomes unicos')
param suffix string = uniqueString(resourceGroup().id)

@description('Regiao')
param location string = resourceGroup().location

@description('Senha do admin da VM')
@secure()
param adminPassword string

// ========== Storage Account ==========
var storageName = 'stperms${suffix}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource publicDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'public-data'
  properties: { publicAccess: 'None' }
}

resource financeDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'finance-data'
  properties: { publicAccess: 'None' }
}

// ========== VM ==========
var vmName = 'vm-perms-test'
var nicName = '${vmName}-nic'
var vnetName = 'vnet-lab-perms'
var subnetName = 'default'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/24'] }
    subnets: [
      {
        name: subnetName
        properties: { addressPrefix: '10.0.0.0/24' }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  tags: {
    dept: 'IT'
    env: 'lab'
  }
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: vmName
      adminUsername: 'azureuser'
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nic.id }]
    }
  }
}

// ========== Outputs ==========
output storageName string = storageAccount.name
output storageId string = storageAccount.id
output vmName string = vm.name
output rgName string = resourceGroup().name
