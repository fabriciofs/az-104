# Lab AZ-104 - Semana 2: Tudo via ARM Templates (JSON)

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI ja vem pre-instalado
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.json`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab de Storage & Compute (~30+ recursos) usando ARM Templates JSON + CLI.
> Cada template inclui boilerplate completo e e fortemente comentado.

---

## Pre-requisitos: Cloud Shell e Conceitos ARM Template

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (Bash)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui Azure CLI pre-instalado e a autenticacao e automatica.
> Para criar os arquivos `.json`, use o editor integrado: `code nome-do-arquivo.json`

Antes de comecar, relembre a estrutura de um ARM template:

```json
{
    // 1. Schema: define ONDE o template sera deployado
    //    - deploymentTemplate: resource group (padrao)
    //    - subscriptionDeploymentTemplate: subscription
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",

    // 2. Versao do conteudo (sempre 1.0.0.0)
    "contentVersion": "1.0.0.0",

    // 3. Parameters: valores fornecidos pelo usuario no deploy
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": { "description": "Regiao do recurso" }
        }
    },

    // 4. Variables: valores calculados internamente
    "variables": {
        "resourceName": "[concat('my-', parameters('location'), '-resource')]"
    },

    // 5. Resources: os recursos a criar/atualizar
    "resources": [
        {
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2023-01-01",
            "name": "mystorageaccount",
            "location": "[parameters('location')]",
            "dependsOn": [],  // EXPLICITO! (diferente do Bicep que e implicito)
            "properties": { }
        }
    ],

    // 6. Outputs: valores exportados apos deploy
    "outputs": {
        "storageId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Storage/storageAccounts', 'mystorageaccount')]"
        }
    }
}
```

> **ARM vs Bicep:** Em Bicep, dependencias sao **implicitas** (detectadas automaticamente).
> Em ARM JSON, voce PRECISA declarar `dependsOn` explicitamente quando um recurso depende de outro.

### Funcoes ARM Essenciais (Revisao)

| Funcao | Uso | Exemplo |
|--------|-----|---------|
| `[parameters('x')]` | Ler parametro | `[parameters('location')]` |
| `[variables('x')]` | Ler variavel | `[variables('storageName')]` |
| `[resourceId(...)]` | ID de recurso | `[resourceId('Microsoft.Storage/storageAccounts', 'mysa')]` |
| `[concat(...)]` | Concatenar strings | `[concat('prefix-', parameters('name'))]` |
| `[resourceGroup().location]` | Regiao do RG | Usado como default em location |
| `[reference(...)]` | Propriedade de recurso | `[reference(resourceId(...)).primaryEndpoints]` |
| `[uniqueString(...)]` | Hash deterministico | `[uniqueString(resourceGroup().id)]` |

---

## Verificacao e Variaveis

```bash
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# Azure CLI ja instalado e autenticado no Cloud Shell
az version
az account show --query "{name:name, id:id}" -o table

# Instalar extensao para Container Apps (Bloco 5)
# Necessaria para: az containerapp ...
az extension add --name containerapp --upgrade 2>/dev/null

if az extension show --name containerapp &>/dev/null; then
    echo "✓ Extensao containerapp instalada: $(az extension show --name containerapp --query version -o tsv)"
else
    echo "✗ ERRO: Extensao containerapp NAO foi instalada."
    echo "  Comandos de Container Apps (Bloco 5) nao funcionarao."
    echo "  Tente manualmente: az extension add --name containerapp"
fi

# Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"

# ============================================================
# VARIAVEIS GLOBAIS
# ============================================================
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" # ← ALTERE
LOCATION="eastus"

# Storage
RG6="az104-rg6"
STORAGE_ACCOUNT_NAME="az104storage${RANDOM}"
CONTAINER_NAME="contoso-data"
FILE_SHARE_NAME="contoso-files"

# VMs
RG7="az104-rg7"
VM_WIN_NAME="az104-vm-win"
VM_LINUX_NAME="az104-vm-linux"
VMSS_NAME="az104-vmss"
VM_SIZE="Standard_D2s_v3"
ADMIN_USERNAME="localadmin"
ADMIN_PASSWORD="SenhaComplexa@2024!" # ← ALTERE

# Web Apps
RG8="az104-rg8"
APP_SERVICE_PLAN="az104-asp"
WEB_APP_NAME="az104-webapp-${RANDOM}"

# ACI
RG9="az104-rg9"

# Container Apps
RG10="az104-rg10"
```

---

## Mapa de Dependencias

```
Bloco 1 (Storage) → ARM templates + CLI
  │
  ▼
Bloco 2 (VMs) → ARM templates
  │
  ▼
Bloco 3 (Web Apps) → ARM templates
  │
  ▼
Bloco 4 (ACI) → ARM template
  │
  ▼
