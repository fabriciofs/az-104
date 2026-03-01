# Storage & Compute

Labs e simulado cobrindo os dominios 2 e 3 do AZ-104: Storage Accounts, Blob/File Storage, Virtual Machines, Web Apps e Containers.

## Arquivos

### Labs

| Arquivo                                        | Descricao                                                    | Ferramenta               |
| ---------------------------------------------- | ------------------------------------------------------------ | ------------------------ |
| [lab-cenario-contoso.md](lab-cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados            | Portal                   |
| [lab-iac-powershell.md](lab-iac-powershell.md) | Reproduz o lab inteiro via PowerShell                        | Cloud Shell (PowerShell) |
| [lab-iac-arm.md](lab-iac-arm.md)               | Reproduz o lab inteiro via ARM Templates JSON                | Cloud Shell (Bash) + CLI |
| [lab-iac-bicep.md](lab-iac-bicep.md)           | Reproduz o lab inteiro via Bicep                             | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                                        | Descricao                                                         |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
| [simulado-storage-compute.md](simulado-storage-compute.md)                     | Caso de estudo NovaTech Solutions — 18 questoes sem respostas     |
| [simulado-storage-compute-solucao.md](simulado-storage-compute-solucao.md)     | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104       |

## Ordem sugerida

```
1. lab-cenario-contoso.md       Cenario interconectado Contoso Corp
2. lab-iac-powershell.md  ─┐
3. lab-iac-bicep.md        ├─  Escolha 1 ou mais para praticar IaC
4. lab-iac-arm.md         ─┘
5. simulado-storage-compute.md  Validacao final (sem consultar labs)
```

## Pre-requisitos

- Conclusao do bloco [1-iam-gov-net](../1-iam-gov-net/) (VNets, NSGs e identidade sao referenciados)
- Assinatura Azure ativa com permissoes de **Owner** ou **Contributor** na subscription

### Permissoes minimas

| Recurso | Role minimo | Motivo |
|---------|-------------|--------|
| Subscription | Contributor | Criar RGs, storage accounts, VMs |
| VNet existente | Network Contributor | Service Endpoint, Private Endpoint |
| Storage Account | Storage Account Contributor | Criar containers, file shares, SAS |
| App Service | Website Contributor | Criar web apps, slots, autoscale |

## Dominios AZ-104 cobertos

| Bloco            | Dominio                                        | Peso no exame |
| ---------------- | ---------------------------------------------- | ------------- |
| Storage          | Implementar e gerenciar armazenamento          | ~15-20%       |
| VMs              | Implantar e gerenciar recursos de computacao   | ~20-25%       |
| Web Apps         | Implantar e gerenciar recursos de computacao   | ~20-25%       |
| ACI              | Implantar e gerenciar recursos de computacao   | ~20-25%       |
| Container Apps   | Implantar e gerenciar recursos de computacao   | ~20-25%       |

## Resource Groups

| RG           | Conteudo                  |
| ------------ | ------------------------- |
| `az104-rg6`  | Storage Account, Blobs, Files, Private Endpoint |
| `az104-rg7`  | VMs Windows/Linux, VMSS, Data Disks             |
| `az104-rg8`  | App Service Plan, Web App, Deployment Slots      |
| `az104-rg9`  | Azure Container Instances                        |
| `az104-rg10` | Container Apps Environment, Container Apps       |
