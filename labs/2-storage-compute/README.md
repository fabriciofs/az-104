# Storage & Compute

Labs e simulado cobrindo principalmente os dominios oficiais de **Storage** e **Compute** do AZ-104.

## Arquivos

### Labs

| Arquivo                                            | Descricao                                         | Ferramenta               |
| -------------------------------------------------- | ------------------------------------------------- | ------------------------ |
| [cenario-contoso.md](cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados | Portal                   |
| [IaC/powershell.md](IaC/powershell.md)             | Reproduz o lab inteiro via PowerShell             | Cloud Shell (PowerShell) |
| [IaC/arm.md](IaC/arm.md)                           | Reproduz o lab inteiro via ARM Templates JSON     | Cloud Shell (Bash) + CLI |
| [IaC/bicep.md](IaC/bicep.md)                       | Reproduz o lab inteiro via Bicep                  | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                                    | Descricao                                                     |
| -------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [simulado-storage-compute.md](simulado-storage-compute.md)                 | Caso de estudo NovaTech Solutions — 18 questoes sem respostas |
| [simulado-storage-compute-solucao.md](simulado-storage-compute-solucao.md) | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104   |

## Ordem sugerida

```
1. cenario-contoso.md          Cenario interconectado Contoso Corp
2. IaC/powershell.md     ─┐
3. IaC/bicep.md           ├─  Escolha 1 ou mais para praticar IaC
4. IaC/arm.md            ─┘
5. simulado-storage-compute.md  Validacao final (sem consultar labs)
```

## Pre-requisitos

- Conclusao do bloco [1-iam-gov-net](../1-iam-gov-net/) (VNets, NSGs e identidade sao referenciados)
- Assinatura Azure ativa com permissoes de **Owner** ou **Contributor** na subscription

### Permissoes minimas

| Recurso         | Role minimo                 | Motivo                             |
| --------------- | --------------------------- | ---------------------------------- |
| Subscription    | Contributor                 | Criar RGs, storage accounts, VMs   |
| VNet existente  | Network Contributor         | Service Endpoint, Private Endpoint |
| Storage Account | Storage Account Contributor | Criar containers, file shares, SAS |
| App Service     | Website Contributor         | Criar web apps, slots, autoscale   |

## Recursos que Geram Cobranca

| Recurso                                    | Gera cobranca?                                | Pode parar?                               | Como parar                       |
| ------------------------------------------ | --------------------------------------------- | ----------------------------------------- | -------------------------------- |
| VMs (vm-web-01, vm-api-01)         | Sim — enquanto alocada                        | Sim — desalocar                           | `az vm deallocate`               |
| VMSS (vmss-contoso-web)                          | Sim — por instancia ativa                     | Sim — escalar para 0                      | `az vmss scale --new-capacity 0` |
| App Service Plan (Standard S1)             | Sim — enquanto existir (mesmo com app parada) | Nao — so deletar ou rebaixar para Free F1 | —                                |
| ACI (ci-contoso-worker, ci-contoso-worker-2) | Sim — enquanto Running                        | Sim — parar                               | `az container stop`              |
| Container Apps (ca-contoso-api)                | Por replica ativa (scale-to-zero = sem custo) | Ja configurado para escalar a zero        | —                                |
| Managed Disks (OS disks, data disks)       | Sim — sempre (mesmo com VM desalocada)        | Nao — so deletar                          | —                                |
| Public IPs (Standard SKU)                  | Sim — enquanto existir                        | Nao — so deletar                          | —                                |
| Private Endpoint                           | Sim — enquanto existir                        | Nao — so deletar                          | —                                |
| Storage Account                            | Sim — por dados armazenados                   | Nao — so deletar                          | —                                |
| VNets, NSGs, Subnets, Service Endpoints    | Gratuito                                      | —                                         | —                                |

## Pausar Recursos entre Sessoes

### Pausar (parar cobranca de compute)

```bash
# CLI — VMs
az vm deallocate -g rg-contoso-compute -n vm-web-01 --no-wait
az vm deallocate -g rg-contoso-compute -n vm-api-01 --no-wait

# CLI — VMSS (escalar para 0)
az vmss scale -g rg-contoso-compute -n vmss-contoso-web --new-capacity 0

# CLI — ACI
az container stop -g rg-contoso-compute -n ci-contoso-worker
az container stop -g rg-contoso-compute -n ci-contoso-worker-2
```

```powershell
# PowerShell — VMs
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-web-01 -Force
Stop-AzVM -ResourceGroupName rg-contoso-compute -Name vm-api-01 -Force

# PowerShell — ACI
Stop-AzContainerGroup -ResourceGroupName rg-contoso-compute -Name ci-contoso-worker
Stop-AzContainerGroup -ResourceGroupName rg-contoso-compute -Name ci-contoso-worker-2
```

### Retomar (quando voltar ao lab)

```bash
az vm start -g rg-contoso-compute -n vm-web-01 --no-wait
az vm start -g rg-contoso-compute -n vm-api-01 --no-wait
az vmss scale -g rg-contoso-compute -n vmss-contoso-web --new-capacity 1
az container start -g rg-contoso-compute -n ci-contoso-worker
az container start -g rg-contoso-compute -n ci-contoso-worker-2
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos e IPs publicos continuam cobrando. O App Service Plan (Standard S1) cobra enquanto existir — para parar, delete o plano ou rebaixe para Free F1. Container Apps com scale-to-zero nao geram custo quando ociosas.

## Dominios AZ-104 cobertos

| Bloco          | Dominio oficial AZ-104                        | Peso no exame |
| -------------- | --------------------------------------------- | ------------- |
| Storage        | Implement and manage Azure storage            | ~15-20%       |
| VMs            | Deploy and manage Azure compute resources     | ~20-25%       |
| Web Apps       | Deploy and manage Azure compute resources     | ~20-25%       |
| ACI            | Deploy and manage Azure compute resources     | ~20-25%       |
| Container Apps | Deploy and manage Azure compute resources     | ~20-25%       |

## Resource Groups

| RG                    | Conteudo                                                                           |
| --------------------- | ---------------------------------------------------------------------------------- |
| `rg-contoso-storage`  | Storage Account, Blobs, Files, Private Endpoint                                    |
| `rg-contoso-compute`  | VMs, VMSS, App Service, ACI, Container Apps Environment (ja existe do Modulo 1)    |
