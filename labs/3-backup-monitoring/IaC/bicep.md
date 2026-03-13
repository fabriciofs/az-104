# Lab AZ-104 - Semana 3: Tudo via Bicep

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI com Bicep ja vem pre-instalados
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.bicep`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab de backup e monitoramento usando templates Bicep + CLI.
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

# 4. Instalar extensao para Data Collection Rules (Bloco 5)
# Necessaria para: az monitor data-collection rule ...
az extension add --name monitor-control-service --upgrade 2>/dev/null

# Validar que a extensao foi instalada com sucesso
if az extension show --name monitor-control-service &>/dev/null; then
    echo "✓ Extensao monitor-control-service instalada: $(az extension show --name monitor-control-service --query version -o tsv)"
else
    echo "✗ ERRO: Extensao monitor-control-service NAO foi instalada."
    echo "  Comandos de DCR (Bloco 5) nao funcionarao."
    echo "  Tente manualmente: az extension add --name monitor-control-service"
fi

# 5. Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"
```

### O que e Bicep e por que usar em vez de ARM JSON

Bicep e a linguagem **declarativa** da Microsoft para deploy de recursos Azure. Ele e compilado para ARM JSON antes do deploy -- ou seja, tudo que Bicep faz, ARM JSON tambem faz, mas Bicep e mais legivel e menos verboso.

> **Conceito: Bicep vs ARM JSON**
>
> | Aspecto | ARM JSON | Bicep |
> |---------|----------|-------|
> | **Dependencias** | `dependsOn` explicito | Implicitas via referencias |
> | **Recursos filhos** | Nome composto + `concat` | `parent:` keyword |
> | **Sintaxe** | JSON verboso (~100 linhas) | Conciso (~30 linhas) |
> | **Deploy** | `az deployment group create` | Mesmo comando |
> | **Compilacao** | Direto | Compila para ARM JSON |
>
> Bicep NAO e uma linguagem separada do ARM -- e um **syntactic sugar** que gera ARM JSON. Na prova, questoes podem usar qualquer um dos dois.

> **Dica prova:** Na AZ-104, o conceito mais cobrado sobre Bicep e a diferenca entre `param` (input do usuario), `var` (calculado internamente) e `existing` (referencia a recurso existente sem cria-lo).

### Conceitos Basicos de Bicep

Antes de comecar, entenda estes conceitos fundamentais:

```bicep
// === CONCEITOS FUNDAMENTAIS ===

// 1. targetScope: define ONDE o template sera deployado
//    'resourceGroup' (padrao) | 'subscription' | 'managementGroup' | 'tenant'
targetScope = 'resourceGroup'

// 2. param: parametros de entrada (valores fornecidos pelo usuario)
@description('Descricao do parametro')  // Decorator: documenta
@allowed(['eastus', 'westus'])          // Decorator: restringe valores
param location string = 'eastus'        // Tipo + valor default

// 3. var: variaveis calculadas (internas ao template)
var resourceName = 'my-${location}-resource'

// 4. resource: declara um recurso Azure
//    Formato: resource <nome-simbolico> '<tipo>@<api-version>'
resource myVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: 'myVault'
  location: location
  properties: { /* ... */ }
}

// 5. existing: referencia recurso ja existente (NAO cria)
resource existingVm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: 'myVM'
}

// 6. output: valores exportados apos deploy
output vaultId string = myVault.id

// 7. Dependencias IMPLICITAS (diferente do ARM!)
//    Bicep detecta automaticamente quando um recurso referencia outro.
//    NAO precisa de "dependsOn" na maioria dos casos.
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
LOCATION_DR="westus"

# --- Credenciais VM ---
VM_USERNAME="localadmin"
VM_PASSWORD='SenhaComplexa@2024!'                        # ← ALTERE

# --- Resource Groups ---
RG11="rg-contoso-management"
RG12="rg-contoso-management"
RG13="rg-contoso-management"

# --- Backup ---
VAULT_NAME="rsv-contoso-backup"

# --- Monitoramento ---
WORKSPACE_NAME="law-contoso-prod"
ACTION_GROUP_NAME="ag-contoso-ops"
ALERT_EMAIL="seuemail@gmail.com"                         # ← ALTERE
```

---

## Mapa de Dependencias

```
Bloco 1 (VM Backup)
  │
  ├─ Recovery Services Vault ──────────────────┐
  ├─ Backup Policy (Daily, 30 dias)            │
  ├─ VM de teste (vm-web-01)                  │
  └─ Protecao + backup on-demand               │
                                               │
                                               ▼
Bloco 2 (File/Blob Protection) ────────────────────────────┐
  │                                                        │
  ├─ Storage Account (soft delete + versioning)            │
  ├─ File Share backup (vault do Bloco 1)                  │
  └─ Blob versioning + soft delete                         │
                                               │           │
                                               ▼           │
Bloco 3 (Azure Site Recovery) ◄──── DR config ─────────────┘
  │
  ├─ RSV secundario (regiao DR)
  ├─ ASR Fabric + Container + Policy
  └─ Recovery Plan + Failover (CLI)
                                               ▼
Bloco 4 (Azure Monitor)
  │
  ├─ Action Group (email)
  ├─ Metric Alert (CPU > 80%)
  └─ Activity Log Alert (VM deallocated)
                                               ▼
Bloco 5 (Log Analytics)
  ├─ Log Analytics Workspace
  ├─ VM Extension (AMA agent)
  ├─ Diagnostic Settings
  └─ Network Watcher
```

---

# Bloco 1 - VM Backup

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 RG, 1 Recovery Services Vault, 1 backup policy, 1 VM, protecao + backup

> **Conceito:** O Azure Backup usa o **Recovery Services Vault** como cofre central.
> Dentro do vault, **backup policies** definem frequencia e retencao.
> VMs sao protegidas associando-as a uma policy dentro do vault.

---

### Task 1.1: Criar Resource Group e VM de teste

A VM e criada via CLI (imperativo) porque e um recurso de suporte -- o foco deste lab e backup/monitoramento. Em cenarios reais, VMs seriam provisionadas via Bicep com `@secure()` para senhas e dependencias implicitas para a stack de rede.

```bash
# ============================================================
# TASK 1.1 - Criar RG e VM para backup (CLI)
# ============================================================
# A VM e criada via CLI para simplicidade. Em producao, use Bicep
# (veja bloco5-vms.bicep do lab Semana 1 como referencia).

az group create --name "$RG11" --location "$LOCATION"

# Criar VM simples para testar backup
az vm create \
    --resource-group "$RG11" \
    --name "vm-web-01" \
    --image "Ubuntu2204" \
    --size "Standard_B1s" \
    --admin-username "$VM_USERNAME" \
    --admin-password "$VM_PASSWORD" \
    --no-wait

echo "VM vm-web-01 sendo criada em background..."
echo "Aguarde 2-3 min antes de prosseguir"
```

> **Por que CLI e nao Bicep para a VM?** A VM aqui e recurso de suporte — o foco do lab
> e backup/monitoramento. Em cenarios reais, VMs seriam provisionadas via Bicep
> com `@secure()` para senha, como demonstrado no lab Semana 1.

---

### Task 1.2: Criar Recovery Services Vault + Backup Policy via Bicep

> **Cobranca:** O vault em si e gratuito, mas cada instancia protegida (VM, File Share) gera cobranca.

Salve como **`bloco1-backup.bicep`**:

```bicep
// ============================================================
// bloco1-backup.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria Recovery Services Vault + Backup Policy para VMs
// ============================================================

@description('Nome do Recovery Services Vault')
param vaultName string

@description('Regiao do vault')
param location string = resourceGroup().location

// ==================== Recovery Services Vault ====================
// O vault e o cofre central do Azure Backup.
// Armazena backups, replicas e metadados de protecao.
// SKU RS0/Standard e o padrao para backup (nao confundir com ASR).
resource vault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'        // Recovery Services tier 0 (padrao)
    tier: 'Standard'   // Standard tier (suficiente para backup)
  }
  properties: {}
}

// ==================== Backup Policy ====================
// Define QUANDO e POR QUANTO TEMPO manter os backups.
// backupManagementType: 'AzureIaasVM' = backup de VMs Azure
//
// Comparacao com ARM JSON:
// Em ARM, o tipo seria "Microsoft.RecoveryServices/vaults/backupPolicies"
// com dependsOn explicito no vault. Em Bicep, 'parent: vault' resolve tudo.
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: vault       // Dependencia implicita: policy e filha do vault
  name: 'rsvpol-contoso-12h'
  properties: {
    backupManagementType: 'AzureIaasVM'    // Tipo: backup de VMs IaaS
    // schedulePolicy: define QUANDO o backup roda
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'                  // Diario
      scheduleRunTimes: ['2024-01-01T02:00:00Z']     // Horario UTC (2h da manha)
    }
    // retentionPolicy: define POR QUANTO TEMPO manter
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: ['2024-01-01T02:00:00Z']
        retentionDuration: {
          count: 30              // Manter por 30 dias
          durationType: 'Days'
        }
      }
    }
  }
}

output vaultId string = vault.id
output policyName string = backupPolicy.name
```

Deploy:

```bash
# Deploy do vault + policy
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco1-backup.bicep \
    --parameters vaultName="$VAULT_NAME"

echo "Recovery Services Vault '$VAULT_NAME' + policy 'rsvpol-contoso-12h' criados"
```

> **Conceito `parent:`** Em Bicep, `parent: vault` indica que `backupPolicy` e um recurso filho
> do vault. Isso:
> 1. Define o nome completo automaticamente (`vaultName/policyName`)
> 2. Cria dependencia implicita (vault e criado antes da policy)
> 3. Equivale ao ARM JSON: `"type": "Microsoft.RecoveryServices/vaults/backupPolicies"`
>    com `"dependsOn": ["[resourceId('Microsoft.RecoveryServices/vaults', ...)]"]`

---

### Task 1.3: Habilitar protecao da VM (CLI)

> **Cobranca:** Habilitar backup gera cobranca por instancia protegida e armazenamento de snapshots.

```bash
# ============================================================
# TASK 1.3 - Habilitar backup protection na VM (CLI)
# ============================================================
# A protecao de backup (protection intent) e uma operacao de controle.
# Embora possivel via Bicep (Microsoft.RecoveryServices/vaults/backupFabrics/
# protectionContainers/protectedItems), a CLI e significativamente mais
# simples e e o padrao na documentacao oficial.

# Verificar que a VM esta pronta
az vm show -g "$RG11" -n "vm-web-01" --query "provisioningState" -o tsv

# Habilitar protecao usando a policy criada
# az backup protection enable-for-vm:
#   --vault-name: vault destino
#   --vm: ID da VM (ou nome com -g)
#   --policy-name: policy de backup a aplicar
az backup protection enable-for-vm \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --vm "vm-web-01" \
    --policy-name "rsvpol-contoso-12h"

echo "Protecao habilitada para vm-web-01"
```

> **POR QUE CLI E NAO BICEP?** Embora exista o recurso
> `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems`,
> o nome do container e do item protegido seguem convencoes complexas
> (ex: `IaasVMContainer;iaasvmcontainerv2;rg;vm` e `VM;iaasvmcontainerv2;rg;vm`).
> A CLI abstrai essa complexidade com `--vm`.

---

### Task 1.4: Disparar backup on-demand (CLI)

```bash
# ============================================================
# TASK 1.4 - Backup on-demand (CLI)
# ============================================================
# Backup agendado roda no horario definido na policy.
# Para nao esperar, disparamos um backup manual.

# Obter container name e item name (necessarios para operacoes de backup)
CONTAINER=$(az backup container list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --backup-management-type AzureIaasVM \
    --query "[0].name" -o tsv)

ITEM=$(az backup item list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --query "[0].name" -o tsv)

echo "Container: $CONTAINER"
echo "Item: $ITEM"

# Disparar backup on-demand
# --retain-until: data de retencao do recovery point
az backup protection backup-now \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --retain-until "$(date -d '+30 days' '+%d-%m-%Y' 2>/dev/null || date -v+30d '+%d-%m-%Y')"

echo "Backup on-demand disparado (pode levar 15-30 min)"
```

---

### Task 1.5: Verificar backup jobs

```bash
# ============================================================
# TASK 1.5 - Verificar jobs de backup
# ============================================================

az backup job list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --query "[].{name:name, operation:properties.operation, status:properties.status, startTime:properties.startTime}" \
    -o table

# Listar recovery points
az backup recoverypoint list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --query "[].{name:name, date:properties.recoveryPointTime, type:properties.recoveryPointType}" \
    -o table
```

> **Conceito AZ-104:** Recovery points podem ser:
> - **AppConsistent:** snapshot consistente com aplicacao (melhor qualidade)
> - **CrashConsistent:** snapshot do disco (VM desligada ou sem agent)
> - **FileSystemConsistent:** snapshot consistente com file system (Linux)

---

