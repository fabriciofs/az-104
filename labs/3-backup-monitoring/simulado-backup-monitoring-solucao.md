# Gabarito — Simulado AZ-104 Backup, Recovery e Monitoramento

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `simulado-backup-monitoring.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Backup e Protecao de Dados

### Q1.1 — Recovery Services Vault

**Resposta: A) Recovery Services Vault**

O **Recovery Services Vault (RSV)** e o recurso correto para backup de VMs Azure e Azure File Shares. O RSV suporta backup de VMs Azure, SQL Server em VMs Azure, Azure Files e SAP HANA. O Backup Vault e um recurso mais recente com escopo diferente, e o Key Vault serve para armazenar segredos, chaves e certificados — nao tem relacao com backup de workloads.

**Por que os outros estao errados:**
- **B) Backup Vault** — Backup Vault e mais recente e suporta workloads diferentes: Azure Blobs, Azure Disks e Azure Database for PostgreSQL. Nao suporta backup de VMs Azure nem Azure File Shares.
- **C) Key Vault** — Key Vault e para gerenciamento de segredos, chaves de criptografia e certificados. Nao tem nenhuma funcionalidade de backup de workloads.
- **D) Storage Account** — Storage Account armazena dados, mas nao oferece funcionalidade nativa de backup com politicas de retencao, agendamento e restauracao.

**[GOTCHA]** RSV ≠ Backup Vault. Sao recursos diferentes com workloads diferentes. RSV = VMs, SQL, File Shares. Backup Vault = Blobs, Disks, PostgreSQL. No exame, preste atencao em QUAL workload precisa de backup para escolher o vault correto.

**Referencia no lab:** Bloco 1 — Task 1.1

---

### Q1.2 — Backup Policy

**Resposta:**

Configurar uma **LongTermRetentionPolicy** com as seguintes retencoes:

| Nivel | Retencao | Detalhe |
|-------|----------|---------|
| **Daily** | 30 dias | `retentionDuration: 30 Days` — backup diario mantido por 30 dias |
| **Weekly** | 12 semanas | `retentionDuration: 12 Weeks`, `daysOfTheWeek: Sunday` — ponto semanal aos domingos |
| **Monthly** | 12 meses | `retentionDuration: 12 Months` — ponto mensal mantido por 1 ano |
| **Yearly** | 7 anos | `retentionDuration: 7 Years`, `monthsOfYear: January` — ponto anual em janeiro |

A politica deve definir o `scheduleRunTimes` (horario do backup diario) e cada nivel de retencao preserva o ponto de recuperacao correspondente pelo tempo especificado.

**[GOTCHA]** Retencao anual de 7 anos requer **GRS (Geo-Redundant Storage)** no vault para compliance. LRS (Locally Redundant Storage) nao protege contra desastre regional. Se a questao mencionar compliance de longo prazo ou regulatorio, a resposta quase sempre envolve GRS.

**Referencia no lab:** Bloco 1 — Task 1.2

---

### Q1.3 — Soft Delete

**Resposta: B) 14 dias**

Por padrao, o **soft delete** para backup de VMs mantem os dados de backup por **14 dias adicionais** apos a exclusao. Durante esse periodo, os dados ficam em estado "soft deleted" e podem ser recuperados sem custo adicional. O periodo pode ser configurado de 1 a 180 dias.

**Por que os outros estao errados:**
- **A) 7 dias** — Nao e o padrao. 7 dias e o padrao de soft delete para Azure Key Vault (minimo), nao para backup de VMs.
- **C) 30 dias** — Nao e o padrao para soft delete de backup. 30 dias e a retencao padrao de daily backup, nao de soft delete.
- **D) 90 dias** — Nao corresponde a nenhum padrao de soft delete no Azure Backup.

**[GOTCHA]** Soft delete para backup ≠ soft delete para blobs. Sao features completamente diferentes com retencoes diferentes. Soft delete para blobs (Storage Account) tem padrao de 7 dias. Soft delete para backup de VMs tem padrao de 14 dias. No exame, identifique QUAL soft delete a questao esta perguntando.

**Referencia no lab:** Bloco 1 — Task 1.5

---

### Q1.4 — File Share Restore

**Resposta:**

Usar **Item Level Recovery (ILR)** — na pagina de backup do file share no Recovery Services Vault, selecionar o recovery point desejado, escolher **"File Recovery"** e selecionar apenas o arquivo necessario para restauracao. Isso e significativamente mais eficiente do que restaurar os 500 GB inteiros do file share.

**Passos detalhados:**
1. Navegar ate o Recovery Services Vault > Backup Items > Azure Storage (Azure Files)
2. Selecionar o file share protegido
3. Clicar em **Restore File** (nao "Restore Share")
4. Selecionar o recovery point desejado
5. Navegar ate o arquivo especifico e seleciona-lo
6. Escolher restaurar para o local original (overwrite) ou local alternativo

**Por que os outros estao errados:**
- **Full Share Restore** — Restaurar os 500 GB inteiros para recuperar um unico arquivo e ineficiente, demorado e desperdiça recursos.
- **Criar novo file share e copiar** — Desnecessario quando ILR esta disponivel.
- **Usar AzCopy do snapshot** — Possivel mas mais complexo que a solucao nativa do portal.

**[GOTCHA]** File share backup usa **share snapshots** por baixo. ILR permite restaurar arquivos individuais sem restaurar o share inteiro. No exame, se a questao pede restauracao de UM arquivo de um file share grande, a resposta e sempre Item Level Recovery.

**Referencia no lab:** Bloco 2 — Task 2.4

---

### Q1.5 — Versioning

**Resposta: B) Nao**

**Soft delete** protege **APENAS contra delecao**. Quando um blob e deletado, soft delete mantem uma versao "soft deleted" que pode ser recuperada. Porem, quando um blob e **sobrescrito (overwrite)**, soft delete **NAO** preserva a versao anterior. A versao antiga e simplesmente substituida pela nova sem possibilidade de recuperacao.

Para proteger contra sobrescrita, e necessario habilitar **Blob Versioning**. O versioning mantem automaticamente todas as versoes anteriores de um blob, permitindo restaurar qualquer versao historica.

**Por que os outros estao errados:**
- **A) Sim** — Incorreto. Soft delete nao protege contra sobrescrita, apenas contra delecao.

**[GOTCHA]** Soft delete = protetor de **delecao**. Versioning = protetor de **sobrescrita**. Sao features **complementares**, nao substitutas. Para protecao completa de dados, habilite AMBOS. No exame, leia com atencao se o cenario e de delecao acidental ou sobrescrita acidental — a resposta e diferente.

**Referencia no lab:** Bloco 2 — Tasks 2.2 e 2.3

---

### Q1.6 — Cross Region Restore

**Resposta: B) Cross Region Restore (CRR)**

O **Cross Region Restore (CRR)** e a feature que permite restaurar backups na regiao secundaria (paired region). GRS (Geo-Redundant Storage) por si so **replica os dados** para a regiao secundaria, mas **NAO permite que voce restaure diretamente** a partir da copia secundaria. CRR e uma feature **adicional** que precisa ser habilitada no vault que ja esta configurado com GRS.

**Por que os outros estao errados:**
- **A) GRS sozinho** — GRS replica os dados para a regiao secundaria mas nao habilita restauracao na secundaria. Sem CRR, voce so consegue restaurar na regiao primaria.
- **C) LRS com Azure Site Recovery** — LRS e local, nao replica para outra regiao. ASR e para disaster recovery de VMs, nao para restauracao de backups.
- **D) ZRS** — ZRS (Zone-Redundant Storage) replica dados entre availability zones na MESMA regiao. Nao protege contra falha regional.

**[GOTCHA]** GRS sozinho replica dados mas **nao habilita restore na secundaria**. CRR e uma feature ADICIONAL que precisa ser explicitamente habilitada no vault com GRS. No exame, se a questao pergunta "restaurar backup na regiao secundaria", a resposta e CRR — nao basta ter GRS.

**Referencia no lab:** Bloco 1 — Task 1.1

---

## Secao 2 — Azure Site Recovery

### Q2.1 — RPO/RTO

**Resposta:**

**1. RPO (Recovery Point Objective) = 1 hora:**
- RPO define a **perda maxima aceitavel de dados**. Com RPO de 1 hora, o ultimo ponto de recuperacao tem no maximo 1 hora de atraso em relacao ao momento da falha. Ou seja, no pior cenario, perde-se ate 1 hora de dados.

**2. RTO (Recovery Time Objective) = 4 horas:**
- RTO define o **tempo maximo para restaurar o servico**. Do momento da falha ate o servico estar operacional novamente, o tempo nao pode exceder 4 horas.

**3. Solucao Azure:**
- **Azure Site Recovery (ASR)** com replication policy configurada para:
  - **Recovery point retention:** adequado ao RPO (manter pontos de recuperacao suficientes)
  - **App-consistent snapshot frequency:** configurado para garantir pontos consistentes com a aplicacao
  - **Replication frequency:** a cada 5 minutos (crash-consistent), com app-consistent snapshots conforme necessidade

**Por que os outros estao errados:**
- **Azure Backup sozinho** — Azure Backup tem RPO minimo de 1 dia (backup diario). Nao atende RPO de 1 hora.
- **Manual VM copy** — Nao atende nenhum dos requisitos de forma automatizada e confiavel.

**[GOTCHA]** RPO = quanto dados voce pode **perder**. RTO = quanto tempo voce pode ficar **fora do ar**. Sao metricas independentes. No exame, nao confunda os dois. RPO e sobre dados, RTO e sobre disponibilidade.

**Referencia no lab:** Bloco 3 — Tasks 3.1 e 3.2

---

### Q2.2 — Test Failover

**Resposta: B) Continua rodando normalmente**

O **test failover** cria VMs de teste na regiao secundaria em uma rede isolada, sem afetar a VM de producao nem a replicacao ativa. A VM original continua rodando normalmente na regiao primaria, e a replicacao para a regiao secundaria continua ativa sem interrupcao.

**Por que os outros estao errados:**
- **A) VM de producao e desligada** — Incorreto. Test failover e NAO destrutivo. A VM de producao nao e afetada de nenhuma forma.
- **C) Replicacao e pausada** — Incorreto. A replicacao continua ativa durante o test failover.
- **D) Dados sao perdidos** — Incorreto. Test failover usa uma copia dos dados replicados, nao afeta os dados originais.

**[GOTCHA]** Test failover e **NAO destrutivo**. A VM de producao e a replicacao nao sao afetadas. Sempre faca test failover em **rede isolada** para evitar conflito de IP com as VMs de producao. No exame, test failover = seguro, sem impacto em producao.

**Referencia no lab:** Bloco 3 — Task 3.3

---

### Q2.3 — Failover

**Resposta:**

**1. Tipo de failover quando a regiao primaria cai sem aviso:**
- **Unplanned failover (forced)** — nao ha tempo para sincronizar dados pendentes. O failover e iniciado manualmente pelo administrador a partir do Recovery Services Vault.

**2. Impacto na integridade dos dados:**
- Se a replicacao nao estava totalmente sincronizada no momento da falha, **pode haver perda de dados** ate o ultimo recovery point disponivel. A perda maxima de dados e determinada pelo RPO configurado.

**3. Processo de failback (retorno a regiao original):**
1. **Re-proteger (re-protect)** as VMs na nova regiao primaria (a que assumiu apos o failover) — isso inicia a replicacao reversa, de volta para a regiao original
2. **Aguardar** a replicacao reversa sincronizar completamente
3. **Executar planned failover** de volta para a regiao original — planned failover garante zero perda de dados porque sincroniza antes de alternar
4. **Re-proteger novamente** para restabelecer a replicacao normal

**[GOTCHA]** Apos failover, voce **PRECISA re-proteger (re-protect)** as VMs. Sem isso, nao ha replicacao de volta e voce fica sem protecao de DR. No exame, a sequencia e sempre: failover → re-protect → failback → re-protect.

**Referencia no lab:** Bloco 3 — Tasks 3.3-3.5

---

### Q2.4 — Recovery Points

**Resposta: B) 6**

Com app-consistent snapshots configurados a cada **4 horas** e recovery point retention de **24 horas**, o calculo e:

24 horas / 4 horas de intervalo = **6 recovery points** app-consistent

Alem desses 6 pontos app-consistent, o ASR tambem cria recovery points **crash-consistent** a cada **5 minutos** por padrao, mas a questao pergunta especificamente sobre app-consistent.

**Por que os outros estao errados:**
- **A) 4** — Calculo incorreto. Nao corresponde a nenhuma divisao valida dos parametros fornecidos.
- **C) 12** — Seria o resultado se o intervalo fosse de 2 horas, nao 4.
- **D) 24** — Seria o resultado se houvesse um snapshot app-consistent por hora, nao a cada 4 horas.

**[GOTCHA]** App-consistent snapshots usam **VSS (Volume Shadow Copy Service)** no Windows ou **scripts pre/post** no Linux. Garantem consistencia da aplicacao (ex: banco de dados em estado valido). Crash-consistent = estado do disco no momento exato, como se desligasse o PC na tomada — a aplicacao pode precisar de recovery ao iniciar. No exame, saiba a diferenca entre os dois tipos.

**Referencia no lab:** Bloco 3 — Task 3.1

---

## Secao 3 — Azure Monitor e Alertas

### Q3.1 — Alert Type

**Resposta: A) Metric alert**

Para monitorar metricas numericas com threshold (ex: CPU > 80%), o tipo correto e **metric alert**. Metric alerts avaliam metricas da plataforma Azure em intervalos regulares e disparam quando o threshold e atingido. Sao ideais para metricas simples e numericas como CPU, memoria, disco e rede.

**Por que os outros estao errados:**
- **B) Log alert** — Log alerts sao baseados em queries **KQL (Kusto Query Language)** executadas no Log Analytics. Sao usados para analises complexas que combinam multiplas fontes de dados ou requerem logica avancada. Para uma metrica simples como CPU > 80%, um log alert e desnecessariamente complexo.
- **C) Activity log alert** — Activity log alerts monitoram **eventos administrativos** (ex: VM deletada, role assigned, resource created). Nao monitoram metricas de performance.
- **D) Smart detection alert** — Smart detection e uma feature do Application Insights para deteccao automatica de anomalias em aplicacoes web, nao para metricas de infraestrutura.

**[GOTCHA]** Metric alerts avaliam a cada **1-5 minutos**. Log alerts avaliam a cada **5-15 minutos**. Para metricas simples com threshold, metric alert e mais rapido e mais eficiente. No exame, se a questao menciona threshold numerico simples (CPU, memoria, disco), a resposta e metric alert.

**Referencia no lab:** Bloco 4 — Task 4.2

---

### Q3.2 — Action Groups

**Resposta:**

Criar **2 action groups** com a seguinte configuracao:

**1. AG-SRE (Time SRE):**
- **Email receivers:** enderecos de email de cada membro do time SRE
- **SMS receivers:** numeros de telefone do time SRE para alertas criticos
- **Webhook action** (ou **ITSM action**): apontando para o endpoint do ServiceNow para criar tickets automaticamente

**2. AG-Director (Dra. Patricia):**
- **Email receiver:** endereco de email da Dra. Patricia

**3. Integracao com ServiceNow:**
- Adicionar uma **ITSM action** ou **Webhook action** no AG-SRE apontando para o endpoint do ServiceNow
- A ITSM action tem integracao nativa com ServiceNow, BMC, Provance e Cherwell
- A Webhook action envia um HTTP POST com o payload do alerta para qualquer endpoint REST

**Configuracao da alert rule:**
- Associar **ambos** os action groups (AG-SRE e AG-Director) a mesma alert rule
- Quando o alerta disparar, ambos os groups sao notificados simultaneamente

**[GOTCHA]** Um alert rule pode ter **multiplos action groups**. Cada action group pode ter **multiplos receivers** de tipos diferentes (email, SMS, webhook, Azure Function, Logic App, ITSM). No exame, nao confunda action group com receiver — um action group e um CONJUNTO de receivers.

**Referencia no lab:** Bloco 4 — Task 4.3

---

### Q3.3 — Diagnostic Settings

**Resposta:**

Possiveis causas para dados nao aparecerem no Log Analytics apos 1 hora de configuracao:

**1. Azure Monitor Agent nao instalado na VM:**
- Diagnostic Settings para **VMs** requer que o **Azure Monitor Agent (AMA)** esteja instalado na VM. Sem o agente, os dados de performance e logs do sistema operacional nao sao coletados.

**2. Workspace ID ou Key incorretos:**
- Se o agente foi instalado manualmente, o Workspace ID ou a Workspace Key podem estar incorretos na configuracao do agente, impedindo o envio de dados.

**3. Network Security Group bloqueando trafego:**
- O NSG associado a subnet ou NIC da VM pode estar bloqueando o trafego de saida para o endpoint do Log Analytics (`*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, porta 443).

