# Redes Virtuais

## Calculo de IPs em Subnets

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

## VNet Peering

- Peering **conecta VNets** para comunicacao direta (latencia baixa, banda alta)
- "VMs em VNets diferentes precisam se comunicar" → **Peering** (NAO DNS server, NAO route table)
- DNS server so resolve nomes, **NAO conecta** redes
- Peering e **NAO transitivo**: A↔B e B↔C **nao** significa A↔C
- Hub-spoke resolve com NVA/Firewall no hub
- **Allow Gateway Transit** permite compartilhar VPN Gateway entre VNets peered
- Cada peering e configurado independentemente nos dois lados

## UDR (User Defined Routes) e NVA

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

## VPN Gateway

### Mover VM para outra VNet (IMPORTANTE)
- **NAO e possivel** trocar a VNet de uma NIC existente
- Para conectar VM a outra VNet: **deletar a VM** (manter disco) → recriar com nova NIC na VNet desejada
- O disco e preservado, apenas a VM e recriada
- "Excluir VM e recriar com nova NIC na VNet2" → **SIM, atende ao objetivo**
- "Adicionar nova NIC na VNet2 sem deletar" → **NAO** (NIC so pode ser de uma VNet)
- "Mover VM para RG da VNet2" → **NAO** (mover RG nao muda a VNet)

## VPN Gateway

- **S2S** = conexao permanente on-premises ↔ Azure (IPsec/IKE)
- **P2S** = clientes individuais → Azure (certificado ou RADIUS)
- **GatewaySubnet** e obrigatoria (nome exato), recomendado /27+
- Active-Passive (padrao) vs Active-Active (HA com 2 tuneis)
- **Allow Gateway Transit** (hub) + **Use Remote Gateways** (spoke) = compartilhar gateway
- **P2S + novo peering/subnet** → **reinstalar cliente VPN P2S** para obter novas rotas (rotas nao atualizam automaticamente)

## NSG (Network Security Groups)

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

## ASG vs Service Tag vs IP Range

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

## Service Endpoints e Private Endpoints

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

## NSG Flow Logs e Traffic Analytics

- Flow Logs v2 e obrigatorio para Traffic Analytics
- Requerem Storage Account + opcionalmente Log Analytics
- Dados no container `insights-logs-networksecuritygroupflowevent`
- "Analisar trafego de rede" → NSG Flow Logs + Traffic Analytics

## DNS

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

## Network Watcher

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
- **Problemas intermitentes** → verificar (1) **health probe** + (2) **SKU compativel** (LB e IP mesmo SKU)
- Health probe mal configurada causa flapping (backend healthy/unhealthy alternando) = intermitencia
- SKUs incompativeis (Standard LB + Basic IP) = nao funciona
- NSG **NAO** e causa de intermitencia — NSG ou bloqueia sempre ou permite sempre
- Modo de distribuicao (session persistence) NAO resolve problemas de conectividade

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
