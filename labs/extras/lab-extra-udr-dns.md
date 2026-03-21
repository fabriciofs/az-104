# Lab Extra - UDR e DNS (Independente)

**Objetivo:** Praticar User Defined Routes e DNS (publica + privada) do zero, sem dependencia dos labs anteriores.
**Tempo estimado:** 1h30
**Custo:** ~$0.50 (4 VMs Ubuntu B1s por ~1h30 + VNets gratuito) — Parte 5 opcional adiciona 1 VM

> **IMPORTANTE:** Este lab cria recursos do zero. Faca cleanup ao final para evitar custos.

## Diagrama

```
┌───────────────────────────────────────────────────────────────┐
│                       rg-lab-udr-dns                          │
│                                                               │
│  ┌─────────────────────────┐    ┌──────────────────────────┐  │
│  │  vnet-frontend          │    │  vnet-backend            │  │
│  │  10.10.0.0/16           │    │  10.20.0.0/16            │  │
│  │                         │    │                          │  │
│  │  snet-web               │    │  snet-api                │  │
│  │  10.10.1.0/24           │    │  10.20.1.0/24            │  │
│  │  vm-web ←───── peering ──────→ vm-api                   │  │
│  │                         │    │                          │  │
│  │  snet-firewall          │    └──────────────────────────┘  │
│  │  10.10.2.0/24           │                                  │
│  │  vm-nva (Ubuntu)        │    ┌──────────────────────────┐  │
│  │  10.10.2.4              │    │ DNS Zones:               │  │
│  │  IP fwd: NIC + OS       │    │                          │  │
│  └─────────────────────────┘    │ • Public: lab.contoso.com│  │
│                                 │ • Private: app.internal  │  │
│  ┌─────────────────────────┐    │   └─ Links: ambas VNets  │  │
│  │ Route Tables:           │    └──────────────────────────┘  │
│  │ • rt-force-firewall     │                                  │
│  │   (snet-api → 10.10.2.4)│                                  │
│  │ • rt-block-internet     │                                  │
│  │   (snet-web → None)     │                                  │
│  └─────────────────────────┘                                  │
└───────────────────────────────────────────────────────────────┘
```

---

## Parte 1 — Setup base (VNets + VMs)

### O que estamos construindo e por que

Vamos criar um cenario simples com **duas redes separadas** (frontend e backend) conectadas por peering. Isso simula uma arquitetura comum em producao: o frontend (web servers) fica numa rede, o backend (APIs/banco) fica em outra, e elas se comunicam via peering.

A separacao em VNets diferentes permite:
- **Isolamento de seguranca** — regras de rede diferentes para cada camada
- **Controle de trafego** — UDRs para forcar trafego por um firewall
- **Equipes independentes** — cada time gerencia sua propria rede

### Task 1.1: Criar Resource Group

Tudo fica num unico Resource Group para facilitar o cleanup no final.

1. Pesquise **Resource groups** > **+ Create**:

   | Setting | Value            |
   | ------- | ---------------- |
   | Name    | `rg-lab-udr-dns` |
   | Region  | **(US) East US** |

2. **Review + create** > **Create**

### Task 1.2: Criar vnet-frontend

A VNet frontend simula a rede onde ficam os web servers voltados para o usuario. Criamos **duas subnets** aqui:
- **snet-web** — onde a VM web vai ficar
- **snet-firewall** — onde ficaria um NVA (firewall/proxy) em producao. Neste lab nao vamos colocar nada aqui, mas o IP `10.10.2.4` sera usado como destino numa UDR para demonstrar o comportamento.

1. Pesquise **Virtual Networks** > **Create**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource Group | `rg-lab-udr-dns` |
   | Name           | `vnet-frontend`  |
   | Region         | **(US) East US** |

2. Aba **IP Addresses**: `10.10.0.0/16`

   > `/16` reserva 65.536 IPs. Os dois primeiros octetos (10.10) sao fixos, os dois ultimos variam. Usamos /16 por conveniencia — em producao, o tamanho depende do planejamento de capacidade.

3. Delete subnet default, adicione:

   | Subnet          | Starting address | Size  |
   | --------------- | ---------------- | ----- |
   | `snet-web`      | `10.10.1.0`      | `/24` |
   | `snet-firewall` | `10.10.2.0`      | `/24` |

   > Por que nao usar `10.10.0.0/24`? Funciona, mas e boa pratica reservar o primeiro bloco. Comecamos em `.1.0` e `.2.0` para organizar melhor.

4. **Review + create** > **Create**

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
# Criar VNet com duas subnets
az network vnet create \
  --resource-group rg-lab-udr-dns \
  --name vnet-frontend \
  --location eastus \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name snet-web \
  --subnet-prefix 10.10.1.0/24

# Adicionar a segunda subnet (a primeira ja foi criada com a VNet)
az network vnet subnet create \
  --resource-group rg-lab-udr-dns \
  --vnet-name vnet-frontend \
  --name snet-firewall \
  --address-prefixes 10.10.2.0/24
```

> **Observe:** No CLI, `az network vnet create` cria a VNet + primeira subnet em um unico comando. Subnets adicionais exigem `az network vnet subnet create` separado.

**PowerShell:**

```powershell
# Criar as definicoes de subnet primeiro (objetos em memoria, nada e criado ainda)
$snetWeb = New-AzVirtualNetworkSubnetConfig `
  -Name "snet-web" `
  -AddressPrefix "10.10.1.0/24"

$snetFirewall = New-AzVirtualNetworkSubnetConfig `
  -Name "snet-firewall" `
  -AddressPrefix "10.10.2.0/24"

# Criar a VNet com ambas as subnets de uma vez
New-AzVirtualNetwork `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "vnet-frontend" `
  -Location "eastus" `
  -AddressPrefix "10.10.0.0/16" `
  -Subnet $snetWeb, $snetFirewall
```

> **Diferenca importante entre CLI e PowerShell:** No CLI, voce cria a VNet com uma subnet e adiciona as demais depois. No PowerShell, voce define as subnets como objetos (`New-AzVirtualNetworkSubnetConfig`) e passa todas de uma vez para `New-AzVirtualNetwork`. Ambos produzem o mesmo resultado.

</details>

### Task 1.3: Criar vnet-backend

A VNet backend simula a rede interna onde ficam APIs e bancos de dados. Apenas uma subnet aqui — o backend e mais simples.

**Detalhe importante:** O address space (`10.20.0.0/16`) NAO pode se sobrepor ao da frontend (`10.10.0.0/16`). Se ambas usassem `10.10.0.0/16`, o peering seria impossivel — o Azure nao saberia para onde rotear o trafego.

1. **Virtual Networks** > **Create**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource Group | `rg-lab-udr-dns` |
   | Name           | `vnet-backend`   |
   | Region         | **(US) East US** |

2. Aba **IP Addresses**: `10.20.0.0/16`

3. Delete subnet default, adicione:

   | Subnet     | Starting address | Size  |
   | ---------- | ---------------- | ----- |
   | `snet-api` | `10.20.1.0`      | `/24` |

4. **Review + create** > **Create**

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
az network vnet create \
  --resource-group rg-lab-udr-dns \
  --name vnet-backend \
  --location eastus \
  --address-prefixes 10.20.0.0/16 \
  --subnet-name snet-api \
  --subnet-prefix 10.20.1.0/24
```

**PowerShell:**

```powershell
$snetApi = New-AzVirtualNetworkSubnetConfig `
  -Name "snet-api" `
  -AddressPrefix "10.20.1.0/24"

New-AzVirtualNetwork `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "vnet-backend" `
  -Location "eastus" `
  -AddressPrefix "10.20.0.0/16" `
  -Subnet $snetApi
```

</details>

### Task 1.4: Configurar VNet Peering

**O que e peering?** E uma conexao direta entre duas VNets que permite que recursos em uma enxerguem recursos na outra. Sem peering, mesmo que as VNets estejam no mesmo Resource Group e regiao, elas sao **completamente isoladas** — como dois predios sem estrada entre eles.

**Caracteristicas importantes do peering:**
- **Baixa latencia** — trafego fica dentro do backbone da Microsoft, nao passa pela internet
- **Bidirecional** — mas precisa configurar dos dois lados (o portal faz isso automaticamente quando voce cria de um lado)
- **NAO transitivo** — se A↔B e B↔C, A NAO fala com C automaticamente

1. Navegue para **vnet-frontend** > **Peerings** > **+ Add**:

   | Setting                                    | Value                           |
   | ------------------------------------------ | ------------------------------- |
   | This virtual network - Peering link name   | `frontend-to-backend`           |
   | Remote virtual network - Peering link name | `backend-to-frontend`           |
   | Virtual network                            | `vnet-backend (rg-lab-udr-dns)` |

2. Deixe todas as opcoes padrao > **Add**

3. Verifique que o status e **Connected** em ambos os lados

   > Se aparecer "Initiated" em vez de "Connected", aguarde — o Azure precisa configurar os dois lados. Se ficar "Disconnected", verifique se os address spaces nao se sobrepoe.

### Task 1.5: Criar vm-web

Esta VM simula um web server no frontend. Colocamos na snet-web.

**Por que NIC NSG = None?** Para este lab, queremos testar UDRs sem interferencia de NSGs. Em producao, voce SEMPRE teria um NSG. Aqui, removemos para isolar variaveis — se algo nao funcionar, sabemos que nao e o NSG.

**Por que sem Public IP?** Vamos usar **Run Command** (portal) para executar comandos nas VMs. O Run Command usa o Azure Agent, que se comunica pelo backbone interno da Microsoft — nao precisa de IP publico, SSH, nem porta aberta. Isso e mais seguro e simula melhor um ambiente de producao.

1. Pesquise **Virtual Machines** > **+ Create** > **Azure virtual machine**:

   | Setting               | Value                                  |
   | --------------------- | -------------------------------------- |
   | Resource Group        | `rg-lab-udr-dns`                       |
   | Name                  | `vm-web`                               |
   | Region                | **(US) East US**                       |
   | Image                 | **Ubuntu Server 24.04 LTS - x64 Gen2** |
   | Size                  | **Standard_B1s**                       |
   | Authentication type   | **SSH public key**                     |
   | Username              | `azureuser`                            |
   | SSH public key source | **Generate new key pair**              |

   > Ao selecionar "Generate new key pair", o Azure cria e oferece download da chave privada no momento do deploy. Guarde-a caso precise de SSH direto no futuro, mas neste lab nao vamos usar.

2. Aba **Networking**:

   | Setting         | Value           |
   | --------------- | --------------- |
   | Virtual network | `vnet-frontend` |
   | Subnet          | `snet-web`      |
   | Public IP       | **None**        |
   | NIC NSG         | **None**        |

   > **Sem Public IP e sem NSG** — a VM fica completamente isolada da internet. Acesso sera exclusivamente via **Run Command** no portal. Em producao, voce usaria Azure Bastion para acesso interativo.

3. **Review + create** > **Create** (faca download da chave SSH quando solicitado)

### Task 1.6: Criar vm-api

Esta VM simula uma API no backend. Mesma configuracao, mas na outra VNet/subnet.