Bloco 5 (Container Apps) → ARM templates
```

---

# Bloco 1 - Storage

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** Storage Account, Blob Container, File Share, Lifecycle Policy, Network Rules, Private Endpoint + DNS

---

### Task 1.1: Criar Resource Group para Storage

```bash
# ============================================================
# TASK 1.1 - Criar RG para recursos de Storage
# ============================================================
az group create --name "$RG6" --location "$LOCATION"
```

---

### Task 1.2: Storage Account + Blob Container + File Share via ARM

Salve como **`bloco1-storage.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS: valores fornecidos no deploy
    // ============================================================
    "parameters": {
        "storageAccountName": {
            "type": "string",
            "minLength": 3,
            "maxLength": 24,
            "metadata": {
                "description": "Nome unico da Storage Account (3-24 chars, lowercase + numeros)"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Regiao do recurso"
            }
        },
        "containerName": {
            "type": "string",
            "defaultValue": "contoso-data",
            "metadata": {
                "description": "Nome do blob container"
            }
        },
        "fileShareName": {
            "type": "string",
            "defaultValue": "contoso-files",
            "metadata": {
                "description": "Nome do file share"
            }
        },
        "fileShareQuotaGB": {
            "type": "int",
            "defaultValue": 5,
            "minValue": 1,
            "maxValue": 5120,
            "metadata": {
                "description": "Quota do file share em GiB"
            }
        }
    },

    // ============================================================
    // VARIABLES: valores calculados internamente
    // ============================================================
    "variables": {
        // uniqueString() gera hash deterministico baseado no RG
        // Garante nome unico sem depender de $RANDOM
        "storageAccountId": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"
    },

    // ============================================================
    // RESOURCES: os recursos a criar
    // ============================================================
    "resources": [
        // --------------------------------------------------------
        // 1. Storage Account
        // --------------------------------------------------------
        {
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2023-01-01",
            "name": "[parameters('storageAccountName')]",
            "location": "[parameters('location')]",
            "tags": {
                "environment": "lab",
                "project": "az104"
            },
            // kind: StorageV2 = General-purpose v2 (recomendado)
            // Suporta Blob, File, Queue, Table
            "kind": "StorageV2",
            "sku": {
                // Standard_LRS = Locally Redundant Storage (3 copias no mesmo datacenter)
                // Outras opcoes: Standard_GRS, Standard_ZRS, Standard_RAGRS
                "name": "Standard_LRS"
            },
            "properties": {
                // accessTier: Hot = acesso frequente (mais caro storage, mais barato acesso)
                //             Cool = acesso infrequente (mais barato storage, mais caro acesso)
                "accessTier": "Hot",
                // TLS 1.2 minimo (seguranca)
                "minimumTlsVersion": "TLS1_2",
                // Permitir apenas HTTPS
                "supportsHttpsTrafficOnly": true,
                // Desabilitar acesso publico aos blobs por padrao
                "allowBlobPublicAccess": false,
                // Habilitar hierarchical namespace = Azure Data Lake Storage Gen2
                // false = Blob Storage normal
                "isHnsEnabled": false
            }
        },

        // --------------------------------------------------------
        // 2. Blob Container
        // --------------------------------------------------------
        {
            // Tipo: recurso FILHO de storageAccounts
            // Formato: Microsoft.Storage/storageAccounts/blobServices/containers
            "type": "Microsoft.Storage/storageAccounts/blobServices/containers",
            "apiVersion": "2023-01-01",
            // Nome composto: storageAccount/default/containerName
            // "default" e o blobService padrao (sempre "default")
            "name": "[concat(parameters('storageAccountName'), '/default/', parameters('containerName'))]",
            // dependsOn EXPLICITO — ARM nao detecta automaticamente!
            // Em Bicep: parent: storageAccount criaria dependencia implicita
            "dependsOn": [
                "[variables('storageAccountId')]"
            ],
            "properties": {
                // publicAccess: None = sem acesso anonimo
                // Outras opcoes: Blob (acesso anonimo ao blob), Container (acesso anonimo ao container + blobs)
                "publicAccess": "None"
            }
        },

        // --------------------------------------------------------
        // 3. File Share
        // --------------------------------------------------------
        {
            // Tipo: recurso FILHO de storageAccounts/fileServices
            "type": "Microsoft.Storage/storageAccounts/fileServices/shares",
            "apiVersion": "2023-01-01",
            // Nome composto: storageAccount/default/shareName
            "name": "[concat(parameters('storageAccountName'), '/default/', parameters('fileShareName'))]",
            "dependsOn": [
                "[variables('storageAccountId')]"
            ],
            "properties": {
                // Quota em GiB — limita o tamanho maximo do share
                "shareQuota": "[parameters('fileShareQuotaGB')]",
                // accessTier: TransactionOptimized = uso geral
                // Outras: Hot (acesso frequente), Cool (arquivamento)
                "accessTier": "TransactionOptimized"
            }
        }
    ],

    // ============================================================
    // OUTPUTS: valores exportados apos deploy
    // ============================================================
    "outputs": {
        "storageAccountId": {
            "type": "string",
            "value": "[variables('storageAccountId')]"
        },
        "storageAccountName": {
            "type": "string",
            "value": "[parameters('storageAccountName')]"
        },
        "primaryBlobEndpoint": {
            "type": "string",
            "value": "[reference(variables('storageAccountId'), '2023-01-01').primaryEndpoints.blob]"
        },
        "primaryFileEndpoint": {
            "type": "string",
            "value": "[reference(variables('storageAccountId'), '2023-01-01').primaryEndpoints.file]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "[concat(parameters('storageAccountName'), '/default/', parameters('containerName'))]"` — nome composto verboso
> - Bicep: `parent: storageAccount` + `name: containerName` — mais claro com `parent`
> - ARM: `dependsOn` obrigatorio para cada recurso filho
> - Bicep: `parent` cria dependencia implicita automaticamente
> - ARM: `[reference(variables('storageAccountId'), '2023-01-01').primaryEndpoints.blob]` — verboso!
> - Bicep: `storageAccount.properties.primaryEndpoints.blob` — direto

Deploy:

```bash
# ============================================================
# Deploy Storage Account + Container + File Share
# ============================================================
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-storage.json \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

# Verificar recursos criados
echo "=== Storage Account ==="
az storage account show -g "$RG6" -n "$STORAGE_ACCOUNT_NAME" \
    --query "{name:name, kind:kind, sku:sku.name, accessTier:accessTier}" -o table

echo ""
echo "=== Blob Container ==="
az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login \
    --query "[].{name:name, publicAccess:properties.publicAccess}" -o table

echo ""
echo "=== File Share ==="
az storage share-rm list --storage-account "$STORAGE_ACCOUNT_NAME" -g "$RG6" \
    --query "[].{name:name, quota:shareQuota, tier:accessTier}" -o table
```

---

### Task 1.3: Lifecycle Management Policy via ARM

Salve como **`bloco1-lifecycle.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "storageAccountName": {
            "type": "string",
            "metadata": {
                "description": "Nome da Storage Account existente"
            }
        }
    },
    "resources": [
        {
            // Lifecycle Management Policy — gerencia movimentacao automatica de blobs entre tiers
            // Tipo: recurso FILHO do blobService
            "type": "Microsoft.Storage/storageAccounts/managementPolicies",
            "apiVersion": "2023-01-01",
            // Nome fixo "default" — cada storage account tem APENAS UMA management policy
            "name": "[concat(parameters('storageAccountName'), '/default')]",
            "properties": {
                "policy": {
                    "rules": [
                        {
                            "name": "MoveToCoolAfter30Days",
                            "enabled": true,
                            "type": "Lifecycle",
                            "definition": {
                                // Filtros: quais blobs essa regra afeta
                                "filters": {
                                    "blobTypes": [ "blockBlob" ],
                                    // prefixMatch: aplica apenas a blobs com este prefixo
                                    "prefixMatch": [ "contoso-data/" ]
                                },
                                // Acoes: o que fazer com os blobs que correspondem
                                "actions": {
                                    "baseBlob": {
                                        // Mover para Cool apos 30 dias sem modificacao
                                        "tierToCool": {
                                            "daysAfterModificationGreaterThan": 30
                                        },
                                        // Mover para Archive apos 90 dias sem modificacao
                                        "tierToArchive": {
                                            "daysAfterModificationGreaterThan": 90
                                        },
                                        // Deletar apos 365 dias sem modificacao
                                        "delete": {
                                            "daysAfterModificationGreaterThan": 365
                                        }
                                    },
                                    // Snapshots: deletar apos 90 dias
                                    "snapshot": {
                                        "delete": {
                                            "daysAfterCreationGreaterThan": 90
                                        }
                                    }
                                }
                            }
                        }
                    ]
                }
            }
        }
    ]
}
```

> **Conceito AZ-104 — Lifecycle Management:**
> - **Hot → Cool → Archive → Delete**: movimentacao automatica baseada em tempo
> - Hot: acesso frequente (custo storage mais alto, acesso mais barato)
> - Cool: acesso infrequente (30+ dias)
> - Archive: raro acesso (180+ dias, rehydration necessario para ler)
> - Policy e avaliada 1x/dia pelo Azure — nao e instantanea
> - Apenas Block Blobs suportam tiering

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-lifecycle.json \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

# Verificar policy
az storage account management-policy show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RG6" \
    --query "policy.rules[].{name:name, enabled:enabled}" -o table
```

---

### Task 1.4: Network Rules (Service Endpoint + Firewall) via ARM

Salve como **`bloco1-network-rules.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "storageAccountName": {
            "type": "string",
            "metadata": {
                "description": "Nome da Storage Account existente"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "allowedIpAddress": {
            "type": "string",
            "defaultValue": "203.0.113.0",
            "metadata": {
                "description": "IP publico permitido (ex: seu IP)"
            }
        }
    },
    "variables": {
        // VNet para demonstrar Service Endpoint
        "vnetName": "storage-vnet",
        "subnetName": "storage-subnet"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. VNet com Service Endpoint para Storage
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "[variables('vnetName')]",
            "location": "[parameters('location')]",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [ "10.50.0.0/16" ]
                },
                "subnets": [
                    {
                        "name": "[variables('subnetName')]",
                        "properties": {
                            "addressPrefix": "10.50.1.0/24",
                            // Service Endpoint: trafego para Storage vai via backbone Azure
                            // (nao passa pela internet publica)
                            "serviceEndpoints": [
                                {
                                    "service": "Microsoft.Storage",
                                    "locations": [ "[parameters('location')]" ]
                                }
                            ]
                        }
                    }
                ]
            }
        },

        // --------------------------------------------------------
        // 2. Storage Account COM Network Rules
        // --------------------------------------------------------
        {
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2023-01-01",
            "name": "[parameters('storageAccountName')]",
            "location": "[parameters('location')]",
            "kind": "StorageV2",
            "sku": {
                "name": "Standard_LRS"
            },
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]"
            ],
            "properties": {
                "accessTier": "Hot",
                "minimumTlsVersion": "TLS1_2",
                "supportsHttpsTrafficOnly": true,
                "allowBlobPublicAccess": false,
                // networkAcls: regras de firewall da storage account
                "networkAcls": {
                    // defaultAction: Deny = bloqueia tudo por padrao
                    // Apenas IPs e VNets listados terao acesso
                    "defaultAction": "Deny",
                    "bypass": "AzureServices",
                    // Regras de IP: permite acesso de IPs publicos especificos
                    "ipRules": [
                        {
                            "value": "[parameters('allowedIpAddress')]",
                            "action": "Allow"
                        }
                    ],
                    // Regras de VNet: permite acesso via Service Endpoint
                    "virtualNetworkRules": [
                        {
                            "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]",
                            "action": "Allow"
                        }
                    ]
                }
            }
        }
    ],
    "outputs": {
        "vnetId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]"
        },
        "subnetId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]"
        }
    }
}
```

> **Conceito AZ-104 — Network Rules:**
> - `defaultAction: Deny` = zero trust — bloqueia TUDO por padrao
> - `bypass: AzureServices` = permite servicos Azure confiados (Monitor, Backup, etc.)
> - `ipRules` = whitelist de IPs publicos
> - `virtualNetworkRules` = whitelist de subnets com Service Endpoint habilitado
> - Service Endpoint ≠ Private Endpoint: SE roteia via backbone Azure, PE cria IP privado na VNet

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-network-rules.json \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

# Verificar network rules
az storage account show -g "$RG6" -n "$STORAGE_ACCOUNT_NAME" \
    --query "networkRuleSet.{default:defaultAction, bypass:bypass, ipRules:ipRules[].value, vnetRules:length(virtualNetworkRules)}" -o json
```

---

### Task 1.5: Private Endpoint + Private DNS Zone via ARM

> **Cobranca:** Private Endpoints geram cobranca enquanto existirem.

Salve como **`bloco1-private-endpoint.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "storageAccountName": {
            "type": "string",
            "metadata": {
                "description": "Nome da Storage Account existente"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "variables": {
        "vnetName": "storage-vnet",
        "peSubnetName": "pe-subnet",
        "privateEndpointName": "[concat(parameters('storageAccountName'), '-pe')]",
        // DNS zone name padrao para Blob: privatelink.blob.core.windows.net
        // Cada servico tem sua zona: privatelink.file.core.windows.net, etc.
        "privateDnsZoneName": "privatelink.blob.core.windows.net",
        "pvtEndpointDnsGroupName": "[concat(variables('privateEndpointName'), '/default')]"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Subnet para Private Endpoint (sem Service Endpoint)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/virtualNetworks/subnets",
            "apiVersion": "2023-05-01",
            "name": "[concat(variables('vnetName'), '/', variables('peSubnetName'))]",
            "properties": {
                "addressPrefix": "10.50.2.0/24",
                // Private Endpoints NAO usam Service Endpoints
                // Mas precisam de uma subnet dedicada (boa pratica)
                "privateEndpointNetworkPolicies": "Disabled"
            }
        },

        // --------------------------------------------------------
        // 2. Private Endpoint para Blob
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/privateEndpoints",
            "apiVersion": "2023-05-01",
            "name": "[variables('privateEndpointName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('peSubnetName'))]"
            ],
            "properties": {
                "subnet": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('peSubnetName'))]"
                },
                // privateLinkServiceConnections: vincula ao recurso alvo
                "privateLinkServiceConnections": [
                    {
                        "name": "[variables('privateEndpointName')]",
                        "properties": {
                            // privateLinkServiceId: o recurso que queremos acessar via PE
                            "privateLinkServiceId": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]",
                            // groupIds: qual sub-recurso (blob, file, table, queue)
                            "groupIds": [ "blob" ]
                        }
                    }
                ]
            }
        },

        // --------------------------------------------------------
        // 3. Private DNS Zone
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/privateDnsZones",
            "apiVersion": "2020-06-01",
            "name": "[variables('privateDnsZoneName')]",
            "location": "global"
        },

        // --------------------------------------------------------
        // 4. Link DNS Zone → VNet
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
            "apiVersion": "2020-06-01",
            "name": "[concat(variables('privateDnsZoneName'), '/storage-vnet-link')]",
            "location": "global",
            "dependsOn": [
                "[resourceId('Microsoft.Network/privateDnsZones', variables('privateDnsZoneName'))]"
            ],
            "properties": {
                "virtualNetwork": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]"
                },
                "registrationEnabled": false
            }
        },

        // --------------------------------------------------------
        // 5. DNS Zone Group (vincula PE → DNS Zone)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/privateEndpoints/privateDnsZoneGroups",
            "apiVersion": "2023-05-01",
            "name": "[variables('pvtEndpointDnsGroupName')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/privateEndpoints', variables('privateEndpointName'))]",
                "[resourceId('Microsoft.Network/privateDnsZones', variables('privateDnsZoneName'))]"
            ],
            "properties": {
                "privateDnsZoneConfigs": [
                    {
                        "name": "config1",
                        "properties": {
                            "privateDnsZoneId": "[resourceId('Microsoft.Network/privateDnsZones', variables('privateDnsZoneName'))]"
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "privateEndpointIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/privateEndpoints', variables('privateEndpointName')), '2023-05-01').customDnsConfigs[0].ipAddresses[0]]"
        }
    }
}
```

