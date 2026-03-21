# Lab Extra: Containers no Azure (ACI, AKS, Container Apps, ACR)

> **Objetivo:** Reforcar conceitos criticos sobre containers que caem na prova AZ-104, praticando a criacao de recursos por multiplos metodos (Portal, CLI, PowerShell, ARM Template, Bicep).
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 90-120 min (teoria + pratica multi-metodo + questoes)
> **Pre-requisitos:** Assinatura Azure ativa, Azure CLI instalado, PowerShell com modulo Az instalado, acesso ao Portal.

---

## Preparacao do Ambiente

Antes de comecar, defina as variaveis que serao reutilizadas ao longo de todo o lab.

**Azure CLI:**

```bash
RG="rg-lab-containers"
LOCATION="eastus"
SA_NAME="salabcont$(date +%s | tail -c 6)"
SHARE_NAME="acishare"
```

**PowerShell:**

```powershell
$RG = "rg-lab-containers"
$Location = "eastus"
$SAName = "salabcont" + (Get-Date -Format "HHmmss")
$ShareName = "acishare"
```

**Criar o Resource Group (necessario para todos os metodos):**

```bash
# Azure CLI
az group create -n $RG -l $LOCATION
```

```powershell
# PowerShell
New-AzResourceGroup -Name $RG -Location $Location
```

> **Portal:** Portal > Resource Groups > + Create > Name: `rg-lab-containers`, Region: `East US` > Review + Create > Create.

---

## Parte 1 — Azure Container Instances (ACI)

### 1.1 Conceitos-chave

| Conceito        | Detalhe                                                                                |
| --------------- | -------------------------------------------------------------------------------------- |
| Storage mount   | **Azure Files** (SMB). ACI **NAO suporta Blob Storage** como volume                    |
| Restart policy  | `Always` (default), `OnFailure`, `Never`                                               |
| Networking      | IP publico OU deploy em VNet (privado)                                                 |
| OS              | Linux e Windows (mas nao misturados no mesmo container group)                          |
| Container Group | Equivalente a um Pod do Kubernetes — containers compartilham lifecycle, rede e storage |
| Billing         | Cobrado por **segundo** de execucao (vCPU + memoria)                                   |

### 1.2 Criar Storage Account e File Share

Antes de criar o ACI com volume, precisamos da Storage Account e do File Share.

#### Metodo 1 — Portal

1. Portal > **Storage accounts** > **+ Create**
2. Resource group: `rg-lab-containers`
3. Storage account name: (nome unico, ex: `salabcont123456`)
4. Region: `East US`
5. Redundancy: `LRS`
6. Review + Create > **Create**
7. Dentro da Storage Account criada > **Data storage** > **File shares** > **+ File share**
8. Name: `acishare` > **Create**

#### Metodo 2 — Azure CLI

```bash
# Criar Storage Account
az storage account create \
  -n $SA_NAME \
  -g $RG \
  -l $LOCATION \
  --sku Standard_LRS

# Obter chave da Storage Account
SA_KEY=$(az storage account keys list -n $SA_NAME -g $RG --query '[0].value' -o tsv)

# Criar File Share
az storage share create \
  -n $SHARE_NAME \
  --account-name $SA_NAME \
  --account-key $SA_KEY
```

#### Metodo 3 — PowerShell

```powershell
# Criar Storage Account
$SA = New-AzStorageAccount `
  -ResourceGroupName $RG `
  -Name $SAName `
  -Location $Location `
  -SkuName Standard_LRS

# Obter contexto (contem a chave)
$SACtx = $SA.Context

# Criar File Share
New-AzStorageShare -Name $ShareName -Context $SACtx
```

### 1.3 Criar ACI com Azure Files montado (TASK PRINCIPAL — 5 metodos)

> **Por que mostrar 5 metodos?** Na prova AZ-104, as questoes podem pedir que voce identifique o comando correto em CLI, PowerShell, ou interprete um ARM template. Saber todos os metodos ajuda a eliminar alternativas erradas.

#### Metodo 1 — Portal

1. Portal > **Container instances** > **+ Create**
2. **Basics:**
   - Resource group: `rg-lab-containers`
   - Container name: `aci-demo`
   - Region: `East US`
   - Image source: `Other registry`
   - Image: `mcr.microsoft.com/azuredocs/aci-hellofiles`
   - Size: 1 vCPU, 1.5 GiB (padrao)
3. **Networking:**
   - Networking type: `Public`
   - Ports: `80` (TCP)
4. **Advanced:**
   - Restart policy: `On failure`
   - Em **Volume mounts** > **Add volume:**
     - Name: `logs`
     - Volume type: `Azure file share`
     - Share name: `acishare`
     - Storage account name: (nome da SA criada)
     - Storage account key: (colar a key)
     - Mount path: `/aci/logs`
5. **Review + Create** > **Create**

> **Quando usar Portal:** Ideal para aprendizado, explorar opcoes disponiveis, ou criar recursos pontuais em ambientes de teste. Nao e recomendado para ambientes de producao (falta de reprodutibilidade).

