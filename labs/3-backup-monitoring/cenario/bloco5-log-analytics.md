> Voltar para o [Cenário Contoso](../cenario-contoso.md)

# Bloco 5 - Log Analytics & Network Watcher

**Origem:** Lab 11 (continuacao) + VM Insights + Network Watcher
**Resource Groups utilizados:** `az104-rg-monitor` (workspace) + `az104-rg7` (VMs da Semana 2) + `az104-rg4` (VNets da Semana 1)

## Contexto

O Azure Monitor coleta metricas basicas automaticamente, mas para observabilidade avancada voce precisa de **Log Analytics** (queries KQL), **VM Insights** (performance e dependencias) e **Network Watcher** (diagnostico de rede). Voce conecta tudo as VMs da Semana 2 e as VNets da Semana 1.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                    Log Analytics & Observabilidade                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Log Analytics Workspace: az104-law (az104-rg-monitor)       │  │
│  │                                                              │  │
│  │  Data Sources:                                               │  │
│  │  ├─ az104-vm-win  (Semana 2) ◄── Azure Monitor Agent         │  │
│  │  ├─ az104-vm-linux (Semana 2) ◄── Azure Monitor Agent        │  │
│  │  └─ Activity Log ◄── Diagnostic Settings                     │  │
│  │                                                              │  │
│  │  Queries (KQL):                                              │  │
│  │  ├─ Heartbeat: verificar conectividade dos agentes           │  │
│  │  ├─ Perf: metricas de CPU, memoria, disco                    │  │
│  │  ├─ Event: logs de eventos Windows                           │  │
│  │  └─ InsightsMetrics: dados de VM Insights                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  VM Insights                                                 │  │
│  │                                                              │  │
│  │  ├─ Performance: CPU, memoria, disco, rede das VMs           │  │
│  │  └─ Map: dependencias entre VMs e servicos                   │  │
│  │     ├─ az104-vm-win → conexoes de rede                       │  │
│  │     └─ az104-vm-linux → processos e portas                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Network Watcher (Semana 1 — VNets)                          │  │
│  │                                                              │  │
│  │  ├─ IP Flow Verify: testar NSG rules nas VNets               │  │
│  │  ├─ Next Hop: verificar routing (route tables da Semana 1)   │  │
│  │  ├─ Connection Troubleshoot: testar conectividade            │  │
│  │  │  (entre VMs da Semana 2 via VNets da Semana 1)            │  │
│  │  ├─ NSG Flow Logs: trafego nos NSGs da Semana 1              │  │
│  │  └─ Topology: visualizar VNets + subnets + NSGs + VMs        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Integra recursos de TODAS as semanas (1, 2 e 3)                 │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Log Analytics Workspace

> **Cobranca:** O workspace gera cobranca por GB de dados ingeridos.

1. Pesquise e selecione **Log Analytics workspaces** > **+ Create**

2. Configure:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource group | `az104-rg-monitor` |
   | Name           | `az104-law`        |
   | Region         | **East US**        |

3. Clique em **Review + Create** > **Create** > **Go to resource**

4. Explore o blade **General** > **Usage and estimated costs**

   > **Conceito:** O Log Analytics Workspace e o repositorio central de logs no Azure Monitor. Todos os dados (metricas guest, logs, eventos) sao enviados para ca e consultados via KQL (Kusto Query Language).

   > **Conexao com Bloco 4:** O workspace complementa os alertas do Bloco 4. Alertas de metrica monitoram valores em tempo real; Log Analytics permite analise historica e correlacao de eventos.

---

### Task 5.2: Conectar VMs ao workspace (Azure Monitor Agent)

Voce habilita a coleta de logs e metricas guest das VMs da Semana 2.

1. No workspace **az104-law**, va para **Settings** > **Agents**

2. Note as instrucoes de instalacao para Windows e Linux

3. **Metodo alternativo (recomendado):** Habilitar via VM Insights (Task 5.3) que instala o agente automaticamente

   > **Conceito:** O Azure Monitor Agent (AMA) substitui os agentes legados (MMA/OMS e Dependency Agent). O AMA usa **Data Collection Rules (DCR)** para definir quais dados coletar e para onde enviar.

**Criar Data Collection Rule:**

4. Pesquise e selecione **Monitor** > **Settings** > **Data Collection Rules** > **+ Create**

