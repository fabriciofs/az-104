# Lab AZ-104 - Semana 3: Tudo via ARM Templates (JSON)

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI ja vem pre-instalado
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.json`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab de Backup & Monitoring usando ARM Templates JSON + CLI.
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
            "type": "Microsoft.RecoveryServices/vaults",
            "apiVersion": "2023-06-01",
            "name": "myVault",
            "location": "[parameters('location')]",
            "dependsOn": [],  // EXPLICITO! (diferente do Bicep que e implicito)
            "properties": { }
        }
    ],

    // 6. Outputs: valores exportados apos deploy
    "outputs": {
        "vaultId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults', 'myVault')]"
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
| `[variables('x')]` | Ler variavel | `[variables('vaultName')]` |
| `[resourceId(...)]` | ID de recurso | `[resourceId('Microsoft.RecoveryServices/vaults', 'myVault')]` |
| `[concat(...)]` | Concatenar strings | `[concat('prefix-', parameters('name'))]` |
| `[resourceGroup().location]` | Regiao do RG | Usado como default em location |
| `[subscription().subscriptionId]` | ID da subscription | Usado em scopes |
| `[guid(...)]` | GUID deterministico | `[guid(resourceGroup().id, 'name')]` |

---

## Verificacao e Variaveis

```bash
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# Azure CLI ja instalado e autenticado no Cloud Shell
az version
az account show --query "{name:name, id:id}" -o table

# Instalar extensao para Data Collection Rules (Bloco 5)
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

# Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"

# ============================================================
# VARIAVEIS GLOBAIS
# ============================================================
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" # ← ALTERE
LOCATION="eastus"
LOCATION_DR="westus"

RG11="az104-rg11"
VAULT_NAME="az104-rsv"
RG12="az104-rg12"
RG13="az104-rg13"
WORKSPACE_NAME="az104-law"

VM_USERNAME="localadmin"
VM_PASSWORD='SenhaComplexa@2024!'                      # ← ALTERE
```

---

## Mapa de Dependencias

```
Bloco 1 (VM Backup)         → ARM templates + CLI
  │
  ▼
Bloco 2 (File/Blob)         → ARM templates + CLI
  │
  ▼
Bloco 3 (Site Recovery)     → ARM templates + CLI
  │
  ▼
Bloco 4 (Azure Monitor)     → ARM templates
  │
  ▼
Bloco 5 (Log Analytics)     → ARM templates + CLI
```

---

# Bloco 1 - VM Backup

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** Recovery Services Vault, Backup Policy, Protection Intent (VM Backup)

---

### Task 1.1: Criar Resource Groups

```bash
# ============================================================
# TASK 1.1 - Criar Resource Groups para o lab
# ============================================================
az group create --name "$RG11" --location "$LOCATION"
az group create --name "$RG12" --location "$LOCATION"
az group create --name "$RG13" --location "$LOCATION"

echo "RGs criados: $RG11, $RG12, $RG13"
```

---

### Task 1.2: Criar VM para backup (ARM)

Salve como **`bloco1-vm.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS - Valores fornecidos no deploy
    // ============================================================
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Regiao onde a VM sera criada"
            }
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin",
            "metadata": {
                "description": "Nome do usuario administrador"
            }
        },
        "adminPassword": {
            "type": "securestring",
            "metadata": {
                "description": "Senha do admin (securestring = nao aparece em logs)"
            }
        }
    },

    // ============================================================
    // VARIABLES - Valores calculados internamente
    // ============================================================
    "variables": {
        "vmName": "az104-vm-backup",
        "nicName": "[concat(variables('vmName'), '-nic')]",
        "vnetName": "[concat(variables('vmName'), '-vnet')]",
        "subnetName": "default",
        "nsgName": "[concat(variables('vmName'), '-nsg')]",
        "pipName": "[concat(variables('vmName'), '-pip')]"
    },

    // ============================================================
    // RESOURCES - Recursos a criar
    // ============================================================
    "resources": [
        // --- NSG ---
        {
            "type": "Microsoft.Network/networkSecurityGroups",
            "apiVersion": "2023-05-01",
            "name": "[variables('nsgName')]",
            "location": "[parameters('location')]",
            "properties": {
                "securityRules": []
            }
        },

        // --- Public IP ---
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('pipName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "Standard"
            },
            "properties": {
                "publicIPAllocationMethod": "Static"
            }
        },

        // --- VNet + Subnet ---
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "[variables('vnetName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
            ],
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [ "10.0.0.0/16" ]
                },
                "subnets": [
                    {
                        "name": "[variables('subnetName')]",
                        "properties": {
                            "addressPrefix": "10.0.0.0/24",
                            "networkSecurityGroup": {
                                "id": "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
                            }
                        }
                    }
                ]
            }
        },

        // --- NIC ---
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "[variables('nicName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]",
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
            ],
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]"
                            },
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
                            }
                        }
                    }
                ]
            }
        },

        // --- VM ---
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2024-03-01",
            "name": "[variables('vmName')]",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
            ],
            "properties": {
                "hardwareProfile": {
                    "vmSize": "Standard_D2s_v3"
                },
                "osProfile": {
                    "computerName": "[variables('vmName')]",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2022-datacenter-azure-edition",
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
                    "networkInterfaces": [
                        {
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
                        }
                    ]
                },
                "diagnosticsProfile": {
                    "bootDiagnostics": {
                        "enabled": false
                    }
                }
            }
        }
    ],

    // ============================================================
    // OUTPUTS - Valores exportados apos deploy
    // ============================================================
    "outputs": {
        "vmId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/virtualMachines', variables('vmName'))]"
        },
        "vmName": {
            "type": "string",
            "value": "[variables('vmName')]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"dependsOn"` explicito em 4 lugares (NSG→VNet, VNet+PIP→NIC, NIC→VM)
> - Bicep: todas as dependencias sao **implicitas** via referencias simbolicas
> - ARM: `"type": "securestring"` no parametro
> - Bicep: `@secure() param adminPassword string` — decorator mais limpo

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco1-vm.json \
    --parameters adminPassword="$VM_PASSWORD"

# Verificar VM criada
az vm show -g "$RG11" -n "az104-vm-backup" \
    --query "{name:name, status:provisioningState, size:hardwareProfile.vmSize}" -o table
```

---

### Task 1.3: Recovery Services Vault via ARM

> **Cobranca:** O vault em si e gratuito, mas cada instancia protegida (VM, File Share) gera cobranca.

Salve como **`bloco1-rsv.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vaultName": {
            "type": "string",
            "defaultValue": "az104-rsv",
            "metadata": {
                "description": "Nome do Recovery Services Vault"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Regiao do vault"
            }
        },
        "skuName": {
            "type": "string",
            "defaultValue": "Standard",
            "allowedValues": [
                "Standard",
                "RS0"
            ],
            "metadata": {
                "description": "SKU do vault (Standard para producao)"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Recovery Services Vault
            // Recurso central para backup e site recovery
            // Armazena pontos de recuperacao, policies e configuracoes
            "type": "Microsoft.RecoveryServices/vaults",
            "apiVersion": "2023-06-01",
            "name": "[parameters('vaultName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "[parameters('skuName')]",
                "tier": "Standard"
            },
            "properties": {
                // publicNetworkAccess: permite acesso pela internet
                // Em producao, considere Private Endpoints
                "publicNetworkAccess": "Enabled"
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "vaultId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults', parameters('vaultName'))]"
        },
        "vaultName": {
            "type": "string",
            "value": "[parameters('vaultName')]"
        }
    }
}
```

> **Conceito AZ-104:**
> - **Recovery Services Vault** e o contêiner que armazena dados de backup e configuracoes de replicacao
> - Cada vault esta vinculado a uma regiao especifica
> - Um vault pode proteger VMs, SQL, File Shares, SAP HANA e mais
> - **SKU Standard** e o padrao para producao; RS0 e legacy

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco1-rsv.json

# Verificar vault criado
az backup vault show \
    --name "$VAULT_NAME" \
    -g "$RG11" \
    --query "{name:name, location:location, sku:sku.name}" -o table
```

---

### Task 1.4: Backup Policy via ARM

Salve como **`bloco1-backup-policy.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vaultName": {
            "type": "string",
            "defaultValue": "az104-rsv",
            "metadata": {
                "description": "Nome do Recovery Services Vault existente"
            }
        },
        "policyName": {
            "type": "string",
            "defaultValue": "az104-daily-policy",
            "metadata": {
                "description": "Nome da policy de backup"
            }
        },
        "scheduleTime": {
            "type": "string",
            "defaultValue": "2024-01-01T02:00:00Z",
            "metadata": {
                "description": "Horario do backup diario (UTC)"
            }
        },
        "dailyRetentionDays": {
            "type": "int",
            "defaultValue": 30,
            "minValue": 7,
            "maxValue": 9999,
            "metadata": {
                "description": "Dias de retencao do backup diario"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Backup Policy (child resource do vault)
            // Define QUANDO e COMO os backups acontecem
            // Tipo: Microsoft.RecoveryServices/vaults/backupPolicies
            // Nome: vaultName/policyName (formato parent/child)
            "type": "Microsoft.RecoveryServices/vaults/backupPolicies",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', parameters('policyName'))]",
            "properties": {
                // backupManagementType: tipo de workload
                //   - AzureIaasVM: VMs Azure
                //   - AzureStorage: File Shares
                //   - AzureWorkload: SQL/SAP HANA
                "backupManagementType": "AzureIaasVM",

                // instantRpRetentionRangeInDays: snapshots locais (1-5 dias)
                // Restauracao rapida direto do snapshot, sem rehydrate
                "instantRpRetentionRangeInDays": 2,

                // schedulePolicy: QUANDO fazer backup
                "schedulePolicy": {
                    "schedulePolicyType": "SimpleSchedulePolicy",
                    "scheduleRunFrequency": "Daily",
                    "scheduleRunTimes": [
                        "[parameters('scheduleTime')]"
                    ]
                },

                // retentionPolicy: POR QUANTO TEMPO manter
                "retentionPolicy": {
                    "retentionPolicyType": "LongTermRetentionPolicy",

                    // Retencao diaria
                    "dailySchedule": {
                        "retentionTimes": [
                            "[parameters('scheduleTime')]"
                        ],
                        "retentionDuration": {
                            "count": "[parameters('dailyRetentionDays')]",
                            "durationType": "Days"
                        }
                    },

                    // Retencao semanal (domingos, 4 semanas)
                    "weeklySchedule": {
                        "daysOfTheWeek": [ "Sunday" ],
                        "retentionTimes": [
                            "[parameters('scheduleTime')]"
                        ],
                        "retentionDuration": {
                            "count": 4,
                            "durationType": "Weeks"
                        }
                    }
                },

                // timeZone: fuso horario do schedule
                "timeZone": "UTC"
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "policyId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults/backupPolicies', parameters('vaultName'), parameters('policyName'))]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "[concat(parameters('vaultName'), '/', parameters('policyName'))]"` — nome composto
> - Bicep: `parent: vault` + `name: policyName` — mais claro com `parent`
> - ARM: `"[parameters('scheduleTime')]"` entre colchetes/aspas
> - Bicep: `scheduleTime` — referencia direta

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco1-backup-policy.json

