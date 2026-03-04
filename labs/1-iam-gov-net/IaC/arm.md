# Lab AZ-104 - Semana 1: Tudo via ARM Templates (JSON)

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI ja vem pre-instalado
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.json`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab unificado v2 (~49 recursos) usando ARM Templates JSON + CLI.
> Cada template inclui boilerplate completo e e fortemente comentado.

---

## Pre-requisitos: Cloud Shell e Conceitos ARM Template

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (Bash)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui Azure CLI pre-instalado e a autenticacao e automatica.
> Para criar os arquivos `.json`, use o editor integrado: `code nome-do-arquivo.json`

Antes de comecar, entenda a estrutura de um ARM template:

```json
{
    // 1. Schema: define ONDE o template sera deployado
    //    - deploymentTemplate: resource group (padrao)
    //    - subscriptionDeploymentTemplate: subscription
    //    - managementGroupDeploymentTemplate: management group
    //    - tenantDeploymentTemplate: tenant
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
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "myVnet",
            "location": "[parameters('location')]",
            "dependsOn": [],  // EXPLICITO! (diferente do Bicep que e implicito)
            "properties": { }
        }
    ],

    // 6. Outputs: valores exportados apos deploy
    "outputs": {
        "vnetId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Network/virtualNetworks', 'myVnet')]"
        }
    }
}
```

> **ARM vs Bicep:** Em Bicep, dependencias sao **implicitas** (detectadas automaticamente).
> Em ARM JSON, voce PRECISA declarar `dependsOn` explicitamente quando um recurso depende de outro.

### Funcoes ARM Essenciais

| Funcao | Uso | Exemplo |
|--------|-----|---------|
| `[parameters('x')]` | Ler parametro | `[parameters('location')]` |
| `[variables('x')]` | Ler variavel | `[variables('vnetName')]` |
| `[resourceId(...)]` | ID de recurso | `[resourceId('Microsoft.Network/virtualNetworks', 'myVnet')]` |
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

# Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"

# ============================================================
# VARIAVEIS GLOBAIS
# ============================================================
TENANT_DOMAIN="seudominio.onmicrosoft.com"           # ← ALTERE
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" # ← ALTERE
GUEST_EMAIL="seuemail@gmail.com"                       # ← ALTERE
GUEST_DISPLAY_NAME="Seu Nome"                          # ← ALTERE
LOCATION="eastus"
VM_USERNAME="localadmin"
VM_PASSWORD='SenhaComplexa@2024!'                      # ← ALTERE
RG2="az104-rg2"
RG3="az104-rg3"
RG4="az104-rg4"
RG5="az104-rg5"
MG_NAME="az104-mg1"
```

---

## Mapa de Dependencias

```
Bloco 1 (Identity) → CLI fallback (Entra ID ≠ ARM)
  │
  ▼
Bloco 2 (Governance) → ARM templates + CLI
  │
  ▼
Bloco 3 (IaC) → ARM template parametrizado
  │
  ▼
Bloco 4 (Networking) → ARM templates
  │
  ▼
Bloco 5 (Connectivity) → ARM templates + CLI
```

---

# Bloco 1 - Identity

**Tecnologia:** Azure CLI (fallback)

> **POR QUE CLI E NAO ARM?** O Entra ID (antigo Azure AD) NAO e um recurso ARM.
> ARM Templates gerenciam apenas recursos do Azure Resource Manager
> (VMs, VNets, discos, policies, etc.). Usuarios, grupos e convites B2B sao
> gerenciados pela **Microsoft Graph API**, que tem schema e endpoint separados.
>
> **Em Bicep isso seria:** Igualmente impossivel — Bicep compila para ARM JSON,
> entao tem as mesmas limitacoes de escopo.

---

### Task 1.1: Criar usuario az104-user1

```bash
# ============================================================
# TASK 1.1 - Criar usuario (CLI — nao e recurso ARM)
# ============================================================
PASSWORD="Az104Lab@$RANDOM"

az ad user create \
    --display-name "az104-user1" \
    --user-principal-name "az104-user1@${TENANT_DOMAIN}" \
    --password "$PASSWORD" \
    --force-change-password-next-sign-in true

echo "=== SALVE ESTA SENHA ==="
echo "UPN: az104-user1@${TENANT_DOMAIN}"
echo "Senha: $PASSWORD"

USER1_ID=$(az ad user show --id "az104-user1@${TENANT_DOMAIN}" --query id -o tsv)

# Atualizar propriedades via Graph API
az rest --method PATCH \
    --url "https://graph.microsoft.com/v1.0/users/${USER1_ID}" \
    --body '{"jobTitle":"IT Lab Administrator","department":"IT","usageLocation":"US"}'
```

---

### Task 1.2: Convidar usuario externo (Guest/B2B)

```bash
# ============================================================
# TASK 1.2 - Convidar guest (Graph API — nao e ARM)
# ============================================================
az rest --method POST \
    --url "https://graph.microsoft.com/v1.0/invitations" \
    --body "{
        \"invitedUserEmailAddress\": \"${GUEST_EMAIL}\",
        \"invitedUserDisplayName\": \"${GUEST_DISPLAY_NAME}\",
        \"inviteRedirectUrl\": \"https://portal.azure.com\",
        \"sendInvitationMessage\": true,
        \"invitedUserMessageInfo\": {
            \"customizedMessageBody\": \"Welcome to Azure and our group project\"
        }
    }"

GUEST_ID=$(az ad user list --filter "mail eq '${GUEST_EMAIL}'" --query "[0].id" -o tsv)

az rest --method PATCH \
    --url "https://graph.microsoft.com/v1.0/users/${GUEST_ID}" \
    --body '{"jobTitle":"IT Lab Administrator","department":"IT","usageLocation":"US"}'

echo ">>> ACEITE O CONVITE NO EMAIL ANTES DE CONTINUAR <<<"
```

---

### Task 1.3: Criar grupo IT Lab Administrators

```bash
# ============================================================
# TASK 1.3 - Criar grupo (CLI — nao e ARM)
# ============================================================
az ad group create \
    --display-name "IT Lab Administrators" \
    --mail-nickname "itlabadmins" \
    --description "Administrators that manage the IT lab"

ITLAB_GROUP_ID=$(az ad group show --group "IT Lab Administrators" --query id -o tsv)

az ad group member add --group "$ITLAB_GROUP_ID" --member-id "$USER1_ID"
az ad group member add --group "$ITLAB_GROUP_ID" --member-id "$GUEST_ID"

az ad group member list --group "$ITLAB_GROUP_ID" --query "[].{name:displayName, type:userType}" -o table
```

---

### Task 1.4: Criar grupo helpdesk

```bash
# ============================================================
# TASK 1.4 - Criar grupo helpdesk
# ============================================================
az ad group create \
    --display-name "helpdesk" \
    --mail-nickname "helpdesk" \
    --description "Helpdesk team for support and VM access"

HELPDESK_GROUP_ID=$(az ad group show --group "helpdesk" --query id -o tsv)
az ad group member add --group "$HELPDESK_GROUP_ID" --member-id "$USER1_ID"
```

---

## Modo Desafio - Bloco 1

- [ ] Criar `az104-user1` + atualizar via Graph API
- [ ] Convidar guest via `az rest` + aceitar convite
- [ ] Criar grupo `IT Lab Administrators` com 2 membros
- [ ] Criar grupo `helpdesk` com 1 membro

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Tipo de membership para adicionar/remover membros automaticamente por departamento?**

A) Assigned  B) Dynamic user  C) Dynamic device  D) Microsoft 365

<details><summary>Ver resposta</summary>**Resposta: B) Dynamic user** — requer Entra ID Premium P1/P2.</details>

### Questao 1.2
**User type de um convidado B2B?**

A) Member  B) Guest  C) External  D) Federated

<details><summary>Ver resposta</summary>**Resposta: B) Guest**</details>

### Questao 1.3
**Propriedade obrigatoria para atribuir licencas?**

A) Department  B) Job title  C) Usage location  D) Manager

<details><summary>Ver resposta</summary>**Resposta: C) Usage location**</details>

---

# Bloco 2 - Governance & Compliance

**Tecnologia:** ARM Templates JSON + CLI
**Recursos criados:** MG, RGs, RBAC, custom role, policies, lock

---

### Task 2.1: Criar Management Group e mover subscription

```bash
# ============================================================
# TASK 2.1 - Management Group (CLI - operacao de controle)
# ============================================================
az account management-group create --name "$MG_NAME" --display-name "$MG_NAME"

az account management-group subscription add \
    --name "$MG_NAME" \
    --subscription "$SUBSCRIPTION_ID"

az account management-group show --name "$MG_NAME" --expand --recurse
```

---

### Task 2.2: Atribuir VM Contributor (CLI)

```bash
# ============================================================
# TASK 2.2 - RBAC no MG (CLI)
# ============================================================
az role assignment create \
    --assignee "$ITLAB_GROUP_ID" \
    --role "Virtual Machine Contributor" \
    --scope "/providers/Microsoft.Management/managementGroups/$MG_NAME"
```

---

### Task 2.3: Criar custom RBAC role via ARM

Salve como **`bloco2-custom-role.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "roleName": {
            "type": "string",
            "defaultValue": "Custom Support Request",
            "metadata": {
                "description": "Nome da role customizada"
            }
        }
    },
    "variables": {
        "roleDefName": "[guid(managementGroup().id, parameters('roleName'))]"
    },
    "resources": [
        {
            "type": "Microsoft.Authorization/roleDefinitions",
            "apiVersion": "2022-04-01",
            "name": "[variables('roleDefName')]",
            "properties": {
                "roleName": "[parameters('roleName')]",
                "description": "A custom contributor role for support requests.",
                "type": "CustomRole",
                "permissions": [
                    {
                        "actions": [
                            "*/read",
                            "Microsoft.Support/*"
                        ],
                        "notActions": [
                            "Microsoft.Support/register/action"
                        ]
                    }
                ],
                "assignableScopes": [
                    "[managementGroup().id]"
                ]
            }
        }
    ],
    "outputs": {
        "roleId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Authorization/roleDefinitions', variables('roleDefName'))]"
        }
    }
}
```

> **Comparacao com Bicep:** Note as diferencas:
> - ARM: `"[guid(managementGroup().id, parameters('roleName'))]"` — funcoes entre colchetes
> - Bicep: `guid(managementGroup().id, roleName)` — chamada direta, sem colchetes/aspas
> - ARM: schema diferente para cada scope
> - Bicep: `targetScope = 'managementGroup'` — uma linha

Deploy:

```bash
az deployment mg create \
    --management-group-id "$MG_NAME" \
    --location "$LOCATION" \
    --template-file bloco2-custom-role.json
```

