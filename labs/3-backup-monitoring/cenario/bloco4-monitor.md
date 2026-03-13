> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 5 - Log Analytics & Network Watcher](bloco5-log-analytics.md)

# Bloco 4 - Monitor & Alerts

**Origem:** Lab 11 - Implement Monitoring
**Resource Groups utilizados:** `rg-contoso-management` (Action Groups, Alert Rules) + `rg-contoso-compute` (VMs da Semana 2)

## Contexto

Com backup e DR configurados (Blocos 1-3), voce agora implementa monitoramento proativo. Voce cria alertas para as VMs da Semana 2, configura Action Groups para notificacoes e explora metricas. Os alertas monitoram recursos criados desde a **Semana 1** (VNets, NSGs) ate a **Semana 2** (VMs, storage).

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                    Azure Monitor                                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Action Groups (rg-contoso-management)                       │  │
│  │                                                              │  │
│  │  └─ ag-contoso-ops: Email + SMS                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Alert Rules                                                 │  │
│  │                                                              │  │
│  │  ├─ CPU Alert: vm-web-01 CPU > 80%                           │  │
│  │  │  (VM da Semana 2) → ag-contoso-ops                        │  │
│  │  │                                                           │  │
│  │  ├─ VM Deleted Alert: Activity Log delete VM                 │  │
│  │  │  (qualquer VM) → ag-contoso-ops                           │  │
│  │  │                                                           │  │
│  │  └─ Backup Failed Alert: Recovery Services vault             │  │
│  │     (vault do Bloco 1) → ag-contoso-ops                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Monitored Resources                                         │  │
│  │                                                              │  │
│  │  Semana 1: VNets, NSGs, DNS ─── metricas de rede             │  │
│  │  Semana 2: VMs, Storage ──────── metricas de compute/storage │  │
│  │  Semana 3: Vaults ────────────── metricas de backup          │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Usado no Bloco 5 para conectar Log Analytics workspace          │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Explorar metricas de VM

Antes de criar alertas, voce precisa entender quais metricas estao disponiveis. O Azure Monitor coleta metricas **automaticamente** de todos os recursos — sem instalar nada. Essas metricas de "host" vem do hypervisor (a camada que gerencia as VMs) e incluem CPU, rede e disco.

**O que NAO esta disponivel sem agente:** Metricas de dentro da VM (guest), como uso de **memoria**, processos e filesystem. Para isso voce precisa do Azure Monitor Agent (configurado no Bloco 5).

1. Navegue para **vm-web-01** (em rg-contoso-compute, Semana 2)

2. No blade **Monitoring** > **Metrics**

3. Configure o grafico:

   | Setting          | Value                    |
   | ---------------- | ------------------------ |
   | Scope            | **vm-web-01**            |
   | Metric Namespace | **Virtual Machine Host** |
   | Metric           | **Percentage CPU**       |
   | Aggregation      | **Avg**                  |

   > **Aggregation** define como os datapoints sao combinados no periodo. **Avg** mostra a media (bom para tendencia), **Max** mostra o pico (bom para detectar spikes), **Min** mostra o vale, **Sum** mostra o total acumulado.

4. Observe o grafico de CPU — este e o baseline da VM

5. Clique em **+ Add metric** e adicione:

   | Setting     | Value                |
   | ----------- | -------------------- |
   | Metric      | **Network In Total** |
   | Aggregation | **Sum**              |

6. Clique em **+ Add metric** novamente:

   | Setting     | Value                 |
   | ----------- | --------------------- |
   | Metric      | **Network Out Total** |
   | Aggregation | **Sum**               |

   > **Conexao com Semana 2:** As metricas de rede mostram o trafego das VMs que estao conectadas as VNets da Semana 1 e se comunicam via peering configurado naquela semana.

7. Altere o **Time range** para **Last 4 hours**

8. Clique em **Pin to dashboard** para salvar o grafico

   > **Conceito:** Azure Monitor coleta metricas automaticamente de todos os recursos Azure. Metricas **Host** (CPU, Network, Disk) estao disponiveis sem agente. Metricas **Guest** (memoria, processos) requerem o Azure Monitor Agent (configurado no Bloco 5). Essa e uma distincao critica na prova.

---

### Task 4.2: Criar Action Group

O Action Group define **quem** recebe a notificacao e **como**. E um recurso reutilizavel — voce cria uma vez e pode associar a quantos alertas quiser. Pense nele como uma "lista de distribuicao" para incidentes.

1. Pesquise e selecione **Monitor** > **Alerts** > **Action groups** > **+ Create**