**4. Data Collection Rule (DCR) nao configurada ou nao associada:**
- Com o AMA, e necessario criar uma **Data Collection Rule** que defina quais dados coletar e para qual workspace enviar. Se a DCR nao estiver associada a VM, nenhum dado sera coletado.

**5. Tempo de ingestao:**
- Dados podem levar ate **10-15 minutos** para aparecer no Log Analytics. Se apos 1 hora nao aparecem, ha um problema real na configuracao.

**[GOTCHA]** Diagnostic Settings para **VMs** requer agente. Para **outros recursos** (NSG, Storage Account, Key Vault, etc.), Diagnostic Settings funciona **sem agente** — os dados sao enviados diretamente pela plataforma Azure. No exame, distinga entre recursos que precisam de agente (VMs) e recursos que nao precisam (PaaS).

**Referencia no lab:** Bloco 4 — Task 4.5

---

### Q3.4 — Dashboard Sharing

**Resposta: A) Reader**

Para visualizar um dashboard compartilhado no Azure, a permissao minima necessaria e **Reader** no recurso do dashboard. O role Reader permite ver o dashboard e seus tiles, mas nao permite editar, mover ou excluir o dashboard.

**Por que os outros estao errados:**
- **B) Contributor** — Contributor permite editar o dashboard. E mais permissao do que o necessario para apenas visualizar.
- **C) Owner** — Owner inclui todas as permissoes de Contributor mais a capacidade de gerenciar acesso (RBAC). Excessivo para visualizacao.
- **D) Monitoring Reader** — Monitoring Reader da acesso a dados de monitoramento, mas nao necessariamente ao dashboard como recurso Azure.

