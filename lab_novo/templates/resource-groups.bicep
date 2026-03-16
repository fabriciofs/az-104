// Bicep - Deploy no nível da Subscription (targetScope = 'subscription')
// Permite criar Resource Groups
targetScope = 'subscription'

@description('Região principal dos recursos')
param location string = 'eastus'

@description('Tags aplicadas a todos os RGs')
param tags object = {
  Projeto: 'ContosoHealth'
  Ambiente: 'Lab'
  CostCenter: 'CC-INFRA'
}

// Cada "resource" define um recurso Azure
// Sintaxe: resource <nome-simbólico> '<tipo>@<api-version>' = { ... }
resource rgIdentity 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ch-identity'
  location: location
  tags: tags
}

resource rgNetwork 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ch-network'
  location: location
  tags: tags
}

resource rgStorage 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ch-storage'
  location: location
  tags: tags
}

resource rgCompute 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ch-compute'
  location: location
  tags: tags
}

resource rgMonitor 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ch-monitor'
  location: location
  tags: tags
}