1. Repita o processo:

   | Setting               | Value                                                                     |
   | --------------------- | ------------------------------------------------------------------------- |
   | Resource Group        | `rg-lab-udr-dns`                                                          |
   | Name                  | `vm-api`                                                                  |
   | Region                | **(US) East US**                                                          |
   | Image                 | **Ubuntu Server 24.04 LTS - x64 Gen2**                                    |
   | Size                  | **Standard_B1s**                                                          |
   | Authentication type   | **SSH public key**                                                        |
   | Username              | `azureuser`                                                               |
   | SSH public key source | **Use existing key stored in Azure** (selecione a chave criada na vm-web) |

2. Aba **Networking**:

   | Setting         | Value          |
   | --------------- | -------------- |
   | Virtual network | `vnet-backend` |
   | Subnet          | `snet-api`     |
   | Public IP       | **None**       |
   | NIC NSG         | **None**       |

3. **Review + create** > **Create**

### Task 1.7: Testar conectividade via Run Command

**Como acessar as VMs sem IP publico?** Pelo **Run Command** no portal Azure. Ele executa scripts dentro da VM usando o Azure Agent (walinuxagent), que se comunica com o Azure pelo backbone interno — nao passa pela internet publica.

**Por que ping funciona por padrao no Ubuntu?** Diferente do Windows (que bloqueia ICMP por padrao no firewall), o Ubuntu permite ICMP sem configuracao extra. Menos um passo!

Portal > **vm-api** > **Operations** > **Run command** > **RunShellScript**:

```bash
# Testar ping para vm-web via peering
ping -c 4 10.10.1.4
```

Portal > **vm-web** > **Operations** > **Run command** > **RunShellScript**:

```bash
# Testar ping para vm-api via peering
ping -c 4 10.20.1.4
```

> **Checkpoint:** Se o ping funciona nos dois sentidos, o peering esta OK. Anote este comportamento — ele vai mudar quando voce adicionar UDRs.

> **Se o ping falhar:** (1) Confira se o peering esta "Connected". (2) Verifique os IPs reais das VMs em VM > Networking > Private IP (podem nao ser .4). (3) Aguarde 1-2 min apos criar as VMs para o agent inicializar.

---

## Parte 2 — User Defined Routes (UDR)

### O que sao UDRs e por que existem

Quando voce cria VNets e peerings, o Azure configura **rotas automaticas** (system routes) que fazem tudo funcionar. Por exemplo:
- Trafego dentro da VNet → rota para VirtualNetwork
- Trafego para VNet peered → rota para VNetPeering
- Trafego para internet → rota para Internet

UDRs (User Defined Routes) permitem **sobrescrever** essas rotas automaticas. Isso e essencial para:
- **Forcar trafego por um firewall** (NVA) antes de chegar ao destino
- **Bloquear trafego** para destinos especificos (next hop = None)
- **Redirecionar trafego** para um VPN gateway ou outro caminho

```
Sem UDR:    vm-api ──peering──→ vm-web  (direto, rota automatica)
Com UDR:    vm-api ──peering──→ 10.10.2.4 (NVA) ──→ vm-web
Com None:   vm-web ──→ internet  BLOQUEADO (next hop = None)
```

### Conceitos-chave antes de comecar

| Conceito              | Significado                                                                         |
| --------------------- | ----------------------------------------------------------------------------------- |
| **Route Table**       | Container de rotas. Voce cria a tabela e depois associa a uma subnet.               |
| **Route (rota)**      | Uma regra dentro da tabela: "para destino X, envie para Y"                          |
| **Next hop**          | Para onde o pacote deve ir. Tipos: Virtual appliance, VNet gateway, Internet, None  |
| **Virtual appliance** | Um IP de uma VM que atua como firewall/proxy (NVA)                                  |
| **None**              | Descarte o pacote (blackhole)                                                       |
| **Associacao**        | Uma route table so funciona quando associada a uma subnet                           |
| **Unidirecional**     | A UDR afeta apenas o trafego **saindo** da subnet associada, nao o trafego chegando |

### Task 2.1: Criar Route Table rt-force-firewall

**O que vamos fazer:** Criar uma route table que diz "todo trafego com destino `10.10.1.0/24` (snet-web) deve passar pelo IP `10.10.2.4` (onde ficaria um NVA)".

**Por que isso e util em producao?** Imagine que voce quer que todo trafego do backend para o frontend passe por um firewall para inspecao. Sem UDR, o trafego vai direto via peering. Com UDR, voce forca o desvio.

**Detalhe intencional:** Nao existe nenhuma VM em `10.10.2.4`. Isso faz com que o trafego seja **descartado**, o que e perfeito para demonstrar que a UDR esta funcionando — se o ping falhar, a rota esta ativa.

1. Pesquise **Route tables** > **+ Create**:

   | Setting                  | Value               |
   | ------------------------ | ------------------- |
   | Resource Group           | `rg-lab-udr-dns`    |
   | Region                   | **(US) East US**    |
   | Name                     | `rt-force-firewall` |
   | Propagate gateway routes | **Yes**             |

   > **Propagate gateway routes = Yes** significa que rotas aprendidas de um VPN Gateway (se existir) serao adicionadas automaticamente a esta tabela. Neste lab nao temos gateway, mas em producao isso e importante para que VMs atras de UDR ainda consigam falar com on-premises.

2. **Review + create** > **Create** > **Go to resource**

3. **Settings** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `to-web-via-nva`      |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.10.1.0/24`        |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.10.2.4`           |

   > **Lendo a rota em portugues:** "Quando um pacote sai desta subnet com destino a qualquer IP em 10.10.1.0/24, encaminhe para 10.10.2.4 em vez de usar a rota padrao."

4. Clique em **Add**

   > **Nota:** A route table existe, mas ainda nao faz nada! Ela precisa ser **associada** a uma subnet para entrar em vigor. E como escrever uma regra no papel mas nao colocar na parede.

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
# Criar a route table
az network route-table create \
  --resource-group rg-lab-udr-dns \
  --name rt-force-firewall \
  --location eastus

# Adicionar a rota
az network route-table route create \
  --resource-group rg-lab-udr-dns \
  --route-table-name rt-force-firewall \
  --name to-web-via-nva \
  --address-prefix 10.10.1.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.10.2.4

# Associar a snet-api (Task 2.2 — feito aqui para manter o fluxo)
az network vnet subnet update \
  --resource-group rg-lab-udr-dns \
  --vnet-name vnet-backend \
  --name snet-api \
  --route-table rt-force-firewall
```

> **Atencao no CLI:** A associacao de route table a uma subnet e feita via `subnet update`, NAO via um comando especifico de route table. Isso e contra-intuitivo e pode confundir na prova. O parametro e `--route-table`.

**PowerShell:**

```powershell
# Criar a route table
$rt = New-AzRouteTable `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "rt-force-firewall" `
  -Location "eastus"

# Adicionar a rota (via Add-AzRouteConfig + Set-AzRouteTable)
$rt | Add-AzRouteConfig `
  -Name "to-web-via-nva" `
  -AddressPrefix "10.10.1.0/24" `
  -NextHopType "VirtualAppliance" `
  -NextHopIpAddress "10.10.2.4" | Set-AzRouteTable

