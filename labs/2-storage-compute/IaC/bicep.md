# Lab AZ-104 - Semana 2: Tudo via Bicep

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI com Bicep ja vem pre-instalados
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.bicep`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab de Storage & Compute (~35 recursos) usando templates Bicep + CLI.
> Cada template e fortemente comentado para aprendizado.

---

## Pre-requisitos: Cloud Shell e Conceitos Bicep

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (Bash)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui Azure CLI e Bicep pre-instalados e a autenticacao e automatica.
> Para criar os arquivos `.bicep`, use o editor integrado: `code nome-do-arquivo.bicep`

```bash
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# 1. Verificar Azure CLI (ja instalado no Cloud Shell)
az version

# 2. Verificar Bicep (ja instalado no Cloud Shell)
az bicep version

# 3. Verificar subscription ativa (ja autenticado!)
az account show --query "{name:name, id:id}" -o table

# 4. Instalar extensao para Container Apps (Bloco 5)
# Necessaria para: az containerapp ...
az extension add --name containerapp --upgrade 2>/dev/null

if az extension show --name containerapp &>/dev/null; then
    echo "✓ Extensao containerapp instalada: $(az extension show --name containerapp --query version -o tsv)"
else
    echo "✗ ERRO: Extensao containerapp NAO foi instalada."
    echo "  Comandos de Container Apps (Bloco 5) nao funcionarao."
    echo "  Tente manualmente: az extension add --name containerapp"
fi

# 5. Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"
```

### Conceitos Bicep Relevantes para este Lab

Antes de comecar, revise estes conceitos que serao usados extensivamente:

```bicep
// === CONCEITOS USADOS NESTE LAB ===

// 1. Decorators de validacao (muito usado em Storage)
@description('Nome da Storage Account')
@minLength(3)                          // Storage Account: minimo 3 caracteres
@maxLength(24)                         // Storage Account: maximo 24 caracteres
param storageAccountName string

// 2. @allowed: restringe valores aceitos
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS'])
param skuName string = 'Standard_LRS'

// 3. @secure: esconde senhas em logs/outputs
@secure()
param adminPassword string

// 4. Recursos filhos com parent (muito usado em Storage)
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/meu-container'
  properties: { publicAccess: 'None' }
}

// 5. Dependencias IMPLICITAS (diferente do ARM!)
//    Bicep detecta automaticamente quando um recurso referencia outro.
//    NAO precisa de "dependsOn" na maioria dos casos.

// 6. Condicional (usado para criar recursos opcionais)
param deploySlot bool = true
resource slot '...' = if (deploySlot) {
  // So cria se deploySlot == true
}

// 7. Loop for (usado para criar multiplos containers/disks)
param containerNames array = ['data', 'logs', 'backups']
resource containers '...' = [for name in containerNames: {
  name: name
  // ...
}]
```

---

## Variaveis Globais (CLI)

> **IMPORTANTE:** Exporte estas variaveis no terminal antes de iniciar.
> Os templates Bicep recebem valores via `--parameters`.

```bash
# ============================================================
# VARIAVEIS GLOBAIS - Defina no terminal ANTES de iniciar
# ============================================================

# --- Configuracoes da subscription (ALTERE estes valores) ---
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" # ← ALTERE
LOCATION="eastus"

# --- Credenciais VM ---
VM_USERNAME="localadmin"
VM_PASSWORD='SenhaComplexa@2024!'                      # ← ALTERE

# --- Resource Group ---
RG6="rg-contoso-storage"

# --- Storage ---
# Storage Account: 3-24 chars, apenas lowercase + numeros, globalmente unico
STORAGE_ACCOUNT_NAME="stcontosoprod${RANDOM}"
echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"

# --- Compute ---
WIN_VM_NAME="vm-web-01"
LINUX_VM_NAME="vm-api-01"
VMSS_NAME="vmss-contoso-web"

# --- Web App ---
APP_PLAN_NAME="asp-contoso-prod"
WEB_APP_NAME="app-contoso-web-${RANDOM}"
echo "Web App Name: $WEB_APP_NAME"

# --- Containers ---
ACI_NAME="ci-contoso-worker"
CONTAINER_APP_NAME="ca-contoso-api"
CONTAINER_ENV_NAME="cae-contoso-prod"
```

---

## Mapa de Dependencias

```
Bloco 1 (Storage)
  │
  ├─ Storage Account (stcontosoprod*) ────────────────────┐
  │   ├─ Blob Container (contoso-data)               │
  │   ├─ File Share (contoso-share)                   │
  │   ├─ Lifecycle Policy (mover para Cool/Archive)   │
  │   ├─ Private Endpoint                             │
  │   └─ Private DNS Zone + Link                      │
  │                                                   │
  │                                                   ▼
Bloco 2 (VMs) ──────────────────────────────────────────────────┐
  │                                                              │
  ├─ VNet + Subnet (para VMs + Private Endpoint)                 │
  ├─ Windows VM + NIC + Public IP                                │
  ├─ Linux VM + NIC + SSH Key                                    │
  ├─ Data Disk (attach to Windows VM)                            │
  ├─ VMSS + Autoscale                                            │
  └─ Custom Script Extension                                     │
                                                                 │
                                                                 ▼
Bloco 3 (Web Apps)
  │
  ├─ App Service Plan (Standard S1)
  ├─ Web App
  ├─ Deployment Slot (staging)
  └─ Autoscale
                                                                 ▼
Bloco 4 (ACI)
  │
  └─ Container Group (nginx)
                                                                 ▼
Bloco 5 (Container Apps)
  │
  ├─ Log Analytics Workspace
  ├─ Container Apps Environment
  └─ Container App + Scaling Rules
```

---

# Bloco 1 - Azure Storage

**Tecnologia:** Bicep
**Recursos criados:** 1 Storage Account, 1 Blob Container, 1 File Share, 1 Lifecycle Policy, 1 Private Endpoint, 1 Private DNS Zone, 1 VNet Link

> **Conceito AZ-104:** Storage Accounts sao o servico fundamental de armazenamento no Azure.
> Suportam Blobs, Files, Tables e Queues. O nome deve ser **globalmente unico** (3-24 chars, lowercase + numeros).

---

### Task 1.1: Criar Resource Group

```bash
# ============================================================
# TASK 1.1 - Criar Resource Group para todo o lab
# ============================================================

az group create --name "$RG6" --location "$LOCATION"

echo "Resource Group $RG6 criado em $LOCATION"
```

---

### Task 1.2: Criar VNet base (necessaria para Private Endpoint e VMs)

Salve como **`bloco1-vnet.bicep`**:

```bicep
// ============================================================
// bloco1-vnet.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria VNet base para todo o lab (Storage PE + VMs)
// ============================================================

@description('Localizacao dos recursos')
param location string = resourceGroup().location

// ==================== VNet ====================
// Uma unica VNet com multiplas subnets para diferentes workloads
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-contoso-hub-brazilsouth'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.40.0.0/16' ]    // Espaco de endereco amplo para o lab
    }
    subnets: [
      {
        // Subnet para VMs (Windows + Linux)
        name: 'vm-subnet'
        properties: {
          addressPrefix: '10.40.0.0/24'       // 251 IPs disponiveis
        }
      }
      {
        // Subnet para Private Endpoints (Storage, etc.)
        name: 'pe-subnet'
        properties: {
          addressPrefix: '10.40.1.0/24'
          // Private Endpoints exigem que a subnet tenha esta configuracao
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        // Subnet para VMSS
        name: 'vmss-subnet'
        properties: {
          addressPrefix: '10.40.2.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vmSubnetId string = vnet.properties.subnets[0].id
output peSubnetId string = vnet.properties.subnets[1].id
output vmssSubnetId string = vnet.properties.subnets[2].id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-vnet.bicep

echo "VNet vnet-contoso-hub-brazilsouth criada com 3 subnets"
```

---

### Task 1.3: Criar Storage Account + Blob Container + File Share

Salve como **`bloco1-storage.bicep`**:

```bicep
// ============================================================
// bloco1-storage.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Storage Account + Blob Container + File Share
// ============================================================

@description('Nome da Storage Account (globalmente unico)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Localizacao')
param location string = resourceGroup().location

@description('Tipo de redundancia')
@allowed([
  'Standard_LRS'       // Locally Redundant - 3 copias no mesmo datacenter
  'Standard_GRS'       // Geo-Redundant - 6 copias (3 primary + 3 secondary region)
  'Standard_ZRS'       // Zone-Redundant - 3 copias em zonas diferentes
  'Standard_RAGRS'     // Read-Access Geo-Redundant - GRS + leitura na secondary
])
param skuName string = 'Standard_LRS'

@description('Tier de acesso padrao')
@allowed(['Hot', 'Cool'])
param accessTier string = 'Hot'

// ==================== Storage Account ====================
// StorageV2: tipo mais comum, suporta Blob, File, Table, Queue
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'          // General-purpose v2 (recomendado)
  sku: {
    name: skuName
  }
  properties: {
    accessTier: accessTier
    // TLS 1.2: versao minima obrigatoria (seguranca)
    minimumTlsVersion: 'TLS1_2'
    // Desabilitar acesso com shared key (forcar Entra ID auth)
    // Em lab mantemos true para simplicidade
    allowSharedKeyAccess: true
    // Network ACLs: restringir acesso por rede
    networkAcls: {
      defaultAction: 'Allow'    // Em producao use 'Deny' + whitelist
      bypass: 'AzureServices'   // Permite servicos Azure (Backup, Monitor, etc.)
    }
    // Permitir acesso publico a blobs (configuravel por container)
    allowBlobPublicAccess: false
    // Habilitar hierarchical namespace para Data Lake (nao usado aqui)
    isHnsEnabled: false
  }
}

// ==================== Blob Service ====================
// Configuracoes globais do Blob service (soft delete, versioning)
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount      // 'parent' indica recurso pai (dependencia implicita!)
  name: 'default'             // Blob service sempre se chama 'default'
  properties: {
    // Soft delete: protege contra exclusao acidental
    deleteRetentionPolicy: {
      enabled: true
      days: 7                 // Manter blobs deletados por 7 dias
    }
    // Container soft delete: protege containers deletados
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ==================== Blob Container ====================
// Container para armazenar blobs (arquivos)
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService         // Filho do blob service (dependencia implicita!)
  name: 'contoso-data'
  properties: {
    // publicAccess: nivel de acesso publico
    // 'None' = privado (requer autenticacao)
    // 'Blob' = leitura publica de blobs individuais
    // 'Container' = leitura publica de todo o container
    publicAccess: 'None'
  }
}

// ==================== File Share ====================
// Azure Files: compartilhamento SMB/NFS
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'contoso-share'
  properties: {
    // Quota em GiB (maximo depende do tier)
    shareQuota: 5             // 5 GiB para o lab
    // Tier do file share
    accessTier: 'TransactionOptimized'  // Bom para workloads com muitas transacoes
    // Outros tiers: 'Hot', 'Cool', 'Premium'
  }
}

// ==================== Outputs ====================
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
output containerName string = blobContainer.name
output shareName string = fileShare.name
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-storage.bicep \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

echo "Storage Account $STORAGE_ACCOUNT_NAME criado com container e file share"

# Verificar
az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG6" \
    --query "{name:name, kind:kind, sku:sku.name, tier:accessTier, tls:minimumTlsVersion}" -o table
```

> **Comparacao Bicep vs ARM:**
> - ARM JSON: `"dependsOn": ["[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"]`
> - Bicep: `parent: storageAccount` (dependencia implicita — Bicep resolve automaticamente!)
> - ARM JSON: ~120 linhas para o mesmo resultado
> - Bicep: ~70 linhas, muito mais legivel

---

### Task 1.4: Lifecycle Management Policy

Salve como **`bloco1-lifecycle.bicep`**:

```bicep
// ============================================================
// bloco1-lifecycle.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Lifecycle Management Policy na Storage Account
// ============================================================

@description('Nome da Storage Account existente')
param storageAccountName string

// Referenciar Storage Account existente
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Referenciar Blob Service existente
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  parent: storageAccount
  name: 'default'
}

// ==================== Lifecycle Policy ====================
// Automatiza movimentacao de blobs entre tiers baseado em regras
// CONCEITO AZ-104: Hot → Cool → Archive (economia de custo)
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'            // Management policy sempre se chama 'default'
  properties: {
    policy: {
      rules: [
        {
          // Regra 1: Mover blobs antigos para Cool
          name: 'moveToCool'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                // Mover para Cool apos 30 dias sem modificacao
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
              }
            }
            filters: {
              blobTypes: [ 'blockBlob' ]
              // Aplicar apenas ao container contoso-data
              prefixMatch: [ 'contoso-data/' ]
            }
          }
        }
        {
          // Regra 2: Mover para Archive apos 90 dias
          name: 'moveToArchive'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                // Mover para Archive apos 90 dias sem modificacao
                tierToArchive: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: [ 'blockBlob' ]
              prefixMatch: [ 'contoso-data/' ]
            }
          }
        }
        {
          // Regra 3: Deletar blobs muito antigos
          name: 'deleteOldBlobs'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                // Deletar apos 365 dias sem modificacao
                delete: {
                  daysAfterModificationGreaterThan: 365
                }
              }
              // Limpar snapshots antigos tambem
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 365
                }
              }
            }
            filters: {
              blobTypes: [ 'blockBlob' ]
            }
          }
        }
      ]
    }
  }
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-lifecycle.bicep \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

echo "Lifecycle policy criada: Cool (30d) → Archive (90d) → Delete (365d)"

# Verificar
az storage account management-policy show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RG6" \
    --query "policy.rules[].{name:name, enabled:enabled}" -o table
