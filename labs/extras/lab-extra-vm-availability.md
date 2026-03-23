# Lab Extra: VM Operations, Availability e SLAs

> **Objetivo:** Dominar operacoes de VM (downtime, resize, disco), Availability Sets/Zones, SLAs e Spot VMs — tudo com multiplos metodos de implantacao.
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 90-120 min (teoria + pratica multi-metodo + questoes)

---

## Variaveis Globais

Todas as tasks deste lab compartilham estas variaveis. Defina-as antes de comecar.

**Azure CLI (Bash):**
```bash
RG="rg-lab-vm-avail"
LOCATION="eastus"
VM_NAME="vm-demo"
ADMIN_USER="azureuser"
```

**PowerShell:**
```powershell
$RG = "rg-lab-vm-avail"
$Location = "eastus"
$VMName = "vm-demo"
$AdminUser = "azureuser"
```

---

## Parte 1 — Operacoes que Causam Downtime

### Tabela critica para a prova

Esta tabela e uma das mais cobradas. Decore quais operacoes exigem que a VM esteja parada.

| Operacao | Requer VM parada? | Downtime? | Por que? |
|----------|:-----------------:|:---------:|----------|
| Redimensionar (resize) | **Depende** | **Depende** | Se o tamanho esta no cluster atual, nao precisa parar. Senao, precisa desalocar. |
| Adicionar NIC | **Sim** | **Sim** | NIC requer reconfiguracao do hypervisor |
| Adicionar disco de dados | Nao | Nao | Hot-attach suportado |
| Instalar extensao | Nao | Nao | Agent executa dentro da VM |
| Alterar NSG | Nao | Nao | NSG e recurso de rede externo |
| Alterar tags | Nao | Nao | Metadado do ARM, nao afeta a VM |
| Capturar imagem | **Sim** (generalizar) | **Sim** | Precisa sysprep/waagent + desalocar |
| Mover para outro RG | Nao | Nao | Operacao de metadado no ARM |
| Alterar tipo de disco (Standard→Premium) | **Sim** | **Sim** | Requer desalocacao para trocar storage tier |

### PONTO CRITICO PARA PROVA

```
MEMORIZE ESTA REGRA:
- Adicionar DISCO = SEM downtime (hot-attach)
- Adicionar NIC = COM downtime (precisa parar VM)
- Instalar EXTENSAO = SEM downtime (agent interno)
- RESIZE = DEPENDE (verificar disponibilidade primeiro!)

A prova ADORA perguntar "quais 2 operacoes causam downtime?"
Resposta classica: Resize + Adicionar NIC
```

### Task 1.1 — Criar Resource Group e VM (5 metodos)

> **Por que aprender 5 metodos?**
> - **Portal:** Ideal para aprendizado visual e operacoes unicas
> - **Azure CLI:** Preferido por admins Linux, scripts rapidos em Bash
> - **PowerShell:** Preferido por admins Windows, integracao com automacao corporativa
> - **ARM Template:** Infraestrutura declarativa, versionavel no Git, padrao historico do Azure
> - **Bicep:** Evolucao do ARM — sintaxe limpa, mesma engine por baixo

#### Metodo 1: Portal

1. Portal > **Resource Groups** > **+ Create**
2. Subscription: sua subscription
3. Resource group: `rg-lab-vm-avail`
4. Region: **East US**
5. **Review + Create** > **Create**

Depois, criar a VM:

1. Portal > **Virtual Machines** > **+ Create** > **Azure virtual machine**
2. Aba **Basics:**
   - Resource group: `rg-lab-vm-avail`
   - Virtual machine name: `vm-demo`
   - Region: **East US**
   - Availability options: **No infrastructure redundancy required**
   - Image: **Ubuntu Server 22.04 LTS**
   - Size: **Standard_B1s**
   - Authentication type: **SSH public key**
   - Username: `azureuser`
   - SSH public key source: **Generate new key pair**
3. Aba **Disks:** manter padrao (Premium SSD)
4. Aba **Networking:** manter padrao (nova VNet, IP publico, NSG basico)
5. **Review + Create** > **Create**
6. Fazer download da chave SSH quando solicitado

#### Metodo 2: Azure CLI

```bash
# Criar Resource Group
az group create -n $RG -l $LOCATION

# Criar VM
az vm create \
  -g $RG \
  -n $VM_NAME \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --output table
```

> **Quando usar CLI:** Scripts rapidos, pipelines CI/CD em Linux, Cloud Shell. O `--generate-ssh-keys` cria e armazena a chave automaticamente em `~/.ssh/`.

#### Metodo 3: PowerShell

```powershell
# Criar Resource Group
New-AzResourceGroup -Name $RG -Location $Location

# Criar credencial (para a prova, saiba que PowerShell usa PSCredential)
$securePassword = ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($AdminUser, $securePassword)

# Criar VM
New-AzVM `
  -ResourceGroupName $RG `
  -Name $VMName `
  -Location $Location `
  -Image "Ubuntu2204" `
  -Size "Standard_B1s" `
  -Credential $cred `
  -OpenPorts 22
