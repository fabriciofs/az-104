# Simulado AZ-104 — Backup, Recovery e Monitoramento

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `simulado-backup-monitoring-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta (salvo indicacao contraria)
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: MedCloud Health

A **MedCloud Health** e uma empresa de healthcare de medio porte que gerencia prontuarios eletronicos e sistemas de telemedicina para clinicas e hospitais. Com sede em Brasilia, a MedCloud migrou recentemente para o Azure, escolhendo **East US** como regiao primaria e **West Europe** como regiao de DR (requisito de compliance).

Rafael Costa, Azure Administrator da MedCloud, precisa configurar backup, disaster recovery e monitoramento de todos os recursos Azure. A empresa esta sujeita a regulamentacoes de saude (LGPD, HIPAA-like) que exigem retencao de dados por 7 anos e RPO maximo de 1 hora para sistemas criticos.

A MedCloud tem 150 funcionarios, 5 clinicas conectadas via VPN, e 3 aplicacoes criticas (prontuario eletronico, sistema de agendamento, portal do paciente).

---

## Personas

| Persona                   | Funcao              | Acesso Necessario                       |
| ------------------------- | ------------------- | --------------------------------------- |
| Rafael Costa (`mc-admin`) | Azure Administrator | Full access a subscription              |
| Dr. Patricia Almeida      | Diretora Clinica    | Reports de compliance e disponibilidade |
| Grupo **Time SRE**        | Equipe de 4         | Monitoramento e resposta a incidentes   |
| Grupo **Time Compliance** | Equipe de 2         | Auditoria e retencao de dados           |

---

## Arquitetura de Backup, DR e Monitoramento

```
            ┌───────────────────────────────────────────────────────────────────┐
            │                    AZURE — East US (Primaria)                     │
            │                                                                   │
            │  ┌──────────────────────────────────────┐                         │
            │  │     Recovery Services Vault          │                         │
            │  │     mc-rsv                           │                         │
            │  │                                      │                         │
            │  │  ┌────────────┐  ┌───────────────┐   │                         │
            │  │  │ VM Backup  │  │ File Share    │   │                         │
            │  │  │ Policy:    │  │ Backup Policy │   │                         │
            │  │  │ Daily 30d  │  │ Daily 30d     │   │                         │
            │  │  │ Weekly 12w │  │ Yearly 7y     │   │                         │
            │  │  │ Monthly 12m│  └───────────────┘   │                         │
            │  │  │ Yearly 7y  │                      │                         │
            │  │  └────────────┘                      │                         │
            │  │  [GRS + Cross Region Restore]        │                         │
            │  └──────────────────────────────────────┘                         │
            │                                                                   │
            │  ┌──────────────────────────────────────┐                         │
            │  │     Azure Site Recovery              │                         │
            │  │     Replicacao: East US → West Europe│                         │
            │  │     RPO: 1 hora | RTO: 4 horas       │                         │
            │  │                                      │                         │
            │  │  ┌──────────┐ ┌──────────┐ ┌──────┐  │                         │
            │  │  │Prontuario│ │Agendament│ │Portal│  │                         │
            │  │  │  VM-01   │ │  VM-02   │ │VM-03 │  │                         │
            │  │  └──────────┘ └──────────┘ └──────┘  │                         │
            │  └──────────────────────────────────────┘                         │
            │                                                                   │
            │  ┌──────────────────────────────────────┐                         │
            │  │     Azure Monitor                    │                         │
            │  │                                      │                         │
            │  │  ┌──────────────┐ ┌──────────────┐   │                         │
            │  │  │ Metric Alerts│ │ Log Alerts   │   │                         │
            │  │  │ CPU > 80%    │ │ Error Logs   │   │                         │
            │  │  └──────────────┘ └──────────────┘   │                         │
            │  │                                      │                         │
            │  │  ┌──────────────┐ ┌──────────────┐   │                         │
            │  │  │ Action Groups│ │ Dashboards   │   │                         │
            │  │  │ SRE: Email+  │ │ Dr.Patricia  │   │                         │
            │  │  │      SMS     │ │ Compliance   │   │                         │
            │  │  │ ServiceNow   │ │ View         │   │                         │
            │  │  └──────────────┘ └──────────────┘   │                         │
            │  └──────────────────────────────────────┘                         │
            │                                                                   │
            │  ┌──────────────────────────────────────┐                         │
            │  │     Log Analytics Workspace          │                         │
            │  │     mc-law                           │                         │
            │  │                                      │                         │
            │  │  ┌──────────┐ ┌──────────┐ ┌──────┐  │                         │
            │  │  │  VM-01   │ │  VM-02   │ │VM-03 │  │  ← Azure Monitor Agent  │
            │  │  │ connected│ │ connected│ │connec│  │                         │
            │  │  └──────────┘ └──────────┘ └──────┘  │                         │
            │  │                                      │                         │
            │  │  VM Insights | Network Watcher       │                         │
            │  └──────────────────────────────────────┘                         │
            │                                                                   │
            └───────────────────────────┬───────────────────────────────────────┘
                                        │
                              ASR Replication
                                        │
            ┌───────────────────────────┴───────────────┐
            │         AZURE — West Europe (DR)          │
            │                                           │
            │  ┌─────────────────────────────────────┐  │
            │  │     Recovery Services Vault (DR)    │  │
            │  │     mc-rsv-westeurope               │  │
            │  │                                     │  │
            │  │  ┌──────────┐ ┌──────────┐ ┌──────┐ │  │
            │  │  │Prontuario│ │Agendament│ │Portal│ │  │
            │  │  │ (replica)│ │ (replica)│ │(repl)│ │  │
            │  │  └──────────┘ └──────────┘ └──────┘ │  │
            │  └─────────────────────────────────────┘  │
            │                                           │
            └───────────────────────────────────────────┘