**[GOTCHA]** Dashboards sao **recursos Azure** com RBAC proprio. Compartilhar um dashboard envolve: 1) **Publicar** o dashboard no resource group, 2) Dar **Reader** no recurso do dashboard, 3) Dar **Reader** nos **recursos subjacentes** que alimentam os tiles do dashboard. Sem permissao nos recursos subjacentes, os tiles mostrarao "access denied" mesmo com acesso ao dashboard.

**Referencia no lab:** Bloco 4 — Task 4.4

---

## Secao 4 — Log Analytics e Insights

### Q4.1 — KQL

**Resposta: A)** `Perf | where TimeGenerated > ago(30m) | where CounterName == "% Processor Time" | top 10 by CounterValue`

A tabela **Perf** contem dados de performance coletados pelo agente (CPU, memoria, disco, rede). O filtro `CounterName == "% Processor Time"` seleciona apenas a metrica de CPU. O operador `top 10 by CounterValue` ordena por valor decrescente e retorna os 10 maiores.

**Por que os outros estao errados:**
- **B)** `Event | where ...` — A tabela Event contem Windows Event Logs, nao metricas de performance.
- **C)** `Heartbeat | where ...` — A tabela Heartbeat contem dados de disponibilidade (se a VM esta online ou offline), nao metricas de CPU.
- **D)** `InsightsMetrics | where ...` — Embora InsightsMetrics contenha metricas de performance, a sintaxe dos campos e diferente (usa `Name` e `Val` em vez de `CounterName` e `CounterValue`), e a query apresentada usa a sintaxe da tabela Perf.

