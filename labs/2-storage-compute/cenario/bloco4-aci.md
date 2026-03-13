> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 5 - Azure Container Apps](bloco5-container-apps.md)

# Bloco 4 - Azure Container Instances

**Origem:** Lab 09b - Implement Azure Container Instances
**Resource Groups utilizados:** `rg-contoso-compute`

## Contexto

A Contoso Corp precisa executar cargas de trabalho em containers para processos batch e microservicos rapidos. Voce implanta Azure Container Instances (ACI) usando o file share do Bloco 1 como volume persistente. Isso demonstra como containers stateless podem acessar dados persistentes armazenados no Azure Storage.

## Diagrama

```
┌────────────────────────────────────────────────────────────────┐
│                          rg-contoso-compute                    │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Container Group: ci-contoso-worker                      │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Container: ci-contoso-worker                      │  │  │
│  │  │  Image: mcr.microsoft.com/azuredocs/aci-helloworld │  │  │
│  │  │                                                    │  │  │
│  │  │  Resources: 1 CPU, 1.5 GiB memory                  │  │  │
│  │  │  Port: 80 (HTTP)                                   │  │  │
│  │  │  Restart policy: On failure                        │  │  │
│  │  │                                                    │  │  │
│  │  │  Volume Mount:                                     │  │  │
│  │  │  ┌──────────────────────────────────────────┐      │  │  │
│  │  │  │  /mnt/fileshare → contoso-files          │      │  │  │
│  │  │  │  (Azure File Share do Bloco 1)           │      │  │  │
│  │  │  │  Storage: stcontosoprod01                │      │  │  │
│  │  │  └──────────────────────────────────────────┘      │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  → File share do Bloco 1 montado como volume no container      │
│  → Dados criados pela VM (Bloco 2) visiveis no container       │
└────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar Container Instance com imagem publica

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running. Pare com `az container stop` ao pausar o lab.

**O que estamos fazendo e por que:** ACI e a forma mais simples de executar containers no Azure — sem cluster, sem orquestracao, sem configuracao de infraestrutura. Voce aponta para uma imagem e o Azure executa. Analogia: se VMs sao "alugar um apartamento" (voce gerencia tudo la dentro), ACI e "reservar um quarto de hotel" (voce chega, usa e vai embora). Ideal para tarefas rapidas, jobs batch e testes.

1. Pesquise e selecione **Container instances** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value                                        |
   | -------------- | -------------------------------------------- |
   | Subscription   | *sua subscription*                           |
   | Resource group | `rg-contoso-compute` (ja existe do Modulo 1) |
   | Container name | `ci-contoso-worker`                          |
   | Region         | **East US**                                  |
   | SKU            | **Standard**                                 |
   | Image source   | **Other registry**                           |
   | Image type     | **Public**                                   |
   | Image          | `mcr.microsoft.com/azuredocs/aci-helloworld` |
   | OS type        | **Linux**                                    |
   | Size           | **1 vcpu, 1.5 GiB memory**                   |

   > **Image source:** Other registry = voce informa a URL da imagem manualmente. Docker Hub e Azure Container Registry sao atalhos. A imagem `aci-helloworld` e uma imagem de demonstracao da Microsoft que mostra uma pagina web simples.

   > **Size:** Diferente de VMs que usam "families" (D-series, B-series), ACI permite especificar CPU e memoria de forma granular. Voce paga exatamente pelo que aloca, por segundo de execucao.

3. Aba **Networking**:

   | Setting         | Value                                       |
   | --------------- | ------------------------------------------- |
   | Networking type | **Public**                                  |
   | DNS name label  | `ci-contoso-<uniqueid>` (globalmente unico) |
   | Ports           | `80`                                        |
   | Port protocol   | **TCP**                                     |

   > **Networking type:** Public = IP publico acessivel pela internet. Private = integrado a uma VNet (so acessivel internamente). Para este lab, usamos Public para testar facilmente no navegador.

4. Aba **Advanced**:

   | Setting        | Value          |
   | -------------- | -------------- |
   | Restart policy | **On failure** |

   > **Restart policy** controla o que acontece quando o processo dentro do container termina. **Always** = reinicia sempre (para servicos long-running). **On failure** = reinicia so se o exit code indicar erro. **Never** = executa uma vez e para (para jobs batch).

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment > **Go to resource**

7. No blade **Overview**, copie o **FQDN** (ex: `ci-contoso-<uniqueid>.eastus.azurecontainer.io`)

8. Acesse o FQDN no navegador — voce deve ver a pagina "Welcome to Azure Container Instances!"

9. Revise no blade:
   - **Status**: Running
   - **IP address** (publico)
   - **Restart count**

   > **Conceito:** ACI e a forma mais simples de executar containers no Azure. Sem orquestracao, sem gerenciamento de cluster. Ideal para tarefas rapidas, batch jobs e cenarios simples. Para orquestracao (auto-scaling, service discovery, load balancing), use Container Apps (Bloco 5) ou AKS.

   > **Pegadinha AZ-104:** ACI monta volumes usando **Azure Files** (SMB), NAO Azure Blob Storage. Essa confusao apareceu em simulados. Blobs sao para armazenamento de objetos; Files sao para file shares montaveis.

---

### Task 4.2: Montar File Share do Bloco 1 como Volume

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running. Pare com `az container stop` ao pausar o lab.

**O que estamos fazendo e por que:** Containers sao **efemeros** por natureza — quando o container para, tudo dentro dele desaparece. Para persistir dados, voce monta um volume externo. Aqui, montamos o file share do Bloco 1, que ja contem arquivos criados pela VM (Bloco 2). Isso demonstra que diferentes plataformas de compute (VMs, containers) podem compartilhar os mesmos dados via Azure Files.

Voce cria um novo container que monta o file share `contoso-files` do Bloco 1, demonstrando persistencia de dados entre containers e VMs.

1. Primeiro, obtenha a **storage account key** do Bloco 1:
   - Navegue para Storage Account **stcontosoprod01** > **Security + networking** > **Access keys**
   - Copie **key1**

2. Pesquise **Container instances** > **+ Create**

3. Aba **Basics**:

   | Setting        | Value                                        |
   | -------------- | -------------------------------------------- |
   | Resource group | `rg-contoso-compute`                         |
   | Container name | `ci-contoso-worker-2`                        |
   | Region         | **East US**                                  |
   | Image source   | **Other registry**                           |
   | Image type     | **Public**                                   |
   | Image          | `mcr.microsoft.com/azuredocs/aci-helloworld` |
   | OS type        | **Linux**                                    |
   | Size           | **1 vcpu, 1.5 GiB memory**                   |

4. Aba **Networking**:

   | Setting         | Value                    |
   | --------------- | ------------------------ |
   | Networking type | **Public**               |
   | DNS name label  | `ci-contoso2-<uniqueid>` |
   | Ports           | `80`                     |

5. Aba **Advanced**:

   | Setting        | Value          |
   | -------------- | -------------- |
   | Restart policy | **On failure** |

6. Em **Volume mounts**, clique em **+ Add volume**:

   | Setting              | Value                       |
   | -------------------- | --------------------------- |
   | Volume name          | `filesharevolume`           |
   | Volume type          | **Azure file share**        |
   | Storage account name | `stcontosoprod01` (Bloco 1) |
   | Storage account key  | *cole key1 copiada acima*   |
   | File share name      | `contoso-files`             |
   | Mount path           | `/mnt/fileshare`            |

   > **Mount path** e o caminho dentro do container onde o file share aparece. `/mnt/fileshare` e uma convencao comum em Linux. Tudo que voce ler/escrever nesse caminho vai diretamente para o Azure File Share — persistente alem da vida do container.

7. Clique em **Add**

8. Clique em **Review + create** > **Create**

9. Apos o deploy, navegue para o container > **Settings** > **Containers** > selecione o container > **Connect**

10. Selecione `/bin/sh` > **Connect**

11. No terminal do container, execute:

    ```bash
    ls /mnt/fileshare/
    cat /mnt/fileshare/vm-test.txt
    ```

    > Voce deve ver o arquivo `vm-test.txt` criado pela Windows VM no Bloco 2! Isso prova que os dados sao compartilhados entre plataformas diferentes.

12. Crie um arquivo a partir do container:

    ```bash
    echo "Hello from ACI container" > /mnt/fileshare/aci-test.txt
    ```

13. **Validacao cruzada:** Volte ao portal > Storage Account > **File shares** > **contoso-files** — confirme que `aci-test.txt` aparece

    > **Conexao com Blocos 1 e 2:** O mesmo file share e acessado pela Windows VM (drive Z:) e pelo container ACI (/mnt/fileshare). Dados sao compartilhados entre compute platforms diferentes via Azure Files — uma VM Windows, um container Linux e o portal Azure todos veem os mesmos arquivos.

---

### Task 4.3: Revisar logs e eventos do container

**O que estamos fazendo e por que:** Monitorar containers e essencial para troubleshooting. ACI fornece logs basicos (stdout/stderr do processo) e eventos de lifecycle (quando o container foi iniciado, parado, etc.). Esses sao os primeiros lugares para investigar quando algo da errado.

1. Na container instance **ci-contoso-worker**, navegue para **Settings** > **Containers**

2. Selecione o container e explore as abas:
   - **Events**: mostra eventos de lifecycle (Pull, Start, etc.)
   - **Logs**: mostra stdout/stderr da aplicacao
   - **Properties**: configuracao detalhada

   > **Events** mostra a sequencia: Pull (baixar imagem) → Create (criar container) → Start (iniciar processo). Se o container falhar, os eventos mostram em que etapa houve problema.

3. Na aba **Logs**, revise as mensagens de log da aplicacao

4. Navegue para a container instance > **Monitoring** > **Metrics**

5. Explore metricas como:
   - **CPU Usage**
   - **Memory Usage**
   - **Network Bytes Received/Sent**

   > **Conceito:** ACI fornece metricas e logs basicos. Para cenarios mais avancados (queries KQL, alertas, dashboards), integre com Azure Monitor e Log Analytics. Comparado com VMs, containers tem lifecycle mais curto — logs precisam ser exportados antes do container ser deletado.

---

### Task 4.4: Testar restart e lifecycle do container

**O que estamos fazendo e por que:** Entender o ciclo de vida do container e importante para a prova. Containers podem ser stopped, started e restarted — e o comportamento de cobranca muda conforme o estado. Containers stopped NAO geram custo de compute, o que os torna mais economicos que VMs desalocadas (que param de cobrar compute mas continuam cobrando disco).

1. Na container instance **ci-contoso-worker**, clique em **Restart** no blade **Overview**

2. Observe os **Events** durante o restart

3. Agora clique em **Stop**

4. Observe o status mudar para **Stopped**

5. Clique em **Start** para reiniciar

6. Acesse o FQDN novamente para confirmar que o container esta respondendo

   > **Conceito:** ACI containers podem ser stopped/started. Quando stopped, voce NAO e cobrado por compute (apenas por storage de logs). A restart policy determina o comportamento automatico: Always (servicos), OnFailure (jobs com retry), Never (jobs one-shot).

   > **Dica AZ-104:** Na prova, diferencie os tres servicos de containers:

   | Servico            | Quando usar                         | Scaling                              | Complexidade  |
   | ------------------ | ----------------------------------- | ------------------------------------ | ------------- |
   | **ACI**            | Jobs simples, batch, teste rapido   | Manual (sem auto-scale)              | Mais simples  |
   | **Container Apps** | Microservicos, APIs, event-driven   | Auto-scale (HTTP, KEDA)              | Medio         |
   | **AKS**            | Kubernetes completo, controle total | Auto-scale (HPA, cluster autoscaler) | Mais complexo |

---

## Modo Desafio - Bloco 4

- [ ] Criar container `ci-contoso-worker` com imagem `aci-helloworld` e acesso publico
- [ ] Acessar FQDN e confirmar que o container esta respondendo
- [ ] **Integracao Bloco 1:** Criar `ci-contoso-worker-2` com volume montando file share `contoso-files`
- [ ] **Integracao Bloco 2:** Via terminal do container, ler arquivo criado pela VM (`vm-test.txt`)
- [ ] Criar arquivo no container → confirmar no portal do Storage Account
- [ ] Revisar logs e eventos do container
- [ ] Testar restart/stop/start e observar lifecycle

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa montar um Azure File Share em um container ACI. Quais informacoes sao necessarias?**

A) Apenas o nome do file share
B) Storage account name, storage account key e file share name
C) Apenas a connection string do storage
D) O SAS token do file share

<details>
<summary>Ver resposta</summary>

**Resposta: B) Storage account name, storage account key e file share name**

Para montar um Azure File Share como volume em ACI, voce precisa do storage account name, da storage account key (para autenticacao) e do nome do file share.

</details>

### Questao 4.2
**Qual restart policy do ACI e mais adequada para um job de processamento batch que deve executar uma vez e parar?**

A) Always
B) OnFailure
C) Never
D) Scheduled

<details>
<summary>Ver resposta</summary>

**Resposta: C) Never**

A restart policy **Never** faz o container executar uma vez e parar. **OnFailure** reinicia apenas se o container falhar (exit code != 0). **Always** reinicia sempre (default para servicos long-running).

</details>

### Questao 4.3
**Voce tem um container ACI no estado Stopped. Voce esta sendo cobrado por compute?**

A) Sim, enquanto o container existir
B) Nao, containers stopped nao geram custo de compute
C) Sim, mas com 50% de desconto
D) Depende do SKU

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, containers stopped nao geram custo de compute**

ACI cobra por segundo de uso de CPU e memoria. Containers no estado Stopped nao consomem compute e nao geram custo de compute. Voce e cobrado apenas quando o container esta Running.

</details>

---
