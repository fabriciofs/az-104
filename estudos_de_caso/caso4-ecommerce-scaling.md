# Estudo de Caso 4 — MegaStore Brasil

**Dificuldade:** Medio | **Dominios:** D3 Compute + D4 Networking + D2 Storage | **Questoes:** 8

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `caso4-ecommerce-scaling-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: MegaStore Brasil

A **MegaStore Brasil** e um e-commerce de grande porte com sede em **Porto Alegre**, especializado em eletronicos e eletrodomesticos. Com 500 funcionarios e 2 milhoes de clientes ativos, a MegaStore processa em media 50.000 pedidos por dia, com picos de ate **500.000 pedidos** durante a Black Friday.

**Thiago Almeida**, Azure Administrator da MegaStore, precisa garantir que a plataforma suporte os picos de demanda sem degradacao de performance, mantendo os custos controlados nos periodos normais.

A MegaStore esta migrando de um datacenter on-premises para o Azure e precisa replicar a arquitetura atual com melhorias de escalabilidade.

### Equipe

| Persona                     | Funcao                   | Responsabilidade            |
| --------------------------- | ------------------------ | --------------------------- |
| Thiago Almeida (`ms-admin`) | Azure Administrator      | Infraestrutura e operacoes  |
| Juliana Campos              | Lider de Desenvolvimento | Deployments e CI/CD         |
| Equipe de Infra (6 pessoas) | Operacoes                | Monitorar e manter recursos |

### Arquitetura

```
                    ┌──────────────────────────────────────────────────────────────┐
                    │                    AZURE — Brazil South                      │
                    │                                                              │
                    │  ┌────────────────────────────────────────────────────────┐  │
                    │  │  RG: ms-frontend-rg                                    │  │
                    │  │                                                        │  │
                    │  │  ┌─────────────────────┐  ┌────────────────────────┐   │  │
                    │  │  │ Application Gateway │  │ App Service:           │   │  │
                    │  │  │ (WAF + Load Balance)│  │ ms-webapp              │   │  │
                    │  │  │                     │──│ (website principal)    │   │  │
                    │  │  │ Subnet: AppGw       │  │ Plan: Standard S2      │   │  │
                    │  │  │ 10.0.1.0/24         │  │ Slots: prod + staging  │   │  │
                    │  │  └─────────────────────┘  └────────────────────────┘   │  │
                    │  └────────────────────────────────────────────────────────┘  │
                    │                                                              │
                    │  ┌────────────────────────────────────────────────────────┐  │
                    │  │  RG: ms-backend-rg                                     │  │
                    │  │                                                        │  │
                    │  │  ┌─────────────────────┐  ┌────────────────────────┐   │  │
                    │  │  │ VMSS: ms-api-vmss   │  │ Container Apps:        │   │  │
                    │  │  │ (API de pedidos)    │  │ ms-workers             │   │  │
                    │  │  │ 2-20 instancias     │  │ (processamento async)  │   │  │
                    │  │  │ Subnet: Backend     │  │                        │   │  │
                    │  │  │ 10.0.2.0/24         │  │                        │   │  │
                    │  │  └─────────────────────┘  └────────────────────────┘   │  │
                    │  └────────────────────────────────────────────────────────┘  │
                    │                                                              │
                    │  ┌────────────────────────────────────────────────────────┐  │
                    │  │  RG: ms-data-rg                                        │  │
                    │  │                                                        │  │
                    │  │  ┌─────────────────────┐  ┌────────────────────────┐   │  │
                    │  │  │ Storage Account:    │  │ SQL Database (PaaS)    │   │  │
                    │  │  │ msproductimages     │  │ Pedidos e catalogo     │   │  │
                    │  │  │ (imagens produto)   │  │                        │   │  │
                    │  │  └─────────────────────┘  └────────────────────────┘   │  │
                    │  └────────────────────────────────────────────────────────┘  │
                    │                                                              │
                    │  VNet: ms-vnet (10.0.0.0/16)                                 │
                    │  On-premises: VPN Gateway (192.168.0.0/16)                   │
                    └──────────────────────────────────────────────────────────────┘
