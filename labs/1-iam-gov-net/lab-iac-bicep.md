# Lab AZ-104 - Semana 1: Tudo via Bicep

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (Bash)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Azure CLI com Bicep ja vem pre-instalados
>   - Autenticacao ja esta feita (nao precisa de `az login`)
>   - Use o editor integrado (`code arquivo.bicep`) para criar os templates
>
> **Objetivo:** Reproduzir **todo** o lab unificado v2 (~49 recursos) usando templates Bicep + CLI.
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

# 4. Se precisar trocar de subscription:
# az account set --subscription "<sua-subscription-id>"
```

### Conceitos Basicos de Bicep

Antes de comecar, entenda estes conceitos fundamentais:

```bicep
// === CONCEITOS FUNDAMENTAIS ===

// 1. targetScope: define ONDE o template sera deployado
//    'resourceGroup' (padrao) | 'subscription' | 'managementGroup' | 'tenant'
targetScope = 'resourceGroup'

// 2. param: parametros de entrada (valores fornicer pelo usuario)
@description('Descricao do parametro')  // Decorator: documenta
@allowed(['eastus', 'westus'])          // Decorator: restringe valores
param location string = 'eastus'        // Tipo + valor default

// 3. var: variaveis calculadas (internas ao template)
var resourceName = 'my-${location}-resource'

// 4. resource: declara um recurso Azure
//    Formato: resource <nome-simbolico> '<tipo>@<api-version>'
resource myVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'myVnet'
  location: location
  properties: { /* ... */ }
}

// 5. existing: referencia recurso ja existente (NAO cria)
resource existingRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: 'az104-rg4'
  scope: subscription()               // Pode cruzar scopes!
}

// 6. output: valores exportados apos deploy
output vnetId string = myVnet.id

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

# --- Configuracoes do tenant (ALTERE estes valores) ---
TENANT_DOMAIN="seudominio.onmicrosoft.com"           # ← ALTERE
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" # ← ALTERE
GUEST_EMAIL="seuemail@gmail.com"                       # ← ALTERE
GUEST_DISPLAY_NAME="Seu Nome"                          # ← ALTERE

# --- Regiao padrao ---
LOCATION="eastus"

# --- Credenciais VM ---
VM_USERNAME="localadmin"
VM_PASSWORD='SenhaComplexa@2024!'                      # ← ALTERE

# --- Resource Groups ---
RG2="az104-rg2"
RG3="az104-rg3"
RG4="az104-rg4"
RG5="az104-rg5"

# --- Management Group ---
MG_NAME="az104-mg1"
```

---

## Mapa de Dependencias

```
Bloco 1 (Identity)
  │
  ├─ az104-user1 ──────────────────┐
  ├─ Guest user ───────────────────┤
  ├─ IT Lab Administrators ────────┤
  └─ helpdesk ─────────────────────┤
                                   │
                                   ▼
Bloco 2 (Governance) ──────────────────────────────────────┐
  │                                                        │
  ├─ RBAC: VM Contributor → IT Lab Administrators (MG)     │
  ├─ RBAC: Reader → Guest user (az104-rg3)                 │
  ├─ Policy: Require tag (Deny) → az104-rg2 (testada)       │
  ├─ Policy: Inherit tag (Modify) → az104-rg2 + az104-rg3  │
  ├─ Policy: Allowed Locations (Deny) → az104-rg3          │
  ├─ Lock: Delete → az104-rg2                              │
  └─ Cria az104-rg3 com tag Cost Center = 000              │
                                   │                       │
                                   ▼                       │
Bloco 3 (IaC) ◄──── Valida governanca ─────────────────────┘
  │
  ├─ Disks em az104-rg3 → tags herdadas automaticamente ✓
  └─ Deploy West US → bloqueado por Allowed Locations ✓
                                                     ▼
Bloco 4 (Networking)
  │
  ├─ CoreServicesVnet (10.20.0.0/16) + ManufacturingVnet (10.30.0.0/16)
  ├─ NSG + ASG
  └─ DNS publico + privado
                                                     ▼
Bloco 5 (Connectivity)
  ├─ VMs + Peering + DNS + Route Table
  └─ Testes de integracao
```

---

# Bloco 1 - Identity

**Tecnologia:** Azure CLI (fallback — Entra ID nao e recurso ARM)
**Recursos criados:** 1 usuario, 1 guest, 2 grupos

> **POR QUE CLI E NAO BICEP?** O Entra ID (antigo Azure AD) NAO e gerenciado pelo Azure
> Resource Manager. Bicep gera templates ARM, que so gerenciam recursos ARM.
> Usuarios, grupos e convites B2B sao recursos do **Microsoft Graph**, nao do ARM.
> Por isso, este bloco usa `az ad` e `az rest` (Graph API) como fallback.

---

### Task 1.1: Criar usuario az104-user1

```bash
# ============================================================
# TASK 1.1 - Criar usuario interno no Entra ID
# ============================================================
# az ad user create: cria usuario via Azure CLI
# --display-name: nome exibido
# --user-principal-name: identidade unica (user@domain)
# --password: senha inicial
# --force-change-password-next-sign-in: obriga troca no primeiro login
#
# NOTA: Propriedades como JobTitle, Department e UsageLocation
# nao estao disponiveis diretamente no 'az ad user create'.
# Usamos 'az rest' para atualizá-las via Graph API.

PASSWORD="Az104Lab@$RANDOM"

az ad user create \
    --display-name "az104-user1" \
    --user-principal-name "az104-user1@${TENANT_DOMAIN}" \
    --password "$PASSWORD" \
    --force-change-password-next-sign-in true

# Salvar a senha!
echo "=== SALVE ESTA SENHA ==="
echo "UPN: az104-user1@${TENANT_DOMAIN}"
echo "Senha: $PASSWORD"
echo "========================"

# Obter o Object ID do usuario (necessario para proximos passos)
USER1_ID=$(az ad user show --id "az104-user1@${TENANT_DOMAIN}" --query id -o tsv)
echo "User ID: $USER1_ID"

# Atualizar propriedades via Graph API (JobTitle, Department, UsageLocation)
# az rest: faz chamada REST direta a qualquer API Microsoft
az rest --method PATCH \
    --url "https://graph.microsoft.com/v1.0/users/${USER1_ID}" \
    --body '{
        "jobTitle": "IT Lab Administrator",
        "department": "IT",
        "usageLocation": "US"
    }'

# Verificar
az ad user show --id "$USER1_ID" --query "{name:displayName, upn:userPrincipalName, job:jobTitle, dept:department}" -o table
```

> **Dica AZ-104:** `UsageLocation` e obrigatoria para atribuir licencas.

---

### Task 1.2: Convidar usuario externo (Guest/B2B)

```bash
# ============================================================
# TASK 1.2 - Convidar usuario externo via B2B
# ============================================================
# B2B invitations NAO tem cmdlet dedicado no az CLI.
# Usamos 'az rest' com a Graph API diretamente.

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

# Obter o Object ID do guest user
GUEST_ID=$(az ad user list --filter "mail eq '${GUEST_EMAIL}'" --query "[0].id" -o tsv)
echo "Guest User ID: $GUEST_ID"

