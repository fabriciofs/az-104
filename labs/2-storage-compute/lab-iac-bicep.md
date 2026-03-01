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
RG6="az104-rg6"

# --- Storage ---
# Storage Account: 3-24 chars, apenas lowercase + numeros, globalmente unico
STORAGE_ACCOUNT_NAME="az104sto${RANDOM}"
echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"

# --- Compute ---
WIN_VM_NAME="az104-winvm"
LINUX_VM_NAME="az104-linuxvm"
VMSS_NAME="az104-vmss"

# --- Web App ---
APP_PLAN_NAME="az104-plan"
WEB_APP_NAME="az104-webapp-${RANDOM}"
echo "Web App Name: $WEB_APP_NAME"

# --- Containers ---
ACI_NAME="az104-aci"
CONTAINER_APP_NAME="az104-containerapp"
CONTAINER_ENV_NAME="az104-containerenv"
```

---

## Mapa de Dependencias

```
Bloco 1 (Storage)
  │
  ├─ Storage Account (az104sto*) ────────────────────┐
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
// Scope: resourceGroup (az104-rg6)
// Cria VNet base para todo o lab (Storage PE + VMs)
// ============================================================

@description('Localizacao dos recursos')
param location string = resourceGroup().location

// ==================== VNet ====================
// Uma unica VNet com multiplas subnets para diferentes workloads
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'az104-vnet'
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

echo "VNet az104-vnet criada com 3 subnets"
```

---

### Task 1.3: Criar Storage Account + Blob Container + File Share

Salve como **`bloco1-storage.bicep`**:

```bicep
// ============================================================
// bloco1-storage.bicep
// Scope: resourceGroup (az104-rg6)
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
// Scope: resourceGroup (az104-rg6)
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
// Scope: resourceGroup (az104-rg6)
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
  name: 'az104-vnet'
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

## Modo Desafio - Bloco 1

- [ ] Criar Resource Group `az104-rg6`
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
// Scope: resourceGroup (az104-rg6)
// Cria Windows VM + NIC + Public IP
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM')
param vmName string = 'az104-winvm'

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
  name: 'az104-vnet'
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
// Scope: resourceGroup (az104-rg6)
// Cria Linux VM com autenticacao SSH (sem senha!)
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM')
param vmName string = 'az104-linuxvm'

@description('Tamanho da VM')
param vmSize string = 'Standard_B2s'

@description('Username do admin')
param adminUsername string = 'localadmin'

@description('Chave publica SSH')
@secure()
param sshPublicKey string

// ==================== Referencia VNet existente ====================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'az104-vnet'
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
// Scope: resourceGroup (az104-rg6)
// Cria Data Disk e anexa a Windows VM
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome da VM Windows existente')
param vmName string = 'az104-winvm'

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

### Task 2.5: Criar VMSS com Autoscale via Bicep

> **Cobranca:** Cada instancia do VMSS gera cobranca. Escale para 0 ao pausar o lab.

Salve como **`bloco2-vmss.bicep`**:

```bicep
// ============================================================
// bloco2-vmss.bicep
// Scope: resourceGroup (az104-rg6)
// Cria VM Scale Set + regras de Autoscale
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do VMSS')
param vmssName string = 'az104-vmss'

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
  name: 'az104-vnet'
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
// Scope: resourceGroup (az104-rg6)
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
// Scope: resourceGroup (az104-rg6)
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
// Scope: resourceGroup (az104-rg6)
// Cria Container Group (ACI) com nginx
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do container group')
param containerGroupName string = 'az104-aci'

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
// Scope: resourceGroup (az104-rg6)
// Cria Container Apps Environment + Container App
// ============================================================

@description('Localizacao')
param location string = resourceGroup().location

@description('Nome do ambiente')
param environmentName string = 'az104-containerenv'

@description('Nome do Container App')
param containerAppName string = 'az104-containerapp'

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

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```bash
# Pausar
az vm deallocate -g az104-rg7 -n az104-vm-win --no-wait
az vm deallocate -g az104-rg7 -n az104-vm-linux --no-wait
az vmss scale -g az104-rg7 -n az104-vmss --new-capacity 0
az container stop -g az104-rg9 -n az104-container-1
az container stop -g az104-rg9 -n az104-container-2

# Retomar
az vm start -g az104-rg7 -n az104-vm-win --no-wait
az vm start -g az104-rg7 -n az104-vm-linux --no-wait
az vmss scale -g az104-rg7 -n az104-vmss --new-capacity 1
az container start -g az104-rg9 -n az104-container-1
az container start -g az104-rg9 -n az104-container-2
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos e IPs publicos continuam cobrando. O App Service Plan (Standard S1) cobra enquanto existir — para parar, delete o plano ou rebaixe para Free F1. Container Apps com scale-to-zero nao geram custo quando ociosas.

---

# Cleanup Unificado

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos do lab
# ============================================================

echo "=== ATENCAO: Isso deletara TODOS os recursos do lab ==="
echo "Resource Group: $RG6"
echo ""
read -p "Confirmar? (y/n): " CONFIRM

if [ "$CONFIRM" = "y" ]; then
    # Deletar Resource Group (remove TODOS os recursos dentro dele)
    az group delete --name "$RG6" --yes --no-wait

    echo ""
    echo "=== CLEANUP INICIADO ==="
    echo "O Resource Group $RG6 esta sendo deletado em background."
    echo "Isso pode levar 5-10 minutos."
    echo ""
    echo "Para verificar status:"
    echo "  az group show --name $RG6 --query properties.provisioningState -o tsv"
else
    echo "Cleanup cancelado."
fi
```

> **Dica:** `--no-wait` retorna imediatamente sem esperar a exclusao completar.
> Util porque RGs com VMs podem demorar 5-10 minutos para deletar.

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
| `@secure()` | `bloco2-windows-vm.bicep` (senha), `bloco2-linux-vm.bicep` (SSH key) |
| `@minValue`, `@maxValue` | `bloco2-data-disk.bicep` (tamanho disco) |
| `parent:` | `bloco1-storage.bicep` (container → blobService → storageAccount) |
| `existing` keyword | `bloco1-lifecycle.bicep`, `bloco1-private-endpoint.bicep` |
| Dependencias implicitas | `bloco2-vmss.bicep` (VMSS → LB → Public IP) |
| `json()` function | `bloco5-container-apps.bicep` (CPU decimal) |
| Loop `for` | Conceito explicado em `bloco1-storage.bicep` |

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
Storage Account (az104sto*)
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