2. Aba **Basics**:

   | Setting           | Value                                             |
   | ----------------- | ------------------------------------------------- |
   | Subscription      | *sua subscription*                                |
   | Resource group    | `rg-contoso-management` (mesmo RG dos Blocos 1-3) |
   | Action group name | `ag-contoso-ops`                                  |
   | Display name      | `ag-contoso-ops`                                  |

   > **Display name** e limitado a 12 caracteres e aparece nos SMS/emails. Escolha algo curto e significativo.

3. Aba **Notifications**:

   | Setting           | Value                                      |
   | ----------------- | ------------------------------------------ |
   | Notification type | **Email/SMS message/Push/Voice**           |
   | Name              | `admin-notification`                       |
   | Email             | *seu email*                                |
   | SMS               | *(opcional — marque e informe seu numero)* |

4. Aba **Actions**: pule por enquanto (sem automation neste lab)

   > A aba **Actions** permite configurar automacoes quando o alerta dispara: Azure Functions, Logic Apps, ITSM (ServiceNow), webhooks e Automation Runbooks. Em producao, e comum ter uma Logic App que cria um ticket no sistema de incidentes.

5. Clique em **Review + create** > **Create**

6. Verifique seu email — voce deve receber uma confirmacao de que foi adicionado ao Action Group

   > **Conceito:** Action Groups definem QUEM e notificado e COMO quando um alerta dispara. Podem incluir emails, SMS, push notifications, voice calls, Azure Functions, Logic Apps, ITSM, webhooks e runbooks. Todas as notificacoes e acoes sao executadas em **paralelo** (email E SMS ao mesmo tempo, nao um ou outro).

   > **Conexao com Bloco 5:** O mesmo Action Group sera reutilizado no Bloco 5 para alertas de Log Analytics.

---

### Task 4.3: Criar alerta de metrica (CPU alta)

Este alerta monitora a CPU da VM e notifica quando ela ultrapassa 80%. E o tipo mais comum de alerta — um valor fixo (static threshold) que voce define com base no que considera aceitavel para o ambiente.

> **Cobranca:** Alert rules geram cobranca minima por sinal monitorado.

1. Pesquise e selecione **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: clique em **Select a resource**

   | Setting                 | Value                              |
   | ----------------------- | ---------------------------------- |
   | Filter by resource type | **Virtual machines**               |
   | Resource                | **vm-web-01** (rg-contoso-compute) |

3. Clique em **Apply**

4. Aba **Condition**: clique em **See all signals** > selecione **Percentage CPU**

5. Configure:

   | Setting          | Value            |
   | ---------------- | ---------------- |
   | Threshold        | **Static**       |
   | Aggregation type | **Average**      |
   | Operator         | **Greater than** |
   | Threshold value  | `80`             |
   | Check every      | **5 minutes**    |
   | Lookback period  | **5 minutes**    |

   > **Check every** = frequencia de avaliacao (a cada 5 min o Azure verifica). **Lookback period** = janela de dados analisada (ultimos 5 min de metricas). Um lookback maior suaviza flutuacoes; um menor reage mais rapido. Na maioria dos cenarios, ambos com 5 minutos e o padrao adequado.

   > **Conexao com Semana 2:** Voce esta monitorando a mesma VM Windows da Semana 2. Se a carga de trabalho configurada naquela semana ultrapassar 80% de CPU, voce sera notificado automaticamente.

6. Clique em **Next: Actions**

7. Selecione **Select action groups** > **ag-contoso-ops** > **Select**

8. Aba **Details**:

   | Setting                | Value                                     |
   | ---------------------- | ----------------------------------------- |
   | Subscription           | *sua subscription*                        |
   | Resource group         | `rg-contoso-management`                   |
   | Severity               | **2 - Warning**                           |
   | Alert rule name        | `alert-vm-web-01-cpu`                     |
   | Alert rule description | `Alert when CPU exceeds 80% on vm-web-01` |
   | Enable upon creation   | **Checked**                               |

   > **Severity** vai de 0 (Critical) a 4 (Verbose). Na prova, saiba: 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose. A severity nao afeta o comportamento do alerta — e apenas para classificacao e filtragem.

9. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de metrica avaliam metricas em intervalos regulares. Static threshold compara com um valor fixo. Dynamic threshold usa ML para detectar anomalias com base no padrao historico. O alerta tem 3 estados: **Fired** (disparou), **Resolved** (metrica voltou ao normal) e **Acknowledged** (operador confirmou que viu).

---

### Task 4.3b: Criar alerta com Dynamic Threshold

Dynamic threshold e a alternativa inteligente ao static — em vez de voce definir "80%", o Azure **aprende** o padrao normal da metrica e alerta quando detecta um desvio. Ideal para metricas que variam ao longo do dia (ex: CPU alta durante horario comercial e baixa a noite).