# Verificar policy criada
az backup policy show \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --name "az104-daily-policy" \
    --query "{name:name, type:properties.backupManagementType}" -o table
```

---

### Task 1.5: Habilitar backup da VM (CLI)

> **Cobranca:** Habilitar backup gera cobranca por instancia protegida e armazenamento de snapshots.

> **POR QUE CLI E NAO ARM?** Habilitar protecao de backup (Protection Intent)
> e uma operacao que depende do estado atual da VM e do vault. Embora exista
> o recurso ARM `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems`,
> a abordagem via CLI e mais direta e confiavel para esta operacao.

```bash
# ============================================================
# TASK 1.5 - Habilitar backup da VM (CLI)
# ============================================================

# Habilitar backup usando a policy customizada
az backup protection enable-for-vm \
    --resource-group "$RG11" \
    --vault-name "$VAULT_NAME" \
    --vm "az104-vm-backup" \
    --policy-name "az104-daily-policy"

# Verificar item protegido
az backup item list \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --query "[].{name:name, policy:properties.policyId, status:properties.protectionStatus}" \
    -o table

echo "VM protegida com a policy az104-daily-policy"
```

---

### Task 1.6: Backup on-demand e restauracao (CLI)

> **POR QUE CLI?** Operacoes de backup on-demand e restore sao acoes
> **imperativas** (executar agora), nao declarativas. ARM Templates sao
> declarativos — descrevem o estado desejado, nao executam acoes pontuais.

```bash
# ============================================================
# TASK 1.6 - Backup on-demand (CLI)
# ============================================================

# Descobrir container e item names
CONTAINER=$(az backup container list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureIaasVM \
    --query "[0].name" -o tsv)

ITEM=$(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --query "[0].name" -o tsv)

# Executar backup on-demand (retencao de 30 dias)
az backup protection backup-now \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --retain-until $(date -u -d "+30 days" +%d-%m-%Y 2>/dev/null || date -u -v+30d +%d-%m-%Y)

echo "Backup on-demand iniciado. Aguarde ~15-30 min para completar."
echo "Verifique o status com:"
echo "  az backup job list --vault-name $VAULT_NAME -g $RG11 -o table"
```

```bash
# ============================================================
# Restaurar VM (exemplo — executar apos backup completar)
# ============================================================

# Listar pontos de recuperacao
az backup recoverypoint list \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --query "[].{name:name, time:properties.recoveryPointTime, type:properties.recoveryPointType}" \
    -o table

# Restore: criar novos discos a partir do recovery point
# (nao sobrescreve a VM original)
RECOVERY_POINT=$(az backup recoverypoint list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --query "[0].name" -o tsv)

az backup restore restore-disks \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --container-name "$CONTAINER" \
    --item-name "$ITEM" \
    --rp-name "$RECOVERY_POINT" \
    --storage-account "az104storerestore" \
    --target-resource-group "$RG11"

echo "Restore iniciado. Os discos serao criados no RG $RG11"
```

---

## Modo Desafio - Bloco 1

- [ ] Deploy `bloco1-vm.json` com VM para backup
- [ ] Deploy `bloco1-rsv.json` (Recovery Services Vault)
- [ ] Deploy `bloco1-backup-policy.json` (policy diaria + semanal)
- [ ] Habilitar backup via CLI (`az backup protection enable-for-vm`)
- [ ] Executar backup on-demand via CLI
- [ ] Listar recovery points

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Qual recurso ARM representa o cofre de backup?**

A) `Microsoft.Backup/vaults`
B) `Microsoft.RecoveryServices/vaults`
C) `Microsoft.Storage/backupVaults`
D) `Microsoft.Compute/backupContainers`

<details><summary>Ver resposta</summary>**Resposta: B) Microsoft.RecoveryServices/vaults**</details>

### Questao 1.2
**Quantos dias de snapshot local (instant restore) sao suportados?**

A) 1-3 dias  B) 1-5 dias  C) 7-30 dias  D) 1-7 dias

<details><summary>Ver resposta</summary>**Resposta: B) 1-5 dias** — configurado via `instantRpRetentionRangeInDays`.</details>

### Questao 1.3
**Backup on-demand pode ser feito via ARM Template?**

A) Sim, com recurso backupNow
B) Nao, e uma operacao imperativa (CLI/PowerShell/API)
C) Sim, com trigger resource
D) Apenas via portal

<details><summary>Ver resposta</summary>**Resposta: B)** — ARM e declarativo, backup on-demand e imperativo.</details>

### Questao 1.4
**Qual tipo de backupManagementType para VMs Azure?**

A) AzureVM  B) AzureIaasVM  C) AzureCompute  D) VirtualMachine

<details><summary>Ver resposta</summary>**Resposta: B) AzureIaasVM**</details>

---

# Bloco 2 - File Share & Blob Protection

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** Storage Account, File Share, Backup protegido, Soft Delete, Versioning

---

### Task 2.1: Storage Account com File Share (ARM)

Salve como **`bloco2-storage.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "storageAccountName": {
            "type": "string",
            "defaultValue": "az104storebkp",
            "minLength": 3,
            "maxLength": 24,
            "metadata": {
                "description": "Nome da storage account (lowercase, sem hifens)"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "fileShareName": {
            "type": "string",
            "defaultValue": "az104-share",
            "metadata": {
                "description": "Nome do file share"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Storage Account com soft delete habilitado
            // Soft delete protege contra exclusao acidental de blobs e shares
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2023-01-01",
            "name": "[parameters('storageAccountName')]",
            "location": "[parameters('location')]",
            "kind": "StorageV2",
            "sku": {
                "name": "Standard_LRS"
            },
            "properties": {
                "minimumTlsVersion": "TLS1_2",
                "supportsHttpsTrafficOnly": true,

                // Soft delete para blobs
                "deleteRetentionPolicy": {
                    "enabled": true,
                    "days": 7
                }
            }
        },

        {
            // Blob Services — configuracao de versionamento e soft delete
            "type": "Microsoft.Storage/storageAccounts/blobServices",
            "apiVersion": "2023-01-01",
            "name": "[concat(parameters('storageAccountName'), '/default')]",
            "dependsOn": [
                "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"
            ],
            "properties": {
                // Soft delete para blobs (7 dias)
                "deleteRetentionPolicy": {
                    "enabled": true,
                    "days": 7
                },
                // Soft delete para containers (7 dias)
                "containerDeleteRetentionPolicy": {
                    "enabled": true,
                    "days": 7
                },
                // Versionamento: mantem versoes anteriores dos blobs
                "isVersioningEnabled": true
            }
        },

        {
            // File Services — soft delete para file shares
            "type": "Microsoft.Storage/storageAccounts/fileServices",
            "apiVersion": "2023-01-01",
            "name": "[concat(parameters('storageAccountName'), '/default')]",
            "dependsOn": [
                "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"
            ],
            "properties": {
                "shareDeleteRetentionPolicy": {
                    "enabled": true,
                    "days": 7
                }
            }
        },

        {
            // File Share — recurso filho de fileServices
            "type": "Microsoft.Storage/storageAccounts/fileServices/shares",
            "apiVersion": "2023-01-01",
            "name": "[concat(parameters('storageAccountName'), '/default/', parameters('fileShareName'))]",
            "dependsOn": [
                "[resourceId('Microsoft.Storage/storageAccounts/fileServices', parameters('storageAccountName'), 'default')]"
            ],
            "properties": {
                "shareQuota": 5,
                "accessTier": "TransactionOptimized"
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "storageAccountId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"
        },
        "fileShareName": {
            "type": "string",
            "value": "[parameters('fileShareName')]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "[concat(parameters('storageAccountName'), '/default/', parameters('fileShareName'))]"` — 3 niveis
> - Bicep: `parent: fileServices` + `name: fileShareName` — aninhamento com parent
> - ARM: 4 niveis de `dependsOn` explicitos para a hierarquia SA → blobServices → fileServices → shares
> - Bicep: tudo implicito via `parent`

Deploy:

```bash
az deployment group create \
    --resource-group "$RG12" \
    --template-file bloco2-storage.json

# Verificar storage account
az storage account show \
    -n "az104storebkp" \
    -g "$RG12" \
    --query "{name:name, kind:kind, softDelete:properties}" -o json

# Verificar file share
az storage share-rm list \
    --storage-account "az104storebkp" \
    -g "$RG12" \
    --query "[].{name:name, quota:properties.shareQuota}" -o table
```

---

### Task 2.2: Backup Policy para File Share (ARM)

Salve como **`bloco2-fileshare-policy.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vaultName": {
            "type": "string",
            "defaultValue": "az104-rsv",
            "metadata": {
                "description": "Nome do Recovery Services Vault (deve existir)"
            }
        },
        "policyName": {
            "type": "string",
            "defaultValue": "az104-fileshare-policy",
            "metadata": {
                "description": "Nome da policy para file shares"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Backup Policy para Azure File Shares
            // backupManagementType: AzureStorage (diferente de VM que e AzureIaasVM)
            "type": "Microsoft.RecoveryServices/vaults/backupPolicies",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', parameters('policyName'))]",
            "properties": {
                "backupManagementType": "AzureStorage",
                "workLoadType": "AzureFileShare",

                "schedulePolicy": {
                    "schedulePolicyType": "SimpleSchedulePolicy",
                    "scheduleRunFrequency": "Daily",
                    "scheduleRunTimes": [
                        "2024-01-01T03:00:00Z"
                    ]
                },

                "retentionPolicy": {
                    "retentionPolicyType": "LongTermRetentionPolicy",
                    "dailySchedule": {
                        "retentionTimes": [
                            "2024-01-01T03:00:00Z"
                        ],
                        "retentionDuration": {
                            "count": 30,
                            "durationType": "Days"
                        }
                    }
                },

                "timeZone": "UTC"
            }
        }
    ]
}
```

Deploy:

```bash
# O vault precisa estar no mesmo RG — usamos o vault do RG11
# Entao deployamos a policy no RG11 (onde o vault esta)
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco2-fileshare-policy.json

# Verificar policy
az backup policy show \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --name "az104-fileshare-policy" -o table
```

---

### Task 2.3: Habilitar backup do File Share (CLI)

> **POR QUE CLI?** Registrar o storage account no vault e habilitar protecao
> sao operacoes que envolvem descoberta automatica de recursos.
> A CLI simplifica esse fluxo de registro + protecao.

```bash
# ============================================================
# TASK 2.3 - Proteger file share (CLI)
# ============================================================

# Registrar storage account no vault
az backup container register \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --resource-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG12}/providers/Microsoft.Storage/storageAccounts/az104storebkp" \
    --backup-management-type AzureStorage \
    --workload-type AzureFileShare

# Habilitar protecao do file share
az backup protection enable-for-azurefileshare \
    --vault-name "$VAULT_NAME" \
    -g "$RG11" \
    --storage-account "az104storebkp" \
    --azure-file-share "az104-share" \
    --policy-name "az104-fileshare-policy"

echo "File share protegido!"
```

---

### Task 2.4: Restaurar file share (CLI)

> **POR QUE CLI?** Restore e uma operacao **imperativa** — nao pode ser declarada via ARM.

```bash
# ============================================================
# TASK 2.4 - Restaurar file share (CLI — exemplo)
# ============================================================

# Listar containers registrados
az backup container list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureStorage \
    --query "[].{name:name, status:properties.registrationStatus}" -o table

# Listar recovery points
FS_CONTAINER=$(az backup container list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureStorage \
    --query "[0].name" -o tsv)

FS_ITEM=$(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureStorage \
    --query "[?properties.friendlyName=='az104-share'].name" -o tsv)

az backup recoverypoint list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --container-name "$FS_CONTAINER" \
    --item-name "$FS_ITEM" \
    --query "[].{name:name, time:properties.recoveryPointTime}" -o table
```

---

## Modo Desafio - Bloco 2

- [ ] Deploy `bloco2-storage.json` (SA + File Share + Soft Delete + Versioning)
- [ ] Deploy `bloco2-fileshare-policy.json` (policy para file shares)
- [ ] Registrar SA no vault e habilitar protecao (CLI)
- [ ] Verificar soft delete e versionamento habilitados

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Qual backupManagementType para Azure File Shares?**

A) AzureIaasVM  B) AzureStorage  C) AzureFileShare  D) AzureFiles

<details><summary>Ver resposta</summary>**Resposta: B) AzureStorage**</details>

