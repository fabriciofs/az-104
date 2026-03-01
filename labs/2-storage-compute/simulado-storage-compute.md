# Simulado AZ-104 — Storage e Compute

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `simulado-storage-compute-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta (salvo indicacao contraria)
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: NovaTech Solutions

A **NovaTech Solutions** e uma empresa de tecnologia de medio porte especializada em desenvolvimento de software e servicos SaaS. Com sede em Curitiba, a empresa esta migrando sua infraestrutura on-premises para o Azure, escolhendo **East US** como regiao primaria e **West US** como regiao de DR.

A CTO, Fernanda Lima, contratou Diego Santos como **Azure Administrator** para configurar todo o armazenamento corporativo e implantar as cargas de trabalho de computacao. A NovaTech tem 200 funcionarios, 3 aplicacoes SaaS em producao, e precisa de alta disponibilidade (99.9% SLA).

---

## Personas

| Persona                   | Funcao              | Necessidade                     |
| ------------------------- | ------------------- | ------------------------------- |
| Diego Santos (`nt-admin`) | Azure Administrator | Full access                     |
| Fernanda Lima             | CTO                 | Reports de custos e compliance  |
| Time DevOps (5 membros)   | Equipe de DevOps    | Deploy de containers e web apps |
| Time Backend (8 membros)  | Equipe de Backend   | Acesso a storage e VMs          |

---

## Arquitetura da NovaTech

```
                    ┌───────────────────────────────────────────────────────────────┐
                    │                    AZURE — East US (Primary)                  │
                    │                                                               │
                    │  ┌─────────────────────────────────────────────────────────┐  │
                    │  │                  NovaTechVnet                           │  │
                    │  │                  10.0.0.0/16                            │  │
                    │  │                                                         │  │
                    │  │  ┌──────────────────┐     ┌──────────────────────────┐  │  │
                    │  │  │  ComputeSubnet   │     │  StorageSubnet           │  │  │
                    │  │  │  10.0.1.0/24     │     │  10.0.2.0/24             │  │  │
                    │  │  │                  │     │                          │  │  │
                    │  │  │  ┌────────────┐  │     │  ┌────────────────────┐  │  │  │
                    │  │  │  │ VM-Win01   │  │     │  │ ntprodsa (Blob)    │  │  │  │
                    │  │  │  │ VM-Linux01 │  │     │  │ ntfilessa (Files)  │  │  │  │
                    │  │  │  │ VMSS-Web   │  │     │  │ Private Endpoints  │  │  │  │
                    │  │  │  └────────────┘  │     │  └────────────────────┘  │  │  │
                    │  │  └──────────────────┘     └──────────────────────────┘  │  │
                    │  │                                                         │  │
                    │  │  ┌──────────────────┐     ┌──────────────────────────┐  │  │
                    │  │  │  WebAppSubnet    │     │  ContainerSubnet         │  │  │
                    │  │  │  10.0.3.0/24     │     │  10.0.4.0/24             │  │  │
                    │  │  │                  │     │                          │  │  │
                    │  │  │  ┌────────────┐  │     │  ┌────────────────────┐  │  │  │
                    │  │  │  │ App Svc    │  │     │  │ ACI (batch jobs)   │  │  │  │
                    │  │  │  │ (prod)     │  │     │  │ Container Apps     │  │  │  │
                    │  │  │  │ (staging)  │  │     │  │ (APIs + traffic    │  │  │  │
                    │  │  │  └────────────┘  │     │  │  splitting)        │  │  │  │
                    │  │  └──────────────────┘     │  └────────────────────┘  │  │  │
                    │  │                           └──────────────────────────┘  │  │
                    │  └─────────────────────────────────────────────────────────┘  │
                    │                                                               │
                    │  Storage Accounts:                                            │
                    │    ntprodsa     — Blob (Hot/Cool/Archive), LRS/ZRS/GRS        │
                    │    ntfilessa    — Azure Files (SMB, NFS)                      │
                    │    ntbackupsa   — Blob (Archive), GRS                         │
                    │                                                               │
                    ├───────────────────────────────────────────────────────────────┤
                    │                    AZURE — West US (DR)                       │
                    │    ntdrsa        — Blob replication target (RA-GRS)           │
                    └───────────────────────────────────────────────────────────────┘
