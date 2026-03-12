# Lab AZ-104 - Semana 1: Tudo via PowerShell

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (PowerShell)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Modulos `Az` e `Microsoft.Graph` ja vem pre-instalados
>   - Autenticacao ja esta feita (nao precisa de `Connect-AzAccount`)
>
> **Objetivo:** Reproduzir **todo** o lab unificado v2 (~49 recursos) usando exclusivamente PowerShell.
> Cada comando e fortemente comentado para aprendizado.

---

## Pre-requisitos: Cloud Shell e Conexao

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (PowerShell)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui os modulos `Az` e `Microsoft.Graph` pre-instalados e a autenticacao
> e automatica (nao precisa de `Connect-AzAccount`). Basta selecionar **PowerShell** como ambiente.

```powershell
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# 1. Verificar que esta no Cloud Shell (PowerShell)
#    O prompt deve mostrar PS /home/<usuario>>
Get-AzContext                      # Mostra subscription ativa (ja autenticado!)

# 2. Conectar ao Microsoft Graph
#    Entra ID (antigo Azure AD) NAO e gerenciado pelo ARM.
#    Precisamos do modulo Graph para users, groups, invites.
#    No Cloud Shell, o modulo ja esta instalado — so precisa conectar:
#    Scopes definem quais permissoes a sessao tera:
#    - User.ReadWrite.All: criar/editar usuarios
#    - Group.ReadWrite.All: criar/editar grupos
#    - Directory.ReadWrite.All: operacoes de diretorio
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.ReadWrite.All"

# 3. Verificar conexoes
Get-AzContext                      # Mostra subscription ativa
Get-MgContext                      # Mostra scopes do Graph
```

---

## Variaveis Globais

> **IMPORTANTE:** Ajuste os valores marcados com `# ← ALTERE` antes de executar.
> Todos os outros valores sao usados consistentemente ao longo do lab.

```powershell
# ============================================================
# VARIAVEIS GLOBAIS - Defina TODAS antes de iniciar
# ============================================================

# --- Configuracoes do tenant (ALTERE estes valores) ---
$tenantDomain    = "seudominio.onmicrosoft.com"           # ← ALTERE: seu dominio do tenant
$subscriptionId  = "00000000-0000-0000-0000-000000000000" # ← ALTERE: sua subscription ID
$guestEmail      = "seuemail@gmail.com"                   # ← ALTERE: email para convite B2B
$guestDisplayName = "Seu Nome"                            # ← ALTERE: nome do convidado

# --- Regiao padrao ---
$location = "eastus"

# --- Credenciais para VMs ---
$vmUsername = "localadmin"
$vmPassword = ConvertTo-SecureString "SenhaComplexa@2024!" -AsPlainText -Force  # ← ALTERE
$vmCredential = New-Object System.Management.Automation.PSCredential($vmUsername, $vmPassword)

# --- Identity (Bloco 1) ---
$userName        = "contoso-user1"
$userUPN         = "$userName@$tenantDomain"
$groupITLab      = "IT Lab Administrators"
$groupHelpdesk   = "helpdesk"

# --- Management Group (Bloco 2) ---
$mgName = "mg-contoso-prod"

# --- Resource Groups (Blocos 2-5) ---
$rg2 = "rg-contoso-identity"
$rg3 = "rg-contoso-identity"
$rg4 = "rg-contoso-network"
$rg5 = "rg-contoso-compute"

# --- Tags ---
$tags = @{ "Cost Center" = "000" }

# --- Discos (Bloco 3) ---
$diskNames = @("disk-iac-test-01", "disk-iac-test-02", "disk-iac-test-03", "disk-iac-test-04", "disk-iac-test-05")
$diskSizeGB = 32
$diskSku    = "Standard_LRS"    # Standard HDD

# --- Networking (Bloco 4) ---
$vnetCore         = "vnet-contoso-hub-eastus"
$vnetCorePrefix   = "10.20.0.0/16"
$vnetMfg          = "vnet-contoso-spoke-eastus"
$vnetMfgPrefix    = "10.30.0.0/16"

$subnetShared     = "snet-shared"
$subnetSharedPfx  = "10.20.10.0/24"
$subnetDB         = "snet-data"
$subnetDBPfx      = "10.20.20.0/24"
$subnetSensor1    = "SensorSubnet1"
$subnetSensor1Pfx = "10.30.20.0/24"
$subnetSensor2    = "SensorSubnet2"
$subnetSensor2Pfx = "10.30.21.0/24"

$asgName  = "asg-web"
$nsgName  = "nsg-snet-shared"

$dnsPublic  = "contoso.com"
$dnsPrivate = "contoso.internal"

# --- Subnets adicionais (Bloco 5) ---
$subnetCore       = "snet-apps"
$subnetCorePfx    = "10.20.0.0/24"
$subnetMfg        = "snet-workloads"
$subnetMfgPfx     = "10.30.0.0/24"
$subnetPerimeter  = "perimeter"
$subnetPerimPfx   = "10.20.1.0/24"

# --- VMs (Bloco 5) ---
$vmCore    = "vm-web-01"
$vmMfg     = "vm-app-01"
$vmSize    = "Standard_D2s_v3"
$vmImage   = "MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest"

# --- Route Table (Bloco 5) ---
$rtName    = "rt-contoso-spoke"
$nvaIP     = "10.20.1.7"
```

---

## Mapa de Dependencias

```
Bloco 1 (Identity)
  │
  ├─ contoso-user1 ──────────────────┐
  ├─ Guest user ───────────────────┤
  ├─ IT Lab Administrators ────────┤
  └─ helpdesk ─────────────────────┤
                                   │
                                   ▼
Bloco 2 (Governance) ──────────────────────────────────────┐
  │                                                        │
  ├─ RBAC: VM Contributor → IT Lab Administrators (MG)     │
  ├─ RBAC: Reader → Guest user (rg-contoso-identity)                 │
  ├─ Policy: Require tag (Deny) → rg-contoso-identity (testada)      │
  ├─ Policy: Inherit tag (Modify) → rg-contoso-identity + rg-contoso-identity  │
  ├─ Policy: Allowed Locations (Deny) → rg-contoso-identity          │
  ├─ Lock: Delete → rg-contoso-identity                              │
  └─ Cria rg-contoso-identity com tag Cost Center = 000              │
                                   │                       │
                                   ▼                       │
Bloco 3 (IaC) ◄──── Valida governanca ─────────────────────┘
  │
  ├─ Disks em rg-contoso-identity → tags herdadas automaticamente ✓
  ├─ Deploy West US → bloqueado por Allowed Locations ✓
  └─ Guest user → Reader, nao pode criar recursos ✓

                                                     ▼
Bloco 4 (Networking) ◄──── Cria infraestrutura de rede
  │
  ├─ vnet-contoso-hub-eastus (10.20.0.0/16) ──────────────┐
  ├─ vnet-contoso-spoke-eastus (10.30.0.0/16) ─────────────┤
  ├─ NSG + ASG na snet-shared             │
  ├─ DNS publico: contoso.com                      │
  └─ DNS privado: contoso.internal ─────────────┤
                                                   │
                                                   ▼
Bloco 5 (Connectivity) ◄──── VMs nas VNets do Bloco 4
  │
  ├─ vm-web-01 na vnet-contoso-hub-eastus (10.20.0.0/24)
  ├─ vm-app-01 na vnet-contoso-spoke-eastus (10.30.0.0/24)
  ├─ Peering entre as VNets do Bloco 4
  ├─ DNS privado resolve nome real da VM ✓
  ├─ contoso-user1 gerencia VMs (VM Contributor) ✓
  └─ Route table + NVA + custom route
```

---

# Bloco 1 - Identity

**Tecnologia:** Microsoft.Graph PowerShell SDK
**Recursos criados:** 1 usuario, 1 guest, 2 grupos (no Entra ID)

> **Por que Microsoft.Graph?** O Entra ID (antigo Azure AD) NAO e um recurso ARM.
> Os cmdlets `Az` (Azure Resource Manager) nao gerenciam usuarios/grupos.
> Para isso, usamos o modulo `Microsoft.Graph` que se comunica com a Microsoft Graph API.

---

### Task 1.1: Criar usuario contoso-user1

```powershell
# ============================================================
# TASK 1.1 - Criar usuario interno no Entra ID
# ============================================================

# Gerar senha aleatoria (16 caracteres)
# PasswordProfile e obrigatorio ao criar usuario via Graph
$passwordProfile = @{
    Password                      = "Az104Lab@$(Get-Random -Minimum 1000 -Maximum 9999)"
    ForceChangePasswordNextSignIn = $true   # Usuario deve trocar no primeiro login
}

# Criar o usuario
# New-MgUser: cmdlet do Microsoft.Graph para criar usuarios
# -UserPrincipalName: identidade unica no tenant (formato: user@domain)
# -DisplayName: nome exibido no portal
# -MailNickname: alias de email (obrigatorio)
# -AccountEnabled: conta ativa imediatamente
# -JobTitle, -Department: propriedades usadas em dynamic groups e filtros
# -UsageLocation: OBRIGATORIA para atribuir licencas (pais ISO 3166-1 alpha-2)
$user1 = New-MgUser `
    -UserPrincipalName $userUPN `
    -DisplayName $userName `
    -MailNickname $userName `
    -PasswordProfile $passwordProfile `
    -AccountEnabled:$true `
    -JobTitle "IT Lab Administrator" `
    -Department "IT" `
    -UsageLocation "US"

# IMPORTANTE: Salve a senha! Sera usada nos Blocos 2 e 5 para testes de RBAC
Write-Host "=== SALVE ESTA SENHA ===" -ForegroundColor Yellow
Write-Host "UPN: $userUPN"
Write-Host "Senha: $($passwordProfile.Password)"
Write-Host "========================" -ForegroundColor Yellow

# Verificar criacao
Get-MgUser -UserId $user1.Id | Select-Object DisplayName, UserPrincipalName, JobTitle, Department, UsageLocation
```

> **Dica AZ-104:** Na prova, preste atencao em `UsageLocation` — e obrigatoria para atribuir licencas.
> Sem ela, `Set-MgUserLicense` falha com erro.

---

### Task 1.2: Convidar usuario externo (Guest/B2B)

```powershell
# ============================================================
# TASK 1.2 - Convidar usuario externo via B2B
# ============================================================

# New-MgInvitation: envia convite B2B para usuario externo
# O usuario recebera email com link para aceitar o convite
# -InvitedUserEmailAddress: email do convidado (qualquer dominio)
# -InvitedUserDisplayName: nome exibido no Entra ID
# -InviteRedirectUrl: para onde redirecionar apos aceitar
# -SendInvitationMessage: envia email automaticamente
$invitation = New-MgInvitation `
    -InvitedUserEmailAddress $guestEmail `
    -InvitedUserDisplayName $guestDisplayName `
    -InviteRedirectUrl "https://portal.azure.com" `
    -SendInvitationMessage:$true `
    -InvitedUserMessageInfo @{
        CustomizedMessageBody = "Welcome to Azure and our group project"
    }

# Capturar o ID do guest user (necessario para adicionar a grupos)
$guestUserId = $invitation.InvitedUser.Id
Write-Host "Guest User ID: $guestUserId"
Write-Host "Status: $($invitation.Status)"

# Atualizar propriedades do guest (JobTitle, Department, UsageLocation)
# Mesmas propriedades do user1 para consistencia
Update-MgUser -UserId $guestUserId `
    -JobTitle "IT Lab Administrator" `
    -Department "IT" `
    -UsageLocation "US"

# Verificar
Get-MgUser -UserId $guestUserId | Select-Object DisplayName, Mail, UserType, JobTitle

# IMPORTANTE: Aceite o convite no email antes de prosseguir!
# O guest user precisa aceitar para os testes de RBAC nos Blocos 2-3 funcionarem.
Write-Host "`n>>> ACEITE O CONVITE NO EMAIL ANTES DE CONTINUAR <<<" -ForegroundColor Cyan
```

> **Conceito B2B:** O usuario aparece com `UserType = Guest`. Ele usa suas proprias credenciais
> (ex: conta Google, Microsoft pessoal) para acessar recursos do seu tenant.

---

### Task 1.3: Criar grupo IT Lab Administrators

```powershell
# ============================================================
# TASK 1.3 - Criar grupo de seguranca IT Lab Administrators
# ============================================================

# New-MgGroup: cria grupo no Entra ID
# -SecurityEnabled: grupo do tipo Security (usado para RBAC)
# -MailEnabled: false para grupos Security (true apenas para Microsoft 365)
# -MailNickname: obrigatorio mesmo sem email
# -GroupTypes @(): array vazio = grupo Assigned (sem dynamic membership)
#   Se fosse dynamic, seria: -GroupTypes @("DynamicMembership")
#   Dynamic requer Entra ID Premium P1/P2
$groupIT = New-MgGroup `
    -DisplayName $groupITLab `
    -Description "Administrators that manage the IT lab" `
    -SecurityEnabled:$true `
    -MailEnabled:$false `
    -MailNickname "itlabadmins" `
    -GroupTypes @()

Write-Host "Grupo criado: $($groupIT.DisplayName) - ID: $($groupIT.Id)"

# Adicionar contoso-user1 como membro
# New-MgGroupMember: adiciona membro ao grupo
# -DirectoryObjectId: ID do usuario a adicionar
New-MgGroupMember -GroupId $groupIT.Id -DirectoryObjectId $user1.Id
Write-Host "Adicionado $userName ao grupo $groupITLab"

# Adicionar guest user como membro
New-MgGroupMember -GroupId $groupIT.Id -DirectoryObjectId $guestUserId
Write-Host "Adicionado guest user ao grupo $groupITLab"

# Verificar membros do grupo
Get-MgGroupMember -GroupId $groupIT.Id | ForEach-Object {
    Get-MgUser -UserId $_.Id | Select-Object DisplayName, UserType
}
```

---

### Task 1.4: Criar grupo helpdesk

```powershell
# ============================================================
# TASK 1.4 - Criar grupo helpdesk
# ============================================================

$groupHD = New-MgGroup `
    -DisplayName $groupHelpdesk `
    -Description "Helpdesk team for support and VM access" `
    -SecurityEnabled:$true `
    -MailEnabled:$false `
    -MailNickname "helpdesk" `
    -GroupTypes @()

# Adicionar apenas contoso-user1 (diferente do grupo IT que tem tambem o guest)
New-MgGroupMember -GroupId $groupHD.Id -DirectoryObjectId $user1.Id

# Verificar ambos os grupos
Write-Host "`n=== Grupos criados ===" -ForegroundColor Green
@($groupIT, $groupHD) | ForEach-Object {
    $members = Get-MgGroupMember -GroupId $_.Id
    Write-Host "$($_.DisplayName): $($members.Count) membros"
    $members | ForEach-Object {
        $u = Get-MgUser -UserId $_.Id
        Write-Host "  - $($u.DisplayName) ($($u.UserType))"
    }
}
```

> **Conexao com Blocos 2-5:** Os usuarios e grupos criados aqui sao a base de toda a governanca.
> `contoso-user1` (membro de ambos os grupos) tera roles RBAC no Bloco 2, testados nos Blocos 3 e 5.

---

### Task 1.5: Criar grupo dinamico (requer Entra ID P1/P2)

```powershell
# ============================================================
# TASK 1.5 - Criar grupo dinamico (requer Entra ID P1/P2)
# ============================================================
# CONCEITO: Grupos dinamicos adicionam/removem membros automaticamente
# com base em regras de propriedades do usuario (department, jobTitle, etc.)
# Requer licenca Entra ID Premium P1 ou P2.
# Grupos Assigned = membros manuais | Dynamic = membros por regra

$dynamicGroup = New-MgGroup -DisplayName "IT Dynamic Group" `
    -Description "Grupo dinamico baseado no departamento IT" `
    -MailEnabled:$false `
    -SecurityEnabled:$true `
    -MailNickname "it-dynamic" `
    -GroupTypes "DynamicMembership" `
    -MembershipRule '(user.department -eq "IT")' `
    -MembershipRuleProcessingState "On"

# Verificar grupo criado
Write-Host "Grupo dinamico criado: $($dynamicGroup.DisplayName)" -ForegroundColor Green
Write-Host "  Membership Rule: $($dynamicGroup.MembershipRule)"
Write-Host "  Processing State: $($dynamicGroup.MembershipRuleProcessingState)"

# Aguardar processamento (pode levar alguns minutos)
Write-Host "Aguarde alguns minutos para o Entra ID processar a regra..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verificar membros dinamicos
$members = Get-MgGroupMember -GroupId $dynamicGroup.Id
Write-Host "Membros atuais: $($members.Count)"
$members | ForEach-Object {
    $u = Get-MgUser -UserId $_.Id
    Write-Host "  - $($u.DisplayName) (Department: $($u.Department))"
}
```