```

> **Quando usar PowerShell:** Ambientes corporativos Windows, Azure Automation Runbooks, integracao com System Center. Na prova, note que PowerShell usa `-ResourceGroupName` (longo) enquanto CLI usa `-g` (curto).

#### Metodo 4: ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vmName": {
      "type": "string",
      "defaultValue": "vm-demo"
    },
    "adminUsername": {
      "type": "string",
      "defaultValue": "azureuser"
    },
    "adminPassword": {
      "type": "securestring"
    },
    "vmSize": {
      "type": "string",
      "defaultValue": "Standard_B1s"
    }
  },
  "variables": {
    "vnetName": "[concat(parameters('vmName'), '-vnet')]",
    "subnetName": "default",
    "nicName": "[concat(parameters('vmName'), '-nic')]",
    "pipName": "[concat(parameters('vmName'), '-pip')]",
    "nsgName": "[concat(parameters('vmName'), '-nsg')]"
  },
  "resources": [
    {
      "type": "Microsoft.Network/networkSecurityGroups",
      "apiVersion": "2023-04-01",
      "name": "[variables('nsgName')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "securityRules": [
          {
            "name": "Allow-SSH",
            "properties": {
              "priority": 1000,
              "protocol": "Tcp",
              "access": "Allow",
              "direction": "Inbound",
              "sourceAddressPrefix": "*",
              "sourcePortRange": "*",
              "destinationAddressPrefix": "*",
              "destinationPortRange": "22"
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Network/publicIPAddresses",
      "apiVersion": "2023-04-01",
      "name": "[variables('pipName')]",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Basic" },
      "properties": {
        "publicIPAllocationMethod": "Dynamic"
      }
    },
    {
      "type": "Microsoft.Network/virtualNetworks",
      "apiVersion": "2023-04-01",
      "name": "[variables('vnetName')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "addressSpace": { "addressPrefixes": ["10.0.0.0/16"] },
        "subnets": [
          {
            "name": "[variables('subnetName')]",
            "properties": { "addressPrefix": "10.0.0.0/24" }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Network/networkInterfaces",
      "apiVersion": "2023-04-01",
      "name": "[variables('nicName')]",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]",
        "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]",
        "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
      ],
      "properties": {
        "ipConfigurations": [
          {
            "name": "ipconfig1",
            "properties": {
              "subnet": {
                "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]"
              },
              "publicIPAddress": {
                "id": "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
              }
            }
          }
        ],
        "networkSecurityGroup": {
          "id": "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
        }
      }
    },
    {
      "type": "Microsoft.Compute/virtualMachines",
      "apiVersion": "2023-07-01",
      "name": "[parameters('vmName')]",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
      ],
      "properties": {
        "hardwareProfile": { "vmSize": "[parameters('vmSize')]" },
        "osProfile": {
          "computerName": "[parameters('vmName')]",
          "adminUsername": "[parameters('adminUsername')]",
          "adminPassword": "[parameters('adminPassword')]"
        },
        "storageProfile": {
          "imageReference": {
            "publisher": "Canonical",
            "offer": "0001-com-ubuntu-server-jammy",
            "sku": "22_04-lts",
            "version": "latest"
          },
          "osDisk": {
            "createOption": "FromImage",
            "managedDisk": { "storageAccountType": "Premium_LRS" }
          }
        },
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
            }
          ]
        }
      }
    }
  ]
}
```

Deploy do ARM Template:

```bash
# Via CLI
az deployment group create \
  -g $RG \
  --template-file vm-template.json \
  --parameters adminPassword="P@ssw0rd1234!"
```

```powershell
# Via PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName $RG `
  -TemplateFile "vm-template.json" `
  -adminPassword (ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force)
```

> **Quando usar ARM Template:** Deployments repetitivos, ambientes padronizados, auditoria de infraestrutura. ARM e o formato nativo do Azure — tudo por baixo e ARM.

#### Metodo 5: Bicep

```bicep
// arquivo: vm-demo.bicep
param vmName string = 'vm-demo'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
param vmSize string = 'Standard_B1s'
param location string = resourceGroup().location

var vnetName = '${vmName}-vnet'
var subnetName = 'default'
var nicName = '${vmName}-nic'
var pipName = '${vmName}-pip'
var nsgName = '${vmName}-nsg'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  sku: { name: 'Basic' }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: subnetName
        properties: { addressPrefix: '10.0.0.0/24' }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
    networkSecurityGroup: { id: nsg.id }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nic.id }]
    }
  }
}
```

Deploy do Bicep:

```bash
# Via CLI
az deployment group create \
  -g $RG \
  --template-file vm-demo.bicep \
  --parameters adminPassword="P@ssw0rd1234!"
```

```powershell
# Via PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName $RG `
  -TemplateFile "vm-demo.bicep" `
  -adminPassword (ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force)
```

> **Quando usar Bicep:** Mesmos cenarios do ARM Template, mas com sintaxe muito mais limpa. Bicep compila para ARM JSON. Microsoft recomenda Bicep como padrao para novos projetos IaC.

---

## Parte 2 — Redimensionar VM (Resize)

### Conceito

Redimensionar uma VM muda a quantidade de vCPUs, memoria e capacidade de rede. O passo **mais importante** (e mais cobrado na prova) e verificar PRIMEIRO se o tamanho desejado esta disponivel no cluster atual.

### Task 2.1 — Verificar tamanhos disponiveis e redimensionar

#### Metodo 1: Portal

1. Portal > **Virtual Machines** > `vm-demo`
2. Menu lateral > **Availability + scaling** > **Size**
3. A lista mostra **apenas os tamanhos disponiveis no cluster atual**
4. Se o tamanho desejado aparece: selecionar > **Resize** (reinicio automatico)
5. Se NAO aparece: precisa desalocar primeiro
   - Menu lateral > **Overview** > **Stop** (desalocar)
   - Depois voltar em **Size** — a lista tera mais opcoes
   - Selecionar tamanho > **Resize**
   - Menu lateral > **Overview** > **Start**

#### Metodo 2: Azure CLI

```bash
# PASSO 1 (OBRIGATORIO): Verificar tamanhos disponiveis no cluster atual
az vm list-vm-resize-options -g $RG -n $VM_NAME -o table

# CENARIO A: Tamanho desejado ESTA na lista → resize direto (reinicia VM)
az vm resize -g $RG -n $VM_NAME --size Standard_B2s

# CENARIO B: Tamanho desejado NAO esta na lista → desalocar primeiro
az vm deallocate -g $RG -n $VM_NAME
az vm resize -g $RG -n $VM_NAME --size Standard_D2s_v3
az vm start -g $RG -n $VM_NAME
```

#### Metodo 3: PowerShell

```powershell
# PASSO 1 (OBRIGATORIO): Verificar tamanhos disponiveis
Get-AzVMSize -ResourceGroupName $RG -VMName $VMName | Format-Table

# CENARIO A: Resize direto
$vm = Get-AzVM -ResourceGroupName $RG -Name $VMName
$vm.HardwareProfile.VmSize = "Standard_B2s"
Update-AzVM -ResourceGroupName $RG -VM $vm

# CENARIO B: Desalocar → resize → iniciar
Stop-AzVM -ResourceGroupName $RG -Name $VMName -Force
$vm = Get-AzVM -ResourceGroupName $RG -Name $VMName
$vm.HardwareProfile.VmSize = "Standard_D2s_v3"
Update-AzVM -ResourceGroupName $RG -VM $vm
Start-AzVM -ResourceGroupName $RG -Name $VMName
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Primeiro passo para redimensionar VM via CLI?"
ERRADO: Desalocar a VM
ERRADO: Reiniciar a VM
CERTO:  Verificar tamanhos disponiveis (az vm list-vm-resize-options)
        So desalocar se o tamanho desejado NAO estiver disponivel no cluster

DETALHES:
- CLI: az vm list-vm-resize-options
- PowerShell: Get-AzVMSize
- Portal: VM > Size (lista automatica)

POR QUE? Cada cluster fisico do Azure tem um conjunto de hardware.
Se o tamanho desejado esta no mesmo cluster, o resize e feito com
apenas um reinicio. Se nao esta, a VM precisa ser movida para outro
cluster (desalocar = mover fisicamente).
```