---

### Task 2.4: Monitorar role assignments via Activity Log

> **Por que CLI?** O Activity Log e uma operacao de **leitura** (query), nao de provisionamento. Nao existe template ARM para consultar logs — isso e feito via CLI ou PowerShell.
> **Em Bicep:** Mesma limitacao — Activity Log nao e um recurso declarativo.

```bash
# Consultar Activity Log para operacoes de role assignment recentes
az monitor activity-log list \
    --resource-provider "Microsoft.Authorization" \
    --offset 1h \
    --query "[?contains(operationName.value, 'roleAssignments')].{Time:eventTimestamp, Op:operationName.value, Status:status.value, Caller:caller}" \
    --output table
```

> **Conceito:** O Activity Log registra TODAS as operacoes de controle (management plane) na subscription. Util para auditoria de quem fez o que, quando. Retencao padrao: 90 dias.

---

### Task 2.5: Criar Resource Groups com tags via ARM

Salve como **`bloco2-rgs.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "eastus"
        },
        "costCenter": {
            "type": "string",
            "defaultValue": "000"
        }
    },
    "resources": [
        {
            "type": "Microsoft.Resources/resourceGroups",
            "apiVersion": "2023-07-01",
            "name": "az104-rg2",
            "location": "[parameters('location')]",
            "tags": {
                "Cost Center": "[parameters('costCenter')]"
            }
        },
        {
            "type": "Microsoft.Resources/resourceGroups",
            "apiVersion": "2023-07-01",
            "name": "az104-rg3",
            "location": "[parameters('location')]",
            "tags": {
                "Cost Center": "[parameters('costCenter')]"
            }
        }
    ]
}
```

> **Comparacao com Bicep:** `bloco2-rgs.bicep` tem 15 linhas. O ARM JSON equivalente tem ~30 linhas.
> O schema `subscriptionDeploymentTemplate.json` faz o papel do `targetScope = 'subscription'`.

Deploy:

```bash
# Deploy no scope de subscription
# Comando: 'az deployment sub create' (NAO 'group create')
az deployment sub create \
    --location "$LOCATION" \
    --template-file bloco2-rgs.json
```

---

### Task 2.6-2.7: Testar Deny policy e substituir por Modify

```bash
# ============================================================
# TASK 2.6 - Aplicar Deny, testar, remover (CLI)
# ============================================================
POLICY_DENY_ID=$(az policy definition list \
    --query "[?displayName=='Require a tag and its value on resources'].name" -o tsv)

az policy assignment create \
    --name "RequireCostCenterTag-rg2" \
    --display-name "Require Cost Center tag with value 000 on resources" \
    --policy "$POLICY_DENY_ID" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}" \
    --params '{"tagName":{"value":"Cost Center"},"tagValue":{"value":"000"}}'

echo "Aguarde 5-15 min para testar..."
```

```bash
# Testar (deve falhar) e remover
az disk create -g "$RG2" -n "test-deny" --size-gb 32 --sku Standard_LRS -l "$LOCATION" 2>&1 || \
    echo "✓ Policy Deny bloqueou!"

az policy assignment delete \
    --name "RequireCostCenterTag-rg2" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}"
```

---

### Task 2.7-2.8: Policies Modify via ARM (rg2)

Salve como **`bloco2-policies-rg2.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "tagName": {
            "type": "string",
            "defaultValue": "Cost Center"
        }
    },
    "variables": {
        "inheritPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54",
        "tagContributorRoleId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')]",
        "policyAssignmentName": "InheritCostCenter-rg2",
        "roleAssignmentName": "[guid(resourceGroup().id, variables('policyAssignmentName'), 'TagContributor')]"
    },
    "resources": [
        {
            "type": "Microsoft.Authorization/policyAssignments",
            "apiVersion": "2024-04-01",
            "name": "[variables('policyAssignmentName')]",
            "location": "[resourceGroup().location]",
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "displayName": "Inherit the Cost Center tag and its value 000 from the resource group if missing",
                "policyDefinitionId": "[variables('inheritPolicyId')]",
                "parameters": {
                    "tagName": {
                        "value": "[parameters('tagName')]"
                    }
                }
            }
        },
        {
            "type": "Microsoft.Authorization/roleAssignments",
            "apiVersion": "2022-04-01",
            "name": "[variables('roleAssignmentName')]",
            "dependsOn": [
                "[resourceId('Microsoft.Authorization/policyAssignments', variables('policyAssignmentName'))]"
            ],
            "properties": {
                "roleDefinitionId": "[variables('tagContributorRoleId')]",
                "principalId": "[reference(resourceId('Microsoft.Authorization/policyAssignments', variables('policyAssignmentName')), '2024-04-01', 'full').identity.principalId]",
                "principalType": "ServicePrincipal"
            }
        }
    ]
}
```

> **Comparacao com Bicep:**
> - ARM: `"dependsOn": ["[resourceId(...)]"]` — EXPLICITO, voce precisa declarar
> - Bicep: `principalId: policyAssignment.identity.principalId` — dependencia IMPLICITA
> - ARM: `"[reference(resourceId(...), '2024-04-01', 'full').identity.principalId]"` — verboso!
> - Bicep: `policyAssignment.identity.principalId` — direto e legivel

Deploy:

```bash
az deployment group create \
    --resource-group "$RG2" \
    --template-file bloco2-policies-rg2.json
```

---

### Task 2.8-2.10: Policies no rg3 + Reader role

Salve como **`bloco2-policies-rg3.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "tagName": {
            "type": "string",
            "defaultValue": "Cost Center"
        },
        "guestUserId": {
            "type": "string",
            "metadata": {
                "description": "Object ID do guest user para Reader role"
            }
        }
    },
    "variables": {
        "inheritPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54",
        "allowedLocationsPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c",
        "tagContributorRoleId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')]",
        "readerRoleId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')]",
        "inheritAssignmentName": "InheritCostCenter-rg3",
        "allowedLocAssignmentName": "AllowedLocations-rg3",
        "tagContributorGuid": "[guid(resourceGroup().id, variables('inheritAssignmentName'), 'TagContributor')]",
        "readerGuid": "[guid(resourceGroup().id, parameters('guestUserId'), 'Reader')]"
    },
    "resources": [
        {
            "type": "Microsoft.Authorization/policyAssignments",
            "apiVersion": "2024-04-01",
            "name": "[variables('inheritAssignmentName')]",
            "location": "[resourceGroup().location]",
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "displayName": "Inherit Cost Center tag on az104-rg3 resources",
                "policyDefinitionId": "[variables('inheritPolicyId')]",
                "parameters": {
                    "tagName": {
                        "value": "[parameters('tagName')]"
                    }
                }
            }
        },
        {
            "type": "Microsoft.Authorization/roleAssignments",
            "apiVersion": "2022-04-01",
            "name": "[variables('tagContributorGuid')]",
            "dependsOn": [
                "[resourceId('Microsoft.Authorization/policyAssignments', variables('inheritAssignmentName'))]"
            ],
            "properties": {
                "roleDefinitionId": "[variables('tagContributorRoleId')]",
                "principalId": "[reference(resourceId('Microsoft.Authorization/policyAssignments', variables('inheritAssignmentName')), '2024-04-01', 'full').identity.principalId]",
                "principalType": "ServicePrincipal"
            }
        },
        {
            "type": "Microsoft.Authorization/policyAssignments",
            "apiVersion": "2024-04-01",
            "name": "[variables('allowedLocAssignmentName')]",
            "properties": {
                "displayName": "Restrict resources to East US only",
                "policyDefinitionId": "[variables('allowedLocationsPolicyId')]",
                "parameters": {
                    "listOfAllowedLocations": {
                        "value": [ "eastus" ]
                    }
                }
            }
        },
        {
            "type": "Microsoft.Authorization/roleAssignments",
            "apiVersion": "2022-04-01",
            "name": "[variables('readerGuid')]",
            "properties": {
                "roleDefinitionId": "[variables('readerRoleId')]",
                "principalId": "[parameters('guestUserId')]",
                "principalType": "User"
            }
        }
    ]
}
```

Salve como **`bloco2-policies-rg3.parameters.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "guestUserId": {
            "value": "ALTERE_COM_GUEST_ID"
        }
    }
}
```

Deploy:

```bash
# Atualizar o parameter file com o guest ID real
sed -i "s/ALTERE_COM_GUEST_ID/$GUEST_ID/" bloco2-policies-rg3.parameters.json

az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco2-policies-rg3.json \
    --parameters @bloco2-policies-rg3.parameters.json

echo "Policies + Reader atribuidos ao $RG3"
echo ">>> Aguarde 5-15 min para as policies entrarem em vigor <<<"
```

---

### Task 2.11: Resource Lock via ARM

Salve como **`bloco2-lock.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "resources": [
        {
            "type": "Microsoft.Authorization/locks",
            "apiVersion": "2020-05-01",
            "name": "rg-lock",
            "properties": {
                "level": "CanNotDelete",
                "notes": "Protege o resource group contra exclusao acidental"
            }
        }
    ]
}
```

> **Comparacao com Bicep:** Identico em estrutura, mas ARM exige `$schema`, `contentVersion`,
> e o array `resources`. Em Bicep bastaria 6 linhas.

Deploy:

```bash
az deployment group create \
    --resource-group "$RG2" \
    --template-file bloco2-lock.json

# Testar exclusao
az group delete --name "$RG2" --yes 2>&1 || echo "✓ Lock impediu exclusao!"
```

---

### Task 2.12: Criar Policy Initiative via ARM Template

> **Conceito:** Uma **Initiative** (Policy Set) agrupa multiplas policy definitions
> em um conjunto unico. Em vez de atribuir 3 policies individualmente,
> voce atribui 1 initiative. Isso simplifica governanca em escala.
>
> Neste lab, ja atribuimos as policies individualmente (Tasks 2.6-2.9).
> Agora criamos uma initiative para aprender o conceito.