```

> **Conceito AZ-104:** Lifecycle Management e essencial para otimizacao de custos.
> Hot tier custa mais por GB mas menos por transacao. Archive e o mais barato por GB
> mas requer reidratacao (horas) para acessar. Use lifecycle policies para automatizar.

---

### Task 1.5: Private Endpoint + Private DNS Zone

> **Cobranca:** Private Endpoints geram cobranca enquanto existirem.

Salve como **`bloco1-private-endpoint.bicep`**:

```bicep
// ============================================================
// bloco1-private-endpoint.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Private Endpoint para Storage + Private DNS Zone
// ============================================================

@description('Nome da Storage Account existente')
param storageAccountName string

@description('Localizacao')
param location string = resourceGroup().location

// ==================== Referencias Existentes ====================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'vnet-contoso-hub-brazilsouth'
}

// Referencia a subnet de Private Endpoints
resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: 'pe-subnet'
}

// ==================== Private Endpoint ====================
// Cria interface de rede privada para acessar Storage via IP interno
// CONCEITO AZ-104: Private Endpoint remove acesso publico ao recurso
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${storageAccountName}-pe'
  location: location
  properties: {
    subnet: {
      id: peSubnet.id         // Subnet onde o PE sera criado
    }
    // Conexao com o recurso de destino
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-connection'
        properties: {
          privateLinkServiceId: storageAccount.id     // Storage Account alvo
          groupIds: [ 'blob' ]  // Sub-recurso: blob, file, table, queue, web, dfs
          // 'blob' = Private Endpoint para Blob Storage
        }
      }
    ]
  }
}

// ==================== Private DNS Zone ====================
// Necessaria para resolver o nome do Storage Account para o IP privado
// Sem DNS zone: nome resolve para IP publico (ignora o PE)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  // Nome DEVE seguir o padrao do servico:
  // Blob: privatelink.blob.core.windows.net
  // File: privatelink.file.core.windows.net
  // Table: privatelink.table.core.windows.net
  name: 'privatelink.blob.core.windows.net'
  location: 'global'          // DNS zones sao sempre globais
}

// ==================== VNet Link ====================
// Vincula a DNS zone privada a VNet para que VMs resolvam o nome
resource dnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false  // Nao registrar VMs automaticamente nesta zone
  }
}

// ==================== DNS Zone Group ====================
// Registra automaticamente o IP do PE na DNS zone privada
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpoint     // Dependencia implicita: PE deve existir primeiro
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output privateEndpointIp string = privateEndpoint.properties.customDnsConfigurations[0].ipAddresses[0]
output privateDnsZoneName string = privateDnsZone.name
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-private-endpoint.bicep \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

echo "Private Endpoint + DNS Zone criados para $STORAGE_ACCOUNT_NAME"

# Verificar IP privado do PE
az network private-endpoint show \
    -g "$RG6" \
    -n "${STORAGE_ACCOUNT_NAME}-pe" \
    --query "customDnsConfigurations[0].{fqdn:fqdn, ip:ipAddresses[0]}" -o table
```

> **Conceito AZ-104:** A cadeia completa de Private Endpoint:
> 1. **Private Endpoint** cria NIC com IP privado na sua VNet
> 2. **Private DNS Zone** mapeia `storageaccount.blob.core.windows.net` → IP privado
> 3. **VNet Link** conecta a DNS zone a VNet
> 4. **DNS Zone Group** registra o IP do PE na DNS zone automaticamente
>
> Sem **todos** esses componentes, a resolucao DNS continua apontando para o IP publico!

---

### Task 1.6: Restringir acesso da Storage Account

```bash
# ============================================================
# TASK 1.6 - Restringir Storage Account para Private Endpoint only
# ============================================================
# Apos criar o PE, desabilitamos acesso publico

az storage account update \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RG6" \
    --default-action Deny \
    --bypass AzureServices

echo "Storage Account agora aceita apenas acesso via Private Endpoint + Azure Services"

# Verificar
az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG6" \
    --query "networkRuleSet.{defaultAction:defaultAction, bypass:bypass}" -o table
```

> **Dica AZ-104:** A ordem importa! Crie o Private Endpoint ANTES de bloquear acesso publico.
> Caso contrario, voce perde acesso ao storage pelo portal/CLI ate criar o PE.

---

### Task 1.6b: Service Endpoint Policy via Bicep

> **Conceito AZ-104 — Service Endpoint Policy:**
> Service Endpoint Policy restringe o trafego de Service Endpoint para recursos Azure **especificos**.
> Sem policy, qualquer Storage Account na regiao e acessivel via Service Endpoint.
> Com policy, apenas as Storage Accounts listadas sao permitidas — protege contra data exfiltration.

Salve como **`bloco1-service-endpoint-policy.bicep`**:

```bicep
// ============================================================
// bloco1-service-endpoint-policy.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Service Endpoint Policy e associa a subnet
// ============================================================

@description('Nome da Storage Account existente')
param storageAccountName string

@description('Localizacao')
param location string = resourceGroup().location

// Referencia a Storage Account existente
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ==================== Service Endpoint Policy ====================
// Restringe trafego do Service Endpoint a storage accounts especificas
// Sem policy: qualquer storage account na regiao e acessivel
// Com policy: apenas as listadas em serviceResources sao permitidas
resource serviceEndpointPolicy 'Microsoft.Network/serviceEndpointPolicies@2023-04-01' = {
  name: 'policy-storage-contoso'
  location: location
  properties: {
    serviceEndpointPolicyDefinitions: [
      {
        name: 'allow-contoso-storage'
        properties: {
          // service: qual servico Azure restringir
          service: 'Microsoft.Storage'
          // serviceResources: lista de recursos permitidos
          serviceResources: [
            storageAccount.id
          ]
        }
      }
    ]
  }
}

// ==================== Atualizar Subnet ====================
// Associar a policy a subnet que tem Service Endpoint habilitado
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: 'storage-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: vnet
  name: 'default'
  properties: {
    addressPrefix: '10.50.0.0/24'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    // serviceEndpointPolicies: associa policies a subnet
    serviceEndpointPolicies: [
      {
        id: serviceEndpointPolicy.id   // Dependencia implicita via referencia
      }
    ]
  }
}

// ==================== Outputs ====================
output policyId string = serviceEndpointPolicy.id
output policyName string = serviceEndpointPolicy.name
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-service-endpoint-policy.bicep \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

# Verificar policy associada a subnet
az network vnet subnet show -g "$RG6" --vnet-name "storage-vnet" -n "default" \
    --query "serviceEndpointPolicies[].id" -o tsv
```

---

## Modo Desafio - Bloco 1

- [ ] Criar Resource Group `rg-contoso-storage`
- [ ] Deploy `bloco1-vnet.bicep` (VNet + 3 subnets)
- [ ] Deploy `bloco1-storage.bicep` (Storage Account + Container + File Share)
- [ ] Deploy `bloco1-lifecycle.bicep` (Cool 30d → Archive 90d → Delete 365d)
- [ ] Deploy `bloco1-private-endpoint.bicep` (PE + DNS Zone + VNet Link)
- [ ] Restringir Storage Account para PE only
- [ ] Verificar IP privado do PE via CLI

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Storage Account com `defaultAction: Deny` e `bypass: AzureServices`. Azure Backup consegue acessar?**

A) Nao, Deny bloqueia tudo
B) Sim, bypass AzureServices permite servicos Azure confiados
C) Apenas com SAS token
D) Apenas via Private Endpoint

<details>
<summary>Ver resposta</summary>

**Resposta: B) Sim, bypass AzureServices permite servicos Azure confiados**

O bypass 'AzureServices' cria excecao para servicos como Backup, Monitor, Data Factory, etc.

</details>

### Questao 1.2
**Lifecycle policy move blob para Archive apos 90 dias. Usuario tenta ler o blob. O que acontece?**

A) Leitura normal
B) Erro — blob em Archive requer reidratacao antes da leitura
C) Automaticamente reidratado
D) Redirecionado para Cool tier

<details>
<summary>Ver resposta</summary>

**Resposta: B) Erro — blob em Archive requer reidratacao antes da leitura**

Archive tier requer reidratacao explicita (Standard: ate 15h, High priority: ate 1h).

</details>

### Questao 1.3
**Private Endpoint criado para Blob, mas sem Private DNS Zone. Resolucao DNS de `storage.blob.core.windows.net` retorna?**

A) IP privado do PE
B) IP publico do Storage Account
C) Erro DNS
D) IP da VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B) IP publico do Storage Account**

Sem a Private DNS Zone configurada, a resolucao DNS padrao retorna o IP publico.
O PE existe mas nao e utilizado porque o trafego vai para o IP publico.

</details>

### Questao 1.4
**Qual nome de DNS zone privada e necessario para Private Endpoint de Azure Files?**

A) `privatelink.blob.core.windows.net`
B) `privatelink.file.core.windows.net`
C) `privatelink.storage.core.windows.net`
D) `privatelink.queue.core.windows.net`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `privatelink.file.core.windows.net`**

Cada sub-recurso tem sua propria DNS zone: blob, file, table, queue, web, dfs.

</details>

---

# Bloco 2 - Azure Virtual Machines

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 Windows VM, 1 Linux VM, Data Disk, VMSS com Autoscale, Custom Script Extension

> **Nota:** VMs geram custo significativo. Faca cleanup assim que terminar.
> Use `Standard_B2s` (burstable) para minimizar custos em lab.

---

### Task 2.1: Criar Windows VM via Bicep

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

Salve como **`bloco2-windows-vm.bicep`**:

```bicep
// ============================================================
// bloco2-windows-vm.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Windows VM + NIC + Public IP
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM')
param vmName string = 'vm-web-01'

@description('Tamanho da VM')
@allowed([
  'Standard_B2s'        // Burstable: 2 vCPU, 4 GiB RAM (~$30/mes)
  'Standard_D2s_v3'     // General purpose: 2 vCPU, 8 GiB RAM (~$70/mes)
  'Standard_D4s_v3'     // General purpose: 4 vCPU, 16 GiB RAM (~$140/mes)
])
param vmSize string = 'Standard_B2s'

@description('Username do admin local')
param adminUsername string = 'localadmin'

@description('Senha do admin local')
@secure()              // @secure: valor NAO aparece em logs, outputs ou historico
param adminPassword string

// ==================== Referencia VNet existente ====================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'vnet-contoso-hub-brazilsouth'
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: 'vm-subnet'
}

// ==================== Public IP ====================
// IP publico para acesso RDP (em producao, use Bastion!)
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'          // Standard SKU (Zone-redundant)
    // Basic SKU esta sendo descontinuado!
  }
  properties: {
    publicIPAllocationMethod: 'Static'   // IP fixo (nao muda)
    // Dynamic: IP muda quando VM e desalocada
  }
}

// ==================== NIC ====================
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnet.id   // Referencia a subnet existente (dependencia implicita)
          }
          publicIPAddress: {
            id: publicIp.id   // Associa Public IP (dependencia implicita)
          }
        }
      }
    ]
  }
}

// ==================== Windows VM ====================
resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      // Windows-specific settings
      windowsConfiguration: {
        provisionVMAgent: true         // VM Agent necessario para Extensions
        enableAutomaticUpdates: true   // Windows Update automatico
        patchSettings: {
          patchMode: 'AutomaticByPlatform'  // Azure gerencia patches
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      // Imagem do SO
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      // Disco do SO
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'   // SSD padrao (bom custo-beneficio)
          // Opcoes: Standard_LRS (HDD), StandardSSD_LRS, Premium_LRS, UltraSSD_LRS
        }
        diskSizeGB: 128                // Tamanho do OS disk
        deleteOption: 'Delete'         // Deletar disco junto com a VM
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id          // Dependencia implicita: VM espera NIC
          properties: {
            deleteOption: 'Delete'   // Deletar NIC junto com a VM
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true         // Habilitar boot diagnostics (util para troubleshooting)
        // Sem storageUri = usa managed storage account (recomendado)
      }
    }
  }
}

output vmId string = windowsVm.id
output publicIpAddress string = publicIp.properties.ipAddress
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco2-windows-vm.bicep \
    --parameters adminPassword="$VM_PASSWORD"

echo "Windows VM criada"

# Obter IP publico
WIN_PIP=$(az vm show -g "$RG6" -n "$WIN_VM_NAME" -d --query publicIps -o tsv)
echo "Windows VM Public IP: $WIN_PIP"
echo "RDP: mstsc /v:$WIN_PIP"
```

> **Conceito Bicep — deleteOption:** O `deleteOption: 'Delete'` em NIC e disco faz com que
> esses recursos sejam deletados automaticamente ao deletar a VM. Sem isso, ficam orfaos.

---

### Task 2.2: Criar Linux VM com SSH via Bicep

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

Salve como **`bloco2-linux-vm.bicep`**:

```bicep
// ============================================================
// bloco2-linux-vm.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Linux VM com autenticacao SSH (sem senha!)
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM')
param vmName string = 'vm-api-01'

@description('Tamanho da VM')
param vmSize string = 'Standard_B2s'

@description('Username do admin')
param adminUsername string = 'localadmin'

@description('Chave publica SSH')
@secure()
param sshPublicKey string

// ==================== Referencia VNet existente ====================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'vnet-contoso-hub-brazilsouth'
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: 'vm-subnet'
}

// ==================== Public IP ====================
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ==================== NIC ====================
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: vmSubnet.id }
          publicIPAddress: { id: publicIp.id }
        }
      }
    ]
  }
}

