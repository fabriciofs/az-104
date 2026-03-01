> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 5 - Intersite Connectivity](bloco5-connectivity.md)

# Bloco 4 - Virtual Networking

**Origem:** Lab 04 - Implement Virtual Networking
**Resource Groups utilizados:** `az104-rg4`

## Contexto

Com IaC dominado e Cloud Shell configurado (Bloco 3), voce constroi a infraestrutura de rede. As VNets criadas aqui serao **usadas no Bloco 5** para implantar VMs. O deploy da ManufacturingVnet via ARM template reutiliza os skills do Bloco 3. O nslookup usa o Cloud Shell ja configurado.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                          az104-rg4                                 │
│                                                                    │
│  ┌──────────────────────────────┐  ┌────────────────────────────┐  │
│  │  CoreServicesVnet            │  │  ManufacturingVnet         │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16              │  │
│  │                              │  │  (deploy via ARM ← Bloco 3)│  │
│  │  ┌────────────────────────┐  │  │                            │  │
│  │  │SharedServicesSubnet    │  │  │  ┌─────────────────────┐   │  │
│  │  │ 10.20.10.0/24          │  │  │  │ SensorSubnet1       │   │  │
│  │  │ ← NSG: myNSGSecure     │  │  │  │ 10.30.20.0/24       │   │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘   │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────┐   │  │
│  │  │ DatabaseSubnet         │  │  │  │ SensorSubnet2       │   │  │
│  │  │ 10.20.20.0/24          │  │  │  │ 10.30.21.0/24       │   │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘   │  │
│  └──────────────────────────────┘  └────────────────────────────┘  │
│                                                                    │
│  → No Bloco 5: subnets adicionais para VMs nestas VNets            │
│  → No Bloco 5: peering entre estas VNets                           │
│                                                                    │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐    │
│  │ ASG: asg-web │  │ DNS Zones:                               │    │
│  └──────────────┘  │ • Public:  contoso.com (A: www)          │    │
│                    │ • Private: private.contoso.com           │    │
│                    │   └─ Link: ManufacturingVnet             │    │
│                    │   → No Bloco 5: record com IP real da VM │    │
│                    └──────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar VNet CoreServicesVnet via portal

1. Pesquise e selecione **Virtual Networks** > **Create**

2. Aba **Basics**:

   | Setting        | Value                            |
   | -------------- | -------------------------------- |
   | Resource Group | `az104-rg4` (crie se necessario) |
   | Name           | `CoreServicesVnet`               |
   | Region         | **(US) East US**                 |

3. Aba **IP Addresses**: IPv4 address space = `10.20.0.0/16`

4. **Delete** a subnet default (se existir)

5. **+ Add a subnet** para cada:

   | Subnet                   | Setting          | Value                  |
   | ------------------------ | ---------------- | ---------------------- |
   | **SharedServicesSubnet** | Subnet name      | `SharedServicesSubnet` |
   |                          | Starting address | `10.20.10.0`           |
   |                          | Size             | `/24`                  |
   | **DatabaseSubnet**       | Subnet name      | `DatabaseSubnet`       |
   |                          | Starting address | `10.20.20.0`           |
   |                          | Size             | `/24`                  |

   > **Conceito:** Cinco IPs sao reservados em cada subnet Azure. Uma /24 tem 251 IPs utilizaveis.

6. Clique em **Review + create** > **Create** > **Go to resource**

7. Verifique **Address space** e **Subnets**

8. **Automation** > **Export template** > **Download** template e parameters

   > **Conexao com Bloco 5:** Esta VNet sera usada para implantar a CoreServicesVM. Voce adicionara uma subnet adicional para VMs no Bloco 5.

---

### Task 4.2: Criar VNet ManufacturingVnet via ARM template

Voce reutiliza os **skills de ARM template do Bloco 3** para criar a segunda VNet.

> **Voce pode:** (A) editar o template exportado da CoreServicesVnet, ou (B) usar o template pronto abaixo.

**Se escolher o caminho A** — edite fazendo estas substituicoes:
- `CoreServicesVnet` → `ManufacturingVnet`
- `10.20.0.0` → `10.30.0.0`
- `SharedServicesSubnet` → `SensorSubnet1`
- `10.20.10.0/24` → `10.30.20.0/24`
- `DatabaseSubnet` → `SensorSubnet2`
- `10.20.20.0/24` → `10.30.21.0/24`

**Se escolher o caminho B** — use os templates prontos:

**`template.json` (ManufacturingVnet):**

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "virtualNetworks_ManufacturingVnet_name": {
            "defaultValue": "ManufacturingVnet",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2023-05-01",
            "name": "[parameters('virtualNetworks_ManufacturingVnet_name')]",
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
                        "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_ManufacturingVnet_name'), 'SensorSubnet1')]",
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
                        "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_ManufacturingVnet_name'), 'SensorSubnet2')]",
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
            "name": "[concat(parameters('virtualNetworks_ManufacturingVnet_name'), '/SensorSubnet1')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_ManufacturingVnet_name'))]"
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
            "name": "[concat(parameters('virtualNetworks_ManufacturingVnet_name'), '/SensorSubnet2')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_ManufacturingVnet_name'))]"
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
        "virtualNetworks_ManufacturingVnet_name": {
            "value": "ManufacturingVnet"
        }
    }
}
```

**Deploy no portal:**

1. Pesquise **Deploy a custom template** > **Build your own template in the editor** > **Load file** > template > **Save**

2. **Edit parameters** > **Load file** > parameters > **Save**

3. Resource group: **az104-rg4**

4. **Review + create** > **Create**

5. Confirme que a ManufacturingVnet e subnets foram criadas

   > **Conexao com Bloco 3:** Voce usou as mesmas skills de ARM template aprendidas no Bloco 3, mas agora para criar infraestrutura de rede.

---

### Task 4.3: Criar ASG e NSG

**Criar o ASG:**

1. Pesquise **Application security groups** > **Create**:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource group | **az104-rg4** |
   | Name           | `asg-web`     |
   | Region         | **East US**   |

2. **Review + create** > **Create**

**Criar o NSG:**

3. Pesquise **Network security groups** > **+ Create**:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource group | **az104-rg4** |
   | Name           | `myNSGSecure` |
   | Region         | **East US**   |

4. **Review + create** > **Create** > **Go to resource**

---

### Task 4.4: Associar NSG a subnet + regras inbound/outbound

1. No NSG **myNSGSecure**, em **Settings** > **Subnets** > **Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg4)** |
   | Subnet          | **SharedServicesSubnet**         |

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

6. Clique em **Add**

   > **Conceito:** NSG rules sao processadas por **priority** (menor = maior prioridade). A DenyInternetOutbound (4096) tem prioridade maior que AllowInternetOutBound (65001).

   > **Conexao com Bloco 5:** Este NSG esta associado apenas a SharedServicesSubnet. As VMs criadas no Bloco 5 ficarao em subnets diferentes (Core, Manufacturing), entao NAO serao afetadas por este NSG — demonstrando que NSGs sao associados por subnet, nao por VNet.

---

### Task 4.5: Criar zona DNS publica com registro A

1. Pesquise **DNS zones** > **+ Create**:

   | Setting        | Value                                          |
   | -------------- | ---------------------------------------------- |
   | Resource group | **az104-rg4**                                  |
   | Name           | `contoso.com` (ajuste se ja estiver reservado) |
   | Region         | **Global** (DNS zones sao recursos globais)    |

2. **Review + create** > **Create** > **Go to resource**

3. **Copie** o endereco de um name server (voce precisara para nslookup)

4. **DNS Management** > **Recordsets** > **+ Add**:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `www`      |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

5. Clique em **Add**

6. Teste via **Cloud Shell** (ja configurado no Bloco 3):

   ```sh
   nslookup www.contoso.com <name-server-copiado>
   ```

   > **Conexao com Bloco 3:** O Cloud Shell ja esta configurado e pronto para uso — sem necessidade de reconfigurar.

7. Verifique que resolve para `10.1.1.4`

---

### Task 4.6: Criar zona DNS privada com virtual network link

1. Pesquise **Private dns zones** > **+ Create**:

   | Setting        | Value                 |
   | -------------- | --------------------- |
   | Resource group | **az104-rg4**         |
   | Name           | `private.contoso.com` |
   | Region         | **Global**            |

2. **Review + create** > **Create** > **Go to resource**

3. Note que nao ha name servers (zona privada)

4. **DNS Management** > **Virtual network links** > configure:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Link name       | `manufacturing-link` |
   | Virtual network | `ManufacturingVnet`  |

5. Clique em **Create** e aguarde

6. **+ Recordsets** > adicione um registro placeholder:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `sensorvm` |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

   > **Conexao com Bloco 5:** No Bloco 5, voce adicionara um registro com o IP **real** da CoreServicesVM e testara a resolucao de nome a partir da ManufacturingVM. Voce tambem adicionara um link para CoreServicesVnet.

---

## Modo Desafio - Bloco 4

- [ ] Criar VNet `CoreServicesVnet` (10.20.0.0/16) com SharedServicesSubnet e DatabaseSubnet
- [ ] Exportar template → criar `ManufacturingVnet` (10.30.0.0/16) via ARM (**skills do Bloco 3**)
- [ ] Criar ASG `asg-web` e NSG `myNSGSecure`
- [ ] Associar NSG a SharedServicesSubnet + regras inbound/outbound
- [ ] Criar DNS publica `contoso.com` + nslookup via **Cloud Shell (Bloco 3)**
- [ ] Criar DNS privada `private.contoso.com` + link para ManufacturingVnet

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Um NSG esta associado a SharedServicesSubnet. Voce cria uma VM em DatabaseSubnet (mesma VNet). A VM e afetada pelas regras do NSG?**

A) Sim, o NSG se aplica a toda a VNet
B) Nao, o NSG se aplica apenas a subnet associada
C) Sim, se o ASG incluir a VM
D) Depende das regras de priority

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, o NSG se aplica apenas a subnet associada**

NSGs sao associados a **subnets** ou **NICs**, nao a VNets inteiras. Uma VM em DatabaseSubnet nao e afetada por um NSG associado a SharedServicesSubnet, mesmo que estejam na mesma VNet.

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