Salve como **`bloco2-initiative.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "variables": {
        "requireTagPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62",
        "inheritTagPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54",
        "allowedLocationsPolicyId": "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    },
    "resources": [
        {
            "type": "Microsoft.Authorization/policySetDefinitions",
            "apiVersion": "2023-04-01",
            "name": "az104-governance-initiative",
            "properties": {
                "displayName": "AZ-104 Lab Governance Initiative",
                "description": "Agrupa 3 policies: require tag, inherit tag, allowed locations",
                "policyType": "Custom",
                "parameters": {
                    "tagName": {
                        "type": "String",
                        "metadata": {
                            "displayName": "Tag Name",
                            "description": "Nome da tag obrigatoria (ex: Cost Center)"
                        }
                    },
                    "tagValue": {
                        "type": "String",
                        "metadata": {
                            "displayName": "Tag Value",
                            "description": "Valor obrigatorio da tag (ex: 000)"
                        }
                    },
                    "allowedLocations": {
                        "type": "Array",
                        "metadata": {
                            "displayName": "Allowed Locations",
                            "description": "Lista de regioes permitidas"
                        }
                    }
                },
                "policyDefinitions": [
                    {
                        "policyDefinitionId": "[variables('requireTagPolicyId')]",
                        "parameters": {
                            "tagName":  { "value": "[parameters('tagName')]" },
                            "tagValue": { "value": "[parameters('tagValue')]" }
                        }
                    },
                    {
                        "policyDefinitionId": "[variables('inheritTagPolicyId')]",
                        "parameters": {
                            "tagName": { "value": "[parameters('tagName')]" }
                        }
                    },
                    {
                        "policyDefinitionId": "[variables('allowedLocationsPolicyId')]",
                        "parameters": {
                            "listOfAllowedLocations": { "value": "[parameters('allowedLocations')]" }
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "initiativeId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Authorization/policySetDefinitions', 'az104-governance-initiative')]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: 80+ linhas com boilerplate JSON completo (`$schema`, `contentVersion`, `variables`, `outputs`)
> - Bicep: ~60 linhas, sem boilerplate, variaveis com `var`, sintaxe limpa
> - ARM: references via `[variables('...')]` e `[parameters('...')]`
> - Bicep: references diretas por nome simbolico
> - Note o schema `subscriptionDeploymentTemplate` (scope subscription)

Deploy:

```bash
# Deploy no scope de subscription
az deployment sub create \
    --location "$LOCATION" \
    --template-file bloco2-initiative.json

# Verificar criacao
az policy set-definition show \
    --name "az104-governance-initiative" \
    --query "{name:name, displayName:displayName, policies:length(policyDefinitions)}" \
    -o table
```

> **Conceito AZ-104:**
> - **Policy Definition**: regra individual (ex: "require tag")
> - **Policy Set Definition (Initiative)**: grupo de regras relacionadas
> - **Policy Assignment**: aplicacao de uma definition OU initiative a um scope
> - Em producao, initiatives sao o padrao — policies individuais sao raras
> - Initiatives built-in do Azure: "CIS Benchmark", "NIST 800-53", "ISO 27001"

---

### Task 2.13: Teste de integracao — Verificar acesso do az104-user1

Aqui voce valida que o RBAC configurado neste bloco funciona com o usuario do Bloco 1.

> **Por que CLI?** Teste de acesso e uma verificacao manual/operacional, nao provisionamento de recurso.
> **Em Bicep:** Mesma limitacao — testes de acesso nao sao recursos declarativos.

```bash
# Verificar roles atribuidos ao grupo IT Lab Administrators
az role assignment list \
    --assignee "$IT_LAB_GROUP_ID" \
    --all \
    --query "[].{Role:roleDefinitionName, Scope:scope}" \
    --output table

echo ""
echo "=== O que az104-user1 PODE fazer ==="
echo "  ✓ Gerenciar VMs (VM Contributor no MG)"
echo "  ✓ Ver recursos no az104-rg3 (heranca do MG)"
echo ""
echo "=== O que az104-user1 NAO PODE fazer ==="
echo "  ✗ Criar Storage Accounts (VM Contributor nao inclui Storage)"
echo "  ✗ Deletar az104-rg2 (Lock impede + sem permissao)"
echo ""
echo "Para validar manualmente:"
echo "  1. Abra janela InPrivate/Incognito"
echo "  2. Login como az104-user1@${TENANT_DOMAIN}"
echo "  3. Tente criar Storage Account no az104-rg2 → deve FALHAR"
echo "  4. Feche a janela InPrivate"
```

---

## Modo Desafio - Bloco 2

- [ ] MG + mover subscription (CLI)
- [ ] VM Contributor no MG (CLI)
- [ ] Deploy `bloco2-custom-role.json` no scope managementGroup
- [ ] Deploy `bloco2-rgs.json` no scope subscription
- [ ] Testar Deny → remover (CLI)
- [ ] Deploy `bloco2-policies-rg2.json` (Modify + Tag Contributor)
- [ ] Deploy `bloco2-policies-rg3.json` com parameter file
- [ ] Deploy `bloco2-lock.json` → testar exclusao
- [ ] Deploy `bloco2-initiative.json` no scope subscription (Policy Initiative)
- [ ] Teste de integracao com az104-user1 em InPrivate

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**VM Contributor no MG. Membro tenta criar Storage. O que acontece?**

A) Permitida  B) Falha — sem permissao de Storage  C) Permitida no MG  D) Depende do RG

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 2.2
**Qual schema ARM voce usa para deploy no scope de subscription?**

A) `deploymentTemplate.json`
B) `subscriptionDeploymentTemplate.json`
C) `managementGroupDeploymentTemplate.json`
D) `tenantDeploymentTemplate.json`

<details>
<summary>Ver resposta</summary>

**Resposta: B) subscriptionDeploymentTemplate.json**

| Scope | Schema |
|-------|--------|
| Resource Group | `deploymentTemplate.json` |
| Subscription | `subscriptionDeploymentTemplate.json` |
| Management Group | `managementGroupDeploymentTemplate.json` |
| Tenant | `tenantDeploymentTemplate.json` |

Em Bicep, usa-se `targetScope` — muito mais simples.

</details>

### Questao 2.3
**Em ARM JSON, como voce declara que recurso B depende do recurso A?**

A) Automaticamente detectado
B) `"dependsOn": ["[resourceId('type', 'nameA')]"]`
C) `"requires": "nameA"`
D) Nao e possivel

<details>
<summary>Ver resposta</summary>

**Resposta: B) `"dependsOn": ["[resourceId('type', 'nameA')]"]`**

Em ARM JSON, dependencias sao **explicitas** via `dependsOn`.
Em Bicep, sao **implicitas** — detectadas automaticamente quando um recurso referencia outro.

</details>

### Questao 2.4
**Owner tenta excluir RG com Delete lock?**

A) Excluido  B) Bloqueado — locks sobrescrevem  C) Alerta  D) Bloqueado sem Owner

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 2.5
**Qual a diferenca entre Policy Definition e Policy Initiative (Policy Set)?**

A) Initiative e uma policy com efeito mais forte
B) Initiative agrupa multiplas policy definitions em um conjunto unico
C) Initiative substitui policy definitions — nao podem coexistir
D) Initiative so funciona com policies custom, nao built-in

<details><summary>Ver resposta</summary>

**Resposta: B)** Initiative agrupa policies em um conjunto unico. Pode conter built-in E custom.

</details>

### Questao 2.6
**Reader role permite...?**

A) Criar e modificar  B) Apenas visualizar  C) Gerenciar VMs  D) Nada para guests

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

---

# Bloco 3 - Azure Resources & IaC

**Tecnologia:** ARM Template parametrizado
**Recursos criados:** 5 managed disks em az104-rg3

---

### Task 3.1-3.5: Template parametrizado para discos

Salve como **`bloco3-disk.json`** (template):

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "diskName": {
            "type": "string",
            "metadata": {
                "description": "Nome do managed disk"
            }
        },
        "diskSizeGB": {
            "type": "int",
            "defaultValue": 32,
            "minValue": 4,
            "maxValue": 32767,
            "metadata": {
                "description": "Tamanho do disco em GiB"
            }
        },
        "diskSku": {
            "type": "string",
            "defaultValue": "Standard_LRS",
            "allowedValues": [
                "Standard_LRS",
                "StandardSSD_LRS",
                "Premium_LRS",
                "UltraSSD_LRS"
            ],
            "metadata": {
                "description": "Tipo de disco (SKU)"
            }
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Localizacao do disco"
            }
        }
    },
    "resources": [
        {
            "type": "Microsoft.Compute/disks",
            "apiVersion": "2023-10-02",
            "name": "[parameters('diskName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "[parameters('diskSku')]"
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

Salve como **`bloco3-disk.parameters.json`** (arquivo de parametros):

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "diskName": {
            "value": "az104-disk1"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"minValue": 4, "maxValue": 32767` — no objeto do parametro
> - Bicep: `@minValue(4) @maxValue(32767)` — decorators mais legíveis
> - ARM: `"allowedValues": [...]` — array no parametro
> - Bicep: `@allowed([...])` — decorator conciso
> - ARM: Nao tem **loop nativo** como o `for` do Bicep. Para criar 5 discos,
>   usa-se `copy` (mais verboso) ou deploya-se 5 vezes com parametros diferentes.

Deploy dos 5 discos:

```bash
# ============================================================
# Deploy dos 5 discos - reutilizando o mesmo template
# ============================================================

# Disco 1 (usando parameter file)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters @bloco3-disk.parameters.json

# Verificar tag herdada
echo "=== Tag do az104-disk1 ==="
az disk show -g "$RG3" -n az104-disk1 --query tags -o json

# Disco 2 (parametro inline)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters diskName=az104-disk2

# Disco 3
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters diskName=az104-disk3

# Disco 4
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters diskName=az104-disk4

# Disco 5 (StandardSSD)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters diskName=az104-disk5 diskSku=StandardSSD_LRS

# Verificar todos
echo ""
echo "=== Todos os discos ==="
az disk list -g "$RG3" --query "[].{name:name, size:diskSizeGb, sku:sku.name, tags:tags}" -o table
```

> **Alternativa ARM: copy loop** (educativo):
> ```json
> {
>     "copy": {
>         "name": "diskLoop",
>         "count": 5
>     },
>     "type": "Microsoft.Compute/disks",
>     "name": "[concat('az104-disk', copyIndex(1))]",
>     ...
> }
> ```
> Em Bicep: `resource disks 'type' = [for i in range(1,5): { name: 'az104-disk${i}' }]` — mais legivel.

---

### Task 3.6: Teste Allowed Locations

```bash
# Tentar deploy em West US (deve falhar!)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.json \
    --parameters diskName=az104-disk-test location=westus 2>&1 || \
    echo "✓ Policy Allowed Locations bloqueou!"

az disk list -g "$RG3" --query "length(@)"
# Esperado: 5
```

---

### Task 3.7: Teste Guest user (informativo)