5. Aba **Basics**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Rule Name      | `az104-dcr`        |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg-monitor` |
   | Region         | **East US**        |
   | Platform Type  | **All**            |

6. Aba **Resources**: clique em **+ Add resources**

7. Expanda `az104-rg7` > selecione **az104-vm-win** e **az104-vm-linux**

   > **Conexao com Semana 2:** Voce esta conectando as VMs criadas na Semana 2 ao workspace de Log Analytics. O agente sera instalado automaticamente nas VMs selecionadas.

8. Clique em **Apply**

9. Aba **Collect and deliver** > **+ Add data source**:

   **Data Source 1 — Performance Counters:**

   | Setting          | Value                                  |
   | ---------------- | -------------------------------------- |
   | Data source type | **Performance Counters**               |
   | Configure        | **Basic** (CPU, Memory, Disk, Network) |

   Destination: **Azure Monitor Logs** > `az104-law`

10. **+ Add data source** novamente:

    **Data Source 2 — Windows Event Logs:**

    | Setting          | Value                                                                               |
    | ---------------- | ----------------------------------------------------------------------------------- |
    | Data source type | **Windows Event Logs**                                                              |
    | Configure        | **Basic** (Application: Critical, Error, Warning; System: Critical, Error, Warning) |

    Destination: **Azure Monitor Logs** > `az104-law`

11. Clique em **Review + create** > **Create**

12. Aguarde alguns minutos para o agente ser instalado nas VMs

---

### Task 5.3: Habilitar VM Insights

1. Navegue para **az104-vm-win** (em az104-rg7)

2. No blade **Monitoring** > **Insights**

3. Clique em **Enable**

4. Configure:

   | Setting                            | Value                        |
   | ---------------------------------- | ---------------------------- |
   | Log Analytics Workspace            | `az104-law`                  |
   | Data collection rule (if prompted) | `az104-dcr` ou crie uma nova |

5. Clique em **Configure** > aguarde o deployment

6. Repita para **az104-vm-linux**:
   - Navegue para **az104-vm-linux** > **Monitoring** > **Insights** > **Enable** > configure com `az104-law`

   > **Conexao com Semana 2:** VM Insights mostra performance detalhada e mapa de dependencias das VMs. Voce podera ver como as VMs da Semana 2 se comunicam entre si e com outros servicos via as VNets da Semana 1.

7. Aguarde 5-10 minutos para dados comecarem a fluir

8. Volte para **az104-vm-win** > **Monitoring** > **Insights**

9. Explore as abas:
   - **Performance:** CPU, memoria, disco, rede (metricas guest via agente)
   - **Map:** dependencias de rede, processos, portas

   > **Conceito:** VM Insights usa o Azure Monitor Agent para coletar metricas de performance e o Dependency Agent para mapear conexoes de rede. O Map mostra processos, portas e conexoes entre VMs e servicos externos.

---

### Task 5.4: Executar queries KQL no Log Analytics

1. Navegue para **az104-law** > **General** > **Logs**

2. Feche o dialog de queries pre-built (se aparecer)

3. Execute as queries abaixo, uma por vez:

**Query 1 — Heartbeat (verificar agentes conectados):**

```kql
Heartbeat
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| project Computer, LastHeartbeat, MinutesSinceLastHeartbeat = datetime_diff('minute', now(), max_TimeGenerated)
```

4. Verifique que ambas as VMs aparecem (az104-vm-win e az104-vm-linux)

**Query 2 — Performance de CPU (ultimas 4 horas):**

```kql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where TimeGenerated > ago(4h)
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

5. Observe o grafico de CPU de ambas as VMs

**Query 3 — Eventos de erro Windows:**

```kql
Event
| where EventLevelName == "Error"
| where TimeGenerated > ago(24h)
| summarize ErrorCount = count() by Source, Computer
| order by ErrorCount desc
| take 10
```

**Query 4 — Top processos por CPU (VM Insights):**

```kql
InsightsMetrics
| where Name == "UtilizationPercentage"
| where TimeGenerated > ago(1h)
| summarize AvgCPU = avg(Val) by bin(TimeGenerated, 5m), Computer
| render timechart
```

> **Conceito:** KQL (Kusto Query Language) e a linguagem de consulta do Azure Monitor. Ela permite filtrar, agregar, correlacionar e visualizar dados de logs e metricas.