**[GOTCHA]** Tabelas KQL importantes para o exame: **Perf** (performance counters), **Event** (Windows Event Logs), **Syslog** (Linux logs), **Heartbeat** (disponibilidade/heartbeat do agente), **InsightsMetrics** (VM Insights metrics). No exame, saiba qual tabela contem qual tipo de dado.

**Referencia no lab:** Bloco 5 — Task 5.3

---

### Q4.2 — Agent

**Resposta: B) Azure Monitor Agent (AMA)**

O **Azure Monitor Agent (AMA)** e o agente unificado recomendado pela Microsoft para coleta de dados de monitoramento. Ele substitui todos os agentes legados (MMA/Log Analytics Agent, Diagnostics Extension, Telegraf) em uma unica solucao.

**Por que os outros estao errados:**
- **A) MMA (Microsoft Monitoring Agent / Log Analytics Agent)** — O MMA esta **deprecated desde agosto de 2024**. Embora ainda funcione, nao deve ser usado em novas implantacoes. A Microsoft recomenda migrar para AMA.
- **C) Diagnostics Extension (WAD/LAD)** — Extensions legadas para coletar metricas e logs de VMs. Tambem estao sendo substituidas pelo AMA.
- **D) Dependency Agent sozinho** — O Dependency Agent e um agente **complementar** que coleta dados de dependencia de rede para VM Insights Map. Ele NAO substitui o AMA — ele funciona **junto** com o AMA.

