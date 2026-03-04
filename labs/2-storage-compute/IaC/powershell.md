# Lab AZ-104 - Semana 2: Tudo via PowerShell

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (PowerShell)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Modulo `Az` ja vem pre-instalado
>   - Autenticacao ja esta feita (nao precisa de `Connect-AzAccount`)
>
> **Objetivo:** Reproduzir **todo** o lab unificado da Semana 2 (~45 recursos) usando exclusivamente PowerShell.
> Cada comando e fortemente comentado para aprendizado.

---

## Pre-requisitos: Cloud Shell e Conexao

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (PowerShell)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui o modulo `Az` pre-instalado e a autenticacao
> e automatica (nao precisa de `Connect-AzAccount`). Basta selecionar **PowerShell** como ambiente.

```powershell
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# 1. Verificar que esta no Cloud Shell (PowerShell)
#    O prompt deve mostrar PS /home/<usuario>>
Get-AzContext                      # Mostra subscription ativa (ja autenticado!)

# 2. Verificar versao do modulo Az
Get-Module -Name Az -ListAvailable | Select-Object Name, Version

# 3. Verificar subscription ativa
Get-AzSubscription | Select-Object Name, Id, State

# 4. Registrar providers necessarios (caso nao estejam registrados)
#    Microsoft.Storage: contas de armazenamento
#    Microsoft.Compute: VMs, VMSS, discos
#    Microsoft.Web: App Service, Web Apps
#    Microsoft.ContainerInstance: ACI
#    Microsoft.App: Container Apps
@(
    "Microsoft.Storage",
    "Microsoft.Compute",
    "Microsoft.Web",
    "Microsoft.ContainerInstance",
    "Microsoft.App"
) | ForEach-Object {
    Register-AzResourceProvider -ProviderNamespace $_ -ErrorAction SilentlyContinue
    Write-Host "Provider $_ registrado/verificado"
}
```

---

## Variaveis Globais

> **IMPORTANTE:** Ajuste os valores marcados com `# ← ALTERE` antes de executar.
> Todos os outros valores sao usados consistentemente ao longo do lab.

```powershell
# ============================================================
# VARIAVEIS GLOBAIS - Defina TODAS antes de iniciar
# ============================================================

# --- Configuracoes (ALTERE estes valores) ---
$subscriptionId = "00000000-0000-0000-0000-000000000000" # ← ALTERE
$location = "eastus"

# --- Storage (Bloco 1) ---
$rg6 = "az104-rg6"
$storageAccountName = "az104storage$(Get-Random -Minimum 1000 -Maximum 9999)" # ← nome unico
$containerName = "contoso-data"
$fileShareName = "contoso-files"

# --- VMs (Bloco 2) ---
$rg7 = "az104-rg7"
$vmWindowsName = "az104-vm-win"
$vmLinuxName = "az104-vm-linux"
$vmssName = "az104-vmss"
$vmSize = "Standard_D2s_v3"
$vmUsername = "localadmin"
$vmPassword = ConvertTo-SecureString "SenhaComplexa@2024!" -AsPlainText -Force # ← ALTERE

# --- Web Apps (Bloco 3) ---
$rg8 = "az104-rg8"
$appServicePlanName = "az104-asp"
$webAppName = "az104-webapp-$(Get-Random -Minimum 1000 -Maximum 9999)"

# --- ACI (Bloco 4) ---
$rg9 = "az104-rg9"
$aciName = "az104-aci"

# --- Container Apps (Bloco 5) ---
$rg10 = "az104-rg10"
$containerAppEnvName = "az104-cae"
$containerAppName = "az104-ca"
```

---

## Mapa de Dependencias

```
Bloco 1 (Storage)
  │
  ├─ Storage Account ($storageAccountName) ─────────────┐
  │    ├─ Blob container (contoso-data)                  │
  │    ├─ File share (contoso-files)                     │
  │    ├─ SAS Token (acesso temporario)                  │
  │    ├─ Lifecycle Policy (mover p/ Cool/Archive)       │
  │    ├─ Service Endpoint (acesso restrito via VNet)     │
  │    ├─ Private Endpoint + DNS Zone                    │
  │    └─ Firewall rules (rede restrita)                 │
  │                                                      │
  │                                                      ▼
Bloco 2 (VMs) ◄──── File Share montado na VM ───────────┘
  │
  ├─ Windows VM (az104-vm-win) ──────────────────────────┐
  │    ├─ Availability Zone 1                            │
  │    ├─ Data Disk (64GB)                               │
  │    └─ Custom Script Extension (IIS)                  │
  ├─ Linux VM (az104-vm-linux)                           │
  │    └─ SSH key authentication                         │
  ├─ VM Resize (Standard_D2s_v3 → Standard_D4s_v3)      │
  └─ VMSS (az104-vmss) com autoscale                    │
                                                         │
                                                         ▼
Bloco 3 (Web Apps) ◄──── Alternativa PaaS a VMs ────────┘
  │
  ├─ App Service Plan (az104-asp, S1)
  ├─ Web App (az104-webapp-XXXX)
  ├─ Deployment Slot (staging)
  ├─ Slot Swap (staging → production)
  ├─ Autoscale rules
  └─ App Settings (configuracao)

Bloco 4 (ACI) ◄──── Container simples
  │
  ├─ Container Group (nginx)
  ├─ Container com env vars + resource limits
  ├─ Container com Azure File Share montado
  └─ Logs do container

Bloco 5 (Container Apps) ◄──── Orquestracao serverless
  │
  ├─ Container Apps Environment
  ├─ Container App (nginx)
  ├─ Scaling rules (HTTP)
  ├─ Ingress configuration
  └─ Traffic splitting (revisions)
```

---

# Bloco 1 - Storage

**Tecnologia:** Az PowerShell module
**Recursos criados:** 1 Resource Group, 1 Storage Account, 1 Blob Container, 1 File Share, SAS Token, Lifecycle Policy, Service Endpoint, Private Endpoint, Firewall rules

> **Conceito:** O Azure Storage oferece 4 servicos: Blobs, Files, Queues e Tables.
> Neste bloco, focamos em Blobs (objetos) e Files (compartilhamento SMB/NFS).

---

### Task 1.1: Criar Resource Group e Storage Account

```powershell
# ============================================================
# TASK 1.1 - Criar Resource Group e Storage Account
# ============================================================

# Criar Resource Group para recursos de Storage
# -Tag: metadados para organizacao e billing
New-AzResourceGroup -Name $rg6 -Location $location -Tag @{ "Env" = "Lab"; "Week" = "2" }
Write-Host "Criado $rg6 em $location"

# New-AzStorageAccount: cria conta de armazenamento
# -SkuName: define redundancia
#   Standard_LRS  = Locally Redundant (3 copias no mesmo datacenter)
#   Standard_GRS  = Geo-Redundant (6 copias em 2 regioes)
#   Standard_ZRS  = Zone-Redundant (3 copias em 3 zonas)
#   Standard_RAGRS = Read-Access Geo-Redundant
# -Kind: tipo da conta
#   StorageV2 = uso geral v2 (recomendado, suporta todos os servicos)
#   BlobStorage = apenas blobs
#   BlockBlobStorage = blobs premium
# -AccessTier: tier padrao para blobs
#   Hot  = acesso frequente (custo armazenamento maior, acesso menor)
#   Cool = acesso infrequente (custo armazenamento menor, acesso maior)
# -MinimumTlsVersion: seguranca minima de transporte
# -AllowBlobPublicAccess: false = bloqueia acesso anonimo a blobs
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $rg6 `
    -Name $storageAccountName `
    -Location $location `
    -SkuName "Standard_LRS" `
    -Kind "StorageV2" `
    -AccessTier "Hot" `
    -MinimumTlsVersion "TLS1_2" `
    -AllowBlobPublicAccess $false `
    -Tag @{ "Env" = "Lab"; "Week" = "2" }

Write-Host "Storage Account criado: $storageAccountName"
Write-Host "Redundancia: Standard_LRS (3 copias locais)"
Write-Host "Access Tier: Hot"

# Obter o contexto do Storage Account (necessario para operacoes de dados)
# O contexto contem as credenciais para autenticar nas operacoes
$ctx = $storageAccount.Context

# Verificar criacao
Get-AzStorageAccount -ResourceGroupName $rg6 -Name $storageAccountName |
    Select-Object StorageAccountName, Location, Kind, AccessTier, Sku
```

> **Dica AZ-104:** O nome do Storage Account precisa ser globalmente unico, entre 3-24 caracteres,
> apenas letras minusculas e numeros. Por isso usamos `Get-Random` no nome.

---

### Task 1.2: Criar Blob Container e fazer upload

```powershell
# ============================================================
# TASK 1.2 - Criar Blob Container e upload de arquivo
# ============================================================

# New-AzStorageContainer: cria container dentro do Storage Account
# Containers organizam blobs (como pastas de primeiro nivel)
# -Permission: nivel de acesso publico
#   Off       = sem acesso publico (requer autenticacao, recomendado)
#   Blob      = leitura publica apenas para blobs individuais
#   Container = leitura publica para o container inteiro
New-AzStorageContainer `
    -Name $containerName `
    -Context $ctx `
    -Permission Off

Write-Host "Container criado: $containerName (acesso privado)"

# Criar um arquivo de teste localmente
$testContent = "Arquivo de teste para o lab AZ-104 - Semana 2"
$testFilePath = "$env:HOME/test-upload.txt"
Set-Content -Path $testFilePath -Value $testContent

# Set-AzStorageBlobContent: faz upload de arquivo para o container
# -File: caminho local do arquivo
# -Container: nome do container destino
# -Blob: nome do blob no Azure (pode ser diferente do arquivo local)
# -BlobType: Block (padrao, ate 4.75TB), Append (logs), Page (VHDs)
# -StandardBlobTier: tier do blob individual
#   Hot  = acesso frequente
#   Cool = acesso infrequente (min 30 dias)
#   Cold = acesso raro (min 90 dias)
#   Archive = acesso raríssimo (min 180 dias, rehydrate lento)
Set-AzStorageBlobContent `
    -File $testFilePath `
    -Container $containerName `
    -Blob "reports/test-upload.txt" `
    -Context $ctx `
    -BlobType Block `
    -StandardBlobTier Hot

Write-Host "Arquivo enviado para $containerName/reports/test-upload.txt"

# Listar blobs no container
Get-AzStorageBlob -Container $containerName -Context $ctx |
    Select-Object Name, Length, BlobType, AccessTier

# Download do blob para verificar
$downloadPath = "$env:HOME/test-download.txt"
Get-AzStorageBlobContent `
    -Container $containerName `
    -Blob "reports/test-upload.txt" `
    -Destination $downloadPath `
    -Context $ctx `
    -Force

Write-Host "Download concluido em: $downloadPath"
Get-Content $downloadPath
```

> **Conceito:** Blobs sao organizados em hierarquia plana com prefixos (ex: `reports/test.txt`).
> Nao existem "pastas" reais — o `/` e apenas parte do nome do blob.

---

### Task 1.3: Criar Azure File Share

```powershell
# ============================================================
# TASK 1.3 - Criar Azure File Share
# ============================================================

# New-AzRmStorageShare: cria compartilhamento de arquivos (SMB/NFS)
# Azure Files fornece file shares gerenciados na nuvem
# -QuotaGiB: tamanho maximo em GiB (padrao 5120 GiB = 5 TiB)
# -AccessTier:
#   TransactionOptimized = workloads transacionais (padrao)
#   Hot  = uso geral com acesso frequente
#   Cool = armazenamento economico
New-AzRmStorageShare `
    -ResourceGroupName $rg6 `
    -StorageAccountName $storageAccountName `
    -Name $fileShareName `
    -QuotaGiB 5 `
    -AccessTier "TransactionOptimized"

Write-Host "File Share criado: $fileShareName (5 GiB, Transaction Optimized)"

# Criar um diretorio dentro do File Share
New-AzStorageDirectory `
    -ShareName $fileShareName `
    -Path "documents" `
    -Context $ctx

Write-Host "Diretorio 'documents' criado no File Share"

# Upload de arquivo para o File Share
$testFileShareContent = "Arquivo no Azure File Share - Lab AZ-104"
$testFileSharePath = "$env:HOME/fileshare-test.txt"
Set-Content -Path $testFileSharePath -Value $testFileShareContent

Set-AzStorageFileContent `
    -ShareName $fileShareName `
    -Source $testFileSharePath `
    -Path "documents/fileshare-test.txt" `
    -Context $ctx

Write-Host "Arquivo enviado para $fileShareName/documents/fileshare-test.txt"

# Listar conteudo do File Share
Get-AzStorageFile -ShareName $fileShareName -Context $ctx | Get-AzStorageFile

# Obter a connection string (necessaria para montar em VMs no Bloco 2)
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $rg6 -Name $storageAccountName)[0].Value
Write-Host "`n=== SALVE PARA O BLOCO 2 ===" -ForegroundColor Yellow
Write-Host "Storage Account: $storageAccountName"
Write-Host "File Share: $fileShareName"
Write-Host "Storage Key: $storageKey"
Write-Host "=============================" -ForegroundColor Yellow
```

> **Dica AZ-104:** Azure Files suporta SMB 3.0+ (Windows/Linux/macOS) e NFS 4.1 (Linux).
> Para montar em VMs, precisa da porta 445 (SMB) aberta. Muitos ISPs bloqueiam!

---

### Task 1.4: Gerar SAS Token

```powershell
# ============================================================
# TASK 1.4 - Gerar Shared Access Signature (SAS) Token
# ============================================================

# SAS Token: concede acesso temporario e limitado ao Storage Account
# Tipos de SAS:
#   Account SAS: acesso a multiplos servicos (Blob, File, Queue, Table)
#   Service SAS: acesso a um servico especifico
#   User Delegation SAS: usa credenciais do Entra ID (mais seguro)

# New-AzStorageAccountSASToken: gera Account SAS
# -Service: quais servicos (b=Blob, f=File, q=Queue, t=Table)
# -ResourceType: quais recursos (s=Service, c=Container, o=Object)
# -Permission: quais operacoes (r=Read, w=Write, d=Delete, l=List, a=Add, c=Create, u=Update, p=Process)
# -ExpiryTime: quando expira (SEMPRE defina um tempo curto!)
# -Protocol: HttpsOnly = nao permite HTTP sem criptografia
$sasToken = New-AzStorageAccountSASToken `
    -Context $ctx `
    -Service Blob,File `
    -ResourceType Container,Object `
    -Permission "rl" `
    -ExpiryTime (Get-Date).AddHours(2) `
    -Protocol HttpsOnly

Write-Host "SAS Token gerado (valido por 2 horas):"
Write-Host $sasToken

# Construir URL de acesso direto ao blob via SAS
$blobUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/reports/test-upload.txt$sasToken"
Write-Host "`nURL de acesso direto ao blob:"
Write-Host $blobUrl
Write-Host "`nTeste no navegador: cole esta URL para baixar o arquivo"

# Verificar validade do SAS Token
# O token contem: sv (versao), ss (servicos), srt (resource types),
# sp (permissoes), se (expiry), spr (protocol), sig (assinatura)
Write-Host "`n=== Componentes do SAS Token ===" -ForegroundColor Cyan
Write-Host "sv  = Storage service version"
Write-Host "ss  = Services (b=blob, f=file)"
Write-Host "srt = Resource types (c=container, o=object)"
Write-Host "sp  = Permissions (r=read, l=list)"
Write-Host "se  = Expiry time"
Write-Host "spr = Protocol (https)"
Write-Host "sig = Signature (assinatura criptografica)"
```

> **Conceito:** SAS Tokens sao a forma mais comum de conceder acesso temporario.
> NUNCA use SAS com permissao ampla ou validade longa em producao.
> Prefira User Delegation SAS (baseado em Entra ID) quando possivel.

---

### Task 1.5: Configurar Lifecycle Management Policy

```powershell
# ============================================================
# TASK 1.5 - Criar Lifecycle Management Policy
# ============================================================

# Lifecycle policies automatizam a movimentacao de blobs entre tiers
# baseando-se na idade (dias desde ultima modificacao/acesso)
# Isso reduz custos movendo dados antigos para tiers mais baratos

# Definir as regras como hashtable
# Regra 1: Mover blobs para Cool apos 30 dias
# Regra 2: Mover blobs para Archive apos 90 dias
# Regra 3: Deletar blobs apos 365 dias
# Regra 4: Deletar snapshots apos 90 dias