```

### Requisitos de Performance

| Componente  | Normal         | Black Friday    |
| ----------- | -------------- | --------------- |
| API (VMSS)  | 2 instancias   | 20 instancias   |
| Web App     | 1 instancia S2 | 5 instancias S2 |
| Storage     | 10 TB imagens  | 10 TB (mesmo)   |
| Pedidos/dia | 50.000         | 500.000         |

---

## Secao 1 — Computacao (3 questoes)

### Q1.1 — VMSS Autoscale Rules (Design)

Thiago precisa configurar autoscale para o VMSS `ms-api-vmss` que hospeda a API de pedidos. Os requisitos sao:

- **Minimo:** 2 instancias (mesmo fora de horario comercial)
- **Maximo:** 20 instancias (limite de orcamento)
- **Scale out:** Adicionar 2 instancias quando a CPU media ultrapassar 75% por 5 minutos
- **Scale in:** Remover 1 instancia quando a CPU media ficar abaixo de 25% por 10 minutos
- **Cooldown:** 5 minutos entre acoes de scale

Responda:

1. Por que o periodo de **cooldown** e importante? O que pode acontecer sem ele?
2. Por que o **scale in** remove apenas 1 instancia (mais conservador) enquanto o **scale out** adiciona 2?
3. Thiago recebe um alerta de que durante a Black Friday, o VMSS escalou para 20 instancias mas a CPU continua acima de 75%. O que ele pode fazer **alem** de aumentar o limite maximo?

---

### Q1.2 — App Service Deployment Slots Swap (Multipla Escolha)

Juliana (lider de desenvolvimento) fez deploy de uma nova versao da webapp `ms-webapp` no slot **staging**. Apos testes, ela executa um **swap** do slot staging para production.

Qual afirmacao e **correta** sobre o processo de swap?

- **A)** O swap copia os arquivos do staging para production, causando downtime durante a copia
- **B)** O swap troca os **virtual IPs** dos slots, redirecionando trafego instantaneamente sem downtime
- **C)** O swap deleta o slot staging apos mover o conteudo para production
- **D)** O swap requer reinicio manual do App Service Plan apos a troca

---

### Q1.3 — ACI vs Container Apps vs AKS (Cenario)

Thiago precisa escolher o servico de container adequado para os **workers de processamento async** (`ms-workers`). Os requisitos sao:

- Processar mensagens de uma fila (Azure Queue Storage)
- Escalar automaticamente de 0 a 50 instancias baseado no tamanho da fila
- Sem necessidade de gerenciar infraestrutura de cluster
- Custo zero quando nao ha mensagens na fila (scale-to-zero)
- Sem requisitos de networking complexo (sem service mesh, sem ingress avancado)

Analise cada opcao e justifique a escolha:

1. **Azure Container Instances (ACI)** — E adequado? Por que sim/nao?
2. **Azure Container Apps** — E adequado? Por que sim/nao?
3. **Azure Kubernetes Service (AKS)** — E adequado? Por que sim/nao?
4. Qual e a escolha **mais adequada** para esse cenario?

---

## Secao 2 — Networking (3 questoes)

### Q2.1 — Application Gateway vs Load Balancer (Multipla Escolha)

Thiago precisa distribuir trafego para a webapp `ms-webapp`. O trafego e:

- 100% HTTP/HTTPS (web)
- Precisa de SSL termination
- Precisa de WAF (Web Application Firewall) para protecao contra ataques
- Path-based routing: `/api/*` vai para o VMSS, `/` vai para o App Service

Qual servico de balanceamento Thiago deve usar?

- **A)** Azure Load Balancer (Standard SKU)
- **B)** Azure Application Gateway (WAF v2 SKU)
- **C)** Azure Front Door
- **D)** Azure Traffic Manager

---

### Q2.2 — NSG + Application Gateway Subnet (Troubleshooting)

Thiago configurou o Application Gateway na subnet `AppGw` (10.0.1.0/24). Apos o deployment, o Application Gateway fica no status **Unhealthy** e nao consegue rotear trafego.

Thiago verifica que criou um NSG na subnet `AppGw` com a seguinte configuracao:

| Prioridade | Nome       | Direcao | Acao  | Porta | Origem | Destino |
| ---------- | ---------- | ------- | ----- | ----- | ------ | ------- |
| 100        | AllowHTTP  | Inbound | Allow | 80    | *      | *       |
| 110        | AllowHTTPS | Inbound | Allow | 443   | *      | *       |
| 200        | DenyAll    | Inbound | Deny  | *     | *      | *       |

1. Por que o Application Gateway esta Unhealthy, mesmo com HTTP/HTTPS permitidos?
2. Quais portas **adicionais** sao obrigatorias para a subnet do Application Gateway?
3. Qual source tag Thiago deve usar na regra NSG para permitir o trafego de health probes do Azure?

---

### Q2.3 — VNet Integration para App Service (Multipla Escolha)

Thiago precisa que o App Service `ms-webapp` acesse o SQL Database que esta dentro da VNet `ms-vnet` (sem exposicao publica). Ele configura **VNet Integration** no App Service.

Qual afirmacao e **correta** sobre VNet Integration?

- **A)** VNet Integration permite que recursos da VNet acessem o App Service atraves de um IP privado
- **B)** VNet Integration permite que o App Service acesse recursos dentro da VNet (trafego de saida), mas nao da um IP privado ao App Service
- **C)** VNet Integration substitui a necessidade de Private Endpoints para o App Service
- **D)** VNet Integration esta disponivel em todos os tiers do App Service, incluindo Free e Basic

---

## Secao 3 — Armazenamento (2 questoes)

### Q3.1 — Blob Tiers para Imagens de Produto (Multipla Escolha)

O storage account `msproductimages` armazena 10 TB de imagens de produtos. Thiago analisa os padroes de acesso:

- **70%** das imagens sao de produtos ativos e acessadas constantemente pelo website
- **20%** sao de produtos descontinuados ha menos de 6 meses (acessados raramente para referencia)
- **10%** sao de produtos descontinuados ha mais de 1 ano (quase nunca acessados)

Qual configuracao de tiers e **mais custo-efetiva**?

- **A)** Hot para 100% — simplicidade operacional
- **B)** Hot para 70%, Cool para 20%, Archive para 10%
- **C)** Hot para 70%, Cool para 20%, Cold para 10%
- **D)** Cool para 100% — economia maxima no armazenamento

---

### Q3.2 — AzCopy para Migracao em Massa (Design)

Thiago precisa migrar 10 TB de imagens de produtos do datacenter on-premises para o storage account `msproductimages`. A conexao VPN entre on-premises e Azure tem **100 Mbps** de bandwidth.

Responda:

1. Quanto tempo levaria a transferencia de 10 TB via VPN de 100 Mbps (calcule em horas)?
2. Thiago decide usar **AzCopy** para a transferencia. Quais parametros/flags sao essenciais para uma migracao eficiente dessa escala?
3. Se o tempo de transferencia for inaceitavel, qual servico offline do Azure Thiago poderia usar como alternativa? Qual o tamanho maximo suportado?

---

## Pontuacao

| Secao             | Questoes | Pontos por Questao | Total  |
| ----------------- | -------- | ------------------ | ------ |
| 1 — Computacao    | 3        | 5                  | 15     |
| 2 — Networking    | 3        | 6                  | 18     |
| 3 — Armazenamento | 2        | 6                  | 12     |
| **Total**         | **8**    | —                  | **45** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                                  |
| ----- | ------------ | ---------------------------------------------- |
| 38-45 | Excelente    | Avance para o Caso 5                           |
| 28-37 | Bom          | Revisar questoes erradas nos labs              |
| 18-27 | Regular      | Refazer blocos com dificuldade                 |
| < 18  | Insuficiente | Revisar labs 2-storage-compute e 1-iam-gov-net |
