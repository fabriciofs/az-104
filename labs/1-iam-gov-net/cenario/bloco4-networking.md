> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 5 - Intersite Connectivity](bloco5-connectivity.md)

# Bloco 4 - Virtual Networking

**Origem:** Lab 04 - Implement Virtual Networking
**Resource Groups utilizados:** `rg-contoso-network`

## Contexto

Com IaC dominado e Cloud Shell configurado (Bloco 3), voce constroi a infraestrutura de rede. As VNets criadas aqui serao **usadas no Bloco 5** para implantar VMs. O deploy da vnet-contoso-spoke via ARM template reutiliza os skills do Bloco 3. O nslookup usa o Cloud Shell ja configurado.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                          rg-contoso-network                          │
│                                                                      │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐  │
│  │  vnet-contoso-hub.           │  │  vnet-contoso-spoke          │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16                │  │
│  │                              │  │  (deploy via ARM ← Bloco 3)  │  │
│  │  ┌────────────────────────┐  │  │                              │  │
│  │  │snet-shared             │  │  │  ┌─────────────────────┐     │  │
│  │  │ 10.20.10.0/24          │  │  │  │ SensorSubnet1       │     │  │
│  │  │ ← NSG: nsg-snet-shared │  │  │  │ 10.30.20.0/24       │     │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘     │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────┐     │  │
│  │  │ snet-data              │  │  │  │ SensorSubnet2       │     │  │
│  │  │ 10.20.20.0/24          │  │  │  │ 10.30.21.0/24       │     │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘     │  │
│  └──────────────────────────────┘  └──────────────────────────────┘  │
│                                                                      │
│  → No Bloco 5: subnets adicionais para VMs nestas VNets              │
│  → No Bloco 5: peering entre estas VNets                             │
│                                                                      │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐      │
│  │ ASG: asg-web │  │ DNS Zones:                               │      │
│  └──────────────┘  │ • Public:  contoso.com (A: www)          │      │
│                    │ • Private: contoso.internal              │      │
│                    │   └─ Link: vnet-contoso-spoke.           │      │
│                    │   → No Bloco 5: record com IP real da VM │      │
│                    └──────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar VNet vnet-contoso-hub via portal

Uma Virtual Network (VNet) e a base de toda comunicacao de rede no Azure. Sem VNet, VMs nao conseguem se comunicar entre si nem com a internet. Aqui voce cria a VNet "hub" — o ponto central da rede na arquitetura hub-and-spoke, que e o padrao recomendado pela Microsoft.

> **Analogia:** Uma VNet e como um condominio fechado. As subnets sao os predios dentro do condominio. Os recursos (VMs, etc.) sao os apartamentos. Por padrao, todos os moradores (recursos) dentro do condominio (VNet) podem se comunicar, mas quem esta fora nao entra sem autorizacao.

> **Conceito:** A arquitetura **hub-and-spoke** centraliza servicos compartilhados (firewall, VPN, DNS) no hub e coloca workloads em spokes separados. Cada spoke se conecta ao hub via peering. Isso simplifica gerenciamento e seguranca. Na prova, reconheca quando um cenario descreve hub-spoke.

1. Pesquise e selecione **Virtual Networks** > **Create**

2. Aba **Basics**:

   | Setting        | Value                                     |
   | -------------- | ----------------------------------------- |
   | Resource Group | `rg-contoso-network` (crie se necessario) |
   | Name           | `vnet-contoso-hub`                        |
   | Region         | **(US) East US**                          |

   > **Regiao da VNet:** Todos os recursos dentro de uma VNet devem estar na mesma regiao. Se voce precisa de recursos em outra regiao, crie outra VNet e conecte via peering (que funciona cross-region).

3. Aba **IP Addresses**: IPv4 address space = `10.20.0.0/16`

   > **Address space /16** reserva 65.536 enderecos (os dois primeiros octetos sao fixos: 10.20.x.x). E um bloco grande que permite criar muitas subnets. Em producao, planeje o address space com cuidado — ele NAO pode se sobrepor com outras VNets que voce pretende conectar via peering.