**[GOTCHA]** MMA esta deprecated desde agosto 2024. Migre para AMA. A principal diferenca: MMA usa configuracao no workspace (centralizada). AMA usa **Data Collection Rules (DCR)** — regras granulares que definem quais dados coletar e para onde enviar. DCR permite enviar dados para multiplos destinos e configurar coleta por VM.

**Referencia no lab:** Bloco 5 — Task 5.2

---

### Q4.3 — VM Insights

**Resposta:**

**1. O que VM Insights monitora:**
- **Performance:** CPU, memoria, disco (IOPS, throughput, latencia), rede (bytes enviados/recebidos)
- **Processos em execucao:** lista de processos rodando na VM com uso de recursos
- **Dependencias de rede:** mapa visual de conexoes de rede entre processos da VM e endpoints externos (outras VMs, servicos, IPs)

**2. Agentes necessarios:**
- **Azure Monitor Agent (AMA)** — agente principal para coleta de metricas e logs
- **Dependency Agent** — agente complementar para coleta de dados de dependencia de rede (processos, conexoes TCP, portas)

**3. Diferenca entre as views:**
- **Performance view:** graficos de metricas de performance ao longo do tempo (CPU, memoria, disco, rede). Mostra tendencias, picos e baselines. Requer apenas o AMA.
- **Map view:** mapa visual interativo mostrando processos em execucao na VM e todas as conexoes de rede (entrada e saida) com outros sistemas. Requer AMA **+ Dependency Agent**.

