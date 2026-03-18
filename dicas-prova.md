# Dicas para Prova AZ-104

Anotacoes rapidas e pegadinhas para revisar antes do exame, consolidadas de todos os labs.

---

## Identidade e Governanca

### Usuarios e Grupos (Entra ID)

- **Usage location** e obrigatoria para atribuir licencas ao usuario
- Grupos dinamicos requerem **Entra ID P1/P2**
- Grupos dinamicos: nao permitem adicionar membros manualmente, avaliacao pode levar minutos
- Grupos dinamicos podem ser baseados em **users OU devices** (nao ambos no mesmo grupo)

### SSPR (Self-Service Password Reset)

- SSPR com 2 metodos requeridos e mais seguro
- Security Questions **NAO** podem ser o unico metodo
- SSPR requer Azure AD Free (cloud users) ou P1/P2 (writeback on-premises)
- **Quem pode usar SSPR:** membros (cloud + sync com writeback) = **sim**; convidados (guests) = **nao**
- Com password writeback, usuarios **sincronizados** do AD local tambem podem usar SSPR

### Roles Administrativas (privilegio minimo)

| Necessidade                                                   | Role correta                    | NAO usar                     |
| ------------------------------------------------------------- | ------------------------------- | ---------------------------- |
| Convidar usuarios externos                                    | **Guest Inviter**               | Global Admin, Security Admin |
| Exibir recursos (somente leitura)                             | **Reader**                      | Contributor                  |
| Gerenciar tags sem acesso a recursos                          | **Tag Contributor**             | Contributor                  |
| Gerenciar grupos                                              | **Groups Administrator**        | Global Admin                 |
| Gerenciar VMs                                                 | **Virtual Machine Contributor** | Contributor                  |
| Exibir custos + gerenciar orcamentos (sem modificar recursos) | **Cost Management Contributor** | Reader, Colaborador          |

- **Guest Inviter** = role especifica para convidar externos (B2B), privilegio minimo
- **Cost Management Contributor** = ve custos + gerencia budgets, SEM poder modificar recursos
- **Reader** NAO gerencia orcamentos, apenas visualiza. NAO confundir com Cost Mgmt Contributor
- **Tag Contributor** = pode gerenciar tags sem acesso aos recursos em si
- Usuarios convidados: UPN tem formato `user_dominio.com#EXT#@tenant.onmicrosoft.com`

### Licenciamento baseado em grupo

- Licencas sao consumidas por **membros** do grupo, NAO por proprietarios
- Convidados (guest) tambem consomem licenca se forem membros
- Proprietario que nao e membro **NAO** consome licenca

### RBAC - Custom Roles e PowerShell

- Custom Role JSON: **Actions** = permitido, **NotActions** = excluido, **AssignableScopes** = onde pode ser atribuida
- `Microsoft.Compute/*/read` = le TODOS os recursos de compute (VMs, disks, snapshots, etc.)
- `Get-AzRoleDefinition -Name` busca por **nome**; para buscar por ID use `-Id`
- **$RoleName deve conter o NOME** (ex: "CustomRole1"), nao o ID GUID
- `New-AzRoleAssignment` atribui role a um usuario

### Azure Policy

- Informacoes de remediacao ficam na secao **metadata** (campo `RemediationDescription`)
- **mode** define quais recursos sao avaliados (ex: All, Indexed)
- **parameters** sao valores configuraveis na atribuicao
- **policyRule** contem a logica (if/then)

### Pegadinhas
- "Membros adicionados automaticamente por departamento" -> **Dynamic user group**
- "Usuario nao consegue resetar senha via SSPR" -> verificar se **registrou os metodos de autenticacao**
- "Convidar externos com privilegio minimo" -> **Guest Inviter** (NAO Security Admin, NAO Global Admin)
- "Marcar VMs por departamento" -> **Tags** (etiquetas)
- "Criar custom role para permissao de marcacao via portal" -> precisa de role com `Microsoft.Compute/virtualMachines/write`
- "Equipe financeira ver custos e gerenciar orcamentos" -> **Cost Management Contributor** (NAO Reader)

### Bloqueios (Locks)

- **Delete lock** impede exclusao acidental de recursos
- Pode aplicar em: **Subscriptions**, **Resource Groups**, **Recursos individuais** (VMs, etc.)
- **NAO pode** aplicar em: **Management Groups**, dados de storage account
- Bloqueio no RG protege os recursos dentro, mas permite excluir o RG se estiver vazio

---

## Gestao de Custos

### Budgets vs Policy vs Automation

| Mecanismo          | Funcao                               | Bloqueia recursos?        |
| ------------------ | ------------------------------------ | ------------------------- |
| Budget             | Alerta quando gasto atinge threshold | **Nao** (apenas notifica) |
| Azure Policy       | Restringe criacao (ex: limitar SKUs) | **Sim** (previne)         |
| Automation Runbook | Executa acao (ex: desligar VMs)      | **Sim** (reage)           |
| Spending Limit     | Limita gasto total                   | **Sim** (apenas dev/test) |