---

## Parte 3 — Operacoes com Disco

### Task 3.1 — Adicionar disco de dados (sem downtime)

> Adicionar disco de dados e uma operacao **hot-attach** — a VM continua rodando.

#### Metodo 1: Portal

1. Portal > **Virtual Machines** > `vm-demo`
2. Menu lateral > **Settings** > **Disks**
3. **+ Create and attach a new disk**
4. Preencher: Name: `disk-data-01`, Size: 64 GiB, SKU: Standard SSD
5. **Save** (nao precisa parar a VM)

#### Metodo 2: Azure CLI

```bash
# Adicionar disco de dados COM a VM rodando (hot-attach)
az vm disk attach \
  -g $RG \
  --vm-name $VM_NAME \
  --name disk-data-01 \
  --size-gb 64 \
  --sku StandardSSD_LRS \
  --new
```

#### Metodo 3: PowerShell

```powershell
# Adicionar disco COM a VM rodando
$vm = Get-AzVM -ResourceGroupName $RG -Name $VMName
$diskConfig = New-AzDiskConfig `
  -SkuName StandardSSD_LRS `
  -Location $Location `
  -CreateOption Empty `
  -DiskSizeGB 64

$dataDisk = New-AzDisk `
  -ResourceGroupName $RG `
  -DiskName "disk-data-01" `
  -Disk $diskConfig

$vm = Add-AzVMDataDisk `
  -VM $vm `
  -Name "disk-data-01" `
  -ManagedDiskId $dataDisk.Id `
  -Lun 0 `
  -CreateOption Attach

Update-AzVM -ResourceGroupName $RG -VM $vm
```

### Task 3.2 — Transferir disco entre VMs

Este cenario e classico na prova: mover um disco de dados de VM1 para VM2 com **minimo downtime**.

> **NOTA TECNICA:** Azure suporta hot-detach de discos de dados (desanexar com VM ligada).
> Porem, na prova a Microsoft espera que voce **pare a VM de origem** para garantir
> consistencia de dados (nenhum processo escrevendo no disco durante o detach).
> "Minimo downtime" na prova = parar **so a VM de origem**, nao ambas.

#### Sequencia correta para a prova (4 passos)

```
VM-ORIGEM                          VM-DESTINO
    |                                  |
    | 1. Parar VM-ORIGEM               |
    |    (deallocate)                  |
    |    (consistencia de dados)       |
    |                                  |
    | 2. Desanexar disco               |
    |    da VM-ORIGEM                  |
    |                                  |
    |          disco ──────────────>   |
    |                                  |
    |                    3. Anexar disco|
    |                    na VM-DESTINO |
    |                    (SEM PARAR!)  |
    |                                  |
    | 4. Iniciar VM-ORIGEM             |
    |                                  |
```

#### Azure CLI

```bash
# Criar segunda VM para demonstracao
az vm create -g $RG -n vm-dest \
  --image Ubuntu2204 --size Standard_B1s \
  --admin-username $ADMIN_USER --generate-ssh-keys

# --- PASSO 1: Parar VM de origem ---
az vm deallocate -g $RG -n $VM_NAME

# --- PASSO 2: Desanexar disco da origem ---
az vm disk detach -g $RG --vm-name $VM_NAME -n disk-data-01

# --- PASSO 3: Anexar disco no destino (SEM parar a VM destino!) ---
az vm disk attach -g $RG --vm-name vm-dest -n disk-data-01

# --- PASSO 4: Reiniciar VM de origem ---
az vm start -g $RG -n $VM_NAME
```

#### PowerShell

```powershell
# --- PASSO 1: Parar VM de origem ---
Stop-AzVM -ResourceGroupName $RG -Name $VMName -Force

# --- PASSO 2: Desanexar disco da origem ---
$vmOrigin = Get-AzVM -ResourceGroupName $RG -Name $VMName
Remove-AzVMDataDisk -VM $vmOrigin -Name "disk-data-01"
Update-AzVM -ResourceGroupName $RG -VM $vmOrigin

# --- PASSO 3: Anexar disco no destino (SEM parar!) ---
$vmDest = Get-AzVM -ResourceGroupName $RG -Name "vm-dest"
$disk = Get-AzDisk -ResourceGroupName $RG -DiskName "disk-data-01"
$vmDest = Add-AzVMDataDisk `
  -VM $vmDest `
  -Name "disk-data-01" `
  -ManagedDiskId $disk.Id `
  -Lun 0 `
  -CreateOption Attach
Update-AzVM -ResourceGroupName $RG -VM $vmDest

# --- PASSO 4: Reiniciar VM de origem ---
Start-AzVM -ResourceGroupName $RG -Name $VMName
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Transferir disco de VM1 para VM2 com minimo downtime. Ordem?"

ERRADO: Iniciar VM1, Iniciar VM2, desanexar, anexar
ERRADO: Parar ambas as VMs, desanexar, anexar, iniciar ambas
CERTO:  Parar VM1 → Desanexar → Anexar na VM2 (sem parar VM2) → Iniciar VM1

REGRAS:
- Tecnicamente hot-detach funciona (disco de dados pode ser removido com VM ligada)
- Mas na PROVA: parar VM ORIGEM antes de remover (garantia de consistencia de dados)
- VM DESTINO NAO precisa ser parada para RECEBER disco (hot-attach)
- "Minimo downtime" = parar SO a VM1 (nao ambas!)
- Se a prova perguntar "sem downtime" ou "sem parar nenhuma VM" → hot-detach + hot-attach
```

---

## Parte 4 — Availability Sets (5 metodos)

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| Fault Domain (FD) | Rack fisico compartilhado (energia + rede). Max = **3** |
| Update Domain (UD) | Grupo logico para manutencao planejada. Max = **20** |
| Manutencao planejada | Afeta **1 UD por vez** — VMs nos outros UDs continuam rodando |
| Falha de hardware | Afeta **1 FD inteiro** — todas as VMs daquele rack caem |
| Managed Disks | **Obrigatorio** para SLA completo de 99,95% |
| SLA | **99,95%** (com 2+ VMs e Managed Disks) |
| Restricao | VM so pode ser adicionada ao Availability Set **na criacao** |

### Calculo de impacto (como a prova pergunta)

> **DICA DE PROVA:** Na Pearson VUE voce recebe um quadro branco com caneta apagavel.
> Para questoes de FD/UD, **desenhe os racks** e distribua as VMs em round-robin.
> Visualizar ajuda muito mais do que tentar calcular de cabeca.

```
EXEMPLO: 5 VMs, 3 FDs, 5 UDs

