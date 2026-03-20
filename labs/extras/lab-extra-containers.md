# Lab Extra: Containers no Azure (ACI, AKS, Container Apps)

> **Objetivo:** Reforcar conceitos criticos sobre containers que caem na prova AZ-104.
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 45-60 min (teoria + CLI + questoes)

---

## Parte 1 — Azure Container Instances (ACI)

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| Storage mount | **Azure Files** (SMB). ACI **NAO suporta Blob Storage** como volume |
| Restart policy | `Always` (default), `OnFailure`, `Never` |
| Networking | IP publico OU deploy em VNet (privado) |
| OS | Linux e Windows (mas nao misturados no mesmo container group) |
| Container Group | Equivalente a um Pod do Kubernetes — containers compartilham lifecycle, rede e storage |

### Task 1.1 — Criar ACI com Azure Files

```bash
# Variaveis
RG="rg-lab-containers"
LOCATION="eastus"
SA_NAME="salabcontainers$(date +%s | tail -c 6)"
SHARE_NAME="acishare"

# Criar RG e Storage Account
az group create -n $RG -l $LOCATION
az storage account create -n $SA_NAME -g $RG -l $LOCATION --sku Standard_LRS
SA_KEY=$(az storage account keys list -n $SA_NAME -g $RG --query '[0].value' -o tsv)

# Criar File Share
az storage share create -n $SHARE_NAME --account-name $SA_NAME --account-key $SA_KEY

# Criar ACI com Azure Files montado
az container create \
  -g $RG \
  -n aci-demo \
  --image mcr.microsoft.com/azuredocs/aci-hellofiles \
  --ports 80 \
  --azure-file-volume-account-name $SA_NAME \
  --azure-file-volume-account-key $SA_KEY \
  --azure-file-volume-share-name $SHARE_NAME \
  --azure-file-volume-mount-path /aci/logs
```

### Task 1.2 — Verificar

```bash
# Ver status
az container show -g $RG -n aci-demo --query '{Status:instanceView.state, IP:ipAddress.ip}' -o table

# Ver logs
az container logs -g $RG -n aci-demo
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "ACI precisa de persistent storage. Qual servico usar?"
ERRADO: Blob Storage
CERTO:  Azure Files (SMB mount)

PERGUNTA: "ACI precisa de restart automatico em falha"
CERTO: --restart-policy OnFailure
```

---

## Parte 2 — Azure Kubernetes Service (AKS)

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| Cluster autoscaler | Escala **nodes**. Ferramentas: `az aks update` + `kubectl` |
| HPA | Horizontal Pod Autoscaler — escala **pods**. Ferramenta: `kubectl autoscale` |
| Escalar manualmente | `az vmss scale --new-capacity X` (VMSS do node pool) |
| Cluster privado | API server acessivel apenas via private endpoint (sem IP publico) |
| ACR integracao | `az aks update --attach-acr <acr-name>` |
| Networking | kubenet (basico) ou Azure CNI (pods recebem IP da VNet) |

### Task 2.1 — Autoscaler via CLI

```bash
# Habilitar cluster autoscaler no node pool
az aks update \
  -g $RG \
  -n aks-demo \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5

# HPA via kubectl
kubectl autoscale deployment nginx --cpu-percent=50 --min=2 --max=10
```

### Task 2.2 — Escalar VMSS manualmente

```bash
# Comando correto para escalar VMSS
az vmss scale \
  -g MC_rg-lab_aks-demo_eastus \
  -n aks-nodepool1-vmss \
  --new-capacity 4

# ERRADO: az vmss update --capacity 4 (nao existe)
# ERRADO: az vmss resize --count 4 (nao existe)
# ERRADO: az vmss set-capacity --value 4 (nao existe)
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Quais 2 ferramentas configuram cluster autoscaler no AKS?"
ERRADO: Portal do Azure, Set-AzVm
CERTO:  kubectl (HPA) + az aks update (node autoscaler)

PERGUNTA: "Escalar VMSS para 4 instancias"
CERTO: az vmss scale --new-capacity 4
```

---

## Parte 3 — Azure Container Apps

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| Modelo | Serverless containers (nao precisa gerenciar infra) |
| Escala | **Event-driven** (KEDA) — escala a zero! |
| Sidecar | Suporta sidecar containers (logging, proxy) |
| Ingress | HTTP ou TCP, com dominio personalizado e TLS |
| Revisoes | Versionamento de deployments (como slots do App Service) |
| Ambiente | Container Apps Environment = namespace logico compartilhado |

