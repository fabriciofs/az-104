> Voltar para o [Cenário Contoso](../cenario-contoso.md)

# Bloco 5 - Azure Container Apps

**Origem:** Lab 09c - Implement Azure Container Apps
**Resource Groups utilizados:** `rg-contoso-compute`

## Contexto

Como passo final, voce implanta Azure Container Apps — uma plataforma serverless para containers que oferece recursos avancados de orquestracao como auto-scaling baseado em HTTP, revisoes e integracao com KEDA. O Container Apps Environment sera configurado para usar a VNet da Semana 1 e o storage do Bloco 1, demonstrando a integracao completa do ecossistema.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────┐
│                          rg-contoso-compute                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Container Apps Environment: cae-contoso-prod                     │  │
│  │  (Ambiente gerenciado para Container Apps)                 │  │
│  │                                                            │  │
│  │  VNet Integration: vnet-contoso-hub-brazilsouth (Semana 1)             │  │
│  │  ou subnet dedicada                                        │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  Container App: ca-contoso-api                           │  │  │
│  │  │  Image: mcr.microsoft.com/azuredocs/containerapps-   │  │  │
│  │  │         helloworld:latest                            │  │  │
│  │  │                                                      │  │  │
│  │  │  Ingress: External (HTTP, port 80)                   │  │  │
│  │  │  Scaling: min 0, max 5 (HTTP requests)               │  │  │
│  │  │  Revisions: Multiple (blue/green)                    │  │  │
│  │  │                                                      │  │  │
│  │  │  Environment Variables:                              │  │  │
│  │  │  • STORAGE_CONN (← Bloco 1)                          │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  Container App: ca-contoso-api-2                           │  │  │
│  │  │  (segunda revisao / multi-container)                 │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  → Usa VNet da Semana 1 para integracao de rede                  │
│  → Storage Account do Bloco 1 referenciado via env vars          │
│  → Demonstra evolucao: VMs → Web Apps → ACI → Container Apps     │
└──────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Container Apps Environment

O environment define a infraestrutura compartilhada onde os Container Apps executam.

1. Pesquise e selecione **Container Apps Environments** > **+ Create**

2. Aba **Basics**:

   | Setting          | Value                             |
   | ---------------- | --------------------------------- |
   | Subscription     | *sua subscription*                |
   | Resource group   | `rg-contoso-compute` (ja existe do Modulo 1) |
   | Environment name | `cae-contoso-prod`                       |
   | Region           | **East US**                       |
   | Environment type | **Consumption only**              |

3. Aba **Networking**:

   | Setting                      | Value                                                                             |
   | ---------------------------- | --------------------------------------------------------------------------------- |
   | Use your own virtual network | **Yes**                                                                           |
   | Virtual network              | **vnet-contoso-hub-brazilsouth** (de rg-contoso-network, Semana 1)                                     |
   | Infrastructure subnet        | *Crie uma nova subnet dedicada* `snet-containers` (10.20.30.0/23, minimo /23) |

   > **Nota:** Container Apps requer uma subnet dedicada com tamanho minimo /23. Se a vnet-contoso-hub-brazilsouth nao tiver espaco disponivel ou nao existir, crie sem VNet integration (selecione **No**) e prossiga.

   > **Conexao com Semana 1:** O Container Apps Environment esta integrado a vnet-contoso-hub-brazilsouth, permitindo comunicacao com recursos na VNet e VNets peered (vnet-contoso-spoke-brazilsouth).

4. Aba **Monitoring**: selecione **Do not create** para Log Analytics (simplificar) ou crie um novo workspace

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment (pode levar 3-5 minutos)

   > **Conceito:** O Container Apps Environment e analogo a um "cluster" — fornece isolamento, logging e networking compartilhados. Multiplos Container Apps podem coexistir no mesmo environment.

---

### Task 5.2: Criar Container App com imagem publica

> **Cobranca:** Container Apps geram cobranca por replica ativa. Com scale-to-zero configurado, nao ha custo quando ociosas.

1. Pesquise **Container Apps** > **+ Create**

2. Aba **Basics**:

   | Setting                    | Value                        |
   | -------------------------- | ---------------------------- |
   | Subscription               | *sua subscription*           |
   | Resource group             | `rg-contoso-compute`                 |
   | Container app name         | `ca-contoso-api`                 |
   | Region                     | **East US**                  |
   | Container Apps Environment | **cae-contoso-prod** (criado acima) |