PASSO 1 — Desenhe os racks (FDs) e distribua as VMs (round-robin):

  Rack 0 (FD0)    Rack 1 (FD1)    Rack 2 (FD2)
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ VM1 (UD0)│    │ VM2 (UD1)│    │ VM3 (UD2)│
  │ VM4 (UD3)│    │ VM5 (UD4)│    │          │
  └──────────┘    └──────────┘    └──────────┘
      2 VMs           2 VMs          1 VM
            distribuicao: 2-2-1

PASSO 2 — Responda a pergunta olhando o desenho:

  "Falha de hardware?" → olhe os RACKS verticalmente
    Pior caso: Rack 0 ou 1 cai → 2 VMs fora

  "Manutencao planejada?" → olhe os UDs (cada UD reinicia sozinho)
    Cada UD tem 1 VM → 1 VM fora por vez
```

```
OUTRO EXEMPLO: 5 VMs, 2 FDs, 5 UDs

  Rack 0 (FD0)    Rack 1 (FD1)
  ┌──────────┐    ┌──────────┐
  │ VM1 (UD0)│    │ VM2 (UD1)│
  │ VM3 (UD2)│    │ VM4 (UD3)│
  │ VM5 (UD4)│    │          │
  └──────────┘    └──────────┘
      3 VMs           2 VMs
        distribuicao: 3-2

  Pior caso hardware: Rack 0 cai → 3 VMs fora
  Manutencao: 1 VM fora por vez
```

### Task 4.1 — Criar Availability Set + VM

#### Metodo 1: Portal

1. Portal > Pesquisar **"Availability sets"** > **+ Create**
2. Resource group: `rg-lab-vm-avail`
3. Name: `avset-demo`
4. Region: **East US**
5. Fault domains: **3**
6. Update domains: **5**
7. Use managed disks: **Yes (Aligned)**
8. **Review + Create** > **Create**

Depois, criar VM no Availability Set:

1. Portal > **Virtual Machines** > **+ Create**
2. Na aba **Basics** > Availability options: **Availability set**
3. Availability set: `avset-demo`
4. Preencher restante normalmente
5. **Review + Create** > **Create**

> **Importante:** Uma VM so pode ser associada a um Availability Set no momento da criacao. Nao e possivel mover uma VM existente para um Availability Set.

#### Metodo 2: Azure CLI

```bash
# Criar Availability Set com 3 FDs e 5 UDs
az vm availability-set create \
  -g $RG \
  -n avset-demo \
  --platform-fault-domain-count 3 \
  --platform-update-domain-count 5

# Criar VM dentro do Availability Set
az vm create \
  -g $RG \
  -n vm-avset-01 \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --availability-set avset-demo \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys

# Criar segunda VM (mesma avset)
az vm create \
  -g $RG \
  -n vm-avset-02 \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --availability-set avset-demo \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys
```

#### Metodo 3: PowerShell

```powershell
# Criar Availability Set
New-AzAvailabilitySet `
  -ResourceGroupName $RG `
  -Name "avset-demo" `
  -Location $Location `
  -PlatformFaultDomainCount 3 `
  -PlatformUpdateDomainCount 5 `
  -Sku Aligned   # Aligned = Managed Disks (obrigatorio para SLA)

# Criar VM no Availability Set
$avset = Get-AzAvailabilitySet -ResourceGroupName $RG -Name "avset-demo"
$cred = New-Object System.Management.Automation.PSCredential (
  $AdminUser,
  (ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force)
)

$vmConfig = New-AzVMConfig `
  -VMName "vm-avset-01" `
  -VMSize "Standard_B1s" `
  -AvailabilitySetId $avset.Id

$vmConfig = Set-AzVMOperatingSystem `
  -VM $vmConfig `
  -Linux `
  -ComputerName "vm-avset-01" `
  -Credential $cred

$vmConfig = Set-AzVMSourceImage `
  -VM $vmConfig `
  -PublisherName "Canonical" `
  -Offer "0001-com-ubuntu-server-jammy" `
  -Skus "22_04-lts" `
  -Version "latest"

New-AzVM -ResourceGroupName $RG -Location $Location -VM $vmConfig
```

> **Na prova:** PowerShell usa `-AvailabilitySetId` no `New-AzVMConfig` e o SKU do Availability Set deve ser `Aligned` para Managed Disks.

#### Metodo 4: ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminPassword": {
      "type": "securestring"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Compute/availabilitySets",
      "apiVersion": "2023-07-01",
      "name": "avset-demo",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Aligned" },
      "properties": {
        "platformFaultDomainCount": 3,
        "platformUpdateDomainCount": 5
      }
    },
    {
      "type": "Microsoft.Network/networkInterfaces",
      "apiVersion": "2023-04-01",
      "name": "vm-avset-01-nic",
      "location": "[resourceGroup().location]",
      "properties": {
        "ipConfigurations": [
          {
            "name": "ipconfig1",
            "properties": {
              "subnet": {
                "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', 'vm-demo-vnet', 'default')]"
              }
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Compute/virtualMachines",
      "apiVersion": "2023-07-01",
      "name": "vm-avset-01",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[resourceId('Microsoft.Compute/availabilitySets', 'avset-demo')]",
        "[resourceId('Microsoft.Network/networkInterfaces', 'vm-avset-01-nic')]"
      ],
      "properties": {
        "availabilitySet": {
          "id": "[resourceId('Microsoft.Compute/availabilitySets', 'avset-demo')]"
        },
        "hardwareProfile": { "vmSize": "Standard_B1s" },
        "osProfile": {
          "computerName": "vm-avset-01",
          "adminUsername": "azureuser",
          "adminPassword": "[parameters('adminPassword')]"
        },
        "storageProfile": {
          "imageReference": {
            "publisher": "Canonical",
            "offer": "0001-com-ubuntu-server-jammy",
            "sku": "22_04-lts",
            "version": "latest"
          },
          "osDisk": {
            "createOption": "FromImage",
            "managedDisk": { "storageAccountType": "Premium_LRS" }
          }
        },
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces', 'vm-avset-01-nic')]"
            }
          ]
        }
      }
    }
  ]
}
```

