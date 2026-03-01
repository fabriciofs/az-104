# Estudo de Caso 5 — Banco Horizonte Digital

**Dificuldade:** Dificil | **Dominios:** Todos os 5 dominios | **Questoes:** 10

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `caso5-banco-migracao-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: Banco Horizonte Digital

O **Banco Horizonte Digital** e um banco medio com sede em **Sao Paulo**, regulado pelo Banco Central do Brasil. Com 5.000 funcionarios distribuidos em 80 agencias e 3 datacenters on-premises, o banco esta executando uma migracao em fases para o Azure. A migracao e motivada pela necessidade de modernizar a infraestrutura, reduzir custos com datacenters e atender novas exigencias regulatorias de resiliencia operacional.

**Marcos Vieira**, CTO do banco, contratou **Camila Duarte** como **Azure Administrator Senior** para liderar a migracao. Os requisitos regulatorios do Banco Central (Resolucao 4.893) exigem:

- Dados de clientes devem permanecer no **Brasil** (soberania de dados)
- Criptografia em repouso com **chaves gerenciadas pelo banco** (CMK)
- Plano de **disaster recovery** com RTO < 4 horas e RPO < 1 hora
- Auditoria completa de todas as operacoes privilegiadas
- Segregacao de ambientes (producao, homologacao, desenvolvimento)

### Equipe

| Persona                    | Funcao                       | Acesso Necessario                           |
| -------------------------- | ---------------------------- | ------------------------------------------- |
| Camila Duarte (`bh-admin`) | Azure Administrator Senior   | Owner na subscription de Producao           |
| Marcos Vieira              | CTO                          | Visualizar tudo, aprovar mudancas criticas  |
| Grupo **CloudOps**         | Operacoes cloud (8 pessoas)  | Gerenciar VMs e networking em Producao      |
| Grupo **SecOps**           | Seguranca (4 pessoas)        | Monitorar compliance e alertas de seguranca |
| Grupo **DevTeam**          | Desenvolvimento (30 pessoas) | Contributor em Dev, Reader em Homologacao   |
| Grupo **AuditoriaInterna** | Auditoria do banco           | Somente leitura em tudo + logs detalhados   |

### Estrutura Organizacional

```
Root Management Group
    └── BancoHorizonte-MG
        │
        ├── BH-Prod-MG
        │   └── BH-Producao-Sub
        │       ├── bh-core-rg        (servicos centrais)
        │       ├── bh-app-rg         (aplicacoes bancarias)
        │       ├── bh-data-rg        (bancos de dados)
        │       └── bh-network-rg     (networking)
        │
        ├── BH-NonProd-MG
        │   ├── BH-Homologacao-Sub
        │   │   └── bh-hml-rg
        │   └── BH-Dev-Sub
        │       └── bh-dev-rg
        │
        └── BH-SharedServices-MG
            └── BH-Shared-Sub
                ├── bh-monitoring-rg   (Log Analytics, alerts)
                ├── bh-security-rg     (Key Vault, Defender)
                └── bh-backup-rg       (Recovery Services)