```bash
az role assignment list -g "$RG3" --assignee "$GUEST_ID" \
    --query "[].{role:roleDefinitionName}" -o table
echo "Guest: Reader (somente leitura)"
```

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-disk.json` com parameter file (disk1)
- [ ] Deploy disks 2-4 com parametros inline
- [ ] Deploy disk5 com `diskSku=StandardSSD_LRS`
- [ ] Verificar tags herdadas em todos os discos
- [ ] Testar `location=westus` → bloqueado

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Policy Modify no rg3. Disco criado via ARM sem tags. Tags?**

A) Sem tags  B) Herda Cost Center = 000  C) Deploy falha  D) Non-compliant

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 3.2
**Qual comando deploya ARM template em Resource Group?**

A) `az deployment sub create`  B) `az deployment group create`  C) `az template deploy`  D) `az arm deploy`

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 3.3
**Em ARM JSON, como criar multiplas copias de um recurso?**

A) Loop `for`  B) Elemento `copy` com `copyIndex()`  C) Array em `resources`  D) Nao e possivel

<details>
<summary>Ver resposta</summary>

**Resposta: B) Elemento `copy` com `copyIndex()`**

ARM JSON usa `copy` para loops. Bicep usa `for` — sintaticamente mais simples.

</details>

---

# Bloco 4 - Virtual Networking

**Tecnologia:** ARM Templates JSON
**Recursos criados:** 2 VNets, subnets, ASG, NSG, DNS zones, VNet link

---

### Task 4.1-4.4: VNets + ASG + NSG

Salve como **`bloco4-networking.json`**:

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
            "name": "CoreServicesVnet",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkSecurityGroups', 'myNSGSecure')]"
            ],
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [ "10.20.0.0/16" ]
                },
                "subnets": [
                    {
                        "name": "SharedServicesSubnet",
                        "properties": {
                            "addressPrefix": "10.20.10.0/24",
                            "networkSecurityGroup": {
                                "id": "[resourceId('Microsoft.Network/networkSecurityGroups', 'myNSGSecure')]"
                            }
                        }
                    },
                    {
                        "name": "DatabaseSubnet",
                        "properties": {
                            "addressPrefix": "10.20.20.0/24"
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "ManufacturingVnet",
            "location": "[parameters('location')]",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [ "10.30.0.0/16" ]
                },
                "subnets": [
                    {
                        "name": "SensorSubnet1",
                        "properties": {
                            "addressPrefix": "10.30.20.0/24"
                        }
                    },
                    {
                        "name": "SensorSubnet2",
                        "properties": {
                            "addressPrefix": "10.30.21.0/24"
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/applicationSecurityGroups",
            "apiVersion": "2023-05-01",
            "name": "asg-web",
            "location": "[parameters('location')]"
        },
        {
            "type": "Microsoft.Network/networkSecurityGroups",
            "apiVersion": "2023-05-01",
            "name": "myNSGSecure",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/applicationSecurityGroups', 'asg-web')]"
            ],
            "properties": {
                "securityRules": [
                    {
                        "name": "AllowASG",
                        "properties": {
                            "priority": 100,
                            "direction": "Inbound",
                            "access": "Allow",
                            "protocol": "Tcp",
                            "sourceApplicationSecurityGroups": [
                                {
                                    "id": "[resourceId('Microsoft.Network/applicationSecurityGroups', 'asg-web')]"
                                }
                            ],
                            "sourcePortRange": "*",
                            "destinationAddressPrefix": "*",
                            "destinationPortRanges": [ "80", "443" ]
                        }
                    },
                    {
                        "name": "DenyInternetOutbound",
                        "properties": {
                            "priority": 4096,
                            "direction": "Outbound",
                            "access": "Deny",
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*",
                            "destinationAddressPrefix": "Internet",
                            "destinationPortRange": "*"
                        }
                    }
                ]
            }
        }
    ]
}
```

> **Comparacao com Bicep:**
> - ARM: `"dependsOn"` explicito no NSG (→ ASG) e no VNet (→ NSG)
> - Bicep: `asg.id` e `nsg.id` criam dependencias **implicitas** automaticamente!
> - ARM precisa de `dependsOn` EXPLICITO em 2 lugares (NSG → ASG, VNet → NSG)
> - Bicep detectaria ambas as dependencias automaticamente

Deploy:

```bash
az group create --name "$RG4" --location "$LOCATION"

az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco4-networking.json
```

---

### Task 4.5-4.6: DNS zones

Salve como **`bloco4-dns.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "resources": [
        {
            "type": "Microsoft.Network/dnsZones",
            "apiVersion": "2023-07-01-preview",
            "name": "contoso.com",
            "location": "global"
        },
        {
            "type": "Microsoft.Network/dnsZones/A",
            "apiVersion": "2023-07-01-preview",
            "name": "contoso.com/www",
            "dependsOn": [
                "[resourceId('Microsoft.Network/dnsZones', 'contoso.com')]"
            ],
            "properties": {
                "TTL": 1,
                "ARecords": [
                    { "ipv4Address": "10.1.1.4" }
                ]
            }
        },
        {
            "type": "Microsoft.Network/privateDnsZones",
            "apiVersion": "2020-06-01",
            "name": "private.contoso.com",
            "location": "global"
        },
        {
            "type": "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
            "apiVersion": "2020-06-01",
            "name": "private.contoso.com/manufacturing-link",
            "location": "global",
            "dependsOn": [
                "[resourceId('Microsoft.Network/privateDnsZones', 'private.contoso.com')]"
            ],
            "properties": {
                "virtualNetwork": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks', 'ManufacturingVnet')]"
                },
                "registrationEnabled": false
            }
        },
        {
            "type": "Microsoft.Network/privateDnsZones/A",
            "apiVersion": "2020-06-01",
            "name": "private.contoso.com/sensorvm",
            "dependsOn": [
                "[resourceId('Microsoft.Network/privateDnsZones', 'private.contoso.com')]"
            ],
            "properties": {
                "ttl": 1,
                "aRecords": [
                    { "ipv4Address": "10.1.1.4" }
                ]
            }
        }
    ],
    "outputs": {
        "nameServers": {
            "type": "array",
            "value": "[reference(resourceId('Microsoft.Network/dnsZones', 'contoso.com')).nameServers]"
        }
    }
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "private.contoso.com/sensorvm"` — nome composto tipo/nome
> - Bicep: `parent: privateDns` + `name: 'sensorvm'` — mais claro com `parent`
> - ARM: `dependsOn` necessario para cada recurso filho
> - Bicep: `parent` cria dependencia implicita

Deploy:

```bash
az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco4-dns.json

NS=$(az network dns zone show -g "$RG4" -n contoso.com --query "nameServers[0]" -o tsv)
nslookup www.contoso.com "$NS"
```

---

## Modo Desafio - Bloco 4

- [ ] Deploy `bloco4-networking.json` (2 VNets + ASG + NSG)
- [ ] Deploy `bloco4-dns.json` (DNS public + private)
- [ ] Testar nslookup
- [ ] Notar os `dependsOn` explicitos (vs Bicep implicito)

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**NSG na SharedServicesSubnet. VM na DatabaseSubnet afetada?**

A) Sim  B) Nao, apenas subnet associada  C) Sim com ASG  D) Depende

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 4.2
**IPs utilizaveis em /24 no Azure?**

A) 256  B) 254  C) 251  D) 250

<details><summary>Ver resposta</summary>**Resposta: C) 251**</details>

### Questao 4.3
**Priority 100 Allow + Priority 200 Deny, porta 80?**

A) Negado  B) Permitido (100 primeiro)  C) Todas avaliadas  D) Mais Allow

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 4.4
**DNS public vs private?**

A) Public gratuita  B) Public internet, private VNets linkadas  C) Private mais tipos  D) Public VPN

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 4.5
**DNS privada linkada a VNet A. VM na VNet B resolve?**

A) Sim  B) Falha sem link  C) DNS publico  D) Com peering

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

---

# Bloco 5 - Intersite Connectivity

**Tecnologia:** ARM Templates + CLI
**Recursos criados:** subnets, VMs, peering, DNS, route table

---

### Task 5.1: Adicionar subnets (CLI)

```bash
az network vnet subnet create \
    --resource-group "$RG4" --vnet-name "CoreServicesVnet" \
    --name "Core" --address-prefixes "10.20.0.0/24"

az network vnet subnet create \
    --resource-group "$RG4" --vnet-name "ManufacturingVnet" \
    --name "Manufacturing" --address-prefixes "10.30.0.0/24"
```

---

### Task 5.2-5.3: Criar VMs via ARM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

Salve como **`bloco5-vms.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin"
        },
        "adminPassword": {
            "type": "securestring",
            "metadata": {
                "description": "Senha do admin"
            }
        },
        "vnetResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg4",
            "metadata": {
                "description": "RG onde as VNets estao (cross-RG reference)"
            }
        }
    },
    "variables": {
        "coreSubnetId": "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'Core')]",
        "mfgSubnetId": "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', 'ManufacturingVnet', 'Manufacturing')]"
    },
    "resources": [
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "CoreServicesVM-nic",
            "location": "[parameters('location')]",
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[variables('coreSubnetId')]"
                            }
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "ManufacturingVM-nic",
            "location": "[parameters('location')]",
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[variables('mfgSubnetId')]"
                            }
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2024-03-01",
            "name": "CoreServicesVM",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkInterfaces', 'CoreServicesVM-nic')]"
            ],
            "properties": {
                "hardwareProfile": {
                    "vmSize": "Standard_D2s_v3"
                },
                "osProfile": {
                    "computerName": "CoreServicesVM",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2025-datacenter-azure-edition",
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
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', 'CoreServicesVM-nic')]"
                        }
                    ]
                },
                "diagnosticsProfile": {
                    "bootDiagnostics": {
                        "enabled": false
                    }
                }
            }
        },
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2024-03-01",
            "name": "ManufacturingVM",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/networkInterfaces', 'ManufacturingVM-nic')]"
            ],
            "properties": {
                "hardwareProfile": {
                    "vmSize": "Standard_D2s_v3"
                },
                "osProfile": {
                    "computerName": "ManufacturingVM",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2025-datacenter-azure-edition",
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
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', 'ManufacturingVM-nic')]"
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
    "outputs": {
        "coreVmPrivateIp": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/networkInterfaces', 'CoreServicesVM-nic')).ipConfigurations[0].properties.privateIPAddress]"
        }
    }
}
```

> **Cross-RG reference em ARM:**
> ```json
> "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'Core')]"
> ```
> O primeiro parametro de `resourceId()` e o nome do RG. Quando omitido, assume o RG do deploy.
>
> **Em Bicep seria:**
> ```bicep
> resource coreVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
>   name: 'CoreServicesVnet'
>   scope: resourceGroup('az104-rg4')
> }
> ```

Salve como **`bloco5-vms.parameters.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "adminPassword": {
            "value": "ALTERE_COM_SENHA"
        }
    }
}
```

Deploy:

