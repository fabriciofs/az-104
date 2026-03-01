# IAM, Governance & Networking

Labs e simulado cobrindo os 5 dominios fundamentais do AZ-104: Identity, Governance, IaC, Virtual Networking e Intersite Connectivity.

## Arquivos

### Labs

| Arquivo                                                    | Descricao                                         | Ferramenta               |
| ---------------------------------------------------------- | ------------------------------------------------- | ------------------------ |
| [lab-cenario-contoso.md](lab-cenario-contoso.md)           | Cenario Contoso Corp — exercicios interconectados | Portal                   |
| [lab-iac-powershell.md](lab-iac-powershell.md)             | Reproduz o lab v2 inteiro via PowerShell          | Cloud Shell (PowerShell) |
| [lab-iac-arm.md](lab-iac-arm.md)                           | Reproduz o lab v2 inteiro via ARM Templates JSON  | Cloud Shell (Bash) + CLI |
| [lab-iac-bicep.md](lab-iac-bicep.md)                       | Reproduz o lab v2 inteiro via Bicep               | Cloud Shell (Bash) + CLI |

### Simulado

| Arquivo                                                            | Descricao                                                     |
| ------------------------------------------------------------------ | ------------------------------------------------------------- |
| [simulado-iam-gov-net.md](simulado-iam-gov-net.md)                 | Caso de estudo DataFlow Analytics — 18 questoes sem respostas |
| [simulado-iam-gov-net-solucao.md](simulado-iam-gov-net-solucao.md) | Gabarito com explicacoes, gotchas e mapa de dominios AZ-104   |

## Ordem sugerida

```
1. lab-cenario-contoso.md       Cenario interconectado Contoso Corp
2. lab-iac-powershell.md  ─┐
3. lab-iac-bicep.md        ├─  Escolha 1 ou mais para praticar IaC
4. lab-iac-arm.md         ─┘
5. simulado-iam-gov-net.md     Validacao final (sem consultar labs)
```

## Dominios AZ-104 cobertos

| Bloco        | Dominio                                    | Peso no exame |
| ------------ | ------------------------------------------ | ------------- |
| Identity     | Manage Microsoft Entra ID users and groups | ~15-20%       |
| Governance   | Manage subscriptions, RBAC, Azure Policy   | ~15-20%       |
| IaC          | Deploy resources using ARM/Bicep           | ~5-10%        |
| Networking   | Configure virtual networks, NSGs, DNS      | ~20-25%       |
| Connectivity | Configure VNet peering, routing, VPN       | ~20-25%       |
