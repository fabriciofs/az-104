# Lab AZ-104 - Semana 3: Tudo via PowerShell

> **Pre-requisitos:**
> - Assinatura Azure ativa com permissoes de Owner/Contributor
> - **Azure Cloud Shell (PowerShell)** via portal Azure (`portal.azure.com` → icone `>_`)
>   - Modulo `Az` ja vem pre-instalado
>   - Autenticacao ja esta feita (nao precisa de `Connect-AzAccount`)
>
> **Objetivo:** Reproduzir **todo** o lab de Backup, Site Recovery e Monitoramento usando exclusivamente PowerShell.
> Cada comando e fortemente comentado para aprendizado.

---

## Pre-requisitos: Cloud Shell e Conexao

> **Ambiente:** Todos os comandos deste lab sao executados no **Azure Cloud Shell (PowerShell)**,
> acessivel diretamente pelo portal Azure (`portal.azure.com` → icone `>_` na barra superior).
>
> O Cloud Shell ja possui o modulo `Az` pre-instalado e a autenticacao
> e automatica (nao precisa de `Connect-AzAccount`). Basta selecionar **PowerShell** como ambiente.
>
> **Dependencia:** Este lab assume que as VMs e Storage Account da **Semana 2** (storage-compute)
> ainda existem. Caso contrario, recrie-os antes de iniciar.

```powershell
# ============================================================
# PRE-REQUISITOS - Verificar ambiente no Cloud Shell
# ============================================================

# 1. Verificar que esta no Cloud Shell (PowerShell)
#    O prompt deve mostrar PS /home/<usuario>>
Get-AzContext                      # Mostra subscription ativa (ja autenticado!)

# 2. Verificar que o modulo Az.RecoveryServices esta disponivel
#    Este modulo e necessario para Backup e Site Recovery
Get-Module -ListAvailable Az.RecoveryServices | Select-Object Name, Version

# 3. Verificar que o modulo Az.Monitor esta disponivel
#    Este modulo e necessario para alertas e diagnosticos
Get-Module -ListAvailable Az.Monitor | Select-Object Name, Version

# 4. Verificar que o modulo Az.OperationalInsights esta disponivel
#    Este modulo e necessario para Log Analytics
Get-Module -ListAvailable Az.OperationalInsights | Select-Object Name, Version

# 5. Verificar recursos da Semana 2
#    VM Windows e Storage Account devem existir
Get-AzVM -ResourceGroupName "rg-contoso-compute" -Name "vm-web-01" -ErrorAction SilentlyContinue |
    Select-Object Name, Location, ProvisioningState
```

---

## Variaveis Globais

> **IMPORTANTE:** Ajuste os valores marcados com `# ← ALTERE` antes de executar.
> Todos os outros valores sao usados consistentemente ao longo do lab.

```powershell
# ============================================================
# VARIAVEIS GLOBAIS - Defina TODAS antes de iniciar
# ============================================================

# --- Configuracoes da subscription (ALTERE estes valores) ---
$subscriptionId = "00000000-0000-0000-0000-000000000000" # ← ALTERE: sua subscription ID
$location       = "eastus"
$locationDR     = "westus"                               # Regiao de DR para Site Recovery

# --- Backup (Blocos 1-2) ---
$rg11       = "rg-contoso-management"
$vaultName  = "rsv-contoso-backup"
$policyName = "rsvpol-contoso-12h"

# --- Site Recovery (Bloco 3) ---
$rg12          = "rg-contoso-management"
$vaultNameDR   = "rsv-contoso-dr-westus"
$fabricSource  = "fabric-contoso-source"
$fabricTarget  = "fabric-contoso-target"

# --- Monitor (Blocos 4-5) ---
$rg13             = "rg-contoso-management"
$workspaceName    = "law-contoso-prod"
$actionGroupName  = "ag-contoso-ops"
$alertRuleName    = "alert-vm-web-01-cpu"

# --- Referencia a recursos existentes (Semana 2) ---
$vmRg       = "rg-contoso-compute"                                # RG das VMs da Semana 2
$vmName     = "vm-web-01"                              # VM Windows da Semana 2
$storageRg  = "rg-contoso-storage"                                 # RG do Storage da Semana 2

# --- Email para alertas (ALTERE) ---
$alertEmail = "seuemail@exemplo.com"                      # ← ALTERE: email para receber alertas
```

---

## Mapa de Dependencias

```
Bloco 1 (VM Backup) ←── Depende de VM da Semana 2
  │
  ├─ rg-contoso-management ─────────────────────────────────┐
  ├─ rsv-contoso-backup (Recovery Services Vault) ─────────┤
  ├─ rsvpol-contoso-12h (Custom Policy) ─────────┤
  ├─ Enable backup na VM vm-web-01 ────────────┤
  ├─ Backup on-demand ────────────────────────────┤
  └─ Restore VM (listar pontos de recuperacao) ───┤
                                                  │
                                                  ▼
Bloco 2 (File/Blob Protection) ←── Depende de Storage da Semana 2
  │
  ├─ Backup de Azure File Share ──────────────────┤
  ├─ Soft delete para blobs ──────────────────────┤
  ├─ Blob versioning ────────────────────────────┤
  └─ Point-in-time restore ──────────────────────┤
                                                  │
                                                  ▼
Bloco 3 (Site Recovery) ←── Depende de VM da Semana 2
  │
  ├─ rg-contoso-management ─────────────────────────────────┐
  ├─ rsv-contoso-dr-westus (Vault na regiao DR) ──────────┤
  ├─ ASR Fabric (source + target) ───────────────┤
  ├─ Protection Container ───────────────────────┤
  ├─ Replication Protected Item ─────────────────┤
  ├─ Recovery Plan ──────────────────────────────┤
  └─ Test Failover + Cleanup ────────────────────┤
                                                  │
                                                  ▼
Bloco 4 (Azure Monitor & Alerts) ←── Depende de VM da Semana 2
  │
  ├─ rg-contoso-management ─────────────────────────────────┐
  ├─ Action Group (email) ───────────────────────┤
  ├─ Metric Alert (CPU > 80%) ───────────────────┤
  ├─ Diagnostic Settings ────────────────────────┤
  └─ Dashboard ──────────────────────────────────┤
                                                  │
                                                  ▼
Bloco 5 (Log Analytics & Insights) ←── Depende de Blocos 4
  │
  ├─ law-contoso-prod (Log Analytics Workspace) ────────┤
  ├─ AMA Agent na VM ────────────────────────────┤
  ├─ KQL queries ────────────────────────────────┤
  ├─ VM Insights ────────────────────────────────┤
  └─ Network Watcher + Connection Monitor ───────┤
```

---

# Bloco 1 - VM Backup

**Tecnologia:** Az.RecoveryServices PowerShell module
**Recursos criados:** 1 Resource Group, 1 Recovery Services Vault, 1 Custom Backup Policy, backup protection na VM

> **Conceito:** O Azure Backup usa **Recovery Services Vaults** para armazenar pontos de recuperacao.
> O vault deve estar na **mesma regiao** que os recursos protegidos.
> Backup policies definem a frequencia (schedule) e retencao (retention) dos backups.

---

### Task 1.1: Criar Resource Group e Recovery Services Vault

> **Cobranca:** O vault em si e gratuito, mas cada instancia protegida (VM, File Share) gera cobranca.

```powershell
# ============================================================
# TASK 1.1 - Criar RG e Recovery Services Vault
# ============================================================

# Criar Resource Group para recursos de backup
# Este RG contera o vault e as policies
New-AzResourceGroup -Name $rg11 -Location $location
Write-Host "Criado Resource Group: $rg11"

# New-AzRecoveryServicesVault: cria um Recovery Services Vault
# O vault e o container central para todos os dados de backup
# -Location: DEVE ser a mesma regiao dos recursos protegidos
# Tipos de redundancia de storage:
#   - GeoRedundant (GRS): padrao, replica para regiao pareada (recomendado producao)
#   - LocallyRedundant (LRS): mais barato, sem replicacao geo
#   - ZoneRedundant (ZRS): replicas em availability zones
$vault = New-AzRecoveryServicesVault `
    -ResourceGroupName $rg11 `
    -Name $vaultName `
    -Location $location

Write-Host "Vault criado: $($vault.Name) em $($vault.Location)"

# Verificar propriedades do vault
Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rg11 |
    Select-Object Name, Location, ResourceGroupName, ProvisioningState
```

> **Dica AZ-104:** Na prova, atente-se a localizacao do vault. Ele DEVE estar na mesma regiao
> dos recursos que voce quer proteger (exceto para Site Recovery, onde o vault fica na regiao DR).

---

### Task 1.2: Configurar contexto do vault e redundancia

```powershell
# ============================================================
# TASK 1.2 - Configurar contexto e redundancia do vault
# ============================================================

# Set-AzRecoveryServicesVaultContext: define o vault como contexto atual
# Todos os cmdlets subsequentes usarao este vault automaticamente
# IMPORTANTE: deve ser chamado ANTES de qualquer operacao no vault
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rg11
Set-AzRecoveryServicesVaultContext -Vault $vault

Write-Host "Contexto definido para vault: $($vault.Name)"

# Set-AzRecoveryServicesBackupProperty: configura propriedades do vault
# -BackupStorageRedundancy: tipo de redundancia do storage do vault
#   GeoRedundant: dados replicados para regiao pareada (mais caro, mais seguro)
#   LocallyRedundant: dados apenas na mesma regiao (mais barato)
#   ZoneRedundant: dados em diferentes availability zones
# IMPORTANTE: so pode ser alterado ANTES do primeiro backup ser configurado!
Set-AzRecoveryServicesBackupProperty `
    -Vault $vault `
    -BackupStorageRedundancy "LocallyRedundant"

Write-Host "Redundancia configurada como LocallyRedundant (LRS)"

# Verificar configuracao
$backupProp = Get-AzRecoveryServicesBackupProperty -Vault $vault
Write-Host "Storage Redundancy: $($backupProp.BackupStorageRedundancy)"
```

> **Conceito:** A redundancia do vault so pode ser alterada ANTES de registrar qualquer item
> de backup. Apos o primeiro backup, a configuracao e permanente.

---

### Task 1.3: Criar custom backup policy

```powershell
# ============================================================
# TASK 1.3 - Criar custom backup policy para VMs
# ============================================================

# Get-AzRecoveryServicesBackupSchedulePolicyObject: obtem objeto de schedule padrao
# WorkloadType: tipo de recurso (AzureVM, AzureFiles, MSSQL, etc.)
# BackupManagementType: tipo de gerenciamento (AzureIaasVM, AzureStorage, etc.)
$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject `
    -WorkloadType "AzureVM" `
    -BackupManagementType "AzureIaasVM"

# Configurar schedule: backup diario as 23:00 UTC
# ScheduleRunFrequency: Daily ou Weekly
# ScheduleRunTimes: horario do backup (UTC)
$schedulePolicy.ScheduleRunFrequency = "Daily"
$schedulePolicy.ScheduleRunTimes[0] = (Get-Date "2024-01-01T23:00:00Z").ToUniversalTime()

Write-Host "Schedule configurado: Daily as 23:00 UTC"

# Get-AzRecoveryServicesBackupRetentionPolicyObject: obtem objeto de retencao padrao
$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject `
    -WorkloadType "AzureVM" `
    -BackupManagementType "AzureIaasVM"

# Configurar retencao diaria: manter por 30 dias (padrao e 30)
# IsDailyScheduleEnabled: habilita retencao diaria
# DailySchedule.DurationCountInDays: dias de retencao
$retentionPolicy.IsDailyScheduleEnabled = $true
$retentionPolicy.DailySchedule.DurationCountInDays = 30

# Configurar retencao semanal: manter 4 semanas (backup de domingo)
$retentionPolicy.IsWeeklyScheduleEnabled = $true
$retentionPolicy.WeeklySchedule.DurationCountInWeeks = 4
$retentionPolicy.WeeklySchedule.DaysOfTheWeek = @("Sunday")

# Configurar retencao mensal: manter 6 meses (primeiro domingo do mes)
$retentionPolicy.IsMonthlyScheduleEnabled = $true
$retentionPolicy.MonthlySchedule.DurationCountInMonths = 6
$retentionPolicy.MonthlySchedule.RetentionScheduleFormatType = "Weekly"
$retentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = @("Sunday")
$retentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = @("First")

Write-Host "Retencao configurada: 30 dias, 4 semanas, 6 meses"

# New-AzRecoveryServicesBackupProtectionPolicy: cria a policy customizada
# -Name: nome unico da policy no vault
# -WorkloadType: tipo de workload protegido
# -SchedulePolicy: objeto de schedule configurado
# -RetentionPolicy: objeto de retencao configurado
$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType "AzureVM" `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy `
    -VaultId $vault.ID

Write-Host "Policy criada: $($policy.Name)"

# Verificar policy criada
Get-AzRecoveryServicesBackupProtectionPolicy -Name $policyName -VaultId $vault.ID |
    Select-Object Name, WorkloadType
```

> **Conceito:** Policies definem QUANDO (schedule) e POR QUANTO TEMPO (retention) manter backups.
> Uma policy pode proteger multiplas VMs. Voce pode ter varias policies no mesmo vault.
> Na prova, preste atencao nas opcoes de retencao: diaria, semanal, mensal e anual.

---

### Task 1.4: Habilitar backup na VM

> **Cobranca:** Habilitar backup gera cobranca por instancia protegida e armazenamento de snapshots.

```powershell
# ============================================================
# TASK 1.4 - Habilitar backup na VM vm-web-01
# ============================================================

# Obter a policy criada
$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -VaultId $vault.ID

# Enable-AzRecoveryServicesBackupProtection: habilita backup para um recurso
# -ResourceGroupName: RG da VM (NAO do vault)
# -Name: nome da VM
# -Policy: policy de backup a aplicar
# -VaultId: ID do vault
# NOTA: A VM DEVE estar na mesma regiao do vault
Enable-AzRecoveryServicesBackupProtection `
    -ResourceGroupName $vmRg `
    -Name $vmName `
    -Policy $policy `
    -VaultId $vault.ID

Write-Host "Backup habilitado para VM $vmName com policy $policyName"

# Verificar status do backup
# Get-AzRecoveryServicesBackupItem: lista itens protegidos
# -WorkloadType: filtro por tipo de workload
# -BackupManagementType: filtro por tipo de gerenciamento
$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType "AzureVM" `
    -FriendlyName $vmName `
    -VaultId $vault.ID

$backupItem = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType "AzureVM" `
    -VaultId $vault.ID

Write-Host "Status: $($backupItem.ProtectionStatus)"
Write-Host "Policy: $($backupItem.ProtectionPolicyName)"
Write-Host "Health: $($backupItem.HealthStatus)"
```

> **Conexao com Semana 2:** A VM `vm-web-01` foi criada na Semana 2 (storage-compute).
> O backup protege a VM inteira, incluindo OS disk e data disks.

---

### Task 1.5: Executar backup on-demand

```powershell
# ============================================================
# TASK 1.5 - Executar backup on-demand (ad-hoc)
# ============================================================

# Obter o backup item (referencia a VM protegida)
$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType "AzureVM" `
    -FriendlyName $vmName `
    -VaultId $vault.ID

$backupItem = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType "AzureVM" `
    -VaultId $vault.ID

# Backup-AzRecoveryServicesBackupItem: dispara backup imediato
# -ExpiryDateTimeUTC: data de expiracao do recovery point ad-hoc
#   Recovery points on-demand tem retencao separada da policy
#   Aqui definimos 30 dias a partir de agora
$expiryDate = (Get-Date).AddDays(30).ToUniversalTime()