4. **Delete** a subnet default (se existir)

5. **+ Add a subnet** para cada:

   | Subnet          | Setting          | Value         |
   | --------------- | ---------------- | ------------- |
   | **snet-shared** | Subnet name      | `snet-shared` |
   |                 | Starting address | `10.20.10.0`  |
   |                 | Size             | `/24`         |
   | **snet-data**   | Subnet name      | `snet-data`   |
   |                 | Starting address | `10.20.20.0`  |
   |                 | Size             | `/24`         |

   > **Conceito:** Cinco IPs sao reservados em cada subnet Azure (.0 rede, .1 gateway, .2 e .3 DNS, .255 broadcast). Uma /24 tem 251 IPs utilizaveis, nao 256.

   > **Por que comecar em 10.20.10.0 e 10.20.20.0?** E uma pratica de organizacao: reservar os primeiros blocos (10.20.0.0 a 10.20.9.0) para uso futuro (como subnets de gateway ou firewall). Em producao, um bom plano de enderecos facilita a vida quando a rede crescer.

6. Clique em **Review + create** > **Create** > **Go to resource**

7. Verifique **Address space** e **Subnets**

8. **Automation** > **Export template** > **Download** template e parameters

   > **Conexao com Bloco 5:** Esta VNet sera usada para implantar a vm-web-01. Voce adicionara uma subnet adicional para VMs no Bloco 5.

### Task 4.1b: Exercicio de calculo de IPs disponiveis

Calcular IPs disponiveis em subnets e uma habilidade essencial para a prova e para o dia-a-dia. O Azure reserva 5 IPs em cada subnet, entao a conta nunca e tao simples quanto "2 elevado a N".

> **Conceito:** Formula rapida para IPs disponiveis no Azure: **2^(32 - prefixo) - 5**. Exemplo: /24 = 2^8 - 5 = 251. /27 = 2^5 - 5 = 27. A menor subnet permitida e /29 (3 IPs utilizaveis).

1. Navegue para **vnet-contoso-hub** > **Subnets**

2. Observe a coluna **Available IPs** para **snet-shared** (/24)

3. Note que o valor e **251** e nao 256 — o Azure reserva **5 IPs** em cada subnet:

   | IP reservado           | Finalidade              |
   | ---------------------- | ----------------------- |
   | `.0`                   | Endereco de rede        |
   | `.1`                   | Gateway padrao          |
   | `.2`                   | Mapeamento DNS do Azure |
   | `.3`                   | Mapeamento DNS do Azure |
   | `.255` (ultimo da /24) | Broadcast               |

4. Consulte a tabela de referencia para subnets comuns:

   | CIDR  | Total de IPs | IPs disponiveis (Azure) |
   | ----- | ------------ | ----------------------- |
   | `/24` | 256          | **251**                 |
   | `/25` | 128          | **123**                 |
   | `/26` | 64           | **59**                  |
   | `/27` | 32           | **27**                  |
   | `/28` | 16           | **11**                  |
   | `/29` | 8            | **3**                   |

   > **Dica AZ-104:** Na prova, questoes de calculo de IPs sao muito comuns. Formula rapida: 2^(32-prefixo) - 5 = IPs disponiveis. A menor subnet permitida no Azure e /29 (3 IPs utilizaveis). Lembre-se sempre dos 5 IPs reservados.

---

### Task 4.2: Criar VNet vnet-contoso-spoke via ARM template

Agora voce cria a segunda VNet (spoke) usando ARM template, reutilizando os skills aprendidos no Bloco 3. Em producao, VNets de spoke sao frequentemente criadas via IaC para garantir padronizacao e facilitar replicacao entre ambientes (dev, staging, prod).