**[GOTCHA]** VM Insights Map requer **Dependency Agent ALEM do AMA**. Se so instalar AMA, tera apenas a **Performance view**. A **Map view** ficara indisponivel. No exame, se a questao pede "visualizar dependencias de rede" ou "mapa de conexoes", a resposta sempre inclui Dependency Agent.

**Referencia no lab:** Bloco 5 — Task 5.4

---

### Q4.4 — Network Watcher

**Resposta:**

**1. Ferramenta para diagnosticar conectividade:**
- **Connection Troubleshoot** (ou **IP Flow Verify**) — testa conectividade TCP/ICMP entre a VM e o endpoint externo na porta 443.

**2. O que a ferramenta retorna:**
- **Status:** Reachable ou Unreachable
- **Latencia:** tempo de round-trip em milissegundos
- **Hops:** caminho de rede percorrido (similar a traceroute)
- **Componente bloqueador:** se unreachable, identifica qual componente esta bloqueando (NSG, UDR, firewall, etc.)

**3. Para verificar regras NSG:**
- **NSG Flow Logs** — registram todo o trafego permitido e negado por NSGs. Permitem analise retroativa de quais fluxos foram bloqueados ou permitidos.
- **NSG Diagnostics** — verifica se uma combinacao especifica de IP/porta/protocolo seria permitida ou negada pelas regras NSG atuais, sem precisar enviar trafego real.