# Atualizar propriedades do guest
az rest --method PATCH \
    --url "https://graph.microsoft.com/v1.0/users/${GUEST_ID}" \
    --body '{
        "jobTitle": "IT Lab Administrator",
        "department": "IT",
        "usageLocation": "US"
    }'

echo ""
echo ">>> ACEITE O CONVITE NO EMAIL ANTES DE CONTINUAR <<<"
```

> **Conceito B2B:** O usuario aparece com `UserType = Guest` e usa suas proprias credenciais.

---

### Task 1.3: Criar grupo IT Lab Administrators

```bash
# ============================================================
# TASK 1.3 - Criar grupo de seguranca IT Lab Administrators
# ============================================================
# az ad group create: cria grupo no Entra ID
# --display-name: nome do grupo
# --mail-nickname: alias (obrigatorio)
# --description: descricao

az ad group create \
    --display-name "IT Lab Administrators" \
    --mail-nickname "itlabadmins" \
    --description "Administrators that manage the IT lab"

# Obter Group ID
ITLAB_GROUP_ID=$(az ad group show --group "IT Lab Administrators" --query id -o tsv)

# Adicionar membros
# az ad group member add: adiciona membro ao grupo
az ad group member add --group "$ITLAB_GROUP_ID" --member-id "$USER1_ID"
az ad group member add --group "$ITLAB_GROUP_ID" --member-id "$GUEST_ID"

# Verificar membros
echo "=== Membros de IT Lab Administrators ==="
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

# Apenas az104-user1 como membro
az ad group member add --group "$HELPDESK_GROUP_ID" --member-id "$USER1_ID"

# Verificar ambos os grupos
echo "=== Membros de helpdesk ==="
az ad group member list --group "$HELPDESK_GROUP_ID" --query "[].{name:displayName}" -o table
```

> **Conexao com Blocos 2-5:** Usuarios e grupos sao a base de todo RBAC.

---

## Modo Desafio - Bloco 1

- [ ] Criar usuario `az104-user1` com `az ad user create`
- [ ] Atualizar propriedades via `az rest` (Graph API)
- [ ] **Salvar a senha** (necessaria nos Blocos 2 e 5)
- [ ] Convidar guest via `az rest` (Graph API invitations)
- [ ] Criar grupo `IT Lab Administrators` — members: az104-user1 + guest
- [ ] Criar grupo `helpdesk` — member: az104-user1

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Sua organizacao precisa que membros de um grupo sejam automaticamente adicionados/removidos com base no departamento do usuario. Qual tipo de membership voce deve configurar?**

A) Assigned
B) Dynamic user
C) Dynamic device
D) Microsoft 365

<details>
<summary>Ver resposta</summary>

**Resposta: B) Dynamic user**

Dynamic user membership permite regras baseadas em propriedades do usuario. Requer Entra ID Premium P1/P2.

</details>

### Questao 1.2
**Um usuario externo convidado via B2B aparece com qual User type?**

A) Member
B) Guest
C) External
D) Federated

<details>
<summary>Ver resposta</summary>

**Resposta: B) Guest**

</details>

### Questao 1.3
**Qual propriedade e obrigatoria para atribuir licencas a um usuario?**

A) Department
B) Job title
C) Usage location
D) Manager

<details>
<summary>Ver resposta</summary>

**Resposta: C) Usage location**

</details>

---

# Bloco 2 - Governance & Compliance

**Tecnologia:** Bicep + CLI
**Recursos criados:** 1 MG, 2 RGs, RBAC, custom role, policies, lock

> Algumas operacoes (MG, mover subscription) usam CLI pois sao operacoes de controle.
> RBAC, policies e locks sao deployados via Bicep.

---

### Task 2.1: Criar Management Group e mover subscription

```bash
# ============================================================
# TASK 2.1 - Criar Management Group (CLI)
# ============================================================
# Management Groups nao sao comumente deployados via Bicep em labs.
# Usamos CLI para simplicidade, mas mostramos o Bicep equivalente.

az account management-group create --name "$MG_NAME" --display-name "$MG_NAME"

# Mover subscription para dentro do MG
az account management-group subscription add \
    --name "$MG_NAME" \
    --subscription "$SUBSCRIPTION_ID"

# Verificar
az account management-group show --name "$MG_NAME" --expand --recurse
```

> **Equivalente Bicep (educativo):** Para criar MG via Bicep, use `targetScope = 'tenant'`:
> ```bicep
> targetScope = 'tenant'
> resource mg 'Microsoft.Management/managementGroups@2021-04-01' = {
>   name: 'az104-mg1'
>   properties: { displayName: 'az104-mg1' }
> }
> ```
> Deploy: `az deployment tenant create --location eastus --template-file mg.bicep`

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

```bash
# ============================================================
# TASK 2.2 - Atribuir VM Contributor ao grupo IT Lab Admins (CLI)
# ============================================================
# RBAC em Management Groups via Bicep requer targetScope = 'managementGroup'
# Para simplicidade, usamos CLI aqui.

az role assignment create \
    --assignee "$ITLAB_GROUP_ID" \
    --role "Virtual Machine Contributor" \
    --scope "/providers/Microsoft.Management/managementGroups/$MG_NAME"

# Verificar
az role assignment list \
    --scope "/providers/Microsoft.Management/managementGroups/$MG_NAME" \
    --query "[?principalName=='IT Lab Administrators'].{role:roleDefinitionName, scope:scope}" \
    -o table
```

---

### Task 2.3: Criar custom RBAC role via Bicep

Salve como **`bloco2-custom-role.bicep`**:

```bicep
// ============================================================
// bloco2-custom-role.bicep
// Scope: managementGroup
// Cria custom role "Custom Support Request"
// ============================================================

// targetScope: este template opera no nivel de Management Group
// (diferente do padrao 'resourceGroup')
targetScope = 'managementGroup'

@description('Nome da role customizada')
param roleName string = 'Custom Support Request'

@description('Descricao da role')
param roleDescription string = 'A custom contributor role for support requests.'

// GUID unico para a role definition (necessario pelo ARM)
// Usamos guid() com um seed para gerar deterministicamente
var roleDefName = guid(managementGroup().id, roleName)

// resource: define a custom role
// Microsoft.Authorization/roleDefinitions: tipo de recurso para roles RBAC
resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    // Actions: permissoes concedidas
    permissions: [
      {
        actions: [
          '*/read'                              // Ler todos os recursos
          'Microsoft.Support/*'                 // Todas as acoes de Support
        ]
        // NotActions: permissoes removidas do conjunto de Actions
        notActions: [
          'Microsoft.Support/register/action'   // EXCETO registrar provider
        ]
      }
    ]
    // AssignableScopes: onde a role pode ser atribuida
    assignableScopes: [
      managementGroup().id
    ]
  }
}

output roleId string = customRole.id
```

Deploy:

```bash
# Deploy no scope de Management Group
az deployment mg create \
    --management-group-id "$MG_NAME" \
    --location "$LOCATION" \
    --template-file bloco2-custom-role.bicep

echo "Custom role 'Custom Support Request' criada"
```

---

### Task 2.4: Monitorar role assignments via Activity Log

> **Por que CLI?** O Activity Log e uma operacao de **leitura** (query), nao de provisionamento de recursos. Nao existe um recurso Bicep para consultar logs — isso e feito via CLI ou PowerShell.

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

### Task 2.5: Criar Resource Groups com tags via Bicep

Salve como **`bloco2-rgs.bicep`**:

```bicep
// ============================================================
// bloco2-rgs.bicep
// Scope: subscription
// Cria 2 Resource Groups com tags
// ============================================================