Voce reutiliza os **skills de ARM template do Bloco 3** para criar a segunda VNet.

> **Voce pode:** (A) editar o template exportado da vnet-contoso-hub, ou (B) usar o template pronto abaixo.

**Se escolher o caminho A** — edite fazendo estas substituicoes:
- `vnet-contoso-hub` → `vnet-contoso-spoke`
- `10.20.0.0` → `10.30.0.0`
- `snet-shared` → `SensorSubnet1`
- `10.20.10.0/24` → `10.30.20.0/24`
- `snet-data` → `SensorSubnet2`
- `10.20.20.0/24` → `10.30.21.0/24`

> **Detalhe importante:** O address space do spoke (`10.30.0.0/16`) NAO pode se sobrepor ao do hub (`10.20.0.0/16`). Se ambos usassem o mesmo range, o peering (que voce configurara no Bloco 5) seria impossivel — o Azure nao saberia para onde rotear o trafego.

**Se escolher o caminho B** — use os templates prontos:

**`template.json` (vnet-contoso-spoke):**

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "virtualNetworks_vnet-contoso-spoke_name": {
            "defaultValue": "vnet-contoso-spoke",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "[parameters('virtualNetworks_vnet-contoso-spoke_name')]",
            "location": "eastus",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [
                        "10.30.0.0/16"
                    ]
                },
                "encryption": {
                    "enabled": false,
                    "enforcement": "AllowUnencrypted"
                },
                "subnets": [
                    {
                        "name": "SensorSubnet1",
                        "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_vnet-contoso-spoke_name'), 'SensorSubnet1')]",
                        "properties": {
                            "addressPrefixes": [
                                "10.30.20.0/24"
                            ],
                            "delegations": [],
                            "privateEndpointNetworkPolicies": "Disabled",
                            "privateLinkServiceNetworkPolicies": "Enabled",
                            "defaultOutboundAccess": true
                        },
                        "type": "Microsoft.Network/virtualNetworks/subnets"
                    },
                    {
                        "name": "SensorSubnet2",
                        "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_vnet-contoso-spoke_name'), 'SensorSubnet2')]",
                        "properties": {
                            "addressPrefixes": [
                                "10.30.21.0/24"
                            ],
                            "delegations": [],
                            "privateEndpointNetworkPolicies": "Disabled",
                            "privateLinkServiceNetworkPolicies": "Enabled",
                            "defaultOutboundAccess": true
                        },
                        "type": "Microsoft.Network/virtualNetworks/subnets"
                    }
                ],
                "virtualNetworkPeerings": [],
                "enableDdosProtection": false
            }
        },
        {
            "type": "Microsoft.Network/virtualNetworks/subnets",
            "apiVersion": "2023-05-01",
            "name": "[concat(parameters('virtualNetworks_vnet-contoso-spoke_name'), '/SensorSubnet1')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_vnet-contoso-spoke_name'))]"
            ],
            "properties": {
                "addressPrefixes": [
                    "10.30.20.0/24"
                ],
                "delegations": [],
                "privateEndpointNetworkPolicies": "Disabled",
                "privateLinkServiceNetworkPolicies": "Enabled",
                "defaultOutboundAccess": true
            }
        },
        {
            "type": "Microsoft.Network/virtualNetworks/subnets",
            "apiVersion": "2023-05-01",
            "name": "[concat(parameters('virtualNetworks_vnet-contoso-spoke_name'), '/SensorSubnet2')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_vnet-contoso-spoke_name'))]"
            ],
            "properties": {
                "addressPrefixes": [
                    "10.30.21.0/24"
                ],
                "delegations": [],
                "privateEndpointNetworkPolicies": "Disabled",
                "privateLinkServiceNetworkPolicies": "Enabled",
                "defaultOutboundAccess": true
            }
        }
    ]
}
```

**`parameters.json`:**

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "virtualNetworks_vnet-contoso-spoke_name": {
            "value": "vnet-contoso-spoke"
        }
    }
}
```