#### Metodo 2 — Azure CLI

```bash
az container create \
  -g $RG \
  -n aci-demo-az-cli \
  --image mcr.microsoft.com/azuredocs/aci-hellofiles \
  --ports 80 \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --restart-policy OnFailure \
  --azure-file-volume-account-name $SA_NAME \
  --azure-file-volume-account-key $SA_KEY \
  --azure-file-volume-share-name $SHARE_NAME \
  --azure-file-volume-mount-path /aci/logs \
  --os-type Linux
```

> **Quando usar CLI:** Scripts de automacao rapidos, pipelines CI/CD em ambientes Linux/macOS, ou quando voce precisa de um one-liner. Sintaxe mais concisa que PowerShell.

#### Metodo 3 — PowerShell

```powershell
# Obter chave da Storage Account
$SAKey = (Get-AzStorageAccountKey -ResourceGroupName $RG -Name $SAName)[0].Value

# Criar credencial para volume
$SAKeySecure = ConvertTo-SecureString -String $SAKey -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($SAName, $SAKeySecure)

# Definir volume Azure Files
$Volume = New-AzContainerGroupVolumeObject `
  -Name "logs" `
  -AzureFileShareName $ShareName `
  -AzureFileStorageAccountName $SAName `
  -AzureFileStorageAccountKey $SAKeySecure

# Definir volume mount no container
$VolumeMount = New-AzContainerInstanceVolumeMountObject `
  -Name "logs" `
  -MountPath "/aci/logs"

# Definir o container
$Container = New-AzContainerInstanceObject `
  -Name "aci-demo" `
  -Image "mcr.microsoft.com/azuredocs/aci-hellofiles" `
  -RequestCpu 1 `
  -RequestMemoryInGb 1.5 `
  -Port @(New-AzContainerInstancePortObject -Port 80 -Protocol "TCP") `
  -VolumeMount @($VolumeMount)

# Criar o Container Group
New-AzContainerGroup `
  -ResourceGroupName $RG `
  -Name "aci-demo-powershell" `
  -Location $Location `
  -Container @($Container) `
  -Volume @($Volume) `
  -RestartPolicy "OnFailure" `
  -OSType "Linux" `
  -IPAddressType "Public" `
  -IPAddressPort @(New-AzContainerGroupPortObject -Port 80 -Protocol "TCP")
```

> **Quando usar PowerShell:** Automacao em ambientes Windows, scripts complexos com logica condicional, integracao com ferramentas Microsoft (Active Directory, Exchange). Sintaxe mais verbosa, porem mais explicita.

#### Metodo 4 — ARM Template

Crie um arquivo `aci-deploy.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageAccountName": {
      "type": "string",
      "metadata": {
        "description": "Nome da Storage Account existente"
      }
    },
    "storageAccountKey": {
      "type": "securestring",
      "metadata": {
        "description": "Chave da Storage Account"
      }
    },
    "fileShareName": {
      "type": "string",
      "defaultValue": "acishare"
    }
  },
  "resources": [
    {
      "type": "Microsoft.ContainerInstance/containerGroups",
      "apiVersion": "2023-05-01",
      "name": "aci-demo",
      "location": "[resourceGroup().location]",
      "properties": {
        "containers": [
          {
            "name": "aci-demo",
            "properties": {
              "image": "mcr.microsoft.com/azuredocs/aci-hellofiles",
              "ports": [
                {
                  "port": 80,
                  "protocol": "TCP"
                }
              ],
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGB": 1.5
                }
              },
              "volumeMounts": [
                {
                  "name": "filesharevolume",
                  "mountPath": "/aci/logs"
                }
              ]
            }
          }
        ],
        "osType": "Linux",
        "restartPolicy": "OnFailure",
        "ipAddress": {
          "type": "Public",
          "ports": [
            {
              "port": 80,
              "protocol": "TCP"
            }
          ]
        },
        "volumes": [
          {
            "name": "filesharevolume",
            "azureFile": {
              "shareName": "[parameters('fileShareName')]",
              "storageAccountName": "[parameters('storageAccountName')]",
              "storageAccountKey": "[parameters('storageAccountKey')]"
            }
          }
        ]
      }
    }
  ],
  "outputs": {
    "containerIPv4Address": {
      "type": "string",
      "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups', 'aci-demo')).ipAddress.ip]"
    }
  }
}
```

**Deploy do template:**

```bash
# Via Azure CLI
az deployment group create \
  -g $RG \
  --template-file aci-deploy.json \
  --parameters storageAccountName=$SA_NAME storageAccountKey=$SA_KEY
```

```powershell
# Via PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName $RG `
  -TemplateFile "aci-deploy.json" `
  -storageAccountName $SAName `
  -storageAccountKey $SAKey
