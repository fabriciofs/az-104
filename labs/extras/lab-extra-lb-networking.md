# Lab Extra: Load Balancer, DNS Import e Troubleshooting de Rede

> **Objetivo:** Dominar Load Balancer (criacao, health probes, session persistence), importacao de zonas DNS e ferramentas de troubleshooting do Network Watcher, usando todos os metodos de deploy.
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 90-120 min (teoria + pratica multi-metodo + questoes)
> **Metodos cobertos:** Portal, Azure CLI, PowerShell, ARM Template, Bicep

---

## Quando usar cada metodo?

Antes de comecar, entenda QUANDO e POR QUE usar cada metodo de deploy:

| Metodo | Quando usar | Vantagem principal | Limitacao |
|--------|-------------|-------------------|-----------|
| **Portal** | Aprender, explorar, deploy unico | Visual, facil de entender | Nao escala, nao e reproduzivel |
| **Azure CLI** | Scripts rapidos, automacao em Bash/Linux, CI/CD | Sintaxe curta, funciona em Cloud Shell | Menos tipado que PowerShell |
| **PowerShell** | Automacao Windows, scripts corporativos complexos | Objetos tipados, pipeline robusto | Mais verboso que CLI |
| **ARM Template** | IaC declarativa, deploy repetivel, auditavel | Idempotente, versionavel no Git | JSON verboso, dificil de ler |
| **Bicep** | IaC moderna (substitui ARM), legibilidade | Sintaxe limpa, compila para ARM | Mais novo, menos exemplos legacy |

> **Para a prova AZ-104:** Voce precisa reconhecer comandos CLI e PowerShell. ARM/Bicep aparecem menos, mas entender o conceito de IaC e importante. DNS Zone Import so funciona em CLI!

---

## Parte 1 — Load Balancer: SKUs e Criacao

### 1.1 — Comparacao de SKUs (Basic vs Standard)

| Criterio | Basic | Standard |
|----------|:-----:|:--------:|
| Back-end pool | Availability Set **OU** VMSS (nao ambos) | Qualquer VM na mesma VNet |
| Back-end cross-VNet | **Nao** | **Nao** (mesma VNet apenas!) |
| Health probes | HTTP, TCP | HTTP, **HTTPS**, TCP |
| SLA | Nenhum | **99,99%** |
| Zonas de disponibilidade | Nao | Sim (zone-redundant) |
| NSG necessario? | Opcional (aberto por padrao) | **Obrigatorio** (fechado por padrao) |
| Seguro por padrao | Nao | **Sim** — precisa de NSG com regra Allow |
| Global LB (cross-region) | Nao | Sim (Standard tier) |
| Preco | Gratuito | Pago |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "LB Standard criado mas VMs nao recebem trafego"
VERIFICAR:
1. Health probe esta na porta correta? (porta e caminho devem coincidir com o servico)
2. NSG no back-end permite o trafego? (Standard e FECHADO por padrao!)
3. VMs estao na MESMA VNet do LB? (obrigatorio para Basic E Standard)
4. VMs estao saudaveis no health probe?

PERGUNTA: "Adicionar VMs de outra VNet ao back-end pool do LB"
RESPOSTA: NAO e possivel. LB (Basic E Standard) = mesma VNet apenas.
          Mesmo com VNet peering configurado, NAO funciona.
          Para cross-VNet, considere Application Gateway ou Traffic Manager.
```

### 1.2 — Criar Load Balancer Standard (todos os metodos)

> **Cenario:** Criar um LB Standard publico com IP publico zone-redundant, front-end, back-end pool, health probe HTTP na porta 80 e regra de balanceamento.

#### Metodo 1: Portal

```
1. Portal > Load balancers > + Create
2. Basics:
   - Subscription: (sua subscription)
   - Resource group: rg-lab-lb (criar novo se necessario)
   - Name: lb-demo
   - Region: East US
   - SKU: Standard
   - Type: Public
   - Tier: Regional
3. Frontend IP configuration > + Add:
   - Name: fe-ip
   - Public IP address > Create new:
     - Name: pip-lb
     - Availability zone: Zone-redundant
4. Backend pools > + Add:
   - Name: be-pool
   - Virtual network: (selecionar VNet existente)
   - Backend Pool Configuration: NIC
5. Inbound rules > + Add a load balancing rule:
   - Name: rule-http
   - Frontend IP: fe-ip
   - Backend pool: be-pool
   - Protocol: TCP
   - Port: 80
   - Backend port: 80
   - Health probe > Create new:
     - Name: probe-http
     - Protocol: HTTP
     - Port: 80
     - Path: /health
     - Interval: 5
     - Unhealthy threshold: 2
6. Review + Create > Create

IMPORTANTE: Depois de criar o LB Standard, voce PRECISA criar um NSG
com regra Allow no back-end, senao o trafego sera bloqueado!
```

#### Metodo 2: Azure CLI

```bash
# Variaveis
RG="rg-lab-lb"
LOCATION="eastus"
LB_NAME="lb-demo"

# Criar Resource Group
az group create -n $RG -l $LOCATION

# Criar IP publico zone-redundant (Standard SKU = obrigatorio para LB Standard)
az network public-ip create \
  -g $RG \
  -n pip-lb \
  --sku Standard \
  --zone 1 2 3 \
  --allocation-method Static

# Criar LB Standard com front-end e back-end pool
az network lb create \
  -g $RG \
  -n $LB_NAME \
  --sku Standard \
  --frontend-ip-name fe-ip \
  --public-ip-address pip-lb \
  --backend-pool-name be-pool