3. Aba **Container**:

   | Setting               | Value                                       |
   | --------------------- | ------------------------------------------- |
   | Image source          | **Docker Hub or other registries**          |
   | Image type            | **Public**                                  |
   | Registry login server | `mcr.microsoft.com`                         |
   | Image and tag         | `azuredocs/containerapps-helloworld:latest` |
   | CPU and Memory        | **0.25 CPU cores, 0.5 Gi memory**           |

4. Em **Environment variables**, clique em **+ Add**:

   | Setting | Value                                            |
   | ------- | ------------------------------------------------ |
   | Name    | `STORAGE_CONNECTION`                             |
   | Source  | **Manual entry**                                 |
   | Value   | *connection string do Storage Account (Bloco 1)* |

   > **Conexao com Bloco 1:** A variavel de ambiente referencia o Storage Account, permitindo que a aplicacao acesse dados do Bloco 1. Em producao, use secrets ao inves de manual entry.

5. Aba **Ingress**:

   | Setting         | Value                               |
   | --------------- | ----------------------------------- |
   | Ingress         | **Enabled**                         |
   | Ingress traffic | **Accepting traffic from anywhere** |
   | Ingress type    | **HTTP**                            |
   | Target port     | `80`                                |

6. Clique em **Review + create** > **Create**

7. Apos o deploy, navegue para o Container App > **Overview**

8. Copie a **Application Url** e acesse no navegador — voce deve ver a pagina de boas-vindas

   > **Conceito:** Container Apps oferece HTTPS automatico, auto-scaling e gerenciamento de revisoes. A URL gerada inclui HTTPS com certificado gerenciado.

---

### Task 5.3: Configurar Scaling e Revisions

1. No Container App **ca-contoso-api**, navegue para **Application** > **Scale and replicas**

2. Clique em **Edit and deploy**

3. Na aba **Scale**:

   | Setting      | Value |
   | ------------ | ----- |
   | Min replicas | `0`   |
   | Max replicas | `5`   |

4. Revise a regra de scaling padrao (**HTTP scaling**):
   - Concurrent requests per replica: `10` (cada replica lida com ate 10 requests simultaneos)

5. Clique em **Create**

   > **Conceito:** Container Apps pode escalar ate ZERO replicas quando nao ha trafego (scale-to-zero). Isso reduz custos drasticamente. O primeiro request apos scale-to-zero pode ter **cold start** (latencia adicional).

6. Navegue para **Application** > **Revisions and replicas**

7. Observe a revisao atual (ativa, com 100% do trafego)

   > **Conceito:** Cada alteracao no Container App cria uma nova **Revision**. Voce pode ter multiplas revisoes ativas para canary deployments ou A/B testing.

---

### Task 5.4: Criar nova revisao (Blue/Green deployment)

1. Navegue para **Revisions and replicas** > **+ Create new revision**

2. Na aba **Container image**:
   - Mantenha a mesma imagem mas altere uma environment variable:

   | Setting | Value            |
   | ------- | ---------------- |
   | Name    | `APP_VERSION`    |
   | Source  | **Manual entry** |
   | Value   | `v2`             |

3. Clique em **Create**

4. Apos a criacao, navegue para **Revisions and replicas**

5. Agora ha **duas revisoes**. Configure o traffic split:
   - Selecione **Revision management** > altere o modo para **Multiple: Several revisions active simultaneously**
   - Revisao v1: `50%`
   - Revisao v2: `50%`

6. Clique em **Save**

7. Acesse a URL da aplicacao varias vezes — voce pode observar respostas de diferentes revisoes

   > **Conceito:** Traffic splitting permite canary deployments e A/B testing. Voce pode gradualmente migrar trafego para a nova revisao (ex: 10%, 25%, 50%, 100%) e reverter se necessario.

   > **Conexao com Bloco 3:** Compare com deployment slots do App Service (Bloco 3). Container Apps usa revisoes para o mesmo proposito, mas com mais granularidade no traffic split.

---

### Task 5.5: Explorar Features do Container Apps (Secrets, Logs, Metrics)

1. Navegue para **Settings** > **Secrets**

2. Clique em **+ Add**:

   | Setting | Value                                   |
   | ------- | --------------------------------------- |
   | Key     | `storage-key`                           |
   | Type    | **Container Apps Secret**               |
   | Value   | *cole a storage account key do Bloco 1* |