$rule1 = New-AzStorageAccountManagementPolicyRule `
    -Name "MoveToCoolAfter30Days" `
    -Enabled `
    -Action (
        New-AzStorageAccountManagementPolicyAction `
            -BaseBlobAction TierToCool `
            -DaysAfterModificationGreaterThan 30
    ) `
    -Filter (
        New-AzStorageAccountManagementPolicyFilter `
            -BlobType blockBlob
    )

$rule2 = New-AzStorageAccountManagementPolicyRule `
    -Name "MoveToArchiveAfter90Days" `
    -Enabled `
    -Action (
        New-AzStorageAccountManagementPolicyAction `
            -BaseBlobAction TierToArchive `
            -DaysAfterModificationGreaterThan 90
    ) `
    -Filter (
        New-AzStorageAccountManagementPolicyFilter `
            -BlobType blockBlob
    )

$rule3 = New-AzStorageAccountManagementPolicyRule `
    -Name "DeleteAfter365Days" `
    -Enabled `
    -Action (
        New-AzStorageAccountManagementPolicyAction `
            -BaseBlobAction Delete `
            -DaysAfterModificationGreaterThan 365
    ) `
    -Filter (
        New-AzStorageAccountManagementPolicyFilter `
            -BlobType blockBlob
    )

$rule4 = New-AzStorageAccountManagementPolicyRule `
    -Name "DeleteSnapshotsAfter90Days" `
    -Enabled `
    -Action (
        New-AzStorageAccountManagementPolicyAction `
            -SnapshotAction Delete `
            -DaysAfterCreationGreaterThan 90
    ) `
    -Filter (
        New-AzStorageAccountManagementPolicyFilter `
            -BlobType blockBlob
    )

# Set-AzStorageAccountManagementPolicy: aplica as regras ao Storage Account
Set-AzStorageAccountManagementPolicy `
    -ResourceGroupName $rg6 `
    -StorageAccountName $storageAccountName `
    -Rule $rule1, $rule2, $rule3, $rule4

Write-Host "Lifecycle Policy aplicada com 4 regras:"
Write-Host "  1. Blobs → Cool apos 30 dias"
Write-Host "  2. Blobs → Archive apos 90 dias"
Write-Host "  3. Blobs deletados apos 365 dias"
Write-Host "  4. Snapshots deletados apos 90 dias"

# Verificar policy aplicada
Get-AzStorageAccountManagementPolicy `
    -ResourceGroupName $rg6 `
    -StorageAccountName $storageAccountName |
    Select-Object -ExpandProperty Rules |
    Select-Object Name, Enabled
```

> **Dica AZ-104:** Lifecycle policies rodam uma vez por dia (nao em tempo real).
> A transicao Hot → Cool tem custo de escrita; Cool → Archive tem custo de rehydrate.
> Archive requer "rehydrate" (ate 15 horas com Standard priority).

---

### Task 1.6: Configurar Service Endpoint

```powershell
# ============================================================
# TASK 1.6 - Configurar Service Endpoint para Storage
# ============================================================

# Service Endpoint: roteia o trafego de uma subnet diretamente para o
# servico Azure via backbone da Microsoft (nao passa pela internet publica)
# O IP de origem continua sendo o IP privado da VM

# Criar VNet e subnet para o lab (sera usada nos Blocos 2-5 tambem)
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name "default" `
    -AddressPrefix "10.0.0.0/24" `
    -ServiceEndpoint "Microsoft.Storage"     # ← Habilita Service Endpoint para Storage

$vnet = New-AzVirtualNetwork `
    -ResourceGroupName $rg6 `
    -Name "az104-vnet-storage" `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnetConfig

Write-Host "VNet criada com Service Endpoint para Microsoft.Storage"

# Obter a subnet com Service Endpoint habilitado
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "default" -VirtualNetwork $vnet
Write-Host "Service Endpoints habilitados na subnet:"
$subnet.ServiceEndpoints | ForEach-Object { Write-Host "  - $($_.Service)" }

# Aplicar Network Rule no Storage Account para restringir acesso
# Apenas trafego vindo desta subnet sera permitido
# Update-AzStorageAccountNetworkRuleSet: configura firewall do Storage
# -DefaultAction Deny: bloqueia todo trafego por padrao
# -VirtualNetworkRule: permite acesso de subnets especificas
$subnetId = $subnet.Id
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName $rg6 `
    -Name $storageAccountName `
    -DefaultAction Deny `
    -VirtualNetworkRule @(@{
        VirtualNetworkResourceId = $subnetId
        Action                   = "Allow"
    })

Write-Host "`nFirewall configurado:"
Write-Host "  Default Action: Deny"
Write-Host "  Subnet permitida: $($subnet.Name) (com Service Endpoint)"
```

> **Conceito:** Service Endpoint vs Private Endpoint:
> - Service Endpoint: trafego via backbone Azure, IP de origem = privado, endpoint publico
> - Private Endpoint: IP privado na sua VNet, endpoint privado (mais seguro)
> Na prova, saiba quando usar cada um!

---

### Task 1.7: Configurar Private Endpoint

> **Cobranca:** Private Endpoints geram cobranca enquanto existirem.

```powershell
# ============================================================
# TASK 1.7 - Criar Private Endpoint para Storage Account
# ============================================================

# Private Endpoint: cria uma NIC com IP privado na sua VNet
# que se conecta ao servico Azure. O trafego NUNCA sai da sua rede.
# Mais seguro que Service Endpoint (IP completamente privado)

# Criar subnet dedicada para Private Endpoints
# Private Endpoints precisam de subnet propria (boa pratica)
$vnet = Get-AzVirtualNetwork -Name "az104-vnet-storage" -ResourceGroupName $rg6

Add-AzVirtualNetworkSubnetConfig `
    -Name "private-endpoints" `
    -AddressPrefix "10.0.1.0/24" `
    -VirtualNetwork $vnet

# Aplicar a mudanca na VNet (padrao PowerShell: Set-Az* para persistir)
$vnet | Set-AzVirtualNetwork
$vnet = Get-AzVirtualNetwork -Name "az104-vnet-storage" -ResourceGroupName $rg6

Write-Host "Subnet 'private-endpoints' criada"

# Obter o ID do Storage Account para o Private Link Service Connection
$storageAccountId = (Get-AzStorageAccount -ResourceGroupName $rg6 -Name $storageAccountName).Id

# Criar Private Link Service Connection
# -GroupId: qual sub-recurso expor (blob, file, table, queue, web, dfs)
$privateLinkConnection = New-AzPrivateLinkServiceConnection `
    -Name "plsc-storage-blob" `
    -PrivateLinkServiceId $storageAccountId `
    -GroupId "blob"

# Obter a subnet para Private Endpoints
$peSubnet = Get-AzVirtualNetworkSubnetConfig -Name "private-endpoints" -VirtualNetwork $vnet

# Criar o Private Endpoint
# -PrivateLinkServiceConnection: define qual servico conectar
# -Subnet: onde criar a NIC com IP privado
$privateEndpoint = New-AzPrivateEndpoint `
    -ResourceGroupName $rg6 `
    -Name "pe-storage-blob" `
    -Location $location `
    -Subnet $peSubnet `
    -PrivateLinkServiceConnection $privateLinkConnection

Write-Host "Private Endpoint criado: pe-storage-blob"
Write-Host "IP Privado: $($privateEndpoint.CustomDnsConfigs[0].IpAddresses[0])"

# ============================================================
# Configurar Private DNS Zone para resolucao de nomes
# ============================================================

# Sem DNS privado, o nome "storageaccount.blob.core.windows.net"
# resolve para o IP publico. Com Private DNS Zone, resolve para o IP privado.

# Criar Private DNS Zone para blob storage
# O nome DEVE seguir o padrao: privatelink.<service>.core.windows.net
$privateDnsZone = New-AzPrivateDnsZone `
    -ResourceGroupName $rg6 `
    -Name "privatelink.blob.core.windows.net"

Write-Host "Private DNS Zone criada: privatelink.blob.core.windows.net"

# Vincular a DNS Zone a VNet (para que VMs na VNet resolvam o nome)
New-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $rg6 `
    -ZoneName "privatelink.blob.core.windows.net" `
    -Name "link-vnet-storage" `
    -VirtualNetworkId $vnet.Id `
    -EnableRegistration:$false

Write-Host "DNS Zone vinculada a VNet az104-vnet-storage"

# Criar registro DNS para o Private Endpoint
# Mapeia: storageaccount.privatelink.blob.core.windows.net → IP privado
$peIp = $privateEndpoint.CustomDnsConfigs[0].IpAddresses[0]

$dnsConfig = New-AzPrivateDnsZoneConfig `
    -Name "privatelink.blob.core.windows.net" `
    -PrivateDnsZoneId $privateDnsZone.ResourceId

New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $rg6 `
    -PrivateEndpointName "pe-storage-blob" `
    -Name "default" `
    -PrivateDnsZoneConfig $dnsConfig

Write-Host "`nResolucao DNS configurada:"
Write-Host "  $storageAccountName.blob.core.windows.net → $peIp (privado)"
```

> **Gotcha:** Private Endpoint + Private DNS Zone = acesso totalmente privado.
> Sem a DNS Zone, o nome ainda resolve para o IP publico e o trafego nao usa o PE.

---

### Task 1.8: Configurar Firewall (Network Rules)

```powershell
# ============================================================
# TASK 1.8 - Configurar Firewall do Storage Account
# ============================================================

# O firewall do Storage Account controla QUEM pode acessar os dados
# Ja configuramos regra de VNet na Task 1.6
# Agora vamos adicionar regra de IP e bypass para servicos Azure

# Adicionar seu IP publico atual a lista de permitidos
# Isso permite acessar o Storage Account do Cloud Shell/navegador
$myIP = (Invoke-RestMethod -Uri "https://ifconfig.me/ip" -TimeoutSec 10)
Write-Host "Seu IP publico: $myIP"

# Adicionar regra de IP ao firewall
Add-AzStorageAccountNetworkRule `
    -ResourceGroupName $rg6 `
    -Name $storageAccountName `
    -IPAddressOrRange $myIP

Write-Host "IP $myIP adicionado as regras de firewall"

# Configurar bypass para servicos Azure confiaveis
# -Bypass: quais servicos Azure podem ignorar o firewall
#   AzureServices = servicos confiaveis (Backup, Monitor, etc.)
#   Metrics = metricas do Azure Monitor
#   Logging = diagnostics logging
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName $rg6 `
    -Name $storageAccountName `
    -Bypass AzureServices,Metrics,Logging

Write-Host "Bypass configurado para: AzureServices, Metrics, Logging"

# Verificar regras de rede
$networkRules = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $rg6 -Name $storageAccountName
Write-Host "`n=== Regras de Rede do Storage Account ===" -ForegroundColor Cyan
Write-Host "Default Action: $($networkRules.DefaultAction)"
Write-Host "Bypass: $($networkRules.Bypass)"
Write-Host "IP Rules:"
$networkRules.IpRules | ForEach-Object { Write-Host "  - $($_.IPAddressOrRange) ($($_.Action))" }
Write-Host "VNet Rules:"
$networkRules.VirtualNetworkRules | ForEach-Object { Write-Host "  - $($_.VirtualNetworkResourceId)" }
```

> **Dica AZ-104:** O bypass "AzureServices" permite que servicos como Azure Backup,
> Azure Monitor e Azure Site Recovery acessem o Storage mesmo com firewall ativo.
> Na prova, esta opcao e frequentemente a resposta correta para cenarios de backup.

---

## Modo Desafio - Bloco 1

- [ ] Criar Storage Account com LRS, Hot tier, TLS 1.2 e sem acesso publico a blobs
- [ ] Criar Blob Container privado e fazer upload de arquivo
- [ ] Criar File Share com 5 GiB e tier Transaction Optimized
- [ ] Gerar SAS Token com permissao read+list, valido por 2 horas, HTTPS only
- [ ] Configurar Lifecycle Policy com 4 regras (Cool 30d, Archive 90d, Delete 365d, Snapshots 90d)
- [ ] Habilitar Service Endpoint na subnet e restringir acesso via firewall
- [ ] Criar Private Endpoint com Private DNS Zone para blob
- [ ] Adicionar regra de IP e bypass para servicos Azure no firewall

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Voce precisa garantir que blobs nao acessados ha mais de 90 dias sejam movidos automaticamente para um tier mais barato. Qual recurso voce deve configurar?**

A) Azure Policy
B) Storage Account Firewall
C) Lifecycle Management Policy
D) Blob Versioning

<details>
<summary>Ver resposta</summary>

**Resposta: C) Lifecycle Management Policy**

Lifecycle Management policies permitem definir regras para mover blobs entre tiers (Hot → Cool → Archive) ou deletar baseado na idade. Roda automaticamente uma vez por dia.

</details>

### Questao 1.2
**Sua empresa exige que o trafego para o Storage Account nunca passe pela internet publica. Qual recurso voce deve usar?**

A) Service Endpoint
B) Private Endpoint
C) Storage Account Firewall com IP rules
D) SAS Token com restricao de IP

<details>
<summary>Ver resposta</summary>

**Resposta: B) Private Endpoint**

Private Endpoint cria um IP privado na sua VNet, garantindo que o trafego fique inteiramente dentro da rede Microsoft. Service Endpoint roteia pelo backbone mas o endpoint ainda e publico.

</details>

### Questao 1.3
**Voce gerou um SAS Token para um container de blobs. Um desenvolvedor reporta que nao consegue listar os blobs, mas consegue ler um blob especifico pelo nome. Qual e a causa mais provavel?**

A) O SAS Token expirou
B) O SAS Token nao inclui a permissao List (l)
C) O container esta configurado como Private
D) O firewall esta bloqueando o acesso

<details>
<summary>Ver resposta</summary>

**Resposta: B) O SAS Token nao inclui a permissao List (l)**

Cada operacao requer permissao especifica no SAS Token. Read (r) permite ler blobs pelo nome, mas List (l) e necessario para enumerar blobs no container.

</details>

### Questao 1.4
**Voce configurou o firewall do Storage Account com Default Action = Deny. O Azure Backup para de funcionar. Como resolver sem abrir para todos?**

A) Adicionar o IP do Azure Backup ao firewall
B) Habilitar "Allow trusted Microsoft services to access this storage account"
C) Criar um Private Endpoint para o Azure Backup
D) Desabilitar o firewall temporariamente

<details>
<summary>Ver resposta</summary>

**Resposta: B) Habilitar "Allow trusted Microsoft services to access this storage account"**

O bypass "AzureServices" (ou "trusted Microsoft services" no portal) permite que servicos confiaveis como Azure Backup acessem o Storage mesmo com firewall ativo. Em PowerShell: `-Bypass AzureServices`.

</details>

---

# Bloco 2 - Virtual Machines

**Tecnologia:** Az PowerShell module
**Recursos criados:** 1 Resource Group, 1 VM Windows, 1 VM Linux, Data Disk, Custom Script Extension, 1 VMSS com autoscale

> **Conceito:** Azure VMs sao o servico IaaS fundamental. Voce controla o SO, middleware e aplicacoes.
> VMs podem ser Windows ou Linux, e existem centenas de tamanhos (series B, D, E, F, etc.).

---

### Task 2.1: Criar Resource Group para VMs

```powershell
# ============================================================
# TASK 2.1 - Criar Resource Group para VMs
# ============================================================

New-AzResourceGroup -Name $rg7 -Location $location -Tag @{ "Env" = "Lab"; "Week" = "2" }
Write-Host "Criado $rg7 em $location"
```

---

### Task 2.2: Criar VM Windows em Availability Zone

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

```powershell
# ============================================================
# TASK 2.2 - Criar VM Windows com Availability Zone
# ============================================================

# Criar credenciais para a VM
$vmCredential = New-Object System.Management.Automation.PSCredential($vmUsername, $vmPassword)

# Criar Public IP para acesso RDP
# -Sku Standard: obrigatorio para VMs em Availability Zones
# -AllocationMethod Static: IP fixo (Standard sempre e Static)
# -Zone: deve ser a mesma zona da VM
$publicIpWin = New-AzPublicIpAddress `
    -ResourceGroupName $rg7 `
    -Name "$vmWindowsName-pip" `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 1

Write-Host "Public IP criado: $($publicIpWin.IpAddress)"

# Criar NSG com regra para RDP (porta 3389)
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
    -Name "AllowRDP" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 3389 `
    -Access Allow

$nsgWin = New-AzNetworkSecurityGroup `
    -ResourceGroupName $rg7 `
    -Name "$vmWindowsName-nsg" `
    -Location $location `
    -SecurityRules $nsgRuleRDP

# Criar subnet e VNet para as VMs (ou reusar do Bloco 1)
$subnetVm = New-AzVirtualNetworkSubnetConfig `
    -Name "vm-subnet" `
    -AddressPrefix "10.1.0.0/24" `
    -NetworkSecurityGroup $nsgWin

$vnetVm = New-AzVirtualNetwork `
    -ResourceGroupName $rg7 `
    -Name "az104-vnet-vm" `
    -Location $location `
    -AddressPrefix "10.1.0.0/16" `
    -Subnet $subnetVm

# Obter a subnet
$subnetRef = Get-AzVirtualNetworkSubnetConfig -Name "vm-subnet" -VirtualNetwork $vnetVm