---

## Modo Desafio - Bloco 1

- [ ] Criar usuario `contoso-user1` com Job title `IT Lab Administrator`, Department `IT`, Usage location `US`
- [ ] **Salvar a senha gerada** (necessaria para testes nos Blocos 2 e 5)
- [ ] Convidar usuario externo (guest) via `New-MgInvitation` + aceitar o convite
- [ ] Criar grupo `IT Lab Administrators` (Assigned) — members: contoso-user1 + guest
- [ ] Criar grupo `helpdesk` (Assigned) — member: contoso-user1
- [ ] Verificar members de ambos os grupos com `Get-MgGroupMember`

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

Dynamic user membership permite criar regras baseadas em propriedades do usuario (como department, jobTitle, etc.) para adicionar/remover membros automaticamente. Requer licenca Entra ID Premium P1 ou P2. No PowerShell, use `-GroupTypes @("DynamicMembership")` e `-MembershipRule`.

</details>

### Questao 1.2
**Um usuario externo foi convidado para o seu tenant via Microsoft Entra External ID (B2B). Qual e o tipo de conta (User type) desse usuario no diretorio?**

A) Member
B) Guest
C) External
D) Federated

<details>
<summary>Ver resposta</summary>

**Resposta: B) Guest**

Usuarios convidados via B2B aparecem com `UserType = Guest`. Usuarios criados via `New-MgUser` sao do tipo `Member`.

</details>

### Questao 1.3
**Voce precisa atribuir uma licenca Microsoft 365 a um usuario. Ao tentar, recebe um erro. Qual propriedade do usuario provavelmente esta faltando?**

A) Department
B) Job title
C) Usage location
D) Manager

<details>
<summary>Ver resposta</summary>

**Resposta: C) Usage location**

A propriedade **UsageLocation** e obrigatoria para atribuir licencas. No PowerShell: `Update-MgUser -UserId $id -UsageLocation "US"`.

</details>

---

# Bloco 2 - Governance & Compliance

**Tecnologia:** Az PowerShell module
**Recursos criados:** 1 Management Group, 2 Resource Groups, 3 RBAC assignments, 1 custom role, 3 policy assignments, 1 resource lock

---

### Task 2.1: Criar Management Group e mover subscription

```powershell
# ============================================================
# TASK 2.1 - Criar Management Group
# ============================================================

# New-AzManagementGroup: cria um MG na hierarquia
# Management Groups organizam subscriptions para aplicar
# policies e RBAC de forma herdada
New-AzManagementGroup -GroupName $mgName -DisplayName $mgName

# Verificar criacao
Get-AzManagementGroup -GroupName $mgName

# Mover subscription para dentro do MG
# SEM mover a subscription, roles atribuidos no MG NAO terao efeito nos recursos!
# New-AzManagementGroupSubscription: associa subscription ao MG
New-AzManagementGroupSubscription `
    -GroupName $mgName `
    -SubscriptionId $subscriptionId

# Verificar que a subscription esta dentro do MG
$mg = Get-AzManagementGroup -GroupName $mgName -Expand
Write-Host "Management Group: $($mg.DisplayName)"
Write-Host "Subscriptions filhas: $($mg.Children.Count)"
$mg.Children | ForEach-Object { Write-Host "  - $($_.DisplayName) ($($_.Name))" }
```

> **Conceito:** O Root Management Group e o topo da hierarquia. Policies e RBAC aplicados
> em um MG sao herdados por todas as subscriptions filhas.

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

```powershell
# ============================================================
# TASK 2.2 - Atribuir VM Contributor ao grupo IT Lab Admins
# ============================================================

# Obter o Object ID do grupo IT Lab Administrators
# Precisamos do ID do Entra ID para o RBAC do ARM
$itLabGroup = Get-MgGroup -Filter "displayName eq '$groupITLab'"

# New-AzRoleAssignment: atribui role RBAC
# -ObjectId: ID do principal (usuario, grupo ou service principal)
# -RoleDefinitionName: nome do built-in role
# -Scope: onde o role se aplica (MG, subscription, RG ou recurso)
#
# Scope do Management Group: /providers/Microsoft.Management/managementGroups/<name>
New-AzRoleAssignment `
    -ObjectId $itLabGroup.Id `
    -RoleDefinitionName "Virtual Machine Contributor" `
    -Scope "/providers/Microsoft.Management/managementGroups/$mgName"

# Verificar a atribuicao
Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$mgName" |
    Where-Object { $_.DisplayName -eq $groupITLab } |
    Select-Object DisplayName, RoleDefinitionName, Scope
```

> **Conceito:** VM Contributor permite gerenciar VMs (Microsoft.Compute/virtualMachines/*),
> mas NAO o SO, a VNet ou o Storage Account conectados.
> RBAC e aditivo — o usuario so pode fazer o que os roles permitem explicitamente.

> **Conexao com Bloco 5:** `contoso-user1` (membro do IT Lab Administrators) podera
> gerenciar VMs em qualquer RG sob este MG. Testaremos no Bloco 5.

---

### Task 2.3: Criar custom RBAC role

```powershell
# ============================================================
# TASK 2.3 - Criar custom role "Custom Support Request"
# ============================================================

# Custom roles sao definidos via JSON com Actions e NotActions.
# Actions: permissoes concedidas
# NotActions: permissoes removidas do conjunto de Actions
# AssignableScopes: onde o role pode ser atribuido

# Definir o role como hashtable (convertido para JSON internamente)
$customRole = @{
    Name             = "Custom Support Request"
    Description      = "A custom contributor role for support requests."
    Actions          = @(
        "*/read"                                        # Ler todos os recursos
        "Microsoft.Support/*"                           # Todas as acoes de Support
    )
    NotActions       = @(
        "Microsoft.Support/register/action"             # EXCETO registrar provider
    )
    AssignableScopes = @(
        "/providers/Microsoft.Management/managementGroups/$mgName"
    )
}

# New-AzRoleDefinition: cria role customizado
# -Role: aceita hashtable ou objeto PSRoleDefinition
New-AzRoleDefinition -Role $customRole

# Verificar criacao (pode levar alguns segundos para propagar)
Start-Sleep -Seconds 10
Get-AzRoleDefinition -Name "Custom Support Request" |
    Select-Object Name, Description, Actions, NotActions
```

> **Conceito:** `NotActions` remove permissoes do conjunto de `Actions`.
> No exemplo: o role pode fazer tudo em Support, EXCETO registrar o provider.

---

### Task 2.4: Monitorar role assignments via Activity Log

```powershell
# ============================================================
# TASK 2.4 - Verificar atividades de RBAC no Activity Log
# ============================================================

# Get-AzActivityLog: consulta o Activity Log
# Filtramos por operacoes de role assignment das ultimas 1h
$startTime = (Get-Date).AddHours(-1)

Get-AzActivityLog `
    -StartTime $startTime `
    -ResourceProvider "Microsoft.Authorization" |
    Where-Object { $_.OperationName.Value -like "*roleAssignments*" } |
    Select-Object EventTimestamp, OperationName, Status, Caller |
    Format-Table -AutoSize
```

---

### Task 2.5: Criar Resource Groups com tags

```powershell
# ============================================================
# TASK 2.5 - Criar Resource Groups rg-contoso-identity e rg-contoso-identity
# ============================================================

# New-AzResourceGroup: cria Resource Group
# -Tag: hashtable de tags (key-value pairs)
# Tags sao metadados para organizacao, billing e automacao

# Criar rg-contoso-identity (usado para testes de governanca)
New-AzResourceGroup -Name $rg2 -Location $location -Tag $tags
Write-Host "Criado $rg2 com tag Cost Center = 000"

# Criar rg-contoso-identity (usado no Bloco 3 para IaC)
New-AzResourceGroup -Name $rg3 -Location $location -Tag $tags
Write-Host "Criado $rg3 com tag Cost Center = 000"

# Verificar
Get-AzResourceGroup -Name $rg2 | Select-Object ResourceGroupName, Location, Tags
Get-AzResourceGroup -Name $rg3 | Select-Object ResourceGroupName, Location, Tags
```

> **Conexao com Bloco 3:** O `rg-contoso-identity` sera usado para deploy de managed disks.
> As policies aplicadas aqui serao validadas quando os discos forem criados.

---

### Task 2.6: Aplicar Azure Policy (Deny) - Require tag no rg-contoso-identity

```powershell
# ============================================================
# TASK 2.6 - Aplicar policy Deny: Require tag no rg-contoso-identity
# ============================================================

# Obter a definicao da policy built-in
# "Require a tag and its value on resources" - efeito Deny
$policyDeny = Get-AzPolicyDefinition |
    Where-Object { $_.DisplayName -eq "Require a tag and its value on resources" }

Write-Host "Policy encontrada: $($policyDeny.DisplayName)"
Write-Host "Efeito: Deny (bloqueia criacao de recursos sem a tag)"

# Definir o scope: RG rg-contoso-identity
$scopeRg2 = "/subscriptions/$subscriptionId/resourceGroups/$rg2"

# Parametros da policy: qual tag e qual valor exigir
$policyParams = @{
    tagName  = @{ value = "Cost Center" }
    tagValue = @{ value = "000" }
}

# New-AzPolicyAssignment: atribui policy a um scope
New-AzPolicyAssignment `
    -Name "RequireCostCenterTag-rg2" `
    -DisplayName "Require Cost Center tag with value 000 on resources" `
    -PolicyDefinition $policyDeny `
    -Scope $scopeRg2 `
    -PolicyParameterObject $policyParams

Write-Host "`nPolicy atribuida! Aguarde 5-15 minutos para entrar em vigor."
Write-Host ">>> Enquanto espera, leia sobre os efeitos: Deny vs Audit vs Modify <<<" -ForegroundColor Cyan
```

> **Conceito:** O efeito **Deny** impede criacao de recursos que nao atendem as condicoes.

---

### Task 2.6b: Testar e remover Deny policy

```powershell
# ============================================================
# TASK 2.6b - Testar a policy Deny e depois remover
# ============================================================

# Teste: tentar criar um disco SEM a tag no rg2
# Isso DEVE falhar com policy violation
try {
    $diskConfig = New-AzDiskConfig `
        -Location $location `
        -CreateOption Empty `
        -DiskSizeGB 32 `
        -SkuName "Standard_LRS"

    New-AzDisk -ResourceGroupName $rg2 -DiskName "test-deny-disk" -Disk $diskConfig
    Write-Host "ERRO: disco criado (policy nao funcionou!)" -ForegroundColor Red
}
catch {
    Write-Host "SUCESSO: Policy Deny bloqueou criacao!" -ForegroundColor Green
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Remover a policy Deny (sera substituida por Modify)
Remove-AzPolicyAssignment -Name "RequireCostCenterTag-rg2" -Scope $scopeRg2
Write-Host "`nPolicy Deny removida do $rg2"
```

---

### Task 2.7: Aplicar Modify policy (Inherit tag) no rg-contoso-identity

```powershell
# ============================================================
# TASK 2.7 - Aplicar policy Modify: Inherit tag no rg-contoso-identity
# ============================================================

# Obter a policy "Inherit a tag from the resource group if missing"
# Efeito: Modify (altera recurso automaticamente durante criacao)
$policyModify = Get-AzPolicyDefinition |
    Where-Object { $_.DisplayName -eq "Inherit a tag from the resource group if missing" }

Write-Host "Policy encontrada: $($policyModify.DisplayName)"
Write-Host "Efeito: Modify (herda tag do RG automaticamente)"

# Parametro: qual tag herdar
$modifyParams = @{
    tagName = @{ value = "Cost Center" }
}

# A policy Modify REQUER Managed Identity para alterar recursos
# -IdentityType SystemAssigned: cria identidade gerenciada automaticamente
# -Location: obrigatorio quando ha Managed Identity
New-AzPolicyAssignment `
    -Name "InheritCostCenter-rg2" `
    -DisplayName "Inherit the Cost Center tag and its value 000 from the resource group if missing" `
    -PolicyDefinition $policyModify `
    -Scope $scopeRg2 `
    -PolicyParameterObject $modifyParams `
    -IdentityType "SystemAssigned" `
    -Location $location

# A Managed Identity precisa de permissao "Tag Contributor" no scope
# para poder modificar tags dos recursos
# Obter o principal ID da managed identity da policy assignment
$assignmentRg2 = Get-AzPolicyAssignment -Name "InheritCostCenter-rg2" -Scope $scopeRg2
$principalId = $assignmentRg2.IdentityPrincipalId

if ($principalId) {
    # Atribuir "Tag Contributor" a managed identity
    New-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionName "Tag Contributor" `
        -Scope $scopeRg2
    Write-Host "Tag Contributor atribuido a Managed Identity da policy"
}

Write-Host "`nPolicy Modify atribuida ao $rg2"
```

> **Gotcha:** A policy Modify precisa de Managed Identity com role "Tag Contributor" no scope.
> Sem isso, a policy detecta non-compliance mas nao consegue corrigir.

---

### Task 2.8: Aplicar Modify policy (Inherit tag) no rg-contoso-identity

```powershell
# ============================================================
# TASK 2.8 - Aplicar policy Modify: Inherit tag no rg-contoso-identity
# ============================================================

$scopeRg3 = "/subscriptions/$subscriptionId/resourceGroups/$rg3"

New-AzPolicyAssignment `
    -Name "InheritCostCenter-rg3" `
    -DisplayName "Inherit Cost Center tag on rg-contoso-identity resources" `
    -PolicyDefinition $policyModify `
    -Scope $scopeRg3 `
    -PolicyParameterObject $modifyParams `
    -IdentityType "SystemAssigned" `
    -Location $location

# Atribuir "Tag Contributor" a managed identity
$assignmentRg3 = Get-AzPolicyAssignment -Name "InheritCostCenter-rg3" -Scope $scopeRg3
$principalIdRg3 = $assignmentRg3.IdentityPrincipalId

if ($principalIdRg3) {
    New-AzRoleAssignment `
        -ObjectId $principalIdRg3 `
        -RoleDefinitionName "Tag Contributor" `
        -Scope $scopeRg3
    Write-Host "Tag Contributor atribuido a Managed Identity"
}

Write-Host "Policy Modify atribuida ao $rg3"
```

> **Conexao com Bloco 3:** Quando criar managed disks no `rg-contoso-identity`, eles receberao
> automaticamente a tag `Cost Center: 000`. Verificaremos em cada deploy.

---

### Task 2.9: Aplicar Allowed Locations policy no rg-contoso-identity

```powershell
# ============================================================
# TASK 2.9 - Aplicar policy Deny: Allowed Locations no rg-contoso-identity
# ============================================================

# "Allowed locations" restringe onde recursos podem ser criados
# Efeito: Deny (bloqueia deploy fora das regioes permitidas)
$policyLocations = Get-AzPolicyDefinition |
    Where-Object { $_.DisplayName -eq "Allowed locations" }

# Parametro: lista de locais permitidos
$locationParams = @{
    listOfAllowedLocations = @{ value = @("eastus") }
}

New-AzPolicyAssignment `
    -Name "AllowedLocations-rg3" `
    -DisplayName "Restrict resources to East US only" `
    -PolicyDefinition $policyLocations `
    -Scope $scopeRg3 `
    -PolicyParameterObject $locationParams

Write-Host "Policy Allowed Locations atribuida ao $rg3 (apenas East US)"
Write-Host ">>> Aguarde 5-15 minutos para as policies entrarem em vigor <<<" -ForegroundColor Cyan
```

> **Conexao com Bloco 3:** No Bloco 3, tentaremos criar um disco em West US e
> esta policy bloqueara a criacao.

---

### Task 2.10: Atribuir Reader role ao Guest user no rg-contoso-identity

```powershell
# ============================================================
# TASK 2.10 - Atribuir Reader ao guest user no rg-contoso-identity
# ============================================================

# O guest user recebe permissao somente-leitura no rg-contoso-identity
# Sera testado no Bloco 3 (pode ver mas nao criar recursos)
New-AzRoleAssignment `
    -ObjectId $guestUserId `
    -RoleDefinitionName "Reader" `
    -ResourceGroupName $rg3

# Verificar
Get-AzRoleAssignment -ResourceGroupName $rg3 |
    Where-Object { $_.ObjectId -eq $guestUserId } |
    Select-Object DisplayName, RoleDefinitionName, Scope