> **Conceito AZ-104 — Private Endpoint vs Service Endpoint:**
>
> | Aspecto | Service Endpoint | Private Endpoint |
> |---------|------------------|------------------|
> | IP | IP publico (rota via backbone) | IP privado na VNet |
> | DNS | Mesmo FQDN publico | Precisa DNS zone privada |
> | Custo | Gratis | Pago (por PE + dados) |
> | Cross-region | Nao | Sim |
> | On-premises | Nao | Sim (via VPN/ER) |
>
> **Em producao:** Private Endpoint e preferido para seguranca maxima.

Deploy:

```bash
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco1-private-endpoint.json \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME"

# Verificar Private Endpoint
az network private-endpoint show -g "$RG6" \
    -n "${STORAGE_ACCOUNT_NAME}-pe" \
    --query "{name:name, subnet:subnet.id, status:privateLinkServiceConnections[0].properties.privateLinkServiceConnectionState.status}" \
    -o table

# Verificar DNS record criado
az network private-dns record-set a list \
    -g "$RG6" -z "privatelink.blob.core.windows.net" \
    --query "[].{name:name, ip:aRecords[0].ipv4Address}" -o table
```

---

## Modo Desafio - Bloco 1

- [ ] Deploy `bloco1-storage.json` (Storage Account + Container + File Share)
- [ ] Deploy `bloco1-lifecycle.json` (Lifecycle Policy: Hot → Cool → Archive → Delete)
- [ ] Deploy `bloco1-network-rules.json` (Firewall + Service Endpoint)
- [ ] Deploy `bloco1-private-endpoint.json` (PE + DNS Zone + Link)
- [ ] Verificar PE IP privado e DNS record

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Storage Account com `defaultAction: Deny` e sem IP rules. Acesso via portal?**

A) Permitido  B) Bloqueado  C) Apenas read  D) Depende do SKU

<details><summary>Ver resposta</summary>**Resposta: B) Bloqueado** — defaultAction Deny bloqueia tudo, incluindo portal (a menos que seu IP esteja na whitelist).</details>

### Questao 1.2
**Qual a diferenca entre Service Endpoint e Private Endpoint?**

A) SE e mais seguro  B) PE cria IP privado na VNet, SE roteia via backbone  C) Sao iguais  D) SE funciona cross-region

<details><summary>Ver resposta</summary>**Resposta: B)** PE cria um IP privado dentro da VNet. SE apenas otimiza a rota via backbone Azure (IP publico permanece).</details>

### Questao 1.3
**Lifecycle policy move blob para Cool apos 30 dias. Blob criado ontem sera movido imediatamente?**

A) Sim  B) Nao, so apos 30 dias sem modificacao  C) Depende do tier  D) Nao suporta Cool

<details><summary>Ver resposta</summary>**Resposta: B)** A policy conta dias desde a ultima modificacao, avaliada 1x/dia.</details>

### Questao 1.4
**Qual zona DNS privada para Blob storage?**

A) `privatelink.storage.azure.com`  B) `privatelink.blob.core.windows.net`  C) `blob.privatelink.azure.com`  D) `storage.privatelink.net`

<details><summary>Ver resposta</summary>**Resposta: B) `privatelink.blob.core.windows.net`** — cada servico tem sua zona especifica.</details>

---

# Bloco 2 - Virtual Machines

**Tecnologia:** ARM Templates JSON
**Recursos criados:** Windows VM, Linux VM, Data Disk, VMSS com Autoscale, Custom Script Extension

---

### Task 2.1: Criar Resource Group e VNet base para VMs

```bash
# ============================================================
# TASK 2.1 - RG e VNet para VMs
# ============================================================
az group create --name "$RG7" --location "$LOCATION"
```

Salve como **`bloco2-vnet.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "vm-vnet",
            "location": "[parameters('location')]",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [ "10.60.0.0/16" ]
                },
                "subnets": [
                    {
                        "name": "vm-subnet",
                        "properties": {
                            "addressPrefix": "10.60.1.0/24"
                        }
                    },
                    {
                        "name": "vmss-subnet",
                        "properties": {
                            "addressPrefix": "10.60.2.0/24"
                        }
                    }
                ]
            }
        }
    ]
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-vnet.json
```

---

### Task 2.2: Windows VM via ARM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

Salve como **`bloco2-vm-windows.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-win",
            "metadata": {
                "description": "Nome da VM Windows"
            }
        },
        "vmSize": {
            "type": "string",
            "defaultValue": "Standard_D2s_v3",
            "allowedValues": [
                "Standard_B2s",
                "Standard_D2s_v3",
                "Standard_D4s_v3"
            ],
            "metadata": {
                "description": "Tamanho da VM"
            }
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin",
            "metadata": {
                "description": "Usuario administrador"
            }
        },
        "adminPassword": {
            "type": "securestring",
            "metadata": {
                "description": "Senha do admin (securestring = nao aparece em logs)"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "variables": {
        "nicName": "[concat(parameters('vmName'), '-nic')]",
        "pipName": "[concat(parameters('vmName'), '-pip')]",
        "subnetId": "[resourceId('Microsoft.Network/virtualNetworks/subnets', 'vm-vnet', 'vm-subnet')]"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Public IP Address
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('pipName')]",
            "location": "[parameters('location')]",
            "sku": {
                // Standard SKU: zone-redundant, static IP
                "name": "Standard"
            },
            "properties": {
                "publicIPAllocationMethod": "Static"
            }
        },

        // --------------------------------------------------------
        // 2. Network Interface (NIC)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "[variables('nicName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
            ],
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[variables('subnetId')]"
                            },
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
                            }
                        }
                    }
                ]
            }
        },

        // --------------------------------------------------------
        // 3. Windows Virtual Machine
        // --------------------------------------------------------
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2024-03-01",
            "name": "[parameters('vmName')]",
            "location": "[parameters('location')]",
            // dependsOn: VM depende da NIC (que depende do PIP)
            // A cadeia completa: PIP → NIC → VM
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
            ],
            "properties": {
                // hardwareProfile: define o tamanho (vCPUs, RAM)
                "hardwareProfile": {
                    "vmSize": "[parameters('vmSize')]"
                },
                // osProfile: configuracao do SO
                "osProfile": {
                    "computerName": "[parameters('vmName')]",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]",
                    "windowsConfiguration": {
                        // provisionVMAgent: OBRIGATORIO para extensions
                        "provisionVMAgent": true,
                        "enableAutomaticUpdates": true,
                        "patchSettings": {
                            "patchMode": "AutomaticByOS"
                        }
                    }
                },
                // storageProfile: disco do SO + imagem
                "storageProfile": {
                    // imageReference: qual imagem usar
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2022-datacenter-azure-edition",
                        "version": "latest"
                    },
                    // osDisk: disco do sistema operacional
                    "osDisk": {
                        "name": "[concat(parameters('vmName'), '-osdisk')]",
                        "createOption": "FromImage",
                        "managedDisk": {
                            // StandardSSD_LRS: bom custo-beneficio para labs
                            "storageAccountType": "StandardSSD_LRS"
                        },
                        "diskSizeGB": 128
                    }
                },
                // networkProfile: NICs associadas
                "networkProfile": {
                    "networkInterfaces": [
                        {
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
                        }
                    ]
                },
                // diagnosticsProfile: boot diagnostics (screenshots de boot)
                "diagnosticsProfile": {
                    "bootDiagnostics": {
                        "enabled": true
                    }
                }
            }
        }
    ],
    "outputs": {
        "vmId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/virtualMachines', parameters('vmName'))]"
        },
        "publicIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))).ipAddress]"
        },
        "privateIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))).ipConfigurations[0].properties.privateIPAddress]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"type": "securestring"` — tipo especial que mascara o valor em logs/outputs
> - Bicep: `@secure() param adminPassword string` — decorator mais legivel
> - ARM: cadeia de `dependsOn` explicita (PIP → NIC → VM)
> - Bicep: `nic.id` referencia cria dependencia automatica
> - ARM: `"[concat(parameters('vmName'), '-nic')]"` — funcao concat
> - Bicep: `'${vmName}-nic'` — interpolacao de string

Deploy:

```bash
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-vm-windows.json \
    --parameters adminPassword="$ADMIN_PASSWORD"

echo "=== Windows VM ==="
az vm show -g "$RG7" -n "$VM_WIN_NAME" -d \
    --query "{name:name, powerState:powerState, publicIps:publicIps, privateIps:privateIps}" -o table
```

---

### Task 2.3: Linux VM (SSH key) via ARM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