// ==================== Linux VM ====================
resource linuxVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      // Linux: autenticacao SSH (melhor pratica — sem senha!)
      linuxConfiguration: {
        disablePasswordAuthentication: true    // Desabilitar login por senha
        ssh: {
          publicKeys: [
            {
              // Path padrao para chave SSH no Linux
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: { deleteOption: 'Delete' }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: { enabled: true }
    }
  }
}

output vmId string = linuxVm.id
output publicIpAddress string = publicIp.properties.ipAddress
```

Deploy:

```bash
# Gerar chave SSH se nao tiver (Cloud Shell ja pode ter em ~/.ssh/)
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco2-linux-vm.bicep \
    --parameters sshPublicKey="$SSH_KEY"

echo "Linux VM criada com autenticacao SSH"

# Obter IP publico
LINUX_PIP=$(az vm show -g "$RG6" -n "$LINUX_VM_NAME" -d --query publicIps -o tsv)
echo "Linux VM Public IP: $LINUX_PIP"
echo "SSH: ssh localadmin@$LINUX_PIP"
```

> **Comparacao Windows vs Linux (Bicep):**
> - Windows: `adminPassword` + `windowsConfiguration`
> - Linux: `sshPublicKey` + `linuxConfiguration` + `disablePasswordAuthentication: true`
> - Ambos precisam de `provisionVMAgent: true` para usar Extensions

---

### Task 2.3: Adicionar Data Disk via Bicep

Salve como **`bloco2-data-disk.bicep`**:

```bicep
// ============================================================
// bloco2-data-disk.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Data Disk e anexa a Windows VM
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM Windows existente')
param vmName string = 'vm-web-01'

@description('Tamanho do disco em GiB')
@minValue(4)
@maxValue(32767)
param diskSizeGB int = 64

@description('Tipo do disco (SKU)')
@allowed([
  'Standard_LRS'         // Standard HDD (~$0.04/GB/mes)
  'StandardSSD_LRS'      // Standard SSD (~$0.075/GB/mes)
  'Premium_LRS'          // Premium SSD (~$0.12/GB/mes)
])
param diskSku string = 'StandardSSD_LRS'

// ==================== Data Disk ====================
// Disco adicional para dados (separado do OS disk)
// CONCEITO AZ-104: Separe OS disk de data disks para:
// - Backup independente
// - Resize sem afetar OS
// - Mover dados entre VMs
resource dataDisk 'Microsoft.Compute/disks@2023-10-02' = {
  name: '${vmName}-datadisk1'
  location: location
  sku: {
    name: diskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'    // Disco vazio (outras: Copy, Upload, FromImage)
    }
    diskSizeGB: diskSizeGB
  }
}

// ==================== Referencia VM existente ====================
resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: vmName
}

// ==================== Attach Disk ====================
// NOTA: Em Bicep, para anexar disco a VM existente, precisamos
// re-declarar a VM com o dataDisks atualizado. Isso e um UPDATE,
// nao um CREATE (Bicep e declarativo — reconcilia estado).
//
// Alternativa mais simples via CLI (Task 2.3b abaixo)
```

Deploy (opcao CLI mais pratica para attach):

```bash
# ============================================================
# TASK 2.3 - Criar e anexar Data Disk (CLI + Bicep hibrido)
# ============================================================

# Criar disco via Bicep
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco2-data-disk.bicep

# Anexar disco a VM (CLI e mais simples para attach)
az vm disk attach \
    --resource-group "$RG6" \
    --vm-name "$WIN_VM_NAME" \
    --name "${WIN_VM_NAME}-datadisk1" \
    --lun 0                    # Logical Unit Number (0-based)

echo "Data Disk anexado a $WIN_VM_NAME no LUN 0"

# Verificar discos da VM
az vm show -g "$RG6" -n "$WIN_VM_NAME" \
    --query "storageProfile.dataDisks[].{name:name, lun:lun, size:diskSizeGb, sku:managedDisk.storageAccountType}" \
    -o table
```

> **Por que CLI para attach?** Bicep e declarativo — para anexar disco a VM existente,
> precisaria re-declarar TODA a VM com o disco adicionado. CLI `az vm disk attach`
> e uma operacao incremental mais simples para este caso.

---

### Task 2.4: Custom Script Extension

```bash
# ============================================================
# TASK 2.4 - Custom Script Extension (instalar IIS na Windows VM)
# ============================================================
# Custom Script Extension executa scripts dentro da VM apos provisionamento
# CONCEITO AZ-104: Extensions sao o mecanismo padrao de pos-configuracao

az vm extension set \
    --resource-group "$RG6" \
    --vm-name "$WIN_VM_NAME" \
    --name CustomScriptExtension \
    --publisher Microsoft.Compute \
    --version 1.10 \
    --settings '{"commandToExecute":"powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools"}'

echo "IIS instalado via Custom Script Extension"

# Verificar acessando o IP publico
WIN_PIP=$(az vm show -g "$RG6" -n "$WIN_VM_NAME" -d --query publicIps -o tsv)
echo "Teste: curl http://$WIN_PIP (ou abra no browser)"
```

> **Equivalente Bicep (educativo):**
> ```bicep
> resource iisExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
>   parent: windowsVm
>   name: 'installIIS'
>   location: location
>   properties: {
>     publisher: 'Microsoft.Compute'
>     type: 'CustomScriptExtension'
>     typeHandlerVersion: '1.10'
>     autoUpgradeMinorVersion: true
>     settings: {
>       commandToExecute: 'powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools'
>     }
>   }
> }
> ```

---

### Task 2.4b: Cloud-init (Custom Data) em Linux VM

```bash
# ============================================================
# TASK 2.4b - Cloud-init: configuracao automatica no 1o boot
# ============================================================
# CONCEITO AZ-104: cloud-init executa APENAS no primeiro boot (provisioning)
# Diferente de Custom Script Extension (pos-deploy) e Run Command (ad-hoc)

# Criar arquivo cloud-init.yaml
cat > cloud-init.yaml << 'CLOUDINIT'
#cloud-config
package_upgrade: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <h1>Hello from cloud-init VM</h1>
      <p>Configurado automaticamente no primeiro boot</p>
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
CLOUDINIT

# Criar VM com cloud-init
az vm create \
    --resource-group "$RG7" \
    --name vm-api-01 \
    --image Ubuntu2204 \
    --size Standard_B1s \
    --admin-username localadmin \
    --admin-password "$ADMIN_PASSWORD" \
    --vnet-name vnet-contoso-spoke-brazilsouth \
    --subnet Manufacturing \
    --custom-data cloud-init.yaml \
    --public-ip-sku Standard \
    --nsg-rule SSH

# Abrir porta 80
az vm open-port \
    --resource-group "$RG7" \
    --name vm-api-01 \
    --port 80

# Verificar - Nginx ja deve estar rodando
CLOUDINIT_PIP=$(az vm show -g "$RG7" -n vm-api-01 -d --query publicIps -o tsv)
echo "Teste: curl http://$CLOUDINIT_PIP"

# Verificar log do cloud-init
az vm run-command invoke \
    --resource-group "$RG7" \
    --name vm-api-01 \
    --command-id RunShellScript \
    --scripts "cloud-init status --long"
```

> **Equivalente Bicep (educativo):**
> ```bicep
> resource linuxVmCloudInit 'Microsoft.Compute/virtualMachines@2024-03-01' = {
>   name: 'vm-api-01'
>   location: location
>   properties: {
>     hardwareProfile: { vmSize: 'Standard_B1s' }
>     osProfile: {
>       computerName: 'vm-api-01'
>       adminUsername: adminUsername
>       adminPassword: adminPassword
>       // customData aceita conteudo em base64
>       customData: base64(loadTextContent('cloud-init.yaml'))
>     }
>     storageProfile: {
>       imageReference: {
>         publisher: 'Canonical'
>         offer: '0001-com-ubuntu-server-jammy'
>         sku: '22_04-lts-gen2'
>         version: 'latest'
>       }
>       osDisk: { createOption: 'FromImage' }
>     }
>     networkProfile: { networkInterfaces: [{ id: nic.id }] }
>   }
> }
> // NOTA: customData so e processado no 1o boot. Para reconfigurar,
> // use Custom Script Extension (Task 2.4) ou Run Command.
> ```
>
> **Comparacao para prova:**
> | Metodo | Quando executa | Windows | Linux | Caso de uso |
> |--------|----------------|---------|-------|-------------|
> | **Cloud-init** (`--custom-data`) | 1º boot | Nao | Sim | Config inicial |
> | **Custom Script Extension** | Pos-deploy | Sim | Sim | Instalar software |
> | **Run Command** | Ad-hoc | Sim | Sim | Troubleshooting |

---

### Task 2.5: Criar VMSS com Autoscale via Bicep

> **Cobranca:** Cada instancia do VMSS gera cobranca. Escale para 0 ao pausar o lab.

Salve como **`bloco2-vmss.bicep`**:

```bicep
// ============================================================
// bloco2-vmss.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria VM Scale Set + regras de Autoscale
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do VMSS')
param vmssName string = 'vmss-contoso-web'

@description('Tamanho das VMs no VMSS')
param vmSize string = 'Standard_B2s'

@description('Username do admin')
param adminUsername string = 'localadmin'

@description('Senha do admin')
@secure()
param adminPassword string

@description('Numero inicial de instancias')
@minValue(1)
@maxValue(10)
param instanceCount int = 2

// ==================== Referencia VNet existente ====================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'vnet-contoso-hub-brazilsouth'
}

resource vmssSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: 'vmss-subnet'
}

// ==================== Load Balancer ====================
// VMSS precisa de LB para distribuir trafego entre instancias
resource lbPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmssName}-lb-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: '${vmssName}-lb'
  location: location
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: { id: lbPublicIp.id }
        }
      }
    ]
    backendAddressPools: [
      { name: 'backend-pool' }
    ]
    // Health probe: verifica saude das instancias
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 15
          numberOfProbes: 2          // 2 falhas = instancia unhealthy
        }
      }
    ]
    // Regra de balanceamento
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${vmssName}-lb', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${vmssName}-lb', 'backend-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${vmssName}-lb', 'http-probe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
        }
      }
    ]
  }
}

// ==================== VM Scale Set ====================
// VMSS: grupo de VMs identicas com autoscale
// CONCEITO AZ-104: VMSS vs Availability Set
// - VMSS: escala automatica (0-1000 instancias), identicas
// - Availability Set: grupo fixo de VMs diferentes
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  name: vmssName
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount     // Numero inicial de instancias
  }
  properties: {
    // Orchestration mode: Uniform (identicas) vs Flexible (heterogeneas)
    orchestrationMode: 'Uniform'
    upgradePolicy: {
      // Modo de upgrade quando a definicao do VMSS muda
      mode: 'Automatic'        // Automatic, Manual, Rolling
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'vmss'     // VMs terao nomes vmss000000, vmss000001, etc.
        adminUsername: adminUsername
        adminPassword: adminPassword
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2022-datacenter-azure-edition'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmssName}-nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: vmssSubnet.id
                    }
                    // Associar ao backend pool do Load Balancer
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancer.name, 'backend-pool')
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      // Extension para instalar IIS em todas as instancias
      extensionProfile: {
        extensions: [
          {
            name: 'installIIS'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.10'
              autoUpgradeMinorVersion: true
              settings: {
                commandToExecute: 'powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe Add-Content -Path "C:\\inetpub\\wwwroot\\Default.htm" -Value $("VMSS Instance: " + $env:computername)'
              }
            }
          }
        ]
      }
    }
  }
}