1. Pesquise e selecione **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: clique em **Select a resource**

   | Setting                 | Value                              |
   | ----------------------- | ---------------------------------- |
   | Filter by resource type | **Virtual machines**               |
   | Resource                | **vm-web-01** (rg-contoso-compute) |

3. Clique em **Apply**

4. Aba **Condition**: clique em **See all signals** > selecione **Percentage CPU**

5. Configure:

   | Setting         | Value         |
   | --------------- | ------------- |
   | Threshold       | **Dynamic**   |
   | Sensitivity     | **Medium**    |
   | Check every     | **5 minutes** |
   | Lookback period | **5 minutes** |

6. Observe o grafico de preview — o Azure mostra a banda de threshold calculada com base no historico da VM

   > A "banda" azul no grafico e o intervalo que o Azure considera normal. Qualquer pico fora dessa banda dispara o alerta. Com **High sensitivity**, a banda e mais estreita (alerta com desvios pequenos). Com **Low**, a banda e mais larga (so alerta com desvios grandes).

7. Clique em **Next: Actions** > selecione **ag-contoso-ops**

8. Aba **Details**:

   | Setting                | Value                                          |
   | ---------------------- | ---------------------------------------------- |
   | Subscription           | *sua subscription*                             |
   | Resource group         | `rg-contoso-management`                        |
   | Severity               | **2 - Warning**                                |
   | Alert rule name        | `alert-vm-web-01-cpu-dynamic`                  |
   | Alert rule description | `Dynamic threshold alert for CPU on vm-web-01` |
   | Enable upon creation   | **Checked**                                    |

9. Clique em **Review + create** > **Create**

   > **Conceito:** Dynamic threshold usa machine learning para aprender o padrao historico da metrica e criar um baseline automatico. Existem 3 niveis de sensibilidade: **High** (alerta com qualquer desvio pequeno), **Medium** (balanceado) e **Low** (alerta apenas com desvios grandes). O modelo precisa de aproximadamente **3 dias de dados** para gerar thresholds confiaveis.

   > **Dica AZ-104:** Na prova, saiba diferenciar Static vs Dynamic threshold. Static: voce define o valor fixo (ex: CPU > 80%). Dynamic: o Azure aprende o padrao e detecta anomalias automaticamente. A pergunta tipica apresenta cenarios onde o comportamento normal varia ao longo do dia — nesse caso, Dynamic e a resposta correta.

---

### Task 4.4: Criar alerta de Activity Log (VM deletada)

Este tipo de alerta monitora **operacoes de gerenciamento** (criar, deletar, atualizar recursos) em vez de metricas numericas. E fundamental para auditoria e seguranca — voce quer saber quando alguem deleta uma VM, mesmo que acidentalmente.

**Diferenca-chave:** Alertas de metrica avaliam valores numericos em intervalos. Alertas de Activity Log disparam quando um **evento** ocorre (delete, create, role assignment). Nao ha aggregation nem lookback — ou o evento aconteceu ou nao.

1. Em **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: selecione **sua subscription** inteira (para cobrir todas as semanas)

   > Ao usar a subscription como scope, o alerta cobre VMs de **todos** os resource groups. Se voce usasse um RG especifico, so cobriria VMs naquele RG.

3. Aba **Condition**: clique em **See all signals**

4. Filtre: **Signal type = Activity Log**

5. Selecione **Delete Virtual Machine (Microsoft.Compute/virtualMachines)**

6. Configure:

   | Setting            | Value                      |
   | ------------------ | -------------------------- |
   | Chart period       | **Over the last 6 hours**  |
   | Event level        | **Informational** (ou All) |
   | Status             | **All**                    |
   | Event initiated by | *(deixe em branco)*        |

7. Clique em **Next: Actions** > selecione **ag-contoso-ops**

8. Aba **Details**:

   | Setting         | Value                          |
   | --------------- | ------------------------------ |
   | Severity        | **1 - Error**                  |
   | Alert rule name | `alert-vm-delete`              |
   | Description     | `Alert when any VM is deleted` |
   | Resource group  | `rg-contoso-management`        |

9. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de Activity Log monitoram operacoes de controle (create, delete, update) ao inves de metricas. Sao uteis para auditoria e compliance. Diferente de alertas de metrica, nao usam aggregation — disparam quando o evento ocorre. Activity Log alerts sao **gratuitos** (nao ha cobranca por alert rule de Activity Log).

   > **Conexao com Semanas 1-2:** Este alerta protege VMs de **todas** as semanas. Se alguem deletar uma VM (seja da Semana 2 ou qualquer outra), voce sera notificado imediatamente.