Salve como **`bloco2-vm-linux.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-linux"
        },
        "vmSize": {
            "type": "string",
            "defaultValue": "Standard_D2s_v3"
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin"
        },
        "adminPassword": {
            "type": "securestring",
            "metadata": {
                "description": "Senha do admin (usada como fallback se SSH nao configurado)"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "variables": {
        "nicName": "[concat(parameters('vmName'), '-nic')]",
        "pipName": "[concat(parameters('vmName'), '-pip')]",
        "subnetId": "[resourceId('Microsoft.Network/virtualNetworks/subnets', 'vm-vnet', 'vm-subnet')]"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Public IP (Standard SKU)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('pipName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Standard" },
            "properties": {
                "publicIPAllocationMethod": "Static"
            }
        },

        // --------------------------------------------------------
        // 2. NIC
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "[variables('nicName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
            ],
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": { "id": "[variables('subnetId')]" },
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
                            }
                        }
                    }
                ]
            }
        },

        // --------------------------------------------------------
        // 3. Linux VM com autenticacao password
        //    (em producao, usar SSH key!)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2024-03-01",
            "name": "[parameters('vmName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
            ],
            "properties": {
                "hardwareProfile": {
                    "vmSize": "[parameters('vmSize')]"
                },
                "osProfile": {
                    "computerName": "[parameters('vmName')]",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]",
                    "linuxConfiguration": {
                        // disablePasswordAuthentication: false para lab
                        // Em producao: true + SSH keys
                        "disablePasswordAuthentication": false,
                        "provisionVMAgent": true
                    }
                },
                "storageProfile": {
                    "imageReference": {
                        // Ubuntu Server 22.04 LTS
                        "publisher": "Canonical",
                        "offer": "0001-com-ubuntu-server-jammy",
                        "sku": "22_04-lts-gen2",
                        "version": "latest"
                    },
                    "osDisk": {
                        "name": "[concat(parameters('vmName'), '-osdisk')]",
                        "createOption": "FromImage",
                        "managedDisk": {
                            "storageAccountType": "StandardSSD_LRS"
                        }
                    }
                },
                "networkProfile": {
                    "networkInterfaces": [
                        {
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
                        }
                    ]
                },
                "diagnosticsProfile": {
                    "bootDiagnostics": { "enabled": true }
                }
            }
        }
    ],
    "outputs": {
        "sshCommand": {
            "type": "string",
            "value": "[concat('ssh ', parameters('adminUsername'), '@', reference(resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))).ipAddress)]"
        }
    }
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-vm-linux.json \
    --parameters adminPassword="$ADMIN_PASSWORD"

echo "=== Linux VM ==="
az vm show -g "$RG7" -n "$VM_LINUX_NAME" -d \
    --query "{name:name, powerState:powerState, publicIps:publicIps, os:storageProfile.osDisk.osType}" -o table
```

---

### Task 2.4: Data Disk via ARM

Salve como **`bloco2-datadisk.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-win"
        },
        "diskName": {
            "type": "string",
            "defaultValue": "az104-vm-win-datadisk1"
        },
        "diskSizeGB": {
            "type": "int",
            "defaultValue": 64,
            "minValue": 4,
            "maxValue": 32767
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Managed Disk
        // --------------------------------------------------------
        {
            "type": "Microsoft.Compute/disks",
            "apiVersion": "2023-10-02",
            "name": "[parameters('diskName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "Premium_LRS"
            },
            "properties": {
                "creationData": {
                    "createOption": "Empty"
                },
                "diskSizeGB": "[parameters('diskSizeGB')]"
            }
        }
    ],
    "outputs": {
        "diskId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/disks', parameters('diskName'))]"
        }
    }
}
```

Deploy + attach:

```bash
# Criar o disco
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-datadisk.json

# Attach via CLI (operacao imperativa — nao declarativa)
az vm disk attach \
    --resource-group "$RG7" \
    --vm-name "$VM_WIN_NAME" \
    --name "az104-vm-win-datadisk1" \
    --lun 0

# Verificar discos
az vm show -g "$RG7" -n "$VM_WIN_NAME" \
    --query "storageProfile.dataDisks[].{name:name, sizeGB:diskSizeGB, lun:lun}" -o table
```

---

### Task 2.5: VMSS com Autoscale via ARM

> **Cobranca:** Cada instancia do VMSS gera cobranca. Escale para 0 ao pausar o lab.

Salve como **`bloco2-vmss.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmssName": {
            "type": "string",
            "defaultValue": "az104-vmss",
            "maxLength": 61
        },
        "instanceCount": {
            "type": "int",
            "defaultValue": 2,
            "minValue": 1,
            "maxValue": 100
        },
        "vmSize": {
            "type": "string",
            "defaultValue": "Standard_D2s_v3"
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin"
        },
        "adminPassword": {
            "type": "securestring"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "variables": {
        "subnetId": "[resourceId('Microsoft.Network/virtualNetworks/subnets', 'vm-vnet', 'vmss-subnet')]",
        "lbName": "[concat(parameters('vmssName'), '-lb')]",
        "lbPipName": "[concat(parameters('vmssName'), '-lb-pip')]",
        "lbFrontendName": "LoadBalancerFrontend",
        "lbBackendPoolName": "LoadBalancerBackendPool",
        "lbProbeName": "healthProbe"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Public IP para Load Balancer
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('lbPipName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Standard" },
            "properties": {
                "publicIPAllocationMethod": "Static"
            }
        },

        // --------------------------------------------------------
        // 2. Load Balancer (necessario para VMSS com IP publico)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Network/loadBalancers",
            "apiVersion": "2023-05-01",
            "name": "[variables('lbName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Standard" },
            "dependsOn": [
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('lbPipName'))]"
            ],
            "properties": {
                "frontendIPConfigurations": [
                    {
                        "name": "[variables('lbFrontendName')]",
                        "properties": {
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('lbPipName'))]"
                            }
                        }
                    }
                ],
                "backendAddressPools": [
                    {
                        "name": "[variables('lbBackendPoolName')]"
                    }
                ],
                "probes": [
                    {
                        "name": "[variables('lbProbeName')]",
                        "properties": {
                            "protocol": "Tcp",
                            "port": 80,
                            "intervalInSeconds": 15,
                            "numberOfProbes": 2
                        }
                    }
                ],
                "loadBalancingRules": [
                    {
                        "name": "httpRule",
                        "properties": {
                            "frontendIPConfiguration": {
                                "id": "[resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', variables('lbName'), variables('lbFrontendName'))]"
                            },
                            "backendAddressPool": {
                                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), variables('lbBackendPoolName'))]"
                            },
                            "probe": {
                                "id": "[resourceId('Microsoft.Network/loadBalancers/probes', variables('lbName'), variables('lbProbeName'))]"
                            },
                            "protocol": "Tcp",
                            "frontendPort": 80,
                            "backendPort": 80,
                            "enableFloatingIP": false
                        }
                    }
                ]
            }
        },

        // --------------------------------------------------------
        // 3. Virtual Machine Scale Set
        // --------------------------------------------------------
        {
            "type": "Microsoft.Compute/virtualMachineScaleSets",
            "apiVersion": "2024-03-01",
            "name": "[parameters('vmssName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/loadBalancers', variables('lbName'))]"
            ],
            // SKU do VMSS: define tamanho e quantidade de instancias
            "sku": {
                "name": "[parameters('vmSize')]",
                "tier": "Standard",
                "capacity": "[parameters('instanceCount')]"
            },
            "properties": {
                // upgradePolicy: como atualizar instancias existentes
                "upgradePolicy": {
                    // Manual = voce decide quando atualizar
                    // Automatic = atualiza automaticamente
                    // Rolling = atualiza em batches
                    "mode": "Manual"
                },
                "virtualMachineProfile": {
                    "osProfile": {
                        "computerNamePrefix": "[parameters('vmssName')]",
                        "adminUsername": "[parameters('adminUsername')]",
                        "adminPassword": "[parameters('adminPassword')]",
                        "linuxConfiguration": {
                            "disablePasswordAuthentication": false,
                            "provisionVMAgent": true
                        }
                    },
                    "storageProfile": {
                        "imageReference": {
                            "publisher": "Canonical",
                            "offer": "0001-com-ubuntu-server-jammy",
                            "sku": "22_04-lts-gen2",
                            "version": "latest"
                        },
                        "osDisk": {
                            "createOption": "FromImage",
                            "managedDisk": {
                                "storageAccountType": "StandardSSD_LRS"
                            }
                        }
                    },
                    "networkProfile": {
                        "networkInterfaceConfigurations": [
                            {
                                "name": "[concat(parameters('vmssName'), '-nic')]",
                                "properties": {
                                    "primary": true,
                                    "ipConfigurations": [
                                        {
                                            "name": "ipconfig1",
                                            "properties": {
                                                "subnet": {
                                                    "id": "[variables('subnetId')]"
                                                },
                                                "loadBalancerBackendAddressPools": [
                                                    {
                                                        "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), variables('lbBackendPoolName'))]"
                                                    }
                                                ]
                                            }
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    // extensionProfile: Custom Script Extension para instalar nginx
                    "extensionProfile": {
                        "extensions": [
                            {
                                "name": "installNginx",
                                "properties": {
                                    "publisher": "Microsoft.Azure.Extensions",
                                    "type": "CustomScript",
                                    "typeHandlerVersion": "2.1",
                                    "autoUpgradeMinorVersion": true,
                                    "settings": {
                                        "commandToExecute": "apt-get update && apt-get install -y nginx && echo 'Hello from VMSS instance' > /var/www/html/index.html"
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },

        // --------------------------------------------------------
        // 4. Autoscale Settings
        // --------------------------------------------------------
        {
            "type": "Microsoft.Insights/autoscaleSettings",
            "apiVersion": "2022-10-01",
            "name": "[concat(parameters('vmssName'), '-autoscale')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Compute/virtualMachineScaleSets', parameters('vmssName'))]"
            ],
            "properties": {
                "enabled": true,
                "name": "[concat(parameters('vmssName'), '-autoscale')]",
                // targetResourceUri: qual recurso escalar
                "targetResourceUri": "[resourceId('Microsoft.Compute/virtualMachineScaleSets', parameters('vmssName'))]",
                "profiles": [
                    {
                        "name": "defaultProfile",
                        // capacity: min, max e default de instancias
                        "capacity": {
                            "minimum": "1",
                            "maximum": "5",
                            "default": "2"
                        },
                        "rules": [
                            // Scale OUT: adicionar instancia quando CPU > 70%
                            {
                                "metricTrigger": {
                                    "metricName": "Percentage CPU",
                                    "metricResourceUri": "[resourceId('Microsoft.Compute/virtualMachineScaleSets', parameters('vmssName'))]",
                                    "operator": "GreaterThan",
                                    "threshold": 70,
                                    "timeAggregation": "Average",
                                    "timeGrain": "PT1M",
                                    "timeWindow": "PT5M",
                                    "statistic": "Average"
                                },
                                "scaleAction": {
                                    "direction": "Increase",
                                    "type": "ChangeCount",
                                    "value": "1",
                                    "cooldown": "PT5M"
                                }
                            },
                            // Scale IN: remover instancia quando CPU < 30%
                            {
                                "metricTrigger": {
                                    "metricName": "Percentage CPU",
                                    "metricResourceUri": "[resourceId('Microsoft.Compute/virtualMachineScaleSets', parameters('vmssName'))]",
                                    "operator": "LessThan",
                                    "threshold": 30,
                                    "timeAggregation": "Average",
                                    "timeGrain": "PT1M",
                                    "timeWindow": "PT5M",
                                    "statistic": "Average"
                                },
                                "scaleAction": {
                                    "direction": "Decrease",
                                    "type": "ChangeCount",
                                    "value": "1",
                                    "cooldown": "PT5M"
                                }
                            }
                        ]
                    }
                ]
            }
        }
    ],
    "outputs": {
        "vmssId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/virtualMachineScaleSets', parameters('vmssName'))]"
        },
        "lbPublicIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/publicIPAddresses', variables('lbPipName'))).ipAddress]"
        }
    }
}
```

