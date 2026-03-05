> Voltar para o [Cenario Contoso](../cenario-contoso.md)

# Bloco 6 - Backup Vault e VM Move

**Origem:** Azure Backup Vault + VM Resource Move
**Resource Groups utilizados:** `az104-rg7` (VMs da Semana 2) + `az104-rg-bv` (Backup Vault)

## Contexto

A Contoso Corp ja configurou backup com Recovery Services Vault (Bloco 1) e Site Recovery para DR (Bloco 3). Agora voce explora dois topicos complementares cobrados no AZ-104: o **Azure Backup Vault** (servico mais novo, diferente do Recovery Services Vault) e o processo de **mover VMs entre Resource Groups e regioes**. Esses topicos completam a cobertura dos dominios de Compute e Monitoring do exame.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ az104-rg7 (VMs da Semana 2)                                  │   │
│  │                                                              │   │
│  │  az104-vm-win ──────────────── Move ──→ az104-rg-moved       │   │
│  │  az104-vm-linux                                              │   │
│  │                                                              │   │
│  │  (VM Move = mesma regiao, diferente RG)                      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ az104-rg-bv (NOVO)                                           │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │ Backup Vault: az104-bv                               │    │   │
│  │  │ Storage Redundancy: LRS                              │    │   │
│  │  │                                                      │    │   │
│  │  │ Backup Policy: az104-bv-policy                       │    │   │
│  │  │ • Retention: 30 days                                 │    │   │
│  │  │                                                      │    │   │
│  │  │ vs Recovery Services Vault (az104-rsv, Bloco 1):     │    │   │
│  │  │ • RSV: VM backup, File Share backup, Site Recovery   │    │   │
│  │  │ • BV: Azure Disks, Blobs, PostgreSQL, AKS            │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Task 6.1: Mover VM para outro Resource Group

Voce move uma VM entre Resource Groups para entender o processo e suas limitacoes.

1. Primeiro, crie o Resource Group de destino. Pesquise **Resource groups** > **+ Create**:

   | Setting        | Value            |
   | -------------- | ---------------- |
   | Resource group | `az104-rg-moved` |
   | Region         | **(US) East US** |

2. Clique em **Review + create** > **Create**

**Mover via Portal:**

3. Navegue para **az104-rg7** > selecione **az104-vm-linux** (ou outra VM de menor impacto)

4. No Overview da VM, clique em **Move** > **Move to another resource group**

5. Selecione:

   | Setting               | Value            |
   | --------------------- | ---------------- |
   | Target resource group | `az104-rg-moved` |

6. O Azure mostrara os **recursos dependentes** que precisam ser movidos junto:
   - Network Interface (NIC)
   - OS Disk
   - Public IP (se existir)
   - NSG (se associado a NIC)

7. Marque todos os recursos dependentes

8. Confirme digitando `yes` ou marcando o checkbox de confirmacao

9. Clique em **Move** > aguarde a validacao e o move (pode levar alguns minutos)

10. **Validacao:** Navegue para `az104-rg-moved` e confirme que a VM e seus recursos dependentes estao la

**Mover via CLI (alternativa):**

11. No Cloud Shell, o comando equivalente seria:

    ```bash
    VM_ID=$(az vm show -g az104-rg7 -n az104-vm-linux --query id -o tsv)
    NIC_ID=$(az vm show -g az104-rg7 -n az104-vm-linux --query "networkProfile.networkInterfaces[0].id" -o tsv)
    DISK_ID=$(az vm show -g az104-rg7 -n az104-vm-linux --query "storageProfile.osDisk.managedDisk.id" -o tsv)

    az resource move \
      --destination-group az104-rg-moved \
      --ids $VM_ID $NIC_ID $DISK_ID
    ```

    > **Conceito:** Mover um recurso entre RGs altera apenas o Resource Group — o resource ID muda mas a regiao e todas as configuracoes permanecem iguais. A VM NAO precisa ser desligada para move entre RGs (mesma regiao). Recursos dependentes devem ser movidos juntos.

