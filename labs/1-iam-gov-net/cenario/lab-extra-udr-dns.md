# Lab Extra - UDR e DNS (Independente)

**Objetivo:** Praticar User Defined Routes e DNS (publica + privada) do zero, sem dependencia dos labs anteriores.
**Tempo estimado:** 1h30
**Custo:** ~$0.50 (2 VMs B1ls por ~1h + VNet gratuito)

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
│  │  (NVA simulado:         │    ┌──────────────────────────┐  │
│  │   10.10.2.4)            │    │ DNS Zones:               │  │
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

1. Pesquise **Virtual Machines** > **+ Create** > **Azure virtual machine**:

   | Setting        | Value                                                        |
   | -------------- | ------------------------------------------------------------ |
   | Resource Group | `rg-lab-udr-dns`                                             |
   | Name           | `vm-web`                                                     |
   | Region         | **(US) East US**                                             |
   | Image          | **Windows Server 2022 Datacenter: Azure Edition - x64 Gen2** |
   | Size           | **Standard_B1ls** ou **B2s**                                 |
   | Username       | `azureuser`                                                  |
   | Password       | (defina uma senha)                                           |

2. Aba **Networking**:

   | Setting         | Value           |
   | --------------- | --------------- |
   | Virtual network | `vnet-frontend` |
   | Subnet          | `snet-web`      |
   | Public IP       | **(new)**       |
   | NIC NSG         | **None**        |

   > O Public IP e necessario para voce acessar a VM via RDP. Em producao, voce usaria Azure Bastion em vez de IP publico.

3. **Review + create** > **Create**

### Task 1.6: Criar vm-api

Esta VM simula uma API no backend. Mesma configuracao, mas na outra VNet/subnet.

1. Repita o processo:

   | Setting         | Value            |
   | --------------- | ---------------- |
   | Resource Group  | `rg-lab-udr-dns` |
   | Name            | `vm-api`         |
   | Virtual network | `vnet-backend`   |
   | Subnet          | `snet-api`       |
   | Public IP       | **(new)**        |
   | NIC NSG         | **None**         |

2. **Review + create** > **Create**

### Task 1.7: Liberar ping nas duas VMs

**Por que ping nao funciona por padrao?** O Windows Firewall bloqueia ICMP (protocolo do ping) por padrao. Isso e uma configuracao do **SO**, nao do Azure. Precisamos criar uma regra no firewall do Windows para permitir.

Conecte via RDP em **cada VM** e rode no PowerShell como Admin:

```powershell
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow -Direction Inbound
```

> O que este comando faz: cria uma regra no Windows Firewall que permite pacotes ICMP tipo 8 (echo request = ping) entrarem na VM.

Teste que o ping funciona entre elas:
- De vm-web: `ping 10.20.1.4`
- De vm-api: `ping 10.10.1.4`

> **Checkpoint:** Se o ping funciona nos dois sentidos, o peering esta OK. Anote este comportamento — ele vai mudar quando voce adicionar UDRs.

> **Se o ping falhar:** (1) Verifique se rodou o comando nas DUAS VMs. (2) Confira se o peering esta "Connected". (3) Verifique os IPs reais das VMs em VM > Networking > Private IP (podem nao ser .4).

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

| Conceito | Significado |
| --- | --- |
| **Route Table** | Container de rotas. Voce cria a tabela e depois associa a uma subnet. |
| **Route (rota)** | Uma regra dentro da tabela: "para destino X, envie para Y" |
| **Next hop** | Para onde o pacote deve ir. Tipos: Virtual appliance, VNet gateway, Internet, None |
| **Virtual appliance** | Um IP de uma VM que atua como firewall/proxy (NVA) |
| **None** | Descarte o pacote (blackhole) |
| **Associacao** | Uma route table so funciona quando associada a uma subnet |
| **Unidirecional** | A UDR afeta apenas o trafego **saindo** da subnet associada, nao o trafego chegando |

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

De **vm-api**, tente:

```powershell
ping 10.10.1.4
```

> **Resultado esperado:** Timeout. O trafego esta sendo enviado para 10.10.2.4 (NVA), que nao existe. O pacote e descartado.

**Agora teste o sentido contrario.** De **vm-web**:

```powershell
ping 10.20.1.4
```

> **Pergunta para pensar:** Este ping funciona? Por que?

<details>
<summary>Ver resposta</summary>

**Sim**, vm-web → vm-api ainda funciona. O UDR esta associado apenas a **snet-api**. O trafego de snet-web usa a rota padrao (peering direto). UDRs sao **unidirecionais** — afetam apenas a subnet onde estao associados.