**Diferenca entre as ferramentas:**
| Ferramenta | Uso | Escopo |
|-----------|------|--------|
| **IP Flow Verify** | Checa uma unica regra NSG para um fluxo especifico | Pontual (uma regra) |
| **Connection Troubleshoot** | Teste completo de conectividade end-to-end | Amplo (todo o caminho) |
| **NSG Flow Logs** | Log historico de todo trafego NSG | Historico (retroativo) |
| **NSG Diagnostics** | Simula fluxo contra todas as regras NSG | Simulacao (sem trafego real) |

**[GOTCHA]** Network Watcher e **por regiao**. Verifique se esta habilitado na regiao das VMs. IP Flow Verify checa uma **unica regra NSG**. Connection Troubleshoot faz **teste completo de conectividade** end-to-end. No exame, se pede diagnostico pontual de NSG, use IP Flow Verify. Se pede diagnostico completo de conectividade, use Connection Troubleshoot.

**Referencia no lab:** Bloco 5 — Task 5.6

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Peso Estimado no Exame |
|---------|----------------|----------------------|
| Q1.1 | Monitor and back up Azure resources | ~10-15% |
| Q1.2 | Monitor and back up Azure resources | ~10-15% |
| Q1.3 | Monitor and back up Azure resources | ~10-15% |
| Q1.4 | Monitor and back up Azure resources | ~10-15% |
| Q1.5 | Monitor and back up Azure resources | ~10-15% |
| Q1.6 | Monitor and back up Azure resources | ~10-15% |
| Q2.1 | Implement backup and recovery (ASR) | ~10-15% |
| Q2.2 | Implement backup and recovery (ASR) | ~10-15% |
| Q2.3 | Implement backup and recovery (ASR) | ~10-15% |
| Q2.4 | Implement backup and recovery (ASR) | ~10-15% |
| Q3.1 | Monitor resources by using Azure Monitor | ~10-15% |
| Q3.2 | Monitor resources by using Azure Monitor | ~10-15% |
| Q3.3 | Monitor resources by using Azure Monitor | ~10-15% |
| Q3.4 | Monitor resources by using Azure Monitor | ~10-15% |
| Q4.1 | Monitor resources by using Azure Monitor | ~10-15% |
| Q4.2 | Monitor resources by using Azure Monitor | ~10-15% |
| Q4.3 | Monitor resources by using Azure Monitor | ~10-15% |
| Q4.4 | Monitor resources by using Azure Monitor | ~10-15% |

> **Nota:** Os dominios de Backup, Recovery e Monitoramento representam juntos cerca de 10-15% do peso do exame AZ-104. Porem, questoes de monitoramento frequentemente aparecem combinadas com outros dominios (VMs, networking, storage), tornando o conhecimento dessas ferramentas essencial para o exame como um todo.

---

## Q5.1 — Backup Vault vs Recovery Services Vault

**Resposta: B) Um novo Azure Backup Vault**

O backup de Azure Managed Disks (baseado em snapshots incrementais) e suportado pelo Backup Vault, nao pelo Recovery Services Vault. O RSV suporta backup de VMs completas (que inclui os discos como parte do snapshot de VM), mas nao backup de discos individuais. Para protecao granular de discos especificos, o Backup Vault e o recurso correto.