---

### Task 6.2: Entender limitacoes de move entre regioes

1. Navegue para a VM em `az104-rg-moved` > **Move** > **Move to another region**

2. Observe que o Azure redireciona para o **Azure Resource Mover** ou **Azure Site Recovery**

3. Revise as informacoes apresentadas:

   | Cenario                          | Metodo                          | Downtime |
   | -------------------------------- | ------------------------------- | -------- |
   | Move entre RGs (mesma regiao)    | `az resource move` (portal/CLI) | Nenhum   |
   | Move entre regioes               | Azure Site Recovery (replicar)  | Minimo   |
   | Move entre regioes (alternativa) | Recriar VM na nova regiao       | Variavel |
   | Move entre subscriptions         | `az resource move` (portal/CLI) | Nenhum   |

4. **NAO execute** o move entre regioes — apenas entenda o processo

5. Mova a VM de volta para o RG original:

   ```bash
   VM_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux --query id -o tsv)
   NIC_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux --query "networkProfile.networkInterfaces[0].id" -o tsv)
   DISK_ID=$(az vm show -g az104-rg-moved -n az104-vm-linux --query "storageProfile.osDisk.managedDisk.id" -o tsv)

   az resource move \
     --destination-group az104-rg7 \
     --ids $VM_ID $NIC_ID $DISK_ID
   ```

   > **Conceito:** Move entre RGs na mesma regiao e simples e sem downtime. Move entre regioes e fundamentalmente diferente — requer recriar o recurso na nova regiao (via ASR, Azure Resource Mover, ou manualmente). Nem todos os recursos suportam move — verifique a documentacao de cada tipo.

   > **Conexao com Bloco 3:** O Azure Site Recovery (configurado no Bloco 3) e a forma recomendada de mover VMs entre regioes, pois permite replicacao continua e failover controlado.

   > **Dica AZ-104:** Na prova: Move entre RGs = sem downtime, resource ID muda. Move entre regioes = requer ASR ou recriar. Move entre subscriptions = possivel mas com restricoes (ex: resources com locks nao podem ser movidos). Sempre verifique `az resource move` support matrix.

---

### Task 6.2b: Explorar Azure Resource Mover

Voce explora o Azure Resource Mover, ferramenta dedicada para mover recursos entre regioes de forma orquestrada.

1. Pesquise **Azure Resource Mover** no portal

2. Clique em **Create move collection**:

   | Setting        | Value          |
   | -------------- | -------------- |
   | Source region  | **East US**    |
   | Target region  | **West US**    |

3. Clique em **+ Add resources**

4. Explore a interface:
   - Observe como o Resource Mover identifica **dependencias** automaticamente (ex: VM depende de NIC, Disk, VNet)
   - Revise os tipos de recurso suportados: VMs, VNets, NSGs, Public IPs, Availability Sets, etc.
   - Note o fluxo: **Add** → **Validate** → **Prepare** → **Initiate move** → **Commit**

5. **NAO execute** o move — apenas explore a interface e entenda o processo

6. Se desejar, cancele e delete a move collection

   > **Conceito:** Azure Resource Mover e um servico dedicado para mover recursos entre regioes Azure. Diferente do `az resource move` (que funciona entre RGs/subscriptions), o Resource Mover orquestra todo o processo cross-region: resolve dependencias, prepara os recursos, executa a movimentacao e faz commit. Internamente, usa Site Recovery para VMs e recria outros recursos na regiao de destino.

   > **Dica AZ-104:** Na prova, saiba diferenciar: `az resource move` = move entre RGs e subscriptions (mesma regiao, sem downtime). Azure Resource Mover = move entre regioes (orquestra dependencias, usa ASR para VMs). Azure Site Recovery = replicacao continua para DR (failover controlado). Os tres sao ferramentas distintas para cenarios diferentes.