**Deploy no portal:**

1. Pesquise **Deploy a custom template** > **Build your own template in the editor** > **Load file** > template > **Save**

2. **Edit parameters** > **Load file** > parameters > **Save**

3. Resource group: **rg-contoso-network**

4. **Review + create** > **Create**

5. Confirme que a vnet-contoso-spoke e subnets foram criadas

   > **Conexao com Bloco 3:** Voce usou as mesmas skills de ARM template aprendidas no Bloco 3, mas agora para criar infraestrutura de rede. O fluxo e sempre o mesmo: template + parameters + deploy.

---

### Task 4.3: Criar ASG e NSG

ASG (Application Security Group) e NSG (Network Security Group) trabalham juntos para controlar trafego de rede. O ASG agrupa VMs logicamente (por funcao, ex: "web servers"), e o NSG cria regras baseadas nesses grupos. Sem eles, voce teria que criar regras baseadas em IPs — o que nao escala.

> **Analogia:** O NSG e o **porteiro do predio** — ele decide quem entra e quem sai baseado em regras. O ASG e o **cracha por departamento** — em vez de listar cada pessoa pelo nome na regra, voce diz "permitir quem tem cracha de TI". Quando alguem novo entra no departamento, so precisa receber o cracha (adicionar ao ASG).

> **Conceito:** NSG opera nas camadas 3 e 4 (IP e porta). Ele NAO inspeciona conteudo (camada 7) — para isso, voce precisaria de Azure Firewall ou Application Gateway com WAF. Na prova, "filtrar trafego por URL" → nao e NSG.

**Criar o ASG:**

1. Pesquise **Application security groups** > **Create**:

   | Setting        | Value                  |
   | -------------- | ---------------------- |
   | Resource group | **rg-contoso-network** |
   | Name           | `asg-web`              |
   | Region         | **East US**            |

   > O ASG sozinho nao faz nada — ele e apenas um "rotulo". Voce o associa a NICs de VMs e o usa como source/destination nas regras do NSG. A associacao com VMs sera feita no Bloco 5.

2. **Review + create** > **Create**

**Criar o NSG:**

3. Pesquise **Network security groups** > **+ Create**:

   | Setting        | Value                  |
   | -------------- | ---------------------- |
   | Resource group | **rg-contoso-network** |
   | Name           | `nsg-snet-shared`      |
   | Region         | **East US**            |

   > **Convencao de nomes:** Nomear o NSG com a subnet que ele protege (`nsg-snet-shared`) facilita a identificacao. Em producao, com dezenas de NSGs, nomes descritivos sao essenciais.

4. **Review + create** > **Create** > **Go to resource**

---

### Task 4.4: Associar NSG a subnet + regras inbound/outbound

Associar o NSG a uma subnet faz com que todas as VMs naquela subnet sejam protegidas pelas regras do NSG automaticamente. Depois voce cria duas regras: uma permitindo trafego web (80/443) de VMs com o ASG `asg-web`, e outra bloqueando acesso a internet.

> **Conceito:** NSGs podem ser associados a **subnets** OU **NICs** (ou ambos). Quando associado a subnet, todas as VMs nela sao afetadas. Quando associado a NIC, apenas aquela VM. Se ambos existem, o trafego passa pelos dois — e como ter dois porteiros (um no predio, outro no apartamento).

1. No NSG **nsg-snet-shared**, em **Settings** > **Subnets** > **Associate**:

   | Setting         | Value                                     |
   | --------------- | ----------------------------------------- |
   | Virtual network | **vnet-contoso-hub (rg-contoso-network)** |
   | Subnet          | **snet-shared**                           |

2. Clique em **OK**

**Regra Inbound - Allow ASG:**