### Diferenca ACI vs Container Apps vs AKS

| Criterio | ACI | Container Apps | AKS |
|----------|-----|----------------|-----|
| Complexidade | Baixa | Media | Alta |
| Escala a zero | Nao | **Sim** | Nao (min 1 node) |
| Orquestracao | Nao | Sim (KEDA) | Sim (K8s completo) |
| Sidecar | Nao | **Sim** | Sim |
| Caso de uso | Tarefas simples, CI/CD | Microservicos event-driven | Controle total do K8s |
| Storage | Azure Files | Azure Files | Varios (PV/PVC) |
| Preco | Por segundo de execucao | Por consumo (vCPU/mem/req) | Por node (VM) |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Precisa de container que escala baseado em eventos e pode ir a zero"
ERRADO: ACI (nao escala), AKS (nao vai a zero)
CERTO:  Container Apps (KEDA, event-driven, scale-to-zero)

PERGUNTA: "Container com sidecar para logging"
ERRADO: ACI (nao suporta sidecar)
CERTO:  Container Apps ou AKS
```

---

## Parte 4 — Azure Container Registry (ACR)

### Conceitos-chave

| SKU | Storage | Webhooks | Geo-replication | Private Link |
|-----|---------|----------|-----------------|--------------|
| Basic | 10 GB | 2 | Nao | Nao |
| Standard | 100 GB | 10 | Nao | Nao |
| **Premium** | 500 GB | 500 | **Sim** | **Sim** |

```bash
# Criar ACR
az acr create -g $RG -n acrLabDemo --sku Standard

# Integrar com AKS
az aks update -g $RG -n aks-demo --attach-acr acrLabDemo

# Build no ACR (sem Docker local)
az acr build --registry acrLabDemo --image myapp:v1 .
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "ACR com geo-replication"
CERTO: SKU Premium (unico que suporta)

PERGUNTA: "ACR com Private Link"
CERTO: SKU Premium
```

---

## Parte 5 — Cleanup

```bash
az group delete -n $RG --yes --no-wait
```

---

## Questoes de Prova

### Q1
Voce precisa implantar um container no Azure que monta armazenamento persistente. O container acessa os dados via protocolo SMB. Qual servico de storage voce deve usar?

- A. Azure Blob Storage
- B. Azure Table Storage
- C. Azure Files
- D. Azure Data Lake Storage Gen2

<details>
<summary>Resposta</summary>

**C.** Azure Files. ACI monta volumes via Azure Files (SMB). Blob Storage NAO e suportado como volume mount em ACI.

</details>

### Q2
Voce tem um cluster AKS e precisa configurar o autoscaling de nodes. Quais duas ferramentas podem ser usadas?

- A. kubectl
- B. az aks
- C. Set-AzVm
- D. Portal do Azure

<details>
<summary>Resposta</summary>

**A, B.** `kubectl autoscale` para HPA (pods) e `az aks update --enable-cluster-autoscaler` para node autoscaler. Portal e Set-AzVm nao sao ferramentas primarias para isso.

</details>

### Q3
Voce precisa de uma solucao de container serverless que escala a zero baseado em eventos HTTP. Qual servico usar?

- A. Azure Container Instances
- B. Azure Kubernetes Service
- C. Azure Container Apps
- D. Azure App Service

<details>
<summary>Resposta</summary>

**C.** Container Apps usa KEDA para escala event-driven e pode escalar a zero. ACI nao escala automaticamente. AKS requer pelo menos 1 node.

</details>

### Q4
Qual SKU do Azure Container Registry suporta geo-replication?

- A. Basic
- B. Standard
- C. Premium
- D. Todas

<details>
<summary>Resposta</summary>

**C.** Apenas o SKU Premium suporta geo-replication e Private Link.

</details>

### Q5
Qual comando escala um VMSS para 4 instancias?

- A. az vmss update --capacity 4
- B. az vmss scale --new-capacity 4
- C. az vmss resize --count 4
- D. az vmss set-capacity --value 4

<details>
<summary>Resposta</summary>

**B.** `az vmss scale --new-capacity 4`. Os outros comandos nao existem.

</details>