// targetScope = 'subscription' porque RGs sao recursos de subscription
// (RGs nao vivem dentro de outros RGs)
targetScope = 'subscription'

@description('Localizacao dos RGs')
param location string = 'eastus'

@description('Valor da tag Cost Center')
param costCenter string = '000'

// Resource Group az104-rg2 (Governance)
resource rg2 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'az104-rg2'
  location: location
  tags: {
    'Cost Center': costCenter
  }
}

// Resource Group az104-rg3 (IaC)
resource rg3 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'az104-rg3'
  location: location
  tags: {
    'Cost Center': costCenter
  }
}

output rg2Name string = rg2.name
output rg3Name string = rg3.name
```

Deploy:

```bash
# Deploy no scope de subscription (NAO resource group!)
# Comando diferente: 'az deployment sub create' (nao 'group create')
az deployment sub create \
    --location "$LOCATION" \
    --template-file bloco2-rgs.bicep

echo "RGs az104-rg2 e az104-rg3 criados com tag Cost Center = 000"
```

> **Conceito:** Note `targetScope = 'subscription'` e o comando `az deployment sub create`.
> Scopes diferentes requerem comandos diferentes!

---

### Task 2.6-2.7: Aplicar Deny policy (testar) e substituir por Modify no rg2

```bash
# ============================================================
# TASK 2.6 - Aplicar policy Deny, testar e remover (CLI)
# ============================================================

# Obter ID da policy "Require a tag and its value on resources"
POLICY_DENY_ID=$(az policy definition list \
    --query "[?displayName=='Require a tag and its value on resources'].name" -o tsv)

# Atribuir ao rg2
az policy assignment create \
    --name "RequireCostCenterTag-rg2" \
    --display-name "Require Cost Center tag with value 000 on resources" \
    --policy "$POLICY_DENY_ID" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}" \
    --params '{"tagName":{"value":"Cost Center"},"tagValue":{"value":"000"}}'

echo "Aguarde 5-15 min para a policy entrar em vigor, depois teste..."
```

```bash
# Testar (deve falhar apos propagacao da policy)
az disk create --resource-group "$RG2" --name "test-deny-disk" \
    --size-gb 32 --sku Standard_LRS --location "$LOCATION" 2>&1 || \
    echo "✓ Policy Deny bloqueou criacao!"

# Remover Deny policy
az policy assignment delete \
    --name "RequireCostCenterTag-rg2" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}"
echo "Policy Deny removida"
```

---

### Task 2.7-2.8: Aplicar Modify policy (Inherit tag) via Bicep

Salve como **`bloco2-policies-rg2.bicep`**:

```bicep
// ============================================================
// bloco2-policies-rg2.bicep
// Scope: resourceGroup (az104-rg2)
// Aplica policy Modify: Inherit tag from resource group
// ============================================================

@description('Nome da tag a herdar')
param tagName string = 'Cost Center'

// Referencia a policy definition built-in pelo ID
// "Inherit a tag from the resource group if missing"
// ID fixo da built-in: cd3aa116-8754-49c9-a813-ad46512ece54
var policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54'

// Policy assignment com Managed Identity
// O efeito Modify REQUER Managed Identity para alterar recursos
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'InheritCostCenter-rg2'
  // identity: cria Managed Identity (SystemAssigned)
  // Necessario para policies com efeito Modify
  identity: {
    type: 'SystemAssigned'
  }
  location: resourceGroup().location
  properties: {
    displayName: 'Inherit the Cost Center tag and its value 000 from the resource group if missing'
    policyDefinitionId: policyDefinitionId
    parameters: {
      tagName: {
        value: tagName
      }
    }
  }
}

// A Managed Identity precisa de role "Tag Contributor" para modificar tags
// Referencia a built-in role "Tag Contributor"
var tagContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')

// Atribuir role a Managed Identity da policy
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, policyAssignment.name, 'TagContributor')
  properties: {
    roleDefinitionId: tagContributorRoleId
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output policyAssignmentId string = policyAssignment.id
output managedIdentityId string = policyAssignment.identity.principalId
```

Deploy no rg2:

```bash
az deployment group create \
    --resource-group "$RG2" \
    --template-file bloco2-policies-rg2.bicep

echo "Policy Modify + Tag Contributor atribuidas ao $RG2"
```

---

### Task 2.8-2.10: Policies no rg3 + Reader role

Salve como **`bloco2-policies-rg3.bicep`**:

```bicep
// ============================================================
// bloco2-policies-rg3.bicep
// Scope: resourceGroup (az104-rg3)
// Aplica: Modify (inherit tag) + Allowed Locations + Reader role
// ============================================================

@description('Nome da tag a herdar')
param tagName string = 'Cost Center'

@description('Object ID do guest user para Reader role')
param guestUserId string

// --- Policy Modify: Inherit tag ---
var inheritPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54'

resource inheritPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'InheritCostCenter-rg3'
  identity: {
    type: 'SystemAssigned'
  }
  location: resourceGroup().location
  properties: {
    displayName: 'Inherit Cost Center tag on az104-rg3 resources'
    policyDefinitionId: inheritPolicyId
    parameters: {
      tagName: { value: tagName }
    }
  }
}

// Tag Contributor para a Managed Identity da policy
var tagContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')

resource tagContributorRg3 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, inheritPolicy.name, 'TagContributor')
  properties: {
    roleDefinitionId: tagContributorRoleId
    principalId: inheritPolicy.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Policy Deny: Allowed Locations ---
// "Allowed locations" - ID fixo: e56962a6-4747-49cd-b67b-bf8b01975c4c
var allowedLocationsPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'

resource allowedLocationsPolicy 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'AllowedLocations-rg3'
  properties: {
    displayName: 'Restrict resources to East US only'
    policyDefinitionId: allowedLocationsPolicyId
    parameters: {
      listOfAllowedLocations: {
        value: [ 'eastus' ]
      }
    }
  }
}

// --- RBAC: Reader para guest user ---
// "Reader" role ID: acdd72a7-3385-48ef-bd42-f606fba81ae7
var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, guestUserId, 'Reader')
  properties: {
    roleDefinitionId: readerRoleId
    principalId: guestUserId
    principalType: 'User'
  }
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco2-policies-rg3.bicep \
    --parameters guestUserId="$GUEST_ID"

echo "Policies + Reader atribuidos ao $RG3"
echo ">>> Aguarde 5-15 min para as policies entrarem em vigor <<<"
```

---

### Task 2.11: Criar Resource Lock via Bicep

Salve como **`bloco2-lock.bicep`**:

```bicep
// ============================================================
// bloco2-lock.bicep
// Scope: resourceGroup (az104-rg2)
// Cria Delete Lock
// ============================================================

// Resource Lock: protege contra exclusao acidental
// Locks sobrescrevem QUALQUER permissao, incluindo Owner
resource deleteLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'rg-lock'
  properties: {
    level: 'CanNotDelete'    // Permite modificar, impede exclusao
    // Outra opcao: 'ReadOnly' - impede modificacao E exclusao
    notes: 'Protege o resource group contra exclusao acidental'
  }
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG2" \
    --template-file bloco2-lock.bicep