### Task 1.6b: Cross Region Restore (CRR)

```bash
# ============================================================
# TASK 1.6b - Configurar Cross Region Restore
# ============================================================
# IMPORTANTE: Deve ser feito ANTES de proteger qualquer item no vault.
# Nao e possivel alterar de LRS para GRS apos o primeiro backup.

az backup vault backup-properties set \
    --name "$VAULT_NAME" \
    --resource-group "$RG11" \
    --backup-storage-redundancy GeoRedundant \
    --cross-region-restore-flag true

# Verificar configuracao
az backup vault backup-properties show \
    --name "$VAULT_NAME" \
    --resource-group "$RG11" \
    --query "{redundancy:storageType, crr:crossRegionRestoreFlag}" -o table

echo "Vault configurado com GRS + Cross Region Restore"
echo "Dados serao replicados para a regiao pareada"
```

> **Conceito AZ-104 — GRS e CRR:**
> - **GRS** (Geo-Redundant Storage): replica dados para a regiao pareada do Azure
> - **CRR** (Cross Region Restore): permite restaurar backups na regiao secundaria
> - GRS custa mais que LRS (~2x), mas habilita DR cross-region
> - Em Bicep, a propriedade `storageType` do vault define LRS/GRS, mas CRR requer CLI
> - Na prova: "restaurar VM em outra regiao" = GRS + CRR habilitados no vault

---

## Modo Desafio - Bloco 1

- [ ] Criar RG `rg-contoso-management` e VM `vm-web-01`
- [ ] Deploy `bloco1-backup.bicep` (vault + policy)
- [ ] Habilitar protecao via CLI (`az backup protection enable-for-vm`)
- [ ] Disparar backup on-demand
- [ ] Verificar job e recovery points

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Qual tipo de recurso armazena backups de VMs Azure?**

A) Backup Vault
B) Recovery Services Vault
C) Storage Account
D) Key Vault

<details>
<summary>Ver resposta</summary>

**Resposta: B) Recovery Services Vault**

O Recovery Services Vault suporta backup de VMs IaaS, SQL, Files e ASR. O Backup Vault e mais novo e suporta Blobs, Disks e PostgreSQL.

</details>

### Questao 1.2
**Backup policy com retencao de 30 dias e frequencia diaria. Quantos recovery points no maximo?**

A) 7
B) 14
C) 30
D) 90

<details>
<summary>Ver resposta</summary>

**Resposta: C) 30**

Com backup diario e retencao de 30 dias, o maximo de recovery points simultaneos e 30.

</details>

### Questao 1.3
**Em Bicep, qual keyword indica que um recurso e filho de outro?**

A) `dependsOn`
B) `scope`
C) `parent`
D) `existing`

<details>
<summary>Ver resposta</summary>

**Resposta: C) `parent`**

`parent: vault` indica relacao pai-filho, gerando nome composto automatico e dependencia implicita.

</details>

---

# Bloco 2 - File/Blob Protection

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 Storage Account, file share, blob container, backup protection

> **Conceito:** Alem de VMs, o Azure Backup protege Azure Files (file shares).
> Para Blobs, a protecao e nativa via **soft delete** e **versioning** (nao requer vault).

---

### Task 2.1: Criar Storage Account com protecao nativa via Bicep

Este template demonstra a hierarquia de recursos do Storage usando `parent:` -- cada recurso filho referencia seu pai diretamente, eliminando a necessidade de nomes compostos e `dependsOn`. O Storage Account inclui protecoes nativas (soft delete, versioning, change feed) que NAO requerem Recovery Services Vault.

> **Conceito: Protecao nativa vs Backup gerenciado**
>
> | Feature | Requer Vault? | O que protege |
> |---------|--------------|---------------|
> | Soft Delete (blob/container/share) | Nao | Delecao acidental |
> | Versioning | Nao | Sobrescrita |
> | Change Feed | Nao | Auditoria de alteracoes |
> | File Share Backup | Sim (RSV) | Snapshots gerenciados com retention |
> | Blob Backup | Sim (Backup Vault) | Vaulted backup com retention |

Salve como **`bloco2-storage.bicep`**:

```bicep
// ============================================================
// bloco2-storage.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria Storage Account com soft delete + versioning + file share
// ============================================================

@description('Nome da storage account (globalmente unico)')
param storageAccountName string

@description('Regiao')
param location string = resourceGroup().location

// ==================== Storage Account ====================
// Propriedades de protecao nativa (NAO requerem vault):
// - Blob soft delete: recupera blobs deletados por N dias
// - Container soft delete: recupera containers deletados
// - Blob versioning: mantem versoes anteriores automaticamente
// - File share soft delete: recupera shares deletados
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    // Seguranca basica
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

// ==================== Blob Services ====================
// Configura protecao nativa para blobs
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    // Soft delete para blobs: recupera blobs deletados
    deleteRetentionPolicy: {
      enabled: true
      days: 14            // Manter blobs deletados por 14 dias
    }
    // Soft delete para containers: recupera containers deletados
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
    // Versioning: mantem versoes anteriores automaticamente
    // Cada modificacao cria uma nova versao (similar a git)
    isVersioningEnabled: true
    // Change feed: registra todas as alteracoes em blobs
    // Util para auditoria e processamento de eventos
    changeFeed: {
      enabled: true
      retentionInDays: 7
    }
  }
}

// ==================== File Services ====================
// Configura protecao nativa para file shares
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 14            // Manter shares deletados por 14 dias
    }
  }
}

// ==================== Blob Container ====================
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices     // Filho de blobServices (que e filho de storageAccount)
  name: 'contoso-container'
}

// ==================== File Share ====================
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileServices
  name: 'contoso-share'
  properties: {
    shareQuota: 5         // Quota de 5 GiB
    accessTier: 'Hot'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
```

Deploy:

```bash
# Gerar nome unico para storage account (deve ser globalmente unico)
STORAGE_NAME="stcontosodocs${RANDOM}"

# Deploy
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco2-storage.bicep \
    --parameters storageAccountName="$STORAGE_NAME"

echo "Storage Account '$STORAGE_NAME' criado com soft delete + versioning"
echo "Salve o nome: STORAGE_NAME=$STORAGE_NAME"
```

> **Comparacao ARM vs Bicep:**
> Em ARM JSON, cada recurso filho precisa do nome completo concatenado:
> `"name": "[concat(variables('storageName'), '/default')]"` e `dependsOn` explicito.
> Em Bicep, `parent: storageAccount` resolve nome e dependencia automaticamente.

---

### Task 2.2: Proteger File Share com backup via Bicep

Este template demonstra o uso de `existing` para referenciar recursos ja criados (vault e storage account) sem recria-los. Tambem mostra um caso raro em Bicep onde `dependsOn` EXPLICITO e necessario -- quando o recurso usa nomes concatenados (strings) em vez de referencias simbolicas, o Bicep nao detecta a dependencia automaticamente.

Salve como **`bloco2-fileshare-backup.bicep`**:

```bicep
// ============================================================
// bloco2-fileshare-backup.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria backup policy para Azure Files e protege o file share
// ============================================================

@description('Nome do Recovery Services Vault existente')
param vaultName string

@description('Nome da Storage Account')
param storageAccountName string

@description('Nome do file share a proteger')
param fileShareName string = 'contoso-share'

param location string = resourceGroup().location

// Referenciar vault existente (criado no Bloco 1)
resource vault 'Microsoft.RecoveryServices/vaults@2023-06-01' existing = {
  name: vaultName
}

// Referenciar storage account existente
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ==================== File Share Backup Policy ====================
// backupManagementType: 'AzureStorage' = backup de Azure Files
// Diferente de 'AzureIaasVM' usado para VMs
resource fileBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: vault
  name: 'fspol-contoso-daily'
  properties: {
    backupManagementType: 'AzureStorage'     // Tipo: Azure Files
    workLoadType: 'AzureFileShare'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: ['2024-01-01T03:00:00Z']     // 3h UTC
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: ['2024-01-01T03:00:00Z']
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }
    // timeZone: UTC por padrao
  }
}

// ==================== Protection Container ====================
// Registra a storage account como container de backup no vault
// O nome segue convencao: StorageContainer;storage;<rgName>;<storageAccountName>
var containerName = 'StorageContainer;storage;${resourceGroup().name};${storageAccountName}'

resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-06-01' = {
  name: '${vaultName}/Azure/${containerName}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: storageAccount.id
  }
}

// ==================== Protected Item (File Share) ====================
// Nome segue convencao: AzureFileShare;<fileShareName>
var protectedItemName = 'AzureFileShare;${fileShareName}'

resource protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-06-01' = {
  name: '${vaultName}/Azure/${containerName}/${protectedItemName}'
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    sourceResourceId: storageAccount.id
    policyId: fileBackupPolicy.id
  }
  dependsOn: [
    protectionContainer    // Dependencia EXPLICITA necessaria aqui
    // O container deve existir antes do item protegido
    // Bicep nao detecta essa dependencia automaticamente porque
    // o item referencia o container pelo nome (string), nao pela referencia
  ]
}

output policyId string = fileBackupPolicy.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco2-fileshare-backup.bicep \
    --parameters vaultName="$VAULT_NAME" storageAccountName="$STORAGE_NAME"

echo "File share 'contoso-share' protegido no vault '$VAULT_NAME'"
```

> **Conceito `dependsOn` explicito:** Na maioria dos casos, Bicep detecta dependencias
> automaticamente via referencias. Mas quando o recurso usa nomes concatenados (strings)
> em vez de referencias simbolicas, Bicep NAO consegue detectar a dependencia.
> Nesse caso, `dependsOn: [protectionContainer]` e necessario.

---

### Task 2.3: Testar protecao de blobs (CLI)

```bash
# ============================================================
# TASK 2.3 - Testar soft delete e versioning de blobs
# ============================================================

# Criar arquivo de teste
echo "Conteudo original v1" > /tmp/test-blob.txt

# Upload do blob
az storage blob upload \
    --account-name "$STORAGE_NAME" \
    --container-name "contoso-container" \
    --name "test-blob.txt" \
    --file /tmp/test-blob.txt \
    --auth-mode login

# Criar versao 2
echo "Conteudo modificado v2" > /tmp/test-blob.txt
az storage blob upload \
    --account-name "$STORAGE_NAME" \
    --container-name "contoso-container" \
    --name "test-blob.txt" \
    --file /tmp/test-blob.txt \
    --auth-mode login \
    --overwrite

# Listar versoes (demonstra versionamento)
az storage blob list \
    --account-name "$STORAGE_NAME" \
    --container-name "contoso-container" \
    --include v \
    --auth-mode login \
    --query "[].{name:name, versionId:versionId, isCurrentVersion:isCurrentVersion}" \
    -o table

# Deletar blob (soft delete mantem por 14 dias)
az storage blob delete \
    --account-name "$STORAGE_NAME" \
    --container-name "contoso-container" \
    --name "test-blob.txt" \
    --auth-mode login

# Listar blobs deletados (soft delete em acao!)
az storage blob list \
    --account-name "$STORAGE_NAME" \
    --container-name "contoso-container" \
    --include d \
    --auth-mode login \
    --query "[?deleted].{name:name, deleted:deleted}" \
    -o table

echo "✓ Blob deletado mas recuperavel via soft delete (14 dias)"
```

> **Conceito AZ-104:**
> - **Soft delete:** Recupera dados deletados acidentalmente (requer ativacao)
> - **Versioning:** Mantem historico de versoes (cada escrita cria versao)
> - **Change feed:** Log de alteracoes para auditoria
> - Nenhum desses requer Recovery Services Vault — sao features nativas do Storage

---

### Task 2.4: Restore de file share (CLI)

```bash
# ============================================================
# TASK 2.4 - Restore de file share via CLI (informativo)
# ============================================================
# Restore e uma operacao de controle, nao de provisionamento.
# Nao existe recurso Bicep para restore.

# Listar recovery points do file share
az backup recoverypoint list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --container-name "StorageContainer;storage;${RG11};${STORAGE_NAME}" \
    --item-name "AzureFileShare;contoso-share" \
    --query "[].{name:name, date:properties.recoveryPointTime}" \
    -o table

echo "Para restore, use:"
echo "az backup restore restore-azurefileshare --restore-mode OriginalLocation ..."
```

---

## Modo Desafio - Bloco 2

- [ ] Deploy `bloco2-storage.bicep` (storage + soft delete + versioning + file share)
- [ ] Deploy `bloco2-fileshare-backup.bicep` (policy + protecao do file share)
- [ ] Testar versionamento de blob (upload, modify, listar versoes)
- [ ] Testar soft delete (deletar blob, verificar recuperacao)
- [ ] Verificar recovery points do file share

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Qual propriedade da Storage Account habilita recuperacao de blobs deletados?**

A) `isVersioningEnabled`
B) `deleteRetentionPolicy`
C) `changeFeed`
D) `containerDeleteRetentionPolicy`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `deleteRetentionPolicy`**