```bash
az group create --name "$RG5" --location "$LOCATION"

# Atualizar senha no parameter file
sed -i "s/ALTERE_COM_SENHA/$VM_PASSWORD/" bloco5-vms.parameters.json

az deployment group create \
    --resource-group "$RG5" \
    --template-file bloco5-vms.json \
    --parameters @bloco5-vms.parameters.json

echo "VMs criadas"
```

---

### Task 5.4: Network Watcher

```bash
az network watcher test-connectivity \
    --resource-group "$RG5" \
    --source-resource "CoreServicesVM" \
    --dest-resource "ManufacturingVM" \
    --dest-port 3389
# Esperado: Unreachable
```

---

### Task 5.5: VNet Peering via ARM

Salve como **`bloco5-peering.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "resources": [
        {
            "type": "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
            "apiVersion": "2023-05-01",
            "name": "CoreServicesVnet/CoreServicesVnet-to-ManufacturingVnet",
            "properties": {
                "remoteVirtualNetwork": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks', 'ManufacturingVnet')]"
                },
                "allowVirtualNetworkAccess": true,
                "allowForwardedTraffic": true,
                "allowGatewayTransit": false,
                "useRemoteGateways": false
            }
        },
        {
            "type": "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
            "apiVersion": "2023-05-01",
            "name": "ManufacturingVnet/ManufacturingVnet-to-CoreServicesVnet",
            "properties": {
                "remoteVirtualNetwork": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks', 'CoreServicesVnet')]"
                },
                "allowVirtualNetworkAccess": true,
                "allowForwardedTraffic": true,
                "allowGatewayTransit": false,
                "useRemoteGateways": false
            }
        }
    ]
}
```

> **Comparacao com Bicep:**
> - ARM: `"name": "CoreServicesVnet/CoreServicesVnet-to-ManufacturingVnet"` — nome composto
> - Bicep: `parent: coreVnet` + `name: 'CoreServicesVnet-to-ManufacturingVnet'`
> - ARM: sem `dependsOn` aqui pois as VNets ja existem (deploy anterior)
> - Nota: ambas VNets devem existir no mesmo RG para este template funcionar

Deploy:

```bash
az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco5-peering.json

az network vnet peering list -g "$RG4" --vnet-name "CoreServicesVnet" \
    --query "[].{name:name, status:peeringState}" -o table
```

---

### Task 5.6: Testar conexao

```bash
CORE_IP=$(az vm show -g "$RG5" -n "CoreServicesVM" -d --query privateIps -o tsv)

az vm run-command invoke \
    --resource-group "$RG5" \
    --name "ManufacturingVM" \
    --command-id RunPowerShellScript \
    --scripts "Test-NetConnection $CORE_IP -Port 3389"
# Esperado: TcpTestSucceeded: True
```

---

### Task 5.7: DNS update via ARM

Salve como **`bloco5-dns-update.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "coreVmIp": {
            "type": "string",
            "metadata": {
                "description": "IP privado da CoreServicesVM"
            }
        }
    },
    "resources": [
        {
            "type": "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
            "apiVersion": "2020-06-01",
            "name": "private.contoso.com/coreservices-link",
            "location": "global",
            "properties": {
                "virtualNetwork": {
                    "id": "[resourceId('Microsoft.Network/virtualNetworks', 'CoreServicesVnet')]"
                },
                "registrationEnabled": false
            }
        },
        {
            "type": "Microsoft.Network/privateDnsZones/A",
            "apiVersion": "2020-06-01",
            "name": "private.contoso.com/corevm",
            "properties": {
                "ttl": 1,
                "aRecords": [
                    {
                        "ipv4Address": "[parameters('coreVmIp')]"
                    }
                ]
            }
        }
    ]
}
```

Deploy:

```bash
CORE_IP=$(az vm show -g "$RG5" -n "CoreServicesVM" -d --query privateIps -o tsv)

az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco5-dns-update.json \
    --parameters coreVmIp="$CORE_IP"

# Testar DNS
az vm run-command invoke \
    --resource-group "$RG5" \
    --name "ManufacturingVM" \
    --command-id RunPowerShellScript \
    --scripts "Resolve-DnsName corevm.private.contoso.com"
```

---

### Task 5.8: Route Table via ARM

Salve como **`bloco5-route.json`**:

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
            "type": "Microsoft.Network/routeTables",
            "apiVersion": "2023-05-01",
            "name": "rt-CoreServices",
            "location": "[parameters('location')]",
            "properties": {
                "disableBgpRoutePropagation": true,
                "routes": [
                    {
                        "name": "PerimetertoCore",
                        "properties": {
                            "addressPrefix": "10.20.0.0/16",
                            "nextHopType": "VirtualAppliance",
                            "nextHopIpAddress": "10.20.1.7"
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "routeTableId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Network/routeTables', 'rt-CoreServices')]"
        }
    }
}
```

Deploy + associar:

```bash
az deployment group create \
    --resource-group "$RG5" \
    --template-file bloco5-route.json

# Criar subnet perimeter
az network vnet subnet create \
    --resource-group "$RG4" --vnet-name "CoreServicesVnet" \
    --name "perimeter" --address-prefixes "10.20.1.0/24"

# Associar route table
RT_ID=$(az network route-table show -g "$RG5" -n "rt-CoreServices" --query id -o tsv)
az network vnet subnet update \
    --resource-group "$RG4" --vnet-name "CoreServicesVnet" \
    --name "Core" --route-table "$RT_ID"
```

---

### Task 5.9-5.10: Verificacoes finais

```bash
# NSG isolado por subnet
az network nsg show -g "$RG4" -n "myNSGSecure" --query "subnets[].id" -o table
echo "NSG apenas em SharedServicesSubnet"

# RBAC informativo
echo "=== Teste RBAC Final ==="
echo "Login como az104-user1@${TENANT_DOMAIN} em InPrivate"
echo "1. VMs visiveis ✓  2. Stop VM ✓  3. Deletar RG ✗  4. Criar Storage ✗"
```

---

## Modo Desafio - Bloco 5

- [ ] Subnets Core e Manufacturing (CLI)
- [ ] Deploy `bloco5-vms.json` com parameter file (VMs cross-RG)
- [ ] Network Watcher → Unreachable
- [ ] Deploy `bloco5-peering.json`
- [ ] Test-NetConnection → Success
- [ ] Deploy `bloco5-dns-update.json` com IP real
- [ ] Resolve-DnsName
- [ ] Deploy `bloco5-route.json` + associar subnet
- [ ] Verificar NSG + RBAC

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**VM no rg5 usa VNet do rg4. Possivel?**

A) Nao  B) Sim, qualquer RG na subscription  C) Apenas ARM  D) Mover VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

Em ARM JSON, cross-RG e feito com `resourceId()` passando o RG como primeiro parametro:
```json
"[resourceId('az104-rg4', 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'Core')]"
```
Em Bicep: `existing` + `scope: resourceGroup('az104-rg4')`.

</details>

### Questao 5.2
**A↔B + B↔C peering. A fala com C?**

A) Sim  B) Nao, NAO transitivo  C) Com forwarded traffic  D) VPN

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 5.3
**UDR next hop IP sem NVA?**

A) Roteado  B) Descartado  C) Azure cria NVA  D) Gateway

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 5.4
**Peering + NVA. O que configurar?**

A) NSG  B) UDR + IP forwarding  C) IP forwarding apenas  D) VPN

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 5.5
**DNS privada linkada VNet A. VM na VNet B com peering resolve?**

A) Sim  B) Falha sem link  C) Forwarded traffic  D) DNS forwarder

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

---

---

# Bloco 6 - Load Balancer e Azure Bastion

**Tecnologia:** ARM Templates JSON + CLI (para Run Command, NSG association, testes)
**Recursos criados:** Subnet LBSubnet, Availability Set, 2 VMs (IIS), Public LB, Internal LB, NSG, Bastion
**Resource Group:** `az104-rg6lb` (VMs e LBs) + `az104-rg4` (VNet existente)

> **Nota:** Este bloco cria VMs, Public IPs e Bastion que geram custo. Faca cleanup assim que terminar.

---

### Task 6.1: Criar subnet LBSubnet (CLI) e Resource Group

```bash
# ============================================================
# TASK 6.1a - Criar RG e subnet LBSubnet
# ============================================================

RG6="az104-rg6lb"
az group create --name "$RG6" --location "$LOCATION" --tags "Cost Center=000"

az network vnet subnet create \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --name "LBSubnet" \
    --address-prefixes "10.20.40.0/24"

echo "RG az104-rg6lb e subnet LBSubnet criados"
```

---

### Task 6.1b: Criar Availability Set e VMs com IIS

Salve como **`bloco6-lb-infra.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "adminUsername": {
            "type": "string",
            "defaultValue": "localadmin"
        },
        "adminPassword": {
            "type": "securestring",
            "metadata": { "description": "Senha do admin local" }
        },
        "vnetResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg4",
            "metadata": { "description": "RG onde a CoreServicesVnet esta" }
        }
    },
    "variables": {
        "avSetName": "az104-avset-lb",
        "vnetName": "CoreServicesVnet",
        "subnetName": "LBSubnet",
        "subnetId": "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]"
    },
    "resources": [
        {
            "type": "Microsoft.Compute/availabilitySets",
            "apiVersion": "2023-07-01",
            "name": "[variables('avSetName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "Aligned"
            },
            "properties": {
                "platformFaultDomainCount": 2,
                "platformUpdateDomainCount": 5
            }
        },
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "LB-VM1-nic",
            "location": "[parameters('location')]",
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[variables('subnetId')]"
                            }
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/networkInterfaces",
            "apiVersion": "2023-05-01",
            "name": "LB-VM2-nic",
            "location": "[parameters('location')]",
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAllocationMethod": "Dynamic",
                            "subnet": {
                                "id": "[variables('subnetId')]"
                            }
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2023-07-01",
            "name": "LB-VM1",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Compute/availabilitySets', variables('avSetName'))]",
                "[resourceId('Microsoft.Network/networkInterfaces', 'LB-VM1-nic')]"
            ],
            "properties": {
                "availabilitySet": {
                    "id": "[resourceId('Microsoft.Compute/availabilitySets', variables('avSetName'))]"
                },
                "hardwareProfile": { "vmSize": "Standard_D2s_v3" },
                "osProfile": {
                    "computerName": "LB-VM1",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2025-datacenter-azure-edition",
                        "version": "latest"
                    },
                    "osDisk": {
                        "createOption": "FromImage",
                        "managedDisk": { "storageAccountType": "StandardSSD_LRS" }
                    }
                },
                "networkProfile": {
                    "networkInterfaces": [
                        { "id": "[resourceId('Microsoft.Network/networkInterfaces', 'LB-VM1-nic')]" }
                    ]
                },
                "diagnosticsProfile": {
                    "bootDiagnostics": { "enabled": false }
                }
            }
        },
        {
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2023-07-01",
            "name": "LB-VM2",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[resourceId('Microsoft.Compute/availabilitySets', variables('avSetName'))]",
                "[resourceId('Microsoft.Network/networkInterfaces', 'LB-VM2-nic')]"
            ],
            "properties": {
                "availabilitySet": {
                    "id": "[resourceId('Microsoft.Compute/availabilitySets', variables('avSetName'))]"
                },
                "hardwareProfile": { "vmSize": "Standard_D2s_v3" },
                "osProfile": {
                    "computerName": "LB-VM2",
                    "adminUsername": "[parameters('adminUsername')]",
                    "adminPassword": "[parameters('adminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "MicrosoftWindowsServer",
                        "offer": "WindowsServer",
                        "sku": "2025-datacenter-azure-edition",
                        "version": "latest"
                    },
                    "osDisk": {
                        "createOption": "FromImage",
                        "managedDisk": { "storageAccountType": "StandardSSD_LRS" }
                    }
                },
                "networkProfile": {
                    "networkInterfaces": [
                        { "id": "[resourceId('Microsoft.Network/networkInterfaces', 'LB-VM2-nic')]" }
                    ]
                },
                "diagnosticsProfile": {
                    "bootDiagnostics": { "enabled": false }
                }
            }
        }
    ],
    "outputs": {
        "avSetId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Compute/availabilitySets', variables('avSetName'))]"
        },
        "vm1Name": { "type": "string", "value": "LB-VM1" },
        "vm2Name": { "type": "string", "value": "LB-VM2" }
    }
}
```

> **ARM vs Bicep:** Note o `dependsOn` explicito para VMs (depende do Availability Set e NICs).
> Em Bicep, essas dependencias sao automaticas quando voce referencia `avSet.id` e `nic1.id`.
> O cross-RG e feito via `resourceId()` com o RG como primeiro parametro em `variables('subnetId')`.

Deploy:

```bash
# ============================================================
# DEPLOY bloco6-lb-infra.json
# ============================================================

