# Gabarito — Estudo de Caso 2: Instituto Saber Digital

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `caso2-escola-monitoramento.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Computacao

### Q1.1 — Selecao de Tamanho de VM por Workload

**Resposta: C) Serie Esv5 (Memory Optimized)**

SQL Server e um workload **memory-intensive**. O cache de dados em RAM e fundamental para performance de queries. A serie Esv5 oferece alta relacao memoria/vCPU, que e ideal para bancos de dados relacionais.

| Serie | Foco | RAM/vCPU | Ideal Para |
|-------|------|----------|------------|
| B | Burstable | Variavel | Dev/test, cargas leves e imprevisiveis |
| Dsv5 | General Purpose | ~4 GB/vCPU | Aplicacoes gerais, web servers |
| **Esv5** | **Memory Optimized** | **~8 GB/vCPU** | **SQL Server, caches, analytics** |
| Fsv2 | Compute Optimized | ~2 GB/vCPU | Batch processing, gaming servers |

**Por que os outros estao errados:**
- **A) Serie B (Burstable)** — Inadequada para SQL Server em producao. VMs burstable tem CPU variavel e acumulam creditos quando ociosas. Em periodo de provas com carga constante, os creditos se esgotam e a CPU e **throttled** para o baseline (20-30%).
- **B) Serie Dsv5** — Funcional, mas com menor relacao memoria/CPU. Para o mesmo custo, a serie E oferece mais RAM, que e o recurso mais critico para SQL Server.
- **D) Serie Fsv2** — Otimizada para CPU, com pouca RAM por vCPU. SQL Server nao precisa de frequencia de CPU alta, precisa de muita memoria.

**[GOTCHA]** No exame, a chave para selecao de VM e identificar o **recurso critico** do workload. SQL Server / bancos de dados = memoria. Batch processing / calculo = CPU. Web server generico = general purpose. Dev/test intermitente = burstable.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco2-vms.md` — Selecao de tamanho de VM

---

### Q1.2 — App Service Plan Tier Choice

**Resposta:**

**1. Tier que atende todos os requisitos: Standard (S1 ou superior)**

Analise por tier:

| Recurso Necessario | Free (F1) | Basic (B1) | Standard (S1) | Premium (P1v3) |
|--------------------|-----------|------------|----------------|----------------|
| Custom domain | Nao | Sim | Sim | Sim |
| SSL/TLS | Nao | Sim | Sim | Sim |
| Deployment slots | Nao | Nao | **Sim (5)** | Sim (20) |
| Auto-scale out | Nao | Nao | **Sim (10 inst.)** | Sim (30 inst.) |

O **Standard** e o tier minimo que suporta **deployment slots** e **auto-scale out**. Free e Basic nao suportam nenhum dos dois. Premium atende mas e mais caro sem necessidade.

**2. Sem deployment slots: Basic (B1)**

Se deployment slots nao fossem necessarios, o **Basic** atenderia custom domain + SSL + scale up (manual). Porem, Basic nao suporta auto-scale out — apenas scale up manual. Se auto-scale out fosse obrigatorio, o minimo continuaria sendo Standard.

**3. Scale up vs Scale out:**

| Aspecto | Scale Up (Vertical) | Scale Out (Horizontal) |
|---------|---------------------|------------------------|
| O que faz | Muda para um plano **mais potente** (mais CPU/RAM) | Adiciona **mais instancias** do mesmo plano |
| Exemplo | B1 → S1 → P1v3 | 1 instancia → 5 instancias → 10 instancias |
| Downtime | Pode haver breve reinicio | Sem downtime (novas instancias sao adicionadas) |
| Limite | Tamanho maximo do plano | Maximo de instancias do tier |
| Automatizacao | Manual | Auto-scale baseado em regras (CPU, requests, etc.) |

No contexto do Instituto Saber Digital, **scale out** e mais adequado: durante periodos de prova, adicionar mais instancias; durante ferias, reduzir para 1 instancia. Scale up seria mudar para uma maquina mais potente, que e menos flexivel.

