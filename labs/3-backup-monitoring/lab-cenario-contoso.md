# Lab Unificado AZ-104 - Semana 3 (v2: Exercicios Interconectados)

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce continua como **Azure Administrator** da Contoso Corp. Nas semanas anteriores, voce construiu toda a base do ambiente Azure:

- **Semana 1 (IAM/Gov/Net):** Identidade, governanca, IaC, networking e conectividade
- **Semana 2 (Storage/Compute):** Storage accounts, file shares, VMs (Windows e Linux), Web Apps e containers

Agora, na **Semana 3**, sua missao e **proteger, monitorar e observar** tudo o que foi construido. Voce vai:

1. **Backup de VMs** — proteger as VMs criadas na Semana 2 com Recovery Services Vault
2. **Protecao de Storage** — backup de file shares e configurar soft delete/versioning no blob storage da Semana 2
3. **Site Recovery** — configurar DR cross-region para VMs criticas
4. **Monitor & Alerts** — monitorar metricas das VMs e configurar alertas com Action Groups
5. **Log Analytics** — conectar workspace as VMs, habilitar VM Insights e usar Network Watcher nas VNets da Semana 1

Ao final, voce tera **um ambiente corporativo com protecao de dados, disaster recovery, monitoramento proativo e observabilidade avancada** — tudo integrado com os recursos das semanas anteriores.

---

## Mapa de Dependencias

```
iam-gov-net (Semana 1)
  ├─ VNets, NSGs, DNS ──────────────────┐
  ├─ RBAC, Policies ────────────────────┤
  └─ Users, Groups ─────────────────────┤
                                        │
storage-compute (Semana 2)              │
  ├─ Storage Account + File Share ──────┤
  ├─ VMs (Windows, Linux) ─────────────┤
  ├─ Web Apps ──────────────────────────┤
  └─ Containers ────────────────────────┤
                                        │
                                        ▼
Bloco 1 (VM Backup) ◄──── Protege VMs da Semana 2
  ├─ Recovery Services Vault ──────────┐
  └─ Backup Policy + On-demand backup ─┤
                                       │
                                       ▼
Bloco 2 (File/Blob Protection) ◄──── Protege Storage da Semana 2
  ├─ File Share backup ────────────────┤
  └─ Soft delete + versioning ─────────┤
                                       │
                                       ▼
Bloco 3 (Site Recovery) ◄──── DR para VMs criticas
  ├─ Replicacao cross-region ──────────┤
  └─ Recovery Plan + Test Failover ────┤
                                       │
                                       ▼
Bloco 4 (Monitor & Alerts) ◄──── Monitora TODOS os recursos
  ├─ Metricas de VMs da Semana 2 ─────┤
  └─ Alerts + Action Groups ───────────┤
                                       │
                                       ▼
Bloco 5 (Log Analytics) ◄──── Analise avancada de tudo
  ├─ Workspace conectado as VMs ───────┤
  ├─ VM Insights ──────────────────────┤
  └─ Network Watcher nas VNets ────────┤
```

---

## Indice

- [Bloco 1 - VM Backup](#bloco-1---vm-backup)
- [Bloco 2 - File & Blob Protection](#bloco-2---file--blob-protection)
- [Bloco 3 - Site Recovery (DR)](#bloco-3---site-recovery-dr)
- [Bloco 4 - Monitor & Alerts](#bloco-4---monitor--alerts)
- [Bloco 5 - Log Analytics & Network Watcher](#bloco-5---log-analytics--network-watcher)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - VM Backup

**Origem:** Lab 10 - Backup Virtual Machines
**Resource Groups utilizados:** `az104-rg-backup` (Recovery Services Vault) + `az104-rg7` (VMs da Semana 2)

## Contexto

Na Semana 2, voce criou VMs Windows (`az104-vm-win`) e Linux (`az104-vm-linux`) no resource group `az104-rg7`. Agora voce precisa proteger essas VMs com backup. O Recovery Services Vault criado aqui sera reutilizado no **Bloco 2** (backup de file shares) e no **Bloco 3** (Site Recovery).

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                    az104-rg-backup                                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │          Recovery Services Vault: az104-rsv                  │    │
│  │                                                              │    │
│  │  Backup Policies:                                            │    │
│  │  ├─ DefaultPolicy (built-in, daily)                         │    │
│  │  └─ az104-backup-policy (custom, 12h frequency)             │    │
│  │                                                              │    │
│  │  Protected Items:                                            │    │
│  │  ├─ az104-vm-win  (Semana 2, az104-rg7) ◄── Custom policy  │    │
│  │  └─ az104-vm-linux (Semana 2, az104-rg7) ◄── Default policy│    │
│  │                                                              │    │
│  │  → Reutilizado no Bloco 2 (File Share backup)               │    │
│  │  → Reutilizado no Bloco 3 (Site Recovery)                   │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────┐        │
│  │  az104-rg7 (Semana 2 — VMs)                              │        │
│  │                                                          │        │
│  │  ├─ az104-vm-win  (Windows Server) ─── backup ativo ✓   │        │
│  │  └─ az104-vm-linux (Ubuntu) ────────── backup ativo ✓   │        │
│  └──────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Recovery Services Vault

O vault centraliza backups de VMs, file shares e configuracoes de Site Recovery. Voce usara este mesmo vault nos **Blocos 2 e 3**.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Recovery Services vaults** > **+ Create**

3. Preencha as configuracoes:

   | Setting        | Value                            |
   | -------------- | -------------------------------- |
   | Subscription   | *sua subscription*               |
   | Resource group | `az104-rg-backup` (crie se necessario) |
   | Vault name     | `az104-rsv`                      |
   | Region         | **East US**                      |

   > **Conceito:** O Recovery Services Vault deve estar na **mesma regiao** dos recursos que protege (para backup). Para Site Recovery (Bloco 3), o vault de DR ficara na regiao secundaria.

4. Clique em **Review + create** > **Create**

5. Selecione **Go to resource**

6. Explore o blade **Overview** — note as secoes: Backup Items, Replication Items, Backup Alerts

   > **Conexao com Blocos 2-3:** Este vault sera reutilizado para proteger file shares (Bloco 2). No Bloco 3, voce criara um vault separado na regiao de DR para Site Recovery.

---

### Task 1.2: Criar custom backup policy

A DefaultPolicy faz backup diario com retencao de 30 dias. Voce cria uma policy customizada com frequencia de 12 horas para VMs criticas.

1. No vault **az104-rsv**, va para **Manage** > **Backup policies**

2. Revise a **DefaultPolicy** — note: frequencia diaria, retencao de 30 dias

3. Clique em **+ Add** > selecione **Azure Virtual Machine**

4. Configure a nova policy:

   | Setting              | Value                               |
   | -------------------- | ----------------------------------- |
   | Policy name          | `az104-backup-policy`               |
   | Frequency            | **Every 12 hours** (Hourly)         |
   | Time                 | `6:00 AM`                           |
   | Timezone             | **(UTC-03:00) Brasilia**            |
   | Instant Restore      | Retain for **2** day(s)             |
   | Daily backup point   | Retain for **180** days             |
   | Weekly backup point  | **Enabled** — Sunday, retain **12** weeks |
   | Monthly backup point | **Enabled** — First Sunday, retain **12** months |

   > **Conceito:** Instant Restore usa snapshots locais para restauracao rapida (minutos). Daily/Weekly/Monthly sao pontos de retencao de longo prazo armazenados no vault.

5. Clique em **Create**

6. Verifique que **az104-backup-policy** aparece na lista junto com **DefaultPolicy**

   > **Dica AZ-104:** Na prova, atente para os limites de retencao: daily (9999 dias), weekly (5163 semanas), monthly (1188 meses), yearly (99 anos).

---

### Task 1.3: Habilitar backup para az104-vm-win (custom policy)

Voce protege a VM Windows da Semana 2 usando a policy customizada.

> **Pre-requisito:** A VM `az104-vm-win` deve existir no `az104-rg7` (criada na Semana 2). Se nao existir, crie uma VM Windows Server basica nesse RG antes de continuar.

1. No vault **az104-rsv**, va para **Getting started** > **Backup**

2. Configure:

   | Setting                     | Value                     |
   | --------------------------- | ------------------------- |
   | Where is your workload running? | **Azure**             |
   | What do you want to back up?    | **Virtual machine**   |

3. Clique em **Backup**

4. Na aba **Backup policy**, selecione **az104-backup-policy** (a custom que voce criou)

5. Na aba **Virtual Machines**, clique em **Add**

6. Selecione **az104-vm-win** (do az104-rg7, Semana 2) > **OK**

   > **Conexao com Semana 2:** Voce esta protegendo a mesma VM Windows que foi criada e configurada na Semana 2. O backup captura o estado completo da VM, incluindo OS disk e data disks.

7. Clique em **Enable Backup**

8. Aguarde a notificacao de sucesso

   > **Conceito:** O Azure instala automaticamente a extensao de backup na VM (VMSnapshot para Windows, VMSnapshotLinux para Linux). Nenhuma acao adicional e necessaria dentro da VM.

---

### Task 1.4: Habilitar backup para az104-vm-linux (DefaultPolicy)

1. Ainda no vault **az104-rsv** > **Getting started** > **Backup**

2. Configure:

   | Setting                     | Value                     |
   | --------------------------- | ------------------------- |
   | Where is your workload running? | **Azure**             |
   | What do you want to back up?    | **Virtual machine**   |

3. Clique em **Backup**

4. Na aba **Backup policy**, selecione **DefaultPolicy**

5. Na aba **Virtual Machines**, clique em **Add**

6. Selecione **az104-vm-linux** (do az104-rg7, Semana 2) > **OK**

   > **Conexao com Semana 2:** A VM Linux tambem precisa de protecao. Usando a DefaultPolicy (diaria) para demonstrar que diferentes VMs podem ter policies diferentes conforme sua criticidade.

7. Clique em **Enable Backup**

---

### Task 1.5: Executar backup on-demand da az104-vm-win

1. No vault **az104-rsv**, va para **Protected items** > **Backup items**

2. Clique em **Azure Virtual Machine**

3. Selecione **az104-vm-win** > clique em **Backup now**

4. Configure:

   | Setting                   | Value                                     |
   | ------------------------- | ----------------------------------------- |
   | Retain Backup Till        | *aceite o default (30 dias a partir de hoje)* |

5. Clique em **OK**

6. Monitore o progresso em **Monitoring** > **Backup Jobs**

   > **Conceito:** O primeiro backup (full) pode levar mais tempo. Backups subsequentes sao incrementais. O job passa por fases: Snapshot → Transfer data to vault.

7. Aguarde ate o status mudar para **Completed** (pode levar 20-30 minutos)

   > **Dica AZ-104:** Na prova, saiba diferenciar: backup on-demand vs scheduled, full vs incremental, snapshot vs vault tier.

---

### Task 1.6: Verificar backup items e restore points

1. No vault **az104-rsv** > **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Verifique que ambas as VMs aparecem:

   | VM              | Policy              | Last Backup Status |
   | --------------- | -------------------- | ------------------ |
   | az104-vm-win    | az104-backup-policy  | Completed          |
   | az104-vm-linux  | DefaultPolicy        | Warning (initial)  |

3. Selecione **az104-vm-win** > clique em **View all restore points**

4. Note os restore points disponiveis — deve haver pelo menos 1 (do backup on-demand)

5. Clique em um restore point > observe as opcoes de restore:
   - **Create virtual machine** — restaura para uma nova VM
   - **Restore disk** — restaura apenas os discos
   - **Replace existing** — substitui os discos da VM atual
   - **Cross Region Restore** — restaura na regiao secundaria (se habilitado)

   > **Conexao com Bloco 3:** No Bloco 3 (Site Recovery), voce configurara replicacao cross-region como alternativa ao Cross Region Restore para cenarios de DR mais robustos.

---

### Task 1.7: Simular restore de disco (dry run)

Voce pratica o processo de restore sem criar recursos permanentes.

1. No vault **az104-rsv** > **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Selecione **az104-vm-win** > **Restore VM**

3. Selecione o restore point mais recente

4. Em **Restore Configuration**, selecione **Restore disks**

5. Configure:

   | Setting               | Value                                  |
   | --------------------- | -------------------------------------- |
   | Staging Location      | *selecione um storage account existente (da Semana 2)* |
   | Resource Group        | `az104-rg-backup`                      |

   > **Conexao com Semana 2:** Voce pode usar o storage account criado na Semana 2 como staging location. O restore process usa esse storage para armazenar temporariamente os discos restaurados.

6. **NAO clique em Restore** — apenas revise as opcoes e cancele

   > **Conceito:** Restore disk cria managed disks que podem ser usados para recriar a VM manualmente ou via ARM template (skills do Bloco 3, Semana 1). Restore VM cria tudo automaticamente.

---

## Modo Desafio - Bloco 1

- [ ] Criar Recovery Services Vault `az104-rsv` em `az104-rg-backup` (East US)
- [ ] Criar custom policy `az104-backup-policy` (12h frequency, 180 days retention)
- [ ] Habilitar backup de `az104-vm-win` **(Semana 2)** com custom policy
- [ ] Habilitar backup de `az104-vm-linux` **(Semana 2)** com DefaultPolicy
- [ ] Executar backup on-demand da `az104-vm-win` → aguardar completion
- [ ] Verificar restore points e opcoes de restore
- [ ] Simular restore de disco (dry run, sem executar)

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Voce precisa fazer backup de uma VM Azure com frequencia de 4 horas. Qual tipo de policy voce deve configurar?**

A) Daily backup policy com 4 backups agendados
B) Enhanced backup policy com frequencia horaria (every 4 hours)
C) Standard backup policy com 4 backup jobs separados
D) Nao e possivel fazer backup com frequencia menor que 24 horas

<details>
<summary>Ver resposta</summary>

**Resposta: B) Enhanced backup policy com frequencia horaria (every 4 hours)**

