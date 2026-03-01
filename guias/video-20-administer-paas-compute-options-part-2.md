# Video 20: Administer PaaS Compute Options (Part 2) AZ-104

## Informacoes Gerais

| Propriedade             | Valor                                           |
| ----------------------- | ----------------------------------------------- |
| **Titulo**              | Administer PaaS Compute Options (Part 2) AZ-104 |
| **Canal**               | Microsoft Learn                                 |
| **Inscritos no Canal**  | 88,7 mil                                        |
| **Visualizacoes**       | 2.500+                                          |
| **Data de Publicacao**  | 4 de junho de 2025                              |
| **Posicao na Playlist** | Episodio 20 de 22                               |
| **Idioma**              | Ingles                                          |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=hyU8TnmxnV8                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Esta e a segunda parte do modulo sobre opcoes de computacao PaaS no Azure. O conteudo aprofunda em servicos de containers como Azure Container Instances (ACI), Azure Kubernetes Service (AKS) e Azure Functions para computacao serverless.

### O que voce aprendera

- Azure Container Instances (ACI)
- Conceitos basicos de Azure Kubernetes Service (AKS)
- Azure Functions e computacao serverless
- Comparacao entre as opcoes de containers
- Casos de uso para cada servico

---

## Topicos Abordados

### 1. Azure Container Instances (ACI)

| Aspecto       | Descricao                                        |
| ------------- | ------------------------------------------------ |
| **Definicao** | Executar containers sem gerenciar infraestrutura |
| **Uso Ideal** | Tarefas simples, batch jobs, desenvolvimento     |
| **Billing**   | Por segundo de execucao                          |
| **Limitacao** | Sem orquestracao avancada                        |

#### Configuracoes ACI

| Configuracao       | Opcoes                         |
| ------------------ | ------------------------------ |
| **OS Type**        | Linux, Windows                 |
| **vCPU**           | 1-4 cores                      |
| **Memory**         | 0.5-16 GB                      |
| **Networking**     | IP publico ou VNet integration |
| **Restart Policy** | Always, Never, OnFailure       |

### 2. Container Groups

| Caracteristica       | Detalhe                                      |
| -------------------- | -------------------------------------------- |
| **Definicao**        | Multiplos containers no mesmo host           |
| **Compartilhamento** | Ciclo de vida, rede, volumes                 |
| **Caso de Uso**      | Sidecar patterns, aplicacoes multi-container |
| **Limitacao**        | Apenas Linux no multi-container              |

### 3. Azure Kubernetes Service (AKS)

| Componente        | Funcao                               |
| ----------------- | ------------------------------------ |
| **Control Plane** | Gerenciado pela Microsoft (gratuito) |
| **Node Pools**    | Workers que executam os pods         |
| **Pods**          | Unidade minima de deployment         |
| **Services**      | Exposicao de rede para pods          |

#### Conceitos AKS para o Exame

| Conceito       | Descricao                                |
| -------------- | ---------------------------------------- |
| **kubectl**    | CLI para gerenciar clusters              |
| **Node Pools** | Grupos de VMs com mesma configuracao     |
| **RBAC**       | Controle de acesso integrado ao Azure AD |
| **Networking** | Kubenet ou Azure CNI                     |

### 4. Azure Functions

| Aspecto      | Detalhe                                   |
| ------------ | ----------------------------------------- |
| **Modelo**   | Event-driven, serverless                  |
| **Triggers** | HTTP, Timer, Blob, Queue, Event Hub, etc. |
| **Bindings** | Input/Output para integracao              |
| **Scaling**  | Automatico baseado em demanda             |

#### Planos de Hosting

| Plano           | Caracteristicas                         |
| --------------- | --------------------------------------- |
| **Consumption** | Pay-per-execution, escala automatica    |
| **Premium**     | Pre-warmed instances, VNet connectivity |
| **Dedicated**   | App Service Plan, previsibilidade       |

---

## Conceitos-Chave para o Exame

1. **ACI vs AKS**

   - ACI: Containers simples, sem orquestracao
   - AKS: Orquestracao completa, aplicacoes complexas

2. **ACI Restart Policies**

   - Always: Reinicia sempre (default)
   - Never: Executa uma vez
   - OnFailure: Reinicia apenas em falha

3. **AKS Node Pools**

   - System Pool: Componentes do sistema
   - User Pool: Workloads da aplicacao
   - Pode ter multiplos pools com diferentes VM sizes

4. **Functions Triggers mais comuns**
   - HTTP: APIs e webhooks
   - Timer: Tarefas agendadas (cron)
   - Blob: Processamento de arquivos
   - Queue: Processamento de mensagens

---

## Comparacao de Servicos

| Servico         | Complexidade | Orquestracao | Custo          | Uso Ideal       |
| --------------- | ------------ | ------------ | -------------- | --------------- |
| **ACI**         | Baixa        | Nenhuma      | Por segundo    | Dev/test, batch |
| **AKS**         | Alta         | Kubernetes   | VMs + servicos | Microservices   |
| **Functions**   | Media        | Automatica   | Por execucao   | Event-driven    |
| **App Service** | Media        | Nenhuma      | Por plano      | Web apps        |

---

## Peso no Exame AZ-104

| Dominio                                               | Peso   |
| ----------------------------------------------------- | ------ |
| Implantar e gerenciar recursos de computacao do Azure | 20-25% |

Containers e serverless sao topicos cada vez mais frequentes no exame AZ-104.

---

## Recursos Complementares

| Recurso                       | Link                                                         |
| ----------------------------- | ------------------------------------------------------------ |
| **Azure Container Instances** | https://learn.microsoft.com/en-us/azure/container-instances/ |
| **Azure Kubernetes Service**  | https://learn.microsoft.com/en-us/azure/aks/                 |
| **Azure Functions**           | https://learn.microsoft.com/en-us/azure/azure-functions/     |

---

## Video Anterior

**Video 19:** Administrar opcoes de computacao PaaS (Parte 1)

- Azure App Service
- App Service Plans
- Deployment slots
- Configuracao de aplicacoes web

## Proximo Video

**Video 21:** Administer Data Protection AZ-104

- Azure Backup
- Recovery Services Vault
- Politicas de backup
- Azure Site Recovery

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_