# Associar a snet-api (Task 2.2)
$vnet = Get-AzVirtualNetwork -ResourceGroupName "rg-lab-udr-dns" -Name "vnet-backend"
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "snet-api"
$subnet.RouteTable = $rt
$vnet | Set-AzVirtualNetwork
```

> **Padrao PowerShell (pipeline):** No PowerShell, a criacao de rotas segue o padrao `Get → Add/Set Config → Set Resource`. Voce obtem o objeto, modifica em memoria, e depois persiste com `Set-AzRouteTable` ou `Set-AzVirtualNetwork`. Esse padrao se repete para NSGs, subnets e outros recursos de rede.

</details>

### Task 2.2: Associar rt-force-firewall a snet-api

**O que acontece ao associar:** A partir de agora, todo trafego **saindo** de snet-api sera avaliado pelas rotas desta tabela. Se houver match, a UDR sobrescreve a rota automatica do Azure.

**Detalhe critico:** A UDR afeta o trafego **saindo** de snet-api, nao o trafego **chegando**. Isso significa que vm-web → vm-api (sentido contrario) NAO e afetado.

1. No rt-force-firewall > **Subnets** > **+ Associate**:

   | Setting         | Value          |
   | --------------- | -------------- |
   | Virtual network | `vnet-backend` |
   | Subnet          | `snet-api`     |

2. Clique em **OK**

### Task 2.3: Testar — ping deve falhar

Agora vem o momento da verdade. O ping de vm-api para vm-web deve falhar porque:
1. vm-api envia pacote para `10.10.1.4`
2. A UDR intercepta: "destino 10.10.1.0/24 → envie para 10.10.2.4"
3. O pacote vai para `10.10.2.4`
4. Nao existe nada em `10.10.2.4` → pacote descartado

Via **Run Command** em **vm-api** (Portal > vm-api > Operations > Run command > RunShellScript):

```bash
ping -c 4 10.10.1.4
```

> **Resultado esperado:** Timeout (100% packet loss). O trafego esta sendo enviado para 10.10.2.4 (NVA), que nao existe. O pacote e descartado.

**Agora teste o sentido contrario.** Via **Run Command** em **vm-web**:

```bash
ping -c 4 10.20.1.4
```

> **Pergunta para pensar:** Este ping funciona? Por que?

<details>
<summary>Ver resposta</summary>

**NAO funciona!** Embora a UDR esteja apenas na snet-api, o ping precisa de **ida E volta**:

1. **Request** (vm-web → vm-api): chega normalmente — snet-web nao tem UDR
2. **Reply** (vm-api → vm-web): o destino e `10.10.1.4` — a UDR na snet-api intercepta! Envia para 10.10.2.4 (NVA inexistente) → descartado

```
vm-web ──request──→ vm-api     ✅ chega (sem UDR na snet-web)
vm-web ←──reply──── vm-api     ❌ UDR intercepta reply (destino 10.10.1.0/24 → NVA)
```

**Conceito importante:** UDRs sao unidirecionais — afetam apenas trafego **saindo** da subnet. Mas ping (e qualquer comunicacao TCP/UDP) exige trafego nos **dois sentidos**. Se a UDR bloqueia o caminho de volta, a comunicacao falha mesmo que a ida funcione.

**Na prova:** Quando disserem "UDR na subnet A afeta trafego da subnet B?", a resposta e: nao diretamente, mas pode afetar as **respostas** que saem de A de volta para B.

</details>

### Task 2.4: Criar vm-nva e fazer o ping funcionar via NVA

**Objetivo:** Provar que a UDR nao e apenas um "bloqueio" — ela realmente **redireciona** trafego. Na Task 2.3, o ping falhou porque nao havia nada em 10.10.2.4. Agora vamos colocar uma VM la, habilitar forwarding, e ver o ping funcionar novamente — passando pelo NVA.

```
Antes:   vm-api → 10.10.2.4 (ninguem) → ❌ descartado
Depois:  vm-api → 10.10.2.4 (vm-nva) → encaminha → vm-web → ✅ ping!
```

**Passo 1 — Criar vm-nva na snet-firewall:**

1. **Virtual Machines** > **+ Create** > **Azure virtual machine**:

   | Setting               | Value                                  |
   | --------------------- | -------------------------------------- |
   | Resource Group        | `rg-lab-udr-dns`                       |
   | Name                  | `vm-nva`                               |
   | Region                | **(US) East US**                       |
   | Image                 | **Ubuntu Server 24.04 LTS - x64 Gen2** |
   | Size                  | **Standard_B1s**                       |
   | Authentication type   | **SSH public key**                     |
   | Username              | `azureuser`                            |
   | SSH public key source | **Generate new key pair**              |

2. Aba **Networking**:

   | Setting         | Value           |
   | --------------- | --------------- |
   | Virtual network | `vnet-frontend` |
   | Subnet          | `snet-firewall` |
   | Public IP       | **None**        |
   | NIC NSG         | **None**        |

3. Aba **Advanced** > **Custom data**:

   Cole este script no campo Custom data:

   ```bash
   #!/bin/bash
   echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
   sysctl -p
   ```

   > **O que e Custom Data?** E um script cloud-init que o Azure injeta na VM no **primeiro boot**. A VM ja liga com IP forwarding ativo no Linux — sem precisar de Run Command depois. Na prova, cloud-init aparece como forma de automatizar configuracao inicial de VMs.

   > **Por que `/etc/sysctl.conf` em vez de `sysctl -w`?** O `sysctl -w` ativa imediatamente mas **nao sobrevive a reboot**. Gravando em `/etc/sysctl.conf`, a configuracao e **persistente**.

4. **Review + create** > **Create**

5. Verifique o IP privado: Portal > vm-nva > **Overview** > Private IP address
   > Deve ser `10.10.2.4` (primeiro IP disponivel na subnet). Se for diferente, voce precisara atualizar a rota na Task 2.1 para apontar para o IP correto.

**Passo 2 — Habilitar IP forwarding na NIC (camada Azure):**

IP forwarding precisa ser habilitado em **duas camadas**: Azure (NIC) e SO (Linux). O Custom Data ja cuidou da camada Linux. Agora falta a camada Azure.

Por padrao, o Azure descarta pacotes que chegam numa NIC mas nao sao destinados ao IP dela. IP forwarding diz ao Azure: "esta NIC pode receber pacotes destinados a outros IPs".

1. Portal > vm-nva > **Networking** > clique na **NIC** (ex: `vm-nvaXXX`)
2. **Settings** > **IP configurations**
3. **IP forwarding** = **Enabled** > **Save**

   > Sem isso, mesmo que a VM exista em 10.10.2.4 e o Linux tenha ip_forward=1, o Azure descarta o pacote na camada de rede antes de chegar ao SO.

> **Por que sao DUAS camadas?** Azure (NIC) controla o que **chega** na VM. Linux (kernel) controla o que a VM **faz** com o pacote. Ambos precisam permitir forwarding. Isso e cobrado na prova!
>
> | Camada | Onde configurar | O que faz |
> | ------ | --------------- | --------- |
> | **Azure (NIC)** | Portal > NIC > IP forwarding | Permite que a NIC aceite pacotes nao destinados ao seu IP |
> | **Linux (SO)** | `sysctl net.ipv4.ip_forward=1` | Permite que o kernel encaminhe pacotes entre interfaces |

**Passo 3 — Verificar que o Custom Data funcionou:**

Run Command em **vm-nva** (RunShellScript):

```bash
cat /proc/sys/net/ipv4/ip_forward
```

> **Resultado esperado:** `1`. Se retornar `0`, o cloud-init pode nao ter rodado ainda (aguarde 1-2 min) ou falhou. Nesse caso, rode manualmente: `sudo sysctl -w net.ipv4.ip_forward=1`

**Passo 4 — Testar: o ping deve funcionar agora!**

Run Command em **vm-api**:

```bash
ping -c 4 10.10.1.4
```

> **Resultado esperado:** Ping funciona! O caminho completo:
> 1. vm-api envia pacote para 10.10.1.4
> 2. UDR redireciona para 10.10.2.4 (vm-nva)
> 3. Azure entrega na NIC do vm-nva (IP forwarding na NIC = enabled)
> 4. Linux encaminha para 10.10.1.4 (ip_forward = 1)
> 5. vm-web recebe e responde

> **Se ainda falhar:** (1) Confirme o IP do vm-nva — se nao for 10.10.2.4, atualize a rota. (2) Verifique IP forwarding na NIC (portal). (3) Verifique ip_forward no SO. (4) Verifique o peering Allow forwarded traffic.

**Passo 5 — Confirmar via traceroute que o trafego passa pelo NVA:**

Run Command em **vm-api**:

```bash
tracepath -n 10.10.1.4
```

> `tracepath` ja vem instalado no Ubuntu (diferente de `traceroute` que precisa instalar). O flag `-n` mostra IPs em vez de tentar resolver nomes.

> **Resultado esperado:** Dois saltos — primeiro `10.10.2.4` (vm-nva), depois `10.10.1.4` (vm-web). Isso prova visualmente que o trafego esta passando pelo NVA.

> **Por que NAO precisamos de "Allow forwarded traffic" no peering?**
> Porque o NVA (vm-nva) e o destino final (vm-web) estao na **mesma VNet** (vnet-frontend). O forwarding acontece **dentro** da VNet, sem cruzar o peering de volta:
> ```
> vm-api (backend) ──peering──→ vm-nva (frontend) ──mesma VNet──→ vm-web (frontend)
>                    ↑ trafego normal                ↑ forwarding interno
> ```
> "Allow forwarded traffic" seria necessario se o NVA precisasse **reenviar trafego de volta pelo peering** para outra VNet — ex: NVA no frontend encaminhando para uma VM no backend.

> **Dica prova — checklist NVA completo:**
> **(1) UDR** apontando para o NVA, **(2) IP forwarding na NIC** (Azure), **(3) IP forwarding no OS**, **(4) Allow forwarded traffic no peering** (apenas se o NVA encaminha trafego **cruzando** o peering), **(5) NSG** permitindo o trafego. Esqueceu qualquer um = trafego descartado.

### Task 2.5: Verificar roteamento com Network Watcher

**Por que usar Network Watcher?** Em producao, voce nao sabe "de cabeca" qual rota esta ativa. O Network Watcher mostra exatamente para onde o Azure esta enviando o pacote — e a ferramenta de diagnostico para problemas de roteamento.

**Next Hop** responde a pergunta: "se um pacote sair do IP X com destino Y, para onde ele vai?"

1. Pesquise **Network Watcher** > **Next hop**:

   | Setting                | Value       |
   | ---------------------- | ----------- |
   | Virtual machine        | `vm-api`    |
   | Source IP address      | `10.20.1.4` |
   | Destination IP address | `10.10.1.4` |

2. Clique em **Next hop**

   > **Resultado esperado:** Next hop type = **VirtualAppliance**, next hop IP = **10.10.2.4**. Isso confirma que o UDR esta ativo e o Azure esta redirecionando o trafego.

3. Agora teste o sentido contrario — selecione `vm-web` como source:

   | Setting                | Value       |
   | ---------------------- | ----------- |
   | Virtual machine        | `vm-web`    |
   | Source IP address      | `10.10.1.4` |
   | Destination IP address | `10.20.1.4` |

   > **Resultado esperado:** Next hop type = **VNetPeering**. Sem UDR neste sentido — prova visual de que UDRs sao unidirecionais.

   > **Dica prova:** Na AZ-104, "qual ferramenta para verificar o proximo salto do trafego?" → **Next Hop** (Network Watcher).

### Task 2.6: Criar Route Table rt-block-internet

**Cenario real:** Voce tem VMs que processam dados sensiveis e NAO devem ter acesso a internet. Uma forma de garantir isso e com UDR + next hop = None.

> **Nota sobre nossas VMs:** Como criamos as VMs **sem IP publico**, elas ja nao tem acesso de saida para a internet (o Azure nao fornece SNAT sem IP publico ou NAT Gateway). Voce pode confirmar: `ping -c 4 microsoft.com` retorna 100% packet loss mesmo sem UDR. Ainda assim, vamos criar a UDR porque: **(1)** em producao, VMs frequentemente tem NAT Gateway ou Load Balancer com outbound rules — a UDR None seria a camada extra de protecao; **(2)** o conceito e cobrado na prova; **(3)** a UDR afeta o Run Command (aprendizado bonus).

**Qual a diferenca de bloquear com NSG vs UDR?**
- **NSG** bloqueia por porta/protocolo/IP → voce precisa conhecer os IPs de destino
- **UDR None** bloqueia por destino de rede → descarta TUDO para aquele prefixo, independente de porta

Para bloquear internet, `0.0.0.0/0` (match-all) + None e mais completo que tentar listar IPs no NSG.

1. **Route tables** > **+ Create**:

   | Setting | Value               |
   | ------- | ------------------- |
   | Name    | `rt-block-internet` |
   | Region  | **(US) East US**    |
   | RG      | `rg-lab-udr-dns`    |

2. **Create** > **Go to resource** > **Routes** > **+ Add**:

   | Setting                  | Value            |
   | ------------------------ | ---------------- |
   | Route name               | `block-internet` |
   | Destination type         | **IP Addresses** |
   | Destination IP addresses | `0.0.0.0/0`      |
   | Next hop type            | **None**         |

   > **Lendo a rota:** "Para qualquer destino (0.0.0.0/0 = tudo), descarte o pacote." Mas calma — isso nao bloqueia TUDO? Nao, porque rotas mais especificas vencem. A rota de peering (10.20.0.0/16) e mais especifica que 0.0.0.0/0, entao o trafego para o backend continua funcionando.

3. **Add**

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
# Criar route table + rota + associar (tudo junto)
az network route-table create \
  --resource-group rg-lab-udr-dns \
  --name rt-block-internet \
  --location eastus

az network route-table route create \
  --resource-group rg-lab-udr-dns \
  --route-table-name rt-block-internet \
  --name block-internet \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type None

# Associar a snet-web (Task 2.7)
az network vnet subnet update \
  --resource-group rg-lab-udr-dns \
  --vnet-name vnet-frontend \
  --name snet-web \
  --route-table rt-block-internet
```

> **next-hop-type None:** No CLI, o tipo `None` e passado como string literal. Valores possiveis: `VirtualAppliance`, `VnetLocal`, `Internet`, `VirtualNetworkGateway`, `None`.

**PowerShell:**

```powershell
$rtBlock = New-AzRouteTable `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "rt-block-internet" `
  -Location "eastus"

$rtBlock | Add-AzRouteConfig `
  -Name "block-internet" `
  -AddressPrefix "0.0.0.0/0" `
  -NextHopType "None" | Set-AzRouteTable

# Associar a snet-web (Task 2.7)
$vnet = Get-AzVirtualNetwork -ResourceGroupName "rg-lab-udr-dns" -Name "vnet-frontend"
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "snet-web"
$subnet.RouteTable = $rtBlock
$vnet | Set-AzVirtualNetwork
```

</details>

### Task 2.7: Associar rt-block-internet a snet-web

1. **Subnets** > **+ Associate** > `vnet-frontend` / `snet-web` > **OK**

   > **AVISO: Run Command na vm-web vai parar de funcionar!** O Run Command precisa de conectividade de saida para reportar resultados ao Azure. Com `0.0.0.0/0 → None`, o Azure Agent na vm-web nao consegue devolver a resposta. Os testes serao feitos a partir de **vm-api** (que nao e afetada) e pelo **portal** (Effective Routes, Network Watcher).

   > A partir de agora, vm-web nao consegue acessar a internet, mas AINDA fala com vm-api via peering.

### Task 2.8: Testar — internet bloqueada mas peering funciona

**Este e o teste mais importante do lab.** Ele demonstra a regra de **longest prefix match** (rota mais especifica vence):

```
Rotas ativas na snet-web:
  10.10.0.0/16 → VirtualNetwork  (rota automatica, /16)
  10.20.0.0/16 → VNetPeering     (rota automatica, /16)
  0.0.0.0/0    → None             (UDR, /0)
