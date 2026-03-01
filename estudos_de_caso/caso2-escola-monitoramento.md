# Estudo de Caso 2 — Instituto Saber Digital

**Dificuldade:** Facil | **Dominios:** D3 Compute + D5 Monitoring | **Questoes:** 6

> **Regras:**
> - Responda sem consultar documentacao ou labs anteriores
> - Anote as questoes que teve duvida — elas indicam gaps de estudo
> - O gabarito esta em `caso2-escola-monitoramento-solucao.md`
> - Questoes de multipla escolha tem **uma unica** resposta correta
> - Questoes abertas/design avaliam raciocinio — nao ha resposta unica "perfeita"

---

## Cenario: Instituto Saber Digital

O **Instituto Saber Digital** e uma rede de escolas tecnicas com sede em **Belo Horizonte** e 3 unidades espalhadas por Minas Gerais. Com 2.000 alunos e 150 professores, o instituto esta migrando sua plataforma de ensino online (EAD) para o Azure.

**Lucas Ferreira**, administrador de TI do instituto, foi promovido a **Azure Administrator** e precisa provisionar a infraestrutura de computacao para hospedar a plataforma EAD, alem de configurar monitoramento para garantir disponibilidade durante periodos de prova.

O instituto tem orcamento limitado e precisa escalar durante periodos de pico (provas semestrais) e reduzir custos nos periodos de ferias.

### Equipe

| Persona                      | Funcao              | Responsabilidade                     |
| ---------------------------- | ------------------- | ------------------------------------ |
| Lucas Ferreira (`isd-admin`) | Azure Administrator | Gerenciar toda a infraestrutura      |
| Prof. Marcia Lima            | Coordenadora de EAD | Reportar problemas de performance    |
| Equipe de TI (3 pessoas)     | Suporte tecnico     | Receber alertas e agir em incidentes |

### Infraestrutura Planejada

```
                    ┌────────────────────────────────────────────────┐
                    │             AZURE — Brazil South               │
                    │                                                │
                    │  ┌──────────────────────────────────────────┐  │
                    │  │  RG: isd-ead-rg                          │  │
                    │  │                                          │  │
                    │  │  ┌──────────────┐  ┌──────────────────┐  │  │
                    │  │  │  VM: ead-db  │  │  App Service:    │  │  │
                    │  │  │  SQL Server  │  │  ead-webapp      │  │  │
                    │  │  │  Standard_D4s│  │  (plataforma EAD)│  │  │
                    │  │  └──────────────┘  └──────────────────┘  │  │
                    │  │                                          │  │
                    │  │  ┌──────────────┐  ┌──────────────────┐  │  │
                    │  │  │  VM: ead-    │  │  Storage Account │  │  │
                    │  │  │  fileserver  │  │  (video-aulas)   │  │  │
                    │  │  │  Standard_B2s│  │                  │  │  │
                    │  │  └──────────────┘  └──────────────────┘  │  │
                    │  └──────────────────────────────────────────┘  │
                    │                                                │
                    │  ┌──────────────────────────────────────────┐  │
                    │  │  RG: isd-monitoring-rg                   │  │
                    │  │                                          │  │
                    │  │  - Log Analytics Workspace               │  │
                    │  │  - Action Group: EquipeTI-AlertGroup     │  │
                    │  │  - Alert Rules (CPU, Memory, HTTP 5xx)   │  │
                    │  └──────────────────────────────────────────┘  │
                    └────────────────────────────────────────────────┘
```

### Padroes de Uso

| Periodo           | Usuarios Simultaneos | Duracao       |
| ----------------- | -------------------- | ------------- |
| Aulas normais     | 200-400              | 10 meses/ano  |
| Periodo de provas | 1.500-2.000          | 4 semanas/ano |
| Ferias            | < 50                 | 6 semanas/ano |

---

## Secao 1 — Computacao (3 questoes)

### Q1.1 — Selecao de Tamanho de VM por Workload (Multipla Escolha)

Lucas precisa escolher o tamanho de VM para o servidor de banco de dados SQL Server (`ead-db`). O workload exige:

- **CPU:** Processamento intensivo de queries durante provas (4+ vCPUs)
- **Memoria:** SQL Server precisa de bastante RAM para cache (16+ GB)
- **Disco:** IOPS altos para queries complexas
- **Custo:** Orcamento limitado, precisa da melhor relacao custo-beneficio

Qual **familia** de VM e mais adequada para esse workload?

- **A)** Serie B (Burstable) — economica com creditos de CPU
- **B)** Serie Dsv5 (General Purpose) — equilibrio entre CPU, memoria e disco
- **C)** Serie Esv5 (Memory Optimized) — otimizada para memoria com bom desempenho de disco
- **D)** Serie Fsv2 (Compute Optimized) — otimizada para CPU com alta frequencia

---

### Q1.2 — App Service Plan Tier Choice (Design)

Lucas precisa hospedar a plataforma EAD (`ead-webapp`) em um App Service. Os requisitos sao:

