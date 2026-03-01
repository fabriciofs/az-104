# Gabarito — Estudo de Caso 5: Banco Horizonte Digital

> **Como usar este gabarito:**
> - Primeiro responda todas as questoes no arquivo `caso5-banco-migracao.md`
> - Depois confira aqui, questao por questao
> - Preste atencao especial nos itens marcados com **[GOTCHA]** — sao armadilhas comuns no exame
> - Para cada erro, volte ao bloco correspondente do lab e refaca o exercicio relacionado

---

## Secao 1 — Identidade e Governanca

### Q1.1 — Management Group + Policy Inheritance Bancario

**Resposta:**

**1. Nivel de atribuicao da Policy Initiative:**

Atribuir no **`BancoHorizonte-MG`** (Management Group raiz do banco). Isso garante que todas as subscriptions (Producao, Homologacao, Dev e Shared) herdem automaticamente, incluindo futuras subscriptions.

**2. Resolver conflito Allowed Locations vs DR:**

Existem duas abordagens:

**Opcao A — Policy Exemption (recomendada):**
- Manter a policy de Allowed Locations no `BancoHorizonte-MG` com apenas Brazil South
- Criar uma **Policy Exemption** (isencao) na subscription ou RG de DR com categoria **Waiver**
- Documentar a justificativa regulatoria para o waiver
- Vantagem: a policy continua enforced globalmente, com excecao explicita e auditavel

**Opcao B — Policy com lista expandida:**
- Modificar a policy para Allowed Locations = [Brazil South, South Central US]
- Desvantagem: permite que **qualquer** recurso seja criado em South Central US, nao apenas recursos de DR

**Opcao C — Estrutura de Management Groups separada:**
```
BancoHorizonte-MG (Policy: tags obrigatorias, CMK, backup)
    ├── BH-Brazil-MG (Policy: Allowed Locations = Brazil South)
    │   ├── BH-Prod-MG
    │   └── BH-NonProd-MG
    └── BH-DR-MG (Policy: Allowed Locations = South Central US)
        └── BH-DR-Sub
```
- Vantagem: separacao clara entre ambientes normais e DR
- Desvantagem: mais complexidade na hierarquia

**3. Policy conflitante na subscription:**

Azure Policy e **aditiva** — ambas as policies sao avaliadas. Se a policy do Management Group usa efeito **Deny** e a policy da subscription permite, o **Deny prevalece**. Policies mais restritivas sempre vencem, independente do nivel.

Porem, se ambas sao Deny com condicoes diferentes, ambas sao avaliadas e ambas devem ser atendidas. O resultado efetivo e a **intersecao** (a mais restritiva).

**[GOTCHA]** No exame, lembre que policies de Management Groups sao **herdadas** e nao podem ser sobrescritas por policies em niveis inferiores. O Deny no MG nao pode ser "desligado" por uma policy na subscription. A unica forma de abrir excecoes e via **Policy Exemption**.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — Policy inheritance

---

### Q1.2 — Restricoes RBAC em Multiplos Escopos

**Resposta:**

**1. Por que o peering falha:**

VNet peering requer permissao em **ambas** as VNets envolvidas:
- **VNet de origem (HubVNet):** `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write` — CloudOps tem via Network Contributor em `bh-network-rg` ✓
- **VNet de destino (AppVNet):** `Microsoft.Network/virtualNetworks/peer/action` — CloudOps **NAO tem** nenhuma permissao em `bh-app-rg` ✗

O role Network Contributor em `bh-network-rg` so cobre a HubVNet. A AppVNet esta em `bh-app-rg`, onde CloudOps nao tem permissao.

**2. Permissao minima adicional:**

Camila deve atribuir ao CloudOps pelo menos a acao `Microsoft.Network/virtualNetworks/peer/action` no `bh-app-rg`. Opcoes:

- **Rapida:** Atribuir **Network Contributor** em `bh-app-rg` (mais permissoes que o necessario)
- **Minima:** Criar um **custom role** com apenas:
  ```json
  "Actions": [
    "Microsoft.Network/virtualNetworks/peer/action",
    "Microsoft.Network/virtualNetworks/read"
  ]
  ```
  E atribuir em `bh-app-rg`