`deleteRetentionPolicy` habilita soft delete para blobs. `isVersioningEnabled` mantem versoes anteriores. `containerDeleteRetentionPolicy` protege containers.

</details>

### Questao 2.2
**Azure Files backup usa qual `backupManagementType`?**

A) AzureIaasVM
B) AzureStorage
C) AzureFiles
D) AzureBlob

<details>
<summary>Ver resposta</summary>

**Resposta: B) AzureStorage**

`AzureStorage` e usado para Azure Files. `AzureIaasVM` e para VMs. Blob backup usa o Backup Vault (nao Recovery Services Vault).

</details>

### Questao 2.3
**Blob versioning esta habilitado. Voce sobrescreve um blob. O que acontece?**

A) Versao anterior e perdida
B) Uma nova versao e criada automaticamente com a versao anterior preservada
C) Precisa de backup manual antes
D) Soft delete e ativado automaticamente

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

Com versioning habilitado, cada escrita cria uma nova versao. Versoes anteriores sao mantidas e acessiveis pelo versionId.

</details>

---

# Bloco 3 - Azure Site Recovery (ASR)

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 RG (DR), 1 RSV (DR), ASR fabric, container, policy, recovery plan

> **Conceito:** Azure Site Recovery (ASR) replica VMs para uma regiao secundaria (DR).
> Em caso de desastre, voce executa **failover** para a regiao DR.
> Componentes: Fabric (regiao) → Container (agrupamento) → Policy (RPO/retencao) → Protected Item.
>
> **IMPORTANTE:** ASR tem custo significativo. Este bloco cria a infraestrutura mas
> a replicacao real de uma VM pode levar 30-60 min e gerar custos de storage na regiao DR.

---

### Task 3.1: Criar infraestrutura DR via Bicep

Este template usa `targetScope = 'subscription'` porque cria um Resource Group -- recurso que pertence ao nivel de subscription, nao de resource group. O deploy usa `az deployment sub create` em vez de `az deployment group create`.

> **Conceito: targetScope em Bicep**
>
> | Scope | Deploy command | O que pode criar |
> |-------|---------------|------------------|
> | `resourceGroup` (padrao) | `az deployment group create` | Recursos dentro de um RG |
> | `subscription` | `az deployment sub create` | RGs, policies, role assignments |
> | `managementGroup` | `az deployment mg create` | Policies em escala |
> | `tenant` | `az deployment tenant create` | Management groups |

Salve como **`bloco3-asr-infra.bicep`**:

```bicep
// ============================================================
// bloco3-asr-infra.bicep
// Scope: subscription
// Cria RG na regiao DR + Recovery Services Vault para ASR
// ============================================================

targetScope = 'subscription'

@description('Regiao de Disaster Recovery')
param locationDR string = 'westus'

@description('Nome do RG de DR')
param rgName string = 'rg-contoso-management'

// ==================== RG na regiao DR ====================
resource rgDR 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: locationDR
}

output rgDRName string = rgDR.name
output rgDRLocation string = rgDR.location
```

Deploy:

```bash
# Criar RG na regiao DR
az deployment sub create \
    --location "$LOCATION_DR" \
    --template-file bloco3-asr-infra.bicep \
    --parameters locationDR="$LOCATION_DR"

echo "RG de DR '$RG12' criado em $LOCATION_DR"
```

---

### Task 3.2: Criar RSV + ASR Policy na regiao DR via Bicep

Este template cria toda a infraestrutura ASR em um unico arquivo, demonstrando a forca do `parent:` em Bicep. Cada recurso filho (Fabric → Container → Mapping) usa `parent:` para referenciar o nivel acima, criando dependencias implicitas em cadeia. Em ARM JSON, seria necessario ~8 blocos de `dependsOn`.

> **Dica prova:** O vault de ASR fica na regiao de DESTINO (DR), nao na regiao de origem. Isso e o oposto do vault de Backup. Na prova: "vault de backup = mesma regiao; vault de ASR = regiao DR".

Salve como **`bloco3-asr-vault.bicep`**:

```bicep
// ============================================================
// bloco3-asr-vault.bicep
// Scope: resourceGroup (rg-contoso-management - regiao DR)
// Cria RSV para ASR + Replication Policy
// ============================================================

@description('Nome do vault de DR')
param vaultName string = 'rsv-contoso-dr-westus'

@description('Regiao de DR')
param location string = resourceGroup().location

@description('Regiao de origem (source)')
param sourceLocation string = 'eastus'

// ==================== Recovery Services Vault (DR) ====================
// Este vault na regiao DR recebe as replicas das VMs da regiao primaria
resource vaultDR 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

// ==================== ASR Fabric (Source) ====================
// Fabric representa uma regiao no contexto do ASR.
// Fabric de origem (source) = regiao onde as VMs estao
resource fabricSource 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: vaultDR
  name: 'asr-fabric-${sourceLocation}'
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: sourceLocation        // Regiao de origem
    }
  }
}

// ==================== ASR Fabric (Target) ====================
// Fabric de destino (target) = regiao de DR
resource fabricTarget 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: vaultDR
  name: 'asr-fabric-${location}'
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: location              // Regiao de DR
    }
  }
}

// ==================== Protection Container (Source) ====================
// Container agrupa itens protegidos dentro de uma fabric
resource containerSource 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: fabricSource
  name: 'asr-container-${sourceLocation}'
  properties: {}
}

// ==================== Protection Container (Target) ====================
resource containerTarget 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: fabricTarget
  name: 'asr-container-${location}'
  properties: {}
}

// ==================== Replication Policy ====================
// Define RPO (Recovery Point Objective) e retencao
resource replicationPolicy 'Microsoft.RecoveryServices/vaults/replicationPolicies@2023-06-01' = {
  parent: vaultDR
  name: 'repl-contoso-policy'
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'              // Azure to Azure
      // RPO: objetivo de ponto de recuperacao (perda maxima de dados)
      recoveryPointHistory: 1440       // Manter recovery points por 24h (em minutos)
      // Frequencia de snapshots app-consistent
      appConsistentFrequencyInMinutes: 240   // A cada 4 horas
      crashConsistentFrequencyInMinutes: 5   // A cada 5 minutos (padrao)
      multiVmSyncStatus: 'Enable'      // Sync multi-VM (recovery plan)
    }
  }
}

// ==================== Container Mapping ====================
// Mapeia container source → container target usando a policy
resource containerMapping 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-06-01' = {
  parent: containerSource
  name: 'asr-mapping-${sourceLocation}-to-${location}'
  properties: {
    targetProtectionContainerId: containerTarget.id
    policyId: replicationPolicy.id
    providerSpecificInput: {
      instanceType: 'A2A'
    }
  }
}

output vaultDRId string = vaultDR.id
output policyId string = replicationPolicy.id
output fabricSourceId string = fabricSource.id
output containerSourceId string = containerSource.id
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG12" \
    --template-file bloco3-asr-vault.bicep \
    --parameters sourceLocation="$LOCATION"

echo "ASR infrastructure criada: vault + fabrics + containers + policy + mapping"
```

> **Conceito ASR - Hierarquia de recursos:**
> ```
> Recovery Services Vault
>   ├── Replication Fabric (eastus - source)
>   │     └── Protection Container (source)
>   ├── Replication Fabric (westus - target)
>   │     └── Protection Container (target)
>   ├── Replication Policy (RPO, retencao)
>   └── Container Mapping (source → target via policy)
> ```
>
> **Comparacao ARM vs Bicep:** Em ARM JSON, cada nivel da hierarquia acima
> exige `dependsOn` explicito. Em Bicep, `parent:` resolve automaticamente.

---

### Task 3.2b: Politica de replicacao customizada (CLI)

```bash
# ============================================================
# TASK 3.2b - Criar politica de replicacao customizada
# ============================================================
# Politicas customizadas permitem ajustar RPO e retencao para
# cenarios especificos. Aqui criamos uma policy com retencao curta (4h).
# A policy Bicep acima cria a policy padrao; esta e uma alternativa via CLI.

az site-recovery policy create \
    --resource-group "$RG12" \
    --vault-name "rsv-contoso-dr-westus" \
    --name "contoso-4h-retention" \
    --provider-specific-input '{
        "instanceType": "A2A",
        "recoveryPointHistory": 240,
        "appConsistentFrequencyInMinutes": 120,
        "crashConsistentFrequencyInMinutes": 5
    }'

echo "Policy customizada criada: contoso-4h-retention"
echo "Retencao: 4h | App-consistent: a cada 2h | Crash-consistent: a cada 5 min"
```

> **Conceito AZ-104 — Replication Policy:**
> - `recoveryPointHistory: 240` = retencao de 4h (armazena pontos das ultimas 4 horas)
> - `appConsistentFrequencyInMinutes: 120` = snapshot consistente com aplicacao a cada 2h
> - `crashConsistentFrequencyInMinutes: 5` = snapshot crash-consistent a cada 5 min
> - Menor retencao = menos storage, mas menos opcoes de recovery point
> - Na prova: "RPO de 5 min" = crash-consistent frequency de 5 min

---

### Task 3.3: Habilitar replicacao de VM (CLI)

> **Cobranca:** A replicacao ASR gera cobranca continua por VM replicada. Nao pode ser pausada — so desabilitada.

```bash
# ============================================================
# TASK 3.3 - Habilitar replicacao ASR para VM (CLI)
# ============================================================
# A replicacao de VM via Bicep e possivel mas extremamente verbosa.
# CLI e o metodo recomendado pela documentacao oficial.
#
# NOTA: Este passo pode levar 30-60 min e gera custos de storage
# na regiao DR. Execute apenas se quiser testar ASR completo.

# Obter IDs necessarios
VM_ID=$(az vm show -g "$RG11" -n "vm-web-01" --query id -o tsv)
VAULT_DR_ID=$(az backup vault show -g "$RG12" -n "rsv-contoso-dr-westus" --query id -o tsv 2>/dev/null)

echo "Para habilitar replicacao ASR (requer: az extension add --name site-recovery):"
echo ""
echo "az site-recovery protected-item create \\"
echo "    --resource-group $RG12 \\"
echo "    --vault-name rsv-contoso-dr-westus \\"
echo "    --fabric-name asr-fabric-$LOCATION \\"
echo "    --protection-container asr-container-$LOCATION \\"
echo "    --name vm-web-01 \\"
echo "    --policy-id <policy-id> \\"
echo "    --provider-specific-details '{...}'"
echo ""
echo ">>> Recomendacao: pule este passo no lab e foque nos conceitos <<<"
```

---

### Task 3.4: Recovery Plan e Failover (conceitual)

```bash
# ============================================================
# TASK 3.4 - Recovery Plan e Failover (conceitual)
# ============================================================
# Recovery Plans orquestram failover de multiplas VMs.
# Em producao, permitem: ordenar VMs, scripts pre/pos, failover parcial.

echo "=== Conceitos de Recovery Plan ==="
echo ""
echo "1. Recovery Plan agrupa VMs para failover coordenado"
echo "2. VMs podem ser organizadas em grupos (ordem de boot)"
echo "3. Scripts pre/pos-failover podem ser adicionados"
echo ""
echo "Tipos de failover:"
echo "  - Test Failover: sem impacto na producao (rede isolada)"
echo "  - Planned Failover: com sincronizacao final (zero data loss)"
echo "  - Unplanned Failover: emergencia (possivel perda de dados)"
echo ""
echo "Comandos de failover (CLI — requer: az extension add --name site-recovery):"
echo "  az site-recovery recovery-plan create ..."
echo "  az site-recovery recovery-plan planned-failover ..."
echo "  az site-recovery recovery-plan unplanned-failover ..."
echo "  az site-recovery recovery-plan test-failover ..."
echo "  az site-recovery recovery-plan commit ..."
echo ""
echo "Alternativa: usar o Portal (Recovery Services Vault > Recovery Plans)"
```