echo "Delete Lock criado no $RG2"

# Testar: tentar deletar o RG (deve falhar)
az group delete --name "$RG2" --yes 2>&1 || echo "✓ Lock impediu exclusao!"
```

---

### Task 2.12: Criar Policy Initiative via Bicep

> **Conceito:** Uma **Initiative** (Policy Set) agrupa multiplas policy definitions
> em um conjunto unico. Em vez de atribuir 3 policies individualmente,
> voce atribui 1 initiative. Isso simplifica governanca em escala.
>
> Neste lab, ja atribuimos as policies individualmente (Tasks 2.6-2.9).
> Agora criamos uma initiative para aprender o conceito.

Salve como **`bloco2-initiative.bicep`**:

```bicep
// ============================================================
// bloco2-initiative.bicep
// Scope: subscription
// Cria uma Policy Initiative (Policy Set Definition) agrupando
// as 3 policies usadas neste lab
// ============================================================

targetScope = 'subscription'

// IDs das built-in policies que compoem a initiative
var requireTagPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62'
var inheritTagPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54'
var allowedLocationsPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'

// Policy Set Definition (Initiative)
// Agrupa 3 policies com parametros compartilhados
resource initiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'az104-governance-initiative'
  properties: {
    displayName: 'AZ-104 Lab Governance Initiative'
    description: 'Agrupa 3 policies: require tag, inherit tag, allowed locations'
    policyType: 'Custom'

    // Parametros que a initiative expoe (quem atribui fornece os valores)
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Nome da tag obrigatoria (ex: Cost Center)'
        }
      }
      tagValue: {
        type: 'String'
        metadata: {
          displayName: 'Tag Value'
          description: 'Valor obrigatorio da tag (ex: 000)'
        }
      }
      allowedLocations: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed Locations'
          description: 'Lista de regioes permitidas'
        }
      }
    }

    // As 3 policies que compoem a initiative
    // Cada uma mapeia seus parametros para os parametros da initiative
    policyDefinitions: [
      {
        policyDefinitionId: requireTagPolicyId
        parameters: {
          tagName:  { value: '[parameters(\'tagName\')]' }
          tagValue: { value: '[parameters(\'tagValue\')]' }
        }
      }
      {
        policyDefinitionId: inheritTagPolicyId
        parameters: {
          tagName: { value: '[parameters(\'tagName\')]' }
        }
      }
      {
        policyDefinitionId: allowedLocationsPolicyId
        parameters: {
          listOfAllowedLocations: { value: '[parameters(\'allowedLocations\')]' }
        }
      }
    ]
  }
}

output initiativeId string = initiative.id
```

Deploy:

```bash
# Deploy no scope de subscription (initiative e definida na subscription)
az deployment sub create \
    --location "$LOCATION" \
    --template-file bloco2-initiative.bicep

# Verificar criacao
az policy set-definition show \
    --name "az104-governance-initiative" \
    --query "{name:name, displayName:displayName, policies:length(policyDefinitions)}" \
    -o table
```

> **Conceito Bicep:** Note que `targetScope = 'subscription'` porque
> Policy Set Definitions sao recursos de subscription.
>
> **Conceito AZ-104:**
> - **Policy Definition**: regra individual (ex: "require tag")
> - **Policy Set Definition (Initiative)**: grupo de regras relacionadas
> - **Policy Assignment**: aplicacao de uma definition OU initiative a um scope
> - Em producao, initiatives sao o padrao — policies individuais sao raras
> - Initiatives built-in do Azure: "CIS Benchmark", "NIST 800-53", "ISO 27001"

---

### Task 2.13: Teste de integracao

```bash
# ============================================================
# TASK 2.13 - Verificar RBAC (informativo)
# ============================================================

echo "=== Verificacao de RBAC ==="
echo "Para teste manual: login como az104-user1@${TENANT_DOMAIN} em InPrivate"
echo ""
echo "O que az104-user1 PODE fazer:"
echo "  ✓ Gerenciar VMs (VM Contributor no MG)"
echo ""
echo "O que az104-user1 NAO PODE fazer:"
echo "  ✗ Criar Storage Accounts"
echo "  ✗ Deletar az104-rg2 (Lock + sem permissao)"
```

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `az104-mg1` e mover subscription
- [ ] Atribuir **VM Contributor** ao grupo `IT Lab Administrators`
- [ ] Deploy `bloco2-custom-role.bicep` no scope managementGroup
- [ ] Deploy `bloco2-rgs.bicep` no scope subscription
- [ ] Testar Deny policy via CLI → remover
- [ ] Deploy `bloco2-policies-rg2.bicep` (Modify + Tag Contributor)
- [ ] Deploy `bloco2-policies-rg3.bicep` (Modify + Allowed Locations + Reader)
- [ ] Deploy `bloco2-lock.bicep` (Delete lock)
- [ ] Testar exclusao do RG → bloqueada por lock
- [ ] Deploy `bloco2-initiative.bicep` no scope subscription (Policy Initiative)

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce atribuiu VM Contributor a um grupo no Management Group. Um membro tenta criar Storage Account. O que acontece?**

A) Permitida
B) Falha — VM Contributor nao inclui permissoes de Storage
C) Permitida no nivel de MG
D) Depende do RG

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

</details>

### Questao 2.2
**Qual efeito de policy requer Managed Identity?**

A) Deny
B) Audit
C) Modify
D) Append

<details>
<summary>Ver resposta</summary>

**Resposta: C) Modify**

Modify altera recursos automaticamente e precisa de identidade com permissao adequada.

</details>

### Questao 2.3
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

### Questao 2.4
**Owner tenta excluir RG com Delete lock. O que acontece?**

A) Excluido
B) Bloqueado — locks sobrescrevem permissoes
C) Gera alerta
D) Bloqueado apenas sem Owner

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

</details>

### Questao 2.5
**Qual a diferenca entre Policy Definition e Policy Initiative (Policy Set)?**

A) Initiative e uma policy com efeito mais forte
B) Initiative agrupa multiplas policy definitions em um conjunto unico
C) Initiative substitui policy definitions — nao podem coexistir
D) Initiative so funciona com policies custom, nao built-in

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

Uma Initiative (Policy Set Definition) e um grupo de policies relacionadas que podem ser
atribuidas como unidade. Pode conter policies built-in E custom.

</details>

### Questao 2.6
**Reader role em um RG permite o usuario...?**

A) Criar e modificar recursos
B) Apenas visualizar, sem criar ou modificar
C) Gerenciar VMs
D) Nada — guests nao recebem roles

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

</details>

---

# Bloco 3 - Azure Resources & IaC

**Tecnologia:** Bicep (template parametrizado + loop)
**Recursos criados:** 5 managed disks em az104-rg3

---

### Task 3.1-3.5: Deploy de 5 discos via template parametrizado

Salve como **`bloco3-disk.bicep`**:

```bicep
// ============================================================
// bloco3-disk.bicep
// Scope: resourceGroup (az104-rg3)
// Cria managed disk parametrizado (reusavel para todos os 5 discos)
// ============================================================

@description('Nome do managed disk')
param diskName string

