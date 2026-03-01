# Video 22: Administer Monitoring AZ-104

## Informacoes Gerais

| Propriedade             | Valor                        |
| ----------------------- | ---------------------------- |
| **Titulo**              | Administer Monitoring AZ-104 |
| **Canal**               | Microsoft Learn              |
| **Inscritos no Canal**  | 88,7 mil                     |
| **Visualizacoes**       | 3.000+                       |
| **Data de Publicacao**  | 4 de junho de 2025           |
| **Posicao na Playlist** | Episodio 22 de 22 (Final)    |
| **Idioma**              | Ingles                       |

---

## Links Importantes

| Recurso                      | URL                                                                      |
| ---------------------------- | ------------------------------------------------------------------------ |
| **Video no YouTube**         | https://www.youtube.com/watch?v=q7xkOpNh6SM                              |
| **Playlist Completa**        | https://www.youtube.com/playlist?list=PLahhVEj9XNTcj4dwEwRHozO3xcxI_UHYG |
| **Curso no Microsoft Learn** | https://aka.ms/AZ-104onLearn                                             |

---

## Descricao do Conteudo

Este e o ultimo video da serie AZ-104 e aborda monitoramento no Azure. Voce aprendera sobre Azure Monitor, Log Analytics, configuracao de alertas, metricas, Application Insights e Network Watcher para ter visibilidade completa do seu ambiente Azure.

### O que voce aprendera

- Azure Monitor e seus componentes
- Log Analytics workspace e queries KQL
- Configuracao de alertas e action groups
- Metricas e diagnostico
- Application Insights
- Network Watcher

---

## Topicos Abordados

### 1. Azure Monitor - Visao Geral

| Componente    | Descricao                           |
| ------------- | ----------------------------------- |
| **Metrics**   | Dados numericos em tempo real       |
| **Logs**      | Dados textuais para analise         |
| **Alerts**    | Notificacoes baseadas em condicoes  |
| **Workbooks** | Dashboards interativos              |
| **Insights**  | Visoes pre-configuradas por servico |

### 2. Fontes de Dados

| Fonte                 | Tipo de Dados                    |
| --------------------- | -------------------------------- |
| **Azure Resources**   | Metricas e logs de plataforma    |
| **Applications**      | Traces, dependencies, exceptions |
| **Operating Systems** | Performance counters, event logs |
| **Custom Sources**    | APIs, scripts, webhooks          |

### 3. Log Analytics Workspace

| Aspecto            | Descricao                        |
| ------------------ | -------------------------------- |
| **Definicao**      | Repositorio central de logs      |
| **Query Language** | Kusto Query Language (KQL)       |
| **Retention**      | 30 dias (gratuito) ate 730 dias  |
| **Data Sources**   | VMs, recursos Azure, on-premises |

#### Queries KQL Basicas

```kql
// Eventos de erro nas ultimas 24h
Event
| where TimeGenerated > ago(24h)
| where EventLevelName == "Error"
| summarize count() by Source

// Performance de CPU
Perf
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 1h)

// Heartbeat de VMs
Heartbeat
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(5m)
```

### 4. Alertas

| Tipo de Alerta          | Baseado em              |
| ----------------------- | ----------------------- |
| **Metric Alerts**       | Valores de metricas     |
| **Log Alerts**          | Resultados de queries   |
| **Activity Log Alerts** | Eventos do Activity Log |
| **Smart Detection**     | ML para anomalias       |

#### Action Groups

| Acao               | Descricao                   |
| ------------------ | --------------------------- |
| **Email/SMS**      | Notificacoes                |
| **Azure Function** | Executar codigo             |
| **Logic App**      | Workflow automatizado       |
| **Webhook**        | Chamar URL externa          |
| **ITSM**           | Integracao ServiceNow, etc. |
| **Runbook**        | Azure Automation            |

### 5. Diagnostic Settings

| Destino              | Uso                         |
| -------------------- | --------------------------- |
| **Log Analytics**    | Queries e analise           |
| **Storage Account**  | Arquivamento longo prazo    |
| **Event Hub**        | Streaming para SIEM externo |
| **Partner Solution** | Integracao com terceiros    |

### 6. Application Insights