---

### Task 4.5: Disparar alerta de CPU (teste)

Voce gera carga na VM para testar o alerta de CPU. Este e um passo importante — testar alertas em ambientes de lab garante que, em producao, voce vai receber as notificacoes quando precisar.

1. Navegue para **vm-web-01** > **Operations** > **Run command** > **RunPowerShellScript**

2. Execute o seguinte script para gerar carga de CPU:

   ```powershell
   # Gera carga de CPU por 5 minutos
   $duration = 300
   $end = (Get-Date).AddSeconds($duration)
   while ((Get-Date) -lt $end) {
       [Math]::Sqrt(rand)
   }
   ```

   > **Run Command** permite executar scripts dentro da VM sem precisar de RDP. O Azure envia o script via extensao de VM. O script acima faz calculos matematicos em loop para consumir CPU por 5 minutos.

3. **Nao aguarde** o script terminar — va para o proximo passo

4. Navegue para **Monitor** > **Alerts**

5. Aguarde 5-10 minutos e verifique se o alerta de CPU disparou

6. Verifique seu email — voce deve receber a notificacao do Action Group

7. Clique no alerta para ver detalhes: metrica, threshold, timestamp

   > **Nota:** O alerta pode levar alguns minutos para avaliar e disparar. Se nao receber em 10 minutos, verifique a configuracao da alert rule e se a VM realmente atingiu 80% de CPU (pode ser que a VM tenha mais capacidade do que o script consome).

---

### Task 4.6: Explorar Azure Monitor Dashboard

O Azure Monitor e o hub central de observabilidade. Aqui voce tem visao consolidada de metricas, alertas, logs e saude dos servicos. Vale a pena conhecer cada blade para saber onde procurar informacoes durante troubleshooting.

1. Pesquise e selecione **Monitor**

2. Explore os blades:

   | Blade                   | Descricao                                    |
   | ----------------------- | -------------------------------------------- |
   | **Overview**            | Resumo de alertas, metricas e servico health |
   | **Activity Log**        | Operacoes de controle em todos os recursos   |
   | **Alerts**              | Alertas ativos e historico                   |
   | **Metrics**             | Explorer de metricas interativo              |
   | **Diagnostic settings** | Configuracao de envio de logs/metricas       |
   | **Service Health**      | Status dos servicos Azure na sua regiao      |

   > **Activity Log** vs **Alerts** vs **Metrics** — sao 3 fontes de dados diferentes: Activity Log registra QUEM fez O QUE (operacoes de controle). Metrics mostra COMO o recurso esta se comportando (numeros). Alerts notifica quando algo precisa de atencao (regras configuradas por voce).

3. Em **Alerts**, revise os alertas disparados e resolvidos

4. Em **Activity Log**, filtre por **Resource group = rg-contoso-compute** para ver operacoes nas VMs da Semana 2

   > **Conexao com Semanas 1-2:** O Activity Log mostra TODAS as operacoes feitas desde a Semana 1: criacao de VNets, deploy de VMs, atribuicao de RBAC, aplicacao de policies, habilitacao de backup, etc.

---

### Task 4.6b: Criar alerta de Service Health

Service Health monitora a saude da **plataforma Azure** — nao dos seus recursos. Ele notifica sobre outages, manutencoes planejadas e mudancas que podem afetar seus servicos. E diferente dos alertas de metrica, que monitoram a performance dos seus recursos.

**Analogia:** Alertas de metrica monitoram se **sua casa** esta com problemas (vazamento, queda de energia). Service Health monitora se **a cidade** esta com problemas (apagao na regiao, obras na rua).

1. Pesquise e selecione **Monitor** > **Service Health**

2. Clique em **Health alerts** > **+ Create service health alert**

3. Configure:

   | Setting      | Value                                                            |
   | ------------ | ---------------------------------------------------------------- |
   | Subscription | *sua subscription*                                               |
   | Services     | **Virtual Machines**, **Storage Accounts**, **Virtual Networks** |
   | Regions      | **East US**                                                      |
   | Event types  | **Service issue**, **Planned maintenance**                       |

   > Voce seleciona apenas os servicos e regioes que usa. Nao faz sentido receber alertas de servicos que voce nao utiliza ou de regioes onde nao tem recursos.

4. Clique em **Actions** > selecione **ag-contoso-ops**

5. Aba **Details**:

   | Setting         | Value                   |
   | --------------- | ----------------------- |
   | Alert rule name | `alert-service-health`  |
   | Resource group  | `rg-contoso-management` |