@description('Tamanho do disco em GiB')
@minValue(4)        // Decorator: valida valor minimo
@maxValue(32767)    // Decorator: valida valor maximo
param diskSizeGB int = 32

@description('Tipo de disco (SKU)')
@allowed([          // Decorator: restringe valores aceitos
  'Standard_LRS'      // Standard HDD
  'StandardSSD_LRS'   // Standard SSD
  'Premium_LRS'       // Premium SSD
  'UltraSSD_LRS'      // Ultra Disk
])
param diskSku string = 'Standard_LRS'

@description('Localizacao do disco')
param location string = resourceGroup().location

// resource: declara o managed disk
// Dependencias implicitas: Bicep detecta que location vem de param
// (diferente de ARM JSON que precisaria de dependsOn explicito)
resource disk 'Microsoft.Compute/disks@2023-10-02' = {
  name: diskName
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

output diskId string = disk.id
output diskName string = disk.name
```

Deploy dos 5 discos:

```bash
# ============================================================
# Deploy dos 5 discos - um por um
# ============================================================

# Disco 1 (Standard HDD)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk1

# Verificar tag herdada
echo "=== Verificando tag do az104-disk1 ==="
az disk show -g "$RG3" -n az104-disk1 --query tags -o json
# Esperado: {"Cost Center": "000"}

# Disco 2
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk2

# Disco 3
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk3

# Disco 4
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk4

# Disco 5 (Standard SSD - diferente dos anteriores)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk5 diskSku=StandardSSD_LRS

# Listar todos os discos
echo ""
echo "=== Todos os discos em $RG3 ==="
az disk list -g "$RG3" --query "[].{name:name, size:diskSizeGb, sku:sku.name, tags:tags}" -o table
```

> **Alternativa avancada com loop:** Voce pode usar `for` no Bicep para criar todos de uma vez:

```bicep
// bloco3-disks-loop.bicep (alternativa educativa - NAO obrigatorio)
// Demonstra o loop for do Bicep

param diskNames array = [
  'az104-disk1'
  'az104-disk2'
  'az104-disk3'
  'az104-disk4'
  'az104-disk5'
]

param location string = resourceGroup().location

// Loop: cria um disco para cada item no array
// O 'for' e uma feature exclusiva do Bicep (ARM JSON nao tem equivalente direto)
resource disks 'Microsoft.Compute/disks@2023-10-02' = [for name in diskNames: {
  name: name
  location: location
  sku: {
    name: name == 'az104-disk5' ? 'StandardSSD_LRS' : 'Standard_LRS'
    // Operador ternario: disk5 usa SSD, demais usam HDD
  }
  properties: {
    creationData: { createOption: 'Empty' }
    diskSizeGB: 32
  }
}]
```

---

### Task 3.6: Teste de integracao — Allowed Locations policy

```bash
# ============================================================
# TASK 3.6 - Testar policy Allowed Locations (East US only)
# ============================================================

# Tentar deploy em West US (deve falhar!)
az deployment group create \
    --resource-group "$RG3" \
    --template-file bloco3-disk.bicep \
    --parameters diskName=az104-disk-test location=westus 2>&1 || \
    echo "✓ Policy Allowed Locations bloqueou deploy em West US!"

# Confirmar que apenas 5 discos existem
az disk list -g "$RG3" --query "length(@)"
# Esperado: 5
```

---

### Task 3.7: Teste de integracao — Guest user (informativo)

```bash
# O guest user tem Reader no az104-rg3
# Verificar programaticamente:
az role assignment list \
    --resource-group "$RG3" \
    --assignee "$GUEST_ID" \
    --query "[].{role:roleDefinitionName}" -o table

echo ">>> Para teste manual: login como guest em InPrivate <<<"
```

---

## Modo Desafio - Bloco 3

- [ ] Deploy `bloco3-disk.bicep` com `diskName=az104-disk1` a `az104-disk4`
- [ ] Deploy `az104-disk5` com `diskSku=StandardSSD_LRS`
- [ ] Verificar tag `Cost Center = 000` herdada em cada disco
- [ ] **Integracao:** Testar deploy com `location=westus` → bloqueado
- [ ] (Bonus) Experimentar `bloco3-disks-loop.bicep` com `for`

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Policy Modify "Inherit tag" no rg3. Disco criado via Bicep sem tags. O que acontece?**

A) Criado sem tags
B) Herda tag Cost Center = 000 automaticamente
C) Deploy falha
D) Marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: B)**

</details>

### Questao 3.2
**Qual comando deploya um template Bicep em um Resource Group?**

A) `az deployment sub create`
B) `az deployment group create`
C) `az bicep deploy`
D) `az template deploy`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `az deployment group create`**

Scopes: `group` (RG), `sub` (subscription), `mg` (management group), `tenant`.

</details>

### Questao 3.3
**Qual feature do Bicep NAO existe em ARM JSON?**

A) Parameters
B) Variables
C) Implicit dependencies (sem dependsOn)
D) Outputs

<details>
<summary>Ver resposta</summary>

**Resposta: C) Implicit dependencies**

Bicep detecta dependencias automaticamente quando um recurso referencia outro. ARM JSON requer `dependsOn` explicito.

</details>

---

# Bloco 4 - Virtual Networking

**Tecnologia:** Bicep
**Recursos criados:** 2 VNets, subnets, 1 ASG, 1 NSG, DNS zones, VNet link

---

### Task 4.1-4.2: Criar ambas as VNets

Salve como **`bloco4-networking.bicep`**:

```bicep
// ============================================================
// bloco4-networking.bicep
// Scope: resourceGroup (az104-rg4)
// Cria 2 VNets com subnets + ASG + NSG
// ============================================================

param location string = resourceGroup().location

// ==================== VNet 1: CoreServicesVnet ====================
resource coreVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'CoreServicesVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.20.0.0/16' ]
    }
    subnets: [
      {
        name: 'SharedServicesSubnet'
        properties: {
          addressPrefix: '10.20.10.0/24'
          networkSecurityGroup: {
            id: nsg.id        // Dependencia implicita: Bicep sabe que o NSG precisa existir antes!
          }
        }
      }
      {
        name: 'DatabaseSubnet'
        properties: {
          addressPrefix: '10.20.20.0/24'
        }
      }
    ]
  }
}

// ==================== VNet 2: ManufacturingVnet ====================
resource mfgVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'ManufacturingVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.30.0.0/16' ]
    }
    subnets: [
      {
        name: 'SensorSubnet1'
        properties: {
          addressPrefix: '10.30.20.0/24'
        }
      }
      {
        name: 'SensorSubnet2'
        properties: {
          addressPrefix: '10.30.21.0/24'
        }
      }
    ]
  }
}

// ==================== ASG ====================
// Application Security Group: agrupa VMs logicamente
resource asg 'Microsoft.Network/applicationSecurityGroups@2023-05-01' = {
  name: 'asg-web'
  location: location
}

// ==================== NSG ====================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'myNSGSecure'
  location: location
  properties: {
    securityRules: [
      // Regra Inbound: Allow ASG na porta 80,443
      {
        name: 'AllowASG'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            { id: asg.id }   // Referencia implicita ao ASG (dependencia automatica!)
          ]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [ '80', '443' ]
        }
      }
      // Regra Outbound: Deny Internet
      {
        name: 'DenyInternetOutbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'   // Service tag
          destinationPortRange: '*'
        }
      }
    ]
  }
}

