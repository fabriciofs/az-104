# Lab Extra: VM Operations, Availability e SLAs

> **Objetivo:** Reforcar operacoes de VM (downtime, resize, disco), Availability Sets/Zones e SLAs.
> **Independente:** Nao depende de nenhum outro lab.
> **Tempo estimado:** 45-60 min (teoria + CLI + questoes)

---

## Parte 1 — Operacoes que causam Downtime

### Tabela critica para a prova

| Operacao | Requer VM parada? | Downtime? |
|----------|:-----------------:|:---------:|
| Redimensionar (resize) | **Sim** | **Sim** |
| Adicionar NIC | **Sim** | **Sim** |
| Adicionar disco de dados | Nao | Nao |
| Instalar extensao | Nao | Nao |
| Alterar NSG | Nao | Nao |
| Alterar tags | Nao | Nao |
| Capturar imagem | **Sim** (generalizar) | **Sim** |
| Mover para outro RG | Nao | Nao |

### Task 1.1 — Redimensionar VM (primeiro passo)

```bash
RG="rg-lab-vm-avail"
LOCATION="eastus"
VM_NAME="vm-demo"

az group create -n $RG -l $LOCATION

# Criar VM
az vm create -g $RG -n $VM_NAME \
  --image Ubuntu2204 --size Standard_B1s \
  --admin-username azureuser --generate-ssh-keys

# PRIMEIRO PASSO: verificar tamanhos disponiveis no cluster atual
az vm list-vm-resize-options -g $RG -n $VM_NAME -o table

# Se o tamanho desejado estiver na lista: resize SEM desalocar
az vm resize -g $RG -n $VM_NAME --size Standard_B2s

# Se NAO estiver: precisa desalocar primeiro
az vm deallocate -g $RG -n $VM_NAME
az vm resize -g $RG -n $VM_NAME --size Standard_D2s_v3
az vm start -g $RG -n $VM_NAME
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Primeiro passo para redimensionar VM via CLI?"
ERRADO: Desalocar a VM
CERTO:  Verificar tamanhos disponiveis no cluster (az vm list-vm-resize-options)
        So desalocar se o tamanho desejado NAO estiver disponivel
```

### Task 1.2 — Adicionar disco (sem downtime)

```bash
# Adicionar disco de dados COM a VM rodando
az vm disk attach -g $RG --vm-name $VM_NAME \
  --name disk-data-01 --size-gb 64 --sku Standard_LRS --new
```

### Task 1.3 — Transferir disco entre VMs

```bash
# Sequencia CORRETA (4 passos):
# 1. Parar VM de origem
az vm stop -g $RG -n vm-origin
az vm deallocate -g $RG -n vm-origin

# 2. Desanexar disco da origem
az vm disk detach -g $RG --vm-name vm-origin -n disk-data-01

# 3. Anexar disco no destino (SEM parar a VM destino!)
az vm disk attach -g $RG --vm-name vm-dest -n disk-data-01

# 4. Reiniciar VM de origem
az vm start -g $RG -n vm-origin
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "Transferir disco de VM1 para VM2 com minimo downtime. Ordem?"
ERRADO: Iniciar VM1, Iniciar VM2, desanexar, anexar
CERTO:  Parar VM1 → Desanexar → Anexar na VM2 (sem parar VM2) → Iniciar VM1

VM destino NAO precisa ser parada para RECEBER disco.
VM origem PRECISA ser parada para REMOVER disco (consistencia).
```

---

## Parte 2 — Availability Sets vs Availability Zones

### Comparacao

| Criterio | Availability Set | Availability Zone |
|----------|:----------------:|:-----------------:|
| Protege contra | Falha de hardware (rack) | Falha de datacenter inteiro |
| Fault Domains (FD) | 2 ou 3 (max **3**) | 1 por zona (isolamento fisico) |
| Update Domains (UD) | 2 a **20** (max 20) | N/A (zonas sao independentes) |
| SLA | **99,95%** | **99,99%** |
| Requer Managed Disks? | Sim (para SLA completo) | Sim |
| Escopo | Dentro de 1 datacenter | Entre datacenters na mesma regiao |

### Task 2.1 — Criar Availability Set

```bash
# Availability Set com 3 FDs e 5 UDs
az vm availability-set create \
  -g $RG -n avset-demo \
  --platform-fault-domain-count 3 \
  --platform-update-domain-count 5

# Criar VM no Availability Set
az vm create -g $RG -n vm-avset-01 \
  --image Ubuntu2204 --size Standard_B1s \
  --availability-set avset-demo \
  --admin-username azureuser --generate-ssh-keys
```

### Task 2.2 — Criar VM em Availability Zone

```bash
# VM na Zona 1
az vm create -g $RG -n vm-zone-01 \
  --image Ubuntu2204 --size Standard_B1s \
  --zone 1 \
  --admin-username azureuser --generate-ssh-keys
```

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "5 VMs em Availability Set com 2 FDs e 5 UDs. Manutencao planejada.
           Quantas VMs ficam indisponiveis ao mesmo tempo?"
RESPOSTA: 1 VM (5 VMs / 5 UDs = 1 por UD. Manutencao atualiza 1 UD por vez)

PERGUNTA: "5 VMs em Availability Set com 2 FDs e 5 UDs. Falha de hardware em 1 rack."
RESPOSTA: Ate 3 VMs (ceil(5/2) = 3 no pior FD, 2 no outro)