# Criar NIC com Public IP
$nicWin = New-AzNetworkInterface `
    -ResourceGroupName $rg7 `
    -Name "$vmWindowsName-nic" `
    -Location $location `
    -SubnetId $subnetRef.Id `
    -PublicIpAddressId $publicIpWin.Id `
    -NetworkSecurityGroupId $nsgWin.Id

# New-AzVMConfig: cria configuracao da VM (objeto local, nao cria no Azure)
# -VMSize: tamanho da VM (vCPUs, RAM, IOPS)
#   Standard_D2s_v3 = 2 vCPUs, 8 GB RAM, SSD temporario
# -Zone: coloca a VM em uma Availability Zone especifica (1, 2 ou 3)
#   Zones protegem contra falhas de datacenter inteiro
$vmConfig = New-AzVMConfig `
    -VMName $vmWindowsName `
    -VMSize $vmSize `
    -Zone 1

# Configurar SO Windows
# -Windows: tipo de SO
# -ComputerName: nome do hostname interno (max 15 chars para Windows)
# -Credential: usuario e senha do SO
# -ProvisionVMAgent: instala agente que permite extensoes
# -EnableAutoUpdate: habilita Windows Update
$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Windows `
    -ComputerName "az104win" `
    -Credential $vmCredential `
    -ProvisionVMAgent `
    -EnableAutoUpdate

# Definir imagem do SO
# Formato: Publisher:Offer:SKU:Version
# MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest
$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2022-datacenter-g2" `
    -Version "latest"

# Configurar disco de SO (Managed Disk)
$vmConfig = Set-AzVMOSDisk `
    -VM $vmConfig `
    -CreateOption FromImage `
    -StorageAccountType "Premium_LRS" `
    -Name "$vmWindowsName-osdisk"

# Anexar NIC a VM
$vmConfig = Add-AzVMNetworkInterface `
    -VM $vmConfig `
    -Id $nicWin.Id

# Desabilitar diagnostico de boot (simplifica o lab)
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

# New-AzVM: cria a VM no Azure (operacao longa, ~3-5 minutos)
New-AzVM `
    -ResourceGroupName $rg7 `
    -Location $location `
    -VM $vmConfig

Write-Host "`nVM Windows criada: $vmWindowsName"
Write-Host "  Zona: 1"
Write-Host "  Tamanho: $vmSize"
Write-Host "  IP Publico: $($publicIpWin.IpAddress)"
Write-Host "  RDP: mstsc /v:$($publicIpWin.IpAddress)"

# Verificar status da VM
Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName -Status |
    Select-Object Name, @{n='Status';e={$_.Statuses[1].DisplayStatus}}, Location
```

> **Dica AZ-104:** Availability Zones protegem contra falhas de datacenter.
> Availability Sets protegem contra falhas de hardware dentro de um datacenter.
> Na prova, Zones oferecem SLA de 99.99%, Sets oferecem 99.95%.

---

### Task 2.3: Criar VM Linux com SSH Key

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab.

```powershell
# ============================================================
# TASK 2.3 - Criar VM Linux com autenticacao SSH
# ============================================================

# Gerar par de chaves SSH (se nao existir)
# Cloud Shell ja pode ter chave em ~/.ssh/id_rsa
if (-not (Test-Path "$env:HOME/.ssh/id_rsa")) {
    ssh-keygen -t rsa -b 4096 -f "$env:HOME/.ssh/id_rsa" -N '""'
    Write-Host "Par de chaves SSH gerado"
}

$sshPublicKey = Get-Content "$env:HOME/.ssh/id_rsa.pub"
Write-Host "SSH Public Key: $($sshPublicKey.Substring(0, 50))..."

# Criar Public IP para SSH
$publicIpLinux = New-AzPublicIpAddress `
    -ResourceGroupName $rg7 `
    -Name "$vmLinuxName-pip" `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 2                      # Zona diferente da VM Windows

# Criar NSG com regra SSH (porta 22)
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "AllowSSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsgLinux = New-AzNetworkSecurityGroup `
    -ResourceGroupName $rg7 `
    -Name "$vmLinuxName-nsg" `
    -Location $location `
    -SecurityRules $nsgRuleSSH

# Criar NIC para VM Linux
# Reutilizando a mesma VNet do Bloco 2
$vnetVm = Get-AzVirtualNetwork -Name "az104-vnet-vm" -ResourceGroupName $rg7
$subnetRef = Get-AzVirtualNetworkSubnetConfig -Name "vm-subnet" -VirtualNetwork $vnetVm

$nicLinux = New-AzNetworkInterface `
    -ResourceGroupName $rg7 `
    -Name "$vmLinuxName-nic" `
    -Location $location `
    -SubnetId $subnetRef.Id `
    -PublicIpAddressId $publicIpLinux.Id `
    -NetworkSecurityGroupId $nsgLinux.Id

# Configurar VM Linux
$vmLinuxConfig = New-AzVMConfig `
    -VMName $vmLinuxName `
    -VMSize $vmSize `
    -Zone 2                      # Zona 2 (diferente do Windows na Zona 1)

# Configurar SO Linux com autenticacao SSH (sem senha)
# -DisablePasswordAuthentication: forca uso de SSH key
$vmLinuxConfig = Set-AzVMOperatingSystem `
    -VM $vmLinuxConfig `
    -Linux `
    -ComputerName "az104linux" `
    -Credential $vmCredential `
    -DisablePasswordAuthentication

# Adicionar SSH key
# -KeyData: conteudo da chave publica SSH
Add-AzVMSshPublicKey `
    -VM $vmLinuxConfig `
    -KeyData $sshPublicKey `
    -Path "/home/$vmUsername/.ssh/authorized_keys"

# Imagem Ubuntu 22.04 LTS
$vmLinuxConfig = Set-AzVMSourceImage `
    -VM $vmLinuxConfig `
    -PublisherName "Canonical" `
    -Offer "0001-com-ubuntu-server-jammy" `
    -Skus "22_04-lts-gen2" `
    -Version "latest"

# Disco de SO
$vmLinuxConfig = Set-AzVMOSDisk `
    -VM $vmLinuxConfig `
    -CreateOption FromImage `
    -StorageAccountType "Premium_LRS" `
    -Name "$vmLinuxName-osdisk"

# Anexar NIC
$vmLinuxConfig = Add-AzVMNetworkInterface `
    -VM $vmLinuxConfig `
    -Id $nicLinux.Id

# Desabilitar boot diagnostics
$vmLinuxConfig = Set-AzVMBootDiagnostic -VM $vmLinuxConfig -Disable

# Criar VM
New-AzVM `
    -ResourceGroupName $rg7 `
    -Location $location `
    -VM $vmLinuxConfig

Write-Host "`nVM Linux criada: $vmLinuxName"
Write-Host "  Zona: 2"
Write-Host "  Tamanho: $vmSize"
Write-Host "  IP Publico: $($publicIpLinux.IpAddress)"
Write-Host "  SSH: ssh $vmUsername@$($publicIpLinux.IpAddress)"
```

> **Conceito:** Autenticacao SSH e mais segura que senha para VMs Linux.
> Na prova, `DisablePasswordAuthentication` + SSH key e a pratica recomendada.

---

### Task 2.4: Redimensionar VM (Resize)

```powershell
# ============================================================
# TASK 2.4 - Redimensionar VM (Scale Up/Down)
# ============================================================

# Listar tamanhos disponiveis na regiao/zona
# Nem todos os tamanhos estao disponiveis em todas as zonas
Get-AzVMSize -Location $location |
    Where-Object { $_.Name -like "Standard_D*s_v3" } |
    Select-Object Name, NumberOfCores, MemoryInMB |
    Format-Table -AutoSize

# Redimensionar: Standard_D2s_v3 → Standard_D4s_v3
# ATENCAO: a VM sera REINICIADA durante o resize
$vmWin = Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName
$vmWin.HardwareProfile.VmSize = "Standard_D4s_v3"

# Update-AzVM: aplica mudancas na VM (resize requer reinicio)
Update-AzVM -ResourceGroupName $rg7 -VM $vmWin

Write-Host "VM redimensionada para Standard_D4s_v3 (4 vCPUs, 16 GB RAM)"

# Verificar novo tamanho
Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName |
    Select-Object Name, @{n='Size';e={$_.HardwareProfile.VmSize}}

# Voltar ao tamanho original (economizar)
$vmWin = Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName
$vmWin.HardwareProfile.VmSize = $vmSize
Update-AzVM -ResourceGroupName $rg7 -VM $vmWin
Write-Host "VM redimensionada de volta para $vmSize"
```

> **Dica AZ-104:** O resize pode exigir deallocation se o novo tamanho nao estiver
> disponivel no cluster atual. `Stop-AzVM -Force` dealloca a VM.

---

### Task 2.5: Adicionar Data Disk

```powershell
# ============================================================
# TASK 2.5 - Adicionar Data Disk a VM Windows
# ============================================================

# Criar Managed Disk separado
# -CreateOption Empty: disco vazio (alternativas: Copy, FromImage, Upload)
# -DiskSizeGB: tamanho em GB
# -SkuName: tipo de disco
#   Premium_LRS    = SSD Premium (recomendado para producao)
#   StandardSSD_LRS = SSD Standard (custo intermediario)
#   Standard_LRS   = HDD Standard (mais barato, menor IOPS)
#   UltraSSD_LRS   = Ultra SSD (altissimo IOPS, requer config especial)
# -Zone: DEVE ser a mesma zona da VM
$diskConfig = New-AzDiskConfig `
    -Location $location `
    -CreateOption Empty `
    -DiskSizeGB 64 `
    -SkuName "Premium_LRS" `
    -Zone 1                  # Mesma zona da VM Windows

$dataDisk = New-AzDisk `
    -ResourceGroupName $rg7 `
    -DiskName "$vmWindowsName-datadisk1" `
    -Disk $diskConfig

Write-Host "Data Disk criado: $($dataDisk.Name) (64 GB, Premium SSD)"

# Anexar o disco a VM
# -Lun: Logical Unit Number (identificador unico do disco na VM, 0-63)
# -ManagedDiskId: ID do Managed Disk
# -Caching: como o host cacheia operacoes de disco
#   None: sem cache (recomendado para write-heavy)
#   ReadOnly: cache de leitura (recomendado para data disks de leitura)
#   ReadWrite: cache de leitura e escrita (apenas para OS disk)
$vmWin = Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName

Add-AzVMDataDisk `
    -VM $vmWin `
    -Name "$vmWindowsName-datadisk1" `
    -ManagedDiskId $dataDisk.Id `
    -Lun 0 `
    -Caching ReadOnly `
    -CreateOption Attach

# Aplicar mudanca (nao requer reinicio para attach de disco)
Update-AzVM -ResourceGroupName $rg7 -VM $vmWin

Write-Host "Data Disk anexado a VM $vmWindowsName (LUN 0)"

# Verificar discos da VM
Get-AzVM -ResourceGroupName $rg7 -Name $vmWindowsName |
    Select-Object -ExpandProperty StorageProfile |
    Select-Object -ExpandProperty DataDisks |
    Select-Object Name, Lun, DiskSizeGB, Caching, ManagedDisk
```

> **Conceito:** Data Disks sao adicionados via LUN (0-63). O OS Disk e separado.
> Cada tamanho de VM tem limite de discos (ex: Standard_D2s_v3 suporta ate 4 data disks).

---

### Task 2.6: Custom Script Extension (Instalar IIS)

```powershell
# ============================================================
# TASK 2.6 - Instalar IIS via Custom Script Extension
# ============================================================

# Custom Script Extension: executa scripts dentro da VM automaticamente
# Util para configuracao pos-deploy (instalar software, configurar servicos)
# O script roda com privilegios de SYSTEM/root

# Set-AzVMCustomScriptExtension: configura extensao de script
# -Run: nome do script a executar
# -CommandToExecute: comando inline (alternativa ao script em arquivo)
# Para IIS, usamos o comando PowerShell Install-WindowsFeature
Set-AzVMCustomScriptExtension `
    -ResourceGroupName $rg7 `
    -VMName $vmWindowsName `
    -Name "InstallIIS" `
    -Location $location `
    -CommandToExecute 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path C:\inetpub\wwwroot\index.html -Value \"Hello from $env:COMPUTERNAME - AZ-104 Lab\""'

Write-Host "Custom Script Extension executada: IIS instalado"

# Verificar extensoes instaladas na VM
Get-AzVMExtension -ResourceGroupName $rg7 -VMName $vmWindowsName |
    Select-Object Name, Publisher, ExtensionType, ProvisioningState

# Testar IIS (se tiver NSG aberta na porta 80)
# Primeiro, adicionar regra HTTP na NSG
$nsgWin = Get-AzNetworkSecurityGroup -ResourceGroupName $rg7 -Name "$vmWindowsName-nsg"
Add-AzNetworkSecurityRuleConfig `
    -NetworkSecurityGroup $nsgWin `
    -Name "AllowHTTP" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1010 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 80 `
    -Access Allow

Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsgWin
Write-Host "Regra HTTP (porta 80) adicionada ao NSG"

# Testar acesso
$winPip = (Get-AzPublicIpAddress -ResourceGroupName $rg7 -Name "$vmWindowsName-pip").IpAddress
Write-Host "`nTeste no navegador: http://$winPip"
```

> **Dica AZ-104:** Custom Script Extension e a forma mais testada na prova para
> configuracao pos-deploy. Alternativas: cloud-init (Linux), Run Command, DSC Extension.

---

### Task 2.6b: Cloud-init (Custom Data) em Linux VM via PowerShell

> **Conceito AZ-104:** Cloud-init executa **apenas no 1º boot** durante o provisioning.
> No PowerShell, usa-se `-CustomData` com conteudo em base64.

```powershell
# ============================================================
# TASK 2.6b - Cloud-init: configuracao automatica no 1o boot
# ============================================================
# CONCEITO AZ-104: cloud-init e processado APENAS no primeiro boot
# Diferente de Custom Script Extension (pos-deploy) e Run Command (ad-hoc)

# Criar conteudo cloud-init
$cloudInitContent = @'
#cloud-config
package_upgrade: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <h1>Hello from cloud-init VM</h1>
      <p>Configurado automaticamente no primeiro boot via PowerShell</p>
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
'@

# Converter para base64 (requisito da API)
$cloudInitBase64 = [Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes($cloudInitContent)
)

# Criar credencial
$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("localadmin", $securePassword)

# Referenciar subnet existente
$vnet = Get-AzVirtualNetwork -Name "ManufacturingVnet" -ResourceGroupName "az104-rg4"
$subnet = $vnet.Subnets | Where-Object { $_.Name -eq "Manufacturing" }

# Criar PIP
$pip = New-AzPublicIpAddress `
    -Name "az104-vm-cloudinit-pip" `
    -ResourceGroupName $RG7 `
    -Location $Location `
    -Sku Standard `
    -AllocationMethod Static

# Criar NIC
$nic = New-AzNetworkInterface `
    -Name "az104-vm-cloudinit-nic" `
    -ResourceGroupName $RG7 `
    -Location $Location `
    -SubnetId $subnet.Id `
    -PublicIpAddressId $pip.Id

# Configurar VM
$vmConfig = New-AzVMConfig -VMName "az104-vm-cloudinit" -VMSize "Standard_B1s"

$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Linux `
    -ComputerName "az104-vm-cloudinit" `
    -Credential $cred `
    -CustomData $cloudInitBase64

$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "Canonical" `
    -Offer "0001-com-ubuntu-server-jammy" `
    -Skus "22_04-lts-gen2" `
    -Version "latest"

$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Criar VM (cloud-init executa automaticamente no 1o boot)
New-AzVM -ResourceGroupName $RG7 -Location $Location -VM $vmConfig

Write-Host "`nVM criada com cloud-init. Nginx sera instalado automaticamente."
Write-Host "IP publico: $($pip.IpAddress)"
Write-Host "Teste: curl http://$($pip.IpAddress)"

# Verificar status do cloud-init
Invoke-AzVMRunCommand `
    -ResourceGroupName $RG7 `
    -VMName "az104-vm-cloudinit" `
    -CommandId "RunShellScript" `
    -ScriptString "cloud-init status --long"
```

> **Comparacao para prova:**
> | Metodo | Cmdlet/Parametro | Quando executa | SO |
> |--------|------------------|----------------|-----|
> | **Cloud-init** | `Set-AzVMOperatingSystem -CustomData` | 1º boot | Linux |
> | **Custom Script Ext** | `Set-AzVMExtension` | Pos-deploy | Win + Linux |
> | **Run Command** | `Invoke-AzVMRunCommand` | Ad-hoc | Win + Linux |

---

### Task 2.7: Criar VMSS com Autoscale

> **Cobranca:** Cada instancia do VMSS gera cobranca. Escale para 0 ao pausar o lab.

```powershell
# ============================================================
# TASK 2.7 - Criar Virtual Machine Scale Set (VMSS) com Autoscale
# ============================================================