- Budgets **alertam** mas **NAO param** recursos automaticamente
- Para controle completo: Policy (prevenir) + Budget (monitorar) + Runbook (reagir)
- Advisor **recomenda**; Budgets **alertam**; Policies **restringem**
- "Forecasted" alerta baseado na tendencia, prevenindo surpresas no fim do mes

---

## Redes Virtuais

### Calculo de IPs em Subnets

- **5 IPs reservados** por subnet: .0 (rede), .1 (gateway), .2-.3 (Azure DNS), .255 (broadcast)
- Formula: **2^(32 - prefixo) - 5** = IPs disponiveis
- Menor subnet permitida: **/29** (3 IPs utilizaveis)

| CIDR | Total | Utilizaveis |
| ---- | ----- | ----------- |
| /24  | 256   | 251         |
| /25  | 128   | 123         |
| /26  | 64    | 59          |
| /27  | 32    | 27          |
| /28  | 16    | 11          |
| /29  | 8     | 3           |

### VNet Peering

- Peering **conecta VNets** para comunicacao direta (latencia baixa, banda alta)
- "VMs em VNets diferentes precisam se comunicar" → **Peering** (NAO DNS server, NAO route table)
- DNS server so resolve nomes, **NAO conecta** redes
- Peering e **NAO transitivo**: A↔B e B↔C **nao** significa A↔C
- Hub-spoke resolve com NVA/Firewall no hub
- **Allow Gateway Transit** permite compartilhar VPN Gateway entre VNets peered
- Cada peering e configurado independentemente nos dois lados

### UDR (User Defined Routes) e NVA

- UDR sobrescreve rotas automaticas do Azure (system routes)
- **Longest prefix match:** rota mais especifica vence (/24 > /16 > /0)
- Se mesmo prefixo: **User route** vence **System route**
- UDRs sao **unidirecionais** — afetam apenas trafego **saindo** da subnet associada
- Next hop **None** = descarta o pacote (blackhole)
- Next hop **Virtual appliance** = encaminha para IP de um NVA
- **NVA (Network Virtual Appliance)** = VM que atua como firewall/proxy/roteador
- Para NVA funcionar: **UDR** + **IP forwarding na NIC** (portal) + **IP forwarding no OS** (Windows/Linux) — os tres sao obrigatorios
- Se o NVA nao existir ou nao tiver IP forwarding, o pacote e **descartado**
- Peering entre VNets + NVA requer **Allow Forwarded Traffic** no peering
- "Forcar trafego por firewall" → **UDR com next hop Virtual appliance**
- "Bloquear internet sem NSG" → **UDR com next hop None para 0.0.0.0/0**
- Desassociar UDR da subnet → rotas automaticas voltam imediatamente

### VPN Gateway

- **S2S** = conexao permanente on-premises ↔ Azure (IPsec/IKE)
- **P2S** = clientes individuais → Azure (certificado ou RADIUS)
- **GatewaySubnet** e obrigatoria (nome exato), recomendado /27+
- Active-Passive (padrao) vs Active-Active (HA com 2 tuneis)
- **Allow Gateway Transit** (hub) + **Use Remote Gateways** (spoke) = compartilhar gateway
- **P2S + novo peering/subnet** → **reinstalar cliente VPN P2S** para obter novas rotas (rotas nao atualizam automaticamente)

### NSG (Network Security Groups)

**O que e NSG:** recurso que filtra trafego por IP, porta e protocolo. Associa-se a **NIC** ou **Sub-rede**.
- "Restringir trafego entre VMs por porta especifica" → **NSG** (NAO VNet, NAO Firewall)
- VNet e apenas o container de rede, nao filtra trafego por porta
- NSG so pode ser associado a sub-redes na **mesma regiao** do NSG

**Ordem de avaliacao:**
- **Inbound:** subnet NSG primeiro → NIC NSG depois (ambos devem permitir)
- **Outbound:** NIC NSG primeiro → subnet NSG depois
- Se **qualquer** NSG negar, trafego e bloqueado
- Se nao ha NSG numa camada, todo trafego e permitido naquela camada

**Pegadinhas:**
- Standard LB **bloqueia** trafego por padrao — precisa de NSG para permitir
- Source `AzureLoadBalancer` permite health probes do LB
- "Backend unhealthy" → verificar health probe + NSG

### ASG vs Service Tag vs IP Range

| Tipo | Quem define | Quando usar | Exemplo |
| --- | --- | --- | --- |
| **Service Tag** | Microsoft | Servicos Azure gerenciados | Internet, AzureLoadBalancer, Storage |
| **ASG** | Voce | Seus recursos agrupados por funcao | asg-web, asg-db, asg-api |
| **IP Range** | Voce | IPs fixos (ultimo recurso) | 10.0.1.0/24, 203.0.113.50 |