```

> **Conexao com Blocos 1 e 3:** Guest (Bloco 1) + Reader (Bloco 2) = pode ver, nao criar.

---

### Task 2.11: Configurar Resource Lock

```powershell
# ============================================================
# TASK 2.11 - Criar Delete Lock no rg-contoso-identity
# ============================================================

# New-AzResourceLock: cria lock em recurso ou RG
# -LockLevel CanNotDelete: permite modificar, impede exclusao
# -LockLevel ReadOnly: impede modificacao E exclusao
New-AzResourceLock `
    -LockName "rg-lock" `
    -LockLevel CanNotDelete `
    -ResourceGroupName $rg2 `
    -Force

# Verificar
Get-AzResourceLock -ResourceGroupName $rg2

# Teste: tentar deletar o RG (deve falhar)
try {
    Remove-AzResourceGroup -Name $rg2 -Force -ErrorAction Stop
    Write-Host "ERRO: RG deletado (lock nao funcionou!)" -ForegroundColor Red
}
catch {
    Write-Host "SUCESSO: Lock impediu exclusao!" -ForegroundColor Green
    Write-Host "Locks sobrescrevem QUALQUER permissao, incluindo Owner." -ForegroundColor Yellow
}
```

> **Conceito:** Resource Locks sobrescrevem quaisquer permissoes, incluindo Owner.
> O lock precisa ser removido primeiro para deletar o recurso.

---

### Task 2.12: Criar Policy Initiative (Policy Set Definition)

> **Conceito:** Uma **Initiative** (Policy Set) agrupa multiplas policy definitions
> em um conjunto unico. Em vez de atribuir 3 policies individualmente,
> voce atribui 1 initiative. Isso simplifica governanca em escala.
>
> Neste lab, ja atribuimos as policies individualmente (Tasks 2.6-2.9).
> Agora criamos uma initiative para aprender o conceito e ver como funcionaria
> em producao.

```powershell
# ============================================================
# TASK 2.12 - Criar Policy Initiative (Policy Set Definition)
# ============================================================

# Obter IDs das 3 built-in policies que ja usamos individualmente
$policyRequireTag = Get-AzPolicyDefinition |
    Where-Object { $_.DisplayName -eq "Require a tag and its value on resources" }

$policyInheritTag = Get-AzPolicyDefinition `
    -Id "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54"

$policyAllowedLocations = Get-AzPolicyDefinition `
    -Id "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

# Definir a composicao da Initiative (quais policies e como parametrizar)
# Cada policy recebe parametros mapeados dos parametros da initiative
$initiativeDefinition = @"
[
    {
        "policyDefinitionId": "$($policyRequireTag.PolicyDefinitionId)",
        "parameters": {
            "tagName":  { "value": "[parameters('tagName')]" },
            "tagValue": { "value": "[parameters('tagValue')]" }
        }
    },
    {
        "policyDefinitionId": "$($policyInheritTag.PolicyDefinitionId)",
        "parameters": {
            "tagName": { "value": "[parameters('tagName')]" }
        }
    },
    {
        "policyDefinitionId": "$($policyAllowedLocations.PolicyDefinitionId)",
        "parameters": {
            "listOfAllowedLocations": { "value": "[parameters('allowedLocations')]" }
        }
    }
]
"@

# Definir parametros que a initiative expoe (quem atribui fornece os valores)
$initiativeParams = @"
{
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
}
"@

# Criar a Initiative (Policy Set Definition) no escopo da subscription
New-AzPolicySetDefinition `
    -Name "contoso-governance-initiative" `
    -DisplayName "AZ-104 Lab Governance Initiative" `
    -Description "Agrupa 3 policies: require tag, inherit tag, allowed locations" `
    -PolicyDefinition $initiativeDefinition `
    -Parameter $initiativeParams

# Verificar criacao
Write-Host "Initiative criada:" -ForegroundColor Green
Get-AzPolicySetDefinition -Name "contoso-governance-initiative" |
    Select-Object Name, DisplayName,
        @{N='TotalPolicies';E={$_.PolicyDefinition.Count}}

# (Opcional) Exemplo de como ATRIBUIR a initiative a um RG:
# Em producao, voce usaria a initiative em vez das 3 atribuicoes individuais.
#
# New-AzPolicyAssignment `
#     -Name "governance-initiative-rg3" `
#     -DisplayName "Governance Initiative no rg-contoso-identity" `
#     -PolicySetDefinition (Get-AzPolicySetDefinition -Name "contoso-governance-initiative") `
#     -Scope "/subscriptions/$subscriptionId/resourceGroups/$rg3" `
#     -PolicyParameterObject @{
#         tagName          = "Cost Center"
#         tagValue         = "000"
#         allowedLocations = @("eastus")
#     } `
#     -IdentityType "SystemAssigned" `
#     -Location $location
```

> **Conceito AZ-104:**
> - **Policy Definition**: regra individual (ex: "require tag")
> - **Policy Set Definition (Initiative)**: grupo de regras relacionadas
> - **Policy Assignment**: aplicacao de uma definition OU initiative a um scope
> - Em producao, initiatives sao o padrao — policies individuais sao raras
> - Initiatives built-in do Azure: "CIS Benchmark", "NIST 800-53", "ISO 27001"

---

### Task 2.13: Teste de integracao — Verificar acesso do contoso-user1

```powershell
# ============================================================
# TASK 2.13 - Verificar RBAC do contoso-user1 (informativo)
# ============================================================

# Para testar de verdade, faca login como contoso-user1 em InPrivate/Incognito
# Aqui, verificamos as atribuicoes programaticamente

Write-Host "=== Verificacao de RBAC para $userName ===" -ForegroundColor Green

# Roles atribuidos ao grupo IT Lab Administrators (que inclui contoso-user1)
$roles = Get-AzRoleAssignment -ObjectId $itLabGroup.Id
Write-Host "`nRoles do grupo $groupITLab :"
$roles | Select-Object RoleDefinitionName, Scope | Format-Table

# O que contoso-user1 PODE fazer:
Write-Host "O que contoso-user1 PODE fazer:"
Write-Host "  ✓ Gerenciar VMs (VM Contributor no MG)"
Write-Host "  ✓ Ver recursos no rg-contoso-identity (heranca do MG)"

# O que contoso-user1 NAO PODE fazer:
Write-Host "`nO que contoso-user1 NAO PODE fazer:"
Write-Host "  ✗ Criar Storage Accounts (VM Contributor nao inclui Storage)"
Write-Host "  ✗ Deletar rg-contoso-identity (Lock impede + sem permissao)"