# VMSS: conjunto de VMs identicas que escalam automaticamente
# Diferente de VMs individuais, o VMSS gerencia o ciclo de vida

# Criar subnet dedicada para o VMSS
$vnetVm = Get-AzVirtualNetwork -Name "az104-vnet-vm" -ResourceGroupName $rg7
Add-AzVirtualNetworkSubnetConfig `
    -Name "vmss-subnet" `
    -AddressPrefix "10.1.1.0/24" `
    -VirtualNetwork $vnetVm
$vnetVm | Set-AzVirtualNetwork
$vnetVm = Get-AzVirtualNetwork -Name "az104-vnet-vm" -ResourceGroupName $rg7

# Criar Load Balancer para o VMSS
$lbPublicIp = New-AzPublicIpAddress `
    -ResourceGroupName $rg7 `
    -Name "$vmssName-lb-pip" `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static"

$frontendConfig = New-AzLoadBalancerFrontendIpConfig `
    -Name "vmss-frontend" `
    -PublicIpAddress $lbPublicIp

$backendPool = New-AzLoadBalancerBackendAddressPoolConfig `
    -Name "vmss-backend"

$healthProbe = New-AzLoadBalancerProbeConfig `
    -Name "vmss-probe" `
    -Protocol Tcp `
    -Port 80 `
    -IntervalInSeconds 15 `
    -ProbeCount 2

$lbRule = New-AzLoadBalancerRuleConfig `
    -Name "vmss-http-rule" `
    -FrontendIpConfiguration $frontendConfig `
    -BackendAddressPool $backendPool `
    -Probe $healthProbe `
    -Protocol Tcp `
    -FrontendPort 80 `
    -BackendPort 80

$loadBalancer = New-AzLoadBalancer `
    -ResourceGroupName $rg7 `
    -Name "$vmssName-lb" `
    -Location $location `
    -Sku "Standard" `
    -FrontendIpConfiguration $frontendConfig `
    -BackendAddressPool $backendPool `
    -Probe $healthProbe `
    -LoadBalancingRule $lbRule

Write-Host "Load Balancer criado: $vmssName-lb"

# Obter referencia ao backend pool
$backendPoolId = $loadBalancer.BackendAddressPools[0].Id

# Configurar IP do VMSS
$vmssSubnet = Get-AzVirtualNetworkSubnetConfig -Name "vmss-subnet" -VirtualNetwork $vnetVm

$ipConfig = New-AzVmssIpConfig `
    -Name "vmss-ipconfig" `
    -SubnetId $vmssSubnet.Id `
    -LoadBalancerBackendAddressPoolsId $backendPoolId

# Criar configuracao do VMSS
# New-AzVmssConfig: cria configuracao base
# -SkuCapacity: numero inicial de instancias
# -SkuName: tamanho de cada instancia
# -UpgradePolicyMode: como atualizar instancias
#   Manual    = voce atualiza manualmente
#   Automatic = Azure atualiza automaticamente
#   Rolling   = atualiza em lotes (min um saudavel)
$vmssConfig = New-AzVmssConfig `
    -Location $location `
    -SkuCapacity 2 `
    -SkuName "Standard_B2s" `
    -UpgradePolicyMode "Automatic" `
    -SinglePlacementGroup $true `
    -OrchestrationMode "Uniform"

# Configurar SO do VMSS
Set-AzVmssOsProfile `
    -VirtualMachineScaleSet $vmssConfig `
    -ComputerNamePrefix "vmss" `
    -AdminUsername $vmUsername `
    -AdminPassword "SenhaComplexa@2024!"

# Configurar imagem
Set-AzVmssStorageProfile `
    -VirtualMachineScaleSet $vmssConfig `
    -ImageReferencePublisher "MicrosoftWindowsServer" `
    -ImageReferenceOffer "WindowsServer" `
    -ImageReferenceSku "2022-datacenter-g2" `
    -ImageReferenceVersion "latest" `
    -OsDiskCreateOption "FromImage" `
    -OsDiskCaching "ReadWrite" `
    -ManagedDisk "Standard_LRS"

# Configurar rede do VMSS
Add-AzVmssNetworkInterfaceConfiguration `
    -VirtualMachineScaleSet $vmssConfig `
    -Name "vmss-nic" `
    -Primary $true `
    -IpConfiguration $ipConfig

# Criar VMSS
New-AzVmss `
    -ResourceGroupName $rg7 `
    -Name $vmssName `
    -VirtualMachineScaleSet $vmssConfig

Write-Host "`nVMSS criado: $vmssName"
Write-Host "  Instancias iniciais: 2"
Write-Host "  Tamanho: Standard_B2s"
Write-Host "  Upgrade Policy: Automatic"

# ============================================================
# Configurar Autoscale para o VMSS
# ============================================================

# Autoscale rules definem quando escalar (scale out/in)
# Baseado em metricas como CPU, memoria, fila, etc.

# Regra 1: Scale Out (adicionar VM) quando CPU > 70%
$ruleScaleOut = New-AzAutoscaleRuleV2 `
    -MetricTriggerMetricName "Percentage CPU" `
    -MetricTriggerMetricResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg7/providers/Microsoft.Compute/virtualMachineScaleSets/$vmssName" `
    -MetricTriggerTimeGrain ([TimeSpan]::FromMinutes(1)) `
    -MetricTriggerStatistic "Average" `
    -MetricTriggerTimeWindow ([TimeSpan]::FromMinutes(5)) `
    -MetricTriggerOperator "GreaterThan" `
    -MetricTriggerThreshold 70 `
    -ScaleActionDirection "Increase" `
    -ScaleActionType "ChangeCount" `
    -ScaleActionValue 1 `
    -ScaleActionCooldown ([TimeSpan]::FromMinutes(5))

# Regra 2: Scale In (remover VM) quando CPU < 30%
$ruleScaleIn = New-AzAutoscaleRuleV2 `
    -MetricTriggerMetricName "Percentage CPU" `
    -MetricTriggerMetricResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg7/providers/Microsoft.Compute/virtualMachineScaleSets/$vmssName" `
    -MetricTriggerTimeGrain ([TimeSpan]::FromMinutes(1)) `
    -MetricTriggerStatistic "Average" `
    -MetricTriggerTimeWindow ([TimeSpan]::FromMinutes(5)) `
    -MetricTriggerOperator "LessThan" `
    -MetricTriggerThreshold 30 `
    -ScaleActionDirection "Decrease" `
    -ScaleActionType "ChangeCount" `
    -ScaleActionValue 1 `
    -ScaleActionCooldown ([TimeSpan]::FromMinutes(5))

# Criar perfil de autoscale
$profile = New-AzAutoscaleProfileV2 `
    -Name "AutoScale-CPU" `
    -DefaultCapacity 2 `
    -MinimumCapacity 1 `
    -MaximumCapacity 5 `
    -Rule $ruleScaleOut, $ruleScaleIn

# Aplicar autoscale ao VMSS
New-AzAutoscaleSettingV2 `
    -ResourceGroupName $rg7 `
    -Name "$vmssName-autoscale" `
    -Location $location `
    -Profile $profile `
    -TargetResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg7/providers/Microsoft.Compute/virtualMachineScaleSets/$vmssName" `
    -Enabled

Write-Host "`nAutoscale configurado:"
Write-Host "  Min: 1 instancia"
Write-Host "  Max: 5 instancias"
Write-Host "  Scale Out: CPU > 70% → +1 VM"
Write-Host "  Scale In:  CPU < 30% → -1 VM"
Write-Host "  Cooldown: 5 minutos"

# Verificar VMSS
Get-AzVmss -ResourceGroupName $rg7 -VMScaleSetName $vmssName |
    Select-Object Name, @{n='Capacity';e={$_.Sku.Capacity}}, @{n='Size';e={$_.Sku.Name}}, Location
```

> **Conceito:** VMSS com autoscale e a base de escalabilidade IaaS no Azure.
> Na prova, preste atencao no cooldown period — se for muito curto, causa "flapping"
> (escalar/desescalar repetidamente). Padrao recomendado: 5 minutos.

---

## Modo Desafio - Bloco 2

- [ ] Criar VM Windows em Availability Zone 1 com Public IP Standard e NSG (RDP)
- [ ] Criar VM Linux em Availability Zone 2 com SSH key authentication
- [ ] Redimensionar VM Windows para Standard_D4s_v3 e voltar para Standard_D2s_v3
- [ ] Criar e anexar Data Disk de 64 GB (Premium SSD) na VM Windows (LUN 0)
- [ ] Instalar IIS via Custom Script Extension e abrir porta 80 no NSG
- [ ] Criar VMSS com 2 instancias iniciais, Load Balancer Standard e autoscale (CPU 30-70%)
- [ ] Verificar que VMSS tem autoscale configurado com min=1, max=5

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce precisa garantir que suas VMs continuem funcionando mesmo se um datacenter inteiro falhar. Qual recurso voce deve usar?**

A) Availability Set
B) Availability Zone
C) Scale Set
D) Proximity Placement Group

<details>
<summary>Ver resposta</summary>

**Resposta: B) Availability Zone**

Availability Zones sao datacenters fisicamente separados dentro de uma regiao Azure. Protegem contra falhas de datacenter inteiro (SLA 99.99%). Availability Sets protegem contra falhas de rack/hardware (SLA 99.95%).

</details>

### Questao 2.2
**Uma VM precisa de mais vCPUs e memoria. Voce altera o tamanho no portal mas recebe erro "AllocationFailed". Qual e a causa mais provavel?**

A) A VM esta desligada
B) O novo tamanho nao esta disponivel no cluster atual
C) O disco de SO e muito pequeno
D) A subscription atingiu o limite de cores

<details>
<summary>Ver resposta</summary>

**Resposta: B) O novo tamanho nao esta disponivel no cluster atual**

Nem todos os tamanhos estao disponiveis em todos os clusters. A solucao e desalocar a VM (`Stop-AzVM -Force`) para que o Azure possa realoca-la em outro cluster, ou escolher um tamanho disponivel no cluster atual.

</details>

### Questao 2.3
**Voce configurou autoscale no VMSS com cooldown de 1 minuto. As instancias ficam escalando e desescalando repetidamente. Como resolver?**

A) Aumentar o cooldown period
B) Reduzir o threshold de scale out
C) Aumentar o numero minimo de instancias
D) Mudar o UpgradePolicyMode para Manual

<details>
<summary>Ver resposta</summary>

**Resposta: A) Aumentar o cooldown period**

O "flapping" (oscilacao) ocorre quando o cooldown e muito curto. Aumente para 5-10 minutos para dar tempo das metricas estabilizarem apos cada acao de escala.

</details>

### Questao 2.4
**Voce precisa executar um script de configuracao automaticamente apos o deploy de uma VM Windows. O script instala software e configura servicos. Qual extensao voce deve usar?**

A) DSC Extension
B) Custom Script Extension
C) Azure Monitor Agent
D) Diagnostics Extension

<details>
<summary>Ver resposta</summary>

**Resposta: B) Custom Script Extension**

Custom Script Extension executa scripts (PowerShell no Windows, Bash no Linux) automaticamente apos o deploy. E a forma mais comum para configuracao pos-deploy no AZ-104.

</details>

---

# Bloco 3 - Web Apps (App Service)

**Tecnologia:** Az PowerShell module
**Recursos criados:** 1 Resource Group, 1 App Service Plan, 1 Web App, 1 Deployment Slot, App Settings, Autoscale

> **Conceito:** Azure App Service e PaaS — voce faz deploy do codigo e o Azure gerencia
> a infraestrutura (SO, patches, scaling). Alternativa ao IaaS (VMs) para aplicacoes web.

---

### Task 3.1: Criar Resource Group e App Service Plan

> **Cobranca:** O App Service Plan gera cobranca enquanto existir, mesmo com a app parada.

```powershell
# ============================================================
# TASK 3.1 - Criar Resource Group e App Service Plan
# ============================================================

New-AzResourceGroup -Name $rg8 -Location $location -Tag @{ "Env" = "Lab"; "Week" = "2" }
Write-Host "Criado $rg8 em $location"

# New-AzAppServicePlan: cria plano que define compute para Web Apps
# -Tier: nivel de preco e recursos
#   Free (F1)     = 1 GB, sem custom domain, sem SSL, sem slots
#   Basic (B1)    = 10 GB, custom domain, SSL manual, sem slots
#   Standard (S1) = 50 GB, auto-scale, 5 slots, backups
#   Premium (P1)  = 250 GB, 20 slots, VNet integration
# -NumberofWorkers: instancias do plano (scale out manual)
# -WorkerSize: tamanho de cada worker (Small/Medium/Large)
$appServicePlan = New-AzAppServicePlan `
    -ResourceGroupName $rg8 `
    -Name $appServicePlanName `
    -Location $location `
    -Tier "Standard" `
    -NumberofWorkers 1 `
    -WorkerSize "Small"

Write-Host "App Service Plan criado: $appServicePlanName"
Write-Host "  Tier: Standard (S1)"
Write-Host "  Workers: 1"
Write-Host "  Features: Auto-scale, Deployment Slots, Backups"

# Verificar
Get-AzAppServicePlan -ResourceGroupName $rg8 -Name $appServicePlanName |
    Select-Object Name, Status, Sku, NumberOfWorkers
```

> **Dica AZ-104:** O plano define o custo — multiplas Web Apps podem compartilhar
> o mesmo plano. Standard (S1) e o minimo para deployment slots e autoscale.

---

### Task 3.2: Criar Web App

```powershell
# ============================================================
# TASK 3.2 - Criar Web App
# ============================================================

# New-AzWebApp: cria aplicacao web no App Service Plan
# O nome precisa ser globalmente unico (vira parte da URL)
# URL: https://<webappname>.azurewebsites.net
$webApp = New-AzWebApp `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -Location $location `
    -AppServicePlan $appServicePlanName

Write-Host "Web App criada: $webAppName"
Write-Host "  URL: https://$webAppName.azurewebsites.net"

# Configurar runtime stack (PHP, .NET, Node, Python, Java)
# Set-AzWebApp: atualiza configuracoes da Web App
# -PhpVersion: versao do PHP (alternativas: -NetFrameworkVersion, -NodeVersion, etc.)
Set-AzWebApp `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -PhpVersion "8.2"

Write-Host "Runtime configurado: PHP 8.2"

# Verificar
Get-AzWebApp -ResourceGroupName $rg8 -Name $webAppName |
    Select-Object Name, State, DefaultHostName, Kind
```

---

### Task 3.3: Criar Deployment Slot (Staging)

```powershell
# ============================================================
# TASK 3.3 - Criar Deployment Slot para staging
# ============================================================

# Deployment Slots: ambientes separados na mesma Web App
# Cada slot tem URL propria: <appname>-<slotname>.azurewebsites.net
# Usado para zero-downtime deployments via swap
# REQUER tier Standard ou superior!

# New-AzWebAppSlot: cria slot na Web App
# -Slot: nome do slot (production e implicito, nao precisa criar)
New-AzWebAppSlot `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -Slot "staging" `
    -AppServicePlan $appServicePlanName

Write-Host "Deployment Slot criado: staging"
Write-Host "  URL: https://$webAppName-staging.azurewebsites.net"

# Configurar App Settings diferentes no slot staging
# App Settings sao variaveis de ambiente da aplicacao
# -SlotSetting: indica que a setting e "sticky" ao slot
#   (nao vai junto no swap — permanece no slot)
$slotSettings = @{
    "ENVIRONMENT" = "staging"
    "DEBUG"       = "true"
}

Set-AzWebAppSlot `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -Slot "staging" `
    -AppSettings $slotSettings

Write-Host "App Settings do slot staging configuradas"

# Marcar settings como "sticky" (slot-specific)
# Sticky settings NAO sao trocadas durante o swap
$stickySettings = @{
    AppSettingNames        = @("ENVIRONMENT", "DEBUG")
    ConnectionStringNames  = @()
}

Set-AzWebAppSlotConfigName `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -AppSettingNames @("ENVIRONMENT", "DEBUG")

Write-Host "Settings ENVIRONMENT e DEBUG marcadas como sticky (slot-specific)"

# Verificar slots
Get-AzWebAppSlot -ResourceGroupName $rg8 -Name $webAppName |
    Select-Object Name, State, DefaultHostName
```

> **Conceito:** Sticky settings permanecem no slot durante swap. Exemplo classico:
> connection strings de producao ficam sticky no slot production.

---

### Task 3.4: Executar Slot Swap

```powershell
# ============================================================
# TASK 3.4 - Swap do slot staging para production
# ============================================================