A Enhanced backup policy permite frequencias de 4, 6, 8 ou 12 horas para VMs Azure. A Standard policy suporta apenas backup diario (1x por dia). A Enhanced policy tambem suporta Multi-Disk Crash Consistency e Zone-Redundant Storage para o vault.

</details>

### Questao 1.2
**Voce fez backup on-demand de uma VM. O restore point aparece imediatamente no vault. De onde vem essa disponibilidade rapida?**

A) O backup ja foi transferido para o vault
B) O Instant Restore usa snapshots locais armazenados no resource group da VM
C) O Azure cria uma copia completa da VM em outra regiao
D) O backup usa a cache do Recovery Services Vault

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Instant Restore usa snapshots locais armazenados no resource group da VM**

O Instant Restore cria snapshots dos discos da VM no mesmo resource group. Esses snapshots permitem restauracao em minutos (sem esperar a transferencia para o vault). A retencao do snapshot e configuravel (1-5 dias para Standard, 1-30 dias para Enhanced).

</details>

### Questao 1.3
**Uma VM tem backup habilitado com DefaultPolicy (retencao 30 dias). O administrador precisa manter um backup especifico por 1 ano. O que ele deve fazer?**

A) Alterar a DefaultPolicy para 365 dias de retencao
B) Executar backup on-demand com "Retain Backup Till" configurado para 1 ano
C) Criar uma nova policy e reaplicar a VM
D) Copiar o restore point para um storage account

<details>
<summary>Ver resposta</summary>

**Resposta: B) Executar backup on-demand com "Retain Backup Till" configurado para 1 ano**

O backup on-demand permite especificar uma data de retencao independente da policy atribuida. Isso e util para preservar backups antes de grandes mudancas ou para compliance, sem afetar a policy regular.

</details>

### Questao 1.4
**Voce quer restaurar apenas o OS disk de uma VM sem afetar os data disks. Qual opcao de restore voce deve usar?**

A) Create virtual machine
B) Replace existing — selecionar apenas o OS disk
C) Restore disks — selecionar apenas o OS disk e reattach manualmente
D) Cross Region Restore

<details>
<summary>Ver resposta</summary>

**Resposta: C) Restore disks — selecionar apenas o OS disk e reattach manualmente**

"Restore disks" permite restaurar discos individuais como managed disks. Voce pode entao swap o OS disk da VM existente. "Replace existing" substitui todos os discos. "Create virtual machine" cria uma nova VM completa.

</details>

---

# Bloco 2 - File & Blob Protection

**Origem:** Lab 10 (continuacao) + Azure Backup for File Shares + Soft Delete & Versioning
**Resource Groups utilizados:** `az104-rg-backup` (vault do Bloco 1) + `az104-rg6` (Storage da Semana 2)

## Contexto

Na Semana 2, voce criou storage accounts com file shares e blob containers no `az104-rg6`. Agora voce protege esses dados com backup de file shares (usando o **mesmo vault do Bloco 1**) e configura soft delete + versioning como camadas adicionais de protecao.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                    az104-rg-backup (Bloco 1)                         │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │          Recovery Services Vault: az104-rsv (Bloco 1)        │    │
│  │                                                              │    │
│  │  Backup Items:                                               │    │
│  │  ├─ Azure VMs: az104-vm-win, az104-vm-linux ◄── Bloco 1    │    │
│  │  └─ Azure File Share: az104-share ◄── NOVO (este bloco)     │    │
│  │                                                              │    │
│  │  File Share Backup Policy:                                   │    │
│  │  └─ az104-fs-policy (daily, 30 days)                        │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  az104-rg6 (Semana 2 — Storage)                              │    │
│  │                                                              │    │
│  │  ┌───────────────────────────────────────────────┐           │    │
│  │  │ Storage Account: az104storageXXX (Semana 2)   │           │    │
│  │  │                                               │           │    │
│  │  │ File Shares:                                  │           │    │
│  │  │ └─ az104-share ──── backup via RSV ✓          │           │    │
│  │  │                                               │           │    │
│  │  │ Blob Containers:                              │           │    │
│  │  │ └─ az104-container                            │           │    │
│  │  │    ├─ Soft delete: 14 dias ✓ (NOVO)           │           │    │
│  │  │    └─ Versioning: habilitado ✓ (NOVO)         │           │    │
│  │  └───────────────────────────────────────────────┘           │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  → Vault reutilizado do Bloco 1                                      │
│  → Storage account reutilizado da Semana 2                           │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Configurar backup de file share

Voce usa o **mesmo vault** criado no Bloco 1 para proteger o file share da Semana 2.

> **Pre-requisito:** O storage account com file share `az104-share` deve existir no `az104-rg6` (criado na Semana 2). Se nao existir, crie um storage account com um file share antes de continuar.

1. No vault **az104-rsv** (criado no Bloco 1), va para **Getting started** > **Backup**

2. Configure:

   | Setting                     | Value                     |
   | --------------------------- | ------------------------- |
   | Where is your workload running? | **Azure**             |
   | What do you want to back up?    | **Azure File Share**  |

3. Clique em **Backup**

4. Em **Storage Account**, clique em **Select** > selecione o storage account do `az104-rg6` (da Semana 2)

   > **Conexao com Semana 2:** Voce esta protegendo o mesmo file share que os usuarios da Contoso Corp utilizam para armazenamento corporativo (configurado na Semana 2).

5. Clique em **OK** e aguarde o vault registrar o storage account

---

### Task 2.2: Criar policy de backup para file share

1. Em **Backup policy**, clique em **Create a new policy**

2. Configure:

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Policy name        | `az104-fs-policy`        |
   | Frequency          | **Daily**                |
   | Time               | `12:00 AM`               |
   | Timezone           | **(UTC-03:00) Brasilia** |
   | Retention of daily | **30** days              |
   | Weekly backup      | **Enabled** — Sunday, retain **8** weeks |
   | Monthly backup     | **Enabled** — First Sunday, retain **6** months |

   > **Conceito:** O backup de file share usa **snapshots** do Azure Files. Cada backup cria um share snapshot que captura o estado completo do file share naquele momento. Diferente de VM backup, nao ha transfer to vault — tudo fica na storage account.

3. Clique em **OK**

---

### Task 2.3: Selecionar file share e habilitar backup

1. Em **File Shares to Backup**, clique em **Add**

2. Selecione **az104-share** > **OK**

3. Clique em **Enable Backup**

4. Aguarde a notificacao de sucesso

   > **Conceito:** O backup de file shares e baseado em share snapshots. Os snapshots sao armazenados **na propria storage account** (nao no vault). O vault gerencia a policy e a retencao.

---

### Task 2.4: Executar backup on-demand do file share

1. No vault **az104-rsv** > **Protected items** > **Backup items** > **Azure File Share**

2. Selecione **az104-share**

3. Clique em **Backup now**

4. Em **Retain Backup Till**, aceite o default

5. Clique em **OK**

6. Monitore em **Monitoring** > **Backup Jobs**

7. Aguarde ate **Completed**

---

### Task 2.5: Testar restore de arquivo do file share

1. No vault **az104-rsv** > **Protected items** > **Backup items** > **Azure File Share**