> **Na prova:** No ARM Template, o Availability Set usa `sku.name: "Aligned"` para Managed Disks. A VM referencia via `availabilitySet.id`. Note o `dependsOn` obrigatorio.

#### Metodo 5: Bicep

```bicep
// arquivo: avset-demo.bicep
@secure()
param adminPassword string
param location string = resourceGroup().location

resource avset 'Microsoft.Compute/availabilitySets@2023-07-01' = {
  name: 'avset-demo'
  location: location
  sku: { name: 'Aligned' }
  properties: {
    platformFaultDomainCount: 3
    platformUpdateDomainCount: 5
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'vm-avset-01-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vm-demo-vnet', 'default')
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-avset-01'
  location: location
  properties: {
    availabilitySet: { id: avset.id }
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: 'vm-avset-01'
      adminUsername: 'azureuser'
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nic.id }]
    }
  }
}
```

> **Bicep vs ARM:** Note como Bicep infere dependencias automaticamente (sem `dependsOn`), usa `avset.id` diretamente, e a sintaxe e drasticamente mais limpa. O resultado compilado e identico ao ARM JSON.

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "5 VMs em Availability Set com 2 FDs e 5 UDs.
           Manutencao planejada. Quantas VMs ficam indisponiveis?"
RESPOSTA: 1 VM (5 VMs / 5 UDs = 1 por UD. Azure atualiza 1 UD por vez)

PERGUNTA: "5 VMs em Availability Set com 2 FDs e 5 UDs.
           Falha de hardware em 1 rack."
RESPOSTA: Ate 3 VMs (ceil(5/2) = 3 no pior FD, 2 no outro)

REGRA DE OURO:
- Manutencao planejada → afeta Update Domains (UD)
- Falha de hardware    → afeta Fault Domains (FD)
- platformUpdateDomainCount maximo = 20
- platformFaultDomainCount maximo = 3

ERROS COMUNS NOS SIMULADOS (errou 3x!):
- Confundir UD com FD na hora de calcular impacto
- Esquecer que max FD = 3 e max UD = 20
- Esquecer que VM so entra no Availability Set NA CRIACAO
```

---

## Parte 5 — Availability Zones

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| O que e | Datacenters fisicamente separados dentro da mesma regiao |
| Zonas por regiao | Geralmente 3 (Zona 1, 2 e 3) |
| Protege contra | Falha de datacenter inteiro (energia, rede, cooling) |
| SLA | **99,99%** (com 2+ VMs em zonas diferentes) |
| Latencia | < 2ms entre zonas (fibra dedicada) |
| Custo | Sem custo adicional pela zona, mas trafego entre zonas e cobrado |
| Restricao | Nem todas as regioes suportam Availability Zones |

### Availability Set vs Availability Zone — Comparacao direta

| Criterio | Availability Set | Availability Zone |
|----------|:----------------:|:-----------------:|
| Protege contra | Falha de hardware (rack) | Falha de datacenter inteiro |
| Fault Domains (FD) | 2 ou 3 (max **3**) | 1 por zona (isolamento fisico) |
| Update Domains (UD) | 2 a **20** (max 20) | N/A (zonas sao independentes) |
| SLA | **99,95%** | **99,99%** |
| Requer Managed Disks? | Sim (para SLA completo) | Sim |
| Escopo | Dentro de 1 datacenter | Entre datacenters na mesma regiao |
| Pode combinar? | **NAO** — Set e Zone sao mutuamente exclusivos para a mesma VM |

### Task 5.1 — Criar VM em Availability Zone

#### Metodo 1: Portal (multiplas zonas de uma vez)

1. Portal > **Virtual Machines** > **+ Create**
2. Aba **Basics:**
   - Resource group: `rg-lab-vm-avail`
   - Virtual machine name: `vm-zone` (Portal gera nomes automaticos: vm-zone-1, vm-zone-2, vm-zone-3)
   - Region: **East US**
   - Availability options: **Availability zone**
   - Selecionar **Zone 1, Zone 2, Zone 3** (multiplas zonas de uma vez!)
   - Image: Ubuntu Server 22.04 LTS
   - Size: Standard_B1s
3. Completar restante > **Review + Create** > **Create**

> **No Portal:** Voce pode selecionar ate 3 zonas de uma vez. O Azure cria **1 VM por zona** automaticamente,
> gerando nomes sequenciais (ex: vm-zone-1, vm-zone-2, vm-zone-3). Clique em "Editar Nomes" para personalizar.
> Availability Set e Availability Zone sao opcoes mutuamente exclusivas.

#### Metodo 2: Azure CLI

```bash
# VM na Zona 1
az vm create \
  -g $RG \
  -n vm-zone-01 \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --zone 1 \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys

# VM na Zona 2 (para SLA de 99,99%)
az vm create \
  -g $RG \
  -n vm-zone-02 \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --zone 2 \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys

# Verificar zona de cada VM
az vm show -g $RG -n vm-zone-01 --query '{Name:name, Zone:zones[0]}' -o table
az vm show -g $RG -n vm-zone-02 --query '{Name:name, Zone:zones[0]}' -o table
```

#### Metodo 3: ARM Template (trecho da VM com zona)

```json
{
  "type": "Microsoft.Compute/virtualMachines",
  "apiVersion": "2023-07-01",
  "name": "vm-zone-01",
  "location": "[resourceGroup().location]",
  "zones": ["1"],
  "properties": {
    "hardwareProfile": { "vmSize": "Standard_B1s" },
    "osProfile": {
      "computerName": "vm-zone-01",
      "adminUsername": "azureuser",
      "adminPassword": "[parameters('adminPassword')]"
    },
    "storageProfile": {
      "imageReference": {
        "publisher": "Canonical",
        "offer": "0001-com-ubuntu-server-jammy",
        "sku": "22_04-lts",
        "version": "latest"
      },
      "osDisk": {
        "createOption": "FromImage",
        "managedDisk": { "storageAccountType": "Premium_LRS" }
      }
    },
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "[resourceId('Microsoft.Network/networkInterfaces', 'vm-zone-01-nic')]"
        }
      ]
    }
  }
}
```

> **No ARM Template:** A zona e definida pelo campo `"zones": ["1"]` no nivel raiz do recurso (nao dentro de `properties`). E um array de strings, nao numeros.

#### Metodo 4: Bicep (trecho)

```bicep
resource vmZone 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-zone-01'
  location: location
  zones: ['1']   // zona definida no nivel raiz
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    // ... restante igual ao template anterior
  }
}
```

#### Metodo 5: PowerShell

```powershell
# VM na Zona 1
$cred = New-Object System.Management.Automation.PSCredential (
  $AdminUser,
  (ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force)
)