$backupJob = Backup-AzRecoveryServicesBackupItem `
    -Item $backupItem `
    -ExpiryDateTimeUTC $expiryDate `
    -VaultId $vault.ID

Write-Host "Backup on-demand iniciado!"
Write-Host "Job ID: $($backupJob.JobId)"
Write-Host "Status: $($backupJob.Status)"

# Monitorar o progresso do job
# Wait-AzRecoveryServicesBackupJob: aguarda conclusao do job
# NOTA: O primeiro backup pode levar 30-60 minutos dependendo do tamanho da VM
Write-Host "`nAguardando backup (pode levar 30-60 min)..."
Write-Host "Para verificar progresso, use:"
Write-Host "  Get-AzRecoveryServicesBackupJob -JobId '$($backupJob.JobId)' -VaultId '$($vault.ID)'"
```

> **Dica AZ-104:** Backups on-demand sao uteis antes de operacoes de manutencao (updates, resize).
> O primeiro backup (initial backup) e sempre completo; subsequentes sao incrementais.

---

### Task 1.6: Listar recovery points e restaurar VM

```powershell
# ============================================================
# TASK 1.6 - Listar recovery points e restaurar VM
# ============================================================

# Obter o backup item
$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType "AzureVM" `
    -FriendlyName $vmName `
    -VaultId $vault.ID

$backupItem = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType "AzureVM" `
    -VaultId $vault.ID

# Get-AzRecoveryServicesBackupRecoveryPoint: lista pontos de recuperacao
# -StartDate/-EndDate: filtro por periodo
# Cada recovery point e um snapshot consistente da VM
$startDate = (Get-Date).AddDays(-30).ToUniversalTime()
$endDate = (Get-Date).ToUniversalTime()

$recoveryPoints = Get-AzRecoveryServicesBackupRecoveryPoint `
    -Item $backupItem `
    -StartDate $startDate `
    -EndDate $endDate `
    -VaultId $vault.ID

Write-Host "=== Recovery Points encontrados: $($recoveryPoints.Count) ==="
$recoveryPoints | Select-Object RecoveryPointId, RecoveryPointTime, RecoveryPointType |
    Format-Table -AutoSize

# Restaurar VM a partir do recovery point mais recente
# Restore-AzRecoveryServicesBackupItem: restaura a partir de um recovery point
# -RecoveryPoint: ponto de recuperacao selecionado
# -StorageAccountName: storage account temporaria para staging
# -StorageAccountResourceGroupName: RG da storage account
# -TargetResourceGroupName: RG onde a VM restaurada sera criada
#
# Opcoes de restore:
#   CreateVirtualMachine: cria VM nova a partir do backup
#   RestoreDisks: restaura apenas os discos (para customizar antes de recriar VM)
if ($recoveryPoints.Count -gt 0) {
    $latestRP = $recoveryPoints[0]  # Mais recente

    # NOTA: Para restaurar, precisamos de uma storage account para staging
    # Usamos a storage account da Semana 2
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $storageRg |
        Select-Object -First 1

    if ($storageAcct) {
        Write-Host "`nIniciando restore dos discos a partir do RP: $($latestRP.RecoveryPointTime)"

        $restoreJob = Restore-AzRecoveryServicesBackupItem `
            -RecoveryPoint $latestRP `
            -StorageAccountName $storageAcct.StorageAccountName `
            -StorageAccountResourceGroupName $storageRg `
            -TargetResourceGroupName $vmRg `
            -VaultId $vault.ID `
            -VaultLocation $location

        Write-Host "Restore job iniciado: $($restoreJob.JobId)"
        Write-Host "Status: $($restoreJob.Status)"
        Write-Host "`nPara monitorar:"
        Write-Host "  Get-AzRecoveryServicesBackupJob -JobId '$($restoreJob.JobId)' -VaultId '$($vault.ID)'"
    } else {
        Write-Host "Nenhuma storage account encontrada em $storageRg para staging" -ForegroundColor Yellow
    }
} else {
    Write-Host "Nenhum recovery point encontrado. Aguarde o backup on-demand concluir." -ForegroundColor Yellow
}
```

> **Conceito:** Ha dois tipos de restore para VMs:
> - **Create Virtual Machine:** cria uma VM nova completa a partir do backup
> - **Restore Disks:** restaura apenas os discos em uma storage account (voce recria a VM manualmente)
> Na prova, `Restore Disks` e usado quando voce precisa customizar a VM antes de recria-la.

---

### Task 1.6b: Cross Region Restore (CRR)

```powershell
# ============================================================
# TASK 1.6b - Configurar Cross Region Restore
# ============================================================
# IMPORTANTE: Deve ser feito ANTES de proteger qualquer item no vault.
# Nao e possivel alterar de LRS para GRS apos o primeiro backup.

# Set-AzRecoveryServicesBackupProperty: configura propriedades do vault
# -BackupStorageRedundancy: LocallyRedundant, GeoRedundant, ZoneRedundant
# -EnableCrossRegionRestore: habilita restauracao na regiao pareada
Set-AzRecoveryServicesBackupProperty `
    -Vault $vault `
    -BackupStorageRedundancy GeoRedundant `
    -EnableCrossRegionRestore $true

# Verificar configuracao
$vaultProperties = Get-AzRecoveryServicesBackupProperty -Vault $vault
Write-Host "Redundancia: $($vaultProperties.BackupStorageRedundancy)"
Write-Host "Cross Region Restore: $($vaultProperties.CrossRegionRestore)"

Write-Host "`nVault configurado com GRS + Cross Region Restore"
Write-Host "Dados serao replicados para a regiao pareada"
```

> **Conceito AZ-104 — GRS e CRR:**
> - **GRS** (Geo-Redundant Storage): replica dados para a regiao pareada do Azure
> - **CRR** (Cross Region Restore): permite restaurar backups na regiao secundaria
> - GRS custa mais que LRS (~2x), mas habilita DR cross-region
> - Na prova: "restaurar VM em outra regiao" = GRS + CRR habilitados no vault

---

## Modo Desafio - Bloco 1

- [ ] Criar Recovery Services Vault no mesmo RG e regiao da VM
- [ ] Configurar redundancia do vault como LocallyRedundant
- [ ] Criar custom backup policy com retencao: 30 dias, 4 semanas, 6 meses
- [ ] Habilitar backup na VM `vm-web-01` com a policy customizada
- [ ] Executar backup on-demand com expiracao de 30 dias
- [ ] Listar recovery points com `Get-AzRecoveryServicesBackupRecoveryPoint`
- [ ] Entender as opcoes de restore: CreateVirtualMachine vs RestoreDisks

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Voce precisa configurar backup para uma VM no East US. Em qual regiao o Recovery Services Vault deve estar?**

A) Qualquer regiao
B) West US (regiao pareada)
C) East US (mesma regiao da VM)
D) Central US (regiao mais proxima)

<details>
<summary>Ver resposta</summary>

**Resposta: C) East US (mesma regiao da VM)**

O Recovery Services Vault para backup de VMs deve estar na **mesma regiao** dos recursos protegidos. Para Site Recovery (DR), o vault fica na regiao de destino.

</details>

### Questao 1.2
**Voce configurou um backup com retencao diaria de 30 dias e semanal de 4 semanas. Um backup diario de segunda-feira tambem e um ponto semanal. Quantas copias sao mantidas desse ponto?**

A) 2 copias separadas
B) 1 copia com a maior retencao aplicada
C) 1 copia com a menor retencao aplicada
D) Depende da policy

<details>
<summary>Ver resposta</summary>

**Resposta: B) 1 copia com a maior retencao aplicada**

O Azure Backup nao duplica dados. Se um ponto de recuperacao se qualifica para multiplas retencoes (diaria E semanal), a **maior retencao** e aplicada.

</details>

### Questao 1.3
**Voce precisa restaurar uma VM mas quer alterar o tamanho (size) antes de recria-la. Qual opcao de restore voce deve usar?**

A) Create Virtual Machine
B) Restore Disks
C) Replace Existing
D) Cross Region Restore

<details>
<summary>Ver resposta</summary>

**Resposta: B) Restore Disks**

**Restore Disks** restaura os discos para uma storage account, permitindo customizar (tamanho, rede, etc.) antes de recriar a VM manualmente. **Create Virtual Machine** recria automaticamente sem opcao de customizacao.

</details>

---

# Bloco 2 - File/Blob Protection

**Tecnologia:** Az.RecoveryServices + Az.Storage PowerShell modules
**Recursos criados:** Backup de File Share, Soft Delete para blobs, Point-in-time restore

> **Conceito:** Alem de VMs, o Azure Backup protege Azure File Shares.
> Para Blob Storage, a protecao usa recursos nativos: Soft Delete, Versioning e Point-in-time Restore.
> Essas features sao configuradas na Storage Account, NAO no Recovery Services Vault.

---

### Task 2.1: Backup de Azure File Share

```powershell
# ============================================================
# TASK 2.1 - Habilitar backup de Azure File Share
# ============================================================

# Obter a storage account da Semana 2
$storageAcct = Get-AzStorageAccount -ResourceGroupName $storageRg |
    Select-Object -First 1

if (-not $storageAcct) {
    Write-Host "ERRO: Nenhuma storage account encontrada em $storageRg" -ForegroundColor Red
    Write-Host "Recrie os recursos da Semana 2 antes de continuar."
    return
}

$storageAccountName = $storageAcct.StorageAccountName
Write-Host "Storage Account encontrada: $storageAccountName"

# Listar file shares existentes
$ctx = $storageAcct.Context
$fileShares = Get-AzStorageShare -Context $ctx
Write-Host "File Shares: $($fileShares.Count)"
$fileShares | Select-Object Name | Format-Table

# Usar o vault do Bloco 1 (mesmo vault pode proteger VMs e File Shares)
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rg11
Set-AzRecoveryServicesVaultContext -Vault $vault

# Registrar a storage account no vault
# Register-AzRecoveryServicesBackupContainer: registra a source dos dados
# O vault precisa "conhecer" a storage account antes de proteger seus file shares
Register-AzRecoveryServicesBackupContainer `
    -ResourceId $storageAcct.Id `
    -BackupManagementType "AzureStorage" `
    -WorkloadType "AzureFiles" `
    -VaultId $vault.ID `
    -Force

Write-Host "Storage Account registrada no vault"

# Obter policy padrao para Azure Files (ou criar uma custom)
# O vault cria uma "DefaultPolicy" para AzureFiles automaticamente
$filePolicy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType "AzureFiles" `
    -VaultId $vault.ID |
    Select-Object -First 1

if (-not $filePolicy) {
    # Criar policy padrao para file shares
    $schedPolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject `
        -WorkloadType "AzureFiles" `
        -BackupManagementType "AzureStorage"

    $retPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject `
        -WorkloadType "AzureFiles" `
        -BackupManagementType "AzureStorage"

    $filePolicy = New-AzRecoveryServicesBackupProtectionPolicy `
        -Name "fspol-contoso-daily" `
        -WorkloadType "AzureFiles" `
        -SchedulePolicy $schedPolicy `
        -RetentionPolicy $retPolicy `
        -VaultId $vault.ID

    Write-Host "Policy para File Shares criada: $($filePolicy.Name)"
}

# Habilitar backup para cada file share encontrado
if ($fileShares.Count -gt 0) {
    $shareName = $fileShares[0].Name
    Write-Host "`nHabilitando backup para file share: $shareName"

    # Enable-AzRecoveryServicesBackupProtection: protege o file share
    # -StorageAccountName: nome da storage account (NAO o ID)
    # -Name: nome do file share
    Enable-AzRecoveryServicesBackupProtection `
        -StorageAccountName $storageAccountName `
        -Name $shareName `
        -Policy $filePolicy `
        -VaultId $vault.ID

    Write-Host "Backup habilitado para file share: $shareName"
} else {
    Write-Host "Nenhum file share encontrado. Crie um file share na storage account da Semana 2." -ForegroundColor Yellow
}
```

> **Conceito:** File Share backup usa snapshots. Cada backup cria um snapshot do share inteiro.
> Restore pode ser do share completo ou de arquivos individuais.
> O vault usa a mesma infraestrutura de VMs, mas com WorkloadType "AzureFiles".

---

### Task 2.2: Configurar Soft Delete para blobs

```powershell
# ============================================================
# TASK 2.2 - Habilitar Soft Delete para blobs
# ============================================================

# Obter a storage account
$storageAcct = Get-AzStorageAccount -ResourceGroupName $storageRg |
    Select-Object -First 1

# Enable-AzStorageBlobDeleteRetentionPolicy: habilita soft delete para blobs
# -RetentionDays: dias que blobs deletados ficam retidos (1-365)
# Blobs deletados ficam no estado "soft deleted" e podem ser recuperados
# IMPORTANTE: Soft delete protege contra delecao acidental, NAO contra sobrescrita
#   Para proteger contra sobrescrita, habilite VERSIONING
Enable-AzStorageBlobDeleteRetentionPolicy `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName `
    -RetentionDays 14 `
    -Enable $true

Write-Host "Soft Delete habilitado: 14 dias de retencao"

# Verificar configuracao
$blobServiceProps = Get-AzStorageBlobServiceProperty `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName

Write-Host "Soft Delete Enabled: $($blobServiceProps.DeleteRetentionPolicy.Enabled)"
Write-Host "Retention Days: $($blobServiceProps.DeleteRetentionPolicy.Days)"
```

> **Dica AZ-104:** Soft Delete para blobs e **diferente** de Soft Delete para containers.
> Ambos devem ser habilitados separadamente. Na prova, atente-se a qual tipo de soft delete
> e necessario.

---

### Task 2.3: Habilitar Container Soft Delete

```powershell
# ============================================================
# TASK 2.3 - Habilitar Soft Delete para containers
# ============================================================

# Container soft delete permite recuperar containers inteiros
# que foram deletados acidentalmente
# -RetentionDays: dias de retencao (1-365)
Enable-AzStorageContainerDeleteRetentionPolicy `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName `
    -RetentionDays 7 `
    -Enable $true

Write-Host "Container Soft Delete habilitado: 7 dias de retencao"
```

---

### Task 2.4: Habilitar Blob Versioning

```powershell
# ============================================================
# TASK 2.4 - Habilitar Blob Versioning
# ============================================================

# Blob Versioning mantém versoes anteriores automaticamente
# quando um blob e sobrescrito ou modificado
# DIFERENCA de Soft Delete:
#   Soft Delete = protege contra DELECAO
#   Versioning = protege contra SOBRESCRITA (mantem versoes anteriores)
# Ambos devem ser habilitados para protecao completa!

# Update-AzStorageBlobServiceProperty: atualiza propriedades do blob service
Update-AzStorageBlobServiceProperty `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName `
    -IsVersioningEnabled $true

Write-Host "Blob Versioning habilitado"

# Verificar
$blobServiceProps = Get-AzStorageBlobServiceProperty `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName

Write-Host "Versioning Enabled: $($blobServiceProps.IsVersioningEnabled)"
```

> **Conceito:** Blob Versioning e essencial para protecao contra sobrescrita acidental.
> Cada modificacao cria uma nova versao. Versoes anteriores podem ser promovidas a versao atual.

---

### Task 2.5: Habilitar Point-in-Time Restore para blobs

```powershell
# ============================================================
# TASK 2.5 - Habilitar Point-in-Time Restore
# ============================================================

# Point-in-Time Restore permite restaurar blobs para um estado anterior
# PRE-REQUISITOS (devem estar habilitados ANTES):
#   1. Blob Versioning (habilitado na Task 2.4)
#   2. Blob Soft Delete (habilitado na Task 2.2)
#   3. Change Feed (habilitado automaticamente)
# NOTA: Point-in-Time Restore so funciona com blobs em containers QUENTES (Hot tier)

# Habilitar Change Feed (pre-requisito para Point-in-Time Restore)
Update-AzStorageBlobServiceProperty `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName `
    -EnableChangeFeed $true

Write-Host "Change Feed habilitado"

# Enable-AzStorageBlobRestorePolicy: habilita Point-in-Time Restore
# -RestoreDays: janela de restauracao (deve ser MENOR que soft delete retention)
#   Se soft delete = 14 dias, restore deve ser < 14 dias
Enable-AzStorageBlobRestorePolicy `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName `
    -RestoreDays 13

Write-Host "Point-in-Time Restore habilitado: 13 dias"

# Verificar todas as configuracoes de protecao
$blobServiceProps = Get-AzStorageBlobServiceProperty `
    -ResourceGroupName $storageRg `
    -StorageAccountName $storageAcct.StorageAccountName