### Questao 2.2
**Soft delete de blob esta habilitado com 7 dias. Blob excluido pode ser recuperado apos 8 dias?**

A) Sim  B) Nao, perda permanente apos 7 dias  C) Depende do versionamento  D) Apenas via support ticket

<details><summary>Ver resposta</summary>**Resposta: B)** — apos o periodo de retencao, a exclusao e permanente.</details>

### Questao 2.3
**Versionamento de blobs exige qual tipo de storage account?**

A) BlobStorage  B) StorageV2 ou BlobStorage  C) Premium_LRS apenas  D) Qualquer tipo

<details><summary>Ver resposta</summary>**Resposta: B) StorageV2 ou BlobStorage** — GPv2 (StorageV2) e o recomendado.</details>

---

# Bloco 3 - Azure Site Recovery (ASR)

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** ASR Fabric, Protection Container, Replication Policy, Replicated Item, Recovery Plan

---

### Task 3.1: ASR Fabric e Protection Container (ARM)

Salve como **`bloco3-asr-infra.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vaultName": {
            "type": "string",
            "defaultValue": "az104-rsv",
            "metadata": {
                "description": "Nome do Recovery Services Vault"
            }
        },
        "primaryLocation": {
            "type": "string",
            "defaultValue": "eastus",
            "metadata": {
                "description": "Regiao primaria (origem)"
            }
        },
        "recoveryLocation": {
            "type": "string",
            "defaultValue": "westus",
            "metadata": {
                "description": "Regiao de DR (destino)"
            }
        }
    },

    // ============================================================
    // VARIABLES
    // ============================================================
    "variables": {
        // Nomes dos fabrics seguem convencao: asr-a2a-default-<regiao>
        "primaryFabricName": "[concat('asr-a2a-default-', parameters('primaryLocation'))]",
        "recoveryFabricName": "[concat('asr-a2a-default-', parameters('recoveryLocation'))]",

        // Protection containers sao filhos dos fabrics
        "primaryContainerName": "[concat('asr-a2a-default-', parameters('primaryLocation'), '-container')]",
        "recoveryContainerName": "[concat('asr-a2a-default-', parameters('recoveryLocation'), '-container')]"
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // ASR Fabric primario (regiao de origem)
            // Fabric representa a infraestrutura de uma regiao no ASR
            "type": "Microsoft.RecoveryServices/vaults/replicationFabrics",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', variables('primaryFabricName'))]",
            "properties": {
                "customDetails": {
                    "instanceType": "Azure",
                    "location": "[parameters('primaryLocation')]"
                }
            }
        },

        {
            // ASR Fabric de recovery (regiao de destino/DR)
            "type": "Microsoft.RecoveryServices/vaults/replicationFabrics",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', variables('recoveryFabricName'))]",
            "properties": {
                "customDetails": {
                    "instanceType": "Azure",
                    "location": "[parameters('recoveryLocation')]"
                }
            }
        },

        {
            // Protection Container primario (filho do fabric primario)
            // Container agrupa os itens protegidos de uma regiao
            "type": "Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', variables('primaryFabricName'), '/', variables('primaryContainerName'))]",
            "dependsOn": [
                "[resourceId('Microsoft.RecoveryServices/vaults/replicationFabrics', parameters('vaultName'), variables('primaryFabricName'))]"
            ],
            "properties": {}
        },

        {
            // Protection Container de recovery (filho do fabric de DR)
            "type": "Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', variables('recoveryFabricName'), '/', variables('recoveryContainerName'))]",
            "dependsOn": [
                "[resourceId('Microsoft.RecoveryServices/vaults/replicationFabrics', parameters('vaultName'), variables('recoveryFabricName'))]"
            ],
            "properties": {}
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "primaryFabricId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults/replicationFabrics', parameters('vaultName'), variables('primaryFabricName'))]"
        },
        "recoveryFabricId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults/replicationFabrics', parameters('vaultName'), variables('recoveryFabricName'))]"
        }
    }
}
```

> **Conceito AZ-104 — Hierarquia ASR:**
> ```
> Recovery Services Vault
>   └── Replication Fabric (por regiao)
>         └── Protection Container (agrupa itens)
>               └── Protected Item (VM replicada)
> ```
> Cada regiao tem seu proprio fabric e container. A replicacao acontece
> do container primario para o container de recovery.

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco3-asr-infra.json

