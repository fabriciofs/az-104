# Backup, Recovery & Monitoring

Labs e simulado cobrindo principalmente o dominio de **monitoramento/backup/recovery** da AZ-104, com cenarios conectados a storage e compute.

## Arquivos

### Labs

| Arquivo                                            | Descricao                                         | Ferramenta               |
| -------------------------------------------------- | ------------------------------------------------- | ------------------------ |
| [cenario-contoso.md](cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados | Portal                   |
| [IaC/powershell.md](IaC/powershell.md)             | Reproduz o lab inteiro via PowerShell             | Cloud Shell (PowerShell) |
| [IaC/arm.md](IaC/arm.md)                           | Reproduz o lab inteiro via ARM Templates JSON     | Cloud Shell (Bash) + CLI |
| [IaC/bicep.md](IaC/bicep.md)                       | Reproduz o lab inteiro via Bicep                  | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                                        | Descricao                                                   |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| [simulado-backup-monitoring.md](simulado-backup-monitoring.md)                 | Caso de estudo MedCloud Health — 18 questoes sem respostas  |
| [simulado-backup-monitoring-solucao.md](simulado-backup-monitoring-solucao.md) | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104 |

## Ordem sugerida

```
1. cenario-contoso.md          Cenario interconectado Contoso Corp
2. IaC/powershell.md     ─┐
3. IaC/bicep.md           ├─  Escolha 1 ou mais para praticar IaC
4. IaC/arm.md            ─┘
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
az vm deallocate -g rg-contoso-compute -n vm-web-01 --no-wait
az vm deallocate -g rg-contoso-compute -n vm-api-01 --no-wait

# CLI — Desabilitar alertas (evita avaliacoes desnecessarias)
az monitor metrics alert update -g rg-contoso-management -n alert-vm-web-01-cpu --enabled false
```

```powershell
# PowerShell — VMs
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-api-01 -Force
```

### Retomar (quando voltar ao lab)

```bash
az vm start -g rg-contoso-compute -n vm-web-01 --no-wait
az vm start -g rg-contoso-compute -n vm-api-01 --no-wait
az monitor metrics alert update -g rg-contoso-management -n alert-vm-web-01-cpu --enabled true
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos continuam cobrando. Site Recovery cobra continuamente por VM replicada — desabilite a replicacao via Portal se nao for continuar no mesmo dia. Recovery Services Vault cobra por instancia protegida — desabilite a protecao se necessario.

## Dominios AZ-104 cobertos

| Bloco                | Dominio oficial AZ-104                              | Peso no exame |
| -------------------- | --------------------------------------------------- | ------------- |
| VM Backup            | Monitor and maintain Azure resources (backup)       | ~10-15%       |
| File/Blob Protection | Monitor and maintain Azure resources (backup)       | ~10-15%       |
| Site Recovery        | Monitor and maintain Azure resources (recovery)     | ~10-15%       |
| Monitor & Alerts     | Monitor and maintain Azure resources (monitoring)   | ~10-15%       |
| Log Analytics        | Monitor and maintain Azure resources (monitoring)   | ~10-15%       |

## Resource Groups

| RG           | Conteudo                                                |
| ------------ | ------------------------------------------------------- |
| `rg-contoso-management` | Recovery Services Vault, Site Recovery, Azure Monitor, Log Analytics, Backup Vault |
