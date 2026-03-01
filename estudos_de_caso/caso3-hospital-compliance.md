# Estudo de Caso 3 — Rede VidaSaude Hospitais

**Dificuldade:** Medio | **Dominios:** D1 Governance + D4 Networking + D2 Storage | **Questoes:** 8

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `caso3-hospital-compliance-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: Rede VidaSaude Hospitais

A **Rede VidaSaude** opera 4 hospitais em **Brasilia** e regiao, com 3.000 funcionarios (medicos, enfermeiros, administrativo e TI). A rede esta migrando seus sistemas para o Azure, mas enfrenta requisitos rigorosos de **compliance da saude** (LGPD e regulamentacoes do CFM) para proteger prontuarios eletronicos.

**Dr. Ricardo Mendes**, CISO da VidaSaude, contratou **Fernanda Rocha** como **Azure Administrator** para implementar a infraestrutura cloud. Os requisitos de compliance exigem:

- Prontuarios eletronicos devem ser **imutaveis** (nao podem ser alterados ou deletados)
- Acesso a dados de pacientes deve ser restrito e auditavel
- Rede segmentada para isolar sistemas criticos
- Auditores externos precisam de acesso controlado

### Equipe

| Persona                     | Funcao                                       | Acesso Necessario                              |
| --------------------------- | -------------------------------------------- | ---------------------------------------------- |
| Fernanda Rocha (`vs-admin`) | Azure Administrator                          | Owner na subscription                          |
| Dr. Ricardo Mendes          | CISO                                         | Visualizar compliance e auditorias             |
| Grupo **MedTech**           | TI dos hospitais (12 pessoas)                | Gerenciar VMs e storage dos sistemas medicos   |
| Grupo **Auditoria**         | Auditores externos                           | Somente leitura em recursos e logs especificos |
| Grupo **AdminHospital**     | Administradores de cada hospital (4 pessoas) | Gerenciar recursos do proprio hospital         |

### Estrutura Organizacional

```
                    ┌────────────────────────────────────────┐
                    │    Management Group: VidaSaude-MG      │
                    │                                        │
                    │  ┌─────────────────────────────────┐   │
                    │  │  Subscription: VidaSaude-Prod   │   │
                    │  │                                 │   │
                    │  │   ┌──────────┐  ┌──────────┐    │   │
                    │  │   │ RG:      │  │ RG:      │    │   │
                    │  │   │ vs-hub-rg│  │ vs-hosp1 │    │   │
                    │  │   │ (rede    │  │ -rg      │    │   │
                    │  │   │ central) │  │          │    │   │
                    │  │   └──────────┘  └──────────┘    │   │
                    │  │                                 │   │
                    │  │   ┌──────────┐  ┌──────────┐    │   │
                    │  │   │ RG:      │  │ RG:      │    │   │
                    │  │   │ vs-hosp2 │  │ vs-hosp3 │    │   │
                    │  │   │ -rg      │  │ -rg      │    │   │
                    │  │   └──────────┘  └──────────┘    │   │
                    │  │                                 │   │
                    │  │   ┌──────────┐  ┌──────────┐    │   │
                    │  │   │ RG:      │  │ RG:      │    │   │
                    │  │   │ vs-hosp4 │  │ vs-shared│    │   │
                    │  │   │ -rg      │  │ -rg      │    │   │
                    │  │   └──────────┘  └──────────┘    │   │
                    │  └─────────────────────────────────┘   │
                    └────────────────────────────────────────┘
```

### Topologia de Rede

```
                    ┌──────────────────────────────────────────────────┐
                    │              AZURE — Brazil South                │
                    │                                                  │
                    │  ┌────────────────────────────────────────────┐  │
                    │  │         HubVNet (10.0.0.0/16)              │  │
                    │  │                                            │  │
                    │  │  ┌───────────────┐  ┌──────────────────┐   │  │
                    │  │  │  GatewaySubnet│  │  SharedServices  │   │  │
                    │  │  │ 10.0.0.0/27   │  │ 10.0.1.0/24      │   │  │
                    │  │  └───────────────┘  └──────────────────┘   │  │
                    │  │                                            │  │
                    │  │  ┌──────────────────────────────────────┐  │  │
                    │  │  │  AzureFirewallSubnet 10.0.2.0/24     │  │  │
                    │  │  └──────────────────────────────────────┘  │  │
                    │  └───────────────────┬────────────────────────┘  │
                    │            Peering   │   Peering                 │
                    │     ┌────────────────┼──────────────┐            │
                    │     │                │              │            │
                    │  ┌──┴───────┐  ┌─────┴─────┐  ┌─────┴─────┐      │
                    │  │Hosp1VNet │  │Hosp2VNet  │  │Hosp3VNet  │      │
                    │  │10.1.0/16 │  │10.2.0/16  │  │10.3.0/16  │      │
                    │  │          │  │           │  │           │      │
                    │  │┌────────┐│  │┌─────────┐│  │┌─────────┐│      │
                    │  ││App     ││  ││App      ││  ││App      ││      │
                    │  ││10.1.1/24│  ││10.2.1/24││  ││10.3.1/24││      │
                    │  │└────────┘│  │└─────────┘│  │└─────────┘│      │
                    │  │┌────────┐│  │┌─────────┐│  │┌─────────┐│      │
                    │  ││Data    ││  ││Data     ││  ││Data     ││      │
                    │  ││10.1.2/24│  ││10.2.2/24││  ││10.3.2/24││      │
                    │  │└────────┘│  │└─────────┘│  │└─────────┘│      │
                    │  └──────────┘  └───────────┘  └───────────┘      │
                    │                                                  │
                    │  Storage: vsprontuarios (Private Endpoint)       │
                    └──────────────────────────────────────────────────┘