- "Permitir trafego do Azure Load Balancer" → **Service Tag** `AzureLoadBalancer`
- "Permitir trafego entre web servers e db servers" → **ASG** (source=asg-web, dest=asg-db)
- VM nova nao recebe trafego mas as outras sim → **falta associar ao ASG**
- ASG em regra Allow **NAO bloqueia** trafego de outras origens — precisa de Deny explicito
- ASG e Service Tag podem ser usados **na mesma regra** NSG

### Service Endpoints e Private Endpoints

| Mecanismo               | O que filtra                        | Direcao                          |
| ----------------------- | ----------------------------------- | -------------------------------- |
| NSG                     | IP, porta, protocolo                | Entrada/saida na subnet          |
| Firewall do Storage     | Subnet/IP de **origem**             | Quem acessa o storage            |
| Service Endpoint Policy | Recurso PaaS de **destino**         | Para onde a subnet envia trafego |
| Private Endpoint        | Elimina acesso publico (IP privado) | Acesso totalmente privado        |

**Service Endpoint vs Private Endpoint:**

|                                | Service Endpoint                                 | Private Endpoint                       |
| ------------------------------ | ------------------------------------------------ | -------------------------------------- |
| IP do servico                  | **Publico** (rota otimizada pelo backbone Azure) | **Privado** (NIC com IP na sua subnet) |
| DNS customizado                | Nao necessario                                   | Sim (Private DNS Zone obrigatoria)     |
| Acesso de on-premises (VPN/ER) | **Nao**                                          | **Sim**                                |
| Custo                          | Gratis                                           | Pago (por hora + trafego)              |
| Trafego sai da VNet?           | Nao (backbone Microsoft)                         | Nao (IP privado)                       |

- Service Endpoint = rota otimizada (IP publico mantido, trafego pelo backbone Azure)
- Private Endpoint = IP privado na VNet (acesso totalmente privado, requer Private DNS Zone)
- Private Endpoint = **NIC** com IP privado na subnet que aponta para o recurso PaaS
- "Acesso a Storage de on-premises via VPN" → **Private Endpoint** (Service Endpoint NAO funciona de on-prem)
- "Eliminar acesso publico ao Storage" → **Private Endpoint** (Service Endpoint mantem IP publico)
- "Restringir Service Endpoint para uma Storage Account especifica" → **Service Endpoint Policy**
- Service Endpoint Policy so funciona com Service Endpoints (nao com Private Endpoints)
- Servicos suportados por policy: **Microsoft.Storage** (GA) e Azure SQL Database (preview)

### NSG Flow Logs e Traffic Analytics

- Flow Logs v2 e obrigatorio para Traffic Analytics
- Requerem Storage Account + opcionalmente Log Analytics
- Dados no container `insights-logs-networksecuritygroupflowevent`
- "Analisar trafego de rede" → NSG Flow Logs + Traffic Analytics

### DNS

- **Azure DNS Privado** = resolucao de nomes entre VNets (custom FQDN como contoso.com)
- **Azure DNS Publico** = hospedagem de dominios publicos (acessiveis da internet)
- **Resolucao fornecida pelo Azure** = apenas dentro da **mesma VNet**, sem nomes customizados
- "VNets peered + FQDN customizado + minimo esforco" → **Azure DNS Privado** (NAO publico)

### DNS - Delegacao de Subdominio

- "Delegar test.contoso.com para outro DNS" → criar **registro NS** chamado `test` na zona `contoso.com`
- A delegacao e feita na **zona PAI**, nao na filha
- Registro NS aponta para **name servers**, nao para IPs (diferente de A record)
- SOA e criado **automaticamente** na zona filha — nao criar manualmente
- Registro A **NAO** delega subdominio (aponta para IP)

**Tipos de registro DNS:**

| Tipo | Funcao |
| --- | --- |
| A | Nome → IPv4 |
| AAAA | Nome → IPv6 |
| CNAME | Nome → Outro nome (alias) — NAO no apex! |
| **NS** | **Delegacao de subdominio** |
| SOA | Autoridade da zona (automatico) |
| MX | Servidor de email |
| TXT | Texto livre (SPF, verificacao de dominio) |
| PTR | IP → Nome (reverse DNS) |

### Network Watcher

- **Effective Security Rules:** ver regras combinadas (subnet + NIC)
- **IP Flow Verify:** testar se pacote especifico seria permitido/bloqueado — "NSG bloqueando comunicacao, qual NSG?" → **IP Flow Verify**
- **Connection Troubleshoot:** testar conectividade fim-a-fim (funciona/nao funciona, NAO mostra rotas)
- **Next Hop:** verificar roteamento (route tables, peering)
- **Effective Routes:** ver **todas as rotas** aplicadas na NIC (inclui next hop type) — "verificar se peering esta como proximo salto" → **Effective Routes**
- **Packet Capture:** inspecionar trafego entre VMs (requer **NetworkWatcherExtension** na VM)

**Quando usar cada ferramenta:**

| Preciso saber...                         | Ferramenta                           |
| ---------------------------------------- | ------------------------------------ |
| Se pacote e permitido/bloqueado pelo NSG | **IP Flow Verify**                   |
| Se VM1 alcanca VM2                       | **Connection Troubleshoot**          |
| Qual rota o trafego segue (next hop)     | **Effective Routes** ou **Next Hop** |
| Capturar pacotes para analise            | **Packet Capture**                   |
| Regras efetivas combinadas               | **Effective Security Rules**         |