// ==================== Autoscale ====================
// Define regras de escala automatica baseado em metricas
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${vmssName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: vmss.id    // Recurso alvo: o VMSS
    profiles: [
      {
        name: 'defaultProfile'
        // Limites de instancias
        capacity: {
          minimum: '1'        // Minimo 1 instancia
          maximum: '5'        // Maximo 5 instancias
          default: '2'        // Padrao 2 instancias
        }
        rules: [
          // Regra: Scale OUT quando CPU > 70%
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              operator: 'GreaterThan'
              threshold: 70
              timeAggregation: 'Average'
              timeGrain: 'PT1M'       // Granularidade: 1 minuto
              timeWindow: 'PT5M'      // Janela: 5 minutos
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'              // Adicionar 1 instancia
              cooldown: 'PT5M'        // Esperar 5 min antes de escalar novamente
            }
          }
          // Regra: Scale IN quando CPU < 25%
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              operator: 'LessThan'
              threshold: 25
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'              // Remover 1 instancia
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

output vmssId string = vmss.id
output lbPublicIp string = lbPublicIp.properties.ipAddress
output autoscaleId string = autoscale.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco2-vmss.bicep \
    --parameters adminPassword="$VM_PASSWORD"

echo "VMSS com autoscale criado"

# Verificar instancias
az vmss list-instances -g "$RG6" -n "$VMSS_NAME" \
    --query "[].{id:instanceId, state:provisioningState}" -o table

# Obter IP do Load Balancer
LB_PIP=$(az network public-ip show -g "$RG6" -n "${VMSS_NAME}-lb-pip" --query ipAddress -o tsv)
echo "Load Balancer IP: $LB_PIP"
echo "Teste: curl http://$LB_PIP (mostra hostname da instancia)"
```

> **Conceito AZ-104 — Autoscale:**
> - **Scale Out** (adicionar instancias): CPU > 70% por 5 min
> - **Scale In** (remover instancias): CPU < 25% por 5 min
> - **Cooldown**: periodo entre acoes de scale (evita oscilacao)
> - **Profiles**: permite regras diferentes por horario (ex: mais instancias em horario comercial)

---

## Modo Desafio - Bloco 2

- [ ] Deploy `bloco2-windows-vm.bicep` (Windows VM + Public IP + NIC)
- [ ] Deploy `bloco2-linux-vm.bicep` (Linux VM com SSH)
- [ ] Deploy `bloco2-data-disk.bicep` + `az vm disk attach` (Data Disk no LUN 0)
- [ ] Custom Script Extension: instalar IIS via CLI
- [ ] Deploy `bloco2-vmss.bicep` (VMSS + LB + Autoscale)
- [ ] Verificar VMSS instancias e acessar via Load Balancer IP
- [ ] Testar autoscale verificando regras via CLI

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**VM criada com `Standard_B2s`. Workload exige uso constante de CPU 100%. Melhor acao?**

A) Nada, B-series funciona para tudo
B) Resize para D-series (general purpose sem burst)
C) Adicionar mais vCPU na mesma serie
D) Criar VMSS

<details>
<summary>Ver resposta</summary>

**Resposta: B) Resize para D-series**

B-series e burstable — acumula creditos em baixa utilizacao e gasta em picos. Com uso constante de 100%, os creditos acabam e a performance cai. D-series oferece CPU consistente.

</details>

### Questao 2.2
**VMSS com `upgradePolicy.mode = 'Automatic'`. Voce atualiza a imagem do VMSS. O que acontece?**

A) Nada ate manual reimage
B) Todas as instancias sao atualizadas automaticamente
C) Novas instancias usam a nova imagem, existentes nao mudam
D) VMSS e recriado

<details>
<summary>Ver resposta</summary>

**Resposta: B) Todas as instancias sao atualizadas automaticamente**

Automatic mode aplica mudancas a todas as instancias. Manual mode requer `az vmss update-instances`. Rolling mode atualiza em lotes.

</details>

### Questao 2.3
**Linux VM criada com `disablePasswordAuthentication: true`. Como conectar?**

A) RDP
B) SSH com senha
C) SSH com chave publica/privada
D) Azure Bastion apenas

<details>
<summary>Ver resposta</summary>

**Resposta: C) SSH com chave publica/privada**

Com senha desabilitada, apenas autenticacao SSH key e aceita. Bastion tambem funciona, mas a questao pede o metodo direto.

</details>

### Questao 2.4
**Autoscale: Scale Out (CPU > 70%, cooldown 5 min) e Scale In (CPU < 25%, cooldown 5 min). CPU esta em 80% por 3 minutos e cai para 20%. Quantas vezes o scale out ocorre?**

A) 0 (timeWindow 5 min nao foi atingido)
B) 1
C) 3
D) Depende do numero de instancias

<details>
<summary>Ver resposta</summary>

**Resposta: A) 0**

A metrica precisa estar acima do threshold durante toda a `timeWindow` (5 min). Como ficou acima apenas 3 min, o scale out NAO e acionado.

</details>

---

# Bloco 3 - Azure App Service (Web Apps)

**Tecnologia:** Bicep
**Recursos criados:** 1 App Service Plan, 1 Web App, 1 Deployment Slot, 1 Autoscale

---

### Task 3.1: Criar App Service Plan + Web App + Slot via Bicep

> **Cobranca:** O App Service Plan gera cobranca enquanto existir, mesmo com a app parada.

Salve como **`bloco3-webapp.bicep`**:

```bicep
// ============================================================
// bloco3-webapp.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria App Service Plan + Web App + Deployment Slot
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do App Service Plan')
param planName string

@description('Nome do Web App (globalmente unico)')
param webAppName string

@description('SKU do App Service Plan')
@allowed([
  'F1'       // Free: 1 GB RAM, 60 min CPU/dia, sem slots
  'B1'       // Basic: 1.75 GB, sem autoscale, sem slots
  'S1'       // Standard: 1.75 GB, autoscale, 5 slots
  'P1v3'     // Premium v3: 8 GB, 20 slots, VNet integration
])
param skuName string = 'S1'

// ==================== App Service Plan ====================
// CONCEITO AZ-104: App Service Plan define os recursos (CPU, RAM, features)
// Multiplos Web Apps podem compartilhar o MESMO plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  sku: {
    name: skuName
    // capacity: numero de instancias (workers)
    capacity: 1
  }
  kind: 'app'                   // 'app' = Windows, 'linux' = Linux
  properties: {
    reserved: false              // false = Windows, true = Linux
  }
}

// ==================== Web App ====================
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id    // Referencia ao plan (dependencia implicita!)
    httpsOnly: true                     // Redirecionar HTTP → HTTPS
    siteConfig: {
      // Runtime stack
      netFrameworkVersion: 'v8.0'
      // Always On: manter app ativo (requer Basic ou superior)
      alwaysOn: true
      // HTTP version
      http20Enabled: true
      // Minimo TLS
      minTlsVersion: '1.2'
      // App settings (variaveis de ambiente)
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'ENVIRONMENT'
          value: 'production'
        }
      ]
    }
  }
}

// ==================== Deployment Slot ====================
// CONCEITO AZ-104: Slots permitem testar em staging antes de ir para producao
// Swap: troca staging ↔ production instantaneamente (sem downtime)
// Requer Standard (S1) ou superior
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = {
  parent: webApp               // Slot e filho do Web App
  name: 'staging'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: 'staging'
          // Para tornar slot-sticky (nao troca no swap):
          // Use Microsoft.Web/sites/config com slotConfigNames
        }
      ]
    }
  }
}

// ==================== Slot Config (Sticky Settings) ====================
// Define quais app settings NAO trocam durante swap
resource slotConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'slotConfigNames'
  properties: {
    appSettingNames: [
      'ENVIRONMENT'            // ENVIRONMENT fica fixo em cada slot
      // No swap: production mantem 'production', staging mantem 'staging'
    ]
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output stagingUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output planId string = appServicePlan.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco3-webapp.bicep \
    --parameters planName="$APP_PLAN_NAME" webAppName="$WEB_APP_NAME"

echo "Web App + Staging Slot criados"

# URLs
echo "Production: https://${WEB_APP_NAME}.azurewebsites.net"
echo "Staging: https://${WEB_APP_NAME}-staging.azurewebsites.net"

# Testar swap (trocar staging ↔ production)
# az webapp deployment slot swap \
#     --resource-group "$RG6" \
#     --name "$WEB_APP_NAME" \
#     --slot staging \
#     --target-slot production
```

> **Conceito AZ-104 — Deployment Slots:**
> - **Swap**: troca instantanea entre slots (staging ↔ production)
> - **Sticky Settings**: app settings que NAO trocam no swap (ex: connection strings de staging)
> - **Warm-up**: Azure faz request ao slot antes do swap (evita cold start)
> - **Auto Swap**: swap automatico apos deploy no slot de origem

---

### Task 3.2: Autoscale para App Service Plan

Salve como **`bloco3-webapp-autoscale.bicep`**:

```bicep
// ============================================================
// bloco3-webapp-autoscale.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Autoscale para App Service Plan
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do App Service Plan existente')
param planName string

// Referencia ao App Service Plan existente
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName
}

// ==================== Autoscale ====================
// App Service autoscale funciona no PLAN (nao no Web App)
// Todas as apps no plan escalam juntas
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${planName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: '1'
          maximum: '3'         // Maximo 3 workers
          default: '1'
        }
        rules: [
          // Scale Out: CPU > 70%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              operator: 'GreaterThan'
              threshold: 70
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          // Scale In: CPU < 25%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              operator: 'LessThan'
              threshold: 25
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

output autoscaleId string = autoscale.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco3-webapp-autoscale.bicep \
    --parameters planName="$APP_PLAN_NAME"

echo "Autoscale configurado para $APP_PLAN_NAME (1-3 instancias)"

# Verificar
az monitor autoscale show \
    --name "${APP_PLAN_NAME}-autoscale" \
    --resource-group "$RG6" \
    --query "{enabled:enabled, min:profiles[0].capacity.minimum, max:profiles[0].capacity.maximum}" \
    -o table
```

> **Conceito AZ-104:** Autoscale no App Service atua no **Plan**, nao no Web App.
> Se 3 Web Apps compartilham o mesmo plan, todas escalam juntas.
> Para escalar independentemente, use plans separados.

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-webapp.bicep` (Plan S1 + Web App + Staging Slot)
- [ ] Verificar URLs de production e staging
- [ ] Verificar slot config names (sticky settings)
- [ ] Deploy `bloco3-webapp-autoscale.bicep` (autoscale 1-3 instancias)
- [ ] (Bonus) Testar swap: `az webapp deployment slot swap`

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Web App no plan Free (F1). Voce tenta criar deployment slot. O que acontece?**

A) Slot criado com sucesso
B) Erro — slots requerem Standard (S1) ou superior
C) Slot criado mas sem swap
D) Slot criado no plan Basic

<details>
<summary>Ver resposta</summary>

**Resposta: B) Erro — slots requerem Standard (S1) ou superior**

Free e Basic NAO suportam deployment slots. Standard (S1) suporta ate 5 slots, Premium ate 20.

</details>

### Questao 3.2
**App setting `ENVIRONMENT=staging` marcada como slot-sticky. Apos swap staging ↔ production, qual valor tem production?**

A) `staging`
B) `production`
C) Vazio
D) Ambos ficam `staging`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `production`**

Sticky settings NAO trocam durante swap. Production mantem `production`, staging mantem `staging`.

</details>

### Questao 3.3
**3 Web Apps no mesmo App Service Plan S1. Autoscale configura max 3 instancias. Quanto cada app recebe?**

A) 1 instancia cada
B) Todas as 3 apps rodam em todas as 3 instancias
C) Depende do uso de CPU individual
D) Round-robin

<details>
<summary>Ver resposta</summary>

**Resposta: B) Todas as 3 apps rodam em todas as 3 instancias**

Apps no mesmo plan compartilham os mesmos workers. Autoscale atua no plan, nao em apps individuais.

</details>

---

# Bloco 4 - Azure Container Instances (ACI)

**Tecnologia:** Bicep
**Recursos criados:** 1 Container Group com nginx

---

### Task 4.1: Criar Container Group via Bicep

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running.

Salve como **`bloco4-aci.bicep`**:

```bicep
// ============================================================
// bloco4-aci.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Container Group (ACI) com nginx
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do container group')
param containerGroupName string = 'ci-contoso-worker'

@description('Imagem do container')
param containerImage string = 'mcr.microsoft.com/oss/nginx/nginx:latest'

@description('Numero de CPUs')
@allowed([1, 2, 4])
param cpuCores int = 1

@description('Memoria em GB')
@allowed([1, 2, 4])
param memoryInGB int = 1

// ==================== Container Group ====================
// CONCEITO AZ-104: ACI e a forma mais simples de rodar containers no Azure
// - Sem orquestracao (diferente de AKS)
// - Billing por segundo
// - Ideal para tarefas simples, batch jobs, dev/test
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  properties: {
    // OS Type: Linux ou Windows
    osType: 'Linux'
    // Restart policy: Always, Never, OnFailure
    restartPolicy: 'Always'
    // Containers no grupo (podem ser multiplos — sidecar pattern)
    containers: [
      {
        name: 'nginx'
        properties: {
          image: containerImage
          // Recursos: CPU e memoria por container
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          // Portas expostas pelo container
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          // Environment variables
          environmentVariables: [
            {
              name: 'NGINX_HOST'
              value: 'contoso.com'
            }
            // Para variaveis secretas:
            // {
            //   name: 'DB_PASSWORD'
            //   secureValue: 'minha-senha-secreta'  // Nao aparece em logs
            // }
          ]
        }
      }
    ]
    // IP Address: publico ou privado
    ipAddress: {
      type: 'Public'           // 'Public' ou 'Private' (requer VNet integration)
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
      // DNS name label (opcional) — cria FQDN
      dnsNameLabel: containerGroupName
    }
  }
}

output containerGroupId string = containerGroup.id
output fqdn string = containerGroup.properties.ipAddress.fqdn
output ipAddress string = containerGroup.properties.ipAddress.ip
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco4-aci.bicep

echo "Container Instance criado"

# Obter IP e FQDN
ACI_IP=$(az container show -g "$RG6" -n "$ACI_NAME" --query "ipAddress.ip" -o tsv)
ACI_FQDN=$(az container show -g "$RG6" -n "$ACI_NAME" --query "ipAddress.fqdn" -o tsv)
echo "ACI IP: $ACI_IP"
echo "ACI FQDN: $ACI_FQDN"
echo "Teste: curl http://$ACI_IP"

# Ver logs do container
az container logs -g "$RG6" -n "$ACI_NAME"
```

> **Comparacao ACI vs App Service vs AKS:**
> | Aspecto | ACI | App Service | AKS |
> |---------|-----|-------------|-----|
> | Complexidade | Baixa | Baixa | Alta |
> | Orquestracao | Nenhuma | Nenhuma | Kubernetes |
> | Scaling | Manual | Autoscale | HPA/VPA |
> | Custo | Per-second | Per-plan | Per-node |
> | Melhor para | Batch, dev/test | Web apps | Microservices |

---

## Modo Desafio - Bloco 4

- [ ] Deploy `bloco4-aci.bicep` (nginx container)
- [ ] Acessar via IP publico ou FQDN
- [ ] Verificar logs com `az container logs`
- [ ] (Bonus) Testar restart policy: `az container restart`

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Container Group com 2 containers (nginx + sidecar). Quantos IPs publicos?**

A) 2 (um por container)
B) 1 (compartilhado pelo grupo)
C) 0 (ACI nao tem IP publico)
D) Depende da configuracao

<details>
<summary>Ver resposta</summary>

**Resposta: B) 1 (compartilhado pelo grupo)**

Containers no mesmo grupo compartilham IP, rede e ciclo de vida. Comunicam via localhost.

</details>

### Questao 4.2
**ACI com `restartPolicy: 'OnFailure'`. Container termina com exit code 0. O que acontece?**