> **Conceito AZ-104:**
> - **RTO** (Recovery Time Objective): tempo maximo aceitavel de indisponibilidade
> - **RPO** (Recovery Point Objective): perda maxima de dados aceitavel
> - ASR garante RPO de minutos (replicacao continua)
> - Test Failover e essencial: valida DR sem afetar producao

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-asr-infra.bicep` (RG na regiao DR)
- [ ] Deploy `bloco3-asr-vault.bicep` (vault DR + fabrics + containers + policy)
- [ ] Entender hierarquia ASR: Fabric → Container → Policy → Mapping
- [ ] Entender tipos de failover: Test, Planned, Unplanned
- [ ] Saber diferenciar RPO vs RTO

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Qual componente ASR representa uma regiao Azure?**

A) Protection Container
B) Replication Fabric
C) Replication Policy
D) Recovery Plan

<details>
<summary>Ver resposta</summary>

**Resposta: B) Replication Fabric**

Fabric representa uma regiao. Container agrupa itens protegidos dentro da fabric.

</details>

### Questao 3.2
**Voce precisa validar DR sem impacto na producao. Qual operacao usar?**

A) Planned Failover
B) Unplanned Failover
C) Test Failover
D) Commit

<details>
<summary>Ver resposta</summary>

**Resposta: C) Test Failover**

Test Failover cria VMs na regiao DR em rede isolada, sem afetar a producao.

</details>

### Questao 3.3
**Replication Policy com `recoveryPointHistory: 1440`. O que significa?**

A) RPO de 1440 segundos
B) Manter recovery points por 1440 minutos (24 horas)
C) 1440 recovery points no maximo
D) Replicacao a cada 1440 minutos

<details>
<summary>Ver resposta</summary>

**Resposta: B) Manter recovery points por 1440 minutos (24 horas)**

`recoveryPointHistory` define por quanto tempo manter recovery points, em minutos.

</details>

### Questao 3.4
**Em Bicep, qual `targetScope` voce usa para criar Resource Groups?**

A) `resourceGroup`
B) `subscription`
C) `managementGroup`
D) `tenant`

<details>
<summary>Ver resposta</summary>

**Resposta: B) subscription**

RGs sao recursos de subscription. O comando de deploy correspondente e `az deployment sub create`.

</details>

---

# Bloco 4 - Azure Monitor

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 RG, 1 Action Group, 1 Metric Alert (CPU), 1 Activity Log Alert

> **Conceito:** Azure Monitor coleta e analisa metricas e logs de recursos Azure.
> **Action Groups** definem QUEM notificar (email, SMS, webhook).
> **Alert Rules** definem QUANDO notificar (condicoes de metrica ou log).

---

### Task 4.1: Criar Resource Group para monitoramento

```bash
# ============================================================
# TASK 4.1 - Criar RG para monitoramento
# ============================================================

az group create --name "$RG13" --location "$LOCATION"

echo "RG '$RG13' criado para recursos de monitoramento"
```

---

### Task 4.2: Criar Action Group + Metric Alert via Bicep

Este template cria tres recursos em um unico arquivo: Action Group, Metric Alert (CPU) e Activity Log Alert (VM desalocada). Observe como as dependencias implicitas funcionam -- o `cpuAlert` referencia `actionGroup.id`, e o Bicep automaticamente garante que o Action Group e criado primeiro.

> **Conceito: Metric Alert vs Activity Log Alert**
> Metric Alerts monitoram dados **continuos** (CPU, memoria) com `evaluationFrequency` e `windowSize`. Activity Log Alerts reagem a **eventos discretos** (VM criada, deletada) sem janela de avaliacao. Na prova, "ser notificado quando VM for desligada" = Activity Log Alert.

> **Cobranca:** Alert rules geram cobranca minima por sinal monitorado.

Salve como **`bloco4-monitor.bicep`**:

```bicep
// ============================================================
// bloco4-monitor.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria Action Group + Metric Alert (CPU > 80%) + Activity Log Alert
// ============================================================

@description('Nome do Action Group')
param actionGroupName string

@description('Email para alertas')
param alertEmail string

@description('Resource ID da VM a monitorar')
param vmResourceId string

@description('Nome da VM (para nomes de alerta)')
param vmName string = 'vm-web-01'

param location string = resourceGroup().location

// ==================== Action Group ====================
// Action Group define QUEM e notificado quando um alerta dispara.
// Pode incluir: email, SMS, push, webhook, Logic App, Function, ITSM.
//
// NOTA: Action Groups sao recursos GLOBAIS (location = 'global')
// independente da regiao do RG.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'      // Action Groups sao SEMPRE globais
  properties: {
    groupShortName: 'ag-contoso-ops'    // Max 12 caracteres
    enabled: true
    // Lista de destinatarios de email
    emailReceivers: [
      {
        name: 'admin-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true    // Schema padronizado para todos os tipos de alerta
      }
    ]
    // Outros tipos de receivers disponiveis:
    // smsReceivers, webhookReceivers, azureFunctionReceivers,
    // logicAppReceivers, automationRunbookReceivers, voiceReceivers
  }
}

// ==================== Metric Alert: CPU > 80% ====================
// Metric Alerts monitoram metricas de recursos Azure em tempo real.
// Quando a condicao e atendida, o Action Group e acionado.
//
// Diferenca de ARM JSON: em ARM, 'criteria' usa tipo completo como string.
// Em Bicep, usamos a mesma sintaxe mas com type-safety nos campos.
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${vmName}-cpu'
  location: 'global'      // Metric Alerts sao SEMPRE globais
  properties: {
    severity: 2            // 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose
    enabled: true
    // scopes: lista de recursos monitorados
    // Pode monitorar multiplos recursos do MESMO tipo na mesma regiao
    scopes: [
      vmResourceId
    ]
    // evaluationFrequency: com que frequencia avaliar a condicao
    evaluationFrequency: 'PT5M'     // A cada 5 minutos (ISO 8601 duration)
    // windowSize: janela de tempo para agregacao
    windowSize: 'PT5M'              // Ultimos 5 minutos
    // criteria: condicao para disparar o alerta
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'Percentage CPU'       // Nome da metrica (especifico do recurso)
          operator: 'GreaterThan'
          threshold: 80                      // Limite: 80%
          timeAggregation: 'Average'         // Tipo de agregacao: media no windowSize
          // Outros: Total, Minimum, Maximum, Count
        }
      ]
    }
    // actions: quem notificar quando disparar
    actions: [
      {
        actionGroupId: actionGroup.id    // Dependencia implicita!
        // webHookProperties: {} // Propriedades adicionais para webhook
      }
    ]
  }
}

// ==================== Activity Log Alert: VM Deallocated ====================
// Activity Log Alerts monitoram operacoes de controle (management plane).
// Exemplos: VM desligada, RG deletado, policy alterada.
//
// Diferente de Metric Alerts, nao tem evaluationFrequency/windowSize
// porque operam em eventos discretos, nao metricas continuas.
resource vmDeallocatedAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: '${vmName}-deallocated-alert'
  location: 'global'
  properties: {
    enabled: true
    scopes: [
      // Scope pode ser subscription, RG ou recurso especifico
      // Aqui monitoramos a subscription inteira
      '/subscriptions/${subscription().subscriptionId}'
    ]
    // condition: define QUAIS eventos disparam o alerta
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'    // Categoria: operacoes administrativas
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Compute/virtualMachines/deallocate/action'
        }
        {
          field: 'status'
          equals: 'Succeeded'         // Apenas quando a operacao foi concluida
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

output actionGroupId string = actionGroup.id
output cpuAlertId string = cpuAlert.id
output activityAlertId string = vmDeallocatedAlert.id
```

Deploy:

```bash
# Obter resource ID da VM
VM_RESOURCE_ID=$(az vm show -g "$RG11" -n "vm-web-01" --query id -o tsv)

# Deploy do Action Group + Alerts
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco4-monitor.bicep \
    --parameters \
        actionGroupName="$ACTION_GROUP_NAME" \
        alertEmail="$ALERT_EMAIL" \
        vmResourceId="$VM_RESOURCE_ID"

echo "Action Group + CPU Alert + Activity Log Alert criados"
echo "Email de notificacao: $ALERT_EMAIL"
```

> **Conceito: Metric Alert vs Activity Log Alert**
>
> | Aspecto | Metric Alert | Activity Log Alert |
> |---------|-------------|-------------------|
> | O que monitora | Metricas continuas (CPU, RAM, IOPS) | Eventos discretos (create, delete, stop) |
> | Frequencia | Avalia a cada N minutos | Imediato ao evento |
> | Window | Agrega sobre janela de tempo | N/A |
> | Scope | Recurso(s) especifico(s) | Subscription/RG/recurso |
> | Custo | ~$0.10/metrica/mes | Gratuito |

---

### Task 4.3: Testar alerta de CPU (CLI)

```bash
# ============================================================
# TASK 4.3 - Gerar carga de CPU para disparar alerta
# ============================================================
# Usa Run Command para executar script dentro da VM

az vm run-command invoke \
    --resource-group "$RG11" \
    --name "vm-web-01" \
    --command-id RunShellScript \
    --scripts "stress-ng --cpu 2 --timeout 600 &"

echo "Carga de CPU gerada na VM por 10 minutos"
echo "Aguarde 5-10 min para o alerta disparar"
echo "Verifique o email: $ALERT_EMAIL"
```

> **Nota:** Se `stress-ng` nao estiver instalado, use:
> `--scripts "apt-get update && apt-get install -y stress-ng && stress-ng --cpu 2 --timeout 600 &"`

---

### Task 4.3b: Alerta com Dynamic Threshold (CLI)

```bash
# ============================================================
# TASK 4.3b - Criar alerta com Dynamic Threshold
# ============================================================
# Dynamic Threshold usa Machine Learning para aprender o padrao de uso
# e alerta quando detecta desvios (anomalias).

az monitor metrics alert create \
    -g "$RG13" \
    -n "alert-vm-web-01-cpu-dynamic" \
    --scopes $(az vm show -g "$RG11" -n "vm-web-01" --query id -o tsv) \
    --condition "avg Percentage CPU > dynamic medium of 4 violations out of 4 since 2024-01-01" \
    --action $(az monitor action-group show -g "$RG13" -n "$ACTION_GROUP_NAME" --query id -o tsv) \
    --severity 2 \
    --description "Alert com Dynamic Threshold - detecta anomalias baseado em ML"

echo "Dynamic Threshold Alert criado"
echo "O ML precisa de ~3 dias de dados historicos para melhor resultado"
```

> **Conceito AZ-104 — Static vs Dynamic Threshold:**
> - **Static:** valor fixo (ex: CPU > 80%) — voce define o limite
> - **Dynamic:** Machine Learning detecta anomalias automaticamente
> - Sensitivity: High (alerta em desvios pequenos), Medium, Low (apenas desvios grandes)
> - Precisa de ~3 dias de dados historicos para melhor resultado
> - Na prova: "detectar comportamento anomalo" = Dynamic; "CPU > 80%" = Static

---

### Task 4.4: Verificar alertas disparados

```bash
# ============================================================
# TASK 4.4 - Verificar alertas disparados
# ============================================================

# Listar metric alerts configurados
az monitor metrics alert list \
    --resource-group "$RG13" \
    --query "[].{name:name, severity:severity, enabled:enabled, criteria:criteria.allOf[0].metricName}" \
    -o table

# Detalhes do alerta especifico
az monitor metrics alert show \
    --resource-group "$RG13" \
    --name "alert-vm-web-01-cpu" \
    --query "{name:name, severity:severity, enabled:enabled}" \
    -o table

# Verificar Action Group
az monitor action-group show \
    --resource-group "$RG13" \
    --name "$ACTION_GROUP_NAME" \
    --query "{name:name, enabled:enabled, emails:emailReceivers[].emailAddress}" \
    -o table
```

---

### Task 4.5: Testar Activity Log Alert (CLI)

```bash
# ============================================================
# TASK 4.5 - Testar Activity Log Alert (deallocate VM)
# ============================================================

# Desalocar a VM (dispara o activity log alert)
az vm deallocate --resource-group "$RG11" --name "vm-web-01" --no-wait

echo "VM sendo desalocada..."
echo "Activity Log Alert deve disparar em 1-5 minutos"
echo "Verifique o email: $ALERT_EMAIL"

# Re-iniciar a VM apos teste
# az vm start --resource-group "$RG11" --name "vm-web-01" --no-wait
```

---

### Task 4.6b: Service Health Alerts (CLI)

```bash
# ============================================================
# TASK 4.6b - Criar alerta de Service Health
# ============================================================
# Service Health monitora incidentes, manutencao e advisories do Azure.
# Diferente de Metric Alerts, usa Activity Log Alerts.

# Alerta para incidentes de servico (outages)
az monitor activity-log alert create \
    -g "$RG13" \
    -n "alert-service-health-incident" \
    --condition category=ServiceHealth and properties.incidentType=Incident \
    --action-group $(az monitor action-group show -g "$RG13" -n "$ACTION_GROUP_NAME" --query id -o tsv) \
    --description "Alerta para incidentes de Service Health"

# Alerta para manutencao planejada
az monitor activity-log alert create \
    -g "$RG13" \
    -n "alert-service-health-maintenance" \
    --condition category=ServiceHealth and properties.incidentType=Maintenance \
    --action-group $(az monitor action-group show -g "$RG13" -n "$ACTION_GROUP_NAME" --query id -o tsv) \
    --description "Alerta para manutencao planejada"

# Verificar alertas criados
az monitor activity-log alert list -g "$RG13" \
    --query "[?contains(name,'service-health')].{name:name, enabled:enabled}" -o table

echo "Service Health Alerts criados: incident + maintenance"
```

> **Conceito AZ-104 — Service Health:**
> Service Health tem 4 tipos de eventos:
> 1. **Service issues** (outages) — servico indisponivel
> 2. **Planned maintenance** — manutencao agendada
> 3. **Health advisories** — mudancas que podem afetar voce
> 4. **Security advisories** — alertas de seguranca
>
> Na prova: "ser notificado quando Azure tiver problemas" = Service Health Alert.
> Service Health usa **Activity Log Alerts**, nao Metric Alerts.

---

## Modo Desafio - Bloco 4

- [ ] Criar RG `rg-contoso-management`
- [ ] Deploy `bloco4-monitor.bicep` (Action Group + CPU Alert + Activity Log Alert)
- [ ] Gerar carga de CPU via Run Command
- [ ] Verificar email de alerta (CPU > 80%)
- [ ] Desalocar VM e verificar Activity Log Alert
- [ ] Entender diferenca entre Metric Alert e Activity Log Alert

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Qual tipo de alert monitora metricas continuas como CPU?**

A) Activity Log Alert
B) Metric Alert
C) Log Analytics Alert
D) Smart Detection Alert

<details>
<summary>Ver resposta</summary>

**Resposta: B) Metric Alert**

Metric Alerts monitoram metricas de recursos em tempo real (CPU, memoria, IOPS).

</details>

### Questao 4.2
**Action Group com email receiver. Severity do alerta e 2. O que significa?**

A) Critical
B) Error
C) Warning
D) Informational

<details>
<summary>Ver resposta</summary>

**Resposta: C) Warning**

Severity: 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose.

</details>

### Questao 4.3
**`evaluationFrequency: 'PT5M'` e `windowSize: 'PT5M'`. CPU atinge 90% por 3 minutos e volta a 50%. Alerta dispara?**

A) Sim, CPU superou 80%
B) Nao, a MEDIA de 5 min pode nao superar 80%
C) Sim, qualquer momento acima dispara
D) Depende do timeAggregation

<details>
<summary>Ver resposta</summary>

**Resposta: D) Depende do timeAggregation**

Com `Average` e windowSize de 5 min, a media da janela precisa superar 80%. Se CPU foi 90% por 3 min e 50% por 2 min, a media e ~74% — NAO dispara. Com `Maximum`, dispararia.

</details>

### Questao 4.4
**Activity Log Alert monitora operacoes de qual plano?**

A) Data plane
B) Management plane (control plane)
C) Ambos
D) Apenas ARM

<details>
<summary>Ver resposta</summary>

**Resposta: B) Management plane (control plane)**

Activity Log registra operacoes de controle: criar, deletar, modificar recursos. NAO monitora data plane (ex: leitura de blob).

</details>

### Questao 4.5
**Em Bicep, Metric Alerts e Action Groups usam `location:` igual a qual valor?**

A) A regiao do Resource Group
B) `'global'`
C) A regiao do recurso monitorado
D) Qualquer regiao

<details>
<summary>Ver resposta</summary>

**Resposta: B) `'global'`**

Metric Alerts e Action Groups sao recursos globais — independem de regiao.

</details>

---

# Bloco 5 - Log Analytics & Diagnostics

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 Log Analytics Workspace, VM extension (AMA), Diagnostic Settings, Network Watcher

> **Conceito:** Log Analytics Workspace e o repositorio central de logs no Azure.
> Recursos enviam logs via **Diagnostic Settings** ou **Azure Monitor Agent (AMA)**.
> Consultas sao feitas via **KQL** (Kusto Query Language).

---

### Task 5.1: Criar Log Analytics Workspace via Bicep

O Log Analytics Workspace e o destino central para todos os logs do Azure Monitor. Este template usa decorators (`@minValue`, `@maxValue`) para validar parametros em tempo de deploy -- recurso exclusivo do Bicep que nao existe com a mesma elegancia em ARM JSON.

> **Conceito: Decorators em Bicep**
> Decorators (`@description`, `@allowed`, `@minValue`, `@maxValue`, `@secure`) adicionam validacao e documentacao aos parametros. Em ARM JSON, o equivalente sao propriedades dentro do bloco `"metadata"`, `"allowedValues"`, `"minValue"`.

> **Cobranca:** O workspace gera cobranca por GB de dados ingeridos.

Salve como **`bloco5-loganalytics.bicep`**:

```bicep
// ============================================================
// bloco5-loganalytics.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria Log Analytics Workspace + configura retencao
// ============================================================

@description('Nome do workspace')
param workspaceName string

@description('Regiao')
param location string = resourceGroup().location

@description('Dias de retencao (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

// ==================== Log Analytics Workspace ====================
// Repositorio central de logs do Azure Monitor.
// Todos os dados sao consultados via KQL (Kusto Query Language).
// SKU 'PerGB2018' cobra por volume de dados ingeridos.
//
// Equivalente ARM JSON:
// {
//   "type": "Microsoft.OperationalInsights/workspaces",
//   "apiVersion": "2022-10-01",
//   "name": "[parameters('workspaceName')]",
//   "location": "[parameters('location')]",
//   "properties": {
//     "sku": { "name": "PerGB2018" },
//     "retentionInDays": 30
//   }
// }
// Note como Bicep e mais conciso!
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'    // Pay-per-GB (unico SKU disponivel)
    }
    retentionInDays: retentionInDays   // 30 dias gratuitos, acima disso cobra
    // features: {
    //   enableLogAccessUsingOnlyResourcePermissions: true  // RBAC por recurso
    // }
  }
}