3. **Inbound security rules** > **+ Add**:

   | Setting                 | Value                          |
   | ----------------------- | ------------------------------ |
   | Source                  | **Application security group** |
   | Source ASG              | **asg-web**                    |
   | Source port ranges      | `*`                            |
   | Destination             | **Any**                        |
   | Service                 | **Custom**                     |
   | Destination port ranges | `80,443`                       |
   | Protocol                | **TCP**                        |
   | Action                  | **Allow**                      |
   | Priority                | `100`                          |
   | Name                    | `AllowASG`                     |

   > **Lendo a regra:** "Permita trafego TCP nas portas 80 (HTTP) e 443 (HTTPS) vindo de qualquer VM que pertenca ao ASG asg-web, com destino a qualquer IP nesta subnet." Source port = `*` porque a porta de origem e efemera (aleatoria) — voce quase nunca filtra por source port.

   > **Priority 100** e a menor (mais prioritaria) que voce pode atribuir de forma pratica. Na prova, lembre: menor numero = maior prioridade. O range e 100-4096 para regras de usuario.

4. Clique em **Add**

**Regra Outbound - Deny Internet:**

5. **Outbound security rules** > note a regra **AllowInternetOutBound** (priority 65001) > **+ Add**:

   | Setting                 | Value                  |
   | ----------------------- | ---------------------- |
   | Source                  | **Any**                |
   | Source port ranges      | `*`                    |
   | Destination             | **Service tag**        |
   | Destination service tag | **Internet**           |
   | Service                 | **Custom**             |
   | Destination port ranges | `*`                    |
   | Protocol                | **Any**                |
   | Action                  | **Deny**               |
   | Priority                | `4096`                 |
   | Name                    | `DenyInternetOutbound` |

   > **Service tag Internet** e um alias mantido pelo Azure que representa todos os IPs da internet publica. Usar service tags e melhor que listar IPs manualmente — o Azure atualiza os ranges automaticamente.

   > **Por que priority 4096 funciona?** Porque a regra padrao AllowInternetOutBound tem priority 65001. Como 4096 < 65001, sua regra Deny e avaliada primeiro e vence. A regra padrao nunca e alcancada para trafego de internet.

6. Clique em **Add**

   > **Conceito:** NSG rules sao processadas por **priority** (menor = maior prioridade). A DenyInternetOutbound (4096) tem prioridade maior que AllowInternetOutBound (65001). Quando um pacote faz match com uma regra, as regras seguintes NAO sao avaliadas — e como o primeiro guarda na fila que decide.

   > **Conexao com Bloco 5:** Este NSG esta associado apenas a snet-shared. As VMs criadas no Bloco 5 ficarao em subnets diferentes (snet-apps, snet-workloads), entao NAO serao afetadas por este NSG — demonstrando que NSGs sao associados por subnet, nao por VNet.

---

### Task 4.5: Criar zona DNS publica com registro A

DNS publica permite que nomes de dominio sejam resolvidos por qualquer pessoa na internet. Aqui voce cria uma zona para `contoso.com` e adiciona um registro A apontando `www` para um IP. Em producao, isso e como voce faz `www.suaempresa.com` apontar para seu web server.

> **Conceito:** Uma zona DNS publica no Azure hospeda seus registros DNS nos name servers da Microsoft (distribuidos globalmente). Para funcionar de verdade na internet, voce precisaria configurar esses name servers no registrador do dominio. Neste lab, testamos diretamente no name server do Azure.

> **Analogia:** DNS publica e a **lista telefonica publicada** — qualquer pessoa pode consultar. DNS privada e o **ramal interno** — so funciona de dentro da empresa.

1. Pesquise **DNS zones** > **+ Create**:

   | Setting        | Value                                          |
   | -------------- | ---------------------------------------------- |
   | Resource group | **rg-contoso-network**                         |
   | Name           | `contoso.com` (ajuste se ja estiver reservado) |
   | Region         | **Global** (DNS zones sao recursos globais)    |

   > **Region = Global:** DNS zones NAO ficam numa regiao especifica — os name servers sao distribuidos mundialmente para alta disponibilidade. Na prova, se perguntarem "qual a region de uma DNS zone?" → Global.

