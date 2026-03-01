# Backup, Recovery & Monitoring

Labs e simulado cobrindo os dominios 2 e 5 do AZ-104: Backup de VMs e File Shares, Azure Site Recovery, Azure Monitor, Log Analytics e Network Watcher.

## Arquivos

### Labs

| Arquivo                                        | Descricao                                                    | Ferramenta               |
| ---------------------------------------------- | ------------------------------------------------------------ | ------------------------ |
| [lab-blocos-independentes.md](lab-blocos-independentes.md) | Blocos independentes — conceitos via Portal                  | Portal                   |
| [lab-cenario-contoso.md](lab-cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados            | Portal                   |
| [lab-iac-powershell.md](lab-iac-powershell.md) | Reproduz o lab inteiro via PowerShell                        | Cloud Shell (PowerShell) |
| [lab-iac-arm.md](lab-iac-arm.md)               | Reproduz o lab inteiro via ARM Templates JSON                | Cloud Shell (Bash) + CLI |
| [lab-iac-bicep.md](lab-iac-bicep.md)           | Reproduz o lab inteiro via Bicep                             | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                                              | Descricao                                                    |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| [simulado-backup-monitoring.md](simulado-backup-monitoring.md)                       | Caso de estudo MedCloud Health — 18 questoes sem respostas   |
| [simulado-backup-monitoring-solucao.md](simulado-backup-monitoring-solucao.md)       | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104  |

## Ordem sugerida

```
1. lab-blocos-independentes.md  Primeira passagem (conceitos via Portal)
2. lab-cenario-contoso.md       Segunda passagem (cenario interconectado)
3. lab-iac-powershell.md  ─┐
4. lab-iac-bicep.md        ├─  Escolha 1 ou mais para praticar IaC
5. lab-iac-arm.md         ─┘
6. simulado-backup-monitoring.md  Validacao final (sem consultar labs)
```

## Pre-requisitos

- Conclusao dos blocos [iam-gov-net](../iam-gov-net/) e [storage-compute](../storage-compute/) (VMs, Storage e VNets sao referenciados)
- Assinatura Azure ativa com permissoes de **Owner** ou **Contributor** na subscription
- VMs existentes nos RGs da Semana 2 (para backup e monitoramento)

### Permissoes minimas

| Recurso | Role minimo | Motivo |
|---------|-------------|--------|
| Subscription | Contributor | Criar RGs, vaults, alertas |
| Recovery Services Vault | Backup Contributor | Configurar e executar backups |
| VMs (source) | VM Contributor | Habilitar backup e extensoes |
| Log Analytics Workspace | Log Analytics Contributor | Criar workspace e DCRs |
| Network Watcher | Network Contributor | Connection Monitor, IP Flow Verify |

### Extensoes CLI necessarias (labs IaC)

| Extensao | Comando de instalacao | Usada em |
|----------|----------------------|----------|
| `monitor-control-service` | `az extension add --name monitor-control-service` | Data Collection Rules (Bloco 5) |
| `site-recovery` (opcional) | `az extension add --name site-recovery` | ASR via CLI (Bloco 3 — alternativa ao Portal) |

## Dominios AZ-104 cobertos

| Bloco                  | Dominio                                        | Peso no exame |
| ---------------------- | ---------------------------------------------- | ------------- |
| VM Backup              | Implementar e gerenciar armazenamento          | ~15-20%       |
| File/Blob Protection   | Implementar e gerenciar armazenamento          | ~15-20%       |
| Site Recovery          | Implementar e gerenciar armazenamento          | ~15-20%       |
| Monitor & Alerts       | Monitorar e manter recursos do Azure           | ~10-15%       |
| Log Analytics          | Monitorar e manter recursos do Azure           | ~10-15%       |

## Resource Groups

| RG           | Conteudo                                                   |
| ------------ | ---------------------------------------------------------- |
| `az104-rg11` | Recovery Services Vault (VM backup + File Share backup)    |
| `az104-rg12` | Azure Site Recovery (replicacao cross-region)               |
| `az104-rg13` | Azure Monitor, Log Analytics Workspace, Network Watcher    |