echo "ASR Fabrics e Containers criados para $LOCATION → $LOCATION_DR"
```

---

### Task 3.2: Replication Policy (ARM)

Salve como **`bloco3-asr-policy.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vaultName": {
            "type": "string",
            "defaultValue": "az104-rsv"
        },
        "policyName": {
            "type": "string",
            "defaultValue": "az104-asr-policy",
            "metadata": {
                "description": "Nome da replication policy"
            }
        },
        "recoveryPointRetentionInMinutes": {
            "type": "int",
            "defaultValue": 1440,
            "metadata": {
                "description": "Retencao de recovery points em minutos (1440 = 24h)"
            }
        },
        "appConsistentFrequencyInMinutes": {
            "type": "int",
            "defaultValue": 240,
            "metadata": {
                "description": "Frequencia de snapshots app-consistent (240 = 4h)"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Replication Policy define RPO e frequencia de snapshots
            // RPO (Recovery Point Objective): quanto de dados voce aceita perder
            // RTO (Recovery Time Objective): quanto tempo para restaurar
            "type": "Microsoft.RecoveryServices/vaults/replicationPolicies",
            "apiVersion": "2023-06-01",
            "name": "[concat(parameters('vaultName'), '/', parameters('policyName'))]",
            "properties": {
                "providerSpecificInput": {
                    "instanceType": "A2A",

                    // recoveryPointHistory: por quanto tempo manter recovery points
                    "recoveryPointHistory": "[parameters('recoveryPointRetentionInMinutes')]",

                    // appConsistentFrequencyInMinutes: snapshots app-consistent
                    // Crash-consistent: a cada 5 min (padrao, nao configuravel)
                    // App-consistent: configuravel (ex: 4h)
                    "appConsistentFrequencyInMinutes": "[parameters('appConsistentFrequencyInMinutes')]",

                    // multiVmSyncStatus: sincronizar recovery points entre VMs
                    "multiVmSyncStatus": "Enable"
                }
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "policyId": {
            "type": "string",
            "value": "[resourceId('Microsoft.RecoveryServices/vaults/replicationPolicies', parameters('vaultName'), parameters('policyName'))]"
        }
    }
}
```

> **Conceito AZ-104 — RPO vs RTO:**
> - **RPO** (Recovery Point Objective): maximo de dados que voce aceita perder
>   - Crash-consistent: ~5 min (dados em disco)
>   - App-consistent: configuravel (dados em memoria flushed)
> - **RTO** (Recovery Time Objective): tempo para failover completar
>   - ASR tipicamente: 15-30 min para failover

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco3-asr-policy.json

# Verificar policy
az rest --method GET \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationPolicies?api-version=2023-06-01" \
    --query "value[].{name:name, rpo:properties.providerSpecificDetails.recoveryPointHistory}" -o table
```

---

### Task 3.3: Container Mapping e Replicacao (CLI)

> **Cobranca:** A replicacao ASR gera cobranca continua por VM replicada. Nao pode ser pausada — so desabilitada.

> **POR QUE CLI?** O Container Mapping (associar container primario ao de recovery)
> e a habilitacao de replicacao de VMs envolvem operacoes complexas com
> multiplas dependencias. A CLI e mais prática neste caso.

```bash
# ============================================================
# TASK 3.3 - Container Mapping (associar source → target)
# ============================================================

PRIMARY_FABRIC="asr-a2a-default-${LOCATION}"
RECOVERY_FABRIC="asr-a2a-default-${LOCATION_DR}"
PRIMARY_CONTAINER="${PRIMARY_FABRIC}-container"
RECOVERY_CONTAINER="${RECOVERY_FABRIC}-container"

# Obter policy ID
POLICY_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationPolicies/az104-asr-policy"

# Criar container mapping (source → target)
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationFabrics/${PRIMARY_FABRIC}/replicationProtectionContainers/${PRIMARY_CONTAINER}/replicationProtectionContainerMappings/primary-to-recovery?api-version=2023-06-01" \
    --body "{
        \"properties\": {
            \"targetProtectionContainerId\": \"/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationFabrics/${RECOVERY_FABRIC}/replicationProtectionContainers/${RECOVERY_CONTAINER}\",
            \"policyId\": \"${POLICY_ID}\",
            \"providerSpecificInput\": {
                \"instanceType\": \"A2A\"
            }
        }
    }"

echo "Container mapping criado: $LOCATION → $LOCATION_DR"
```

---

### Task 3.4: Failover e Recovery Plan (CLI)

> **POR QUE CLI?** Operacoes de failover sao **imperativas** — voce executa
> um failover em resposta a um desastre, nao declara um estado desejado.

```bash
# ============================================================
# TASK 3.4 - Recovery Plan (CLI)
# ============================================================

# Criar recovery plan (agrupa VMs para failover coordenado)
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationRecoveryPlans/az104-recovery-plan?api-version=2023-06-01" \
    --body "{
        \"properties\": {
            \"primaryFabricId\": \"/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationFabrics/${PRIMARY_FABRIC}\",
            \"recoveryFabricId\": \"/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG11}/providers/Microsoft.RecoveryServices/vaults/${VAULT_NAME}/replicationFabrics/${RECOVERY_FABRIC}\",
            \"failoverDeploymentModel\": \"ResourceManager\",
            \"groups\": [
                {
                    \"groupType\": \"Boot\",
                    \"replicationProtectedItems\": [],
                    \"startGroupActions\": [],
                    \"endGroupActions\": []
                }
            ]
        }
    }"

echo "Recovery Plan criado: az104-recovery-plan"
echo ""
echo "Para executar failover (APENAS em emergencia real ou teste):"
echo "  az rest --method POST --url '.../replicationRecoveryPlans/az104-recovery-plan/testFailover'"
```

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-asr-infra.json` (Fabrics + Containers para 2 regioes)
- [ ] Deploy `bloco3-asr-policy.json` (Replication Policy com RPO 24h)
- [ ] Criar container mapping via CLI (source → target)
- [ ] Criar recovery plan via CLI
- [ ] Entender hierarquia: Vault → Fabric → Container → Protected Item

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Qual instanceType para replicacao Azure-to-Azure?**

A) HyperV  B) VMware  C) A2A  D) InMage

<details><summary>Ver resposta</summary>**Resposta: C) A2A** — Azure-to-Azure.</details>

### Questao 3.2
**RPO de crash-consistent snapshots no ASR?**

A) 1 minuto  B) 5 minutos  C) 15 minutos  D) 1 hora

<details><summary>Ver resposta</summary>**Resposta: B) 5 minutos** — padrao do ASR, nao configuravel.</details>

### Questao 3.3
**Para que serve o Recovery Plan?**

A) Substituir backup policies
B) Agrupar VMs para failover coordenado com ordem definida
C) Monitorar replicacao em tempo real
D) Definir RPO e RTO

<details><summary>Ver resposta</summary>**Resposta: B)** — Recovery Plans agrupam VMs em grupos de boot para failover ordenado.</details>

### Questao 3.4
**Failover pode ser feito via ARM Template?**

A) Sim, com recurso failoverAction
B) Nao, e uma operacao imperativa (CLI/Portal/PowerShell)
C) Sim, usando triggers
D) Apenas via runbook

<details><summary>Ver resposta</summary>**Resposta: B)** — ARM e declarativo; failover e uma acao pontual.</details>

---

# Bloco 4 - Azure Monitor

**Tecnologia:** ARM Templates JSON
**Recursos criados:** Action Group, Metric Alert, Diagnostic Settings

---

### Task 4.1: Action Group via ARM

Salve como **`bloco4-action-group.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "actionGroupName": {
            "type": "string",
            "defaultValue": "az104-ag-email",
            "metadata": {
                "description": "Nome do Action Group"
            }
        },
        "actionGroupShortName": {
            "type": "string",
            "defaultValue": "az104email",
            "maxLength": 12,
            "metadata": {
                "description": "Nome curto do Action Group (max 12 chars)"
            }
        },
        "emailAddress": {
            "type": "string",
            "defaultValue": "admin@contoso.com",
            "metadata": {
                "description": "Email para notificacoes"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Action Group: QUEM sera notificado e COMO
            // Suporta: email, SMS, push, webhook, ITSM, Logic App, Function, Runbook
            "type": "Microsoft.Insights/actionGroups",
            "apiVersion": "2023-01-01",
            "name": "[parameters('actionGroupName')]",
            "location": "global",
            "properties": {
                "groupShortName": "[parameters('actionGroupShortName')]",
                "enabled": true,

                // Email receivers: lista de emails para notificar
                "emailReceivers": [
                    {
                        "name": "admin-email",
                        "emailAddress": "[parameters('emailAddress')]",
                        "useCommonAlertSchema": true
                    }
                ],

                // SMS receivers (exemplo comentado):
                // "smsReceivers": [
                //     {
                //         "name": "admin-sms",
                //         "countryCode": "55",
                //         "phoneNumber": "11999999999"
                //     }
                // ],

                // Webhook receivers (para integracao com PagerDuty, Slack, etc.):
                // "webhookReceivers": [
                //     {
                //         "name": "slack-webhook",
                //         "serviceUri": "https://hooks.slack.com/services/..."
                //     }
                // ]

                // ARM Role receivers: notificar todos com determinada role
                "armRoleReceivers": [
                    {
                        "name": "owner-role",
                        "roleId": "8e3af657-a8ff-443c-a75c-2fe8c4bcb635",
                        "useCommonAlertSchema": true
                    }
                ]
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "actionGroupId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Insights/actionGroups', parameters('actionGroupName'))]"
        }
    }
}
```

> **Conceito AZ-104 — Common Alert Schema:**
> Quando `useCommonAlertSchema: true`, todas as notificacoes seguem o mesmo
> formato JSON, independentemente do tipo de alerta (metric, log, activity log).
> Facilita integracao com ferramentas externas.

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco4-action-group.json \
    --parameters emailAddress="seu-email@example.com"

# Verificar action group
az monitor action-group show \
    -n "az104-ag-email" \
    -g "$RG13" \
    --query "{name:name, shortName:groupShortName, emails:emailReceivers[].emailAddress}" -o json
```

---

### Task 4.2: Metric Alert Rule via ARM

> **Cobranca:** Alert rules geram cobranca minima por sinal monitorado.

Salve como **`bloco4-metric-alert.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "alertName": {
            "type": "string",
            "defaultValue": "az104-cpu-alert",
            "metadata": {
                "description": "Nome do alerta de metrica"
            }
        },
        "vmResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg11",
            "metadata": {
                "description": "Resource Group da VM monitorada"
            }
        },
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-backup",
            "metadata": {
                "description": "Nome da VM a monitorar"
            }
        },
        "actionGroupName": {
            "type": "string",
            "defaultValue": "az104-ag-email",
            "metadata": {
                "description": "Nome do Action Group para notificacao"
            }
        },
        "cpuThreshold": {
            "type": "int",
            "defaultValue": 80,
            "minValue": 1,
            "maxValue": 100,
            "metadata": {
                "description": "Percentual de CPU para disparar alerta"
            }
        }
    },

    // ============================================================
    // VARIABLES
    // ============================================================
    "variables": {
        // resourceId da VM em outro RG (cross-resource-group reference)
        "vmId": "[resourceId(parameters('vmResourceGroup'), 'Microsoft.Compute/virtualMachines', parameters('vmName'))]",
        "actionGroupId": "[resourceId('Microsoft.Insights/actionGroups', parameters('actionGroupName'))]"
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Metric Alert: monitora uma metrica e dispara acao
            // Exemplo: CPU > 80% por 5 minutos → envia email
            "type": "Microsoft.Insights/metricAlerts",
            "apiVersion": "2018-03-01",
            "name": "[parameters('alertName')]",
            "location": "global",
            "properties": {
                "description": "Alerta quando CPU da VM excede o limite configurado",
                "severity": 2,
                "enabled": true,

                // scopes: quais recursos monitorar
                "scopes": [
                    "[variables('vmId')]"
                ],

                // evaluationFrequency: com que frequencia verificar (ISO 8601)
                "evaluationFrequency": "PT5M",

                // windowSize: janela de avaliacao
                "windowSize": "PT15M",

                // criteria: condicao para disparar
                "criteria": {
                    "odata.type": "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria",
                    "allOf": [
                        {
                            "name": "HighCPU",
                            "metricName": "Percentage CPU",
                            "metricNamespace": "Microsoft.Compute/virtualMachines",
                            "operator": "GreaterThan",
                            "threshold": "[parameters('cpuThreshold')]",
                            "timeAggregation": "Average",
                            "criterionType": "StaticThresholdCriterion"
                        }
                    ]
                },

                // actions: o que fazer quando dispara
                "actions": [
                    {
                        "actionGroupId": "[variables('actionGroupId')]"
                    }
                ],

                // autoMitigate: resolver automaticamente quando metrica volta ao normal
                "autoMitigate": true
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "alertId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Insights/metricAlerts', parameters('alertName'))]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"odata.type": "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"` — string exata
> - Bicep: mesma string, mas dentro de sintaxe mais limpa
> - ARM: ISO 8601 para frequencia (`PT5M` = 5 minutos, `PT15M` = 15 minutos)
> - Bicep: mesmos valores ISO 8601

> **Conceito AZ-104 — Tipos de Alert Criteria:**
> | Tipo | Uso |
> |------|-----|
> | Static Threshold | Valor fixo (ex: CPU > 80%) |
> | Dynamic Threshold | Machine Learning detecta anomalias |
> | Log Alert | Baseado em query KQL no Log Analytics |
> | Activity Log Alert | Eventos de controle (create, delete, etc.) |

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco4-metric-alert.json

# Verificar alerta
az monitor metrics alert show \
    --name "az104-cpu-alert" \
    -g "$RG13" \
    --query "{name:name, severity:severity, enabled:enabled, metric:criteria.allOf[0].metricName}" -o json
```

---

### Task 4.3: Diagnostic Settings via ARM

Salve como **`bloco4-diagnostics.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-backup",
            "metadata": {
                "description": "Nome da VM para configurar diagnostics"
            }
        },
        "workspaceName": {
            "type": "string",
            "defaultValue": "az104-law",
            "metadata": {
                "description": "Nome do Log Analytics Workspace (sera criado no Bloco 5)"
            }
        },
        "workspaceResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg13",
            "metadata": {
                "description": "RG do workspace"
            }
        },
        "settingName": {
            "type": "string",
            "defaultValue": "az104-vm-diag",
            "metadata": {
                "description": "Nome da configuracao de diagnostico"
            }
        }
    },

    // ============================================================
    // VARIABLES
    // ============================================================
    "variables": {
        "workspaceId": "[resourceId(parameters('workspaceResourceGroup'), 'Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))]"
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Diagnostic Settings: encaminha metricas/logs para destinos
            // Destinos possiveis: Log Analytics, Storage Account, Event Hub
            // O recurso e um "extension" da VM (deploy como sub-recurso)
            "type": "Microsoft.Compute/virtualMachines/providers/diagnosticSettings",
            "apiVersion": "2021-05-01-preview",
            "name": "[concat(parameters('vmName'), '/Microsoft.Insights/', parameters('settingName'))]",
            "properties": {
                // workspaceId: enviar para Log Analytics
                "workspaceId": "[variables('workspaceId')]",

                // metrics: quais metricas coletar
                "metrics": [
                    {
                        "category": "AllMetrics",
                        "enabled": true,
                        "retentionPolicy": {
                            "enabled": false,
                            "days": 0
                        }
                    }
                ]

                // logs: quais logs coletar (VMs nao tem logs nativos via diagnostic settings)
                // Para logs de VM, use o Azure Monitor Agent (Bloco 5)
            }
        }
    ]
}
```

> **IMPORTANTE:** Diagnostic Settings para VMs enviam apenas **metricas de plataforma**.
> Para coletar logs do sistema operacional (Event Log, Syslog, Performance Counters),
> voce precisa do **Azure Monitor Agent** (configurado no Bloco 5).
>
> **Destinos suportados:**
> - Log Analytics Workspace (query via KQL)
> - Storage Account (arquivamento de longo prazo)
> - Event Hub (streaming para SIEM externo)
> - Partner Solutions (Datadog, Elastic, etc.)

Deploy:

```bash
# NOTA: Execute este deploy APOS criar o Log Analytics Workspace no Bloco 5
# Caso contrario, o deploy falhara por falta do workspace