---

## Load Balancer

### Standard vs Basic

- Standard LB requer Standard SKU Public IP
- Standard LB bloqueia trafego por padrao (precisa de NSG)
- Basic LB esta sendo descontinuado

### Session Persistence

| Modo                   | Hash                                                   | Uso                       |
| ---------------------- | ------------------------------------------------------ | ------------------------- |
| None (padrao)          | 5-tupla (src IP, src port, dst IP, dst port, protocol) | Distribuicao uniforme     |
| Client IP              | 2-tupla (src IP, dst IP)                               | Manter sessao por IP      |
| Client IP and Protocol | 3-tupla (src IP, dst IP, protocol)                     | Sessao por IP + protocolo |

- "Usuarios perdem sessao" → mudar para **Client IP**
- "Aplicacao stateless, distribuicao uniforme" → **None**
- "Distribuicao desigual entre VMs" → **desabilitar persistencia de sessao** (Session persistence = None)
- None usa 5-tupla, **nao** round-robin puro

### Public vs Internal

- Public LB = trafego da internet para VMs
- Internal LB = trafego entre tiers internos (ex: app → db)
- Ambos Standard SKU suportam Availability Zones

### Troubleshooting

- Backend unhealthy → verificar **health probe** + **NSG**
- Sem conectividade → verificar NSG permite source `AzureLoadBalancer`
- Standard LB requer NSG explicito (diferente do Basic)

---

## Azure Bastion

- Subnet obrigatoria: **AzureBastionSubnet** (nome exato)
- Demora ~15 min para ser criado

### SKUs (4 camadas)

| Feature                       | Developer | Basic   | Standard | Premium       |
| ----------------------------- | --------- | ------- | -------- | ------------- |
| Gratuito                      | Sim       | Nao     | Nao      | Nao           |
| Requer AzureBastionSubnet /26 | Nao       | Sim     | Sim      | Sim           |
| Requer IP publico             | Nao       | Sim     | Sim      | Nao (privado) |
| VNet peering                  | Nao       | Sim     | Sim      | Sim           |
| Cliente nativo (CLI)          | Nao       | Nao     | Sim      | Sim           |
| File transfer                 | Nao       | Nao     | Sim      | Sim           |
| Link compartilhavel           | Nao       | Nao     | Sim      | Sim           |
| Gravacao de sessao            | Nao       | Nao     | Nao      | Sim           |
| Deploy 100% privado           | Nao       | Nao     | Nao      | Sim           |
| Scale units                   | Nao       | 2 fixas | 2-50     | 2-50          |

### Pegadinhas
- "Conexao via cliente SSH nativo" → **Standard** ou Premium
- "Gravar sessoes para auditoria" → **Premium**
- Upgrade: Developer → Basic → Standard → Premium (**sem downgrade**, precisa excluir e recriar)
- Developer: 1 VM por vez, nao suporta peering, sem subnet dedicada

---

## Virtual Machines

### Familias de VM

- **B** = burstable, **D** = general purpose, **E** = memory optimized
- **F** = compute optimized, **N** = GPU

### Disponibilidade de VMs

| Protecao contra                     | Solucao                                           | SLA               |
| ----------------------------------- | ------------------------------------------------- | ----------------- |
| Falha de **hardware** (rack/switch) | **Availability Set** (fault/update domains)       | 99.95%            |
| Falha de **datacenter** inteiro     | **Availability Zone** (zonas 1, 2, 3)             | 99.99%            |
| Escala automatica                   | **VM Scale Set** (auto-scale, nao e HA por si so) | depende da config |

- "Datacenter falhar" → **Availability Zone** (NAO Scale Set, NAO Availability Set)
- Availability Set protege contra falha de **rack**, nao de datacenter
- Scale Set = escalabilidade, nao e sinonimo de alta disponibilidade

### Spot VMs

- Custo reduzido, mas Azure pode **remover a qualquer momento**
- 2 fatores de remocao: (1) **capacidade do Azure** (precisa para outros workloads), (2) **preco excede maximo definido**
- NAO depende de: CPU da instancia, hora do dia, uso de memoria
- Boas para: dev/test, batch processing, workloads sem SLA
- Politica de remocao: **Stop/Deallocate** (padrao) ou **Delete**

### Reimplantar vs Mover

- **Reimplantar (Redeploy)** = move VM para outro host fisico (resolve problemas de hardware/manutencao)
- Azure desliga a VM, move para novo host, e reinicia
- IPs dinamicos podem mudar; IPs estaticos sao mantidos

### Cloud-init / Custom Data vs Custom Script Extension