6. Clique em **Create alert rule**

   > **Conceito:** Service Health monitora 4 tipos de eventos: **Service issues** (outages que afetam sua regiao/servico), **Planned maintenance** (manutencoes agendadas pela Microsoft), **Health advisories** (mudancas que requerem acao, como deprecacao de features) e **Security advisories** (notificacoes de seguranca). Diferente de alertas de metrica, Service Health alerts sao **gratuitos**.

   > **Dica AZ-104:** Na prova, Service Health e frequentemente testado. Saiba que Service Health alerts so monitoram eventos da **plataforma Azure** (nao metricas dos seus recursos). Para monitorar CPU, memoria, etc., use alertas de metrica. Service Health + Action Group = notificacao automatica quando Azure tem problemas na sua regiao.

---

## Modo Desafio - Bloco 4

- [ ] Explorar metricas de CPU, Network In/Out da `vm-web-01` **(Semana 2)**
- [ ] Criar Action Group `ag-contoso-ops` com email (+ SMS opcional)
- [ ] Criar alerta de metrica: CPU > 80% na `vm-web-01` → `ag-contoso-ops`
- [ ] Criar alerta com Dynamic Threshold (CPU) na `vm-web-01` → `ag-contoso-ops`
- [ ] Criar alerta de Activity Log: VM deletada (subscription scope) → `ag-contoso-ops`
- [ ] **Integracao:** Gerar carga de CPU na VM → verificar alerta disparado → checar email
- [ ] Criar alerta de Service Health para VMs, Storage e VNets (East US) → `ag-contoso-ops`
- [ ] Explorar Azure Monitor: Activity Log, Alerts, Service Health

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa ser notificado quando a CPU de uma VM exceder 90% por mais de 10 minutos. Qual tipo de alerta e configuracao voce deve usar?**

A) Activity Log alert com filtro de CPU
B) Metric alert com Static threshold, aggregation Average, lookback period 10 minutes
C) Log query alert com KQL
D) Service Health alert

<details>
<summary>Ver resposta</summary>

**Resposta: B) Metric alert com Static threshold, aggregation Average, lookback period 10 minutes**

Alertas de metrica com static threshold sao ideais para monitorar limites conhecidos. Configure: metric = Percentage CPU, aggregation = Average, operator = Greater than, threshold = 90, lookback period = 10 minutes. Activity Log alerts monitoram operacoes, nao metricas.

</details>

### Questao 4.2
**Qual a diferenca entre um alerta de metrica e um alerta de Activity Log?**

A) Alertas de metrica monitoram performance, alertas de Activity Log monitoram operacoes de controle
B) Ambos monitoram a mesma coisa, mas com syntaxes diferentes
C) Alertas de Activity Log sao mais rapidos que alertas de metrica
D) Alertas de metrica requerem Log Analytics, Activity Log nao

<details>
<summary>Ver resposta</summary>

**Resposta: A) Alertas de metrica monitoram performance, alertas de Activity Log monitoram operacoes de controle**

- **Metric alerts:** Monitoram metricas numericas (CPU, memoria, latencia, throughput)
- **Activity Log alerts:** Monitoram operacoes de gerenciamento (create, delete, update, role assignments)
- **Log alerts:** Monitoram logs usando queries KQL (Bloco 5)

</details>

### Questao 4.3
**Um Action Group tem email e SMS configurados. Um alerta dispara. Quantas notificacoes sao enviadas?**

A) Apenas email (SMS e fallback)
B) Apenas SMS (mais rapido)
C) Ambos: email E SMS sao enviados simultaneamente
D) O usuario escolhe qual receber no momento do alerta

<details>
<summary>Ver resposta</summary>

**Resposta: C) Ambos: email E SMS sao enviados simultaneamente**

Todas as notificacoes e acoes configuradas em um Action Group sao executadas em paralelo quando um alerta dispara. Email, SMS, push, voice, webhooks, Azure Functions — todos sao acionados simultaneamente.

</details>

### Questao 4.4
**Voce quer criar um alerta que detecte automaticamente padroes anomalos de CPU, sem definir um threshold fixo. Que tipo de threshold voce deve usar?**

A) Static threshold com valor muito alto
B) Dynamic threshold (baseline automatico via ML)
C) Nao e possivel sem threshold fixo
D) Log query com anomaly detection

<details>
<summary>Ver resposta</summary>

**Resposta: B) Dynamic threshold (baseline automatico via ML)**

Dynamic thresholds usam machine learning para aprender o padrao historico da metrica e detectar desvios. Nao requerem que voce defina um valor fixo — o Azure determina automaticamente o que e "normal" e alerta quando detecta anomalias.

</details>

---