```

Quando vm-web envia pacote para `10.20.1.4` (vm-api):
- Match com `10.20.0.0/16` (/16 = 16 bits especificos)
- Match com `0.0.0.0/0` (/0 = 0 bits especificos)
- **/16 vence /0** → trafego vai por peering, funciona!

Quando vm-web envia pacote para `13.107.42.14` (microsoft.com):
- NAO match com nenhuma rota especifica
- Match com `0.0.0.0/0` → None → pacote descartado!

**Como testar se Run Command nao funciona na vm-web?** Use **vm-api** (que nao tem UDR) e ferramentas do portal que nao dependem do Agent.

**Teste 1 — Peering ainda funciona (vm-api → vm-web):**

Portal > **vm-api** > Run command > RunShellScript:

```bash
# vm-api pinga vm-web? Sim — peering funciona (rota /16 vence /0)
ping -c 4 10.10.1.4
```

> **Resultado esperado:** Ping funciona! A rota de peering e mais especifica que a UDR de bloqueio.

**Teste 2 — Internet bloqueada na vm-web (via Network Watcher):**

O **Next Hop** do Network Watcher consulta as rotas no Azure — nao depende do Agent dentro da VM.

1. **Network Watcher** > **Next hop**:

   | Setting                | Value          |
   | ---------------------- | -------------- |
   | Virtual machine        | `vm-web`       |
   | Source IP address      | `10.10.1.4`    |
   | Destination IP address | `13.107.42.14` |

   > Pode usar qualquer IP publico como destino (ex: 8.8.8.8).

2. **Resultado esperado:** Next hop type = **None**. Confirma que trafego para internet e descartado.

3. Agora teste destino interno:

   | Setting                | Value       |
   | ---------------------- | ----------- |
   | Virtual machine        | `vm-web`    |
   | Source IP address      | `10.10.1.4` |
   | Destination IP address | `10.20.1.4` |

4. **Resultado esperado:** Next hop type = **VNetPeering**. Trafego interno nao e afetado pelo bloqueio.

> **Isso demonstra visualmente o longest prefix match:** mesmo destino vm-web, mas dependendo do IP de destino, a rota e diferente (/16 para peering, /0 para internet).

**Teste 3 — Run Command na vm-web trava (demonstracao):**

Tente rodar qualquer comando via Run Command na vm-web:

```bash
echo "hello"
```

> **Resultado esperado:** Fica em "Script execution in progress..." indefinidamente. O Agent executa o script, mas nao consegue enviar o resultado de volta (precisa de internet). Isso prova que `0.0.0.0/0 → None` bloqueia **tudo** que nao tem rota mais especifica — incluindo a comunicacao do Azure Agent.

<details>
<summary>Regra completa de precedencia de rotas no Azure</summary>

Quando ha multiplas rotas que fazem match, o Azure escolhe nesta ordem:

1. **Longest prefix match** — a rota mais especifica vence (/24 > /16 > /0)
2. Se mesmo prefixo, **User route** vence **System route**
3. Se mesmo prefixo e tipo, **BGP route** vence **System route**

Na prova, 90% das questoes sobre rotas se resolvem com a regra 1 (longest prefix match).

</details>

### Task 2.9: Verificar Effective Routes

**Effective Routes** mostra TODAS as rotas ativas numa NIC — tanto as automaticas quanto as UDRs. E a visao completa do que o Azure "ve" quando precisa rotear um pacote.

1. Navegue para **Network Watcher** > **Effective routes** > selecione a NIC da vm-web

   > Caminho alternativo: **vm-web** > **Networking** > **Network settings** > clique na NIC > **Help** > **Effective routes**

2. Observe todas as rotas aplicadas:

   | Source   | Address Prefix | Next Hop Type  | Explicacao                     |
   | -------- | -------------- | -------------- | ------------------------------ |
   | Default  | 10.10.0.0/16   | VirtualNetwork | Trafego dentro da propria VNet |
   | **User** | **0.0.0.0/0**  | **None**       | Sua UDR bloqueando internet    |
   | Default  | 10.20.0.0/16   | VNetPeering    | Trafego para VNet peered       |

   > **Observe a coluna Source:** "Default" = rota automatica do Azure. "User" = sua UDR. Quando ha conflito no mesmo prefixo, User vence Default. Quando os prefixos sao diferentes, o mais especifico vence.

   > **Dica prova:** "Qual ferramenta mostra TODAS as rotas aplicadas numa NIC?" → **Effective Routes**.

### Task 2.10: Desassociar rt-block-internet de snet-web

**Importante:** As proximas partes (DNS) precisam de Run Command na vm-web. Desassocie a rt-block-internet para restaurar a conectividade.

1. Portal > **rt-block-internet** > **Subnets** > clique em `snet-web` > **Remove**

   > Run Command na vm-web volta a funcionar imediatamente.

### Task 2.11: Remover UDR e confirmar restauracao

**O que acontece ao desassociar uma UDR?** As rotas automaticas do Azure voltam a funcionar imediatamente. Nao precisa reiniciar nada — o Azure recalcula as rotas em tempo real.

1. No rt-force-firewall > **Subnets** > clique em snet-api > **Remove** (desassociar)

2. Via Run Command em **vm-api**, teste novamente:

```bash
ping -c 4 10.10.1.4
```

> **Resultado esperado:** Ping volta a funcionar. Ao desassociar o UDR, a rota padrao de peering e restaurada automaticamente.

> **Conceito:** UDRs NAO deletam as rotas automaticas — apenas as sobrescrevem temporariamente. Removeu a UDR? As rotas originais voltam como se nada tivesse acontecido.

### Referencia: ARM Template para Route Table com rotas

Em cenarios de IaC (Infrastructure as Code), voce pode definir route tables e suas rotas declarativamente via ARM Template. Abaixo esta um exemplo completo que cria a `rt-force-firewall` com a rota `to-web-via-nva` — equivalente ao que fizemos nas Tasks 2.1 e 2.2.

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "nvaIpAddress": {
      "type": "string",
      "defaultValue": "10.10.2.4",
      "metadata": {
        "description": "IP privado do NVA (Virtual Appliance)"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Network/routeTables",
      "apiVersion": "2023-09-01",
      "name": "rt-force-firewall",
      "location": "[resourceGroup().location]",
      "properties": {
        "disableBgpRoutePropagation": false,
        "routes": [
          {
            "name": "to-web-via-nva",
            "properties": {
              "addressPrefix": "10.10.1.0/24",
              "nextHopType": "VirtualAppliance",
              "nextHopIpAddress": "[parameters('nvaIpAddress')]"
            }
          },
          {
            "name": "block-internet",
            "properties": {
              "addressPrefix": "0.0.0.0/0",
              "nextHopType": "None"
            }
          }
        ]
      }
    }
  ],
  "outputs": {
    "routeTableId": {
      "type": "string",
      "value": "[resourceId('Microsoft.Network/routeTables', 'rt-force-firewall')]"
    }
  }
}
```

> **Pontos importantes para a prova sobre ARM Templates de rotas:**
>
> | Elemento | Detalhes |
> |----------|----------|
> | **type** | `Microsoft.Network/routeTables` (route table) e `routes` como array dentro de `properties` |
> | **nextHopType** | Valores validos: `VirtualAppliance`, `VnetLocal`, `Internet`, `VirtualNetworkGateway`, `None` |
> | **nextHopIpAddress** | Obrigatorio **apenas** quando `nextHopType` = `VirtualAppliance`. Para `None`, `Internet`, etc., NAO se usa esse campo |
> | **disableBgpRoutePropagation** | `false` = propaga rotas BGP (equivale a "Propagate gateway routes = Yes" no portal). `true` = bloqueia |
> | **Rotas inline** | No ARM, as rotas podem ser definidas **dentro** do recurso da route table (como acima) ou como recursos filhos separados (`Microsoft.Network/routeTables/routes`) |
>
> **Para deployar este template:**
>
> ```bash
> # CLI
> az deployment group create \
>   --resource-group rg-lab-udr-dns \
>   --template-file route-table.json \
>   --parameters nvaIpAddress=10.10.2.4
> ```
>
> ```powershell
> # PowerShell
> New-AzResourceGroupDeployment `
>   -ResourceGroupName "rg-lab-udr-dns" `
>   -TemplateFile "route-table.json" `
>   -nvaIpAddress "10.10.2.4"
> ```

---

## Parte 3 — DNS

### O que e DNS e por que importa

DNS (Domain Name System) traduz **nomes** em **IPs**. Sem DNS, voce teria que decorar IPs para acessar qualquer coisa (imagine acessar `142.250.217.78` em vez de `google.com`).

No Azure, existem **dois tipos** de DNS zones:

| Tipo        | Quem resolve                  | Uso                           |
| ----------- | ----------------------------- | ----------------------------- |
| **Publica** | Qualquer pessoa na internet   | Sites, APIs publicas          |
| **Privada** | Apenas VMs nas VNets linkadas | Comunicacao interna entre VMs |

**Analogia:**
- DNS publica = lista telefonica publicada (qualquer pessoa consulta)
- DNS privada = ramal interno da empresa (so funciona de dentro)

### Task 3.1: Criar zona DNS publica

Uma zona DNS publica hospeda registros que podem ser consultados por **qualquer pessoa** na internet. Voce pode criar qualquer nome (como `lab.contoso.com`), mas para que funcione de verdade na internet, voce precisaria configurar os name servers no registrador do dominio (Namecheap, GoDaddy, etc.).

Neste lab, como nao somos donos do dominio `contoso.com`, vamos testar consultando diretamente os name servers do Azure (em vez de depender do DNS publico da internet).

1. Pesquise **DNS zones** > **+ Create**:

   | Setting        | Value             |
   | -------------- | ----------------- |
   | Resource Group | `rg-lab-udr-dns`  |
   | Name           | `lab.contoso.com` |

   > **Region = Global:** DNS zones sao recursos **globais** — nao ficam numa regiao especifica. Os name servers sao distribuidos mundialmente.

2. **Review + create** > **Create** > **Go to resource**

3. **Copie** o endereco de um Name Server (ex: `ns1-03.azure-dns.com`)

   > Voce vai precisar deste name server para testar com nslookup. Ele e o "telefone" do servidor que sabe responder sobre a sua zona.

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
# Criar zona DNS publica
az network dns zone create \
  --resource-group rg-lab-udr-dns \
  --name lab.contoso.com

# Ver os name servers atribuidos
az network dns zone show \
  --resource-group rg-lab-udr-dns \
  --name lab.contoso.com \
  --query "nameServers" -o tsv
```

**PowerShell:**

```powershell
# Criar zona DNS publica
New-AzDnsZone `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "lab.contoso.com"