az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco4-diagnostics.json

echo "Diagnostic settings configurado para az104-vm-backup"
echo "Metricas serao enviadas para o workspace $WORKSPACE_NAME"
```

---

## Modo Desafio - Bloco 4

- [ ] Deploy `bloco4-action-group.json` (Action Group com email + ARM role)
- [ ] Deploy `bloco4-metric-alert.json` (CPU > 80% → Action Group)
- [ ] Deploy `bloco4-diagnostics.json` (metricas da VM → Log Analytics)
- [ ] Entender: Action Group = QUEM, Alert Rule = QUANDO, Diagnostic = COMO coletar

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Qual recurso ARM define QUEM recebe notificacoes de alerta?**

A) `Microsoft.Insights/metricAlerts`
B) `Microsoft.Insights/actionGroups`
C) `Microsoft.Insights/diagnosticSettings`
D) `Microsoft.Insights/scheduledQueryRules`

<details><summary>Ver resposta</summary>**Resposta: B) Microsoft.Insights/actionGroups** — define os receivers (email, SMS, webhook, etc.).</details>

### Questao 4.2
**`evaluationFrequency: PT5M` e `windowSize: PT15M`. O que significa?**

A) Verifica a cada 15 min, usa dados de 5 min
B) Verifica a cada 5 min, usa dados dos ultimos 15 min
C) Verifica a cada 5 min, usa dados de 5 min
D) Verifica a cada 15 min, usa dados de 15 min

<details><summary>Ver resposta</summary>

**Resposta: B)** A cada 5 minutos, avalia a media dos ultimos 15 minutos.

- `evaluationFrequency`: com que frequencia a regra e verificada
- `windowSize`: janela de dados considerada em cada verificacao
- `windowSize >= evaluationFrequency` (sempre)

</details>

### Questao 4.3
**Action Group com `useCommonAlertSchema: true`. Qual a vantagem?**

A) Alertas mais rapidos
B) Formato JSON padronizado para todos os tipos de alerta
C) Menos custo
D) Mais tipos de receiver

<details><summary>Ver resposta</summary>**Resposta: B)** — formato uniforme facilita integracao com ITSM, Logic Apps, etc.</details>

### Questao 4.4
**`autoMitigate: true` em um metric alert. O que acontece?**

A) O alerta e excluido automaticamente
B) O alerta e resolvido automaticamente quando a metrica volta ao normal
C) A VM e reiniciada automaticamente
D) O action group e desabilitado

<details><summary>Ver resposta</summary>**Resposta: B)** — quando a condicao nao e mais verdadeira, o alerta muda para "Resolved".</details>

---

# Bloco 5 - Log Analytics

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** Log Analytics Workspace, VM Extension (Azure Monitor Agent), Saved Search, Network Watcher

---

### Task 5.1: Log Analytics Workspace via ARM

> **Cobranca:** O workspace gera cobranca por GB de dados ingeridos.

Salve como **`bloco5-law.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "workspaceName": {
            "type": "string",
            "defaultValue": "az104-law",
            "metadata": {
                "description": "Nome do Log Analytics Workspace"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "sku": {
            "type": "string",
            "defaultValue": "PerGB2018",
            "allowedValues": [
                "PerGB2018",
                "Free",
                "CapacityReservation"
            ],
            "metadata": {
                "description": "Pricing tier do workspace"
            }
        },
        "retentionInDays": {
            "type": "int",
            "defaultValue": 30,
            "minValue": 7,
            "maxValue": 730,
            "metadata": {
                "description": "Retencao de dados em dias (7-730)"
            }
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Log Analytics Workspace: repositorio central de logs
            // Recebe dados de: VMs, Azure services, on-premises, containers
            // Consultado via KQL (Kusto Query Language)
            "type": "Microsoft.OperationalInsights/workspaces",
            "apiVersion": "2022-10-01",
            "name": "[parameters('workspaceName')]",
            "location": "[parameters('location')]",
            "properties": {
                "sku": {
                    "name": "[parameters('sku')]"
                },

                // retentionInDays: por quanto tempo manter os logs
                // Free tier: 7 dias fixo
                // PerGB2018: 30 dias gratis, ate 730 com custo adicional
                "retentionInDays": "[parameters('retentionInDays')]",

                // features: configuracoes adicionais
                "features": {
                    "enableLogAccessUsingOnlyResourcePermissions": true
                },

                // publicNetworkAccessForIngestion: aceitar dados via internet
                "publicNetworkAccessForIngestion": "Enabled",
                // publicNetworkAccessForQuery: permitir queries via internet
                "publicNetworkAccessForQuery": "Enabled"
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "workspaceId": {
            "type": "string",
            "value": "[resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))]"
        },
        "customerId": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))).customerId]"
        }
    }
}
```

> **Conceito AZ-104 — Pricing Tiers:**
> | Tier | Retencao | Custo |
> |------|----------|-------|
> | Free | 7 dias | 500 MB/dia gratis (legacy) |
> | PerGB2018 | 30 dias gratis (ate 730) | ~$2.76/GB ingerido |
> | CapacityReservation | 30 dias gratis (ate 730) | Desconto por reserva (100+ GB/dia) |

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco5-law.json

# Verificar workspace
az monitor log-analytics workspace show \
    --workspace-name "$WORKSPACE_NAME" \
    -g "$RG13" \
    --query "{name:name, sku:sku.name, retention:retentionInDays, customerId:customerId}" -o json
```

---

### Task 5.2: Azure Monitor Agent via ARM (VM Extension)

Salve como **`bloco5-ama-extension.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "vmName": {
            "type": "string",
            "defaultValue": "az104-vm-backup",
            "metadata": {
                "description": "Nome da VM onde instalar o agente"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Azure Monitor Agent (AMA) — substituto do Log Analytics Agent (MMA/OMS)
            // Instalado como VM Extension
            // Coleta logs e metricas do SO e envia para Log Analytics
            //
            // AMA vs MMA (Legacy):
            // - AMA: suporta Data Collection Rules (DCR), multi-homing nativo
            // - MMA: deprecated em agosto 2024, sem novas features
            "type": "Microsoft.Compute/virtualMachines/extensions",
            "apiVersion": "2023-09-01",
            "name": "[concat(parameters('vmName'), '/AzureMonitorWindowsAgent')]",
            "location": "[parameters('location')]",
            "properties": {
                "publisher": "Microsoft.Azure.Monitor",
                "type": "AzureMonitorWindowsAgent",
                "typeHandlerVersion": "1.0",
                "autoUpgradeMinorVersion": true,
                "enableAutomaticUpgrade": true
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "extensionId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/virtualMachines/extensions', parameters('vmName'), 'AzureMonitorWindowsAgent')]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "[concat(parameters('vmName'), '/AzureMonitorWindowsAgent')]"` — nome composto
> - Bicep: `parent: vm` + `name: 'AzureMonitorWindowsAgent'` — mais claro
> - ARM: `"enableAutomaticUpgrade": true` — atualiza automaticamente o agente
> - Ambos: mesma API, mesmas propriedades

> **IMPORTANTE para AZ-104:**
> - **Windows**: `AzureMonitorWindowsAgent` (publisher: `Microsoft.Azure.Monitor`)
> - **Linux**: `AzureMonitorLinuxAgent` (publisher: `Microsoft.Azure.Monitor`)
> - O MMA (Microsoft Monitoring Agent) esta **deprecated** — use sempre AMA

Deploy:

```bash
az deployment group create \
    --resource-group "$RG11" \
    --template-file bloco5-ama-extension.json

# Verificar extensao instalada
az vm extension show \
    --vm-name "az104-vm-backup" \
    -g "$RG11" \
    --name "AzureMonitorWindowsAgent" \
    --query "{name:name, status:provisioningState, version:typeHandlerVersion}" -o table
```

---

### Task 5.3: Data Collection Rule via ARM