Write-Host "`n=== Protecao de Blobs Configurada ==="
Write-Host "Soft Delete:          $($blobServiceProps.DeleteRetentionPolicy.Enabled) ($($blobServiceProps.DeleteRetentionPolicy.Days) dias)"
Write-Host "Versioning:           $($blobServiceProps.IsVersioningEnabled)"
Write-Host "Change Feed:          $($blobServiceProps.ChangeFeed.Enabled)"
Write-Host "Point-in-Time Restore: $($blobServiceProps.RestorePolicy.Enabled) ($($blobServiceProps.RestorePolicy.Days) dias)"
```

> **Conceito:** A hierarquia de protecao de blobs no Azure:
> 1. **Soft Delete** → protege contra delecao acidental
> 2. **Versioning** → protege contra sobrescrita
> 3. **Point-in-Time Restore** → restaura container inteiro para estado anterior
> Cada nivel requer o anterior. Point-in-Time Restore e o mais poderoso mas requer todos.

---

### Task 2.6: Restaurar container (simulacao)

```powershell
# ============================================================
# TASK 2.6 - Restaurar container usando Point-in-Time Restore
# ============================================================

# NOTA: Este comando so funciona se houver blobs e alteracoes
# rastreadas pelo Change Feed. Aqui demonstramos a sintaxe.

# Restore-AzStorageBlobRange: restaura blobs para um ponto no tempo
# -TimeToRestore: datetime do ponto de restauracao (UTC)
# -BlobRestoreRange: range de blobs a restaurar (prefixo)
#   "" a "" = todos os blobs

# Exemplo: restaurar todos os blobs de 1 hora atras
$restoreTime = (Get-Date).AddHours(-1).ToUniversalTime()

# Criar range de restauracao (todos os blobs)
$blobRange = New-AzStorageBlobRangeToRestore -StartRange "" -EndRange ""

Write-Host "Exemplo de comando de restore (NAO executado):"
Write-Host @"
Restore-AzStorageBlobRange ``
    -ResourceGroupName $storageRg ``
    -StorageAccountName $($storageAcct.StorageAccountName) ``
    -TimeToRestore $restoreTime ``
    -BlobRestoreRange $blobRange
"@

Write-Host "`nNOTA: Restauracao so funciona com dados reais e Change Feed ativo."
Write-Host "Em producao, use datetime ANTERIOR a delecao/corrupcao."
```

---

## Modo Desafio - Bloco 2

- [ ] Registrar Storage Account no Recovery Services Vault
- [ ] Habilitar backup de Azure File Share com policy customizada
- [ ] Habilitar Soft Delete para blobs (14 dias) e containers (7 dias)
- [ ] Habilitar Blob Versioning
- [ ] Habilitar Point-in-Time Restore (13 dias, menor que soft delete)
- [ ] Entender a hierarquia: Soft Delete → Versioning → Point-in-Time Restore

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce habilitou Soft Delete com 14 dias para blobs. Um usuario sobrescreve um blob critico com dados errados. O Soft Delete vai proteger contra isso?**

A) Sim, o blob original e mantido por 14 dias
B) Nao, Soft Delete so protege contra delecao, nao sobrescrita
C) Sim, mas apenas se Blob Versioning tambem estiver habilitado
D) Nao, e preciso usar Azure Backup para blobs

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, Soft Delete so protege contra delecao, nao sobrescrita**

Soft Delete protege apenas contra **delecao**. Para proteger contra **sobrescrita**, voce precisa de **Blob Versioning**, que mantém versoes anteriores automaticamente.

</details>

### Questao 2.2
**Voce quer habilitar Point-in-Time Restore para blobs. Quais features DEVEM estar habilitadas primeiro?**

A) Apenas Soft Delete
B) Soft Delete e Versioning
C) Soft Delete, Versioning e Change Feed
D) Apenas Versioning

<details>
<summary>Ver resposta</summary>

**Resposta: C) Soft Delete, Versioning e Change Feed**

Point-in-Time Restore requer TODOS: Blob Soft Delete, Blob Versioning e Change Feed. Se qualquer um estiver desabilitado, Point-in-Time Restore nao pode ser habilitado.

</details>

### Questao 2.3
**Qual e a diferenca entre backup de File Share (Recovery Services Vault) e protecao de Blobs (Soft Delete/Versioning)?**

A) Nao ha diferenca, ambos usam Recovery Services Vault
B) File Share backup usa vault com snapshots; Blob protection usa features nativas da Storage Account
C) Blob protection e mais completo que File Share backup
D) File Share backup so funciona com Premium storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) File Share backup usa vault com snapshots; Blob protection usa features nativas da Storage Account**

Azure File Share backup e gerenciado pelo Recovery Services Vault usando snapshots. Protecao de blobs (Soft Delete, Versioning, Point-in-Time Restore) sao features nativas da Storage Account, configuradas sem vault.

</details>

---

# Bloco 3 - Azure Site Recovery

**Tecnologia:** Az.RecoveryServices PowerShell module (ASR cmdlets)
**Recursos criados:** 1 Resource Group, 1 Recovery Services Vault (DR), Fabric, Protection Container, Replication

> **Conceito:** Azure Site Recovery (ASR) e a solucao de **Disaster Recovery** do Azure.
> Diferente do Backup (que protege dados), ASR replica **VMs inteiras** para outra regiao.
> Em caso de desastre na regiao primaria, voce faz **failover** para a regiao DR.
>
> **IMPORTANTE:** O vault de Site Recovery fica na regiao de DESTINO (DR), NAO na regiao de origem.
> Isso e o oposto do Backup, onde o vault fica na mesma regiao do recurso.

---

### Task 3.1: Criar vault na regiao DR

```powershell
# ============================================================
# TASK 3.1 - Criar RG e Vault na regiao de DR
# ============================================================

# Criar Resource Group na regiao de DR
# O vault de ASR DEVE estar na regiao de DESTINO (failover target)
New-AzResourceGroup -Name $rg12 -Location $locationDR
Write-Host "Criado Resource Group: $rg12 em $locationDR"

# Criar Recovery Services Vault na regiao DR
# Este vault gerenciara a replicacao da VM do East US para West US
$vaultDR = New-AzRecoveryServicesVault `
    -ResourceGroupName $rg12 `
    -Name $vaultNameDR `
    -Location $locationDR

Write-Host "Vault DR criado: $($vaultDR.Name) em $($vaultDR.Location)"

# Definir contexto para o vault DR
Set-AzRecoveryServicesVaultContext -Vault $vaultDR
```

> **Diferenca critica Backup vs ASR:**
> - **Backup Vault:** mesma regiao do recurso protegido (East US → East US)
> - **ASR Vault:** regiao de destino/DR (East US → vault no West US)

---

### Task 3.2: Criar ASR Fabrics (source e target)

```powershell
# ============================================================
# TASK 3.2 - Criar ASR Fabrics para source e target
# ============================================================

# ASR Fabric e uma representacao logica de uma regiao no contexto do Site Recovery
# Voce precisa de dois fabrics: source (origem) e target (destino)

# Criar fabric para a regiao source (onde a VM esta)
# New-AzRecoveryServicesAsrFabric: cria fabric ASR
# -Name: nome identificador do fabric
# -Azure: indica que e um fabric Azure (vs on-premises)
# -Location: regiao que este fabric representa
$fabricSourceJob = New-AzRecoveryServicesAsrFabric `
    -Name $fabricSource `
    -Azure `
    -Location $location

Write-Host "Criando fabric source ($location)..."
Write-Host "Job: $($fabricSourceJob.Name) - Status: $($fabricSourceJob.State)"

# Aguardar conclusao do fabric source
# O fabric pode levar alguns minutos para ser criado
$fabricSourceJob = Get-AzRecoveryServicesAsrJob -Job $fabricSourceJob
while ($fabricSourceJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $fabricSourceJob = Get-AzRecoveryServicesAsrJob -Job $fabricSourceJob
    Write-Host "  Aguardando fabric source... $($fabricSourceJob.State)"
}

# Criar fabric para a regiao target (DR)
$fabricTargetJob = New-AzRecoveryServicesAsrFabric `
    -Name $fabricTarget `
    -Azure `
    -Location $locationDR

Write-Host "Criando fabric target ($locationDR)..."

# Aguardar conclusao
$fabricTargetJob = Get-AzRecoveryServicesAsrJob -Job $fabricTargetJob
while ($fabricTargetJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $fabricTargetJob = Get-AzRecoveryServicesAsrJob -Job $fabricTargetJob
    Write-Host "  Aguardando fabric target... $($fabricTargetJob.State)"
}

# Obter objetos dos fabrics criados
$sourceFabric = Get-AzRecoveryServicesAsrFabric -Name $fabricSource
$targetFabric = Get-AzRecoveryServicesAsrFabric -Name $fabricTarget

Write-Host "`n=== Fabrics criados ==="
Write-Host "Source: $($sourceFabric.FriendlyName) ($($sourceFabric.FabricSpecificDetails.Location))"
Write-Host "Target: $($targetFabric.FriendlyName) ($($targetFabric.FabricSpecificDetails.Location))"
```

> **Conceito:** Fabrics representam regioes no ASR. Cada fabric contem Protection Containers
> que agrupam os itens protegidos. A hierarquia e: Vault → Fabric → Container → Protected Item.

---

### Task 3.3: Criar Protection Containers

```powershell
# ============================================================
# TASK 3.3 - Criar Protection Containers
# ============================================================

# Protection Container e um agrupamento logico dentro do fabric
# Source container: contem os itens originais
# Target container: contem as replicas

# Criar container source
$sourceContainerJob = New-AzRecoveryServicesAsrProtectionContainer `
    -InputObject $sourceFabric `
    -Name "source-container"

# Aguardar
$sourceContainerJob = Get-AzRecoveryServicesAsrJob -Job $sourceContainerJob
while ($sourceContainerJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $sourceContainerJob = Get-AzRecoveryServicesAsrJob -Job $sourceContainerJob
}

# Criar container target
$targetContainerJob = New-AzRecoveryServicesAsrProtectionContainer `
    -InputObject $targetFabric `
    -Name "target-container"

# Aguardar
$targetContainerJob = Get-AzRecoveryServicesAsrJob -Job $targetContainerJob
while ($targetContainerJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $targetContainerJob = Get-AzRecoveryServicesAsrJob -Job $targetContainerJob
}

# Obter containers
$sourceContainer = Get-AzRecoveryServicesAsrProtectionContainer `
    -Fabric $sourceFabric `
    -Name "source-container"

$targetContainer = Get-AzRecoveryServicesAsrProtectionContainer `
    -Fabric $targetFabric `
    -Name "target-container"

Write-Host "Source Container: $($sourceContainer.FriendlyName)"
Write-Host "Target Container: $($targetContainer.FriendlyName)"
```

---

### Task 3.4: Criar Replication Policy e Container Mapping

```powershell
# ============================================================
# TASK 3.4 - Criar Replication Policy e Container Mapping
# ============================================================

# Replication Policy define os parametros de replicacao:
#   - RPO (Recovery Point Objective): perda maxima de dados aceitavel
#   - Frequencia de snapshots consistentes com aplicacao
#   - Retencao de recovery points

# New-AzRecoveryServicesAsrPolicy: cria policy de replicacao
# -Name: nome da policy
# -ReplicationProvider: A2A (Azure to Azure), HyperVReplicaAzure, InMageAzureV2
# -RecoveryPointRetentionInHours: horas de retencao (padrao 24)
# -ApplicationConsistentSnapshotFrequencyInHours: frequencia de snapshot consistente
# -RPOWarningThresholdInMinutes: alerta se RPO exceder (0 = desabilitado)
$replicationPolicy = New-AzRecoveryServicesAsrPolicy `
    -Name "repl-contoso-policy" `
    -ReplicationProvider "A2A" `
    -RecoveryPointRetentionInHours 24 `
    -ApplicationConsistentSnapshotFrequencyInHours 4

Write-Host "Policy de replicacao criada"

# Aguardar policy
$policyJob = Get-AzRecoveryServicesAsrJob -Name $replicationPolicy.Name
while ($policyJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $policyJob = Get-AzRecoveryServicesAsrJob -Name $policyJob.Name
}

$policy = Get-AzRecoveryServicesAsrPolicy -Name "repl-contoso-policy"

# Container Mapping: associa source container ao target container com a policy
# New-AzRecoveryServicesAsrProtectionContainerMapping: cria mapeamento
# -Name: nome do mapeamento
# -Policy: policy de replicacao
# -PrimaryProtectionContainer: container source
# -RecoveryProtectionContainer: container target
$mappingJob = New-AzRecoveryServicesAsrProtectionContainerMapping `
    -Name "source-to-target-mapping" `
    -Policy $policy `
    -PrimaryProtectionContainer $sourceContainer `
    -RecoveryProtectionContainer $targetContainer

Write-Host "Container mapping criado"

# Aguardar
$mappingJob = Get-AzRecoveryServicesAsrJob -Job $mappingJob
while ($mappingJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $mappingJob = Get-AzRecoveryServicesAsrJob -Job $mappingJob
}

$containerMapping = Get-AzRecoveryServicesAsrProtectionContainerMapping `
    -ProtectionContainer $sourceContainer `
    -Name "source-to-target-mapping"

Write-Host "Mapping: $($containerMapping.FriendlyName) - State: $($containerMapping.State)"
```

> **Conceito RPO vs RTO:**
> - **RPO (Recovery Point Objective):** maxima perda de dados aceitavel (ex: 15 min = pode perder ate 15 min de dados)
> - **RTO (Recovery Time Objective):** tempo maximo para restaurar o servico
> ASR garante RPO de minutos e RTO de horas (dependendo da complexidade do failover).

---

### Task 3.4b: Politica de replicacao customizada

```powershell
# ============================================================
# TASK 3.2b - Criar politica de replicacao customizada
# ============================================================
# Politicas customizadas permitem ajustar RPO e retencao para
# cenarios especificos. Aqui criamos uma policy com retencao curta (4h).

# New-AzRecoveryServicesAsrPolicy: cria policy de replicacao
# -RecoveryPointRetentionInHours: 4 = retencao de 4 horas
# -ApplicationConsistentSnapshotFrequencyInHours: 2 = app-consistent a cada 2h
# -RPOWarningThresholdInMinutes: 5 = alerta se RPO exceder 5 min
$customPolicy = New-AzRecoveryServicesAsrPolicy `
    -Name "contoso-4h-retention" `
    -ReplicationProvider "A2A" `
    -RecoveryPointRetentionInHours 4 `
    -ApplicationConsistentSnapshotFrequencyInHours 2 `
    -RPOWarningThresholdInMinutes 5

# Aguardar criacao da policy
$policyJob = Get-AzRecoveryServicesAsrJob -Name $customPolicy.Name
while ($policyJob.State -eq "InProgress") {
    Start-Sleep -Seconds 10
    $policyJob = Get-AzRecoveryServicesAsrJob -Name $policyJob.Name
}

# Verificar policy criada
$createdPolicy = Get-AzRecoveryServicesAsrPolicy -Name "contoso-4h-retention"
Write-Host "Policy customizada criada: $($createdPolicy.FriendlyName)"
Write-Host "Retencao: $($createdPolicy.ReplicationProviderSettings.RecoveryPointHistory) min"
Write-Host "App-consistent: $($createdPolicy.ReplicationProviderSettings.AppConsistentFrequencyInMinutes) min"
```

> **Conceito AZ-104 — Replication Policy:**
> - `RecoveryPointRetentionInHours: 4` = armazena pontos das ultimas 4 horas
> - `ApplicationConsistentSnapshotFrequencyInHours: 2` = snapshot app-consistent a cada 2h
> - Crash-consistent: a cada 5 min (padrao A2A, nao configuravel diretamente)
> - Menor retencao = menos storage, mas menos opcoes de recovery point
> - Na prova: "RPO de 5 min" = crash-consistent frequency de 5 min

---

### Task 3.5: Habilitar replicacao da VM

> **Cobranca:** A replicacao ASR gera cobranca continua por VM replicada. Nao pode ser pausada — so desabilitada.

