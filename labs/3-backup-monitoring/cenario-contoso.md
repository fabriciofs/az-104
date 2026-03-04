# Lab Unificado AZ-104 - Semana 3 (v2: Exercicios Interconectados)

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce continua como **Azure Administrator** da Contoso Corp. Nas semanas anteriores, voce construiu toda a base do ambiente Azure:

- **Semana 1 (IAM/Gov/Net):** Identidade, governanca, IaC, networking e conectividade
- **Semana 2 (Storage/Compute):** Storage accounts, file shares, VMs (Windows e Linux), Web Apps e containers

Agora, na **Semana 3**, sua missao e **proteger, monitorar e observar** tudo o que foi construido. Voce vai:

1. **Backup de VMs** — proteger as VMs criadas na Semana 2 com Recovery Services Vault
2. **Protecao de Storage** — backup de file shares e configurar soft delete/versioning no blob storage da Semana 2
3. **Site Recovery** — configurar DR cross-region para VMs criticas
4. **Monitor & Alerts** — monitorar metricas das VMs e configurar alertas com Action Groups
5. **Log Analytics** — conectar workspace as VMs, habilitar VM Insights e usar Network Watcher nas VNets da Semana 1

Ao final, voce tera **um ambiente corporativo com protecao de dados, disaster recovery, monitoramento proativo e observabilidade avancada** — tudo integrado com os recursos das semanas anteriores.

---

## Mapa de Dependencias

```
iam-gov-net (Semana 1)
  ├─ VNets, NSGs, DNS ──────────────────┐
  ├─ RBAC, Policies ────────────────────┤
  └─ Users, Groups ─────────────────────┤
                                        │
storage-compute (Semana 2)              │
  ├─ Storage Account + File Share ──────┤
  ├─ VMs (Windows, Linux) ──────────────┤
  ├─ Web Apps ──────────────────────────┤
  └─ Containers ────────────────────────┤
                                        │
                                        ▼
Bloco 1 (VM Backup) ◄──── Protege VMs da Semana 2
  ├─ Recovery Services Vault ───────────┐
  └─ Backup Policy + On-demand backup ──┤
                                        │
                                        ▼
Bloco 2 (File/Blob Protection) ◄──── Protege Storage da Semana 2
  ├─ File Share backup ─────────────────┤
  └─ Soft delete + versioning ──────────┤
                                        │
                                        ▼
Bloco 3 (Site Recovery) ◄──── DR para VMs criticas
  ├─ Replicacao cross-region ───────────┤
  └─ Recovery Plan + Test Failover ─────┤
                                        │
                                        ▼
Bloco 4 (Monitor & Alerts) ◄──── Monitora TODOS os recursos
  ├─ Metricas de VMs da Semana 2 ───────┤
  └─ Alerts + Action Groups ────────────┤
                                        │
                                        ▼
Bloco 5 (Log Analytics) ◄──── Analise avancada de tudo
  ├─ Workspace conectado as VMs ────────┤
  ├─ VM Insights ───────────────────────┤
  └─ Network Watcher nas VNets ─────────┤
                                        │
                                        ▼
Bloco 6 (Backup Vault + VM Move) ◄──── Complementa backup + compute
  ├─ VM Move entre Resource Groups ─────┤
  ├─ Backup Vault vs RSV (comparacao) ──┤
  └─ Disk backup policy ────────────────┤
```

---

## Indice

| Bloco | Descricao                       | Link                                                                             |
| ----- | ------------------------------- | -------------------------------------------------------------------------------- |
| 1     | VM Backup                       | [cenario/bloco1-vm-backup.md](cenario/bloco1-vm-backup.md)                       |
| 2     | File & Blob Protection          | [cenario/bloco2-file-blob.md](cenario/bloco2-file-blob.md)                       |
| 3     | Site Recovery (DR)              | [cenario/bloco3-site-recovery.md](cenario/bloco3-site-recovery.md)               |
| 4     | Monitor & Alerts                | [cenario/bloco4-monitor.md](cenario/bloco4-monitor.md)                           |
| 5     | Log Analytics & Network Watcher | [cenario/bloco5-log-analytics.md](cenario/bloco5-log-analytics.md)               |
| 6     | Backup Vault e VM Move          | [cenario/bloco6-backup-vault-vm-move.md](cenario/bloco6-backup-vault-vm-move.md) |

