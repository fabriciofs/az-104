> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 5 - Azure Container Apps](bloco5-container-apps.md)

# Bloco 4 - Azure Container Instances

**Origem:** Lab 09b - Implement Azure Container Instances
**Resource Groups utilizados:** `rg-contoso-compute`

## Contexto

A Contoso Corp precisa executar cargas de trabalho em containers para processos batch e microservicos rapidos. Voce implanta Azure Container Instances (ACI) usando o file share do Bloco 1 como volume persistente. Isso demonstra como containers stateless podem acessar dados persistentes armazenados no Azure Storage.

## Diagrama

```
┌────────────────────────────────────────────────────────────────┐
│                          rg-contoso-compute                             │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Container Group: ci-contoso-worker                            │  │
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
│  │  │  │  Storage: stcontosoprod01               │      │  │  │
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

1. Pesquise e selecione **Container instances** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value                                        |
   | -------------- | -------------------------------------------- |
   | Subscription   | *sua subscription*                           |
   | Resource group | `rg-contoso-compute` (ja existe do Modulo 1)             |
   | Container name | `ci-contoso-worker`                          |
   | Region         | **East US**                                  |
   | SKU            | **Standard**                                 |
   | Image source   | **Other registry**                           |
   | Image type     | **Public**                                   |
   | Image          | `mcr.microsoft.com/azuredocs/aci-helloworld` |
   | OS type        | **Linux**                                    |
   | Size           | **1 vcpu, 1.5 GiB memory**                   |

3. Aba **Networking**:

   | Setting         | Value                                      |
   | --------------- | ------------------------------------------ |
   | Networking type | **Public**                                 |
   | DNS name label  | `ci-contoso-<uniqueid>` (globalmente unico) |
   | Ports           | `80`                                       |
   | Port protocol   | **TCP**                                    |

4. Aba **Advanced**:

   | Setting        | Value          |
   | -------------- | -------------- |
   | Restart policy | **On failure** |

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment > **Go to resource**

7. No blade **Overview**, copie o **FQDN** (ex: `ci-contoso-<uniqueid>.eastus.azurecontainer.io`)

8. Acesse o FQDN no navegador — voce deve ver a pagina "Welcome to Azure Container Instances!"

9. Revise no blade:
   - **Status**: Running
   - **IP address** (publico)
   - **Restart count**

   > **Conceito:** ACI e a forma mais simples de executar containers no Azure. Sem orquestracao, sem gerenciamento de cluster. Ideal para tarefas rapidas, batch jobs e cenarios simples.

---

### Task 4.2: Montar File Share do Bloco 1 como Volume

> **Cobranca:** Container Instances geram cobranca enquanto estiverem Running. Pare com `az container stop` ao pausar o lab.

Voce cria um novo container que monta o file share `contoso-files` do Bloco 1, demonstrando persistencia de dados entre containers e VMs.

1. Primeiro, obtenha a **storage account key** do Bloco 1:
   - Navegue para Storage Account **stcontosoprod01** > **Security + networking** > **Access keys**
   - Copie **key1**

2. Pesquise **Container instances** > **+ Create**

3. Aba **Basics**:

   | Setting        | Value                                        |
   | -------------- | -------------------------------------------- |
   | Resource group | `rg-contoso-compute`                                  |
   | Container name | `ci-contoso-worker-2`                          |
   | Region         | **East US**                                  |
   | Image source   | **Other registry**                           |
   | Image type     | **Public**                                   |
   | Image          | `mcr.microsoft.com/azuredocs/aci-helloworld` |
   | OS type        | **Linux**                                    |
   | Size           | **1 vcpu, 1.5 GiB memory**                   |

4. Aba **Networking**:

   | Setting         | Value                   |
   | --------------- | ----------------------- |
   | Networking type | **Public**              |
   | DNS name label  | `ci-contoso2-<uniqueid>` |
   | Ports           | `80`                    |

5. Aba **Advanced**:

   | Setting        | Value          |
   | -------------- | -------------- |
   | Restart policy | **On failure** |

6. Em **Volume mounts**, clique em **+ Add volume**:

   | Setting              | Value                              |
   | -------------------- | ---------------------------------- |
   | Volume name          | `filesharevolume`                  |
   | Volume type          | **Azure file share**               |
   | Storage account name | `stcontosoprod01` (Bloco 1) |
   | Storage account key  | *cole key1 copiada acima*          |
   | File share name      | `contoso-files`                    |
   | Mount path           | `/mnt/fileshare`                   |

7. Clique em **Add**

8. Clique em **Review + create** > **Create**

9. Apos o deploy, navegue para o container > **Settings** > **Containers** > selecione o container > **Connect**

10. Selecione `/bin/sh` > **Connect**

11. No terminal do container, execute:

    ```bash
    ls /mnt/fileshare/
    cat /mnt/fileshare/vm-test.txt
    ```

    > Voce deve ver o arquivo `vm-test.txt` criado pela Windows VM no Bloco 2!

12. Crie um arquivo a partir do container:

    ```bash
    echo "Hello from ACI container" > /mnt/fileshare/aci-test.txt
    ```

13. **Validacao cruzada:** Volte ao portal > Storage Account > **File shares** > **contoso-files** — confirme que `aci-test.txt` aparece

    > **Conexao com Blocos 1 e 2:** O mesmo file share e acessado pela Windows VM (drive Z:) e pelo container ACI (/mnt/fileshare). Dados sao compartilhados entre compute platforms diferentes via Azure Files.

---

### Task 4.3: Revisar logs e eventos do container

1. Na container instance **ci-contoso-worker**, navegue para **Settings** > **Containers**

2. Selecione o container e explore as abas:
   - **Events**: mostra eventos de lifecycle (Pull, Start, etc.)
   - **Logs**: mostra stdout/stderr da aplicacao
   - **Properties**: configuracao detalhada

3. Na aba **Logs**, revise as mensagens de log da aplicacao

4. Navegue para a container instance > **Monitoring** > **Metrics**

5. Explore metricas como:
   - **CPU Usage**
   - **Memory Usage**
   - **Network Bytes Received/Sent**

   > **Conceito:** ACI fornece metricas e logs basicos. Para cenarios mais avancados, integre com Azure Monitor e Log Analytics.

---

### Task 4.4: Testar restart e lifecycle do container

1. Na container instance **ci-contoso-worker**, clique em **Restart** no blade **Overview**

2. Observe os **Events** durante o restart

3. Agora clique em **Stop**

4. Observe o status mudar para **Stopped**

5. Clique em **Start** para reiniciar

6. Acesse o FQDN novamente para confirmar que o container esta respondendo

   > **Conceito:** ACI containers podem ser stopped/started. Quando stopped, voce NAO e cobrado por compute (apenas por storage de logs). A restart policy determina o comportamento automatico: Always, OnFailure, Never.

   > **Dica AZ-104:** Na prova, diferencie: ACI = containers simples sem orquestracao; AKS = Kubernetes gerenciado com orquestracao completa; Container Apps = meio-termo (orquestracao serverless baseada em KEDA/Dapr).

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