2. **Review + create** > **Create** > **Go to resource**

3. **Copie** o endereco de um name server (voce precisara para nslookup)

   > Os name servers (ex: `ns1-03.azure-dns.com`) sao atribuidos automaticamente pelo Azure. Voce precisa deles para testar a resolucao e, em producao, para configurar no registrador do dominio.

4. **DNS Management** > **Recordsets** > **+ Add**:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `www`      |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

   > **Registro A** e o tipo mais basico de DNS: mapeia um nome diretamente para um IPv4. `www` + zona `contoso.com` = `www.contoso.com → 10.1.1.4`. O TTL (Time to Live) define por quantos segundos o resultado fica em cache — TTL 1 segundo e ideal para labs (propagacao rapida).

5. Clique em **Add**

6. Teste via **Cloud Shell** (ja configurado no Bloco 3):

   ```sh
   nslookup www.contoso.com <name-server-copiado>
   ```

   > **Por que passar o name server?** Porque `contoso.com` nao esta registrado na internet de verdade sob seu controle. Sem especificar o name server, o nslookup perguntaria ao DNS publico da internet, que nao conhece sua zona de lab. Passando o name server do Azure, voce pergunta diretamente a quem sabe.

   > **Conexao com Bloco 3:** O Cloud Shell ja esta configurado e pronto para uso — sem necessidade de reconfigurar.

7. Verifique que resolve para `10.1.1.4`

---

### Task 4.6: Criar zona DNS privada com virtual network link

DNS privada e essencial para comunicacao interna entre VMs. Em vez de decorar IPs (que podem mudar), voce usa nomes como `sensorvm.contoso.internal`. A zona privada so resolve para VMs em VNets que voce **explicitamente linkar**.

> **Conceito:** Zonas DNS privadas NAO sao visiveis na internet. Elas usam o DNS interno do Azure (`168.63.129.16`) para resolucao. Para uma VM resolver nomes da zona, dois requisitos: (1) a zona existe, (2) a VNet da VM tem um Virtual Network Link para a zona.

> **Dica AZ-104:** Na prova, "peering entre VNets compartilha DNS?" → **NAO**. Peering compartilha conectividade IP, mas DNS e um servico separado. Cada VNet precisa de seu proprio link para a zona privada.

1. Pesquise **Private dns zones** > **+ Create**:

   | Setting        | Value                  |
   | -------------- | ---------------------- |
   | Resource group | **rg-contoso-network** |
   | Name           | `contoso.internal`     |
   | Region         | **Global**             |

   > Voce pode usar qualquer nome para zonas privadas (`.internal`, `.corp`, `.local`). O Azure nao valida se o dominio existe publicamente. Em producao, evite usar dominios publicos reais para nao causar conflito de resolucao.

2. **Review + create** > **Create** > **Go to resource**

3. Note que nao ha name servers (zona privada)

   > Diferente da zona publica, a zona privada nao tem name servers visiveis. A resolucao e feita internamente pelo Azure DNS (`168.63.129.16`) — as VMs ja estao configuradas para usar esse DNS por padrao.

4. **DNS Management** > **Virtual network links** > configure:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Link name       | `manufacturing-link` |
   | Virtual network | `vnet-contoso-spoke` |

   > **O que e um Virtual Network Link?** E a conexao entre a zona DNS privada e uma VNet. Sem este link, VMs na VNet nao conseguem resolver nomes da zona — mesmo que a zona exista. E como conectar o sistema de ramais a um andar do predio.

5. Clique em **Create** e aguarde