output workspaceId string = workspace.id
output workspaceCustomerId string = workspace.properties.customerId
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco5-loganalytics.bicep \
    --parameters workspaceName="$WORKSPACE_NAME"

echo "Log Analytics Workspace '$WORKSPACE_NAME' criado"
```

> **Conceito SKU:** `PerGB2018` e o unico SKU disponivel atualmente.
> Primeiros 5 GB/mes de ingestao sao gratuitos. Retencao de 30 dias gratuita.
> Acima de 30 dias, cobra por GB retido.

---

### Task 5.2: Instalar Azure Monitor Agent (AMA) na VM via Bicep

VM Extensions sao recursos filhos da VM. Em Bicep, `parent: vm` com `existing` cria a extensao na VM existente sem recria-la. O `enableAutomaticUpgrade: true` garante que o agente se mantenha atualizado automaticamente.

Salve como **`bloco5-vm-agent.bicep`**:

```bicep
// ============================================================
// bloco5-vm-agent.bicep
// Scope: resourceGroup (rg-contoso-management - onde a VM esta)
// Instala Azure Monitor Agent (AMA) na VM
// ============================================================

@description('Nome da VM')
param vmName string = 'vm-web-01'

@description('Regiao da VM')
param location string = resourceGroup().location

// Referenciar VM existente
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: vmName
}

// ==================== Azure Monitor Agent (AMA) ====================
// AMA substitui o antigo Log Analytics Agent (MMA/OMS).
// E a extensao recomendada para coletar logs e metricas de VMs.
//
// Diferenca:
// - MMA (legado): configurado pelo workspace ID + key
// - AMA (atual): configurado via Data Collection Rules (DCR)
//
// Para Linux: AzureMonitorLinuxAgent
// Para Windows: AzureMonitorWindowsAgent
resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm       // Extensao e filha da VM (dependencia implicita)
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'        // Linux
    // Para Windows use: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true          // Atualiza automaticamente
  }
}

output extensionId string = amaExtension.id
```

Deploy:

```bash
# Reiniciar VM (pode estar desalocada do Bloco 4)
az vm start --resource-group "$RG11" --name "vm-web-01" 2>/dev/null

# Deploy do AMA
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco5-vm-agent.bicep

echo "Azure Monitor Agent instalado na VM"
```

---

### Task 5.3: Criar Data Collection Rule + Diagnostic Settings via Bicep

A DCR define QUAIS dados coletar da VM (syslog, performance counters) e PARA ONDE enviar (Log Analytics). A associacao DCR → VM e feita via CLI porque a VM pode estar em outro RG, e Bicep exige o `scope` correto para recursos cross-RG.

> **Conceito: DCR vs Diagnostic Settings**
> DCR coleta dados de **VMs** (via AMA agent). Diagnostic Settings coleta dados de **recursos PaaS** (vaults, storage, NSG) diretamente. Sao mecanismos diferentes para o mesmo destino (Log Analytics).

Salve como **`bloco5-diagnostics.bicep`**:

```bicep
// ============================================================
// bloco5-diagnostics.bicep
// Scope: resourceGroup (rg-contoso-management)
// Cria Data Collection Rule + Diagnostic Settings
// ============================================================

@description('Resource ID do Log Analytics Workspace')
param workspaceId string

@description('Resource ID da VM a monitorar')
param vmResourceId string

@description('Nome da VM')
param vmName string = 'vm-web-01'

@description('RG da VM')
param vmResourceGroup string

param location string = resourceGroup().location

// ==================== Data Collection Rule (DCR) ====================
// DCR define QUAIS dados coletar e PARA ONDE enviar.
// Substitui a configuracao direta no workspace (modelo antigo).
//
// Componentes:
// - dataSources: o que coletar (syslog, performance, eventos)
// - destinations: para onde enviar (Log Analytics)
// - dataFlows: conecta sources com destinations
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-contoso-perf-linux'
  location: location
  properties: {
    // dataSources: define o que coletar da VM
    dataSources: {
      // Syslog: logs do sistema Linux
      syslog: [
        {
          name: 'syslogDataSource'
          streams: ['Microsoft-Syslog']
          facilityNames: [
            'auth'
            'authpriv'
            'daemon'
            'kern'
            'syslog'
          ]
          logLevels: [
            'Alert'
            'Critical'
            'Emergency'
            'Error'
            'Warning'
          ]
        }
      ]
      // Performance counters: metricas de performance
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60    // Coletar a cada 60 segundos
          counterSpecifiers: [
            '\\Processor(*)\\% Processor Time'
            '\\Memory(*)\\% Used Memory'
            '\\LogicalDisk(*)\\% Free Space'
            '\\Network(*)\\Total Bytes Transmitted'
          ]
        }
      ]
    }
    // destinations: para onde enviar os dados
    destinations: {
      logAnalytics: [
        {
          name: 'logAnalyticsDestination'
          workspaceResourceId: workspaceId
        }
      ]
    }
    // dataFlows: conecta sources → destinations
    dataFlows: [
      {
        streams: ['Microsoft-Syslog']
        destinations: ['logAnalyticsDestination']
      }
      {
        streams: ['Microsoft-Perf']
        destinations: ['logAnalyticsDestination']
      }
    ]
  }
}

// ==================== DCR Association ====================
// Associa a DCR a VM (diz a VM para coletar dados conforme a DCR)
// NOTA: Este recurso usa scope da VM, entao precisa de referencia cross-RG
//
// Em producao, DCR associations sao frequentemente feitas via CLI
// quando a VM esta em outro RG, pois Bicep exige o scope correto.

output dcrId string = dcr.id
output dcrName string = dcr.name
```

Deploy:

```bash
# Obter IDs necessarios
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)

VM_RESOURCE_ID=$(az vm show -g "$RG11" -n "vm-web-01" --query id -o tsv)

# Deploy da DCR
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco5-diagnostics.bicep \
    --parameters \
        workspaceId="$WORKSPACE_ID" \
        vmResourceId="$VM_RESOURCE_ID" \
        vmResourceGroup="$RG11"

echo "Data Collection Rule criada"

# Preflight: verificar que comandos de DCR estao disponiveis
if ! az monitor data-collection rule -h &>/dev/null; then
    echo "✗ ERRO: Comandos de DCR nao disponiveis."
    echo "  Execute: az extension add --name monitor-control-service --upgrade"
    echo "  Pulando associacao DCR → VM."
else
    # Associar DCR a VM via CLI (mais simples que Bicep para cross-RG)
    DCR_ID=$(az monitor data-collection rule show \
        -g "$RG13" -n "dcr-contoso-perf-linux" --query id -o tsv)

    az monitor data-collection rule association create \
        --name "vm-web-01-dcr-association" \
        --resource "$VM_RESOURCE_ID" \
        --rule-id "$DCR_ID"
fi

echo "DCR associada a VM vm-web-01"
```

> **Conceito: DCR vs Diagnostic Settings**
>
> | Aspecto | Data Collection Rule (DCR) | Diagnostic Settings |
> |---------|---------------------------|-------------------|
> | Para quem | VMs (via AMA agent) | Recursos Azure (PaaS) |
> | O que coleta | Syslog, perf counters, eventos | Metricas, logs de recurso |
> | Como configura | DCR + Association | Direto no recurso |
> | Agent necessario | Sim (AMA) | Nao |

---

### Task 5.4: Diagnostic Settings para o Recovery Services Vault via Bicep

Diagnostic Settings sao **extension resources** -- recursos que se "acoplam" a outro recurso existente. Em Bicep, usamos `scope: vault` (diferente de `parent:` que e para recursos filhos). Isso envia logs do vault para o Log Analytics Workspace, permitindo consultar operacoes de backup via KQL.

> **Dica prova:** `scope:` e `parent:` sao conceitos diferentes em Bicep. `parent:` cria recurso FILHO (gera nome composto). `scope:` aplica um extension resource a um recurso existente (como Diagnostic Settings, locks, role assignments).

Salve como **`bloco5-vault-diagnostics.bicep`**:

```bicep
// ============================================================
// bloco5-vault-diagnostics.bicep
// Scope: resourceGroup (rg-contoso-management)
// Configura Diagnostic Settings no Recovery Services Vault
// ============================================================

