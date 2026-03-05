# IAM, Governance & Networking

Labs e simulado cobrindo principalmente os dominios de **Identity/Governance** e **Networking** do AZ-104, com IaC aplicado como habilidade transversal.

## Arquivos

### Labs

| Arquivo                                            | Descricao                                         | Ferramenta               |
| -------------------------------------------------- | ------------------------------------------------- | ------------------------ |
| [cenario-contoso.md](cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados | Portal                   |
| [IaC/powershell.md](IaC/powershell.md)             | Reproduz o lab v2 inteiro via PowerShell          | Cloud Shell (PowerShell) |
| [IaC/arm.md](IaC/arm.md)                           | Reproduz o lab v2 inteiro via ARM Templates JSON  | Cloud Shell (Bash) + CLI |
| [IaC/bicep.md](IaC/bicep.md)                       | Reproduz o lab v2 inteiro via Bicep               | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                            | Descricao                                                     |
| ------------------------------------------------------------------ | ------------------------------------------------------------- |
| [simulado-iam-gov-net.md](simulado-iam-gov-net.md)                 | Caso de estudo DataFlow Analytics — 18 questoes sem respostas |
| [simulado-iam-gov-net-solucao.md](simulado-iam-gov-net-solucao.md) | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104   |

## Ordem sugerida

```
1. cenario-contoso.md          Cenario interconectado Contoso Corp
2. IaC/powershell.md     ─┐
3. IaC/bicep.md           ├─  Escolha 1 ou mais para praticar IaC
4. IaC/arm.md            ─┘
5. simulado-iam-gov-net.md     Validacao final (sem consultar labs)
```

## Recursos que Geram Cobranca

| Recurso                                       | Gera cobranca?                        | Pode parar?     | Como parar          |
| --------------------------------------------- | ------------------------------------- | --------------- | ------------------- |
| VMs (CoreServicesVM, ManufacturingVM)         | Sim, enquanto alocada                 | Sim, desalocar  | `az vm deallocate`  |
| Managed Disks (az104-disk1 a disk5, OS disks) | Sim, sempre (mesmo com VM desalocada) | Nao, so deletar | Deletar disco ou RG |
| Public IP (Standard SKU)                      | Sim, enquanto existir                 | Nao, so deletar | Deletar IP ou RG    |
| DNS Zones (publica e privada)                 | Sim, cobranca minima mensal           | Nao, so deletar | Deletar zona ou RG  |
| Storage Account                               | Sim, por dados armazenados            | Nao, so deletar | Deletar conta ou RG |
| VNets, NSGs, Route Tables                     | Gratuito                              | —               | —                   |
| RBAC, Policy, Users, Groups                   | Gratuito                              | —               | —                   |

## Pausar Recursos entre Sessoes

### Pausar (parar cobranca de compute)

```bash
# CLI
az vm deallocate -g az104-rg5 -n CoreServicesVM --no-wait
az vm deallocate -g az104-rg5 -n ManufacturingVM --no-wait
```

```powershell
# PowerShell
Stop-AzVM -ResourceGroupName az104-rg5 -Name CoreServicesVM -Force
Stop-AzVM -ResourceGroupName az104-rg5 -Name ManufacturingVM -Force
```

### Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg5 -n CoreServicesVM --no-wait
az vm start -g az104-rg5 -n ManufacturingVM --no-wait
```

> **Nota:** Desalocar a VM para a cobranca de compute mas discos e IPs publicos continuam gerando cobranca. Para zerar completamente, delete o Resource Group.

## Dominios AZ-104 cobertos

| Bloco        | Dominio                                    | Peso no exame |
| ------------ | ------------------------------------------ | ------------- |
| Identity     | Manage identity and governance in Azure    | ~20-25%       |
| Governance   | Manage identity and governance in Azure    | ~20-25%       |
| IaC          | Topico do dominio 1 (sem peso isolado)     | n/a           |
| Networking   | Configure and manage virtual networks      | ~15-20%       |
| Connectivity | Configure and manage virtual networks      | ~15-20%       |