| Aspecto                | Cloud-init (Custom Data) | Custom Script Extension | Run Command     |
| ---------------------- | ------------------------ | ----------------------- | --------------- |
| SO                     | Linux apenas             | Windows e Linux         | Windows e Linux |
| Quando executa         | Primeiro boot            | Pos-provisioning        | Ad-hoc          |
| Atualizar apos criacao | Nao (imutavel)           | Sim                     | Sim             |
| Uso tipico             | Config inicial, pacotes  | Deploy software         | Troubleshooting |

### Pegadinhas
- "Instalar pacotes no 1o boot de VM Linux" → **cloud-init**
- "Executar script em VM ja criada" → **Custom Script Extension**
- "Troubleshooting rapido sem RDP/SSH" → **Run Command**
- Custom Data em **base64** no ARM/Bicep
- Cloud-init **NAO** funciona em Windows

### ARM Templates (IaC)

- `New-AzResourceGroupDeployment` = deploy ARM template em **Resource Group** (mais comum)
- `New-AzSubscriptionDeployment` = deploy no nivel de **Subscription**
- `New-AzManagementGroupDeployment` = deploy no nivel de **Management Group**
- `New-AzVM` = cria VM diretamente (sem template)
- Para passar **array como parametro inline**: usar `--parameters` no comando de deploy
- NAO usar arquivo separado para arrays inline — usar diretamente no `--parameters`
- Folha **Implantacoes** no RG mostra nome, status, **data/hora** de cada deploy ARM
- Folha Diagnostico = metricas; Folha Policy = politicas

**Parametros de referencia ao template:**

| Template esta onde | CLI | PowerShell |
| --- | --- | --- |
| Disco local | `--template-file` | `-TemplateFile` |
| URL (blob, GitHub) | `--template-uri` | `-TemplateUri` |
| Template Spec no Azure | `--template-spec` | `-TemplateSpecId` |
| `-Tag` | **NAO existe** para deploy (distrator!) | |

- "Template em blob storage" → **-TemplateUri** (NAO -TemplateFile)
- "Template local" → **-TemplateFile**
- "Template Spec salvo no Azure" → **-TemplateSpecId**

**Exportar template de recurso existente:**

| Cmdlet | O que faz |
| --- | --- |
| `Save-AzDeploymentTemplate` | Salva o template de um **deployment passado** |
| `Export-AzResourceGroup` | Exporta o **estado atual** dos recursos do RG |
| RG/Recurso > **Export template** > Deploy | Exporta e faz deploy pelo portal |

- 3 formas de usar VM como modelo: (1) `Save-AzDeploymentTemplate` + deploy, (2) Portal Export + download + deploy, (3) VM > Export template > Deploy direto
- `Get-AzVM` **NAO** exporta templates (apenas lista VMs)
- `Save-AzDeploymentScriptLog` salva **logs**, nao templates

### RBAC vs Entra ID Roles vs ABAC

| Sistema | Controla | Escopo | Exemplo |
| --- | --- | --- | --- |
| **Entra ID Roles** | Diretorio (usuarios, grupos, apps) | Tenant | Guest Inviter, User Admin |
| **Azure RBAC** | Recursos Azure (VMs, storage, VNets) | MG → Sub → RG → Resource | Owner, Contributor, Reader |
| **Azure ABAC** | RBAC + condicoes por atributos | Mesmo do RBAC | "Ler blobs com tag dept=HR" |

- "Convidar usuarios, gerenciar grupos, licencas" → **Entra ID Role**
- "Gerenciar VMs, storage, VNets" → **Azure RBAC**
- "Acesso condicional por tag/atributo" → **ABAC** (raramente cai no AZ-104)

### Availability Set - Update Domains (calculo)

- Update Domains (UD) = grupos de VMs reiniciadas juntas em manutencao
- Azure reinicia **1 UD por vez** durante manutencao planejada
- **Calculo:** VMs divididas igualmente entre UDs
- Exemplo: 18 VMs, 10 UDs → primeiros 10 UDs recebem 1 VM cada, 8 UDs restantes recebem +1 = **2 VMs max por UD**
- Numero maximo de VMs indisponiveis = VMs no maior UD = **ceil(18/10) = 2**
- NAO e 9 (isso seria fault domain com 2 FDs)

---

## Storage

### SAS Token e Revogacao

- Como revogar SAS: (1) Deletar stored access policy, (2) Regenerar storage key, (3) Alterar expiry
- "SAS comprometido, revogacao mais rapida" → **deletar Stored Access Policy**
- "Blob deletado acidentalmente, como recuperar?" → **Soft Delete** (se habilitado)

### Lifecycle Management vs Immutability

- Lifecycle = **automacao de custo** (mover entre tiers)
- Immutability = **compliance e retencao legal** (impedir alteracao/delecao)
- Para regras baseadas em **ultimo acesso** (lastAccessTime), habilitar **access tracking** (controle de acesso)
- Access tracking ≠ versioning. **Versioning** rastreia alteracoes, **access tracking** rastreia leitura
- Sem access tracking, lifecycle so pode usar **lastModifiedTime**

### Azure Files - Large File Shares