output coreVnetId string = coreVnet.id
output mfgVnetId string = mfgVnet.id
output nsgId string = nsg.id
```

Deploy:

```bash
# Criar RG para networking
az group create --name "$RG4" --location "$LOCATION"

# Deploy networking
az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco4-networking.bicep

echo "VNets, ASG e NSG criados"
```

> **Conceito Bicep:** Note como as dependencias sao **implicitas**:
> - `asg.id` dentro do NSG cria dependencia automatica NSG → ASG
> - `nsg.id` dentro da subnet inline cria dependencia automatica VNet → NSG
> Em ARM JSON, voce precisaria de `dependsOn` explicito para cada uma!

---

### Task 4.5-4.6: Criar DNS zones

Salve como **`bloco4-dns.bicep`**:

```bicep
// ============================================================
// bloco4-dns.bicep
// Scope: resourceGroup (az104-rg4)
// Cria DNS public zone + private zone + VNet link
// ============================================================

// ==================== DNS Public Zone ====================
// DNS zones sao recursos GLOBAIS (nao tem location especifica)
resource publicDns 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: 'contoso.com'
  location: 'global'     // DNS zones sao sempre 'global'
}

// Registro A: www.contoso.com → 10.1.1.4
resource wwwRecord 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: publicDns      // Indica que este recurso e filho de publicDns
  name: 'www'
  properties: {
    TTL: 1
    ARecords: [
      { ipv4Address: '10.1.1.4' }
    ]
  }
}

// ==================== DNS Private Zone ====================
resource privateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'private.contoso.com'
  location: 'global'
}

// Virtual Network Link: ManufacturingVnet
// Referencia a VNet usando 'existing' keyword
resource mfgVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'ManufacturingVnet'
  // Nao precisa de scope pois esta no mesmo RG
}

resource mfgLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDns
  name: 'manufacturing-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: mfgVnet.id     // Referencia a VNet existente
    }
    registrationEnabled: false
  }
}

// Registro A placeholder
resource sensorRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDns
  name: 'sensorvm'
  properties: {
    ttl: 1
    aRecords: [
      { ipv4Address: '10.1.1.4' }
    ]
  }
}

output nameServers array = publicDns.properties.nameServers
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco4-dns.bicep

echo "DNS zones criadas"

# Testar resolucao da zona publica
NS=$(az network dns zone show -g "$RG4" -n contoso.com --query "nameServers[0]" -o tsv)
echo "Teste: nslookup www.contoso.com $NS"
nslookup www.contoso.com "$NS"
```

> **Conceito `existing`:** A keyword `existing` referencia um recurso que ja existe.
> NAO cria o recurso — apenas obtem seu ID para uso no template.
> Se o recurso nao existir, o deploy falha.

---

## Modo Desafio - Bloco 4

- [ ] Deploy `bloco4-networking.bicep` (2 VNets + ASG + NSG)
- [ ] Verificar que NSG esta associado apenas a SharedServicesSubnet
- [ ] Deploy `bloco4-dns.bicep` (DNS public + private + link)
- [ ] Testar nslookup via CLI

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**NSG na SharedServicesSubnet. VM em DatabaseSubnet e afetada?**

A) Sim, NSG se aplica a toda a VNet
B) Nao, NSG se aplica apenas a subnet associada
C) Sim, se ASG incluir a VM
D) Depende da priority

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 4.2
**IPs utilizaveis em /24 no Azure?**

A) 256  B) 254  C) 251  D) 250

<details><summary>Ver resposta</summary>**Resposta: C) 251** (5 reservados)</details>

### Questao 4.3
**Rule A (100, Allow, 80) e Rule B (200, Deny, 80). Pacote na porta 80?**

A) Negado  B) Permitido  C) Todas avaliadas  D) Mais Allow vence

<details><summary>Ver resposta</summary>**Resposta: B)** Priority menor (100) e processada primeiro.</details>

### Questao 4.4
**Diferenca entre DNS public e private zones?**

A) Public gratuita  B) Public resolve na internet, private em VNets linkadas  C) Private mais tipos  D) Public requer VPN

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 4.5
**DNS privada linkada a VNet A. VM na VNet B (nao linkada) resolve?**

A) Sim  B) Falha — sem link  C) Via DNS publico  D) Apenas com peering

<details><summary>Ver resposta</summary>**Resposta: B)** Peering NAO propaga DNS.</details>

---

# Bloco 5 - Intersite Connectivity

**Tecnologia:** Bicep + CLI (para Run Command e Network Watcher)
**Recursos criados:** 2 subnets, 2 VMs, peering, VNet link, DNS record, route table

> **Nota:** Este bloco cria VMs que geram custo. Faca cleanup assim que terminar.

---

### Task 5.1: Adicionar subnets para VMs (CLI)

```bash
# ============================================================
# TASK 5.1 - Adicionar subnets Core e Manufacturing (CLI)
# ============================================================
# Subnets adicionais sao mais simples via CLI do que Bicep
# (em Bicep precisaria re-declarar toda a VNet ou usar existing + child)

az network vnet subnet create \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --name "Core" \
    --address-prefixes "10.20.0.0/24"

az network vnet subnet create \
    --resource-group "$RG4" \
    --vnet-name "ManufacturingVnet" \
    --name "Manufacturing" \
    --address-prefixes "10.30.0.0/24"

echo "Subnets Core e Manufacturing adicionadas"
```

---

### Task 5.2-5.3: Criar VMs via Bicep

Salve como **`bloco5-vms.bicep`**:

```bicep
// ============================================================
// bloco5-vms.bicep
// Scope: resourceGroup (az104-rg5)
// Cria 2 VMs com NICs referenciando VNets em OUTRO RG (az104-rg4)
// ============================================================

param location string = resourceGroup().location

@description('Username do admin local')
param adminUsername string = 'localadmin'

@description('Senha do admin local')
@secure()    // Decorator @secure: valor NAO aparece em logs/outputs
param adminPassword string

@description('RG onde as VNets estao')
param vnetResourceGroup string = 'az104-rg4'

// ==================== Referencia CROSS-RG a VNets ====================
// 'existing' + 'scope' permite referenciar recursos em outro RG!
// Isso e essencial quando recursos estao organizados em RGs diferentes

// Referencia a CoreServicesVnet (em az104-rg4)
resource coreVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'CoreServicesVnet'
  scope: resourceGroup(vnetResourceGroup)  // Aponta para OUTRO resource group!
}

// Referencia a subnet Core dentro da VNet
resource coreSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: coreVnet
  name: 'Core'
}

// Referencia a ManufacturingVnet (em az104-rg4)
resource mfgVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'ManufacturingVnet'
  scope: resourceGroup(vnetResourceGroup)
}

resource mfgSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: mfgVnet
  name: 'Manufacturing'
}

// ==================== NIC: CoreServicesVM ====================
resource coreNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'CoreServicesVM-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: coreSubnet.id  // Referencia cross-RG via 'existing'
          }
        }
      }
    ]
  }
}

// ==================== NIC: ManufacturingVM ====================
resource mfgNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'ManufacturingVM-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: mfgSubnet.id   // Referencia cross-RG
          }
        }
      }
    ]
  }
}