2. Selecione **az104-share** > **Restore Share**

3. Selecione o restore point mais recente

4. Em **Restore Type**, revise as opcoes:

   | Opcao                     | Descricao                                          |
   | ------------------------- | -------------------------------------------------- |
   | **Full Share Restore**    | Restaura todo o file share para original ou novo   |
   | **Item Level Restore**    | Restaura arquivos/pastas individuais               |

5. Selecione **Item Level Restore**

6. Selecione **Destination Folder** > **Original Location** ou **Alternate Location**

   > **Conceito:** Item Level Restore permite recuperar arquivos individuais sem restaurar o share inteiro. Full Share Restore pode sobrescrever o share original ou criar um novo.

7. **Cancele** — este e apenas um dry run para conhecer as opcoes

---

### Task 2.6: Habilitar soft delete para blobs

Soft delete protege contra exclusao acidental de blobs no storage account da Semana 2.

1. Navegue para o **storage account** no `az104-rg6` (da Semana 2)

2. Va para **Data management** > **Data protection**

3. Em **Recovery**, configure:

   | Setting                                  | Value         |
   | ---------------------------------------- | ------------- |
   | Enable soft delete for blobs             | **Checked**   |
   | Days to retain deleted blobs             | **14**        |
   | Enable soft delete for containers        | **Checked**   |
   | Days to retain deleted containers        | **14**        |

4. Clique em **Save**

   > **Conceito:** Soft delete mantem os dados deletados por um periodo configuravel (1-365 dias). Durante esse periodo, voce pode restaurar blobs e containers excluidos. Depois do periodo, a exclusao se torna permanente.

---

### Task 2.7: Habilitar blob versioning

1. No mesmo storage account, ainda em **Data management** > **Data protection**

2. Em **Tracking**, configure:

   | Setting                      | Value       |
   | ---------------------------- | ----------- |
   | Enable versioning for blobs  | **Checked** |

3. Clique em **Save**

   > **Conceito:** O versioning cria automaticamente uma nova versao do blob a cada modificacao (overwrite). Voce pode acessar versoes anteriores a qualquer momento. Combinado com soft delete, oferece protecao robusta contra exclusao e sobrescrita acidental.

---

### Task 2.8: Testar soft delete e versioning

1. No storage account, va para **Data storage** > **Containers**

2. Selecione **az104-container** (ou crie um se necessario)

3. **Upload** um arquivo de teste (qualquer arquivo pequeno, ex: `test.txt`)

4. **Upload** o mesmo arquivo novamente com conteudo diferente (para gerar versao)

5. Selecione o blob > na barra superior, clique em **Versions**

6. Verifique que existem **2 versoes** do blob

7. **Delete** o blob

8. Na barra superior do container, clique em **Show deleted blobs**

9. Verifique que o blob aparece com status **Deleted** e a data de expiracao do soft delete

10. Selecione o blob deletado > **Undelete**

11. Verifique que o blob foi restaurado

    > **Conexao com Semana 2:** O storage account que voce configurou na Semana 2 agora tem 3 camadas de protecao: backup via RSV (file shares), soft delete (blobs) e versioning (blobs). Cada camada protege contra cenarios diferentes.

---

## Modo Desafio - Bloco 2

- [ ] Configurar backup do file share `az104-share` **(Semana 2)** usando o vault `az104-rsv` **(Bloco 1)**
- [ ] Criar policy `az104-fs-policy` (daily, 30 days retention)
- [ ] Executar backup on-demand do file share → aguardar completion
- [ ] Revisar opcoes de restore (Full Share vs Item Level)
- [ ] Habilitar soft delete para blobs e containers (14 dias) no storage **(Semana 2)**
- [ ] Habilitar blob versioning
- [ ] **Integracao:** Testar upload → versioning → delete → soft delete → undelete

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce habilitou backup de um Azure File Share via Recovery Services Vault. Onde os snapshots de backup sao armazenados?**

A) No Recovery Services Vault
B) Na propria storage account do file share
C) Em um storage account gerenciado pelo Azure
D) Em uma regiao secundaria automaticamente

<details>
<summary>Ver resposta</summary>

**Resposta: B) Na propria storage account do file share**

Diferente do backup de VMs (que transfere dados para o vault), o backup de file shares usa **share snapshots** armazenados na propria storage account. O vault gerencia a policy, retencao e orquestracao, mas os dados ficam no storage account.

</details>

### Questao 2.2
**Um usuario deletou acidentalmente um blob importante. Soft delete esta habilitado com retencao de 14 dias. Qual e o estado do blob e como restaura-lo?**

A) O blob foi removido permanentemente — nao ha como restaurar
B) O blob esta em estado "soft-deleted" — use Undelete para restaura-lo dentro de 14 dias
C) O blob foi movido para uma lixeira no portal — arraste de volta
D) O blob foi arquivado automaticamente — faca rehydrate

<details>
<summary>Ver resposta</summary>

**Resposta: B) O blob esta em estado "soft-deleted" — use Undelete para restaura-lo dentro de 14 dias**

Com soft delete habilitado, blobs excluidos ficam em estado "soft-deleted" pelo periodo configurado. Use a operacao **Undelete** (via portal, CLI ou SDK) para restaura-los. Apos o periodo de retencao, a exclusao se torna permanente.

</details>

### Questao 2.3
**Qual a diferenca entre soft delete e versioning para protecao de blobs?**

A) Ambos protegem contra exclusao, mas versioning tambem protege contra sobrescrita
B) Soft delete protege contra sobrescrita, versioning protege contra exclusao
C) Nao ha diferenca — sao funcionalidades identicas
D) Versioning requer Premium storage, soft delete funciona em Standard

<details>
<summary>Ver resposta</summary>

**Resposta: A) Ambos protegem contra exclusao, mas versioning tambem protege contra sobrescrita**

- **Soft delete:** Protege contra exclusao acidental (mantem dados deletados por X dias)
- **Versioning:** Protege contra sobrescrita acidental (cria nova versao a cada modificacao)
- Combinados, oferecem protecao contra ambos os cenarios

</details>

### Questao 2.4
**Voce precisa restaurar um unico arquivo de um Azure File Share. O file share tem backup configurado via Recovery Services Vault. Qual opcao de restore voce deve usar?**

A) Full Share Restore para um novo file share e copiar o arquivo
B) Item Level Restore selecionando o arquivo especifico
C) Baixar o share snapshot completo e extrair o arquivo
D) Usar AzCopy para copiar do snapshot

<details>
<summary>Ver resposta</summary>

**Resposta: B) Item Level Restore selecionando o arquivo especifico**

O Azure Backup para File Shares suporta **Item Level Restore**, que permite restaurar arquivos e pastas individuais sem precisar restaurar o share inteiro. Voce pode restaurar para a localizacao original ou para uma localizacao alternativa.

</details>

---

# Bloco 3 - Site Recovery (DR)

**Origem:** Lab 10 (Site Recovery) + Disaster Recovery Planning
**Resource Groups utilizados:** `az104-rg-dr` (vault DR na regiao secundaria) + `az104-rg7` (VMs da Semana 2)

## Contexto

O backup (Blocos 1-2) protege contra perda de dados, mas nao garante disponibilidade em caso de falha regional. Agora voce configura **Azure Site Recovery (ASR)** para replicar VMs criticas da Semana 2 para uma regiao secundaria, criando um plano de DR completo.

## Diagrama

```
┌────────────────────────────────────────┐     ┌──────────────────────────────────────┐
│          East US (Primaria)            │     │         West US (DR)                 │
│                                        │     │                                      │
│  ┌──────────────────────────────────┐  │     │  ┌──────────────────────────────────┐│
│  │ az104-rg7 (Semana 2)            │  │     │  │ az104-rg-dr                      ││
│  │                                  │  │     │  │                                  ││
│  │ ┌──────────────┐                │  │     │  │ Recovery Services Vault:          ││
│  │ │az104-vm-win  │────replicacao──│──│─────│──│─► az104-rsv-dr                    ││
│  │ │(Windows)     │                │  │     │  │                                  ││
│  │ └──────────────┘                │  │     │  │ Replicated Items:                ││
│  │                                  │  │     │  │ ├─ az104-vm-win (replicada)      ││
│  │ VNet da Semana 1 ◄──────────────│──│─────│──│─► VNet DR (auto-created)          ││
│  │                                  │  │     │  │                                  ││
│  │ Storage (Semana 2) ◄────────────│──│─────│──│─► Cache Storage (auto-created)    ││
│  └──────────────────────────────────┘  │     │  │                                  ││
│                                        │     │  │ Recovery Plans:                  ││
│  az104-rg-backup (Bloco 1)            │     │  │ └─ contoso-recovery-plan          ││
│  └─ az104-rsv (backup local)          │     │  └──────────────────────────────────┘│
│                                        │     │                                      │
└────────────────────────────────────────┘     └──────────────────────────────────────┘
```

> **Nota:** Site Recovery gera custos de replicacao e storage. Configure e teste rapidamente, depois faca cleanup.

---

### Task 3.1: Criar Recovery Services Vault na regiao de DR

Para Site Recovery, o vault deve estar na **regiao de destino** (DR), diferente do vault de backup (regiao primaria).

1. Pesquise e selecione **Recovery Services vaults** > **+ Create**

2. Preencha as configuracoes:

   | Setting        | Value                              |
   | -------------- | ---------------------------------- |
   | Subscription   | *sua subscription*                 |
   | Resource group | `az104-rg-dr` (crie se necessario) |
   | Vault name     | `az104-rsv-dr`                     |
   | Region         | **West US**                        |

   > **Conceito:** O vault de Site Recovery deve estar na regiao de **destino** (DR), nao na regiao de origem. Isso garante que o vault permanece acessivel mesmo se a regiao primaria ficar indisponivel.

3. Clique em **Review + create** > **Create** > **Go to resource**

   > **Conexao com Bloco 1:** Note a diferenca: o vault do Bloco 1 (`az104-rsv`, East US) e para backup local. Este vault (`az104-rsv-dr`, West US) e para DR cross-region. Sao propositos diferentes com vaults separados.

---

### Task 3.2: Habilitar replicacao para az104-vm-win

1. No vault **az104-rsv-dr** (West US), va para **Getting started** > **Site Recovery**

2. Em **Azure virtual machines**, clique em **Enable replication**

3. Aba **Source**:

   | Setting              | Value                     |
   | -------------------- | ------------------------- |
   | Region               | **East US**               |
   | Subscription         | *sua subscription*        |
   | Resource group       | `az104-rg7`               |
   | Virtual machine deployment model | **Resource Manager** |