@description('Nome do vault')
param vaultName string

@description('Resource ID do Log Analytics Workspace')
param workspaceId string

// Referenciar vault existente
resource vault 'Microsoft.RecoveryServices/vaults@2023-06-01' existing = {
  name: vaultName
}

// ==================== Diagnostic Settings ====================
// Envia logs do vault para o Log Analytics Workspace.
// Diferente de DCR (que e para VMs), Diagnostic Settings e para
// recursos PaaS/plataforma (vaults, storage, NSG, etc).
//
// Os logs do vault incluem:
// - AzureBackupReport: relatorios de backup
// - CoreAzureBackup: operacoes core de backup
// - AddonAzureBackupJobs: jobs de backup
// - AddonAzureBackupAlerts: alertas de backup
// - AddonAzureBackupPolicy: alteracoes de policy
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vault-to-law'
  scope: vault           // Aplica ao vault (NAO ao RG!)
  properties: {
    workspaceId: workspaceId
    // logs: categorias de log a habilitar
    logs: [
      {
        category: 'CoreAzureBackup'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AddonAzureBackupJobs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AddonAzureBackupAlerts'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AddonAzureBackupPolicy'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureSiteRecoveryJobs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    // metrics: metricas do vault
    metrics: [
      {
        category: 'Health'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
```

Deploy:

```bash
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)

az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco5-vault-diagnostics.bicep \
    --parameters vaultName="$VAULT_NAME" workspaceId="$WORKSPACE_ID"

echo "Diagnostic Settings configurado: vault → Log Analytics"
```

> **Conceito `scope:`:** Em Bicep, `scope: vault` indica que o Diagnostic Settings
> e aplicado ao vault, nao ao resource group. Isso e diferente de `parent:`:
> - `parent:` = recurso FILHO (nome composto, ex: vault/policy)
> - `scope:` = recurso ASSOCIADO (extension resource, ex: diagnosticSettings no vault)

---

### Task 5.5: Network Watcher (CLI)

```bash
# ============================================================
# TASK 5.5 - Network Watcher: diagnostico de rede
# ============================================================
# Network Watcher e criado automaticamente pelo Azure na maioria das regioes.
# Verifica conectividade, captura pacotes e diagnostica NSGs.

# Verificar se Network Watcher existe na regiao
az network watcher list --query "[?location=='$LOCATION'].{name:name, location:location}" -o table

# IP Flow Verify: verifica se NSG permite trafego
# Simula um pacote e diz se sera permitido ou negado
az network watcher test-ip-flow \
    --resource-group "$RG11" \
    --vm "vm-web-01" \
    --direction Inbound \
    --protocol TCP \
    --local "10.0.0.4:22" \
    --remote "10.0.0.1:*" 2>/dev/null || \
echo "IP Flow Verify requer VM running e Network Watcher habilitado"

# Connection Troubleshoot: diagnostica problemas de conectividade
az network watcher test-connectivity \
    --resource-group "$RG11" \
    --source-resource "vm-web-01" \
    --dest-address "8.8.8.8" \
    --dest-port 443 2>/dev/null || \
echo "Connection Troubleshoot requer VM running e Network Watcher extension"

echo ""
echo "=== Ferramentas do Network Watcher ==="
echo "1. IP Flow Verify: testa se NSG permite/bloqueia trafego"
echo "2. Connection Troubleshoot: diagnostica conectividade end-to-end"
echo "3. NSG Flow Logs: registra trafego permitido/negado"
echo "4. Packet Capture: captura pacotes na VM"
echo "5. Topology: visualiza topologia de rede"
echo "6. Next Hop: mostra proximo salto de roteamento"
```

---

### Task 5.6: Consultar logs via KQL (CLI)

```bash
# ============================================================
# TASK 5.6 - Consultar logs no Log Analytics via KQL
# ============================================================
# KQL (Kusto Query Language) e a linguagem de consulta do Azure Monitor.
# Sintaxe basica: Tabela | operador | operador

# Obter workspace ID (resource path) para az rest
WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
    -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)

# NOTA: `az monitor log-analytics query` pode falhar em versoes recentes do CLI.
# Usamos `az rest` contra a API do Log Analytics, que e o metodo mais confiavel.

# Consulta 1: Heartbeat da VM (confirma que AMA esta enviando dados)
echo "=== Query 1: Heartbeat ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Heartbeat | summarize LastHeartbeat=max(TimeGenerated) by Computer | project Computer, LastHeartbeat"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Heartbeat pode levar 10-15 min para aparecer apos instalar AMA"

# Consulta 2: Performance de CPU (Perf table)
echo "=== Query 2: CPU ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Perf | where ObjectName == '\''Processor'\'' and CounterName == '\''% Processor Time'\'' | summarize AvgCPU=avg(CounterValue) by Computer, bin(TimeGenerated, 5m) | order by TimeGenerated desc | take 10"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Dados de performance podem levar 10-15 min para aparecer"

# Consulta 3: Syslog
echo "=== Query 3: Syslog ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Syslog | where SeverityLevel in ('\''err'\'', '\''crit'\'', '\''alert'\'', '\''emerg'\'') | project TimeGenerated, Computer, Facility, SeverityLevel, SyslogMessage | order by TimeGenerated desc | take 20"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Syslog pode levar 10-15 min para aparecer"

# Alternativa: Portal Azure → Log Analytics Workspace → Logs → colar a query KQL
# O portal oferece IntelliSense e visualizacao grafica dos resultados.

echo ""
echo "=== KQL Basico ==="
echo "Tabela | where campo == 'valor'    → filtrar"
echo "       | summarize count() by campo → agrupar"
echo "       | project campo1, campo2     → selecionar colunas"
echo "       | order by campo desc        → ordenar"
echo "       | take 10                    → limitar resultados"
```

---

### Task 5.9b: NSG Flow Logs com Traffic Analytics (CLI)

```bash
# ============================================================
# TASK 5.9b - Configurar NSG Flow Logs com Traffic Analytics
# ============================================================
# Flow Logs registram todo trafego que passa pelo NSG (permitido e negado).
# Traffic Analytics agrega os dados no Log Analytics para visualizacao.

# Obter IDs necessarios
NSG_ID=$(az network nsg show -g "$RG11" -n "nsg-contoso" --query id -o tsv)
WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)
STORAGE_ID=$(az storage account show -g "$RG11" -n "$STORAGE_ACCOUNT_NAME" --query id -o tsv)

# Criar Flow Log com versao 2 e Traffic Analytics
az network watcher flow-log create \
    --location "$LOCATION" \
    --name "nsg-flow-log" \
    --nsg $NSG_ID \
    --storage-account $STORAGE_ID \
    --retention 30 \
    --format JSON \
    --log-version 2 \
    --traffic-analytics true \
    --workspace $WORKSPACE_ID \
    --interval 10

# Verificar flow log criado
az network watcher flow-log show \
    --location "$LOCATION" \
    --name "nsg-flow-log" \
    --query "{name:name, enabled:enabled, version:format.version, trafficAnalytics:flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled}" -o table

echo "NSG Flow Log criado com Traffic Analytics habilitado"
echo "Dados ficam no storage: insights-logs-networksecuritygroupflowevent"
```

> **Conceito AZ-104 — NSG Flow Logs:**
> - Flow Logs v2 inclui estado do fluxo (Begin, Continuing, End) e throughput
> - Traffic Analytics agrega flow logs no Log Analytics para visualizacao
> - Dados ficam no storage account: `insights-logs-networksecuritygroupflowevent`
> - Retencao: 0 = ilimitado (dependendo do storage); recomendado >= 30 dias
> - Na prova: "analisar trafego de rede" = NSG Flow Logs + Traffic Analytics

---

## Modo Desafio - Bloco 5

- [ ] Deploy `bloco5-loganalytics.bicep` (workspace)
- [ ] Deploy `bloco5-vm-agent.bicep` (AMA na VM)
- [ ] Deploy `bloco5-diagnostics.bicep` (DCR + association)
- [ ] Deploy `bloco5-vault-diagnostics.bicep` (diagnostic settings no vault)
- [ ] Testar Network Watcher (IP Flow, Connection Troubleshoot)
- [ ] Consultar logs via KQL (Heartbeat, Perf, Syslog)

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Qual e o SKU disponivel para Log Analytics Workspace?**

A) Free
B) Standard
C) Premium
D) PerGB2018

<details>
<summary>Ver resposta</summary>

**Resposta: D) PerGB2018**

E o unico SKU disponivel. Cobra por GB ingerido. Primeiros 5 GB/mes gratuitos.

</details>

### Questao 5.2
**Azure Monitor Agent (AMA) e configurado via qual recurso?**

A) Workspace settings
B) Data Collection Rule (DCR)
C) Diagnostic Settings
D) Log Analytics Agent

<details>
<summary>Ver resposta</summary>

**Resposta: B) Data Collection Rule (DCR)**

AMA usa DCRs para saber o que coletar e para onde enviar. O antigo MMA usava workspace ID + key.

</details>

### Questao 5.3
**Diagnostic Settings de um Recovery Services Vault enviam dados para:**

A) Azure Storage apenas
B) Event Hub apenas
C) Log Analytics Workspace (ou Storage ou Event Hub)
D) Application Insights

<details>
<summary>Ver resposta</summary>

**Resposta: C) Log Analytics Workspace (ou Storage ou Event Hub)**

Diagnostic Settings suportam 3 destinos: Log Analytics, Storage Account, Event Hub. Pode enviar para multiplos simultaneamente.

</details>

### Questao 5.4
**Em Bicep, qual keyword aplica um extension resource (como Diagnostic Settings) a um recurso existente?**

A) `parent`
B) `scope`
C) `existing`
D) `dependsOn`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `scope`**

`scope: vault` aplica o Diagnostic Settings ao vault. `parent` e para recursos filhos (nome composto). `existing` referencia recurso ja criado.

</details>

### Questao 5.5
**Network Watcher IP Flow Verify testa o que?**

A) Latencia de rede
B) Se uma regra NSG permite ou bloqueia um pacote especifico
C) DNS resolution
D) Throughput de rede

<details>
<summary>Ver resposta</summary>

**Resposta: B) Se uma regra NSG permite ou bloqueia um pacote especifico**

IP Flow Verify simula um pacote com source/destination/port/protocol e diz se o NSG permite ou bloqueia, indicando qual regra e responsavel.

</details>

---

# Bloco 6 - Backup Vault e VM Move

> **Contexto:** O Backup Vault e o servico mais recente de backup do Azure, projetado para workloads
> que o Recovery Services Vault nao suporta (Disks, Blobs, PostgreSQL, AKS). Neste bloco voce tambem
> pratica mover VMs entre Resource Groups — topico cobrado no AZ-104 (dominio Compute).
>
> **Resource Groups:** `rg-contoso-compute` (VMs da Semana 2) + `rg-contoso-management` (Backup Vault) + `rg-contoso-moved` (destino do move)

---

### Task 6.1: Mover VM para outro Resource Group (CLI)

> **Por que CLI e nao Bicep?** Move de recursos e uma operacao imperativa (`az resource move`),
> nao um provisionamento declarativo. Bicep descreve o estado desejado de recursos;
> mover um recurso existente entre RGs nao e algo que se modela em template.

```bash
# ============================================================
# TASK 6.1 - Mover VM entre Resource Groups
# ============================================================
# Move de recursos entre RGs:
# - NAO requer downtime (VM continua running)
# - Altera o resource ID (novo RG no path)
# - Regiao e configuracoes permanecem iguais
# - Recursos dependentes (NIC, Disk, PIP) devem ser movidos JUNTOS
# ============================================================

# Criar RG de destino
az group create --name rg-contoso-moved --location eastus

# Obter IDs dos recursos a mover
# IMPORTANTE: VM + NIC + Disk devem ir juntos (dependencias)
VM_ID=$(az vm show -g rg-contoso-compute -n vm-api-01 --query id -o tsv)
NIC_ID=$(az vm show -g rg-contoso-compute -n vm-api-01 \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)
DISK_ID=$(az vm show -g rg-contoso-compute -n vm-api-01 \
    --query "storageProfile.osDisk.managedDisk.id" -o tsv)

echo "VM ID: $VM_ID"
echo "NIC ID: $NIC_ID"
echo "Disk ID: $DISK_ID"

# Mover todos os recursos dependentes de uma vez
# az resource move: operacao imperativa (nao declarativa)
# --destination-group: RG de destino (mesma subscription)
# --ids: lista de resource IDs a mover
az resource move \
    --destination-group rg-contoso-moved \
    --ids $VM_ID $NIC_ID $DISK_ID

# Validar: VM agora esta no novo RG
az vm show -g rg-contoso-moved -n vm-api-01 --query "{name:name, rg:resourceGroup, location:location}" -o table
```

> **Conceito AZ-104:** `az resource move` altera o Resource Group no resource ID mas NAO altera
> a regiao, configuracao ou estado do recurso. A VM continua running durante o move.

---

### Task 6.2: Entender limitacoes de move e mover VM de volta

```bash
# ============================================================
# TASK 6.2 - Limitacoes de Move e reverter
# ============================================================
# Tipos de move no Azure:
#
# | Cenario                       | Metodo               | Downtime |
# |-------------------------------|----------------------|----------|
# | Move entre RGs (mesma regiao) | az resource move     | Nenhum   |
# | Move entre regioes            | ASR / Resource Mover | Minimo   |
# | Move entre subscriptions      | az resource move     | Nenhum   |
#
# LIMITACOES IMPORTANTES:
# - Nem todos os recursos suportam move (verificar support matrix)
# - Recursos com locks NAO podem ser movidos (remover lock antes)
# - Move entre regioes NAO usa az resource move — requer ASR ou recriar
# - Recursos dependentes DEVEM ser movidos juntos
# ============================================================

# Mover VM de volta ao RG original
VM_ID=$(az vm show -g rg-contoso-moved -n vm-api-01 --query id -o tsv)
NIC_ID=$(az vm show -g rg-contoso-moved -n vm-api-01 \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)
DISK_ID=$(az vm show -g rg-contoso-moved -n vm-api-01 \
    --query "storageProfile.osDisk.managedDisk.id" -o tsv)

az resource move \
    --destination-group rg-contoso-compute \
    --ids $VM_ID $NIC_ID $DISK_ID

# Validar: VM de volta ao RG original
az vm show -g rg-contoso-compute -n vm-api-01 --query "{name:name, rg:resourceGroup}" -o table
echo "VM movida de volta para rg-contoso-compute com sucesso"
```

> **Conexao com Bloco 3:** Para mover VMs entre regioes, use Azure Site Recovery (configurado no Bloco 3).
> `az resource move` NAO suporta move cross-region para VMs.

---

### Task 6.3: Criar Azure Backup Vault via Bicep

Crie o arquivo `bloco6-backup-vault.bicep`:

```bicep
// ============================================================
// BLOCO 6 - Azure Backup Vault + Disk Backup Policy
// ============================================================
// Backup Vault vs Recovery Services Vault:
// - Backup Vault: Azure Disks, Blobs, PostgreSQL, AKS
// - Recovery Services Vault: VMs, File Shares, Site Recovery, SAP HANA, SQL in VM
//
// O Backup Vault e o servico mais recente de backup da Microsoft.
// A Microsoft esta gradualmente migrando workloads para ele.
// No AZ-104, saber QUAL vault suporta QUAL workload e critico.
//
// Tipo ARM: Microsoft.DataProtection/backupVaults
// (diferente de Microsoft.RecoveryServices/vaults usado no Bloco 1)
// ============================================================

@description('Localizacao dos recursos. Deve ser a mesma regiao dos discos a proteger.')
param location string = resourceGroup().location

@description('Nome do Backup Vault.')
param backupVaultName string = 'bv-contoso-disks'

@description('Redundancia do storage do vault. LRS para labs, GRS para producao.')
@allowed([
  'LocallyRedundant'
  'GeoRedundant'
])
param storageRedundancy string = 'LocallyRedundant'

@description('Nome da politica de backup para Azure Disks.')
param diskPolicyName string = 'bv-contoso-disks-disk-policy'

@description('Retencao em dias para os snapshots de disco.')
@minValue(1)
@maxValue(360)
param retentionDays int = 30

// ============================================================
// Backup Vault
// ============================================================
// Microsoft.DataProtection/backupVaults:
// - storageSettings: define redundancia (LRS/GRS)
//   Diferente do RSV, aqui e um ARRAY de storage settings
// - Nao tem propriedade de soft delete no template (habilitado por padrao)
// ============================================================
resource backupVault 'Microsoft.DataProtection/backupVaults@2023-11-01' = {
  name: backupVaultName
  location: location
  identity: {
    // System-assigned managed identity: necessaria para acessar discos
    // O vault precisa de roles nos discos: Disk Backup Reader + Disk Snapshot Contributor
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        // datastoreType: VaultStore para dados no vault, OperationalStore para snapshots locais
        // Disk backup usa OperationalStore (snapshots ficam na subscription, nao no vault)
        datastoreType: 'VaultStore'
        type: storageRedundancy
      }
    ]
  }
}