---

### Task 6.3: Criar Azure Backup Vault

O Backup Vault e o servico mais recente de backup do Azure, projetado para workloads que o Recovery Services Vault nao suporta nativamente.

1. Pesquise **Backup vaults** > **+ Create**:

   | Setting            | Value                              |
   | ------------------ | ---------------------------------- |
   | Resource group     | `az104-rg-bv` (crie se necessario) |
   | Backup vault name  | `az104-bv`                         |
   | Region             | **(US) East US**                   |
   | Storage redundancy | **Locally-redundant (LRS)**        |

2. **Review + create** > **Create** > **Go to resource**

3. No Overview, note as diferencas visuais em relacao ao Recovery Services Vault:
   - Interface mais moderna
   - Foco em workloads de dados (Blobs, Disks, PostgreSQL, AKS)
   - Nao suporta VM backup completo (isso continua no RSV)

   > **Conceito:** Azure Backup Vault e o successor parcial do Recovery Services Vault. Atualmente, cada vault suporta workloads diferentes. Em novos projetos, verifique qual vault suporta o workload que voce precisa proteger.

---

### Task 6.4: Comparar Backup Vault vs Recovery Services Vault

1. Navegue para o **Recovery Services Vault** `az104-rsv` (do Bloco 1, em az104-rg-backup) — se ainda existir

2. Se nao existir, revise as diferencas conceituais:

   | Aspecto                  | Recovery Services Vault (RSV) | Backup Vault (BV)           |
   | ------------------------ | ----------------------------- | --------------------------- |
   | **VM Backup**            | Sim (Windows + Linux)         | Nao                         |
   | **Azure Files**          | Sim (File Share backup)       | Nao                         |
   | **Site Recovery**        | Sim (DR/replicacao)           | Nao                         |
   | **Azure Disks**          | Nao                           | Sim (snapshot-based)        |
   | **Azure Blobs**          | Nao (uso Operational Backup)  | Sim (vaulted + operational) |
   | **PostgreSQL**           | Nao                           | Sim                         |
   | **AKS**                  | Nao                           | Sim                         |
   | **SAP HANA**             | Sim                           | Nao                         |
   | **SQL in VM**            | Sim                           | Nao                         |
   | **Interface**            | Classic                       | Modern                      |
   | **Cross Region Restore** | Sim (com GRS)                 | Sim (com GRS)               |

3. No portal, explore os menus do Backup Vault:
   - **Backup center**: visao unificada de AMBOS os vaults
   - **Backup instances**: lista de workloads protegidos
   - **Backup policies**: configuracao de retencao

   > **Conceito:** A Microsoft esta gradualmente movendo workloads para o Backup Vault. Hoje, a maioria das organizacoes usa ambos: RSV para VMs e Azure Files; BV para Disks, Blobs e workloads cloud-native. O **Backup Center** no portal unifica a gestao de ambos.

   > **Dica AZ-104:** Na prova, saber qual vault suporta qual workload e critico. VM backup = RSV. Disk backup = BV. File Share = RSV. Blob backup = BV. Site Recovery = RSV apenas.

---

### Task 6.5: Configurar politica de backup no Backup Vault

1. No **Backup Vault** `az104-bv`, navegue para **Manage** > **Backup policies**

2. Clique em **+ Add**:

   | Setting         | Value                  |
   | --------------- | ---------------------- |
   | Datasource type | **Azure Disks**        |
   | Policy name     | `az104-bv-disk-policy` |

3. Configure o schedule:

   | Setting            | Value              |
   | ------------------ | ------------------ |
   | Frequency          | **Daily**          |
   | Time               | *horario desejado* |
   | Retention duration | **30 days**        |

4. Clique em **Create**