```

---

## Secao 1 — Governanca (3 questoes)

### Q1.1 — Policy Initiative vs Policies Individuais (Multipla Escolha)

Fernanda precisa aplicar as seguintes regras de compliance em toda a subscription:

- Todos os recursos devem ter a tag `Hospital`
- Todos os recursos devem ter a tag `DataClassification` (valores: `Public`, `Internal`, `Confidential`, `Restricted`)
- Storage Accounts devem ter HTTPS obrigatorio
- Storage Accounts devem usar TLS 1.2 minimo
- VMs nao podem usar discos nao gerenciados

Fernanda esta decidindo entre criar 5 policies individuais ou agrupá-las em uma **Policy Initiative**.

Qual e a principal vantagem de usar uma Policy Initiative nesse cenario?

- **A)** Initiatives permitem efeitos diferentes (Deny, Audit) na mesma initiative; policies individuais nao
- **B)** Initiatives permitem uma unica assignment com compliance tracking unificado, em vez de 5 assignments separadas
- **C)** Initiatives sao avaliadas mais rapido pelo Azure Resource Manager
- **D)** Initiatives podem ser atribuidas em Management Groups; policies individuais so podem ser atribuidas em subscriptions

---

### Q1.2 — Management Group Hierarchy Multi-Hospital (Design)

Fernanda precisa projetar a hierarquia de Management Groups para a VidaSaude. Os requisitos sao:

- Cada hospital deve ter autonomia para gerenciar seus proprios recursos
- Policies de seguranca (HTTPS obrigatorio, tags, etc.) devem ser aplicadas em todos os hospitais uniformemente
- No futuro, a VidaSaude pode adquirir novos hospitais que precisarao herdar as mesmas policies automaticamente
- Auditores devem ter acesso a todos os hospitais, mas administradores de cada hospital so ao seu proprio

Responda:

1. Desenhe (ou descreva) uma hierarquia de Management Groups que atenda esses requisitos
2. Em qual nivel da hierarquia Fernanda deve atribuir a Policy Initiative de compliance?
3. Em qual nivel Fernanda deve atribuir o role **Reader** para o grupo Auditoria?
4. Como Fernanda garante que cada membro do grupo AdminHospital so veja recursos do seu hospital?

---

### Q1.3 — Custom RBAC Role para Auditor (Troubleshooting)

Dr. Ricardo Mendes quer que os auditores possam:
- Ler todas as configuracoes de recursos (VMs, Storage, Network)
- Ler logs de atividade (Activity Log)
- **NAO** podem ler o conteudo dos blobs de prontuarios (data plane)
- **NAO** podem modificar nenhum recurso

Fernanda atribui o role built-in **Reader** ao grupo Auditoria no escopo da subscription. Os auditores reclamam que conseguem ver os recursos mas **nao conseguem acessar os Activity Logs detalhados** (precisam ver quem fez cada operacao).

1. Por que o role Reader nao e suficiente para acessar Activity Logs detalhados?
2. Fernanda deve criar um custom role. Liste as **actions** (permissions) minimas que esse custom role deve ter.
3. Existe risco de que o role Reader permita acesso ao conteudo dos blobs de prontuarios? Explique a diferenca entre management plane e data plane nesse contexto.

---

## Secao 2 — Networking (3 questoes)

### Q2.1 — Private Endpoint DNS Resolution (Multipla Escolha)

Fernanda configurou um **Private Endpoint** para o storage account `vsprontuarios` na subnet SharedServices da HubVNet. O Private Endpoint recebeu o IP privado `10.0.1.10`.

Uma VM na Hosp1VNet tenta acessar `vsprontuarios.blob.core.windows.net` e a conexao vai para o **IP publico** do storage account em vez do Private Endpoint.

O que Fernanda precisa configurar para que a resolucao DNS aponte para o IP privado?

- **A)** Criar um registro A manual no servidor DNS on-premises
- **B)** Criar uma Azure Private DNS Zone `privatelink.blob.core.windows.net` com VNet Links para todas as VNets
- **C)** Configurar o firewall do storage account para bloquear acesso publico
- **D)** Alterar o DNS das VMs para apontar para o IP `10.0.1.10` diretamente

---

### Q2.2 — Hub-Spoke Network Design e Peering (Design)

Fernanda implementou a topologia hub-spoke mostrada no diagrama. Os requisitos sao:

- Todo trafego entre hospitais deve passar pelo Hub (Azure Firewall para inspecao)
- Hospital 1 precisa acessar o storage account `vsprontuarios` via Private Endpoint no Hub
- Hospitais nao devem se comunicar diretamente entre si (isolamento)

Responda:

1. Fernanda configurou peering entre HubVNet e Hosp1VNet. Quais opcoes de peering ela deve habilitar no **lado do Hub** e no **lado do spoke** para que o trafego de Hosp1 passe pelo Azure Firewall?
2. Uma VM na Hosp2VNet tenta acessar uma VM na Hosp1VNet e o trafego flui diretamente (sem passar pelo Firewall). O que pode estar errado?
3. Como Fernanda pode forcar todo trafego spoke-to-spoke a passar pelo Azure Firewall no Hub?

---

### Q2.3 — NSG Rules para Isolamento de Subnets (Cenario)

Dentro de cada hospital VNet, Fernanda precisa isolar a subnet **App** da subnet **Data**:

- A subnet **App** (onde ficam os web servers) pode acessar a subnet **Data** (onde ficam os bancos de dados) apenas na **porta 1433** (SQL Server)
- A subnet **Data** nao pode iniciar conexoes para a subnet **App**
- Ambas as subnets podem acessar a internet para atualizacoes
- Nenhuma outra porta deve estar aberta entre as subnets

Fernanda cria o seguinte NSG na subnet **Data** do Hospital 1:

| Prioridade | Nome           | Direcao | Acao  | Porta | Origem      | Destino     |
| ---------- | -------------- | ------- | ----- | ----- | ----------- | ----------- |
| 100        | AllowSQL       | Inbound | Allow | 1433  | 10.1.1.0/24 | 10.1.2.0/24 |
| 200        | DenyAllInbound | Inbound | Deny  | *     | *           | *           |

1. Essa configuracao de NSG atende os requisitos? Se nao, o que esta faltando?
2. A regra `DenyAllInbound` na prioridade 200 vai bloquear as **respostas** de trafego que a subnet Data iniciou para a internet (ex: atualizacoes)? Explique.
3. Se Fernanda quiser tambem bloquear que a subnet Data **inicie** conexoes para a subnet App, onde e como ela deve configurar isso?

---

## Secao 3 — Armazenamento (2 questoes)

### Q3.1 — Immutable Storage (WORM) para Prontuarios (Multipla Escolha)

A regulamentacao exige que prontuarios eletronicos sejam armazenados de forma **imutavel** — uma vez gravados, nao podem ser alterados nem deletados por um periodo minimo de 10 anos.

Fernanda configura uma **immutability policy** no container `prontuarios` do storage account `vsprontuarios` com retencao de 10 anos (3.650 dias).

Apos configurar, um medico grava um prontuario e percebe que cometeu um erro no texto. Ele tenta atualizar o blob e recebe erro.

Qual tipo de immutability policy Fernanda deveria ter usado para permitir **adicao** de novos blobs mas **impedir alteracao e delecao** dos existentes?

- **A)** Time-based retention policy no estado **Locked**
- **B)** Time-based retention policy no estado **Unlocked**
- **C)** Legal hold
- **D)** Todas as opcoes acima impedem alteracao e delecao igualmente

---

### Q3.2 — Storage Firewall + Private Endpoint (Troubleshooting)

Fernanda configurou o storage account `vsprontuarios` com:

- **Private Endpoint** na subnet SharedServices da HubVNet (IP: 10.0.1.10)
- **Firewall do storage:** "Allow access from Selected networks" com apenas a VNet HubVNet adicionada
- **Private DNS Zone** `privatelink.blob.core.windows.net` vinculada a todas as VNets

Uma VM na **Hosp1VNet** (10.1.1.4) resolve `vsprontuarios.blob.core.windows.net` para o IP privado `10.0.1.10` corretamente. Porem, ao tentar acessar os blobs, recebe **403 Forbidden**.

1. Por que a VM recebe 403 mesmo resolvendo para o IP privado via Private Endpoint?
2. O que Fernanda precisa alterar na configuracao de firewall do storage account?
3. Se Fernanda mudar o firewall para "Allow access from All networks", o Private Endpoint ainda funciona? Qual o impacto na seguranca?

---

## Pontuacao

| Secao             | Questoes | Pontos por Questao | Total  |
| ----------------- | -------- | ------------------ | ------ |
| 1 — Governanca    | 3        | 5                  | 15     |
| 2 — Networking    | 3        | 6                  | 18     |
| 3 — Armazenamento | 2        | 6                  | 12     |
| **Total**         | **8**    | —                  | **45** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                                  |
| ----- | ------------ | ---------------------------------------------- |
| 38-45 | Excelente    | Avance para o Caso 4                           |
| 28-37 | Bom          | Revisar questoes erradas nos labs              |
| 18-27 | Regular      | Refazer blocos com dificuldade                 |
| < 18  | Insuficiente | Revisar labs 1-iam-gov-net e 2-storage-compute |