# Ver os name servers
(Get-AzDnsZone -ResourceGroupName "rg-lab-udr-dns" -Name "lab.contoso.com").NameServers
```

> **Nota:** DNS zones sao recursos globais — nao e necessario especificar `-Location`. O Azure distribui os name servers automaticamente.

</details>

### Task 3.2: Adicionar registros DNS

Vamos criar tres tipos de registro diferentes para entender as diferencas:

**Registro A** — O mais basico. Aponta um nome diretamente para um IP.

1. **+ Record set** — Registro A:

   | Setting    | Value       |
   | ---------- | ----------- |
   | Name       | `www`       |
   | Type       | **A**       |
   | TTL        | `1`         |
   | IP address | `10.10.1.4` |

   > Isso cria: `www.lab.contoso.com → 10.10.1.4`. Simples e direto.

**Registro CNAME** — Um "alias" (apelido) que aponta para OUTRO nome, nao para um IP.

2. **+ Record set** — Registro CNAME:

   | Setting | Value                 |
   | ------- | --------------------- |
   | Name    | `portal`              |
   | Type    | **CNAME**             |
   | TTL     | `1`                   |
   | Alias   | `www.lab.contoso.com` |

   > Isso cria: `portal.lab.contoso.com → www.lab.contoso.com → 10.10.1.4`. O CNAME "segue" o A record. Se voce mudar o IP do `www`, o `portal` automaticamente aponta para o novo IP.
   >
   > **Pegadinha prova:** CNAME **nao pode** ser usado no apex domain (raiz, como `contoso.com`). Apenas em subdomains (`www.contoso.com`, `portal.contoso.com`).

**Registro TXT** — Armazena texto livre. Usado para verificacao de dominio, SPF (email), etc.

3. **+ Record set** — Registro TXT:

   | Setting | Value                        |
   | ------- | ---------------------------- |
   | Name    | `@`                          |
   | Type    | **TXT**                      |
   | TTL     | `1`                          |
   | Value   | `v=spf1 include:contoso.com` |

   > `@` significa o dominio raiz (`lab.contoso.com`). SPF e um registro que diz quais servidores podem enviar email em nome do dominio. Nao afeta roteamento — e apenas metadado.

### Task 3.3: Testar DNS publica via Cloud Shell

**nslookup** e a ferramenta de diagnostico DNS. Ela pergunta a um name server "qual o IP de tal nome?"

```bash
# Registro A — pergunta: "qual IP de www.lab.contoso.com?"
nslookup www.lab.contoso.com <name-server>
# Resposta esperada: 10.10.1.4

# CNAME — pergunta: "qual IP de portal.lab.contoso.com?"
nslookup portal.lab.contoso.com <name-server>
# Resposta esperada: alias para www.lab.contoso.com, que resolve para 10.10.1.4

# TXT — pergunta: "qual texto esta no registro TXT de lab.contoso.com?"
nslookup -type=TXT lab.contoso.com <name-server>
# Resposta esperada: "v=spf1 include:contoso.com"
```

> **Por que passamos o name server?** Porque `lab.contoso.com` nao esta registrado na internet de verdade. Os DNS publicos (Google 8.8.8.8, Cloudflare 1.1.1.1) nao sabem que essa zona existe. Ao passar o name server do Azure, perguntamos diretamente a quem sabe.

> **Sem o name server** (`nslookup www.lab.contoso.com` sozinho) → falha, porque o DNS padrao da internet nao conhece a sua zona de lab.

<details>
<summary>Tabela: Tipos de registro DNS mais comuns na prova</summary>

| Tipo      | Funcao                          | Exemplo                           |
| --------- | ------------------------------- | --------------------------------- |
| **A**     | Nome → IPv4                     | `www → 10.1.1.4`                  |
| **AAAA**  | Nome → IPv6                     | `www → 2001:db8::1`               |
| **CNAME** | Nome → outro nome (alias)       | `portal → www.contoso.com`        |
| **MX**    | Email server do dominio         | `contoso.com → mail.contoso.com`  |
| **TXT**   | Texto livre (SPF, verificacao)  | `contoso.com → "v=spf1 ..."`      |
| **NS**    | Name servers do dominio         | `contoso.com → ns1.azure-dns.com` |
| **SOA**   | Autoridade da zona (automatico) | Metadados da zona                 |

</details>

### Task 3.4: Criar zona DNS privada

**Diferenca crucial:** Zonas privadas NAO sao visiveis na internet. Elas so resolvem para VMs dentro de VNets que voce **explicitamente linkar**. E como um sistema de ramais interno — so funciona dentro da empresa.

**Quando usar DNS privada?**
- VMs precisam se comunicar por nome em vez de IP (mais facil de lembrar, nao quebra se IP mudar)
- Microservicos internos (`api.internal`, `database.internal`)
- Ambientes de dev/test que imitam producao

1. Pesquise **Private DNS zones** > **+ Create**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource Group | `rg-lab-udr-dns` |
   | Name           | `app.internal`   |

   > Voce pode usar qualquer nome (`.internal`, `.corp`, `.local`). O Azure nao valida se o dominio existe publicamente. Em producao, evite usar dominios publicos reais para nao causar conflito.

2. **Review + create** > **Create** > **Go to resource**

   > Note que a zona privada **nao tem name servers** (diferente da publica). Ela e resolvida internamente pelo DNS do Azure (168.63.129.16), nao por name servers publicos.

<details>
<summary>Alternativa: CLI e PowerShell</summary>

**Azure CLI:**

```bash
# Criar zona DNS privada
az network private-dns zone create \
  --resource-group rg-lab-udr-dns \
  --name app.internal

# Criar links com auto registration (Task 3.5 — feito aqui para manter o fluxo)
az network private-dns link vnet create \
  --resource-group rg-lab-udr-dns \
  --zone-name app.internal \
  --name link-frontend \
  --virtual-network vnet-frontend \
  --registration-enabled true

az network private-dns link vnet create \
  --resource-group rg-lab-udr-dns \
  --zone-name app.internal \
  --name link-backend \
  --virtual-network vnet-backend \
  --registration-enabled true
```

> **CLI — DNS publica vs privada:** Os comandos sao diferentes! `az network dns` (publica) vs `az network private-dns` (privada). O parametro de auto registration e `--registration-enabled true` (nao `--auto-registration`).

**PowerShell:**

```powershell
# Criar zona DNS privada
New-AzPrivateDnsZone `
  -ResourceGroupName "rg-lab-udr-dns" `
  -Name "app.internal"

# Criar links com auto registration (Task 3.5)
New-AzPrivateDnsVirtualNetworkLink `
  -ResourceGroupName "rg-lab-udr-dns" `
  -ZoneName "app.internal" `
  -Name "link-frontend" `
  -VirtualNetworkId (Get-AzVirtualNetwork -ResourceGroupName "rg-lab-udr-dns" -Name "vnet-frontend").Id `
  -EnableRegistration

New-AzPrivateDnsVirtualNetworkLink `
  -ResourceGroupName "rg-lab-udr-dns" `
  -ZoneName "app.internal" `
  -Name "link-backend" `
  -VirtualNetworkId (Get-AzVirtualNetwork -ResourceGroupName "rg-lab-udr-dns" -Name "vnet-backend").Id `
  -EnableRegistration
```

> **PowerShell — VirtualNetworkId:** O cmdlet `New-AzPrivateDnsVirtualNetworkLink` exige o **Resource ID** completo da VNet, nao apenas o nome. Por isso usamos `(Get-AzVirtualNetwork ...).Id` inline para obter o ID. Esse padrao de passar Resource IDs e muito comum no PowerShell do Azure.

</details>

### Task 3.5: Criar Virtual Network Links

**O que e um link?** E a conexao entre a zona DNS privada e uma VNet. Sem link, as VMs na VNet **nao conseguem** resolver nomes da zona. E como conectar o PABX (sistema de ramais) ao andar do predio — sem a conexao, os telefones daquele andar nao funcionam.

**Auto registration:** Quando habilitado, o Azure cria automaticamente registros A para cada VM na VNet. VM criou? Registro aparece. VM deletou? Registro some. Sem auto registration, voce precisa criar os registros manualmente.

1. **Virtual network links** > **+ Add**:

   | Setting                  | Value           |
   | ------------------------ | --------------- |
   | Link name                | `link-frontend` |
   | Virtual network          | `vnet-frontend` |
   | Enable auto registration | **Enabled**     |

2. **OK** e aguarde

3. **+ Add** novamente:

   | Setting                  | Value          |
   | ------------------------ | -------------- |
   | Link name                | `link-backend` |
   | Virtual network          | `vnet-backend` |
   | Enable auto registration | **Enabled**    |

4. **OK** e aguarde

   > **Ponto critico para prova:** Peering entre VNets **NAO compartilha DNS**. Mesmo que frontend↔backend estejam peered, voce precisa linkar **AMBAS** as VNets a zona DNS. Uma VNet sem link nao resolve nomes da zona — ponto final.

### Task 3.6: Verificar auto registration

Agora veja a "magica" do auto registration — os registros ja devem ter sido criados automaticamente.

1. Na zona `app.internal` > **Overview** > **Record sets**

2. Verifique se apareceram automaticamente:

   | Name     | Type | Value     |
   | -------- | ---- | --------- |
   | `vm-web` | A    | 10.10.1.4 |
   | `vm-nva` | A    | 10.10.2.4 |
   | `vm-api` | A    | 10.20.1.4 |

   > Se as VMs ja estavam criadas quando voce habilitou o link com auto registration, os registros aparecem em ate 1-2 minutos.

   > **O que acontece se voce criar uma nova VM?** O registro e criado automaticamente em segundos. Se deletar a VM? O registro e removido. Tudo automatico.

### Task 3.7: Testar DNS privada entre VMs

Este e o teste mais satisfatório — em vez de decorar IPs, voce usa nomes legíveis.

Via Run Command em **vm-web** (RunShellScript):

```bash
# Resolver vm-api pelo nome — DNS traduz nome → IP
nslookup vm-api.app.internal
# Resposta esperada: 10.20.1.4

# Ping pelo FQDN — prova que funciona ponta a ponta
ping -c 4 vm-api.app.internal
```

Via Run Command em **vm-api** (RunShellScript):

```bash
nslookup vm-web.app.internal
# Resposta esperada: 10.10.1.4

ping -c 4 vm-web.app.internal
```

> **Resultado esperado:** Ambas resolvem e o ping funciona. Ubuntu permite ICMP por padrao — sem necessidade de regra de firewall.

> **Observe:** Voce nao precisou passar nenhum name server! As VMs usam o DNS interno do Azure (`168.63.129.16`) automaticamente, que sabe sobre as zonas privadas linkadas.

### Task 3.8: Adicionar registro manual + testar

**Objetivo:** Demonstrar que DNS so traduz nomes → IPs. Nao valida se o IP existe, se tem VM, ou se esta acessivel.

1. Na zona `app.internal` > **+ Record set**:

   | Setting    | Value        |
   | ---------- | ------------ |
   | Name       | `database`   |
   | Type       | **A**        |
   | TTL        | `1`          |
   | IP address | `10.20.1.99` |

   > Nao existe nenhuma VM com IP `10.20.1.99`. Mesmo assim, o registro sera criado sem erro.

2. Via Run Command em **vm-web** (RunShellScript):

```bash
# O DNS resolve? Sim!
nslookup database.app.internal
# Resposta: 10.20.1.99