az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco6-lb-infra.json \
    --parameters adminPassword="$VM_PASSWORD" \
    --name "deploy-lb-infra"

az vm wait --resource-group "$RG6" --name "LB-VM1" --created
az vm wait --resource-group "$RG6" --name "LB-VM2" --created
echo "VMs LB-VM1 e LB-VM2 criadas no Availability Set"
```

---

### Task 6.1c: Instalar IIS nas VMs via Run Command

```bash
# ============================================================
# TASK 6.1c - Instalar IIS via Run Command
# ============================================================

az vm run-command invoke \
    --resource-group "$RG6" --name "LB-VM1" \
    --command-id RunPowerShellScript \
    --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools; Remove-Item 'C:\inetpub\wwwroot\iisstart.htm'; Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value \$('Hello from ' + \$env:computername)"

az vm run-command invoke \
    --resource-group "$RG6" --name "LB-VM2" \
    --command-id RunPowerShellScript \
    --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools; Remove-Item 'C:\inetpub\wwwroot\iisstart.htm'; Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value \$('Hello from ' + \$env:computername)"

echo "IIS instalado em ambas as VMs"
```

---

### Task 6.2-6.3: Criar Public Load Balancer com NSG

Salve como **`bloco6-public-lb.json`**:

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
    "variables": {
        "lbName": "az104-pub-lb",
        "pipName": "az104-lb-pip",
        "nsgName": "nsg-lb",
        "frontendName": "lb-frontend",
        "backendPoolName": "lb-backend-pool",
        "probeName": "http-probe",
        "lbId": "[resourceId('Microsoft.Network/loadBalancers', variables('lbName'))]",
        "frontendId": "[concat(variables('lbId'), '/frontendIPConfigurations/', variables('frontendName'))]",
        "backendPoolId": "[concat(variables('lbId'), '/backendAddressPools/', variables('backendPoolName'))]",
        "probeId": "[concat(variables('lbId'), '/probes/', variables('probeName'))]"
    },
    "resources": [
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('pipName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Standard" },
            "zones": ["1", "2", "3"],
            "properties": {
                "publicIPAllocationMethod": "Static",
                "publicIPAddressVersion": "IPv4"
            }
        },
        {
            "type": "Microsoft.Network/loadBalancers",
            "apiVersion": "2023-05-01",
            "name": "[variables('lbName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "Standard",
                "tier": "Regional"
            },
            "dependsOn": [
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
            ],
            "properties": {
                "frontendIPConfigurations": [
                    {
                        "name": "[variables('frontendName')]",
                        "properties": {
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
                            }
                        }
                    }
                ],
                "backendAddressPools": [
                    { "name": "[variables('backendPoolName')]" }
                ],
                "probes": [
                    {
                        "name": "[variables('probeName')]",
                        "properties": {
                            "protocol": "Http",
                            "port": 80,
                            "requestPath": "/",
                            "intervalInSeconds": 5,
                            "numberOfProbes": 2
                        }
                    }
                ],
                "loadBalancingRules": [
                    {
                        "name": "http-rule",
                        "properties": {
                            "frontendIPConfiguration": { "id": "[variables('frontendId')]" },
                            "backendAddressPool": { "id": "[variables('backendPoolId')]" },
                            "probe": { "id": "[variables('probeId')]" },
                            "protocol": "Tcp",
                            "frontendPort": 80,
                            "backendPort": 80,
                            "enableFloatingIP": false,
                            "idleTimeoutInMinutes": 4,
                            "loadDistribution": "Default"
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/networkSecurityGroups",
            "apiVersion": "2023-05-01",
            "name": "[variables('nsgName')]",
            "location": "[parameters('location')]",
            "properties": {
                "securityRules": [
                    {
                        "name": "AllowHTTP",
                        "properties": {
                            "priority": 100,
                            "direction": "Inbound",
                            "access": "Allow",
                            "protocol": "Tcp",
                            "sourcePortRange": "*",
                            "destinationPortRange": "80",
                            "sourceAddressPrefix": "*",
                            "destinationAddressPrefix": "*"
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "lbId": { "type": "string", "value": "[variables('lbId')]" },
        "lbFrontendIp": {
            "type": "string",
            "value": "[reference(variables('pipName')).ipAddress]"
        },
        "nsgId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
        }
    }
}
```

> **ARM Pattern:** Note o uso de `concat()` para construir IDs de sub-recursos do LB
> (frontend, backend pool, probe). Em Bicep, usamos `resourceId()` inline.
> O `dependsOn` para o LB referencia o PIP — em Bicep isso e automatico.

Deploy:

```bash
# ============================================================
# DEPLOY bloco6-public-lb.json
# ============================================================

az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco6-public-lb.json \
    --name "deploy-public-lb"

# Associar NSG a LBSubnet
NSG_ID=$(az network nsg show -g "$RG6" -n "nsg-lb" --query id -o tsv)
az network vnet subnet update \
    --resource-group "$RG4" --vnet-name "CoreServicesVnet" \
    --name "LBSubnet" --network-security-group "$NSG_ID"

# Adicionar VMs ao Backend Pool
az network nic ip-config address-pool add \
    --resource-group "$RG6" --nic-name "LB-VM1-nic" \
    --ip-config-name "ipconfig1" --lb-name "az104-pub-lb" \
    --address-pool "lb-backend-pool"

az network nic ip-config address-pool add \
    --resource-group "$RG6" --nic-name "LB-VM2-nic" \
    --ip-config-name "ipconfig1" --lb-name "az104-pub-lb" \
    --address-pool "lb-backend-pool"

LB_PIP=$(az network public-ip show -g "$RG6" -n "az104-lb-pip" --query ipAddress -o tsv)
echo "Teste: http://${LB_PIP}"
```

---

### Task 6.4: Testar failover

```bash
# ============================================================
# TASK 6.4 - Testar failover do Load Balancer
# ============================================================

az vm stop --resource-group "$RG6" --name "LB-VM1"
echo "LB-VM1 parada. Aguarde 30-60s. Apenas LB-VM2 deve responder."

# Reiniciar
az vm start --resource-group "$RG6" --name "LB-VM1"
echo "LB-VM1 reiniciada. Aguarde probe detectar como healthy."
```

---

### Task 6.5: Criar Internal Load Balancer

Salve como **`bloco6-internal-lb.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "vnetResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg4"
        }
    },
    "variables": {
        "lbName": "az104-int-lb",
        "frontendName": "int-lb-frontend",
        "backendPoolName": "int-lb-backend",
        "probeName": "int-http-probe",
        "subnetId": "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'LBSubnet')]",
        "lbId": "[resourceId('Microsoft.Network/loadBalancers', variables('lbName'))]"
    },
    "resources": [
        {
            "type": "Microsoft.Network/loadBalancers",
            "apiVersion": "2023-05-01",
            "name": "[variables('lbName')]",
            "location": "[parameters('location')]",
            "sku": {
                "name": "Standard",
                "tier": "Regional"
            },
            "properties": {
                "frontendIPConfigurations": [
                    {
                        "name": "[variables('frontendName')]",
                        "properties": {
                            "privateIPAddress": "10.20.40.100",
                            "privateIPAllocationMethod": "Static",
                            "subnet": {
                                "id": "[variables('subnetId')]"
                            }
                        }
                    }
                ],
                "backendAddressPools": [
                    { "name": "[variables('backendPoolName')]" }
                ],
                "probes": [
                    {
                        "name": "[variables('probeName')]",
                        "properties": {
                            "protocol": "Http",
                            "port": 80,
                            "requestPath": "/",
                            "intervalInSeconds": 5,
                            "numberOfProbes": 2
                        }
                    }
                ],
                "loadBalancingRules": [
                    {
                        "name": "int-http-rule",
                        "properties": {
                            "frontendIPConfiguration": {
                                "id": "[concat(variables('lbId'), '/frontendIPConfigurations/', variables('frontendName'))]"
                            },
                            "backendAddressPool": {
                                "id": "[concat(variables('lbId'), '/backendAddressPools/', variables('backendPoolName'))]"
                            },
                            "probe": {
                                "id": "[concat(variables('lbId'), '/probes/', variables('probeName'))]"
                            },
                            "protocol": "Tcp",
                            "frontendPort": 80,
                            "backendPort": 80,
                            "enableFloatingIP": false,
                            "idleTimeoutInMinutes": 4,
                            "loadDistribution": "Default"
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "intLbId": { "type": "string", "value": "[variables('lbId')]" },
        "intLbFrontendIp": { "type": "string", "value": "10.20.40.100" }
    }
}
```