# Health probe HTTP na porta 80
az network lb probe create \
  -g $RG \
  --lb-name $LB_NAME \
  -n probe-http \
  --protocol Http \
  --port 80 \
  --path /health \
  --interval 5 \
  --threshold 2

# Regra de balanceamento
az network lb rule create \
  -g $RG \
  --lb-name $LB_NAME \
  -n rule-http \
  --frontend-ip fe-ip \
  --backend-pool-name be-pool \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --probe-name probe-http \
  --idle-timeout 4

# LEMBRETE: Criar NSG com Allow na porta 80 para o back-end!
az network nsg create -g $RG -n nsg-backend
az network nsg rule create -g $RG --nsg-name nsg-backend \
  -n AllowHTTP --priority 100 \
  --destination-port-ranges 80 --protocol Tcp --access Allow \
  --direction Inbound
```

#### Metodo 3: Azure PowerShell

```powershell
# Variaveis
$rg = "rg-lab-lb"
$location = "eastus"
$lbName = "lb-demo"

# Criar Resource Group
New-AzResourceGroup -Name $rg -Location $location

# Criar IP publico
$pip = New-AzPublicIpAddress `
  -Name "pip-lb" `
  -ResourceGroupName $rg `
  -Location $location `
  -Sku "Standard" `
  -AllocationMethod "Static" `
  -Zone 1, 2, 3

# Configurar front-end
$feConfig = New-AzLoadBalancerFrontendIpConfig `
  -Name "fe-ip" `
  -PublicIpAddress $pip

# Configurar back-end pool
$bePool = New-AzLoadBalancerBackendAddressPoolConfig `
  -Name "be-pool"

# Health probe
$probe = New-AzLoadBalancerProbeConfig `
  -Name "probe-http" `
  -Protocol "Http" `
  -Port 80 `
  -RequestPath "/health" `
  -IntervalInSeconds 5 `
  -ProbeCount 2

# Regra de balanceamento
$rule = New-AzLoadBalancerRuleConfig `
  -Name "rule-http" `
  -FrontendIpConfiguration $feConfig `
  -BackendAddressPool $bePool `
  -Probe $probe `
  -Protocol "Tcp" `
  -FrontendPort 80 `
  -BackendPort 80

# Criar LB (tudo junto)
# NOTA: PowerShell cria o LB inteiro de uma vez com todas as configs
New-AzLoadBalancer `
  -Name $lbName `
  -ResourceGroupName $rg `
  -Location $location `
  -Sku "Standard" `
  -FrontendIpConfiguration $feConfig `
  -BackendAddressPool $bePool `
  -Probe $probe `
  -LoadBalancingRule $rule

# Criar NSG com Allow (Standard LB e fechado por padrao!)
$nsgRule = New-AzNetworkSecurityRuleConfig `
  -Name "AllowHTTP" `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 100 `
  -SourceAddressPrefix "*" `
  -SourcePortRange "*" `
  -DestinationAddressPrefix "*" `
  -DestinationPortRange 80 `
  -Access "Allow"

New-AzNetworkSecurityGroup `
  -Name "nsg-backend" `
  -ResourceGroupName $rg `
  -Location $location `
  -SecurityRules $nsgRule
```

> **Diferenca CLI vs PowerShell:** No CLI, o LB e criado primeiro e depois probe/rule sao adicionados incrementalmente. No PowerShell, voce monta todas as configs como objetos e cria o LB inteiro de uma vez. Ambos alcancam o mesmo resultado, mas o modelo mental e diferente.

#### Metodo 4: ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "lbName": {
      "type": "string",
      "defaultValue": "lb-demo"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Network/publicIPAddresses",
      "apiVersion": "2023-09-01",
      "name": "pip-lb",
      "location": "[parameters('location')]",
      "sku": { "name": "Standard" },
      "zones": [ "1", "2", "3" ],
      "properties": {
        "publicIPAllocationMethod": "Static"
      }
    },
    {
      "type": "Microsoft.Network/loadBalancers",
      "apiVersion": "2023-09-01",
      "name": "[parameters('lbName')]",
      "location": "[parameters('location')]",
      "sku": { "name": "Standard" },
      "dependsOn": [
        "[resourceId('Microsoft.Network/publicIPAddresses', 'pip-lb')]"
      ],
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "fe-ip",
            "properties": {
              "publicIPAddress": {
                "id": "[resourceId('Microsoft.Network/publicIPAddresses', 'pip-lb')]"
              }
            }
          }
        ],
        "backendAddressPools": [
          { "name": "be-pool" }
        ],
        "probes": [
          {
            "name": "probe-http",
            "properties": {
              "protocol": "Http",
              "port": 80,
              "requestPath": "/health",
              "intervalInSeconds": 5,
              "numberOfProbes": 2
            }
          }
        ],
        "loadBalancingRules": [
          {
            "name": "rule-http",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', parameters('lbName'), 'fe-ip')]"
              },
              "backendAddressPool": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('lbName'), 'be-pool')]"
              },
              "probe": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/probes', parameters('lbName'), 'probe-http')]"
              },
              "protocol": "Tcp",
              "frontendPort": 80,
              "backendPort": 80,
              "idleTimeoutInMinutes": 4
            }
          }
        ]
      }
    }
  ]
}
```

```bash
# Deploy do ARM Template
az deployment group create \
  -g rg-lab-lb \
  --template-file lb-template.json