```

---

## Secao 1 — Backup e Protecao de Dados (6 questoes)

### Q1.1 — Recovery Services Vault vs Backup Vault (Multipla Escolha)

Rafael precisa fazer backup de VMs Azure e Azure File Shares. Ele esta decidindo qual tipo de vault utilizar para centralizar a protecao desses recursos.

Qual tipo de vault ele deve usar?

- **A)** Recovery Services Vault — suporta ambos os workloads
- **B)** Backup Vault — e o vault mais recente e suporta todos os workloads
- **C)** Key Vault — centraliza protecao de dados e chaves
- **D)** Ambos A e B — VMs no Recovery Services Vault e File Shares no Backup Vault

---

### Q1.2 — Backup Policy Retention (Design)

A MedCloud precisa configurar uma politica de backup que atenda aos seguintes requisitos de retencao:

- **Backups diarios** retidos por 30 dias
- **Backups semanais** retidos por 12 semanas
- **Backups mensais** retidos por 12 meses
- **Backups anuais** retidos por 7 anos (requisito regulatorio)

Responda:

1. Onde Rafael configura essa politica (em qual recurso)?
2. E possivel ter todos esses niveis de retencao em uma unica policy? Explique.
3. Qual o impacto no custo de armazenamento ao manter backups anuais por 7 anos? Que estrategia Rafael pode usar para otimizar custos?

---

### Q1.3 — Soft Delete para VMs (Multipla Escolha)

Rafael deletou acidentalmente um backup item de VM no Recovery Services Vault. Ele percebeu o erro minutos depois e precisa recuperar os dados.

Por quantos dias o Azure mantem os dados de backup em **soft delete** por padrao?

- **A)** 7 dias
- **B)** 14 dias
- **C)** 30 dias
- **D)** 90 dias

---

### Q1.4 — File Share Backup vs Snapshot (Cenario)

Rafael precisa restaurar um unico arquivo de um Azure File Share de 500 GB. O file share tem backup configurado no Recovery Services Vault. O time reportou que um arquivo critico de configuracao (`/config/app-settings.json`) foi sobrescrito com dados incorretos ha 2 horas.

1. Qual metodo e mais eficiente para restaurar apenas 1 arquivo sem afetar o restante do file share?
2. O Azure Backup de File Shares usa snapshots internamente? Explique como funciona.
3. Se Rafael escolher "restaurar para local original", o que acontece com o arquivo atual que esta incorreto?

---

### Q1.5 — Blob Versioning vs Soft Delete (Multipla Escolha)

Um membro do Time SRE sobrescreveu um blob critico (`/data/patient-records.json`) com dados incorretos em um Storage Account. O Storage Account tem **soft delete** habilitado (14 dias de retencao) mas **versioning** nao esta habilitado.

O blob com a versao anterior (dados corretos) pode ser recuperado?

- **A)** Sim, soft delete protege contra sobrescrita e mantem a versao anterior
- **B)** Nao, sem versioning a versao anterior foi perdida — soft delete so protege contra delecao, nao sobrescrita
- **C)** Sim, usando o snapshot automatico gerado pelo Azure
- **D)** Depende do tier do blob (Hot, Cool ou Archive)

---

### Q1.6 — Cross-Region Restore (Multipla Escolha)

A MedCloud precisa garantir que, em caso de desastre total na regiao primaria (East US), os backups de VMs possam ser restaurados na regiao secundaria (West Europe).

Qual feature deve ser habilitada no Recovery Services Vault para permitir isso?

- **A)** Geo-Redundant Storage (GRS) — suficiente por si so
- **B)** Cross Region Restore (CRR) — requer GRS e habilita restauracao na regiao secundaria
- **C)** Zone Redundant Storage (ZRS) — replica entre availability zones
- **D)** Locally Redundant Storage (LRS) com replicacao manual

---

## Secao 2 — Azure Site Recovery (4 questoes)

### Q2.1 — RPO vs RTO (Design)

A diretoria da MedCloud definiu os seguintes objetivos de recuperacao para o sistema de prontuario eletronico:

- **RPO:** 1 hora
- **RTO:** 4 horas

Responda:

1. O que significa RPO de 1 hora em termos praticos? Qual o impacto para os dados dos pacientes?
2. O que significa RTO de 4 horas em termos praticos? Qual o impacto para as clinicas conectadas?
3. Qual feature do Azure ajuda a atingir esses objetivos? Como ela garante o RPO definido?

---

### Q2.2 — Test Failover (Multipla Escolha)

Rafael executa um **test failover** no Azure Site Recovery para validar o plano de DR da MedCloud. A equipe de compliance exige que esse teste seja feito mensalmente sem impactar a producao.

O que acontece com a VM de producao durante o test failover?

- **A)** E desligada automaticamente para liberar recursos
- **B)** Continua rodando normalmente — o test failover nao afeta a producao
- **C)** E pausada temporariamente enquanto o teste executa
- **D)** E replicada novamente do zero apos o teste

---

### Q2.3 — Failover Types (Cenario)

A regiao primaria (East US) sofreu uma falha total inesperada. O sistema de prontuario eletronico esta fora do ar e as clinicas nao conseguem acessar os dados dos pacientes. Rafael precisa ativar o plano de DR imediatamente.

1. Que tipo de failover Rafael deve usar nessa situacao? Qual a diferenca entre **planned failover** e **unplanned (forced) failover**?
2. O que acontece se a replicacao nao estava completamente sincronizada no momento da falha? Pode haver perda de dados?
3. Apos a regiao primaria ser restaurada, quais passos Rafael precisa executar para fazer o **failback** (retornar para East US)?

---

### Q2.4 — Replication Policy (Multipla Escolha)

Rafael configura o Azure Site Recovery com a seguinte replication policy:

- **Recovery point retention:** 24 horas
- **App-consistent snapshot frequency:** 4 horas

Quantos recovery points **app-consistent** serao mantidos simultaneamente?

- **A)** 4
- **B)** 6
- **C)** 24
- **D)** Depende do tamanho da VM

---

## Secao 3 — Azure Monitor e Alertas (4 questoes)

### Q3.1 — Metric Alert vs Log Alert (Multipla Escolha)

Rafael precisa configurar um alerta que dispare quando a **CPU de uma VM** ultrapassar **80%** por mais de **5 minutos consecutivos**. O alerta deve notificar o Time SRE imediatamente.

Qual tipo de alert rule Rafael deve criar?

- **A)** Metric alert — avalia metricas de plataforma em intervalos regulares
- **B)** Log alert — executa query KQL no Log Analytics
- **C)** Activity log alert — monitora operacoes no plano de controle
- **D)** Smart detection alert — usa machine learning para detectar anomalias

---

### Q3.2 — Action Group Configuration (Design)

A MedCloud precisa configurar notificacoes para diferentes stakeholders quando alertas forem disparados:

1. **Time SRE:** Notificacao por email **e** SMS (resposta imediata)
2. **Dr. Patricia Almeida:** Notificacao apenas por email (visibilidade)
3. **ServiceNow:** Abertura automatica de ticket (rastreamento)

Responda:

1. Rafael deve criar um unico Action Group ou multiplos? Justifique.
2. Como configurar a integracao com ServiceNow no Action Group?
3. Se Rafael quiser que alertas criticos notifiquem por SMS mas alertas de warning apenas por email, como estruturar isso?

---

### Q3.3 — Diagnostic Settings (Cenario)

Rafael habilitou **Diagnostic Settings** para as 3 VMs criticas da MedCloud, configurando o envio de logs para o Log Analytics Workspace `mc-law`. Apos 1 hora, ele executa uma query KQL e nao encontra nenhum log das VMs.

Identifique as possiveis causas:

1. Qual e a causa mais provavel relacionada ao agente de monitoramento?
2. O Diagnostic Settings sozinho e suficiente para coletar logs de dentro da VM (syslog, event logs)? Explique.
3. Que outra configuracao Rafael pode ter esquecido no Log Analytics Workspace?

---

### Q3.4 — Dashboard Sharing (Multipla Escolha)

Rafael criou um dashboard personalizado no Azure Portal com metricas de CPU, memoria e disco das 3 VMs criticas. Ele precisa compartilhar esse dashboard com o **Time SRE** para que eles possam visualizar os dados mas **nao** modificar o layout.

Qual permissao minima Rafael deve conceder no dashboard?

- **A)** Reader — permite visualizar o dashboard e os dados subjacentes
- **B)** Contributor — necessario para acessar dashboards compartilhados
- **C)** Owner — unico role que permite visualizar dashboards de outros usuarios
- **D)** Dashboard Reader — role especifico para leitura de dashboards

---

## Secao 4 — Log Analytics e Insights (4 questoes)

### Q4.1 — KQL Query (Multipla Escolha)

Rafael precisa identificar os **10 eventos de maior consumo de CPU** nos ultimos **30 minutos** para investigar um problema de performance reportado pelo Time SRE.

Qual query KQL retorna o resultado correto?

- **A)** `Perf | where TimeGenerated > ago(30m) | where CounterName == "% Processor Time" | top 10 by CounterValue`
- **B)** `Event | where TimeGenerated > ago(30m) | where CPU > 80 | take 10`
- **C)** `Heartbeat | where TimeGenerated > ago(30m) | summarize count() by Computer | top 10`
- **D)** `InsightsMetrics | where Name == "CPU" | top 10 by Val`

---

### Q4.2 — Azure Monitor Agent vs Legacy (Multipla Escolha)

Rafael precisa instalar um agente de monitoramento nas 3 VMs criticas da MedCloud para coletar metricas e logs. Ele encontrou documentacao mencionando diferentes agentes: Log Analytics Agent (MMA), Azure Monitor Agent (AMA) e Dependency Agent.

Qual agente a Microsoft recomenda atualmente como padrao?

- **A)** Log Analytics Agent (MMA) — agente original com maior compatibilidade
- **B)** Azure Monitor Agent (AMA) — agente unificado recomendado pela Microsoft
- **C)** Dependency Agent — agente necessario para toda coleta de dados
- **D)** Diagnostics Extension — extensao nativa que substitui todos os agentes

---

### Q4.3 — VM Insights (Design)

Rafael habilitou **VM Insights** nas 3 VMs criticas da MedCloud para ter visibilidade completa da performance e dependencias das aplicacoes.

Responda:

1. Que tipos de dados o VM Insights coleta automaticamente? Liste pelo menos 3 categorias.
2. Qual agente (ou agentes) e instalado automaticamente ao habilitar VM Insights?
3. Qual a diferenca entre a **Performance view** e a **Map view** do VM Insights? Em que situacao cada uma e mais util?

---

### Q4.4 — Network Watcher (Cenario)

O Time SRE reporta que VMs na subnet `mc-app-subnet` nao conseguem conectar a uma API externa de laboratorio na porta 443. Rafael precisa diagnosticar o problema rapidamente — as clinicas estao sem acesso a resultados de exames.

1. Qual ferramenta especifica do **Network Watcher** Rafael deve usar primeiro para testar a conectividade?
2. Que informacao essa ferramenta retorna? Como interpretar o resultado?
3. Qual outra ferramenta do Network Watcher ajudaria Rafael a verificar se alguma regra de NSG esta bloqueando o trafego na porta 443?

---

### Q5.1 — Backup Vault vs Recovery Services Vault (Multipla Escolha)

Rafael precisa proteger discos gerenciados (Managed Disks) individuais de VMs criticas usando snapshots incrementais diarios. Ele ja tem um Recovery Services Vault configurado para backup de VMs.

Qual recurso Rafael deve usar para o backup de discos individuais?

A) O mesmo Recovery Services Vault ja existente
B) Um novo Azure Backup Vault
C) Azure Site Recovery
D) Snapshots manuais via Azure CLI

---

### Q5.2 — VM Move entre Resource Groups (Multipla Escolha)

Rafael precisa mover a VM `mc-prontuario` do resource group `mc-app-rg` para `mc-prod-rg`, ambos na mesma regiao (East US). A VM esta running e atende requisicoes de usuarios.

Qual afirmacao e verdadeira sobre esse processo?

A) A VM precisa ser parada (deallocated) antes do move
B) A VM pode ser movida sem downtime — apenas o resource ID muda
C) A VM sera recriada no novo RG com um novo IP privado
D) Voce precisa primeiro exportar a VM como ARM template

---

### Q5.3 — Move entre Regioes (Design)

Rafael precisa mover a VM `mc-portal` da regiao East US para West Europe para atender requisitos de compliance de dados (LGPD). A VM esta configurada com Azure Backup no RSV.

Responda:
1. O comando `az resource move` funciona para mover VMs entre regioes? Por que?
2. Qual servico do Azure Rafael deve usar para migrar a VM para outra regiao com minimo downtime?
3. O backup configurado no RSV de East US sera migrado automaticamente?

---

## Pontuacao

| Secao                    | Questoes | Pontos por Questao | Total   |
| ------------------------ | -------- | ------------------ | ------- |
| 1 — Backup               | 6        | 5                  | 30      |
| 2 — Site Recovery        | 4        | 5                  | 20      |
| 3 — Monitor e Alertas    | 4        | 5                  | 20      |
| 4 — Log Analytics        | 4        | 5                  | 20      |
| 5 — Backup Vault/VM Move | 3        | 5                  | 15      |
| **Total**                | **21**   | ---                | **105** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                             |
| ----- | ------------ | ----------------------------------------- |
| 80-90 | Excelente    | Pronto para o exame ou proximo bloco      |
| 65-79 | Bom          | Revisar questoes erradas nos labs         |
| 45-64 | Regular      | Refazer blocos com dificuldade            |
| < 45  | Insuficiente | Refazer lab completo de Backup/Monitoring |