4. Clique em **Next**

5. Aba **Virtual machines**: selecione **az104-vm-win**

   > **Conexao com Semana 2:** Voce esta configurando DR para a mesma VM que esta protegida por backup no Bloco 1. Backup e Site Recovery sao complementares: backup protege dados, ASR protege disponibilidade.

6. Clique em **Next**

7. Aba **Replication settings** — revise:

   | Setting                    | Value                          |
   | -------------------------- | ------------------------------ |
   | Target location            | **West US** (auto)             |
   | Target resource group      | `az104-rg7-asr` (auto-created) |
   | Failover virtual network   | auto-created ou selecione uma  |
   | Target availability        | *aceite default*               |
   | Replication policy         | `24-hour-retention-policy` (default) |

   > **Conceito:** O ASR cria automaticamente recursos na regiao de destino: RG, VNet, storage account para cache. A replication policy define RPO (Recovery Point Objective) e retencao de recovery points.

8. Revise a aba **Manage** — note as opcoes de automation (runbooks, scripts pre/pos failover)

9. Clique em **Next** > **Enable replication**

10. Monitore em **Protected items** > **Replicated items**

11. Aguarde ate o status mudar para **Protected** (pode levar 15-30 minutos para a sincronizacao inicial)

    > **Dica AZ-104:** Na prova, saiba que a sincronizacao inicial pode levar horas dependendo do tamanho dos discos. O RPO comeca a ser medido apos a sincronizacao completar.

---

### Task 3.3: Criar Recovery Plan

Um Recovery Plan define a ordem e agrupamento de VMs para failover coordenado.

1. No vault **az104-rsv-dr** > **Manage** > **Recovery Plans (Site Recovery)**

2. Clique em **+ Recovery Plan**

3. Configure:

   | Setting        | Value                    |
   | -------------- | ------------------------ |
   | Name           | `contoso-recovery-plan`  |
   | Source         | **East US**              |
   | Target         | **West US**              |
   | Allow items with deployment model | **Resource Manager** |

4. Em **Select items**, selecione **az104-vm-win** > **OK**

5. Clique em **Create**

6. Selecione **contoso-recovery-plan** > observe a estrutura:

   ```
   Group 1: Start
     └─ az104-vm-win
   ```

   > **Conceito:** Recovery Plans permitem agrupar VMs em grupos que fazem failover em sequencia (Group 1 primeiro, depois Group 2, etc.). Voce pode adicionar scripts pre/pos cada grupo para automacao (ex: atualizar DNS, notificar equipe).

---

### Task 3.4: Executar Test Failover

Test Failover valida a replicacao sem afetar a producao.

> **Pre-requisito:** A VM deve estar com status **Protected** em Replicated items.

1. No vault **az104-rsv-dr** > **Protected items** > **Replicated items**

2. Selecione **az104-vm-win**

3. Clique em **Test Failover**

4. Configure:

   | Setting               | Value                                          |
   | --------------------- | ---------------------------------------------- |
   | Recovery Point        | **Latest processed** (mais recente)             |
   | Azure virtual network | *selecione a VNet auto-created ou crie uma de teste* |

   > **Conceito:** Use uma VNet isolada para test failover para evitar conflitos de IP com a VM de producao. O "Latest processed" usa o recovery point mais recente ja processado pelo ASR.

5. Clique em **OK**

6. Monitore em **Monitoring** > **Site Recovery Jobs**

7. Quando completar, navegue para **Virtual Machines** na regiao **West US** e verifique que a VM de teste foi criada

   > **IMPORTANTE:** A VM de teste consome recursos e gera custos. Voce DEVE fazer cleanup do test failover.

---

### Task 3.5: Cleanup Test Failover

1. Volte para **Replicated items** > **az104-vm-win**

2. Note o aviso: **"Test failover cleanup pending"**

3. Clique em **Cleanup test failover**

4. Marque **"Testing is complete. Delete test failover virtual machine(s)"**

5. Digite suas notas (ex: "Test failover validated successfully")

6. Clique em **OK**

7. Monitore em **Site Recovery Jobs** ate o cleanup completar

8. Verifique que a VM de teste foi removida de **Virtual Machines** na regiao West US

   > **Conexao com Semanas 1-2:** O test failover validou que a VM criada na Semana 2, nas VNets da Semana 1, pode ser recuperada na regiao de DR. Em producao, o failover real redirecionaria o trafego para a regiao secundaria.

---

### Task 3.6: Revisar RPO e metricas de replicacao

1. No vault **az104-rsv-dr** > **Protected items** > **Replicated items** > **az104-vm-win**

2. Revise o blade **Overview**:

   | Metrica                  | Descricao                                              |
   | ------------------------ | ------------------------------------------------------ |
   | **Replication health**   | Healthy/Warning/Critical                               |
   | **RPO**                  | Tempo desde o ultimo recovery point (minutos)          |
   | **Latest recovery point**| Timestamp do ponto mais recente                        |
   | **Failover health**      | Se a VM esta pronta para failover                      |

3. Va para **Compute and Network** — revise as configuracoes da VM na regiao de destino

4. Va para **Disks** — verifique quais discos estao sendo replicados

   > **Conceito:** RPO (Recovery Point Objective) indica a perda de dados maxima aceitavel. Um RPO de 5 minutos significa que, no pior caso, voce perde ate 5 minutos de dados. RTO (Recovery Time Objective) depende do tamanho da VM e complexidade do recovery plan.

---

## Modo Desafio - Bloco 3

- [ ] Criar vault `az104-rsv-dr` em **West US** (regiao de DR)
- [ ] Habilitar replicacao de `az104-vm-win` **(Semana 2)** para West US
- [ ] Aguardar status **Protected**
- [ ] Criar Recovery Plan `contoso-recovery-plan`
- [ ] Executar **Test Failover** → verificar VM de teste na regiao DR
- [ ] **Cleanup** Test Failover → remover VM de teste
- [ ] Revisar RPO, replication health e failover health

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa configurar Site Recovery para uma VM em East US. Em qual regiao o Recovery Services Vault deve ser criado?**

A) East US (mesma regiao da VM)
B) Na regiao de destino (ex: West US)
C) Em qualquer regiao — nao importa
D) Central US (regiao intermediaria)

<details>
<summary>Ver resposta</summary>

**Resposta: B) Na regiao de destino (ex: West US)**

O vault de Site Recovery deve estar na regiao de **destino** (DR). Isso garante que o vault permanece acessivel durante uma falha na regiao de origem. O vault de backup (diferente do de DR) fica na mesma regiao dos recursos protegidos.

</details>

### Questao 3.2
**Qual a diferenca entre RPO e RTO no contexto de Site Recovery?**

A) RPO e o tempo de recuperacao, RTO e a perda de dados aceitavel
B) RPO e a perda de dados maxima aceitavel (em tempo), RTO e o tempo para restaurar o servico
C) RPO e RTO sao a mesma coisa
D) RPO se aplica a VMs, RTO se aplica a storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) RPO e a perda de dados maxima aceitavel (em tempo), RTO e o tempo para restaurar o servico**

- **RPO (Recovery Point Objective):** Quanto de dados voce pode perder (ex: RPO 5 min = ate 5 min de dados perdidos)
- **RTO (Recovery Time Objective):** Quanto tempo leva para restaurar o servico (ex: RTO 1h = servico restaurado em ate 1 hora)

</details>

### Questao 3.3
**Voce executou um test failover e a VM de teste foi criada na regiao de DR. O que acontece com a VM de producao durante o test failover?**

A) A VM de producao e pausada
B) A VM de producao continua funcionando normalmente — test failover nao afeta producao
C) A VM de producao e desligada automaticamente
D) A replicacao e interrompida durante o teste

<details>
<summary>Ver resposta</summary>

**Resposta: B) A VM de producao continua funcionando normalmente — test failover nao afeta producao**

O test failover cria uma **copia isolada** da VM na regiao de DR, sem afetar a VM de producao ou a replicacao em andamento. Por isso e recomendado usar uma VNet isolada para o teste, evitando conflitos de IP.

</details>

### Questao 3.4
**Voce tem um Recovery Plan com 3 grupos. O Group 1 tem o banco de dados, Group 2 tem o app server, Group 3 tem o web server. Em que ordem ocorre o failover?**

A) Todos os grupos fazem failover simultaneamente
B) Group 1 primeiro, depois Group 2, depois Group 3 (sequencial)
C) A ordem e aleatoria
D) O Azure decide a ordem baseado na dependencia

<details>
<summary>Ver resposta</summary>

**Resposta: B) Group 1 primeiro, depois Group 2, depois Group 3 (sequencial)**

Recovery Plans executam grupos em **sequencia numerica**. VMs dentro do mesmo grupo fazem failover em paralelo. Isso permite orquestrar a ordem correta: banco de dados primeiro, depois aplicacao, depois frontend.

</details>

---

# Bloco 4 - Monitor & Alerts

**Origem:** Lab 11 - Implement Monitoring
**Resource Groups utilizados:** `az104-rg-monitor` (Action Groups, Alert Rules) + `az104-rg7` (VMs da Semana 2)

## Contexto

Com backup e DR configurados (Blocos 1-3), voce agora implementa monitoramento proativo. Voce cria alertas para as VMs da Semana 2, configura Action Groups para notificacoes e explora metricas. Os alertas monitoram recursos criados desde a **Semana 1** (VNets, NSGs) ate a **Semana 2** (VMs, storage).

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Azure Monitor                                     │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Action Groups (az104-rg-monitor)                            │    │
│  │                                                              │    │
│  │  └─ az104-ag1: Email + SMS                                  │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Alert Rules                                                 │    │
│  │                                                              │    │
│  │  ├─ CPU Alert: az104-vm-win CPU > 80%                       │    │
│  │  │  (VM da Semana 2) → az104-ag1                            │    │
│  │  │                                                          │    │
│  │  ├─ VM Deleted Alert: Activity Log delete VM                │    │
│  │  │  (qualquer VM) → az104-ag1                               │    │
│  │  │                                                          │    │
│  │  └─ Backup Failed Alert: Recovery Services vault             │    │
│  │     (vault do Bloco 1) → az104-ag1                          │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Monitored Resources                                         │    │
│  │                                                              │    │
│  │  Semana 1: VNets, NSGs, DNS ─── metricas de rede            │    │
│  │  Semana 2: VMs, Storage ──────── metricas de compute/storage │    │
│  │  Semana 3: Vaults ────────────── metricas de backup          │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  → Usado no Bloco 5 para conectar Log Analytics workspace            │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Explorar metricas de VM

