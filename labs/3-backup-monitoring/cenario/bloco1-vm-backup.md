> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 2 - File & Blob Protection](bloco2-file-blob.md)

# Bloco 1 - VM Backup

**Origem:** Lab 10 - Backup Virtual Machines
**Resource Groups utilizados:** `rg-contoso-management` (Recovery Services Vault) + `rg-contoso-compute` (VMs da Semana 2)

## Contexto

Na Semana 2, voce criou VMs Windows (`vm-web-01`) e Linux (`vm-api-01`) no resource group `rg-contoso-compute`. Agora voce precisa proteger essas VMs com backup. O Recovery Services Vault criado aqui sera reutilizado no **Bloco 2** (backup de file shares) e no **Bloco 3** (Site Recovery).

## Diagrama

```
┌────────────────────────────────────────────────────────────────────────┐
│                    rg-contoso-management                               │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │          Recovery Services Vault: rsv-contoso-backup             │  │
│  │                                                                  │  │
│  │  Backup Policies:                                                │  │
│  │  ├─ DefaultPolicy (built-in, daily)                              │  │
│  │  └─ rsvpol-contoso-12h (custom, 12h frequency)                   │  │
│  │                                                                  │  │
│  │  Protected Items:                                                │  │
│  │  ├─ vm-web-01  (Semana 2, rg-contoso-compute) ◄── Custom policy  │  │
│  │  └─ vm-api-01 (Semana 2, rg-contoso-compute) ◄── Default policy  │  │
│  │                                                                  │  │
│  │  → Reutilizado no Bloco 2 (File Share backup)                    │  │
│  │  → Reutilizado no Bloco 3 (Site Recovery)                        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│    ┌──────────────────────────────────────────────────────────────┐    │
│    │  rg-contoso-compute (Semana 2 — VMs)                         │    │
│    │                                                              │    │
│    │  ├─ vm-web-01  (Windows Server) ─── backup ativo ✓           │    │
│    │  └─ vm-api-01 (Ubuntu) ────────── backup ativo ✓             │    │
│    └──────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Recovery Services Vault

O Recovery Services Vault e o "cofre" central onde o Azure armazena e gerencia backups. Pense nele como um cofre de banco: voce guarda copias de seguranca dos seus recursos e define regras de retencao. Tudo — VMs, file shares e configuracoes de DR — pode ser gerenciado a partir de um unico vault.

O vault criado aqui sera reutilizado nos **Blocos 2 e 3**, entao ele e a base de toda a estrategia de protecao.

> **Cobranca:** O vault em si e gratuito, mas cada instancia protegida (VM, File Share) gera cobranca.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Recovery Services vaults** > **+ Create**

3. Preencha as configuracoes:

   | Setting        | Value                                        |
   | -------------- | -------------------------------------------- |
   | Subscription   | *sua subscription*                           |
   | Resource group | `rg-contoso-management` (crie se necessario) |
   | Vault name     | `rsv-contoso-backup`                         |
   | Region         | **East US**                                  |

   > **Conceito:** O Recovery Services Vault deve estar na **mesma regiao** dos recursos que protege (para backup). Para Site Recovery (Bloco 3), o vault de DR ficara na regiao secundaria. Isso e uma regra fundamental — vault em East US so protege recursos em East US.

4. Clique em **Review + create** > **Create**

5. Selecione **Go to resource**

6. Explore o blade **Overview** — note as secoes: Backup Items, Replication Items, Backup Alerts

   > **Conexao com Blocos 2-3:** Este vault sera reutilizado para proteger file shares (Bloco 2). No Bloco 3, voce criara um vault separado na regiao de DR para Site Recovery.

---

### Task 1.2: Criar custom backup policy

Uma backup policy define **quando** e **com que frequencia** o Azure faz backup, e **por quanto tempo** mantem os dados. A DefaultPolicy faz backup diario com retencao de 30 dias — suficiente para muitos cenarios. Mas VMs criticas (como servidores de producao) podem precisar de backups mais frequentes.

**Analogia:** A policy e como a programacao de um alarme — voce define a hora, a frequencia e por quanto tempo quer manter o historico de gravacoes.

1. No vault **rsv-contoso-backup**, va para **Manage** > **Backup policies**

2. Revise a **DefaultPolicy** — note: frequencia diaria, retencao de 30 dias

3. Clique em **+ Add** > selecione **Azure Virtual Machine**

4. Configure a nova policy:

   | Setting              | Value                                            |
   | -------------------- | ------------------------------------------------ |
   | Policy name          | `rsvpol-contoso-12h`                             |
   | Frequency            | **Every 12 hours** (Hourly)                      |
   | Time                 | `6:00 AM`                                        |
   | Timezone             | **(UTC-03:00) Brasilia**                         |
   | Instant Restore      | Retain for **2** day(s)                          |
   | Daily backup point   | Retain for **180** days                          |
   | Weekly backup point  | **Enabled** — Sunday, retain **12** weeks        |
   | Monthly backup point | **Enabled** — First Sunday, retain **12** months |

   > **Conceito:** **Instant Restore** usa snapshots locais para restauracao rapida (minutos em vez de horas). Os snapshots ficam no mesmo resource group da VM e permitem restore quase instantaneo. Ja os pontos daily/weekly/monthly sao armazenados no vault para retencao de longo prazo — mais lentos para restaurar, mas protegidos contra falha do resource group.

   > **Frequency "Every 12 hours"** requer uma **Enhanced backup policy**. A Standard policy suporta apenas 1x por dia. Enhanced tambem habilita Multi-Disk Crash Consistency.

5. Clique em **Create**

6. Verifique que **rsvpol-contoso-12h** aparece na lista junto com **DefaultPolicy**

   > **Dica AZ-104:** Na prova, atente para os limites de retencao: daily (9999 dias), weekly (5163 semanas), monthly (1188 meses), yearly (99 anos). Tambem saiba que Enhanced policy permite frequencias de 4, 6, 8 ou 12 horas.

---

### Task 1.3: Habilitar backup para vm-web-01 (custom policy)

Agora voce conecta a VM a policy que acabou de criar. Ao habilitar backup, o Azure instala automaticamente uma extensao na VM (VMSnapshot para Windows, VMSnapshotLinux para Linux) que coordena os snapshots. Voce nao precisa fazer nada dentro da VM.

> **Cobranca:** Habilitar backup gera cobranca por instancia protegida e armazenamento de snapshots.

> **Pre-requisito:** A VM `vm-web-01` deve existir no `rg-contoso-compute` (criada na Semana 2). Se nao existir, crie uma VM Windows Server basica nesse RG antes de continuar.

1. No vault **rsv-contoso-backup**, va para **Getting started** > **Backup**

2. Configure:

   | Setting                         | Value               |
   | ------------------------------- | ------------------- |
   | Where is your workload running? | **Azure**           |
   | What do you want to back up?    | **Virtual machine** |

3. Clique em **Backup**

4. Na aba **Backup policy**, selecione **rsvpol-contoso-12h** (a custom que voce criou)

5. Na aba **Virtual Machines**, clique em **Add**

6. Selecione **vm-web-01** (do rg-contoso-compute, Semana 2) > **OK**

   > **Conexao com Semana 2:** Voce esta protegendo a mesma VM Windows que foi criada e configurada na Semana 2. O backup captura o estado completo da VM, incluindo OS disk e data disks.

7. Clique em **Enable Backup**

8. Aguarde a notificacao de sucesso

   > **Conceito:** O Azure instala automaticamente a extensao de backup na VM (VMSnapshot para Windows, VMSnapshotLinux para Linux). Nenhuma acao adicional e necessaria dentro da VM. Essa extensao usa o VSS (Volume Shadow Copy Service) no Windows para garantir consistencia de aplicacao — ou seja, o backup captura um estado consistente mesmo com o banco de dados rodando.

---

### Task 1.4: Habilitar backup para vm-api-01 (DefaultPolicy)

A VM Linux recebe a DefaultPolicy (backup diario). Isso demonstra um cenario comum: VMs com diferentes niveis de criticidade recebem policies diferentes. A vm-web-01 (producao, voltada para usuario) tem backup a cada 12h; a vm-api-01 (backend) tem backup diario.

1. Ainda no vault **rsv-contoso-backup** > **Getting started** > **Backup**

2. Configure:

   | Setting                         | Value               |
   | ------------------------------- | ------------------- |
   | Where is your workload running? | **Azure**           |
   | What do you want to back up?    | **Virtual machine** |

3. Clique em **Backup**

4. Na aba **Backup policy**, selecione **DefaultPolicy**

5. Na aba **Virtual Machines**, clique em **Add**

6. Selecione **vm-api-01** (do rg-contoso-compute, Semana 2) > **OK**

   > **Conexao com Semana 2:** A VM Linux tambem precisa de protecao. Usando a DefaultPolicy (diaria) para demonstrar que diferentes VMs podem ter policies diferentes conforme sua criticidade.

7. Clique em **Enable Backup**

---

### Task 1.5: Executar backup on-demand da vm-web-01

O backup on-demand permite criar um ponto de restauracao **agora**, sem esperar o proximo agendamento. Isso e util antes de grandes mudancas (atualizacoes de SO, deploy de aplicacao) — voce cria um "checkpoint" para poder voltar caso algo de errado.

1. No vault **rsv-contoso-backup**, va para **Protected items** > **Backup items**

2. Clique em **Azure Virtual Machine**

3. Selecione **vm-web-01** > clique em **Backup now**

4. Configure:

   | Setting            | Value                                         |
   | ------------------ | --------------------------------------------- |
   | Retain Backup Till | *aceite o default (30 dias a partir de hoje)* |

   > **Retain Backup Till** define ate quando este backup especifico sera mantido, independente da policy. E util para preservar um backup antes de uma grande mudanca, garantindo que ele nao sera removido pela retencao normal da policy.

5. Clique em **OK**

6. Monitore o progresso em **Monitoring** > **Backup Jobs**

   > **Conceito:** O primeiro backup (full) pode levar mais tempo porque copia todos os dados. Backups subsequentes sao **incrementais** — apenas as mudancas desde o ultimo backup sao copiadas. O job passa por duas fases: **Snapshot** (rapida, cria snapshot local) e **Transfer data to vault** (mais lenta, envia dados para o vault).

7. Aguarde ate o status mudar para **Completed** (pode levar 20-30 minutos)

   > **Dica AZ-104:** Na prova, saiba diferenciar: backup on-demand vs scheduled, full vs incremental, snapshot vs vault tier. O snapshot tier permite Instant Restore (restauracao em minutos); o vault tier e para retencao de longo prazo.

---

### Task 1.6: Verificar backup items e restore points

Apos o backup completar, voce verifica os itens protegidos e os pontos de restauracao disponiveis. Cada restore point e um "momento no tempo" para o qual voce pode voltar — como salvar o jogo antes de uma fase dificil.

1. No vault **rsv-contoso-backup** > **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Verifique que ambas as VMs aparecem:

   | VM        | Policy             | Last Backup Status |
   | --------- | ------------------ | ------------------ |
   | vm-web-01 | rsvpol-contoso-12h | Completed          |
   | vm-api-01 | DefaultPolicy      | Warning (initial)  |

   > O status **Warning (initial)** da vm-api-01 e normal — significa que nenhum backup foi executado ainda (apenas agendado). O primeiro backup agendado corrigira isso.

3. Selecione **vm-web-01** > clique em **View all restore points**

4. Note os restore points disponiveis — deve haver pelo menos 1 (do backup on-demand)

5. Clique em um restore point > observe as opcoes de restore:
   - **Create virtual machine** — restaura para uma nova VM
   - **Restore disk** — restaura apenas os discos
   - **Replace existing** — substitui os discos da VM atual
   - **Cross Region Restore** — restaura na regiao secundaria (se habilitado)

   > **Conceito:** Cada opcao atende um cenario diferente. **Create VM** e para quando a VM original foi perdida. **Restore disk** da mais controle — voce recebe managed disks e decide o que fazer. **Replace existing** e um "rollback" — substitui os discos atuais mantendo a mesma VM. **Cross Region Restore** e para DR (requer GRS no vault).

   > **Conexao com Bloco 3:** No Bloco 3 (Site Recovery), voce configurara replicacao cross-region como alternativa ao Cross Region Restore para cenarios de DR mais robustos.

---

### Task 1.6b: Explorar Cross Region Restore e replicacao do vault

Voce revisa as configuracoes de replicacao de storage do vault e entende como habilitar Cross Region Restore. A replicacao do vault define **quantas copias** dos seus backups existem e **onde** elas ficam — e uma decisao critica que impacta diretamente a resiliencia da sua estrategia de protecao.

1. Navegue para **rsv-contoso-backup** > **Properties**

2. Em **Backup Configuration**, clique em **Update**

3. Observe o **Storage Replication Type** atual:

   | Opcao   | Descricao                                                      |
   | ------- | -------------------------------------------------------------- |
   | **LRS** | 3 copias na mesma regiao (default)                             |
   | **GRS** | 6 copias: 3 na regiao primaria + 3 na regiao pareada           |
   | **ZRS** | 3 copias em zonas de disponibilidade diferentes (mesma regiao) |

   > **Analogia:** LRS e guardar 3 copias do documento no mesmo escritorio. ZRS e guardar em 3 escritorios diferentes da mesma cidade. GRS e guardar em 2 cidades diferentes. Quanto mais distribuido, maior a protecao contra desastres.

4. Se nenhum backup item estiver configurado, voce pode alterar para **GRS** e habilitar **Cross Region Restore**

5. Se backups ja existirem (Tasks 1.3-1.5), o campo Storage Replication Type estara **read-only** — observe a restricao e entenda a limitacao

   > **IMPORTANTE:** A replicacao de storage do vault so pode ser alterada **antes** de configurar qualquer backup item. Apos o primeiro backup, a configuracao fica bloqueada. Planeje isso no inicio do projeto.

6. Com GRS + Cross Region Restore habilitado, a opcao **Cross Region Restore** apareceria nos restore points (Task 1.6, opcao 4), permitindo restaurar a VM na regiao pareada

   > **Conceito:** **LRS** replica 3 vezes dentro de um unico datacenter — protege contra falha de hardware. **ZRS** replica entre zonas de disponibilidade — protege contra falha de datacenter. **GRS** replica para a regiao pareada do Azure — protege contra falha regional. **Cross Region Restore (CRR)** requer GRS e permite restaurar backups na regiao secundaria, funcionando como uma alternativa simplificada ao Site Recovery para cenarios de DR baseados em backup.

   > **Dica AZ-104:** Na prova, atente: CRR so funciona com GRS. A replicacao do vault NAO pode ser alterada apos o primeiro backup item ser configurado. CRR tem RPO de ate 36 horas (tempo de replicacao geo). Para RPO menor, use Site Recovery (Bloco 3).

---

### Task 1.7: Simular restore de disco (dry run)

Voce pratica o processo de restore sem criar recursos permanentes. Em producao, a restauracao mais comum e **Restore disks** — ela da flexibilidade para voce decidir como reconstruir a VM (novo nome, nova rede, etc.).

1. No vault **rsv-contoso-backup** > **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Selecione **vm-web-01** > **Restore VM**

3. Selecione o restore point mais recente

4. Em **Restore Configuration**, selecione **Restore disks**

5. Configure:

   | Setting          | Value                                                  |
   | ---------------- | ------------------------------------------------------ |
   | Staging Location | *selecione um storage account existente (da Semana 2)* |
   | Resource Group   | `rg-contoso-management`                                |

   > **Staging Location** e o storage account temporario onde o Azure coloca os discos restaurados e um ARM template de deploy. Voce pode usar o storage account criado na Semana 2. Apos a restauracao, voce pode usar o template para recriar a VM ou anexar os discos manualmente.

6. **NAO clique em Restore** — apenas revise as opcoes e cancele

   > **Conceito:** Restore disk cria managed disks que podem ser usados para recriar a VM manualmente ou via ARM template (skills do Bloco 3, Semana 1). Restore VM cria tudo automaticamente. Na prova, saiba que **Restore disks** e a unica opcao que permite restaurar discos individuais (ex: apenas o OS disk sem os data disks).

---

## Modo Desafio - Bloco 1

- [ ] Criar Recovery Services Vault `rsv-contoso-backup` em `rg-contoso-management` (East US)
- [ ] Criar custom policy `rsvpol-contoso-12h` (12h frequency, 180 days retention)
- [ ] Habilitar backup de `vm-web-01` **(Semana 2)** com custom policy
- [ ] Habilitar backup de `vm-api-01` **(Semana 2)** com DefaultPolicy
- [ ] Executar backup on-demand da `vm-web-01` → aguardar completion
- [ ] Verificar restore points e opcoes de restore
- [ ] Explorar replicacao do vault (LRS/GRS/ZRS) e entender Cross Region Restore
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