Write-Host "`n>>> Para teste manual: login como $userUPN em InPrivate <<<" -ForegroundColor Cyan
```

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `mg-contoso-prod` e **mover subscription** com `New-AzManagementGroupSubscription`
- [ ] Atribuir **VM Contributor** ao grupo `IT Lab Administrators` no MG
- [ ] Criar custom role **Custom Support Request** com `New-AzRoleDefinition`
- [ ] Verificar no Activity Log com `Get-AzActivityLog`
- [ ] Criar RGs `rg-contoso-identity` e `rg-contoso-identity` com tag `Cost Center: 000`
- [ ] Aplicar Deny policy (Require tag) no rg2 → testar → remover
- [ ] Aplicar Modify policy (Inherit tag) no rg2 e rg3 com `-IdentityType SystemAssigned`
- [ ] Atribuir **Tag Contributor** as Managed Identities das policies
- [ ] Aplicar **Allowed Locations** (East US only) no rg3
- [ ] Atribuir **Reader** ao guest user no rg3
- [ ] Criar Resource Lock (Delete) no rg2 → testar exclusao
- [ ] Criar **Policy Initiative** agrupando as 3 policies com `New-AzPolicySetDefinition`
- [ ] **Integracao:** Verificar roles programaticamente

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce atribuiu VM Contributor a um grupo no Management Group. Um membro do grupo tenta criar um Storage Account. O que acontece?**

A) A criacao e permitida porque VM Contributor inclui todas as permissoes de compute
B) A criacao falha porque VM Contributor nao inclui permissoes de Storage
C) A criacao e permitida no nivel de Management Group
D) A criacao depende do Resource Group

<details>
<summary>Ver resposta</summary>

**Resposta: B) A criacao falha porque VM Contributor nao inclui permissoes de Storage**

VM Contributor permite gerenciar VMs (`Microsoft.Compute/virtualMachines/*`) mas NAO inclui permissoes para Storage, Network ou outros servicos.

</details>

### Questao 2.2
**Voce aplicou a policy "Allowed locations" com East US em um Resource Group. Um usuario tenta criar um disco em West US via PowerShell nesse RG. O que acontece?**

A) O disco e criado em West US normalmente
B) O disco e criado em East US automaticamente
C) O deploy falha com erro de policy violation
D) O disco e criado mas marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: C) O deploy falha com erro de policy violation**

A policy "Allowed locations" usa o efeito **Deny**, que bloqueia ativamente a criacao de recursos em locais nao permitidos.

</details>

### Questao 2.3
**Qual a diferenca entre os efeitos Deny, Audit e Modify no Azure Policy?**

A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente
B) Todos os tres bloqueiam a criacao de recursos
C) Deny e Audit sao identicos, Modify cria recursos novos
D) Audit bloqueia, Deny registra, Modify exclui recursos

<details>
<summary>Ver resposta</summary>

**Resposta: A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente**

- **Deny:** Impede criacao/modificacao de recursos nao-conformes
- **Audit:** Permite a criacao mas registra como non-compliant
- **Modify:** Altera propriedades automaticamente (requer Managed Identity com role adequado)

</details>

### Questao 2.4
**Um usuario com role Owner tenta excluir um Resource Group que tem um Delete lock. O que acontece?**

A) A exclusao e permitida porque Owner tem todas as permissoes
B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario
C) A exclusao e permitida mas gera um alerta
D) A exclusao e bloqueada apenas para usuarios sem role Owner

<details>
<summary>Ver resposta</summary>

**Resposta: B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario**

Resource Locks sobrescrevem quaisquer permissoes, incluindo Owner. O lock precisa ser removido primeiro. Em PowerShell: `Remove-AzResourceLock -LockName "rg-lock" -ResourceGroupName $rg2 -Force`.

</details>

### Questao 2.5
**Qual a diferenca entre Policy Definition e Policy Initiative (Policy Set)?**

A) Initiative e uma policy com efeito mais forte
B) Initiative agrupa multiplas policy definitions em um conjunto unico
C) Initiative substitui policy definitions — nao podem coexistir
D) Initiative so funciona com policies custom, nao built-in

<details>
<summary>Ver resposta</summary>

**Resposta: B) Initiative agrupa multiplas policy definitions em um conjunto unico**

Uma Initiative (Policy Set Definition) e um grupo de policies relacionadas que podem ser
atribuidas como unidade. Pode conter policies built-in E custom. Em producao, initiatives
sao preferidas para simplificar governanca (ex: "CIS Benchmark" = dezenas de policies).

</details>

### Questao 2.6
**Voce atribuiu Reader role a um guest user em um Resource Group. O que este usuario pode fazer?**

A) Criar e modificar recursos no RG
B) Apenas visualizar recursos, sem poder criar ou modificar
C) Gerenciar apenas VMs no RG
D) Nada — guest users nao podem receber roles

<details>
<summary>Ver resposta</summary>

**Resposta: B) Apenas visualizar recursos, sem poder criar ou modificar**

O role **Reader** permite apenas visualizar. Guest users podem receber qualquer role RBAC.

</details>

---

# Bloco 3 - Azure Resources & IaC

**Tecnologia:** Az PowerShell module (New-AzDisk)
**Recursos criados:** 5 managed disks em rg-contoso-identity

> Neste bloco, TODOS os discos sao criados via PowerShell puro (New-AzDiskConfig + New-AzDisk).
> No lab v2 original, diferentes metodos (Portal, ARM, CLI, Bicep) eram usados.
> Aqui, o foco e dominar os cmdlets PowerShell para gerenciamento de discos.

---

### Task 3.1: Criar disk-iac-test-01

```powershell
# ============================================================
# TASK 3.1 - Criar disk-iac-test-01 via PowerShell
# ============================================================

# New-AzDiskConfig: cria CONFIGURACAO do disco (nao cria o recurso ainda)
# E um objeto de configuracao que sera passado para New-AzDisk
# -Location: regiao do disco
# -CreateOption Empty: disco vazio (sem dados iniciais)
#   Outras opcoes: Copy (copia de outro disco), Upload (VHD), FromImage (imagem)
# -DiskSizeGB: tamanho em GiB
# -SkuName: tipo de disco
#   Standard_LRS = Standard HDD
#   StandardSSD_LRS = Standard SSD
#   Premium_LRS = Premium SSD
#   UltraSSD_LRS = Ultra Disk
$diskConfig = New-AzDiskConfig `
    -Location $location `
    -CreateOption Empty `
    -DiskSizeGB $diskSizeGB `
    -SkuName $diskSku

# New-AzDisk: cria o disco no Azure usando a configuracao
$disk1 = New-AzDisk `
    -ResourceGroupName $rg3 `
    -DiskName $diskNames[0] `
    -Disk $diskConfig

Write-Host "Disco criado: $($disk1.Name) em $($disk1.Location)"

# VALIDACAO DE GOVERNANCA: verificar tag herdada
# A policy Modify do Bloco 2 deve ter atribuido "Cost Center = 000"
$disk1Tags = (Get-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[0]).Tags
if ($disk1Tags["Cost Center"] -eq "000") {
    Write-Host "✓ Tag 'Cost Center = 000' herdada automaticamente pela policy Modify!" -ForegroundColor Green
} else {
    Write-Host "⚠ Tag nao encontrada. A policy pode levar 5-15 min para propagar." -ForegroundColor Yellow
    Write-Host "  Tags atuais: $($disk1Tags | ConvertTo-Json -Compress)"
}
```

> **Conexao com Bloco 2:** A policy "Inherit tag from resource group if missing"
> esta funcionando! O disco herdou a tag do `rg-contoso-identity` sem configuracao manual.

---

### Task 3.2: Criar disk-iac-test-02

```powershell
# ============================================================
# TASK 3.2 - Criar disk-iac-test-02
# ============================================================

# Reutiliza a mesma configuracao (o objeto $diskConfig pode ser reusado)
$disk2 = New-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[1] -Disk $diskConfig

# Verificar tag
$disk2Tags = (Get-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[1]).Tags
Write-Host "$($diskNames[1]) criado - Tag Cost Center: $($disk2Tags['Cost Center'])"
```

---

### Task 3.3: Criar disk-iac-test-03

```powershell
# ============================================================
# TASK 3.3 - Criar disk-iac-test-03
# ============================================================

$disk3 = New-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[2] -Disk $diskConfig

$disk3Tags = (Get-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[2]).Tags
Write-Host "$($diskNames[2]) criado - Tag Cost Center: $($disk3Tags['Cost Center'])"
```

---

### Task 3.4: Criar disk-iac-test-04

```powershell
# ============================================================
# TASK 3.4 - Criar disk-iac-test-04
# ============================================================

$disk4 = New-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[3] -Disk $diskConfig

$disk4Tags = (Get-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[3]).Tags
Write-Host "$($diskNames[3]) criado - Tag Cost Center: $($disk4Tags['Cost Center'])"
```

---

### Task 3.5: Criar disk-iac-test-05 (StandardSSD)

```powershell
# ============================================================
# TASK 3.5 - Criar disk-iac-test-05 (StandardSSD para variar)
# ============================================================

# Usar SKU diferente para demonstrar flexibilidade
$diskConfig5 = New-AzDiskConfig `
    -Location $location `
    -CreateOption Empty `
    -DiskSizeGB $diskSizeGB `
    -SkuName "StandardSSD_LRS"   # Standard SSD (vs Standard HDD dos anteriores)

$disk5 = New-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[4] -Disk $diskConfig5

$disk5Tags = (Get-AzDisk -ResourceGroupName $rg3 -DiskName $diskNames[4]).Tags
Write-Host "$($diskNames[4]) criado (StandardSSD) - Tag Cost Center: $($disk5Tags['Cost Center'])"

# Listar todos os 5 discos
Write-Host "`n=== Todos os discos em $rg3 ===" -ForegroundColor Green
Get-AzDisk -ResourceGroupName $rg3 |
    Select-Object Name, DiskSizeGB, @{N='Sku';E={$_.Sku.Name}}, Location, @{N='CostCenter';E={$_.Tags['Cost Center']}} |
    Format-Table -AutoSize
```

---

### Task 3.6: Teste de integracao — Allowed Locations policy

```powershell
# ============================================================
# TASK 3.6 - Testar policy Allowed Locations (East US only)
# ============================================================

# Tentar criar um disco em West US (deve falhar!)
$diskConfigWest = New-AzDiskConfig `
    -Location "westus" `
    -CreateOption Empty `
    -DiskSizeGB 32 `
    -SkuName "Standard_LRS"

try {
    New-AzDisk -ResourceGroupName $rg3 -DiskName "disk-iac-test-region" -Disk $diskConfigWest -ErrorAction Stop
    Write-Host "ERRO: disco criado em West US (policy nao funcionou!)" -ForegroundColor Red
}
catch {
    Write-Host "✓ Policy Allowed Locations bloqueou deploy em West US!" -ForegroundColor Green
    Write-Host "Erro: Resource was disallowed by policy" -ForegroundColor Yellow
}

# Confirmar que apenas os 5 discos originais existem
$diskCount = (Get-AzDisk -ResourceGroupName $rg3).Count
Write-Host "`nDiscos no $rg3 : $diskCount (esperado: 5)"
```

> **Conexao com Bloco 2:** A policy "Allowed locations" aplicada no Bloco 2 esta funcionando!

---

### Task 3.7: Teste de integracao — Guest user com Reader role (Informativo)

```powershell
# ============================================================
# TASK 3.7 - Verificar RBAC do guest user (informativo)
# ============================================================

# O guest user tem Reader no rg-contoso-identity (atribuido no Bloco 2)
# Para testar: login como guest em InPrivate/Incognito

# Verificacao programatica:
$guestRoles = Get-AzRoleAssignment -ObjectId $guestUserId -ResourceGroupName $rg3
Write-Host "=== RBAC do Guest User no $rg3 ==="
$guestRoles | Select-Object DisplayName, RoleDefinitionName | Format-Table

Write-Host "O guest user pode:"
Write-Host "  ✓ Ver os 5 discos no $rg3"
Write-Host "  ✗ Criar novos discos (Reader nao permite)"

Write-Host "`n>>> Para teste manual: login como guest em InPrivate <<<" -ForegroundColor Cyan
```

---

## Modo Desafio - Bloco 3

- [ ] Criar `disk-iac-test-01` via `New-AzDisk` em rg-contoso-identity → **verificar tag herdada**
- [ ] Criar `disk-iac-test-02` a `disk-iac-test-04` reutilizando `$diskConfig` → **verificar tags**
- [ ] Criar `disk-iac-test-05` com SKU `StandardSSD_LRS` → **verificar tag**
- [ ] **Integracao:** Tentar deploy em West US → bloqueado por policy
- [ ] Listar todos os discos com `Get-AzDisk` e verificar tags
- [ ] **Integracao (opcional):** Verificar RBAC do guest user

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce aplicou uma policy Modify "Inherit tag from resource group" no rg-contoso-identity. Voce cria um managed disk via `New-AzDisk` sem tags. O que acontece com as tags do disco?**

A) O disco e criado sem tags
B) O disco herda a tag Cost Center = 000 do resource group automaticamente
C) O deploy falha porque o disco nao tem a tag
D) O disco e criado e marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: B) O disco herda a tag Cost Center = 000 do resource group automaticamente**

O efeito **Modify** altera as propriedades do recurso durante a criacao. A policy copia a tag do RG para o recurso se ele nao a possuir.

</details>

### Questao 3.2
**Qual cmdlet PowerShell faz deploy de um ARM template em um Resource Group?**

A) `Set-AzResourceGroup`
B) `New-AzResourceGroupDeployment`
C) `New-AzDeployment`
D) `Deploy-AzTemplate`

<details>
<summary>Ver resposta</summary>

**Resposta: B) New-AzResourceGroupDeployment**

- `New-AzResourceGroupDeployment` → deploy no nivel de Resource Group
- `New-AzDeployment` (ou `New-AzSubscriptionDeployment`) → deploy no nivel de Subscription
- `New-AzManagementGroupDeployment` → deploy no nivel de Management Group
- `New-AzTenantDeployment` → deploy no nivel de Tenant

</details>

### Questao 3.3
**Qual cmdlet cria a CONFIGURACAO de um managed disk sem criar o recurso?**

A) `New-AzDisk`
B) `Set-AzDisk`
C) `New-AzDiskConfig`
D) `New-AzManagedDisk`

<details>
<summary>Ver resposta</summary>

**Resposta: C) New-AzDiskConfig**

`New-AzDiskConfig` cria um objeto de configuracao local. O disco so e criado no Azure quando esse objeto e passado para `New-AzDisk`.

</details>

---

# Bloco 4 - Virtual Networking

**Tecnologia:** Az PowerShell module
**Recursos criados:** 2 VNets, 4 subnets, 1 ASG, 1 NSG, 1 DNS public zone, 1 DNS private zone, 1 VNet link

---

### Task 4.1: Criar VNet vnet-contoso-hub-eastus

```powershell
# ============================================================
# TASK 4.1 - Criar vnet-contoso-hub-eastus com 2 subnets
# ============================================================

# Criar RG para networking
New-AzResourceGroup -Name $rg4 -Location $location

# Definir subnets ANTES de criar a VNet
# New-AzVirtualNetworkSubnetConfig: cria config de subnet (nao cria no Azure)
$subShared = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetShared `
    -AddressPrefix $subnetSharedPfx

$subDB = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetDB `
    -AddressPrefix $subnetDBPfx

# New-AzVirtualNetwork: cria a VNet com as subnets definidas
# -AddressPrefix: CIDR da VNet inteira
# -Subnet: array de configs de subnets
$vnetCoreObj = New-AzVirtualNetwork `
    -ResourceGroupName $rg4 `
    -Name $vnetCore `
    -Location $location `
    -AddressPrefix $vnetCorePrefix `
    -Subnet @($subShared, $subDB)

Write-Host "VNet criada: $($vnetCoreObj.Name)"
Write-Host "Address space: $($vnetCoreObj.AddressSpace.AddressPrefixes)"
Write-Host "Subnets:"
$vnetCoreObj.Subnets | ForEach-Object {
    Write-Host "  - $($_.Name): $($_.AddressPrefix)"
}
```

> **Conceito:** 5 IPs sao reservados em cada subnet Azure (.0, .1, .2, .3, .255).
> Uma /24 tem 251 IPs utilizaveis.

> **Conexao com Bloco 5:** Esta VNet sera usada para implantar a vm-web-01.

---

### Task 4.2: Criar VNet vnet-contoso-spoke-eastus

```powershell
# ============================================================
# TASK 4.2 - Criar vnet-contoso-spoke-eastus com 2 subnets
# ============================================================

$subSensor1 = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetSensor1 `
    -AddressPrefix $subnetSensor1Pfx

$subSensor2 = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetSensor2 `
    -AddressPrefix $subnetSensor2Pfx

$vnetMfgObj = New-AzVirtualNetwork `
    -ResourceGroupName $rg4 `
    -Name $vnetMfg `
    -Location $location `
    -AddressPrefix $vnetMfgPrefix `
    -Subnet @($subSensor1, $subSensor2)

Write-Host "VNet criada: $($vnetMfgObj.Name)"
$vnetMfgObj.Subnets | ForEach-Object {
    Write-Host "  - $($_.Name): $($_.AddressPrefix)"
}
```

---

### Task 4.3: Criar ASG e NSG

```powershell
# ============================================================
# TASK 4.3 - Criar ASG (asg-web) e NSG (nsg-snet-shared)
# ============================================================

# Application Security Group: agrupa VMs logicamente para regras NSG
# Permite criar regras tipo "permitir HTTP para o grupo web"
# sem precisar especificar IPs individuais
$asg = New-AzApplicationSecurityGroup `
    -ResourceGroupName $rg4 `
    -Name $asgName `
    -Location $location

Write-Host "ASG criado: $($asg.Name)"

# Network Security Group: firewall virtual por subnet/NIC
$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $rg4 `
    -Name $nsgName `
    -Location $location

Write-Host "NSG criado: $($nsg.Name)"
```

---

### Task 4.4: Associar NSG a subnet + regras inbound/outbound

```powershell
# ============================================================
# TASK 4.4 - Associar NSG a snet-shared + regras
# ============================================================

# 1. Associar NSG a subnet
# Buscar a VNet atualizada
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4

# Set-AzVirtualNetworkSubnetConfig: atualiza config de subnet existente
# -NetworkSecurityGroup: associa NSG a subnet
Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnetCoreObj `
    -Name $subnetShared `
    -AddressPrefix $subnetSharedPfx `
    -NetworkSecurityGroup $nsg | Out-Null

# IMPORTANTE: As mudancas so sao aplicadas no Azure com Set-AzVirtualNetwork
$vnetCoreObj | Set-AzVirtualNetwork | Out-Null
Write-Host "NSG associado a $subnetShared"

# 2. Regra Inbound - Allow ASG na porta 80,443
# Add-AzNetworkSecurityRuleConfig: adiciona regra ao objeto NSG local
# Depois precisa de Set-AzNetworkSecurityGroup para aplicar
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg4

Add-AzNetworkSecurityRuleConfig `
    -NetworkSecurityGroup $nsg `
    -Name "AllowASG" `
    -Description "Allow HTTP/HTTPS from ASG web" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceApplicationSecurityGroupId $asg.Id `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange @("80", "443") | Out-Null

# 3. Regra Outbound - Deny Internet
Add-AzNetworkSecurityRuleConfig `
    -NetworkSecurityGroup $nsg `
    -Name "DenyInternetOutbound" `
    -Description "Deny all outbound internet traffic" `
    -Access Deny `
    -Protocol "*" `
    -Direction Outbound `
    -Priority 4096 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "Internet" `
    -DestinationPortRange "*" | Out-Null

# Aplicar as regras no Azure
$nsg | Set-AzNetworkSecurityGroup | Out-Null

Write-Host "`n=== Regras do NSG ==="
Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg4 |
    Get-AzNetworkSecurityRuleConfig |
    Select-Object Name, Direction, Access, Priority, Protocol, DestinationPortRange |
    Format-Table -AutoSize
```

> **Conceito:** NSG rules sao processadas por priority (menor numero = maior prioridade).
> DenyInternetOutbound (4096) tem prioridade sobre AllowInternetOutBound (65001, rule default).

> **Conexao com Bloco 5:** O NSG esta na snet-shared. VMs no Bloco 5 ficarao
> em subnets diferentes e NAO serao afetadas — NSGs sao por subnet, nao por VNet.

---

### Task 4.5: Criar zona DNS publica com registro A

```powershell
# ============================================================
# TASK 4.5 - Criar DNS zone publica + registro A
# ============================================================

# New-AzDnsZone: cria zona DNS publica
# DNS zones sao recursos globais (nao tem regiao)
$dnsZone = New-AzDnsZone `
    -ResourceGroupName $rg4 `
    -Name $dnsPublic

Write-Host "DNS Zone criada: $($dnsZone.Name)"
Write-Host "Name servers:"
$dnsZone.NameServers | ForEach-Object { Write-Host "  - $_" }

# Guardar um name server para nslookup
$nameServer = $dnsZone.NameServers[0]

# Criar registro A: www.contoso.com → 10.1.1.4
# New-AzDnsRecordSet + Add-AzDnsRecordConfig: cria registro DNS
$recordSet = New-AzDnsRecordSet `
    -ResourceGroupName $rg4 `
    -ZoneName $dnsPublic `
    -Name "www" `
    -RecordType A `
    -Ttl 1

Add-AzDnsRecordConfig -RecordSet $recordSet -Ipv4Address "10.1.1.4" | Out-Null
Set-AzDnsRecordSet -RecordSet $recordSet | Out-Null

Write-Host "`nRegistro A criado: www.$dnsPublic → 10.1.1.4"

# Testar resolucao (requer nslookup/Resolve-DnsName)
Write-Host "`nTeste de resolucao (use Cloud Shell ou terminal local):"
Write-Host "  nslookup www.$dnsPublic $nameServer"
```

---

### Task 4.6: Criar zona DNS privada com virtual network link

```powershell
# ============================================================
# TASK 4.6 - Criar DNS zone privada + VNet link
# ============================================================

# New-AzPrivateDnsZone: cria zona DNS privada
# Zonas privadas so resolvem dentro de VNets linkadas
$privateDns = New-AzPrivateDnsZone `
    -ResourceGroupName $rg4 `
    -Name $dnsPrivate

Write-Host "DNS Zone privada criada: $($privateDns.Name)"
Write-Host "Nota: zonas privadas NAO tem name servers publicos."

# Criar Virtual Network Link para vnet-contoso-spoke-eastus
# New-AzPrivateDnsVirtualNetworkLink: vincula VNet a zona privada
# -EnableRegistration $false: nao registra VMs automaticamente
$link = New-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $rg4 `
    -ZoneName $dnsPrivate `
    -Name "manufacturing-link" `
    -VirtualNetworkId $vnetMfgObj.Id `
    -EnableRegistration $false

Write-Host "Link criado: vnet-contoso-spoke-eastus → $dnsPrivate"

# Criar registro A placeholder: sensorvm.contoso.internal → 10.1.1.4
$privateRecord = New-AzPrivateDnsRecordSet `
    -ResourceGroupName $rg4 `
    -ZoneName $dnsPrivate `
    -Name "sensorvm" `
    -RecordType A `
    -Ttl 1

Add-AzPrivateDnsRecordConfig -RecordSet $privateRecord -Ipv4Address "10.1.1.4" | Out-Null
Set-AzPrivateDnsRecordSet -RecordSet $privateRecord | Out-Null

Write-Host "Registro A placeholder: sensorvm.$dnsPrivate → 10.1.1.4"
```

> **Conexao com Bloco 5:** No Bloco 5, adicionaremos registro com IP **real** da
> vm-web-01 e link para vnet-contoso-hub-eastus.

---

## Modo Desafio - Bloco 4

- [ ] Criar `vnet-contoso-hub-eastus` (10.20.0.0/16) com `New-AzVirtualNetwork` + 2 subnets
- [ ] Criar `vnet-contoso-spoke-eastus` (10.30.0.0/16) com 2 subnets
- [ ] Criar ASG `asg-web` e NSG `nsg-snet-shared`
- [ ] Associar NSG a snet-shared + regras AllowASG e DenyInternetOutbound
- [ ] Criar DNS publica `contoso.com` + registro A `www`
- [ ] Criar DNS privada `contoso.internal` + link para vnet-contoso-spoke-eastus

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Um NSG esta associado a snet-shared. Voce cria uma VM em snet-data (mesma VNet). A VM e afetada pelas regras do NSG?**

A) Sim, o NSG se aplica a toda a VNet
B) Nao, o NSG se aplica apenas a subnet associada
C) Sim, se o ASG incluir a VM
D) Depende das regras de priority

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, o NSG se aplica apenas a subnet associada**

NSGs sao associados a **subnets** ou **NICs**, nao a VNets inteiras.

</details>

### Questao 4.2
**Quantos enderecos IP utilizaveis existem em uma subnet /24 no Azure?**

A) 256
B) 254
C) 251
D) 250

<details>
<summary>Ver resposta</summary>

**Resposta: C) 251**

O Azure reserva 5 IPs: .0 (network), .1 (gateway), .2 e .3 (DNS), .255 (broadcast). 256 - 5 = 251.

</details>

### Questao 4.3
**Voce tem regras NSG: Rule A (Priority 100, Allow, Port 80) e Rule B (Priority 200, Deny, Port 80). Um pacote chega na porta 80. O que acontece?**

A) Negado pela Rule B
B) Permitido pela Rule A
C) Avaliado por todas as regras, ultima vence
D) Permitido porque ha mais regras Allow

<details>
<summary>Ver resposta</summary>

**Resposta: B) Permitido pela Rule A**

NSG rules sao processadas em ordem de priority (menor primeiro). Rule A (100) e avaliada primeiro.

</details>

### Questao 4.4
**Qual a diferenca entre Azure DNS public zones e private zones?**

A) Public zones sao gratuitas, private zones sao pagas
B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas
C) Private zones suportam mais tipos de registro
D) Public zones requerem VPN

<details>
<summary>Ver resposta</summary>

**Resposta: B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas**

Private DNS zones requerem Virtual Network Links e resolvem apenas para recursos nas VNets linkadas.

</details>

### Questao 4.5
**Voce criou uma zona DNS privada e linkou a VNet A. Uma VM na VNet B (nao linkada) tenta resolver um nome nessa zona. O que acontece?**

A) Resolve normalmente
B) Falha — a VNet B nao esta linkada a zona
C) Resolve usando o DNS publico
D) Resolve apenas se houver peering entre A e B

<details>
<summary>Ver resposta</summary>

**Resposta: B) Falha — a VNet B nao esta linkada a zona**

Peering entre VNets NAO implica resolucao DNS automatica — o link precisa ser explicitamente criado.

</details>

---

# Bloco 5 - Intersite Connectivity

**Tecnologia:** Az PowerShell module
**Recursos criados:** 2 subnets novas, 2 VMs + NICs, 1 VNet peering bidirecional, 1 VNet link, 1 DNS record, 1 route table, 1 custom route

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 5.1: Adicionar subnets para VMs nas VNets existentes

```powershell
# ============================================================
# TASK 5.1 - Adicionar subnets Core e Manufacturing
# ============================================================

# Adicionar subnet "snet-apps" na vnet-contoso-hub-eastus
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4

# Add-AzVirtualNetworkSubnetConfig: adiciona subnet a VNet existente
Add-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnetCoreObj `
    -Name $subnetCore `
    -AddressPrefix $subnetCorePfx | Out-Null

# Aplicar no Azure
$vnetCoreObj | Set-AzVirtualNetwork | Out-Null
Write-Host "Subnet '$subnetCore' ($subnetCorePfx) adicionada a $vnetCore"

# Adicionar subnet "snet-workloads" na vnet-contoso-spoke-eastus
$vnetMfgObj = Get-AzVirtualNetwork -Name $vnetMfg -ResourceGroupName $rg4

Add-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnetMfgObj `
    -Name $subnetMfg `
    -AddressPrefix $subnetMfgPfx | Out-Null

$vnetMfgObj | Set-AzVirtualNetwork | Out-Null
Write-Host "Subnet '$subnetMfg' ($subnetMfgPfx) adicionada a $vnetMfg"

# Verificar todas as subnets
Write-Host "`n=== Subnets de $vnetCore ==="
(Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4).Subnets |
    Select-Object Name, AddressPrefix | Format-Table

Write-Host "=== Subnets de $vnetMfg ==="
(Get-AzVirtualNetwork -Name $vnetMfg -ResourceGroupName $rg4).Subnets |
    Select-Object Name, AddressPrefix | Format-Table
```

> **Conexao com Bloco 4:** VNets sao estruturas vivas que crescem conforme a necessidade.

---

### Task 5.2: Criar vm-web-01

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

```powershell
# ============================================================
# TASK 5.2 - Criar vm-web-01
# ============================================================

# Criar RG para VMs
New-AzResourceGroup -Name $rg5 -Location $location

# Buscar a subnet Core na vnet-contoso-hub-eastus (que esta em rg4!)
# Esta e uma referencia CROSS-RESOURCE-GROUP: VM no rg5, VNet no rg4
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4
$subnetCoreObj = $vnetCoreObj.Subnets | Where-Object { $_.Name -eq $subnetCore }

# Criar NIC (Network Interface Card) referenciando subnet de outro RG
# O ID da subnet contem o RG da VNet (/resourceGroups/rg-contoso-network/...)
$nicCore = New-AzNetworkInterface `
    -ResourceGroupName $rg5 `
    -Name "$vmCore-nic" `
    -Location $location `
    -SubnetId $subnetCoreObj.Id

Write-Host "NIC criada: $($nicCore.Name)"
Write-Host "  Subnet ID (cross-RG): $($nicCore.IpConfigurations[0].Subnet.Id)"

# Configurar a VM
# New-AzVMConfig: configura tamanho e nome
# Set-AzVMOperatingSystem: configura OS, credenciais, timezone
# Set-AzVMSourceImage: define a imagem do OS
# Add-AzVMNetworkInterface: associa NIC a VM
# Set-AzVMBootDiagnostic: desabilita boot diagnostics (simplifica lab)
$vmConfig = New-AzVMConfig -VMName $vmCore -VMSize $vmSize |
    Set-AzVMOperatingSystem -Windows -ComputerName $vmCore -Credential $vmCredential |
    Set-AzVMSourceImage `
        -PublisherName "MicrosoftWindowsServer" `
        -Offer "WindowsServer" `
        -Skus "2025-datacenter-azure-edition" `
        -Version "latest" |
    Add-AzVMNetworkInterface -Id $nicCore.Id |
    Set-AzVMBootDiagnostic -Disable

# Criar a VM (pode levar 3-5 minutos)
Write-Host "`nCriando $vmCore (pode levar 3-5 min)..."
New-AzVM -ResourceGroupName $rg5 -Location $location -VM $vmConfig -AsJob

Write-Host "$vmCore sendo criada em background. Continue para a proxima task."
```

> **Nota importante:** A VM esta no `rg-contoso-compute` mas usa VNet do `rg-contoso-network`.
> No PowerShell, a referencia cross-RG e feita pelo ID completo da subnet.

---

### Task 5.3: Criar vm-app-01

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

```powershell
# ============================================================
# TASK 5.3 - Criar vm-app-01
# ============================================================

# Buscar subnet Manufacturing na vnet-contoso-spoke-eastus (rg4)
$vnetMfgObj = Get-AzVirtualNetwork -Name $vnetMfg -ResourceGroupName $rg4
$subnetMfgObj = $vnetMfgObj.Subnets | Where-Object { $_.Name -eq $subnetMfg }

# Criar NIC (referencia cross-RG novamente)
$nicMfg = New-AzNetworkInterface `
    -ResourceGroupName $rg5 `
    -Name "$vmMfg-nic" `
    -Location $location `
    -SubnetId $subnetMfgObj.Id

# Configurar e criar VM
$vmMfgConfig = New-AzVMConfig -VMName $vmMfg -VMSize $vmSize |
    Set-AzVMOperatingSystem -Windows -ComputerName $vmMfg -Credential $vmCredential |
    Set-AzVMSourceImage `
        -PublisherName "MicrosoftWindowsServer" `
        -Offer "WindowsServer" `
        -Skus "2025-datacenter-azure-edition" `
        -Version "latest" |
    Add-AzVMNetworkInterface -Id $nicMfg.Id |
    Set-AzVMBootDiagnostic -Disable

Write-Host "Criando $vmMfg (pode levar 3-5 min)..."
New-AzVM -ResourceGroupName $rg5 -Location $location -VM $vmMfgConfig -AsJob

# Aguardar ambas as VMs
Write-Host "`nAguardando ambas as VMs serem provisionadas..."
Get-Job | Wait-Job | Out-Null

# Verificar
Get-AzVM -ResourceGroupName $rg5 |
    Select-Object Name, @{N='Status';E={(Get-AzVM -ResourceGroupName $rg5 -Name $_.Name -Status).Statuses[1].DisplayStatus}} |
    Format-Table
```

---

### Task 5.4: Network Watcher — Connection Troubleshoot

```powershell
# ============================================================
# TASK 5.4 - Network Watcher: testar conectividade ANTES do peering
# ============================================================

# Test-AzNetworkWatcherConnectivity: testa conectividade entre VMs
# ANTES do peering, VNets diferentes NAO se comunicam

# Obter IDs das VMs
$vmCoreId = (Get-AzVM -ResourceGroupName $rg5 -Name $vmCore).Id
$vmMfgId  = (Get-AzVM -ResourceGroupName $rg5 -Name $vmMfg).Id

# Buscar Network Watcher da regiao (criado automaticamente pelo Azure)
$nw = Get-AzNetworkWatcher | Where-Object { $_.Location -eq $location }

# Testar conectividade
$test = Test-AzNetworkWatcherConnectivity `
    -NetworkWatcher $nw `
    -SourceId $vmCoreId `
    -DestinationId $vmMfgId `
    -DestinationPort 3389

Write-Host "Resultado: $($test.ConnectionStatus)"
# Esperado: Unreachable

if ($test.ConnectionStatus -eq "Unreachable") {
    Write-Host "✓ Correto! VNets diferentes NAO se comunicam sem peering." -ForegroundColor Green
}
```

> **Conceito:** VNets diferentes NAO se comunicam por padrao, mesmo estando no mesmo RG
> ou subscription. E necessario VNet Peering (ou VPN/ExpressRoute).

---

### Task 5.5: Configurar VNet Peering bidirecional

```powershell
# ============================================================
# TASK 5.5 - Configurar VNet Peering bidirecional
# ============================================================

# VNet Peering precisa ser criado em AMBAS as direcoes

# Buscar VNets atualizadas
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4
$vnetMfgObj  = Get-AzVirtualNetwork -Name $vnetMfg -ResourceGroupName $rg4

# Peering 1: Core → Manufacturing
# Add-AzVirtualNetworkPeering: cria peering unidirecional
# -AllowForwardedTraffic: permite trafego encaminhado (ex: NVA)
Add-AzVirtualNetworkPeering `
    -Name "vnet-contoso-hub-eastus-to-vnet-contoso-spoke-eastus" `
    -VirtualNetwork $vnetCoreObj `
    -RemoteVirtualNetworkId $vnetMfgObj.Id `
    -AllowForwardedTraffic

# Peering 2: Manufacturing → Core
Add-AzVirtualNetworkPeering `
    -Name "vnet-contoso-spoke-eastus-to-vnet-contoso-hub-eastus" `
    -VirtualNetwork $vnetMfgObj `
    -RemoteVirtualNetworkId $vnetCoreObj.Id `
    -AllowForwardedTraffic

# Verificar status (ambos devem ser "Connected")
Write-Host "`n=== Status do Peering ==="
Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetCore -ResourceGroupName $rg4 |
    Select-Object Name, PeeringState | Format-Table
Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetMfg -ResourceGroupName $rg4 |
    Select-Object Name, PeeringState | Format-Table
```

> **Conceito:** VNet Peering e **NAO transitivo**. Se A↔B e B↔C, A nao se comunica com C.

---

### Task 5.6: Testar conexao via Run Command

```powershell
# ============================================================
# TASK 5.6 - Testar conectividade APOS peering via Run Command
# ============================================================

# Obter IP privado da vm-web-01
$coreIP = (Get-AzNetworkInterface -Name "$vmCore-nic" -ResourceGroupName $rg5).IpConfigurations[0].PrivateIpAddress
Write-Host "IP privado da vm-web-01: $coreIP"

# Invoke-AzVMRunCommand: executa comando dentro da VM
# -CommandId RunPowerShellScript: executa PowerShell na VM
# -ScriptString: comando a executar
$result = Invoke-AzVMRunCommand `
    -ResourceGroupName $rg5 `
    -VMName $vmMfg `
    -CommandId "RunPowerShellScript" `
    -ScriptString "Test-NetConnection $coreIP -Port 3389"

# Mostrar resultado
$result.Value[0].Message
# Esperado: TcpTestSucceeded: True
```

---

### Task 5.6b: Testar nao-transitividade do peering

```powershell
# ============================================================
# TASK 5.6b - Testar nao-transitividade do peering
# ============================================================
# CONCEITO AZ-104: Peering e NAO transitivo!
# Se vnet-contoso-hub-eastus ↔ vnet-contoso-spoke-eastus e
# vnet-contoso-spoke-eastus ↔ ResearchVnet,
# vnet-contoso-hub-eastus NAO fala com ResearchVnet automaticamente.
# Para transitividade: hub-spoke com NVA ou Azure Virtual WAN.

# Testar conectividade para um IP de uma terceira VNet inexistente
# (simulando que nao ha peering direto)
$result = Invoke-AzVMRunCommand `
    -ResourceGroupName $rg5 `
    -VMName $vmMfg `
    -CommandId "RunPowerShellScript" `
    -ScriptString "Test-NetConnection -ComputerName 10.40.0.4 -Port 3389 -WarningAction SilentlyContinue | Select-Object TcpTestSucceeded"

$result.Value[0].Message
# Resultado esperado: TcpTestSucceeded: False
# Peering e NAO transitivo: A↔B e B↔C nao significa A↔C
```

> O peering funciona! As VMs se comunicam pela rede backbone da Microsoft.

---

### Task 5.7: Teste de integracao — DNS privado com IP real da VM

```powershell
# ============================================================
# TASK 5.7 - Atualizar DNS privado com IP real da vm-web-01
# ============================================================

# 1. Adicionar Virtual Network Link para vnet-contoso-hub-eastus
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4

New-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $rg4 `
    -ZoneName $dnsPrivate `
    -Name "coreservices-link" `
    -VirtualNetworkId $vnetCoreObj.Id `
    -EnableRegistration $false

Write-Host "Link adicionado: vnet-contoso-hub-eastus → $dnsPrivate"

# 2. Criar registro A com IP REAL da vm-web-01
$coreIP = (Get-AzNetworkInterface -Name "$vmCore-nic" -ResourceGroupName $rg5).IpConfigurations[0].PrivateIpAddress

$coreRecord = New-AzPrivateDnsRecordSet `
    -ResourceGroupName $rg4 `
    -ZoneName $dnsPrivate `
    -Name "corevm" `
    -RecordType A `
    -Ttl 1

Add-AzPrivateDnsRecordConfig -RecordSet $coreRecord -Ipv4Address $coreIP | Out-Null
Set-AzPrivateDnsRecordSet -RecordSet $coreRecord | Out-Null

Write-Host "Registro A: corevm.$dnsPrivate → $coreIP"

# 3. Testar resolucao DNS a partir da vm-app-01
$dnsResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $rg5 `
    -VMName $vmMfg `
    -CommandId "RunPowerShellScript" `
    -ScriptString "Resolve-DnsName corevm.$dnsPrivate"

$dnsResult.Value[0].Message
# Esperado: retorna o IP privado da vm-web-01
```

> **Conexao com Bloco 4:** A zona DNS privada agora resolve nomes reais de VMs.
> vnet-contoso-spoke-eastus (linkada no Bloco 4) e vnet-contoso-hub-eastus (linkada agora)
> podem resolver nomes nesta zona.

---

### Task 5.8: Criar subnet perimeter, Route Table e custom route

```powershell
# ============================================================
# TASK 5.8 - Criar subnet perimeter + Route Table + UDR
# ============================================================

# 1. Adicionar subnet "perimeter" na vnet-contoso-hub-eastus
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4

Add-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnetCoreObj `
    -Name $subnetPerimeter `
    -AddressPrefix $subnetPerimPfx | Out-Null

$vnetCoreObj | Set-AzVirtualNetwork | Out-Null
Write-Host "Subnet '$subnetPerimeter' ($subnetPerimPfx) adicionada"

# 2. Criar Route Table
# -DisableBgpRoutePropagation: nao propaga rotas do BGP (equivale a "No" no portal)
$rt = New-AzRouteTable `
    -ResourceGroupName $rg5 `
    -Name $rtName `
    -Location $location `
    -DisableBgpRoutePropagation

Write-Host "Route table criada: $rtName"

# 3. Criar custom route (UDR)
# Add-AzRouteConfig + Set-AzRouteTable: adiciona rota e aplica
# -NextHopType VirtualAppliance: direciona para NVA (firewall/proxy)
# -NextHopIpAddress: IP do NVA
Add-AzRouteConfig `
    -RouteTable $rt `
    -Name "PerimetertoCore" `
    -AddressPrefix "10.20.0.0/16" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $nvaIP | Out-Null

$rt | Set-AzRouteTable | Out-Null
Write-Host "Rota adicionada: 10.20.0.0/16 → NVA $nvaIP"

# 4. Associar route table a subnet Core
# Buscar VNet e subnet atualizados
$vnetCoreObj = Get-AzVirtualNetwork -Name $vnetCore -ResourceGroupName $rg4
$subnetCoreConfig = $vnetCoreObj.Subnets | Where-Object { $_.Name -eq $subnetCore }

Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnetCoreObj `
    -Name $subnetCore `
    -AddressPrefix $subnetCorePfx `
    -RouteTableId $rt.Id | Out-Null

$vnetCoreObj | Set-AzVirtualNetwork | Out-Null
Write-Host "Route table associada a subnet $subnetCore"
```

> **Conceito:** UDRs sobrescrevem rotas do sistema. Se o NVA nao existir no IP configurado,
> o trafego e **descartado** (dropped).

---

### Task 5.9: Teste de integracao — Verificar isolamento NSG por subnet

```powershell
# ============================================================
# TASK 5.9 - Verificar que o NSG afeta apenas snet-shared
# ============================================================

# Listar associacoes do NSG
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg4

Write-Host "=== Subnets associadas ao NSG $nsgName ==="
$nsg.Subnets | ForEach-Object {
    # Extrair nome da subnet do ID
    $parts = $_.Id -split "/"
    $subnetName = $parts[-1]
    $vnetName = $parts[-3]
    Write-Host "  - $vnetName / $subnetName"
}

Write-Host "`n=== Validacao ==="
Write-Host "vm-web-01 (subnet Core): NAO afetada pelo NSG ✓"
Write-Host "vm-app-01 (subnet Manufacturing): NAO afetada pelo NSG ✓"
Write-Host "Apenas snet-shared e protegida pelo NSG."
Write-Host "NSGs sao associados a subnets ou NICs, NAO a VNets inteiras."
```

---

### Task 5.10: Teste de integracao final — RBAC de ponta a ponta

```powershell
# ============================================================
# TASK 5.10 - Verificar RBAC end-to-end (informativo + manual)
# ============================================================

Write-Host "=== Teste de RBAC End-to-End ===" -ForegroundColor Green
Write-Host ""
Write-Host "Para teste manual completo, abra InPrivate/Incognito e faca login como:"
Write-Host "  UPN: $userUPN"
Write-Host "  Senha: (salva no Bloco 1)"
Write-Host ""
Write-Host "Verificacoes:"
Write-Host "  1. Virtual Machines → deve ver vm-web-01 e vm-app-01"
Write-Host "  2. Stop vm-web-01 → deve funcionar (VM Contributor)"
Write-Host "  3. Deletar rg-contoso-identity → deve falhar (sem permissao + Lock)"
Write-Host "  4. Criar Storage Account → deve falhar (VM Contributor nao inclui Storage)"

# Verificacao programatica dos roles
Write-Host "`n=== Roles de $userName (via grupo) ===" -ForegroundColor Yellow
$userRoles = Get-AzRoleAssignment -ObjectId $user1.Id
$groupRoles = Get-AzRoleAssignment -ObjectId $itLabGroup.Id

$allRoles = $userRoles + $groupRoles | Select-Object -Unique DisplayName, RoleDefinitionName, Scope
$allRoles | Format-Table -AutoSize

Write-Host "`nValidacao completa:" -ForegroundColor Green
Write-Host "  ✓ Bloco 1: Identidade criada"
Write-Host "  ✓ Bloco 2: RBAC (VM Contributor) + Lock + Policies"
Write-Host "  ✓ Bloco 3: Discos com tags herdadas + policy de localizacao"
Write-Host "  ✓ Bloco 4: VNets, NSG, DNS criados"
Write-Host "  ✓ Bloco 5: VMs comunicando via peering + DNS resolvendo"
```

---

## Modo Desafio - Bloco 5

- [ ] Adicionar subnet `Core` (10.20.0.0/24) na vnet-contoso-hub-eastus
- [ ] Adicionar subnet `Manufacturing` (10.30.0.0/24) na vnet-contoso-spoke-eastus
- [ ] Criar NIC cross-RG + `vm-web-01` em rg-contoso-compute
- [ ] Criar NIC cross-RG + `vm-app-01` em rg-contoso-compute
- [ ] `Test-AzNetworkWatcherConnectivity` → Unreachable
- [ ] `Add-AzVirtualNetworkPeering` bidirecional
- [ ] `Invoke-AzVMRunCommand` → Test-NetConnection → Success
- [ ] Adicionar VNet link + registro A com IP real → `Resolve-DnsName`
- [ ] Criar subnet `perimeter` + Route Table + custom route (NVA 10.20.1.7)
- [ ] Verificar NSG isolado por subnet
- [ ] **Integracao final:** Verificar RBAC end-to-end

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Uma VM no rg-contoso-compute usa uma VNet do rg-contoso-network. E possivel?**

A) Nao, VMs e VNets devem estar no mesmo Resource Group
B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription
C) Sim, mas apenas via ARM template
D) Nao, a VNet precisa ser movida para o mesmo RG

<details>
<summary>Ver resposta</summary>

**Resposta: B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription**

No PowerShell, a referencia cross-RG e feita pelo ID completo da subnet (que contem o RG da VNet). Exemplo: `New-AzNetworkInterface -SubnetId $subnetObj.Id`.

</details>

### Questao 5.2
**VNet A tem peering com VNet B. VNet B tem peering com VNet C. VNet A se comunica com VNet C?**

A) Sim, peering e transitivo
B) Nao, peering NAO e transitivo — precisa de peering direto A↔C
C) Sim, se forwarded traffic estiver habilitado
D) Nao, precisa de VPN Gateway

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, peering NAO e transitivo**

Peering nao e transitivo. Para A↔C, crie peering direto ou use hub-spoke com NVA/VPN Gateway.

</details>

### Questao 5.3
**Voce criou uma UDR com next hop "Virtual appliance" IP 10.20.1.7, mas nao ha NVA nesse IP. O que acontece com o trafego?**

A) Roteado normalmente, ignorando a regra
B) Descartado (dropped)
C) Azure cria um NVA automaticamente
D) Redirecionado para o gateway padrao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Descartado (dropped)**

UDRs sobrescrevem rotas do sistema. Se o next hop nao for alcancavel, o trafego e descartado sem fallback.

</details>

### Questao 5.4
**Voce configurou VNet Peering e quer que o trafego passe por um NVA antes de alcançar o destino. O que precisa configurar?**

A) Apenas um NSG na subnet de destino
B) Uma UDR na subnet de origem com next hop apontando para o NVA
C) Habilitar IP forwarding no NVA e nada mais
D) Criar um VPN Gateway entre as VNets

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma UDR na subnet de origem com next hop apontando para o NVA**

Alem da UDR, o NVA precisa ter **IP forwarding** habilitado na NIC.

</details>

### Questao 5.5
**Voce criou uma Private DNS Zone e vinculou apenas a VNet A. Uma VM na VNet B (com peering para A) tenta resolver. O que acontece?**

A) A resolucao funciona porque o peering compartilha DNS
B) A resolucao falha porque a VNet B nao tem Virtual Network Link
C) A resolucao funciona se "Allow forwarded traffic" estiver habilitado
D) A resolucao funciona apenas com DNS forwarder

<details>
<summary>Ver resposta</summary>

**Resposta: B) A resolucao falha porque a VNet B nao tem Virtual Network Link**

Private DNS Zones resolvem nomes apenas para VNets com Virtual Network Link configurado. Peering NAO propaga DNS.

</details>

---

---

# Bloco 6 - Load Balancer e Azure Bastion

**Tecnologia:** PowerShell (Az module)
**Recursos criados:** Subnet snet-lb, Availability Set, 2 VMs (IIS), Public LB, Internal LB, NSG, Bastion
**Resource Group:** `rg-contoso-network` (VMs e LBs) + `rg-contoso-network` (VNet existente)

> **Nota:** Este bloco cria VMs, Public IPs e Bastion que geram custo. Faca cleanup assim que terminar.

---

### Task 6.1: Criar RG, subnet e Availability Set

```powershell
# ============================================================
# TASK 6.1a - Criar RG e subnet snet-lb
# ============================================================

$rg6 = "rg-contoso-network"
New-AzResourceGroup -Name $rg6 -Location $location -Tag @{"Cost Center" = "000"}

# Adicionar subnet snet-lb na vnet-contoso-hub-eastus (rg-contoso-network)
$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4
Add-AzVirtualNetworkSubnetConfig -Name "snet-lb" `
    -VirtualNetwork $coreVnet `
    -AddressPrefix "10.20.40.0/24"
$coreVnet | Set-AzVirtualNetwork   # IMPORTANTE: Set-Az* aplica a mudanca!

Write-Host "RG rg-contoso-network e subnet snet-lb criados" -ForegroundColor Green
```

---

### Task 6.1b: Criar Availability Set e VMs

```powershell
# ============================================================
# TASK 6.1b - Availability Set + 2 VMs
# ============================================================
# CONCEITO AZ-104: Availability Sets distribuem VMs entre:
#   - Fault Domains (FD): racks fisicos diferentes
#   - Update Domains (UD): reinicializacoes escalonadas
# O LB Standard requer VMs em AvSet, Zone ou VMSS

# Criar Availability Set
$avSet = New-AzAvailabilitySet -ResourceGroupName $rg6 `
    -Name "avail-contoso-lb" `
    -Location $location `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 5 `
    -Sku "Aligned"   # Obrigatorio para managed disks

Write-Host "Availability Set criado: $($avSet.Name)" -ForegroundColor Green

# Obter subnet snet-lb (cross-RG: VNet em rg4, VM em rg6)
$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4
$lbSubnet = $coreVnet.Subnets | Where-Object { $_.Name -eq "snet-lb" }

# ==================== Criar vm-lb-01 ====================
# NIC cross-RG: NIC no rg6, subnet no rg4
$nic1 = New-AzNetworkInterface -Name "nic-vm-lb-01" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -SubnetId $lbSubnet.Id   # Cross-RG pelo ID completo

# Configuracao da VM
$vmConfig1 = New-AzVMConfig -VMName "vm-lb-01" `
    -VMSize "Standard_D2s_v3" `
    -AvailabilitySetId $avSet.Id   # Associa ao Availability Set

$vmConfig1 = Set-AzVMOperatingSystem -VM $vmConfig1 `
    -Windows -ComputerName "vm-lb-01" `
    -Credential $vmCredential

$vmConfig1 = Set-AzVMSourceImage -VM $vmConfig1 `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"

$vmConfig1 = Add-AzVMNetworkInterface -VM $vmConfig1 -Id $nic1.Id

$vmConfig1 = Set-AzVMBootDiagnostic -VM $vmConfig1 -Disable

New-AzVM -ResourceGroupName $rg6 -Location $location -VM $vmConfig1
Write-Host "vm-lb-01 criada" -ForegroundColor Green

# ==================== Criar vm-lb-02 ====================
$nic2 = New-AzNetworkInterface -Name "nic-vm-lb-02" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -SubnetId $lbSubnet.Id

$vmConfig2 = New-AzVMConfig -VMName "vm-lb-02" `
    -VMSize "Standard_D2s_v3" `
    -AvailabilitySetId $avSet.Id

$vmConfig2 = Set-AzVMOperatingSystem -VM $vmConfig2 `
    -Windows -ComputerName "vm-lb-02" `
    -Credential $vmCredential

$vmConfig2 = Set-AzVMSourceImage -VM $vmConfig2 `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"

$vmConfig2 = Add-AzVMNetworkInterface -VM $vmConfig2 -Id $nic2.Id

$vmConfig2 = Set-AzVMBootDiagnostic -VM $vmConfig2 -Disable

New-AzVM -ResourceGroupName $rg6 -Location $location -VM $vmConfig2
Write-Host "vm-lb-02 criada" -ForegroundColor Green
```

---

### Task 6.1c: Instalar IIS nas VMs

```powershell
# ============================================================
# TASK 6.1c - Instalar IIS via Run Command
# ============================================================
# CONCEITO: Invoke-AzVMRunCommand executa scripts DENTRO da VM
# A pagina customizada exibe o hostname para verificar balanceamento

$iisScript = @"
Install-WindowsFeature -name Web-Server -IncludeManagementTools
Remove-Item 'C:\inetpub\wwwroot\iisstart.htm'
Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value `$('Hello from ' + `$env:computername)
"@

Invoke-AzVMRunCommand -ResourceGroupName $rg6 -VMName "vm-lb-01" `
    -CommandId "RunPowerShellScript" -ScriptString $iisScript
Write-Host "IIS instalado em vm-lb-01" -ForegroundColor Green

Invoke-AzVMRunCommand -ResourceGroupName $rg6 -VMName "vm-lb-02" `
    -CommandId "RunPowerShellScript" -ScriptString $iisScript
Write-Host "IIS instalado em vm-lb-02" -ForegroundColor Green
```

---

### Task 6.2: Criar Public Load Balancer

```powershell
# ============================================================
# TASK 6.2 - Public Load Balancer Standard
# ============================================================
# CONCEITO AZ-104: Standard LB
#   - BLOQUEIA trafego por padrao (NSG obrigatorio)
#   - Requer Standard SKU PIP
#   - Backend pool por VNet (nao por NIC como Basic)
#   - Zone-aware, suporta Availability Zones

# 1. Public IP (Standard SKU, Static)
$lbPip = New-AzPublicIpAddress -Name "pip-lbe-contoso-web" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 1,2,3   # Zone-redundant

# 2. Frontend IP Configuration
$frontendConfig = New-AzLoadBalancerFrontendIpConfig -Name "fe-lbe-web" `
    -PublicIpAddressId $lbPip.Id

# 3. Backend Address Pool
$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "bp-lbe-web"

# 4. Health Probe (HTTP na porta 80)
# CONCEITO: Probe HTTP verifica a APLICACAO, nao apenas a VM
# Se IIS parar mas VM continuar, probe falha → VM removida do pool
$healthProbe = New-AzLoadBalancerProbeConfig -Name "http-probe" `
    -Protocol "Http" `
    -Port 80 `
    -RequestPath "/" `
    -IntervalInSeconds 5 `
    -ProbeCount 2   # 2 falhas = unhealthy

# 5. Load Balancing Rule
# CONCEITO: 5-tuple hash (src IP, src port, dst IP, dst port, protocol)
$lbRule = New-AzLoadBalancerRuleConfig -Name "http-rule" `
    -FrontendIpConfigurationId $frontendConfig.Id `
    -BackendAddressPoolId $backendPool.Id `
    -ProbeId $healthProbe.Id `
    -Protocol "Tcp" `
    -FrontendPort 80 `
    -BackendPort 80 `
    -IdleTimeoutInMinutes 4 `
    -LoadDistribution "Default"   # 5-tuple hash

# 6. Criar Load Balancer
$publicLb = New-AzLoadBalancer -Name "lbe-contoso-web" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -Sku "Standard" `
    -FrontendIpConfiguration $frontendConfig `
    -BackendAddressPool $backendPool `
    -Probe $healthProbe `
    -LoadBalancingRule $lbRule

Write-Host "Public Load Balancer criado: $($publicLb.Name)" -ForegroundColor Green

# 7. Adicionar VMs ao Backend Pool
$publicLb = Get-AzLoadBalancer -Name "lbe-contoso-web" -ResourceGroupName $rg6
$backendPool = $publicLb.BackendAddressPools[0]

$nic1 = Get-AzNetworkInterface -Name "nic-vm-lb-01" -ResourceGroupName $rg6
$nic1.IpConfigurations[0].LoadBalancerBackendAddressPools = $backendPool
$nic1 | Set-AzNetworkInterface

$nic2 = Get-AzNetworkInterface -Name "nic-vm-lb-02" -ResourceGroupName $rg6
$nic2.IpConfigurations[0].LoadBalancerBackendAddressPools = $backendPool
$nic2 | Set-AzNetworkInterface

Write-Host "VMs adicionadas ao backend pool" -ForegroundColor Green
Write-Host "Teste: http://$($lbPip.IpAddress)" -ForegroundColor Cyan
```

---

### Task 6.3: Criar NSG e associar a snet-lb

```powershell
# ============================================================
# TASK 6.3 - NSG para snet-lb
# ============================================================
# CONCEITO: Standard LB BLOQUEIA todo trafego por padrao!
# Sem NSG com AllowHTTP, as VMs nao respondem

# Criar regra AllowHTTP
$httpRule = New-AzNetworkSecurityRuleConfig -Name "AllowHTTP" `
    -Priority 100 `
    -Direction "Inbound" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -SourcePortRange "*" `
    -DestinationPortRange "80" `
    -SourceAddressPrefix "*" `
    -DestinationAddressPrefix "*"

# Criar NSG
$nsgLb = New-AzNetworkSecurityGroup -Name "nsg-snet-lb" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -SecurityRules $httpRule

# Associar NSG a snet-lb (cross-RG: NSG em rg6, subnet em rg4)
$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4
$lbSubnetConfig = $coreVnet.Subnets | Where-Object { $_.Name -eq "snet-lb" }
$lbSubnetConfig.NetworkSecurityGroup = $nsgLb
$coreVnet | Set-AzVirtualNetwork

Write-Host "NSG nsg-snet-lb associado a snet-lb" -ForegroundColor Green
Write-Host "Teste: http://$($lbPip.IpAddress) + hard refresh (Ctrl+Shift+R)" -ForegroundColor Cyan
```

---

### Task 6.3b: Testar Session Persistence

```powershell
# ============================================================
# TASK 6.3b - Testar Session Persistence
# ============================================================
# CONCEITO AZ-104: Load Distribution (Session Persistence)
#   | Modo                    | Hash           | Comportamento                    |
#   |-------------------------|----------------|----------------------------------|
#   | None (Default)          | 5-tuple        | src IP+port, dst IP+port, proto  |
#   | Client IP (SourceIP)    | 2-tuple        | src IP + dst IP                  |
#   | Client IP and Protocol  | 3-tuple        | src IP + dst IP + proto          |
# None = melhor distribuicao | SourceIP = sticky sessions

# Obter LB e regra atual
$lb = Get-AzLoadBalancer -Name "lbe-contoso-web" -ResourceGroupName $rg6
$rule = $lb.LoadBalancingRules[0]

# Modo 1: None (5-tuple hash) - padrao, ja testado
Write-Host "Modo atual: $($rule.LoadDistribution)" -ForegroundColor Cyan

# Modo 2: Client IP (2-tuple: source IP + dest IP)
$rule.LoadDistribution = "SourceIP"
Set-AzLoadBalancer -LoadBalancer $lb | Out-Null
Write-Host "Alterado para SourceIP (2-tuple)" -ForegroundColor Yellow
Write-Host "Teste: refresh no navegador → mesmo servidor responde" -ForegroundColor Cyan

# Modo 3: Client IP and Protocol (3-tuple)
$rule.LoadDistribution = "SourceIPProtocol"
Set-AzLoadBalancer -LoadBalancer $lb | Out-Null
Write-Host "Alterado para SourceIPProtocol (3-tuple)" -ForegroundColor Yellow

# Reverter para None (5-tuple) - padrao
$rule.LoadDistribution = "Default"
Set-AzLoadBalancer -LoadBalancer $lb | Out-Null
Write-Host "Revertido para Default (5-tuple)" -ForegroundColor Green
```

---

### Task 6.4: Testar failover

```powershell
# ============================================================
# TASK 6.4 - Testar failover do Load Balancer
# ============================================================
# CONCEITO: Quando VM falha no probe, LB remove da rotacao automaticamente

Stop-AzVM -ResourceGroupName $rg6 -Name "vm-lb-01" -Force
Write-Host "vm-lb-01 parada. Apenas vm-lb-02 deve responder." -ForegroundColor Yellow

# Reiniciar
Start-AzVM -ResourceGroupName $rg6 -Name "vm-lb-01"
Write-Host "vm-lb-01 reiniciada. Aguarde probe re-detectar (~30s)." -ForegroundColor Green
```

---

### Task 6.5: Criar Internal Load Balancer

```powershell
# ============================================================
# TASK 6.5 - Internal Load Balancer
# ============================================================
# CONCEITO: Internal LB usa IP PRIVADO como frontend
# Ideal para comunicacao entre tiers (ex: frontend → backend)
# Public e Internal LBs podem compartilhar o MESMO backend pool

$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4
$lbSubnet = $coreVnet.Subnets | Where-Object { $_.Name -eq "snet-lb" }

# Frontend com IP privado estatico
$intFrontend = New-AzLoadBalancerFrontendIpConfig -Name "int-fe-lbe-web" `
    -PrivateIpAddress "10.20.40.100" `
    -SubnetId $lbSubnet.Id

$intBackend = New-AzLoadBalancerBackendAddressPoolConfig -Name "bp-lbi-apps"

$intProbe = New-AzLoadBalancerProbeConfig -Name "int-http-probe" `
    -Protocol "Http" -Port 80 -RequestPath "/" `
    -IntervalInSeconds 5 -ProbeCount 2

$intRule = New-AzLoadBalancerRuleConfig -Name "int-http-rule" `
    -FrontendIpConfigurationId $intFrontend.Id `
    -BackendAddressPoolId $intBackend.Id `
    -ProbeId $intProbe.Id `
    -Protocol "Tcp" -FrontendPort 80 -BackendPort 80 `
    -IdleTimeoutInMinutes 4 -LoadDistribution "Default"

$intLb = New-AzLoadBalancer -Name "lbi-contoso-apps" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -Sku "Standard" `
    -FrontendIpConfiguration $intFrontend `
    -BackendAddressPool $intBackend `
    -Probe $intProbe `
    -LoadBalancingRule $intRule

# Adicionar VMs ao backend pool do Internal LB
$intLb = Get-AzLoadBalancer -Name "lbi-contoso-apps" -ResourceGroupName $rg6
$intPool = $intLb.BackendAddressPools[0]

$nic1 = Get-AzNetworkInterface -Name "nic-vm-lb-01" -ResourceGroupName $rg6
$nic1.IpConfigurations[0].LoadBalancerBackendAddressPools += $intPool
$nic1 | Set-AzNetworkInterface

$nic2 = Get-AzNetworkInterface -Name "nic-vm-lb-02" -ResourceGroupName $rg6
$nic2.IpConfigurations[0].LoadBalancerBackendAddressPools += $intPool
$nic2 | Set-AzNetworkInterface

Write-Host "Internal LB criado com frontend IP 10.20.40.100" -ForegroundColor Green
```

---

### Task 6.6: Troubleshoot health probe

```powershell
# ============================================================
# TASK 6.6 - Troubleshoot: parar/reiniciar IIS
# ============================================================
# CONCEITO: Probe detecta falha na APLICACAO (IIS), nao na VM
# VM running + IIS parado = probe unhealthy → VM removida do pool

# Parar IIS
Invoke-AzVMRunCommand -ResourceGroupName $rg6 -VMName "vm-lb-01" `
    -CommandId "RunPowerShellScript" `
    -ScriptString "Stop-Service -Name W3SVC -Force"

Write-Host "IIS parado em vm-lb-01. Verifique Health Probe Status no portal." -ForegroundColor Yellow

# Corrigir: reiniciar IIS
Invoke-AzVMRunCommand -ResourceGroupName $rg6 -VMName "vm-lb-01" `
    -CommandId "RunPowerShellScript" `
    -ScriptString "Start-Service -Name W3SVC"

Write-Host "IIS reiniciado em vm-lb-01." -ForegroundColor Green
```

---

### Task 6.7: Implantar Azure Bastion

```powershell
# ============================================================
# TASK 6.7 - Azure Bastion
# ============================================================
# CONCEITO AZ-104: Azure Bastion
#   - Acesso RDP/SSH via portal sem IP publico na VM
#   - Subnet DEVE ser 'AzureBastionSubnet' (nome obrigatorio!)
#   - Tamanho minimo /26 (64 IPs)
#   - Basic: RDP/SSH via portal
#   - Standard: + native client, IP-based connection

# Criar AzureBastionSubnet
$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4
Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" `
    -VirtualNetwork $coreVnet `
    -AddressPrefix "10.20.30.0/26"   # /26 minimo!
$coreVnet | Set-AzVirtualNetwork

# Public IP para Bastion
$bastionPip = New-AzPublicIpAddress -Name "bas-contoso-hub-pip" `
    -ResourceGroupName $rg6 `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static"

# Criar Bastion
# NOTA: O deploy pode levar 5-10 minutos
$coreVnet = Get-AzVirtualNetwork -Name "vnet-contoso-hub-eastus" -ResourceGroupName $rg4

New-AzBastion -ResourceGroupName $rg6 `
    -Name "bas-contoso-hub" `
    -PublicIpAddressRgName $rg6 `
    -PublicIpAddressName "bas-contoso-hub-pip" `
    -VirtualNetworkRgName $rg4 `
    -VirtualNetworkName "vnet-contoso-hub-eastus" `
    -Sku "Basic"

Write-Host "Azure Bastion implantado" -ForegroundColor Green
Write-Host "Acesse: vm-lb-01 > Connect > Bastion (sem IP publico!)" -ForegroundColor Cyan
```

---

## Modo Desafio - Bloco 6

- [ ] Criar RG `rg-contoso-network` e subnet `snet-lb`
- [ ] `New-AzAvailabilitySet` (2 FD, 5 UD, Aligned)
- [ ] Criar 2 VMs (`New-AzVM`) no Availability Set, cross-RG NIC
- [ ] `Invoke-AzVMRunCommand` para instalar IIS
- [ ] `New-AzLoadBalancer` (Standard, Public) com frontend, backend, probe, rule
- [ ] `New-AzNetworkSecurityGroup` com AllowHTTP, associar a snet-lb
- [ ] Testar balanceamento + failover
- [ ] `New-AzLoadBalancer` (Standard, Internal) com IP 10.20.40.100
- [ ] Troubleshoot: parar IIS → unhealthy → reiniciar IIS
- [ ] `New-AzBastion` (AzureBastionSubnet /26 + Basic)
- [ ] Conectar via Bastion

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Standard LB, VMs no backend, probes healthy, mas clientes nao acessam. Causa?**

A) LB requer Availability Zones  B) Falta NSG permitindo trafego  C) Probe errado  D) VMs precisam IP publico

<details><summary>Ver resposta</summary>**Resposta: B)** Standard LB bloqueia trafego por padrao. NSG obrigatorio.</details>

### Questao 6.2
**Diferenca entre Public LB e Internal LB?**

A) Public = Basic; Internal = Standard  B) Public = internet; Internal = dentro da VNet  C) Internal sem probes  D) Public so TCP

<details><summary>Ver resposta</summary>**Resposta: B)** Public = IP publico. Internal = IP privado entre tiers.</details>

### Questao 6.3
**Requisito de subnet para Azure Bastion?**

A) `BastionSubnet` /28  B) `AzureBastionSubnet` /26  C) Qualquer /24  D) `AzureBastionSubnet` /24

<details><summary>Ver resposta</summary>**Resposta: B)** Nome EXATO `AzureBastionSubnet`, minimo /26.</details>

### Questao 6.4
**VM com probe Unhealthy mas running e acessivel via RDP. Causa?**

A) Sem IP publico  B) Servico (IIS) nao responde  C) AvSet diferente  D) LB precisa restart

<details><summary>Ver resposta</summary>**Resposta: B)** Probes verificam a APLICACAO, nao a VM.</details>

### Questao 6.5
**3 VMs, 1 unhealthy. Trafego?**

A) Enfileirado  B) Redistribuido para healthy  C) LB para  D) Descartado

<details><summary>Ver resposta</summary>**Resposta: B)** LB redistribui para VMs healthy.</details>

---

# Bloco 7 - SSPR, Cost Management e NSG Effective Rules

**Tecnologia:** PowerShell (Microsoft.Graph + Az module) + Portal
**Recursos:** SSPR config, Budget, Advisor, Network Watcher diagnostics
**Resource Groups utilizados:** `rg-contoso-network`, `rg-contoso-compute`, `rg-contoso-network`

> **Nota:** Bloco majoritariamente portal/PowerShell. SSPR usa Microsoft.Graph,
> Cost Management e Advisor usam cmdlets Az, Network Watcher usa cmdlets de diagnostico.

---

### Task 7.1: Criar grupo SSPR-TestGroup e habilitar SSPR

```powershell
# ============================================================
# TASK 7.1 - Criar grupo e habilitar SSPR
# ============================================================
# CONCEITO AZ-104: SSPR (Self-Service Password Reset)
#   - Permite reset sem helpdesk
#   - Habilitado para: All | Selected (grupo) | None
#   - Azure AD Free: cloud users | P1/P2: writeback on-premises

# Criar grupo de seguranca para SSPR (Microsoft.Graph)
$ssprGroup = New-MgGroup -DisplayName "SSPR-TestGroup" `
    -MailEnabled:$false `
    -MailNickname "sspr-testgroup" `
    -SecurityEnabled:$true `
    -Description "Grupo de teste para Self-Service Password Reset"

Write-Host "Grupo SSPR-TestGroup criado: $($ssprGroup.Id)" -ForegroundColor Green

# Adicionar contoso-user1 ao grupo
$user1Obj = Get-MgUser -Filter "userPrincipalName eq 'contoso-user1@$tenantDomain'"
New-MgGroupMember -GroupId $ssprGroup.Id `
    -DirectoryObjectId $user1Obj.Id

Write-Host "contoso-user1 adicionado ao SSPR-TestGroup" -ForegroundColor Green

# Habilitar SSPR via portal
Write-Host "`n=== ACAO MANUAL REQUERIDA ===" -ForegroundColor Yellow
Write-Host "1. Portal > Entra ID > Protection > Password reset"
Write-Host "2. Properties > Enabled: Selected > Group: SSPR-TestGroup"
Write-Host "3. Save"
```

---

### Task 7.2: Configurar metodos de autenticacao

```powershell
# ============================================================
# TASK 7.2 - Configurar metodos SSPR (portal)
# ============================================================

Write-Host "=== ACAO MANUAL - Portal ===" -ForegroundColor Yellow
Write-Host "1. Password reset > Authentication methods"
Write-Host "   - Methods required: 1"
Write-Host "   - Methods: Email + Security questions"
Write-Host "2. Security questions: register 3, reset 3"
Write-Host "3. Registration: Require on sign-in: Yes"
Write-Host "4. Notifications: Notify users + admins: Yes"
```

---

### Task 7.3: Testar reset de senha

```powershell
# ============================================================
# TASK 7.3 - Testar fluxo SSPR
# ============================================================

Write-Host "1. InPrivate > https://aka.ms/ssprsetup > login contoso-user1" -ForegroundColor Cyan
Write-Host "2. Registrar metodos (email + security questions)"
Write-Host "3. https://aka.ms/sspr > username > captcha > nova senha"
```

---

### Task 7.4: Criar Budget e alertas

```powershell
# ============================================================
# TASK 7.4 - Criar Budget no Cost Management
# ============================================================
# CONCEITO: Budgets alertam mas NAO param recursos
# Para enforcement: Azure Policy ou Automation

# PowerShell nao tem cmdlet nativo para budgets
# Use az CLI dentro do PowerShell ou portal
Write-Host "=== Criar Budget via Portal ou CLI ===" -ForegroundColor Yellow
Write-Host "Portal: Cost Management > Budgets > + Add"
Write-Host "  Name: contoso-lab-budget"
Write-Host "  Reset: Monthly"
Write-Host "  Amount: `$50"
Write-Host "  Alertas: 80% Actual, 100% Actual, 120% Forecasted"
Write-Host ""
Write-Host "Ou via Azure CLI no Cloud Shell (Bash):" -ForegroundColor Cyan
Write-Host '  az consumption budget create --budget-name "contoso-lab-budget" --amount 50 --time-grain Monthly --category Cost'
```

---

### Task 7.4b: Configurar enforcement automatico com Action Group

```powershell
# ============================================================
# TASK 7.4b - Configurar enforcement automatico com Action Group
# ============================================================
# CONCEITO: Budgets alertam mas NAO bloqueiam. Para enforcement:
# - Azure Policy: restringir SKUs de VM permitidos
# - Automation Runbook: desligar VMs quando budget atingido
# - Spending Limit: apenas para subscriptions dev/test

# Criar Action Group para notificacoes de budget
$emailReceiver = New-AzActionGroupEmailReceiverObject `
    -Name "admin-email" `
    -EmailAddress "your@email.com"

$actionGroup = Set-AzActionGroup `
    -ResourceGroupName $rg6 `
    -Name "contoso-budget-ag" `
    -ShortName "budgetag" `
    -EmailReceiver $emailReceiver

Write-Host "Action Group criado: $($actionGroup.Name)" -ForegroundColor Green
Write-Host "  Email: your@email.com"

# Atualizar budget para usar Action Group
Write-Host ""
Write-Host "=== Para vincular Action Group ao Budget ===" -ForegroundColor Yellow
Write-Host "Portal: Cost Management > Budgets > contoso-lab-budget > Edit"
Write-Host "  Alert conditions > Action group: contoso-budget-ag"
Write-Host ""
Write-Host "Ou via REST API (az CLI dentro do PowerShell):"
Write-Host '  az rest --method PUT --url "https://management.azure.com/subscriptions/{sub-id}/providers/Microsoft.Consumption/budgets/contoso-lab-budget?api-version=2023-05-01"'
```

---

### Task 7.5: Revisar Azure Advisor

```powershell
# ============================================================
# TASK 7.5 - Azure Advisor
# ============================================================
# CONCEITO: Advisor fornece recomendacoes de Cost, Security,
# Reliability, Operational Excellence, Performance

# Listar recomendacoes
Get-AzAdvisorRecommendation | Where-Object { $_.Category -eq "Cost" } |
    Select-Object Category, Impact, ShortDescription | Format-Table

Write-Host "`nCriar alerta: Advisor > Alerts > + New alert" -ForegroundColor Yellow
Write-Host "Category: Cost, Impact: High, Name: contoso-advisor-cost-alert"
```

---

### Task 7.6: Network Watcher - Effective Security Rules e IP Flow Verify

```powershell
# ============================================================
# TASK 7.6 - Network Watcher diagnostics
# ============================================================
# CONCEITO AZ-104: Network Watcher
#   - Effective Security Rules: regras NSG combinadas (subnet + NIC)
#   - IP Flow Verify: testa pacote especifico
#   - Inbound: subnet NSG → NIC NSG (AMBOS devem permitir)
#   - Outbound: NIC NSG → subnet NSG

# Obter NIC da vm-lb-01
$vm1 = Get-AzVM -ResourceGroupName $rg6 -Name "vm-lb-01"
$nicId = $vm1.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]

# Effective Security Rules
Write-Host "=== Effective Security Rules - vm-lb-01 ===" -ForegroundColor Cyan
$nic1Obj = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rg6
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceId $nic1Obj.Id |
    Select-Object -ExpandProperty EffectiveSecurityRules |
    Format-Table Name, Protocol, SourcePortRange, DestinationPortRange, Access, Direction, Priority

# IP Flow Verify - HTTP (deve ser permitido)
$vm1Ip = $nic1Obj.IpConfigurations[0].PrivateIpAddress
$nw = Get-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name "NetworkWatcher_$location" -ErrorAction SilentlyContinue

Write-Host "`n=== IP Flow Verify: HTTP porta 80 (ALLOW) ===" -ForegroundColor Cyan
Test-AzNetworkWatcherIPFlow -NetworkWatcher $nw `
    -TargetVirtualMachineId $vm1.Id `
    -Direction "Inbound" `
    -Protocol "TCP" `
    -LocalIPAddress $vm1Ip `
    -LocalPort "80" `
    -RemoteIPAddress "10.0.0.1" `
    -RemotePort "12345"

# IP Flow Verify - SSH (deve ser bloqueado)
Write-Host "`n=== IP Flow Verify: SSH porta 22 (DENY) ===" -ForegroundColor Cyan
Test-AzNetworkWatcherIPFlow -NetworkWatcher $nw `
    -TargetVirtualMachineId $vm1.Id `
    -Direction "Inbound" `
    -Protocol "TCP" `
    -LocalIPAddress $vm1Ip `
    -LocalPort "22" `
    -RemoteIPAddress "10.0.0.1" `
    -RemotePort "12345"
```

---

### Task 7.6b: Testar ordem de avaliacao NSG (subnet vs NIC)

```powershell
# ============================================================
# TASK 7.6b - Testar ordem de avaliacao NSG (subnet vs NIC)
# ============================================================
# CONCEITO AZ-104: Ordem de avaliacao NSG
#   Inbound:  subnet NSG primeiro → depois NIC NSG (ambos devem permitir)
#   Outbound: NIC NSG primeiro → depois subnet NSG
#   Se QUALQUER um bloquear, o trafego e negado.

# 1. Criar NSG para associar a NIC
$nsgNicTest = New-AzNetworkSecurityGroup -Name "nsg-nic-vm-web-01" `
    -ResourceGroupName $rg6 `
    -Location $location

# 2. Adicionar regra Deny HTTP na NIC
$nsgNicTest | Add-AzNetworkSecurityRuleConfig `
    -Name "DenyHTTP" `
    -Priority 100 `
    -Direction "Inbound" `
    -Access "Deny" `
    -Protocol "Tcp" `
    -SourcePortRange "*" `
    -DestinationPortRange "80" `
    -SourceAddressPrefix "*" `
    -DestinationAddressPrefix "*" | Set-AzNetworkSecurityGroup | Out-Null

Write-Host "NSG nsg-nic-vm-web-01 criado com regra DenyHTTP" -ForegroundColor Yellow

# 3. Associar NSG a NIC da vm-lb-01
$vm1 = Get-AzVM -ResourceGroupName $rg6 -Name "vm-lb-01"
$nicId = $vm1.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rg6
$nic.NetworkSecurityGroup = $nsgNicTest
$nic | Set-AzNetworkInterface | Out-Null

Write-Host "NSG associado a NIC $nicName" -ForegroundColor Yellow

# 4. Testar com IP Flow Verify - HTTP agora bloqueado
Write-Host "`n=== IP Flow Verify: HTTP porta 80 (agora DENY pela NIC) ===" -ForegroundColor Cyan
Test-AzNetworkWatcherIPFlow -NetworkWatcher $nw `
    -TargetVirtualMachineId $vm1.Id `
    -Direction "Inbound" `
    -Protocol "TCP" `
    -LocalIPAddress $vm1Ip `
    -LocalPort "80" `
    -RemoteIPAddress "10.0.0.1" `
    -RemotePort "12345"
# Resultado: Access DENY — subnet NSG permite, mas NIC NSG bloqueia

# 5. Cleanup: remover NSG da NIC
$nic.NetworkSecurityGroup = $null
$nic | Set-AzNetworkInterface | Out-Null
Remove-AzNetworkSecurityGroup -Name "nsg-nic-vm-web-01" -ResourceGroupName $rg6 -Force
Write-Host "Cleanup: NSG nsg-nic-vm-web-01 removido" -ForegroundColor Green
```

---

## Modo Desafio - Bloco 7

- [ ] `New-MgGroup` SSPR-TestGroup + `New-MgGroupMember` contoso-user1
- [ ] Habilitar SSPR (Selected) via portal
- [ ] Configurar metodos: Email + Security Questions, 1 requerido
- [ ] Testar reset via `https://aka.ms/sspr`
- [ ] Criar Budget $50/mes (portal ou CLI)
- [ ] Alertas 80%, 100%, 120%
- [ ] `Get-AzAdvisorRecommendation` + criar alerta Cost/High
- [ ] `Get-AzEffectiveNetworkSecurityGroup` em vm-lb-01
- [ ] `Test-AzNetworkWatcherIPFlow` HTTP (Allow) e SSH (Deny)

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
**Verificar se TCP 443 e permitido para VM. Ferramenta?**

A) Connection Troubleshoot  B) Effective Security Rules  C) IP Flow Verify  D) Next Hop

<details><summary>Ver resposta</summary>**Resposta: C)** IP Flow Verify testa pacote especifico.</details>

### Questao 7.4
**NSG subnet permite porta 80. NSG NIC bloqueia porta 80. Inbound?**

A) Subnet precedencia  B) Bloqueado (AMBOS devem permitir)  C) Allow vence  D) Depende priority

<details><summary>Ver resposta</summary>**Resposta: B)** Inbound: subnet → NIC. Ambos devem permitir.</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```powershell
# Pausar
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-app-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-network -Name vm-lb-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-network -Name vm-lb-02 -Force

# Retomar
Start-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01
Start-AzVM -ResourceGroupName rg-contoso-compute -Name vm-app-01
Start-AzVM -ResourceGroupName rg-contoso-network -Name vm-lb-01
Start-AzVM -ResourceGroupName rg-contoso-network -Name vm-lb-02
```

> **Nota:** Desalocar para cobranca de compute. Discos, IPs publicos e Bastion continuam gerando custo.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente VMs e Bastion.
> Execute na ordem: policies/locks primeiro, depois RGs, MG e identidades.

```powershell
# ============================================================
# CLEANUP - Remover TODOS os recursos criados
# ============================================================

# 1. Remover Policy Assignments ANTES de deletar RGs
Write-Host "1. Removendo Policy Assignments..." -ForegroundColor Yellow
$scopeRg2 = "/subscriptions/$subscriptionId/resourceGroups/$rg2"
$scopeRg3 = "/subscriptions/$subscriptionId/resourceGroups/$rg3"

Remove-AzPolicyAssignment -Name "InheritCostCenter-rg2" -Scope $scopeRg2 -ErrorAction SilentlyContinue
Remove-AzPolicyAssignment -Name "InheritCostCenter-rg3" -Scope $scopeRg3 -ErrorAction SilentlyContinue
Remove-AzPolicyAssignment -Name "AllowedLocations-rg3" -Scope $scopeRg3 -ErrorAction SilentlyContinue
Remove-AzPolicySetDefinition -Name "contoso-governance-initiative" -Force -ErrorAction SilentlyContinue
Write-Host "  Policies e Initiative removidas"

# 2. Remover Resource Lock ANTES de deletar rg-contoso-identity
Write-Host "2. Removendo Resource Lock..." -ForegroundColor Yellow
Remove-AzResourceLock -LockName "rg-lock" -ResourceGroupName $rg2 -Force -ErrorAction SilentlyContinue
Write-Host "  Lock removido"

# 3. Deletar Resource Groups (VMs primeiro por custo)
Write-Host "3. Deletando Resource Groups..." -ForegroundColor Yellow
Remove-AzResourceGroup -Name "rg-contoso-network" -Force -AsJob   # LB VMs + Bastion
Remove-AzResourceGroup -Name $rg5 -Force -AsJob   # VMs
Remove-AzResourceGroup -Name $rg4 -Force -AsJob   # VNets, DNS, NSG
Remove-AzResourceGroup -Name $rg3 -Force -AsJob   # Discos
Remove-AzResourceGroup -Name $rg2 -Force -AsJob   # Governance
Write-Host "  RGs sendo deletados em background..."

# 4. Remover subscription do MG e deletar
Write-Host "4. Removendo Management Group..." -ForegroundColor Yellow
Remove-AzManagementGroupSubscription -GroupName $mgName -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
Remove-AzManagementGroup -GroupName $mgName -ErrorAction SilentlyContinue
Write-Host "  MG removido"

# 5. Deletar Custom Role
Write-Host "5. Removendo Custom Role..." -ForegroundColor Yellow
Remove-AzRoleDefinition -Name "Custom Support Request" -Force -ErrorAction SilentlyContinue
Write-Host "  Custom role removido"

# 6. Deletar usuarios e grupos do Entra ID
Write-Host "6. Removendo usuarios e grupos..." -ForegroundColor Yellow
Remove-MgUser -UserId $user1.Id -ErrorAction SilentlyContinue
Remove-MgUser -UserId $guestUserId -ErrorAction SilentlyContinue
Remove-MgGroup -GroupId $groupIT.Id -ErrorAction SilentlyContinue
Remove-MgGroup -GroupId $groupHD.Id -ErrorAction SilentlyContinue
Remove-MgGroup -GroupId $ssprGroup.Id -ErrorAction SilentlyContinue
Write-Host "  Usuarios e grupos removidos"

# 7. Aguardar RGs serem deletados
Write-Host "`n7. Aguardando exclusao dos RGs..." -ForegroundColor Yellow
Get-Job | Wait-Job | Out-Null
Write-Host "  Todos os RGs deletados"

Write-Host "`n=== CLEANUP COMPLETO ===" -ForegroundColor Green
```

---

# Key Takeaways Consolidados

## Bloco 1 - Identity (Microsoft.Graph)
- `New-MgUser` cria usuarios, `New-MgInvitation` convida guests (B2B)
- `New-MgGroup` cria grupos; `-GroupTypes @()` = Assigned, `@("DynamicMembership")` = Dynamic
- **UsageLocation** e obrigatoria para licencas
- Entra ID e gerenciado pelo **Microsoft.Graph**, NAO pelo modulo Az

## Bloco 2 - Governance (Az module)
- `New-AzManagementGroup` + `New-AzManagementGroupSubscription` para hierarquia
- `New-AzRoleAssignment` atribui RBAC; `-Scope` define onde
- `New-AzRoleDefinition` cria custom roles com Actions/NotActions
- `New-AzPolicyAssignment` com `-IdentityType SystemAssigned` para Modify policies
- **Gotcha:** Managed Identity da policy precisa de role "Tag Contributor"
- `New-AzResourceLock` com `-LockLevel CanNotDelete` protege recursos

## Bloco 3 - IaC (Az module)
- `New-AzDiskConfig` cria configuracao local; `New-AzDisk` cria no Azure
- SkuName: `Standard_LRS` (HDD), `StandardSSD_LRS` (SSD), `Premium_LRS`, `UltraSSD_LRS`
- Policy Modify valida automaticamente — tags herdadas sem intervencao

## Bloco 4 - Networking (Az module)
- `New-AzVirtualNetworkSubnetConfig` + `New-AzVirtualNetwork` para VNets
- `Add-AzNetworkSecurityRuleConfig` + `Set-AzNetworkSecurityGroup` para NSG rules
- **Padrao PowerShell:** muitos cmdlets precisam de `Set-Az*` para aplicar mudancas
- `New-AzDnsZone` (publica) vs `New-AzPrivateDnsZone` (privada)
- `New-AzPrivateDnsVirtualNetworkLink` vincula VNet a zona privada

## Bloco 5 - Connectivity (Az module)
- `New-AzNetworkInterface -SubnetId $subnet.Id` referencia cross-RG pelo ID completo
- `Add-AzVirtualNetworkPeering` cria peering (precisa nos DOIS lados)
- `Invoke-AzVMRunCommand` executa scripts dentro da VM remotamente
- `New-AzRouteTable` + `Add-AzRouteConfig` para UDRs
- `Test-AzNetworkWatcherConnectivity` testa conectividade entre VMs

## Bloco 6 - Load Balancer e Bastion (Az module)
- `New-AzAvailabilitySet` com `-Sku Aligned` para managed disks
- `New-AzLoadBalancer` com configs de frontend, backend, probe e rule separados
- `New-AzLoadBalancerFrontendIpConfig` (Public IP ou Private IP)
- `New-AzLoadBalancerProbeConfig` verifica saude da APLICACAO, nao da VM
- `New-AzNetworkSecurityGroup` obrigatorio para Standard LB (bloqueia por padrao)
- `New-AzBastion` requer `AzureBastionSubnet` /26 (nome exato!)
- **Padrao PowerShell:** NIC precisa de `Set-AzNetworkInterface` para associar ao backend pool

## Bloco 7 - SSPR, Cost e Network Watcher
- `New-MgGroup` + `New-MgGroupMember` para grupo SSPR (Microsoft.Graph)
- SSPR e configuracao do portal (Entra ID > Protection > Password reset)
- Budgets alertam mas NAO param recursos — enforcement via Policy/Automation
- `Get-AzEffectiveNetworkSecurityGroup` mostra regras combinadas (subnet + NIC)
- `Test-AzNetworkWatcherIPFlow` testa pacote especifico contra NSG
- NSG inbound: subnet primeiro, depois NIC — AMBOS devem permitir

## Resumo de Cmdlets por Categoria

| Categoria | Cmdlet principal | Modulo |
|-----------|-----------------|--------|
| Usuarios | `New-MgUser` | Microsoft.Graph |
| Guests | `New-MgInvitation` | Microsoft.Graph |
| Grupos | `New-MgGroup` + `New-MgGroupMember` | Microsoft.Graph |
| RBAC | `New-AzRoleAssignment` / `New-AzRoleDefinition` | Az |
| Policy | `New-AzPolicyAssignment` | Az |
| Lock | `New-AzResourceLock` | Az |
| RG | `New-AzResourceGroup` | Az |
| MG | `New-AzManagementGroup` | Az |
| Disk | `New-AzDiskConfig` + `New-AzDisk` | Az |
| VNet | `New-AzVirtualNetwork` | Az |
| Subnet | `Add-AzVirtualNetworkSubnetConfig` + `Set-AzVirtualNetwork` | Az |
| NSG | `New-AzNetworkSecurityGroup` + `Add-AzNetworkSecurityRuleConfig` | Az |
| ASG | `New-AzApplicationSecurityGroup` | Az |
| DNS Public | `New-AzDnsZone` + `New-AzDnsRecordSet` | Az |
| DNS Private | `New-AzPrivateDnsZone` + `New-AzPrivateDnsVirtualNetworkLink` | Az |
| VM | `New-AzVMConfig` + `New-AzVM` | Az |
| NIC | `New-AzNetworkInterface` | Az |
| Peering | `Add-AzVirtualNetworkPeering` | Az |
| Route | `New-AzRouteTable` + `Add-AzRouteConfig` | Az |
| Run Command | `Invoke-AzVMRunCommand` | Az |
| Net Test | `Test-AzNetworkWatcherConnectivity` | Az |
| Availability Set | `New-AzAvailabilitySet` | Az |
| Load Balancer | `New-AzLoadBalancer` | Az |
| LB Frontend | `New-AzLoadBalancerFrontendIpConfig` | Az |
| LB Backend | `New-AzLoadBalancerBackendAddressPoolConfig` | Az |
| LB Probe | `New-AzLoadBalancerProbeConfig` | Az |
| LB Rule | `New-AzLoadBalancerRuleConfig` | Az |
| Bastion | `New-AzBastion` | Az |
| Effective NSG | `Get-AzEffectiveNetworkSecurityGroup` | Az |
| IP Flow Verify | `Test-AzNetworkWatcherIPFlow` | Az |
| Advisor | `Get-AzAdvisorRecommendation` | Az |