Voce explora as metricas da VM criada na Semana 2 para entender o baseline de performance.

1. Navegue para **az104-vm-win** (em az104-rg7, Semana 2)

2. No blade **Monitoring** > **Metrics**

3. Configure o grafico:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Scope      | **az104-vm-win**               |
   | Metric Namespace | **Virtual Machine Host** |
   | Metric     | **Percentage CPU**             |
   | Aggregation | **Avg**                       |

4. Observe o grafico de CPU — este e o baseline da VM

5. Clique em **+ Add metric** e adicione:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Metric     | **Network In Total**           |
   | Aggregation | **Sum**                       |

6. Clique em **+ Add metric** novamente:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Metric     | **Network Out Total**          |
   | Aggregation | **Sum**                       |

   > **Conexao com Semana 2:** As metricas de rede mostram o trafego das VMs que estao conectadas as VNets da Semana 1 e se comunicam via peering configurado naquela semana.

7. Altere o **Time range** para **Last 4 hours**

8. Clique em **Pin to dashboard** para salvar o grafico

   > **Conceito:** Azure Monitor coleta metricas automaticamente de todos os recursos Azure. Metricas **Host** (CPU, Network, Disk) estao disponiveis sem agente. Metricas **Guest** (memoria, processos) requerem o Azure Monitor Agent (configurado no Bloco 5).

---

### Task 4.2: Criar Action Group

1. Pesquise e selecione **Monitor** > **Alerts** > **Action groups** > **+ Create**

2. Aba **Basics**:

   | Setting        | Value                                    |
   | -------------- | ---------------------------------------- |
   | Subscription   | *sua subscription*                       |
   | Resource group | `az104-rg-monitor` (crie se necessario)  |
   | Action group name | `az104-ag1`                           |
   | Display name   | `az104-ag1`                              |

3. Aba **Notifications**:

   | Setting             | Value                                    |
   | ------------------- | ---------------------------------------- |
   | Notification type   | **Email/SMS message/Push/Voice**         |
   | Name                | `admin-notification`                     |
   | Email               | *seu email*                              |
   | SMS                 | *(opcional — marque e informe seu numero)*|

4. Aba **Actions**: pule por enquanto (sem automation neste lab)

5. Clique em **Review + create** > **Create**

6. Verifique seu email — voce deve receber uma confirmacao de que foi adicionado ao Action Group

   > **Conceito:** Action Groups definem QUEM e notificado e COMO quando um alerta dispara. Podem incluir emails, SMS, push notifications, voice calls, Azure Functions, Logic Apps, ITSM, webhooks e runbooks.

   > **Conexao com Bloco 5:** O mesmo Action Group sera reutilizado no Bloco 5 para alertas de Log Analytics.

---

### Task 4.3: Criar alerta de metrica (CPU alta)

Este alerta monitora a CPU da VM da Semana 2 e notifica via Action Group.

1. Pesquise e selecione **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: clique em **Select a resource**

   | Setting       | Value                        |
   | ------------- | ---------------------------- |
   | Filter by resource type | **Virtual machines** |
   | Resource      | **az104-vm-win** (az104-rg7) |

3. Clique em **Apply**

4. Aba **Condition**: clique em **See all signals** > selecione **Percentage CPU**

5. Configure:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Threshold       | **Static**           |
   | Aggregation type| **Average**          |
   | Operator        | **Greater than**     |
   | Threshold value | `80`                 |
   | Check every     | **5 minutes**        |
   | Lookback period | **5 minutes**        |

   > **Conexao com Semana 2:** Voce esta monitorando a mesma VM Windows da Semana 2. Se a carga de trabalho configurada naquela semana ultrapassar 80% de CPU, voce sera notificado automaticamente.

6. Clique em **Next: Actions**

7. Selecione **Select action groups** > **az104-ag1** > **Select**

8. Aba **Details**:

   | Setting                   | Value                                |
   | ------------------------- | ------------------------------------ |
   | Subscription              | *sua subscription*                   |
   | Resource group            | `az104-rg-monitor`                   |
   | Severity                  | **2 - Warning**                      |
   | Alert rule name           | `az104-vm-win-cpu-alert`             |
   | Alert rule description    | `Alert when CPU exceeds 80% on az104-vm-win` |
   | Enable upon creation      | **Checked**                          |

9. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de metrica avaliam metricas em intervalos regulares. Static threshold compara com um valor fixo. Dynamic threshold usa ML para detectar anomalias com base no padrao historico.

---

### Task 4.4: Criar alerta de Activity Log (VM deletada)

Este alerta dispara quando qualquer VM e deletada — protegendo recursos de todas as semanas.

1. Em **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: selecione **sua subscription** inteira (para cobrir todas as semanas)

3. Aba **Condition**: clique em **See all signals**

4. Filtre: **Signal type = Activity Log**

5. Selecione **Delete Virtual Machine (Microsoft.Compute/virtualMachines)**

6. Configure:

   | Setting    | Value                    |
   | ---------- | ------------------------ |
   | Chart period | **Over the last 6 hours** |
   | Event level  | **Informational** (ou All) |
   | Status       | **All**                 |
   | Event initiated by | *(deixe em branco)* |

7. Clique em **Next: Actions** > selecione **az104-ag1**

8. Aba **Details**:

   | Setting            | Value                                |
   | ------------------ | ------------------------------------ |
   | Severity           | **1 - Error**                        |
   | Alert rule name    | `az104-vm-deleted-alert`             |
   | Description        | `Alert when any VM is deleted`       |
   | Resource group     | `az104-rg-monitor`                   |

9. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de Activity Log monitoram operacoes de controle (create, delete, update) ao inves de metricas. Sao uteis para auditoria e compliance. Diferente de alertas de metrica, nao usam aggregation — disparam quando o evento ocorre.

   > **Conexao com Semanas 1-2:** Este alerta protege VMs de **todas** as semanas. Se alguem deletar uma VM (seja da Semana 2 ou qualquer outra), voce sera notificado imediatamente.

---

### Task 4.5: Disparar alerta de CPU (teste)

Voce gera carga na VM para testar o alerta de CPU.

1. Navegue para **az104-vm-win** > **Operations** > **Run command** > **RunPowerShellScript**

2. Execute o seguinte script para gerar carga de CPU:

   ```powershell
   # Gera carga de CPU por 5 minutos
   $duration = 300
   $end = (Get-Date).AddSeconds($duration)
   while ((Get-Date) -lt $end) {
       [Math]::Sqrt(rand)
   }
   ```

3. **Nao aguarde** o script terminar — va para o proximo passo

4. Navegue para **Monitor** > **Alerts**

5. Aguarde 5-10 minutos e verifique se o alerta de CPU disparou

6. Verifique seu email — voce deve receber a notificacao do Action Group

7. Clique no alerta para ver detalhes: metrica, threshold, timestamp

   > **Nota:** O alerta pode levar alguns minutos para avaliar e disparar. Se nao receber em 10 minutos, verifique a configuracao da alert rule e se a VM realmente atingiu 80% de CPU.

---

### Task 4.6: Explorar Azure Monitor Dashboard

1. Pesquise e selecione **Monitor**

2. Explore os blades:

   | Blade              | Descricao                                         |
   | ------------------ | ------------------------------------------------- |
   | **Overview**       | Resumo de alertas, metricas e servico health      |
   | **Activity Log**   | Operacoes de controle em todos os recursos         |
   | **Alerts**         | Alertas ativos e historico                         |
   | **Metrics**        | Explorer de metricas interativo                    |
   | **Diagnostic settings** | Configuracao de envio de logs/metricas        |
   | **Service Health** | Status dos servicos Azure na sua regiao            |

3. Em **Alerts**, revise os alertas disparados e resolvidos

4. Em **Activity Log**, filtre por **Resource group = az104-rg7** para ver operacoes nas VMs da Semana 2

   > **Conexao com Semanas 1-2:** O Activity Log mostra TODAS as operacoes feitas desde a Semana 1: criacao de VNets, deploy de VMs, atribuicao de RBAC, aplicacao de policies, habilitacao de backup, etc.

---

## Modo Desafio - Bloco 4

- [ ] Explorar metricas de CPU, Network In/Out da `az104-vm-win` **(Semana 2)**
- [ ] Criar Action Group `az104-ag1` com email (+ SMS opcional)
- [ ] Criar alerta de metrica: CPU > 80% na `az104-vm-win` → `az104-ag1`
- [ ] Criar alerta de Activity Log: VM deletada (subscription scope) → `az104-ag1`
- [ ] **Integracao:** Gerar carga de CPU na VM → verificar alerta disparado → checar email
- [ ] Explorar Azure Monitor: Activity Log, Alerts, Service Health

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa ser notificado quando a CPU de uma VM exceder 90% por mais de 10 minutos. Qual tipo de alerta e configuracao voce deve usar?**

A) Activity Log alert com filtro de CPU
B) Metric alert com Static threshold, aggregation Average, lookback period 10 minutes
C) Log query alert com KQL
D) Service Health alert

<details>
<summary>Ver resposta</summary>

**Resposta: B) Metric alert com Static threshold, aggregation Average, lookback period 10 minutes**

Alertas de metrica com static threshold sao ideais para monitorar limites conhecidos. Configure: metric = Percentage CPU, aggregation = Average, operator = Greater than, threshold = 90, lookback period = 10 minutes. Activity Log alerts monitoram operacoes, nao metricas.

</details>

### Questao 4.2
**Qual a diferenca entre um alerta de metrica e um alerta de Activity Log?**

A) Alertas de metrica monitoram performance, alertas de Activity Log monitoram operacoes de controle
B) Ambos monitoram a mesma coisa, mas com syntaxes diferentes
C) Alertas de Activity Log sao mais rapidos que alertas de metrica
D) Alertas de metrica requerem Log Analytics, Activity Log nao

<details>
<summary>Ver resposta</summary>

**Resposta: A) Alertas de metrica monitoram performance, alertas de Activity Log monitoram operacoes de controle**

- **Metric alerts:** Monitoram metricas numericas (CPU, memoria, latencia, throughput)
- **Activity Log alerts:** Monitoram operacoes de gerenciamento (create, delete, update, role assignments)
- **Log alerts:** Monitoram logs usando queries KQL (Bloco 5)

</details>

### Questao 4.3
**Um Action Group tem email e SMS configurados. Um alerta dispara. Quantas notificacoes sao enviadas?**