> **Conceito AZ-104 — VMSS Autoscale:**
> - **Scale OUT** (adicionar instancias): quando metrica ultrapassa threshold
> - **Scale IN** (remover instancias): quando metrica fica abaixo do threshold
> - **Cooldown**: periodo de espera entre acoes de scale (evita oscilacao)
> - **timeWindow**: janela de tempo para avaliar a metrica
> - **capacity**: min/max/default garantem limites de custo e disponibilidade

Deploy:

```bash
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-vmss.json \
    --parameters adminPassword="$ADMIN_PASSWORD"

echo "=== VMSS ==="
az vmss show -g "$RG7" -n "$VMSS_NAME" \
    --query "{name:name, capacity:sku.capacity, vmSize:sku.name}" -o table

echo ""
echo "=== Instancias ==="
az vmss list-instances -g "$RG7" -n "$VMSS_NAME" \
    --query "[].{instanceId:instanceId, provisioningState:provisioningState}" -o table

echo ""
echo "=== Load Balancer IP ==="
az network public-ip show -g "$RG7" -n "${VMSS_NAME}-lb-pip" --query ipAddress -o tsv
```

---

### Task 2.6: Custom Script Extension via ARM (VM existente)

Salve como **`bloco2-extension.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-win"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        {
            // Custom Script Extension para Windows
            // Tipo: recurso FILHO da VM
            "type": "Microsoft.Compute/virtualMachines/extensions",
            "apiVersion": "2024-03-01",
            // Nome composto: vmName/extensionName
            "name": "[concat(parameters('vmName'), '/installIIS')]",
            "location": "[parameters('location')]",
            "properties": {
                "publisher": "Microsoft.Compute",
                "type": "CustomScriptExtension",
                "typeHandlerVersion": "1.10",
                "autoUpgradeMinorVersion": true,
                "settings": {
                    // commandToExecute: script PowerShell inline
                    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -name Web-Server -IncludeManagementTools; Set-Content -Path 'C:\\inetpub\\wwwroot\\index.html' -Value 'Hello from ARM Template VM'\""
                }
            }
        }
    ]
}
```

> **Conceito AZ-104 — VM Extensions:**
> - Extensions sao **agentes** que rodam dentro da VM apos provisionamento
> - **CustomScriptExtension** (Windows): roda PowerShell/CMD
> - **CustomScript** (Linux): roda bash/python
> - Outras: AzureMonitorAgent, DependencyAgent, DSC, etc.
> - Requer VM Agent instalado (`provisionVMAgent: true`)

Deploy:

```bash
az deployment group create \
    --resource-group "$RG7" \
    --template-file bloco2-extension.json

# Verificar extension
az vm extension list -g "$RG7" --vm-name "$VM_WIN_NAME" \
    --query "[].{name:name, status:provisioningState}" -o table
```

---

## Modo Desafio - Bloco 2

- [ ] Deploy `bloco2-vnet.json` (VNet com 2 subnets)
- [ ] Deploy `bloco2-vm-windows.json` (Windows VM + PIP + NIC)
- [ ] Deploy `bloco2-vm-linux.json` (Linux VM com Ubuntu)
- [ ] Deploy `bloco2-datadisk.json` + attach via CLI
- [ ] Deploy `bloco2-vmss.json` (VMSS + LB + Autoscale)
- [ ] Deploy `bloco2-extension.json` (Custom Script com IIS)
- [ ] Testar acesso HTTP no IP do Load Balancer

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**VMSS com autoscale: CPU 80% por 5 minutos. O que acontece?**

A) Nada  B) Scale OUT (adiciona instancia)  C) Scale IN  D) Reinicia instancias

<details><summary>Ver resposta</summary>**Resposta: B) Scale OUT** — threshold 70% ultrapassado, cooldown respeitado.</details>

### Questao 2.2
**Custom Script Extension: VM sem VM Agent. O que acontece?**

A) Extension funciona  B) Extension falha  C) VM reinicia  D) Azure instala automaticamente

<details><summary>Ver resposta</summary>**Resposta: B) Extension falha** — VM Agent e pre-requisito para qualquer extension.</details>

### Questao 2.3
**Data disk attached a VM. VM deletada. O que acontece com o disco?**

A) Deletado junto  B) Permanece como disco orfao  C) Move para outro RG  D) Depende do deleteOption

<details>
<summary>Ver resposta</summary>

**Resposta: D) Depende do deleteOption**

Se `deleteOption: Delete` no template, disco e deletado com a VM.
Se `deleteOption: Detach` (padrao), disco permanece como recurso orfao.

</details>

### Questao 2.4
**VMSS upgradePolicy: Manual. Imagem atualizada no template. Instancias existentes atualizam?**

A) Sim, imediatamente  B) Nao, precisa upgrade manual  C) Apenas novas instancias  D) Reboot automatico

<details><summary>Ver resposta</summary>**Resposta: B) Nao, precisa upgrade manual** — `az vmss update-instances` para aplicar.</details>

---

# Bloco 3 - Web Apps (App Service)

**Tecnologia:** ARM Templates JSON
**Recursos criados:** App Service Plan, Web App, Deployment Slot, Autoscale, App Settings

---

### Task 3.1: Criar Resource Group para Web Apps

```bash
az group create --name "$RG8" --location "$LOCATION"
```

---

### Task 3.2: App Service Plan + Web App + Slot via ARM

> **Cobranca:** O App Service Plan gera cobranca enquanto existir, mesmo com a app parada.

Salve como **`bloco3-webapp.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "appServicePlanName": {
            "type": "string",
            "defaultValue": "az104-asp",
            "metadata": {
                "description": "Nome do App Service Plan"
            }
        },
        "webAppName": {
            "type": "string",
            "metadata": {
                "description": "Nome globalmente unico do Web App"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "skuName": {
            "type": "string",
            "defaultValue": "S1",
            "allowedValues": [
                "F1",
                "B1",
                "S1",
                "S2",
                "P1v3",
                "P2v3"
            ],
            "metadata": {
                "description": "SKU do App Service Plan (S1+ necessario para slots)"
            }
        }
    },
    "resources": [
        // --------------------------------------------------------
        // 1. App Service Plan (define compute: CPU, RAM, features)
        // --------------------------------------------------------
        {
            "type": "Microsoft.Web/serverfarms",
            "apiVersion": "2023-01-01",
            "name": "[parameters('appServicePlanName')]",
            "location": "[parameters('location')]",
            "sku": {
                // S1: Standard tier — suporta slots, autoscale, custom domains
                // F1: Free — sem slots, sem custom domain SSL
                // B1: Basic — sem autoscale
                "name": "[parameters('skuName')]"
            },
            "kind": "linux",
            "properties": {
                // reserved: true = Linux, false = Windows
                "reserved": true
            }
        },

        // --------------------------------------------------------
        // 2. Web App
        // --------------------------------------------------------
        {
            "type": "Microsoft.Web/sites",
            "apiVersion": "2023-01-01",
            "name": "[parameters('webAppName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]"
            ],
            "properties": {
                // serverFarmId: vincula ao App Service Plan
                "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                "httpsOnly": true,
                "siteConfig": {
                    // linuxFxVersion: runtime da aplicacao
                    // Formato: RUNTIME|VERSION
                    "linuxFxVersion": "NODE|18-lts",
                    "alwaysOn": true,
                    "minTlsVersion": "1.2",
                    // appSettings: variaveis de ambiente da aplicacao
                    "appSettings": [
                        {
                            "name": "ENVIRONMENT",
                            "value": "production"
                        },
                        {
                            "name": "APP_VERSION",
                            "value": "1.0.0"
                        },
                        {
                            // WEBSITE_NODE_DEFAULT_VERSION: versao padrao do Node.js
                            "name": "WEBSITE_NODE_DEFAULT_VERSION",
                            "value": "~18"
                        }
                    ]
                }
            }
        },

        // --------------------------------------------------------
        // 3. Deployment Slot (staging)
        // --------------------------------------------------------
        {
            // Tipo: recurso FILHO do site
            "type": "Microsoft.Web/sites/slots",
            "apiVersion": "2023-01-01",
            // Nome composto: webAppName/slotName
            "name": "[concat(parameters('webAppName'), '/staging')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Web/sites', parameters('webAppName'))]"
            ],
            "properties": {
                "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                "siteConfig": {
                    "linuxFxVersion": "NODE|18-lts",
                    "appSettings": [
                        {
                            "name": "ENVIRONMENT",
                            // slotSetting: se true, o valor NAO acompanha o swap
                            // Como nao ha como marcar slotSetting no appSettings inline,
                            // isso requer um recurso separado (config/appsettings) ou CLI
                            "value": "staging"
                        },
                        {
                            "name": "APP_VERSION",
                            "value": "2.0.0-beta"
                        }
                    ]
                }
            }
        }
    ],
    "outputs": {
        "webAppUrl": {
            "type": "string",
            "value": "[concat('https://', reference(resourceId('Microsoft.Web/sites', parameters('webAppName'))).defaultHostName)]"
        },
        "stagingUrl": {
            "type": "string",
            "value": "[concat('https://', parameters('webAppName'), '-staging.azurewebsites.net')]"
        },
        "appServicePlanId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]"
        }
    }
}
```