# O ping funciona? Nao!
ping -c 4 database.app.internal
# Resposta: timeout (nao existe nada nesse IP)
```

> **Conceito importante:** DNS e resolucao de nomes apenas uma "lista telefonica" — traduz nomes em IPs. Se o IP esta errado, offline, ou nao existe, o DNS nao sabe e nao se importa. Ele so faz a traducao.

### Task 3.9: Testar isolamento — VNet sem link

**Objetivo:** Provar que sem Virtual Network Link, a VNet nao consegue resolver nomes da zona privada — mesmo que tenha peering com outra VNet que tem link.

1. Remova o link `link-backend`: **Virtual network links** > `link-backend` > **Delete**

   > Agora vnet-backend nao tem link com `app.internal`. Mas vnet-frontend ainda tem.

2. Via Run Command em **vm-api** (RunShellScript):

```bash
nslookup vm-web.app.internal
```

> **Resultado esperado:** **Falha.** Mesmo que vm-api tenha peering com vnet-frontend (que TEM link), a resolucao DNS nao "herda" do peering. Cada VNet precisa de seu proprio link.

> **Essa e uma das pegadinhas mais cobradas na prova:** "VNets peered compartilham DNS?" → **NAO.** Peering compartilha conectividade de rede (IP-to-IP), mas DNS e um servico separado que requer link explicito.

3. Via Run Command em **vm-web** (RunShellScript):

```bash
nslookup vm-api.app.internal
```

> **Resultado esperado:** Pode ainda resolver por um tempo (o registro existe na zona), mas o auto registration de vm-api sera removido em breve ja que vnet-backend nao esta mais linkada.

4. **Recrie** o link `link-backend` com auto registration para restaurar tudo

---

## Parte 3B — Delegacao de Subdominio DNS (registro NS)

> **Contexto de prova:** "Voce tem a zona contoso.com e precisa delegar test.contoso.com para outro servidor DNS. O que fazer?" → Criar um record set NS chamado "test" na zona contoso.com. Isso caiu no simulado e e um conceito que confunde.

### Task 3B.1: Entender delegacao DNS (conceito)

```
Delegacao = "eu gerencio contoso.com, mas test.contoso.com e responsabilidade de outro DNS"

contoso.com (zona pai — voce gerencia)
  ├── www    → A record  → 1.2.3.4       (voce resolve)
  ├── api    → A record  → 5.6.7.8       (voce resolve)
  └── test   → NS record → ns1.outro.com (DELEGADO — outro DNS resolve)
                           ns2.outro.com

Quando alguem consulta app.test.contoso.com:
  1. DNS raiz → "contoso.com esta no Azure DNS"
  2. Azure DNS → "test.contoso.com? Veja no ns1.outro.com" (NS record)
  3. ns1.outro.com → "app.test.contoso.com = 9.8.7.6" (resolve la)
```

### Task 3B.2: Criar zona filha e delegar via NS record

```bash
# Usar a zona publica criada na Task 3.1 (lab.contoso.com ou similar)
# Se nao tem, crie uma:
az network dns zone create \
  --resource-group rg-lab-udr-dns \
  --name lab.contoso.com

# Criar uma zona filha (simula "outro servidor DNS")
az network dns zone create \
  --resource-group rg-lab-udr-dns \
  --name test.lab.contoso.com

# Ver os name servers da zona filha
az network dns zone show \
  --resource-group rg-lab-udr-dns \
  --name test.lab.contoso.com \
  --query "nameServers" -o tsv
```

> **Anote os name servers** da zona filha (ex: ns1-08.azure-dns.com, ns2-08.azure-dns.net, etc.)

### Task 3B.3: Criar o registro NS na zona pai (A RESPOSTA DA PROVA)

```bash
# Obter os name servers da zona filha
NS1=$(az network dns zone show --resource-group rg-lab-udr-dns --name test.lab.contoso.com --query "nameServers[0]" -o tsv)
NS2=$(az network dns zone show --resource-group rg-lab-udr-dns --name test.lab.contoso.com --query "nameServers[1]" -o tsv)
NS3=$(az network dns zone show --resource-group rg-lab-udr-dns --name test.lab.contoso.com --query "nameServers[2]" -o tsv)
NS4=$(az network dns zone show --resource-group rg-lab-udr-dns --name test.lab.contoso.com --query "nameServers[3]" -o tsv)

# CRIAR O REGISTRO NS NA ZONA PAI — esta e a delegacao!
az network dns record-set ns add-record \
  --resource-group rg-lab-udr-dns \
  --zone-name lab.contoso.com \
  --record-set-name test \
  --nsdname $NS1

az network dns record-set ns add-record \
  --resource-group rg-lab-udr-dns \
  --zone-name lab.contoso.com \
  --record-set-name test \
  --nsdname $NS2

az network dns record-set ns add-record \
  --resource-group rg-lab-udr-dns \
  --zone-name lab.contoso.com \
  --record-set-name test \
  --nsdname $NS3

az network dns record-set ns add-record \
  --resource-group rg-lab-udr-dns \
  --zone-name lab.contoso.com \
  --record-set-name test \
  --nsdname $NS4

echo "Delegacao criada: test.lab.contoso.com delegado via NS records na zona pai"
```

> **O que fizemos:** Criamos um record set NS chamado `test` na zona `lab.contoso.com`. Os valores NS apontam para os name servers da zona `test.lab.contoso.com`. Agora, qualquer consulta para `*.test.lab.contoso.com` sera redirecionada para esses name servers.

### Task 3B.4: Verificar a delegacao pelo portal

1. Portal > **DNS zones** > **lab.contoso.com** > **Record sets**
2. Procure o registro `test` do tipo **NS**
3. Observe que aponta para os name servers da zona filha

4. Agora va em **test.lab.contoso.com** > **Record sets**
5. Crie um registro A de teste:

```bash
az network dns record-set a add-record \
  --resource-group rg-lab-udr-dns \
  --zone-name test.lab.contoso.com \
  --record-set-name app \
  --ipv4-address 10.99.99.99
```

6. Teste a resolucao (se o dominio fosse real e estivesse delegado no registrador):

```bash
# Consultar diretamente nos name servers do Azure
nslookup app.test.lab.contoso.com $NS1
```

> **Resultado esperado:** Resolve para 10.99.99.99. O DNS da zona pai (lab.contoso.com) delegou para a zona filha (test.lab.contoso.com) que contem o registro.

### Task 3B.5: Verificar que os outros tipos NAO funcionam para delegacao

```bash
# Ver todos os record sets na zona pai
az network dns record-set list \
  --resource-group rg-lab-udr-dns \
  --zone-name lab.contoso.com \
  --query "[].{name:name, type:type, records:nsRecords || aRecords || soaRecord}" \
  -o table
```

> **Por que as outras opcoes da prova estao erradas:**
> | Opcao | Por que NAO funciona para delegacao |
> |---|---|
> | Registro A | Aponta para um **IP**, nao para outro DNS server |
> | Registro SOA | SOA e criado **automaticamente** na zona filha, nao na pai |
> | Modificar A da zona pai | Nao tem relacao com delegacao de subdominio |
> | **Registro NS** | **CORRETO** — aponta para os name servers responsaveis pelo subdominio |

### Dicas de prova — Delegacao DNS

```
┌─────────────────────────────────────────────────────────────────────┐
│              DELEGACAO DNS — REGRAS PARA PROVA                      │
│                                                                     │
│  1. Delegacao = registro NS na ZONA PAI (nao na filha)             │
│     "Delegar test.contoso.com" → criar NS "test" em contoso.com   │
│                                                                     │
│  2. O registro NS aponta para NAME SERVERS, nao para IPs           │
│     NS = "quem responde por esse subdominio"                       │
│     A  = "qual IP desse nome" (diferente!)                         │
│                                                                     │
│  3. SOA e criado AUTOMATICAMENTE na zona filha                     │
│     Voce NAO precisa criar SOA manualmente                         │
│                                                                     │
│  4. A delegacao e feita APENAS na zona pai                         │
│     Nao precisa criar nada "especial" na zona filha               │
│     (so os registros normais que ela vai gerenciar)                │
│                                                                     │
│  5. Tipos de registro DNS para prova:                              │
│     A     → Nome → IPv4                                            │
│     AAAA  → Nome → IPv6                                            │
│     CNAME → Nome → Outro nome (alias) — NAO no apex!              │
│     NS    → Delegacao de subdominio                                │
│     SOA   → Autoridade da zona (automatico)                        │
│     MX    → Servidor de email                                      │
│     TXT   → Texto livre (SPF, verificacao de dominio)              │
│     PTR   → IP → Nome (reverse DNS)                                │
│     SRV   → Servico especifico (porta + protocolo)                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Comparacao de Metodos

Ao longo deste lab, os recursos foram criados pelo **Portal** com alternativas em **CLI**, **PowerShell** e **ARM Template**. A tabela abaixo resume quando usar cada metodo e suas diferencas praticas.

### Quando usar cada metodo

| Metodo | Melhor para | Quando evitar |
|--------|-------------|---------------|
| **Portal** | Aprendizado, exploracao, recursos pontuais | Ambientes de producao repetitivos, automacao |
| **CLI (`az`)** | Scripts Bash, pipelines Linux/macOS, Cloud Shell | Quem ja domina PowerShell e prefere consistencia |
| **PowerShell** | Automacao Windows, scripts complexos com logica, pipelines Azure DevOps | Ambientes Linux puros sem necessidade de logica complexa |
| **ARM Template** | IaC, deploys repetitivos, ambientes identicos (dev/staging/prod) | Prototipacao rapida, recursos experimentais |

### Diferencas de sintaxe por operacao

| Operacao | CLI | PowerShell |
|----------|-----|------------|
| Criar VNet | `az network vnet create --name X --address-prefixes Y` | `New-AzVirtualNetwork -Name X -AddressPrefix Y` |
| Criar subnet | `az network vnet subnet create --vnet-name X --name Y` | `Add-AzVirtualNetworkSubnetConfig` + `Set-AzVirtualNetwork` |
| Criar route table | `az network route-table create --name X` | `New-AzRouteTable -Name X` |
| Adicionar rota | `az network route-table route create --route-table-name X` | `Add-AzRouteConfig` + `Set-AzRouteTable` (pipeline) |
| Associar RT a subnet | `az network vnet subnet update --route-table X` | `$subnet.RouteTable = $rt` + `Set-AzVirtualNetwork` |
| Criar DNS publica | `az network dns zone create --name X` | `New-AzDnsZone -Name X` |
| Criar DNS privada | `az network private-dns zone create --name X` | `New-AzPrivateDnsZone -Name X` |
| Link VNet a DNS privada | `az network private-dns link vnet create` | `New-AzPrivateDnsVirtualNetworkLink -VirtualNetworkId $id` |

### Padroes que caem na prova

```
┌──────────────────────────────────────────────────────────────────────┐
│                PADROES CLI vs POWERSHELL (PROVA)                      │
│                                                                      │
│  1. CLI usa nomes de recursos diretamente:                           │
│     --route-table rt-force-firewall                                  │
│     PowerShell frequentemente exige Resource IDs:                    │
│     -VirtualNetworkId (Get-AzVirtualNetwork ...).Id                  │
│                                                                      │
│  2. PowerShell segue o padrao GET → MODIFY → SET:                    │
│     $vnet = Get-AzVirtualNetwork ...                                 │
│     Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet ...       │
│     $vnet | Set-AzVirtualNetwork                                     │
│                                                                      │
│  3. CLI separa DNS publica e privada pelo comando:                   │
│     az network dns ...          → publica                            │
│     az network private-dns ...  → privada                            │
│                                                                      │
│  4. ARM Template: nextHopIpAddress so aparece com VirtualAppliance   │
│     Se usar nextHopType = "None", NAO inclua nextHopIpAddress        │
│                                                                      │
│  5. Associar route table a subnet:                                   │
│     CLI: feito via "subnet update" (nao via route-table!)            │
│     PowerShell: atribuir ao objeto $subnet.RouteTable e salvar       │
│     ARM: definir routeTable.id dentro da subnet no template          │
└──────────────────────────────────────────────────────────────────────┘
```