A) Reinicia automaticamente
B) Para e nao reinicia (exit code 0 = sucesso)
C) Erro
D) Reinicia apos 5 minutos

<details>
<summary>Ver resposta</summary>

**Resposta: B) Para e nao reinicia**

OnFailure reinicia apenas em exit code != 0. Always reinicia sempre. Never nunca reinicia.

</details>

---

# Bloco 5 - Azure Container Apps

**Tecnologia:** Bicep
**Recursos criados:** 1 Log Analytics Workspace, 1 Container Apps Environment, 1 Container App com scaling rules

---

### Task 5.1: Criar Container Apps Environment + App via Bicep

Salve como **`bloco5-container-apps.bicep`**:

```bicep
// ============================================================
// bloco5-container-apps.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Container Apps Environment + Container App
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do ambiente')
param environmentName string = 'cae-contoso-prod'

@description('Nome do Container App')
param containerAppName string = 'ca-contoso-api'

// ==================== Log Analytics Workspace ====================
// Container Apps Environment REQUER Log Analytics para logs
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${environmentName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'       // Pricing tier padrao
    }
    retentionInDays: 30        // Manter logs por 30 dias
  }
}

// ==================== Container Apps Environment ====================
// CONCEITO AZ-104: Container Apps Environment e o "cluster" que hospeda Container Apps
// Similar a um namespace Kubernetes, mas totalmente gerenciado
resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    // Configuracao de logs
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
        // Dependencia implicita: Bicep sabe que precisa do Log Analytics primeiro
      }
    }
    // Zone redundancy (requer VNet, nao usado neste lab)
    zoneRedundant: false
  }
}

// ==================== Container App ====================
// Container App: servico serverless para containers
// CONCEITO AZ-104: Container Apps vs ACI
// - Container Apps: autoscale baseado em regras, revisions, ingress
// - ACI: simples, sem orquestracao, per-second billing
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      // Ingress: configura acesso externo ao container
      ingress: {
        external: true            // Acessivel pela internet
        targetPort: 80            // Porta do container
        transport: 'auto'         // HTTP/1.1 ou HTTP/2
        // Traffic routing: permite split entre revisions
        traffic: [
          {
            latestRevision: true
            weight: 100            // 100% do trafego para latest revision
          }
        ]
      }
      // Registros de container (para imagens privadas)
      // registries: []
    }
    template: {
      containers: [
        {
          name: 'nginx'
          image: 'mcr.microsoft.com/oss/nginx/nginx:latest'
          resources: {
            cpu: json('0.5')       // 0.5 vCPU
            memory: '1Gi'          // 1 GiB RAM
          }
          // Environment variables
          env: [
            {
              name: 'APP_ENV'
              value: 'production'
            }
          ]
        }
      ]
      // ==================== Scaling Rules ====================
      // Autoscale baseado em regras (HTTP, CPU, custom, etc.)
      scale: {
        minReplicas: 0             // Scale to zero! (economia maxima)
        maxReplicas: 5
        rules: [
          {
            // Regra HTTP: escala baseado em requests concorrentes
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'   // 1 replica por 10 requests
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output environmentId string = containerEnv.id
output logAnalyticsId string = logAnalytics.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco5-container-apps.bicep

echo "Container Apps Environment + App criados"

# Obter URL
CONTAINER_APP_URL=$(az containerapp show \
    -g "$RG6" -n "$CONTAINER_APP_NAME" \
    --query "properties.configuration.ingress.fqdn" -o tsv)
echo "Container App URL: https://$CONTAINER_APP_URL"
echo "Teste: curl https://$CONTAINER_APP_URL"

# Ver replicas (pode ser 0 se nao houver trafego!)
az containerapp replica list -g "$RG6" -n "$CONTAINER_APP_NAME" -o table
```

> **Conceito AZ-104 — Scale to Zero:**
> Container Apps pode escalar para **0 replicas** quando nao ha trafego.
> Isso significa custo ZERO quando idle (diferente de ACI que sempre tem 1 instancia rodando).
> O primeiro request apos scale-to-zero tem latencia extra (cold start).

---

### Task 5.2: Criar nova Revision (versao)

```bash
# ============================================================
# TASK 5.2 - Criar nova revision do Container App
# ============================================================
# CONCEITO AZ-104: Revisions sao versoes imutaveis do Container App
# Permite rollback instantaneo e traffic splitting

az containerapp update \
    --resource-group "$RG6" \
    --name "$CONTAINER_APP_NAME" \
    --set-env-vars "APP_VERSION=v2"

echo "Nova revision criada"

# Listar revisions
az containerapp revision list \
    -g "$RG6" -n "$CONTAINER_APP_NAME" \
    --query "[].{name:name, active:properties.active, traffic:properties.trafficWeight}" \
    -o table
```

> **Conceito AZ-104 — Traffic Splitting:**
> Voce pode dividir trafego entre revisions (ex: 80% v1 + 20% v2).
> Isso permite canary deployments e A/B testing sem ferramentas extras.

---

## Modo Desafio - Bloco 5

- [ ] Deploy `bloco5-container-apps.bicep` (Environment + App + Scaling Rules)
- [ ] Acessar Container App via FQDN
- [ ] Verificar replicas (pode ser 0 — scale to zero)
- [ ] Criar nova revision via `az containerapp update`
- [ ] Listar revisions e verificar traffic weight

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Container App com `minReplicas: 0`. Nenhum trafego por 5 minutos. Quantas replicas?**

A) 1 (minimo sempre 1)
B) 0 (scale to zero ativo)
C) Depende do cooldown
D) Erro — minimo deve ser 1

<details>
<summary>Ver resposta</summary>

**Resposta: B) 0 (scale to zero ativo)**

Container Apps permite scale to zero quando nao ha trafego. O primeiro request aciona cold start.

</details>

### Questao 5.2
**Container Apps Environment REQUER qual recurso?**

A) Azure Container Registry
B) Log Analytics Workspace
C) Virtual Network
D) Key Vault

<details>
<summary>Ver resposta</summary>

**Resposta: B) Log Analytics Workspace**

Container Apps Environment requer Log Analytics para armazenar logs. VNet e ACR sao opcionais.

</details>

### Questao 5.3
**Qual a diferenca principal entre ACI e Container Apps?**

A) ACI suporta Linux, Container Apps nao
B) Container Apps tem autoscale (incluindo scale to zero), ACI nao
C) ACI e mais caro
D) Container Apps requer Kubernetes

<details>
<summary>Ver resposta</summary>

**Resposta: B) Container Apps tem autoscale (incluindo scale to zero), ACI nao**

Container Apps oferece autoscale baseado em regras, revisions, ingress, e scale to zero. ACI e mais simples — sem orquestracao.

</details>

---

# Bloco 6 - Storage Avancado e Disk Encryption

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 Storage Account (destino AzCopy), 1 Key Vault com 2 chaves RSA, Object Replication, CMK, ADE
**Resource Groups:** `rg-contoso-storage` (existente), `rg-contoso-compute` (existente), `rg-contoso-storage` (novo)

> **Pre-requisito:** Blocos 1 e 2 devem estar completos (Storage Account + VMs criadas).

---

### Task 6.1: Criar Storage Account de destino para AzCopy

A segunda Storage Account serve como destino para transferencias com AzCopy e como conta de destino para Object Replication.

Salve como **`bloco6-storage2.bicep`**:

```bicep
// ============================================================
// bloco6-storage2.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria segunda Storage Account para destino de AzCopy e
// Object Replication
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da Storage Account de destino (deve ser globalmente unico)')
@minLength(3)
@maxLength(24)
param storageAccountName string

// ==================== Storage Account (Destino) ====================
// CONCEITO AZ-104: Segunda Storage Account para demonstrar:
// - AzCopy entre contas (server-to-server transfer)
// - Object Replication (assincrona, cross-account)
// A conta de destino precisa de versioning habilitado para Object Replication
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'     // LRS para lab (menor custo)
  }
  kind: 'StorageV2'          // General purpose v2 — requerido para Object Replication
  properties: {
    accessTier: 'Hot'
    // Versioning e change feed sao requeridos para Object Replication
    // CONCEITO AZ-104: Versioning mantem versoes anteriores dos blobs
    // Change feed registra alteracoes (creates, updates, deletes)
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// ==================== Blob Service com Versioning ====================
// CONCEITO AZ-104: Object Replication requer versioning em AMBAS as contas
// e change feed na conta de ORIGEM
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    // Versioning: mantem snapshot automatico de cada alteracao
    isVersioningEnabled: true
    // Change feed: log de todas as mudancas nos blobs
    // Na conta de destino, change feed e opcional mas versioning e obrigatorio
    changeFeed: {
      enabled: true
    }
  }
}

// ==================== Container de Destino ====================
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'data-replica'
  properties: {
    publicAccess: 'None'     // Acesso privado — requer SAS ou auth
  }
}

// ==================== Outputs ====================
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
```

**Deploy:**

```bash
# Criar Resource Group para recursos avancados
az group create --name rg-contoso-storage --location eastus

# Gerar nome unico para a segunda Storage Account
STORAGE2_NAME="stcontosoprod01$(openssl rand -hex 3)"
echo "Storage Account 2: $STORAGE2_NAME"

# Deploy via Bicep
az deployment group create \
  -g rg-contoso-storage \
  --template-file bloco6-storage2.bicep \
  --parameters storageAccountName="$STORAGE2_NAME"
```

**Transferir blobs com AzCopy:**

```bash
# ============================================================
# AzCopy: Transferencia server-to-server entre Storage Accounts
# ============================================================

# CONCEITO AZ-104: AzCopy transfere dados pela rede backbone do Azure
# (server-to-server). Nao passa pelo seu computador local.
# Suporta: SAS tokens, Azure AD auth, access keys

# 1. Obter nome da Storage Account de origem (Bloco 1)
STORAGE1_NAME=$(az storage account list -g rg-contoso-storage \
  --query "[0].name" -o tsv)
echo "Origem: $STORAGE1_NAME"

# 2. Gerar SAS de ORIGEM (Read + List)
# CONCEITO AZ-104: SAS token permite acesso delegado sem compartilhar account keys
EXPIRY=$(date -u -d "+1 day" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+1d '+%Y-%m-%dT%H:%MZ')
SAS_ORIGEM=$(az storage account generate-sas \
  --account-name "$STORAGE1_NAME" \
  --services b \
  --resource-types sco \
  --permissions rl \
  --expiry "$EXPIRY" \
  --https-only \
  -o tsv)

# 3. Gerar SAS de DESTINO (Read + Write + List + Create)
SAS_DESTINO=$(az storage account generate-sas \
  --account-name "$STORAGE2_NAME" \
  --services b \
  --resource-types sco \
  --permissions rwlc \
  --expiry "$EXPIRY" \
  --https-only \
  -o tsv)

# 4. Executar AzCopy (server-to-server — dados nao passam pelo Cloud Shell)
azcopy copy \
  "https://${STORAGE1_NAME}.blob.core.windows.net/data?${SAS_ORIGEM}" \
  "https://${STORAGE2_NAME}.blob.core.windows.net/data-replica?${SAS_DESTINO}" \
  --recursive

# 5. Verificar blobs copiados no destino
az storage blob list \
  --account-name "$STORAGE2_NAME" \
  --container-name data-replica \
  --auth-mode login \
  -o table
```

> **Dica AZ-104:** Na prova, AzCopy e a ferramenta recomendada para transferencias em massa. Storage Explorer usa AzCopy internamente. Para copias programaticas, use `az storage blob copy` (CLI) ou `Start-AzStorageBlobCopy` (PowerShell).

---

### Task 6.2: Gerenciar blobs com Storage Explorer (versao portal)

> **Nota:** Esta task usa o portal (Storage Browser). Nao ha template Bicep — o objetivo e praticar operacoes visuais de gerenciamento de blobs.

```bash
# ============================================================
# Storage Explorer via CLI — operacoes equivalentes
# ============================================================

# 1. Upload de arquivo de teste
echo "Arquivo de teste para Storage Explorer" > /tmp/teste-explorer.txt
az storage blob upload \
  --account-name "$STORAGE1_NAME" \
  --container-name data \
  --name "teste-explorer.txt" \
  --file /tmp/teste-explorer.txt \
  --auth-mode login

# 2. Criar pasta virtual (prefixo) fazendo upload com path
echo "Log de teste" > /tmp/log-teste.txt
az storage blob upload \
  --account-name "$STORAGE1_NAME" \
  --container-name data \
  --name "logs/log-teste.txt" \
  --file /tmp/log-teste.txt \
  --auth-mode login

# 3. Gerar SAS para blob individual (mais granular que SAS de conta)
# CONCEITO AZ-104: Blob-level SAS e mais seguro que account-level SAS
BLOB_SAS=$(az storage blob generate-sas \
  --account-name "$STORAGE1_NAME" \
  --container-name data \
  --name "teste-explorer.txt" \
  --permissions r \
  --expiry "$EXPIRY" \
  --https-only \
  -o tsv)

echo "URL com SAS: https://${STORAGE1_NAME}.blob.core.windows.net/data/teste-explorer.txt?${BLOB_SAS}"
# Abra essa URL em uma aba anonima para testar acesso
```

---

### Task 6.3: Configurar Object Replication via CLI