```powershell
# ============================================================
# TASK 3.5 - Habilitar replicacao da VM para a regiao DR
# ============================================================

# Obter informacoes da VM source
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName
$vmResourceId = $vm.Id

# Obter discos da VM
$osDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
Write-Host "VM: $($vm.Name)"
Write-Host "OS Disk: $osDiskId"

# Criar cache storage account na regiao source (necessario para replicacao)
# A cache storage account armazena dados temporarios durante a replicacao
$cacheSaName = "stcontosocache$(Get-Random -Minimum 1000 -Maximum 9999)"
$cacheSa = New-AzStorageAccount `
    -ResourceGroupName $rg11 `
    -Name $cacheSaName `
    -Location $location `
    -SkuName "Standard_LRS" `
    -Kind "StorageV2"

Write-Host "Cache Storage Account criada: $cacheSaName"

# Configurar mapeamento de disco para replicacao
# Cada disco da VM precisa de configuracao: disco original → disco replica
$diskConfig = New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig `
    -ManagedDisk `
    -LogStorageAccountId $cacheSa.Id `
    -DiskId $osDiskId `
    -RecoveryResourceGroupId (Get-AzResourceGroup -Name $rg12).ResourceId `
    -RecoveryReplicaDiskAccountType "Standard_LRS" `
    -RecoveryTargetDiskAccountType "Standard_LRS"

# Habilitar replicacao
# New-AzRecoveryServicesAsrReplicationProtectedItem: inicia replicacao
# Este e o cmdlet que efetivamente "liga" a replicacao da VM
# -Name: nome do item protegido
# -ProtectionContainerMapping: mapeamento source→target
# -AzureVmId: ID da VM a replicar
# -AzureToAzureDiskReplicationConfiguration: configuracao dos discos
# -RecoveryResourceGroupId: RG na regiao DR onde a replica sera criada
$replicationJob = New-AzRecoveryServicesAsrReplicationProtectedItem `
    -Name "$vmName-repl" `
    -ProtectionContainerMapping $containerMapping `
    -AzureVmId $vmResourceId `
    -AzureToAzureDiskReplicationConfiguration @($diskConfig) `
    -RecoveryResourceGroupId (Get-AzResourceGroup -Name $rg12).ResourceId

Write-Host "`nReplicacao iniciada para $vmName!"
Write-Host "Job: $($replicationJob.Name) - Status: $($replicationJob.State)"
Write-Host "`nA replicacao inicial pode levar 30-60 minutos."
Write-Host "Para monitorar:"
Write-Host "  Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer `$sourceContainer"
```

> **IMPORTANTE:** A replicacao inicial sincroniza todos os discos da VM para a regiao DR.
> Apos a sincronizacao inicial, apenas mudancas incrementais sao replicadas.

---

### Task 3.6: Criar Recovery Plan

```powershell
# ============================================================
# TASK 3.6 - Criar Recovery Plan
# ============================================================

# Recovery Plan define a ORDEM de failover das VMs
# Em producao, voce agrupa VMs em groups (1, 2, 3...) para controlar a sequencia
# Ex: Group 1 = banco de dados (sobe primeiro), Group 2 = app server, Group 3 = web server

# Obter o item replicado
$replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem `
    -ProtectionContainer $sourceContainer |
    Where-Object { $_.FriendlyName -eq $vmName }

if ($replicatedItem -and $replicatedItem.ReplicationHealth -ne "None") {
    # New-AzRecoveryServicesAsrRecoveryPlan: cria plano de recuperacao
    # -Name: nome do plano
    # -PrimaryFabric: fabric de origem
    # -RecoveryFabric: fabric de destino
    # -ReplicationProtectedItem: itens incluidos no plano
    $recoveryPlan = New-AzRecoveryServicesAsrRecoveryPlan `
        -Name "recovery-plan-contoso" `
        -PrimaryFabric $sourceFabric `
        -RecoveryFabric $targetFabric `
        -ReplicationProtectedItem $replicatedItem

    Write-Host "Recovery Plan criado: recovery-plan-contoso"
    Write-Host "VMs incluidas: $($replicatedItem.FriendlyName)"
} else {
    Write-Host "Item replicado ainda nao esta pronto. Aguarde a replicacao inicial." -ForegroundColor Yellow
    Write-Host "Verifique com: Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer `$sourceContainer"
}
```

---

### Task 3.7: Test Failover

```powershell
# ============================================================
# TASK 3.7 - Executar Test Failover
# ============================================================

# Test Failover cria uma COPIA da VM na regiao DR para validacao
# NAO afeta a VM original nem interrompe a replicacao
# IMPORTANTE: Sempre faca test failover antes de um failover real!

# Obter o recovery plan
$plan = Get-AzRecoveryServicesAsrRecoveryPlan -Name "recovery-plan-contoso"

if ($plan) {
    # Start-AzRecoveryServicesAsrTestFailoverJob: inicia test failover
    # -Direction: PrimaryToRecovery (source → target)
    # -RecoveryPlan: plano de recuperacao
    # NOTA: Em producao, voce criaria uma VNet isolada para o teste
    $testFailoverJob = Start-AzRecoveryServicesAsrTestFailoverJob `
        -Direction "PrimaryToRecovery" `
        -RecoveryPlan $plan `
        -AzureVMNetworkId "yourTestVnetId"  # ← ALTERE: ID da VNet de teste na regiao DR

    Write-Host "Test Failover iniciado!"
    Write-Host "Job: $($testFailoverJob.Name)"
    Write-Host "Status: $($testFailoverJob.State)"
    Write-Host "`nApos validacao, execute o cleanup:"
    Write-Host "  Start-AzRecoveryServicesAsrTestFailoverCleanupJob -RecoveryPlan `$plan"
} else {
    Write-Host "Recovery Plan nao encontrado. Execute a Task 3.6 primeiro." -ForegroundColor Yellow
}
```

---

### Task 3.8: Cleanup do Test Failover

```powershell
# ============================================================
# TASK 3.8 - Cleanup do Test Failover
# ============================================================

# Apos validar que o test failover funcionou, SEMPRE execute o cleanup
# O cleanup remove as VMs temporarias criadas pelo teste
# Se nao fizer cleanup, nao podera iniciar outro test failover

$plan = Get-AzRecoveryServicesAsrRecoveryPlan -Name "recovery-plan-contoso"

if ($plan) {
    # Start-AzRecoveryServicesAsrTestFailoverCleanupJob: remove recursos do teste
    $cleanupJob = Start-AzRecoveryServicesAsrTestFailoverCleanupJob `
        -RecoveryPlan $plan `
        -Comment "Test failover validado com sucesso"

    Write-Host "Cleanup do test failover iniciado"
    Write-Host "Job: $($cleanupJob.Name) - Status: $($cleanupJob.State)"
} else {
    Write-Host "Recovery Plan nao encontrado." -ForegroundColor Yellow
}
```

> **Dica AZ-104:** Na prova, a sequencia correta e:
> 1. Habilitar replicacao
> 2. Criar Recovery Plan
> 3. Test Failover (validacao)
> 4. Cleanup do test
> 5. Failover real (apenas em caso de desastre)
> 6. Re-protect (inverter replicacao apos failover)

---

## Modo Desafio - Bloco 3

- [ ] Criar vault DR na regiao de destino (West US)
- [ ] Criar ASR Fabrics para source e target
- [ ] Criar Protection Containers em ambos os fabrics
- [ ] Criar Replication Policy com RPO e retencao definidos
- [ ] Criar Container Mapping (source → target com policy)
- [ ] Habilitar replicacao da VM com configuracao de discos
- [ ] Criar Recovery Plan com a VM replicada
- [ ] Executar Test Failover + Cleanup

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa configurar Azure Site Recovery para uma VM no East US. Em qual regiao o Recovery Services Vault deve ser criado?**

A) East US (mesma regiao da VM)
B) West US (regiao de destino/DR)
C) Qualquer regiao
D) Central US

<details>
<summary>Ver resposta</summary>

**Resposta: B) West US (regiao de destino/DR)**

Para Site Recovery, o vault deve estar na regiao de **destino** (DR). Isso e o oposto do Backup, onde o vault fica na mesma regiao do recurso. O vault gerencia a replicacao para sua regiao.

</details>

### Questao 3.2
**Qual e a diferenca entre RPO e RTO no contexto de Azure Site Recovery?**

A) RPO e o tempo de restore, RTO e a perda de dados
B) RPO e a perda maxima de dados aceitavel, RTO e o tempo maximo para restaurar
C) RPO e RTO sao a mesma coisa
D) RPO se aplica a backups, RTO a Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) RPO e a perda maxima de dados aceitavel, RTO e o tempo maximo para restaurar**

**RPO (Recovery Point Objective):** quantidade maxima de dados que pode ser perdida (ex: 15 min). **RTO (Recovery Time Objective):** tempo maximo para restaurar o servico apos desastre.

</details>

### Questao 3.3
**Apos executar um Test Failover no Azure Site Recovery, o que voce DEVE fazer antes de poder executar outro teste ou failover real?**

A) Desabilitar a replicacao
B) Executar Test Failover Cleanup
C) Recriar o Recovery Plan
D) Reiniciar a VM

<details>
<summary>Ver resposta</summary>

**Resposta: B) Executar Test Failover Cleanup**

O cleanup remove os recursos temporarios criados pelo teste. Sem executar o cleanup, o ASR bloqueia novos testes ou failovers. Use `Start-AzRecoveryServicesAsrTestFailoverCleanupJob`.

</details>

---

# Bloco 4 - Azure Monitor & Alerts

**Tecnologia:** Az.Monitor PowerShell module
**Recursos criados:** 1 Resource Group, 1 Action Group, 1 Metric Alert, Diagnostic Settings

> **Conceito:** Azure Monitor e o servico centralizado de monitoramento do Azure.
> Ele coleta **metricas** (dados numericos em tempo real) e **logs** (eventos detalhados).
> **Alerts** reagem automaticamente quando condicoes sao atingidas.
> **Action Groups** definem quem e notificado e como (email, SMS, webhook, Logic App, etc.).

---

### Task 4.1: Criar Resource Group para monitoramento

```powershell
# ============================================================
# TASK 4.1 - Criar Resource Group para recursos de monitoramento
# ============================================================

# Criar RG para recursos de monitoramento
New-AzResourceGroup -Name $rg13 -Location $location
Write-Host "Criado Resource Group: $rg13"
```

---

### Task 4.2: Criar Action Group

```powershell
# ============================================================
# TASK 4.2 - Criar Action Group com notificacao por email
# ============================================================

# Action Group define QUEM e notificado e COMO quando um alert dispara
# Tipos de acao: Email, SMS, Push (App), Voice, Azure Function, Logic App,
#                Webhook, ITSM, Automation Runbook

# Criar receiver de email
# New-AzActionGroupEmailReceiverObject: cria configuracao de email
# -Name: identificador do receiver
# -EmailAddress: email destino
# -UseCommonAlertSchema: formato padronizado de alerta ($true recomendado)
$emailReceiver = New-AzActionGroupEmailReceiverObject `
    -Name "admin-email" `
    -EmailAddress $alertEmail `
    -UseCommonAlertSchema $true

# New-AzActionGroup: cria o Action Group
# -ResourceGroupName: RG do Action Group
# -Name: nome do recurso
# -ShortName: nome curto (max 12 caracteres, usado em SMS)
# -Location: "Global" para Action Groups (NAO uma regiao especifica)
# -EmailReceiver: array de receivers de email
$actionGroup = New-AzActionGroup `
    -ResourceGroupName $rg13 `
    -Name $actionGroupName `
    -ShortName "ag-contoso-ops" `
    -Location "Global" `
    -EmailReceiver @($emailReceiver)

Write-Host "Action Group criado: $($actionGroup.Name)"
Write-Host "Email configurado: $alertEmail"

# Verificar
Get-AzActionGroup -ResourceGroupName $rg13 -Name $actionGroupName |
    Select-Object Name, Location, GroupShortName
```

> **Dica AZ-104:** Action Groups tem Location "Global" porque sao um recurso global.
> O ShortName (max 12 chars) e usado como identificador em notificacoes SMS.

---

### Task 4.3: Criar Metric Alert (CPU > 80%)

> **Cobranca:** Alert rules geram cobranca minima por sinal monitorado.

```powershell
# ============================================================
# TASK 4.3 - Criar alerta de metrica: CPU > 80%
# ============================================================

# Obter a VM para monitoramento
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# Criar condicao do alerta
# New-AzMetricAlertRuleV2Criteria: define a condicao de disparo
# -MetricName: nome da metrica (Percentage CPU, Available Memory Bytes, etc.)
# -TimeAggregation: como agregar os dados (Average, Maximum, Minimum, Total, Count)
# -Operator: operador de comparacao (GreaterThan, LessThan, Equals)
# -Threshold: valor limite
$condition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "Percentage CPU" `
    -TimeAggregation "Average" `
    -Operator "GreaterThan" `
    -Threshold 80

# Referencia ao Action Group
$actionGroupId = $actionGroup.Id

# Add-AzMetricAlertRuleV2: cria a regra de alerta
# -Name: nome da regra
# -ResourceGroupName: RG da regra (pode ser diferente do recurso monitorado)
# -WindowSize: janela de avaliacao (ex: 5 min = avalia media dos ultimos 5 min)
# -Frequency: frequencia de avaliacao (ex: 1 min = avalia a cada 1 min)
# -TargetResourceId: ID do recurso monitorado
# -Condition: criterio(s) de disparo
# -ActionGroupId: action group(s) a notificar
# -Severity: 0 (Critical), 1 (Error), 2 (Warning), 3 (Informational), 4 (Verbose)
# -Description: descricao do alerta
Add-AzMetricAlertRuleV2 `
    -Name $alertRuleName `
    -ResourceGroupName $rg13 `
    -WindowSize (New-TimeSpan -Minutes 5) `
    -Frequency (New-TimeSpan -Minutes 1) `
    -TargetResourceId $vm.Id `
    -Condition $condition `
    -ActionGroupId @($actionGroupId) `
    -Severity 2 `
    -Description "Alerta quando CPU media excede 80% por 5 minutos"

Write-Host "Alert Rule criada: $alertRuleName"
Write-Host "Condicao: CPU media > 80% (janela de 5 min, avaliacao a cada 1 min)"
Write-Host "Severity: 2 (Warning)"
Write-Host "Action Group: $actionGroupName"

# Verificar
Get-AzMetricAlertRuleV2 -ResourceGroupName $rg13 -Name $alertRuleName |
    Select-Object Name, Severity, Enabled
```

> **Conceito:** Metric Alerts avaliam metricas em tempo real:
> - **WindowSize:** periodo de dados avaliado (ultimos X minutos)
> - **Frequency:** intervalo entre avaliacoes
> - **Severity:** 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose
> Na prova, preste atencao na diferenca entre WindowSize e Frequency.

---

### Task 4.3b: Alerta com Dynamic Threshold

```powershell
# ============================================================
# TASK 4.3b - Criar alerta com Dynamic Threshold
# ============================================================
# Dynamic Threshold usa Machine Learning para aprender o padrao de uso
# e alerta quando detecta desvios (anomalias).

$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# New-AzMetricAlertRuleV2DimensionSelection: (nao necessario aqui)
# New-AzMetricAlertRuleV2Criteria com -DynamicThreshold: define criterio dinamico
# -MetricName: metrica a monitorar
# -TimeAggregation: agregacao (Average, Maximum, etc.)
# -Operator: GreaterThan, LessThan, GreaterOrLessThan
# -Sensitivity: High, Medium, Low (sensibilidade do ML)
# -FailingPeriod: numero de violacoes para disparar
# -ExaminedPeriod: janela de avaliacao
$dynamicCondition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "Percentage CPU" `
    -TimeAggregation "Average" `
    -DynamicThreshold `
    -Operator "GreaterThan" `
    -Sensitivity "Medium" `
    -FailingPeriod 4 `
    -ExaminedPeriod 4