**3. DevTeam nao consegue deletar VM em Homologacao:**

DevTeam tem apenas **Reader** em BH-Homologacao-Sub. Reader permite **somente leitura** — nao permite criar, modificar ou deletar recursos. Para deletar, seria necessario pelo menos **Contributor** ou **Virtual Machine Contributor**.

O RBAC e **aditivo**: ter Contributor em Dev-Sub nao concede nada em Homologacao-Sub. Cada assignment de role e valida apenas no escopo onde foi atribuida.

**[GOTCHA]** RBAC e aditivo e escoped. Permissao em uma subscription nao se propaga para outra. Peering requer permissao em **ambos os lados** — esse gotcha aparece frequentemente no exame.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco2-governance.md` — RBAC cross-RG

---

## Secao 2 — Armazenamento

### Q2.1 — Storage Encryption com CMK (Key Vault)

**Resposta: B) O storage account precisa ter uma System-Assigned Managed Identity com permissoes de wrap/unwrap key no Key Vault**

Para que o storage account use CMK, ele precisa **acessar o Key Vault** para operacoes de criptografia. Isso requer:

1. O storage account ter uma **Managed Identity** (System-Assigned ou User-Assigned)
2. Essa Managed Identity ter **permissoes** no Key Vault:
   - **Key permissions:** Get, Wrap Key, Unwrap Key
   - Ou o **Key Vault RBAC role:** Key Vault Crypto Service Encryption User

O erro *"necessary permissions to perform wrap/unwrap"* indica que a Managed Identity nao tem as permissoes necessarias no Key Vault.

**Por que os outros estao errados:**
- **A) Soft-delete e purge protection** — Esses sao **requisitos do Key Vault** para CMK, e o Azure geralmente os habilita automaticamente ou bloqueia a configuracao se nao estiverem habilitados. Mas o erro especifico de "wrap/unwrap" indica problema de **permissao**, nao de configuracao do KV.
- **C) CMK so com Premium** — Incorreto. CMK funciona com qualquer tipo de Storage Account (Standard ou Premium).
- **D) Mesma regiao** — Recomendado para latencia, mas nao obrigatorio. CMK cross-region funciona (embora nao seja ideal).

**Nota sobre soft-delete e purge protection:** Embora nao seja a resposta desta questao, ambos **sao** pre-requisitos para configurar CMK. O Azure exige que o Key Vault tenha soft-delete habilitado e purge protection habilitado antes de configurar CMK. Se esses pre-requisitos nao estiverem atendidos, o erro seria diferente (nao mencionaria wrap/unwrap).

**[GOTCHA]** CMK = Managed Identity + Key Vault permissions. O erro de "wrap/unwrap" sempre indica problema de permissao da Managed Identity no Key Vault. No exame, se a questao menciona CMK + erro de permissao, verifique se a MI tem as key permissions corretas.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Criptografia e Key Vault

---

### Q2.2 — Replicacao Cross-Region GRS/GZRS

**Resposta:**

**1. Redundancia por storage account:**

| Storage Account | Redundancia | Justificativa |
|-----------------|-------------|---------------|
| `bhdatastorage` | **RA-GZRS** | Dados criticos de clientes: ZRS para alta disponibilidade local (3 zonas) + replicacao para regiao secundaria + **leitura** na regiao secundaria para RPO near-zero. RA permite verificar dados na secundaria sem failover. |
| `bhappstorage` | **GRS** | Binarios de aplicacao: nao requerem leitura na regiao secundaria (failover manual aceitavel). GRS e suficiente e mais economico que RA-GRS. |
| `bhlogs` | **GRS** + Immutable storage | Logs de auditoria precisam de redundancia geografica (sobreviver a desastre regional) e imutabilidade (retencao legal). GRS garante a copia na regiao pareada; immutability policy garante que logs nao sejam alterados/deletados. |

**2. GRS vs RA-GRS:**

| Aspecto | GRS | RA-GRS |
|---------|-----|--------|
| Replicacao para regiao secundaria | Sim | Sim |
| **Leitura** na regiao secundaria | **Nao** (so apos failover) | **Sim** (endpoint `-secondary`) |
| Endpoint secundario | Nao acessivel | `accountname-secondary.blob.core.windows.net` |
| Custo | Menor | Maior |
| Uso tipico | DR com failover manual | DR + leitura ativa para verificacao/backup |

RA-GRS permite que aplicacoes **leiam** da regiao secundaria sem precisar de failover. Util para cenarios onde voce quer verificar se os dados estao la, ou para distribuir leitura geograficamente.

**3. Failover de storage account:**

Quando um failover e iniciado:
- A regiao **secundaria** se torna a **primaria**
- O endpoint do storage account (`accountname.blob.core.windows.net`) **nao muda** — o DNS e atualizado automaticamente para apontar para a nova regiao primaria
- A aplicacao **nao precisa mudar** a connection string
- O storage account se torna **LRS** na nova regiao primaria (perde a redundancia geografica)
- Apos estabilizar, Camila deve reconfigurar GRS para restabelecer a redundancia

**[GOTCHA]** Apos failover, o storage account perde a redundancia geografica (vira LRS). E necessario reconfigurar GRS manualmente apos o failover. A URL nao muda — o failover e transparente para as aplicacoes.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco1-storage.md` — Redundancia de storage

