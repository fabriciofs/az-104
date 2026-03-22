# Monitoramento

## Azure Monitor - Tipos de Alerta

| Tipo                   | Monitora                               | Uso                                     |
| ---------------------- | -------------------------------------- | --------------------------------------- |
| Metric alert (Static)  | Valor fixo (ex: CPU > 80%)             | Thresholds conhecidos                   |
| Metric alert (Dynamic) | Anomalias via ML                       | Comportamento que varia ao longo do dia |
| Activity Log alert     | Operacoes de controle (create, delete) | Auditoria e compliance                  |
| Log query alert (KQL)  | Queries em Log Analytics               | Analise complexa                        |
| Service Health alert   | Eventos da plataforma Azure            | Outages, manutencao                     |

- Dynamic threshold precisa de **~3 dias** de dados historicos
- "Detectar comportamento anomalo" → **Dynamic**; "CPU > 80%" → **Static**
- Service Health so monitora **plataforma Azure** (nao metricas dos seus recursos)

## Service Health - Tipos de Evento

1. **Service issues** — servico indisponivel (outage)
2. **Planned maintenance** — manutencao agendada
3. **Health advisories** — mudancas que podem afetar voce
4. **Security advisories** — alertas de seguranca

## Metricas Host vs Guest

| Tipo  | Exemplos                  | Agente necessario |
| ----- | ------------------------- | :---------------: |
| Host  | CPU, Network In/Out, Disk |        Nao        |
| Guest | Memoria, Processos        |  Sim (AMA + DCR)  |

- "Metrica de memoria nao aparece" → instalar **Azure Monitor Agent** + configurar **Data Collection Rules**
- "Coletar logs customizados (JSON, texto) → Log Analytics" → **AMA + DCR** (NAO Custom Script Extension)

## Azure Monitor - Estados de Alerta

| Estado           | Significado                          | Quem define |
| ---------------- | ------------------------------------ | ----------- |
| **New**          | Alerta disparado, ninguem investigou | Automatico  |
| **Acknowledged** | Admin esta investigando              | **Manual**  |
| **Closed**       | Admin resolveu/descartou             | **Manual**  |

- Estado de alerta e **sempre manual** — NAO muda automaticamente quando a condicao some
- "50 alertas fechados" → um **administrador alterou manualmente** o estado
- Alertas NAO se fecham sozinhos (nem por idade, nem por resolver a condicao)

## Dashboard compartilhado

- Dados fixados em dashboard compartilhado: maximo **30 dias** de exibicao
- Dashboards privados: sem limite (alem da retencao do Log Analytics)

## Azure Advisor — 5 Categorias

| Categoria | O que faz | Exemplo |
| --- | --- | --- |
| **Custo** | Identifica desperdicio | VMs **subutilizadas**, discos orfaos |
| Seguranca | Recomendacoes de seguranca | Integra com Defender for Cloud |
| Confiabilidade | Resiliencia | Adicionar redundancia, backups |
| Excelencia Operacional | Boas praticas de gestao | Tags, policies, automacao |
| Desempenho | Performance | Resize de VMs, cache, CDN |

- "VMs **subutilizadas**" → **Custo** (NAO Desempenho!)
- "VMs **lentas**" → **Desempenho**
- "Alta disponibilidade" **NAO existe** como categoria — o nome correto e **Confiabilidade**
- Advisor **recomenda**; Budgets **alertam**; Policies **restringem**

## KQL (Kusto Query Language)

### Operadores principais

| Operador | Traducao na prova | O que faz | SQL equivalente |
| --- | --- | --- | --- |
| **where** | onde | Filtra linhas | WHERE |
| **summarize** | resumir | Agrupa/agrega | GROUP BY |
| **project** | projeto | Seleciona/renomeia colunas | SELECT |
| **extend** | estender | Adiciona coluna calculada | SELECT *, nova_col |
| **search in** | buscar em | Busca texto em tabela especifica | LIKE em toda a tabela |
| **top** | topo | Retorna N primeiros ordenados | ORDER BY + LIMIT |
| **count** | contar | Conta registros | COUNT(*) |
| **distinct** | distintos | Valores unicos | DISTINCT |
| **order by** / **sort by** | ordenar | Ordena resultado | ORDER BY |

