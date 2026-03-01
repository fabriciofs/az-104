> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 2 - File & Blob Protection](bloco2-file-blob.md)

# Bloco 1 - VM Backup

**Origem:** Lab 10 - Backup Virtual Machines
**Resource Groups utilizados:** `az104-rg-backup` (Recovery Services Vault) + `az104-rg7` (VMs da Semana 2)

## Contexto

Na Semana 2, voce criou VMs Windows (`az104-vm-win`) e Linux (`az104-vm-linux`) no resource group `az104-rg7`. Agora voce precisa proteger essas VMs com backup. O Recovery Services Vault criado aqui sera reutilizado no **Bloco 2** (backup de file shares) e no **Bloco 3** (Site Recovery).

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                    az104-rg-backup                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          Recovery Services Vault: az104-rsv                  │  │
│  │                                                              │  │
│  │  Backup Policies:                                            │  │
│  │  ├─ DefaultPolicy (built-in, daily)                          │  │
│  │  └─ az104-backup-policy (custom, 12h frequency)              │  │
│  │                                                              │  │
│  │  Protected Items:                                            │  │
│  │  ├─ az104-vm-win  (Semana 2, az104-rg7) ◄── Custom policy    │  │
│  │  └─ az104-vm-linux (Semana 2, az104-rg7) ◄── Default policy  │  │
│  │                                                              │  │
│  │  → Reutilizado no Bloco 2 (File Share backup)                │  │
│  │  → Reutilizado no Bloco 3 (Site Recovery)                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│    ┌──────────────────────────────────────────────────────────┐    │
│    │  az104-rg7 (Semana 2 — VMs)                              │    │
│    │                                                          │    │
│    │  ├─ az104-vm-win  (Windows Server) ─── backup ativo ✓    │    │
│    │  └─ az104-vm-linux (Ubuntu) ────────── backup ativo ✓    │    │
│    └──────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Recovery Services Vault

O vault centraliza backups de VMs, file shares e configuracoes de Site Recovery. Voce usara este mesmo vault nos **Blocos 2 e 3**.

> **Cobranca:** O vault em si e gratuito, mas cada instancia protegida (VM, File Share) gera cobranca.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Recovery Services vaults** > **+ Create**

3. Preencha as configuracoes:

   | Setting        | Value                                  |
   | -------------- | -------------------------------------- |
   | Subscription   | *sua subscription*                     |
   | Resource group | `az104-rg-backup` (crie se necessario) |
   | Vault name     | `az104-rsv`                            |
   | Region         | **East US**                            |

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

   | Setting              | Value                                            |
   | -------------------- | ------------------------------------------------ |
   | Policy name          | `az104-backup-policy`                            |
   | Frequency            | **Every 12 hours** (Hourly)                      |
   | Time                 | `6:00 AM`                                        |
   | Timezone             | **(UTC-03:00) Brasilia**                         |
   | Instant Restore      | Retain for **2** day(s)                          |
   | Daily backup point   | Retain for **180** days                          |
   | Weekly backup point  | **Enabled** — Sunday, retain **12** weeks        |
   | Monthly backup point | **Enabled** — First Sunday, retain **12** months |

   > **Conceito:** Instant Restore usa snapshots locais para restauracao rapida (minutos). Daily/Weekly/Monthly sao pontos de retencao de longo prazo armazenados no vault.

5. Clique em **Create**

6. Verifique que **az104-backup-policy** aparece na lista junto com **DefaultPolicy**

   > **Dica AZ-104:** Na prova, atente para os limites de retencao: daily (9999 dias), weekly (5163 semanas), monthly (1188 meses), yearly (99 anos).

---

### Task 1.3: Habilitar backup para az104-vm-win (custom policy)

Voce protege a VM Windows da Semana 2 usando a policy customizada.

> **Cobranca:** Habilitar backup gera cobranca por instancia protegida e armazenamento de snapshots.

> **Pre-requisito:** A VM `az104-vm-win` deve existir no `az104-rg7` (criada na Semana 2). Se nao existir, crie uma VM Windows Server basica nesse RG antes de continuar.

1. No vault **az104-rsv**, va para **Getting started** > **Backup**

2. Configure:

   | Setting                         | Value               |
   | ------------------------------- | ------------------- |
   | Where is your workload running? | **Azure**           |
   | What do you want to back up?    | **Virtual machine** |

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

   | Setting                         | Value               |
   | ------------------------------- | ------------------- |
   | Where is your workload running? | **Azure**           |
   | What do you want to back up?    | **Virtual machine** |

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

   | Setting            | Value                                         |
   | ------------------ | --------------------------------------------- |
   | Retain Backup Till | *aceite o default (30 dias a partir de hoje)* |

5. Clique em **OK**

6. Monitore o progresso em **Monitoring** > **Backup Jobs**

   > **Conceito:** O primeiro backup (full) pode levar mais tempo. Backups subsequentes sao incrementais. O job passa por fases: Snapshot → Transfer data to vault.

7. Aguarde ate o status mudar para **Completed** (pode levar 20-30 minutos)

   > **Dica AZ-104:** Na prova, saiba diferenciar: backup on-demand vs scheduled, full vs incremental, snapshot vs vault tier.

---

### Task 1.6: Verificar backup items e restore points

1. No vault **az104-rsv** > **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Verifique que ambas as VMs aparecem:

   | VM             | Policy              | Last Backup Status |
   | -------------- | ------------------- | ------------------ |
   | az104-vm-win   | az104-backup-policy | Completed          |
   | az104-vm-linux | DefaultPolicy       | Warning (initial)  |

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

   | Setting          | Value                                                  |
   | ---------------- | ------------------------------------------------------ |
   | Staging Location | *selecione um storage account existente (da Semana 2)* |
   | Resource Group   | `az104-rg-backup`                                      |

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

