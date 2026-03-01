# Lab Unificado AZ-104 - Semana 2 (v2: Exercicios Interconectados)

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)
>
> **Semana 1 concluida:** Os recursos de identidade, governanca e rede (labs iam-gov-net) devem ter sido provisionados ou voce deve conhecer os conceitos

---

## Cenario Corporativo

Voce continua como **Azure Administrator** da Contoso Corp. Na semana anterior, voce configurou identidade, governanca e rede. Agora precisa provisionar armazenamento para dados corporativos e implantar cargas de trabalho de computacao nos ambientes de rede ja existentes:

1. **Storage** — criar contas de armazenamento, blobs, file shares e configurar seguranca de rede (service endpoints e private endpoints) usando as VNets da Semana 1
2. **Virtual Machines** — implantar VMs Windows e Linux nas VNets existentes, gerenciar discos e configurar VMSS
3. **Web Apps** — criar App Services com deployment slots, conectando a storage para configuracoes
4. **Azure Container Instances (ACI)** — executar containers com montagem de file shares criados no Bloco 1
5. **Azure Container Apps** — orquestrar containers em ambiente gerenciado integrado a rede existente

Ao final, voce tera **um ambiente corporativo completo** onde armazenamento, computacao, web apps e containers estao integrados entre si e com a infraestrutura de identidade e rede da Semana 1.

---

## Mapa de Dependencias

```
iam-gov-net (Semana 1)
  │
  ├─ VNets (CoreServicesVnet, ManufacturingVnet) ─────────┐
  ├─ NSGs, DNS zones ────────────────────────────────────┤
  ├─ RBAC, Policies ──────────────────────────────────────┤
  └─ Users, Groups ───────────────────────────────────────┤
                                                          │
                                                          ▼
Bloco 1 (Storage)
  │
  ├─ Storage Account (contosostore*) ──────┐
  ├─ Blob Container ───────────────────────┤
  ├─ File Share (contoso-files) ───────────┤
  ├─ Private Endpoint (na VNet) ───────────┤
  └─ Service Endpoint ─────────────────────┤
                                           │
                                           ▼
Bloco 2 (VMs) ◄──── Usa VNets + Storage
  │
  ├─ Windows VM ───────────────────────────┐
  ├─ Linux VM ─────────────────────────────┤
  ├─ VMSS ─────────────────────────────────┤
  └─ Data Disks ───────────────────────────┤
                                           │
                                           ▼
Bloco 3 (Web Apps) ◄──── Usa Storage (Connection Strings)
  │
  └─ App Service + Slots ──────────────────┤
                                           │
                                           ▼
Bloco 4 (ACI) ◄──── Usa File Share do Bloco 1
  │
  └─ Container Instances ──────────────────┤
                                           │
                                           ▼
Bloco 5 (Container Apps) ◄──── Usa VNet + contexto anterior
```

---

## Indice

| Bloco | Descricao | Link |
|-------|-----------|------|
| 1 | Azure Storage | [cenario/bloco1-storage.md](cenario/bloco1-storage.md) |
| 2 | Virtual Machines | [cenario/bloco2-vms.md](cenario/bloco2-vms.md) |
| 3 | Azure Web Apps | [cenario/bloco3-webapps.md](cenario/bloco3-webapps.md) |
| 4 | Azure Container Instances | [cenario/bloco4-aci.md](cenario/bloco4-aci.md) |
| 5 | Azure Container Apps | [cenario/bloco5-container-apps.md](cenario/bloco5-container-apps.md) |