- "Agregar resultados por coluna" → **summarize** (NAO where, NAO project)
- "Filtrar linhas" → **where**
- "Selecionar colunas" → **project**
- "Adicionar coluna nova" → **extend**
- "Buscar texto em tabela" → **search in (Tabela) "texto"**

### 5 queries que caem na prova (memorize!)

```kql
-- 1. Buscar texto em tabela (caiu no simulado!)
search in (Event) "error"

-- 2. Filtrar por campo + tempo
Event | where EventLevelName == "Error" | where TimeGenerated > ago(1h)

-- 3. Contar por categoria
Event | summarize count() by Source

-- 4. Top N resultados
Perf | where CounterName == "% Processor Time"
     | top 10 by CounterValue desc

-- 5. Selecionar colunas especificas
Event | where Level == 1
      | project TimeGenerated, Source, RenderedDescription
```

### Erros comuns na prova

| Armadilha | Realidade |
| --- | --- |
| Usar SQL (`SELECT * FROM Event`) | KQL nao e SQL! Use `Event \| where ...` |
| Usar PowerShell (`Get-Event`) | KQL roda no Log Analytics, nao no terminal |
| `search "error"` sem `in (Tabela)` | Funciona mas busca em TODAS as tabelas (lento) |
| `Event \| where Level == "Error"` | Level e numerico (1=Error, 2=Warning). Use `EventLevelName` para string |

### Tabelas mais cobradas

| Tabela | O que contem |
| --- | --- |
| **Event** | Windows Event Log (System, Application, Security) |
| **Syslog** | Logs do Linux |
| **Perf** | Metricas de performance (CPU, memoria, disco) |
| **Heartbeat** | Status de conectividade dos agentes |
| **AzureActivity** | Activity Log (operacoes de controle) |
| **SigninLogs** | Logs de login do Entra ID |

- Outros operadores uteis: `render` (visualizacao), `ago()` (tempo relativo), `bin()` (agrupamento temporal)

### Funcoes de tempo no KQL

| Funcao | O que faz | Exemplo (hoje = segunda-feira) |
| --- | --- | --- |
| `ago(Xd)` | Retorna datetime X dias atras | `ago(9d)` = sabado retrasado |
| `startofweek(dt)` | Retorna **domingo** (inicio da semana) do datetime | `startofweek(ago(9d))` = domingo retrasado |
| `endofweek(dt)` | Retorna **sabado** (fim da semana) do datetime | `endofweek(ago(2d))` = sabado passado |
| `startofday(dt)` | Retorna meia-noite do dia | `startofday(now())` = hoje 00:00 |
| `startofmonth(dt)` | Retorna primeiro dia do mes | `startofmonth(now())` = dia 01 do mes |
| `endofmonth(dt)` | Retorna ultimo dia do mes | `endofmonth(now())` = dia 28/30/31 |

- **Semana no KQL comeca no domingo** e termina no sabado
- `startofweek()` sempre volta ao **domingo** daquela semana
- `endofweek()` sempre avanca ao **sabado** daquela semana (23:59:59)

### Como calcular intervalos com startofweek/endofweek

```
Exemplo: hoje = segunda-feira

ago(9d) = 9 dias atras = sabado (semana retrasada)
startofweek(ago(9d)) = domingo da semana retrasada (recua 1 dia)

ago(2d) = 2 dias atras = sabado (semana passada)
endofweek(ago(2d)) = sabado da semana passada (ja e sabado, mantem)

Intervalo = domingo retrasado ate sabado passado = 14 dias (2 semanas)
```

**Dica para a prova:**
1. Calcule a data exata de `ago(Xd)` a partir do dia da semana informado
2. Aplique `startofweek` (volta ao domingo) ou `endofweek` (avanca ao sabado)
3. Conte os dias entre as duas datas resultantes