Add-AzMetricAlertRuleV2 `
    -Name "alert-vm-web-01-cpu-dynamic" `
    -ResourceGroupName $rg13 `
    -WindowSize (New-TimeSpan -Minutes 20) `
    -Frequency (New-TimeSpan -Minutes 5) `
    -TargetResourceId $vm.Id `
    -Condition $dynamicCondition `
    -ActionGroupId @($actionGroupId) `
    -Severity 2 `
    -Description "Alert com Dynamic Threshold - detecta anomalias baseado em ML"

Write-Host "Dynamic Threshold Alert criado"
Write-Host "O ML precisa de ~3 dias de dados historicos para melhor resultado"
```

> **Conceito AZ-104 — Static vs Dynamic Threshold:**
> - **Static:** valor fixo (ex: CPU > 80%) — voce define o limite
> - **Dynamic:** Machine Learning detecta anomalias automaticamente
> - Sensitivity: High (alerta em desvios pequenos), Medium, Low (apenas desvios grandes)
> - FailingPeriod/ExaminedPeriod: quantas violacoes em quantas avaliacoes (ex: 4 de 4)
> - Precisa de ~3 dias de dados historicos para melhor resultado
> - Na prova: "detectar comportamento anomalo" = Dynamic; "CPU > 80%" = Static

---

### Task 4.4: Configurar Diagnostic Settings na VM

> **Cobranca:** O workspace gera cobranca por GB de dados ingeridos.

```powershell
# ============================================================
# TASK 4.4 - Configurar Diagnostic Settings
# ============================================================

# Diagnostic Settings enviam metricas e logs para destinos de armazenamento:
#   1. Log Analytics Workspace (para consultas KQL e analise)
#   2. Storage Account (para retencao longa e compliance)
#   3. Event Hub (para integracao com ferramentas externas como Splunk)
# Voce pode enviar para multiplos destinos simultaneamente

# NOTA: O Log Analytics Workspace sera criado no Bloco 5
# Por enquanto, criamos o workspace antecipadamente para usar aqui

$workspace = New-AzOperationalInsightsWorkspace `
    -ResourceGroupName $rg13 `
    -Name $workspaceName `
    -Location $location `
    -Sku "PerGB2018"

Write-Host "Log Analytics Workspace criado: $($workspace.Name)"
Write-Host "Workspace ID: $($workspace.CustomerId)"

# Obter a VM
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# Set-AzDiagnosticSetting: configura envio de metricas/logs
# -ResourceId: recurso que gera os dados
# -WorkspaceId: destino Log Analytics
# -MetricCategory: categorias de metricas a enviar
# -Enabled: habilitar/desabilitar
$diagSetting = Set-AzDiagnosticSetting `
    -ResourceId $vm.Id `
    -WorkspaceId $workspace.ResourceId `
    -Name "alert-vm-web-01-diagnostics" `
    -MetricCategory @("AllMetrics") `
    -Enabled $true

Write-Host "`nDiagnostic Settings configurado:"
Write-Host "Recurso: $vmName"
Write-Host "Destino: $workspaceName (Log Analytics)"
Write-Host "Metricas: AllMetrics"
```

> **Conceito:** Diagnostic Settings sao a "ponte" entre um recurso e os destinos de dados.
> Cada recurso pode ter multiplas diagnostic settings, cada uma enviando para destinos diferentes.
> Metricas sao dados numericos (CPU %, memory bytes); Logs sao eventos estruturados (audit, sign-in).

---

### Task 4.5: Visualizar metricas no console

```powershell
# ============================================================
# TASK 4.5 - Consultar metricas da VM via PowerShell
# ============================================================

# Get-AzMetric: consulta metricas de um recurso
# Util para verificar se os dados estao sendo coletados
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# Consultar CPU dos ultimos 30 minutos
$metrics = Get-AzMetric `
    -ResourceId $vm.Id `
    -MetricName "Percentage CPU" `
    -TimeGrain (New-TimeSpan -Minutes 5) `
    -StartTime (Get-Date).AddMinutes(-30) `
    -EndTime (Get-Date) `
    -AggregationType "Average"

Write-Host "=== Metricas de CPU - Ultimos 30 minutos ==="
$metrics.Data | ForEach-Object {
    Write-Host "  $($_.TimeStamp): $([math]::Round($_.Average, 2))%"
}

# Listar todas as metricas disponiveis para a VM
Write-Host "`n=== Metricas disponiveis ==="
Get-AzMetricDefinition -ResourceId $vm.Id |
    Select-Object Name, Unit, PrimaryAggregationType |
    Format-Table -AutoSize
```

---

### Task 4.6b: Service Health Alerts

```powershell
# ============================================================
# TASK 4.6b - Criar alerta de Service Health
# ============================================================
# Service Health monitora incidentes, manutencao e advisories do Azure.
# Usa Activity Log Alerts, nao Metric Alerts.

# Criar condicao para Service Health Incidents
$conditionIncident = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject `
    -Equal "ServiceHealth" `
    -Field "category"

$conditionIncidentType = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject `
    -Equal "Incident" `
    -Field "properties.incidentType"

# Criar Action Group reference
$actionGroupRef = New-AzActivityLogAlertActionGroupObject `
    -Id $actionGroup.Id

# Criar alerta para incidentes (outages)
New-AzActivityLogAlert `
    -Name "alert-service-health-incident" `
    -ResourceGroupName $rg13 `
    -Location "Global" `
    -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)" `
    -Condition @($conditionIncident, $conditionIncidentType) `
    -Action @($actionGroupRef) `
    -Description "Alerta para incidentes de Service Health"

Write-Host "Service Health Alert (Incidents) criado"

# Criar condicao para Planned Maintenance
$conditionMaintenance = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject `
    -Equal "Maintenance" `
    -Field "properties.incidentType"

# Criar alerta para manutencao planejada
New-AzActivityLogAlert `
    -Name "alert-service-health-maintenance" `
    -ResourceGroupName $rg13 `
    -Location "Global" `
    -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)" `
    -Condition @($conditionIncident, $conditionMaintenance) `
    -Action @($actionGroupRef) `
    -Description "Alerta para manutencao planejada"

Write-Host "Service Health Alert (Maintenance) criado"
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

- [ ] Criar Action Group com email receiver
- [ ] Criar Metric Alert: CPU > 80%, WindowSize 5 min, Frequency 1 min, Severity 2
- [ ] Criar Log Analytics Workspace
- [ ] Configurar Diagnostic Settings na VM (metricas → Log Analytics)
- [ ] Consultar metricas da VM com `Get-AzMetric`
- [ ] Entender a diferenca entre WindowSize e Frequency

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa ser notificado por email quando uma VM tiver CPU acima de 90% por mais de 10 minutos. Quais recursos voce deve criar?**

A) Apenas um Metric Alert
B) Um Action Group e um Metric Alert
C) Um Log Analytics Workspace e uma Alert Rule
D) Um Diagnostic Setting e um Action Group

<details>
<summary>Ver resposta</summary>

**Resposta: B) Um Action Group e um Metric Alert**

O **Action Group** define o email de destino. O **Metric Alert** define a condicao (CPU > 90%) e o WindowSize (10 min). O Action Group e referenciado pelo Metric Alert.

</details>

### Questao 4.2
**Qual e a diferenca entre WindowSize e Frequency em uma Metric Alert Rule?**

A) WindowSize e o intervalo de avaliacao, Frequency e o periodo de dados
B) WindowSize e o periodo de dados avaliado, Frequency e o intervalo entre avaliacoes
C) Ambos definem o mesmo parametro
D) WindowSize se aplica a logs, Frequency a metricas

<details>
<summary>Ver resposta</summary>

**Resposta: B) WindowSize e o periodo de dados avaliado, Frequency e o intervalo entre avaliacoes**

**WindowSize** (ex: 5 min) = "olhe os ultimos 5 minutos de dados". **Frequency** (ex: 1 min) = "faca essa avaliacao a cada 1 minuto". A frequency deve ser menor ou igual ao WindowSize.

</details>

### Questao 4.3
**Voce quer enviar logs de uma VM para Log Analytics E para uma Storage Account simultaneamente. Quantas Diagnostic Settings voce precisa?**

A) 1 diagnostic setting com dois destinos
B) 2 diagnostic settings, uma para cada destino
C) Nao e possivel enviar para dois destinos
D) Depende do tipo de log

<details>
<summary>Ver resposta</summary>

**Resposta: A) 1 diagnostic setting com dois destinos**

Uma unica Diagnostic Setting pode enviar dados para multiplos destinos (Log Analytics, Storage Account, Event Hub). Voce tambem pode criar multiplas settings para o mesmo recurso.

</details>

### Questao 4.4
**Quais sao os tres destinos possiveis para Diagnostic Settings?**

A) Log Analytics, Storage Account, Event Hub
B) Log Analytics, Azure SQL, Cosmos DB
C) Storage Account, Event Hub, Azure Monitor
D) Log Analytics, Application Insights, Storage Account

<details>
<summary>Ver resposta</summary>

**Resposta: A) Log Analytics, Storage Account, Event Hub**

Os tres destinos de Diagnostic Settings sao: **Log Analytics Workspace** (analise e alertas), **Storage Account** (retencao longa e compliance), **Event Hub** (integracao com ferramentas externas como Splunk, Datadog).

</details>

---

# Bloco 5 - Log Analytics & Insights

**Tecnologia:** Az.OperationalInsights + Az.Monitor PowerShell modules
**Recursos criados:** AMA Agent na VM, KQL queries, VM Insights, Network Watcher

> **Conceito:** Log Analytics e o motor de consulta do Azure Monitor.
> Dados de logs e metricas sao armazenados em **Log Analytics Workspaces**.
> Consultas sao feitas em **KQL (Kusto Query Language)**.
> **VM Insights** e uma solucao que coleta e visualiza metricas detalhadas de VMs.

---

### Task 5.1: Instalar Azure Monitor Agent (AMA) na VM

```powershell
# ============================================================
# TASK 5.1 - Instalar Azure Monitor Agent (AMA) na VM
# ============================================================

# O Azure Monitor Agent (AMA) substitui o antigo Log Analytics Agent (MMA/OMS)
# AMA e o agente recomendado para coletar logs e metricas de VMs
# Ele e instalado como uma VM Extension

# Obter a VM
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# Set-AzVMExtension: instala extensao na VM
# -ExtensionName: nome da extensao
# -Publisher: publicador da extensao
# -ExtensionType: tipo especifico da extensao
# -TypeHandlerVersion: versao da extensao
# Para Windows: AzureMonitorWindowsAgent
# Para Linux: AzureMonitorLinuxAgent
Set-AzVMExtension `
    -ResourceGroupName $vmRg `
    -VMName $vmName `
    -Name "AzureMonitorWindowsAgent" `
    -Publisher "Microsoft.Azure.Monitor" `
    -ExtensionType "AzureMonitorWindowsAgent" `
    -TypeHandlerVersion "1.0" `
    -Location $location `
    -EnableAutomaticUpgrade $true

Write-Host "Azure Monitor Agent (AMA) instalado na VM $vmName"
Write-Host "NOTA: O agente precisa de alguns minutos para iniciar a coleta."

# Verificar extensoes instaladas
Get-AzVMExtension -ResourceGroupName $vmRg -VMName $vmName |
    Select-Object Name, Publisher, ExtensionType, ProvisioningState |
    Format-Table -AutoSize
```

> **Conceito MMA vs AMA:**
> - **MMA (Microsoft Monitoring Agent):** agente legado, sendo descontinuado
> - **AMA (Azure Monitor Agent):** novo agente, suporta Data Collection Rules (DCRs)
> Na prova, AMA e a resposta correta para cenarios de monitoramento modernos.

---

### Task 5.2: Criar Data Collection Rule

```powershell
# ============================================================
# TASK 5.2 - Criar Data Collection Rule (DCR)
# ============================================================

# Data Collection Rules definem QUAIS dados coletar e PARA ONDE enviar
# DCRs substituem a configuracao direta do workspace (legado)
# Um DCR pode ser associado a multiplas VMs

# Obter o workspace criado no Bloco 4
$workspace = Get-AzOperationalInsightsWorkspace `
    -ResourceGroupName $rg13 `
    -Name $workspaceName

# Criar DCR via REST API (cmdlet nativo ainda limitado)
# Definir os dados a coletar:
#   - Performance counters (CPU, Memory, Disk, Network)
#   - Windows Event Logs (System, Application)
$dcrName = "dcr-contoso-perf"

# Usando New-AzDataCollectionRule (modulo Az.Monitor)
$windowsEventLogs = New-AzWindowsEventLogDataSourceObject `
    -Name "WindowsEventLogs" `
    -Stream "Microsoft-Event" `
    -XPathQuery @("System!*[System[(Level=1 or Level=2 or Level=3)]]",
                   "Application!*[System[(Level=1 or Level=2 or Level=3)]]")

$perfCounters = New-AzPerfCounterDataSourceObject `
    -Name "PerfCounters" `
    -Stream "Microsoft-Perf" `
    -CounterSpecifier @(
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\Network Interface(*)\\Bytes Total/sec"
    ) `
    -SamplingFrequencyInSecond 60

$destination = New-AzLogAnalyticsDestinationObject `
    -Name "LogAnalyticsDest" `
    -WorkspaceResourceId $workspace.ResourceId

$dataFlow = New-AzDataFlowObject `
    -Stream @("Microsoft-Perf", "Microsoft-Event") `
    -Destination @("LogAnalyticsDest")

$dcr = New-AzDataCollectionRule `
    -ResourceGroupName $rg13 `
    -Name $dcrName `
    -Location $location `
    -DataSourceWindowsEventLog @($windowsEventLogs) `
    -DataSourcePerformanceCounter @($perfCounters) `
    -DestinationLogAnalytic @($destination) `
    -DataFlow @($dataFlow)

Write-Host "Data Collection Rule criada: $dcrName"
Write-Host "Dados coletados: Performance Counters + Windows Event Logs"
Write-Host "Destino: $workspaceName"

# Associar DCR a VM
# New-AzDataCollectionRuleAssociation: vincula DCR a um recurso
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

New-AzDataCollectionRuleAssociation `
    -TargetResourceId $vm.Id `
    -AssociationName "dcr-contoso-perf-assoc" `
    -RuleId $dcr.Id

Write-Host "DCR associada a VM $vmName"
```

> **Conceito DCR:** Data Collection Rules sao o mecanismo moderno de configuracao de coleta.
> Vantagens sobre o metodo legado:
> - Centralizacao: uma regra para multiplas VMs
> - Granularidade: controle fino do que coletar
> - Separacao: regra separada do agente

---

### Task 5.3: Executar queries KQL

```powershell
# ============================================================
# TASK 5.3 - Executar queries KQL no Log Analytics
# ============================================================

# KQL (Kusto Query Language) e a linguagem de consulta do Azure Monitor
# Dados levam 5-15 minutos para aparecer apos configurar o agente

# Invoke-AzOperationalInsightsQuery: executa KQL no workspace
# -WorkspaceId: ID do workspace (CustomerId, NAO ResourceId!)
# -Query: consulta KQL

$workspace = Get-AzOperationalInsightsWorkspace `
    -ResourceGroupName $rg13 `
    -Name $workspaceName

$workspaceId = $workspace.CustomerId

# Query 1: Ultimos eventos de erro do Windows
Write-Host "=== Query 1: Ultimos 10 erros do Windows ==="
$query1 = @"
Event
| where EventLevelName == "Error"
| project TimeGenerated, Source, EventID, RenderedDescription
| order by TimeGenerated desc
| take 10
"@

$result1 = Invoke-AzOperationalInsightsQuery `
    -WorkspaceId $workspaceId `
    -Query $query1

if ($result1.Results) {
    $result1.Results | Format-Table -AutoSize
} else {
    Write-Host "Sem dados ainda. Aguarde 5-15 min apos instalar o agente."
}

# Query 2: Uso de CPU nos ultimos 30 minutos
Write-Host "`n=== Query 2: CPU nos ultimos 30 minutos ==="
$query2 = @"
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where InstanceName == "_Total"
| where TimeGenerated > ago(30m)
| summarize AvgCPU=avg(CounterValue) by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
"@

$result2 = Invoke-AzOperationalInsightsQuery `
    -WorkspaceId $workspaceId `
    -Query $query2