- File Shares padrao: ate **5 TiB**
- Para ate **100 TiB**: habilitar **EnableLargeFileShare** na conta de storage
- Cmdlets necessarios:
  1. `Set-AzStorageAccount -EnableLargeFileShare` (habilita suporte)
  2. `Update-AzRmStorageShare -QuotaGiB 102400` (atualiza a cota)
- **NAO precisa** alterar o tipo de redundancia (RA-RAGRS) para aumentar file share
- **NAO precisa** criar novo file share, pode atualizar o existente

### Tipos de Conta e Data Lake Gen2

| Tipo de conta           | Suporta Data Lake Gen2? | Observacao                            |
| ----------------------- | :---------------------: | ------------------------------------- |
| **Standard GPv2**       |           Sim           | Mais comum, suporta todos os servicos |
| **Premium Block Blobs** |           Sim           | Alta performance para blobs           |
| Premium File Shares     |           Nao           | Apenas Azure Files                    |
| Premium Page Blobs      |         **Nao**         | Apenas page blobs (VHDs)              |

- Data Lake Gen2 = **namespace hierarquico** habilitado na conta
- **ACLs POSIX** requerem **namespace hierarquico** (nao SFTP, nao camada de acesso)
- SFTP e um protocolo de acesso, nao habilita ACLs POSIX
- Namespace hierarquico e habilitado **na criacao** (nao pode ser adicionado depois em contas existentes - com excecoes recentes)

### Object Replication - Pre-requisitos

Para configurar Object Replication entre storage1 (origem) → storage2 (destino):

1. **Versionamento habilitado em AMBAS** as contas (origem E destino)
2. **Change feed habilitado na ORIGEM** (storage1)
3. Contas devem ser **GPv2 ou Premium Block Blobs**

- "Versionamento desabilitado" → **habilitar versionamento** (nao change feed, nao namespace)
- Change feed so e necessario na **origem**, nao no destino
- Restauracao pontual NAO e pre-requisito

### Redundancia - Leitura na regiao secundaria

| Tipo        |   Multi-regiao   |     Leitura secundaria     |
| ----------- | :--------------: | :------------------------: |
| LRS         |       Nao        |            Nao             |
| ZRS         | Nao (multi-zona) |            Nao             |
| GRS         |       Sim        |   **Nao** (so failover)    |
| **RA-GRS**  |       Sim        | **Sim** (leitura continua) |
| GZRS        |       Sim        |          **Nao**           |
| **RA-GZRS** |       Sim        |          **Sim**           |

- "Ler dados da regiao secundaria" → precisa do prefixo **RA-** (Read Access)

### Replicacao e Transferencia

- **GRS/GZRS** = replicacao sincrona gerenciada (redundancia)
- **Object Replication** = replicacao assincrona configuravel (flexibilidade, qualquer regiao)
- **AzCopy copy** = copia arquivos (uso com `--recursive` para diretorios inteiros)
- **AzCopy sync** = sincroniza (similar, mas compara timestamps)
- **Get-ChildItem -Recurse | Set-AzStorageBlobContent** = alternativa PowerShell para upload em massa
- **Set-AzStorageBlobContent** sozinho = upload de **um unico arquivo** (nao recursivo)
- Storage Explorer usa AzCopy internamente

### Criptografia

- **SSE** = padrao, automatico, no storage layer (sempre ativo)
- **ADE** = no OS (BitLocker/DM-Crypt), requer Key Vault
- SSE e ADE sao complementares
- **CMK** requer Key Vault com **purge protection** habilitado

### Azure Files - Autenticacao

- 3 metodos: (1) Storage account key (padrao), (2) Entra ID Domain Services, (3) On-premises AD DS
- RBAC controla acesso no nivel do **share**; ACLs NTFS controlam acesso **granular**

---

## App Service e Containers

### App Service

- Connection strings com prefixo no ambiente: `CUSTOMCONNSTR_`, `SQLCONNSTR_`, `SQLAZURECONNSTR_`
- Slot settings marcados como "deployment slot setting" **NAO** sao swapped
- Backup requer **Standard+**, limite de 10 GB
- VNet Integration = **outbound** (App Service acessa VNet)
- Private Endpoint = **inbound** (VNet acessa App Service)
- Subnet dedicada /28 minimo para VNet Integration

### Custom Domain e TLS

- **CNAME** = subdominio (www.contoso.com); **A record** = apex domain (contoso.com)
- TXT record `asuid` = verificacao de propriedade
- Free/Shared tier **nao** suporta custom domains
- App Service Managed Certificate = gratis, automatico, **so subdomains**
- Apex domain ou wildcard → certificado do Key Vault ou upload .pfx
- SNI SSL (padrao) vs IP-based SSL (requer IP dedicado)
- HTTPS Only forca redirect **301** de HTTP para HTTPS

### ACR (Azure Container Registry)

| SKU      | Storage | Features extras                    |
| -------- | ------- | ---------------------------------- |
| Basic    | 10 GiB  | -                                  |
| Standard | 100 GiB | Webhooks                           |
| Premium  | 500 GiB | Geo-replication, Private Link, CMK |