| Recurso                | Descricao                    |
| ---------------------- | ---------------------------- |
| **Live Metrics**       | Metricas em tempo real       |
| **Application Map**    | Visualizacao de dependencias |
| **Failures**           | Analise de erros             |
| **Performance**        | Tempos de resposta           |
| **Availability Tests** | Testes de endpoint           |
| **User Flows**         | Comportamento do usuario     |

### 7. Network Watcher

| Ferramenta                  | Uso                           |
| --------------------------- | ----------------------------- |
| **IP Flow Verify**          | Testar se trafego e permitido |
| **Next Hop**                | Verificar roteamento          |
| **Connection Troubleshoot** | Diagnosticar conectividade    |
| **Packet Capture**          | Capturar pacotes de rede      |
| **NSG Flow Logs**           | Logs de trafego NSG           |
| **Traffic Analytics**       | Analise de trafego            |

---

## Conceitos-Chave para o Exame

1. **Azure Monitor Data Types**

   - Metrics: Numerico, real-time, 93 dias retencao
   - Logs: Textual, historico, configuravel

2. **Log Analytics**

   - Workspace e requisito para muitos recursos
   - KQL e a linguagem de query
   - Pode coletar de multiplas subscriptions

3. **Alert Severity**

   - Sev 0: Critical
   - Sev 1: Error
   - Sev 2: Warning
   - Sev 3: Informational
   - Sev 4: Verbose

4. **Diagnostic Settings**

   - Cada recurso tem suas categorias
   - Pode enviar para multiplos destinos
   - Nem todos os recursos suportam todos os logs

5. **Network Watcher**
   - Habilitado por regiao
   - NSG Flow Logs requerem Storage Account
   - Connection Monitor para monitoramento continuo

---

## Peso no Exame AZ-104

| Dominio                                       | Peso   |
| --------------------------------------------- | ------ |
| Monitorar e fazer backup de recursos do Azure | 10-15% |

Monitoramento e um topico essencial que aparece frequentemente no exame.

---

## Recursos Complementares

| Recurso             | Link                                                                              |
| ------------------- | --------------------------------------------------------------------------------- |
| **Azure Monitor**   | https://learn.microsoft.com/en-us/azure/azure-monitor/                            |
| **Log Analytics**   | https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview |
| **KQL Reference**   | https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/                |
| **Network Watcher** | https://learn.microsoft.com/en-us/azure/network-watcher/                          |

---

## Video Anterior

**Video 21:** Administer Data Protection AZ-104

- Azure Backup
- Recovery Services Vault
- Politicas de backup
- Azure Site Recovery

## Conclusao do Curso

Este e o ultimo video da playlist AZ-104: Azure Administrator. Apos completar todos os 22 videos, voce esta preparado para:

1. Fazer o exame de certificacao AZ-104
2. Administrar ambientes Azure em producao
3. Implementar melhores praticas de seguranca e governanca
4. Gerenciar recursos de computacao, rede e armazenamento
5. Monitorar e proteger seus recursos Azure

### Proximos Passos Recomendados

- Praticar no Azure Portal com uma conta gratuita
- Fazer os laboratorios do Microsoft Learn
- Revisar a documentacao oficial
- Fazer simulados do exame
- Agendar o exame AZ-104

---

_Fonte: Microsoft Learn - Canal oficial no YouTube_

---

## Resumo da Playlist Completa AZ-104

| Video | Titulo                    | Duracao |
| ----- | ------------------------- | ------- |
| 1     | Previa do curso           | 5 min   |
| 2     | Course Introduction       | 2 min   |
| 3-4   | Microsoft Entra ID        | 63 min  |
| 5-6   | Governance and Compliance | 84 min  |
| 7     | Azure Resources           | 34 min  |
| 8-10  | Virtual Networking        | 110 min |
| 11-12 | Intersite Connectivity    | 63 min  |
| 13    | Network Traffic           | 57 min  |
| 14-16 | Azure Storage             | 127 min |
| 17-18 | Azure Virtual Machines    | 93 min  |
| 19-20 | PaaS Compute Options      | 66 min  |
| 21    | Data Protection           | 37 min  |
| 22    | Monitoring                | 42 min  |
