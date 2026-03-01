# Backup, Recovery & Monitoring

Labs e simulado cobrindo os dominios 2 e 5 do AZ-104: Backup de VMs e File Shares, Azure Site Recovery, Azure Monitor, Log Analytics e Network Watcher.

## Arquivos

### Labs

| Arquivo                                          | Descricao                                         | Ferramenta               |
| ------------------------------------------------ | ------------------------------------------------- | ------------------------ |
| [lab-cenario-contoso.md](lab-cenario-contoso.md) | Cenario Contoso Corp — exercicios interconectados | Portal                   |
| [lab-iac-powershell.md](lab-iac-powershell.md)   | Reproduz o lab inteiro via PowerShell             | Cloud Shell (PowerShell) |
| [lab-iac-arm.md](lab-iac-arm.md)                 | Reproduz o lab inteiro via ARM Templates JSON     | Cloud Shell (Bash) + CLI |
| [lab-iac-bicep.md](lab-iac-bicep.md)             | Reproduz o lab inteiro via Bicep                  | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                                        | Descricao                                                   |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| [simulado-backup-monitoring.md](simulado-backup-monitoring.md)                 | Caso de estudo MedCloud Health — 18 questoes sem respostas  |
| [simulado-backup-monitoring-solucao.md](simulado-backup-monitoring-solucao.md) | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104 |

## Ordem sugerida

```
1. lab-cenario-contoso.md       Cenario interconectado Contoso Corp
2. lab-iac-powershell.md  ─┐
3. lab-iac-bicep.md        ├─  Escolha 1 ou mais para praticar IaC
4. lab-iac-arm.md         ─┘
5. simulado-backup-monitoring.md  Validacao final (sem consultar labs)
```

## Pre-requisitos

- Conclusao dos blocos [1-iam-gov-net](../1-iam-gov-net/) e [2-storage-compute](../2-storage-compute/) (VMs, Storage e VNets sao referenciados)
- Assinatura Azure ativa com permissoes de **Owner** ou **Contributor** na subscription
- VMs existentes nos RGs da Semana 2 (para backup e monitoramento)

### Permissoes minimas

| Recurso                 | Role minimo               | Motivo                             |
| ----------------------- | ------------------------- | ---------------------------------- |
| Subscription            | Contributor               | Criar RGs, vaults, alertas         |
| Recovery Services Vault | Backup Contributor        | Configurar e executar backups      |
| VMs (source)            | VM Contributor            | Habilitar backup e extensoes       |
| Log Analytics Workspace | Log Analytics Contributor | Criar workspace e DCRs             |
| Network Watcher         | Network Contributor       | Connection Monitor, IP Flow Verify |

### Extensoes CLI necessarias (labs IaC)

| Extensao                   | Comando de instalacao                             | Usada em                                      |
| -------------------------- | ------------------------------------------------- | --------------------------------------------- |
| `monitor-control-service`  | `az extension add --name monitor-control-service` | Data Collection Rules (Bloco 5)               |
| `site-recovery` (opcional) | `az extension add --name site-recovery`           | ASR via CLI (Bloco 3 — alternativa ao Portal) |

## Recursos que Geram Cobranca

| Recurso                                             | Gera cobranca?                                | Pode parar?                                 | Como parar                                        |
| --------------------------------------------------- | --------------------------------------------- | ------------------------------------------- | ------------------------------------------------- |
| VMs (da Semana 2, usadas para backup/monitoramento) | Sim — enquanto alocada                        | Sim — desalocar                             | `az vm deallocate`                                |
| Recovery Services Vault (backup de VM)              | Sim — por instancia protegida + armazenamento | Sim — desabilitar protecao                  | `az backup protection disable`                    |
| Site Recovery (replicacao ASR)                      | Sim — continua por VM replicada               | Nao pode pausar — so desabilitar replicacao | Portal (Disable replication)                      |
| Log Analytics Workspace                             | Sim — por GB ingerido                         | Sim — desconectar fontes de dados           | Remover DCR/diagnostic settings                   |
| Alert Rules (metricas, log query)                   | Sim — minima                                  | Sim — desabilitar                           | `az monitor metrics alert update --enabled false` |
| Action Groups                                       | Gratuito (exceto SMS em excesso)              | —                                           | —                                                 |
| Network Watcher                                     | Gratuito (ferramentas de diagnostico)         | —                                           | —                                                 |
| Data Collection Rules                               | Gratuito (custo via Log Analytics)            | —                                           | —                                                 |
| Diagnostic Settings                                 | Gratuito (custo via Log Analytics)            | —                                           | —                                                 |

## Pausar Recursos entre Sessoes

### Pausar (parar cobranca)

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

### Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg7 -n az104-vm-win --no-wait
az vm start -g az104-rg7 -n az104-vm-linux --no-wait
az monitor metrics alert update -g az104-rg-monitor -n az104-vm-win-cpu-alert --enabled true
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia. Recovery Services Vault cobra por instancia protegida — desabilite a protecao se necessario.

## Dominios AZ-104 cobertos

| Bloco                | Dominio                               | Peso no exame |
| -------------------- | ------------------------------------- | ------------- |
| VM Backup            | Implementar e gerenciar armazenamento | ~15-20%       |
| File/Blob Protection | Implementar e gerenciar armazenamento | ~15-20%       |
| Site Recovery        | Implementar e gerenciar armazenamento | ~15-20%       |
| Monitor & Alerts     | Monitorar e manter recursos do Azure  | ~10-15%       |
| Log Analytics        | Monitorar e manter recursos do Azure  | ~10-15%       |

## Resource Groups

| RG           | Conteudo                                                |
| ------------ | ------------------------------------------------------- |
| `az104-rg11` | Recovery Services Vault (VM backup + File Share backup) |
| `az104-rg12` | Azure Site Recovery (replicacao cross-region)           |
| `az104-rg13` | Azure Monitor, Log Analytics Workspace, Network Watcher |