// ==================== VM: CoreServicesVM ====================
resource coreVM 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'CoreServicesVM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'CoreServicesVM'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-azure-edition'
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
      networkInterfaces: [
        { id: coreNic.id }    // Dependencia implicita: VM espera NIC ser criada
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// ==================== VM: ManufacturingVM ====================
resource mfgVM 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'ManufacturingVM'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'ManufacturingVM'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-azure-edition'
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
      networkInterfaces: [
        { id: mfgNic.id }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

output coreVmId string = coreVM.id
output mfgVmId string = mfgVM.id
output coreNicPrivateIp string = coreNic.properties.ipConfigurations[0].properties.privateIPAddress
```

Deploy:

```bash
# Criar RG para VMs
az group create --name "$RG5" --location "$LOCATION"

# Deploy VMs (pode levar 5-10 min)
az deployment group create \
    --resource-group "$RG5" \
    --template-file bloco5-vms.bicep \
    --parameters adminPassword="$VM_PASSWORD"

echo "VMs criadas"
```

---

### Task 5.4: Network Watcher — Connection Troubleshoot

```bash
# ============================================================
# TASK 5.4 - Testar conectividade ANTES do peering (CLI)
# ============================================================
# Network Watcher nao e gerenciado via Bicep — e uma ferramenta operacional

az network watcher test-connectivity \
    --resource-group "$RG5" \
    --source-resource "CoreServicesVM" \
    --dest-resource "ManufacturingVM" \
    --dest-port 3389

# Esperado: connectionStatus = Unreachable
echo "✓ VNets diferentes NAO se comunicam sem peering"
```

---

### Task 5.5: Configurar VNet Peering via Bicep

Salve como **`bloco5-peering.bicep`**:

```bicep
// ============================================================
// bloco5-peering.bicep
// Scope: resourceGroup (az104-rg4)
// Cria peering bidirecional entre as 2 VNets
// ============================================================

// Referenciar VNets existentes
resource coreVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'CoreServicesVnet'
}

resource mfgVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'ManufacturingVnet'
}

// Peering 1: Core → Manufacturing
// VNet Peering precisa ser criado em AMBAS as direcoes
resource peeringCoreToMfg 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: coreVnet
  name: 'CoreServicesVnet-to-ManufacturingVnet'
  properties: {
    remoteVirtualNetwork: {
      id: mfgVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true       // Permite trafego encaminhado (ex: NVA)
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// Peering 2: Manufacturing → Core
resource peeringMfgToCore 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: mfgVnet
  name: 'ManufacturingVnet-to-CoreServicesVnet'
  properties: {
    remoteVirtualNetwork: {
      id: coreVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
```

Deploy:

```bash
az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco5-peering.bicep

# Verificar status
az network vnet peering list \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --query "[].{name:name, status:peeringState}" -o table
```

> **Conceito:** VNet Peering e **NAO transitivo** (A↔B + B↔C ≠ A↔C).

---

### Task 5.6: Testar conexao via Run Command

```bash
# ============================================================
# TASK 5.6 - Testar conectividade APOS peering
# ============================================================

# Obter IP privado da CoreServicesVM
CORE_IP=$(az vm show -g "$RG5" -n "CoreServicesVM" -d --query privateIps -o tsv)
echo "CoreServicesVM IP: $CORE_IP"

# Run Command: executa script dentro da VM
az vm run-command invoke \
    --resource-group "$RG5" \
    --name "ManufacturingVM" \
    --command-id RunPowerShellScript \
    --scripts "Test-NetConnection $CORE_IP -Port 3389"

# Esperado: TcpTestSucceeded: True
```

---

### Task 5.7: DNS privado com IP real + VNet link

Salve como **`bloco5-dns-update.bicep`**:

```bicep
// ============================================================
// bloco5-dns-update.bicep
// Scope: resourceGroup (az104-rg4)
// Adiciona link para CoreServicesVnet + registro com IP real
// ============================================================

@description('IP privado da CoreServicesVM')
param coreVmIp string

// Referenciar DNS zone e VNet existentes
resource privateDns 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'private.contoso.com'
}

resource coreVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: 'CoreServicesVnet'
}

// Link para CoreServicesVnet
resource coreLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDns
  name: 'coreservices-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: coreVnet.id
    }
    registrationEnabled: false
  }
}

// Registro A com IP real
resource coreVmRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDns
  name: 'corevm'
  properties: {
    ttl: 1
    aRecords: [
      { ipv4Address: coreVmIp }
    ]
  }
}
```

Deploy:

```bash
CORE_IP=$(az vm show -g "$RG5" -n "CoreServicesVM" -d --query privateIps -o tsv)

az deployment group create \
    --resource-group "$RG4" \
    --template-file bloco5-dns-update.bicep \
    --parameters coreVmIp="$CORE_IP"

# Testar resolucao DNS a partir da ManufacturingVM
az vm run-command invoke \
    --resource-group "$RG5" \
    --name "ManufacturingVM" \
    --command-id RunPowerShellScript \
    --scripts "Resolve-DnsName corevm.private.contoso.com"
```

---

### Task 5.8: Route Table + custom route via Bicep

Salve como **`bloco5-route.bicep`**:

```bicep
// ============================================================
// bloco5-route.bicep
// Scope: resourceGroup (az104-rg5)
// Cria Route Table + custom route + associa a subnet Core
// ============================================================

param location string = resourceGroup().location

@description('RG onde a VNet esta')
param vnetResourceGroup string = 'az104-rg4'