- [Pausar entre Sessoes](#pausar-entre-sessoes)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---


# Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

## Pausar (parar cobranca)

```bash
# CLI — VMs (da Semana 2)
az vm deallocate -g az104-rg7 -n az104-vm-win --no-wait
az vm deallocate -g az104-rg7 -n az104-vm-linux --no-wait

# CLI — Desabilitar alertas (evita avaliacoes desnecessarias)
az monitor metrics alert update -g az104-rg-monitor -n az104-vm-win-cpu-alert --enabled false
```

```powershell
# PowerShell — VMs
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-win -Force
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-linux -Force
```

## Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg7 -n az104-vm-win --no-wait
az vm start -g az104-rg7 -n az104-vm-linux --no-wait
az monitor metrics alert update -g az104-rg-monitor -n az104-vm-win-cpu-alert --enabled true
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia. Recovery Services Vault cobra por instancia protegida — desabilite a protecao se necessario.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente VMs e replicacao do Site Recovery.

## Ordem de cleanup (PRIORIDADE por custo)

1. **Site Recovery primeiro** (replicacao gera custo contínuo)
2. **VMs** (compute e o maior custo)
3. **Vaults** (requerem que items sejam removidos primeiro)
4. **Demais recursos**

## Via Azure Portal

1. **Desabilitar replicacao (Site Recovery):**
   - `az104-rsv-dr` > Replicated items > az104-vm-win > **Disable replication** > confirme
   - Aguarde o job completar

2. **Parar backup e deletar dados:**
   - `az104-rsv` > Backup items > Azure Virtual Machine > selecione cada VM > **Stop backup** > **Delete backup data** > confirme
   - `az104-rsv` > Backup items > Azure File Share > selecione az104-share > **Stop backup** > **Delete backup data** > confirme

3. **Deletar vaults** (so funciona apos remover todos os items):
   - `az104-rsv-dr` > **Delete** (vault de DR)
   - `az104-rsv` > **Delete** (vault de backup)

4. **Deletar Resource Groups:**
   - `az104-rg-dr` (Site Recovery)
   - `az104-rg-backup` (vault de backup)
   - `az104-rg-monitor` (Log Analytics, alerts, action groups)

5. **Reverter configuracoes nos recursos das semanas anteriores:**
   - Storage account (az104-rg6): desabilitar soft delete e versioning se desejar
   - VMs (az104-rg7): desinstalar Azure Monitor Agent se desejar

6. **Deletar auto-created resource groups** (Site Recovery):
   - `az104-rg7-asr` (se foi criado pelo ASR)

## Via CLI

> **Nota:** Remova Site Recovery e backup items **antes** de deletar os vaults. Vaults com items protegidos nao podem ser deletados.

```bash
# ============================================================
# CLEANUP - Descoberta dinamica de nomes internos
# ============================================================

VAULT_NAME="az104-rsv"
VAULT_DR="az104-rsv-dr"
RG_BACKUP="az104-rg-backup"
RG_DR="az104-rg-dr"
RG_MONITOR="az104-rg-monitor"

# 1. Desabilitar replicacao (Site Recovery)
#    NOTA: ASR cleanup via CLI e complexo. Recomenda-se usar o Portal:
#    Recovery Services Vault > Replicated Items > selecionar > Disable Replication
#    Se preferir CLI, use az rest com a API REST do ASR:
echo "Passo 1: Desabilite a replicacao ASR via Portal antes de continuar."
echo "         Vault: $VAULT_DR > Replicated Items > Disable Replication"
read -p "Pressione Enter apos desabilitar a replicacao no Portal..."

# 2. Desabilitar backup de VMs (descoberta dinamica dos nomes internos)
echo "Desabilitando backup de VMs..."
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
  --backup-management-type AzureIaasVM \
  --query "[].name" -o tsv 2>/dev/null); do

  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureIaasVM \
    --query "[].name" -o tsv 2>/dev/null); do

    echo "  Desabilitando: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" \
      --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" \
      -g "$RG_BACKUP" \
      --backup-management-type AzureIaasVM \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 3. Desabilitar backup de File Shares (descoberta dinamica)
echo "Desabilitando backup de File Shares..."
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
  --backup-management-type AzureStorage \
  --query "[].name" -o tsv 2>/dev/null); do

  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureStorage \
    --query "[].name" -o tsv 2>/dev/null); do

    echo "  Desabilitando: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" \
      --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" \
      -g "$RG_BACKUP" \
      --backup-management-type AzureStorage \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 4. Deletar vaults (so funciona apos desabilitar todas as protecoes)
echo "Deletando vaults..."
az backup vault delete -g "$RG_BACKUP" --name "$VAULT_NAME" --yes 2>/dev/null
az backup vault delete -g "$RG_DR" --name "$VAULT_DR" --yes 2>/dev/null

# 5. Deletar Resource Groups
echo "Deletando Resource Groups..."
az group delete --name "$RG_DR" --yes --no-wait
az group delete --name "$RG_BACKUP" --yes --no-wait
az group delete --name "$RG_MONITOR" --yes --no-wait

# 6. Deletar RGs auto-created pelo ASR (se existirem)
az group delete --name az104-rg7-asr --yes --no-wait 2>/dev/null

echo "Cleanup concluido. RGs sendo deletados em background."
```

## Via PowerShell

```powershell
# 1. Desabilitar replicacao (recomenda-se portal para este passo)

# 2. Parar backup
$vault = Get-AzRecoveryServicesVault -ResourceGroupName az104-rg-backup -Name az104-rsv
Set-AzRecoveryServicesVaultContext -Vault $vault
$backupItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
foreach ($item in $backupItems) {
    Disable-AzRecoveryServicesBackupProtection -Item $item -RemoveRecoveryPoints -Force
}

# 3. Deletar vaults
Remove-AzRecoveryServicesVault -Vault $vault

# 4. Deletar Resource Groups
Remove-AzResourceGroup -Name az104-rg-dr -Force -AsJob
Remove-AzResourceGroup -Name az104-rg-backup -Force -AsJob
Remove-AzResourceGroup -Name az104-rg-monitor -Force -AsJob

# 5. Deletar RGs auto-created
Remove-AzResourceGroup -Name az104-rg7-asr -Force -AsJob -ErrorAction SilentlyContinue

# 6. Remover diagnostic settings
$subscriptionId = (Get-AzContext).Subscription.Id
Remove-AzDiagnosticSetting -Name az104-activity-to-law -ResourceId "/subscriptions/$subscriptionId"
```

> **Nota:** Nao delete os resource groups das semanas anteriores (`az104-rg4` a `az104-rg7`) a menos que nao precise mais dos recursos. O cleanup desta semana remove apenas o que foi criado na Semana 3.

---

# Key Takeaways Consolidados

## Bloco 1 - VM Backup
- **Recovery Services Vault** centraliza backup de VMs, file shares e Site Recovery
- **Backup policies** definem frequencia e retencao; Enhanced policy suporta frequencia horaria (4/6/8/12h)
- **Instant Restore** usa snapshots locais para restauracao rapida (minutos)
- **Restore options:** Create VM, Restore disk, Replace existing, Cross Region Restore
- Backup on-demand permite retencao independente da policy
- O Azure instala a extensao de backup **automaticamente** na VM

## Bloco 2 - File & Blob Protection
- **File share backup** usa share snapshots armazenados **na propria storage account** (nao no vault)
- **Item Level Restore** permite restaurar arquivos individuais sem restaurar o share inteiro
- **Soft delete** protege contra exclusao acidental (mantem dados por X dias)
- **Versioning** protege contra sobrescrita acidental (cria nova versao a cada modificacao)
- Combinados (backup + soft delete + versioning), oferecem **protecao em camadas** contra diferentes cenarios

## Bloco 3 - Site Recovery (DR)
- **Vault de DR** fica na regiao de **destino**, nao na regiao de origem
- **RPO** = perda de dados maxima aceitavel; **RTO** = tempo para restaurar o servico
- **Test Failover** valida DR sem afetar producao — sempre faca cleanup depois
- **Recovery Plans** orquestram failover em grupos sequenciais com scripts pre/pos
- Backup e Site Recovery sao **complementares**: backup protege dados, ASR protege disponibilidade

## Bloco 4 - Monitor & Alerts
- **Metric alerts** monitoram valores numericos (CPU, latencia); **Activity Log alerts** monitoram operacoes
- **Static threshold** compara com valor fixo; **Dynamic threshold** usa ML para detectar anomalias
- **Action Groups** definem QUEM/COMO notificar — reutilizaveis entre alertas
- Todas as notificacoes de um Action Group sao executadas **em paralelo**
- Azure Monitor coleta metricas **host** automaticamente; metricas **guest** requerem agente

## Bloco 5 - Log Analytics & Network Watcher
- **Log Analytics Workspace** e o repositorio central de logs — consultas via KQL
- **Azure Monitor Agent (AMA)** + **Data Collection Rules (DCR)** substituem os agentes legados
- **VM Insights** oferece performance detalhada + mapa de dependencias
- **Network Watcher:** IP Flow Verify (NSG), Next Hop (routing), Connection Troubleshoot (conectividade), Topology (visualizacao)
- **Diagnostic Settings** enviam dados de plataforma; **DCR** enviam dados guest
- KQL basico para prova: `where`, `summarize`, `project`, `render`, `ago()`, `bin()`

## Bloco 6 - Backup Vault e VM Move
- **VM Move entre RGs** (mesma regiao) nao requer downtime; move entre regioes requer ASR ou recriar
- **Recursos dependentes** (NIC, Disk, IP) devem ser movidos junto com a VM
- **Backup Vault** suporta Azure Disks, Blobs, PostgreSQL e AKS; **RSV** suporta VMs, File Shares e Site Recovery
- **Disk backup** no Backup Vault usa snapshots incrementais (menor custo que VM backup completo)
- **Backup Center** no portal unifica gestao de ambos os tipos de vault
- Verifique a **support matrix** antes de mover qualquer recurso entre RGs ou subscriptions

## Integracao Geral (Semanas 1-3)
- **Semana 1 (IAM/Gov/Net)** criou a base: identidade, governanca, rede
- **Semana 2 (Storage/Compute)** implantou cargas de trabalho: VMs, storage, apps
- **Semana 3 (Backup/Monitor)** protege e observa tudo que foi construido
- **Backup** (Blocos 1-2) protege dados das VMs e storage da Semana 2
- **Site Recovery** (Bloco 3) garante disponibilidade das VMs da Semana 2 em caso de falha regional
- **Monitor** (Bloco 4) monitora proativamente recursos de TODAS as semanas
- **Log Analytics + Network Watcher** (Bloco 5) integra observabilidade das VMs (Semana 2) com diagnostico de rede (Semana 1)
- **Tudo se conecta:** um alerta de CPU (Bloco 4) monitora uma VM (Semana 2) em uma VNet (Semana 1), com backup (Bloco 1) e DR (Bloco 3) prontos para proteger, e Log Analytics (Bloco 5) correlacionando eventos de todo o ambiente