Salve como **`bloco5-dcr.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "dcrName": {
            "type": "string",
            "defaultValue": "az104-dcr-perf",
            "metadata": {
                "description": "Nome da Data Collection Rule"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "workspaceName": {
            "type": "string",
            "defaultValue": "az104-law"
        },
        "workspaceResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg13"
        }
    },

    // ============================================================
    // VARIABLES
    // ============================================================
    "variables": {
        "workspaceId": "[resourceId(parameters('workspaceResourceGroup'), 'Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))]"
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Data Collection Rule (DCR): define O QUE coletar e PARA ONDE enviar
            // Substitui a configuracao direta no workspace (modelo antigo com MMA)
            // AMA + DCR = modelo moderno de coleta de dados
            "type": "Microsoft.Insights/dataCollectionRules",
            "apiVersion": "2022-06-01",
            "name": "[parameters('dcrName')]",
            "location": "[parameters('location')]",
            "properties": {
                "description": "Coleta de performance counters e event logs do Windows",

                // dataSources: O QUE coletar
                "dataSources": {
                    // Performance Counters (CPU, memoria, disco)
                    "performanceCounters": [
                        {
                            "name": "perfCounterDataSource",
                            "streams": [ "Microsoft-Perf" ],
                            "samplingFrequencyInSeconds": 60,
                            "counterSpecifiers": [
                                "\\Processor Information(_Total)\\% Processor Time",
                                "\\Memory\\Available Bytes",
                                "\\LogicalDisk(_Total)\\% Free Space",
                                "\\LogicalDisk(_Total)\\Disk Reads/sec",
                                "\\LogicalDisk(_Total)\\Disk Writes/sec"
                            ]
                        }
                    ],

                    // Windows Event Logs
                    "windowsEventLogs": [
                        {
                            "name": "eventLogsDataSource",
                            "streams": [ "Microsoft-Event" ],
                            "xPathQueries": [
                                "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
                                "System!*[System[(Level=1 or Level=2 or Level=3)]]"
                            ]
                        }
                    ]
                },

                // destinations: PARA ONDE enviar
                "destinations": {
                    "logAnalytics": [
                        {
                            "workspaceResourceId": "[variables('workspaceId')]",
                            "name": "law-destination"
                        }
                    ]
                },

                // dataFlows: conecta sources → destinations
                "dataFlows": [
                    {
                        "streams": [ "Microsoft-Perf" ],
                        "destinations": [ "law-destination" ]
                    },
                    {
                        "streams": [ "Microsoft-Event" ],
                        "destinations": [ "law-destination" ]
                    }
                ]
            }
        }
    ],

    // ============================================================
    // OUTPUTS
    // ============================================================
    "outputs": {
        "dcrId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Insights/dataCollectionRules', parameters('dcrName'))]"
        }
    }
}
```

> **Conceito AZ-104 — Data Collection Rule (DCR):**
> | Componente | Funcao |
> |------------|--------|
> | `dataSources` | O que coletar (perf counters, event logs, syslog) |
> | `destinations` | Para onde enviar (Log Analytics, Metrics, Storage) |
> | `dataFlows` | Conecta sources a destinations (stream routing) |
>
> **Fluxo:** VM → AMA Agent → DCR (filtra/transforma) → Log Analytics Workspace

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco5-dcr.json

# Preflight: verificar que comandos de DCR estao disponiveis
if ! az monitor data-collection rule -h &>/dev/null; then
    echo "✗ ERRO: Comandos de DCR nao disponiveis."
    echo "  Execute: az extension add --name monitor-control-service --upgrade"
    echo "  Pulando associacao DCR → VM."
else
    # Associar DCR a VM
    VM_ID=$(az vm show -g "$RG11" -n "az104-vm-backup" --query id -o tsv)
    DCR_ID=$(az monitor data-collection rule show -g "$RG13" -n "az104-dcr-perf" --query id -o tsv)

    az monitor data-collection rule association create \
        --name "az104-vm-dcr-assoc" \
        --resource "$VM_ID" \
        --rule-id "$DCR_ID"

    echo "DCR associada a VM. Dados comecam a fluir em ~5 minutos."
fi
```

---

### Task 5.4: Saved Search (KQL) via ARM

Salve como **`bloco5-saved-searches.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    // ============================================================
    // PARAMETERS
    // ============================================================
    "parameters": {
        "workspaceName": {
            "type": "string",
            "defaultValue": "az104-law"
        }
    },

    // ============================================================
    // RESOURCES
    // ============================================================
    "resources": [
        {
            // Saved Search 1: CPU alta (ultimas 4 horas)
            "type": "Microsoft.OperationalInsights/workspaces/savedSearches",
            "apiVersion": "2020-08-01",
            "name": "[concat(parameters('workspaceName'), '/cpuHighUsage')]",
            "properties": {
                "category": "AZ-104 Lab",
                "displayName": "VMs com CPU > 80% (4h)",
                "query": "Perf | where ObjectName == 'Processor Information' and CounterName == '% Processor Time' | where CounterValue > 80 | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 15m) | order by AvgCPU desc",
                "version": 2
            }
        },
        {
            // Saved Search 2: Erros no Event Log
            "type": "Microsoft.OperationalInsights/workspaces/savedSearches",
            "apiVersion": "2020-08-01",
            "name": "[concat(parameters('workspaceName'), '/eventLogErrors')]",
            "properties": {
                "category": "AZ-104 Lab",
                "displayName": "Erros no Event Log (24h)",
                "query": "Event | where EventLevelName == 'Error' | summarize ErrorCount = count() by Source, Computer | order by ErrorCount desc",
                "version": 2
            }
        },
        {
            // Saved Search 3: Espaco em disco
            "type": "Microsoft.OperationalInsights/workspaces/savedSearches",
            "apiVersion": "2020-08-01",
            "name": "[concat(parameters('workspaceName'), '/diskFreeSpace')]",
            "properties": {
                "category": "AZ-104 Lab",
                "displayName": "Espaco livre em disco < 20%",
                "query": "Perf | where ObjectName == 'LogicalDisk' and CounterName == '% Free Space' | where CounterValue < 20 and InstanceName != '_Total' | summarize MinFree = min(CounterValue) by Computer, InstanceName | order by MinFree asc",
                "version": 2
            }
        },
        {
            // Saved Search 4: Heartbeat (VMs que pararam de reportar)
            "type": "Microsoft.OperationalInsights/workspaces/savedSearches",
            "apiVersion": "2020-08-01",
            "name": "[concat(parameters('workspaceName'), '/missingHeartbeat')]",
            "properties": {
                "category": "AZ-104 Lab",
                "displayName": "VMs sem heartbeat (>15min)",
                "query": "Heartbeat | summarize LastHeartbeat = max(TimeGenerated) by Computer | where LastHeartbeat < ago(15m) | order by LastHeartbeat asc",
                "version": 2
            }
        }
    ]
}
```

> **Conceito AZ-104 — KQL (Kusto Query Language):**
> - Linguagem de consulta para Log Analytics e Azure Data Explorer
> - Pipe-based: `Tabela | where | summarize | order`
> - Tabelas comuns: `Perf`, `Event`, `Heartbeat`, `Syslog`, `AzureActivity`
> - Funcoes uteis: `ago(1h)`, `bin(TimeGenerated, 5m)`, `count()`, `avg()`

Deploy:

```bash
az deployment group create \
    --resource-group "$RG13" \
    --template-file bloco5-saved-searches.json

# Obter workspace resource ID — necessario para queries via az rest
WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
    -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)

# Testar query no workspace (via az rest — metodo mais confiavel que az monitor log-analytics query)
echo "=== Testando Heartbeat query ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Heartbeat | summarize count() by Computer"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Heartbeat pode levar 10-15 min para aparecer apos instalar AMA"

echo "Saved searches criadas no workspace $WORKSPACE_NAME"
```

---

### Task 5.5: Network Watcher Connection Monitor (CLI)

> **POR QUE CLI?** O Connection Monitor envolve configuracoes complexas
> com endpoints e test configurations. A CLI facilita o setup.

```bash
# ============================================================
# TASK 5.5 - Network Watcher Connection Monitor (CLI)
# ============================================================

# Habilitar Network Watcher na regiao (se necessario)
az network watcher configure \
    --locations "$LOCATION" \
    --resource-group "NetworkWatcherRG" \
    --enabled true

# Instalar extensao Network Watcher Agent na VM
az vm extension set \
    --vm-name "az104-vm-backup" \
    -g "$RG11" \
    --name "NetworkWatcherAgentWindows" \
    --publisher "Microsoft.Azure.NetworkWatcher" \
    --version "1.4"

# Criar Connection Monitor
VM_ID=$(az vm show -g "$RG11" -n "az104-vm-backup" --query id -o tsv)

az network watcher connection-monitor create \
    --name "az104-conn-monitor" \
    --resource-group "NetworkWatcherRG" \
    --location "$LOCATION" \
    --endpoint-source-name "az104-vm" \
    --endpoint-source-resource-id "$VM_ID" \
    --endpoint-dest-name "bing" \
    --endpoint-dest-address "www.bing.com" \
    --test-config-name "tcp-443" \
    --protocol "Tcp" \
    --tcp-port 443 \
    --test-group-name "web-test"

echo "Connection Monitor criado: az104-conn-monitor"
echo "Monitora conectividade da VM para www.bing.com:443"
```

---

### Task 5.6: Testar queries KQL (CLI)

```bash
# ============================================================
# TASK 5.6 - Testar KQL queries no workspace
# ============================================================

# Obter workspace resource ID para queries via az rest
WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
    -g "$RG13" -n "$WORKSPACE_NAME" --query id -o tsv)

# NOTA: Usamos `az rest` contra a API do Log Analytics em vez de `az monitor log-analytics query`,
# que pode falhar em versoes recentes do CLI. `az rest` funciona em qualquer versao.
# Alternativa: Portal Azure → Log Analytics Workspace → Logs → colar a query KQL

echo "=== Query 1: Heartbeats recentes ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Heartbeat | summarize LastCall = max(TimeGenerated) by Computer | order by LastCall desc"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Heartbeat pode levar 10-15 min para aparecer"

echo ""
echo "=== Query 2: Top 5 processos por CPU ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Perf | where ObjectName == '\''Processor Information'\'' | where CounterName == '\''% Processor Time'\'' | summarize AvgCPU = avg(CounterValue) by Computer | top 5 by AvgCPU desc"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Dados de Perf podem levar 10-15 min para aparecer"