# Switch-AzWebAppSlot: troca o conteudo entre dois slots
# O swap e atomico — se falhar, volta ao estado anterior
# O Azure automaticamente "aquece" o slot destino antes do swap
# -SourceSlotName: slot de origem (staging)
# -DestinationSlotName: slot destino (production = "production")
Switch-AzWebAppSlot `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -SourceSlotName "staging" `
    -DestinationSlotName "production"

Write-Host "Swap executado: staging → production"
Write-Host "  O que estava em staging agora e production"
Write-Host "  O que estava em production agora e staging"
Write-Host "  Settings sticky (ENVIRONMENT, DEBUG) NAO foram trocadas"

# Verificar que as settings sticky permaneceram nos slots corretos
$prodSettings = (Get-AzWebApp -ResourceGroupName $rg8 -Name $webAppName).SiteConfig.AppSettings
$stagSettings = (Get-AzWebAppSlot -ResourceGroupName $rg8 -Name $webAppName -Slot "staging").SiteConfig.AppSettings

Write-Host "`nProduction App Settings:"
$prodSettings | ForEach-Object { Write-Host "  $($_.Name) = $($_.Value)" }
Write-Host "Staging App Settings:"
$stagSettings | ForEach-Object { Write-Host "  $($_.Name) = $($_.Value)" }
```

> **Dica AZ-104:** O swap preserva a URL de production. Os usuarios nao percebem a troca.
> Se algo der errado, faca swap novamente para "rollback" instantaneo.

---

### Task 3.5: Configurar Autoscale para App Service

```powershell
# ============================================================
# TASK 3.5 - Configurar Autoscale no App Service Plan
# ============================================================

# Autoscale no App Service escala o PLAN (todas as apps no plan)
# Similar ao autoscale do VMSS, usa metricas para decidir

# Regra: Scale Out quando CPU > 70%
$ruleOut = New-AzAutoscaleRuleV2 `
    -MetricTriggerMetricName "CpuPercentage" `
    -MetricTriggerMetricResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg8/providers/Microsoft.Web/serverfarms/$appServicePlanName" `
    -MetricTriggerTimeGrain ([TimeSpan]::FromMinutes(1)) `
    -MetricTriggerStatistic "Average" `
    -MetricTriggerTimeWindow ([TimeSpan]::FromMinutes(5)) `
    -MetricTriggerOperator "GreaterThan" `
    -MetricTriggerThreshold 70 `
    -ScaleActionDirection "Increase" `
    -ScaleActionType "ChangeCount" `
    -ScaleActionValue 1 `
    -ScaleActionCooldown ([TimeSpan]::FromMinutes(5))

# Regra: Scale In quando CPU < 30%
$ruleIn = New-AzAutoscaleRuleV2 `
    -MetricTriggerMetricName "CpuPercentage" `
    -MetricTriggerMetricResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg8/providers/Microsoft.Web/serverfarms/$appServicePlanName" `
    -MetricTriggerTimeGrain ([TimeSpan]::FromMinutes(1)) `
    -MetricTriggerStatistic "Average" `
    -MetricTriggerTimeWindow ([TimeSpan]::FromMinutes(5)) `
    -MetricTriggerOperator "LessThan" `
    -MetricTriggerThreshold 30 `
    -ScaleActionDirection "Decrease" `
    -ScaleActionType "ChangeCount" `
    -ScaleActionValue 1 `
    -ScaleActionCooldown ([TimeSpan]::FromMinutes(5))

# Criar perfil de autoscale
$aspProfile = New-AzAutoscaleProfileV2 `
    -Name "ASP-AutoScale" `
    -DefaultCapacity 1 `
    -MinimumCapacity 1 `
    -MaximumCapacity 3 `
    -Rule $ruleOut, $ruleIn

# Aplicar autoscale ao App Service Plan
New-AzAutoscaleSettingV2 `
    -ResourceGroupName $rg8 `
    -Name "$appServicePlanName-autoscale" `
    -Location $location `
    -Profile $aspProfile `
    -TargetResourceUri "/subscriptions/$subscriptionId/resourceGroups/$rg8/providers/Microsoft.Web/serverfarms/$appServicePlanName" `
    -Enabled

Write-Host "Autoscale configurado no App Service Plan:"
Write-Host "  Min: 1 worker"
Write-Host "  Max: 3 workers"
Write-Host "  Scale Out: CPU > 70%"
Write-Host "  Scale In:  CPU < 30%"
```

---

### Task 3.6: Configurar App Settings

```powershell
# ============================================================
# TASK 3.6 - Configurar App Settings e Connection Strings
# ============================================================

# App Settings sao variaveis de ambiente acessiveis pela aplicacao
# Mais seguro que hardcoded no codigo
# No portal: Configuration → Application settings

$appSettings = @{
    "APP_NAME"    = "AZ-104 Lab"
    "APP_VERSION" = "1.0.0"
    "STORAGE_ACCOUNT" = $storageAccountName
}

# Set-AzWebApp: atualiza configuracoes
# -AppSettings: hashtable de settings (substitui TODAS as existentes!)
Set-AzWebApp `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -AppSettings $appSettings

Write-Host "App Settings configuradas:"
$appSettings.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key) = $($_.Value)"
}

# Verificar settings aplicadas
(Get-AzWebApp -ResourceGroupName $rg8 -Name $webAppName).SiteConfig.AppSettings |
    Select-Object Name, Value |
    Format-Table -AutoSize

# Configurar Connection String (mais seguro que App Settings para DBs)
# Connection Strings tem tipos: SQLServer, MySQL, PostgreSQL, Custom
$connStrings = @{
    "DefaultConnection" = @{
        Type  = "Custom"
        Value = "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;EndpointSuffix=core.windows.net"
    }
}

Set-AzWebApp `
    -ResourceGroupName $rg8 `
    -Name $webAppName `
    -ConnectionStrings $connStrings

Write-Host "`nConnection String configurada: DefaultConnection"
```

> **Conceito:** App Settings sobrescrevem variaveis do web.config/appsettings.json.
> Na prova, App Settings sao a resposta para "como configurar variaveis sem alterar codigo".

---

## Modo Desafio - Bloco 3

- [ ] Criar App Service Plan tier Standard (S1) com 1 worker
- [ ] Criar Web App com runtime PHP 8.2
- [ ] Criar Deployment Slot "staging" com App Settings diferentes
- [ ] Marcar ENVIRONMENT e DEBUG como sticky settings
- [ ] Executar swap staging → production
- [ ] Configurar autoscale no App Service Plan (CPU 30-70%, max 3 workers)
- [ ] Configurar App Settings e Connection String

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa fazer deploy de uma nova versao da aplicacao sem downtime. A Web App esta no tier Standard. Qual abordagem voce deve usar?**

A) Reiniciar a Web App
B) Fazer deploy direto em production
C) Usar deployment slot com swap
D) Escalar para mais instancias

<details>
<summary>Ver resposta</summary>

**Resposta: C) Usar deployment slot com swap**

Deployment slots permitem deploy em staging, testar, e depois swap para production atomicamente (zero downtime). Requer tier Standard ou superior.

</details>

### Questao 3.2
**Apos um swap, a connection string de producao foi substituida pela de staging. Como prevenir isso em futuros swaps?**

A) Usar App Settings em vez de Connection Strings
B) Marcar a connection string como "Deployment slot setting" (sticky)
C) Configurar a connection string via ARM template
D) Criar um Key Vault reference

<details>
<summary>Ver resposta</summary>

**Resposta: B) Marcar a connection string como "Deployment slot setting" (sticky)**

Settings marcadas como sticky (slot-specific) NAO sao trocadas durante o swap. Connection strings de producao devem ser sticky para nao vazar para staging.

</details>

### Questao 3.3
**Qual e o tier minimo do App Service Plan que suporta deployment slots e autoscale?**

A) Free (F1)
B) Basic (B1)
C) Standard (S1)
D) Premium (P1v2)

<details>
<summary>Ver resposta</summary>

**Resposta: C) Standard (S1)**

Standard (S1) e o tier minimo para deployment slots (5 slots) e autoscale. Free e Basic nao suportam nenhum dos dois. Premium oferece 20 slots.

</details>

---

# Bloco 4 - Azure Container Instances (ACI)

**Tecnologia:** Az PowerShell module
**Recursos criados:** 1 Resource Group, 3 Container Groups (nginx simples, com env vars, com file share)

> **Conceito:** ACI e a forma mais rapida de rodar containers no Azure. Sem orquestracao,
> sem cluster. Ideal para tarefas batch, build agents, e testes rapidos.

---

### Task 4.1: Criar Resource Group e Container Group simples

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running.

```powershell
# ============================================================
# TASK 4.1 - Criar Resource Group e Container Group (nginx)
# ============================================================

New-AzResourceGroup -Name $rg9 -Location $location -Tag @{ "Env" = "Lab"; "Week" = "2" }
Write-Host "Criado $rg9 em $location"

# New-AzContainerGroup: cria grupo de containers
# -Image: imagem Docker (do Docker Hub, ACR, ou outro registry)
# -OsType: Linux ou Windows
# -Cpu: vCPUs por container (fracionario: 0.5, 1, 2, 4)
# -MemoryInGB: RAM por container (fracionario: 0.5, 1, 1.5, etc.)
# -IpAddressType: Public ou Private
# -Port: portas expostas (pode ser array para multiplas)
# -DnsNameLabel: cria FQDN: <label>.<region>.azurecontainer.io
$aciSimple = New-AzContainerGroup `
    -ResourceGroupName $rg9 `
    -Name "$aciName-simple" `
    -Image "nginx:latest" `
    -OsType "Linux" `
    -Cpu 1 `
    -MemoryInGB 1.5 `
    -IpAddressType "Public" `
    -Port @(80) `
    -DnsNameLabel "$aciName-simple-$(Get-Random -Minimum 100 -Maximum 999)" `
    -RestartPolicy "Always"

Write-Host "Container Group criado: $aciName-simple"
Write-Host "  Imagem: nginx:latest"
Write-Host "  CPU: 1 vCPU"
Write-Host "  Memoria: 1.5 GB"
Write-Host "  IP: $($aciSimple.IpAddress)"
Write-Host "  FQDN: $($aciSimple.Fqdn)"
Write-Host "`nTeste no navegador: http://$($aciSimple.Fqdn)"

# Verificar status
Get-AzContainerGroup -ResourceGroupName $rg9 -Name "$aciName-simple" |
    Select-Object Name, ProvisioningState, IpAddress, OsType
```

> **Dica AZ-104:** ACI cobra por segundo de uso (CPU + memoria). Nao ha custo quando
> o container esta parado. Ideal para workloads burst e efemeros.

---

### Task 4.2: Criar Container com Environment Variables e Resource Limits

```powershell
# ============================================================
# TASK 4.2 - Container com env vars e resource limits
# ============================================================

# Criar container com variaveis de ambiente personalizadas
# e limites de recursos (CPU/memoria)
# Usando New-AzContainerInstanceObject para configuracao avancada

# Definir variaveis de ambiente
# -Name + -Value: variavel normal (visivel)
# -Name + -SecureValue: variavel segura (oculta nos logs/portal)
$envVars = @(
    New-AzContainerInstanceEnvironmentVariableObject -Name "APP_ENV" -Value "production"
    New-AzContainerInstanceEnvironmentVariableObject -Name "APP_PORT" -Value "80"
    New-AzContainerInstanceEnvironmentVariableObject -Name "DB_PASSWORD" -SecureValue "SenhaSecreta123!"
)

# Criar objeto de container com configuracao detalhada
$container = New-AzContainerInstanceObject `
    -Name "webapp" `
    -Image "nginx:latest" `
    -Port @(New-AzContainerGroupPortObject -Port 80 -Protocol "TCP") `
    -EnvironmentVariable $envVars `
    -RequestCpu 0.5 `
    -RequestMemoryInGb 0.5 `
    -LimitCpu 1 `
    -LimitMemoryInGb 1

# Criar container group com o container configurado
$aciAdvanced = New-AzContainerGroup `
    -ResourceGroupName $rg9 `
    -Name "$aciName-advanced" `
    -Location $location `
    -Container $container `
    -OsType "Linux" `
    -IpAddressType "Public" `
    -RestartPolicy "OnFailure" `
    -Tag @{ "Env" = "Lab" }

Write-Host "Container Group criado: $aciName-advanced"
Write-Host "  Request: 0.5 CPU, 0.5 GB"
Write-Host "  Limit: 1 CPU, 1 GB"
Write-Host "  Env vars: APP_ENV=production, APP_PORT=80, DB_PASSWORD=***"
Write-Host "  Restart Policy: OnFailure"

# Verificar status
Get-AzContainerGroup -ResourceGroupName $rg9 -Name "$aciName-advanced" |
    Select-Object Name, ProvisioningState, IpAddress
```

> **Conceito:** `Request` = minimo garantido; `Limit` = maximo que o container pode usar.
> Se o container exceder o limit de memoria, e terminado (OOMKilled).
> `SecureValue` e para senhas/tokens — nao aparece em logs ou portal.

---

### Task 4.3: Criar Container com Azure File Share montado

```powershell
# ============================================================
# TASK 4.3 - Container com Azure File Share montado
# ============================================================

# Montar Azure File Share permite persistir dados alem do ciclo de vida do container
# Os dados ficam no Storage Account (Bloco 1) e sobrevivem ao reinicio

# Obter credenciais do Storage Account (do Bloco 1)
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $rg6 -Name $storageAccountName)[0].Value

# Criar volume com Azure File Share
$volume = New-AzContainerGroupVolumeObject `
    -Name "fileshare-volume" `
    -AzureFileShareName $fileShareName `
    -AzureFileStorageAccountName $storageAccountName `
    -AzureFileStorageAccountKey (ConvertTo-SecureString $storageKey -AsPlainText -Force)

# Criar container com volume montado
$containerWithVolume = New-AzContainerInstanceObject `
    -Name "webapp-volume" `
    -Image "nginx:latest" `
    -Port @(New-AzContainerGroupPortObject -Port 80 -Protocol "TCP") `
    -RequestCpu 0.5 `
    -RequestMemoryInGb 0.5 `
    -VolumeMount @(
        New-AzContainerInstanceVolumeMountObject `
            -Name "fileshare-volume" `
            -MountPath "/mnt/azure" `
            -ReadOnly $false
    )

$aciVolume = New-AzContainerGroup `
    -ResourceGroupName $rg9 `
    -Name "$aciName-volume" `
    -Location $location `
    -Container $containerWithVolume `
    -Volume $volume `
    -OsType "Linux" `
    -IpAddressType "Public" `
    -RestartPolicy "Always"

Write-Host "Container Group criado: $aciName-volume"
Write-Host "  Volume montado: $fileShareName → /mnt/azure"
Write-Host "  Dados persistidos no Storage Account: $storageAccountName"
Write-Host "  IP: $($aciVolume.IpAddress)"
```

> **Conexao com Bloco 1:** O File Share criado na Task 1.3 e montado no container.
> Qualquer arquivo gravado em `/mnt/azure` persiste no Storage Account.

---

### Task 4.4: Verificar Logs dos Containers

```powershell
# ============================================================
# TASK 4.4 - Consultar logs dos containers
# ============================================================

# Get-AzContainerInstanceLog: obtem stdout/stderr do container
# Essencial para debugging e monitoramento

# Logs do container simples
Write-Host "=== Logs: $aciName-simple ===" -ForegroundColor Cyan
Get-AzContainerInstanceLog `
    -ResourceGroupName $rg9 `
    -ContainerGroupName "$aciName-simple" `
    -ContainerName "$aciName-simple"

# Logs do container avancado
Write-Host "`n=== Logs: $aciName-advanced ===" -ForegroundColor Cyan
Get-AzContainerInstanceLog `
    -ResourceGroupName $rg9 `
    -ContainerGroupName "$aciName-advanced" `
    -ContainerName "webapp"

# Logs do container com volume
Write-Host "`n=== Logs: $aciName-volume ===" -ForegroundColor Cyan
Get-AzContainerInstanceLog `
    -ResourceGroupName $rg9 `
    -ContainerGroupName "$aciName-volume" `
    -ContainerName "webapp-volume"

# Verificar detalhes de todos os container groups
Get-AzContainerGroup -ResourceGroupName $rg9 |
    Select-Object Name, ProvisioningState, IpAddress, OsType, RestartPolicy |
    Format-Table -AutoSize
```

---

## Modo Desafio - Bloco 4

- [ ] Criar Container Group simples com nginx, 1 CPU, 1.5 GB, IP publico
- [ ] Criar Container com env vars (normal + secure) e resource limits (request + limit)
- [ ] Criar Container com Azure File Share montado em /mnt/azure
- [ ] Verificar logs de todos os containers com `Get-AzContainerInstanceLog`
- [ ] Testar acesso HTTP ao container nginx no navegador

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa rodar um container que processa dados uma vez e para. Qual restart policy voce deve usar?**

A) Always
B) OnFailure
C) Never
D) Once