A) Apenas email (SMS e fallback)
B) Apenas SMS (mais rapido)
C) Ambos: email E SMS sao enviados simultaneamente
D) O usuario escolhe qual receber no momento do alerta

<details>
<summary>Ver resposta</summary>

**Resposta: C) Ambos: email E SMS sao enviados simultaneamente**

Todas as notificacoes e acoes configuradas em um Action Group sao executadas em paralelo quando um alerta dispara. Email, SMS, push, voice, webhooks, Azure Functions — todos sao acionados simultaneamente.

</details>

### Questao 4.4
**Voce quer criar um alerta que detecte automaticamente padroes anomalos de CPU, sem definir um threshold fixo. Que tipo de threshold voce deve usar?**

A) Static threshold com valor muito alto
B) Dynamic threshold (baseline automatico via ML)
C) Nao e possivel sem threshold fixo
D) Log query com anomaly detection

<details>
<summary>Ver resposta</summary>

**Resposta: B) Dynamic threshold (baseline automatico via ML)**

Dynamic thresholds usam machine learning para aprender o padrao historico da metrica e detectar desvios. Nao requerem que voce defina um valor fixo — o Azure determina automaticamente o que e "normal" e alerta quando detecta anomalias.

</details>

---

# Bloco 5 - Log Analytics & Network Watcher

**Origem:** Lab 11 (continuacao) + VM Insights + Network Watcher
**Resource Groups utilizados:** `az104-rg-monitor` (workspace) + `az104-rg7` (VMs da Semana 2) + `az104-rg4` (VNets da Semana 1)

## Contexto

O Azure Monitor coleta metricas basicas automaticamente, mas para observabilidade avancada voce precisa de **Log Analytics** (queries KQL), **VM Insights** (performance e dependencias) e **Network Watcher** (diagnostico de rede). Voce conecta tudo as VMs da Semana 2 e as VNets da Semana 1.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Log Analytics & Observabilidade                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Log Analytics Workspace: az104-law (az104-rg-monitor)       │    │
│  │                                                              │    │
│  │  Data Sources:                                               │    │
│  │  ├─ az104-vm-win  (Semana 2) ◄── Azure Monitor Agent       │    │
│  │  ├─ az104-vm-linux (Semana 2) ◄── Azure Monitor Agent      │    │
│  │  └─ Activity Log ◄── Diagnostic Settings                   │    │
│  │                                                              │    │
│  │  Queries (KQL):                                              │    │
│  │  ├─ Heartbeat: verificar conectividade dos agentes          │    │
│  │  ├─ Perf: metricas de CPU, memoria, disco                  │    │
│  │  ├─ Event: logs de eventos Windows                          │    │
│  │  └─ InsightsMetrics: dados de VM Insights                   │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  VM Insights                                                 │    │
│  │                                                              │    │
│  │  ├─ Performance: CPU, memoria, disco, rede das VMs          │    │
│  │  └─ Map: dependencias entre VMs e servicos                  │    │
│  │     ├─ az104-vm-win → conexoes de rede                      │    │
│  │     └─ az104-vm-linux → processos e portas                  │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Network Watcher (Semana 1 — VNets)                          │    │
│  │                                                              │    │
│  │  ├─ IP Flow Verify: testar NSG rules nas VNets              │    │
│  │  ├─ Next Hop: verificar routing (route tables da Semana 1)  │    │
│  │  ├─ Connection Troubleshoot: testar conectividade           │    │
│  │  │  (entre VMs da Semana 2 via VNets da Semana 1)           │    │
│  │  ├─ NSG Flow Logs: trafego nos NSGs da Semana 1             │    │
│  │  └─ Topology: visualizar VNets + subnets + NSGs + VMs      │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  → Integra recursos de TODAS as semanas (1, 2 e 3)                   │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Log Analytics Workspace

1. Pesquise e selecione **Log Analytics workspaces** > **+ Create**

2. Configure:

   | Setting        | Value                                  |
   | -------------- | -------------------------------------- |
   | Subscription   | *sua subscription*                     |
   | Resource group | `az104-rg-monitor`                     |
   | Name           | `az104-law`                            |
   | Region         | **East US**                            |

3. Clique em **Review + Create** > **Create** > **Go to resource**

4. Explore o blade **General** > **Usage and estimated costs**

   > **Conceito:** O Log Analytics Workspace e o repositorio central de logs no Azure Monitor. Todos os dados (metricas guest, logs, eventos) sao enviados para ca e consultados via KQL (Kusto Query Language).

   > **Conexao com Bloco 4:** O workspace complementa os alertas do Bloco 4. Alertas de metrica monitoram valores em tempo real; Log Analytics permite analise historica e correlacao de eventos.

---

### Task 5.2: Conectar VMs ao workspace (Azure Monitor Agent)

Voce habilita a coleta de logs e metricas guest das VMs da Semana 2.

1. No workspace **az104-law**, va para **Settings** > **Agents**

2. Note as instrucoes de instalacao para Windows e Linux

3. **Metodo alternativo (recomendado):** Habilitar via VM Insights (Task 5.3) que instala o agente automaticamente

   > **Conceito:** O Azure Monitor Agent (AMA) substitui os agentes legados (MMA/OMS e Dependency Agent). O AMA usa **Data Collection Rules (DCR)** para definir quais dados coletar e para onde enviar.

**Criar Data Collection Rule:**

4. Pesquise e selecione **Monitor** > **Settings** > **Data Collection Rules** > **+ Create**

5. Aba **Basics**:

   | Setting        | Value                    |
   | -------------- | ------------------------ |
   | Rule Name      | `az104-dcr`              |
   | Subscription   | *sua subscription*       |
   | Resource Group | `az104-rg-monitor`       |
   | Region         | **East US**              |
   | Platform Type  | **All**                  |

6. Aba **Resources**: clique em **+ Add resources**

7. Expanda `az104-rg7` > selecione **az104-vm-win** e **az104-vm-linux**

   > **Conexao com Semana 2:** Voce esta conectando as VMs criadas na Semana 2 ao workspace de Log Analytics. O agente sera instalado automaticamente nas VMs selecionadas.

8. Clique em **Apply**

9. Aba **Collect and deliver** > **+ Add data source**:

   **Data Source 1 — Performance Counters:**

   | Setting     | Value                      |
   | ----------- | -------------------------- |
   | Data source type | **Performance Counters** |
   | Configure   | **Basic** (CPU, Memory, Disk, Network) |

   Destination: **Azure Monitor Logs** > `az104-law`

10. **+ Add data source** novamente:

    **Data Source 2 — Windows Event Logs:**

    | Setting     | Value                      |
    | ----------- | -------------------------- |
    | Data source type | **Windows Event Logs** |
    | Configure   | **Basic** (Application: Critical, Error, Warning; System: Critical, Error, Warning) |

    Destination: **Azure Monitor Logs** > `az104-law`

11. Clique em **Review + create** > **Create**

12. Aguarde alguns minutos para o agente ser instalado nas VMs

---

### Task 5.3: Habilitar VM Insights

1. Navegue para **az104-vm-win** (em az104-rg7)

2. No blade **Monitoring** > **Insights**

3. Clique em **Enable**

4. Configure:

   | Setting                              | Value           |
   | ------------------------------------ | --------------- |
   | Log Analytics Workspace              | `az104-law`     |
   | Data collection rule (if prompted)   | `az104-dcr` ou crie uma nova |

5. Clique em **Configure** > aguarde o deployment

6. Repita para **az104-vm-linux**:
   - Navegue para **az104-vm-linux** > **Monitoring** > **Insights** > **Enable** > configure com `az104-law`

   > **Conexao com Semana 2:** VM Insights mostra performance detalhada e mapa de dependencias das VMs. Voce podera ver como as VMs da Semana 2 se comunicam entre si e com outros servicos via as VNets da Semana 1.

7. Aguarde 5-10 minutos para dados comecarem a fluir

8. Volte para **az104-vm-win** > **Monitoring** > **Insights**

9. Explore as abas:
   - **Performance:** CPU, memoria, disco, rede (metricas guest via agente)
   - **Map:** dependencias de rede, processos, portas

   > **Conceito:** VM Insights usa o Azure Monitor Agent para coletar metricas de performance e o Dependency Agent para mapear conexoes de rede. O Map mostra processos, portas e conexoes entre VMs e servicos externos.

---

### Task 5.4: Executar queries KQL no Log Analytics

1. Navegue para **az104-law** > **General** > **Logs**

2. Feche o dialog de queries pre-built (se aparecer)

3. Execute as queries abaixo, uma por vez:

**Query 1 — Heartbeat (verificar agentes conectados):**

```kql
Heartbeat
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| project Computer, LastHeartbeat, MinutesSinceLastHeartbeat = datetime_diff('minute', now(), max_TimeGenerated)
```

4. Verifique que ambas as VMs aparecem (az104-vm-win e az104-vm-linux)

**Query 2 — Performance de CPU (ultimas 4 horas):**