if ($result2.Results) {
    $result2.Results | Format-Table -AutoSize
} else {
    Write-Host "Sem dados de performance ainda. Aguarde a coleta iniciar."
}

# Query 3: Heartbeat (verificar que o agente esta enviando dados)
Write-Host "`n=== Query 3: Heartbeat do agente ==="
$query3 = @"
Heartbeat
| summarize LastHeartbeat=max(TimeGenerated) by Computer
| order by LastHeartbeat desc
"@

$result3 = Invoke-AzOperationalInsightsQuery `
    -WorkspaceId $workspaceId `
    -Query $query3

if ($result3.Results) {
    $result3.Results | Format-Table -AutoSize
} else {
    Write-Host "Sem heartbeats ainda. O agente pode levar alguns minutos para iniciar."
}
```

> **Conceito KQL:** KQL e essencial para o AZ-104. Conheca os operadores basicos:
> - `where`: filtra linhas
> - `project`: seleciona colunas
> - `summarize`: agrega dados (avg, count, sum, max, min)
> - `bin()`: agrupa por intervalo de tempo
> - `ago()`: referencia temporal relativa (ex: ago(30m) = 30 min atras)
> - `order by`: ordena resultados
> - `take N`: limita a N resultados

---

### Task 5.4: Habilitar VM Insights

```powershell
# ============================================================
# TASK 5.4 - Habilitar VM Insights
# ============================================================

# VM Insights e uma solucao que fornece:
#   - Performance detalhada (CPU, memoria, disco, rede)
#   - Mapa de dependencias (processos e conexoes de rede)
#   - Tendencias de performance ao longo do tempo

# VM Insights requer:
#   1. Azure Monitor Agent (AMA) instalado (Task 5.1)
#   2. Log Analytics Workspace configurado (Task 4.4)
#   3. Dependency Agent (para mapa de dependencias)

# Instalar Dependency Agent (necessario para mapa de dependencias)
# O Dependency Agent captura dados de conexoes TCP e processos
Set-AzVMExtension `
    -ResourceGroupName $vmRg `
    -VMName $vmName `
    -Name "DependencyAgentWindows" `
    -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" `
    -ExtensionType "DependencyAgentWindows" `
    -TypeHandlerVersion "9.10" `
    -Location $location `
    -EnableAutomaticUpgrade $true

Write-Host "Dependency Agent instalado na VM $vmName"

# Habilitar VM Insights
# NOTA: VM Insights e habilitado automaticamente quando AMA + Dependency Agent estao instalados
# e a DCR esta configurada para coletar metricas de performance.
# O portal mostra os dados em: VM → Monitoring → Insights
#
# Para verificar se VM Insights esta ativo via PowerShell:
$vmInsightsStatus = Get-AzVMExtension -ResourceGroupName $vmRg -VMName $vmName |
    Where-Object { $_.ExtensionType -in @('AzureMonitorLinuxAgent', 'AzureMonitorWindowsAgent', 'DependencyAgentWindows', 'DependencyAgentLinux') }

if ($vmInsightsStatus.Count -ge 2) {
    Write-Host "✓ VM Insights pre-requisitos instalados (AMA + Dependency Agent)"
    Write-Host "  Dados aparecerao em: Portal → VM $vmName → Monitoring → Insights"
} else {
    Write-Host "⚠ VM Insights requer AMA + Dependency Agent. Extensoes encontradas:"
    $vmInsightsStatus | Select-Object Name, ExtensionType, ProvisioningState | Format-Table
}

Write-Host "`nPara verificar no portal:"
Write-Host "1. Portal Azure → VM $vmName → Monitoring → Insights"
Write-Host "2. Se 'Not configured', clique em 'Enable' e selecione o workspace $workspaceName"

# Verificar extensoes instaladas (AMA + Dependency Agent)
Write-Host "`n=== Extensoes instaladas na VM ==="
Get-AzVMExtension -ResourceGroupName $vmRg -VMName $vmName |
    Select-Object Name, Publisher, ExtensionType, ProvisioningState |
    Format-Table -AutoSize
```

> **Conceito VM Insights:** Fornece tres visualizacoes principais:
> 1. **Performance:** metricas detalhadas com tendencias
> 2. **Map:** mapa de processos e conexoes de rede (requer Dependency Agent)
> 3. **Health:** status de saude da VM (preview)

---

### Task 5.5: Network Watcher e Connection Monitor

```powershell
# ============================================================
# TASK 5.5 - Network Watcher e Connection Monitor
# ============================================================

# Network Watcher e um servico de diagnostico de rede do Azure
# Funcionalidades: Connection Monitor, IP Flow Verify, NSG Flow Logs,
#                  Packet Capture, Next Hop, Topology

# Verificar se Network Watcher esta habilitado na regiao
# Network Watcher e criado automaticamente quando voce cria a primeira VNet
$networkWatcher = Get-AzNetworkWatcher |
    Where-Object { $_.Location -eq $location }