// Route Table
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-CoreServices'
  location: location
  properties: {
    disableBgpRoutePropagation: true   // Nao propaga rotas BGP
    routes: [
      {
        name: 'PerimetertoCore'
        properties: {
          addressPrefix: '10.20.0.0/16'
          nextHopType: 'VirtualAppliance'   // Direciona para NVA
          nextHopIpAddress: '10.20.1.7'     // IP do NVA
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
```

Deploy + associar + criar subnet perimeter:

```bash
# Deploy Route Table
az deployment group create \
    --resource-group "$RG5" \
    --template-file bloco5-route.bicep

# Criar subnet perimeter
az network vnet subnet create \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --name "perimeter" \
    --address-prefixes "10.20.1.0/24"

# Associar route table a subnet Core (CLI mais simples que Bicep aqui)
RT_ID=$(az network route-table show -g "$RG5" -n "rt-CoreServices" --query id -o tsv)

az network vnet subnet update \
    --resource-group "$RG4" \
    --vnet-name "CoreServicesVnet" \
    --name "Core" \
    --route-table "$RT_ID"

echo "Route table associada a subnet Core"
```

> **Conceito:** UDRs sobrescrevem rotas do sistema. Trafego para NVA inexistente e descartado.

---

### Task 5.9: Verificar isolamento NSG

```bash
# ============================================================
# TASK 5.9 - Verificar NSG isolado por subnet
# ============================================================

az network nsg show -g "$RG4" -n "myNSGSecure" \
    --query "subnets[].id" -o table

echo ""
echo "NSG associado APENAS a SharedServicesSubnet"
echo "CoreServicesVM (subnet Core) e ManufacturingVM (subnet Manufacturing)"
echo "NAO sao afetadas pelo NSG."
```

---

### Task 5.10: Teste RBAC final

```bash
# ============================================================
# TASK 5.10 - Teste RBAC end-to-end (informativo)
# ============================================================

echo "=== Teste Final RBAC ==="
echo "Login como az104-user1@${TENANT_DOMAIN} em InPrivate"
echo ""
echo "1. VMs → deve ver CoreServicesVM e ManufacturingVM"
echo "2. Stop VM → deve funcionar (VM Contributor)"
echo "3. Deletar az104-rg2 → deve falhar (Lock + sem permissao)"
echo "4. Criar Storage → deve falhar (VM Contributor ≠ Storage)"
```

---

## Modo Desafio - Bloco 5

- [ ] Adicionar subnets `Core` e `Manufacturing` via CLI
- [ ] Deploy `bloco5-vms.bicep` (VMs com referencia cross-RG via `existing`)
- [ ] Network Watcher → Unreachable
- [ ] Deploy `bloco5-peering.bicep` (peering bidirecional)
- [ ] Test-NetConnection via Run Command → Success
- [ ] Deploy `bloco5-dns-update.bicep` (link + registro A real)
- [ ] Resolve-DnsName via Run Command
- [ ] Deploy `bloco5-route.bicep` + associar subnet
- [ ] Verificar NSG isolado por subnet
- [ ] Teste RBAC final

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**VM no rg5 usa VNet do rg4. Possivel?**

A) Nao, mesmo RG obrigatorio  B) Sim, qualquer RG na mesma subscription  C) Apenas via ARM  D) VNet deve ser movida

<details><summary>Ver resposta</summary>**Resposta: B)** Em Bicep, use `existing` com `scope: resourceGroup('rg4')`.</details>

### Questao 5.2
**A↔B peering, B↔C peering. A comunica com C?**

A) Sim  B) Nao, peering NAO e transitivo  C) Sim com forwarded traffic  D) Precisa VPN

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 5.3
**UDR com next hop IP 10.20.1.7 sem NVA. Trafego?**

A) Roteado normalmente  B) Descartado  C) Azure cria NVA  D) Gateway padrao

<details><summary>Ver resposta</summary>**Resposta: B)**</details>

### Questao 5.4
**Peering + NVA. O que configurar?**

A) NSG  B) UDR com next hop NVA  C) IP forwarding apenas  D) VPN Gateway

<details><summary>Ver resposta</summary>**Resposta: B)** + IP forwarding no NVA.</details>

### Questao 5.5
**DNS privada linkada a VNet A. VM na VNet B (com peering) resolve?**

A) Sim  B) Falha — sem link  C) Com forwarded traffic  D) Com DNS forwarder

<details><summary>Ver resposta</summary>**Resposta: B)** Peering NAO propaga DNS.</details>

---

# Cleanup Unificado

```bash
# ============================================================
# CLEANUP - Remover TODOS os recursos
# ============================================================

# 1. Remover Policy Assignments
echo "1. Removendo policies..."
az policy assignment delete --name "InheritCostCenter-rg2" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG2}" 2>/dev/null
az policy assignment delete --name "InheritCostCenter-rg3" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG3}" 2>/dev/null
az policy assignment delete --name "AllowedLocations-rg3" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG3}" 2>/dev/null
az policy set-definition delete --name "az104-governance-initiative" 2>/dev/null

# 2. Remover Lock
echo "2. Removendo lock..."
az lock delete --name "rg-lock" --resource-group "$RG2" 2>/dev/null

# 3. Deletar RGs (VMs primeiro)
echo "3. Deletando RGs..."
az group delete --name "$RG5" --yes --no-wait
az group delete --name "$RG4" --yes --no-wait
az group delete --name "$RG3" --yes --no-wait
az group delete --name "$RG2" --yes --no-wait

# 4. Management Group
echo "4. Removendo MG..."
az account management-group subscription remove --name "$MG_NAME" \
    --subscription "$SUBSCRIPTION_ID" 2>/dev/null
az account management-group delete --name "$MG_NAME" 2>/dev/null

# 5. Custom Role
echo "5. Removendo custom role..."
az role definition delete --name "Custom Support Request" 2>/dev/null

# 6. Usuarios e grupos
echo "6. Removendo identidades..."
az ad user delete --id "az104-user1@${TENANT_DOMAIN}" 2>/dev/null
az ad user delete --id "$GUEST_ID" 2>/dev/null
az ad group delete --group "IT Lab Administrators" 2>/dev/null
az ad group delete --group "helpdesk" 2>/dev/null

echo ""
echo "=== CLEANUP COMPLETO ==="
```

---

# Key Takeaways Consolidados

## Bicep vs ARM JSON vs Portal

| Aspecto | Bicep | ARM JSON | Portal |
|---------|-------|----------|--------|
| Sintaxe | Concisa, declarativa | Verbosa, JSON | Visual |
| Dependencias | **Implicitas** (automaticas) | Explicitas (`dependsOn`) | N/A |
| Type safety | Decorators (`@allowed`, `@minValue`) | Nenhum | Validacao visual |
| Reutilizacao | Modules, loops (`for`) | Linked/nested templates | N/A |
| Cross-RG | `existing` + `scope` | `resourceId('rg', 'type', 'name')` | Dropdown |
| Scopes | `targetScope` keyword | Schema URL diferente | Navegacao |

## Conceitos Bicep Demonstrados

| Conceito | Onde no lab |
|----------|-------------|
| `targetScope = 'subscription'` | `bloco2-rgs.bicep` (criar RGs) |
| `targetScope = 'managementGroup'` | `bloco2-custom-role.bicep` |
| `@description`, `@allowed`, `@minValue` | `bloco3-disk.bicep` |
| `@secure()` | `bloco5-vms.bicep` (senha da VM) |
| `existing` keyword | `bloco4-dns.bicep`, `bloco5-vms.bicep` |
| `existing` + `scope: resourceGroup()` | `bloco5-vms.bicep` (cross-RG) |
| `parent:` | DNS records, subnets |
| Dependencias implicitas | `bloco4-networking.bicep` (NSG → ASG) |
| Loop `for` | `bloco3-disks-loop.bicep` (alternativa) |
| `guid()` para nomes unicos | `bloco2-custom-role.bicep` |
| `identity: { type: 'SystemAssigned' }` | `bloco2-policies-rg2.bicep` |

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
| `bloco2-custom-role.bicep` | managementGroup | Custom RBAC role |
| `bloco2-rgs.bicep` | subscription | 2 RGs com tags |
| `bloco2-policies-rg2.bicep` | resourceGroup | Modify policy + Tag Contributor |
| `bloco2-policies-rg3.bicep` | resourceGroup | Modify + Allowed Locations + Reader |
| `bloco2-lock.bicep` | resourceGroup | Delete lock |
| `bloco3-disk.bicep` | resourceGroup | Disco parametrizado (reusavel x5) |
| `bloco4-networking.bicep` | resourceGroup | 2 VNets + subnets + ASG + NSG |
| `bloco4-dns.bicep` | resourceGroup | DNS public + private + links |
| `bloco5-vms.bicep` | resourceGroup | 2 VMs + NICs (cross-RG) |
| `bloco5-peering.bicep` | resourceGroup | Peering bidirecional |
| `bloco5-dns-update.bicep` | resourceGroup | Link + A record real |
| `bloco5-route.bicep` | resourceGroup | Route table + UDR |