### Containers: ACI vs AKS vs Container Apps

| Servico        | Quando usar                                            |
| -------------- | ------------------------------------------------------ |
| ACI            | Containers simples, sem orquestracao                   |
| Container Apps | Serverless com auto-scale, revisions, HTTPS automatico |
| AKS            | Controle total do Kubernetes                           |

### ACI (Azure Container Instances)

- Armazenamento persistente: **Azure Files** (file share montado como volume)
- ACI **NAO** suporta montar Blob, Queue ou Table como volume persistente
- "Container + armazenamento persistente" → **Azure Files** (NUNCA Blob Storage)
- Suporta Linux e Windows containers
- Pode rodar em VNet (deploy privado)

### AKS (Azure Kubernetes Service)

**Seguranca do API Server:**

| Opcao                     | O que faz                                                        |
| ------------------------- | ---------------------------------------------------------------- |
| **IP ranges autorizados** | Mantém endpoint público, restringe quem acessa                   |
| **Cluster privado**       | API server acessível **apenas** pela VNet (sem endpoint público) |

- "Limitar acesso ao API server" → **IP ranges** + **cluster privado** (NAO tags)
- Tags sao metadados de organizacao, nao controlam acesso de rede

### Container Apps

**Tipos de container:**

| Tipo                   | Funcao                                                         |
| ---------------------- | -------------------------------------------------------------- |
| **App**                | Container principal do aplicativo                              |
| **Sidecar (auxiliar)** | Container auxiliar que roda junto (ex: coletor de logs, proxy) |
| **Init**               | Roda antes do app iniciar, depois encerra                      |

- "Container que atualiza cache usado pelo app principal" → **Sidecar** (aplicativo auxiliar)
- "Container privilegiado" NAO e um tipo valido em Container Apps

**Triggers de escalonamento:**

| Trigger          | Quando usar                                                         |
| ---------------- | ------------------------------------------------------------------- |
| HTTP             | Escalar com base em requisicoes HTTP                                |
| CPU/Memoria      | Escalar com base em uso de recursos                                 |
| **Event-driven** | Escalar com base em **eventos externos** (Service Bus, Kafka, etc.) |
| Custom           | Metricas personalizadas                                             |

- "Escalar com base em mensagens do Service Bus" → **Event-driven** (controlado por evento)
- HTTP trigger **NAO** funciona para filas/Service Bus

### App Service - Logs de Diagnostico

**Niveis de severidade (do mais grave ao menos):**
1. Error
2. **Warning** (inclui Warning + Error + Critical)
3. Information
4. **Verbose** (inclui TUDO — mais detalhado)

- "Armazenar avisos e niveis superiores" → nivel **Warning** (NAO Verbose)
- Verbose inclui TUDO (excess de logs); Warning filtra apenas Warning+Error+Critical
- **Blob** = logs persistentes (mais de 1 semana); **FileSystem** = temporario (ate 12h)

---

## Backup e Recuperacao

### MARS vs MABS vs VM Backup

| Agente        | O que protege                                                | Onde instala                  |
| ------------- | ------------------------------------------------------------ | ----------------------------- |
| **MARS**      | **Arquivos e pastas**                                        | Direto no servidor (Windows)  |
| **MABS**      | Workloads completos (SQL, SharePoint, Exchange, VMs Hyper-V) | Servidor dedicado             |
| **VM Backup** | VM inteira (todos os discos)                                 | Sem agente (plataforma Azure) |

- "Backup de **arquivos e pastas**" → **agente MARS** (NAO MABS)
- "Backup de SQL Server ou SharePoint" → **MABS**
- "Backup de VM inteira" → **Azure Backup** (sem agente)
- MARS requer **Recovery Services Vault** + registrar o servidor no vault

### Recovery Services Vault vs Backup Vault

| Workload                |  RSV  | Backup Vault |
| ----------------------- | :---: | :----------: |
| VM backup               |  Sim  |     Nao      |
| Disk backup (snapshots) |  Nao  |     Sim      |
| File Share backup       |  Sim  |     Nao      |
| Blob backup             |  Nao  |     Sim      |
| Site Recovery           |  Sim  |     Nao      |

- Disk backup via Backup Vault = **snapshots incrementais** (menor custo)
- VM backup via RSV = ponto de restauracao **completo**

### Backup Policy

- Limites de retencao: daily (9999 dias), weekly (5163 semanas), monthly (1188 meses), yearly (99 anos)
- Diferenciar: backup on-demand vs scheduled, full vs incremental, snapshot vs vault tier

### Deletar Recovery Services Vault (sequencia obrigatoria)

1. **Interromper backup** de todos os itens (Stop backup + Delete data)
2. **Desabilitar soft delete** (habilitado por padrao, retencao 14 dias)
3. **Purgar itens em soft-deleted state** (Undelete → Delete permanente)
4. **Deletar vault** (so funciona quando completamente vazio)