```

---

## Secao 1 — Armazenamento (6 questoes)

### Q1.1 — Redundancia de Storage Account (Multipla Escolha)

Diego precisa escolher a opcao de redundancia para dados criticos da NovaTech. Os dados precisam sobreviver a uma falha de datacenter dentro da mesma regiao, mas **nao** precisam de replicacao para outra regiao.

Qual opcao de redundancia atende a esse requisito com o menor custo?

- **A)** LRS (Locally Redundant Storage)
- **B)** ZRS (Zone-Redundant Storage)
- **C)** GRS (Geo-Redundant Storage)
- **D)** RA-GRS (Read-Access Geo-Redundant Storage)

---

### Q1.2 — SAS Token vs Access Key (Design)

Diego precisa dar acesso temporario ao Time Backend para upload de blobs em um container especifico chamado `uploads`, sem expor a Access Key da Storage Account.

Responda:

1. Que tipo de SAS (Account SAS, Service SAS ou User Delegation SAS) Diego deve usar? Justifique.
2. Quais permissoes minimas devem ser configuradas no SAS token para permitir apenas upload?
3. Qual risco de seguranca existe se Diego usar Account SAS em vez de Service SAS para este cenario?

---

### Q1.3 — Lifecycle Management (Multipla Escolha)

A NovaTech tem blobs de logs que sao acessados frequentemente nos primeiros 30 dias, raramente nos proximos 90 dias, e nunca depois disso. Diego precisa configurar lifecycle management para otimizar custos.

Qual configuracao de lifecycle e a mais adequada?

- **A)** Hot → Cool (30 dias), Cool → Archive (90 dias), Delete (365 dias)
- **B)** Hot → Cool (30 dias), Cool → Delete (90 dias)
- **C)** Hot → Archive (30 dias), Delete (120 dias)
- **D)** Cool → Archive (30 dias), Archive → Delete (90 dias)

---

### Q1.4 — Private Endpoint vs Service Endpoint (Multipla Escolha)

Diego precisa garantir que o trafego entre a NovaTechVnet e o Storage Account `ntprodsa` nunca saia da rede backbone da Microsoft. Alem disso, ele precisa que o Storage Account tenha um **IP privado dentro da VNet**.

Qual opcao atende a ambos os requisitos?

- **A)** Service Endpoint
- **B)** Private Endpoint
- **C)** VNet Integration
- **D)** Network Peering

---

### Q1.5 — Azure Files Authentication (Cenario)

O Time Backend precisa mapear um Azure File Share como drive de rede (Z:) em VMs Windows dentro da NovaTechVnet. O file share esta na Storage Account `ntfilessa` e Diego quer usar autenticacao baseada em identidade com Microsoft Entra ID em vez de storage account keys.

Responda:

1. Quais pre-requisitos sao necessarios para habilitar autenticacao baseada em Entra ID para Azure Files?
2. Qual protocolo e porta sao usados para acessar Azure File Shares de VMs Windows?
3. Qual nivel de permissao RBAC minimo Diego deve atribuir ao Time Backend para que possam ler e gravar arquivos no file share?

---

### Q1.6 — Blob Soft Delete vs Versioning (Multipla Escolha)

Diego habilitou **soft delete** com 14 dias de retencao no blob storage da Storage Account `ntprodsa`. Um membro do Time Backend acidentalmente **sobrescreve** um blob critico com dados incorretos (faz upload de um novo arquivo com o mesmo nome).

O soft delete protege o blob original neste caso?

- **A)** Sim, soft delete protege contra sobrescrita e delecao
- **B)** Nao, soft delete so protege contra delecao. Versioning protege contra sobrescrita
- **C)** Sim, mas apenas se blob versioning tambem estiver habilitado
- **D)** Nao, nenhum mecanismo nativo do Azure protege contra sobrescrita

---

## Secao 2 — Virtual Machines (4 questoes)

### Q2.1 — Availability Options (Multipla Escolha)

A NovaTech precisa garantir **99.99% SLA** para as VMs de producao que hospedam as aplicacoes SaaS. Qual configuracao atende a esse nivel de SLA?

- **A)** Single VM com Premium SSD
- **B)** Availability Set com 2 fault domains e 5 update domains
- **C)** VMs distribuidas em Availability Zones
- **D)** VMSS com todas as instancias em uma zona unica

---

### Q2.2 — VM Resize (Troubleshooting)

Diego tenta redimensionar a VM `VM-Win01` de **Standard_D2s_v3** para **Standard_E4s_v3** pelo portal do Azure, mas recebe o erro: **"Allocation failed. The requested VM size is not available in the current hardware cluster."**

Responda:

1. Qual e a causa raiz desse erro?
2. Quais sao as solucoes possiveis para resolver o problema? Liste pelo menos duas abordagens.

---

### Q2.3 — Custom Script Extension vs Run Command (Design)

Diego precisa instalar e configurar um agente de monitoramento automaticamente em 50 VMs existentes e garantir que todas as VMs futuras criadas no VMSS tambem recebam o agente.

Responda:

1. Qual mecanismo de extensao Diego deve usar para instalar o agente nas VMs existentes?
2. Qual a diferenca fundamental entre Custom Script Extension e Run Command?
3. Como Diego pode garantir que VMs futuras criadas pelo VMSS ja tenham o agente instalado automaticamente?

---

### Q2.4 — VMSS Autoscale (Cenario)

A NovaTech configurou um VMSS para hospedar a aplicacao web principal com as seguintes regras de autoscale:

- **Scale-out:** Quando CPU media > 75% por 5 minutos, adicionar 2 instancias
- **Scale-in:** Quando CPU media < 25% por 10 minutos, remover 1 instancia
- **Minimo:** 2 instancias
- **Maximo:** 10 instancias
- **Cool-down period:** 5 minutos

Durante um pico de trafego, o VMSS escalou de 2 para 8 instancias. Quando o pico passou, as instancias voltaram gradualmente para 2.

Responda:

1. O comportamento de scale-out e scale-in descrito esta correto e esperado? Explique.
2. Que problema pode ocorrer se o cool-down period for configurado com um valor muito curto (ex: 1 minuto)?
3. Por que a regra de scale-in remove apenas 1 instancia por vez enquanto scale-out adiciona 2?

---

## Secao 3 — Web Apps (4 questoes)

### Q3.1 — App Service Plan Tiers (Multipla Escolha)

Diego precisa configurar deployment slots para a aplicacao SaaS principal da NovaTech no Azure App Service. Qual tier **minimo** do App Service Plan suporta deployment slots?

- **A)** Free (F1)
- **B)** Basic (B1)
- **C)** Standard (S1)
- **D)** Premium (P1v2)

---

### Q3.2 — Deployment Slot Swap (Cenario)

Diego deployou uma nova versao da aplicacao no slot **staging** e, apos validacao, executou um swap para **production**. Cinco minutos depois, o time de QA reporta um bug critico na nova versao em production.

Responda:

1. Como Diego pode reverter rapidamente para a versao anterior?
2. O que acontece com as app settings marcadas como "deployment slot setting" durante um swap?
3. Quais tipos de configuracoes **NAO** sao trocados durante um swap e permanecem fixos no slot?

---

### Q3.3 — App Service Autoscale (Multipla Escolha)

Diego configurou autoscale para o App Service Plan da NovaTech baseado na metrica **HTTP Queue Length**. Qual condicao indica que a aplicacao precisa de mais instancias?

- **A)** CPU percentage > 80%
- **B)** Memory percentage > 70%
- **C)** HTTP Queue Length > 0
- **D)** Requests per second > 1000

---

### Q3.4 — Slot-specific Settings (Design)

A NovaTech precisa que o slot de **staging** use um banco de dados de teste (`sqldb-staging`), enquanto o slot de **production** use o banco de dados real (`sqldb-prod`). Alem disso, o slot de staging deve usar uma Application Insights separada para nao poluir as metricas de producao.

Responda:

1. Como Diego deve configurar as connection strings para garantir que elas **nao** sejam trocadas durante um swap?
2. Qual checkbox ou configuracao especifica no portal do Azure controla esse comportamento?
3. Se Diego esquecer de marcar essa configuracao e fizer um swap, qual seria o impacto imediato em production?

---

## Secao 4 — Containers (4 questoes)

### Q4.1 — ACI vs Container Apps vs AKS (Design)

A NovaTech tem tres cenarios diferentes de containers. Para cada cenario, indique qual servico Diego deve usar e justifique:

1. **Cenario A:** Um job de processamento batch que roda 1 vez por dia, processa um arquivo CSV de 2GB e termina em aproximadamente 30 minutos
2. **Cenario B:** Uma API REST que precisa de autoscale baseado em requisicoes HTTP e traffic splitting (80/20) entre duas versoes
3. **Cenario C:** Uma arquitetura de microservicos com 15 servicos, service mesh, e necessidade de controle granular sobre networking e scheduling

---

### Q4.2 — ACI Resource Limits (Multipla Escolha)

Diego precisa rodar um container de processamento de dados no Azure Container Instances (ACI). Qual e o limite **maximo** de CPU cores que pode ser alocado por container group no ACI?

- **A)** 2 cores
- **B)** 4 cores
- **C)** 8 cores
- **D)** 16 cores

---

### Q4.3 — Container Apps Revision (Cenario)

Diego deployou a **v1** de uma API como Azure Container App. Agora precisa deployar a **v2** mas quer fazer um rollout gradual: manter **80%** do trafego na v1 e direcionar **20%** para a v2.

Responda:

1. Qual recurso do Azure Container Apps permite fazer traffic splitting entre versoes?
2. Como Diego deve configurar o traffic splitting para 80/20?
3. Se a v2 apresentar erros, como Diego pode rapidamente direcionar 100% do trafego de volta para v1?

---

### Q4.4 — ACI com File Share Mount (Troubleshooting)

Diego criou um Azure Container Instance com um volume mount apontando para um Azure File Share na Storage Account `ntfilessa`. O container nao inicia e mostra o erro: **"volume mount failed"**.

Diego verifica as seguintes possiveis causas:

1. Storage Account key fornecida esta incorreta ou expirada
2. O File Share especificado no deployment nao existe
3. O container esta rodando como usuario non-root e nao tem permissao no mount point
4. O Storage Account tem firewall habilitado e nao permite acesso da rede do ACI

Responda:

1. Quais dessas causas sao validas para o erro "volume mount failed"?
2. Qual e a causa **mais comum** desse erro em ambientes corporativos com seguranca habilitada?
3. Como Diego pode diagnosticar qual causa especifica esta gerando o erro?

---

## Pontuacao

| Secao             | Questoes | Pontos por Questao | Total  |
| ----------------- | -------- | ------------------ | ------ |
| 1 — Armazenamento | 6        | 5                  | 30     |
| 2 — VMs           | 4        | 5                  | 20     |
| 3 — Web Apps      | 4        | 5                  | 20     |
| 4 — Containers    | 4        | 5                  | 20     |
| **Total**         | **18**   | ---                | **90** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                     |
| ----- | ------------ | --------------------------------- |
| 80-90 | Excelente    | Pronto para avancar para Semana 3 |
| 65-79 | Bom          | Revisar questoes erradas nos labs |
| 45-64 | Regular      | Refazer blocos com dificuldade    |
| < 45  | Insuficiente | Refazer lab completo da Semana 2  |