---

## Secao 3 — Computacao

### Q3.1 — VM Disaster Recovery com ASR

**Resposta:**

**1. Por que a aplicacao nao conecta:**

A connection string da aplicacao tem o IP `10.2.1.4` (IP do SQL Server na producao) **hardcoded**. Na regiao de DR, a VNet tem address space diferente (10.100.0.0/16), e o SQL Server recebeu o IP `10.100.2.4`. A aplicacao tenta conectar em `10.2.1.4`, que nao existe na rede de DR.

**2. Abordagens permanentes:**

- **Opcao A (recomendada): DNS interno**
  - Usar Azure Private DNS Zone com um nome como `sqldb.bancohorizonte.internal`
  - Na producao: registro A → `10.2.1.4`
  - No failover: ASR atualiza o registro A → `10.100.2.4` (via automation runbook)
  - Aplicacao usa o hostname em vez de IP — transparente no failover

- **Opcao B: Recovery plan com custom script**
  - Configurar no ASR recovery plan um **custom script** (Azure Automation runbook) que atualiza a connection string da aplicacao apos o failover
  - Requer automacao robusta e testes

- **Opcao C: Manter mesmo IP range**
  - Configurar a VNet de DR com o **mesmo address space** da producao
  - As VMs recebem os mesmos IPs na regiao de DR
  - **Cuidado:** Os address spaces nao podem sobrepor se houver peering/conectividade entre as regioes

- **Opcao D: Load Balancer/Application Gateway**
  - Usar um balanceador que redireciona para o backend correto em cada regiao

**3. Test Failover vs Failover:**

| Aspecto | Test Failover | Failover |
|---------|---------------|----------|
| **Impacto na producao** | **Nenhum** — VMs de producao continuam rodando | VMs de producao sao **desligadas** |
| **Replicacao** | Continua normalmente | Interrompida (precisa re-proteger) |
| **VNet** | Criada em VNet de **teste isolada** | Usa VNet de **DR real** |
| **Finalidade** | Validar que o failover funciona | Failover real em caso de desastre |
| **Cleanup** | **Obrigatorio** — deve limpar as VMs de teste | Nao tem cleanup (e o novo ambiente) |

Test Failover **nao afeta a producao** porque cria VMs em uma rede isolada. E recomendado executar test failover periodicamente para validar o plano de DR.