```bash
# ============================================================
# Object Replication entre Storage Accounts
# ============================================================

# CONCEITO AZ-104: Object Replication copia blobs ASSINCRONAMENTE
# entre storage accounts. Diferente de GRS/GZRS (sincrono, gerenciado).
# Requer: versioning em AMBAS as contas + change feed na ORIGEM

# 1. Habilitar versioning + change feed na conta de ORIGEM (se ainda nao habilitados)
az storage account blob-service-properties update \
  --account-name "$STORAGE1_NAME" \
  --enable-versioning true \
  --enable-change-feed true

# 2. Verificar que a conta de DESTINO ja tem versioning (habilitado pelo Bicep)
az storage account blob-service-properties show \
  --account-name "$STORAGE2_NAME" \
  --query "{versioning: isVersioningEnabled, changeFeed: changeFeed.enabled}" \
  -o table

# 3. Criar politica de Object Replication
# A regra define: container de origem → container de destino
STORAGE1_ID=$(az storage account show -n "$STORAGE1_NAME" --query id -o tsv)
STORAGE2_ID=$(az storage account show -n "$STORAGE2_NAME" --query id -o tsv)

az storage account or-policy create \
  --account-name "$STORAGE2_NAME" \
  --source-account "$STORAGE1_NAME" \
  --destination-account "$STORAGE2_NAME" \
  --source-container data \
  --destination-container data-replica \
  --min-creation-time "$(date -u '+%Y-%m-%dT%H:%MZ')"

# 4. Validar: faça upload de um novo blob na origem
echo "Teste de replicacao $(date)" > /tmp/teste-replicacao.txt
az storage blob upload \
  --account-name "$STORAGE1_NAME" \
  --container-name data \
  --name "teste-replicacao.txt" \
  --file /tmp/teste-replicacao.txt \
  --auth-mode login

echo "Aguarde alguns minutos e verifique o blob no container data-replica da conta $STORAGE2_NAME"
```

> **Dica AZ-104:** Na prova, diferencie: GRS/GZRS = replicacao sincrona gerenciada pelo Azure (redundancia); Object Replication = replicacao assincrona configuravel pelo usuario (flexibilidade). Object Replication funciona entre qualquer regiao e qualquer conta.

---

### Task 6.4: Criar Key Vault com chaves RSA via Bicep

O Key Vault armazena as chaves de criptografia para CMK (Storage) e ADE (Disk Encryption).

Salve como **`bloco6-keyvault.bicep`**:

```bicep
// ============================================================
// bloco6-keyvault.bicep
// Scope: resourceGroup (rg-contoso-storage)
// Cria Key Vault com purge protection + 2 chaves RSA
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do Key Vault (deve ser globalmente unico)')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Object ID do usuario administrador (para RBAC)')
param adminObjectId string

// ==================== Key Vault ====================
// CONCEITO AZ-104: Key Vault armazena secrets, keys e certificates
// Purge protection: chaves deletadas NAO podem ser removidas por 90 dias
// Isso e OBRIGATORIO para CMK em Storage Accounts
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'        // Standard = software-protected keys; Premium = HSM
    }
    tenantId: subscription().tenantId
    // RBAC: modelo recomendado (vs Access Policies legado)
    enableRbacAuthorization: true
    // Purge protection: OBRIGATORIO para CMK
    // Uma vez habilitado, NAO pode ser desabilitado
    enablePurgeProtection: true
    // Soft delete: habilitado por padrao (retencao de 90 dias)
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    // Habilitar para Azure Disk Encryption
    enabledForDiskEncryption: true
    // Habilitar para deploy de templates (acesso a secrets durante deploy)
    enabledForTemplateDeployment: true
  }
}

// ==================== RBAC: Key Vault Crypto Officer ====================
// CONCEITO AZ-104: Permite ao admin criar, importar e gerenciar chaves
// Role ID fixo: 14b46e9e-c2b7-41b4-b07b-48a6ebf60603
resource cryptoOfficerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, adminObjectId, '14b46e9e-c2b7-41b4-b07b-48a6ebf60603')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '14b46e9e-c2b7-41b4-b07b-48a6ebf60603')
    principalId: adminObjectId
    principalType: 'User'
  }
}

// ==================== Chave RSA: storage-cmk ====================
// CONCEITO AZ-104: Customer-Managed Key para criptografia de Storage Account
// A Storage Account usara Managed Identity para acessar esta chave
resource storageCmkKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'storage-cmk'
  properties: {
    kty: 'RSA'                // Tipo: RSA (assimetrica)
    keySize: 2048             // Tamanho: 2048 bits (minimo recomendado)
    keyOps: [                 // Operacoes permitidas para CMK
      'wrapKey'               // Encriptar a chave de dados
      'unwrapKey'             // Decriptar a chave de dados
    ]
  }
  dependsOn: [cryptoOfficerRole]  // Precisa da permissao antes de criar a chave
}

// ==================== Chave RSA: disk-encryption ====================
// CONCEITO AZ-104: Key Encryption Key (KEK) para Azure Disk Encryption
// ADE usa BitLocker (Windows) ou DM-Crypt (Linux) + Key Vault
resource diskEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'disk-encryption'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'wrapKey'
      'unwrapKey'
      'encrypt'
      'decrypt'
    ]
  }
  dependsOn: [cryptoOfficerRole]
}

// ==================== Outputs ====================
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output storageCmkKeyUri string = storageCmkKey.properties.keyUriWithVersion
output diskEncryptionKeyUri string = diskEncryptionKey.properties.keyUriWithVersion
```

**Deploy:**

```bash
# Obter Object ID do usuario atual (para RBAC)
ADMIN_OID=$(az ad signed-in-user show --query id -o tsv)

# Gerar nome unico para Key Vault
KV_NAME="kv-contoso-prod-$(openssl rand -hex 3)"
echo "Key Vault: $KV_NAME"

# Deploy do Key Vault + chaves
az deployment group create \
  -g rg-contoso-storage \
  --template-file bloco6-keyvault.bicep \
  --parameters keyVaultName="$KV_NAME" adminObjectId="$ADMIN_OID"

# Verificar chaves criadas
az keyvault key list --vault-name "$KV_NAME" -o table
```

**Configurar CMK na Storage Account (via CLI):**

```bash
# ============================================================
# CMK: Customer-Managed Keys para Storage Account
# ============================================================

# CONCEITO AZ-104: CMK permite usar SUA chave (Key Vault) em vez da
# chave gerenciada pela Microsoft. A Storage Account precisa de
# Managed Identity para acessar o Key Vault.

# 1. Habilitar System-assigned Managed Identity na Storage Account de origem
az storage account update \
  --name "$STORAGE1_NAME" \
  --resource-group rg-contoso-storage \
  --identity-type SystemAssigned

# 2. Obter o Principal ID da Managed Identity
STORAGE_IDENTITY=$(az storage account show \
  --name "$STORAGE1_NAME" \
  --resource-group rg-contoso-storage \
  --query identity.principalId -o tsv)
echo "Storage Account Identity: $STORAGE_IDENTITY"

# 3. Atribuir role "Key Vault Crypto Service Encryption User" ao Managed Identity
# CONCEITO AZ-104: Esta role permite que a Storage Account use a chave
# para wrap/unwrap (criptografar/decriptografar) a chave de dados
az role assignment create \
  --role "Key Vault Crypto Service Encryption User" \
  --assignee-object-id "$STORAGE_IDENTITY" \
  --assignee-principal-type ServicePrincipal \
  --scope "$(az keyvault show --name $KV_NAME --query id -o tsv)"

# 4. Configurar CMK na Storage Account
az storage account update \
  --name "$STORAGE1_NAME" \
  --resource-group rg-contoso-storage \
  --encryption-key-source Microsoft.Keyvault \
  --encryption-key-vault "https://${KV_NAME}.vault.azure.net" \
  --encryption-key-name storage-cmk

# 5. Verificar configuracao
az storage account show \
  --name "$STORAGE1_NAME" \
  --resource-group rg-contoso-storage \
  --query "encryption.{keySource: keySource, keyVault: keyVaultProperties.keyVaultUri, keyName: keyVaultProperties.keyName}" \
  -o table
```

> **Dica AZ-104:** Na prova: CMK requer Key Vault com purge protection habilitado. A Storage Account precisa de Managed Identity com permissao no Key Vault. Se a chave for revogada, os dados ficam inacessiveis.

---

### Task 6.5: Configurar acesso baseado em identidade para Azure Files

> **Nota:** A configuracao completa de Entra ID auth para Azure Files requer AADDS ou hybrid join. Em ambiente de lab, exploraremos as configuracoes e entenderemos os conceitos via CLI.

```bash
# ============================================================
# Identity-based access para Azure Files
# ============================================================

# CONCEITO AZ-104: Azure Files suporta 3 metodos de autenticacao:
# 1. Storage account key (padrao, full access)
# 2. Entra ID Domain Services (AADDS)
# 3. On-premises AD DS via sync
#
# As roles RBAC especificas para SMB sao:
# - Storage File Data SMB Share Reader (leitura)
# - Storage File Data SMB Share Contributor (leitura + escrita + delete)
# - Storage File Data SMB Share Elevated Contributor (acima + NTFS ACLs)

# 1. Verificar status atual de identity-based access
az storage account show \
  --name "$STORAGE1_NAME" \
  --resource-group rg-contoso-storage \
  --query "azureFilesIdentityBasedAuthentication" \
  -o json

# 2. Listar roles RBAC disponiveis para File Shares
echo "=== Roles RBAC para Azure Files ==="
echo ""
echo "Storage File Data SMB Share Reader:"
echo "  - Read access a arquivos e diretorios via SMB"
echo ""
echo "Storage File Data SMB Share Contributor:"
echo "  - Read, write, delete em arquivos e diretorios via SMB"
echo ""
echo "Storage File Data SMB Share Elevated Contributor:"
echo "  - Acima + modificar ACLs NTFS"
echo ""
echo "CONCEITO: RBAC controla acesso no NIVEL DO SHARE."
echo "ACLs NTFS controlam acesso GRANULAR (arquivo/diretorio)."

# 3. Exemplo de como atribuir role (nao executar sem AADDS):
# az role assignment create \
#   --role "Storage File Data SMB Share Contributor" \
#   --assignee "<user-or-group-object-id>" \
#   --scope "/subscriptions/<sub-id>/resourceGroups/rg-contoso-storage/providers/Microsoft.Storage/storageAccounts/$STORAGE1_NAME/fileServices/default/fileshares/contoso-files"
```

---

### Task 6.6: Habilitar Azure Disk Encryption na VM Windows

```bash
# ============================================================
# Azure Disk Encryption (ADE) na VM Windows
# ============================================================

# CONCEITO AZ-104: ADE usa BitLocker (Windows) ou DM-Crypt (Linux)
# para criptografar discos no NIVEL DO OS.
# Diferente de SSE (Server-Side Encryption) que criptografa no storage layer.
# ADE + SSE = dupla camada de protecao.
#
# Requisitos:
# - Key Vault com enabledForDiskEncryption = true (configurado no Bicep)
# - VM deve estar RUNNING
# - Nao suportado em Basic VMs ou VMs com < 2 GB RAM

# 1. Verificar que a VM esta running
az vm show -g rg-contoso-compute -n vm-web-01 \
  --query "powerState" -o tsv --show-details

# 2. Habilitar ADE com Key Encryption Key (KEK)
# CONCEITO AZ-104: KEK adiciona camada extra — a chave do BitLocker
# e encriptada pela KEK no Key Vault
az vm encryption enable \
  --resource-group rg-contoso-compute \
  --name vm-web-01 \
  --disk-encryption-keyvault "$KV_NAME" \
  --key-encryption-key disk-encryption \
  --volume-type All

# NOTA: Este comando pode levar 10-15 minutos para completar

# 3. Verificar status da criptografia
az vm encryption show \
  --resource-group rg-contoso-compute \
  --name vm-web-01 \
  -o table

# 4. Verificar no detalhe
az vm encryption show \
  --resource-group rg-contoso-compute \
  --name vm-web-01 \
  --query "{osDisk: disks[0].statuses[0].code, dataDisk: disks[1].statuses[0].code}" \
  -o json
```

> **Dica AZ-104:** Na prova, diferencie: SSE (padrao, automatico, no storage layer) vs ADE (no OS, via BitLocker/DM-Crypt, requer Key Vault). ADE e SSE sao complementares. ADE requer Key Vault com disk encryption habilitado.

---

## Modo Desafio - Bloco 6

- [ ] Deploy `bloco6-storage2.bicep` (Storage Account de destino + container data-replica)
- [ ] Gerar SAS tokens (origem: read, destino: write) e executar AzCopy entre containers
- [ ] Usar Storage Browser para upload, criar pasta virtual e gerar SAS de blob individual
- [ ] Habilitar versioning + change feed e configurar Object Replication via CLI
- [ ] Deploy `bloco6-keyvault.bicep` (Key Vault + chaves storage-cmk e disk-encryption)
- [ ] Configurar CMK na Storage Account via Managed Identity + Key Vault
- [ ] Explorar roles RBAC para Azure Files (SMB Share Reader/Contributor/Elevated)
- [ ] Habilitar Azure Disk Encryption na VM Windows **(Bloco 2)** via Key Vault

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce precisa copiar 500 GB de blobs entre duas storage accounts em regioes diferentes. Qual ferramenta e mais eficiente?**

A) Azure Portal (upload/download manual)
B) AzCopy com SAS tokens
C) Azure Data Factory
D) Storage Explorer desktop

<details>
<summary>Ver resposta</summary>

**Resposta: B) AzCopy com SAS tokens**

AzCopy faz transferencias server-to-server (dados trafegam pela rede backbone Azure, nao pelo seu computador). Para volumes grandes entre storage accounts, e a opcao mais eficiente e rapida. Data Factory e mais indicado para pipelines complexos com transformacoes.

</details>

### Questao 6.2
**Voce configurou Object Replication da Storage Account A (East US) para Storage Account B (West Europe). Um blob existente no container de origem nao aparece no destino. Por que?**