### ARM Template vs CLI/PowerShell

| Aspecto | CLI / PowerShell | ARM Template |
|---------|------------------|--------------|
| **Abordagem** | Imperativa ("faca isso, depois aquilo") | Declarativa ("quero este estado final") |
| **Idempotencia** | Precisa tratar manualmente (verificar se existe antes de criar) | Nativo — re-deploy atualiza sem duplicar |
| **Ordem de recursos** | Voce controla a sequencia | O Azure resolve dependencias automaticamente (`dependsOn`) |
| **Versionamento** | Script versionado no Git | Template JSON versionado no Git |
| **Complexidade** | Mais simples para 1-2 recursos | Mais adequado para 10+ recursos interligados |
| **Prova** | Questoes pedem comandos especificos e parametros | Questoes pedem identificar tipo de recurso, propriedades, ou erros no JSON |

---

## Parte 4 — Questoes de Prova

### Questao 1
**Voce tem uma UDR com destino 10.10.1.0/24 → Virtual appliance (10.10.2.4) associada a snet-api. Um pacote de vm-api para 10.10.1.4 e descartado. Qual a causa?**

A) O peering nao esta configurado
B) O NVA em 10.10.2.4 nao existe ou nao faz forwarding
C) O NSG esta bloqueando
D) A rota padrao esta sobrescrevendo a UDR

<details>
<summary>Ver resposta</summary>

**B)** O UDR direciona para 10.10.2.4, mas se nao existe VM nesse IP (ou nao tem IP forwarding habilitado), o pacote e descartado. UDRs direcionam trafego, mas nao garantem que o destino esta funcional.

**Por que nao A?** O peering pode estar OK — o problema e que o UDR desvia o trafego para um IP que nao responde.
**Por que nao D?** UDRs (User) sempre sobrescrevem rotas Default para o mesmo prefixo.

</details>

### Questao 2
**Voce criou uma rota 0.0.0.0/0 → None na snet-web. A vm-web ainda consegue pingar vm-api (10.20.1.4). Por que?**

A) A rota None nao bloqueia ICMP
B) O peering ignora route tables
C) A rota de peering (10.20.0.0/16) e mais especifica que 0.0.0.0/0
D) O NSG permite o trafego

<details>
<summary>Ver resposta</summary>

**C)** Longest prefix match: `/16` (16 bits especificos) vence `/0` (0 bits especificos). O trafego para 10.20.x.x usa a rota de peering; apenas trafego sem match mais especifico (internet) e bloqueado.

**Por que nao A?** None bloqueia TUDO — ICMP, TCP, UDP, sem excecao.
**Por que nao B?** Peering NAO ignora route tables. Se voce criasse uma UDR `10.20.0.0/16 → None`, o peering pararia de funcionar.

</details>

### Questao 3
**Voce criou uma zona DNS privada `app.internal` e linkou a vnet-frontend com auto registration. Qual registro e criado automaticamente?**

A) CNAME para o hostname da VM
B) A record com o IP publico da VM
C) A record com o IP privado da VM
D) PTR record para reverse lookup

<details>
<summary>Ver resposta</summary>

**C)** Auto registration cria registros **A** com o **IP privado** da VM. O nome e o hostname da VM (ex: `vm-web.app.internal → 10.10.1.4`).

**Por que nao B?** DNS privada e para comunicacao interna — usar IP publico nao faria sentido.
**Por que nao A?** CNAME nao e criado automaticamente. Apenas registros A.

</details>

### Questao 4
**Voce tem duas VNets peered. A zona DNS privada `app.internal` esta linkada apenas a vnet-frontend. Uma VM na vnet-backend tenta resolver `vm-web.app.internal`. O que acontece?**

A) Resolve via peering
B) Resolve via Azure DNS publico
C) Falha — vnet-backend nao tem link para a zona
D) Resolve se tiver auto registration

<details>
<summary>Ver resposta</summary>

**C)** Peering conecta redes (camada IP), mas **nao compartilha DNS** (camada de resolucao de nomes). Sao servicos independentes. Cada VNet precisa de seu proprio Virtual Network Link.

Voce comprovou isso na Task 3.9 deste lab.

</details>

### Questao 5
**Voce quer que o trafego de snet-api para 10.10.1.0/24 passe por um NVA (10.10.2.4). O que voce precisa configurar ALEM da UDR?**

A) NSG permitindo o trafego
B) IP forwarding na NIC do NVA + IP forwarding no OS
C) Peering com Allow Forwarded Traffic
D) Todas as anteriores

<details>
<summary>Ver resposta</summary>

**D)** Para NVA funcionar em producao, voce precisa de **tudo**:

1. **UDR** apontando para o NVA (direciona o trafego)
2. **IP forwarding na NIC** do NVA no portal Azure (permite que a NIC aceite pacotes destinados a outros IPs)
3. **IP forwarding no OS** da VM (Windows: routing, Linux: ip_forward)
4. **Peering com "Allow Forwarded Traffic"** (se o trafego cruza VNets — permite pacotes encaminhados pelo NVA)
5. **NSG** permitindo o trafego na subnet do NVA (sem NSG Allow, o pacote e bloqueado)

Neste lab nao configuramos tudo isso porque o objetivo era demonstrar o comportamento da UDR. Mas na prova, lembre: NVA requer IP forwarding em DUAS camadas (NIC + OS).

</details>

### Questao 6
**Voce tem uma zona DNS do Azure chamada contoso.com. Precisa adicionar um subdominio test.contoso.com e delegar para um servidor DNS diferente. Como voce deve configurar a delegacao?**

A) Adicione um registro A para test.contoso.com
B) Adicione um conjunto de registros NS chamado "test" a zona contoso.com
C) Crie o registro SOA para test.contoso.com
D) Modifique o registro A de contoso.com

<details>
<summary>Ver resposta</summary>

**Resposta: B) Registro NS chamado "test" na zona contoso.com**

Para delegar um subdominio, voce cria um record set NS na **zona pai** com o nome do subdominio. Os valores NS apontam para os name servers que gerenciam a zona filha.

**A) Errada:** Registro A aponta para um IP, nao delega para outro DNS.
**C) Errada:** SOA e criado automaticamente na zona filha — voce nao cria SOA na zona pai para delegar.
**D) Errada:** Modificar o registro A da zona pai nao tem relacao com delegacao de subdominio.

**Regra:** Delegacao DNS = registro NS na zona PAI apontando para os name servers da zona FILHA.

</details>

### Questao 7
**Voce criou a zona test.contoso.com no Azure DNS. A zona pai contoso.com tambem esta no Azure DNS. Usuarios na internet nao conseguem resolver nomes em test.contoso.com. O que esta faltando?**

A) Virtual Network Link para a zona test.contoso.com
B) Registro NS "test" na zona contoso.com apontando para os name servers de test.contoso.com
C) Registro CNAME na zona contoso.com
D) Habilitar auto registration na zona test.contoso.com

<details>
<summary>Ver resposta</summary>

**Resposta: B) Registro NS na zona pai**

A zona filha existe mas ninguem sabe que ela existe — a zona pai precisa do registro NS para redirecionar consultas. Sem ele, o DNS para em contoso.com e retorna "nao encontrado" para qualquer *.test.contoso.com.

**A) Errada:** VNet Link e para DNS **privada**, nao publica.
**C) Errada:** CNAME cria alias para um nome, nao delega um subdominio.
**D) Errada:** Auto registration e para DNS privada, nao publica.

</details>

---

## Parte 5 (Opcional) — Hub-Spoke com NVA

### Por que Hub-Spoke?

Ate agora, vm-nva e vm-web estao na **mesma VNet** (vnet-frontend). Isso significa que o forwarding do NVA acontece internamente, sem cruzar peering. Em producao, a arquitetura padrao e **hub-spoke**:

- **Hub** = VNet central com servicos compartilhados (firewall/NVA, VPN Gateway, DNS)
- **Spokes** = VNets de workload (frontend, backend, etc.) que se conectam ao hub

Spokes **nao falam entre si diretamente** — todo trafego cross-spoke e forcado a passar pelo NVA no hub. Isso garante inspecao centralizada.

```
Antes (flat):
  vnet-frontend (vm-web + vm-nva) ←── peering ──→ vnet-backend (vm-api)

Depois (hub-spoke):
  vnet-frontend (vm-web) ←── peering ──→ vnet-hub (vm-nva) ←── peering ──→ vnet-backend (vm-api)
       spoke-1                               hub                              spoke-2
```

**O que vai mudar:**
- vm-nva sai do vnet-frontend e vai para uma nova vnet-hub
- Peering direto frontend↔backend e removido
- Novos peerings: frontend↔hub e backend↔hub (com Allow Forwarded Traffic)
- UDRs em ambos os spokes apontando para o NVA no hub
- Spokes so falam entre si **via NVA** — peering nao e transitivo

**O que vai provar:**
- Peering NAO e transitivo (spoke↔spoke falha sem UDR)
- "Allow forwarded traffic" agora e **obrigatorio** (trafego cruza peering duas vezes)
- NVA centralizado inspeciona todo trafego cross-spoke

### Task 5.1: Criar vnet-hub

1. **Virtual Networks** > **Create**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource Group | `rg-lab-udr-dns` |
   | Name           | `vnet-hub`       |
   | Region         | **(US) East US** |

2. Aba **IP Addresses**: `10.0.0.0/16`

3. Delete subnet default, adicione:

   | Subnet     | Starting address | Size  |
   | ---------- | ---------------- | ----- |
   | `snet-nva` | `10.0.1.0`       | `/24` |

4. **Review + create** > **Create**

### Task 5.2: Criar vm-nva-hub

Precisamos de um NVA na vnet-hub. Vamos criar uma nova VM (vm-nva continua no vnet-frontend por enquanto — nao da para mover VMs entre VNets).

1. **Virtual Machines** > **+ Create**:

   | Setting               | Value                                  |
   | --------------------- | -------------------------------------- |
   | Resource Group        | `rg-lab-udr-dns`                       |
   | Name                  | `vm-nva-hub`                           |
   | Region                | **(US) East US**                       |
   | Image                 | **Ubuntu Server 24.04 LTS - x64 Gen2** |
   | Size                  | **Standard_B1s**                       |
   | Authentication type   | **SSH public key**                     |
   | Username              | `azureuser`                            |
   | SSH public key source | **Generate new key pair**              |

2. Aba **Networking**:

   | Setting         | Value      |
   | --------------- | ---------- |
   | Virtual network | `vnet-hub` |
   | Subnet          | `snet-nva` |
   | Public IP       | **None**   |
   | NIC NSG         | **None**   |

3. Aba **Advanced** > **Custom data**:

   ```bash
   #!/bin/bash
   echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
   sysctl -p
   ```

4. **Review + create** > **Create**

5. Anote o IP privado (deve ser `10.0.1.4`)