**[GOTCHA]** IP hardcoded e uma das causas mais comuns de falha em DR. Sempre use DNS ou service discovery para comunicacao entre VMs. No exame, se a questao menciona "IP hardcoded + failover falha", a resposta envolve DNS ou automacao para atualizar IPs.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco3-site-recovery.md` — ASR e failover

---

### Q3.2 — VMSS Update Policy Rolling vs Manual

**Resposta: C) Rolling — atualiza em lotes configuraveis, com pausa entre lotes e rollback em caso de falha**

| Policy | Comportamento | Downtime | Controle |
|--------|---------------|----------|----------|
| **Manual** | Nada acontece automaticamente. Admin precisa chamar `Update-AzVmssInstance` em cada VM | Depende do admin | Total |
| **Automatic** | Atualiza todas as instancias assim que possivel | Pode causar downtime total | Nenhum |
| **Rolling** | Atualiza em **lotes** (ex: 2 VMs por vez), com pausa entre lotes | **Minimo** — sempre ha instancias saudaveis | Configuravel |

**Parametros do Rolling upgrade:**

- **Max batch percentage:** % maximo de instancias atualizadas por vez (ex: 20% = 2 de 10)
- **Pause time between batches:** Tempo de espera entre lotes (ex: 10 segundos)
- **Max unhealthy instance percentage:** Se mais que X% ficarem unhealthy, a atualizacao **para automaticamente** (rollback)
- **Max unhealthy upgraded instance percentage:** Threshold de falha por lote

**Por que os outros estao errados:**
- **A) Manual** — Requer intervencao humana para cada instancia. Nao automatiza o processo.
- **B) Automatic** — Atualiza tudo de uma vez sem controle. Pode causar indisponibilidade total se a atualizacao tiver problemas.
- **D) Blue-Green** — Nao e uma upgrade policy nativa do VMSS. E um padrao de deployment que pode ser implementado com multiplos VMSS ou usando deployment slots (App Service).

**[GOTCHA]** No exame, "atualizar sem downtime em VMSS" = Rolling upgrade policy. Manual e para controle total; Automatic e para ambientes nao-criticos; Rolling e para producao.

**Referencia no lab:** `labs/2-storage-compute/cenario/bloco2-vms.md` — VMSS upgrade policies

---

## Secao 4 — Networking

### Q4.1 — Hub-Spoke com NVA e Forced Tunneling

**Resposta:**

**1. Configurar forced tunneling:**

Camila deve criar **UDRs (User-Defined Routes)** nas subnets dos spokes (AppVNet e DataVNet) com uma rota padrao (0.0.0.0/0) apontando para o next hop no on-premises:

**Route Table nos spokes:**

| Nome | Address Prefix | Next Hop Type | Next Hop IP |
|------|---------------|---------------|-------------|
| forced-tunnel | 0.0.0.0/0 | Virtual Appliance | 10.0.2.4 (Azure Firewall) |

E no Azure Firewall, configurar uma rota para 0.0.0.0/0 com next hop **VirtualNetworkGateway** (ExpressRoute), que encaminha o trafego para o on-premises.

Alternativamente, se o ExpressRoute estiver configurado com **default route advertisement** (0.0.0.0/0 via BGP), o forced tunneling e automatico para subnets que usam o gateway.

**2. Private Endpoints com forced tunneling ativo:**

**Sim**, VMs continuam acessando Azure PaaS via Private Endpoints mesmo com forced tunneling. Isso porque:

- Private Endpoints criam IPs privados **dentro da VNet** (ex: 10.0.1.10 para Key Vault)
- O trafego para 10.0.1.10 e roteado dentro da VNet (via peering), **nao** pelo default route (0.0.0.0/0)
- O forced tunneling afeta apenas trafego com destino a **internet** (0.0.0.0/0)
- Trafego para IPs privados segue as rotas de VNet/peering, que tem precedencia sobre o default route

**3. Problema do Azure Firewall com forced tunneling:**

O Azure Firewall **precisa de acesso direto a internet** para gerenciamento (health checks, atualizacoes, logs). Com forced tunneling no subnet do Firewall, esse acesso e perdido e o Firewall fica **unhealthy**.

**Solucao:** Criar uma **Management subnet** separada para o Azure Firewall (`AzureFirewallManagementSubnet`) com uma UDR que roteia 0.0.0.0/0 para **Internet** (next hop type = Internet). Essa subnet permite que o Firewall mantenha conectividade de gerenciamento enquanto o trafego de dados segue pelo forced tunneling.

```
AzureFirewallSubnet (10.0.2.0/24)           → UDR: 0.0.0.0/0 → VirtualNetworkGateway
AzureFirewallManagementSubnet (10.0.3.0/24) → UDR: 0.0.0.0/0 → Internet
```

**[GOTCHA]** Azure Firewall com forced tunneling requer **AzureFirewallManagementSubnet**. Sem essa subnet, o Firewall perde a gestao e fica unhealthy. No exame, se a questao menciona "forced tunneling + Azure Firewall", procure a opcao que menciona a Management subnet.

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco5-routing.md` — Forced tunneling