> **Conceito AZ-104 — Deployment Slots:**
> - Slots permitem deploy **zero-downtime** via swap
> - Cada slot tem URL propria: `webappname-slotname.azurewebsites.net`
> - **Swap**: troca o slot de staging para production instantaneamente
> - **Slot settings**: configuracoes que NAO acompanham o swap (ex: connection strings de staging)
> - Requer **Standard (S1)** ou superior — Free e Basic NAO suportam slots

Deploy:

```bash
az deployment group create \
    --resource-group "$RG8" \
    --template-file bloco3-webapp.json \
    --parameters webAppName="$WEB_APP_NAME"

echo "=== Web App ==="
az webapp show -g "$RG8" -n "$WEB_APP_NAME" \
    --query "{name:name, state:state, url:defaultHostName}" -o table

echo ""
echo "=== Slots ==="
az webapp deployment slot list -g "$RG8" -n "$WEB_APP_NAME" \
    --query "[].{name:name, state:state}" -o table
```

---

### Task 3.3: Autoscale para App Service Plan via ARM

Salve como **`bloco3-autoscale.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "appServicePlanName": {
            "type": "string",
            "defaultValue": "az104-asp"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        {
            "type": "Microsoft.Insights/autoscaleSettings",
            "apiVersion": "2022-10-01",
            "name": "[concat(parameters('appServicePlanName'), '-autoscale')]",
            "location": "[parameters('location')]",
            "properties": {
                "enabled": true,
                "targetResourceUri": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                "profiles": [
                    {
                        "name": "defaultProfile",
                        "capacity": {
                            "minimum": "1",
                            "maximum": "3",
                            "default": "1"
                        },
                        "rules": [
                            // Scale OUT quando CPU > 70%
                            {
                                "metricTrigger": {
                                    "metricName": "CpuPercentage",
                                    "metricResourceUri": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                                    "operator": "GreaterThan",
                                    "threshold": 70,
                                    "timeAggregation": "Average",
                                    "timeGrain": "PT1M",
                                    "timeWindow": "PT5M",
                                    "statistic": "Average"
                                },
                                "scaleAction": {
                                    "direction": "Increase",
                                    "type": "ChangeCount",
                                    "value": "1",
                                    "cooldown": "PT5M"
                                }
                            },
                            // Scale IN quando CPU < 30%
                            {
                                "metricTrigger": {
                                    "metricName": "CpuPercentage",
                                    "metricResourceUri": "[resourceId('Microsoft.Web/serverfarms', parameters('appServicePlanName'))]",
                                    "operator": "LessThan",
                                    "threshold": 30,
                                    "timeAggregation": "Average",
                                    "timeGrain": "PT1M",
                                    "timeWindow": "PT5M",
                                    "statistic": "Average"
                                },
                                "scaleAction": {
                                    "direction": "Decrease",
                                    "type": "ChangeCount",
                                    "value": "1",
                                    "cooldown": "PT5M"
                                }
                            }
                        ]
                    }
                ]
            }
        }
    ]
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG8" \
    --template-file bloco3-autoscale.json

# Testar swap de slot
az webapp deployment slot swap \
    --resource-group "$RG8" \
    --name "$WEB_APP_NAME" \
    --slot "staging" \
    --target-slot "production"

echo "Swap executado! Staging agora e production."
```

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-webapp.json` (ASP + Web App + Staging Slot)
- [ ] Deploy `bloco3-autoscale.json` (Autoscale no ASP)
- [ ] Verificar URL do Web App e do Staging Slot
- [ ] Executar swap staging → production
- [ ] Verificar que APP_VERSION mudou no production

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Web App no Free tier. Tentativa de criar deployment slot. O que acontece?**

A) Slot criado  B) Falha — requer Standard+  C) Slot criado sem URL  D) Upgrade automatico

<details><summary>Ver resposta</summary>**Resposta: B) Falha** — Deployment slots requerem Standard (S1) ou superior.</details>

### Questao 3.2
**Swap de slot: app setting marcada como "slot setting". O que acontece com ela no swap?**

A) Acompanha o swap  B) Permanece no slot original  C) Deletada  D) Duplicada

<details><summary>Ver resposta</summary>**Resposta: B) Permanece no slot original** — slot settings sao "sticky" ao slot, nao ao app.</details>

### Questao 3.3
**App Service Plan com `reserved: true`. O que isso significa?**

A) Reserva capacidade  B) Linux  C) Windows  D) Premium tier

<details><summary>Ver resposta</summary>**Resposta: B) Linux** — `reserved: true` indica Linux. Windows seria `reserved: false` (ou omitido).</details>

### Questao 3.4
**AlwaysOn: true. Qual o efeito?**

A) App nunca dorme  B) App escala automaticamente  C) App reinicia a cada hora  D) Apenas para Premium

<details><summary>Ver resposta</summary>**Resposta: A) App nunca dorme** — sem AlwaysOn, app idle por 20 min e descarregado da memoria. AlwaysOn envia pings periodicos. Requer Basic+ tier.</details>

---

# Bloco 4 - Azure Container Instances (ACI)

**Tecnologia:** ARM Template JSON
**Recursos criados:** Container Group com nginx, volumes, environment variables

---

### Task 4.1: Criar Resource Group

```bash
az group create --name "$RG9" --location "$LOCATION"
```

---

### Task 4.2: Container Group via ARM

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running.

Salve como **`bloco4-aci.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "containerGroupName": {
            "type": "string",
            "defaultValue": "az104-aci-nginx",
            "metadata": {
                "description": "Nome do container group"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "storageAccountName": {
            "type": "string",
            "metadata": {
                "description": "Storage Account para volume Azure Files"
            }
        },
        "storageAccountKey": {
            "type": "securestring",
            "metadata": {
                "description": "Chave da Storage Account"
            }
        },
        "fileShareName": {
            "type": "string",
            "defaultValue": "contoso-files",
            "metadata": {
                "description": "Nome do Azure File Share existente"
            }
        }
    },
    "resources": [
        {
            // Container Group: unidade de deploy do ACI
            // Todos os containers no grupo compartilham:
            //   - Network (mesmo IP)
            //   - Lifecycle (criados/destruidos juntos)
            //   - Volumes
            "type": "Microsoft.ContainerInstance/containerGroups",
            "apiVersion": "2023-05-01",
            "name": "[parameters('containerGroupName')]",
            "location": "[parameters('location')]",
            "properties": {
                // osType: Linux ou Windows
                "osType": "Linux",
                // restartPolicy: Always, OnFailure, Never
                "restartPolicy": "OnFailure",
                // containers: lista de containers no grupo
                "containers": [
                    {
                        "name": "nginx",
                        "properties": {
                            // image: imagem Docker (Docker Hub por padrao)
                            "image": "nginx:latest",
                            // resources: CPU e memoria alocados
                            "resources": {
                                "requests": {
                                    // cpu: numero de cores (pode ser fracao: 0.5)
                                    "cpu": 1,
                                    // memoryInGB: RAM em GB
                                    "memoryInGB": 1.5
                                }
                            },
                            // ports: portas expostas pelo container
                            "ports": [
                                {
                                    "port": 80,
                                    "protocol": "TCP"
                                }
                            ],
                            // environmentVariables: variaveis de ambiente
                            "environmentVariables": [
                                {
                                    "name": "ENVIRONMENT",
                                    "value": "lab"
                                },
                                {
                                    // secureValue: nao aparece em logs/API
                                    // (similar a securestring em parametros)
                                    "name": "SECRET_KEY",
                                    "secureValue": "my-secret-value-2024"
                                }
                            ],
                            // volumeMounts: montar volumes no container
                            "volumeMounts": [
                                {
                                    "name": "azurefile",
                                    "mountPath": "/mnt/azure",
                                    "readOnly": false
                                }
                            ]
                        }
                    }
                ],
                // ipAddress: configuracao de rede externa
                "ipAddress": {
                    // type: Public = IP publico, Private = VNet integration
                    "type": "Public",
                    "ports": [
                        {
                            "port": 80,
                            "protocol": "TCP"
                        }
                    ],
                    // dnsNameLabel: cria FQDN: <label>.<region>.azurecontainer.io
                    "dnsNameLabel": "[parameters('containerGroupName')]"
                },
                // volumes: definicao dos volumes disponiveis
                "volumes": [
                    {
                        "name": "azurefile",
                        // azureFile: monta Azure File Share como volume
                        "azureFile": {
                            "shareName": "[parameters('fileShareName')]",
                            "storageAccountName": "[parameters('storageAccountName')]",
                            "storageAccountKey": "[parameters('storageAccountKey')]"
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "containerIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups', parameters('containerGroupName'))).ipAddress.ip]"
        },
        "containerFqdn": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups', parameters('containerGroupName'))).ipAddress.fqdn]"
        }
    }
}
```

> **Conceito AZ-104 — ACI:**
> - ACI e **serverless containers** — sem gerenciar VMs ou clusters
> - Container Group ≈ Pod do Kubernetes (containers compartilham rede/storage)
> - Ideal para: tarefas batch, CI/CD runners, testes, workloads simples
> - NAO ideal para: apps complexas com service mesh, auto-scaling sofisticado
> - Volumes suportados: Azure Files, emptyDir, gitRepo, secret

Deploy:

```bash
# Obter chave da storage account
STORAGE_KEY=$(az storage account keys list -g "$RG6" -n "$STORAGE_ACCOUNT_NAME" \
    --query "[0].value" -o tsv)

az deployment group create \
    --resource-group "$RG9" \
    --template-file bloco4-aci.json \
    --parameters \
        storageAccountName="$STORAGE_ACCOUNT_NAME" \
        storageAccountKey="$STORAGE_KEY"

echo "=== Container Group ==="
az container show -g "$RG9" -n "az104-aci-nginx" \
    --query "{name:name, state:instanceView.state, ip:ipAddress.ip, fqdn:ipAddress.fqdn}" -o table

echo ""
echo "=== Testar acesso ==="
FQDN=$(az container show -g "$RG9" -n "az104-aci-nginx" --query "ipAddress.fqdn" -o tsv)
curl -s "http://$FQDN" | head -5

echo ""
echo "=== Logs ==="
az container logs -g "$RG9" -n "az104-aci-nginx"
```

---

## Modo Desafio - Bloco 4

- [ ] Deploy `bloco4-aci.json` (Container Group + Volume + Env Vars)
- [ ] Verificar FQDN e testar acesso HTTP
- [ ] Verificar logs do container
- [ ] Verificar volume montado: `az container exec -g $RG9 -n az104-aci-nginx --exec-command "ls /mnt/azure"`

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Container Group com 2 containers. Eles compartilham o que?**

A) Nada  B) Network + storage + lifecycle  C) Apenas network  D) Apenas storage

<details><summary>Ver resposta</summary>**Resposta: B)** Containers no mesmo grupo compartilham IP, volumes e lifecycle (criados/destruidos juntos).</details>

### Questao 4.2
**ACI com restartPolicy: Never. Container falha. O que acontece?**

A) Reinicia  B) Permanece em estado Failed  C) Novo container criado  D) Escala automaticamente

<details><summary>Ver resposta</summary>**Resposta: B) Permanece em estado Failed** — Never = nao reinicia. OnFailure reiniciaria. Always reinicia sempre.</details>

### Questao 4.3
**Qual tipo de volume persiste dados apos container ser destruido?**

A) emptyDir  B) Azure Files  C) gitRepo  D) secret

<details><summary>Ver resposta</summary>**Resposta: B) Azure Files** — emptyDir e temporario (lifecycle do container). Azure Files persiste independentemente.</details>

---

# Bloco 5 - Container Apps

**Tecnologia:** ARM Templates JSON
**Recursos criados:** Container Apps Environment, Container App, Scaling Rules, Ingress, Traffic Splitting

---

### Task 5.1: Criar Resource Group

```bash
az group create --name "$RG10" --location "$LOCATION"
```

---

### Task 5.2: Container Apps Environment via ARM

Salve como **`bloco5-container-env.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "environmentName": {
            "type": "string",
            "defaultValue": "az104-cae",
            "metadata": {
                "description": "Nome do Container Apps Environment"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "variables": {
        // Log Analytics Workspace: obrigatorio para Container Apps Environment
        "logAnalyticsName": "[concat(parameters('environmentName'), '-logs')]"
    },
    "resources": [
        // --------------------------------------------------------
        // 1. Log Analytics Workspace (obrigatorio para CAE)
        // --------------------------------------------------------
        {
            "type": "Microsoft.OperationalInsights/workspaces",
            "apiVersion": "2022-10-01",
            "name": "[variables('logAnalyticsName')]",
            "location": "[parameters('location')]",
            "properties": {
                "sku": {
                    "name": "PerGB2018"
                },
                "retentionInDays": 30
            }
        },

        // --------------------------------------------------------
        // 2. Container Apps Environment
        //    = infraestrutura compartilhada (VNet, logging, etc.)
        //    Similar a um "namespace" do Kubernetes
        // --------------------------------------------------------
        {
            "type": "Microsoft.App/managedEnvironments",
            "apiVersion": "2023-05-01",
            "name": "[parameters('environmentName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.OperationalInsights/workspaces', variables('logAnalyticsName'))]"
            ],
            "properties": {
                "appLogsConfiguration": {
                    "destination": "log-analytics",
                    "logAnalyticsConfiguration": {
                        "customerId": "[reference(resourceId('Microsoft.OperationalInsights/workspaces', variables('logAnalyticsName'))).customerId]",
                        "sharedKey": "[listKeys(resourceId('Microsoft.OperationalInsights/workspaces', variables('logAnalyticsName')), '2022-10-01').primarySharedKey]"
                    }
                }
            }
        }
    ],
    "outputs": {
        "environmentId": {
            "type": "string",
            "value": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `[listKeys(resourceId(...), '2022-10-01').primarySharedKey]` — funcao listKeys verbosa
> - Bicep: `logAnalytics.listKeys().primarySharedKey` — chamada direta
> - ARM: `[reference(resourceId(...))]` para obter customerId
> - Bicep: `logAnalytics.properties.customerId` — acesso direto a propriedade

Deploy:

```bash
az deployment group create \
    --resource-group "$RG10" \
    --template-file bloco5-container-env.json

echo "=== Container Apps Environment ==="
az containerapp env show -g "$RG10" -n "az104-cae" \
    --query "{name:name, provisioningState:provisioningState}" -o table
```

---

### Task 5.3: Container App com Scaling e Ingress via ARM

Salve como **`bloco5-container-app.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "containerAppName": {
            "type": "string",
            "defaultValue": "az104-app",
            "metadata": {
                "description": "Nome do Container App"
            }
        },
        "environmentName": {
            "type": "string",
            "defaultValue": "az104-cae"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        {
            "type": "Microsoft.App/containerApps",
            "apiVersion": "2023-05-01",
            "name": "[parameters('containerAppName')]",
            "location": "[parameters('location')]",
            "properties": {
                // managedEnvironmentId: vincula ao Container Apps Environment
                "managedEnvironmentId": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]",
                "configuration": {
                    // activeRevisionsMode: Single ou Multiple
                    // Multiple: permite traffic splitting entre revisoes
                    "activeRevisionsMode": "Multiple",
                    // ingress: configuracao de entrada (como o trafego chega ao app)
                    "ingress": {
                        // external: true = acessivel via internet
                        // false = apenas dentro do environment
                        "external": true,
                        "targetPort": 80,
                        "transport": "http",
                        // traffic: distribuicao de trafego entre revisoes
                        "traffic": [
                            {
                                // latestRevision: true = sempre aponta para ultima revisao
                                "latestRevision": true,
                                "weight": 100
                            }
                        ]
                    }
                },
                "template": {
                    // containers: definicao dos containers
                    "containers": [
                        {
                            "name": "nginx",
                            "image": "nginx:latest",
                            "resources": {
                                "cpu": 0.5,
                                "memory": "1Gi"
                            },
                            "env": [
                                {
                                    "name": "ENVIRONMENT",
                                    "value": "production"
                                }
                            ]
                        }
                    ],
                    // scale: regras de autoscaling
                    "scale": {
                        // minReplicas: 0 = scale to zero (economia de custo!)
                        "minReplicas": 0,
                        "maxReplicas": 5,
                        "rules": [
                            {
                                // HTTP scaling: baseado em requisicoes concorrentes
                                "name": "http-scaling",
                                "http": {
                                    "metadata": {
                                        // concurrentRequests: escala quando > 10 req/replica
                                        "concurrentRequests": "10"
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        }
    ],
    "outputs": {
        "appUrl": {
            "type": "string",
            "value": "[concat('https://', reference(resourceId('Microsoft.App/containerApps', parameters('containerAppName'))).configuration.ingress.fqdn)]"
        },
        "latestRevisionName": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.App/containerApps', parameters('containerAppName'))).latestRevisionName]"
        }
    }
}
```

> **Conceito AZ-104 — Container Apps:**
> - Container Apps = **serverless containers com Kubernetes features**
> - Diferenca do ACI: suporta autoscaling (incluindo scale-to-zero), revisoes, traffic splitting
> - **Revisao**: snapshot imutavel do app (similar a deployment no K8s)
> - **activeRevisionsMode: Multiple**: permite canary/blue-green deployments
> - **Scale rules**: HTTP (requisicoes), Azure Queue, Custom (KEDA)
> - **minReplicas: 0**: app "dorme" quando sem trafego (gratis quando idle!)

Deploy:

```bash
az deployment group create \
    --resource-group "$RG10" \
    --template-file bloco5-container-app.json

echo "=== Container App ==="
az containerapp show -g "$RG10" -n "az104-app" \
    --query "{name:name, fqdn:properties.configuration.ingress.fqdn, latestRevision:properties.latestRevisionName}" -o table

echo ""
echo "=== Testar acesso ==="
APP_URL=$(az containerapp show -g "$RG10" -n "az104-app" --query "properties.configuration.ingress.fqdn" -o tsv)
curl -s "https://$APP_URL" | head -5
```

---

### Task 5.4: Traffic Splitting (Canary Deployment) via ARM

Salve como **`bloco5-traffic-split.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "containerAppName": {
            "type": "string",
            "defaultValue": "az104-app"
        },
        "environmentName": {
            "type": "string",
            "defaultValue": "az104-cae"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },
    "resources": [
        {
            "type": "Microsoft.App/containerApps",
            "apiVersion": "2023-05-01",
            "name": "[parameters('containerAppName')]",
            "location": "[parameters('location')]",
            "properties": {
                "managedEnvironmentId": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]",
                "configuration": {
                    "activeRevisionsMode": "Multiple",
                    "ingress": {
                        "external": true,
                        "targetPort": 80,
                        "transport": "http",
                        // Traffic splitting: 80% para revisao atual, 20% para nova
                        // Canary deployment: testa nova versao com % pequeno de trafego
                        "traffic": [
                            {
                                "latestRevision": true,
                                "weight": 80
                            },
                            {
                                // revisionName: nome exato da revisao anterior
                                // Substituir pelo nome real apos primeiro deploy
                                "revisionName": "az104-app--REVISION_ANTERIOR",
                                "weight": 20
                            }
                        ]
                    }
                },
                "template": {
                    "containers": [
                        {
                            "name": "nginx",
                            // Nova imagem: httpd como "v2" para demonstrar canary
                            "image": "httpd:latest",
                            "resources": {
                                "cpu": 0.5,
                                "memory": "1Gi"
                            },
                            "env": [
                                {
                                    "name": "ENVIRONMENT",
                                    "value": "canary"
                                }
                            ]
                        }
                    ],
                    "scale": {
                        "minReplicas": 0,
                        "maxReplicas": 5,
                        "rules": [
                            {
                                "name": "http-scaling",
                                "http": {
                                    "metadata": {
                                        "concurrentRequests": "10"
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        }
    ]
}
```

> **Conceito AZ-104 — Traffic Splitting:**
> - **Blue/Green**: 100% para v1 OU 100% para v2 (swap instantaneo)
> - **Canary**: X% para v1, (100-X)% para v2 (teste gradual)
> - Container Apps usa `traffic` array para definir pesos
> - `latestRevision: true` sempre aponta para a revisao mais recente
> - Cada deploy cria uma NOVA revisao (imutavel)

Deploy:

```bash
# Primeiro, obter nome da revisao atual
CURRENT_REVISION=$(az containerapp show -g "$RG10" -n "az104-app" \
    --query "properties.latestRevisionName" -o tsv)
echo "Revisao atual: $CURRENT_REVISION"

# Atualizar o template com o nome da revisao real
sed "s/az104-app--REVISION_ANTERIOR/$CURRENT_REVISION/" bloco5-traffic-split.json > bloco5-traffic-split-updated.json

az deployment group create \
    --resource-group "$RG10" \
    --template-file bloco5-traffic-split-updated.json

echo "=== Revisoes ==="
az containerapp revision list -g "$RG10" -n "az104-app" \
    --query "[].{name:name, active:properties.active, trafficWeight:properties.trafficWeight}" -o table
```

---

## Modo Desafio - Bloco 5

- [ ] Deploy `bloco5-container-env.json` (Environment + Log Analytics)
- [ ] Deploy `bloco5-container-app.json` (Container App + Scaling + Ingress)
- [ ] Verificar FQDN e testar acesso HTTPS
- [ ] Deploy `bloco5-traffic-split.json` (Canary: 80/20)
- [ ] Verificar revisoes e pesos de trafego

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Container App com minReplicas: 0. Sem trafego por 5 minutos. O que acontece?**

A) App permanece rodando  B) Escala para zero (sem custo de compute)  C) App e deletado  D) Erro

<details><summary>Ver resposta</summary>**Resposta: B) Escala para zero** — Container Apps suporta scale-to-zero. Primeira requisicao tera cold start.</details>

### Questao 5.2
**activeRevisionsMode: Single. Deploy de nova imagem. O que acontece com revisao anterior?**

A) Permanece ativa  B) Desativada automaticamente  C) Deletada  D) Recebe 50% do trafego