Isso e uma pegadinha comum na prova: "UDR na subnet A afeta trafego da subnet B?" → NAO.

</details>

### Task 2.4: Verificar com Network Watcher

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

### Task 2.5: Criar Route Table rt-block-internet

**Cenario real:** Voce tem VMs que processam dados sensiveis e NAO devem ter acesso a internet. Uma forma de garantir isso e com UDR + next hop = None.

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

### Task 2.6: Associar rt-block-internet a snet-web

1. **Subnets** > **+ Associate** > `vnet-frontend` / `snet-web` > **OK**

   > A partir de agora, vm-web nao consegue acessar a internet, mas AINDA fala com vm-api via peering.

### Task 2.7: Testar — internet bloqueada mas peering funciona

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

De **vm-web** (via RDP), teste internet:

```powershell
# Testar acesso a internet
Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -TimeoutSec 10
```

> **Resultado esperado:** Timeout ou erro de conexao.

Agora teste peering:

```powershell
ping 10.20.1.4
```

> **Resultado esperado:** Ping funciona! A rota de peering (/16) e mais especifica que a rota de bloqueio (/0).

<details>
<summary>Regra completa de precedencia de rotas no Azure</summary>

Quando ha multiplas rotas que fazem match, o Azure escolhe nesta ordem:

1. **Longest prefix match** — a rota mais especifica vence (/24 > /16 > /0)
2. Se mesmo prefixo, **User route** vence **System route**
3. Se mesmo prefixo e tipo, **BGP route** vence **System route**

Na prova, 90% das questoes sobre rotas se resolvem com a regra 1 (longest prefix match).

</details>

### Task 2.8: Verificar Effective Routes

**Effective Routes** mostra TODAS as rotas ativas numa NIC — tanto as automaticas quanto as UDRs. E a visao completa do que o Azure "ve" quando precisa rotear um pacote.

1. Navegue para **vm-web** > **Networking** > clique na **NIC** > **Effective routes**

2. Observe todas as rotas aplicadas:

   | Source  | Address Prefix | Next Hop Type  | Explicacao |
   | ------- | -------------- | -------------- | ---------- |
   | Default | 10.10.0.0/16   | VirtualNetwork | Trafego dentro da propria VNet |
   | **User** | **0.0.0.0/0** | **None**       | Sua UDR bloqueando internet |
   | Default | 10.20.0.0/16   | VNetPeering    | Trafego para VNet peered |

   > **Observe a coluna Source:** "Default" = rota automatica do Azure. "User" = sua UDR. Quando ha conflito no mesmo prefixo, User vence Default. Quando os prefixos sao diferentes, o mais especifico vence.

   > **Dica prova:** "Qual ferramenta mostra TODAS as rotas aplicadas numa NIC?" → **Effective Routes**.

### Task 2.9: Remover UDR e confirmar restauracao

**O que acontece ao desassociar uma UDR?** As rotas automaticas do Azure voltam a funcionar imediatamente. Nao precisa reiniciar nada — o Azure recalcula as rotas em tempo real.

1. No rt-force-firewall > **Subnets** > clique em snet-api > **Remove** (desassociar)

2. De vm-api, teste novamente:

```powershell
ping 10.10.1.4
```

> **Resultado esperado:** Ping volta a funcionar. Ao desassociar o UDR, a rota padrao de peering e restaurada automaticamente.

> **Conceito:** UDRs NAO deletam as rotas automaticas — apenas as sobrescrevem temporariamente. Removeu a UDR? As rotas originais voltam como se nada tivesse acontecido.

---

## Parte 3 — DNS

### O que e DNS e por que importa

DNS (Domain Name System) traduz **nomes** em **IPs**. Sem DNS, voce teria que decorar IPs para acessar qualquer coisa (imagine acessar `142.250.217.78` em vez de `google.com`).

No Azure, existem **dois tipos** de DNS zones:

| Tipo | Quem resolve | Uso |
| --- | --- | --- |
| **Publica** | Qualquer pessoa na internet | Sites, APIs publicas |
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