```

### Topologia de Rede

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AZURE                                                │
│                                                                              │
│  Brazil South (Primaria)                   South Central US (DR)             │
│  ┌──────────────────────────────────┐      ┌──────────────────────────┐      │
│  │  HubVNet (10.0.0.0/16)           │      │  DR-HubVNet              │      │
│  │  ┌────────────┐ ┌────────────┐   │      │  (10.100.0.0/16)         │      │
│  │  │GatewaySubnet│ │AzFirewall │   │      │  ┌────────────────────┐  │      │
│  │  │10.0.0.0/27 │ │10.0.2.0/24 │   │      │  │ DR VMs (standby)   │  │      │
│  │  └────────────┘ └────────────┘   │      │  └────────────────────┘  │      │
│  └────────────┬─────────────────────┘      └──────────────────────────┘      │
│               │ Peering                                                      │
│  ┌────────────┴─────────────────────┐                                        │
│  │  AppVNet (10.1.0.0/16)           │                                        │
│  │  ┌──────────────┐ ┌──────────┐   │                                        │
│  │  │ WebApp       │ │ API      │   │                                        │
│  │  │ 10.1.1.0/24  │ │10.1.2/24 │   │                                        │
│  │  └──────────────┘ └──────────┘   │                                        │
│  └────────────┬─────────────────────┘                                        │
│               │ Peering                                                      │
│  ┌────────────┴─────────────────────┐                                        │
│  │  DataVNet (10.2.0.0/16)          │                                        │
│  │  ┌──────────────┐ ┌──────────┐   │                                        │
│  │  │ SQL VMs      │ │ Storage  │   │                                        │
│  │  │ 10.2.1.0/24  │ │10.2.2/24 │   │                                        │
│  │  └──────────────┘ └──────────┘   │                                        │
│  └──────────────────────────────────┘                                        │
│                                                                              │
│  On-premises (Datacenter SP): 192.168.0.0/16                                 │
│  Conexao: ExpressRoute (1 Gbps) + VPN Gateway (backup)                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Requisitos de DR

| Componente               | Regiao Primaria | Regiao DR        | RTO | RPO           |
| ------------------------ | --------------- | ---------------- | --- | ------------- |
| VMs (aplicacoes)         | Brazil South    | South Central US | 4h  | 1h            |
| Storage (dados criticos) | Brazil South    | South Central US | 2h  | RPO near-zero |
| SQL VMs                  | Brazil South    | South Central US | 4h  | 1h            |

---

## Secao 1 — Identidade e Governanca (2 questoes)

### Q1.1 — Management Group + Policy Inheritance Bancario (Design)

Camila precisa configurar policies que atendam os requisitos regulatorios:

- **Policy 1:** Todos os recursos devem ser criados **apenas** em Brazil South (soberania de dados)
- **Policy 2:** Todos os Storage Accounts devem usar **criptografia com CMK** (Customer Managed Key)
- **Policy 3:** Todas as VMs devem ter **backup habilitado**
- **Policy 4:** Tags obrigatorias: `Environment`, `CostCenter`, `DataClassification`

Porem, a regiao de DR e **South Central US**, e recursos de DR precisam ser criados la.

Responda:

1. Em qual nivel da hierarquia de Management Groups Camila deve atribuir a Policy Initiative principal?
2. Como Camila resolve o conflito da Policy 1 (Allowed Locations = Brazil South) com a necessidade de recursos em South Central US para DR?
3. Se Camila aplicar a Policy Initiative no `BancoHorizonte-MG` e um futuro administrador tentar criar uma policy conflitante no nivel de subscription, qual policy prevalece?

---

### Q1.2 — Restricoes RBAC em Multiplos Escopos (Troubleshooting)

Camila configurou o seguinte RBAC:

| Grupo    | Role                        | Escopo             |
| -------- | --------------------------- | ------------------ |
| CloudOps | Virtual Machine Contributor | BH-Producao-Sub    |
| CloudOps | Network Contributor         | bh-network-rg      |
| DevTeam  | Contributor                 | BH-Dev-Sub         |
| DevTeam  | Reader                      | BH-Homologacao-Sub |
| SecOps   | Security Reader             | BancoHorizonte-MG  |

Um membro do **CloudOps** tenta criar um **VNet peering** entre a HubVNet (em `bh-network-rg`) e a AppVNet (em `bh-app-rg`). A operacao **falha** com erro de permissao.

1. Por que a operacao falha, se CloudOps tem Network Contributor em `bh-network-rg`?
2. Qual a permissao minima adicional que Camila deve conceder?
3. Um membro do **DevTeam** tenta deletar uma VM na subscription de Homologacao. A operacao falha. Por que?

---

## Secao 2 — Armazenamento (2 questoes)

### Q2.1 — Storage Encryption com CMK (Key Vault) (Multipla Escolha)

Camila precisa configurar o storage account `bhdatastorage` para usar criptografia com **Customer Managed Key (CMK)** armazenada no **Azure Key Vault**.

Apos configurar, ela recebe um erro: *"The key vault does not have the necessary permissions to perform wrap/unwrap operations"*.

Qual e a causa mais provavel?

- **A)** O Key Vault precisa ter soft-delete e purge protection habilitados
- **B)** O storage account precisa ter uma **System-Assigned Managed Identity** com permissoes de wrap/unwrap key no Key Vault
- **C)** CMK so funciona com Premium Storage Accounts
- **D)** O Key Vault e o Storage Account precisam estar na mesma regiao

---

### Q2.2 — Replicacao Cross-Region GRS/GZRS (Design)

Camila precisa configurar redundancia para 3 storage accounts criticos:

| Storage Account | Dados                   | Requisito de DR                       |
| --------------- | ----------------------- | ------------------------------------- |
| `bhdatastorage` | Dados de clientes (PII) | RPO near-zero, failover automatico    |
| `bhappstorage`  | Binarios de aplicacao   | RPO 15 min, failover manual aceitavel |
| `bhlogs`        | Logs de auditoria       | Retencao legal, imutavel              |

Responda:

1. Qual tipo de redundancia (LRS/ZRS/GRS/RA-GRS/GZRS/RA-GZRS) voce recomenda para **cada** storage account? Justifique.
2. Qual a diferenca entre **GRS** e **RA-GRS** em termos de acesso a regiao secundaria?
3. Quando um failover de storage account e iniciado (GRS), o que acontece com a URL do endpoint? A aplicacao precisa mudar a connection string?

---

## Secao 3 — Computacao (2 questoes)

### Q3.1 — VM Disaster Recovery com ASR (Cenario)

Camila configurou **Azure Site Recovery (ASR)** para replicar as VMs de producao de Brazil South para South Central US. O RPO configurado e de 1 hora.

Durante um teste de DR (test failover), as VMs sao criadas em South Central US com sucesso. Porem, ao testar a aplicacao bancaria, ela nao consegue conectar ao banco de dados SQL que tambem foi replicado.

A equipe investiga e descobre que:
- As VMs de DR foram criadas na VNet `DR-HubVNet` (10.100.0.0/16)
- O IP do SQL Server na producao e `10.2.1.4` — a aplicacao tem esse IP hardcoded na connection string
- Na regiao de DR, o SQL Server recebeu um IP diferente: `10.100.2.4`

1. Por que a aplicacao nao consegue conectar ao SQL Server apos o failover?
2. Quais abordagens Camila pode usar para resolver esse problema de forma **permanente** (nao apenas para esse teste)?
3. Qual a diferenca entre **Test Failover** e **Failover** no ASR? O test failover afeta a producao?

---

### Q3.2 — VMSS Update Policy Rolling vs Manual (Multipla Escolha)

Camila configurou um VMSS com 10 instancias para hospedar a API bancaria. Ela precisa aplicar uma atualizacao de imagem do SO (security patch) sem causar indisponibilidade.

Qual **upgrade policy** permite que a atualizacao seja aplicada em lotes, mantendo um numero minimo de instancias saudaveis durante o processo?

- **A)** Manual — requer restart individual de cada instancia
- **B)** Automatic — atualiza todas as instancias simultaneamente
- **C)** Rolling — atualiza em lotes configuraveis, com pausa entre lotes e rollback em caso de falha
- **D)** Blue-Green — cria um VMSS novo e troca o trafego de uma vez

---

## Secao 4 — Networking (2 questoes)

### Q4.1 — Hub-Spoke com NVA e Forced Tunneling (Design)

Camila configurou a topologia hub-spoke com Azure Firewall no Hub. O regulatorio bancario exige que **todo trafego de internet** das VMs passe pelo datacenter on-premises para inspecao (forced tunneling via ExpressRoute).

Requisitos:
- VMs em AppVNet e DataVNet **nao** devem acessar a internet diretamente
- Todo trafego com destino a internet deve ir via ExpressRoute → datacenter on-premises → proxy corporativo → internet
- VMs precisam continuar acessando servicos PaaS do Azure (Storage, Key Vault) via Private Endpoints

Responda:

1. Como Camila configura **forced tunneling** para direcionar trafego de internet para o on-premises?
2. Com forced tunneling ativo, as VMs ainda conseguem acessar Azure PaaS services (ex: Key Vault) via Private Endpoints? Explique.
3. Qual problema pode ocorrer com o **Azure Firewall** quando forced tunneling esta habilitado? Como resolver?

---

### Q4.2 — ExpressRoute vs VPN Gateway (Troubleshooting)

Camila configurou a conectividade hibrida:

- **ExpressRoute:** Circuito de 1 Gbps (Microsoft Peering) — conexao primaria
- **VPN Gateway:** Site-to-site VPN como backup — failover automatico

O ExpressRoute esta funcionando normalmente. Porem, quando Camila testa o failover desconectando o ExpressRoute, a VPN Gateway **nao assume automaticamente** e a conectividade com on-premises cai.

1. Por que a VPN Gateway nao assumiu como failover automatico?
2. O que Camila precisa configurar para que o failover aconteca automaticamente?
3. Qual a diferenca entre **ExpressRoute Private Peering** e **Microsoft Peering**? Qual deles Camila precisa para acessar Azure PaaS services como Storage e Key Vault?

---

## Secao 5 — Monitoramento (2 questoes)

### Q5.1 — Azure Monitor Alerting Multi-Recurso (Design)

Camila precisa configurar um sistema de alertas abrangente para o ambiente bancario:

| Alerta                  | Condicao                                       | Severidade      | Destinatario                            |
| ----------------------- | ---------------------------------------------- | --------------- | --------------------------------------- |
| CPU critica             | CPU > 95% por 5 min em qualquer VM de producao | Sev 0 (Critico) | CloudOps (SMS + Email) + SecOps (Email) |
| Disk space              | Disco > 90% em qualquer VM                     | Sev 1 (Erro)    | CloudOps (Email)                        |
| Key Vault access denied | Qualquer acesso negado ao Key Vault            | Sev 0 (Critico) | SecOps (SMS + Email) + Camila (Email)   |
| Policy non-compliance   | Novo recurso non-compliant detectado           | Sev 2 (Warning) | SecOps (Email)                          |

Responda:

1. Quantos **Action Groups** Camila deve criar? Quais sao eles e quem recebe em cada um?
2. Para o alerta de "CPU critica em qualquer VM de producao", Camila pode criar **um unico alert rule** que monitore todas as VMs? Como?
3. O alerta de "Key Vault access denied" e baseado em **metrica** ou em **log**? Qual tabela/metrica seria usada?

---

### Q5.2 — KQL Query para Auditoria de Seguranca (Cenario)

O departamento de compliance do banco solicita a Camila os seguintes relatorios de auditoria:

**Relatorio 1:** Todas as operacoes de **criacao ou delecao de usuarios** no Microsoft Entra ID nos ultimos 30 dias, incluindo quem fez a operacao e quando.

**Relatorio 2:** Todas as tentativas de acesso a **Key Vaults** que foram **negadas** nos ultimos 7 dias, agrupadas por IP de origem.

Responda:

1. Escreva a query KQL para o **Relatorio 1** (use a tabela `AuditLogs`).
2. Escreva a query KQL para o **Relatorio 2** (use a tabela `AzureDiagnostics` com category `AuditEvent`).
3. Camila quer agendar esses relatorios para execucao **semanal automatica** e enviar por email ao departamento de compliance. Qual recurso do Azure Monitor ela deve usar?

---

## Pontuacao

| Secao                       | Questoes | Pontos por Questao | Total  |
| --------------------------- | -------- | ------------------ | ------ |
| 1 — Identidade e Governanca | 2        | 6                  | 12     |
| 2 — Armazenamento           | 2        | 6                  | 12     |
| 3 — Computacao              | 2        | 6                  | 12     |
| 4 — Networking              | 2        | 7                  | 14     |
| 5 — Monitoramento           | 2        | 7                  | 14     |
| **Total**                   | **10**   | —                  | **64** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                                    |
| ----- | ------------ | ------------------------------------------------ |
| 55-64 | Excelente    | Pronto para o exame                              |
| 42-54 | Bom          | Revisar questoes erradas — foco nos gotchas      |
| 28-41 | Regular      | Refazer labs dos dominios com mais erros         |
| < 28  | Insuficiente | Revisar todos os labs e simulados antes do exame |