<details><summary>Ver resposta</summary>**Resposta: B) Desativada automaticamente** — Single mode mantem apenas a revisao mais recente ativa.</details>

### Questao 5.3
**Container Apps vs ACI: qual suporta scale-to-zero?**

A) Apenas ACI  B) Apenas Container Apps  C) Ambos  D) Nenhum

<details><summary>Ver resposta</summary>**Resposta: B) Apenas Container Apps** — ACI sempre tem pelo menos 1 instancia ativa enquanto o container group existir.</details>

### Questao 5.4
**Traffic splitting: 80% v1, 20% v2. Apos testes, como promover v2 para 100%?**

A) Deletar v1  B) Alterar weights para 0/100  C) Criar nova revisao  D) Swap como App Service

<details><summary>Ver resposta</summary>**Resposta: B) Alterar weights** — mude traffic para latestRevision: true com weight: 100.</details>

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
# CLEANUP - Remover TODOS os recursos da Semana 2
# ============================================================

echo "1. Deletando Container Apps (RG10)..."
az group delete --name "$RG10" --yes --no-wait

echo "2. Deletando ACI (RG9)..."
az group delete --name "$RG9" --yes --no-wait

echo "3. Deletando Web Apps (RG8)..."
az group delete --name "$RG8" --yes --no-wait