- Suporte a **custom domain** (saber-digital.edu.br)
- **SSL/TLS** obrigatorio
- **Deployment slots** para testar atualizacoes antes de ir para producao
- **Scale out** automatico durante periodo de provas
- Orcamento moderado

Responda:

1. Qual **tier** do App Service Plan atende todos os requisitos? Justifique eliminando os tiers inferiores.
2. Se Lucas nao precisasse de deployment slots, qual tier mais barato atenderia os demais requisitos?
3. Qual a diferenca entre **scale up** (vertical) e **scale out** (horizontal) no contexto do App Service?

---

### Q1.3 — Availability Set vs Availability Zone (Multipla Escolha)

Lucas esta preocupado com a disponibilidade do servidor de banco de dados (`ead-db`). Ele quer proteger contra falhas de hardware no datacenter. Um colega sugere usar **Availability Set**, enquanto outro sugere **Availability Zone**.

Qual afirmacao e **correta** sobre a diferenca entre os dois?

- **A)** Availability Set protege contra falhas em datacenters diferentes; Availability Zone protege contra falhas de rack dentro do mesmo datacenter
- **B)** Availability Set distribui VMs entre fault domains e update domains dentro de um datacenter; Availability Zone distribui VMs entre datacenters fisicamente separados na mesma regiao
- **C)** Availability Set e Availability Zone oferecem o mesmo SLA de 99.99%
- **D)** Availability Zone esta disponivel em todas as regioes do Azure; Availability Set requer configuracao especial

---

## Secao 2 — Monitoramento (3 questoes)

### Q2.1 — Metric Alert vs Log Alert (Multipla Escolha)

Lucas precisa configurar dois tipos de alertas:

- **Alerta 1:** Disparar quando a CPU da VM `ead-db` ficar acima de 90% por mais de 5 minutos
- **Alerta 2:** Disparar quando houver mais de 50 erros HTTP 500 no App Service `ead-webapp` nos ultimos 15 minutos

Qual tipo de alerta Lucas deve usar para **cada** cenario?

- **A)** Metric Alert para ambos
- **B)** Log Alert para ambos
- **C)** Metric Alert para o Alerta 1; Log Alert para o Alerta 2
- **D)** Log Alert para o Alerta 1; Metric Alert para o Alerta 2

---

### Q2.2 — Action Groups Configuration (Design)

Lucas precisa configurar um **Action Group** chamado `EquipeTI-AlertGroup` para notificar a equipe de TI quando alertas forem disparados. Os requisitos sao:

- **Lucas Ferreira:** Receber email + SMS em qualquer alerta critico
- **Equipe de TI (3 pessoas):** Receber email em qualquer alerta
- **Prof. Marcia Lima:** Receber email apenas em alertas de indisponibilidade da plataforma EAD
- Quando a CPU da VM `ead-db` ultrapassar 95%, executar um **runbook** de automacao que aumenta o tamanho da VM temporariamente

Responda:

1. Quantos **Action Groups** Lucas deveria criar? Justifique.
2. Quais **action types** Lucas usaria dentro de cada Action Group?
3. Como Lucas pode fazer para que Prof. Marcia receba notificacao apenas de alertas especificos, sem receber todos os alertas?

---

### Q2.3 — KQL Query para Troubleshooting (Cenario)

Prof. Marcia reporta que a plataforma EAD esta **lenta** durante as ultimas tardes (14h-17h). Lucas precisa investigar usando o **Log Analytics Workspace**.

Os dados de performance da VM `ead-db` estao sendo coletados na tabela `Perf`, e os logs do App Service estao na tabela `AppServiceHTTPLogs`.

Lucas escreve a seguinte query KQL para investigar:

```kql
Perf
| where Computer == "ead-db"
| where CounterName == "% Processor Time"
| where TimeGenerated > ago(7d)
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

A query retorna dados, mas Lucas percebe que a **media de CPU esta normal** (45%) em todos os horarios, inclusive das 14h as 17h.

1. Se a CPU media esta normal, que **outro contador de performance** Lucas deveria investigar que pode explicar a lentidao de um SQL Server?
2. Escreva uma query KQL que filtre apenas o horario problematico (14h-17h) dos ultimos 7 dias para o contador que voce sugeriu.
3. Que tabela e query Lucas poderia usar para verificar se o App Service esta retornando **respostas lentas** (tempo de resposta > 5 segundos)?

---

## Pontuacao

| Secao             | Questoes | Pontos por Questao | Total  |
| ----------------- | -------- | ------------------ | ------ |
| 1 — Computacao    | 3        | 5                  | 15     |
| 2 — Monitoramento | 3        | 5                  | 15     |
| **Total**         | **6**    | —                  | **30** |

### Classificacao

| Faixa | Nivel        | Acao Sugerida                                        |
| ----- | ------------ | ---------------------------------------------------- |
| 26-30 | Excelente    | Avance para o Caso 3                                 |
| 20-25 | Bom          | Revisar questoes erradas nos labs                    |
| 12-19 | Regular      | Refazer blocos com dificuldade                       |
| < 12  | Insuficiente | Revisar labs 2-storage-compute e 3-backup-monitoring |