<details>
<summary>Ver resposta</summary>

**Resposta: C) Never**

`Never` = container roda uma vez e para (batch jobs). `Always` = reinicia sempre (web servers). `OnFailure` = reinicia apenas se falhar (exit code != 0).

</details>

### Questao 4.2
**Um container ACI precisa acessar dados que persistem entre reinicializacoes. Qual abordagem voce deve usar?**

A) Aumentar o disco local do container
B) Montar um Azure File Share como volume
C) Usar um Managed Disk
D) Armazenar no registro do container

<details>
<summary>Ver resposta</summary>

**Resposta: B) Montar um Azure File Share como volume**

ACI suporta volumes montados com Azure Files. O filesystem local do container e efemero — dados sao perdidos ao reiniciar. Azure Files persiste os dados no Storage Account.

</details>

### Questao 4.3
**Voce precisa passar uma senha para um container ACI sem que ela apareca nos logs ou no portal. Como fazer?**

A) Usar uma variavel de ambiente normal
B) Usar uma variavel de ambiente segura (secureValue)
C) Montar um arquivo de configuracao
D) Usar um Key Vault reference

<details>
<summary>Ver resposta</summary>

**Resposta: B) Usar uma variavel de ambiente segura (secureValue)**

Variaveis com `secureValue` sao criptografadas e nao aparecem em logs, portal ou API responses. Para cenarios mais complexos, Key Vault references tambem funcionam.

</details>

---

# Bloco 5 - Container Apps

**Tecnologia:** az CLI (Container Apps nao tem cmdlets PowerShell nativos)
**Recursos criados:** 1 Resource Group, 1 Container Apps Environment, 1 Container App, Traffic splitting

> **NOTA IMPORTANTE:** Azure Container Apps **nao possui cmdlets PowerShell nativos** no modulo Az.
> Usamos `az containerapp` (CLI) diretamente no Cloud Shell PowerShell.
> Isso e comum no Azure — alguns servicos mais novos so tem suporte CLI inicialmente.

---

### Task 5.1: Criar Resource Group e Container Apps Environment

```powershell
# ============================================================
# TASK 5.1 - Criar Resource Group e Container Apps Environment
# ============================================================

New-AzResourceGroup -Name $rg10 -Location $location -Tag @{ "Env" = "Lab"; "Week" = "2" }
Write-Host "Criado $rg10 em $location"

# Instalar/atualizar extensao Container Apps no CLI
# Extensoes adicionam funcionalidades ao az CLI
az extension add --name containerapp --upgrade --yes 2>$null

# Validar que a extensao foi instalada
$extCheck = az extension show --name containerapp 2>$null | ConvertFrom-Json
if ($extCheck) {
    Write-Host "✓ Extensao containerapp instalada: $($extCheck.version)"
} else {
    Write-Host "✗ ERRO: Extensao containerapp NAO foi instalada."
    Write-Host "  Comandos de Container Apps nao funcionarao."
    Write-Host "  Tente manualmente: az extension add --name containerapp"
}

# az containerapp env create: cria Container Apps Environment
# O Environment e o "cluster" onde os Container Apps rodam
# Inclui: Log Analytics, networking, e orquestracao
# Multiplos Container Apps compartilham o mesmo Environment
az containerapp env create `
    --name $containerAppEnvName `
    --resource-group $rg10 `
    --location $location

Write-Host "`nContainer Apps Environment criado: $containerAppEnvName"
Write-Host "  O Environment gerencia networking, logs e orquestracao"

# Verificar
az containerapp env show `
    --name $containerAppEnvName `
    --resource-group $rg10 `
    --query "{name:name, provisioningState:properties.provisioningState, location:location}" `
    --output table
```

> **Conceito:** Container Apps Environment = Kubernetes under the hood, sem gerenciar o cluster.
> E o "runtime" serverless para containers, com Dapr e KEDA integrados.

---

### Task 5.2: Criar Container App

```powershell
# ============================================================
# TASK 5.2 - Criar Container App com nginx
# ============================================================

# az containerapp create: cria um Container App
# --image: imagem Docker
# --target-port: porta que o container escuta
# --ingress: tipo de acesso
#   external = acessivel pela internet (cria URL publica)
#   internal = acessivel apenas dentro do Environment
# --cpu: vCPUs (0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 4)
# --memory: RAM (0.5Gi, 1Gi, 1.5Gi, 2Gi, 3Gi, 4Gi, 8Gi)
# --min-replicas: minimo de instancias (0 = scale to zero!)
# --max-replicas: maximo de instancias
az containerapp create `
    --name $containerAppName `
    --resource-group $rg10 `
    --environment $containerAppEnvName `
    --image "nginx:latest" `
    --target-port 80 `
    --ingress external `
    --cpu 0.5 `
    --memory 1Gi `
    --min-replicas 0 `
    --max-replicas 5

# Obter URL do Container App
$containerAppUrl = az containerapp show `
    --name $containerAppName `
    --resource-group $rg10 `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

Write-Host "`nContainer App criado: $containerAppName"
Write-Host "  URL: https://$containerAppUrl"
Write-Host "  CPU: 0.5 vCPU"
Write-Host "  Memoria: 1 Gi"
Write-Host "  Replicas: 0-5 (scale to zero!)"
Write-Host "`nTeste no navegador: https://$containerAppUrl"
```

> **Dica AZ-104:** Container Apps suportam scale-to-zero (min-replicas=0),
> ou seja, quando nao ha trafego, nao ha instancia rodando (custo zero!).
> ACI NAO suporta scale-to-zero.

---

### Task 5.3: Configurar Scaling Rules

```powershell
# ============================================================
# TASK 5.3 - Configurar regras de scaling (HTTP)
# ============================================================

# Container Apps suportam diversos tipos de scaling:
# - HTTP: baseado no numero de requisicoes concorrentes
# - Custom: KEDA scalers (Azure Queue, Kafka, etc.)
# - CPU/Memory: baseado no uso de recursos

# az containerapp update: atualiza Container App
# --scale-rule-name: nome da regra
# --scale-rule-type: tipo (http, azure-queue, custom, etc.)
# --scale-rule-http-concurrency: requisicoes simultaneas por replica
az containerapp update `
    --name $containerAppName `
    --resource-group $rg10 `
    --min-replicas 1 `
    --max-replicas 10 `
    --scale-rule-name "http-rule" `
    --scale-rule-type "http" `
    --scale-rule-http-concurrency 50

Write-Host "Scaling atualizado:"
Write-Host "  Replicas: 1-10"
Write-Host "  Regra: HTTP concurrency = 50"
Write-Host "  Significado: 1 nova replica a cada 50 requisicoes simultaneas"

# Verificar configuracao de scaling
az containerapp show `
    --name $containerAppName `
    --resource-group $rg10 `
    --query "properties.template.scale" `
    --output json
```

---

### Task 5.4: Configurar Ingress

```powershell
# ============================================================
# TASK 5.4 - Configurar Ingress detalhado
# ============================================================

# Ingress controla como o trafego externo chega ao Container App
# Podemos configurar: porta, protocolo, CORS, IP restrictions

# az containerapp ingress update: atualiza configuracoes de ingress
# --allow-insecure: false = redireciona HTTP para HTTPS
# --transport: auto, http, http2, tcp
az containerapp ingress update `
    --name $containerAppName `
    --resource-group $rg10 `
    --target-port 80 `
    --transport auto `
    --allow-insecure false

Write-Host "Ingress atualizado:"
Write-Host "  HTTP → HTTPS redirect: habilitado"
Write-Host "  Transport: auto (HTTP/1.1 ou HTTP/2)"

# Verificar ingress
az containerapp ingress show `
    --name $containerAppName `
    --resource-group $rg10 `
    --output table
```

---

### Task 5.5: Traffic Splitting (Blue/Green com Revisions)

```powershell
# ============================================================
# TASK 5.5 - Traffic Splitting entre Revisions
# ============================================================

# Container Apps usam Revisions (snapshots imutaveis da configuracao)
# Cada mudanca cria uma nova revision
# Podemos dividir trafego entre revisions (canary/blue-green)

# Habilitar modo multi-revision (necessario para traffic splitting)
az containerapp revision set-mode `
    --name $containerAppName `
    --resource-group $rg10 `
    --mode multiple

Write-Host "Modo multi-revision habilitado"

# Criar nova revision (simulando deploy de nova versao)
# --revision-suffix: sufixo para identificar a revision
az containerapp revision copy `
    --name $containerAppName `
    --resource-group $rg10 `
    --revision-suffix "v2" `
    --cpu 0.5 `
    --memory 1Gi

Write-Host "Nova revision criada com sufixo 'v2'"

# Listar revisions
az containerapp revision list `
    --name $containerAppName `
    --resource-group $rg10 `
    --output table

# Obter nomes das revisions
$revisions = az containerapp revision list `
    --name $containerAppName `
    --resource-group $rg10 `
    --query "[].name" `
    --output tsv

$revisionOld = ($revisions -split "`n")[0].Trim()
$revisionNew = ($revisions -split "`n")[-1].Trim()

Write-Host "`nRevisions:"
Write-Host "  Old: $revisionOld"
Write-Host "  New: $revisionNew"

# Dividir trafego: 80% na versao antiga, 20% na nova (canary)
az containerapp ingress traffic set `
    --name $containerAppName `
    --resource-group $rg10 `
    --revision-weight "$revisionOld=80" "$revisionNew=20"

Write-Host "`nTraffic Split configurado:"
Write-Host "  $revisionOld → 80%"
Write-Host "  $revisionNew → 20% (canary)"

# Verificar distribuicao de trafego
az containerapp ingress traffic show `
    --name $containerAppName `
    --resource-group $rg10 `
    --output table

# Quando satisfeito, promover nova versao para 100%
Write-Host "`n--- Para promover a nova versao (quando satisfeito): ---" -ForegroundColor Yellow
Write-Host "az containerapp ingress traffic set ``"
Write-Host "    --name $containerAppName ``"
Write-Host "    --resource-group $rg10 ``"
Write-Host "    --revision-weight '$revisionNew=100'"
```

> **Conceito:** Traffic Splitting e a base de canary deployments no Container Apps.
> 80/20 → 50/50 → 100/0 gradualmente, verificando metricas entre cada passo.

---

## Modo Desafio - Bloco 5

- [ ] Criar Container Apps Environment no $rg10
- [ ] Criar Container App com nginx, ingress externo, scale-to-zero (min=0, max=5)
- [ ] Configurar scaling rule HTTP com concurrency 50
- [ ] Configurar ingress para redirecionar HTTP para HTTPS
- [ ] Habilitar multi-revision mode e criar nova revision
- [ ] Configurar traffic splitting: 80% old, 20% new (canary)
- [ ] Verificar distribuicao de trafego com `az containerapp ingress traffic show`

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Voce precisa rodar containers serverless que escalam automaticamente para zero quando nao ha trafego. Qual servico voce deve usar?**

A) Azure Container Instances (ACI)
B) Azure Container Apps
C) Azure Kubernetes Service (AKS)
D) Azure App Service (container)

<details>
<summary>Ver resposta</summary>

**Resposta: B) Azure Container Apps**

Container Apps suporta scale-to-zero (min-replicas=0), ou seja, quando nao ha trafego, nao ha instancia rodando. ACI nao escala automaticamente, AKS requer gerenciar o cluster, e App Service nao escala para zero.

</details>

### Questao 5.2
**Voce precisa fazer deploy gradual de uma nova versao do container, enviando 10% do trafego para a nova versao. Qual recurso do Container Apps voce deve usar?**

A) Deployment Slots
B) Revision-based traffic splitting
C) Blue/Green deployment via AKS
D) Rolling update

<details>
<summary>Ver resposta</summary>

**Resposta: B) Revision-based traffic splitting**

Container Apps usa revisions (snapshots imutaveis) para versionamento. Traffic splitting entre revisions permite canary deployments (ex: 90/10, 80/20, etc.). Deployment Slots sao do App Service, nao Container Apps.

</details>

### Questao 5.3
**Qual e a diferenca entre ACI e Container Apps para a prova AZ-104?**

A) ACI suporta orchestracao, Container Apps nao
B) Container Apps suporta scaling automatico e traffic splitting, ACI nao
C) ACI suporta multi-container groups, Container Apps nao
D) Ambos sao identicos em funcionalidade

<details>
<summary>Ver resposta</summary>

**Resposta: B) Container Apps suporta scaling automatico e traffic splitting, ACI nao**

ACI = container simples, sem orquestracao, sem auto-scaling (voce gerencia manualmente). Container Apps = serverless com auto-scaling (KEDA), traffic splitting, revisions, Dapr integration. ACI tambem suporta multi-container groups, mas Container Apps tem mais recursos de orquestracao.

</details>

---

# Bloco 6 - Storage Avancado e Disk Encryption

**Tecnologia:** PowerShell (Az module) + az CLI
**Recursos criados:** 1 Storage Account (destino AzCopy), 1 Key Vault com 2 chaves RSA, Object Replication, CMK, ADE
**Resource Groups:** `az104-rg6` (existente), `az104-rg7` (existente), `az104-rg6adv` (novo)

> **Pre-requisito:** Blocos 1 e 2 devem estar completos (Storage Account + VMs criadas).

---

### Task 6.1: Criar Storage Account de destino para AzCopy

```powershell
# ============================================================
# Segunda Storage Account para destino de AzCopy e Object Replication
# ============================================================

# Criar Resource Group
$rg6adv = "az104-rg6adv"
New-AzResourceGroup -Name $rg6adv -Location "East US" -Force

# CONCEITO AZ-104: Segunda Storage Account demonstra:
# - AzCopy entre contas (server-to-server)
# - Object Replication (assincrona, cross-account)
$storage2Name = "contosostore2" + (-join ((48..57) + (97..102) | Get-Random -Count 6 | ForEach-Object { [char]$_ }))
Write-Host "Storage Account 2: $storage2Name"

$storage2 = New-AzStorageAccount `
    -ResourceGroupName $rg6adv `
    -Name $storage2Name `
    -Location "East US" `
    -SkuName Standard_LRS `
    -Kind StorageV2 `
    -AccessTier Hot `
    -MinimumTlsVersion TLS1_2 `
    -AllowBlobPublicAccess $false

# CONCEITO AZ-104: Object Replication requer versioning em AMBAS as contas
# e change feed na ORIGEM. Habilitamos ambos no destino tambem.
$ctx2 = $storage2.Context

# Habilitar versioning e change feed
Update-AzStorageBlobServiceProperty `
    -ResourceGroupName $rg6adv `
    -StorageAccountName $storage2Name `
    -IsVersioningEnabled $true `
    -EnableChangeFeed $true

# Criar container de destino
New-AzStorageContainer `
    -Name "data-replica" `
    -Context $ctx2 `
    -Permission Off

Write-Host "Storage Account $storage2Name criada com container data-replica"
```

**Transferir blobs com AzCopy:**

```powershell
# ============================================================
# AzCopy: Transferencia server-to-server entre Storage Accounts
# ============================================================

# CONCEITO AZ-104: AzCopy transfere dados pela rede backbone Azure
# (server-to-server). Nao passa pelo seu computador local.
# PowerShell nao tem cmdlet nativo para AzCopy — usamos o executavel

# 1. Obter contexto da Storage Account de origem (Bloco 1)
$storage1Name = (Get-AzStorageAccount -ResourceGroupName "az104-rg6")[0].StorageAccountName
Write-Host "Origem: $storage1Name"
$ctx1 = (Get-AzStorageAccount -ResourceGroupName "az104-rg6" -Name $storage1Name).Context

# 2. Gerar SAS de ORIGEM (Read + List)
$sasOrigem = New-AzStorageAccountSASToken `
    -Context $ctx1 `
    -Service Blob `
    -ResourceType Service,Container,Object `
    -Permission rl `
    -ExpiryTime (Get-Date).AddDays(1) `
    -Protocol HttpsOnly

# 3. Gerar SAS de DESTINO (Read + Write + List + Create)
$sasDestino = New-AzStorageAccountSASToken `
    -Context $ctx2 `
    -Service Blob `
    -ResourceType Service,Container,Object `
    -Permission rwlc `
    -ExpiryTime (Get-Date).AddDays(1) `
    -Protocol HttpsOnly

# 4. Executar AzCopy (disponivel no Cloud Shell)
azcopy copy `
    "https://${storage1Name}.blob.core.windows.net/data${sasOrigem}" `
    "https://${storage2Name}.blob.core.windows.net/data-replica${sasDestino}" `
    --recursive

# 5. Verificar blobs copiados
Get-AzStorageBlob -Container "data-replica" -Context $ctx2 | Format-Table Name, Length, LastModified
```

> **Dica AZ-104:** Na prova, AzCopy e a ferramenta recomendada para transferencias em massa. Para copias programaticas em PowerShell, use `Start-AzStorageBlobCopy`.

---

### Task 6.2: Gerenciar blobs com Storage Explorer (versao portal)

```powershell
# Operacoes equivalentes ao Storage Browser via PowerShell