echo "4. Deletando VMs e VMSS (RG7)..."
az group delete --name "$RG7" --yes --no-wait

echo "5. Deletando Storage (RG6)..."
az group delete --name "$RG6" --yes --no-wait

echo ""
echo "=== CLEANUP COMPLETO ==="
echo "Todos os RGs (rg6-rg10) sendo deletados em background."
echo "Use 'az group list --query \"[?starts_with(name, 'az104-rg')]\" -o table' para verificar."
```

---

# Key Takeaways Consolidados

## ARM JSON: Padroes Recorrentes Neste Lab

| Padrao | Exemplo | Quando Usar |
|--------|---------|-------------|
| Recurso filho (nome composto) | `"name": "storageAccount/default/container"` | Blob, File Share, Slot, Extension |
| `dependsOn` explicito | `"dependsOn": ["[resourceId(...)]"]` | Sempre que recurso B precisa de A |
| `securestring` | `"type": "securestring"` | Senhas, chaves, secrets |
| Cross-resource reference | `[reference(resourceId(...))]` | Obter IP, FQDN, keys de outro recurso |
| `listKeys()` | `[listKeys(resourceId(...), 'api').key]` | Obter chaves de Storage, Log Analytics |
| `concat()` | `[concat(params('a'), '/default/', params('b'))]` | Nomes compostos de recursos filhos |

## ARM vs Bicep: Comparacao Direta (Semana 2)

### Recurso Filho
```json
// ARM: nome composto + dependsOn
"name": "[concat(parameters('storageAccountName'), '/default/', parameters('containerName'))]",
"dependsOn": ["[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"]
```
```bicep
// Bicep: parent + nome simples
parent: storageAccount
name: containerName
```

### Secrets
```json
// ARM: tipo especial no parametro
"adminPassword": {
    "type": "securestring"
}
```
```bicep
// Bicep: decorator
@secure()
param adminPassword string
```

### listKeys
```json
// ARM: funcao verbosa
"[listKeys(resourceId('Microsoft.OperationalInsights/workspaces', variables('logAnalyticsName')), '2022-10-01').primarySharedKey]"
```
```bicep
// Bicep: chamada direta
logAnalytics.listKeys().primarySharedKey
```

## Templates Criados

| Template | Scope | Recursos | Linhas |
|----------|-------|----------|--------|
| `bloco1-storage.json` | resourceGroup | Storage Account + Container + File Share | ~120 |
| `bloco1-lifecycle.json` | resourceGroup | Lifecycle Management Policy | ~55 |
| `bloco1-network-rules.json` | resourceGroup | VNet + Service Endpoint + Firewall | ~75 |
| `bloco1-private-endpoint.json` | resourceGroup | PE + DNS Zone + Link + DNS Group | ~100 |
| `bloco2-vnet.json` | resourceGroup | VNet com 2 subnets | ~25 |
| `bloco2-vm-windows.json` | resourceGroup | Windows VM + PIP + NIC | ~110 |
| `bloco2-vm-linux.json` | resourceGroup | Linux VM + PIP + NIC | ~85 |
| `bloco2-datadisk.json` | resourceGroup | Managed Disk | ~30 |
| `bloco2-vmss.json` | resourceGroup | VMSS + LB + Autoscale | ~180 |
| `bloco2-extension.json` | resourceGroup | Custom Script Extension | ~25 |
| `bloco3-webapp.json` | resourceGroup | ASP + Web App + Staging Slot | ~95 |
| `bloco3-autoscale.json` | resourceGroup | Autoscale Settings | ~60 |
| `bloco4-aci.json` | resourceGroup | Container Group + Volume + Env | ~80 |
| `bloco5-container-env.json` | resourceGroup | CAE + Log Analytics | ~45 |
| `bloco5-container-app.json` | resourceGroup | Container App + Scale + Ingress | ~70 |
| `bloco5-traffic-split.json` | resourceGroup | Traffic Splitting (Canary) | ~65 |

## Funcoes ARM Mais Usadas no Lab

| Funcao | Exemplo | Equivalente Bicep |
|--------|---------|-------------------|
| `[parameters('x')]` | `[parameters('storageAccountName')]` | `storageAccountName` (direto) |
| `[variables('x')]` | `[variables('nicName')]` | `nicName` (direto) |
| `[resourceId(...)]` | `[resourceId('type', 'name')]` | `resource.id` |
| `[concat(...)]` | `[concat('sa', '/default/', 'container')]` | `'sa/default/${container}'` |
| `[reference(...)]` | `[reference(resourceId(...)).prop]` | `resource.properties.prop` |
| `[listKeys(...)]` | `[listKeys(resourceId(...), 'api').key]` | `resource.listKeys().key` |
| `[uniqueString(...)]` | `[uniqueString(resourceGroup().id)]` | `uniqueString(resourceGroup().id)` |

## Schemas por Scope (Revisao)

| Scope | Schema URL | Comando deploy |
|-------|-----------|----------------|
| Resource Group | `schemas/2019-04-01/deploymentTemplate.json#` | `az deployment group create` |
| Subscription | `schemas/2018-05-01/subscriptionDeploymentTemplate.json#` | `az deployment sub create` |
| Management Group | `schemas/2019-08-01/managementGroupDeploymentTemplate.json#` | `az deployment mg create` |
| Tenant | `schemas/2019-08-01/tenantDeploymentTemplate.json#` | `az deployment tenant create` |