if ($networkWatcher) {
    Write-Host "Network Watcher encontrado: $($networkWatcher.Name) em $($networkWatcher.Location)"
} else {
    # Criar Network Watcher se nao existir
    Write-Host "Network Watcher nao encontrado. Criando..."
    $networkWatcher = New-AzNetworkWatcher `
        -Name "NetworkWatcher_$location" `
        -ResourceGroupName "NetworkWatcherRG" `
        -Location $location

    Write-Host "Network Watcher criado: $($networkWatcher.Name)"
}

# Connection Monitor: monitora conectividade entre endpoints
# Testa continuamente a conexao e alerta quando ha problemas

# Instalar extensao Network Watcher na VM (pre-requisito)
Set-AzVMExtension `
    -ResourceGroupName $vmRg `
    -VMName $vmName `
    -Name "NetworkWatcherAgentWindows" `
    -Publisher "Microsoft.Azure.NetworkWatcher" `
    -ExtensionType "NetworkWatcherAgentWindows" `
    -TypeHandlerVersion "1.4" `
    -Location $location

Write-Host "Network Watcher Agent instalado na VM $vmName"

# Criar Connection Monitor
# Monitora conectividade da VM para um endpoint externo
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName

# Definir source endpoint (VM)
$sourceEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -AzureVM `
    -Name "source-vm" `
    -ResourceId $vm.Id

# Definir destination endpoint (endpoint externo)
$destEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -ExternalAddress `
    -Name "destination-bing" `
    -Address "www.bing.com"

# Definir configuracao de teste
$testConfig = New-AzNetworkWatcherConnectionMonitorTestConfigurationObject `
    -Name "tcp-443-test" `
    -TestFrequencySec 60 `
    -ProtocolTcp `
    -TcpPort 443

# Definir grupo de teste
$testGroup = New-AzNetworkWatcherConnectionMonitorTestGroupObject `
    -Name "test-group-1" `
    -TestConfiguration @($testConfig) `
    -Source @($sourceEndpoint) `
    -Destination @($destEndpoint)

# Criar Connection Monitor
$connMonitor = New-AzNetworkWatcherConnectionMonitor `
    -NetworkWatcherName $networkWatcher.Name `
    -ResourceGroupName $networkWatcher.ResourceGroupName `
    -Name "alert-conn-monitor" `
    -TestGroup @($testGroup) `
    -WorkspaceResourceId $workspace.ResourceId

Write-Host "`nConnection Monitor criado: alert-conn-monitor"
Write-Host "Source: $vmName"
Write-Host "Destination: www.bing.com:443"
Write-Host "Frequencia: a cada 60 segundos"
Write-Host "Dados enviados para: $workspaceName"
```

> **Conceito Network Watcher:** Ferramentas de diagnostico de rede:
> - **Connection Monitor:** monitora conectividade continuamente
> - **IP Flow Verify:** testa se NSG permite/bloqueia trafego
> - **Next Hop:** mostra a proxima rota para um destino
> - **Packet Capture:** captura pacotes na VM
> - **NSG Flow Logs:** registra todo trafego que passa pelo NSG

---

### Task 5.6: IP Flow Verify e Next Hop

```powershell
# ============================================================
# TASK 5.6 - IP Flow Verify e Next Hop
# ============================================================

# IP Flow Verify: testa se uma regra de NSG permite ou bloqueia trafego
# Util para diagnosticar problemas de conectividade

$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName
$nic = Get-AzNetworkInterface -ResourceGroupName $vmRg |
    Where-Object { $_.VirtualMachine.Id -eq $vm.Id } |
    Select-Object -First 1

if ($nic) {
    $localIP = $nic.IpConfigurations[0].PrivateIpAddress

    # Test-AzNetworkWatcherIPFlow: verifica se trafego e permitido/bloqueado
    # -Direction: Inbound ou Outbound
    # -Protocol: TCP ou UDP
    # -LocalIPAddress: IP da VM
    # -LocalPort: porta local
    # -RemoteIPAddress: IP remoto
    # -RemotePort: porta remota
    Write-Host "=== IP Flow Verify: Testar HTTP Outbound ==="
    $flowResult = Test-AzNetworkWatcherIPFlow `
        -NetworkWatcher $networkWatcher `
        -TargetVirtualMachineId $vm.Id `
        -Direction "Outbound" `
        -Protocol "TCP" `
        -LocalIPAddress $localIP `
        -LocalPort "50000" `
        -RemoteIPAddress "8.8.8.8" `
        -RemotePort "443"

    Write-Host "Acesso: $($flowResult.Access)"
    Write-Host "Regra: $($flowResult.RuleName)"

    # Get-AzNetworkWatcherNextHop: mostra o proximo salto na rota
    Write-Host "`n=== Next Hop: Rota para 8.8.8.8 ==="
    $nextHop = Get-AzNetworkWatcherNextHop `
        -NetworkWatcher $networkWatcher `
        -TargetVirtualMachineId $vm.Id `
        -SourceIPAddress $localIP `
        -DestinationIPAddress "8.8.8.8"

    Write-Host "Next Hop Type: $($nextHop.NextHopType)"
    Write-Host "Next Hop IP: $($nextHop.NextHopIpAddress)"
    Write-Host "Route Table: $($nextHop.RouteTableId)"
} else {
    Write-Host "NIC da VM nao encontrada." -ForegroundColor Yellow
}
```

---

### Task 5.9b: NSG Flow Logs com Traffic Analytics

```powershell
# ============================================================
# TASK 5.9b - Configurar NSG Flow Logs com Traffic Analytics
# ============================================================
# Flow Logs registram todo trafego que passa pelo NSG (permitido e negado).
# Traffic Analytics agrega os dados no Log Analytics para visualizacao.

# Obter NSG, Storage Account e Workspace
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $vmRg -Name "nsg-contoso"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $vmRg |
    Select-Object -First 1

# Configurar Traffic Analytics
$trafficAnalyticsConfig = New-AzNetworkWatcherFlowLogTrafficAnalyticsConfigurationObject `
    -Enabled $true `
    -WorkspaceResourceId $workspace.ResourceId `
    -TrafficAnalyticsInterval 10

# New-AzNetworkWatcherFlowLog: cria NSG Flow Log
# -NetworkWatcherName: nome do Network Watcher na regiao
# -FlowLogName: nome do flow log
# -TargetResourceId: ID do NSG monitorado
# -StorageAccountId: storage para armazenar logs brutos
# -Enabled: habilitar coleta
# -FormatVersion: 2 = inclui estado do fluxo (Begin, Continuing, End)
# -RetentionInDays: dias para manter logs no storage
# -EnableTrafficAnalytics: habilitar Traffic Analytics
New-AzNetworkWatcherFlowLog `
    -NetworkWatcherName $networkWatcher.Name `
    -ResourceGroupName $networkWatcher.ResourceGroupName `
    -FlowLogName "nsg-flow-log" `
    -TargetResourceId $nsg.Id `
    -StorageAccountId $storageAccount.Id `
    -Enabled $true `
    -FormatVersion 2 `
    -RetentionInDays 30 `
    -TrafficAnalyticsConfiguration $trafficAnalyticsConfig

Write-Host "NSG Flow Log criado com Traffic Analytics habilitado"
Write-Host "NSG: $($nsg.Name)"
Write-Host "Storage: $($storageAccount.StorageAccountName)"
Write-Host "Workspace: $($workspace.Name)"
Write-Host "Dados ficam no storage: insights-logs-networksecuritygroupflowevent"
```

> **Conceito AZ-104 — NSG Flow Logs:**
> - Flow Logs v2 inclui estado do fluxo (Begin, Continuing, End) e throughput
> - Traffic Analytics agrega flow logs no Log Analytics para visualizacao
> - Dados ficam no storage account: `insights-logs-networksecuritygroupflowevent`
> - Retencao: 0 = ilimitado (dependendo do storage); recomendado >= 30 dias
> - Na prova: "analisar trafego de rede" = NSG Flow Logs + Traffic Analytics

---

## Modo Desafio - Bloco 5

- [ ] Instalar Azure Monitor Agent (AMA) na VM
- [ ] Criar Data Collection Rule com Performance Counters e Event Logs
- [ ] Associar DCR a VM com `New-AzDataCollectionRuleAssociation`
- [ ] Executar queries KQL: Event errors, CPU usage, Heartbeat
- [ ] Instalar Dependency Agent e entender VM Insights
- [ ] Criar Connection Monitor com Network Watcher
- [ ] Usar IP Flow Verify e Next Hop para diagnostico de rede

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Voce precisa coletar logs de performance e eventos do Windows de 50 VMs e enviar para um Log Analytics Workspace. Qual e a abordagem recomendada?**

A) Instalar MMA (Microsoft Monitoring Agent) em cada VM
B) Instalar AMA (Azure Monitor Agent) e criar uma Data Collection Rule
C) Configurar Diagnostic Settings em cada VM individualmente
D) Usar Azure Automation para coletar logs periodicamente

<details>
<summary>Ver resposta</summary>

**Resposta: B) Instalar AMA (Azure Monitor Agent) e criar uma Data Collection Rule**

AMA com DCR e a abordagem moderna e recomendada. Uma unica DCR pode ser associada a multiplas VMs, simplificando o gerenciamento. MMA esta sendo descontinuado.

</details>

### Questao 5.2
**Voce quer verificar se uma regra de NSG esta bloqueando trafego SSH (porta 22) para uma VM. Qual ferramenta do Network Watcher voce deve usar?**

A) Connection Monitor
B) IP Flow Verify
C) Next Hop
D) Packet Capture

<details>
<summary>Ver resposta</summary>

**Resposta: B) IP Flow Verify**

**IP Flow Verify** testa se uma combinacao especifica de IP/porta/protocolo e permitida ou bloqueada pelas regras do NSG. Retorna a regra exata que permite ou bloqueia o trafego.

</details>

### Questao 5.3
**Qual query KQL retorna o uso medio de CPU dos ultimos 30 minutos, agrupado em intervalos de 5 minutos?**

A) `Perf | where CounterName == "% Processor Time" | summarize avg(CounterValue) by bin(TimeGenerated, 5m)`
B) `Metrics | where Name == "CPU" | average by 5m`
C) `Event | where Type == "CPU" | group by 5m`
D) `InsightsMetrics | where Name == "CPU" | aggregate avg(Val) by 5m`

<details>
<summary>Ver resposta</summary>

**Resposta: A) `Perf | where CounterName == "% Processor Time" | summarize avg(CounterValue) by bin(TimeGenerated, 5m)`**

KQL usa a tabela **Perf** para dados de performance counters. `summarize avg()` calcula a media e `bin(TimeGenerated, 5m)` agrupa em intervalos de 5 minutos.

</details>

### Questao 5.4
**Qual e a diferenca entre Azure Monitor Agent (AMA) e o Dependency Agent?**

A) AMA coleta metricas, Dependency Agent coleta logs
B) AMA coleta logs e metricas, Dependency Agent captura processos e conexoes de rede para VM Insights Map
C) Sao o mesmo agente com nomes diferentes
D) Dependency Agent substitui o AMA

<details>
<summary>Ver resposta</summary>

**Resposta: B) AMA coleta logs e metricas, Dependency Agent captura processos e conexoes de rede para VM Insights Map**

**AMA** coleta logs, metricas e eventos do SO. **Dependency Agent** captura dados de processos e conexoes TCP para a funcionalidade **Map** do VM Insights. Ambos sao necessarios para VM Insights completo.

</details>

### Questao 5.5
**Voce quer monitorar continuamente a conectividade entre uma VM no Azure e um servidor on-premises. Qual ferramenta usar?**

A) IP Flow Verify
B) Connection Monitor
C) Next Hop
D) Diagnostic Settings

<details>
<summary>Ver resposta</summary>

**Resposta: B) Connection Monitor**

**Connection Monitor** monitora conectividade de forma continua, testando periodicamente a conexao entre endpoints. IP Flow Verify e Next Hop sao verificacoes pontuais (on-demand).

</details>

---

# Bloco 6 - Backup Vault e VM Move

> **Contexto:** O Backup Vault e o servico mais recente de backup do Azure, projetado para workloads
> que o Recovery Services Vault nao suporta (Disks, Blobs, PostgreSQL, AKS). Neste bloco voce tambem
> pratica mover VMs entre Resource Groups — topico cobrado no AZ-104 (dominio Compute).
>
> **Resource Groups:** `rg-contoso-compute` (VMs da Semana 2) + `rg-contoso-management` (Backup Vault) + `rg-contoso-moved` (destino do move)
>
> **Modulo principal:** `Az.DataProtection` (Backup Vault) + `Az.Resources` (VM Move)

---

### Task 6.1: Mover VM para outro Resource Group (PowerShell)

```powershell
# ============================================================
# TASK 6.1 - Mover VM entre Resource Groups
# ============================================================
# Move de recursos entre RGs:
# - NAO requer downtime (VM continua running)
# - Altera o resource ID (novo RG no path)
# - Regiao e configuracoes permanecem iguais
# - Recursos dependentes (NIC, Disk, PIP) devem ser movidos JUNTOS
#
# Cmdlet principal: Move-AzResource (modulo Az.Resources)
# - Aceita um array de resource IDs
# - -DestinationResourceGroupName: RG de destino
# ============================================================

# Criar RG de destino
New-AzResourceGroup -Name "rg-contoso-moved" -Location "eastus"

# Obter a VM e seus recursos dependentes
$vm = Get-AzVM -ResourceGroupName "rg-contoso-compute" -Name "vm-api-01"

# Obter IDs dos recursos dependentes
# IMPORTANTE: VM + NIC + Disk devem ir juntos
$vmId = $vm.Id
$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$diskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id

Write-Host "VM ID: $vmId"
Write-Host "NIC ID: $nicId"
Write-Host "Disk ID: $diskId"

# Move-AzResource: move recursos entre Resource Groups
# - Aceita array de IDs: todos movidos atomicamente
# - -Force: nao pede confirmacao interativa
# - NAO desliga a VM (move entre RGs e sem downtime)
Move-AzResource `
    -DestinationResourceGroupName "rg-contoso-moved" `
    -ResourceId @($vmId, $nicId, $diskId) `
    -Force

# Validar: VM agora esta no novo RG
Get-AzVM -ResourceGroupName "rg-contoso-moved" -Name "vm-api-01" |
    Select-Object Name, ResourceGroupName, Location |
    Format-Table
```

> **Conceito AZ-104:** `Move-AzResource` altera o Resource Group no resource ID mas NAO altera
> a regiao, configuracao ou estado do recurso. A VM continua running durante o move.

---

### Task 6.2: Entender limitacoes de move e mover VM de volta

```powershell
# ============================================================
# TASK 6.2 - Limitacoes de Move e reverter
# ============================================================
# Tipos de move no Azure:
#
# | Cenario                       | Metodo                       | Downtime |
# |-------------------------------|------------------------------|----------|
# | Move entre RGs (mesma regiao) | Move-AzResource              | Nenhum   |
# | Move entre regioes            | ASR / Azure Resource Mover   | Minimo   |
# | Move entre subscriptions      | Move-AzResource              | Nenhum   |
#
# LIMITACOES IMPORTANTES:
# - Nem todos os recursos suportam move (verificar support matrix)
# - Recursos com locks NAO podem ser movidos (remover lock antes)
# - Move entre regioes NAO usa Move-AzResource — requer ASR ou recriar
# - Recursos dependentes DEVEM ser movidos juntos
# ============================================================

# Obter recursos no RG de destino
$vm = Get-AzVM -ResourceGroupName "rg-contoso-moved" -Name "vm-api-01"
$vmId = $vm.Id
$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$diskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id

# Mover VM de volta ao RG original
Move-AzResource `
    -DestinationResourceGroupName "rg-contoso-compute" `
    -ResourceId @($vmId, $nicId, $diskId) `
    -Force

# Validar: VM de volta ao RG original
Get-AzVM -ResourceGroupName "rg-contoso-compute" -Name "vm-api-01" |
    Select-Object Name, ResourceGroupName |
    Format-Table

Write-Host "VM movida de volta para rg-contoso-compute com sucesso" -ForegroundColor Green
```

> **Conexao com Bloco 3:** Para mover VMs entre regioes, use Azure Site Recovery (configurado no Bloco 3).
> `Move-AzResource` NAO suporta move cross-region para VMs.

---

### Task 6.3: Criar Azure Backup Vault via PowerShell

```powershell
# ============================================================
# TASK 6.3 - Criar Backup Vault + Disk Backup Policy
# ============================================================
# Modulo: Az.DataProtection
# - New-AzDataProtectionBackupVault: cria o Backup Vault
# - New-AzDataProtectionBackupPolicy: cria policy de backup
#
# Backup Vault vs Recovery Services Vault:
# - Backup Vault (Microsoft.DataProtection): Disks, Blobs, PostgreSQL, AKS
# - Recovery Services Vault (Microsoft.RecoveryServices): VMs, Files, ASR
#
# O Backup Vault e o servico mais recente. A Microsoft esta migrando
# workloads gradualmente. No AZ-104, saber qual vault suporta
# qual workload e critico para a prova.
# ============================================================

# Variaveis
$bvRg = "rg-contoso-management"
$bvName = "bv-contoso-disks"
$location = "eastus"
$policyName = "bv-contoso-disks-disk-policy"

# Criar Resource Group
New-AzResourceGroup -Name $bvRg -Location $location

# ============================================================
# Criar Backup Vault
# ============================================================
# New-AzDataProtectionBackupVault:
# - StorageSetting: define redundancia e tipo de datastore
#   New-AzDataProtectionBackupVaultStorageSetting cria o objeto
# - -IdentityType: SystemAssigned = managed identity para acesso a discos
#   O vault precisa de roles: Disk Backup Reader + Disk Snapshot Contributor
# ============================================================

# Criar storage setting (LRS para lab, GRS para producao)
$storageSetting = New-AzDataProtectionBackupVaultStorageSetting `
    -DataStoreType VaultStore `
    -Type LocallyRedundant

# Criar o Backup Vault
$backupVault = New-AzDataProtectionBackupVault `
    -ResourceGroupName $bvRg `
    -VaultName $bvName `
    -Location $location `
    -StorageSetting $storageSetting `
    -IdentityType "SystemAssigned"

Write-Host "Backup Vault criado: $($backupVault.Name)" -ForegroundColor Green
Write-Host "Principal ID: $($backupVault.IdentityPrincipalId)"

# ============================================================
# Criar Disk Backup Policy
# ============================================================
# New-AzDataProtectionBackupPolicy:
# - Usa um "policy template" como base (Get-AzDataProtectionPolicyTemplate)
# - O template traz as regras padrao para o tipo de datasource
# - Voce pode customizar schedule e retention antes de criar
#
# Disk backup usa snapshots incrementais:
# - Primeiro snapshot: copia completa do disco
# - Snapshots seguintes: apenas deltas (blocos alterados)
# - Menor custo e tempo que VM backup completo do RSV
# ============================================================

# Obter policy template para Azure Disk
# Get-AzDataProtectionPolicyTemplate: retorna o esqueleto da policy
# -DatasourceType: AzureDisk para backup de discos gerenciados
$policyTemplate = Get-AzDataProtectionPolicyTemplate -DatasourceType AzureDisk

# Customizar retencao: 30 dias (padrao pode ser 7)
# O template retorna um objeto que pode ser modificado antes de criar
# policyRules[1] = regra de retencao (Default)
# lifecycles[0].deleteAfter.duration = periodo ISO 8601
$policyTemplate.PolicyRule[1].Lifecycle[0].DeleteAfterDuration = "P30D"

# Criar a policy no vault
$diskPolicy = New-AzDataProtectionBackupPolicy `
    -ResourceGroupName $bvRg `
    -VaultName $bvName `
    -Name $policyName `
    -Policy $policyTemplate

Write-Host "Disk Backup Policy criada: $($diskPolicy.Name)" -ForegroundColor Green
Write-Host "Retencao: $($diskPolicy.Property.PolicyRule[1].Lifecycle[0].DeleteAfterDuration)"

# Validar
Get-AzDataProtectionBackupPolicy `
    -ResourceGroupName $bvRg `
    -VaultName $bvName |
    Select-Object Name |
    Format-Table
```

---

### Task 6.4: Comparar Backup Vault vs Recovery Services Vault

> **Esta task e conceitual — nao requer script PowerShell.**
> A tabela abaixo e a referencia principal para o AZ-104.

| Aspecto | Recovery Services Vault (RSV) | Backup Vault (BV) |
|---------|-------------------------------|---------------------|
| **Tipo ARM** | `Microsoft.RecoveryServices/vaults` | `Microsoft.DataProtection/backupVaults` |
| **Modulo PowerShell** | `Az.RecoveryServices` | `Az.DataProtection` |
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
| **Criar vault** | `New-AzRecoveryServicesVault` | `New-AzDataProtectionBackupVault` |
| **Criar policy** | `New-AzRecoveryServicesBackupProtectionPolicy` | `New-AzDataProtectionBackupPolicy` |

> **Dica AZ-104:** Na prova, saber qual vault suporta qual workload e critico.
> VM backup = RSV. Disk backup = BV. File Share = RSV. Blob backup = BV. Site Recovery = RSV apenas.
> O **Backup Center** no portal unifica a gestao de ambos os vaults.

---

### Task 6.5: Configurar backup de disco no Backup Vault

```powershell
# ============================================================
# TASK 6.5 - Configurar Disk Backup Instance
# ============================================================
# Passos:
# 1. Atribuir roles ao Backup Vault (managed identity)
# 2. Inicializar e criar a backup instance
#
# Roles necessarias:
# - Disk Backup Reader: no RG do disco (para ler dados)
# - Disk Snapshot Contributor: no RG de snapshots (para criar snapshots)
#
# Cmdlets principais:
# - Initialize-AzDataProtectionBackupInstance: prepara configuracao
# - New-AzDataProtectionBackupInstance: cria e ativa protecao
# ============================================================

# Variaveis
$bvRg = "rg-contoso-management"
$bvName = "bv-contoso-disks"
$vmRg = "rg-contoso-compute"
$vmName = "vm-api-01"
$policyName = "bv-contoso-disks-disk-policy"

# Obter o Backup Vault e a VM
$backupVault = Get-AzDataProtectionBackupVault -ResourceGroupName $bvRg -VaultName $bvName
$vm = Get-AzVM -ResourceGroupName $vmRg -Name $vmName
$diskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id

# Obter IDs para role assignments
$principalId = $backupVault.IdentityPrincipalId
$diskRgId = (Get-AzResourceGroup -Name $vmRg).ResourceId
$snapshotRgId = (Get-AzResourceGroup -Name $bvRg).ResourceId

Write-Host "Vault Principal ID: $principalId"
Write-Host "Disk ID: $diskId"

# ============================================================
# 1. Atribuir roles ao vault
# ============================================================
# New-AzRoleAssignment: atribui role RBAC
# - Disk Backup Reader: permite ao vault ler dados do disco
# - Disk Snapshot Contributor: permite criar snapshots
# ============================================================

# Role: Disk Backup Reader no RG do disco
New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName "Disk Backup Reader" `
    -Scope $diskRgId `
    -ErrorAction SilentlyContinue

# Role: Disk Snapshot Contributor no RG de snapshots
New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName "Disk Snapshot Contributor" `
    -Scope $snapshotRgId `
    -ErrorAction SilentlyContinue

Write-Host "Roles atribuidas. Aguardando propagacao (30s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# ============================================================
# 2. Criar Backup Instance
# ============================================================
# Initialize-AzDataProtectionBackupInstance:
# - Prepara o objeto de configuracao (nao cria ainda)
# - -DatasourceType: AzureDisk
# - -DatasourceId: ID do disco a proteger
# - -PolicyId: ID da policy de backup
# - -SnapshotResourceGroupId: RG onde ficam os snapshots
#
# New-AzDataProtectionBackupInstance:
# - Cria a backup instance (ativa a protecao)
# - Usa o objeto retornado por Initialize-
# ============================================================

# Obter a policy
$policy = Get-AzDataProtectionBackupPolicy `
    -ResourceGroupName $bvRg `
    -VaultName $bvName `
    -Name $policyName

# Inicializar (preparar configuracao)
$backupInstance = Initialize-AzDataProtectionBackupInstance `
    -DatasourceType AzureDisk `
    -DatasourceLocation $backupVault.Location `
    -DatasourceId $diskId `
    -PolicyId $policy.Id `
    -SnapshotResourceGroupId $snapshotRgId

# Criar a backup instance (ativar protecao)
New-AzDataProtectionBackupInstance `
    -ResourceGroupName $bvRg `
    -VaultName $bvName `
    -BackupInstance $backupInstance

# Validar: disco protegido
Get-AzDataProtectionBackupInstance `
    -ResourceGroupName $bvRg `
    -VaultName $bvName |
    Select-Object Name, @{N="Status";E={$_.Property.CurrentProtectionState}} |
    Format-Table

Write-Host ""
Write-Host "=== Disk Backup Configurado ===" -ForegroundColor Green
Write-Host "O Backup Vault criara snapshots incrementais conforme a policy"
Write-Host "Snapshots ficam no OperationalStore (rapido para restore)"
```

> **Conceito:** Disk backup usa snapshots incrementais — apenas blocos alterados desde o ultimo snapshot
> sao capturados. Isso e mais eficiente que VM backup completo do RSV.
> Ideal para proteger discos individuais sem overhead de backup de VM.

---

## Modo Desafio - Bloco 6

- [ ] Criar RG `rg-contoso-moved` e mover VM Linux via `Move-AzResource`
- [ ] Verificar recursos dependentes movidos junto (NIC, Disk)
- [ ] Entender as diferencas entre move entre RGs vs move entre regioes
- [ ] Mover VM de volta ao RG original
- [ ] Criar Backup Vault `bv-contoso-disks` (LRS) com `New-AzDataProtectionBackupVault`
- [ ] Criar disk backup policy com `New-AzDataProtectionBackupPolicy`
- [ ] Comparar workloads suportados: RSV vs Backup Vault (tabela conceitual)
- [ ] Configurar backup de disco via `Initialize-`/`New-AzDataProtectionBackupInstance`
- [ ] Validar backup instance no Backup Vault

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce precisa mover uma VM para outro Resource Group na mesma regiao usando PowerShell. Qual cmdlet usar?**

A) `Set-AzResource -ResourceGroupName`
B) `Move-AzResource -DestinationResourceGroupName`
C) `Copy-AzResource -DestinationResourceGroupName`
D) `New-AzResourceGroupDeployment`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `Move-AzResource -DestinationResourceGroupName`**

`Move-AzResource` move recursos entre Resource Groups ou subscriptions. Aceita um array de `-ResourceId` para mover recursos dependentes juntos. A VM NAO precisa ser desligada para move entre RGs na mesma regiao.

</details>

### Questao 6.2
**Qual modulo PowerShell contem os cmdlets para Azure Backup Vault?**

A) Az.RecoveryServices
B) Az.DataProtection
C) Az.Backup
D) Az.Storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) Az.DataProtection**

O modulo `Az.DataProtection` contem cmdlets para o Backup Vault (`New-AzDataProtectionBackupVault`, `New-AzDataProtectionBackupPolicy`, etc.). O modulo `Az.RecoveryServices` e para o Recovery Services Vault. Sao modulos diferentes para vaults diferentes.

</details>

### Questao 6.3
**Qual cmdlet PowerShell prepara a configuracao de uma backup instance ANTES de cria-la no Backup Vault?**

A) `New-AzDataProtectionBackupInstance`
B) `Set-AzDataProtectionBackupInstance`
C) `Initialize-AzDataProtectionBackupInstance`
D) `Enable-AzDataProtectionBackupInstance`

<details>
<summary>Ver resposta</summary>

**Resposta: C) `Initialize-AzDataProtectionBackupInstance`**

O padrao em Az.DataProtection e: `Initialize-` prepara o objeto de configuracao (datasource, policy, snapshot RG), depois `New-` cria efetivamente a backup instance no vault. Isso permite validar a configuracao antes de criar.

</details>

---

## Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

```powershell
# Pausar
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-api-01 -Force

# Retomar
Start-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01
Start-AzVM -ResourceGroupName rg-contoso-compute -Name vm-api-01
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos.
> Execute os comandos na ordem indicada: desabilitar backup ANTES de deletar o vault,
> depois Resource Groups. O Backup Vault tambem requer remover backup instances antes da exclusao.

```powershell
# ============================================================
# CLEANUP - Remover TODOS os recursos criados
# ============================================================

# 1. Desabilitar backup da VM ANTES de deletar o vault
#    OBRIGATORIO: nao e possivel deletar vault com itens protegidos
Write-Host "1. Desabilitando backup da VM..." -ForegroundColor Yellow

$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rg11
Set-AzRecoveryServicesVaultContext -Vault $vault

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType "AzureVM" `
    -FriendlyName $vmName `
    -VaultId $vault.ID `
    -ErrorAction SilentlyContinue

if ($container) {
    $backupItem = Get-AzRecoveryServicesBackupItem `
        -Container $container `
        -WorkloadType "AzureVM" `
        -VaultId $vault.ID

    # Disable-AzRecoveryServicesBackupProtection: desabilita protecao
    # -RemoveRecoveryPoints: deleta TODOS os recovery points (libera storage)
    # -Force: nao pede confirmacao
    Disable-AzRecoveryServicesBackupProtection `
        -Item $backupItem `
        -RemoveRecoveryPoints `
        -Force `
        -VaultId $vault.ID

    Write-Host "  Backup da VM desabilitado e recovery points removidos"
}

# 2. Desabilitar backup de File Shares
Write-Host "2. Desabilitando backup de File Shares..." -ForegroundColor Yellow
$fileContainers = Get-AzRecoveryServicesBackupContainer `
    -ContainerType "AzureStorage" `
    -VaultId $vault.ID `
    -ErrorAction SilentlyContinue

foreach ($fc in $fileContainers) {
    $fileItems = Get-AzRecoveryServicesBackupItem `
        -Container $fc `
        -WorkloadType "AzureFiles" `
        -VaultId $vault.ID

    foreach ($fi in $fileItems) {
        Disable-AzRecoveryServicesBackupProtection `
            -Item $fi `
            -RemoveRecoveryPoints `
            -Force `
            -VaultId $vault.ID
    }

    # Unregister storage account do vault
    Unregister-AzRecoveryServicesBackupContainer `
        -Container $fc `
        -Force `
        -VaultId $vault.ID
}
Write-Host "  File Share backups desabilitados"

# 3. Deletar Recovery Services Vault (backup)
Write-Host "3. Removendo Recovery Services Vault (backup)..." -ForegroundColor Yellow
Remove-AzRecoveryServicesVault -Vault $vault -ErrorAction SilentlyContinue
Write-Host "  Vault de backup removido"

# 4. Desabilitar replicacao e deletar vault DR
Write-Host "4. Removendo recursos de Site Recovery..." -ForegroundColor Yellow
$vaultDR = Get-AzRecoveryServicesVault -Name $vaultNameDR -ResourceGroupName $rg12 -ErrorAction SilentlyContinue
if ($vaultDR) {
    Set-AzRecoveryServicesVaultContext -Vault $vaultDR

    # Remover itens replicados
    $sourceFabric = Get-AzRecoveryServicesAsrFabric -Name $fabricSource -ErrorAction SilentlyContinue
    if ($sourceFabric) {
        $containers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $sourceFabric -ErrorAction SilentlyContinue
        foreach ($c in $containers) {
            $items = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $c -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Remove-AzRecoveryServicesAsrReplicationProtectedItem -InputObject $item -Force
            }
        }
    }

    # Aguardar limpeza
    Start-Sleep -Seconds 30

    Remove-AzRecoveryServicesVault -Vault $vaultDR -ErrorAction SilentlyContinue
    Write-Host "  Vault DR removido"
}

# 5. Remover backup instances do Backup Vault (Bloco 6)
Write-Host "5. Removendo Backup Vault instances..." -ForegroundColor Yellow
$bvInstances = Get-AzDataProtectionBackupInstance `
    -ResourceGroupName "rg-contoso-management" `
    -VaultName "bv-contoso-disks" `
    -ErrorAction SilentlyContinue

foreach ($inst in $bvInstances) {
    # Suspender protecao antes de remover
    Suspend-AzDataProtectionBackupInstanceBackup `
        -ResourceGroupName "rg-contoso-management" `
        -VaultName "bv-contoso-disks" `
        -BackupInstanceName $inst.Name `
        -ErrorAction SilentlyContinue

    # Remover backup instance
    Remove-AzDataProtectionBackupInstance `
        -ResourceGroupName "rg-contoso-management" `
        -VaultName "bv-contoso-disks" `
        -Name $inst.Name `
        -ErrorAction SilentlyContinue

    Write-Host "  Backup instance $($inst.Name) removida"
}

# 6. Remover Connection Monitor
Write-Host "6. Removendo Connection Monitor..." -ForegroundColor Yellow
$networkWatcher = Get-AzNetworkWatcher | Where-Object { $_.Location -eq $location }
if ($networkWatcher) {
    Remove-AzNetworkWatcherConnectionMonitor `
        -NetworkWatcherName $networkWatcher.Name `
        -ResourceGroupName $networkWatcher.ResourceGroupName `
        -Name "alert-conn-monitor" `
        -ErrorAction SilentlyContinue
    Write-Host "  Connection Monitor removido"
}

# 7. Remover extensoes da VM (AMA, Dependency Agent, Network Watcher)
Write-Host "7. Removendo extensoes da VM..." -ForegroundColor Yellow
@("AzureMonitorWindowsAgent", "DependencyAgentWindows", "NetworkWatcherAgentWindows") | ForEach-Object {
    Remove-AzVMExtension `
        -ResourceGroupName $vmRg `
        -VMName $vmName `
        -Name $_ `
        -Force `
        -ErrorAction SilentlyContinue
    Write-Host "  Extensao $_ removida"
}