// ============================================================
// Disk Backup Policy
// ============================================================
// Microsoft.DataProtection/backupVaults/backupPolicies:
// - datasourceTypes: ['Microsoft.Compute/disks'] para backup de discos
// - policyRules: define schedule (quando) e retention (quanto tempo)
//
// Disk backup usa snapshots incrementais:
// - Primeiro snapshot: copia completa do disco
// - Snapshots seguintes: apenas deltas (blocos alterados)
// - Menor custo e tempo que VM backup completo do RSV
//
// Conceito Bicep: recurso FILHO usa 'parent:' para declarar hierarquia
// O Bicep gera automaticamente o dependsOn e nome composto
// ============================================================
resource diskBackupPolicy 'Microsoft.DataProtection/backupVaults/backupPolicies@2023-11-01' = {
  parent: backupVault
  name: diskPolicyName
  properties: {
    datasourceTypes: [
      'Microsoft.Compute/disks'
    ]
    objectType: 'BackupPolicy'
    policyRules: [
      {
        // Regra de BACKUP: define quando executar
        name: 'BackupDaily'
        objectType: 'AzureBackupRule'
        backupParameters: {
          objectType: 'AzureBackupParams'
          // backupType: Incremental = apenas blocos alterados (menor custo)
          // Full nao e suportado para disk backup
          backupType: 'Incremental'
        }
        trigger: {
          objectType: 'ScheduleBasedTriggerContext'
          schedule: {
            // Formato ISO 8601: backup diario as 02:00 UTC
            repeatingTimeIntervals: [
              'R/2024-01-01T02:00:00+00:00/P1D'
            ]
            // P1D = Period 1 Day (diario)
            // Outros exemplos: PT4H (a cada 4h), P1W (semanal)
          }
          taggingCriteria: [
            {
              // Tag padrao: aplica retencao default a todos os recovery points
              isDefault: true
              tagInfo: {
                tagName: 'Default'
              }
              taggingPriority: 99
            }
          ]
        }
        dataStore: {
          // OperationalStore: snapshots ficam na subscription (rapido para restore)
          // VaultStore: dados copiados para o vault (mais seguro, mais lento)
          // Disk backup usa OperationalStore por padrao
          datastoreType: 'OperationalStore'
          objectType: 'DataStoreInfoBase'
        }
      }
      {
        // Regra de RETENCAO: define quanto tempo manter
        name: 'Default'
        objectType: 'AzureRetentionRule'
        isDefault: true
        lifecycles: [
          {
            // deleteAfter: quando excluir os recovery points
            // P30D = Period 30 Days
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P${retentionDays}D'
            }
            sourceDataStore: {
              datastoreType: 'OperationalStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
      }
    ]
  }
}

// ============================================================
// Outputs
// ============================================================
@description('Resource ID do Backup Vault (necessario para configurar backup instances via CLI)')
output backupVaultId string = backupVault.id

@description('Nome do Backup Vault')
output backupVaultName string = backupVault.name

@description('Principal ID da managed identity do vault (necessario para role assignments)')
output backupVaultPrincipalId string = backupVault.identity.principalId

@description('Nome da politica de backup de disco')
output diskPolicyName string = diskBackupPolicy.name

@description('Resource ID da politica de backup')
output diskPolicyId string = diskBackupPolicy.id
```

Deploy:

```bash
# ============================================================
# DEPLOY - Backup Vault + Disk Policy
# ============================================================

# Criar Resource Group para o Backup Vault
az group create --name rg-contoso-management --location eastus

# Deploy do template
az deployment group create \
    -g rg-contoso-management \
    -f bloco6-backup-vault.bicep \
    --query "properties.outputs" -o table

# Validar: Backup Vault criado com LRS
az dataprotection backup-vault show \
    -g rg-contoso-management \
    --vault-name bv-contoso-disks \
    --query "{name:name, location:location, redundancy:properties.storageSettings[0].type}" \
    -o table

# Validar: Policy criada
az dataprotection backup-policy show \
    -g rg-contoso-management \
    --vault-name bv-contoso-disks \
    --name bv-contoso-disks-disk-policy \
    --query "{name:name, datasources:properties.datasourceTypes[0]}" \
    -o table
```

---

### Task 6.4: Comparar Backup Vault vs Recovery Services Vault

> **Esta task e conceitual — nao requer template Bicep.**
> A tabela abaixo e a referencia principal para o AZ-104.

| Aspecto | Recovery Services Vault (RSV) | Backup Vault (BV) |
|---------|-------------------------------|---------------------|
| **Tipo ARM** | `Microsoft.RecoveryServices/vaults` | `Microsoft.DataProtection/backupVaults` |
| **VM Backup** | Sim (Windows + Linux) | Nao |
| **Azure Files** | Sim (File Share backup) | Nao |
| **Site Recovery** | Sim (DR/replicacao) | Nao |
| **Azure Disks** | Nao | Sim (snapshot-based) |
| **Azure Blobs** | Nao | Sim (vaulted + operational) |
| **PostgreSQL** | Nao | Sim |
| **AKS** | Nao | Sim |
| **SAP HANA** | Sim | Nao |
| **SQL in VM** | Sim | Nao |
| **Cross Region Restore** | Sim (com GRS) | Sim (com GRS) |
| **Soft Delete** | 14 dias (configuravel) | Habilitado por padrao |
| **Bicep parent keyword** | Policy filho do vault | Policy filho do vault |

> **Dica AZ-104:** Na prova, saber qual vault suporta qual workload e critico.
> VM backup = RSV. Disk backup = BV. File Share = RSV. Blob backup = BV. Site Recovery = RSV apenas.
> O **Backup Center** no portal unifica a gestao de ambos os vaults.

---

### Task 6.5: Configurar backup de disco no Backup Vault (CLI)

> **Por que CLI e nao Bicep?** Configurar uma backup instance (associar um disco especifico ao vault)
> depende de IDs de recursos existentes e role assignments. Embora seja possivel em Bicep
> (`Microsoft.DataProtection/backupVaults/backupInstances`), na pratica usa-se CLI
> para flexibilidade e porque o portal guia as permissoes necessarias.

```bash
# ============================================================
# TASK 6.5 - Configurar Disk Backup Instance via CLI
# ============================================================
# Passos:
# 1. Atribuir roles ao Backup Vault (managed identity)
# 2. Criar snapshot resource group (onde os snapshots serao armazenados)
# 3. Inicializar e criar a backup instance
#
# Roles necessarias:
# - Disk Backup Reader: no disco (para ler dados do disco)
# - Disk Snapshot Contributor: no snapshot RG (para criar snapshots)
# ============================================================

# Variaveis
BV_NAME="bv-contoso-disks"
BV_RG="rg-contoso-management"
VM_RG="rg-contoso-compute"
VM_NAME="vm-api-01"
POLICY_NAME="bv-contoso-disks-disk-policy"

# Obter IDs necessarios
BV_PRINCIPAL_ID=$(az dataprotection backup-vault show \
    -g "$BV_RG" --vault-name "$BV_NAME" \
    --query "identity.principalId" -o tsv)

DISK_ID=$(az vm show -g "$VM_RG" -n "$VM_NAME" \
    --query "storageProfile.osDisk.managedDisk.id" -o tsv)

DISK_RG_ID=$(az group show -g "$VM_RG" --query id -o tsv)
SNAPSHOT_RG_ID=$(az group show -g "$BV_RG" --query id -o tsv)

echo "Backup Vault Principal ID: $BV_PRINCIPAL_ID"
echo "Disk ID: $DISK_ID"

# 1. Atribuir role: Disk Backup Reader no RG do disco
#    Permite ao vault ler os dados do disco para criar snapshots
az role assignment create \
    --assignee-object-id "$BV_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Disk Backup Reader" \
    --scope "$DISK_RG_ID"

# 2. Atribuir role: Disk Snapshot Contributor no RG de snapshots
#    Permite ao vault criar e gerenciar snapshots neste RG
az role assignment create \
    --assignee-object-id "$BV_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Disk Snapshot Contributor" \
    --scope "$SNAPSHOT_RG_ID"

echo "Roles atribuidas. Aguardando propagacao (30s)..."
sleep 30

# 3. Inicializar backup instance (prepara configuracao)
#    az dataprotection backup-instance initialize:
#    - Gera o JSON de configuracao necessario para criar a instance
#    - --datasource-id: recurso a proteger (disco)
#    - --datasource-type: tipo do recurso (AzureDisk)
#    - --policy-id: policy que define schedule/retention
#    - --snapshot-resource-group-name: RG onde ficam os snapshots
az dataprotection backup-instance initialize \
    --datasource-id "$DISK_ID" \
    --datasource-type AzureDisk \
    --policy-id $(az dataprotection backup-policy show \
        -g "$BV_RG" --vault-name "$BV_NAME" \
        --name "$POLICY_NAME" --query id -o tsv) \
    --snapshot-resource-group-name "$BV_RG" \
    > backup-instance.json

# 4. Criar backup instance (ativa a protecao)
az dataprotection backup-instance create \
    -g "$BV_RG" \
    --vault-name "$BV_NAME" \
    --backup-instance @backup-instance.json

# 5. Validar: disco protegido
az dataprotection backup-instance list \
    -g "$BV_RG" \
    --vault-name "$BV_NAME" \
    --query "[].{name:name, status:properties.currentProtectionState, datasource:properties.dataSourceInfo.resourceName}" \
    -o table

echo ""
echo "=== Disk Backup Configurado ==="
echo "O Backup Vault criara snapshots incrementais conforme a policy"
echo "Snapshots ficam no OperationalStore (rapido para restore)"
```

> **Conceito:** Disk backup usa snapshots incrementais — apenas blocos alterados desde o ultimo snapshot
> sao capturados. Isso e mais eficiente que VM backup completo do RSV.
> Ideal para proteger discos individuais sem overhead de backup de VM.

---

## Modo Desafio - Bloco 6

- [ ] Criar RG `rg-contoso-moved` e mover VM Linux para ele via CLI (`az resource move`)
- [ ] Verificar recursos dependentes movidos junto (NIC, Disk)
- [ ] Entender as diferencas entre move entre RGs vs move entre regioes
- [ ] Mover VM de volta ao RG original
- [ ] Deploy `bloco6-backup-vault.bicep` (Backup Vault + disk policy)
- [ ] Comparar workloads suportados: RSV vs Backup Vault (tabela conceitual)
- [ ] Configurar backup de disco de VM no Backup Vault via CLI
- [ ] Validar backup instance no Backup Vault

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce precisa mover uma VM para outro Resource Group na mesma regiao. A VM precisa ser desligada?**

A) Sim, a VM deve estar parada (deallocated) para mover
B) Nao, a VM pode ser movida enquanto esta running
C) Sim, mas apenas se a VM tiver data disks
D) Depende do tamanho da VM

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, a VM pode ser movida enquanto esta running**

Move entre Resource Groups na mesma regiao nao requer downtime. O Azure atualiza o resource ID mas a VM continua operando normalmente. Todos os recursos dependentes (NIC, disks, public IP) devem ser movidos juntos.

</details>

### Questao 6.2
**Qual vault do Azure suporta backup de Azure Managed Disks (snapshots incrementais)?**

A) Recovery Services Vault
B) Backup Vault
C) Ambos
D) Nenhum — discos usam Azure Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) Backup Vault**

O backup de Azure Managed Disks (baseado em snapshots incrementais) e suportado pelo Backup Vault (`Microsoft.DataProtection/backupVaults`), nao pelo Recovery Services Vault. O RSV suporta backup de VMs completas (que inclui os discos), mas nao backup de discos individuais.

</details>

### Questao 6.3
**Em Bicep, como voce declara um Backup Policy como recurso filho do Backup Vault?**

A) Usando `scope: backupVault`
B) Usando `parent: backupVault`
C) Usando `dependsOn: [backupVault]`
D) Concatenando o nome: `'${backupVaultName}/${policyName}'`

<details>
<summary>Ver resposta</summary>

**Resposta: B) Usando `parent: backupVault`**

Em Bicep, `parent:` declara hierarquia pai-filho. O Bicep gera automaticamente o nome composto e o `dependsOn`. `scope:` e para extension resources (como Diagnostic Settings). A opcao D funciona em ARM JSON mas nao e o padrao idiomatico em Bicep.

</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```bash
# Pausar
az vm deallocate -g rg-contoso-compute -n vm-web-01 --no-wait
az vm deallocate -g rg-contoso-compute -n vm-api-01 --no-wait
az monitor metrics alert update -g rg-contoso-management -n alert-vm-web-01-cpu --enabled false

# Retomar
az vm start -g rg-contoso-compute -n vm-web-01 --no-wait
az vm start -g rg-contoso-compute -n vm-api-01 --no-wait
az monitor metrics alert update -g rg-contoso-management -n alert-vm-web-01-cpu --enabled true
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia.

---

# Cleanup Unificado

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos
# ============================================================

# 1. Desabilitar backup antes de deletar vault
# O vault NAO pode ser deletado com itens protegidos
echo "1. Desabilitando backups..."

# Obter container e item names
CONTAINER=$(az backup container list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --backup-management-type AzureIaasVM \
    --query "[0].name" -o tsv 2>/dev/null)

ITEM=$(az backup item list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --query "[?properties.backupManagementType=='AzureIaasVM'].name" -o tsv 2>/dev/null)

# Desabilitar protecao VM + deletar dados
if [ -n "$CONTAINER" ] && [ -n "$ITEM" ]; then
    az backup protection disable \
        --container-name "$CONTAINER" \
        --item-name "$ITEM" \
        --vault-name "$VAULT_NAME" \
        -g "$RG11" \
        --delete-backup-data true \
        --yes 2>/dev/null
    echo "Protecao VM desabilitada"
fi

# Desabilitar protecao File Share + deletar dados
FS_ITEM=$(az backup item list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --query "[?properties.backupManagementType=='AzureStorage'].name" -o tsv 2>/dev/null)

FS_CONTAINER=$(az backup container list \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --backup-management-type AzureStorage \
    --query "[0].name" -o tsv 2>/dev/null)

if [ -n "$FS_CONTAINER" ] && [ -n "$FS_ITEM" ]; then
    az backup protection disable \
        --container-name "$FS_CONTAINER" \
        --item-name "$FS_ITEM" \
        --vault-name "$VAULT_NAME" \
        -g "$RG11" \
        --delete-backup-data true \
        --yes 2>/dev/null
    echo "Protecao File Share desabilitada"
fi

# 2. Desabilitar backup instances no Backup Vault (Bloco 6)
echo "2. Desabilitando Backup Vault instances..."
BV_INSTANCES=$(az dataprotection backup-instance list \
    -g rg-contoso-management --vault-name bv-contoso-disks \
    --query "[].name" -o tsv 2>/dev/null)

for INST in $BV_INSTANCES; do
    az dataprotection backup-instance stop-protection \
        -g rg-contoso-management --vault-name bv-contoso-disks \
        --backup-instance-name "$INST" 2>/dev/null
    az dataprotection backup-instance delete \
        -g rg-contoso-management --vault-name bv-contoso-disks \
        --backup-instance-name "$INST" --yes 2>/dev/null
    echo "  Backup instance $INST removida"
done

# 3. Remover Diagnostic Settings
echo "3. Removendo diagnostic settings..."
az monitor diagnostic-settings delete \
    --name "vault-to-law" \
    --resource "$VAULT_NAME" \
    --resource-group "$RG11" \
    --resource-type "Microsoft.RecoveryServices/vaults" 2>/dev/null

# 4. Remover DCR association
echo "4. Removendo DCR association..."
VM_RESOURCE_ID=$(az vm show -g "$RG11" -n "vm-web-01" --query id -o tsv 2>/dev/null)
az monitor data-collection rule association delete \
    --name "vm-web-01-dcr-association" \
    --resource "$VM_RESOURCE_ID" \
    --yes 2>/dev/null

# 5. Deletar Resource Groups
echo "5. Deletando Resource Groups..."
az group delete --name "$RG11" --yes --no-wait
az group delete --name "$RG12" --yes --no-wait
az group delete --name "$RG13" --yes --no-wait
az group delete --name rg-contoso-management --yes --no-wait
az group delete --name rg-contoso-moved --yes --no-wait 2>/dev/null

echo ""
echo "=== CLEANUP INICIADO ==="
echo "RGs estao sendo deletados em background (pode levar 5-10 min)"
echo "Verifique no portal: Resource Groups → filtrar por 'rg-contoso-'"
```

> **IMPORTANTE:** O Recovery Services Vault NAO pode ser deletado se houver itens protegidos.
> Por isso, o cleanup desabilita backup + deleta dados ANTES de remover o RG.
> O Backup Vault tambem requer remover backup instances antes da exclusao do RG.

---

# Key Takeaways Consolidados

## Bicep vs ARM JSON vs Portal

| Aspecto | Bicep | ARM JSON | Portal |
|---------|-------|----------|--------|
| Sintaxe | Concisa, declarativa | Verbosa, JSON | Visual |
| Dependencias | **Implicitas** (automaticas) | Explicitas (`dependsOn`) | N/A |
| Type safety | Decorators (`@allowed`, `@minValue`, `@secure`) | Nenhum | Validacao visual |
| Reutilizacao | Modules, loops (`for`) | Linked/nested templates | N/A |
| Extension resources | `scope: recurso` | `scope` em JSON | Dropdown |
| Recursos filhos | `parent: recurso` | Nome concatenado + dependsOn | Automatico |

## Conceitos Bicep Demonstrados

| Conceito | Onde no lab |
|----------|-------------|
| `parent:` (recurso filho) | `bloco1-backup.bicep` (policy filho do vault) |
| `parent:` (recurso filho) | `bloco6-backup-vault.bicep` (disk policy filho do Backup Vault) |
| `existing` keyword | `bloco2-fileshare-backup.bicep` (vault existente) |
| `scope:` (extension resource) | `bloco5-vault-diagnostics.bicep` (diagnostic settings) |
| `targetScope = 'subscription'` | `bloco3-asr-infra.bicep` (criar RG) |
| `@description`, `@minValue`, `@maxValue` | `bloco5-loganalytics.bicep`, `bloco6-backup-vault.bicep` |
| `dependsOn` explicito (quando necessario) | `bloco2-fileshare-backup.bicep` |
| Hierarquia profunda (3 niveis) | `bloco2-storage.bicep` (storage/blobServices/containers) |
| Dependencias implicitas | `bloco4-monitor.bicep` (alert → action group) |
| String interpolation em duracoes | `bloco6-backup-vault.bicep` (`'P${retentionDays}D'`) |
| `identity` (managed identity) | `bloco6-backup-vault.bicep` (SystemAssigned para acesso a discos) |

## Comandos de Deploy por Scope

| Scope | Comando | targetScope |
|-------|---------|-------------|
| Resource Group | `az deployment group create -g <rg>` | (padrao) |
| Subscription | `az deployment sub create --location <loc>` | `subscription` |
| Management Group | `az deployment mg create --management-group-id <mg>` | `managementGroup` |
| Tenant | `az deployment tenant create --location <loc>` | `tenant` |

## Templates Criados

| Template | Scope | Recursos |
|----------|-------|----------|
| `bloco1-backup.bicep` | resourceGroup | RSV + backup policy (VM) |
| `bloco2-storage.bicep` | resourceGroup | Storage + soft delete + versioning + share |
| `bloco2-fileshare-backup.bicep` | resourceGroup | File share backup policy + protection |
| `bloco3-asr-infra.bicep` | subscription | RG na regiao DR |
| `bloco3-asr-vault.bicep` | resourceGroup | RSV DR + fabrics + containers + policy + mapping |
| `bloco4-monitor.bicep` | resourceGroup | Action Group + CPU alert + Activity Log alert |
| `bloco5-loganalytics.bicep` | resourceGroup | Log Analytics Workspace |
| `bloco5-vm-agent.bicep` | resourceGroup | AMA extension na VM |
| `bloco5-diagnostics.bicep` | resourceGroup | Data Collection Rule |
| `bloco5-vault-diagnostics.bicep` | resourceGroup | Diagnostic Settings no vault |
| `bloco6-backup-vault.bicep` | resourceGroup | Backup Vault (LRS) + disk backup policy |

## Operacoes que Usam CLI (nao Bicep)

| Operacao | Motivo |
|----------|--------|
| Habilitar backup de VM | Nomes de container/item seguem convencao complexa |
| Backup on-demand | Operacao de controle, nao provisionamento |
| Restore | Operacao de controle |
| Failover (ASR) | Operacao de controle |
| DCR Association (cross-RG) | Scope da VM em outro RG |
| Network Watcher (testes) | Ferramenta operacional |
| Consultas KQL | Leitura de dados |
| VM Move entre RGs | Operacao imperativa (`az resource move`), nao provisionamento |
| Disk backup instance | Depende de IDs de recursos existentes + role assignments |