New-AzVM `
  -ResourceGroupName $RG `
  -Name "vm-zone-01" `
  -Location $Location `
  -Zone 1 `
  -Image "Ubuntu2204" `
  -Size "Standard_B1s" `
  -Credential $cred `
  -OpenPorts 22
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Maior disponibilidade possivel para VMs na mesma regiao?"
CERTO: Availability Zones (99,99%)
ERRADO: Availability Set (99,95% — menor)

PERGUNTA: "Posso colocar uma VM em Availability Set E Zone ao mesmo tempo?"
RESPOSTA: NAO. Sao mutuamente exclusivos. Escolha um ou outro.

PERGUNTA: "VM em Zone 1 e outra em Zone 2. SLA?"
RESPOSTA: 99,99% (2+ VMs em zonas diferentes)

DETALHES TECNICOS:
- Zones = datacenters separados fisicamente (km de distancia)
- Sets = racks separados dentro do MESMO datacenter
- Zones > Sets em nivel de protecao
```

---

## Parte 6 — SLAs de Disponibilidade

### Tabela completa de SLAs (DECORE!)

| Configuracao | SLA | Observacao |
|-------------|:---:|-----------|
| VM unica com Premium SSD/Ultra Disk | **99,9%** | Minimo para producao |
| VM unica com Standard HDD | **Nenhum** | Sem SLA! Nao use em producao |
| Availability Set + Managed Disks | **99,95%** | 2+ VMs no mesmo datacenter |
| VMSS com 2+ instancias | **99,95%** | Mesmo nivel que Availability Set |
| Availability Zones (2+ VMs) | **99,99%** | Maior SLA para VMs |
| Traffic Manager | **99,99%** | DNS-based, nao LB |
| Azure Front Door | **99,99%** | Global load balancer |
| Standard Load Balancer | **99,99%** | Regional load balancer |

### Hierarquia visual de SLAs

```
99,99% ─── Availability Zones (2+ VMs em zonas diferentes)
       ─── Traffic Manager
       ─── Azure Front Door
       ─── Standard Load Balancer

99,95% ─── Availability Set + Managed Disks (2+ VMs)
       ─── VMSS com 2+ instancias

99,9%  ─── VM unica com Premium SSD ou Ultra Disk

  0%   ─── VM unica com Standard HDD (sem SLA)
       ─── Spot VMs (sem SLA)
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "SLA de 99,95% para VMs. Quais 2 recursos?"
CERTO: Managed Disks + Availability Set (com 2+ VMs)

PERGUNTA: "VMSS com multiplas VMs tem SLA de 99,95%?"
CERTO: SIM — mesmo nivel que Availability Set

PEGADINHA: "Traffic Manager tem SLA de 99,95%?"
RESPOSTA: NAO — Traffic Manager = 99,99% (MAIOR, nao menor!)
A prova coloca 99,95% como opcao para confundir.

PEGADINHA: "VM unica com Ultra Disk tem SLA de 99,95%?"
RESPOSTA: NAO — VM unica com Ultra Disk = 99,9% (nao 99,95%)

REGRA: SLA de 99,95% exige MULTIPLAS VMs (Set ou VMSS).
       VM unica NUNCA passa de 99,9%.
```

---

## Parte 7 — Spot VMs

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| O que e | VM com desconto (ate **90%**!) usando capacidade ociosa do Azure |
| Eviction (despejo) | Azure pode tomar a VM a **qualquer momento** quando precisa da capacidade |
| Eviction policy | **Deallocate** (default) — mantem disco e config. **Delete** — destroi tudo |
| Eviction type | **Capacity-based** — Azure precisa do hardware. **Price-based** — preco subiu acima do max |
| Max price | Voce define o preco maximo que aceita pagar. `-1` = pay-as-you-go price (nunca evict por preco) |
| SLA | **Nenhum** (0% — sem NENHUMA garantia) |
| Uso ideal | Batch processing, dev/test, CI/CD, rendering, HPC — tudo que tolera interrupcao |
| NAO usar para | Producao critica, bancos de dados, servicos que precisam estar sempre up |

### Task 7.1 — Criar Spot VM

#### Azure CLI

```bash
# Spot VM com eviction policy Deallocate
az vm create \
  -g $RG \
  -n vm-spot-01 \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --priority Spot \
  --eviction-policy Deallocate \
  --max-price 0.05 \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys
```

#### PowerShell

```powershell
$cred = New-Object System.Management.Automation.PSCredential (
  $AdminUser,
  (ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force)
)

New-AzVM `
  -ResourceGroupName $RG `
  -Name "vm-spot-01" `
  -Location $Location `
  -Image "Ubuntu2204" `
  -Size "Standard_D2s_v3" `
  -Priority Spot `
  -EvictionPolicy Deallocate `
  -MaxPrice 0.05 `
  -Credential $cred `
  -OpenPorts 22
```

#### Portal

1. Portal > **Virtual Machines** > **+ Create**
2. Aba **Basics:**
   - Preencher dados normais (nome, regiao, imagem, tamanho)
   - **Azure Spot instance:** marcar checkbox **Yes**
   - **Eviction type:** escolher (Capacity only / Price or capacity)
   - **Eviction policy:** escolher (Stop / Deallocate / Delete)
   - **Maximum price:** definir valor ou deixar -1 (on-demand)
3. **Review + Create** > **Create**

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "VM com menor custo para workload que tolera interrupcao"
CERTO: Spot VM (ate 90% desconto)
ERRADO: Reserved Instance (desconto menor, sem interrupcao)
ERRADO: B-series (burstable, mas preco normal)

PERGUNTA: "Spot VM eviction policy para PRESERVAR disco e IP"
CERTO: Deallocate (mantem disco e config alocada, so desaloca compute)
ERRADO: Delete (destroi a VM, disco e todos os recursos associados)

PERGUNTA: "Spot VM tem SLA?"
RESPOSTA: NAO. SLA = 0%. Sem NENHUMA garantia de disponibilidade.

DICA: Se a prova pergunta "menor custo" + "pode ser interrompido",
      a resposta e SEMPRE Spot VM.
```