---

### Q4.2 — ExpressRoute vs VPN Gateway

**Resposta:**

**1. Por que a VPN Gateway nao assumiu:**

Para que a VPN Gateway funcione como **failover automatico** do ExpressRoute, ambos precisam coexistir na mesma VNet e o roteamento precisa estar configurado corretamente:

Causas possiveis:
- **BGP nao esta habilitado** na VPN Gateway — sem BGP, a VPN nao anuncia/aprende rotas automaticamente
- **O weight/priority das rotas** nao esta configurado para preferir ExpressRoute e failover para VPN
- **A VPN Gateway nao tem conexao site-to-site ativa** — pode estar configurada mas nao conectada ao dispositivo on-premises
- **O ExpressRoute Circuit pode nao estar totalmente down** — se o circuito ficar em estado degradado (mas nao down), o failover pode nao ser triggerado

**2. Configurar failover automatico:**

1. **Habilitar BGP** em ambos — ExpressRoute (automatico) e VPN Gateway (configuracao manual)
2. **Configurar AS Path prepending** na VPN para que o ExpressRoute seja preferido:
   - ExpressRoute: AS Path curto (preferido)
   - VPN: AS Path mais longo (backup)
3. **Coexistence:** Ambos os gateways (ExpressRoute Gateway + VPN Gateway) devem estar na mesma VNet, no `GatewaySubnet`
4. **Testar o failover** periodicamente para validar

O fluxo:
```
Normal:     On-premises ←→ ExpressRoute (1 Gbps, AS Path curto)
Failover:   On-premises ←→ VPN Gateway (ate 1.25 Gbps, AS Path longo)
```

**3. ExpressRoute Private Peering vs Microsoft Peering:**

| Aspecto | Private Peering | Microsoft Peering |
|---------|-----------------|-------------------|
| **Conecta a** | VNets do Azure (IPs privados) | Servicos PaaS publicos (Storage, SQL, M365) |
| **IPs** | Privados (10.x, 172.x, 192.168.x) | IPs publicos da Microsoft |
| **Uso** | Acesso a VMs, Private Endpoints, VNets | Acesso a Azure Storage, Office 365, Dynamics |
| **Necessario para** | Comunicacao com VNets | Acessar PaaS sem internet |

Para acessar Azure PaaS (Storage, Key Vault) **sem** Private Endpoints, Camila precisa de **Microsoft Peering**. Porem, se usar **Private Endpoints** para esses servicos, o trafego vai por **Private Peering** (porque os Private Endpoints tem IPs privados na VNet).

**[GOTCHA]** No exame: Private Peering = VNets e IPs privados; Microsoft Peering = servicos PaaS publicos. Se a arquitetura usa Private Endpoints para PaaS, o trafego usa Private Peering (nao precisa de Microsoft Peering).

**Referencia no lab:** `labs/1-iam-gov-net/cenario/bloco5-routing.md` — ExpressRoute e VPN Gateway

---

## Secao 5 — Monitoramento

### Q5.1 — Azure Monitor Alerting Multi-Recurso

**Resposta:**

**1. Action Groups — criar 3:**

| Action Group | Destinatarios | Action Types |
|--------------|--------------|--------------|
| `AG-CloudOps-Critical` | CloudOps (8 pessoas) | SMS + Email |
| `AG-SecOps-Alert` | SecOps (4 pessoas) + Camila | Email (Camila tambem SMS para Sev 0) |
| `AG-CloudOps-Standard` | CloudOps (8 pessoas) | Email (sem SMS) |