- [Pausar entre Sessoes](#pausar-entre-sessoes)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

## Pausar (parar cobranca de compute)

```bash
# CLI — VMs
az vm deallocate -g az104-rg7 -n az104-vm-win --no-wait
az vm deallocate -g az104-rg7 -n az104-vm-linux --no-wait

# CLI — VMSS (escalar para 0)
az vmss scale -g az104-rg7 -n az104-vmss --new-capacity 0

# CLI — ACI
az container stop -g az104-rg9 -n az104-container-1
az container stop -g az104-rg9 -n az104-container-2
```

```powershell
# PowerShell — VMs
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-win -Force
Stop-AzVM -ResourceGroupName az104-rg7 -Name az104-vm-linux -Force

# PowerShell — ACI
Stop-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-1
Stop-AzContainerGroup -ResourceGroupName az104-rg9 -Name az104-container-2
```

## Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg7 -n az104-vm-win --no-wait
az vm start -g az104-rg7 -n az104-vm-linux --no-wait
az vmss scale -g az104-rg7 -n az104-vmss --new-capacity 1
az container start -g az104-rg9 -n az104-container-1
az container start -g az104-rg9 -n az104-container-2
```

> **Nota:** Desalocar VMs para cobranca de compute, mas discos e IPs publicos continuam cobrando. O App Service Plan (Standard S1) cobra enquanto existir — para parar, delete o plano ou rebaixe para Free F1. Container Apps com scale-to-zero nao geram custo quando ociosas.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente VMs (Bloco 2), Container Apps (Bloco 5) e App Service (Bloco 3).

## Via Azure Portal

1. **Deletar Resource Groups** (prioridade por custo):
   - `az104-rg7` (VMs e VMSS — PRIORIDADE por custo)
   - `az104-rg10` (Container Apps Environment)
   - `az104-rg8` (App Service Plan e Web App)
   - `az104-rg9` (Container Instances)
   - `az104-rg6` (Storage Account, Private Endpoint)

2. **Verificar Private DNS Zones:**
   - Se a zona `privatelink.blob.core.windows.net` foi criada automaticamente no Bloco 1, verifique se ela foi removida com o RG

3. **Verificar recursos orfaos:**
   - Pesquise **All resources** e filtre por `az104` para garantir que nao restam recursos

## Via CLI

```bash
# 1. Deletar RGs (VMs e compute primeiro por custo)
az group delete --name az104-rg7 --yes --no-wait
az group delete --name az104-rg10 --yes --no-wait
az group delete --name az104-rg8 --yes --no-wait
az group delete --name az104-rg9 --yes --no-wait
az group delete --name az104-rg6 --yes --no-wait

# 2. Verificar se todos os recursos foram removidos
az resource list --query "[?contains(name, 'az104')]" -o table
```

## Via PowerShell

```powershell
# 1. Deletar RGs
Remove-AzResourceGroup -Name az104-rg7 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg10 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg8 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg9 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg6 -Force -AsJob

# 2. Verificar recursos remanescentes
Get-AzResource | Where-Object { $_.Name -like "*az104*" } | Format-Table Name, ResourceGroupName, ResourceType
```

> **Nota:** A exclusao dos RGs pode levar varios minutos. Verifique em **Notifications** (sino) no portal ou use `az group list --query "[?contains(name, 'az104')]" -o table`.

---

# Key Takeaways Consolidados

## Bloco 1 - Azure Storage
- **Storage Account** fornece namespace unico com endpoints para Blob, File, Queue e Table
- **Access Tiers**: Hot (frequente), Cool (infrequente, 30d), Cold (raro, 90d), Archive (rarissimo, 180d, rehydrate lento)
- **SAS Tokens** concedem acesso granular; **Stored Access Policies** permitem revogacao centralizada
- **Service Endpoint** = rota otimizada (IP publico mantido); **Private Endpoint** = IP privado na VNet
- **Lifecycle Management** automatiza transicao entre tiers; **Immutability** (WORM) garante compliance
- **Soft Delete** protege contra exclusao acidental (blobs, containers, file shares)

## Bloco 2 - Virtual Machines
- VMs podem usar VNets de **outros Resource Groups** (cross-RG deployment)
- **Data Disks** suportam hot-attach em VMs running; **OS Disk** requer stop/deallocate para swap
- **Azure Files** pode ser montado como drive de rede em VMs Windows (SMB) e Linux (NFS/SMB)
- **VMSS** permite auto-scaling com regras baseadas em metricas (CPU, memoria, custom)
- **VM Families**: B=burstable, D=general purpose, E=memory optimized, F=compute optimized, N=GPU
- **Run Command** permite troubleshooting sem RDP/SSH, executado via VM Agent

## Bloco 3 - Azure Web Apps
- **App Service Plan** define recursos de compute; multiplas apps compartilham o mesmo plan
- **Deployment Slots** requerem Standard S1 ou superior; slots permitem zero-downtime deploys
- **Slot settings** marcados como "deployment slot setting" sao **sticky** (nao sao swapped)
- **Auto-scaling** opera no nivel do App Service Plan, nao da Web App individual
- **Connection Strings** podem referenciar Storage Accounts para integracao entre servicos
- **VNet Integration** permite que Web Apps acessem recursos com Private Endpoints

## Bloco 4 - Azure Container Instances
- ACI e a forma **mais simples** de executar containers no Azure (sem orquestracao)
- **Volume mount** com Azure File Share permite persistencia de dados entre containers
- **Restart policies**: Always (servico), OnFailure (retry), Never (batch job)
- Containers **Stopped** nao geram custo de compute (cobrado por segundo quando Running)
- **File shares** podem ser compartilhados entre VMs e containers (plataformas diferentes, mesmos dados)

## Bloco 5 - Azure Container Apps
- Container Apps oferece **serverless containers** com auto-scaling, HTTPS automatico e revisoes
- **Scale-to-zero** (min replicas = 0) elimina custos quando nao ha trafego
- **Revisoes** permitem canary/blue-green deployments com traffic split granular
- **Environment** requer subnet dedicada **/23** para VNet integration
- **Secrets** armazenam credenciais de forma segura (prefira a hardcoded env vars)
- Compre: ACI = simples; Container Apps = serverless com orquestracao; AKS = Kubernetes completo

## Integracao Geral
- **Storage (Bloco 1)** e a base de dados para todos os servicos de compute
- **File Shares** sao compartilhados entre VMs (drive Z:) e containers (volume mount) — mesmos dados, plataformas diferentes
- **Connection Strings** conectam Web Apps e Container Apps ao Storage Account
- **VNets da Semana 1** sao reutilizadas: VMs em subnets existentes, Private Endpoints, Container Apps Environment
- **Evolucao de compute**: VMs (IaaS) → Web Apps (PaaS) → ACI (containers simples) → Container Apps (serverless containers)
- **Cada bloco constroi sobre o anterior**: storage → VMs usam storage → Web Apps referenciam storage → ACI monta file shares → Container Apps integra tudo