---

## Parte 8 — Cleanup

```bash
# CLI
az group delete -n $RG --yes --no-wait
```

```powershell
# PowerShell
Remove-AzResourceGroup -Name $RG -Force -AsJob
```

---

### Task 5.1 — Custom Script Extension em ARM Template (VMSS)

**Conceito crítico (errado em simulado!):**

Para instalar software (ex: NGINX) em VMs de um VMSS via ARM Template:

**Passo 1:** Upload do script para uma Storage Account
**Passo 2:** Usar `extensionProfile` com Custom Script Extension no ARM

```json
{
  "extensionProfile": {
    "extensions": [
      {
        "name": "installNginx",
        "properties": {
          "publisher": "Microsoft.Azure.Extensions",
          "type": "CustomScript",
          "typeHandlerVersion": "2.1",
          "autoUpgradeMinorVersion": true,
          "settings": {
            "fileUris": [
              "https://mystorageaccount.blob.core.windows.net/scripts/install-nginx.sh"
            ],
            "commandToExecute": "bash install-nginx.sh"
          }
        }
      }
    ]
  }
}
```

| Extensão | Quando usar | Publisher |
|----------|-------------|----------|
| **Custom Script Extension (Linux)** | Executar script bash | Microsoft.Azure.Extensions |
| **Custom Script Extension (Windows)** | Executar script PS1 | Microsoft.Compute |
| **DSC Extension** | Desired State Configuration (Windows) | Microsoft.PowerShell |

> **DICA PROVA:** "Instalar NGINX em VMSS via ARM" → Storage Account + Custom Script Extension (extensionProfile). DSC é alternativa para Windows, mas Custom Script é a resposta quando a questão menciona script.

### Task 5.2 — Mover VM entre VNets

**Conceito crítico (errado em simulado!):**

Não é possível trocar a VNet de uma NIC existente. Para mover uma VM para outra VNet:

**Sequência:**
```
1. Anotar configurações da VM (tamanho, discos, extensões)
2. Deletar a VM (mantém os discos!)
3. Criar nova NIC na VNet de destino
4. Recriar a VM usando o disco OS existente + nova NIC
```

**Exemplo — CLI:**
```bash
# 1. Deletar VM (preserva disco)
az vm delete --name VM1 --resource-group RG1 --yes

# 2. Criar NIC na nova VNet
az network nic create \
  --name VM1-NIC-new \
  --resource-group RG1 \
  --vnet-name VNET2 \
  --subnet SubnetA

# 3. Recriar VM com disco existente
az vm create \
  --name VM1 \
  --resource-group RG1 \
  --attach-os-disk VM1-OSDisk \
  --os-type Linux \
  --nics VM1-NIC-new
```

> **DICA PROVA:** "Mover VM para outra VNet" → Deletar VM + recriar com nova NIC + disco existente. A VM é deletada mas o disco é preservado. Esta é uma solução VÁLIDA.

---

## Comparacao de Metodos

### Quando usar cada metodo

| Criterio | Portal | Azure CLI | PowerShell | ARM Template | Bicep |
|----------|:------:|:---------:|:----------:|:------------:|:-----:|
| Curva de aprendizado | Facil | Media | Media | Dificil | Media |
| Automacao | Nao | Sim | Sim | Sim | Sim |
| Idempotente | Nao | Parcial | Parcial | **Sim** | **Sim** |
| Versionamento (Git) | Nao | Sim (scripts) | Sim (scripts) | **Sim** | **Sim** |
| Validacao pre-deploy | Nao | Nao | Nao | **Sim** (what-if) | **Sim** (what-if) |
| Melhor para | Aprendizado, tarefas unicas | Scripts, pipelines Linux | Automacao Windows | Infra padronizada | Infra padronizada (moderno) |
| Suporte a modulos/loops | N/A | for/while (Bash) | ForEach | **copy** element | **for** expression |
| Estado | Sem estado | Sem estado | Sem estado | Declarativo | Declarativo |

### Equivalencia de comandos criticos

| Operacao | Azure CLI | PowerShell |
|----------|-----------|------------|
| Criar VM | `az vm create` | `New-AzVM` |
| Listar tamanhos | `az vm list-vm-resize-options` | `Get-AzVMSize` |
| Resize VM | `az vm resize --size` | `Update-AzVM` (apos alterar HardwareProfile) |
| Desalocar VM | `az vm deallocate` | `Stop-AzVM -Force` |
| Iniciar VM | `az vm start` | `Start-AzVM` |
| Attach disco | `az vm disk attach` | `Add-AzVMDataDisk` + `Update-AzVM` |
| Detach disco | `az vm disk detach` | `Remove-AzVMDataDisk` + `Update-AzVM` |
| Criar Availability Set | `az vm availability-set create` | `New-AzAvailabilitySet` |
| Deploy template | `az deployment group create` | `New-AzResourceGroupDeployment` |

### Equivalencia de parametros criticos

| Conceito | CLI | PowerShell | ARM/Bicep |
|----------|-----|------------|-----------|
| Resource Group | `-g` ou `--resource-group` | `-ResourceGroupName` | `resourceGroup()` |
| Zona | `--zone 1` | `-Zone 1` | `"zones": ["1"]` |
| Availability Set | `--availability-set <nome>` | `-AvailabilitySetId <id>` | `"availabilitySet": {"id": "..."}` |
| Spot VM | `--priority Spot` | `-Priority Spot` | `"priority": "Spot"` |
| Tamanho | `--size Standard_B1s` | `-Size "Standard_B1s"` | `"vmSize": "Standard_B1s"` |

### PONTO CRITICO PARA PROVA

```
A prova AZ-104 cobra CLI E PowerShell. Memorize as diferencas:

CLI:
  az vm list-vm-resize-options  (um comando)
  az vm resize --size           (um comando)
  az vm disk attach --new       (cria e anexa em um passo)

PowerShell:
  Get-AzVMSize                  (um cmdlet)
  Update-AzVM                   (precisa Get → alterar objeto → Update)
  Add-AzVMDataDisk + Update-AzVM (dois passos sempre)

REGRA: CLI = 1 comando faz tudo. PowerShell = pipeline de objetos
       (Get → Modify → Update).

ARM Template:
  --parameters inline: az deployment group create --parameters key=value
  NAO confunda com --parameters @file.json (arquivo)
  Errou 2x nos simulados!
```