> **Dica AZ-104:** Na prova, voce pode ver queries KQL basicas. Foque em operadores: `where`, `summarize`, `project`, `render`, `ago()`, `bin()`.

---

### Task 5.5: Configurar Diagnostic Settings para Activity Log

Voce envia o Activity Log para o workspace, permitindo queries KQL sobre operacoes de gerenciamento de todas as semanas.

1. Pesquise e selecione **Monitor** > **Activity Log**

2. Clique em **Export Activity Logs**

3. Clique em **+ Add diagnostic setting**

4. Configure:

   | Setting                                      | Value                                                                      |
   | -------------------------------------------- | -------------------------------------------------------------------------- |
   | Diagnostic setting name                      | `az104-activity-to-law`                                                    |
   | Log categories                               | **Selecione todas** (Administrative, Security, ServiceHealth, Alert, etc.) |
   | Destination: Send to Log Analytics workspace | **Checked**                                                                |
   | Subscription                                 | *sua subscription*                                                         |
   | Log Analytics workspace                      | `az104-law`                                                                |

5. Clique em **Save**

   > **Conexao com Semanas 1-2:** Agora, TODAS as operacoes de gerenciamento (criacao de VNets na Semana 1, deploy de VMs na Semana 2, habilitacao de backup na Semana 3) sao enviadas para o workspace e podem ser analisadas via KQL.

6. Aguarde alguns minutos e execute a query:

```kql
AzureActivity
| where TimeGenerated > ago(1h)
| summarize count() by OperationNameValue, ActivityStatusValue
| order by count_ desc
| take 20
```

---

### Task 5.6: Network Watcher — IP Flow Verify

Voce usa o Network Watcher para diagnosticar regras NSG nas VNets da Semana 1.

1. Pesquise e selecione **Network Watcher**

2. Em **Network diagnostic tools** > **IP flow verify**

3. Configure:

   | Setting           | Value                                                          |
   | ----------------- | -------------------------------------------------------------- |
   | Subscription      | *sua subscription*                                             |
   | Resource group    | `az104-rg7`                                                    |
   | Virtual machine   | **az104-vm-win**                                               |
   | Network interface | *selecione a NIC da VM*                                        |
   | Protocol          | **TCP**                                                        |
   | Direction         | **Inbound**                                                    |
   | Local port        | `3389`                                                         |
   | Remote IP address | `10.20.10.5` (IP simulado na SharedServicesSubnet da Semana 1) |
   | Remote port       | `*`                                                            |

4. Clique em **Check**

5. Observe o resultado: **Allowed** ou **Denied** e qual NSG rule causou

   > **Conexao com Semana 1:** O IP Flow Verify testa as regras dos NSGs criados na Semana 1 (ex: myNSGSecure associado a SharedServicesSubnet). Voce pode verificar se as regras configuradas naquela semana estao permitindo ou bloqueando o trafego esperado.

---

### Task 5.7: Network Watcher — Next Hop

1. Em **Network Watcher** > **Network diagnostic tools** > **Next hop**

2. Configure:

   | Setting                | Value                                                      |
   | ---------------------- | ---------------------------------------------------------- |
   | Subscription           | *sua subscription*                                         |
   | Resource group         | `az104-rg7`                                                |
   | Virtual machine        | **az104-vm-win**                                           |
   | Network interface      | *selecione a NIC da VM*                                    |
   | Source IP address      | *IP privado da az104-vm-win*                               |
   | Destination IP address | `10.30.0.4` (IP simulado na ManufacturingVnet da Semana 1) |

3. Clique em **Next hop**

4. Observe o resultado:

   | Resultado esperado    | Significado                                    |
   | --------------------- | ---------------------------------------------- |
   | **VNet peering**      | Trafego roteado via peering (Semana 1)         |
   | **Virtual appliance** | Trafego roteado via NVA (se route table ativa) |
   | **Internet**          | Sem rota especifica — vai para internet        |
   | **None**              | Trafego descartado                             |

   > **Conexao com Semana 1:** O Next Hop mostra como as route tables e peerings configurados na Semana 1 afetam o trafego. Se voce configurou UDRs com next hop "Virtual appliance", o resultado mostrara isso.

---