# 1. Upload de arquivo
"Arquivo de teste para Storage Explorer" | Out-File /tmp/teste-explorer.txt
Set-AzStorageBlobContent `
    -Container "data" -Blob "teste-explorer.txt" `
    -File "/tmp/teste-explorer.txt" -Context $ctx1 -Force

# 2. Criar pasta virtual (prefixo) com upload
"Log de teste" | Out-File /tmp/log-teste.txt
Set-AzStorageBlobContent `
    -Container "data" -Blob "logs/log-teste.txt" `
    -File "/tmp/log-teste.txt" -Context $ctx1 -Force

# 3. Gerar SAS para blob individual
# CONCEITO AZ-104: Blob-level SAS e mais granular que account-level SAS
$blobSas = New-AzStorageBlobSASToken `
    -Container "data" -Blob "teste-explorer.txt" `
    -Permission r `
    -ExpiryTime (Get-Date).AddHours(1) `
    -Protocol HttpsOnly `
    -Context $ctx1

$blobUrl = "https://${storage1Name}.blob.core.windows.net/data/teste-explorer.txt${blobSas}"
Write-Host "URL com SAS: $blobUrl"
```

---

### Task 6.3: Configurar Object Replication

```powershell
# CONCEITO AZ-104: Object Replication = copia assincrona entre contas
# Requer: versioning em AMBAS + change feed na ORIGEM

# 1. Habilitar versioning + change feed na origem
Update-AzStorageBlobServiceProperty `
    -ResourceGroupName "az104-rg6" `
    -StorageAccountName $storage1Name `
    -IsVersioningEnabled $true `
    -EnableChangeFeed $true

# 2. Criar politica via az CLI (cmdlets PS para OR-policy sao limitados)
az storage account or-policy create `
    --account-name $storage2Name `
    --source-account $storage1Name `
    --destination-account $storage2Name `
    --source-container data `
    --destination-container data-replica `
    --min-creation-time (Get-Date -Format "yyyy-MM-ddTHH:mmZ")

# 3. Validar: upload novo blob na origem
"Teste replicacao $(Get-Date)" | Out-File /tmp/teste-replicacao.txt
Set-AzStorageBlobContent `
    -Container "data" -Blob "teste-replicacao.txt" `
    -File "/tmp/teste-replicacao.txt" -Context $ctx1 -Force

Write-Host "Aguarde minutos e verifique data-replica em $storage2Name"
```

---

### Task 6.4: Criar Key Vault com chaves RSA

```powershell
# ============================================================
# Key Vault com purge protection + chaves RSA
# ============================================================

# CONCEITO AZ-104: Key Vault armazena secrets, keys e certificates
# Purge protection: OBRIGATORIO para CMK (nao pode ser desabilitado depois)
$kvName = "az104-kv-" + (-join ((48..57) + (97..102) | Get-Random -Count 6 | ForEach-Object { [char]$_ }))
Write-Host "Key Vault: $kvName"

$kv = New-AzKeyVault `
    -Name $kvName `
    -ResourceGroupName $rg6adv `
    -Location "East US" `
    -Sku Standard `
    -EnableRbacAuthorization `
    -EnablePurgeProtection `
    -SoftDeleteRetentionInDays 90 `
    -EnabledForDiskEncryption `
    -EnabledForTemplateDeployment

# Atribuir role Key Vault Crypto Officer ao usuario atual
$adminOid = (Get-AzADUser -SignedIn).Id

New-AzRoleAssignment `
    -ObjectId $adminOid `
    -RoleDefinitionName "Key Vault Crypto Officer" `
    -Scope $kv.ResourceId

# Aguardar propagacao do RBAC
Start-Sleep -Seconds 15

# Criar chave RSA: storage-cmk (para CMK na Storage Account)
# CONCEITO AZ-104: wrapKey/unwrapKey = encriptar/decriptar a chave de dados
$storageCmkKey = Add-AzKeyVaultKey `
    -VaultName $kvName `
    -Name "storage-cmk" `
    -KeyType RSA `
    -Size 2048 `
    -KeyOps wrapKey,unwrapKey

# Criar chave RSA: disk-encryption (KEK para ADE)
$diskEncKey = Add-AzKeyVaultKey `
    -VaultName $kvName `
    -Name "disk-encryption" `
    -KeyType RSA `
    -Size 2048 `
    -KeyOps wrapKey,unwrapKey,encrypt,decrypt

Write-Host "Chaves criadas:"
Get-AzKeyVaultKey -VaultName $kvName | Format-Table Name, KeyType, Enabled
```

**Configurar CMK na Storage Account:**

```powershell
# CONCEITO AZ-104: CMK = sua chave no Key Vault, em vez da chave da Microsoft
# Requer: Managed Identity na Storage Account + permissao no Key Vault

# 1. Habilitar System-assigned Managed Identity
$storage1 = Set-AzStorageAccount `
    -ResourceGroupName "az104-rg6" `
    -Name $storage1Name `
    -AssignIdentity

$storageIdentity = $storage1.Identity.PrincipalId
Write-Host "Storage Identity: $storageIdentity"

# 2. Atribuir role no Key Vault
New-AzRoleAssignment `
    -ObjectId $storageIdentity `
    -RoleDefinitionName "Key Vault Crypto Service Encryption User" `
    -Scope $kv.ResourceId

Start-Sleep -Seconds 15  # Aguardar propagacao

# 3. Configurar CMK via az CLI (mais simples que PS para CMK)
az storage account update `
    --name $storage1Name `
    --resource-group "az104-rg6" `
    --encryption-key-source Microsoft.Keyvault `
    --encryption-key-vault "https://${kvName}.vault.azure.net" `
    --encryption-key-name "storage-cmk"

# 4. Verificar
$storageEnc = Get-AzStorageAccount -ResourceGroupName "az104-rg6" -Name $storage1Name
Write-Host "Encryption Key Source: $($storageEnc.Encryption.KeySource)"
Write-Host "Key Vault URI: $($storageEnc.Encryption.KeyVaultProperties.KeyVaultUri)"
```

---

### Task 6.5: Configurar acesso baseado em identidade para Azure Files

```powershell
# CONCEITO AZ-104: Azure Files suporta 3 metodos de auth:
# 1. Storage account key (padrao)  2. Entra ID DS  3. On-premises AD DS
#
# Roles RBAC para SMB:
# - Storage File Data SMB Share Reader
# - Storage File Data SMB Share Contributor
# - Storage File Data SMB Share Elevated Contributor

Write-Host "=== Roles RBAC para Azure Files ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Storage File Data SMB Share Reader:"
Write-Host "  - Read access a arquivos e diretorios via SMB"
Write-Host ""
Write-Host "Storage File Data SMB Share Contributor:"
Write-Host "  - Read, write, delete em arquivos e diretorios via SMB"
Write-Host ""
Write-Host "Storage File Data SMB Share Elevated Contributor:"
Write-Host "  - Acima + modificar ACLs NTFS"
Write-Host ""
Write-Host "RBAC = nivel do SHARE. ACLs NTFS = nivel granular (arquivo/diretorio)."

# Exemplo (nao executar sem AADDS):
# New-AzRoleAssignment `
#     -ObjectId "<user-object-id>" `
#     -RoleDefinitionName "Storage File Data SMB Share Contributor" `
#     -Scope "/subscriptions/<sub>/resourceGroups/az104-rg6/providers/Microsoft.Storage/storageAccounts/$storage1Name/fileServices/default/fileshares/contoso-files"
```

---

### Task 6.6: Habilitar Azure Disk Encryption na VM Windows

```powershell
# CONCEITO AZ-104: ADE = BitLocker (Win) / DM-Crypt (Linux) no nivel do OS
# Diferente de SSE (Server-Side Encryption) que criptografa no storage layer
# ADE + SSE = dupla camada de protecao

# 1. Verificar VM running
$vmStatus = Get-AzVM -ResourceGroupName "az104-rg7" -Name "az104-vm-win" -Status
Write-Host "VM Status: $($vmStatus.Statuses[1].DisplayStatus)"

# 2. Habilitar ADE com KEK
# CONCEITO AZ-104: KEK adiciona camada extra — a chave BitLocker e
# encriptada pela KEK no Key Vault
# PowerShell nao tem cmdlet nativo simples para ADE com KEK,
# az CLI e mais direto para este caso
az vm encryption enable `
    --resource-group "az104-rg7" `
    --name "az104-vm-win" `
    --disk-encryption-keyvault $kvName `
    --key-encryption-key "disk-encryption" `
    --volume-type All

# NOTA: Este comando pode levar 10-15 minutos

# 3. Verificar status da criptografia
# Via PowerShell:
$encStatus = Get-AzVMDiskEncryptionStatus `
    -ResourceGroupName "az104-rg7" `
    -VMName "az104-vm-win"
Write-Host "OS Disk: $($encStatus.OsVolumeEncryptionSettings)"
Write-Host "Data Disk: $($encStatus.DataVolumesEncrypted)"

# Via az CLI (mais detalhado):
az vm encryption show --resource-group "az104-rg7" --name "az104-vm-win" -o table
```

---

## Modo Desafio - Bloco 6

- [ ] Criar Storage Account de destino com `New-AzStorageAccount` + habilitar versioning
- [ ] Gerar SAS tokens com `New-AzStorageAccountSASToken` e executar AzCopy
- [ ] Usar Storage Browser ou `Set-AzStorageBlobContent` para uploads e pasta virtual
- [ ] Configurar Object Replication via CLI (versioning + change feed)
- [ ] Criar Key Vault com `New-AzKeyVault` + chaves com `Add-AzKeyVaultKey`
- [ ] Configurar CMK na Storage Account via Managed Identity + Key Vault
- [ ] Explorar roles RBAC para Azure Files (SMB Share Reader/Contributor/Elevated)
- [ ] Habilitar Azure Disk Encryption na VM Windows **(Bloco 2)** via Key Vault

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Copiar 500 GB de blobs entre storage accounts em regioes diferentes. Qual ferramenta?**

A) Portal (upload/download)  B) AzCopy com SAS tokens  C) Data Factory  D) Storage Explorer

<details>
<summary>Ver resposta</summary>

**Resposta: B) AzCopy com SAS tokens**

AzCopy faz transferencias server-to-server pelo backbone Azure. Mais eficiente para volumes grandes. Em PowerShell, `Start-AzStorageBlobCopy` e a alternativa programatica.

</details>

### Questao 6.2
**Object Replication configurada. Blob existente na origem nao aparece no destino. Por que?**

A) Nao funciona entre regioes
B) Replica apenas blobs criados apos a regra (por padrao)
C) Blob em Archive nao replica
D) Precisa de AzCopy manual

<details>
<summary>Ver resposta</summary>

**Resposta: B) Replica apenas blobs criados apos a regra (por padrao)**

Habilite "Copy over existing blobs" para incluir blobs existentes. Object Replication funciona entre qualquer regiao.

</details>

### Questao 6.3
**CMK para Storage Account. Qual configuracao do Key Vault e OBRIGATORIA?**

A) Soft delete  B) Purge protection  C) Network firewall  D) Access policy Wrap/Unwrap

<details>
<summary>Ver resposta</summary>

**Resposta: B) Purge protection habilitado**

Garante que chaves deletadas nao sejam removidas permanentemente por 90 dias. Em PowerShell: `-EnablePurgeProtection` no `New-AzKeyVault`.

</details>

### Questao 6.4
**Diferenca entre ADE e SSE?**

A) Sao iguais
B) ADE no nivel do OS (BitLocker/DM-Crypt); SSE no storage service
C) SSE requer Key Vault
D) ADE so para Linux

<details>
<summary>Ver resposta</summary>

**Resposta: B) ADE no nivel do OS (BitLocker/DM-Crypt); SSE no nivel do storage service**

SSE e padrao em todos os managed disks. ADE usa BitLocker (Win) ou DM-Crypt (Linux). Complementares — podem ser usados juntos.

</details>

### Questao 6.5
**Acesso a File Share via Entra ID com leitura e escrita. Qual role?**

A) Storage Account Contributor
B) Storage Blob Data Contributor
C) Storage File Data SMB Share Contributor
D) Reader

<details>
<summary>Ver resposta</summary>

**Resposta: C) Storage File Data SMB Share Contributor**

Roles SMB: Reader (leitura), Contributor (leitura + escrita + exclusao), Elevated Contributor (acima + ACLs NTFS).

</details>

---

# Bloco 7 - ACR e App Service Avancado

**Tecnologia:** PowerShell (Az module) + az CLI
**Recursos criados:** 1 Azure Container Registry (Basic), 1 ACI from ACR, App Service configs
**Resource Groups:** `az104-rg8` (existente), `az104-rg7acr` (novo)

> **Pre-requisito:** Blocos 1 e 3 devem estar completos (Storage Account + App Service criados).

---

### Task 7.1: Criar Azure Container Registry

```powershell
# ============================================================
# Azure Container Registry (Basic) com admin user
# ============================================================

# CONCEITO AZ-104: ACR SKUs e diferencas (importante para a prova):
# - Basic: 10 GiB, sem webhooks avancados
# - Standard: 100 GiB, webhooks
# - Premium: 500 GiB, geo-replication, private link, CMK

$rg7acr = "az104-rg7acr"
New-AzResourceGroup -Name $rg7acr -Location "East US" -Force

$acrName = "az104acr" + (-join ((48..57) + (97..102) | Get-Random -Count 6 | ForEach-Object { [char]$_ }))
Write-Host "ACR: $acrName"

$acr = New-AzContainerRegistry `
    -ResourceGroupName $rg7acr `
    -Name $acrName `
    -Sku Basic `
    -EnableAdminUser

# Admin user: habilita username/password (dev/test)
# Em producao, use Managed Identity ou Service Principal
Write-Host "Login Server: $($acr.LoginServer)"

# Obter credenciais do admin user
$acrCreds = Get-AzContainerRegistryCredential `
    -ResourceGroupName $rg7acr `
    -Name $acrName
Write-Host "Username: $($acrCreds.Username)"
```

---

### Task 7.2: Build e push de imagem via az acr build

```powershell
# CONCEITO AZ-104: az acr build = build no cloud, sem Docker local
# Nao ha cmdlet PowerShell nativo para ACR build — usamos az CLI

# 1. Criar Dockerfile
New-Item -Path ~/acr-lab -ItemType Directory -Force | Out-Null
Set-Content -Path ~/acr-lab/Dockerfile -Value "FROM mcr.microsoft.com/hello-world"

# 2. Build no ACR
Push-Location ~/acr-lab
az acr build --registry $acrName --image sample-app:v1 --file Dockerfile .
Pop-Location

# 3. Verificar
az acr repository list --name $acrName -o table
az acr repository show-tags --name $acrName --repository sample-app -o table
```

---

### Task 7.3: Deploy ACI a partir de imagem privada do ACR

```powershell
# ============================================================
# ACI from private ACR
# ============================================================

# CONCEITO AZ-104: ACI puxa imagem de ACR privado via credenciais
# Metodos: admin user, service principal, managed identity

$acrLoginServer = $acr.LoginServer
$acrUsername = $acrCreds.Username
$acrPassword = ConvertTo-SecureString $acrCreds.Password -AsPlainText -Force
$acrCredential = New-Object System.Management.Automation.PSCredential($acrUsername, $acrPassword)

# Criar container puxando imagem do ACR
New-AzContainerGroup `
    -ResourceGroupName $rg7acr `
    -Name "az104-acr-aci" `
    -Location "East US" `
    -OsType Linux `
    -RestartPolicy Always `
    -RegistryServerDomain $acrLoginServer `
    -RegistryCredential $acrCredential `
    -Container @(
        @{
            Name = "az104-acr-aci"
            Image = "$acrLoginServer/sample-app:v1"
            RequestCpu = 1
            RequestMemoryInGb = 1
            Port = @(80)
        }
    ) `
    -IpAddressType Public `
    -Port @(80)

# Verificar
$container = Get-AzContainerGroup -ResourceGroupName $rg7acr -Name "az104-acr-aci"
Write-Host "Status: $($container.State)"
Write-Host "IP: $($container.IPAddressIP)"

# Logs
Get-AzContainerInstanceLog -ResourceGroupName $rg7acr -ContainerGroupName "az104-acr-aci"
```

---

### Task 7.4: Mapear dominio DNS customizado para App Service (walkthrough)

```powershell
# CONCEITO AZ-104: Custom domain requer CNAME (subdomain) ou A record (apex)
# + TXT record para verificacao. Free/Shared tier NAO suporta custom domains.

$appName = (Get-AzWebApp -ResourceGroupName "az104-rg8")[0].Name
Write-Host "App: $appName.azurewebsites.net"

Write-Host "`n=== PROCESSO DE CUSTOM DOMAIN ===" -ForegroundColor Cyan
Write-Host "1. DNS: CNAME www -> $appName.azurewebsites.net"
Write-Host "        TXT asuid.www -> [Verification ID do portal]"
Write-Host "2. Portal: App Service > Custom domains > + Add"
Write-Host "3. Para apex: A record -> [IP] + TXT asuid -> [ID]"