| Tipo | Funcao | Exemplo |
| --- | --- | --- |
| **A** | Nome → IPv4 | `www → 10.1.1.4` |
| **AAAA** | Nome → IPv6 | `www → 2001:db8::1` |
| **CNAME** | Nome → outro nome (alias) | `portal → www.contoso.com` |
| **MX** | Email server do dominio | `contoso.com → mail.contoso.com` |
| **TXT** | Texto livre (SPF, verificacao) | `contoso.com → "v=spf1 ..."` |
| **NS** | Name servers do dominio | `contoso.com → ns1.azure-dns.com` |
| **SOA** | Autoridade da zona (automatico) | Metadados da zona |

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
   | `vm-api` | A    | 10.20.1.4 |

   > Se as VMs ja estavam criadas quando voce habilitou o link com auto registration, os registros aparecem em ate 1-2 minutos.

   > **O que acontece se voce criar uma nova VM?** O registro e criado automaticamente em segundos. Se deletar a VM? O registro e removido. Tudo automatico.

### Task 3.7: Testar DNS privada entre VMs

Este e o teste mais satisfatório — em vez de decorar IPs, voce usa nomes legíveis.

De **vm-web** (via RDP), rode no PowerShell:

```powershell
# Resolver vm-api pelo nome — DNS traduz nome → IP
nslookup vm-api.app.internal
# Resposta esperada: 10.20.1.4

# Ping pelo FQDN — prova que funciona ponta a ponta
ping vm-api.app.internal
```

De **vm-api**:

```powershell
nslookup vm-web.app.internal
# Resposta esperada: 10.10.1.4

ping vm-web.app.internal
```

> **Resultado esperado:** Ambas resolvem e o ping funciona (se o firewall rule do ICMPv4 esta ativo).

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

2. De vm-web:

```powershell
# O DNS resolve? Sim!
nslookup database.app.internal
# Resposta: 10.20.1.99

# O ping funciona? Nao!
ping database.app.internal
# Resposta: timeout (nao existe nada nesse IP)
```

> **Conceito importante:** DNS e resolucao de nomes apenas uma "lista telefonica" — traduz nomes em IPs. Se o IP esta errado, offline, ou nao existe, o DNS nao sabe e nao se importa. Ele so faz a traducao.

### Task 3.9: Testar isolamento — VNet sem link

**Objetivo:** Provar que sem Virtual Network Link, a VNet nao consegue resolver nomes da zona privada — mesmo que tenha peering com outra VNet que tem link.

1. Remova o link `link-backend`: **Virtual network links** > `link-backend` > **Delete**

   > Agora vnet-backend nao tem link com `app.internal`. Mas vnet-frontend ainda tem.

2. De **vm-api** (que esta na vnet-backend sem link), teste:

```powershell
nslookup vm-web.app.internal
```

> **Resultado esperado:** **Falha.** Mesmo que vm-api tenha peering com vnet-frontend (que TEM link), a resolucao DNS nao "herda" do peering. Cada VNet precisa de seu proprio link.

> **Essa e uma das pegadinhas mais cobradas na prova:** "VNets peered compartilham DNS?" → **NAO.** Peering compartilha conectividade de rede (IP-to-IP), mas DNS e um servico separado que requer link explicito.

3. De **vm-web** (que esta na vnet-frontend COM link), teste:

```powershell
nslookup vm-api.app.internal
```

> **Resultado esperado:** Pode ainda resolver por um tempo (o registro existe na zona), mas o auto registration de vm-api sera removido em breve ja que vnet-backend nao esta mais linkada.

4. **Recrie** o link `link-backend` com auto registration para restaurar tudo

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

| Conceito                   | O que fez                                                    | Regra para prova |
| -------------------------- | ------------------------------------------------------------ | ---------------- |
| UDR → Virtual appliance    | Forcou trafego por IP inexistente, viu pacote ser descartado | NVA precisa existir E ter IP forwarding |
| UDR → None                 | Bloqueou internet sem usar NSG                               | None = descarte total |
| Effective Routes           | Visualizou todas as rotas (default + user)                   | User vence Default no mesmo prefixo |
| Next Hop                   | Confirmou para onde o trafego esta indo                      | Ferramenta de diagnostico de roteamento |
| UDR e unidirecional        | Viu que o sentido contrario nao e afetado                    | UDR afeta apenas trafego SAINDO da subnet |
| Rota mais especifica vence | /16 vence /0                                                 | Longest prefix match |
| DNS publica                | Criou A, CNAME, TXT e testou com nslookup                    | CNAME nao funciona no apex domain |
| DNS privada                | Criou zona, links, auto registration                         | Auto reg cria A records com IP privado |
| DNS isolamento             | Viu que sem link, resolucao falha                            | Link e obrigatorio por VNet |
| DNS ≠ Peering              | Peering nao compartilha DNS                                  | Cada VNet precisa de seu proprio link |