Mapeamento de alertas para Action Groups:

| Alerta | Action Groups |
|--------|--------------|
| CPU critica (Sev 0) | AG-CloudOps-Critical + AG-SecOps-Alert |
| Disk space (Sev 1) | AG-CloudOps-Standard |
| Key Vault denied (Sev 0) | AG-SecOps-Alert |
| Policy non-compliance (Sev 2) | AG-SecOps-Alert |

**2. Alert rule para todas as VMs de producao:**

**Sim**, Camila pode criar um unico alert rule que monitore todas as VMs usando:

- **Scope:** Selecionar a **subscription inteira** ou o **resource group** que contem as VMs de producao
- **Target resource type:** Virtual Machines
- **Split by dimensions:** Nao necessario se quer um alerta agregado
- **Condition:** Metrica `Percentage CPU` > 95% por 5 minutos

O Azure Monitor suporta **multi-resource metric alerts** para VMs — um unico alert rule pode monitorar todas as VMs em um escopo (subscription ou RG). Se uma nova VM for adicionada ao RG, ela e automaticamente incluida no monitoramento.

**3. Key Vault access denied — metrica ou log:**

E baseado em **log**, nao em metrica. O Key Vault registra tentativas de acesso negadas nos **diagnostic logs** (tabela `AzureDiagnostics` com category `AuditEvent`).

Camila deve:
1. Habilitar **diagnostic settings** no Key Vault para enviar logs ao Log Analytics Workspace
2. Criar um **Log Alert** com query KQL:

```kql
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultType == "Forbidden" or httpStatusCode_d == 403
| where TimeGenerated > ago(5m)
```

A metrica nativa do Key Vault (`ServiceApiResult`) **nao** diferencia entre sucesso e falha por padrao. Para detectar acessos negados especificamente, log alert e mais preciso.

**[GOTCHA]** Multi-resource metric alerts para VMs sao uma feature poderosa que evita criar um alert por VM. No exame, se a questao fala "monitorar todas as VMs", lembre que um unico alert rule com scope na subscription/RG cobre todas.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco4-monitor.md` — Alert rules e Action Groups

---

### Q5.2 — KQL Query para Auditoria de Seguranca

**Resposta:**

**1. Relatorio 1 — Operacoes de usuario no Entra ID:**

```kql
AuditLogs
| where TimeGenerated > ago(30d)
| where Category == "UserManagement"
| where OperationName has_any ("Add user", "Delete user", "Invite external user")
| project
    TimeGenerated,
    OperationName,
    Result,
    InitiatedBy = tostring(InitiatedBy.user.userPrincipalName),
    TargetUser = tostring(TargetResources[0].userPrincipalName),
    IPAddress = tostring(InitiatedBy.user.ipAddress)
| order by TimeGenerated desc
```

Essa query:
- Filtra ultimos 30 dias
- Foca em operacoes de **UserManagement** (criar, deletar, convidar)
- Mostra **quem** fez a operacao (`InitiatedBy`), **quando** e **qual usuario** foi afetado
- Inclui o IP de origem para rastreamento

**2. Relatorio 2 — Acessos negados ao Key Vault:**

```kql
AzureDiagnostics
| where TimeGenerated > ago(7d)
| where ResourceType == "VAULTS"
| where Category == "AuditEvent"
| where httpStatusCode_d == 403
    or ResultType == "Forbidden"
| summarize
    DeniedAttempts = count(),
    Operations = make_set(OperationName),
    LastAttempt = max(TimeGenerated)
    by CallerIPAddress