Deploy:

```bash
# ============================================================
# DEPLOY bloco6-internal-lb.json
# ============================================================

az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco6-internal-lb.json \
    --name "deploy-internal-lb"

az network nic ip-config address-pool add \
    --resource-group "$RG6" --nic-name "LB-VM1-nic" \
    --ip-config-name "ipconfig1" --lb-name "az104-int-lb" \
    --address-pool "int-lb-backend"

az network nic ip-config address-pool add \
    --resource-group "$RG6" --nic-name "LB-VM2-nic" \
    --ip-config-name "ipconfig1" --lb-name "az104-int-lb" \
    --address-pool "int-lb-backend"

echo "Internal LB criado com frontend IP 10.20.40.100"
```

---

### Task 6.6: Troubleshoot health probe

```bash
# ============================================================
# TASK 6.6 - Troubleshoot: parar IIS e diagnosticar
# ============================================================

az vm run-command invoke --resource-group "$RG6" --name "LB-VM1" \
    --command-id RunPowerShellScript --scripts "Stop-Service -Name W3SVC -Force"
echo "IIS parado em LB-VM1. Verifique Health Probe Status no portal."

# Corrigir
az vm run-command invoke --resource-group "$RG6" --name "LB-VM1" \
    --command-id RunPowerShellScript --scripts "Start-Service -Name W3SVC"
echo "IIS reiniciado."
```

---

### Task 6.7: Implantar Azure Bastion

Salve como **`bloco6-bastion.json`**:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]"
        },
        "vnetResourceGroup": {
            "type": "string",
            "defaultValue": "az104-rg4"
        }
    },
    "variables": {
        "bastionName": "az104-bastion",
        "bastionPipName": "az104-bastion-pip",
        "bastionSubnetId": "[resourceId(parameters('vnetResourceGroup'), 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'AzureBastionSubnet')]"
    },
    "resources": [
        {
            "type": "Microsoft.Network/virtualNetworks/subnets",
            "apiVersion": "2023-05-01",
            "name": "CoreServicesVnet/AzureBastionSubnet",
            "properties": {
                "addressPrefix": "10.20.30.0/26"
            }
        },
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2023-05-01",
            "name": "[variables('bastionPipName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Standard" },
            "properties": {
                "publicIPAllocationMethod": "Static"
            }
        },
        {
            "type": "Microsoft.Network/bastionHosts",
            "apiVersion": "2023-05-01",
            "name": "[variables('bastionName')]",
            "location": "[parameters('location')]",
            "sku": { "name": "Basic" },
            "dependsOn": [
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('bastionPipName'))]"
            ],
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "bastionIpConfig",
                        "properties": {
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('bastionPipName'))]"
                            },
                            "subnet": {
                                "id": "[variables('bastionSubnetId')]"
                            }
                        }
                    }
                ]
            }
        }
    ],
    "outputs": {
        "bastionName": { "type": "string", "value": "[variables('bastionName')]" }
    }
}
```

> **ARM Pattern:** O Bastion requer `dependsOn` explicito para o PIP. A subnet e referenciada
> via `resourceId()` com o RG da VNet como parametro (cross-RG). O nome da subnet DEVE ser
> `AzureBastionSubnet` — e requisito do Azure.

> **NOTA:** A subnet `AzureBastionSubnet` deve ser criada na VNet que esta em `az104-rg4`.
> O ARM template acima cria a subnet como nested resource. Se preferir, crie via CLI:

```bash
# Alternativa: criar AzureBastionSubnet via CLI
az network vnet subnet create \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --name "AzureBastionSubnet" \
    --address-prefixes "10.20.30.0/26"
```

Deploy:

```bash
# ============================================================
# DEPLOY bloco6-bastion.json
# ============================================================
# Primeiro criar a subnet (se nao usou o template acima para isso)
az network vnet subnet create \
    --resource-group "$RG4" --vnet-name "CoreServicesVnet" \
    --name "AzureBastionSubnet" --address-prefixes "10.20.30.0/26" 2>/dev/null

# Deploy Bastion (pode levar 5-10 minutos)
az deployment group create \
    --resource-group "$RG6" \
    --template-file bloco6-bastion.json \
    --name "deploy-bastion"

echo "Azure Bastion implantado. Acesse VMs via Connect > Bastion"
```

---

## Modo Desafio - Bloco 6

- [ ] Criar RG `az104-rg6lb` e subnet `LBSubnet` (10.20.40.0/24)
- [ ] Deploy `bloco6-lb-infra.json` com parameter file
- [ ] Instalar IIS via Run Command
- [ ] Deploy `bloco6-public-lb.json`
- [ ] Associar NSG a LBSubnet e VMs ao backend pool
- [ ] Testar balanceamento (hard refresh)
- [ ] Testar failover: parar VM1 → apenas VM2 → reiniciar VM1
- [ ] Deploy `bloco6-internal-lb.json` (IP 10.20.40.100)
- [ ] Troubleshoot: parar IIS → unhealthy → reiniciar
- [ ] Deploy `bloco6-bastion.json` (AzureBastionSubnet /26)
- [ ] Conectar via Bastion

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Standard LB, VMs no backend, probes healthy, mas clientes nao acessam. Causa?**

A) LB Standard requer Availability Zones  B) Falta NSG permitindo trafego  C) Probe configurado errado  D) VMs precisam IP publico

<details><summary>Ver resposta</summary>**Resposta: B)** Standard LB bloqueia trafego por padrao. NSG obrigatorio.</details>

### Questao 6.2
**Diferenca entre Public LB e Internal LB?**

A) Public usa Basic; Internal usa Standard  B) Public distribui trafego da internet; Internal distribui dentro da VNet  C) Internal nao suporta probes  D) Public so TCP

<details><summary>Ver resposta</summary>**Resposta: B)** Public = IP publico (internet). Internal = IP privado (entre tiers).</details>

### Questao 6.3
**Requisito de subnet para Azure Bastion?**

A) `BastionSubnet` /28  B) `AzureBastionSubnet` /26  C) Qualquer subnet /24  D) `AzureBastionSubnet` /24

<details><summary>Ver resposta</summary>**Resposta: B)** Nome EXATO `AzureBastionSubnet`, minimo /26.</details>

### Questao 6.4
**VM no backend, probe Unhealthy, VM running. Causa?**

A) Sem IP publico  B) Servico (IIS) nao responde na porta do probe  C) Availability Set diferente  D) LB precisa restart

<details><summary>Ver resposta</summary>**Resposta: B)** Probes verificam a APLICACAO, nao a VM.</details>

### Questao 6.5
**3 VMs no backend, 1 unhealthy. O que acontece com o trafego?**

A) Enfileirado  B) Redirecionado para VMs healthy  C) LB para  D) Descartado

<details><summary>Ver resposta</summary>**Resposta: B)** LB redistribui para VMs healthy automaticamente.</details>

---

# Bloco 7 - SSPR, Cost Management e NSG Effective Rules

**Tecnologia:** CLI (operacoes de Entra ID, Cost Management e Network Watcher)
**Recursos:** SSPR config, Budget, Advisor alert, Network Watcher diagnostics
**Resource Groups utilizados:** `az104-rg4`, `az104-rg5`, `az104-rg6lb`

> **Nota:** Bloco majoritariamente portal/CLI. SSPR e configuracao do Entra ID,
> Cost Management/Advisor sao leitura + config, Network Watcher e diagnostico.

---

### Task 7.1: Criar grupo SSPR-TestGroup e habilitar SSPR

```bash
# ============================================================
# TASK 7.1 - Criar grupo e habilitar SSPR
# ============================================================

az ad group create \
    --display-name "SSPR-TestGroup" \
    --mail-nickname "sspr-testgroup" \
    --description "Grupo de teste para Self-Service Password Reset"

SSPR_GROUP_ID=$(az ad group show --group "SSPR-TestGroup" --query id -o tsv)

USER1_ID=$(az ad user show --id "az104-user1@${TENANT_DOMAIN}" --query id -o tsv)
az ad group member add --group "SSPR-TestGroup" --member-id "$USER1_ID"

echo "=== ACAO MANUAL ==="
echo "Portal > Entra ID > Protection > Password reset"
echo "Properties > Enabled: Selected > Group: SSPR-TestGroup > Save"
```

---

### Task 7.2: Configurar metodos de autenticacao

```bash
# ============================================================
# TASK 7.2 - Configurar metodos SSPR (portal)
# ============================================================

echo "1. Password reset > Authentication methods"
echo "   - Methods required: 1"
echo "   - Methods: Email + Security questions"
echo "2. Security questions: register 3, reset 3"
echo "3. Registration: Require on sign-in: Yes, Re-confirm: 90 days"
echo "4. Notifications: Notify users + admins: Yes"
```

---

### Task 7.3: Testar reset de senha

```bash
# ============================================================
# TASK 7.3 - Testar fluxo SSPR
# ============================================================

echo "1. InPrivate > https://aka.ms/ssprsetup > login az104-user1"
echo "2. Registrar metodos (email + security questions)"
echo "3. https://aka.ms/sspr > username > captcha > verificacao > nova senha"
```

---

### Task 7.4: Criar Budget e alertas

```bash
# ============================================================
# TASK 7.4 - Criar Budget no Cost Management
# ============================================================

START_DATE=$(date -u +"%Y-%m-01")
END_DATE=$(date -u -d "+6 months" +"%Y-%m-01" 2>/dev/null || date -u -v+6m +"%Y-%m-01")

az consumption budget create \
    --budget-name "az104-lab-budget" \
    --amount 50 \
    --time-grain "Monthly" \
    --start-date "$START_DATE" \
    --end-date "$END_DATE" \
    --category "Cost"

echo "Budget criado. Configure alertas 80%, 100%, 120% no portal."
echo "Cost Management > Budgets > az104-lab-budget > Edit"
```

---

### Task 7.5: Revisar Azure Advisor

```bash
# ============================================================
# TASK 7.5 - Azure Advisor
# ============================================================

az advisor recommendation list --category Cost -o table 2>/dev/null
az advisor recommendation list --category Security -o table 2>/dev/null

echo "Criar alerta: Advisor > Alerts > + New alert"
echo "Category: Cost, Impact: High, Name: az104-advisor-cost-alert"
```

---

### Task 7.6: Network Watcher - Effective Security Rules e IP Flow Verify

```bash
# ============================================================
# TASK 7.6 - Network Watcher diagnostics
# ============================================================

echo "=== Effective Security Rules - LB-VM1 ==="
az network watcher show-security-group-view \
    --resource-group "$RG6" --vm "LB-VM1" -o table