REGRA:
- Manutencao planejada → Update Domains (UD)
- Falha de hardware → Fault Domains (FD)
- platformUpdateDomainCount maximo = 20
- platformFaultDomainCount maximo = 3
```

---

## Parte 3 — SLAs de Disponibilidade

### Tabela de SLAs

| Configuracao | SLA |
|-------------|-----|
| VM unica com Premium SSD | 99,9% |
| VM unica com Ultra Disk | 99,95% |
| Availability Set + Managed Disks | **99,95%** |
| VMSS com multiplas instancias | **99,95%** |
| Availability Zones (2+ VMs) | **99,99%** |
| Traffic Manager | **99,99%** |
| Azure Front Door | **99,99%** |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "SLA de 99,95% para VMs. Quais 2 recursos?"
CERTO: Managed Disks + Availability Sets

PERGUNTA: "VMSS com multiplas VMs tem SLA de 99,95%?"
CERTO: SIM (mesmo nivel que Availability Set)

PERGUNTA: "Traffic Manager tem SLA de 99,95%?"
ERRADO: NAO — Traffic Manager = 99,99% (MAIOR, nao menor)

PERGUNTA: "Availability Zones vs Set?"
Zone = 99,99% (entre datacenters)
Set  = 99,95% (dentro de 1 datacenter)
```

---

## Parte 4 — Spot VMs

### Conceitos-chave

| Conceito | Detalhe |
|----------|---------|
| O que e | VM com desconto (ate 90%) usando capacidade nao utilizada |
| Eviction | Azure pode tomar a VM a qualquer momento |
| Eviction policy | **Deallocate** (default) ou **Delete** |
| Eviction type | Capacity-based ou Price-based (max price) |
| SLA | **Nenhum** (0% — sem garantia) |
| Uso ideal | Workloads tolerantes a interrupcao (batch, dev/test, CI/CD) |

### PONTO CRITICO PARA PROVA

```
PERGUNTA: "VM com menor custo para workload que tolera interrupcao"
CERTO: Spot VM (ate 90% desconto)

PERGUNTA: "Spot VM eviction policy para preservar disco e IP"
CERTO: Deallocate (mantem disco e config, so desaloca)
ERRADO: Delete (destroi tudo)
```

---

## Parte 5 — Cleanup

```bash
az group delete -n $RG --yes --no-wait
```

---

## Questoes de Prova

### Q1
Voce possui a VM `demovm` (D4s_v3, 1 NIC, 1 disco). Planeja: redimensionar para D8s_v3, adicionar disco de 200 GB, adicionar uma NIC, instalar extensao Puppet. Quais 2 alteracoes causam downtime?

- A. Redimensionar
- B. Adicionar disco
- C. Adicionar NIC
- D. Instalar extensao

<details>
<summary>Resposta</summary>

**A, C.** Redimensionar e adicionar NIC exigem VM parada. Disco e extensao podem ser feitos com VM em execucao.

</details>

### Q2
Voce precisa redimensionar uma VM Linux via CLI. Qual e o primeiro passo?

- A. Desalocar a VM
- B. Reiniciar a VM
- C. Verificar tamanhos disponiveis no cluster
- D. Desconectar a NIC primaria

<details>
<summary>Resposta</summary>

**C.** Verificar tamanhos disponiveis (`az vm list-vm-resize-options`). Se o tamanho desejado estiver disponivel, nao precisa desalocar.

</details>

### Q3
5 VMs em um Availability Set com 2 Fault Domains e 5 Update Domains. Durante manutencao planejada, quantas VMs ficam indisponiveis ao mesmo tempo?

- A. 1
- B. 2
- C. 3
- D. 5

<details>
<summary>Resposta</summary>

**A.** Manutencao planejada = Update Domains. 5 VMs / 5 UDs = 1 VM por UD. Azure atualiza 1 UD por vez.

</details>

### Q4
Para garantir SLA de 99,95%, quais recursos sao necessarios?

- A. Availability Zones
- B. Managed Disks + Availability Set
- C. Traffic Manager
- D. Premium SSD em VM unica

<details>
<summary>Resposta</summary>

**B.** Managed Disks + Availability Set = 99,95%. Zones = 99,99%. Traffic Manager = 99,99%. VM unica Premium SSD = 99,9%.

</details>

### Q5
Voce precisa transferir um disco de dados da VM1 para a VM2 com minimo downtime. Qual a ordem correta?

- A. Iniciar VM1 → Iniciar VM2 → Desanexar → Anexar
- B. Parar VM1 → Desanexar → Anexar na VM2 → Iniciar VM1
- C. Parar ambas → Desanexar → Anexar → Iniciar ambas
- D. Desanexar da VM1 → Parar VM2 → Anexar → Iniciar VM2

<details>
<summary>Resposta</summary>

**B.** Parar VM origem → desanexar disco → anexar na VM destino (sem parar!) → reiniciar VM origem. VM destino nao precisa ser parada para receber disco.

</details>

### Q6
VMSS com multiplas instancias tem SLA de 99,95%? Traffic Manager tem SLA de 99,95%?

- A. VMSS = Sim, TM = Sim
- B. VMSS = Sim, TM = Nao
- C. VMSS = Nao, TM = Sim
- D. VMSS = Nao, TM = Nao

<details>
<summary>Resposta</summary>

**B.** VMSS multiplas instancias = 99,95%. Traffic Manager = 99,99% (maior que 99,95%, portanto a resposta e NAO se a pergunta e "e 99,95%").

</details>