**[GOTCHA]** No exame, deployment slots e auto-scale sao os **divisores** entre Basic e Standard. Se a questao menciona qualquer um dos dois, a resposta minima e Standard.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco3-webapps.md` — App Service Plans e deployment

---

### Q1.3 — Availability Set vs Availability Zone

**Resposta: B) Availability Set distribui VMs entre fault domains e update domains dentro de um datacenter; Availability Zone distribui VMs entre datacenters fisicamente separados na mesma regiao**

| Aspecto | Availability Set | Availability Zone |
|---------|------------------|-------------------|
| Escopo | Dentro de **um datacenter** | Entre **datacenters** da mesma regiao |
| Protecao | Falha de rack (fault domain) e manutencao (update domain) | Falha de datacenter inteiro |
| SLA | **99.95%** | **99.99%** |
| Fault Domains | 2-3 por set | Cada zona = 1 fault domain |
| Custo | Sem custo adicional | Sem custo adicional (mas trafego entre zonas tem custo) |

**Por que os outros estao errados:**
- **A) Invertido** — A descricao esta trocada. Availability Set protege dentro do datacenter; Availability Zone protege entre datacenters.
- **C) Mesmo SLA** — Incorreto. Availability Set = 99.95%; Availability Zone = 99.99%.
- **D) Zone em todas as regioes** — Incorreto. Availability Zones nao estao disponiveis em todas as regioes do Azure. Nem todas as regioes tem 3+ datacenters separados fisicamente.

**[GOTCHA]** SLAs: Availability Set = 99.95% (dois nines e meio), Availability Zone = 99.99% (quatro nines). Esses numeros aparecem frequentemente no exame. VM unica com Premium SSD = 99.9%.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco2-vms.md` — Disponibilidade de VMs

---

## Secao 2 — Monitoramento

### Q2.1 — Metric Alert vs Log Alert

**Resposta: A) Metric Alert para ambos**

Tanto a CPU da VM quanto os erros HTTP 500 do App Service estao disponiveis como **metricas** no Azure Monitor:

- **CPU da VM:** Metrica `Percentage CPU` — disponivel nativamente para todas as VMs
- **Erros HTTP 500 do App Service:** Metrica `Http5xx` — disponivel nativamente para App Services

Metric alerts avaliam metricas em **near real-time** (frequencia de avaliacao de 1 minuto) e sao a escolha preferida quando a informacao esta disponivel como metrica.

**Quando usar Log Alert em vez de Metric Alert:**
- Quando o dado **nao existe como metrica** e so esta disponivel em logs (ex: eventos customizados, logs de aplicacao)
- Quando voce precisa de **logica complexa** (correlacionar dados de multiplas tabelas, queries KQL elaboradas)
- Quando voce precisa de **agregacoes personalizadas** que vao alem do que metric alerts suportam

**Por que os outros estao errados:**
- **B) Log Alert para ambos** — Funcional, mas subotimo. Log alerts tem latencia maior (frequencia de avaliacao minima de 5 minutos) e sao mais complexos de configurar.
- **C) Metric para CPU, Log para HTTP 500** — Incorreto porque HTTP 5xx e disponivel como metrica nativa do App Service.
- **D) Invertido** — Ambos sao metricas, nao ha razao para usar log alert para CPU.

**[GOTCHA]** No exame, a regra geral e: se a informacao esta disponivel como **metrica nativa**, use **Metric Alert**. Metric alerts sao mais rapidos, simples e baratos. Use Log alerts apenas quando a metrica nao existe ou quando precisa de logica KQL complexa.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco4-monitor.md` — Configuracao de alertas

---

### Q2.2 — Action Groups Configuration

**Resposta:**

**1. Quantos Action Groups criar: 2**

- **Action Group 1:** `EquipeTI-AlertGroup` — Para alertas gerais (Lucas + Equipe de TI)
- **Action Group 2:** `EAD-Disponibilidade-AlertGroup` — Para alertas especificos de disponibilidade da plataforma EAD (Prof. Marcia)

Justificativa: Prof. Marcia so deve receber alertas de **indisponibilidade da plataforma**, nao todos os alertas. Ao separar em dois Action Groups, Lucas pode associar cada alert rule ao Action Group adequado.

**2. Action Types:**

| Action Group | Destinatario | Action Type |
|--------------|-------------|-------------|
| EquipeTI-AlertGroup | Lucas Ferreira | Email + SMS |
| EquipeTI-AlertGroup | Equipe de TI (3 pessoas) | Email |
| EquipeTI-AlertGroup | Automation Runbook | Automation Runbook (scale up VM) |
| EAD-Disponibilidade-AlertGroup | Prof. Marcia Lima | Email |

**3. Notificacao seletiva para Prof. Marcia:**

Lucas deve:
1. Criar um Action Group separado que inclui apenas Prof. Marcia
2. Associar esse Action Group **apenas** as alert rules de disponibilidade (ex: HTTP 5xx > threshold, App Service status = down)
3. As demais alert rules (CPU, memoria, etc.) usam apenas o `EquipeTI-AlertGroup`, sem incluir Prof. Marcia

Alternativamente, Lucas pode usar **alert processing rules** (anteriormente chamadas de action rules) para suprimir notificacoes para determinados usuarios em horarios especificos ou para alertas especificos.

**[GOTCHA]** No exame, Action Groups sao a "cola" entre alert rules e notificacoes. Uma alert rule pode ter multiplos Action Groups, e um Action Group pode ser usado em multiplas alert rules. A granularidade de "quem recebe qual alerta" e controlada pela **associacao** entre alert rule e Action Group.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco4-monitor.md` — Action Groups