**Referencia no lab:** Bloco 6 — Tasks 6.3-6.5 (Backup Vault)

---

## Q5.2 — VM Move entre Resource Groups

**Resposta: B) A VM pode ser movida sem downtime — apenas o resource ID muda**

Move entre Resource Groups na mesma regiao nao requer parar a VM. O Azure atualiza o resource ID (que inclui o nome do RG no path) mas a VM continua operando. Recursos dependentes (NIC, discos, IP publico) devem ser movidos junto. O IP privado, configuracoes e dados permanecem inalterados.

**Referencia no lab:** Bloco 6 — Task 6.1 (VM Move)

---

## Q5.3 — Move entre Regioes

**Respostas:**

1. **Nao, `az resource move` NAO suporta move entre regioes para VMs.** Esse comando so funciona para moves entre RGs ou subscriptions na mesma regiao. Mover entre regioes requer recriar o recurso na regiao de destino.

2. **Azure Site Recovery (ASR)** e o servico recomendado. ASR replica a VM continuamente para a regiao de destino e permite failover controlado com minimo downtime. Alternativas incluem Azure Resource Mover e export/recreate manual via ARM template.

3. **Nao, o backup NAO e migrado automaticamente.** O RSV de East US protege recursos nessa regiao. Rafael precisara criar um novo RSV em West Europe e configurar backup para a VM na nova regiao. Backups existentes permanecem no RSV original (acessiveis para restore ate a retencao expirar).

**Referencia no lab:** Bloco 6 — Task 6.2 (Limitacoes de move entre regioes)

---

## Top 10 Gotchas — Consolidado

| # | Gotcha | Questao | Por que Pega |
|---|--------|---------|-------------|
| 1 | **RSV ≠ Backup Vault** — workloads diferentes | Q1.1 | Candidatos assumem que sao intercambiaveis |
| 2 | **Soft delete backup ≠ soft delete blobs** — retencoes diferentes | Q1.3 | Confusao entre features de nomes similares |
| 3 | **Soft delete nao protege contra sobrescrita** — so delecao | Q1.5 | Assume que soft delete protege tudo |
| 4 | **GRS sozinho nao habilita restore na secundaria** — precisa CRR | Q1.6 | Assume que replicacao = restauracao |
| 5 | **RPO ≠ RTO** — dados vs disponibilidade | Q2.1 | Confunde as duas metricas |
| 6 | **Test failover e NAO destrutivo** — producao nao e afetada | Q2.2 | Medo de testar DR por achar que afeta producao |
| 7 | **Apos failover, precisa re-protect** — sem isso, sem replicacao | Q2.3 | Esquece que failover quebra a replicacao |
| 8 | **Metric alert vs Log alert** — threshold simples vs query KQL | Q3.1 | Usa log alert para metrica simples |
| 9 | **Diagnostic Settings para VMs requer agente** — PaaS nao | Q3.3 | Assume que Diagnostic Settings funciona igual para tudo |
| 10 | **VM Insights Map requer Dependency Agent** — AMA sozinho nao basta | Q4.3 | Instala so AMA e Map view nao funciona |

---

## Proximos Passos

Apos corrigir o caso de estudo:

1. **Erros em Backup?** → Refazer Blocos 1 e 2 do lab focando em tipos de vault, politicas de retencao e soft delete
2. **Erros em Site Recovery?** → Refazer Bloco 3 focando em RPO/RTO, failover e re-protect
3. **Erros em Azure Monitor?** → Refazer Bloco 4 focando em tipos de alerta, action groups e diagnostic settings
4. **Erros em Log Analytics?** → Refazer Bloco 5 focando em KQL, agentes e VM Insights
5. **Erros em Network Watcher?** → Refazer Bloco 5 Task 5.6 focando nas ferramentas de diagnostico
6. **Score > 85%?** → Revisar simulados anteriores e consolidar conhecimento