---

## Questoes de Prova

### Q1

Voce possui a VM `demovm` (D4s_v3, 1 NIC, 1 disco). Planeja: redimensionar para D8s_v3, adicionar disco de 200 GB, adicionar uma NIC, instalar extensao Puppet. Quais **2 alteracoes** causam downtime?

- A. Redimensionar
- B. Adicionar disco
- C. Adicionar NIC
- D. Instalar extensao

<details>
<summary>Resposta</summary>

**A, C.** Redimensionar e adicionar NIC exigem VM parada. Disco de dados suporta hot-attach (sem downtime). Extensoes sao instaladas pelo Azure VM Agent dentro da VM sem necessidade de reinicio.

</details>

### Q2

Voce precisa redimensionar uma VM Linux via CLI. Qual e o **primeiro passo**?

- A. Desalocar a VM
- B. Reiniciar a VM
- C. Verificar tamanhos disponiveis no cluster
- D. Desconectar a NIC primaria

<details>
<summary>Resposta</summary>

**C.** Verificar tamanhos disponiveis com `az vm list-vm-resize-options`. Se o tamanho desejado estiver no cluster atual, o resize pode ser feito sem desalocar (apenas reinicio). Desalocar so e necessario se o tamanho NAO estiver disponivel no cluster.

Comando: `az vm list-vm-resize-options -g <rg> -n <vm> -o table`
PowerShell equivalente: `Get-AzVMSize -ResourceGroupName <rg> -VMName <vm>`

</details>

### Q3

5 VMs em um Availability Set com 2 Fault Domains e 5 Update Domains. Durante **manutencao planejada**, quantas VMs ficam indisponiveis ao mesmo tempo?

- A. 1
- B. 2
- C. 3
- D. 5

<details>
<summary>Resposta</summary>

**A.** Manutencao planejada = **Update Domains**. 5 VMs / 5 UDs = 1 VM por UD. Azure atualiza 1 UD por vez, entao no maximo 1 VM fica indisponivel simultaneamente.

Se a pergunta fosse sobre **falha de hardware** (Fault Domains): 5 VMs / 2 FDs = ceil(5/2) = **3 VMs** no pior caso (3 em um FD, 2 no outro).

**MEMORIZE:** Manutencao = UD. Hardware = FD. Errou 3x nos simulados!

</details>

### Q4

Para garantir SLA de **99,95%** para VMs, quais recursos sao necessarios?

- A. Availability Zones
- B. Managed Disks + Availability Set
- C. Traffic Manager
- D. Premium SSD em VM unica

<details>
<summary>Resposta</summary>

**B.** Managed Disks + Availability Set (com 2+ VMs) = **99,95%**.

Analise das outras opcoes:
- A: Availability Zones = 99,99% (maior, nao 99,95%)
- C: Traffic Manager = 99,99% (maior, nao 99,95%)
- D: VM unica com Premium SSD = 99,9% (menor, nao 99,95%)

**Dica:** SLA de 99,95% exige multiplas VMs em Availability Set ou VMSS.

</details>

### Q5

Voce precisa transferir um disco de dados da VM1 para a VM2 com **minimo downtime**. Qual a ordem correta?

- A. Iniciar VM1 → Iniciar VM2 → Desanexar → Anexar
- B. Parar VM1 → Desanexar → Anexar na VM2 → Iniciar VM1
- C. Parar ambas → Desanexar → Anexar → Iniciar ambas
- D. Desanexar da VM1 → Parar VM2 → Anexar → Iniciar VM2

<details>
<summary>Resposta</summary>

**B.** Parar VM1 (origem) → Desanexar disco → Anexar na VM2 (destino SEM parar) → Iniciar VM1.

Por que?
- VM origem PRECISA ser parada para garantir consistencia ao remover disco
- VM destino NAO precisa ser parada — disco de dados suporta hot-attach
- Isso garante minimo downtime (so VM1 sofre downtime temporario)

Opcao C esta errada porque parar ambas causa downtime desnecessario na VM2.
Opcao D esta errada porque voce nao pode desanexar de uma VM rodando.

</details>

### Q6

VMSS com multiplas instancias tem SLA de 99,95%? Traffic Manager tem SLA de 99,95%?

- A. VMSS = Sim, TM = Sim
- B. VMSS = Sim, TM = Nao
- C. VMSS = Nao, TM = Sim
- D. VMSS = Nao, TM = Nao

<details>
<summary>Resposta</summary>

**B.** VMSS com 2+ instancias = **99,95%** (mesmo nivel do Availability Set). Traffic Manager = **99,99%** (maior que 99,95%, portanto a resposta e NAO se a pergunta especifica "99,95%").

**Pegadinha classica:** Traffic Manager tem SLA MAIOR (99,99%), entao a afirmacao "tem SLA de 99,95%" e tecnicamente falsa — o SLA e superior.

Tabela rapida:
| Recurso | SLA |
|---------|-----|
| VMSS 2+ instancias | 99,95% |
| Traffic Manager | 99,99% |

</details>

---

## Resumo Final — Checklist de Estudo

```
OPERACOES DE VM:
[ ] Sei quais operacoes causam downtime (resize, NIC) e quais nao (disco, extensao)
[ ] Sei que o PRIMEIRO passo do resize e verificar tamanhos disponiveis
[ ] Sei a sequencia correta de transferir disco entre VMs

AVAILABILITY:
[ ] Sei a diferenca entre Availability Set (99,95%) e Zone (99,99%)
[ ] Sei calcular impacto de manutencao (UD) e falha de hardware (FD)
[ ] Sei que FD max = 3 e UD max = 20
[ ] Sei que VM so entra no Availability Set na CRIACAO

SLAs:
[ ] Decorei a tabela de SLAs (99,9% / 99,95% / 99,99%)
[ ] Sei que Traffic Manager = 99,99% (NAO 99,95%)
[ ] Sei que VMSS 2+ = 99,95% (igual Availability Set)
[ ] Sei que Spot VM = 0% SLA

METODOS:
[ ] Sei quando usar Portal vs CLI vs PowerShell vs ARM vs Bicep
[ ] Sei a diferenca entre CLI (1 comando) e PowerShell (pipeline Get→Update)
[ ] Sei fazer deploy de ARM/Bicep via CLI e PowerShell
```
