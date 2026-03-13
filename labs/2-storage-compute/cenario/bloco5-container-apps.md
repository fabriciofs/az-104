> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 6 - Storage Avancado e Disk Encryption](bloco6-storage-advanced.md)

# Bloco 5 - Azure Container Apps

**Origem:** Lab 09c - Implement Azure Container Apps
**Resource Groups utilizados:** `rg-contoso-compute`

## Contexto

Como passo final, voce implanta Azure Container Apps — uma plataforma serverless para containers que oferece recursos avancados de orquestracao como auto-scaling baseado em HTTP, revisoes e integracao com KEDA. O Container Apps Environment sera configurado para usar a VNet da Semana 1 e o storage do Bloco 1, demonstrando a integracao completa do ecossistema.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────┐
│                          rg-contoso-compute                      │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Container Apps Environment: cae-contoso-prod              │  │
│  │  (Ambiente gerenciado para Container Apps)                 │  │
│  │                                                            │  │
│  │  VNet Integration: vnet-contoso-hub (Semana 1)             │  │
│  │  ou subnet dedicada                                        │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  Container App: ca-contoso-api                       │  │  │
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
│  │  │  Container App: ca-contoso-api-2                     │  │  │
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

**O que estamos fazendo e por que:** O Container Apps Environment e o "condominio" onde os Container Apps moram. Ele fornece infraestrutura compartilhada — rede, logging e isolamento. Todos os Container Apps no mesmo environment compartilham a mesma VNet e podem se comunicar internamente. Analogia: o environment e o predio, cada Container App e um apartamento dentro dele.

O environment define a infraestrutura compartilhada onde os Container Apps executam.

1. Pesquise e selecione **Container Apps Environments** > **+ Create**

2. Aba **Basics**:

   | Setting          | Value                                        |
   | ---------------- | -------------------------------------------- |
   | Subscription     | *sua subscription*                           |
   | Resource group   | `rg-contoso-compute` (ja existe do Modulo 1) |
   | Environment name | `cae-contoso-prod`                           |
   | Region           | **East US**                                  |
   | Environment type | **Consumption only**                         |

   > **Environment type:** Consumption only = serverless, paga por uso (scale-to-zero possivel). Workload profiles = permite escolher tamanhos de hardware (mais controle, para workloads exigentes). Para a maioria dos cenarios e para a prova, Consumption e a resposta padrao.

3. Aba **Networking**:

   | Setting                      | Value                                                                         |
   | ---------------------------- | ----------------------------------------------------------------------------- |
   | Use your own virtual network | **Yes**                                                                       |
   | Virtual network              | **vnet-contoso-hub** (de rg-contoso-network, Semana 1)                        |
   | Infrastructure subnet        | *Crie uma nova subnet dedicada* `snet-containers` (10.20.30.0/23, minimo /23) |

   > **Por que /23 minimo?** Container Apps precisa de muitos IPs para gerenciar a infraestrutura interna (envoy proxies, logging, etc.) alem das replicas dos containers. /23 = 512 IPs, que e o minimo para acomodar tudo. Subnets menores que /23 serao rejeitadas.

   > **Nota:** Container Apps requer uma subnet dedicada com tamanho minimo /23. Se a vnet-contoso-hub nao tiver espaco disponivel ou nao existir, crie sem VNet integration (selecione **No**) e prossiga.

   > **Conexao com Semana 1:** O Container Apps Environment esta integrado a vnet-contoso-hub, permitindo comunicacao com recursos na VNet e VNets peered (vnet-contoso-spoke).

4. Aba **Monitoring**: selecione **Do not create** para Log Analytics (simplificar) ou crie um novo workspace

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment (pode levar 3-5 minutos)

   > **Conceito:** O Container Apps Environment e analogo a um "cluster" — fornece isolamento, logging e networking compartilhados. Diferente de AKS, voce nao gerencia nodes nem infraestrutura. O Azure cuida de tudo — voce so se preocupa com os containers.

---

### Task 5.2: Criar Container App com imagem publica

> **Cobranca:** Container Apps geram cobranca por replica ativa. Com scale-to-zero configurado, nao ha custo quando ociosas.

**O que estamos fazendo e por que:** Agora criamos o Container App em si — a aplicacao que roda dentro do environment. Container Apps oferece HTTPS automatico, auto-scaling e gerenciamento de revisoes "de graca" (incluso na plataforma). Compare com ACI (Bloco 4): la voce tem um container simples; aqui voce tem uma plataforma completa de microservicos.

1. Pesquise **Container Apps** > **+ Create**