| order by DeniedAttempts desc
```

Essa query:
- Filtra ultimos 7 dias na tabela de diagnostico
- Filtra apenas acessos **negados** (HTTP 403 / Forbidden)
- Agrupa por **IP de origem** para identificar fontes suspeitas
- Mostra quais operacoes foram tentadas e quando foi a ultima tentativa

**3. Agendamento semanal automatico:**

Camila deve usar **Workbooks** do Azure Monitor combinados com **Logic Apps** ou **Azure Monitor Scheduled Query Rules**:

**Opcao recomendada: Scheduled Query Rules (Log Search Alert) + Action Group:**
1. Criar uma **Scheduled Query Rule** com frequencia de avaliacao = 7 dias
2. A query retorna os resultados e dispara o Action Group
3. O Action Group envia email com os resultados

**Opcao alternativa: Azure Workbook + Subscription de relatorio:**
1. Criar um **Azure Workbook** com as queries KQL
2. Configurar **Workbook subscriptions** (preview) para enviar snapshots por email semanalmente

**Opcao com mais controle: Logic App:**
1. Criar um **Logic App** com trigger de recorrencia (semanal)
2. Usar a acao **Run query and list results** do Log Analytics
3. Formatar os resultados em tabela HTML
4. Enviar email via Office 365 ou SendGrid

**[GOTCHA]** No exame, `AuditLogs` e para operacoes do Entra ID (usuarios, grupos, apps). `AzureDiagnostics` e para logs de recursos Azure (Key Vault, Storage, etc.). Saber qual tabela usar para cada cenario e essencial.

**Referencia no lab:** `labs/3-backup-monitoring/cenario/bloco5-log-analytics.md` — KQL avancado

---

## Mapa de Dominios AZ-104

| Questao | Dominio AZ-104 | Subtopico |
|---------|----------------|-----------|
| Q1.1 | D1 — Manage identities and governance | Management Groups, Policy inheritance, exemptions |
| Q1.2 | D1 — Manage identities and governance | RBAC multi-scope, peering permissions |
| Q2.1 | D2 — Implement and manage storage | CMK, Key Vault, Managed Identity |
| Q2.2 | D2 — Implement and manage storage | GRS/GZRS, failover, RA-GRS |
| Q3.1 | D3 — Deploy and manage compute resources | ASR, test failover, IP resolution |
| Q3.2 | D3 — Deploy and manage compute resources | VMSS Rolling upgrade |
| Q4.1 | D4 — Implement and manage virtual networking | Forced tunneling, Private Endpoints, AzFW Management subnet |
| Q4.2 | D4 — Implement and manage virtual networking | ExpressRoute vs VPN, peering types |
| Q5.1 | D5 — Monitor and maintain resources | Multi-resource alerts, Action Groups |
| Q5.2 | D5 — Monitor and maintain resources | KQL, AuditLogs, AzureDiagnostics |

---

## Top Gotchas — Caso 5

| # | Gotcha | Questao |
|---|--------|---------|
| 1 | Policy Deny no MG **nao pode** ser sobrescrito por policy na subscription — use **Exemption** | Q1.1 |
| 2 | VNet peering requer permissao em **ambos os lados** (peer/action) | Q1.2 |
| 3 | CMK = Managed Identity + **Key Vault permissions** (wrap/unwrap) | Q2.1 |
| 4 | Apos failover de storage, a conta vira **LRS** — reconfigurar GRS manualmente | Q2.2 |
| 5 | IP **hardcoded** = falha em DR — usar DNS ou automacao | Q3.1 |
| 6 | VMSS Rolling upgrade = **zero downtime**, atualiza em lotes | Q3.2 |
| 7 | Azure Firewall com forced tunneling requer **AzureFirewallManagementSubnet** | Q4.1 |
| 8 | ExpressRoute failover para VPN requer **BGP** habilitado em ambos | Q4.2 |
| 9 | Multi-resource metric alerts monitoram **todas as VMs** no escopo com uma unica regra | Q5.1 |
| 10 | `AuditLogs` = Entra ID; `AzureDiagnostics` = recursos Azure (Key Vault, Storage) | Q5.2 |

---

## Consolidado — Todos os Estudos de Caso

Apos completar todos os 5 estudos de caso:

1. **Analise seus erros por dominio** — Identifique o dominio com mais erros
2. **Reveja os gotchas** — Eles representam as armadilhas mais comuns do exame
3. **Refaca os labs** dos dominios com mais dificuldade
4. **Pontuacao alvo:** ≥ 80% em cada estudo de caso antes de fazer o exame
5. **Foco final:** Os 5 gotchas que mais te pegaram nos estudos de caso