A) Object Replication nao funciona entre regioes diferentes
B) Object Replication replica apenas blobs criados apos a configuracao da regra (por padrao)
C) O blob esta no tier Archive e nao pode ser replicado
D) Voce precisa executar AzCopy manualmente para blobs existentes

<details>
<summary>Ver resposta</summary>

**Resposta: B) Object Replication replica apenas blobs criados apos a configuracao da regra (por padrao)**

Por padrao, Object Replication so replica novos blobs. Para incluir blobs existentes, habilite "Copy over existing blobs". Object Replication funciona entre qualquer regiao e qualquer conta StorageV2.

</details>

### Questao 6.3
**Voce quer configurar Customer-Managed Keys (CMK) para uma Storage Account. Qual configuracao do Key Vault e OBRIGATORIA?**

A) Soft delete habilitado
B) Purge protection habilitado
C) Network firewall configurado
D) Access policy com Wrap/Unwrap Key

<details>
<summary>Ver resposta</summary>

**Resposta: B) Purge protection habilitado**

CMK requer que o Key Vault tenha purge protection habilitado. Isso garante que chaves deletadas nao possam ser permanentemente removidas por 90 dias, protegendo contra perda acidental de acesso aos dados criptografados.

</details>

### Questao 6.4
**Qual a diferenca entre Azure Disk Encryption (ADE) e Server-Side Encryption (SSE)?**

A) ADE e SSE sao a mesma coisa com nomes diferentes
B) ADE criptografa no nivel do OS (BitLocker/DM-Crypt); SSE criptografa no nivel do storage service
C) SSE requer Key Vault; ADE nao
D) ADE esta disponivel apenas para VMs Linux

<details>
<summary>Ver resposta</summary>

**Resposta: B) ADE criptografa no nivel do OS (BitLocker/DM-Crypt); SSE criptografa no nivel do storage service**

SSE e habilitado por padrao em todos os managed disks (storage layer). ADE usa BitLocker (Windows) ou DM-Crypt (Linux) no nivel do OS. Ambos podem ser usados simultaneamente para dupla camada de protecao.

</details>

### Questao 6.5
**Voce precisa conceder acesso a um Azure File Share para usuarios usando credenciais do Entra ID. Qual role RBAC permite leitura e escrita?**

A) Storage Account Contributor
B) Storage Blob Data Contributor
C) Storage File Data SMB Share Contributor
D) Reader

<details>
<summary>Ver resposta</summary>

**Resposta: C) Storage File Data SMB Share Contributor**

As roles especificas para Azure Files via SMB sao: Reader (leitura), Contributor (leitura + escrita + exclusao) e Elevated Contributor (acima + modificar ACLs NTFS). Storage Blob Data Contributor e para blobs, nao files.

</details>

---

# Bloco 7 - ACR e App Service Avancado

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 Azure Container Registry (Basic), 1 ACI from ACR, App Service configs (custom domain, TLS, backup, VNet integration)
**Resource Groups:** `rg-contoso-compute` (existente), `rg-contoso-computeacr` (novo)

> **Pre-requisito:** Blocos 1 e 3 devem estar completos (Storage Account + App Service criados).

---

### Task 7.1: Criar Azure Container Registry via Bicep

Salve como **`bloco7-acr.bicep`**:

```bicep
// ============================================================
// bloco7-acr.bicep
// Scope: resourceGroup (rg-contoso-computeacr)
// Cria Azure Container Registry (Basic) com admin user
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do ACR (deve ser globalmente unico, apenas alfanumerico)')
@minLength(5)
@maxLength(50)
param acrName string

// ==================== Azure Container Registry ====================
// CONCEITO AZ-104: ACR e um registro privado de containers (Docker-compatible)
// SKUs e suas diferencas (importante para a prova):
// - Basic: 10 GiB, sem webhooks avancados
// - Standard: 100 GiB, webhooks, replicacao (mesma regiao)
// - Premium: 500 GiB, geo-replication, private link, content trust, CMK
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'              // Basic para lab (menor custo)
  }
  properties: {
    // Admin user: habilita autenticacao por username/password
    // CONCEITO AZ-104: Admin user e para dev/test. Em producao,
    // use Managed Identity ou Service Principal
    adminUserEnabled: true
    // Politicas de seguranca
    policies: {
      quarantinePolicy: {
        status: 'disabled'     // Quarentena de imagens (Premium only)
      }
      retentionPolicy: {
        status: 'disabled'     // Retencao de manifests nao-tagados (Premium only)
      }
    }
  }
}

// ==================== Outputs ====================
output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
// CONCEITO AZ-104: Login server = <acrname>.azurecr.io
// Usado para push/pull de imagens: docker push <loginServer>/image:tag
```

**Deploy:**

```bash
# Criar Resource Group para ACR
az group create --name rg-contoso-computeacr --location eastus

# Gerar nome unico para ACR (apenas alfanumerico, sem hifens)
ACR_NAME="acrcontosoprod$(openssl rand -hex 3)"
echo "ACR: $ACR_NAME"

# Deploy via Bicep
az deployment group create \
  -g rg-contoso-computeacr \
  --template-file bloco7-acr.bicep \
  --parameters acrName="$ACR_NAME"

# Verificar login server
az acr show --name "$ACR_NAME" --query loginServer -o tsv
```

---

### Task 7.2: Build e push de imagem via az acr build

```bash
# ============================================================
# ACR Build: Construir imagem no cloud (sem Docker local)
# ============================================================

# CONCEITO AZ-104: az acr build executa o build no ACR Tasks
# Envia Dockerfile + contexto ao ACR que faz o build e armazena
# Ideal para CI/CD e ambientes sem Docker instalado

# 1. Criar Dockerfile simples
mkdir -p ~/acr-lab && cd ~/acr-lab

cat > Dockerfile << 'EOF'
FROM mcr.microsoft.com/hello-world
EOF

# 2. Executar build no ACR
az acr build \
  --registry "$ACR_NAME" \
  --image sample-app:v1 \
  --file Dockerfile .

# 3. Verificar imagem no repositorio
az acr repository list --name "$ACR_NAME" -o table
az acr repository show-tags --name "$ACR_NAME" --repository sample-app -o table
```

---

### Task 7.3: Deploy ACI a partir de imagem privada do ACR via Bicep

Salve como **`bloco7-aci-from-acr.bicep`**:

```bicep
// ============================================================
// bloco7-aci-from-acr.bicep
// Scope: resourceGroup (rg-contoso-computeacr)
// Cria ACI puxando imagem de um ACR privado
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do container instance')
param containerName string = 'ci-contoso-worker'

@description('Login server do ACR (ex: acrcontosoprod123.azurecr.io)')
param acrLoginServer string

@description('Username do ACR (admin user)')
@secure()
param acrUsername string

@description('Password do ACR (admin user)')
@secure()
param acrPassword string

@description('Imagem com tag (ex: sample-app:v1)')
param imageName string = 'sample-app:v1'

// ==================== Container Instance from ACR ====================
// CONCEITO AZ-104: ACI pode puxar imagens de registros privados
// Metodos de autenticacao: admin user, service principal, managed identity
// Em producao, prefira managed identity para eliminar credenciais hardcoded
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    // Credenciais para acessar o ACR privado
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
    containers: [
      {
        name: containerName
        properties: {
          // Imagem completa: <loginServer>/<image>:<tag>
          image: '${acrLoginServer}/${imageName}'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
  }
}

// ==================== Outputs ====================
output containerFqdn string = containerGroup.properties.ipAddress.fqdn
output containerIp string = containerGroup.properties.ipAddress.ip
```

**Deploy:**

```bash
# Obter credenciais do ACR
ACR_LOGIN=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

# Deploy ACI from ACR
az deployment group create \
  -g rg-contoso-computeacr \
  --template-file bloco7-aci-from-acr.bicep \
  --parameters \
    acrLoginServer="$ACR_LOGIN" \
    acrUsername="$ACR_USER" \
    acrPassword="$ACR_PASS" \
    imageName="sample-app:v1"

# Verificar status
az container show -g rg-contoso-computeacr -n ci-contoso-worker \
  --query "{status: instanceView.state, ip: ipAddress.ip}" -o table

# Ver logs do container
az container logs -g rg-contoso-computeacr -n ci-contoso-worker
```

---

### Task 7.4: Mapear dominio DNS customizado para App Service (walkthrough)

> **Nota:** Esta task documenta o processo. Em ambiente de lab sem dominio comprado, explore as opcoes no portal.

```bash
# ============================================================
# Custom Domain para App Service (walkthrough)
# ============================================================

# CONCEITO AZ-104: Dominios customizados requerem:
# 1. CNAME record (para subdomain: www.contoso.com)
#    OU A record (para apex domain: contoso.com)
# 2. TXT record para verificacao de propriedade (asuid.<subdomain>)
#
# IMPORTANTE: Free/Shared tier NAO suporta custom domains
# Requer Basic ou superior

# Obter nome do App Service (Bloco 3)
APP_NAME=$(az webapp list -g rg-contoso-compute --query "[0].name" -o tsv)
echo "App Service: $APP_NAME"
echo "Default FQDN: $APP_NAME.azurewebsites.net"

# Verificar Custom Domain Verification ID
az webapp show -g rg-contoso-compute -n "$APP_NAME" \
  --query "hostNames" -o json

# Processo de mapeamento (documentacao):
echo ""
echo "=== PROCESSO DE CUSTOM DOMAIN ==="
echo ""
echo "1. No provedor DNS, criar:"
echo "   CNAME  www        → $APP_NAME.azurewebsites.net"
echo "   TXT    asuid.www  → [Custom Domain Verification ID do portal]"
echo ""
echo "2. No portal: App Service > Custom domains > + Add custom domain"
echo "3. O Azure verifica CNAME e TXT antes de vincular"
echo ""
echo "Para apex domain (contoso.com sem subdomain):"
echo "   A record → [IP do App Service]"
echo "   TXT asuid → [Verification ID]"
```

---

### Task 7.5: Configurar TLS/SSL no App Service

```bash
# ============================================================
# TLS/SSL para App Service
# ============================================================

# CONCEITO AZ-104: HTTPS Only forca redirecionamento HTTP → HTTPS (301)
# TLS 1.2 e o minimo recomendado — versoes 1.0/1.1 tem vulnerabilidades
#
# Tipos de certificado:
# - App Service Managed Certificate: gratis, automatico, so subdomains
# - Import from Key Vault: certificado do Key Vault
# - Upload .pfx: certificado proprio
#
# Binding types: SNI SSL (padrao) vs IP-based SSL (requer IP dedicado)

# 1. Configurar HTTPS Only
az webapp update \
  --resource-group rg-contoso-compute \
  --name "$APP_NAME" \
  --https-only true

# 2. Configurar TLS minimo 1.2
az webapp config set \
  --resource-group rg-contoso-compute \
  --name "$APP_NAME" \
  --min-tls-version 1.2

# 3. Verificar configuracao
az webapp show \
  --resource-group rg-contoso-compute \
  --name "$APP_NAME" \
  --query "{httpsOnly: httpsOnly, minTls: siteConfig.minTlsVersion}" \
  -o table
```

```bash
# TASK 7.5 (validacao) - Testar redirect HTTP → HTTPS
# HTTPS Only forca redirect 301 de HTTP para HTTPS
WEBAPP_URL=$(az webapp show -g rg-contoso-compute -n "$APP_NAME" --query "defaultHostName" -o tsv)
curl -I http://$WEBAPP_URL 2>/dev/null | head -5
# Resultado esperado:
# HTTP/1.1 301 Moved Permanently
# Location: https://$WEBAPP_URL/
echo "Redirect HTTP → HTTPS configurado com sucesso"
```

---

### Task 7.6: Configurar backup do App Service para Storage Account

```bash
# ============================================================
# App Service Backup para Storage Account
# ============================================================

# CONCEITO AZ-104: App Service Backup cria snapshot completo:
# - Codigo da aplicacao
# - Configuracoes (app settings, connection strings)
# - Conteudo (wwwroot)
# - Opcionalmente: banco de dados vinculado
# Limite: 10 GB por app. Requer Standard tier ou superior.

# 1. Criar container para backups na Storage Account do Bloco 1
az storage container create \
  --account-name "$STORAGE1_NAME" \
  --name webapp-backups \
  --auth-mode login

# 2. Gerar SAS para o container de backup
# O App Service precisa de SAS para gravar os backups
BACKUP_EXPIRY=$(date -u -d "+1 year" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+1y '+%Y-%m-%dT%H:%MZ')
BACKUP_SAS=$(az storage container generate-sas \
  --account-name "$STORAGE1_NAME" \
  --name webapp-backups \
  --permissions rwdl \
  --expiry "$BACKUP_EXPIRY" \
  --https-only \
  -o tsv)

BACKUP_URL="https://${STORAGE1_NAME}.blob.core.windows.net/webapp-backups?${BACKUP_SAS}"

# 3. Configurar backup agendado (diario, 30 dias de retencao)
az webapp config backup update \
  --resource-group rg-contoso-compute \
  --webapp-name "$APP_NAME" \
  --container-url "$BACKUP_URL" \
  --frequency 1d \
  --retain-one-always true \
  --retention 30

# 4. Executar backup imediato
az webapp config backup create \
  --resource-group rg-contoso-compute \
  --webapp-name "$APP_NAME" \
  --container-url "$BACKUP_URL"

# 5. Verificar status do backup
az webapp config backup list \
  --resource-group rg-contoso-compute \
  --webapp-name "$APP_NAME" \
  -o table

echo "Verifique o arquivo .zip no container webapp-backups da conta $STORAGE1_NAME"
```