3. Clique em **Add**

   > **Conceito:** Secrets sao armazenados de forma segura no Container Apps Environment. Eles podem ser referenciados como environment variables nos containers, evitando hardcode de credenciais.

4. Navegue para **Monitoring** > **Log stream**

5. Selecione a revisao ativa e observe os logs em tempo real

6. Navegue para **Monitoring** > **Metrics**

7. Explore metricas como:
   - **Requests** (total de requests HTTP)
   - **Replica Count** (numero de replicas ativas)
   - **CPU Usage** e **Memory Usage**

8. Navegue para **Application** > **Containers**:
   - Revise a configuracao do container
   - Note os resource limits (CPU/Memory)

   > **Conceito:** Container Apps integra com Azure Monitor para metricas e logs. Em cenarios de producao, use Log Analytics workspace para consultas avancadas (KQL).

   > **Dica AZ-104:** Na prova, compare: ACI = containers simples (sem scaling avancado); Container Apps = serverless com auto-scale, revisions, HTTPS automatico; AKS = controle total do Kubernetes.

---

## Modo Desafio - Bloco 5

- [ ] Criar Container Apps Environment `cae-contoso-prod` no rg-contoso-compute
- [ ] **Integracao Semana 1:** Configurar VNet Integration com vnet-contoso-hub-brazilsouth (subnet dedicada /23)
- [ ] Criar Container App `ca-contoso-api` com imagem `containerapps-helloworld`
- [ ] **Integracao Bloco 1:** Adicionar env var com connection string do Storage Account
- [ ] Acessar Application URL e confirmar resposta
- [ ] Configurar scaling: min 0, max 5 (HTTP, 10 concurrent requests)
- [ ] Criar nova revisao com env var `APP_VERSION=v2`
- [ ] Configurar traffic split: 50%/50% entre revisoes
- [ ] Adicionar Secret com storage key do Bloco 1
- [ ] Explorar Log stream e Metrics

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Qual o tamanho minimo de subnet necessario para um Container Apps Environment com VNet integration?**

A) /28
B) /27
C) /24
D) /23

<details>
<summary>Ver resposta</summary>

**Resposta: D) /23**

Container Apps requer uma subnet dedicada com tamanho minimo **/23** (512 enderecos). Isso e necessario para acomodar a infraestrutura do environment e as replicas dos containers.

</details>

### Questao 5.2
**Voce configurou um Container App com min replicas = 0. O que acontece quando nao ha trafego HTTP?**

A) Uma replica permanece ativa (minimo 1)
B) O Container App e escalado para zero replicas (nao gera custo de compute)
C) O Container App e deletado automaticamente
D) O Container App entra em modo hibernacao com custo reduzido

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Container App e escalado para zero replicas (nao gera custo de compute)**

Container Apps suporta **scale-to-zero** — quando nao ha trafego, nenhuma replica e executada e nao ha custo de compute. O primeiro request apos scale-to-zero pode ter cold start (latencia adicional).

</details>

### Questao 5.3
**Qual servico Azure e mais adequado para executar containers com orquestracao serverless, auto-scaling baseado em HTTP e suporte a revisoes para canary deployment?**

A) Azure Container Instances (ACI)
B) Azure Kubernetes Service (AKS)
C) Azure Container Apps
D) Azure App Service (containers)

<details>
<summary>Ver resposta</summary>

**Resposta: C) Azure Container Apps**

Container Apps oferece orquestracao serverless com auto-scaling (incluindo scale-to-zero), revisoes para canary/blue-green deployments, HTTPS automatico e integracao com KEDA para scaling baseado em eventos. ACI e mais simples (sem orquestracao), AKS oferece controle total do Kubernetes.

</details>

### Questao 5.4
**Voce tem duas revisoes do Container App com traffic split 80/20. Voce quer reverter totalmente para a revisao anterior. O que voce deve fazer?**

A) Deletar a nova revisao
B) Alterar o traffic split para 100/0 (revisao anterior/nova)
C) Fazer rollback via CLI
D) Recriar o Container App

<details>
<summary>Ver resposta</summary>

**Resposta: B) Alterar o traffic split para 100/0 (revisao anterior/nova)**

Basta alterar o traffic split para enviar 100% do trafego para a revisao desejada. As revisoes podem ser mantidas ativas para futuras mudancas. Nao e necessario deletar a revisao.

</details>

---