# Em PowerShell, custom domains sao gerenciados via:
# New-AzWebAppSSLBinding (para binding de certificado)
# Set-AzWebApp -HostNames @("www.contoso.com", "$appName.azurewebsites.net")
```

---

### Task 7.5: Configurar TLS/SSL no App Service

```powershell
# CONCEITO AZ-104: HTTPS Only = redirect HTTP -> HTTPS (301)
# Managed Certificate = gratis, automatico, so subdomains

# 1. Configurar HTTPS Only e TLS 1.2
Set-AzWebApp `
    -ResourceGroupName "az104-rg8" `
    -Name $appName `
    -HttpsOnly $true `
    -MinTlsVersion "1.2"

# 2. Verificar
$app = Get-AzWebApp -ResourceGroupName "az104-rg8" -Name $appName
Write-Host "HTTPS Only: $($app.HttpsOnly)"
Write-Host "Min TLS: $($app.SiteConfig.MinTlsVersion)"
```

---

### Task 7.6: Configurar backup do App Service para Storage Account

```powershell
# CONCEITO AZ-104: Backup requer Standard+. Limite 10 GB.
# Inclui codigo, config e opcionalmente banco de dados.

# 1. Criar container para backups
New-AzStorageContainer `
    -Name "webapp-backups" `
    -Context $ctx1 `
    -Permission Off

# 2. Gerar SAS para container de backup
$backupSas = New-AzStorageContainerSASToken `
    -Name "webapp-backups" `
    -Permission rwdl `
    -ExpiryTime (Get-Date).AddYears(1) `
    -Protocol HttpsOnly `
    -Context $ctx1

$backupUrl = "https://${storage1Name}.blob.core.windows.net/webapp-backups${backupSas}"

# 3. Configurar backup agendado via az CLI (mais simples)
az webapp config backup update `
    --resource-group "az104-rg8" `
    --webapp-name $appName `
    --container-url $backupUrl `
    --frequency 1d `
    --retain-one-always true `
    --retention 30

# 4. Executar backup imediato
az webapp config backup create `
    --resource-group "az104-rg8" `
    --webapp-name $appName `
    --container-url $backupUrl

# 5. Verificar
az webapp config backup list `
    --resource-group "az104-rg8" `
    --webapp-name $appName -o table

Write-Host "Verifique .zip no container webapp-backups de $storage1Name"
```

---

### Task 7.7: Configurar VNet Integration no App Service

```powershell
# CONCEITO AZ-104: VNet Integration = outbound; Private Endpoint = inbound
# Requer subnet dedicada (/28 minimo)

$vnetRg = "az104-rg4"
$vnetName = "CoreServicesVnet"

# 1. Criar subnet dedicada (delegada ao App Service)
$vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetRg -Name $vnetName -ErrorAction SilentlyContinue
if ($vnet) {
    $subnetConfig = Add-AzVirtualNetworkSubnetConfig `
        -Name "WebAppSubnet" `
        -VirtualNetwork $vnet `
        -AddressPrefix "10.20.50.0/24" `
        -Delegation @(
            @{
                Name = "webapp-delegation"
                ServiceName = "Microsoft.Web/serverFarms"
            }
        )
    $vnet | Set-AzVirtualNetwork
    Write-Host "Subnet WebAppSubnet criada"
} else {
    Write-Host "VNet $vnetName nao encontrada em $vnetRg" -ForegroundColor Yellow
}

# 2. Configurar VNet Integration via az CLI
az webapp vnet-integration add `
    --resource-group "az104-rg8" `
    --name $appName `
    --vnet $vnetName `
    --subnet WebAppSubnet

# 3. Verificar
az webapp vnet-integration list `
    --resource-group "az104-rg8" `
    --name $appName -o table

Write-Host "`nO App Service pode acessar Private Endpoints e VMs na VNet"
```

---

## Modo Desafio - Bloco 7

- [ ] Criar ACR com `New-AzContainerRegistry` (Basic + admin user)
- [ ] Executar `az acr build` para gerar imagem `sample-app:v1`
- [ ] Criar ACI com `New-AzContainerGroup` puxando imagem privada do ACR
- [ ] Explorar Custom Domain no App Service — CNAME + TXT verification
- [ ] Configurar HTTPS Only + TLS 1.2 com `Set-AzWebApp`
- [ ] Configurar backup com schedule diario para Storage Account **(Bloco 1)**
- [ ] Configurar VNet Integration com CoreServicesVnet **(Semana 1)**

---

## Questoes de Prova - Bloco 7

### Questao 7.1
**Build de imagem sem Docker local. Qual servico?**

A) ACI  B) ACR Tasks (az acr build)  C) AKS  D) App Service

<details>
<summary>Ver resposta</summary>

**Resposta: B) ACR Tasks (az acr build)**

Build no cloud, sem Docker local. Nao ha cmdlet PowerShell nativo — use `az acr build`.

</details>

### Questao 7.2
**Mapear `api.contoso.com` para App Service. Qual registro DNS?**

A) A record  B) CNAME para `*.azurewebsites.net`  C) MX record  D) SRV record

<details>
<summary>Ver resposta</summary>

**Resposta: B) CNAME para `*.azurewebsites.net`**

Subdomains = CNAME. Apex domain = A record + TXT. Em PowerShell: `Set-AzWebApp -HostNames`.

</details>

### Questao 7.3
**Qual SKU do ACR suporta geo-replicacao e Private Link?**

A) Basic  B) Standard  C) Premium  D) Todas

<details>
<summary>Ver resposta</summary>

**Resposta: C) Premium**

Basic = 10 GiB; Standard = 100 GiB; Premium = 500 GiB + geo-replication + private link + CMK.

</details>

### Questao 7.4
**VNet Integration em App Service permite o que?**

A) Inbound via IP privado  B) Outbound pela VNet  C) Deploy na VNet  D) IP publico da VNet

<details>
<summary>Ver resposta</summary>

**Resposta: B) Outbound pela VNet para acessar recursos privados**

Para inbound, use Private Endpoints. Requer subnet dedicada /28 minimo.

</details>

### Questao 7.5
**Backup automatico de App Service requer?**

A) Free + Blob  B) Standard+ + Storage Account  C) Qualquer tier + Backup vault  D) Premium + Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) Standard tier ou superior + Storage Account com container**

Limite 10 GB. Inclui codigo + config. Em PowerShell, use `New-AzWebAppBackup` ou `az webapp config backup`.

</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```powershell
# Pausar
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-win -Force
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-linux -Force
Stop-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-1
Stop-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-2
Stop-AzContainerGroup -ResourceGroupName az104-rg7acr -Name az104-acr-aci

# Retomar
Start-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-win
Start-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-linux
Start-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-1
Start-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-2
Start-AzContainerGroup -ResourceGroupName az104-rg7acr -Name az104-acr-aci
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos e IPs publicos continuam cobrando. O App Service Plan (Standard S1) cobra enquanto existir — para parar, delete o plano ou rebaixe para Free F1. Container Apps com scale-to-zero nao geram custo quando ociosas. Key Vault cobra por operacao (muito baixo custo).

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente as VMs do Bloco 2.
> Execute os comandos na ordem indicada para evitar erros de dependencia.

```powershell
# ============================================================
# CLEANUP - Remover TODOS os recursos criados
# ============================================================

# 1. Deletar Container Apps primeiro (servico mais novo, menos dependencias)
Write-Host "1. Removendo Container Apps..." -ForegroundColor Yellow
az containerapp delete --name $containerAppName --resource-group $rg10 --yes 2>$null
az containerapp env delete --name $containerAppEnvName --resource-group $rg10 --yes 2>$null
Write-Host "  Container Apps removidos"

# 2. Deletar Resource Groups (VMs primeiro por custo mais alto)
Write-Host "2. Deletando Resource Groups em background..." -ForegroundColor Yellow
Remove-AzResourceGroup -Name $rg7 -Force -AsJob      # VMs - PRIORIDADE
Remove-AzResourceGroup -Name $rg10 -Force -AsJob     # Container Apps
Remove-AzResourceGroup -Name $rg9 -Force -AsJob      # ACI
Remove-AzResourceGroup -Name $rg8 -Force -AsJob      # Web Apps
Remove-AzResourceGroup -Name $rg6 -Force -AsJob      # Storage
Remove-AzResourceGroup -Name $rg6adv -Force -AsJob   # Storage Avancado + Key Vault
Remove-AzResourceGroup -Name $rg7acr -Force -AsJob   # ACR
Write-Host "  RGs sendo deletados em background..."

# 3. Aguardar RGs serem deletados
Write-Host "`n3. Aguardando exclusao dos RGs (pode levar 5-10 minutos)..." -ForegroundColor Yellow
Get-Job | Wait-Job | Out-Null
Write-Host "  Todos os RGs deletados"

# 4. Purge Key Vault (necessario por purge protection)
Write-Host "`n4. Purge do Key Vault..." -ForegroundColor Yellow
Write-Host "  Execute: az keyvault purge --name $kvName --location eastus"
Write-Host "  Sem purge, o nome fica reservado por 90 dias"

Write-Host "`n=== CLEANUP COMPLETO ===" -ForegroundColor Green
Write-Host "Recursos removidos:"
Write-Host "  - $rg6 (Storage Account, Blob, File Share, Private Endpoint)"
Write-Host "  - $rg6adv (Storage Account 2, Key Vault, Chaves RSA)"
Write-Host "  - $rg7 (VMs, VMSS, Load Balancer, Disks, NICs)"
Write-Host "  - $rg7acr (ACR, ACI from ACR)"
Write-Host "  - $rg8 (App Service Plan, Web App, Slots)"
Write-Host "  - $rg9 (Container Instances)"
Write-Host "  - $rg10 (Container Apps Environment, Container App)"
```

---

# Key Takeaways Consolidados

## Bloco 1 - Storage (Az module)
- `New-AzStorageAccount` cria conta com `-SkuName` para redundancia e `-AccessTier` para custo
- `New-AzStorageContainer` cria blob container; `-Permission Off` para acesso privado
- `Set-AzStorageBlobContent` faz upload; `-StandardBlobTier` define tier do blob
- `New-AzRmStorageShare` cria File Share; `-AccessTier` para custo
- `New-AzStorageAccountSASToken` gera SAS; `-ExpiryTime` e `-Permission` sao essenciais
- `Set-AzStorageAccountManagementPolicy` configura lifecycle rules
- Private Endpoint + Private DNS Zone = acesso totalmente privado
- **Gotcha:** SAS Token sem permissao List nao permite listar blobs

## Bloco 2 - VMs (Az module)
- `New-AzVMConfig` + `Set-AzVMOperatingSystem` + `Set-AzVMSourceImage` + `New-AzVM` para criar VMs
- `-Zone` coloca VM em Availability Zone (SLA 99.99%); Availability Set = SLA 99.95%
- `Add-AzVMDataDisk` anexa disco sem reinicio; resize de VM requer reinicio
- `Set-AzVMCustomScriptExtension` para configuracao pos-deploy
- `New-AzVmss` com `New-AzAutoscaleSettingV2` para VMSS com autoscale
- **Gotcha:** Disco e VM devem estar na mesma Zone

## Bloco 3 - Web Apps (Az module)
- `New-AzAppServicePlan` define compute; `-Tier Standard` e minimo para slots e autoscale
- `New-AzWebApp` cria app; `New-AzWebAppSlot` cria slot para zero-downtime deploy
- `Switch-AzWebAppSlot` faz swap atomico entre slots
- `Set-AzWebAppSlotConfigName` marca settings como sticky (nao trocam no swap)
- **Gotcha:** Set-AzWebApp -AppSettings substitui TODAS as settings existentes

## Bloco 4 - ACI (Az module)
- `New-AzContainerGroup` cria containers rapidamente; sem orquestracao
- `-RestartPolicy`: Always (servers), OnFailure (retry), Never (batch)
- `SecureValue` para variaveis sensiveis (nao aparece em logs)
- Azure File Share como volume para persistencia de dados
- **Gotcha:** ACI nao tem auto-scaling — use Container Apps para isso

## Bloco 5 - Container Apps (az CLI)
- `az containerapp` (sem cmdlets PowerShell nativos)
- Environment e o "cluster gerenciado" para Container Apps
- `--min-replicas 0` = scale-to-zero (custo zero sem trafego)
- Traffic splitting entre revisions para canary deployments
- **Gotcha:** Multi-revision mode precisa estar habilitado para traffic splitting

## Bloco 6 - Storage Avancado e Disk Encryption (Az module + az CLI)
- `New-AzStorageAccountSASToken` + AzCopy para transferencias server-to-server
- `New-AzStorageBlobSASToken` para SAS granular (blob-level)
- `Update-AzStorageBlobServiceProperty` habilita versioning e change feed
- `New-AzKeyVault -EnablePurgeProtection` e OBRIGATORIO para CMK
- `Add-AzKeyVaultKey` cria chaves RSA; `-KeyOps wrapKey,unwrapKey` para CMK
- `Set-AzStorageAccount -AssignIdentity` habilita Managed Identity para CMK
- ADE: use `az vm encryption enable` (mais simples que PS para KEK)
- **Gotcha:** AzCopy nao tem cmdlet PowerShell nativo — use o executavel diretamente

## Bloco 7 - ACR e App Service Avancado (Az module + az CLI)
- `New-AzContainerRegistry -EnableAdminUser` cria ACR; admin user e para dev/test
- `az acr build` para build no cloud (sem cmdlet PS nativo)
- `New-AzContainerGroup -RegistryCredential` para ACI from ACR privado
- `Set-AzWebApp -HttpsOnly $true -MinTlsVersion "1.2"` para TLS
- `az webapp config backup` para backup (sem cmdlet PS simples equivalente)
- `az webapp vnet-integration add` para VNet Integration
- **Gotcha:** Varios recursos avancados requerem az CLI mesmo em workflow PowerShell

## Resumo de Cmdlets por Categoria

| Categoria | Cmdlet principal | Modulo |
|-----------|-----------------|--------|
| Storage Account | `New-AzStorageAccount` | Az |
| Blob Container | `New-AzStorageContainer` | Az |
| Blob Upload | `Set-AzStorageBlobContent` | Az |
| File Share | `New-AzRmStorageShare` | Az |
| SAS Token (Account) | `New-AzStorageAccountSASToken` | Az |
| SAS Token (Blob) | `New-AzStorageBlobSASToken` | Az |
| Lifecycle | `Set-AzStorageAccountManagementPolicy` | Az |
| Versioning/ChangeFeed | `Update-AzStorageBlobServiceProperty` | Az |
| Private Endpoint | `New-AzPrivateEndpoint` | Az |
| Private DNS | `New-AzPrivateDnsZone` + `New-AzPrivateDnsVirtualNetworkLink` | Az |
| Network Rules | `Update-AzStorageAccountNetworkRuleSet` | Az |
| Key Vault | `New-AzKeyVault` | Az |
| Key Vault Keys | `Add-AzKeyVaultKey` | Az |
| Key Vault RBAC | `New-AzRoleAssignment` | Az |
| VM | `New-AzVMConfig` + `New-AzVM` | Az |
| VM Disk | `New-AzDiskConfig` + `New-AzDisk` + `Add-AzVMDataDisk` | Az |
| VM Disk Encryption | `Get-AzVMDiskEncryptionStatus` / `az vm encryption enable` | Az / CLI |
| VM Extension | `Set-AzVMCustomScriptExtension` | Az |
| VMSS | `New-AzVmssConfig` + `New-AzVmss` | Az |
| Autoscale | `New-AzAutoscaleSettingV2` | Az |
| App Service Plan | `New-AzAppServicePlan` | Az |
| Web App | `New-AzWebApp` | Az |
| Web App TLS | `Set-AzWebApp -HttpsOnly -MinTlsVersion` | Az |
| Web App Backup | `az webapp config backup` | az CLI |
| Web App VNet | `az webapp vnet-integration add` | az CLI |
| Deployment Slot | `New-AzWebAppSlot` + `Switch-AzWebAppSlot` | Az |
| ACR | `New-AzContainerRegistry` | Az |
| ACR Build | `az acr build` | az CLI |
| ACI | `New-AzContainerGroup` | Az |
| ACI from ACR | `New-AzContainerGroup -RegistryCredential` | Az |
| ACI Logs | `Get-AzContainerInstanceLog` | Az |
| Container Apps | `az containerapp` | az CLI |
| Container Apps Env | `az containerapp env` | az CLI |
| Traffic Split | `az containerapp ingress traffic set` | az CLI |