> **Conexao com Bloco 1:** O backup e armazenado na Storage Account criada no Bloco 1, demonstrando integracao entre servicos.

---

### Task 7.7: Configurar VNet Integration no App Service

```bash
# ============================================================
# VNet Integration para App Service (outbound traffic)
# ============================================================

# CONCEITO AZ-104:
# VNet Integration = OUTBOUND (App Service acessa recursos na VNet)
# Private Endpoint = INBOUND (VNet acessa App Service)
# Requer subnet DEDICADA (/28 minimo), sem outros recursos
# Funciona com peering e ExpressRoute

# 1. Verificar VNets disponiveis (vnet-contoso-hub-brazilsouth da Semana 1)
az network vnet list \
  --query "[?contains(name, 'CoreServices')].{name:name, rg:resourceGroup, addressSpace:addressSpace.addressPrefixes[0]}" \
  -o table

# 2. Criar subnet dedicada para App Service (se necessario)
# A subnet precisa ser delegada ao Microsoft.Web/serverFarms
VNET_RG="rg-contoso-network"  # RG da VNet da Semana 1
VNET_NAME="vnet-contoso-hub-brazilsouth"

az network vnet subnet create \
  --resource-group "$VNET_RG" \
  --vnet-name "$VNET_NAME" \
  --name WebAppSubnet \
  --address-prefix 10.20.50.0/24 \
  --delegations Microsoft.Web/serverFarms \
  2>/dev/null || echo "Subnet ja existe ou VNet nao encontrada"

# 3. Configurar VNet Integration
az webapp vnet-integration add \
  --resource-group rg-contoso-compute \
  --name "$APP_NAME" \
  --vnet "$VNET_NAME" \
  --subnet WebAppSubnet

# 4. Verificar integracao
az webapp vnet-integration list \
  --resource-group rg-contoso-compute \
  --name "$APP_NAME" \
  -o table

echo ""
echo "O App Service agora pode acessar:"
echo "  - Private Endpoints na VNet (ex: Storage Account do Bloco 1)"
echo "  - VMs em subnets da mesma VNet"
echo "  - Recursos em VNets peered"
```

> **Conexao com Semana 1:** O App Service agora pode acessar o Storage Account via Private Endpoint pela vnet-contoso-hub-brazilsouth, garantindo trafego privado.

---

## Modo Desafio - Bloco 7

- [ ] Deploy `bloco7-acr.bicep` (ACR Basic com admin user)
- [ ] Criar Dockerfile e executar `az acr build` para gerar imagem `sample-app:v1`
- [ ] Deploy `bloco7-aci-from-acr.bicep` (ACI puxando imagem privada do ACR)
- [ ] Explorar Custom Domain no App Service **(Bloco 3)** — CNAME + TXT verification
- [ ] Configurar HTTPS Only + TLS 1.2 no App Service
- [ ] Configurar backup do App Service para Storage Account **(Bloco 1)** com schedule diario
- [ ] Configurar VNet Integration no App Service com vnet-contoso-hub-brazilsouth **(Semana 1)**

---

## Questoes de Prova - Bloco 7

### Questao 7.1
**Voce precisa construir uma imagem de container sem instalar Docker localmente. Qual servico permite isso?**

A) Azure Container Instances
B) Azure Container Registry Tasks (az acr build)
C) Azure Kubernetes Service
D) Azure App Service

<details>
<summary>Ver resposta</summary>

**Resposta: B) Azure Container Registry Tasks (az acr build)**

ACR Tasks permite executar builds de imagens no cloud. O comando `az acr build` envia o Dockerfile e contexto para o ACR, que executa o build e armazena a imagem. Nao requer Docker localmente.

</details>

### Questao 7.2
**Voce quer mapear `api.contoso.com` para um App Service. Qual registro DNS voce deve criar?**

A) A record apontando para o IP do App Service
B) CNAME record apontando para `*.azurewebsites.net`
C) MX record apontando para o App Service
D) SRV record com a porta 443

<details>
<summary>Ver resposta</summary>

**Resposta: B) CNAME record apontando para `*.azurewebsites.net`**

Para subdomains (www, api), use CNAME apontando para o FQDN do App Service. Para apex domain (contoso.com), use A record + TXT para verificacao.

</details>

### Questao 7.3
**Qual SKU do ACR suporta geo-replicacao e Private Link?**

A) Basic  B) Standard  C) Premium  D) Todas

<details>
<summary>Ver resposta</summary>

**Resposta: C) Premium**

Apenas Premium suporta geo-replicacao, Private Link, content trust e CMK. Basic = 10 GiB; Standard = 100 GiB; Premium = 500 GiB.

</details>

### Questao 7.4
**VNet Integration em um App Service permite o que?**

A) Usuarios na VNet acessam o App Service via IP privado
B) O App Service envia trafego outbound pela VNet para acessar recursos privados
C) O App Service e implantado na VNet
D) O App Service recebe IP publico da VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B) O App Service envia trafego outbound pela VNet para acessar recursos privados**

VNet Integration = outbound. Para inbound via IP privado, use Private Endpoints. Requer subnet dedicada (/28 minimo).

</details>

### Questao 7.5
**Backup automatico de App Service requer quais componentes?**

A) Free tier + Blob storage
B) Standard tier ou superior + Storage Account com container
C) Qualquer tier + Azure Backup vault
D) Premium tier + Azure Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) Standard tier ou superior + Storage Account com container**

App Service Backup requer Standard+ e uma Storage Account com container blob. Limite: 10 GB por app. Inclui codigo, configuracao e opcionalmente banco de dados.

</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```bash
# Pausar
az vm deallocate -g rg-contoso-compute -n vm-web-01 --no-wait
az vm deallocate -g rg-contoso-compute -n vm-api-01 --no-wait
az vmss scale -g rg-contoso-compute -n vmss-contoso-web --new-capacity 0
az container stop -g rg-contoso-compute -n ci-contoso-worker
az container stop -g rg-contoso-compute -n ci-contoso-worker
az container stop -g rg-contoso-computeacr -n ci-contoso-worker

# Retomar
az vm start -g rg-contoso-compute -n vm-web-01 --no-wait
az vm start -g rg-contoso-compute -n vm-api-01 --no-wait
az vmss scale -g rg-contoso-compute -n vmss-contoso-web --new-capacity 1
az container start -g rg-contoso-compute -n ci-contoso-worker
az container start -g rg-contoso-compute -n ci-contoso-worker
az container start -g rg-contoso-computeacr -n ci-contoso-worker
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos e IPs publicos continuam cobrando. O App Service Plan (Standard S1) cobra enquanto existir — para parar, delete o plano ou rebaixe para Free F1. Container Apps com scale-to-zero nao geram custo quando ociosas. Key Vault cobra por operacao (muito baixo custo).

---

# Cleanup Unificado

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos do lab
# ============================================================

echo "=== ATENCAO: Isso deletara TODOS os recursos do lab ==="
echo ""
read -p "Confirmar? (y/n): " CONFIRM

if [ "$CONFIRM" = "y" ]; then
    # Deletar Resource Groups (remove TODOS os recursos dentro deles)
    az group delete --name rg-contoso-storage --yes --no-wait
    az group delete --name rg-contoso-storage --yes --no-wait
    az group delete --name rg-contoso-compute --yes --no-wait
    az group delete --name rg-contoso-computeacr --yes --no-wait
    az group delete --name rg-contoso-compute --yes --no-wait
    az group delete --name rg-contoso-compute --yes --no-wait
    az group delete --name rg-contoso-compute --yes --no-wait

    # Purge Key Vault (necessario porque tem purge protection habilitado)
    # Sem purge, o nome fica reservado por 90 dias
    echo ""
    echo "Aguardando RGs serem deletados para purge do Key Vault..."
    echo "Execute manualmente apos os RGs serem deletados:"
    echo "  az keyvault purge --name $KV_NAME --location eastus"

    echo ""
    echo "=== CLEANUP INICIADO ==="
    echo "Todos os RGs sendo deletados em background."
    echo "Use 'az group list --query \"[?starts_with(name, 'rg-contoso')]\" -o table' para verificar."
else
    echo "Cleanup cancelado."
fi
```

> **Dica:** `--no-wait` retorna imediatamente sem esperar a exclusao completar.
> Key Vault com purge protection precisa de `az keyvault purge` apos o RG ser deletado, senao o nome fica reservado por 90 dias.

---

# Key Takeaways Consolidados

## Bicep vs ARM JSON vs Portal

| Aspecto | Bicep | ARM JSON | Portal |
|---------|-------|----------|--------|
| Sintaxe | Concisa, declarativa | Verbosa, JSON | Visual |
| Dependencias | **Implicitas** (automaticas) | Explicitas (`dependsOn`) | N/A |
| Type safety | Decorators (`@allowed`, `@minValue`, `@secure`) | Nenhum | Validacao visual |
| Reutilizacao | Modules, loops (`for`), condicional (`if`) | Linked/nested templates | N/A |
| Cross-RG | `existing` + `scope` | `resourceId('rg', 'type', 'name')` | Dropdown |

## Conceitos Bicep Demonstrados

| Conceito | Onde no lab |
|----------|-------------|
| `@description`, `@minLength`, `@maxLength` | `bloco1-storage.bicep` (Storage Account) |
| `@allowed` (string + int) | `bloco1-storage.bicep`, `bloco2-windows-vm.bicep` |
| `@secure()` | `bloco2-windows-vm.bicep` (senha), `bloco2-linux-vm.bicep` (SSH key), `bloco7-aci-from-acr.bicep` (ACR creds) |
| `@minValue`, `@maxValue` | `bloco2-data-disk.bicep` (tamanho disco) |
| `parent:` | `bloco1-storage.bicep`, `bloco6-keyvault.bicep` (keys → vault), `bloco6-storage2.bicep` (container → blobService) |
| `existing` keyword | `bloco1-lifecycle.bicep`, `bloco1-private-endpoint.bicep` |
| Dependencias implicitas | `bloco2-vmss.bicep` (VMSS → LB → Public IP) |
| `json()` function | `bloco5-container-apps.bicep` (CPU decimal) |
| Loop `for` | Conceito explicado em `bloco1-storage.bicep` |
| `scope:` em RBAC | `bloco6-keyvault.bicep` (roleAssignment scoped ao Key Vault) |
| `enabledForDiskEncryption` | `bloco6-keyvault.bicep` (Key Vault para ADE) |

## Comandos de Deploy

| Recurso | Comando |
|---------|---------|
| Resource Group scope | `az deployment group create -g <rg> --template-file <file.bicep>` |
| Com parametros | `--parameters param1=value1 param2=value2` |
| Com arquivo de params | `--parameters @params.json` |
| Com parametro seguro | `--parameters adminPassword="$VM_PASSWORD"` |

## Templates Criados

| Template | Recursos |
|----------|----------|
| `bloco1-vnet.bicep` | VNet + 3 subnets (VM, PE, VMSS) |
| `bloco1-storage.bicep` | Storage Account + Blob Container + File Share |
| `bloco1-lifecycle.bicep` | Lifecycle Policy (Cool 30d → Archive 90d → Delete 365d) |
| `bloco1-private-endpoint.bicep` | Private Endpoint + DNS Zone + VNet Link |
| `bloco2-windows-vm.bicep` | Windows VM + NIC + Public IP |
| `bloco2-linux-vm.bicep` | Linux VM + NIC + SSH Key |
| `bloco2-data-disk.bicep` | Data Disk (attach via CLI) |
| `bloco2-vmss.bicep` | VMSS + Load Balancer + Autoscale |
| `bloco3-webapp.bicep` | App Service Plan + Web App + Staging Slot |
| `bloco3-webapp-autoscale.bicep` | Autoscale para App Service Plan |
| `bloco4-aci.bicep` | Container Group (nginx) |
| `bloco5-container-apps.bicep` | Container Apps Environment + App + Scaling |
| `bloco6-storage2.bicep` | Storage Account (destino) + Container data-replica |
| `bloco6-keyvault.bicep` | Key Vault + chaves RSA (storage-cmk, disk-encryption) + RBAC |
| `bloco7-acr.bicep` | Azure Container Registry (Basic) |
| `bloco7-aci-from-acr.bicep` | ACI from private ACR image |

## Comparacao de Servicos de Compute

| Servico | Tipo | Scaling | Custo Minimo | Melhor Para |
|---------|------|---------|--------------|-------------|
| **VM** | IaaS | Manual/VMSS | ~$15/mes (B1s) | Controle total, legacy apps |
| **VMSS** | IaaS | Autoscale (1-1000) | ~$15/mes (1 inst) | Workloads identicos, escala horizontal |
| **App Service** | PaaS | Autoscale | Free (F1) | Web apps, APIs |
| **ACI** | CaaS | Manual | Per-second | Batch, dev/test, tarefas simples |
| **Container Apps** | CaaS | Autoscale (0-N) | Scale to zero | Microservices, event-driven |

## Hierarquia de Storage

```
Storage Account (stcontosoprod*)
├── Blob Service
│   ├── Container (contoso-data)
│   │   └── Blobs (arquivos)
│   └── Lifecycle Policy
│       ├── Hot (padrao)
│       ├── Cool (30 dias)
│       ├── Archive (90 dias)
│       └── Delete (365 dias)
├── File Service
│   └── Share (contoso-share, 5 GiB)
├── Table Service (nao usado neste lab)
├── Queue Service (nao usado neste lab)
└── Network Security
    ├── Firewall Rules (defaultAction: Deny)
    ├── Private Endpoint (pe-subnet)
    ├── Private DNS Zone (privatelink.blob.core.windows.net)
    └── VNet Link
```