```kql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where TimeGenerated > ago(4h)
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

5. Observe o grafico de CPU de ambas as VMs

**Query 3 — Eventos de erro Windows:**

```kql
Event
| where EventLevelName == "Error"
| where TimeGenerated > ago(24h)
| summarize ErrorCount = count() by Source, Computer
| order by ErrorCount desc
| take 10
```

**Query 4 — Top processos por CPU (VM Insights):**

```kql
InsightsMetrics
| where Name == "UtilizationPercentage"
| where TimeGenerated > ago(1h)
| summarize AvgCPU = avg(Val) by bin(TimeGenerated, 5m), Computer
| render timechart
```

> **Conceito:** KQL (Kusto Query Language) e a linguagem de consulta do Azure Monitor. Ela permite filtrar, agregar, correlacionar e visualizar dados de logs e metricas.

> **Dica AZ-104:** Na prova, voce pode ver queries KQL basicas. Foque em operadores: `where`, `summarize`, `project`, `render`, `ago()`, `bin()`.

---

### Task 5.5: Configurar Diagnostic Settings para Activity Log

Voce envia o Activity Log para o workspace, permitindo queries KQL sobre operacoes de gerenciamento de todas as semanas.

1. Pesquise e selecione **Monitor** > **Activity Log**

2. Clique em **Export Activity Logs**

3. Clique em **+ Add diagnostic setting**

4. Configure:

   | Setting                     | Value                          |
   | --------------------------- | ------------------------------ |
   | Diagnostic setting name     | `az104-activity-to-law`        |
   | Log categories              | **Selecione todas** (Administrative, Security, ServiceHealth, Alert, etc.) |
   | Destination: Send to Log Analytics workspace | **Checked**  |
   | Subscription                | *sua subscription*             |
   | Log Analytics workspace     | `az104-law`                    |

5. Clique em **Save**

   > **Conexao com Semanas 1-2:** Agora, TODAS as operacoes de gerenciamento (criacao de VNets na Semana 1, deploy de VMs na Semana 2, habilitacao de backup na Semana 3) sao enviadas para o workspace e podem ser analisadas via KQL.

6. Aguarde alguns minutos e execute a query:

```kql
AzureActivity
| where TimeGenerated > ago(1h)
| summarize count() by OperationNameValue, ActivityStatusValue
| order by count_ desc
| take 20
```

---

### Task 5.6: Network Watcher — IP Flow Verify

Voce usa o Network Watcher para diagnosticar regras NSG nas VNets da Semana 1.

1. Pesquise e selecione **Network Watcher**

2. Em **Network diagnostic tools** > **IP flow verify**

3. Configure:

   | Setting              | Value                                    |
   | -------------------- | ---------------------------------------- |
   | Subscription         | *sua subscription*                       |
   | Resource group       | `az104-rg7`                              |
   | Virtual machine      | **az104-vm-win**                         |
   | Network interface    | *selecione a NIC da VM*                  |
   | Protocol             | **TCP**                                  |
   | Direction            | **Inbound**                              |
   | Local port           | `3389`                                   |
   | Remote IP address    | `10.20.10.5` (IP simulado na SharedServicesSubnet da Semana 1) |
   | Remote port          | `*`                                      |

4. Clique em **Check**

5. Observe o resultado: **Allowed** ou **Denied** e qual NSG rule causou

   > **Conexao com Semana 1:** O IP Flow Verify testa as regras dos NSGs criados na Semana 1 (ex: myNSGSecure associado a SharedServicesSubnet). Voce pode verificar se as regras configuradas naquela semana estao permitindo ou bloqueando o trafego esperado.

---

### Task 5.7: Network Watcher — Next Hop

1. Em **Network Watcher** > **Network diagnostic tools** > **Next hop**

2. Configure:

   | Setting              | Value                                    |
   | -------------------- | ---------------------------------------- |
   | Subscription         | *sua subscription*                       |
   | Resource group       | `az104-rg7`                              |
   | Virtual machine      | **az104-vm-win**                         |
   | Network interface    | *selecione a NIC da VM*                  |
   | Source IP address    | *IP privado da az104-vm-win*             |
   | Destination IP address | `10.30.0.4` (IP simulado na ManufacturingVnet da Semana 1) |

3. Clique em **Next hop**

4. Observe o resultado:

   | Resultado esperado | Significado                              |
   | ------------------ | ---------------------------------------- |
   | **VNet peering**   | Trafego roteado via peering (Semana 1)   |
   | **Virtual appliance** | Trafego roteado via NVA (se route table ativa) |
   | **Internet**       | Sem rota especifica — vai para internet  |
   | **None**           | Trafego descartado                       |

   > **Conexao com Semana 1:** O Next Hop mostra como as route tables e peerings configurados na Semana 1 afetam o trafego. Se voce configurou UDRs com next hop "Virtual appliance", o resultado mostrara isso.

---

### Task 5.8: Network Watcher — Connection Troubleshoot (cross-VNet)

1. Em **Network Watcher** > **Network diagnostic tools** > **Connection troubleshoot**

2. Configure:

   | Setting              | Value                        |
   | -------------------- | ---------------------------- |
   | Source type          | **Virtual machine**          |
   | Virtual machine      | **az104-vm-win**             |
   | Destination type     | **Specify manually**         |
   | URI, FQDN or IP address | *IP privado de az104-vm-linux* |
   | Destination port     | `22` (SSH)                   |
   | Protocol             | **TCP**                      |

3. Clique em **Check**

4. Observe: **Reachable** ou **Unreachable** e o caminho completo (hops)

   > **Conexao com Semanas 1-2:** Este teste verifica a comunicacao entre VMs da Semana 2 usando a infraestrutura de rede da Semana 1 (VNets, peering, NSGs, route tables). O Network Watcher mostra cada hop no caminho, incluindo NSGs e route tables.

---

### Task 5.9: Network Watcher — Topology

1. Em **Network Watcher** > **Monitoring** > **Topology**

2. Configure:

   | Setting        | Value                    |
   | -------------- | ------------------------ |
   | Subscription   | *sua subscription*       |
   | Resource Group | `az104-rg4` (VNets da Semana 1) |

3. Observe o diagrama visual mostrando:
   - VNets e suas subnets
   - NSGs associados as subnets
   - NICs e VMs (se no mesmo RG)

4. Troque para `az104-rg7` e observe as VMs da Semana 2 e suas conexoes de rede

   > **Conceito:** O Topology fornece uma visualizacao grafica da infraestrutura de rede. E util para entender a arquitetura e identificar gaps de seguranca (subnets sem NSG, etc.).

   > **Conexao com Semana 1:** A topologia mostra a arquitetura de rede completa que voce construiu na Semana 1: VNets, subnets, NSGs, peerings — tudo em um diagrama interativo.

---

### Task 5.10: Criar alerta de log query (KQL)

Voce cria um alerta baseado em query KQL que dispara quando VMs param de enviar heartbeats.

1. Em **Monitor** > **Alerts** > **+ Create** > **Alert rule**

2. Aba **Scope**: selecione o workspace **az104-law**

3. Aba **Condition**: clique em **See all signals** > filtre por **Custom log search**

4. Na query, insira:

   ```kql
   Heartbeat
   | summarize LastHeartbeat = max(TimeGenerated) by Computer
   | where LastHeartbeat < ago(5m)
   ```

5. Configure:

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Measurement        | **Table rows**           |
   | Aggregation type   | **Count**                |
   | Threshold operator | **Greater than**         |
   | Threshold value    | `0`                      |
   | Frequency          | **5 minutes**            |
   | Lookback period    | **5 minutes**            |

6. Clique em **Next: Actions** > selecione **az104-ag1** (do Bloco 4)

   > **Conexao com Bloco 4:** Voce reutiliza o mesmo Action Group criado no Bloco 4, demonstrando que Action Groups sao reutilizaveis entre diferentes tipos de alertas.

7. Aba **Details**:

   | Setting            | Value                                    |
   | ------------------ | ---------------------------------------- |
   | Severity           | **1 - Error**                            |
   | Alert rule name    | `az104-vm-heartbeat-lost`                |
   | Description        | `Alert when VM stops sending heartbeats` |
   | Resource group     | `az104-rg-monitor`                       |

8. Clique em **Review + create** > **Create**

   > **Conceito:** Alertas de log query (Custom Log Search) executam queries KQL periodicamente. Quando a query retorna resultados que atendem ao threshold, o alerta dispara. Sao mais flexiveis que alertas de metrica, mas tem maior latencia (frequencia minima de 5 minutos).

---

## Modo Desafio - Bloco 5

- [ ] Criar Log Analytics Workspace `az104-law` em `az104-rg-monitor`
- [ ] Criar Data Collection Rule `az104-dcr` conectando VMs **(Semana 2)** ao workspace
- [ ] Habilitar VM Insights em `az104-vm-win` e `az104-vm-linux` **(Semana 2)**
- [ ] Executar queries KQL: Heartbeat, Perf (CPU), Events, InsightsMetrics
- [ ] Configurar Diagnostic Settings: Activity Log → `az104-law`
- [ ] **Integracao:** Network Watcher — IP Flow Verify nos NSGs **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Next Hop verificando routing **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Connection Troubleshoot entre VMs **(Semana 2)** via VNets **(Semana 1)**
- [ ] **Integracao:** Network Watcher — Topology das VNets **(Semana 1)**
- [ ] Criar alerta de log query (heartbeat lost) → reutilizar `az104-ag1` **(Bloco 4)**

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Voce precisa coletar metricas de memoria de uma VM Azure. As metricas de memoria nao aparecem em Azure Monitor Metrics. O que esta faltando?**

A) Metricas de memoria nao sao suportadas no Azure
B) O Azure Monitor Agent precisa ser instalado na VM para coletar metricas guest (incluindo memoria)
C) Voce precisa habilitar Boot Diagnostics
D) Voce precisa usar Premium storage

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Azure Monitor Agent precisa ser instalado na VM para coletar metricas guest (incluindo memoria)**

Azure Monitor coleta automaticamente metricas **host** (CPU, Network, Disk IO) sem agente. Metricas **guest** (memoria, processos, logs do SO) requerem o Azure Monitor Agent (AMA) com Data Collection Rules configuradas.

</details>

### Questao 5.2
**Voce executa a query KQL `Heartbeat | summarize count() by Computer` no Log Analytics. O que esta query retorna?**

A) A quantidade total de heartbeats de todas as VMs juntas
B) A quantidade de heartbeats agrupada por cada computador (VM)
C) O timestamp do ultimo heartbeat de cada VM
D) Uma lista de VMs com problemas de heartbeat

<details>
<summary>Ver resposta</summary>

**Resposta: B) A quantidade de heartbeats agrupada por cada computador (VM)**

O operador `summarize count() by Computer` conta os registros e agrupa por valor unico de Computer. Cada linha do resultado mostra o nome da VM e a quantidade de heartbeats.

</details>

### Questao 5.3
**Voce usou IP Flow Verify no Network Watcher para testar conectividade a uma VM. O resultado mostra "Access denied" pela regra "DenyAllInBound". O que isso significa?**

A) A VM esta desligada
B) Nao ha regra NSG que permita o trafego — a regra default DenyAllInBound esta bloqueando
C) O firewall da VM esta bloqueando
D) O Network Watcher esta com problema

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao ha regra NSG que permita o trafego — a regra default DenyAllInBound esta bloqueando**

A regra DenyAllInBound (priority 65500) e a regra default que bloqueia todo trafego inbound nao explicitamente permitido. Se essa regra esta sendo acionada, significa que nenhuma regra com priority menor (maior prioridade) permite o trafego testado.

</details>

### Questao 5.4
**Voce quer identificar gargalos de rede entre duas VMs em VNets diferentes com peering. Qual ferramenta do Network Watcher e mais adequada?**

A) IP Flow Verify
B) Connection Troubleshoot
C) NSG Flow Logs
D) VPN Troubleshoot

<details>
<summary>Ver resposta</summary>

**Resposta: B) Connection Troubleshoot**

Connection Troubleshoot testa a conectividade de ponta a ponta entre dois endpoints, mostrando cada hop no caminho, latencia e se a conexao e bem-sucedida. IP Flow Verify testa apenas regras NSG em uma NIC. NSG Flow Logs capturam trafego para analise posterior.

</details>

### Questao 5.5
**Qual e a diferenca entre Data Collection Rules (DCR) e Diagnostic Settings no Azure Monitor?**

A) DCR coleta dados de VMs (guest), Diagnostic Settings coleta dados de recursos Azure (platform)
B) Sao a mesma coisa com nomes diferentes
C) DCR e para Log Analytics, Diagnostic Settings e para Storage Account
D) DCR e o antigo, Diagnostic Settings e o novo

<details>
<summary>Ver resposta</summary>

**Resposta: A) DCR coleta dados de VMs (guest), Diagnostic Settings coleta dados de recursos Azure (platform)**

- **Data Collection Rules (DCR):** Usadas com o Azure Monitor Agent para coletar dados de dentro das VMs (metricas guest, logs do SO, eventos)
- **Diagnostic Settings:** Configuradas em recursos Azure (VMs, Storage, VNets, etc.) para enviar metricas de plataforma e logs de recurso para destinos (Log Analytics, Storage, Event Hub)

</details>

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente VMs e replicacao do Site Recovery.

## Ordem de cleanup (PRIORIDADE por custo)

1. **Site Recovery primeiro** (replicacao gera custo contínuo)
2. **VMs** (compute e o maior custo)
3. **Vaults** (requerem que items sejam removidos primeiro)
4. **Demais recursos**

## Via Azure Portal

1. **Desabilitar replicacao (Site Recovery):**
   - `az104-rsv-dr` > Replicated items > az104-vm-win > **Disable replication** > confirme
   - Aguarde o job completar

2. **Parar backup e deletar dados:**
   - `az104-rsv` > Backup items > Azure Virtual Machine > selecione cada VM > **Stop backup** > **Delete backup data** > confirme
   - `az104-rsv` > Backup items > Azure File Share > selecione az104-share > **Stop backup** > **Delete backup data** > confirme

3. **Deletar vaults** (so funciona apos remover todos os items):
   - `az104-rsv-dr` > **Delete** (vault de DR)
   - `az104-rsv` > **Delete** (vault de backup)

4. **Deletar Resource Groups:**
   - `az104-rg-dr` (Site Recovery)
   - `az104-rg-backup` (vault de backup)
   - `az104-rg-monitor` (Log Analytics, alerts, action groups)

5. **Reverter configuracoes nos recursos das semanas anteriores:**
   - Storage account (az104-rg6): desabilitar soft delete e versioning se desejar
   - VMs (az104-rg7): desinstalar Azure Monitor Agent se desejar

6. **Deletar auto-created resource groups** (Site Recovery):
   - `az104-rg7-asr` (se foi criado pelo ASR)

## Via CLI

> **Nota:** Remova Site Recovery e backup items **antes** de deletar os vaults. Vaults com items protegidos nao podem ser deletados.

```bash
# ============================================================
# CLEANUP - Descoberta dinamica de nomes internos
# ============================================================