---

### Q2.3 — KQL Query para Troubleshooting

**Resposta:**

**1. Outro contador de performance para SQL Server:**

Se a CPU esta normal, o gargalo provavelmente e **memoria** ou **disco**. Para SQL Server, os contadores mais relevantes sao:

- **`Available MBytes`** — Memoria disponivel. Se estiver muito baixo, o SQL Server esta sob pressao de memoria e fazendo paging para disco.
- **`Disk Reads/sec`** e **`Disk Writes/sec`** — IOPS de disco. Alto IOPS pode indicar que o SQL Server esta lendo do disco em vez de usar o cache em memoria.
- **`% Free Space`** — Espaco em disco. Disco cheio pode causar lentidao.
- **`Avg. Disk sec/Read`** e **`Avg. Disk sec/Write`** — Latencia de disco. Valores acima de 20ms indicam disco lento.

O mais provavel nesse cenario: **`Available MBytes`** baixo, indicando que o SQL Server esta sem memoria suficiente para cache e fazendo paging excessivo.

**2. Query KQL para horario problematico:**

```kql
Perf
| where Computer == "ead-db"
| where CounterName == "Available MBytes"
| where TimeGenerated > ago(7d)
| where datetime_part("hour", TimeGenerated) >= 14
    and datetime_part("hour", TimeGenerated) < 17
| summarize AvgMemMB = avg(CounterValue),
            MinMemMB = min(CounterValue)
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

Essa query:
- Filtra apenas o contador de memoria disponivel
- Restringe ao horario das 14h-17h dos ultimos 7 dias
- Mostra media e minimo por hora para identificar picos de consumo

**3. Query para respostas lentas do App Service:**

```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(7d)
| where TimeTaken > 5000
| where datetime_part("hour", TimeGenerated) >= 14
    and datetime_part("hour", TimeGenerated) < 17
| summarize SlowRequests = count() by bin(TimeGenerated, 1h),
            CsUriStem
| order by SlowRequests desc
```

Notas:
- `TimeTaken` na tabela `AppServiceHTTPLogs` e medido em **milissegundos**, entao > 5000 = > 5 segundos
- `CsUriStem` mostra qual URL/endpoint esta lento, ajudando a identificar a pagina problematica
- A correlacao entre memoria baixa na VM do SQL e respostas lentas no App Service confirma que o banco de dados e o gargalo

**[GOTCHA]** No exame, KQL aparece frequentemente. Os pontos-chave: `ago()` para janelas de tempo, `summarize` para agregacoes, `bin()` para agrupar por intervalo, `datetime_part()` para filtrar por hora do dia. A tabela `Perf` contem contadores de performance de VMs; `AppServiceHTTPLogs` contem logs de requisicao HTTP.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco5-log-analytics.md` — Queries KQL

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Subtopico |
|---------|----------------|-----------|
| Q1.1 | D3 — Deploy and manage compute resources | VM sizing |
| Q1.2 | D3 — Deploy and manage compute resources | App Service Plans |
| Q1.3 | D3 — Deploy and manage compute resources | Availability Sets vs Zones |
| Q2.1 | D5 — Monitor and maintain resources | Alert types |
| Q2.2 | D5 — Monitor and maintain resources | Action Groups |
| Q2.3 | D5 — Monitor and maintain resources | KQL, Log Analytics |

---

## Top Gotchas — Caso 2

| # | Gotcha | Questao |
|---|--------|---------|
| 1 | SQL Server = **Memory Optimized** (serie E), nao General Purpose | Q1.1 |
| 2 | Deployment slots e auto-scale exigem tier **Standard** ou superior | Q1.2 |
| 3 | Availability Set = 99.95%; Availability Zone = 99.99% | Q1.3 |
| 4 | Se a metrica existe nativamente, use **Metric Alert**, nao Log Alert | Q2.1 |
| 5 | Action Groups controlam **quem** recebe **qual** alerta | Q2.2 |
| 6 | `Perf` para metricas de VM; `AppServiceHTTPLogs` para HTTP; `TimeTaken` em ms | Q2.3 |