6. **+ Recordsets** > adicione um registro placeholder:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `sensorvm` |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

   > Este registro e um placeholder — o IP `10.1.1.4` nao corresponde a nenhuma VM real ainda. No Bloco 5, voce atualizara com o IP real. DNS e apenas uma "lista telefonica" — ele traduz nomes em IPs sem validar se o IP esta ativo.

   > **Conexao com Bloco 5:** No Bloco 5, voce adicionara um registro com o IP **real** da vm-web-01 e testara a resolucao de nome a partir da vm-app-01. Voce tambem adicionara um link para vnet-contoso-hub.

---

## Modo Desafio - Bloco 4

- [ ] Criar VNet `vnet-contoso-hub` (10.20.0.0/16) com snet-shared e snet-data
- [ ] Verificar IPs disponiveis na snet-shared e calcular para /24, /25, /26, /27, /28, /29
- [ ] Exportar template → criar `vnet-contoso-spoke` (10.30.0.0/16) via ARM (**skills do Bloco 3**)
- [ ] Criar ASG `asg-web` e NSG `nsg-snet-shared`
- [ ] Associar NSG a snet-shared + regras inbound/outbound
- [ ] Criar DNS publica `contoso.com` + nslookup via **Cloud Shell (Bloco 3)**
- [ ] Criar DNS privada `contoso.internal` + link para vnet-contoso-spoke

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Um NSG esta associado a snet-shared. Voce cria uma VM em snet-data (mesma VNet). A VM e afetada pelas regras do NSG?**

A) Sim, o NSG se aplica a toda a VNet
B) Nao, o NSG se aplica apenas a subnet associada
C) Sim, se o ASG incluir a VM
D) Depende das regras de priority

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, o NSG se aplica apenas a subnet associada**

NSGs sao associados a **subnets** ou **NICs**, nao a VNets inteiras. Uma VM em snet-data nao e afetada por um NSG associado a snet-shared, mesmo que estejam na mesma VNet.

</details>

### Questao 4.2
**Quantos enderecos IP utilizaveis existem em uma subnet /24 no Azure?**

A) 256
B) 254
C) 251
D) 250

<details>
<summary>Ver resposta</summary>

**Resposta: C) 251**

O Azure reserva 5 IPs: network address (.0), gateway (.1), Azure DNS (.2, .3), broadcast (.255). 256 - 5 = 251.

</details>

### Questao 4.3
**Voce tem regras NSG: Rule A (Priority 100, Allow, Port 80) e Rule B (Priority 200, Deny, Port 80). Um pacote chega na porta 80. O que acontece?**

A) Negado pela Rule B
B) Permitido pela Rule A
C) Avaliado por todas as regras, ultima vence
D) Permitido porque ha mais regras Allow

<details>
<summary>Ver resposta</summary>

**Resposta: B) Permitido pela Rule A**

NSG rules sao processadas em ordem de priority (menor primeiro). Rule A (100) e avaliada primeiro e permite o trafego. Rule B nunca e alcancada.

</details>

### Questao 4.4
**Qual a diferenca entre Azure DNS public zones e private zones?**

A) Public zones sao gratuitas, private zones sao pagas
B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas
C) Private zones suportam mais tipos de registro
D) Public zones requerem VPN

<details>
<summary>Ver resposta</summary>

**Resposta: B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas**

Private DNS zones requerem Virtual Network Links e resolvem apenas para recursos nas VNets linkadas.

</details>

### Questao 4.5
**Voce criou uma zona DNS privada e linkou a VNet A. Uma VM na VNet B (nao linkada) tenta resolver um nome nessa zona. O que acontece?**

A) Resolve normalmente
B) Falha — a VNet B nao esta linkada a zona
C) Resolve usando o DNS publico
D) Resolve apenas se houver peering entre A e B

<details>
<summary>Ver resposta</summary>

**Resposta: B) Falha — a VNet B nao esta linkada a zona**

Zonas DNS privadas so resolvem para VNets que possuem Virtual Network Links configurados. Peering entre VNets NAO implica resolucao DNS automatica — o link precisa ser explicitamente criado.

</details>

---