2. Aba **Basics**:

   | Setting                    | Value                               |
   | -------------------------- | ----------------------------------- |
   | Subscription               | *sua subscription*                  |
   | Resource group             | `rg-contoso-compute`                |
   | Container app name         | `ca-contoso-api`                    |
   | Region                     | **East US**                         |
   | Container Apps Environment | **cae-contoso-prod** (criado acima) |

3. Aba **Container**:

   | Setting               | Value                                       |
   | --------------------- | ------------------------------------------- |
   | Image source          | **Docker Hub or other registries**          |
   | Image type            | **Public**                                  |
   | Registry login server | `mcr.microsoft.com`                         |
   | Image and tag         | `azuredocs/containerapps-helloworld:latest` |
   | CPU and Memory        | **0.25 CPU cores, 0.5 Gi memory**           |

   > **CPU/Memory granular:** Container Apps permite alocacoes muito menores que ACI ou VMs. 0.25 CPU + 0.5 Gi e suficiente para apps leves e custa centavos por hora. Isso, combinado com scale-to-zero, torna Container Apps extremamente economico para workloads intermitentes.

4. Em **Environment variables**, clique em **+ Add**:

   | Setting | Value                                            |
   | ------- | ------------------------------------------------ |
   | Name    | `STORAGE_CONNECTION`                             |
   | Source  | **Manual entry**                                 |
   | Value   | *connection string do Storage Account (Bloco 1)* |

   > **Conexao com Bloco 1:** A variavel de ambiente referencia o Storage Account, permitindo que a aplicacao acesse dados do Bloco 1. Em producao, use **Secrets** (Task 5.5) ao inves de manual entry para nao expor credenciais em texto plano na configuracao.

5. Aba **Ingress**:

   | Setting         | Value                               |
   | --------------- | ----------------------------------- |
   | Ingress         | **Enabled**                         |
   | Ingress traffic | **Accepting traffic from anywhere** |
   | Ingress type    | **HTTP**                            |
   | Target port     | `80`                                |

   > **Ingress** controla como o trafego chega ao container. Disabled = nao acessivel externamente (apenas internamente no environment). External = acessivel pela internet. Internal = acessivel apenas dentro da VNet. O Container Apps cuida de TLS, certificado e load balancing automaticamente.

6. Clique em **Review + create** > **Create**

7. Apos o deploy, navegue para o Container App > **Overview**

8. Copie a **Application Url** e acesse no navegador — voce deve ver a pagina de boas-vindas

   > **Conceito:** Container Apps oferece HTTPS automatico, auto-scaling e gerenciamento de revisoes. A URL gerada inclui HTTPS com certificado gerenciado — voce nao precisa configurar nada. Compare com ACI (Bloco 4), onde voce tem HTTP simples sem certificado.

---

### Task 5.3: Configurar Scaling e Revisions

**O que estamos fazendo e por que:** O grande diferencial de Container Apps sobre ACI e o **auto-scaling inteligente**. Voce define regras (ex: "ate 10 requests simultaneos por replica") e o Container Apps cria/remove replicas automaticamente. O recurso mais poderoso e **scale-to-zero**: quando ninguem esta usando a app, nenhuma replica roda e voce paga zero. O primeiro request apos scale-to-zero tem latencia adicional (cold start).

1. No Container App **ca-contoso-api**, navegue para **Application** > **Scale and replicas**

2. Clique em **Edit and deploy**

3. Na aba **Scale**:

   | Setting      | Value |
   | ------------ | ----- |
   | Min replicas | `0`   |
   | Max replicas | `5`   |

   > **Min replicas = 0** habilita scale-to-zero. Se voce precisa de resposta instantanea (sem cold start), defina min = 1 — mas pagara pela replica ociosa.

4. Revise a regra de scaling padrao (**HTTP scaling**):
   - Concurrent requests per replica: `10` (cada replica lida com ate 10 requests simultaneos)

   > **Como funciona:** Se chegam 25 requests simultaneos e cada replica suporta 10, o Container Apps cria 3 replicas (25/10 = 2.5, arredondado para 3). Se o trafego cai para 5 requests, reduz para 1 replica.

5. Clique em **Create**

   > **Conceito:** Container Apps pode escalar ate ZERO replicas quando nao ha trafego (scale-to-zero). Isso reduz custos drasticamente. O primeiro request apos scale-to-zero pode ter **cold start** (latencia adicional de 1-5 segundos). Para apps criticas, mantenha min = 1.

6. Navegue para **Application** > **Revisions and replicas**