VM1_IP=$(az vm show -g "$RG6" -n "LB-VM1" -d --query privateIps -o tsv)

echo "=== IP Flow Verify: HTTP porta 80 (ALLOW) ==="
az network watcher test-ip-flow \
    --resource-group "$RG6" --vm "LB-VM1" \
    --direction "Inbound" --protocol "TCP" \
    --local "${VM1_IP}:80" --remote "10.0.0.1:12345"

echo "=== IP Flow Verify: SSH porta 22 (DENY) ==="
az network watcher test-ip-flow \
    --resource-group "$RG6" --vm "LB-VM1" \
    --direction "Inbound" --protocol "TCP" \
    --local "${VM1_IP}:22" --remote "10.0.0.1:12345"
```

---

## Modo Desafio - Bloco 7

- [ ] Criar `SSPR-TestGroup` com `az104-user1`
- [ ] Habilitar SSPR (Selected) via portal
- [ ] Configurar metodos: Email + Security Questions, 1 requerido
- [ ] Testar reset via `https://aka.ms/sspr`
- [ ] Criar Budget $50/mes
- [ ] Alertas 80%, 100%, 120% (forecasted)
- [ ] Revisar Advisor + criar alerta Cost/High
- [ ] Effective Security Rules em LB-VM1
- [ ] IP Flow Verify HTTP (Allow) e SSH (Deny)

---

## Questoes de Prova - Bloco 7

### Questao 7.1
**SSPR habilitado para grupo. Usuario nao consegue resetar. Verificar?**

A) Licenca P2  B) Se registrou metodos  C) Se e Owner  D) Se SSPR esta em "All"

<details><summary>Ver resposta</summary>**Resposta: B)** Usuario precisa ter registrado metodos requeridos.</details>

### Questao 7.2
**Budget $100/mes, alerta 80%. Gasto $85. O que acontece?**

A) Desliga recursos  B) Email de alerta, recursos continuam  C) Bloqueia deployments  D) Rebaixa SKUs

<details><summary>Ver resposta</summary>**Resposta: B)** Budgets alertam mas NAO param recursos.</details>

### Questao 7.3
**Verificar se TCP 443 de IP externo e permitido. Ferramenta?**

A) Connection Troubleshoot  B) Effective Security Rules  C) IP Flow Verify  D) Next Hop

<details><summary>Ver resposta</summary>**Resposta: C)** IP Flow Verify testa pacote especifico.</details>

### Questao 7.4
**NSG subnet permite porta 80. NSG NIC bloqueia porta 80. Inbound?**

A) Permitido (subnet precedencia)  B) Bloqueado (AMBOS devem permitir)  C) Allow vence Deny  D) Depende priority

<details><summary>Ver resposta</summary>**Resposta: B)** Inbound: subnet NSG → NIC NSG. Ambos devem permitir.</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```bash
# Pausar
az vm deallocate -g az104-rg5 -n CoreServicesVM --no-wait
az vm deallocate -g az104-rg5 -n ManufacturingVM --no-wait
az vm deallocate -g az104-rg6lb -n LB-VM1 --no-wait
az vm deallocate -g az104-rg6lb -n LB-VM2 --no-wait

# Retomar
az vm start -g az104-rg5 -n CoreServicesVM --no-wait
az vm start -g az104-rg5 -n ManufacturingVM --no-wait
az vm start -g az104-rg6lb -n LB-VM1 --no-wait
az vm start -g az104-rg6lb -n LB-VM2 --no-wait
```

> **Nota:** Desalocar para cobranca de compute. Discos, IPs publicos e Bastion continuam gerando custo.

---

# Cleanup Unificado

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos
# ============================================================

# 1. Policies
echo "1. Removendo policies..."
az policy assignment delete --name "InheritCostCenter-rg2" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}" 2>/dev/null
az policy assignment delete --name "InheritCostCenter-rg3" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG3}" 2>/dev/null
az policy assignment delete --name "AllowedLocations-rg3" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG3}" 2>/dev/null
az policy set-definition delete --name "az104-governance-initiative" 2>/dev/null

# 2. Lock
echo "2. Removendo lock..."
az lock delete --name "rg-lock" --resource-group "$RG2" 2>/dev/null

# 3. RGs (VMs primeiro)
echo "3. Deletando RGs..."
az group delete --name "az104-rg6lb" --yes --no-wait
az group delete --name "$RG5" --yes --no-wait
az group delete --name "$RG4" --yes --no-wait
az group delete --name "$RG3" --yes --no-wait
az group delete --name "$RG2" --yes --no-wait

# 4. MG
echo "4. Removendo MG..."
az account management-group subscription remove --name "$MG_NAME" \
    --subscription "$SUBSCRIPTION_ID" 2>/dev/null
az account management-group delete --name "$MG_NAME" 2>/dev/null

# 5. Custom Role
echo "5. Custom role..."
az role definition delete --name "Custom Support Request" 2>/dev/null

# 6. Identidades
echo "6. Identidades..."
az ad user delete --id "az104-user1@${TENANT_DOMAIN}" 2>/dev/null
az ad user delete --id "$GUEST_ID" 2>/dev/null
az ad group delete --group "IT Lab Administrators" 2>/dev/null
az ad group delete --group "helpdesk" 2>/dev/null
az ad group delete --group "SSPR-TestGroup" 2>/dev/null

# 7. Budget
echo "7. Removendo budget..."
az consumption budget delete --budget-name "az104-lab-budget" 2>/dev/null

echo "=== CLEANUP COMPLETO ==="
```

---

# Key Takeaways Consolidados

## ARM JSON vs Bicep vs PowerShell

| Aspecto | ARM JSON | Bicep | PowerShell |
|---------|----------|-------|------------|
| Formato | JSON verboso | DSL conciso | Comandos imperativos |
| Dependencias | `dependsOn` **explicito** | **Implicitas** (automaticas) | Ordem de execucao |
| Type safety | Nenhum | Decorators | Tipagem PS |
| Validacao params | `allowedValues`, `minValue` | `@allowed`, `@minValue` | Validacao manual |
| Cross-RG | `resourceId('rg', ...)` | `existing` + `scope` | ID completo |
| Loops | `copy` + `copyIndex()` | `for` | `ForEach-Object` |
| Scope | Schema URL diferente | `targetScope` | Cmdlet diferente |
| Boilerplate | ~15 linhas por template | ~2 linhas | 0 |

## ARM vs Bicep: Comparacao Direta

### Dependencia
```json
// ARM: EXPLICITO
"dependsOn": [
    "[resourceId('Microsoft.Network/applicationSecurityGroups', 'asg-web')]"
]
```
```bicep
// Bicep: IMPLICITO (basta referenciar)
sourceApplicationSecurityGroups: [ { id: asg.id } ]
```

### Cross-RG Reference
```json
// ARM:
"[resourceId('az104-rg4', 'Microsoft.Network/virtualNetworks/subnets', 'CoreServicesVnet', 'Core')]"
```
```bicep
// Bicep:
resource coreVnet 'type' existing = {
  name: 'CoreServicesVnet'
  scope: resourceGroup('az104-rg4')
}
```

### Parametros com Validacao
```json
// ARM: dentro do objeto parameter
"diskSizeGB": {
    "type": "int",
    "minValue": 4,
    "maxValue": 32767,
    "defaultValue": 32
}
```
```bicep
// Bicep: decorators separados (mais legivel)
@minValue(4)
@maxValue(32767)
param diskSizeGB int = 32
```

## Templates Criados

| Template | Scope | Recursos | Linhas |
|----------|-------|----------|--------|
| `bloco2-custom-role.json` | managementGroup | Custom RBAC role | ~40 |
| `bloco2-rgs.json` | subscription | 2 RGs com tags | ~25 |
| `bloco2-policies-rg2.json` | resourceGroup | Modify policy + role | ~50 |
| `bloco2-policies-rg3.json` + `.parameters.json` | resourceGroup | Modify + Locations + Reader | ~75 |
| `bloco2-lock.json` | resourceGroup | Delete lock | ~15 |
| `bloco3-disk.json` + `.parameters.json` | resourceGroup | Disco parametrizado | ~45 |
| `bloco4-networking.json` | resourceGroup | 2 VNets + ASG + NSG | ~110 |
| `bloco4-dns.json` | resourceGroup | DNS public + private + link | ~65 |
| `bloco5-vms.json` + `.parameters.json` | resourceGroup | 2 VMs + NICs cross-RG | ~130 |
| `bloco5-peering.json` | resourceGroup | Peering bidirecional | ~35 |
| `bloco5-dns-update.json` | resourceGroup | Link + A record | ~30 |
| `bloco5-route.json` | resourceGroup | Route table + UDR | ~30 |
| `bloco6-lb-infra.json` | resourceGroup | Availability Set + 2 VMs + NICs (cross-RG) | ~130 |
| `bloco6-public-lb.json` | resourceGroup | Public LB + PIP + Backend Pool + NSG | ~100 |
| `bloco6-internal-lb.json` | resourceGroup | Internal LB com IP estatico | ~70 |
| `bloco6-bastion.json` | resourceGroup | AzureBastionSubnet + Bastion + PIP | ~50 |

## Schemas por Scope

| Scope | Schema URL | Comando deploy |
|-------|-----------|----------------|
| Resource Group | `schemas/2019-04-01/deploymentTemplate.json#` | `az deployment group create` |
| Subscription | `schemas/2018-05-01/subscriptionDeploymentTemplate.json#` | `az deployment sub create` |
| Management Group | `schemas/2019-08-01/managementGroupDeploymentTemplate.json#` | `az deployment mg create` |
| Tenant | `schemas/2019-08-01/tenantDeploymentTemplate.json#` | `az deployment tenant create` |

## Funcoes ARM Mais Usadas no Lab

| Funcao | Exemplo | Equivalente Bicep |
|--------|---------|-------------------|
| `[parameters('x')]` | `[parameters('location')]` | `location` (direto) |
| `[variables('x')]` | `[variables('vnetName')]` | `vnetName` (direto) |
| `[resourceId(...)]` | `[resourceId('type', 'name')]` | `resource.id` |
| `[resourceId('rg', ...)]` | Cross-RG reference | `existing` + `scope` |
| `[concat(...)]` | `[concat('a-', 'b')]` | `'a-${b}'` (interpolacao) |
| `[reference(...)]` | Obter propriedade de outro recurso | `resource.properties.x` |
| `[guid(...)]` | GUID deterministico | `guid(...)` |
| `[resourceGroup().location]` | Regiao do RG | `resourceGroup().location` |
| `[subscription().subscriptionId]` | ID da subscription | `subscription().subscriptionId` |