VAULT_NAME="az104-rsv"
VAULT_DR="az104-rsv-dr"
RG_BACKUP="az104-rg-backup"
RG_DR="az104-rg-dr"
RG_MONITOR="az104-rg-monitor"

# 1. Desabilitar replicacao (Site Recovery)
#    NOTA: ASR cleanup via CLI e complexo. Recomenda-se usar o Portal:
#    Recovery Services Vault > Replicated Items > selecionar > Disable Replication
#    Se preferir CLI, use az rest com a API REST do ASR:
echo "Passo 1: Desabilite a replicacao ASR via Portal antes de continuar."
echo "         Vault: $VAULT_DR > Replicated Items > Disable Replication"
read -p "Pressione Enter apos desabilitar a replicacao no Portal..."

# 2. Desabilitar backup de VMs (descoberta dinamica dos nomes internos)
echo "Desabilitando backup de VMs..."
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
  --backup-management-type AzureIaasVM \
  --query "[].name" -o tsv 2>/dev/null); do

  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureIaasVM \
    --query "[].name" -o tsv 2>/dev/null); do

    echo "  Desabilitando: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" \
      --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" \
      -g "$RG_BACKUP" \
      --backup-management-type AzureIaasVM \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 3. Desabilitar backup de File Shares (descoberta dinamica)
echo "Desabilitando backup de File Shares..."
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
  --backup-management-type AzureStorage \
  --query "[].name" -o tsv 2>/dev/null); do

  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG_BACKUP" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureStorage \
    --query "[].name" -o tsv 2>/dev/null); do

    echo "  Desabilitando: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" \
      --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" \
      -g "$RG_BACKUP" \
      --backup-management-type AzureStorage \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 4. Deletar vaults (so funciona apos desabilitar todas as protecoes)
echo "Deletando vaults..."
az backup vault delete -g "$RG_BACKUP" --name "$VAULT_NAME" --yes 2>/dev/null
az backup vault delete -g "$RG_DR" --name "$VAULT_DR" --yes 2>/dev/null

# 5. Deletar Resource Groups
echo "Deletando Resource Groups..."
az group delete --name "$RG_DR" --yes --no-wait
az group delete --name "$RG_BACKUP" --yes --no-wait
az group delete --name "$RG_MONITOR" --yes --no-wait

# 6. Deletar RGs auto-created pelo ASR (se existirem)
az group delete --name az104-rg7-asr --yes --no-wait 2>/dev/null

echo "Cleanup concluido. RGs sendo deletados em background."
```

## Via PowerShell

```powershell
# 1. Desabilitar replicacao (recomenda-se portal para este passo)

# 2. Parar backup
$vault = Get-AzRecoveryServicesVault -ResourceGroupName az104-rg-backup -Name az104-rsv
Set-AzRecoveryServicesVaultContext -Vault $vault
$backupItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
foreach ($item in $backupItems) {
    Disable-AzRecoveryServicesBackupProtection -Item $item -RemoveRecoveryPoints -Force
}

# 3. Deletar vaults
Remove-AzRecoveryServicesVault -Vault $vault

# 4. Deletar Resource Groups
Remove-AzResourceGroup -Name az104-rg-dr -Force -AsJob
Remove-AzResourceGroup -Name az104-rg-backup -Force -AsJob
Remove-AzResourceGroup -Name az104-rg-monitor -Force -AsJob

# 5. Deletar RGs auto-created
Remove-AzResourceGroup -Name az104-rg7-asr -Force -AsJob -ErrorAction SilentlyContinue

# 6. Remover diagnostic settings
$subscriptionId = (Get-AzContext).Subscription.Id
Remove-AzDiagnosticSetting -Name az104-activity-to-law -ResourceId "/subscriptions/$subscriptionId"
```

> **Nota:** Nao delete os resource groups das semanas anteriores (`az104-rg4` a `az104-rg7`) a menos que nao precise mais dos recursos. O cleanup desta semana remove apenas o que foi criado na Semana 3.

---

# Key Takeaways Consolidados

## Bloco 1 - VM Backup
- **Recovery Services Vault** centraliza backup de VMs, file shares e Site Recovery
- **Backup policies** definem frequencia e retencao; Enhanced policy suporta frequencia horaria (4/6/8/12h)
- **Instant Restore** usa snapshots locais para restauracao rapida (minutos)
- **Restore options:** Create VM, Restore disk, Replace existing, Cross Region Restore
- Backup on-demand permite retencao independente da policy
- O Azure instala a extensao de backup **automaticamente** na VM

## Bloco 2 - File & Blob Protection
- **File share backup** usa share snapshots armazenados **na propria storage account** (nao no vault)
- **Item Level Restore** permite restaurar arquivos individuais sem restaurar o share inteiro
- **Soft delete** protege contra exclusao acidental (mantem dados por X dias)
- **Versioning** protege contra sobrescrita acidental (cria nova versao a cada modificacao)
- Combinados (backup + soft delete + versioning), oferecem **protecao em camadas** contra diferentes cenarios

## Bloco 3 - Site Recovery (DR)
- **Vault de DR** fica na regiao de **destino**, nao na regiao de origem
- **RPO** = perda de dados maxima aceitavel; **RTO** = tempo para restaurar o servico
- **Test Failover** valida DR sem afetar producao — sempre faca cleanup depois
- **Recovery Plans** orquestram failover em grupos sequenciais com scripts pre/pos
- Backup e Site Recovery sao **complementares**: backup protege dados, ASR protege disponibilidade

## Bloco 4 - Monitor & Alerts
- **Metric alerts** monitoram valores numericos (CPU, latencia); **Activity Log alerts** monitoram operacoes
- **Static threshold** compara com valor fixo; **Dynamic threshold** usa ML para detectar anomalias
- **Action Groups** definem QUEM/COMO notificar — reutilizaveis entre alertas
- Todas as notificacoes de um Action Group sao executadas **em paralelo**
- Azure Monitor coleta metricas **host** automaticamente; metricas **guest** requerem agente

## Bloco 5 - Log Analytics & Network Watcher
- **Log Analytics Workspace** e o repositorio central de logs — consultas via KQL
- **Azure Monitor Agent (AMA)** + **Data Collection Rules (DCR)** substituem os agentes legados
- **VM Insights** oferece performance detalhada + mapa de dependencias
- **Network Watcher:** IP Flow Verify (NSG), Next Hop (routing), Connection Troubleshoot (conectividade), Topology (visualizacao)
- **Diagnostic Settings** enviam dados de plataforma; **DCR** enviam dados guest
- KQL basico para prova: `where`, `summarize`, `project`, `render`, `ago()`, `bin()`

## Integracao Geral (Semanas 1-3)
- **Semana 1 (IAM/Gov/Net)** criou a base: identidade, governanca, rede
- **Semana 2 (Storage/Compute)** implantou cargas de trabalho: VMs, storage, apps
- **Semana 3 (Backup/Monitor)** protege e observa tudo que foi construido
- **Backup** (Blocos 1-2) protege dados das VMs e storage da Semana 2
- **Site Recovery** (Bloco 3) garante disponibilidade das VMs da Semana 2 em caso de falha regional
- **Monitor** (Bloco 4) monitora proativamente recursos de TODAS as semanas
- **Log Analytics + Network Watcher** (Bloco 5) integra observabilidade das VMs (Semana 2) com diagnostico de rede (Semana 1)
- **Tudo se conecta:** um alerta de CPU (Bloco 4) monitora uma VM (Semana 2) em uma VNet (Semana 1), com backup (Bloco 1) e DR (Bloco 3) prontos para proteger, e Log Analytics (Bloco 5) correlacionando eventos de todo o ambiente