6. Habilitar **IP forwarding na NIC**:
   Portal > vm-nva-hub > **Networking** > NIC > **IP configurations** > IP forwarding = **Enabled** > **Save**

### Task 5.3: Remover peering direto frontend↔backend

Em hub-spoke, spokes **nao devem** ter peering direto entre si. Todo trafego passa pelo hub.

1. Portal > **vnet-frontend** > **Peerings** > `frontend-to-backend` > **Delete**

   > Isso tambem remove o lado `backend-to-frontend` automaticamente.

2. Teste via Run Command em **vm-web**:

   ```bash
   ping -c 4 10.20.1.4
   ```

   > **Resultado esperado:** Falha. Sem peering, as VNets estao completamente isoladas.

### Task 5.4: Criar peerings hub-spoke

Agora conectamos cada spoke ao hub. Os peerings precisam de **Allow Forwarded Traffic** porque o NVA vai encaminhar trafego entre spokes.

**Peering 1: hub ↔ frontend**

1. Portal > **vnet-hub** > **Peerings** > **+ Add**:

   | Setting                                             | Value             |
   | --------------------------------------------------- | ----------------- |
   | This virtual network - Peering link name            | `hub-to-frontend` |
   | Allow traffic to remote virtual network             | **Enabled**       |
   | Allow traffic forwarded from remote virtual network | **Enabled**       |
   | Remote virtual network - Peering link name          | `frontend-to-hub` |
   | Allow traffic to remote virtual network             | **Enabled**       |
   | Allow traffic forwarded from remote virtual network | **Enabled**       |
   | Virtual network                                     | `vnet-frontend`   |

2. **Add**

**Peering 2: hub ↔ backend**

3. **+ Add** novamente:

   | Setting                                             | Value            |
   | --------------------------------------------------- | ---------------- |
   | This virtual network - Peering link name            | `hub-to-backend` |
   | Allow traffic to remote virtual network             | **Enabled**      |
   | Allow traffic forwarded from remote virtual network | **Enabled**      |
   | Remote virtual network - Peering link name          | `backend-to-hub` |
   | Allow traffic to remote virtual network             | **Enabled**      |
   | Allow traffic forwarded from remote virtual network | **Enabled**      |
   | Virtual network                                     | `vnet-backend`   |

4. **Add**

> **Por que "Allow forwarded traffic" em TODOS os lados?** Porque o NVA no hub recebe pacotes de um spoke e encaminha para o outro. Sem essa opcao, o peering descarta pacotes cujo IP de origem nao pertence a VNet de onde vieram.

### Task 5.5: Provar que peering NAO e transitivo

Agora temos: frontend↔hub↔backend. Mas spokes conseguem falar entre si?

Run Command em **vm-web**:

```bash
ping -c 4 10.20.1.4
```

> **Resultado esperado:** **Falha!** Mesmo com frontend↔hub e hub↔backend, nao existe rota de frontend para backend. Peering NAO e transitivo — A↔B e B↔C nao implica A↔C.

> **Dica prova:** "Peering e transitivo?" → **NAO.** Para comunicacao cross-spoke, precisa de UDR + NVA (ou VPN Gateway com route propagation).

### Task 5.6: Criar UDRs para forcar trafego pelo NVA

Agora criamos rotas em cada spoke dizendo: "para chegar ao outro spoke, passe pelo NVA no hub".

**Route Table para snet-web (spoke frontend → hub):**

1. **Route tables** > **+ Create**:

   | Setting | Value               |
   | ------- | ------------------- |
   | Name    | `rt-spoke-frontend` |
   | Region  | **(US) East US**    |
   | RG      | `rg-lab-udr-dns`    |

2. **Create** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `to-backend-via-nva`  |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.20.0.0/16`        |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.0.1.4`            |

3. **Subnets** > **+ Associate** > `vnet-frontend` / `snet-web`

**Route Table para snet-api (spoke backend → hub):**

4. **Route tables** > **+ Create**:

   | Setting | Value              |
   | ------- | ------------------ |
   | Name    | `rt-spoke-backend` |
   | Region  | **(US) East US**   |
   | RG      | `rg-lab-udr-dns`   |

5. **Create** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `to-frontend-via-nva` |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.10.0.0/16`        |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.0.1.4`            |

6. **Subnets** > **+ Associate** > `vnet-backend` / `snet-api`

> **Nota:** Se snet-api ainda tem o rt-force-firewall da Parte 2, desassocie primeiro (Route tables > rt-force-firewall > Subnets > Remove).

### Task 5.7: Testar — ping cross-spoke via NVA

Run Command em **vm-web**:

```bash
ping -c 4 10.20.1.4
```

> **Resultado esperado:** Ping funciona! O caminho completo:
> ```
> vm-web (10.10.1.4, spoke-frontend)
>   → UDR: 10.20.0.0/16 via 10.0.1.4
>   → peering frontend→hub
>   → vm-nva-hub (10.0.1.4) recebe e encaminha
>   → peering hub→backend
>   → vm-api (10.20.1.4, spoke-backend)
>   → reply faz o caminho inverso
> ```

Run Command em **vm-api**:

```bash
ping -c 4 10.10.1.4
```

> **Resultado esperado:** Tambem funciona (UDR no spoke-backend encaminha via NVA).

**Confirmar com tracepath:**

Run Command em **vm-web**:

```bash
tracepath -n 10.20.1.4
```

> **Resultado esperado:** Tres saltos — `10.0.1.4` (NVA no hub), depois `10.20.1.4` (vm-api). Prova visual do trafego cruzando spoke→hub→spoke.

### Task 5.8: Verificar com Network Watcher

1. **Network Watcher** > **Next hop**:

   | Setting                | Value       |
   | ---------------------- | ----------- |
   | Virtual machine        | `vm-web`    |
   | Source IP address      | `10.10.1.4` |
   | Destination IP address | `10.20.1.4` |

   > **Resultado esperado:** Next hop = **VirtualAppliance**, IP = **10.0.1.4**

2. Teste tambem de vm-api para vm-web — deve mostrar o mesmo NVA.

### Task 5.9: DNS privada com 3 VNets

A zona `app.internal` precisa de link para a vnet-hub tambem, senao vm-nva-hub nao resolve nomes.

1. Portal > **Private DNS zones** > `app.internal` > **Virtual network links** > **+ Add**:

   | Setting                  | Value       |
   | ------------------------ | ----------- |
   | Link name                | `link-hub`  |
   | Virtual network          | `vnet-hub`  |
   | Enable auto registration | **Enabled** |

2. **OK**

3. Verifique que `vm-nva-hub.app.internal` apareceu nos record sets

4. Run Command em **vm-web**:

   ```bash
   nslookup vm-api.app.internal
   nslookup vm-nva-hub.app.internal
   ```

   > Ambos devem resolver. Cada VNet tem seu proprio link — DNS funciona independente do peering.

### Diagrama final Hub-Spoke

```
┌─────────────────────────────────────────────────────────────────────┐
│                         rg-lab-udr-dns                              │
│                                                                     │
│            ┌──────────────────────────┐                             │
│            │  vnet-hub (10.0.0.0/16)  │                             │
│            │                          │                             │
│            │  snet-nva (10.0.1.0/24)  │                             │
│            │  vm-nva-hub (10.0.1.4)   │                             │
│            │  IP fwd: NIC + OS        │                             │
│            └─────────┬────────────────┘                             │
│                      │                                              │
│            ┌─────────┴─────────┐                                    │
│            │   peering + fwd   │                                    │
│       ┌────┴───┐          ┌───┴────┐                                │
│       │        │          │        │                                │
│  ┌────┴─────────────┐  ┌───┴─────────────┐   ┌────────────────────┐ │
│  │ vnet-frontend    │  │ vnet-backend    │   │ DNS:               │ │
│  │ 10.10.0.0/16     │  │ 10.20.0.0/16    │   │ • app.internal     │ │
│  │                  │  │                 │   │   links: hub,      │ │
│  │ snet-web         │  │ snet-api        │   │   frontend,backend │ │
│  │ vm-web (10.10.1.4│  │ vm-api(10.20.1.4│   └────────────────────┘ │
│  │                  │  │                 │                          │
│  │ UDR: 10.20/16    │  │ UDR: 10.10/16   │                          │
│  │  → 10.0.1.4(NVA) │  │  → 10.0.1.4(NVA)│                          │
│  └──────────────────┘  └─────────────────┘                          │
│                                                                     │
│  ❌ Sem peering direto entre spokes (nao transitivo)                │
│  ✅ Todo trafego cross-spoke passa pelo NVA no hub                  │
└─────────────────────────────────────────────────────────────────────┘
```

> **Resumo Hub-Spoke para prova:**
> - Peering **NAO** e transitivo — spoke↔spoke requer UDR via NVA
> - **Allow forwarded traffic** e obrigatorio nos peerings quando NVA encaminha cross-VNet
> - NVA precisa de IP forwarding em **duas camadas** (NIC Azure + SO)
> - DNS privada precisa de link para **cada VNet** (incluindo hub)
> - Hub-spoke centraliza inspecao de trafego e simplifica governanca

---

## Cleanup

**IMPORTANTE: Delete tudo para evitar custos.**

```bash
az group delete --name rg-lab-udr-dns --yes --no-wait
```

Ou pelo portal: **Resource groups** > `rg-lab-udr-dns` > **Delete resource group**

> O `--no-wait` faz o comando retornar imediatamente enquanto a delecao acontece em background. Pode levar 5-10 minutos para tudo ser removido.

---

## Resumo do que voce praticou

| Conceito                   | O que fez                                                    | Regra para prova                                                       |
| -------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| UDR → Virtual appliance    | Forcou trafego por IP inexistente, viu pacote ser descartado | UDR redireciona, mas nao garante que destino existe                    |
| NVA com IP forwarding      | Criou vm-nva, habilitou fwd na NIC + OS, ping voltou via NVA | NVA requer: UDR + IP fwd NIC + IP fwd OS (+ peering fwd se cross-VNet) |
| UDR → None                 | Bloqueou internet sem usar NSG                               | None = descarte total                                                  |
| Effective Routes           | Visualizou todas as rotas (default + user)                   | User vence Default no mesmo prefixo                                    |
| Next Hop                   | Confirmou para onde o trafego esta indo                      | Ferramenta de diagnostico de roteamento                                |
| UDR e unidirecional        | Viu que o sentido contrario nao e afetado                    | UDR afeta apenas trafego SAINDO da subnet                              |
| Rota mais especifica vence | /16 vence /0                                                 | Longest prefix match                                                   |
| DNS publica                | Criou A, CNAME, TXT e testou com nslookup                    | CNAME nao funciona no apex domain                                      |
| DNS privada                | Criou zona, links, auto registration                         | Auto reg cria A records com IP privado                                 |
| DNS isolamento             | Viu que sem link, resolucao falha                            | Link e obrigatorio por VNet                                            |
| DNS ≠ Peering              | Peering nao compartilha DNS                                  | Cada VNet precisa de seu proprio link                                  |
| Hub-Spoke                  | Criou hub com NVA, spokes sem peering direto                 | Peering NAO e transitivo, NVA centraliza inspecao                      |
| Allow Forwarded Traffic    | Habilitou nos peerings hub↔spoke para NVA funcionar          | Obrigatorio quando NVA encaminha cross-VNet                            |