```

> **Vantagem do ARM:** Template declarativo e idempotente — voce pode rodar varias vezes e o resultado sera o mesmo. Ideal para ambientes que precisam de auditoria e versionamento no Git.

#### Metodo 5: Bicep

```bicep
// lb-main.bicep
param location string = resourceGroup().location
param lbName string = 'lb-demo'

// IP Publico zone-redundant
resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-lb'
  location: location
  sku: { name: 'Standard' }
  zones: [ '1', '2', '3' ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Load Balancer Standard
resource lb 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: lbName
  location: location
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'fe-ip'
        properties: {
          publicIPAddress: { id: pip.id }
        }
      }
    ]
    backendAddressPools: [
      { name: 'be-pool' }
    ]
    probes: [
      {
        name: 'probe-http'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/health'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'fe-ip')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'be-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'probe-http')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

output lbId string = lb.id
output pipAddress string = pip.properties.ipAddress
```

```bash
# Deploy do Bicep
az deployment group create \
  -g rg-lab-lb \
  --template-file lb-main.bicep
```

> **Bicep vs ARM:** Bicep e a evolucao do ARM Template. Mesma engine por baixo (Bicep compila para ARM JSON), mas com sintaxe muito mais limpa. Para novos projetos, prefira Bicep. Na prova, ARM aparece mais, mas Bicep esta crescendo.

---

## Parte 2 — Health Probes

### 2.1 — Tipos de Health Probe

| Tipo | Porta | Caminho | Uso tipico | SKU |
|------|-------|---------|------------|-----|
| **TCP** | Qualquer | N/A | Verifica se porta esta aberta (ex: banco de dados) | Basic + Standard |
| **HTTP** | 80 (padrao) | / (padrao) | Verifica resposta HTTP 200 (ex: web app) | Basic + Standard |
| **HTTPS** | 443 (padrao) | / (padrao) | Verifica resposta HTTPS 200 (ex: API segura) | **Standard apenas** |

### 2.2 — Parametros do Health Probe

| Parametro | Default | Significado | Impacto |
|-----------|---------|-------------|---------|
| **Port** | — | Porta a verificar | **Deve corresponder ao servico!** Porta errada = VM unhealthy |
| **Path** | / | Caminho HTTP/HTTPS | Use um endpoint de saude (ex: /health) |
| **Interval** | 5 seg | Tempo entre probes | Menor = deteccao mais rapida, mais trafego |
| **Unhealthy threshold** | 2 | Falhas consecutivas para marcar unhealthy | Maior = mais tolerante a falhas transientes |

### 2.3 — Criar e gerenciar Health Probes

#### Portal

```
Para ADICIONAR probe a um LB existente:
1. Portal > Load balancers > lb-demo
2. Settings > Health probes > + Add
3. Preencher:
   - Name: probe-https
   - Protocol: HTTPS
   - Port: 443
   - Path: /api/health
   - Interval: 10
   - Unhealthy threshold: 3
4. Save

Para VERIFICAR status das VMs:
1. Portal > Load balancers > lb-demo
2. Monitoring > Insights (ou Metrics)
3. Verificar "Health Probe Status" por instancia
```

#### Azure CLI

```bash
# Criar probe HTTPS (apenas Standard LB)
az network lb probe create \
  -g $RG \
  --lb-name $LB_NAME \
  -n probe-https \
  --protocol Https \
  --port 443 \
  --path /api/health \
  --interval 10 \
  --threshold 3

# Listar probes
az network lb probe list -g $RG --lb-name $LB_NAME -o table

# Atualizar probe existente (mudar intervalo)
az network lb probe update \
  -g $RG \
  --lb-name $LB_NAME \
  -n probe-http \
  --interval 10

# Deletar probe
az network lb probe delete -g $RG --lb-name $LB_NAME -n probe-https
```

#### PowerShell

```powershell
# Obter LB existente
$lb = Get-AzLoadBalancer -Name $lbName -ResourceGroupName $rg

# Adicionar probe HTTPS
$lb | Add-AzLoadBalancerProbeConfig `
  -Name "probe-https" `
  -Protocol "Https" `
  -Port 443 `
  -RequestPath "/api/health" `
  -IntervalInSeconds 10 `
  -ProbeCount 3

# Salvar alteracoes (PowerShell exige Set- para persistir!)
$lb | Set-AzLoadBalancer

# Listar probes
$lb.Probes | Format-Table Name, Protocol, Port, RequestPath

# Remover probe
$lb | Remove-AzLoadBalancerProbeConfig -Name "probe-https"
$lb | Set-AzLoadBalancer
```

> **Diferenca importante CLI vs PowerShell:** No CLI, `az network lb probe create` ja persiste a alteracao. No PowerShell, voce precisa chamar `Set-AzLoadBalancer` depois de `Add-AzLoadBalancerProbeConfig` para salvar. Esquecer o `Set-` e um erro comum.

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "LB esta funcionando mas nenhuma VM recebe trafego"
CAUSA MAIS COMUM: Health probe na porta errada ou servico nao esta rodando
SOLUCAO: Verificar se a porta do probe corresponde ao servico na VM

PERGUNTA: "VMs marcadas como unhealthy no LB"
CHECKLIST DE TROUBLESHOOTING:
1. Servico (ex: nginx) esta rodando na porta correta?
2. NSG permite trafego na porta do health probe? (168.63.129.16 = IP do Azure)
3. Probe path retorna HTTP 200? (nao 301, 302, 404, 500)
4. Firewall do OS permite a porta?

IP ESPECIAL: 168.63.129.16
- E o IP de origem dos health probes do Azure
- NUNCA bloqueie este IP no NSG!
- Se bloquear, TODAS as VMs ficam unhealthy
```

---

## Parte 3 — Session Persistence (Afinidade de Sessao)

### 3.1 — Modos de Distribuicao

| Modo | Nome no CLI | Hash baseado em | Comportamento |
|------|-------------|-----------------|---------------|
| **None** (default) | `Default` | 5-tupla (IP src, IP dst, porta src, porta dst, protocolo) | Round-robin — cada request pode ir para VM diferente |
| **Client IP** | `SourceIP` | 2-tupla (IP src, IP dst) | Todas as requests do mesmo IP vao para a mesma VM |
| **Client IP and Protocol** | `SourceIPProtocol` | 3-tupla (IP src, IP dst, protocolo) | Mesmo IP + mesmo protocolo = mesma VM |

### 3.2 — Quando usar cada modo

| Cenario | Modo recomendado | Por que |
|---------|-----------------|---------|
| Web app stateless (API REST) | **None** | Melhor distribuicao de carga |
| Web app com sessao (shopping cart) | **Client IP** | Usuario mantem sessao na mesma VM |
| RDP Gateway (multiplas sessoes) | **Client IP and Protocol** | Distingue sessoes TCP/UDP do mesmo cliente |
| Upload de arquivos grandes | **Client IP** | Evita fragmentacao entre VMs |

### 3.3 — Configurar Session Persistence

#### Portal

```
1. Portal > Load balancers > lb-demo
2. Settings > Load balancing rules
3. Clicar na regra existente (rule-http)
4. Alterar "Session persistence":
   - None (default)
   - Client IP
   - Client IP and protocol
5. Save
```

#### Azure CLI

```bash
# Alterar para Client IP (sticky sessions)
az network lb rule update \
  -g $RG \
  --lb-name $LB_NAME \
  -n rule-http \
  --load-distribution SourceIP

# Alterar para Client IP and Protocol
az network lb rule update \
  -g $RG \
  --lb-name $LB_NAME \
  -n rule-http \
  --load-distribution SourceIPProtocol

# Voltar para None (round-robin, default)
az network lb rule update \
  -g $RG \
  --lb-name $LB_NAME \
  -n rule-http \
  --load-distribution Default

# Verificar configuracao atual
az network lb rule show \
  -g $RG \
  --lb-name $LB_NAME \
  -n rule-http \
  --query loadDistribution -o tsv
```

#### PowerShell

```powershell
# Obter LB
$lb = Get-AzLoadBalancer -Name $lbName -ResourceGroupName $rg

# Alterar para Client IP
$lb.LoadBalancingRules[0].LoadDistribution = "SourceIP"
$lb | Set-AzLoadBalancer

# Alterar para Client IP and Protocol
$lb.LoadBalancingRules[0].LoadDistribution = "SourceIPProtocol"
$lb | Set-AzLoadBalancer

# Voltar para None (default)
$lb.LoadBalancingRules[0].LoadDistribution = "Default"
$lb | Set-AzLoadBalancer

# Verificar
$lb.LoadBalancingRules | Select-Object Name, LoadDistribution
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Requisicoes do mesmo usuario devem ir sempre para a mesma VM"
CERTO: Session Persistence = Client IP (SourceIP)

PERGUNTA: "Distribuir trafego igualmente entre todas as VMs"
CERTO: Session Persistence = None (default, 5-tuple hash)

NOMES EQUIVALENTES NA PROVA (mesma coisa, nomes diferentes):
- "Client IP" = "Source IP affinity" = "SourceIP" = "Session persistence" = "2-tuple hash"
- "None" = "5-tuple hash" = "Default distribution" = "Round-robin"
- "Client IP and Protocol" = "SourceIPProtocol" = "3-tuple hash"

CUIDADO COM A PEGADINHA:
- "Session persistence" na prova pode significar o CONCEITO (afinidade) ou o MODO "Client IP"
- Leia o contexto da pergunta para entender qual significado
```

---

## Parte 4 — DNS Zone Import

### 4.1 — Por que so o Azure CLI suporta import de zona DNS?

O Azure DNS suporta importacao de arquivos de zona no formato padrao (RFC 1035). Porem, essa funcionalidade foi implementada **apenas no Azure CLI**, por questoes historicas de design:

| Ferramenta | Import de zona DNS | Export de zona DNS | Criar registros individuais |
|------------|:-----------------:|:------------------:|:--------------------------:|
| **Azure CLI** | **Sim** | **Sim** | Sim |
| **PowerShell** | **Nao** | **Nao** | Sim |
| **Portal** | **Nao** | **Nao** | Sim |
| **REST API** | **Nao** | **Nao** | Sim |
| **ARM/Bicep** | **Nao** | **Nao** | Sim |

> **Conclusao:** Se a prova perguntar sobre migrar uma zona DNS inteira para o Azure, a resposta e **sempre** Azure CLI com `az network dns zone import`.

### 4.2 — Importar zona DNS completa (CLI - unico metodo)

```bash
# Formato do arquivo de zona (techcloud.com.zone):
# $ORIGIN techcloud.com.
# $TTL 3600
# @  IN  SOA  ns1.techcloud.com. admin.techcloud.com. (
# @  IN  NS   ns1-01.azure-dns.com.
# @  IN  A    20.30.40.50
# www  IN  CNAME  techcloud.com.
# mail IN  MX  10  mail.techcloud.com.
# ... (500+ registros)

# Importar zona DNS inteira a partir do arquivo
az network dns zone import \
  -g $RG \
  -n techcloud.com \
  --file-name techcloud.com.zone

# Exportar zona DNS para arquivo (backup antes de migrar)
az network dns zone export \
  -g $RG \
  -n techcloud.com \
  --file-name techcloud-export.zone

# Verificar registros importados
az network dns record-set list \
  -g $RG \
  -z techcloud.com \
  -o table
```

### 4.3 — Criar registros DNS individuais (CLI + PowerShell como comparacao)

Quando voce nao tem um arquivo de zona e precisa criar registros um a um, tanto CLI quanto PowerShell funcionam:

#### Azure CLI

```bash
# Criar zona DNS
az network dns zone create -g $RG -n techcloud.com

# Registro A
az network dns record-set a add-record \
  -g $RG -z techcloud.com \
  -n www -a 20.30.40.50

# Registro CNAME
az network dns record-set cname set-record \
  -g $RG -z techcloud.com \
  -n blog -c blog.techcloud.com

# Registro MX
az network dns record-set mx add-record \
  -g $RG -z techcloud.com \
  -n @ -e mail.techcloud.com -p 10

# Listar todos os record sets
az network dns record-set list -g $RG -z techcloud.com -o table
```

#### PowerShell

```powershell
# Criar zona DNS
New-AzDnsZone -Name "techcloud.com" -ResourceGroupName $rg

# Registro A
New-AzDnsRecordSet -Name "www" -RecordType A -ZoneName "techcloud.com" `
  -ResourceGroupName $rg -Ttl 3600 `
  -DnsRecords (New-AzDnsRecordConfig -IPv4Address "20.30.40.50")

# Registro CNAME
New-AzDnsRecordSet -Name "blog" -RecordType CNAME -ZoneName "techcloud.com" `
  -ResourceGroupName $rg -Ttl 3600 `
  -DnsRecords (New-AzDnsRecordConfig -Cname "blog.techcloud.com")

# Registro MX
New-AzDnsRecordSet -Name "@" -RecordType MX -ZoneName "techcloud.com" `
  -ResourceGroupName $rg -Ttl 3600 `
  -DnsRecords (New-AzDnsRecordConfig -Exchange "mail.techcloud.com" -Preference 10)

# Listar registros
Get-AzDnsRecordSet -ZoneName "techcloud.com" -ResourceGroupName $rg
```

> **Perceba a diferenca:** Para 500 registros, usar CLI com `az network dns zone import` e 1 comando. Com PowerShell, seriam 500 comandos `New-AzDnsRecordSet`. Por isso o CLI e a resposta correta para migracoes em massa.

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Migrar 500 registros DNS para Azure com menor esforco"
ERRADO: Azure PowerShell (nao suporta import de zona — teria que criar 1 a 1)
ERRADO: Portal do Azure (nao suporta import de zona — teria que criar 1 a 1)
ERRADO: Gerenciador de DNS do Windows (ferramenta local, nao Azure)
ERRADO: ARM Template / Bicep (nao suportam import de arquivo de zona)
CERTO:  Azure CLI — az network dns zone import

SOMENTE o Azure CLI suporta import/export de arquivos de zona DNS!
Este e um dos poucos casos onde uma operacao existe em APENAS uma ferramenta.
```

---

## Parte 5 — Troubleshooting de Rede (Network Watcher)

### 5.1 — Ferramentas do Network Watcher

| Ferramenta | O que faz | Quando usar | Pre-requisito |
|------------|-----------|-------------|---------------|
| **IP Flow Verify** | Testa se um pacote especifico (IP+porta+protocolo) e permitido ou negado | "Por que nao consigo conectar na porta 443?" | VM deve estar em execucao |
| **NSG Flow Logs** | Registra **TODO** trafego que passa pelos NSGs | "Auditar todo trafego de rede para compliance" | Storage Account para armazenar logs |
| **Connection Monitor** | Monitora conectividade **continuamente** entre endpoints | "Alertar se conexao entre App e DB cair" | Extensao Network Watcher Agent |
| **Connection Troubleshoot** | Diagnostico **pontual** de conectividade | "Testar conectividade agora (one-shot)" | Extensao Network Watcher Agent |
| **Packet Capture** | Captura pacotes de rede (como Wireshark) | "Analisar trafego em detalhe tecnico" | **Extensao Network Watcher Agent!** |
| **Next Hop** | Mostra proximo salto de roteamento para um destino | "Para onde vai o trafego desta VM?" | VM deve estar em execucao |
| **Effective Security Rules** | Mostra TODAS as regras NSG efetivas aplicadas a uma NIC | "Quais regras realmente se aplicam a esta VM?" | Nenhum extra |
| **Topology** | Diagrama visual dos recursos de rede | "Visualizar a arquitetura de rede" | Nenhum extra |

### 5.2 — Usando as ferramentas (Portal + CLI)

#### IP Flow Verify

**O que e:** Testa se um pacote especifico seria permitido ou negado pelas regras NSG de uma VM. Diferente do NSG Flow Logs que registra tudo, aqui voce testa UM pacote especifico.

```
Portal:
1. Portal > Network Watcher > IP flow verify
2. Selecionar VM, NIC, protocolo (TCP/UDP), direcao (Inbound/Outbound)
3. Preencher: Local port, Remote IP, Remote port
4. Clicar "Check" — resultado: Access allowed / Access denied + regra responsavel
```

```bash
# CLI: Verificar se trafego TCP na porta 80 e permitido
az network watcher test-ip-flow \
  --vm $VM_NAME \
  -g $RG \
  --direction Inbound \
  --protocol TCP \
  --local 10.0.0.4:80 \
  --remote 203.0.113.50:12345

# Resultado exemplo: "Access: Allow, Rule: AllowHTTP"
# ou: "Access: Deny, Rule: DenyAllInBound"
```

```powershell
# PowerShell
Test-AzNetworkWatcherIPFlow `
  -NetworkWatcher $networkWatcher `
  -TargetVirtualMachineId $vm.Id `
  -Direction "Inbound" `
  -Protocol "TCP" `
  -LocalIPAddress "10.0.0.4" `
  -LocalPort "80" `
  -RemoteIPAddress "203.0.113.50" `
  -RemotePort "12345"
```

#### NSG Flow Logs

**O que e:** Registra TODOS os fluxos de trafego (permitidos e negados) que passam por um NSG. Armazena em uma Storage Account no formato JSON. Usado para auditoria e analise historica.

```
Portal:
1. Portal > Network Watcher > NSG flow logs > + Create
2. Selecionar NSG, Storage Account, retention (dias)
3. Opcional: habilitar Traffic Analytics (requer Log Analytics Workspace)
```

```bash
# CLI: Habilitar NSG Flow Logs
az network watcher flow-log create \
  -g $RG \
  --nsg nsg-backend \
  -n flowlog-nsg \
  --storage-account $SA_ID \
  --enabled true \
  --retention 90 \
  --format JSON

# Verificar status
az network watcher flow-log show \
  -g $RG \
  --nsg nsg-backend
```

#### Packet Capture

**O que e:** Captura pacotes de rede de uma VM (como tcpdump/Wireshark). Resultado pode ser salvo localmente na VM ou em Storage Account.

```
Portal:
1. Portal > Network Watcher > Packet capture > + Add
2. Selecionar VM (extensao sera instalada automaticamente se necessario)
3. Configurar filtros (protocolo, porta, IP)
4. Definir destino (Storage Account ou local na VM)
5. Start
```

```bash
# PREREQUISITO: instalar extensao Network Watcher Agent na VM
az vm extension set \
  -g $RG \
  --vm-name $VM_NAME \
  --name NetworkWatcherAgentLinux \
  --publisher Microsoft.Azure.NetworkWatcher

# Iniciar captura
az network watcher packet-capture create \
  -g $RG \
  --vm $VM_NAME \
  -n capture-demo \
  --storage-account $SA_ID \
  --filters '[{"protocol":"TCP","localPort":"80"}]' \
  --time-limit 60

# Listar capturas
az network watcher packet-capture list -l $LOCATION -o table

# Parar captura
az network watcher packet-capture stop \
  -l $LOCATION \
  -n capture-demo
```

```powershell
# PowerShell: instalar extensao
Set-AzVMExtension `
  -ResourceGroupName $rg `
  -VMName $vmName `
  -Name "NetworkWatcherAgentLinux" `
  -Publisher "Microsoft.Azure.NetworkWatcher" `
  -ExtensionType "NetworkWatcherAgentLinux" `
  -TypeHandlerVersion "1.4" `
  -Location $location
```

#### Next Hop

```bash
# CLI: Verificar proximo salto para um destino
az network watcher show-next-hop \
  -g $RG \
  --vm $VM_NAME \
  --source-ip 10.0.0.4 \
  --dest-ip 8.8.8.8

# Resultado exemplo: "nextHopType: Internet" ou "nextHopType: VirtualAppliance"
```

#### Connection Monitor

```bash
# CLI: Criar monitor de conectividade continuo
az network watcher connection-monitor create \
  -n monitor-app-to-db \
  -l $LOCATION \
  --test-group-name tg-sql \
  --endpoint-source-name app-vm \
  --endpoint-source-resource-id $APP_VM_ID \
  --endpoint-dest-name db-vm \
  --endpoint-dest-resource-id $DB_VM_ID \
  --test-config-name tcp-1433 \
  --protocol Tcp \
  --tcp-port 1433 \
  --frequency 30
```

### 5.3 — Tabela de decisao rapida para a prova

| Cenario na prova | Ferramenta correta |
|-----------------|-------------------|
| "Registrar TODO trafego de/para uma VM" | **NSG Flow Logs** |
| "Verificar se porta 80 esta permitida ou bloqueada" | **IP Flow Verify** |
| "Capturar pacotes para analise detalhada" | **Packet Capture** (requer extensao!) |
| "Monitorar conectividade entre dois endpoints continuamente" | **Connection Monitor** |
| "Testar conectividade pontual entre duas VMs" | **Connection Troubleshoot** |
| "Ver para onde vai o trafego (rota)" | **Next Hop** |
| "Ver todas as regras NSG efetivas de uma NIC" | **Effective Security Rules** |
| "Visualizar topologia da rede" | **Topology** |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Registrar TODAS as tentativas de conexao de/para uma VM"
CERTO: Network Watcher + NSG Flow Logs
ERRADO: IP Flow Verify (testa UM pacote, nao registra tudo)
ERRADO: Packet Capture (captura pacotes, nao registra fluxos)

PERGUNTA: "Verificar se trafego na porta 80 e permitido ou negado"
CERTO: IP Flow Verify
ERRADO: NSG Flow Logs (registra historico, nao testa em tempo real)

PERGUNTA: "Capturar pacotes de rede de uma VM"
CERTO: Packet Capture
PREREQUISITO OBRIGATORIO: Extensao Network Watcher Agent na VM!
- Linux: NetworkWatcherAgentLinux
- Windows: NetworkWatcherAgentWindows
SEM a extensao, o Packet Capture NAO funciona.

PERGUNTA: "Monitorar conectividade entre VM e endpoint externo continuamente"
CERTO: Connection Monitor (continuo, com alertas)
ERRADO: Connection Troubleshoot (pontual, sem alertas)

NAO CONFUNDIR:
- NSG Flow Logs = REGISTRA tudo (passivo, historico)
- IP Flow Verify = TESTA um pacote (ativo, tempo real)
- Packet Capture = CAPTURA pacotes (ativo, detalhe tecnico)
- Connection Monitor = MONITORA conectividade (continuo, com alertas)
- Connection Troubleshoot = TESTA conectividade (pontual, sem alertas)
```

---

## Parte 6 — Cleanup

```bash
# Azure CLI
az group delete -n $RG --yes --no-wait
```

```powershell
# PowerShell
Remove-AzResourceGroup -Name $rg -Force -AsJob
```

---

## Comparacao de Metodos

### Resumo por operacao

| Operacao | Portal | CLI | PowerShell | ARM | Bicep |
|----------|:------:|:---:|:----------:|:---:|:-----:|
| Criar LB Standard | Sim | Sim | Sim | Sim | Sim |
| Criar Health Probe | Sim | Sim | Sim | Sim | Sim |
| Configurar Session Persistence | Sim | Sim | Sim | Sim | Sim |
| **Import zona DNS** | **Nao** | **Sim** | **Nao** | **Nao** | **Nao** |
| **Export zona DNS** | **Nao** | **Sim** | **Nao** | **Nao** | **Nao** |
| Criar registro DNS individual | Sim | Sim | Sim | Sim | Sim |
| IP Flow Verify | Sim | Sim | Sim | N/A | N/A |
| NSG Flow Logs | Sim | Sim | Sim | Sim | Sim |
| Packet Capture | Sim | Sim | Sim | N/A | N/A |
| Connection Monitor | Sim | Sim | Sim | Sim | Sim |

### Quando usar cada metodo neste lab

| Cenario | Melhor metodo | Por que |
|---------|--------------|---------|
| Criar LB pela primeira vez (aprendizado) | **Portal** | Visual, ve todas as opcoes |
| Automatizar criacao de LB em CI/CD | **Bicep/ARM** | Declarativo, idempotente, versionavel |
| Script rapido para testar LB | **CLI** | Rapido de escrever, bom para Cloud Shell |
| Ambiente corporativo Windows | **PowerShell** | Objetos tipados, integra com AD/SCCM |
| Migrar zona DNS inteira | **CLI** | Unica opcao! |
| Troubleshooting de rede | **Portal + CLI** | Portal para visual, CLI para automacao |

### Comparacao de verbosidade (linhas de codigo para criar LB completo)

| Metodo | Linhas aproximadas | Complexidade |
|--------|:-----------------:|:------------:|
| Portal | 6 telas, ~20 cliques | Baixa |
| CLI | ~25 linhas | Baixa |
| PowerShell | ~35 linhas | Media |
| ARM Template | ~70 linhas | Alta |
| Bicep | ~50 linhas | Media |

### Modelo mental de cada ferramenta

```
Portal     → "Clique e configure" (imperativo visual)
CLI        → "Faca isso agora" (imperativo sequencial)
PowerShell → "Monte o objeto, depois salve" (imperativo com objetos)
ARM        → "Descreva o estado final em JSON" (declarativo verboso)
Bicep      → "Descreva o estado final, limpo" (declarativo moderno)
```

---

## Questoes de Prova

### Q1
Voce configurou um Azure Load Balancer Standard publico. Duas VMs estao no back-end pool rodando nginx na porta 80. O NSG permite trafego na porta 80. O health probe esta configurado na porta 443. Nenhum usuario consegue acessar o servico. Qual e a causa mais provavel?

- A. O LB precisa ser Basic, nao Standard
- B. O health probe esta na porta errada (443 em vez de 80)
- C. As VMs precisam estar em um Availability Set
- D. O LB precisa de um IP privado, nao publico

<details>
<summary>Resposta</summary>

**B.** O health probe verifica a porta 443, mas o nginx roda na porta 80. As VMs sao marcadas como **unhealthy** porque nao respondem na porta 443, e o LB para de enviar trafego para elas. A solucao e corrigir a porta do probe para 80.

**Por que as outras estao erradas:**
- A: Standard LB funciona perfeitamente, nao precisa ser Basic
- C: Availability Set nao e obrigatorio para o LB funcionar
- D: IP publico e correto para acesso externo

</details>

### Q2
Voce tem um Azure Load Balancer interno Basic. VMs em uma VNet diferente (com peering bidirecional configurado e funcionando) precisam ser adicionadas ao back-end pool. Isso e possivel?

- A. Sim, com peering bidirecional e suficiente
- B. Sim, mas precisa de VNet Gateway alem do peering
- C. Nao, Load Balancer so suporta VMs da mesma VNet no back-end pool
- D. Sim, mas apenas com LB Standard (Basic nao suporta)

<details>
<summary>Resposta</summary>

**C.** Azure Load Balancer (tanto Basic quanto Standard) so suporta VMs da **mesma VNet** no back-end pool. Peering NAO resolve isso — mesmo com peering bidirecional funcionando, voce nao pode adicionar VMs de outra VNet ao pool.

**Por que as outras estao erradas:**
- A: Peering permite comunicacao entre VNets, mas nao permite adicionar VMs ao back-end pool do LB
- B: VNet Gateway tambem nao resolve essa limitacao
- D: Standard tambem tem essa limitacao — mesma VNet apenas

</details>

### Q3
Usuarios de um aplicativo web reclamam que perdem o carrinho de compras quando navegam entre paginas. O aplicativo usa um Azure Load Balancer Standard com 3 VMs. A sessao e armazenada localmente na VM. Qual configuracao do LB resolve o problema?

- A. Session Persistence = None
- B. Session Persistence = Client IP
- C. Aumentar o health probe interval para 30 segundos
- D. Habilitar Floating IP

<details>
<summary>Resposta</summary>

**B.** Session Persistence = Client IP (SourceIP) garante que todas as requisicoes do mesmo IP de cliente vao para a mesma VM. Como a sessao esta armazenada localmente na VM, o usuario precisa sempre cair na mesma VM para manter o carrinho.

**Por que as outras estao erradas:**
- A: None (default) usa 5-tuple hash, podendo enviar requests do mesmo usuario para VMs diferentes
- C: Interval do probe nao afeta distribuicao de trafego
- D: Floating IP e para cenarios com SQL AlwaysOn, nao para afinidade de sessao

</details>

### Q4
Voce e o administrador de DNS de uma empresa. Precisa migrar uma zona DNS com 500 registros de um servidor DNS on-premises para o Azure DNS com o menor esforco administrativo. Qual ferramenta voce deve usar?

- A. Azure PowerShell (New-AzDnsRecordSet para cada registro)
- B. Azure CLI (az network dns zone import)
- C. Portal do Azure (criar cada registro manualmente)
- D. Gerenciador de DNS do Windows Server

<details>
<summary>Resposta</summary>

**B.** Azure CLI com `az network dns zone import` e a **unica** ferramenta que suporta importacao de um arquivo de zona DNS inteiro para o Azure DNS. Um unico comando importa todos os 500 registros.

**Por que as outras estao erradas:**
- A: PowerShell funciona para criar registros individuais, mas nao suporta import de arquivo de zona (seria 500 comandos separados!)
- C: Portal permite criar registros um a um, mas seria extremamente trabalhoso para 500 registros
- D: Gerenciador de DNS e uma ferramenta local do Windows Server, nao do Azure

</details>

### Q5
Voce precisa registrar todo o trafego de rede (permitido e negado) que passa pelos NSGs associados a uma VM para fins de auditoria e compliance. Qual recurso do Network Watcher voce deve configurar?

- A. Connection Monitor
- B. IP Flow Verify
- C. Packet Capture
- D. NSG Flow Logs

<details>
<summary>Resposta</summary>

**D.** NSG Flow Logs registram **todo** o trafego IP que passa pelos NSGs (origem, destino, porta, protocolo, allow/deny). Os logs sao armazenados em uma Storage Account e podem ser analisados com Traffic Analytics.

**Por que as outras estao erradas:**
- A: Connection Monitor monitora conectividade entre endpoints, nao registra todo trafego
- B: IP Flow Verify testa se UM pacote especifico seria permitido/negado (pontual, nao registra)
- C: Packet Capture captura conteudo dos pacotes (nivel 4-7), nao registra fluxos; alem disso requer extensao

</details>

### Q6
Voce precisa capturar pacotes de rede de uma VM Linux no Azure para diagnosticar um problema de conectividade. Voce tenta usar o Packet Capture do Network Watcher, mas recebe um erro. Qual e a causa mais provavel?

- A. O Network Watcher nao esta habilitado na regiao
- B. A VM nao tem a extensao Network Watcher Agent instalada
- C. A VM esta parada (deallocated)
- D. Todas as anteriores

<details>
<summary>Resposta</summary>

**D.** Todas as opcoes sao causas validas, mas na prova, se a pergunta pedir a causa **mais provavel** e a VM esta rodando, a resposta mais comum e **B** — a extensao Network Watcher Agent (`NetworkWatcherAgentLinux`) deve estar instalada na VM para que o Packet Capture funcione.

**Checklist completo:**
1. Network Watcher habilitado na regiao (geralmente automatico)
2. VM em execucao (nao deallocated)
3. **Extensao Network Watcher Agent instalada na VM** (causa mais cobrada na prova)

</details>

---

## Resumo Final para Revisao Rapida

```
LOAD BALANCER:
- Basic: gratuito, sem SLA, NSG opcional (aberto), sem HTTPS probe
- Standard: pago, 99,99% SLA, NSG OBRIGATORIO (fechado), HTTPS probe
- Ambos: mesma VNet apenas (peering NAO ajuda)
- Troubleshooting: probe errada + NSG bloqueando = 90% dos problemas

SESSION PERSISTENCE:
- None (Default) = 5-tupla = round-robin
- Client IP (SourceIP) = 2-tupla = sticky sessions
- Client IP and Protocol (SourceIPProtocol) = 3-tupla

DNS ZONE IMPORT:
- SOMENTE Azure CLI: az network dns zone import
- PowerShell/Portal/ARM/Bicep = NAO suportam import de zona

NETWORK WATCHER:
- NSG Flow Logs = registra TUDO (passivo)
- IP Flow Verify = testa UM pacote (ativo)
- Packet Capture = requer extensao Network Watcher Agent!
- Connection Monitor = continuo / Connection Troubleshoot = pontual
```