# 8. Remover cache storage account
Write-Host "8. Removendo cache storage account..." -ForegroundColor Yellow
Get-AzStorageAccount -ResourceGroupName $rg11 |
    Where-Object { $_.StorageAccountName -like "stcontosocache*" } |
    ForEach-Object {
        Remove-AzStorageAccount -ResourceGroupName $rg11 -Name $_.StorageAccountName -Force
        Write-Host "  Storage account $($_.StorageAccountName) removida"
    }

# 9. Deletar Resource Groups (todos os recursos restantes)
Write-Host "9. Deletando Resource Groups..." -ForegroundColor Yellow
Remove-AzResourceGroup -Name $rg11 -Force -AsJob            # Backup vault + policies
Remove-AzResourceGroup -Name $rg12 -Force -AsJob            # Site Recovery
Remove-AzResourceGroup -Name $rg13 -Force -AsJob            # Monitor + Log Analytics
Remove-AzResourceGroup -Name "rg-contoso-management" -Force -AsJob    # Backup Vault
Remove-AzResourceGroup -Name "rg-contoso-moved" -Force -AsJob -ErrorAction SilentlyContinue  # Move RG
Write-Host "  RGs sendo deletados em background..."

# 10. Reverter configuracoes de protecao de blobs (opcional)
Write-Host "10. Revertendo protecao de blobs..." -ForegroundColor Yellow
$storageAcct = Get-AzStorageAccount -ResourceGroupName $storageRg -ErrorAction SilentlyContinue | Select-Object -First 1
if ($storageAcct) {
    Disable-AzStorageBlobRestorePolicy `
        -ResourceGroupName $storageRg `
        -StorageAccountName $storageAcct.StorageAccountName `
        -ErrorAction SilentlyContinue

    Update-AzStorageBlobServiceProperty `
        -ResourceGroupName $storageRg `
        -StorageAccountName $storageAcct.StorageAccountName `
        -EnableChangeFeed $false `
        -IsVersioningEnabled $false `
        -ErrorAction SilentlyContinue

    Disable-AzStorageBlobDeleteRetentionPolicy `
        -ResourceGroupName $storageRg `
        -StorageAccountName $storageAcct.StorageAccountName `
        -ErrorAction SilentlyContinue

    Disable-AzStorageContainerDeleteRetentionPolicy `
        -ResourceGroupName $storageRg `
        -StorageAccountName $storageAcct.StorageAccountName `
        -ErrorAction SilentlyContinue

    Write-Host "  Protecao de blobs revertida"
}

# 11. Aguardar RGs serem deletados
Write-Host "`n11. Aguardando exclusao dos RGs..." -ForegroundColor Yellow
Get-Job | Wait-Job | Out-Null
Write-Host "  Todos os RGs deletados"

Write-Host "`n=== CLEANUP COMPLETO ===" -ForegroundColor Green
```

---

# Key Takeaways Consolidados

## Bloco 1 - VM Backup (Az.RecoveryServices)
- `New-AzRecoveryServicesVault` cria vault na **mesma regiao** do recurso
- `Set-AzRecoveryServicesVaultContext` define o vault ativo para cmdlets subsequentes
- `New-AzRecoveryServicesBackupProtectionPolicy` cria policy com schedule + retention
- `Enable-AzRecoveryServicesBackupProtection` habilita backup para VM/File Share
- `Backup-AzRecoveryServicesBackupItem` dispara backup on-demand
- `Restore-AzRecoveryServicesBackupItem` restaura (CreateVM ou RestoreDisks)
- **Gotcha:** Redundancia do vault so pode ser alterada ANTES do primeiro backup

## Bloco 2 - File/Blob Protection (Az.Storage)
- Backup de File Share usa Recovery Services Vault (snapshots)
- Protecao de Blobs usa features nativas: Soft Delete, Versioning, Point-in-Time Restore
- **Hierarquia:** Soft Delete (delecao) → Versioning (sobrescrita) → Point-in-Time Restore (restauracao)
- Point-in-Time Restore requer: Soft Delete + Versioning + Change Feed
- `RestoreDays` deve ser MENOR que `RetentionDays` do Soft Delete

## Bloco 3 - Site Recovery (Az.RecoveryServices ASR)
- Vault ASR fica na **regiao de destino** (oposto do Backup)
- Hierarquia: Vault → Fabric → Container → Protected Item
- `New-AzRecoveryServicesAsrFabric` cria representacao logica de uma regiao
- `New-AzRecoveryServicesAsrReplicationProtectedItem` inicia replicacao
- **Sempre** execute Test Failover + Cleanup antes de failover real
- **RPO** = perda maxima de dados; **RTO** = tempo maximo de restauracao

## Bloco 4 - Azure Monitor & Alerts (Az.Monitor)
- `New-AzActionGroup` com Location "Global" define notificacoes
- `Add-AzMetricAlertRuleV2` cria alertas baseados em metricas
- **WindowSize** = periodo de dados avaliado; **Frequency** = intervalo entre avaliacoes
- Diagnostic Settings enviam para: Log Analytics, Storage Account, Event Hub
- Severity: 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose

## Bloco 5 - Log Analytics & Insights (Az.OperationalInsights)
- **AMA** substitui MMA (legado); usa Data Collection Rules (DCRs)
- `New-AzDataCollectionRule` define o que coletar e para onde enviar
- KQL: `where`, `project`, `summarize`, `bin()`, `ago()`, `order by`, `take`
- VM Insights requer: AMA + Dependency Agent + Log Analytics Workspace
- Network Watcher: Connection Monitor (continuo), IP Flow Verify (pontual), Next Hop (rota)

## Bloco 6 - Backup Vault e VM Move (Az.DataProtection + Az.Resources)
- `Move-AzResource` move recursos entre RGs (sem downtime, mesma regiao)
- Move entre regioes requer ASR ou recriar (NAO usa Move-AzResource)
- `New-AzDataProtectionBackupVault` cria Backup Vault (diferente de RSV)
- `New-AzDataProtectionBackupPolicy` cria policy usando template (`Get-AzDataProtectionPolicyTemplate`)
- `Initialize-AzDataProtectionBackupInstance` → `New-AzDataProtectionBackupInstance` (padrao Initialize/New)
- Roles necessarias: Disk Backup Reader + Disk Snapshot Contributor
- Disk backup usa snapshots incrementais (menor custo que VM backup do RSV)

## Resumo de Cmdlets por Categoria

| Categoria | Cmdlet principal | Modulo |
|-----------|-----------------|--------|
| Vault | `New-AzRecoveryServicesVault` | Az.RecoveryServices |
| Vault Context | `Set-AzRecoveryServicesVaultContext` | Az.RecoveryServices |
| Backup Policy | `New-AzRecoveryServicesBackupProtectionPolicy` | Az.RecoveryServices |
| Enable Backup | `Enable-AzRecoveryServicesBackupProtection` | Az.RecoveryServices |
| Backup On-demand | `Backup-AzRecoveryServicesBackupItem` | Az.RecoveryServices |
| Recovery Points | `Get-AzRecoveryServicesBackupRecoveryPoint` | Az.RecoveryServices |
| Restore VM | `Restore-AzRecoveryServicesBackupItem` | Az.RecoveryServices |
| Disable Backup | `Disable-AzRecoveryServicesBackupProtection` | Az.RecoveryServices |
| Soft Delete Blob | `Enable-AzStorageBlobDeleteRetentionPolicy` | Az.Storage |
| Blob Versioning | `Update-AzStorageBlobServiceProperty` | Az.Storage |
| Point-in-Time | `Enable-AzStorageBlobRestorePolicy` | Az.Storage |
| ASR Fabric | `New-AzRecoveryServicesAsrFabric` | Az.RecoveryServices |
| ASR Container | `New-AzRecoveryServicesAsrProtectionContainer` | Az.RecoveryServices |
| ASR Replication | `New-AzRecoveryServicesAsrReplicationProtectedItem` | Az.RecoveryServices |
| Recovery Plan | `New-AzRecoveryServicesAsrRecoveryPlan` | Az.RecoveryServices |
| Test Failover | `Start-AzRecoveryServicesAsrTestFailoverJob` | Az.RecoveryServices |
| Action Group | `New-AzActionGroup` | Az.Monitor |
| Metric Alert | `Add-AzMetricAlertRuleV2` | Az.Monitor |
| Diagnostic Setting | `Set-AzDiagnosticSetting` | Az.Monitor |
| Metrics | `Get-AzMetric` | Az.Monitor |
| Log Analytics WS | `New-AzOperationalInsightsWorkspace` | Az.OperationalInsights |
| KQL Query | `Invoke-AzOperationalInsightsQuery` | Az.OperationalInsights |
| VM Extension | `Set-AzVMExtension` | Az.Compute |
| DCR | `New-AzDataCollectionRule` | Az.Monitor |
| Network Watcher | `New-AzNetworkWatcher` | Az.Network |
| Conn Monitor | `New-AzNetworkWatcherConnectionMonitor` | Az.Network |
| IP Flow Verify | `Test-AzNetworkWatcherIPFlow` | Az.Network |
| Next Hop | `Get-AzNetworkWatcherNextHop` | Az.Network |
| VM Move | `Move-AzResource` | Az.Resources |
| Backup Vault | `New-AzDataProtectionBackupVault` | Az.DataProtection |
| BV Policy | `New-AzDataProtectionBackupPolicy` | Az.DataProtection |
| BV Instance | `New-AzDataProtectionBackupInstance` | Az.DataProtection |
| BV Policy Template | `Get-AzDataProtectionPolicyTemplate` | Az.DataProtection |