7. Observe a revisao atual (ativa, com 100% do trafego)

   > **Conceito:** Cada alteracao no Container App (imagem, env vars, scaling) cria uma nova **Revision**. Revisoes sao imutaveis — uma vez criadas, nao mudam. Voce pode ter multiplas revisoes ativas simultaneamente para canary deployments ou A/B testing.

---

### Task 5.4: Criar nova revisao (Blue/Green deployment)

**O que estamos fazendo e por que:** Revisoes permitem o padrao blue/green deployment: voce cria uma nova versao (green) ao lado da existente (blue) e divide o trafego entre elas. Diferente do swap de slots do App Service (Bloco 3) que e tudo-ou-nada, aqui voce pode enviar 10%, 50% ou qualquer percentual para a nova versao. Se algo der errado, basta redirecionar 100% de volta.

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

   > **Traffic split** funciona no nivel do ingress — o load balancer distribui as requisicoes conforme os percentuais. Cada requisicao vai inteira para uma revisao (nao e round-robin por pacote). Com 50/50, metade dos usuarios ve v1 e metade ve v2.

6. Clique em **Save**

7. Acesse a URL da aplicacao varias vezes — voce pode observar respostas de diferentes revisoes

   > **Conceito:** Traffic splitting permite canary deployments e A/B testing. Voce pode gradualmente migrar trafego para a nova revisao (ex: 10%, 25%, 50%, 100%) e reverter se necessario. Cada revisao pode ter configuracoes de scaling independentes.

   > **Conexao com Bloco 3:** Compare com deployment slots do App Service (Bloco 3). Container Apps usa revisoes para o mesmo proposito, mas com mais granularidade no traffic split (qualquer percentual vs tudo-ou-nada no swap).

---

### Task 5.5: Explorar Features do Container Apps (Secrets, Logs, Metrics)

**O que estamos fazendo e por que:** Em producao, credenciais nunca devem ficar em texto plano nas environment variables. Container Apps tem um sistema de **Secrets** que armazena valores de forma segura e os injeta nos containers. Alem disso, logs e metricas sao essenciais para monitorar a saude da aplicacao e entender padroes de trafego.

1. Navegue para **Settings** > **Secrets**

2. Clique em **+ Add**:

   | Setting | Value                                   |
   | ------- | --------------------------------------- |
   | Key     | `storage-key`                           |
   | Type    | **Container Apps Secret**               |
   | Value   | *cole a storage account key do Bloco 1* |

3. Clique em **Add**

   > **Conceito:** Secrets sao armazenados de forma segura no Container Apps Environment — criptografados em repouso e nunca expostos em logs. Eles podem ser referenciados como environment variables nos containers, substituindo valores em texto plano. Para integracao com Key Vault, use "Key Vault reference" como tipo.

4. Navegue para **Monitoring** > **Log stream**

5. Selecione a revisao ativa e observe os logs em tempo real

6. Navegue para **Monitoring** > **Metrics**

7. Explore metricas como:
   - **Requests** (total de requests HTTP)
   - **Replica Count** (numero de replicas ativas)
   - **CPU Usage** e **Memory Usage**

   > **Replica Count** e a metrica mais importante para validar se o auto-scaling esta funcionando. Se voce espera 3 replicas mas ve apenas 1, verifique as regras de scaling e o trafego.

8. Navegue para **Application** > **Containers**:
   - Revise a configuracao do container
   - Note os resource limits (CPU/Memory)

   > **Conceito:** Container Apps integra com Azure Monitor para metricas e logs. Em cenarios de producao, use Log Analytics workspace para consultas avancadas (KQL).

   > **Dica AZ-104:** Na prova, compare os tres servicos de containers:

   | Feature                | ACI   | Container Apps   | AKS                  |
   | ---------------------- | ----- | ---------------- | -------------------- |
   | Auto-scale             | Nao   | Sim (HTTP, KEDA) | Sim (HPA)            |
   | Scale-to-zero          | Nao   | Sim              | Nao (minimo 1 node)  |
   | HTTPS automatico       | Nao   | Sim              | Manual (Ingress)     |
   | Revisoes/traffic split | Nao   | Sim              | Manual (Helm, Istio) |
   | Complexidade           | Baixa | Media            | Alta                 |

---

## Modo Desafio - Bloco 5

- [ ] Criar Container Apps Environment `cae-contoso-prod` no rg-contoso-compute
- [ ] **Integracao Semana 1:** Configurar VNet Integration com vnet-contoso-hub (subnet dedicada /23)
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