echo ""
echo "=== Query 3: Eventos de erro (ultimas 24h) ==="
az rest --method post \
    --url "${WORKSPACE_RESOURCE_ID}/api/query?api-version=2022-10-27" \
    --body '{"query": "Event | where TimeGenerated > ago(24h) | where EventLevelName == '\''Error'\'' | summarize count() by Source | top 10 by count_"}' \
    --query "tables[0].rows" -o table 2>/dev/null || \
echo "Eventos podem levar 10-15 min para aparecer"
```

---

## Modo Desafio - Bloco 5

- [ ] Deploy `bloco5-law.json` (Log Analytics Workspace)
- [ ] Deploy `bloco5-ama-extension.json` (Azure Monitor Agent na VM)
- [ ] Deploy `bloco5-dcr.json` (Data Collection Rule com perf + events)
- [ ] Associar DCR a VM via CLI
- [ ] Deploy `bloco5-saved-searches.json` (4 queries KQL salvas)
- [ ] Configurar Network Watcher + Connection Monitor via CLI
- [ ] Testar queries KQL via CLI

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Qual agente substituiu o Log Analytics Agent (MMA)?**

A) Dependency Agent  B) Azure Monitor Agent (AMA)  C) Diagnostics Agent  D) OMS Agent

<details><summary>Ver resposta</summary>**Resposta: B) Azure Monitor Agent (AMA)** — MMA foi deprecated em agosto 2024.</details>

### Questao 5.2
**Data Collection Rule (DCR) define...**

A) Quem tem acesso ao workspace
B) O que coletar e para onde enviar
C) Quanto cobrar por GB
D) A retencao maxima de dados

<details><summary>Ver resposta</summary>**Resposta: B)** — DCR tem `dataSources` (o que), `destinations` (para onde), `dataFlows` (roteamento).</details>

### Questao 5.3
**Log Analytics Workspace com SKU PerGB2018. Retencao gratis?**

A) 7 dias  B) 30 dias  C) 90 dias  D) 365 dias

<details><summary>Ver resposta</summary>**Resposta: B) 30 dias** — apos 30 dias, custo adicional por dia/GB retido.</details>

### Questao 5.4
**Qual tabela KQL contem dados de conectividade de VMs?**

A) Event  B) Perf  C) Heartbeat  D) AzureActivity

<details><summary>Ver resposta</summary>**Resposta: C) Heartbeat** — enviado pelo agente a cada 1 minuto, confirma que a VM esta ativa.</details>

### Questao 5.5
**Connection Monitor monitora...**

A) CPU e memoria da VM
B) Conectividade de rede entre endpoints
C) Alteracoes no NSG
D) Trafego de DNS

<details><summary>Ver resposta</summary>**Resposta: B)** — testa conectividade TCP/ICMP/HTTP entre source e destination.</details>

### Questao 5.6
**Em ARM JSON, como referenciar um recurso de outro Resource Group?**

A) `[resourceId('type', 'name')]`
B) `[resourceId('otherRG', 'type', 'name')]`
C) `[crossResourceId('type', 'name')]`
D) Nao e possivel

<details>
<summary>Ver resposta</summary>

**Resposta: B) `[resourceId('otherRG', 'type', 'name')]`**

O primeiro parametro de `resourceId()` pode ser o nome do Resource Group.
Quando omitido, assume o RG do deploy atual.

Formato completo: `[resourceId(subscriptionId, resourceGroupName, 'type', 'name')]`

</details>

---

# Bloco 6 - Backup Vault e VM Move

> **Contexto:** O Backup Vault e o servico mais recente de backup do Azure, projetado para workloads
> que o Recovery Services Vault nao suporta (Disks, Blobs, PostgreSQL, AKS). Neste bloco voce tambem
> pratica mover VMs entre Resource Groups — topico cobrado no AZ-104 (dominio Compute).
>
> **Resource Groups:** `az104-rg7` (VMs da Semana 2) + `az104-rg-bv` (Backup Vault) + `az104-rg-moved` (destino do move)

---

### Task 6.1: Mover VM para outro Resource Group (CLI)

> **Por que CLI e nao ARM?** Move de recursos e uma operacao imperativa (`az resource move`),
> nao um provisionamento declarativo. ARM templates descrevem o estado desejado de recursos;
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
az group create --name az104-rg-moved --location eastus

# Obter IDs dos recursos a mover
# IMPORTANTE: VM + NIC + Disk devem ir juntos (dependencias)
VM_ID=$(az vm show -g az104-rg7 -n az104-vm-linux --query id -o tsv)
NIC_ID=$(az vm show -g az104-rg7 -n az104-vm-linux \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)
DISK_ID=$(az vm show -g az104-rg7 -n az104-vm-linux \
    --query "storageProfile.osDisk.managedDisk.id" -o tsv)

echo "VM ID: $VM_ID"
echo "NIC ID: $NIC_ID"
echo "Disk ID: $DISK_ID"

# Mover todos os recursos dependentes de uma vez
# az resource move: operacao imperativa (nao declarativa)
# --destination-group: RG de destino (mesma subscription)
# --ids: lista de resource IDs a mover
az resource move \
    --destination-group az104-rg-moved \
    --ids $VM_ID $NIC_ID $DISK_ID

# Validar: VM agora esta no novo RG
az vm show -g az104-rg-moved -n az104-vm-linux --query "{name:name, rg:resourceGroup, location:location}" -o table
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
VM_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux --query id -o tsv)
NIC_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)
DISK_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux \
    --query "storageProfile.osDisk.managedDisk.id" -o tsv)

az resource move \
    --destination-group az104-rg7 \
    --ids $VM_ID $NIC_ID $DISK_ID

# Validar: VM de volta ao RG original
az vm show -g az104-rg7 -n az104-vm-linux --query "{name:name, rg:resourceGroup}" -o table
echo "VM movida de volta para az104-rg7 com sucesso"
```

> **Conexao com Bloco 3:** Para mover VMs entre regioes, use Azure Site Recovery (configurado no Bloco 3).
> `az resource move` NAO suporta move cross-region para VMs.

---

### Task 6.3: Criar Azure Backup Vault via ARM JSON

Crie o arquivo `bloco6-backup-vault.json`:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",

    "_comment": "================================================================",
    "_comment2": "BLOCO 6 - Azure Backup Vault + Disk Backup Policy",
    "_comment3": "================================================================",
    "_comment4": "Backup Vault vs Recovery Services Vault:",
    "_comment5": "- Backup Vault: Azure Disks, Blobs, PostgreSQL, AKS",
    "_comment6": "- Recovery Services Vault: VMs, File Shares, Site Recovery, SAP HANA, SQL in VM",
    "_comment7": "",
    "_comment8": "Tipo ARM: Microsoft.DataProtection/backupVaults",
    "_comment9": "(diferente de Microsoft.RecoveryServices/vaults usado no Bloco 1)",
    "_comment10": "================================================================",

    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Localizacao dos recursos. Deve ser a mesma regiao dos discos a proteger."
            }
        },
        "backupVaultName": {
            "type": "string",
            "defaultValue": "az104-bv",
            "metadata": {
                "description": "Nome do Backup Vault."
            }
        },
        "storageRedundancy": {
            "type": "string",
            "defaultValue": "LocallyRedundant",
            "allowedValues": [
                "LocallyRedundant",
                "GeoRedundant"
            ],
            "metadata": {
                "description": "Redundancia do storage do vault. LRS para labs, GRS para producao."
            }
        },
        "diskPolicyName": {
            "type": "string",
            "defaultValue": "az104-bv-disk-policy",
            "metadata": {
                "description": "Nome da politica de backup para Azure Disks."
            }
        },
        "retentionDays": {
            "type": "int",
            "defaultValue": 30,
            "minValue": 1,
            "maxValue": 360,
            "metadata": {
                "description": "Retencao em dias para os snapshots de disco."
            }
        }
    },

    "resources": [
        {
            "_comment": "=========================================",
            "_comment2": "Backup Vault",
            "_comment3": "=========================================",
            "_comment4": "Microsoft.DataProtection/backupVaults:",
            "_comment5": "- storageSettings: define redundancia (LRS/GRS)",
            "_comment6": "  Diferente do RSV, aqui e um ARRAY de storage settings",
            "_comment7": "- identity: SystemAssigned para acessar discos",
            "_comment8": "  O vault precisa de roles: Disk Backup Reader + Disk Snapshot Contributor",
            "_comment9": "=========================================",

            "type": "Microsoft.DataProtection/backupVaults",
            "apiVersion": "2023-11-01",
            "name": "[parameters('backupVaultName')]",
            "location": "[parameters('location')]",
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "storageSettings": [
                    {
                        "datastoreType": "VaultStore",
                        "type": "[parameters('storageRedundancy')]"
                    }
                ]
            }
        },
        {
            "_comment": "=========================================",
            "_comment2": "Disk Backup Policy",
            "_comment3": "=========================================",
            "_comment4": "Microsoft.DataProtection/backupVaults/backupPolicies:",
            "_comment5": "- datasourceTypes: ['Microsoft.Compute/disks'] para discos",
            "_comment6": "- policyRules: define schedule (quando) e retention (quanto tempo)",
            "_comment7": "",
            "_comment8": "Disk backup usa snapshots incrementais:",
            "_comment9": "- Primeiro snapshot: copia completa do disco",
            "_commentA": "- Snapshots seguintes: apenas deltas (blocos alterados)",
            "_commentB": "- Menor custo e tempo que VM backup completo do RSV",
            "_commentC": "",
            "_commentD": "ARM JSON: recurso filho usa nome composto (vault/policy)",
            "_commentE": "e dependsOn explicito (diferente do Bicep que usa parent:)",
            "_commentF": "=========================================",

            "type": "Microsoft.DataProtection/backupVaults/backupPolicies",
            "apiVersion": "2023-11-01",
            "name": "[format('{0}/{1}', parameters('backupVaultName'), parameters('diskPolicyName'))]",
            "dependsOn": [
                "[resourceId('Microsoft.DataProtection/backupVaults', parameters('backupVaultName'))]"
            ],
            "properties": {
                "datasourceTypes": [
                    "Microsoft.Compute/disks"
                ],
                "objectType": "BackupPolicy",
                "policyRules": [
                    {
                        "name": "BackupDaily",
                        "objectType": "AzureBackupRule",
                        "backupParameters": {
                            "objectType": "AzureBackupParams",
                            "backupType": "Incremental"
                        },
                        "trigger": {
                            "objectType": "ScheduleBasedTriggerContext",
                            "schedule": {
                                "repeatingTimeIntervals": [
                                    "R/2024-01-01T02:00:00+00:00/P1D"
                                ]
                            },
                            "taggingCriteria": [
                                {
                                    "isDefault": true,
                                    "tagInfo": {
                                        "tagName": "Default"
                                    },
                                    "taggingPriority": 99
                                }
                            ]
                        },
                        "dataStore": {
                            "datastoreType": "OperationalStore",
                            "objectType": "DataStoreInfoBase"
                        }
                    },
                    {
                        "name": "Default",
                        "objectType": "AzureRetentionRule",
                        "isDefault": true,
                        "lifecycles": [
                            {
                                "deleteAfter": {
                                    "objectType": "AbsoluteDeleteOption",
                                    "duration": "[format('P{0}D', parameters('retentionDays'))]"
                                },
                                "sourceDataStore": {
                                    "datastoreType": "OperationalStore",
                                    "objectType": "DataStoreInfoBase"
                                }
                            }
                        ]
                    }
                ]
            }
        }
    ],

    "outputs": {
        "backupVaultId": {
            "type": "string",
            "value": "[resourceId('Microsoft.DataProtection/backupVaults', parameters('backupVaultName'))]",
            "metadata": {
                "description": "Resource ID do Backup Vault (necessario para configurar backup instances via CLI)"
            }
        },
        "backupVaultName": {
            "type": "string",
            "value": "[parameters('backupVaultName')]"
        },
        "backupVaultPrincipalId": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.DataProtection/backupVaults', parameters('backupVaultName')), '2023-11-01', 'full').identity.principalId]",
            "metadata": {
                "description": "Principal ID da managed identity do vault (necessario para role assignments)"
            }
        },
        "diskPolicyName": {
            "type": "string",
            "value": "[parameters('diskPolicyName')]"
        },
        "diskPolicyId": {
            "type": "string",
            "value": "[resourceId('Microsoft.DataProtection/backupVaults/backupPolicies', parameters('backupVaultName'), parameters('diskPolicyName'))]"
        }
    }
}
```

Deploy:

```bash
# ============================================================
# DEPLOY - Backup Vault + Disk Policy (ARM JSON)
# ============================================================

