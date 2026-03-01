# Guia Complementar de Estudos - AZ-104

> **Objetivo:** Aprofundar topicos avancados que complementam os videos e materiais do curso AZ-104
> **Geracao:** Via Perplexity AI
> **Data:** 01/01/2026

---

## Sumario

1. [Identidade e Seguranca](#1-identidade-e-seguranca)
2. [Armazenamento Avancado](#2-armazenamento-avancado)
3. [Rede e Conectividade](#3-rede-e-conectividade)
4. [Computacao e VMs](#4-computacao-e-vms)
5. [Monitoramento e Recuperacao](#5-monitoramento-e-recuperacao)
6. [Checklist Final de Estudos](#6-checklist-final-de-estudos)

---

## 1. Identidade e Seguranca

### 1.1 Azure Bastion - Tiers e Configuracoes

O Azure Bastion oferece conectividade RDP/SSH segura sem expor IPs publicos nas VMs.

#### Comparacao de SKUs

| Recurso                     | Basico | Standard | Premium |
| --------------------------- | ------ | -------- | ------- |
| Conexoes VMs mesma VNet     | Sim    | Sim      | Sim     |
| Conexoes VNets emparelhadas | Sim    | Sim      | Sim     |
| Dimensionamento de host     | Nao    | Sim      | Sim     |
| Upload/Download de arquivos | Nao    | Sim      | Sim     |
| Autenticacao Kerberos       | Sim    | Sim      | Sim     |
| Link compartilhavel         | Nao    | Sim      | Sim     |
| Conexao por IP              | Nao    | Sim      | Sim     |
| Implantacao privada         | Nao    | Nao      | Sim     |

#### Configuracoes Importantes para o Exame

| Aspecto                      | Detalhe                           |
| ---------------------------- | --------------------------------- |
| **Sub-rede obrigatoria**     | `AzureBastionSubnet` - nome exato |
| **Tamanho minimo subnet**    | /26 ou maior                      |
| **Instancias SKU Basico**    | 2 instancias automaticas          |
| **Conexoes por instancia**   | 20 RDP + 40 SSH simultaneas       |
| **Protocolo**                | TLS porta 443                     |
| **Zonas de disponibilidade** | Suportado em algumas regioes      |

#### Pontos-Chave para o Exame

1. Bastion elimina necessidade de IP publico nas VMs
2. Sub-rede deve ter nome exato `AzureBastionSubnet`
3. Standard+ permite transferencia de arquivos
4. Premium permite modo somente privado

---

### 1.2 Microsoft Entra Connect e Identidades Hibridas

#### Conceito

Ferramenta para sincronizar identidades on-premises (Active Directory) com Microsoft Entra ID (Azure AD).

#### Metodos de Autenticacao

| Metodo                       | Descricao                  | Quando Usar                        |
| ---------------------------- | -------------------------- | ---------------------------------- |
| **Password Hash Sync (PHS)** | Hash de senha sincronizado | Simplicidade, alta disponibilidade |
| **Pass-through Auth (PTA)**  | Autenticacao em tempo real | Politicas de senha on-premises     |
| **Federation (AD FS)**       | Federacao com AD FS        | Controle total, MFA on-premises    |

#### Componentes

- **Azure AD Connect Sync** - Motor de sincronizacao
- **Azure AD Connect Health** - Monitoramento da sincronizacao
- **Seamless SSO** - Single sign-on transparente

#### Pontos-Chave para o Exame

1. PHS e o metodo mais simples e recomendado
2. PTA requer agentes on-premises
3. Sincronizacao padrao a cada 30 minutos
4. Filtros de dominio/OU controlam o que sincroniza

---

### 1.3 Conditional Access Policies

#### Conceito

Politicas que controlam acesso baseado em condicoes (usuario, dispositivo, localizacao, risco).

#### Componentes de uma Policy

| Componente                  | Opcoes                               |
| --------------------------- | ------------------------------------ |
| **Assignments (Quem)**      | Usuarios, grupos, roles              |
| **Conditions (Quando)**     | Localizacao, dispositivo, app, risco |
| **Access Controls (O que)** | Grant, Block, Session controls       |

#### Condicoes Disponiveis

- **Device platforms** - Windows, iOS, Android, etc.
- **Locations** - Named locations, trusted IPs
- **Client apps** - Browser, mobile, desktop
- **Device state** - Compliant, Hybrid joined
- **Sign-in risk** - Low, Medium, High

#### Controles de Acesso

| Controle                         | Acao                              |
| -------------------------------- | --------------------------------- |
| **Block access**                 | Bloqueia totalmente               |
| **Grant access**                 | Permite com requisitos            |
| **Require MFA**                  | Exige autenticacao multi-fator    |
| **Require compliant device**     | Exige dispositivo em conformidade |
| **Require Hybrid Azure AD join** | Exige join hibrido                |

#### Pontos-Chave para o Exame

1. Policies aplicam na ordem: Block > Grant
2. "All users" inclui guests - cuidado!
3. Sempre exclua conta de emergencia (break glass)
4. Report-only mode para teste sem impacto

---

## 2. Armazenamento Avancado

### 2.1 Azure File Sync

#### Conceito

Sincroniza arquivos entre servidores Windows e Azure Files, com cache local e tiering para nuvem.

#### Componentes

| Componente               | Funcao                              |
| ------------------------ | ----------------------------------- |
| **Storage Sync Service** | Gerencia sincronizacao na regiao    |
| **Sync Group**           | Agrupa endpoints para sincronizacao |
| **Server Endpoint**      | Pasta no servidor Windows           |
| **Cloud Endpoint**       | Azure file share                    |
| **Cloud Tiering**        | Move arquivos frios para Azure      |

#### Limites Importantes

| Limite                               | Valor   |
| ------------------------------------ | ------- |
| Servidores por sync group            | 30      |
| Sync groups por Storage Sync Service | 200     |
| File shares por storage account      | 100     |
| Tamanho maximo de arquivo            | 100 GiB |

#### Cloud Tiering

- Libera espaco local movendo arquivos para Azure
- Mantem stub local para acesso rapido
- Politicas baseadas em espaco livre ou data de acesso
- Recall sob demanda ou manual

#### Pontos-Chave para o Exame

1. Requer agente Azure File Sync no Windows Server
2. Cloud tiering e opcional mas recomendado
3. NTFS permissions sao sincronizadas
4. Suporta DFS Namespaces

---

### 2.2 Private Endpoints vs Service Endpoints

#### Tabela Comparativa Completa

| Aspecto               | Service Endpoints             | Private Endpoints          |
| --------------------- | ----------------------------- | -------------------------- |
| **IP de destino**     | Publico (via backbone)        | Privado (da VNet)          |
| **Exposicao publica** | Ainda atinge endpoint publico | Totalmente privado         |
| **On-premises**       | Nao suportado                 | Sim (via VPN/ExpressRoute) |
| **Escopo**            | Por servico (todo Storage)    | Por instancia/recurso      |
| **DNS**               | Publico                       | Private DNS Zone           |
| **Custo**             | Gratuito                      | Pago (por hora + dados)    |
| **Complexidade**      | Simples                       | Maior (DNS, NIC)           |

#### Quando Usar Cada Um

| Cenario                       | Recomendacao      |
| ----------------------------- | ----------------- |
| Acesso simples Azure-only     | Service Endpoints |
| Acesso on-premises necessario | Private Endpoints |
| Maximo isolamento             | Private Endpoints |
| Custo prioritario             | Service Endpoints |
| Multiplos servicos Azure      | Service Endpoints |
| Recurso especifico            | Private Endpoints |

#### Pontos-Chave para o Exame

1. Service Endpoints: Simples, gratuito, Azure-only
2. Private Endpoints: Seguro, privado, requer DNS config
3. Ambos evitam internet publica
4. Private Endpoints criam NIC na subnet

---

### 2.3 Azure Disk Encryption vs Server-Side Encryption

| Aspecto             | Azure Disk Encryption (ADE)            | Server-Side Encryption (SSE) |
| ------------------- | -------------------------------------- | ---------------------------- |
| **Aplica-se a**     | Discos de VMs                          | Storage Accounts             |
| **Tecnologia**      | BitLocker (Windows) / DM-Crypt (Linux) | Criptografia no servidor     |
| **Chaves**          | Key Vault obrigatorio                  | Opcional (Microsoft ou CMK)  |
| **Padrao**          | Precisa habilitar                      | Sempre ativo                 |
| **Custo adicional** | Nao                                    | Nao                          |

#### Requisitos ADE

- Azure Key Vault na mesma regiao
- Soft-delete habilitado
- Purge protection habilitado
- Access policy ou RBAC configurado

#### Pontos-Chave para o Exame

1. ADE para discos de VMs, SSE para storage
2. SSE e automatico e sem custo
3. ADE requer Key Vault com soft-delete
4. Discos temporarios nao sao criptografados por ADE

---

### 2.4 Immutable Storage e WORM Policies

#### Conceito

Impede alteracao/delecao de blobs por periodo definido (compliance SEC 17a-4, FINRA).

#### Tipos de Politicas

| Tipo           | Comportamento                |
| -------------- | ---------------------------- |
| **Time-based** | Bloqueia ate data especifica |
| **Legal Hold** | Bloqueia ate remocao manual  |

#### Niveis de Aplicacao

- **Container-level** - Aplica a todos os blobs
- **Version-level** - Aplica a versoes especificas

#### Pontos-Chave para o Exame

1. Dados nao podem ser deletados durante retencao
2. Legal hold nao tem data de expiracao
3. Requer blob versioning para version-level
4. Util para compliance regulatorio

---

## 3. Rede e Conectividade

### 3.1 User Defined Routes (UDR) e NVA

#### Conceito

Rotas personalizadas que sobrescrevem rotas de sistema para controlar fluxo de trafego.

#### Next Hop Types

| Tipo                        | Uso                              |
| --------------------------- | -------------------------------- |
| **Virtual appliance**       | Enviar para NVA (firewall, etc.) |
| **Virtual network gateway** | Enviar para VPN/ExpressRoute     |
| **Virtual network**         | Roteamento intra-VNet            |
| **Internet**                | Enviar para internet             |
| **None**                    | Descartar trafego                |

#### Network Virtual Appliances (NVA)

- VMs que atuam como firewall, router, load balancer
- Exemplos: Palo Alto, Fortinet, Cisco
- Requerem IP forwarding habilitado
- Alta disponibilidade via Availability Sets/Zones

#### Pontos-Chave para o Exame

1. UDR tem prioridade sobre rotas de sistema
2. Route table e associada a subnet
3. NVA requer IP forwarding na NIC
4. Cuidado com loops de roteamento

---

### 3.2 ExpressRoute vs VPN Gateway

| Aspecto       | VPN Gateway              | ExpressRoute           |
| ------------- | ------------------------ | ---------------------- |
| **Conexao**   | Internet (criptografada) | Privada (sem internet) |
| **Bandwidth** | Ate 10 Gbps              | Ate 100 Gbps           |
| **Latencia**  | Variavel                 | Baixa e consistente    |
| **SLA**       | 99.95% - 99.99%          | 99.95%                 |
| **Custo**     | Menor                    | Maior                  |
| **Setup**     | Simples                  | Requer provedor        |

#### Tipos de VPN Gateway

| Tipo                    | Uso                                 |
| ----------------------- | ----------------------------------- |
| **Site-to-Site (S2S)**  | Conexao permanente datacenter-Azure |
| **Point-to-Site (P2S)** | Clientes individuais remotos        |
| **VNet-to-VNet**        | Conexao entre VNets                 |

#### ExpressRoute - Modelos de Conectividade

- **CloudExchange co-location** - Datacenter no provedor
- **Point-to-point Ethernet** - Conexao dedicada
- **Any-to-any (IPVPN)** - Integracao com WAN corporativa
- **ExpressRoute Direct** - Conexao direta Microsoft

#### Pontos-Chave para o Exame

1. VPN: Internet, criptografado, mais barato
2. ExpressRoute: Privado, maior banda, menor latencia
3. Ambos podem coexistir (failover)
4. ExpressRoute Global Reach conecta sites via backbone MS

---

## 4. Computacao e VMs

### 4.1 Virtual Machine Scale Sets (VMSS)

#### Modos de Orquestracao

| Modo         | Caracteristicas                         |
| ------------ | --------------------------------------- |
| **Uniform**  | VMs identicas, gerenciamento automatico |
| **Flexible** | VMs podem variar, mais controle manual  |

#### Scaling

| Tipo             | Descricao                              |
| ---------------- | -------------------------------------- |
| **Manual**       | Ajuste manual do numero de instancias  |
| **Scheduled**    | Escala baseada em horarios             |
| **Metric-based** | Escala baseada em metricas (CPU, etc.) |
| **Predictive**   | ML prediz demanda futura               |

#### Regras de Auto-Scale

| Componente         | Funcao                               |
| ------------------ | ------------------------------------ |
| **Metric**         | O que monitorar (CPU, memoria, etc.) |
| **Threshold**      | Valor que dispara acao               |
| **Direction**      | Scale out ou scale in                |
| **Instance count** | Quantas instancias adicionar/remover |
| **Cool down**      | Tempo entre acoes de escala          |

#### Pontos-Chave para o Exame

1. Uniform: Identico, mais simples, maior automacao
2. Flexible: Mais controle, mistura de VMs
3. Always configure scale-in policy (evita perda de VMs erradas)
4. Cool down evita oscilacao (flapping)

---

### 4.2 Azure Disk Encryption com Key Vault

#### Fluxo de Configuracao

1. Criar Key Vault na mesma regiao da VM
2. Habilitar soft-delete e purge protection
3. Criar chave (KEK) ou usar chave gerenciada
4. Configurar access policy para VM
5. Habilitar ADE na VM

#### Requisitos do Key Vault

| Requisito        | Valor               |
| ---------------- | ------------------- |
| Regiao           | Mesma da VM         |
| Soft-delete      | Obrigatorio         |
| Purge protection | Obrigatorio         |
| SKU              | Standard ou Premium |

#### Pontos-Chave para o Exame

1. Key Vault deve estar na mesma regiao
2. VM precisa de permissoes no Key Vault
3. Encrypcao pode demorar em discos grandes
4. Nao suporta todos os tamanhos de VM

---

## 5. Monitoramento e Recuperacao

### 5.1 Azure Site Recovery - RPO/RTO

#### Conceitos

| Metrica                            | Significado                       |
| ---------------------------------- | --------------------------------- |
| **RPO (Recovery Point Objective)** | Quanto tempo de dados pode perder |
| **RTO (Recovery Time Objective)**  | Tempo para restaurar operacao     |

#### Capacidades ASR

| Aspecto                     | Valor        |
| --------------------------- | ------------ |
| RPO minimo Azure-to-Azure   | 30 segundos  |
| RTO SLA zone-to-zone        | Ate 1 hora   |
| Retencao de recovery points | Ate 15 dias  |
| Crash-consistent snapshots  | Sim          |
| App-consistent snapshots    | Configuravel |

#### Componentes

| Componente                  | Funcao                 |
| --------------------------- | ---------------------- |
| **Recovery Services Vault** | Armazena configuracoes |
| **Replication Policy**      | Define RPO, retencao   |
| **Recovery Plan**           | Orquestra failover     |
| **Test Failover**           | Valida DR sem impacto  |

#### Pontos-Chave para o Exame

1. ASR para DR, Backup para protecao de dados (diferentes!)
2. Test failover nao afeta producao
3. RPO depende da frequencia de replicacao
4. Automation runbooks podem reduzir RTO

---

### 5.2 Kusto Query Language (KQL) - Queries Essenciais

#### Sintaxe Basica

```kql
// Estrutura basica
TableName
| where Column == "value"
| summarize count() by GroupColumn
| order by count_ desc
```

#### Queries Comuns para o Exame

```kql
// 1. Eventos de erro nas ultimas 24h
Event
| where TimeGenerated > ago(24h)
| where EventLevelName == "Error"
| summarize count() by Source

// 2. CPU acima de 90%
Perf
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| where CounterValue > 90
| summarize avg(CounterValue) by Computer

// 3. VMs sem heartbeat (possivelmente offline)
Heartbeat
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(5m)

// 4. Falhas de login
SigninLogs
| where ResultType != 0
| summarize FailedLogins = count() by UserPrincipalName
| order by FailedLogins desc

// 5. Alertas disparados
AzureActivity
| where OperationNameValue contains "alert"
| where ActivityStatusValue == "Succeeded"
| project TimeGenerated, Caller, OperationNameValue
```

#### Operadores Importantes

| Operador    | Funcao                       |
| ----------- | ---------------------------- |
| `where`     | Filtrar linhas               |
| `summarize` | Agregar dados                |
| `project`   | Selecionar colunas           |
| `extend`    | Adicionar colunas calculadas |
| `join`      | Combinar tabelas             |
| `ago()`     | Tempo relativo               |
| `bin()`     | Agrupar por intervalos       |

#### Pontos-Chave para o Exame

1. KQL e case-sensitive para strings
2. `ago(24h)` para ultimas 24 horas
3. `summarize` similar a GROUP BY do SQL
4. `project` similar a SELECT do SQL

---

### 5.3 Azure Monitor Workbooks e Dashboards

#### Workbooks

| Caracteristica       | Descricao                            |
| -------------------- | ------------------------------------ |
| **Tipo**             | Relatorios interativos               |
| **Dados**            | Logs, metricas, Azure Resource Graph |
| **Compartilhamento** | Salvo como recurso Azure             |
| **Visualizacoes**    | Graficos, tabelas, grids, mapas      |

#### Dashboards

| Caracteristica       | Descricao              |
| -------------------- | ---------------------- |
| **Tipo**             | Visualizacao rapida    |
| **Dados**            | Metricas, tiles, links |
| **Compartilhamento** | Portal ou JSON export  |
| **Atualizacao**      | Tempo real             |

#### Quando Usar

| Cenario                     | Recomendacao |
| --------------------------- | ------------ |
| Analise profunda de logs    | Workbooks    |
| Visao rapida operacional    | Dashboards   |
| Relatorio para stakeholders | Workbooks    |
| Monitoramento continuo      | Dashboards   |

---

## 6. Checklist Final de Estudos

### Identidade e Governanca (20-25%)

- [ ] Criar/gerenciar usuarios e grupos Entra ID
- [ ] Configurar SSPR (Self-Service Password Reset)
- [ ] Implementar RBAC em diferentes escopos
- [ ] Configurar Azure Policy e iniciativas
- [ ] Gerenciar Management Groups
- [ ] Aplicar resource locks e tags
- [ ] Configurar Azure Bastion

### Armazenamento (15-20%)

- [ ] Criar storage accounts com redundancia adequada
- [ ] Configurar blob tiers e lifecycle policies
- [ ] Implementar Azure Files e File Sync
- [ ] Configurar SAS tokens e access policies
- [ ] Implementar Private/Service Endpoints
- [ ] Configurar immutable storage

### Computacao (20-25%)

- [ ] Criar e configurar VMs
- [ ] Implementar availability sets/zones
- [ ] Configurar VMSS com auto-scale
- [ ] Implementar Azure Disk Encryption
- [ ] Configurar App Service e slots
- [ ] Trabalhar com ACI e AKS basico
- [ ] Configurar Azure Functions

### Redes (15-20%)

- [ ] Criar VNets e subnets
- [ ] Configurar NSGs e ASGs
- [ ] Implementar VNet peering
- [ ] Configurar VPN Gateway
- [ ] Implementar Azure DNS
- [ ] Configurar Load Balancer e Application Gateway
- [ ] Criar UDRs e trabalhar com NVAs

### Monitoramento (10-15%)

- [ ] Configurar Azure Monitor e alertas
- [ ] Trabalhar com Log Analytics e KQL
- [ ] Implementar Azure Backup
- [ ] Configurar Azure Site Recovery
- [ ] Usar Network Watcher para diagnostico

---

## Recursos Adicionais

| Recurso                     | Link                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------ |
| **Microsoft Learn AZ-104**  | https://aka.ms/AZ-104onLearn                                                         |
| **Guia de Estudos Oficial** | https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-104 |
| **Sandbox Gratuito**        | https://learn.microsoft.com/training/browse/?products=azure                          |
| **Documentacao Azure**      | https://docs.microsoft.com/azure                                                     |

---

## Dicas para o Exame

1. **Leia atentamente** - Muitas questoes tem "pegadinhas" nos detalhes
2. **Marque para revisao** - Use o tempo sabiamente
3. **Pratique no portal** - Experiencia pratica e essencial
4. **Conheca os limites** - Muitas questoes sobre limites de recursos
5. **Entenda os cenarios** - Saiba quando usar cada servico
6. **Revise os labs** - Os 14 labs cobrem cenarios reais

---

_Guia gerado via Perplexity AI em 01/01/2026_
_Complementa os 22 videos da playlist AZ-104 e materiais do Microsoft Learn_