### Task 5.8: Network Watcher — Connection Troubleshoot (cross-VNet)

1. Em **Network Watcher** > **Network diagnostic tools** > **Connection troubleshoot**

2. Configure:

   | Setting                 | Value                          |
   | ----------------------- | ------------------------------ |
   | Source type             | **Virtual machine**            |
   | Virtual machine         | **az104-vm-win**               |
   | Destination type        | **Specify manually**           |
   | URI, FQDN or IP address | *IP privado de az104-vm-linux* |
   | Destination port        | `22` (SSH)                     |
   | Protocol                | **TCP**                        |

3. Clique em **Check**

4. Observe: **Reachable** ou **Unreachable** e o caminho completo (hops)

   > **Conexao com Semanas 1-2:** Este teste verifica a comunicacao entre VMs da Semana 2 usando a infraestrutura de rede da Semana 1 (VNets, peering, NSGs, route tables). O Network Watcher mostra cada hop no caminho, incluindo NSGs e route tables.

---

### Task 5.9: Network Watcher — Topology

1. Em **Network Watcher** > **Monitoring** > **Topology**

2. Configure:

   | Setting        | Value                           |
   | -------------- | ------------------------------- |
   | Subscription   | *sua subscription*              |
   | Resource Group | `az104-rg4` (VNets da Semana 1) |

3. Observe o diagrama visual mostrando:
   - VNets e suas subnets
   - NSGs associados as subnets
   - NICs e VMs (se no mesmo RG)

4. Troque para `az104-rg7` e observe as VMs da Semana 2 e suas conexoes de rede

   > **Conceito:** O Topology fornece uma visualizacao grafica da infraestrutura de rede. E util para entender a arquitetura e identificar gaps de seguranca (subnets sem NSG, etc.).

   > **Conexao com Semana 1:** A topologia mostra a arquitetura de rede completa que voce construiu na Semana 1: VNets, subnets, NSGs, peerings — tudo em um diagrama interativo.

---

### Task 5.10: Criar alerta de log query (KQL)

Voce cria um alerta baseado em query KQL que dispara quando VMs param de enviar heartbeats.

> **Cobranca:** Alert rules geram cobranca minima por sinal monitorado.

1. Em **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: selecione o workspace **az104-law**

3. Aba **Condition**: clique em **See all signals** > filtre por **Custom log search**

4. Na query, insira:

   ```kql
   Heartbeat
   | summarize LastHeartbeat = max(TimeGenerated) by Computer
   | where LastHeartbeat < ago(5m)
   ```

5. Configure:

   | Setting            | Value            |
   | ------------------ | ---------------- |
   | Measurement        | **Table rows**   |
   | Aggregation type   | **Count**        |
   | Threshold operator | **Greater than** |
   | Threshold value    | `0`              |
   | Frequency          | **5 minutes**    |
   | Lookback period    | **5 minutes**    |

6. Clique em **Next: Actions** > selecione **az104-ag1** (do Bloco 4)

   > **Conexao com Bloco 4:** Voce reutiliza o mesmo Action Group criado no Bloco 4, demonstrando que Action Groups sao reutilizaveis entre diferentes tipos de alertas.

7. Aba **Details**:

   | Setting         | Value                                    |
   | --------------- | ---------------------------------------- |
   | Severity        | **1 - Error**                            |
   | Alert rule name | `az104-vm-heartbeat-lost`                |
   | Description     | `Alert when VM stops sending heartbeats` |
   | Resource group  | `az104-rg-monitor`                       |

8. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de log query (Custom Log Search) executam queries KQL periodicamente. Quando a query retorna resultados que atendem ao threshold, o alerta dispara. Sao mais flexiveis que alertas de metrica, mas tem maior latencia (frequencia minima de 5 minutos).

---

## Modo Desafio - Bloco 5