- NAO precisa deletar as VMs (so parar o backup)
- NAO precisa criar novo vault
- **Lock IMPEDE** exclusao — e distrator quando perguntam "como deletar"
- Soft delete vem **habilitado por padrao** em todos os vaults novos
- Itens soft-deleted: podem ser restaurados via **Undelete** dentro de 14 dias
- **Immutability (WORM)** no vault impede exclusao por qualquer usuario (compliance)

### Cross Region Restore (CRR)

- CRR so funciona com **GRS** (Geo-Redundant Storage)
- Replicacao do vault **NAO pode ser alterada** apos o primeiro backup
- CRR tem RPO de ate **36 horas** (tempo de replicacao geo)
- Para RPO menor, use **Site Recovery**

### Site Recovery (DR)

- Sincronizacao inicial pode levar horas (depende do tamanho dos discos)
- RPO comeca a ser medido **apos a sincronizacao completar**
- Recovery point **retention** ≠ RPO: retention = quanto tempo pontos sao mantidos; RPO = frequencia de criacao
- App-consistent snapshots sao menos frequentes e tem maior impacto no IO

### Tipos de Failover

| Tipo               |     Data Loss      | Quando usar                             |
| ------------------ | :----------------: | --------------------------------------- |
| Test Failover      |       Nenhum       | Validacao (VM isolada, sem impacto)     |
| Planned Failover   |        Zero        | Migracao planejada (VM desligada antes) |
| Unplanned Failover | Possivel (ate RPO) | Desastre (ultimo recovery point)        |

- Apos failover real: **Commit** para confirmar ou **Change recovery point** para usar outro ponto

**Ciclo completo de failover/failback:**

```
Failover → Commit → Re-protect → Failback
```

| Status | Significado | Proximo passo |
| --- | --- | --- |
| Failover completed | VM na secundaria, nao confirmado | Commit ou Cancel |
| **Failover committed** | Confirmado, recovery points antigos removidos | **Re-protect** |
| Re-protecting | Replicacao inversa em andamento | Aguardar |
| Protected | Replicacao ativa | Pronto para failback |

- "Status antes de re-proteger" → **Failover committed** (NAO "mecanismo de failover confirmado")
- Re-protect so fica disponivel **apos commit**
- Re-protect inverte a replicacao: secundaria → primaria

### Mover Recursos

| Cenario                  | Metodo                         | Downtime |
| ------------------------ | ------------------------------ | -------- |
| Entre RGs (mesma regiao) | `az resource move`             | Nenhum   |
| Entre subscriptions      | `az resource move`             | Nenhum   |
| Entre regioes            | ASR / Resource Mover / Recriar | Variavel |

- `az resource move` **NAO** suporta move entre regioes para VMs
- Resources com **locks** nao podem ser movidos
- **Azure Resource Mover** orquestra dependencias para moves cross-region

---

## Monitoramento

### Azure Monitor - Tipos de Alerta

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

### Service Health - Tipos de Evento

1. **Service issues** — servico indisponivel (outage)
2. **Planned maintenance** — manutencao agendada
3. **Health advisories** — mudancas que podem afetar voce
4. **Security advisories** — alertas de seguranca

### Metricas Host vs Guest

| Tipo  | Exemplos                  | Agente necessario |
| ----- | ------------------------- | :---------------: |
| Host  | CPU, Network In/Out, Disk |        Nao        |
| Guest | Memoria, Processos        |  Sim (AMA + DCR)  |

- "Metrica de memoria nao aparece" → instalar **Azure Monitor Agent** + configurar **Data Collection Rules**

### Azure Monitor - Estados de Alerta

| Estado           | Significado                          | Quem define |
| ---------------- | ------------------------------------ | ----------- |
| **New**          | Alerta disparado, ninguem investigou | Automatico  |
| **Acknowledged** | Admin esta investigando              | **Manual**  |
| **Closed**       | Admin resolveu/descartou             | **Manual**  |

- Estado de alerta e **sempre manual** — NAO muda automaticamente quando a condicao some
- "50 alertas fechados" → um **administrador alterou manualmente** o estado
- Alertas NAO se fecham sozinhos (nem por idade, nem por resolver a condicao)

### Dashboard compartilhado

- Dados fixados em dashboard compartilhado: maximo **30 dias** de exibicao
- Dashboards privados: sem limite (alem da retencao do Log Analytics)

### Azure Advisor — 5 Categorias

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

### KQL (Kusto Query Language)

| Operador | Traducao na prova | O que faz | SQL equivalente |
| --- | --- | --- | --- |
| **where** | onde | Filtra linhas | WHERE |
| **summarize** | resumir | Agrupa/agrega | GROUP BY |
| **project** | projeto | Seleciona/renomeia colunas | SELECT |
| **extend** | estender | Adiciona coluna calculada | SELECT *, nova_col |

- "Agregar resultados por coluna" → **summarize** (NAO where, NAO project)
- "Filtrar linhas" → **where**
- "Selecionar colunas" → **project**
- "Adicionar coluna nova" → **extend**
- Outros operadores uteis: `render` (visualizacao), `ago()` (tempo relativo), `bin()` (agrupamento temporal)