```

> **Quando usar ARM Template:** Infraestrutura como codigo (IaC) em ambientes corporativos, quando voce precisa de deploys reprodutiveis e versionados. ARM templates sao o formato nativo do Azure — toda operacao no Portal gera um ARM template por baixo. Na prova, questoes podem pedir para interpretar ou completar trechos de ARM.

#### Metodo 5 — Bicep

Crie um arquivo `aci-deploy.bicep`:

```bicep
@description('Nome da Storage Account existente')
param storageAccountName string

@secure()
@description('Chave da Storage Account')
param storageAccountKey string

@description('Nome do File Share')
param fileShareName string = 'acishare'

resource aciDemo 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'aci-demo'
  location: resourceGroup().location
  properties: {
    containers: [
      {
        name: 'aci-demo'
        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-hellofiles'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('1.5')
            }
          }
          volumeMounts: [
            {
              name: 'filesharevolume'
              mountPath: '/aci/logs'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
    volumes: [
      {
        name: 'filesharevolume'
        azureFile: {
          shareName: fileShareName
          storageAccountName: storageAccountName
          storageAccountKey: storageAccountKey
        }
      }
    ]
  }
}

output containerIPv4Address string = aciDemo.properties.ipAddress.ip
```

**Deploy do template:**

```bash
# Via Azure CLI
az deployment group create \
  -g $RG \
  --template-file aci-deploy.bicep \
  --parameters storageAccountName=$SA_NAME storageAccountKey=$SA_KEY
```

```powershell
# Via PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName $RG `
  -TemplateFile "aci-deploy.bicep" `
  -storageAccountName $SAName `
  -storageAccountKey $SAKey
```

> **Quando usar Bicep:** Mesmos cenarios do ARM Template, porem com sintaxe muito mais limpa e legivel. Bicep e transpilado para ARM JSON no momento do deploy — ou seja, e a mesma engine, so a linguagem muda. Preferido para novos projetos de IaC no Azure.

### 1.4 Verificar o ACI

```bash
# Azure CLI — Ver status e IP
az container show -g $RG -n aci-demo \
  --query '{Status:instanceView.state, IP:ipAddress.ip}' -o table

# Azure CLI — Ver logs
az container logs -g $RG -n aci-demo
```

```powershell
# PowerShell — Ver status
$aci = Get-AzContainerGroup -ResourceGroupName $RG -Name "aci-demo"
$aci | Select-Object Name, ProvisioningState, @{N='IP';E={$_.IPAddressIP}}

# PowerShell — Ver logs
Get-AzContainerInstanceLog -ResourceGroupName $RG -ContainerGroupName "aci-demo" -ContainerName "aci-demo"
```

> **Portal:** Container instances > `aci-demo` > Overview (ver Status e IP). Para logs: menu lateral > Containers > selecionar container > aba **Logs**.

### PONTO CRITICO PARA PROVA — ACI

```
PERGUNTA: "ACI precisa de persistent storage. Qual servico usar?"
ERRADO:  Blob Storage
CERTO:   Azure Files (SMB mount)
POR QUE: ACI suporta APENAS Azure Files como volume mount. Blob Storage
         nao tem protocolo SMB compativel com mount de filesystem.

PERGUNTA: "ACI precisa de restart automatico em falha"
CERTO:   --restart-policy OnFailure
NOTA:    O default e "Always" — que reinicia inclusive apos sucesso.

PERGUNTA: "Preciso de containers que compartilhem rede e lifecycle"
CERTO:   Container Group (equivale ao Pod do Kubernetes)
```

---

## Parte 2 — Azure Kubernetes Service (AKS)

### 2.1 Conceitos-chave

| Conceito            | Detalhe                                                                      |
| ------------------- | ---------------------------------------------------------------------------- |
| Cluster autoscaler  | Escala **nodes** (VMs). Ferramentas: `az aks update` + `kubectl`             |
| HPA                 | Horizontal Pod Autoscaler — escala **pods**. Ferramenta: `kubectl autoscale` |
| Escalar manualmente | `az aks nodepool scale --node-count X` (ou `az aks scale` para default pool) |
| Cluster privado     | API server acessivel apenas via private endpoint (sem IP publico)            |
| ACR integracao      | `az aks update --attach-acr <acr-name>`                                      |
| Networking          | kubenet (basico) ou Azure CNI (pods recebem IP da VNet)                      |
| Node pools          | System pool (obrigatorio, componentes AKS) + User pool (cargas de trabalho)  |
| Managed identity    | AKS cria uma managed identity automaticamente para gerenciar recursos        |

### 2.2 Autoscaler via CLI

```bash
# Habilitar cluster autoscaler no node pool (escala NODES)
az aks update \
  -g $RG \
  -n aks-demo \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5

# HPA via kubectl (escala PODS)
kubectl autoscale deployment nginx --cpu-percent=50 --min=2 --max=10
```

```powershell
# PowerShell — Habilitar cluster autoscaler
Set-AzAksCluster `
  -ResourceGroupName $RG `
  -Name "aks-demo" `
  -EnableClusterAutoScaler `
  -MinCount 1 `
  -MaxCount 5
```

### 2.3 Escalar VMSS manualmente

```bash
# Comando CORRETO para escalar VMSS
az vmss scale \
  -g MC_rg-lab_aks-demo_eastus \
  -n aks-nodepool1-vmss \
  --new-capacity 4

# ERRADO: az vmss update --capacity 4    (nao existe)
# ERRADO: az vmss resize --count 4       (nao existe)
# ERRADO: az vmss set-capacity --value 4 (nao existe)
```

```powershell
# PowerShell — Escalar VMSS
Update-AzVmss `
  -ResourceGroupName "MC_rg-lab_aks-demo_eastus" `
  -VMScaleSetName "aks-nodepool1-vmss" `
  -SkuCapacity 4
```

### PONTO CRITICO PARA PROVA — AKS

```
PERGUNTA: "Quais 2 ferramentas configuram autoscaler no AKS?"
ERRADO:  Portal do Azure, Set-AzVm
CERTO:   kubectl (HPA para pods) + az aks update (cluster autoscaler para nodes)
NOTA:    Sao DUAS camadas de autoscaling — pods (HPA) e nodes (cluster autoscaler).

PERGUNTA: "Escalar VMSS para 4 instancias"
CERTO:   az vmss scale --new-capacity 4
ERRADO:  Qualquer variacao com update/resize/set-capacity — esses subcomandos
         nao existem com esses parametros.

PERGUNTA: "Cluster AKS privado — como acessar?"
CERTO:   Via private endpoint. API server NAO tem IP publico.
         Use VM na mesma VNet ou VPN/ExpressRoute.
```

---

## Parte 3 — Azure Container Registry (ACR)

### 3.1 Conceitos-chave — SKUs

| SKU         | Storage | Webhooks | Geo-replication | Private Link | Content Trust |
| ----------- | ------- | -------- | --------------- | ------------ | ------------- |
| Basic       | 10 GB   | 2        | Nao             | Nao          | Nao           |
| Standard    | 100 GB  | 10       | Nao             | Nao          | Nao           |
| **Premium** | 500 GB  | 500      | **Sim**         | **Sim**      | **Sim**       |

> **Memorizacao:** Tudo que e "enterprise-grade" (geo-replication, Private Link, Content Trust) exige **Premium**.

### 3.2 Criar ACR (3 metodos)

#### Metodo 1 — Portal

1. Portal > **Container registries** > **+ Create**
2. Resource group: `rg-lab-containers`
3. Registry name: `acrlabdemo` (nome unico global, so minusculas e numeros)
4. Location: `East US`
5. SKU: `Standard`
6. Review + Create > **Create**

#### Metodo 2 — Azure CLI

```bash
az acr create \
  -g $RG \
  -n acrlabdemo \
  --sku Standard
```

#### Metodo 3 — PowerShell

```powershell
New-AzContainerRegistry `
  -ResourceGroupName $RG `
  -Name "acrlabdemo" `
  -Sku "Standard" `
  -Location $Location
```

### 3.3 Integrar ACR com AKS

```bash
# Azure CLI — Vincular ACR ao AKS (AKS recebe permissao AcrPull)
az aks update -g $RG -n aks-demo --attach-acr acrlabdemo
```

```powershell
# PowerShell — Vincular ACR ao AKS
Set-AzAksCluster `
  -ResourceGroupName $RG `
  -Name "aks-demo" `
  -AcrNameToAttach "acrlabdemo"
```

### 3.4 Build de imagem no ACR (sem Docker local)

```bash
# Azure CLI — Build usando ACR Tasks (nao precisa Docker instalado!)
az acr build --registry acrlabdemo --image myapp:v1 .
```

> **Nota:** `az acr build` executa o build no proprio ACR. Voce so precisa do Dockerfile no diretorio atual. Util para pipelines CI/CD sem Docker daemon.

### PONTO CRITICO PARA PROVA — ACR

```
PERGUNTA: "ACR com geo-replication — qual SKU?"
CERTO:   Premium (unico que suporta)
ERRADO:  Standard ou Basic

PERGUNTA: "ACR com Private Link — qual SKU?"
CERTO:   Premium (unico que suporta)

PERGUNTA: "Build de imagem sem Docker local"
CERTO:   az acr build (ACR Tasks executa o build no servidor)

PERGUNTA: "Integrar ACR com AKS"
CERTO:   az aks update --attach-acr <acr-name>
NOTA:    Isso atribui a role AcrPull a managed identity do AKS.
```

---

## Parte 3B — Fluxo Completo: Projeto Local → ACR → Container Apps

> **Objetivo:** Praticar o fluxo real de trabalho com containers no Azure: construir uma imagem do seu projeto local, enviar ao ACR e deployar no Azure Container Apps. Use o seu proprio projeto!

### 3B.1 Pre-requisitos

```bash
# Variáveis (ajuste para seu ambiente)
RG="rg-lab-containers"
LOCATION="eastus"
ACR_NAME="acrlabdemo"     # nome unico global, so minusculas/numeros
CAE_NAME="cae-lab-demo"   # Container Apps Environment
CA_NAME="ca-meuapp"       # Nome do Container App
```

Seu projeto local deve ter um **Dockerfile** na raiz. Se nao tiver, crie um basico:

```dockerfile
# Exemplo para app Node.js
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### 3B.2 Criar ACR (se ainda nao existir)

```bash
# CLI
az acr create -g $RG -n $ACR_NAME --sku Standard
```

```powershell
# PowerShell
New-AzContainerRegistry -ResourceGroupName $RG -Name $ACR_NAME -Sku "Standard" -Location $LOCATION
```

### 3B.3 Build e Push da Imagem

#### Opcao A — Build remoto com ACR Tasks (recomendado, sem Docker local)

```bash
# Envia o contexto para o ACR e faz o build la
az acr build \
  --registry $ACR_NAME \
  --image meuapp:v1 \
  --file Dockerfile \
  .
```

> **Quando usar:** Nao tem Docker instalado, pipeline CI/CD, ou quer evitar build local. O ACR recebe os arquivos, executa o `docker build` no servidor e armazena a imagem.

#### Opcao B — Build local + Push manual (requer Docker instalado)

```bash
# 1. Login no ACR
az acr login --name $ACR_NAME

# 2. Build local
docker build -t $ACR_NAME.azurecr.io/meuapp:v1 .

# 3. Push para o ACR
docker push $ACR_NAME.azurecr.io/meuapp:v1
```

> **Quando usar:** Voce quer testar a imagem localmente antes de enviar (`docker run`), ou precisa de builds multi-stage complexos.

#### Verificar a imagem no ACR

```bash
# CLI — Listar repositorios
az acr repository list --name $ACR_NAME -o table

# CLI — Listar tags de uma imagem
az acr repository show-tags --name $ACR_NAME --repository meuapp -o table
```

```powershell
# PowerShell — Ver detalhes do registry
Get-AzContainerRegistry -ResourceGroupName $RG -Name $ACR_NAME
```

### 3B.4 Criar Container Apps Environment (se ainda nao existir)

O Environment e o namespace logico que agrupa Container Apps (compartilham VNet, logging, etc).

```bash
# CLI
az containerapp env create \
  -n $CAE_NAME \
  -g $RG \
  -l $LOCATION
```

```powershell
# PowerShell
New-AzContainerAppManagedEnv `
  -Name $CAE_NAME `
  -ResourceGroupName $RG `
  -Location $LOCATION
```

### 3B.5 Deploy no Container Apps usando imagem do ACR

#### Metodo 1 — CLI (mais simples)

```bash
# Criar Container App com imagem do ACR
# --registry-server usa o login server do ACR
az containerapp create \
  -n $CA_NAME \
  -g $RG \
  --environment $CAE_NAME \
  --image $ACR_NAME.azurecr.io/meuapp:v1 \
  --registry-server $ACR_NAME.azurecr.io \
  --target-port 3000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 3
```

> **Nota:** O `az containerapp create` com `--registry-server` do ACR configura automaticamente a managed identity com role AcrPull. Voce nao precisa passar usuario/senha.

#### Metodo 2 — CLI com credenciais explicitas

```bash
# Se precisar passar credenciais manualmente
ACR_PASSWORD=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)

az containerapp create \
  -n $CA_NAME \
  -g $RG \
  --environment $CAE_NAME \
  --image $ACR_NAME.azurecr.io/meuapp:v1 \
  --registry-server $ACR_NAME.azurecr.io \
  --registry-username $ACR_NAME \
  --registry-password $ACR_PASSWORD \
  --target-port 3000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 3
```

#### Metodo 3 — PowerShell

```powershell
# Obter ID do environment
$envId = (Get-AzContainerAppManagedEnv -ResourceGroupName $RG -Name $CAE_NAME).Id

# Obter credenciais do ACR
$acrCred = Get-AzContainerRegistryCredential -ResourceGroupName $RG -Name $ACR_NAME
$securePass = ConvertTo-SecureString $acrCred.Password -AsPlainText -Force

New-AzContainerApp `
  -Name $CA_NAME `
  -ResourceGroupName $RG `
  -ManagedEnvironmentId $envId `
  -Location $LOCATION `
  -IngressTargetPort 3000 `
  -IngressExternal `
  -RegistryServer "$ACR_NAME.azurecr.io" `
  -RegistryUserName $ACR_NAME `
  -RegistryPasswordSecretRef "acr-password" `
  -Secret @(@{Name="acr-password"; Value=$acrCred.Password}) `
  -TemplateContainer @(@{
    Name  = $CA_NAME
    Image = "$ACR_NAME.azurecr.io/meuapp:v1"
  }) `
  -ScaleMinReplica 0 `
  -ScaleMaxReplica 3
```

### 3B.6 Atualizar imagem (nova versao)

Fluxo de update: build nova versao → push → update do Container App:

```bash
# 1. Build nova versao
az acr build --registry $ACR_NAME --image meuapp:v2 .

# 2. Update do Container App para usar v2
az containerapp update \
  -n $CA_NAME \
  -g $RG \
  --image $ACR_NAME.azurecr.io/meuapp:v2
```

> **Conceito importante:** Cada update cria uma nova **revision** no Container Apps. Voce pode manter revisoes anteriores ativas para rollback ou traffic splitting (similar a deployment slots do App Service).

### 3B.7 Verificar e testar

```bash
# Ver URL do Container App
az containerapp show -n $CA_NAME -g $RG --query "properties.configuration.ingress.fqdn" -o tsv

# Ver logs do Container App
az containerapp logs show -n $CA_NAME -g $RG --type console

# Ver revisoes (historico de deploys)
az containerapp revision list -n $CA_NAME -g $RG -o table
```

### PONTO CRITICO PARA PROVA — Fluxo ACR → Container Apps

```
PERGUNTA: "Fazer build de imagem sem Docker instalado localmente"
CERTO:   az acr build (ACR Tasks faz o build no servidor)
ERRADO:  docker build (requer Docker local)

PERGUNTA: "Deploy de container app com imagem de registry privado"
CERTO:   --registry-server + credenciais OU managed identity com AcrPull
ERRADO:  Imagem publica nao precisa de registry-server

PERGUNTA: "Atualizar imagem de um Container App existente"
CERTO:   az containerapp update --image <nova-imagem>
NOTA:    Cria nova revision automaticamente

PERGUNTA: "Container Apps vs ACI para imagem do ACR"
- ACA: managed identity ou credenciais, suporta update/revisions
- ACI: --registry-login-server + --registry-username + --registry-password
```

---

## Parte 4 — Azure Container Apps

### 4.1 Conceitos-chave

| Conceito | Detalhe                                                     |
| -------- | ----------------------------------------------------------- |
| Modelo   | Serverless containers (nao precisa gerenciar infra)         |
| Escala   | **Event-driven** (KEDA) — escala a zero!                    |
| Sidecar  | Suporta sidecar containers (logging, proxy, etc.)           |
| Ingress  | HTTP ou TCP, com dominio personalizado e TLS                |
| Revisoes | Versionamento de deployments (como slots do App Service)    |
| Ambiente | Container Apps Environment = namespace logico compartilhado |
| Dapr     | Integracao nativa com Dapr para microservicos               |

### 4.2 Criar Container App (CLI e PowerShell)

```bash
# Azure CLI — Criar ambiente e container app
az containerapp env create \
  -n cae-lab-demo \
  -g $RG \
  -l $LOCATION

az containerapp create \
  -n ca-demo \
  -g $RG \
  --environment cae-lab-demo \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 80 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 5
```

```powershell
# PowerShell — Criar ambiente e container app
New-AzContainerAppManagedEnv `
  -Name "cae-lab-demo" `
  -ResourceGroupName $RG `
  -Location $Location

New-AzContainerApp `
  -Name "ca-demo" `
  -ResourceGroupName $RG `
  -ManagedEnvironmentId (Get-AzContainerAppManagedEnv -ResourceGroupName $RG -Name "cae-lab-demo").Id `
  -Location $Location `
  -IngressTargetPort 80 `
  -IngressExternal `
  -TemplateContainer @(@{
    Name  = "ca-demo"
    Image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
  }) `
  -ScaleMinReplica 0 `
  -ScaleMaxReplica 5
```

### 4.3 Diferenca ACI vs Container Apps vs AKS

| Criterio      | ACI                                   | Container Apps                   | AKS                        |
| ------------- | ------------------------------------- | -------------------------------- | -------------------------- |
| Complexidade  | Baixa                                 | Media                            | Alta                       |
| Escala a zero | **Nao**                               | **Sim**                          | Nao (min 1 node)           |
| Orquestracao  | Nao                                   | Sim (KEDA)                       | Sim (K8s completo)         |
| Sidecar       | **Nao**                               | **Sim**                          | Sim                        |
| Event-driven  | Nao                                   | **Sim**                          | Via config adicional       |
| Caso de uso   | Tarefas simples, batch, CI/CD runners | Microservicos event-driven, APIs | Controle total do K8s      |
| Storage       | Azure Files                           | Azure Files, volumes             | Varios (PV/PVC)            |
| Preco         | Por segundo (vCPU/mem)                | Por consumo (vCPU/mem/req)       | Por node (VM fixa)         |
| Gerenciamento | Nenhum                                | Plataforma gerenciada            | Voce gerencia pods/deploys |

> **Regra rapida para a prova:**
> - Precisa de algo simples e rapido? **ACI**
> - Precisa de escala event-driven ou scale-to-zero? **Container Apps**
> - Precisa de controle total do Kubernetes? **AKS**

### PONTO CRITICO PARA PROVA — Container Apps

```
PERGUNTA: "Precisa de container que escala baseado em eventos e pode ir a zero"
ERRADO:  ACI (nao escala automaticamente), AKS (nao vai a zero, min 1 node)
CERTO:   Container Apps (KEDA, event-driven, scale-to-zero)

PERGUNTA: "Container com sidecar para logging"
ERRADO:  ACI (nao suporta sidecar)
CERTO:   Container Apps ou AKS (ambos suportam sidecar)

PERGUNTA: "Microservico que reage a mensagens de fila (Queue)"
CERTO:   Container Apps (KEDA escala baseado em queue length)
         Tambem aceita: AKS com KEDA instalado manualmente
```

---

## Parte 5 — Comparacao de Metodos de Criacao

### Quando usar cada metodo?

| Metodo           | Velocidade         | Reprodutibilidade | Curva de Aprendizado | Melhor Para                                     |
| ---------------- | ------------------ | ----------------- | -------------------- | ----------------------------------------------- |
| **Portal**       | Rapido (1 recurso) | Baixa (manual)    | Facil                | Aprendizado, exploracao, testes rapidos         |
| **Azure CLI**    | Rapido             | Media (scripts)   | Media                | Automacao em Linux/macOS, pipelines, one-liners |
| **PowerShell**   | Medio              | Media (scripts)   | Media                | Automacao Windows, integracao com AD/Exchange   |
| **ARM Template** | Lento (setup)      | **Alta** (IaC)    | Alta                 | Producao, governanca, deploys corporativos      |
| **Bicep**        | Medio (setup)      | **Alta** (IaC)    | Media                | IaC moderno no Azure, alternativa limpa ao ARM  |

### Comparacao detalhada

#### Portal
- **Vantagem:** Visual, intuitivo, mostra todas as opcoes disponiveis
- **Desvantagem:** Nao e reprodutivel, sujeito a erro humano
- **Na prova:** Questoes raramente pedem "como fazer via Portal" — mas o Portal ajuda a entender as opcoes existentes

#### Azure CLI (`az`)
- **Vantagem:** Conciso, funciona em qualquer terminal, otimo para Cloud Shell
- **Desvantagem:** Sintaxe propria (nao e Bash nem PowerShell)
- **Na prova:** MUITO cobrado! Saber os comandos `az container create`, `az aks update`, `az vmss scale`, `az acr build`

#### PowerShell (`New-Az*`, `Set-Az*`)
- **Vantagem:** Linguagem completa (loops, condicionais), objetos ricos
- **Desvantagem:** Verboso, requer modulo Az instalado
- **Na prova:** Cobrado principalmente em cenarios de automacao e scripts

#### ARM Template (JSON)
- **Vantagem:** Formato nativo do Azure, deploy "what-if", completo
- **Desvantagem:** JSON verboso, dificil de ler/manter
- **Na prova:** Questoes pedem para interpretar trechos, identificar erros, ou completar parametros. **Atencao ao `--parameters` inline vs arquivo!**

#### Bicep
- **Vantagem:** Sintaxe limpa, type-safe, transpila para ARM
- **Desvantagem:** Ferramenta relativamente nova, menos documentacao legada
- **Na prova:** Aparece cada vez mais. Saiba que Bicep = ARM por baixo, mesma engine.

### Mapeamento CLI ↔ PowerShell (mais cobrados)

| Acao           | Azure CLI                                   | PowerShell                                  |
| -------------- | ------------------------------------------- | ------------------------------------------- |
| Criar ACI      | `az container create`                       | `New-AzContainerGroup`                      |
| Ver ACI        | `az container show`                         | `Get-AzContainerGroup`                      |
| Logs ACI       | `az container logs`                         | `Get-AzContainerInstanceLog`                |
| Criar AKS      | `az aks create`                             | `New-AzAksCluster`                          |
| Autoscaler AKS | `az aks update --enable-cluster-autoscaler` | `Set-AzAksCluster -EnableClusterAutoScaler` |
| Escalar VMSS   | `az vmss scale --new-capacity X`            | `Update-AzVmss -SkuCapacity X`              |
| Criar ACR      | `az acr create`                             | `New-AzContainerRegistry`                   |
| Build ACR      | `az acr build`                              | (sem equivalente direto)                    |
| Deploy ARM     | `az deployment group create`                | `New-AzResourceGroupDeployment`             |

---

## Parte 6 — Cleanup

```bash
# Azure CLI
az group delete -n $RG --yes --no-wait
```

```powershell
# PowerShell
Remove-AzResourceGroup -Name $RG -Force -AsJob
```

> **Portal:** Resource Groups > `rg-lab-containers` > Delete resource group > digitar o nome para confirmar > Delete.

---

## Questoes de Prova

### Q1 — ACI + Storage

Voce precisa implantar um container no Azure Container Instances que monta armazenamento persistente. O container acessa os dados via protocolo SMB. Qual servico de storage voce deve usar?

- A. Azure Blob Storage
- B. Azure Table Storage
- C. Azure Files
- D. Azure Data Lake Storage Gen2

<details>
<summary>Resposta</summary>

**C.** Azure Files. ACI monta volumes exclusivamente via Azure Files (protocolo SMB). Blob Storage **NAO** e suportado como volume mount em ACI — este e um erro recorrente nos simulados.

**Por que as outras estao erradas:**
- **A (Blob Storage):** Nao suporta mount como filesystem em ACI
- **B (Table Storage):** Servico de NoSQL, nao serve para mount de volume
- **D (Data Lake Gen2):** Storage analitico, nao suportado como volume em ACI

</details>

### Q2 — AKS Autoscaler

Voce tem um cluster AKS e precisa configurar o autoscaling de nodes. Quais duas ferramentas podem ser usadas? (Selecione duas.)

- A. kubectl
- B. az aks
- C. Set-AzVm
- D. Portal do Azure

<details>
<summary>Resposta</summary>

**A, B.** Existem duas camadas de autoscaling no AKS:
- `kubectl autoscale` configura o **HPA** (Horizontal Pod Autoscaler) — escala **pods**
- `az aks update --enable-cluster-autoscaler` configura o **cluster autoscaler** — escala **nodes**

**Por que as outras estao erradas:**
- **C (Set-AzVm):** Gerencia VMs individuais, nao VMSS de node pools
- **D (Portal):** Nao e a ferramenta primaria para configurar autoscaler no AKS

</details>

### Q3 — Container Apps vs ACI vs AKS

Voce precisa de uma solucao de container serverless que escala a zero baseado em eventos HTTP. Qual servico usar?

- A. Azure Container Instances
- B. Azure Kubernetes Service
- C. Azure Container Apps
- D. Azure App Service

<details>
<summary>Resposta</summary>

**C.** Azure Container Apps usa KEDA para escala event-driven e pode **escalar a zero** (zero replicas quando nao ha trafico).

**Por que as outras estao erradas:**
- **A (ACI):** Nao tem autoscaling nativo — voce cria/destroi manualmente
- **B (AKS):** Requer pelo menos 1 node rodando (nao escala a zero nos nodes)
- **D (App Service):** Nao e container-native; nao escala a zero (exceto Functions no Consumption plan, mas isso nao e App Service padrao)

</details>

### Q4 — ACR SKU

Voce precisa de um Azure Container Registry com geo-replication para atender usuarios em multiplas regioes. Qual SKU voce deve escolher?

- A. Basic
- B. Standard
- C. Premium
- D. Todas as SKUs suportam geo-replication

<details>
<summary>Resposta</summary>

**C.** Apenas o SKU **Premium** suporta geo-replication, Private Link e Content Trust.

**Dica de prova:** Sempre que a questao mencionar geo-replication ou Private Link para ACR, a resposta e Premium.

</details>

### Q5 — VMSS Scale

Voce administra um AKS cluster e precisa escalar manualmente o Virtual Machine Scale Set (VMSS) do node pool para 4 instancias. Qual comando voce deve usar?

- A. `az vmss update --capacity 4`
- B. `az vmss scale --new-capacity 4`
- C. `az vmss resize --count 4`
- D. `az vmss set-capacity --value 4`

<details>
<summary>Resposta</summary>

**B.** `az vmss scale --new-capacity 4` e o unico comando correto. Os outros subcomandos/parametros **nao existem** na CLI do Azure.

**Dica de prova:** Quando a questao oferecer multiplos comandos `az vmss`, o correto e sempre `scale` com `--new-capacity`. As outras opcoes sao distratores inventados.

</details>

---

## Resumo dos Pontos Criticos

| #   | Topico                 | O que lembrar                             | Erro comum                                        |
| --- | ---------------------- | ----------------------------------------- | ------------------------------------------------- |
| 1   | ACI + Storage          | **Azure Files** (SMB)                     | Escolher Blob Storage                             |
| 2   | ACI Restart            | `--restart-policy OnFailure`              | Esquecer que default e `Always`                   |
| 3   | AKS Autoscaler         | `kubectl` (HPA) + `az aks update` (nodes) | Achar que e via Portal ou Set-AzVm                |
| 4   | VMSS Scale             | `az vmss scale --new-capacity X`          | Inventar comandos como `resize` ou `set-capacity` |
| 5   | Container Apps         | Event-driven, KEDA, **scale-to-zero**     | Confundir com ACI (nao escala)                    |
| 6   | Container Apps Sidecar | Suporta sidecar                           | Achar que ACI suporta sidecar                     |
| 7   | ACR Premium            | Geo-replication + Private Link            | Achar que Standard basta                          |
| 8   | ACR + AKS              | `az aks update --attach-acr`              | Nao saber o comando                               |
| 9   | ARM --parameters       | `--parameters param=value` (inline)       | Confundir sintaxe inline com arquivo              |
| 10  | Bicep                  | Transpila para ARM, mesma engine          | Achar que Bicep e algo separado do ARM            |