5. Agora configure um backup de disco. Navegue para **+ Configure backup**:

   | Setting         | Value                  |
   | --------------- | ---------------------- |
   | Datasource type | **Azure Disks**        |
   | Backup vault    | `az104-bv`             |
   | Backup policy   | `az104-bv-disk-policy` |

6. Selecione o disco da VM `az104-vm-win` (ou outra VM disponivel)

   > **Nota:** O Backup Vault precisa de permissoes no disco. O portal guiara a atribuicao da role **Disk Backup Reader** na VM/disco e **Disk Snapshot Contributor** no snapshot resource group.

7. Complete a configuracao seguindo os prompts do portal

8. **Validacao:** Navegue para **Backup instances** e confirme que o disco aparece como protegido

   > **Conceito:** Backup de discos no Backup Vault usa snapshots incrementais — apenas as alteracoes desde o ultimo snapshot sao capturadas. Isso e mais eficiente que o backup completo de VM do RSV. Ideal para proteger discos individuais sem o overhead de backup de VM completo.

   > **Dica AZ-104:** Na prova: Disk backup via Backup Vault cria snapshots incrementais (menor custo e tempo). VM backup via RSV cria um ponto de restauracao completo (snapshot + dados em vault). Escolha baseado no RPO e granularidade desejados.

---

## Modo Desafio - Bloco 6

- [ ] Criar RG `az104-rg-moved` e mover VM Linux para ele (portal ou CLI)
- [ ] Verificar recursos dependentes movidos junto (NIC, Disk)
- [ ] Entender as diferencas entre move entre RGs vs move entre regioes
- [ ] Explorar Azure Resource Mover (move collection East US → West US, sem executar)
- [ ] Mover VM de volta ao RG original
- [ ] Criar Backup Vault `az104-bv` (LRS) no az104-rg-bv
- [ ] Comparar workloads suportados: RSV vs Backup Vault **(Bloco 1)**
- [ ] Criar politica de backup para Azure Disks (Daily, 30 dias)
- [ ] Configurar backup de disco de VM no Backup Vault

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce precisa mover uma VM para outro Resource Group na mesma regiao. A VM precisa ser desligada?**

A) Sim, a VM deve estar parada (deallocated) para mover
B) Nao, a VM pode ser movida enquanto esta running
C) Sim, mas apenas se a VM tiver data disks
D) Depende do tamanho da VM

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, a VM pode ser movida enquanto esta running**

Move entre Resource Groups na mesma regiao nao requer downtime. O Azure atualiza o resource ID mas a VM continua operando normalmente. Todos os recursos dependentes (NIC, disks, public IP) devem ser movidos juntos.

</details>

### Questao 6.2
**Qual vault do Azure suporta backup de Azure Managed Disks (snapshots)?**

A) Recovery Services Vault
B) Backup Vault
C) Ambos
D) Nenhum — discos usam Azure Site Recovery

<details>
<summary>Ver resposta</summary>

**Resposta: B) Backup Vault**

O backup de Azure Managed Disks (baseado em snapshots incrementais) e suportado pelo Backup Vault, nao pelo Recovery Services Vault. O RSV suporta backup de VMs completas (que inclui os discos), mas nao backup de discos individuais.

</details>

### Questao 6.3
**Voce quer mover uma VM da regiao East US para West Europe. Qual abordagem e recomendada?**

A) Usar `az resource move` com a flag --destination-region
B) Usar Azure Site Recovery para replicar e fazer failover
C) Exportar o ARM template e fazer deploy na nova regiao
D) B e C sao ambas abordagens validas

<details>
<summary>Ver resposta</summary>

**Resposta: D) B e C sao ambas abordagens validas**

`az resource move` NAO suporta move entre regioes para VMs. As abordagens validas sao: (1) Azure Site Recovery — replica a VM e faz failover controlado (menor downtime); (2) Exportar/recriar — export ARM template, ajustar regiao e fazer deploy (mais manual). Azure Resource Mover tambem e uma opcao.

</details>

---