# Criar Resource Group para o Backup Vault
az group create --name az104-rg-bv --location eastus

# Deploy do template ARM
az deployment group create \
    -g az104-rg-bv \
    --template-file bloco6-backup-vault.json \
    --query "properties.outputs" -o table

# Validar: Backup Vault criado com LRS
az dataprotection backup-vault show \
    -g az104-rg-bv \
    --vault-name az104-bv \
    --query "{name:name, location:location, redundancy:properties.storageSettings[0].type}" \
    -o table

# Validar: Policy criada
az dataprotection backup-policy show \
    -g az104-rg-bv \
    --vault-name az104-bv \
    --name az104-bv-disk-policy \
    --query "{name:name, datasources:properties.datasourceTypes[0]}" \
    -o table
```

---

### Task 6.4: Comparar Backup Vault vs Recovery Services Vault

> **Esta task e conceitual — nao requer template ARM.**
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
| **ARM JSON child resource** | Nome composto + `dependsOn` | Nome composto + `dependsOn` |

> **Dica AZ-104:** Na prova, saber qual vault suporta qual workload e critico.
> VM backup = RSV. Disk backup = BV. File Share = RSV. Blob backup = BV. Site Recovery = RSV apenas.
> O **Backup Center** no portal unifica a gestao de ambos os vaults.

---

### Task 6.5: Configurar backup de disco no Backup Vault (CLI)

> **Por que CLI e nao ARM?** Configurar uma backup instance (associar um disco especifico ao vault)
> depende de IDs de recursos existentes e role assignments. Embora seja possivel em ARM
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
BV_NAME="az104-bv"
BV_RG="az104-rg-bv"
VM_RG="az104-rg7"
VM_NAME="az104-vm-linux"
POLICY_NAME="az104-bv-disk-policy"

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

- [ ] Criar RG `az104-rg-moved` e mover VM Linux para ele via CLI (`az resource move`)
- [ ] Verificar recursos dependentes movidos junto (NIC, Disk)
- [ ] Entender as diferencas entre move entre RGs vs move entre regioes
- [ ] Mover VM de volta ao RG original
- [ ] Deploy `bloco6-backup-vault.json` (Backup Vault + disk policy)
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
**Em ARM JSON, como voce declara um recurso filho (ex: backup policy dentro de um Backup Vault)?**

A) Usando a propriedade `parent`
B) Usando nome composto `"vaultName/policyName"` + `dependsOn` explicito
C) Usando a propriedade `scope`
D) Criando um nested template

<details>
<summary>Ver resposta</summary>

**Resposta: B) Usando nome composto `"vaultName/policyName"` + `dependsOn` explicito**

Em ARM JSON, recursos filhos usam nome composto (`[format('{0}/{1}', vaultName, policyName)]`) e `dependsOn` explicito apontando para o recurso pai. Em Bicep, usa-se `parent:` que gera automaticamente o nome composto e dependsOn. A propriedade `scope` e para extension resources.

</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```bash
# Pausar
az vm deallocate -g az104-rg7 -n az104-vm-win --no-wait
az vm deallocate -g az104-rg7 -n az104-vm-linux --no-wait
az monitor metrics alert update -g az104-rg-monitor -n az104-vm-win-cpu-alert --enabled false

# Retomar
az vm start -g az104-rg7 -n az104-vm-win --no-wait
az vm start -g az104-rg7 -n az104-vm-linux --no-wait
az monitor metrics alert update -g az104-rg-monitor -n az104-vm-win-cpu-alert --enabled true
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia.

---

# Cleanup

> **IMPORTANTE:** Antes de excluir os Resource Groups, voce DEVE desabilitar
> o backup e excluir os itens protegidos. O vault nao pode ser excluido com
> itens protegidos ativos. O Backup Vault tambem requer remover backup instances antes da exclusao.

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos do lab
# ============================================================

# 1. Desabilitar soft delete do vault (necessario para exclusao)
az backup vault backup-properties set \
    --name "$VAULT_NAME" \
    -g "$RG11" \
    --soft-delete-feature-state Disable

# 2. Listar e desabilitar backup de VMs
CONTAINER_VM=$(az backup container list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureIaasVM \
    --query "[0].name" -o tsv)

ITEM_VM=$(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureIaasVM \
    --query "[0].name" -o tsv)

if [ -n "$ITEM_VM" ]; then
    az backup protection disable \
        --container-name "$CONTAINER_VM" \
        --item-name "$ITEM_VM" \
        --vault-name "$VAULT_NAME" \
        -g "$RG11" \
        --delete-backup-data true \
        --yes
    echo "Backup de VM desabilitado e dados excluidos"
fi

# 3. Listar e desabilitar backup de File Shares
CONTAINER_FS=$(az backup container list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureStorage \
    --query "[0].name" -o tsv)

ITEM_FS=$(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --backup-management-type AzureStorage \
    --query "[0].name" -o tsv)

if [ -n "$ITEM_FS" ]; then
    az backup protection disable \
        --container-name "$CONTAINER_FS" \
        --item-name "$ITEM_FS" \
        --vault-name "$VAULT_NAME" \
        -g "$RG11" \
        --delete-backup-data true \
        --yes
    echo "Backup de File Share desabilitado e dados excluidos"
fi

# 4. Excluir o vault
az backup vault delete --name "$VAULT_NAME" -g "$RG11" --yes --force
echo "Recovery Services Vault excluido"

# 5. Desabilitar backup instances no Backup Vault (Bloco 6)
echo "5. Desabilitando Backup Vault instances..."
BV_INSTANCES=$(az dataprotection backup-instance list \
    -g az104-rg-bv --vault-name az104-bv \
    --query "[].name" -o tsv 2>/dev/null)

for INST in $BV_INSTANCES; do
    az dataprotection backup-instance stop-protection \
        -g az104-rg-bv --vault-name az104-bv \
        --backup-instance-name "$INST" 2>/dev/null
    az dataprotection backup-instance delete \
        -g az104-rg-bv --vault-name az104-bv \
        --backup-instance-name "$INST" --yes 2>/dev/null
    echo "  Backup instance $INST removida"
done

# 6. Excluir Resource Groups (em paralelo com --no-wait)
az group delete --name "$RG11" --yes --no-wait
az group delete --name "$RG12" --yes --no-wait
az group delete --name "$RG13" --yes --no-wait
az group delete --name az104-rg-bv --yes --no-wait
az group delete --name az104-rg-moved --yes --no-wait 2>/dev/null

echo ""
echo "=== Cleanup iniciado ==="
echo "RGs sendo excluidos em background: $RG11, $RG12, $RG13, az104-rg-bv, az104-rg-moved"
echo "Verifique com: az group list --query \"[?starts_with(name,'az104-rg')].name\" -o tsv"
```

---

## Resumo de Templates Criados

| Template | Tipo | Scope | Recursos |
|----------|------|-------|----------|
| `bloco1-vm.json` | ARM | Resource Group | NSG, PIP, VNet, NIC, VM |
| `bloco1-rsv.json` | ARM | Resource Group | Recovery Services Vault |
| `bloco1-backup-policy.json` | ARM | Resource Group | Backup Policy (VM) |
| `bloco2-storage.json` | ARM | Resource Group | Storage Account, Blob/File Services, File Share |
| `bloco2-fileshare-policy.json` | ARM | Resource Group | Backup Policy (File Share) |
| `bloco3-asr-infra.json` | ARM | Resource Group | ASR Fabrics (2), Protection Containers (2) |
| `bloco3-asr-policy.json` | ARM | Resource Group | Replication Policy |
| `bloco4-action-group.json` | ARM | Resource Group | Action Group |
| `bloco4-metric-alert.json` | ARM | Resource Group | Metric Alert Rule |
| `bloco4-diagnostics.json` | ARM | Resource Group | Diagnostic Settings |
| `bloco5-law.json` | ARM | Resource Group | Log Analytics Workspace |
| `bloco5-ama-extension.json` | ARM | Resource Group | VM Extension (AMA) |
| `bloco5-dcr.json` | ARM | Resource Group | Data Collection Rule |
| `bloco5-saved-searches.json` | ARM | Resource Group | Saved Searches (4 KQL queries) |
| `bloco6-backup-vault.json` | ARM | Resource Group | Backup Vault (LRS) + disk backup policy |

---

## Operacoes que NAO sao ARM (e por que)

| Operacao | Motivo | Alternativa |
|----------|--------|-------------|
| Backup on-demand | Acao imperativa (executar agora) | CLI: `az backup protection backup-now` |
| Restore VM/File Share | Acao imperativa | CLI: `az backup restore` |
| Failover ASR | Acao imperativa de emergencia | CLI/Portal |
| Container Mapping | Configuracao complexa de ASR | CLI: `az rest` |
| Recovery Plan | Orquestracao de failover | CLI: `az rest` |
| KQL queries (ad-hoc) | Leitura/consulta, nao provisionamento | CLI: `az rest --method post --url <workspace-id>/api/query` |
| Connection Monitor | Monitoramento de rede | CLI: `az network watcher connection-monitor` |
| Network Watcher enable | Configuracao regional | CLI: `az network watcher configure` |
| VM Move entre RGs | Operacao imperativa (`az resource move`) | CLI: `az resource move --destination-group` |
| Disk backup instance | Depende de IDs existentes + role assignments | CLI: `az dataprotection backup-instance create` |

---

## Checklist Final

- [ ] **Bloco 1:** VM + RSV + Backup Policy + Protecao habilitada
- [ ] **Bloco 2:** Storage Account + File Share + Soft Delete + Backup protegido
- [ ] **Bloco 3:** ASR Fabrics + Containers + Replication Policy + Container Mapping
- [ ] **Bloco 4:** Action Group + Metric Alert + Diagnostic Settings
- [ ] **Bloco 5:** Log Analytics Workspace + AMA Agent + DCR + Saved Searches + Connection Monitor
- [ ] **Bloco 6:** Backup Vault + Disk Policy + VM Move + Disk Backup Instance
- [ ] **Cleanup:** Backup desabilitado → Vault excluido → Backup instances removidas → RGs excluidos