- [ ] Criar Log Analytics Workspace `az104-law` em `az104-rg-monitor`
- [ ] Criar Data Collection Rule `az104-dcr` conectando VMs **(Semana 2)** ao workspace
- [ ] Habilitar VM Insights em `az104-vm-win` e `az104-vm-linux` **(Semana 2)**
- [ ] Executar queries KQL: Heartbeat, Perf (CPU), Events, InsightsMetrics
- [ ] Configurar Diagnostic Settings: Activity Log → `az104-law`
- [ ] **Integracao:** Network Watcher — IP Flow Verify nos NSGs **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Next Hop verificando routing **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Connection Troubleshoot entre VMs **(Semana 2)** via VNets **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Topology das VNets **(Semana 1)**
- [ ] Criar alerta de log query (heartbeat lost) → reutilizar `az104-ag1` **(Bloco 4)**

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Voce precisa coletar metricas de memoria de uma VM Azure. As metricas de memoria nao aparecem em Azure Monitor Metrics. O que esta faltando?**

A) Metricas de memoria nao sao suportadas no Azure
B) O Azure Monitor Agent precisa ser instalado na VM para coletar metricas guest (incluindo memoria)
C) Voce precisa habilitar Boot Diagnostics
D) Voce precisa usar Premium storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Azure Monitor Agent precisa ser instalado na VM para coletar metricas guest (incluindo memoria)**

Azure Monitor coleta automaticamente metricas **host** (CPU, Network, Disk IO) sem agente. Metricas **guest** (memoria, processos, logs do SO) requerem o Azure Monitor Agent (AMA) com Data Collection Rules configuradas.

</details>

### Questao 5.2
**Voce executa a query KQL `Heartbeat | summarize count() by Computer` no Log Analytics. O que esta query retorna?**

A) A quantidade total de heartbeats de todas as VMs juntas
B) A quantidade de heartbeats agrupada por cada computador (VM)
C) O timestamp do ultimo heartbeat de cada VM
D) Uma lista de VMs com problemas de heartbeat

<details>
<summary>Ver resposta</summary>

**Resposta: B) A quantidade de heartbeats agrupada por cada computador (VM)**

O operador `summarize count() by Computer` conta os registros e agrupa por valor unico de Computer. Cada linha do resultado mostra o nome da VM e a quantidade de heartbeats.

</details>

### Questao 5.3
**Voce usou IP Flow Verify no Network Watcher para testar conectividade a uma VM. O resultado mostra "Access denied" pela regra "DenyAllInBound". O que isso significa?**

A) A VM esta desligada
B) Nao ha regra NSG que permita o trafego — a regra default DenyAllInBound esta bloqueando
C) O firewall da VM esta bloqueando
D) O Network Watcher esta com problema

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao ha regra NSG que permita o trafego — a regra default DenyAllInBound esta bloqueando**

A regra DenyAllInBound (priority 65500) e a regra default que bloqueia todo trafego inbound nao explicitamente permitido. Se essa regra esta sendo acionada, significa que nenhuma regra com priority menor (maior prioridade) permite o trafego testado.

</details>

### Questao 5.4
**Voce quer identificar gargalos de rede entre duas VMs em VNets diferentes com peering. Qual ferramenta do Network Watcher e mais adequada?**

A) IP Flow Verify
B) Connection Troubleshoot
C) NSG Flow Logs
D) VPN Troubleshoot

<details>
<summary>Ver resposta</summary>

**Resposta: B) Connection Troubleshoot**

Connection Troubleshoot testa a conectividade de ponta a ponta entre dois endpoints, mostrando cada hop no caminho, latencia e se a conexao e bem-sucedida. IP Flow Verify testa apenas regras NSG em uma NIC. NSG Flow Logs capturam trafego para analise posterior.

</details>

### Questao 5.5
**Qual e a diferenca entre Data Collection Rules (DCR) e Diagnostic Settings no Azure Monitor?**

A) DCR coleta dados de VMs (guest), Diagnostic Settings coleta dados de recursos Azure (platform)
B) Sao a mesma coisa com nomes diferentes
C) DCR e para Log Analytics, Diagnostic Settings e para Storage Account
D) DCR e o antigo, Diagnostic Settings e o novo

<details>
<summary>Ver resposta</summary>

**Resposta: A) DCR coleta dados de VMs (guest), Diagnostic Settings coleta dados de recursos Azure (platform)**

- **Data Collection Rules (DCR):** Usadas com o Azure Monitor Agent para coletar dados de dentro das VMs (metricas guest, logs do SO, eventos)
- **Diagnostic Settings:** Configuradas em recursos Azure (VMs, Storage, VNets, etc.) para enviar metricas de plataforma e logs de recurso para destinos (Log Analytics, Storage, Event Hub)

</details>

---
