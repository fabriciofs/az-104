# Lab Unificado AZ-104 - Semana 3: Backup, Recovery & Monitoring

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce esta na terceira semana como **Azure Administrator** da empresa. Com identidade, governanca, rede, storage e compute ja configurados, sua missao agora e proteger os dados e monitorar a infraestrutura de forma proativa. Voce vai configurar backups de VMs e storage, preparar disaster recovery entre regioes, implementar alertas e dashboards, e criar uma solucao de analytics centralizada com Log Analytics e KQL.

---

## Indice

- [Bloco 1 - VM Backup](#bloco-1---vm-backup)
- [Bloco 2 - File & Blob Protection](#bloco-2---file--blob-protection)
- [Bloco 3 - Azure Site Recovery](#bloco-3---azure-site-recovery)
- [Bloco 4 - Azure Monitor & Alerts](#bloco-4---azure-monitor--alerts)
- [Bloco 5 - Log Analytics & Insights](#bloco-5---log-analytics--insights)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - VM Backup

**Origem:** Lab 10 - Implement Data Protection (parte 1)
**Resource Groups utilizados:** `az104-rg11`

## Contexto

O primeiro passo para proteger a infraestrutura e garantir que suas VMs tenham backup configurado. Voce vai criar um Recovery Services Vault, definir politicas de backup com frequencia e retencao customizadas, habilitar backup de VMs existentes, executar backups on-demand e restaurar VMs a partir de pontos de recuperacao.

## Diagrama

```
┌───────────────────────────────────────────────────────────────┐
│                        az104-rg11                             │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐   │
│  │           Recovery Services Vault                      │   │
│  │           (az104-rsv1)                                 │   │
│  │                                                        │   │
│  │  ┌──────────────────┐   ┌───────────────────────────┐  │   │
│  │  │  Backup Policy   │   │   Backup Items            │  │   │
│  │  │  (Daily, 30d     │   │                           │  │   │
│  │  │   retention)     │──▶│  ┌─────────────────────┐  │  │   │
│  │  │                  │   │  │  az104-vm1 (VM)     │  │  │   │
│  │  └──────────────────┘   │  │  ● Scheduled backup │  │  │   │
│  │                         │  │  ● On-demand backup │  │  │   │
│  │                         │  └─────────────────────┘  │  │   │
│  │                         └───────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────┘   │
│                              │                                │
│                              ▼                                │
│                    ┌───────────────────┐                      │
│                    │  Restore Options  │                      │
│                    │  • New VM         │                      │
│                    │  • Replace exist. │                      │
│                    │  • Restore disk   │                      │
│                    └───────────────────┘                      │
└───────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Recovery Services Vault

O Recovery Services Vault e o container central que armazena backups e pontos de recuperacao. Ele deve estar na mesma regiao dos recursos protegidos.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Recovery Services vaults**

3. Clique em **+ Create** e preencha:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg11` (crie se necessario) |
   | Vault name     | `az104-rsv1`       |
   | Region         | **East US**        |

4. Clique em **Review + Create** > **Create**

5. Apos o deploy, selecione **Go to resource**

6. Explore o blade **Overview** e note as secoes:
   - **Backup Items** - recursos protegidos
   - **Backup Jobs** - historico de operacoes
   - **Backup Alerts** - alertas de falha

   > **Conceito:** O Recovery Services Vault armazena dados de backup e configuracoes de recovery. Ele suporta VMs, SQL Server, Azure Files, SAP HANA e workloads on-premises. O vault deve estar na **mesma regiao** que os recursos a serem protegidos.

---

### Task 1.2: Configurar Backup Policy (frequencia e retencao)

Uma backup policy define quando e com que frequencia os backups ocorrem, e por quanto tempo os pontos de recuperacao sao retidos.

1. No vault **az104-rsv1**, va para **Manage** > **Backup policies**

2. Observe a policy padrao **DefaultPolicy** - clique para revisar suas configuracoes

3. Volte para **Backup policies** e clique em **+ Add**

4. Selecione o tipo **Azure Virtual Machine**

5. Preencha as configuracoes da policy:

   | Setting                     | Value                        |
   | --------------------------- | ---------------------------- |
   | Policy name                 | `az104-backup-policy`        |
   | Frequency                   | **Daily**                    |
   | Time                        | **12:00 AM**                 |
   | Timezone                    | *seu timezone*               |
   | Instant restore snapshot    | **2** days                   |
   | Daily backup point retained | **30** days                  |
   | Weekly backup point         | **Enabled** - Sundays, 12 weeks |
   | Monthly backup point        | **Disabled**                 |
   | Yearly backup point         | **Disabled**                 |

6. Clique em **Create**

   > **Conceito:** A **Instant Restore** armazena snapshots localmente para restauracao rapida (minutos em vez de horas). A retencao diaria, semanal, mensal e anual define a estrategia GFS (Grandfather-Father-Son). Snapshots instantaneos sao armazenados no resource group do recurso, nao no vault.

   > **Dica AZ-104:** Na prova, preste atencao nos periodos de retencao e na diferenca entre backup frequencia e retencao. Uma policy com retencao de 30 dias mantendo backups diarios nao significa 30 backups - o Azure gerencia os recovery points de acordo com a politica GFS.

---

### Task 1.3: Habilitar backup de VM existente

Agora voce vai habilitar o backup de uma VM usando a policy customizada criada.

> **Pre-requisito:** Voce precisa de uma VM existente no resource group `az104-rg11`. Se nao tiver uma, crie rapidamente:
>
> ```bash
> az vm create --resource-group az104-rg11 --name az104-vm1 --image Ubuntu2204 --size Standard_B1s --admin-username azureuser --generate-ssh-keys --no-wait
> ```

1. No vault **az104-rsv1**, va para **Getting started** > **Backup**

2. Configure:

   | Setting                    | Value                       |
   | -------------------------- | --------------------------- |
   | Where is your workload running? | **Azure**              |
   | What do you want to back up?    | **Virtual machine**    |

3. Clique em **Backup**

4. Na aba **Policy**, selecione a policy **az104-backup-policy** criada anteriormente

5. Na aba **Virtual Machines**, clique em **Add**

6. Selecione a VM **az104-vm1** e clique em **OK**

7. Clique em **Enable Backup**

8. Aguarde a notificacao de configuracao concluida

   > **Conceito:** Ao habilitar o backup, o Azure instala a **VM Backup Extension** automaticamente. Para VMs Windows, e o VMSnapshot; para Linux, e o VMSnapshotLinux. A extensao coordena com o VSS (Windows) ou flush do filesystem (Linux) para garantir consistencia.

---

### Task 1.4: Executar backup on-demand

O backup agendado pode demorar para o primeiro ponto de recuperacao. Voce pode executar um backup imediatamente.

1. No vault **az104-rsv1**, va para **Protected items** > **Backup items**

2. Clique em **Azure Virtual Machine**

3. Selecione a VM **az104-vm1**

4. Clique em **Backup now**

5. Na tela de confirmacao:

   | Setting                    | Value              |
   | -------------------------- | ------------------ |
   | Retain Backup Till         | *aceite o padrao (30 dias)* |

6. Clique em **OK**

7. Monitore o progresso em **Monitoring** > **Backup Jobs**

8. Observe os detalhes do job: **Status**, **Duration**, **Data Transferred**

   > **Nota:** O primeiro backup completo pode levar entre 30 minutos e algumas horas dependendo do tamanho da VM. Backups subsequentes sao incrementais e mais rapidos.

   > **Dica AZ-104:** Para a prova, saiba que o backup on-demand usa a mesma retencao definida na policy, a menos que voce especifique uma data diferente no campo "Retain Backup Till".

---

### Task 1.5: Restaurar VM a partir de backup

Apos o backup ser concluido com sucesso, voce pode restaurar a VM usando diferentes opcoes.

> **Nota:** Esta task so pode ser executada apos o backup da Task 1.4 ter sido concluido com sucesso. Verifique o status em Backup Jobs.

1. No vault **az104-rsv1**, va para **Protected items** > **Backup items** > **Azure Virtual Machine**

2. Selecione a VM **az104-vm1**

3. Clique em **Restore VM**

4. Explore as opcoes de **Restore Point** e selecione o ponto mais recente

5. Revise as opcoes de **Restore Configuration**:

   | Opcao                  | Descricao                                         |
   | ---------------------- | ------------------------------------------------- |
   | **Create new**         | Cria uma nova VM a partir do backup               |
   | **Replace existing**   | Substitui os discos da VM atual pelos do backup   |
   | **Restore disk**       | Restaura apenas o disco para um storage account   |

6. Selecione **Create new** e preencha:

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Restore Type       | **Create new virtual machine** |
   | Virtual Machine Name | `az104-vm1-restored`   |
   | Resource Group     | `az104-rg11`             |
   | Virtual Network    | *selecione a VNet existente* |
   | Subnet             | *selecione a subnet existente* |
   | Staging Location   | *selecione um storage account* |

7. Clique em **Restore**

8. Monitore o progresso em **Monitoring** > **Backup Jobs** (a operacao de Restore aparece como job separado)

   > **Conceito:** O **Replace existing** so funciona se a VM original ainda existir. O **Restore disk** e util quando voce precisa personalizar a VM antes de recria-la (por exemplo, alterar o tamanho ou a configuracao de rede). O staging location e um storage account temporario usado durante o processo de restauracao.

   > **IMPORTANTE:** A restauracao **Create new** cria uma VM completamente nova. A VM original permanece intacta. Voce pode optar por deletar a VM restaurada apos validar os dados.

---

## Modo Desafio - Bloco 1

Para repeticoes rapidas, execute sem consultar os passos detalhados:

- [ ] Criar Recovery Services Vault `az104-rsv1` em East US no RG `az104-rg11`
- [ ] Criar backup policy `az104-backup-policy` (diaria, 30 dias retencao, semanal habilitada)
- [ ] Criar uma VM `az104-vm1` se necessario
- [ ] Habilitar backup da VM usando a policy customizada
- [ ] Executar backup on-demand
- [ ] Aguardar conclusao e restaurar VM como nova VM `az104-vm1-restored`
- [ ] Verificar a VM restaurada e os Backup Jobs

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Sua empresa precisa armazenar backups de VMs Azure. Voce esta decidindo entre um Recovery Services Vault e um Backup Vault. Qual das afirmacoes abaixo e correta?**

A) Recovery Services Vault e Backup Vault sao identicos em funcionalidade
B) Recovery Services Vault suporta VMs Azure, SQL e File Shares; Backup Vault suporta Azure Disks, Blobs e PostgreSQL
C) Backup Vault substitui completamente o Recovery Services Vault
D) Recovery Services Vault e usado apenas para backups on-premises

<details>
<summary>Ver resposta</summary>

**Resposta: B) Recovery Services Vault suporta VMs Azure, SQL e File Shares; Backup Vault suporta Azure Disks, Blobs e PostgreSQL**

O **Recovery Services Vault** e o container classico que suporta backup de VMs Azure, SQL Server in Azure VMs, Azure Files e workloads on-premises (via MARS/MABS). O **Backup Vault** e mais recente e suporta Azure Disks, Azure Blobs, Azure Database for PostgreSQL e Azure Kubernetes Service. Cada tipo de workload tem seu vault especifico.

</details>

### Questao 1.2
**Voce configurou uma backup policy com retencao diaria de 30 dias e semanal de 12 semanas. Quantos dias no minimo um ponto de backup semanal sera retido?**

A) 30 dias
B) 12 dias
C) 84 dias (12 semanas)
D) 7 dias

<details>
<summary>Ver resposta</summary>

**Resposta: C) 84 dias (12 semanas)**

A retencao semanal de 12 semanas significa que o ponto de backup semanal sera mantido por **84 dias** (12 x 7). A retencao semanal opera independentemente da retencao diaria. Se um ponto de backup for marcado como diario E semanal, a retencao mais longa prevalece.

</details>

### Questao 1.3
**Uma VM foi acidentalmente deletada. Voce precisa restaura-la com a mesma configuracao. Qual opcao de restauracao voce deve usar?**

A) Replace existing
B) Create new virtual machine
C) Restore disk
D) Cross Region Restore

<details>
<summary>Ver resposta</summary>

**Resposta: B) Create new virtual machine**

Como a VM original foi **deletada**, a opcao **Replace existing** nao esta disponivel (ela requer que a VM original ainda exista para substituir os discos). A opcao correta e **Create new virtual machine**, que recria a VM completa a partir do ponto de recuperacao. **Restore disk** restaura apenas os discos, exigindo que voce recrie a VM manualmente. **Cross Region Restore** e para restaurar em uma regiao secundaria.

</details>

---

# Bloco 2 - File & Blob Protection

**Origem:** Lab 10 - Implement Data Protection (parte 2)
**Resource Groups utilizados:** `az104-rg11` (mesmo vault)

## Contexto

Alem das VMs, dados armazenados em Azure Files e Blob Storage tambem precisam de protecao. Voce vai configurar backup de Azure File Shares via Recovery Services Vault, habilitar soft delete para proteger contra exclusoes acidentais de blobs e containers, ativar blob versioning para manter historico de alteracoes, e praticar a recuperacao de dados em cada cenario.

## Diagrama

```
┌───────────────────────────────────────────────────────────────┐
│                        az104-rg11                             │
│                                                               │
│  ┌─────────────────────────┐   ┌───────────────────────────┐  │
│  │  Recovery Services Vault│   │  Storage Account          │  │
│  │  (az104-rsv1)           │   │  (az104stbackup)          │  │
│  │                         │   │                           │  │
│  │  ┌───────────────────┐  │   │  ┌─────────────────────┐  │  │
│  │  │ File Share Backup │◀─┼───┼──│ File Share          │  │  │
│  │  │ (daily snapshots) │  │   │  │ (az104-share1)      │  │  │
│  │  └───────────────────┘  │   │  └─────────────────────┘  │  │
│  └─────────────────────────┘   │                           │  │
│                                │  ┌─────────────────────┐  │  │
│                                │  │ Blob Container      │  │  │
│                                │  │ (az104-container1)  │  │  │
│                                │  │                     │  │  │
│                                │  │ ● Soft Delete (7d)  │  │  │
│                                │  │ ● Versioning ON     │  │  │
│                                │  └─────────────────────┘  │  │
│                                └───────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Configurar backup de Azure File Share

O Azure Backup suporta backup nativo de Azure File Shares usando snapshots gerenciados pelo Recovery Services Vault.

1. Primeiro, crie um Storage Account e um File Share (se ainda nao existirem):

   - Pesquise e selecione **Storage accounts** > **+ Create**

   | Setting              | Value                    |
   | -------------------- | ------------------------ |
   | Resource Group       | `az104-rg11`             |
   | Storage account name | `az104stbackup` (ajuste para nome unico) |
   | Region               | **East US**              |
   | Performance          | **Standard**             |
   | Redundancy           | **LRS**                  |

   - Clique em **Review + Create** > **Create**

2. Apos o deploy, va para o storage account e selecione **Data storage** > **File shares**

3. Clique em **+ File share**:

   | Setting | Value            |
   | ------- | ---------------- |
   | Name    | `az104-share1`   |
   | Tier    | **Transaction optimized** |

4. Clique em **Create**

5. Faca upload de alguns arquivos de teste para o file share (clique no share > **Upload**)

6. Agora va para o vault **az104-rsv1** > **Getting started** > **Backup**

7. Configure:

   | Setting                          | Value                          |
   | -------------------------------- | ------------------------------ |
   | Where is your workload running?  | **Azure**                      |
   | What do you want to back up?     | **Azure FileShare**            |

8. Clique em **Backup**

9. Selecione o storage account **az104stbackup**

10. Selecione o file share **az104-share1**

11. Na secao **Policy**, revise a policy padrao ou crie uma customizada:

    | Setting           | Value           |
    | ----------------- | --------------- |
    | Policy name       | *DefaultPolicy ou customizada* |
    | Backup frequency  | **Daily**       |
    | Retention         | **30 days**     |

12. Clique em **Enable Backup**

    > **Conceito:** O backup de Azure File Shares funciona baseado em **share snapshots**. O Azure Backup gerencia automaticamente a criacao e retencao dos snapshots. Os snapshots sao incrementais - apenas as diferencas desde o ultimo snapshot sao armazenadas.

---

### Task 2.2: Habilitar Soft Delete para blobs e containers

Soft delete protege contra exclusoes acidentais mantendo dados deletados por um periodo configuravel.

1. Va para o storage account **az104stbackup**

2. No blade **Data management** > **Data protection**

3. Configure as opcoes de protecao:

   | Setting                                     | Value         |
   | ------------------------------------------- | ------------- |
   | Enable soft delete for blobs                | **Checked**   |
   | Days to retain deleted blobs                | **7** days    |
   | Enable soft delete for containers           | **Checked**   |
   | Days to retain deleted containers           | **7** days    |

4. Clique em **Save**

   > **Conceito:** **Soft delete** funciona como uma lixeira. Quando um blob ou container e deletado, ele e movido para um estado "soft-deleted" e permanece recuperavel pelo periodo configurado (1 a 365 dias). Apos o periodo, a exclusao se torna permanente.

   > **Dica AZ-104:** Soft delete para blobs e habilitado por padrao com 7 dias de retencao em novos storage accounts. Para a prova, saiba que soft delete para **containers** deve ser habilitado separadamente.

---

### Task 2.3: Configurar Blob Versioning

Blob versioning mantem automaticamente versoes anteriores de um blob quando ele e modificado ou sobrescrito.

1. Ainda em **Data management** > **Data protection** do storage account

2. Na secao **Tracking**:

   | Setting                   | Value       |
   | ------------------------- | ----------- |
   | Enable versioning for blobs | **Checked** |

3. Clique em **Save**

4. Agora crie um container para testar:
   - Va para **Data storage** > **Containers** > **+ Container**

   | Setting          | Value                |
   | ---------------- | -------------------- |
   | Name             | `az104-container1`   |
   | Public access level | **Private**       |

5. Clique em **Create**

6. Acesse o container e faca upload de um arquivo de texto

7. Faca upload do **mesmo arquivo** novamente com conteudo diferente (sobrescreva)

8. Selecione o blob e clique em **Versions** para ver as versoes anteriores

   > **Conceito:** Com **versioning** habilitado, cada vez que um blob e modificado ou sobrescrito, uma nova versao e criada automaticamente. A versao atual e chamada de "current version" e as anteriores sao acessiveis por seu version ID. Voce pode restaurar uma versao anterior promovendo-a para current.

---

### Task 2.4: Restaurar arquivo de File Share via backup

Apos o backup ser concluido, voce pode restaurar arquivos individuais ou o file share inteiro.

> **Nota:** Aguarde o primeiro backup do file share ser concluido antes de prosseguir.

1. No vault **az104-rsv1**, va para **Protected items** > **Backup items**

2. Selecione **Azure Storage (Azure Files)**

3. Selecione o file share **az104-share1**

4. Clique em **Restore Share**

5. Selecione o **Restore Point** mais recente

6. Escolha o tipo de restauracao:

   | Opcao                  | Descricao                                          |
   | ---------------------- | -------------------------------------------------- |
   | **Full Share Restore** | Restaura o file share inteiro para local original ou alternativo |
   | **File Level Restore** | Restaura arquivos individuais                      |

7. Selecione **File Level Restore**

8. Navegue e selecione os arquivos a restaurar

9. Configure o destino:

   | Setting                 | Value                      |
   | ----------------------- | -------------------------- |
   | Restore Location        | **Original Location** ou **Alternate Location** |
   | In case of conflicts    | **Overwrite** ou **Skip**  |

10. Clique em **Restore**

11. Monitore o progresso em **Monitoring** > **Backup Jobs**

    > **Dica AZ-104:** Na prova, saiba que a restauracao de File Share para o **local original** pode sobrescrever arquivos existentes. Use **Alternate Location** se quiser preservar o estado atual e comparar antes de substituir.

---

### Task 2.5: Recuperar blob deletado via soft delete

Agora voce vai praticar a recuperacao de um blob que foi "acidentalmente" deletado.

1. Va para o storage account **az104stbackup** > **Containers** > **az104-container1**

2. Selecione um blob e clique em **Delete** > confirme a exclusao

3. Note que o blob desapareceu da lista padrao

4. Clique em **Show deleted blobs** (botao na barra superior ou toggle)

5. O blob deletado aparece com status **Deleted** e a data de expiracao

6. Selecione o blob deletado e clique em **Undelete**

7. Confirme que o blob voltou ao estado **Active**

8. Verifique o conteudo do blob para confirmar integridade

   > **Conceito:** Soft delete preserva o blob e seus snapshots/versoes por um periodo configurado. O **Undelete** restaura o blob ao estado ativo. Apos expirar o periodo de retencao, o dado e permanentemente removido e nao pode ser recuperado.

---

## Modo Desafio - Bloco 2

- [ ] Criar storage account `az104stbackup` com File Share `az104-share1`
- [ ] Fazer upload de arquivos de teste no file share
- [ ] Configurar backup do file share no vault `az104-rsv1`
- [ ] Habilitar soft delete para blobs (7 dias) e containers (7 dias)
- [ ] Habilitar blob versioning
- [ ] Criar container `az104-container1`, fazer upload e sobrescrever arquivo
- [ ] Verificar versoes do blob
- [ ] Executar backup on-demand do file share
- [ ] Restaurar arquivo individual do file share
- [ ] Deletar blob e recuperar via soft delete (undelete)

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Qual e a principal diferenca entre o backup de Azure File Share e um share snapshot manual?**

A) Nao ha diferenca - ambos criam snapshots identicos
B) O backup via Azure Backup gerencia automaticamente a retencao e permite restauracao granular; snapshots manuais devem ser gerenciados manualmente
C) Share snapshots sao mais confiaveis que o Azure Backup
D) O Azure Backup cria copias completas; snapshots sao incrementais

<details>
<summary>Ver resposta</summary>

**Resposta: B) O backup via Azure Backup gerencia automaticamente a retencao e permite restauracao granular; snapshots manuais devem ser gerenciados manualmente**

O Azure Backup para File Shares usa **share snapshots** internamente, mas adiciona: gerenciamento automatico de retencao segundo a policy, restauracao granular (file-level) pelo portal, monitoramento centralizado via vault, e alertas de falha. Snapshots manuais sao uteis para cenarios simples, mas nao oferecem gerenciamento automatizado. Ambos (backup e snapshots manuais) sao incrementais.

</details>

### Questao 2.2
**Voce habilitou soft delete para blobs com retencao de 14 dias. Um usuario deletou um blob critico ha 10 dias. O que acontece?**

A) O blob ja foi permanentemente removido
B) O blob pode ser recuperado usando Undelete porque ainda esta dentro do periodo de retencao
C) O blob so pode ser recuperado abrindo um ticket de suporte
D) O blob pode ser recuperado mas sem os metadados originais

<details>
<summary>Ver resposta</summary>

**Resposta: B) O blob pode ser recuperado usando Undelete porque ainda esta dentro do periodo de retencao**

Com soft delete configurado para 14 dias, o blob permanece em estado "soft-deleted" por 14 dias apos a exclusao. Como se passaram apenas 10 dias, o blob pode ser recuperado via **Undelete** com todos os seus dados, metadados e versoes intactos. Apos 14 dias, a exclusao se torna permanente.

</details>

### Questao 2.3
**Sua equipe precisa manter um historico completo de todas as alteracoes feitas em documentos armazenados como blobs. Qual recurso voce deve habilitar?**

A) Soft delete
B) Blob snapshots
C) Blob versioning
D) Change feed

<details>
<summary>Ver resposta</summary>

**Resposta: C) Blob versioning**

**Blob versioning** cria automaticamente uma nova versao cada vez que um blob e modificado ou sobrescrito, mantendo um historico completo de alteracoes. **Soft delete** protege contra exclusoes acidentais mas nao rastreia modificacoes. **Snapshots** sao pontos no tempo criados manualmente. **Change feed** fornece um log de alteracoes mas nao armazena as versoes anteriores dos dados.

</details>

---

# Bloco 3 - Azure Site Recovery

**Origem:** Lab 10 - Implement Data Protection (parte 3)
**Resource Groups utilizados:** `az104-rg12`

## Contexto

O Azure Site Recovery (ASR) e a solucao de disaster recovery do Azure. Ele replica VMs entre regioes para garantir continuidade de negocios. Voce vai configurar replicacao de uma VM para uma regiao secundaria, criar um plano de recuperacao, executar um test failover para validar sem impactar producao, e limpar o ambiente de teste.

## Diagrama

```
┌──────────────────────────────┐         ┌──────────────────────────────┐
│       REGIAO PRIMARIA        │         │      REGIAO SECUNDARIA       │
│         (East US)            │         │        (West US)             │
│                              │         │                              │
│  ┌────────────────────────┐  │  ASR    │  ┌────────────────────────┐  │
│  │    az104-rg12           │  │ Repli- │  │ az104-rg12-asr (auto) │  │
│  │                        │  │ cacao  │  │                        │  │
│  │  ┌──────────────────┐  │  │ ──────▶│  │  ┌──────────────────┐  │  │
│  │  │  az104-vm-asr    │  │  │        │  │  │  Replica (discos │  │  │
│  │  │  (VM ativa)      │  │  │        │  │  │  + config)       │  │  │
│  │  └──────────────────┘  │  │        │  │  └──────────────────┘  │  │
│  │                        │  │        │  │                        │  │
│  │  ┌──────────────────┐  │  │        │  │  ┌──────────────────┐  │  │
│  │  │  Recovery Plan   │  │  │        │  │  │  Test Failover   │  │  │
│  │  │  (az104-plan)    │──┼──┼────────┼──┼─▶│  VM (validacao)  │  │  │
│  │  └──────────────────┘  │  │        │  │  └──────────────────┘  │  │
│  └────────────────────────┘  │        │  └────────────────────────┘  │
│                              │         │                              │
│  ┌────────────────────────┐  │        │  ┌────────────────────────┐  │
│  │  RSV (az104-rsv-asr)  │  │        │  │  Cache Storage Account │  │
│  │  (vault na regiao      │  │        │  │  (auto-provisionado)   │  │
│  │   secundaria)          │  │        │  │                        │  │
│  └────────────────────────┘  │        │  └────────────────────────┘  │
└──────────────────────────────┘         └──────────────────────────────┘
```

---

### Task 3.1: Configurar replicacao de VM para regiao secundaria

Voce vai configurar o Azure Site Recovery para replicar uma VM de East US para West US.

> **Pre-requisito:** Crie uma VM para replicacao se nao existir:
>
> ```bash
> az vm create --resource-group az104-rg12 --name az104-vm-asr --image Ubuntu2204 --size Standard_B1s --admin-username azureuser --generate-ssh-keys --location eastus
> ```

1. No Azure Portal, pesquise e selecione **Recovery Services vaults**

2. Clique em **+ Create** e preencha:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg12`       |
   | Vault name     | `az104-rsv-asr`    |
   | Region         | **West US** (regiao secundaria/destino) |

   > **IMPORTANTE:** O vault do ASR deve estar na regiao de **destino** (secundaria), nao na regiao de origem. Isso e diferente do vault de backup, que deve estar na mesma regiao dos recursos.

3. Clique em **Review + Create** > **Create**

4. Apos o deploy, va para o vault **az104-rsv-asr**

5. No blade **Getting started** > **Site Recovery**, clique em **Enable Site Recovery**

6. Na secao **Azure virtual machines**, clique em **Enable replication**

7. Na aba **Source**, configure:

   | Setting         | Value              |
   | --------------- | ------------------ |
   | Region          | **East US**        |
   | Subscription    | *sua subscription* |
   | Resource Group  | `az104-rg12`       |

8. Clique em **Next**

9. Na aba **Virtual machines**, selecione **az104-vm-asr**

10. Na aba **Replication settings**, revise:
    - **Target region:** West US
    - **Target resource group:** az104-rg12-asr (criado automaticamente)
    - **Failover virtual network:** (criada automaticamente)
    - **Cache storage account:** (criada automaticamente)

11. Clique em **Next** > **Enable replication**

12. Monitore o progresso em **Protected items** > **Replicated items**

13. Aguarde o status mudar para **Protected** (isso pode levar 30-60 minutos para a sincronizacao inicial)

    > **Conceito:** O ASR replica dados continuamente para a regiao secundaria. O processo envolve: 1) Instalacao do Mobility Service na VM de origem, 2) Replicacao inicial completa dos discos, 3) Replicacao continu de alteracoes (delta). O cache storage account na regiao de origem armazena temporariamente os dados antes de envia-los para a regiao de destino.

---

### Task 3.2: Configurar Recovery Plan

Um Recovery Plan define a ordem e agrupamento de VMs durante um failover, permitindo orquestrar a recuperacao de aplicacoes multi-tier.

1. No vault **az104-rsv-asr**, va para **Manage** > **Recovery Plans (Site Recovery)**

2. Clique em **+ Recovery Plan**

3. Preencha:

   | Setting        | Value                    |
   | -------------- | ------------------------ |
   | Name           | `az104-recovery-plan`    |
   | Source         | **East US**              |
   | Target         | **West US**              |
   | Allow items with deployment model | **Resource Manager** |

4. Clique em **Select items** e selecione **az104-vm-asr**

5. Clique em **OK** > **Create**

6. Apos criacao, selecione o recovery plan para visualizar:
   - **Group 1:** VMs que fazem failover simultaneamente
   - Voce pode adicionar mais grupos para sequenciar o failover (ex: banco de dados primeiro, depois aplicacao)

   > **Conceito:** Recovery Plans permitem: 1) Agrupar VMs por tier (DB, App, Web), 2) Definir ordem de failover, 3) Adicionar scripts/acoes manuais entre grupos, 4) Testar failover de toda a aplicacao de uma vez. Isso e essencial para aplicacoes complexas com dependencias.

---

### Task 3.3: Executar Test Failover

O Test Failover valida sua estrategia de disaster recovery sem impactar os recursos de producao.

> **Nota:** Aguarde a replicacao estar com status **Protected** antes de executar o test failover.

1. No vault **az104-rsv-asr**, va para **Protected items** > **Replicated items**

2. Selecione **az104-vm-asr**

3. Clique em **Test Failover**

4. Configure:

   | Setting                  | Value                                |
   | ------------------------ | ------------------------------------ |
   | Recovery Point           | **Latest processed** (menor RPO)     |
   | Azure virtual network    | *selecione uma VNet na regiao secundaria (ou crie uma de teste)* |

   > **Conceito:** Opcoes de Recovery Point:
   > - **Latest processed:** Ultimo ponto processado pelo ASR (menor RPO)
   > - **Latest:** Processa todos os dados pendentes antes do failover (maior RPO, mas dados mais recentes)
   > - **Latest app-consistent:** Ultimo ponto consistente com aplicacao

5. Clique em **OK**

6. Monitore o progresso em **Monitoring** > **Site Recovery jobs**

7. Aguarde o job completar - uma VM de teste sera criada na regiao secundaria

   > **IMPORTANTE:** O test failover cria recursos na regiao de destino (VM, discos, NIC) mas NAO afeta a VM de producao na regiao de origem. A replicacao continua normalmente durante o teste.

---

### Task 3.4: Validar VM na regiao secundaria

Apos o test failover concluir, valide que a VM esta funcional na regiao de destino.

1. Pesquise e selecione **Virtual machines**

2. Localize a VM criada pelo test failover (geralmente com sufixo `-test`)

3. Verifique:
   - **Status:** Running
   - **Location:** West US (regiao secundaria)
   - **Size:** Mesmo tamanho da VM original
   - **Discos:** Mesma configuracao

4. Se necessario, conecte-se a VM para validar dados e aplicacoes

   > **Dica AZ-104:** Na prova, lembre-se que o test failover cria uma VM **isolada** na VNet de teste. Se voce precisa testar conectividade com outros recursos, deve usar uma VNet de teste com a configuracao apropriada. A VM de teste nao tem IP publico por padrao.

---

### Task 3.5: Executar Cleanup do test failover

Apos validar, voce deve limpar os recursos do test failover para liberar recursos e custos.

1. Volte ao vault **az104-rsv-asr** > **Protected items** > **Replicated items**

2. Selecione **az104-vm-asr**

3. Note o banner ou o botao **Cleanup test failover**

4. Marque o checkbox **Testing is complete. Delete test failover virtual machine(s)**

5. Adicione notas opcionais sobre o resultado do teste

6. Clique em **OK**

7. Monitore o progresso - o Azure deletara automaticamente a VM de teste e seus recursos associados

8. Verifique que o status da replicacao voltou a **Protected**

   > **Conceito:** O cleanup e obrigatorio antes de poder executar um failover real ou outro test failover. Enquanto o teste nao for limpo, a opcao de failover fica bloqueada. Sempre documente os resultados do teste para compliance e auditoria.

---

## Modo Desafio - Bloco 3

- [ ] Criar VM `az104-vm-asr` em East US no RG `az104-rg12`
- [ ] Criar Recovery Services Vault `az104-rsv-asr` em **West US** (regiao de destino)
- [ ] Configurar replicacao da VM de East US para West US via ASR
- [ ] Aguardar status **Protected**
- [ ] Criar Recovery Plan `az104-recovery-plan` incluindo a VM
- [ ] Executar Test Failover usando o recovery point mais recente
- [ ] Validar a VM de teste na regiao secundaria
- [ ] Executar Cleanup do test failover
- [ ] Verificar que a replicacao voltou ao status Protected

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Sua empresa tem um RPO (Recovery Point Objective) de 4 horas e um RTO (Recovery Time Objective) de 1 hora. O que esses valores significam?**

A) RPO define o tempo maximo para restaurar o servico; RTO define a perda maxima de dados aceitavel
B) RPO define a perda maxima de dados aceitavel (4h de dados podem ser perdidos); RTO define o tempo maximo para restaurar o servico (1h para voltar a operar)
C) RPO e RTO sao a mesma coisa, apenas medidos de formas diferentes
D) RPO se aplica a backups e RTO se aplica a disaster recovery exclusivamente

<details>
<summary>Ver resposta</summary>

**Resposta: B) RPO define a perda maxima de dados aceitavel (4h de dados podem ser perdidos); RTO define o tempo maximo para restaurar o servico (1h para voltar a operar)**

- **RPO (Recovery Point Objective):** Quantidade maxima de dados que a organizacao aceita perder, medida em tempo. RPO de 4h significa que ate 4 horas de dados podem ser perdidos.
- **RTO (Recovery Time Objective):** Tempo maximo aceitavel para restaurar o servico apos uma interrupcao. RTO de 1h significa que o servico deve voltar a operar em no maximo 1 hora.
- O ASR oferece RPO tipico de 15-30 minutos para VMs Azure.

</details>

### Questao 3.2
**Qual a diferenca entre Test Failover, Planned Failover e Unplanned (Forced) Failover no Azure Site Recovery?**

A) Todos os tres migram a VM permanentemente para a regiao secundaria
B) Test Failover nao afeta producao; Planned Failover e para migracoes planejadas com zero perda de dados; Forced Failover e para desastres com possivel perda de dados
C) Test Failover e Planned Failover sao identicos
D) Apenas Forced Failover replica os dados

<details>
<summary>Ver resposta</summary>

**Resposta: B) Test Failover nao afeta producao; Planned Failover e para migracoes planejadas com zero perda de dados; Forced Failover e para desastres com possivel perda de dados**

- **Test Failover:** Cria uma VM de teste isolada na regiao secundaria. A VM de producao e a replicacao nao sao afetados. Usado para validacao.
- **Planned Failover:** Usado quando a regiao primaria ainda esta acessivel. Garante zero perda de dados sincronizando todos os dados pendentes antes do failover.
- **Unplanned/Forced Failover:** Usado quando a regiao primaria esta indisponivel (desastre real). Pode haver perda de dados dependendo do ultimo ponto de replicacao.

</details>

### Questao 3.3
**Voce esta configurando ASR para uma VM em East US. Em qual regiao o Recovery Services Vault deve ser criado?**

A) East US (mesma regiao da VM)
B) Na regiao de destino do failover (ex: West US)
C) Qualquer regiao - nao importa
D) Em ambas as regioes

<details>
<summary>Ver resposta</summary>

**Resposta: B) Na regiao de destino do failover (ex: West US)**

Para o **Azure Site Recovery**, o vault deve ser criado na **regiao de destino** (secundaria), pois ele coordena a replicacao e o failover nessa regiao. Isso e diferente do vault de **backup**, que deve estar na mesma regiao dos recursos protegidos. O cache storage account e criado automaticamente na regiao de **origem**.

</details>

---

# Bloco 4 - Azure Monitor & Alerts

**Origem:** Lab 11 - Implement Monitoring (parte 1)
**Resource Groups utilizados:** `az104-rg13`

## Contexto

Com backups e disaster recovery configurados, voce precisa monitorar proativamente a infraestrutura para detectar problemas antes que impactem os usuarios. Voce vai explorar metricas no Azure Monitor, criar regras de alerta baseadas em metricas (como CPU alta), configurar Action Groups para notificacoes, criar dashboards personalizados e habilitar diagnostic settings para coleta de dados detalhados.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                        az104-rg13                                   │
│                                                                     │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐   │
│  │  az104-vm-   │    │           Azure Monitor                  │   │
│  │  monitor     │    │                                          │   │
│  │  (VM)        │───▶│  ┌───────────────┐  ┌────────────────┐  │   │
│  │              │    │  │   Metrics      │  │  Alert Rules   │  │   │
│  └──────────────┘    │  │  • CPU %       │  │  • CPU > 80%   │  │   │
│                      │  │  • Memory      │  │  • Disk IO     │  │   │
│                      │  │  • Network     │  │                │  │   │
│                      │  └───────────────┘  └───────┬────────┘  │   │
│                      │                             │            │   │
│                      │                             ▼            │   │
│                      │               ┌──────────────────────┐   │   │
│                      │               │    Action Group      │   │   │
│                      │               │  • Email             │   │   │
│                      │               │  • SMS               │   │   │
│                      │               │  • Webhook           │   │   │
│                      │               └──────────────────────┘   │   │
│                      │                                          │   │
│                      │  ┌───────────────┐  ┌────────────────┐  │   │
│                      │  │  Diagnostic   │  │   Dashboard    │  │   │
│                      │  │  Settings     │  │  (Portal)      │  │   │
│                      │  │  → Storage    │  │  • CPU chart   │  │   │
│                      │  │  → Log Analyt.│  │  • Memory chart│  │   │
│                      │  └───────────────┘  └────────────────┘  │   │
│                      └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Explorar metricas de VM no Azure Monitor

Voce vai explorar as metricas disponiveis para uma VM e criar graficos no Metrics Explorer.

> **Pre-requisito:** Crie uma VM para monitoramento se nao existir:
>
> ```bash
> az vm create --resource-group az104-rg13 --name az104-vm-monitor --image Win2022Datacenter --size Standard_B2s --admin-username azureuser --admin-password 'Az104P@ssw0rd!' --location eastus
> ```

1. Pesquise e selecione **Monitor** no Azure Portal

2. No blade **Overview**, explore as secoes:
   - **Metrics** - dados numericos em tempo real
   - **Alerts** - notificacoes baseadas em condicoes
   - **Logs** - dados de log para analise

3. Selecione **Metrics** no blade esquerdo

4. Configure o escopo:

   | Setting     | Value                     |
   | ----------- | ------------------------- |
   | Scope       | **az104-vm-monitor**      |
   | Metric Namespace | **Virtual Machine Host** |
   | Metric      | **Percentage CPU**        |
   | Aggregation | **Avg**                   |

5. Clique em **Apply** e observe o grafico

6. Clique em **Add metric** para adicionar mais metricas ao mesmo grafico:

   | Metric                    | Aggregation |
   | ------------------------- | ----------- |
   | Network In Total          | **Sum**     |
   | Network Out Total         | **Sum**     |

7. Altere o **Time range** para as ultimas **1 hour** e **30 minutes**

8. Clique em **Pin to dashboard** para salvar o grafico

   > **Conceito:** As metricas do **Virtual Machine Host** sao coletadas automaticamente sem agente. Incluem CPU, disco e rede. Para metricas de **Guest OS** (memoria, processos), voce precisa instalar o Azure Monitor Agent e configurar Data Collection Rules.

   > **Dica AZ-104:** Na prova, saiba a diferenca entre **Host metrics** (disponiveis automaticamente) e **Guest OS metrics** (requerem agente). A metrica "Percentage CPU" e uma host metric; "Available Memory" e uma guest OS metric.

---

### Task 4.2: Criar Alert Rule (metrica: CPU > 80%)

Voce vai criar uma regra de alerta que dispara quando a CPU da VM ultrapassa 80%.

1. No Azure Portal, pesquise e selecione **Monitor** > **Alerts**

2. Clique em **+ Create** > **Alert rule**

3. Na aba **Scope**, selecione o resource:

   | Setting  | Value                              |
   | -------- | ---------------------------------- |
   | Resource | **az104-vm-monitor** (Virtual Machine) |

4. Clique em **Apply**

5. Na aba **Condition**, clique em **Add condition**:

   | Setting          | Value                  |
   | ---------------- | ---------------------- |
   | Signal name      | **Percentage CPU**     |
   | Alert logic      |                        |
   | Threshold        | **Static**             |
   | Aggregation type | **Average**            |
   | Operator         | **Greater than**       |
   | Threshold value  | **80**                 |
   | Check every      | **1 minute**           |
   | Lookback period  | **5 minutes**          |

6. Observe o grafico de preview que mostra quando o alerta teria disparado no historico recente

7. Clique em **Next: Actions**

   > **Conceito:** Alert rules avaliam condicoes periodicamente. O **Lookback period** define a janela de dados avaliada. O **Check every** define a frequencia de avaliacao. Um alerta com lookback de 5 min e check every 1 min avalia a media dos ultimos 5 minutos a cada 1 minuto.

---

### Task 4.3: Configurar Action Group (email notification)

Um Action Group define o que acontece quando um alerta dispara - quem e notificado e quais acoes sao executadas.

1. Continuando na aba **Actions** da regra de alerta, clique em **Create action group**

2. Na aba **Basics**:

   | Setting             | Value                |
   | ------------------- | -------------------- |
   | Subscription        | *sua subscription*   |
   | Resource Group      | `az104-rg13`         |
   | Action group name   | `az104-action-group` |
   | Display name        | `az104-ag`           |

3. Na aba **Notifications**:

   | Setting           | Value                     |
   | ----------------- | ------------------------- |
   | Notification type | **Email/SMS message/Push/Voice** |
   | Name              | `admin-email`             |

4. No painel que abre, configure:

   | Setting | Value                     |
   | ------- | ------------------------- |
   | Email   | **checked** - *seu email* |
   | SMS     | *opcional*                |

5. Clique em **OK**

6. Na aba **Actions** (acoes automatizadas - opcional), explore as opcoes:
   - **Automation Runbook** - executar script automaticamente
   - **Azure Function** - chamar uma funcao
   - **Logic App** - iniciar um workflow
   - **Webhook** - chamar URL externa
   - **ITSM** - integrar com sistema de tickets

7. Clique em **Review + Create** > **Create**

8. De volta a regra de alerta, configure os **Details**:

   | Setting              | Value                        |
   | -------------------- | ---------------------------- |
   | Severity             | **2 - Warning**              |
   | Alert rule name      | `az104-cpu-alert`            |
   | Description          | `Alert when CPU exceeds 80%` |
   | Region               | **East US**                  |
   | Enable upon creation | **checked**                  |

   > **Conceito:** Os niveis de **Severity** do Azure Monitor:
   > - **Sev 0 - Critical:** Incidente critico que requer atencao imediata
   > - **Sev 1 - Error:** Erro que impacta servicos
   > - **Sev 2 - Warning:** Aviso que pode se tornar um problema
   > - **Sev 3 - Informational:** Informacao para investigacao
   > - **Sev 4 - Verbose:** Detalhamento para debug

9. Clique em **Review + Create** > **Create**

10. Voce recebera um email de confirmacao do Action Group

    > **Dica AZ-104:** Na prova, lembre-se que um Action Group pode ser reutilizado por multiplas alert rules. Voce tambem pode ter multiplas notificacoes e acoes em um unico Action Group.

---

### Task 4.4: Criar Dashboard personalizado no Azure Portal

Dashboards fornecem uma visao consolidada dos recursos e metricas mais importantes.

1. No Azure Portal, clique em **Dashboard** no menu esquerdo (ou pesquise **Dashboard**)

2. Clique em **+ New dashboard** > **Blank dashboard**

3. Nomeie o dashboard: `az104-monitoring-dashboard`

4. Use a **Tile Gallery** para adicionar componentes:

5. Adicione um tile de **Metrics chart**:
   - Arraste o tile para o canvas
   - Configure: Scope = `az104-vm-monitor`, Metric = `Percentage CPU`
   - Clique em **Done editing**

6. Adicione um tile de **Markdown**:
   - Arraste o tile para o canvas
   - Adicione texto descritivo: `## Monitoramento az104-vm-monitor`
   - Clique em **Done editing**

7. Adicione um tile de **Resource group**:
   - Arraste o tile para o canvas
   - Selecione o resource group `az104-rg13`

8. Reorganize os tiles conforme preferencia (arraste e redimensione)

9. Clique em **Save**

10. Explore as opcoes de compartilhamento:
    - **Share** > **Publish** (compartilha com outros usuarios)
    - O dashboard compartilhado e armazenado como um recurso Azure no resource group selecionado

    > **Conceito:** Dashboards podem ser **privados** (visiveis apenas para voce) ou **compartilhados** (publicados como recursos Azure). Dashboards compartilhados respeitam RBAC - usuarios precisam de pelo menos a role **Reader** para visualizar. Dashboards podem ser exportados/importados como JSON.

    > **Dica AZ-104:** Na prova, saiba que dashboards compartilhados sao recursos Azure e podem ser gerenciados via RBAC. Eles sao armazenados no resource group especificado durante o compartilhamento.

---

### Task 4.5: Habilitar Diagnostic Settings para VM

Diagnostic Settings configuram para onde os dados de diagnostico de um recurso sao enviados - storage account, Log Analytics workspace ou Event Hub.

1. Pesquise e selecione a VM **az104-vm-monitor**

2. No blade **Monitoring**, selecione **Diagnostic settings**

3. Clique em **Add diagnostic setting**

4. Preencha:

   | Setting               | Value                            |
   | --------------------- | -------------------------------- |
   | Diagnostic setting name | `az104-vm-diagnostics`         |

5. Na secao **Category details**, selecione as categorias de logs e metricas:

   | Category          | Selecao     |
   | ----------------- | ----------- |
   | AllMetrics         | **Checked** |

   > **Nota:** Para VMs, as diagnostic settings no nivel do recurso coletam metricas de plataforma. Para logs detalhados do Guest OS (Event Logs, Syslog, Perf Counters), voce precisara do Azure Monitor Agent + Data Collection Rules (abordado no Bloco 5).

6. Na secao **Destination details**, configure:

   | Setting                        | Value                              |
   | ------------------------------ | ---------------------------------- |
   | Send to Log Analytics workspace | **Checked**                       |
   | Log Analytics workspace        | *selecione ou crie um workspace*  |

   > Se nao tiver um workspace, clique em **Create New**:
   >
   > | Setting | Value               |
   > | ------- | ------------------- |
   > | Name    | `az104-law1`        |
   > | Region  | **East US**         |

7. Clique em **Save**

   > **Conceito:** Os dados podem ser enviados para tres destinos:
   > - **Log Analytics workspace:** Para analise com KQL e integracoes com Azure Monitor
   > - **Storage Account:** Para retencao de longo prazo e auditoria
   > - **Event Hub:** Para streaming para sistemas externos (SIEM, etc.)
   >
   > Voce pode enviar para multiplos destinos simultaneamente.

---

## Modo Desafio - Bloco 4

- [ ] Criar VM `az104-vm-monitor` em East US no RG `az104-rg13`
- [ ] Explorar metricas da VM no Metrics Explorer (CPU, Network In/Out)
- [ ] Fixar grafico de metricas no dashboard
- [ ] Criar Alert Rule para CPU > 80% (static threshold, check every 1 min, lookback 5 min)
- [ ] Criar Action Group `az104-action-group` com notificacao por email
- [ ] Verificar email de confirmacao do Action Group
- [ ] Criar dashboard `az104-monitoring-dashboard` com tiles de metricas e markdown
- [ ] Configurar Diagnostic Settings enviando metricas para Log Analytics workspace
- [ ] Explorar opcoes de compartilhamento do dashboard

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Qual a diferenca principal entre metric alerts e log alerts no Azure Monitor?**

A) Metric alerts avaliam dados numericos em tempo real; log alerts executam queries KQL em dados de log no Log Analytics
B) Log alerts sao mais rapidos que metric alerts
C) Metric alerts so funcionam com VMs; log alerts funcionam com qualquer recurso
D) Nao ha diferenca - sao apenas nomes diferentes para o mesmo recurso

<details>
<summary>Ver resposta</summary>

**Resposta: A) Metric alerts avaliam dados numericos em tempo real; log alerts executam queries KQL em dados de log no Log Analytics**

- **Metric Alerts:** Avaliam metricas numericas de plataforma em intervalos regulares. Sao avaliados quase em tempo real (a cada 1-5 minutos). Exemplos: CPU%, disk IOPS, request count.
- **Log Alerts:** Executam queries KQL (Kusto Query Language) em dados do Log Analytics workspace. Sao mais flexiveis mas com latencia maior. Podem correlacionar dados de multiplas fontes.
- **Activity Log Alerts:** Um terceiro tipo que monitora eventos do plano de controle (operacoes no Azure Resource Manager).

</details>

### Questao 4.2
**Voce precisa notificar a equipe de operacoes por email E executar automaticamente um runbook quando um alerta disparar. Quantos Action Groups voce precisa?**

A) 2 - um para email e outro para runbook
B) 1 - um Action Group pode conter multiplas notificacoes e acoes
C) 3 - um para email, um para runbook e um para gerenciar ambos
D) 0 - notificacoes e acoes sao configuradas diretamente na alert rule

<details>
<summary>Ver resposta</summary>

**Resposta: B) 1 - um Action Group pode conter multiplas notificacoes e acoes**

Um unico **Action Group** pode conter ate 10 de cada tipo: email, SMS, push, voice, Azure Function, Logic App, Automation Runbook, Webhook e ITSM. Nao e necessario criar Action Groups separados para diferentes tipos de acoes. Alem disso, uma alert rule pode referenciar multiplos Action Groups, e um Action Group pode ser referenciado por multiplas alert rules.

</details>

### Questao 4.3
**Voce configurou Diagnostic Settings para uma VM enviando metricas para um Log Analytics workspace. Que tipo de dados voce ainda NAO tem acesso?**

A) Percentage CPU
B) Network In/Out
C) Windows Event Logs do Guest OS
D) Disk Read/Write bytes

<details>
<summary>Ver resposta</summary>

**Resposta: C) Windows Event Logs do Guest OS**

As **Diagnostic Settings** no nivel do recurso coletam metricas de **plataforma** (host metrics) como CPU, disco e rede. Para coletar dados do **Guest OS** como Event Logs, Syslog, Performance Counters e logs de aplicacao, voce precisa instalar o **Azure Monitor Agent (AMA)** na VM e configurar **Data Collection Rules (DCR)**. Isso e abordado no Bloco 5.

</details>

### Questao 4.4
**Voce criou um dashboard compartilhado. Um colega reporta que nao consegue visualiza-lo. O que provavelmente esta faltando?**

A) O colega precisa de uma licenca premium
B) O colega precisa de pelo menos a role Reader no resource group onde o dashboard foi publicado
C) Dashboards nao podem ser compartilhados entre usuarios
D) O colega precisa estar na mesma subscription

<details>
<summary>Ver resposta</summary>

**Resposta: B) O colega precisa de pelo menos a role Reader no resource group onde o dashboard foi publicado**

Dashboards **compartilhados** sao armazenados como recursos Azure em um resource group. Para visualiza-los, o usuario precisa de pelo menos a role **Reader** nesse resource group. Para edita-los, precisa da role **Contributor**. O RBAC padrao do Azure se aplica. Nao e necessario licenca premium ou mesma subscription (pode ser compartilhado via RBAC cross-subscription se configurado).

</details>

---

# Bloco 5 - Log Analytics & Insights

**Origem:** Lab 11 - Implement Monitoring (parte 2)
**Resource Groups utilizados:** `az104-rg13` (mesmo workspace)

## Contexto

O ultimo bloco aprofunda o monitoramento com Log Analytics, a plataforma de analytics do Azure. Voce vai criar um workspace, conectar VMs, executar queries KQL para analisar dados, habilitar VM Insights para visibilidade completa de performance e dependencias, criar Workbooks para relatorios visuais, e configurar Network Watcher para monitoramento de conectividade.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           az104-rg13                                    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              Log Analytics Workspace (az104-law1)                 │  │
│  │                                                                    │  │
│  │  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐     │  │
│  │  │ Data Sources  │   │  KQL Queries │   │  Workbooks         │     │  │
│  │  │              │   │              │   │                    │     │  │
│  │  │ • VM Agent   │──▶│ • Heartbeat  │──▶│ • Custom reports   │     │  │
│  │  │ • Diag. Set. │   │ • Perf       │   │ • Visualizations   │     │  │
│  │  │ • Activity   │   │ • Event      │   │ • Shared templates │     │  │
│  │  └──────────────┘   └──────────────┘   └────────────────────┘     │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────┐   ┌──────────────────────────────────────────┐    │
│  │  az104-vm-monitor│   │           VM Insights                    │    │
│  │  (VM + AMA)      │──▶│  • Performance (CPU, Mem, Disk, Net)    │    │
│  │                  │   │  • Map (dependencies, connections)      │    │
│  │  Azure Monitor   │   │  • Health diagnostics                   │    │
│  │  Agent installed │   └──────────────────────────────────────────┘    │
│  └──────────────────┘                                                   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Network Watcher                               │   │
│  │  • Connection Monitor    • IP Flow Verify    • Next Hop         │   │
│  │  • NSG Diagnostics       • Packet Capture    • Topology         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Log Analytics Workspace

O Log Analytics Workspace e o repositorio central para dados de log e metricas no Azure Monitor.

1. Pesquise e selecione **Log Analytics workspaces**

2. Se voce ja criou o workspace `az104-law1` na Task 4.5, pule para a Task 5.2. Caso contrario, clique em **+ Create**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg13`       |
   | Name           | `az104-law1`       |
   | Region         | **East US**        |

3. Clique em **Review + Create** > **Create**

4. Apos o deploy, va para o workspace e explore:
   - **General** > **Logs** - interface de query KQL
   - **Settings** > **Agents** - instrucoes para conectar recursos
   - **Usage and estimated costs** - volume de dados e custos

   > **Conceito:** O workspace e cobrado por volume de dados ingeridos (GB/dia). O tier padrao e **Pay-As-You-Go**. Para volumes maiores, existem **Commitment Tiers** com desconto. Os dados sao retidos por 30 dias gratuitamente (extensivel ate 730 dias com custo).

   > **Dica AZ-104:** Na prova, saiba que workspaces podem receber dados de multiplas subscriptions e tenants. A arquitetura recomendada e **centralizada** (um workspace para a maioria dos cenarios) vs **descentralizada** (multiplos workspaces para compliance ou separacao de dados).

---

### Task 5.2: Conectar VM ao workspace (instalar Azure Monitor Agent)

O Azure Monitor Agent (AMA) coleta dados de telemetria do Guest OS e os envia para o Log Analytics workspace.

1. Pesquise e selecione **Monitor** > **Settings** > **Data Collection Rules**

2. Clique em **+ Create**:

   | Setting           | Value                    |
   | ----------------- | ------------------------ |
   | Rule Name         | `az104-dcr-vm`           |
   | Subscription      | *sua subscription*       |
   | Resource Group    | `az104-rg13`             |
   | Platform Type     | **Windows** (ou Linux conforme sua VM) |

3. Na aba **Resources**, clique em **+ Add resources**

4. Expanda o resource group `az104-rg13` e selecione **az104-vm-monitor**

5. Clique em **Apply**

   > **Nota:** O Azure instala automaticamente o **Azure Monitor Agent (AMA)** na VM quando voce a adiciona como resource em uma Data Collection Rule.

6. Na aba **Collect and deliver**, clique em **+ Add data source**:

   | Setting        | Value                      |
   | -------------- | -------------------------- |
   | Data source type | **Windows Event Logs** (ou **Linux Syslog**) |

7. Selecione os logs a coletar:

   | Category    | Level           |
   | ----------- | --------------- |
   | Application | **Critical, Error, Warning** |
   | Security    | **Audit success, Audit failure** |
   | System      | **Critical, Error, Warning** |

8. Na aba **Destination**, configure:

   | Setting     | Value              |
   | ----------- | ------------------ |
   | Destination | **Azure Monitor Logs** |
   | Workspace   | `az104-law1`       |

9. Clique em **Add data source**

10. Adicione outro data source para **Performance Counters**:

    | Setting          | Value                  |
    | ---------------- | ---------------------- |
    | Data source type | **Performance Counters** |
    | Counters         | **Basic** (CPU, Memory, Disk, Network) |

11. Configure o destino para o mesmo workspace `az104-law1`

12. Clique em **Review + Create** > **Create**

13. Aguarde 5-10 minutos para o agente ser instalado e os primeiros dados chegarem

    > **Conceito:** O **Azure Monitor Agent (AMA)** substitui os agentes legados (Log Analytics Agent/MMA e Diagnostics Extension). O AMA usa **Data Collection Rules (DCR)** para definir o que coletar e para onde enviar. Vantagens do AMA: multi-homing nativo, filtros granulares, suporte a Azure Arc.

---

### Task 5.3: Executar queries KQL basicas (Heartbeat, Perf, Event)

O KQL (Kusto Query Language) e a linguagem de query usada no Log Analytics para analisar dados de log.

1. Va para o workspace **az104-law1** > **General** > **Logs**

2. Feche o painel de queries de exemplo se aparecer

3. Execute a query **Heartbeat** (verifica quais VMs estao reportando):

   ```kql
   Heartbeat
   | where TimeGenerated > ago(1h)
   | summarize LastHeartbeat = max(TimeGenerated) by Computer
   | order by LastHeartbeat desc
   ```

   > **Conceito:** A tabela **Heartbeat** recebe um registro a cada minuto de cada agente conectado. E a forma mais simples de verificar se um agente esta ativo e reportando.

4. Execute a query **Perf** (metricas de performance):

   ```kql
   Perf
   | where TimeGenerated > ago(1h)
   | where ObjectName == "Processor" and CounterName == "% Processor Time"
   | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
   | render timechart
   ```

   > **Conceito:** A tabela **Perf** armazena contadores de performance coletados pelo agente. Voce pode usar `summarize` para agregar dados e `render timechart` para visualizar graficamente.

5. Execute a query **Event** (Windows Event Logs):

   ```kql
   Event
   | where TimeGenerated > ago(24h)
   | where EventLevelName in ("Error", "Warning")
   | summarize Count = count() by EventLog, EventLevelName
   | order by Count desc
   ```

6. Execute uma query de **alertas de disco**:

   ```kql
   Perf
   | where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
   | where InstanceName != "_Total"
   | summarize AvgFreeSpace = avg(CounterValue) by Computer, InstanceName
   | where AvgFreeSpace < 20
   | order by AvgFreeSpace asc
   ```

7. Explore as opcoes de resultado:
   - **Results** - tabela de dados
   - **Chart** - visualizacao grafica
   - **Pin to dashboard** - fixar no dashboard
   - **Export** - CSV, Power BI

   > **Dica AZ-104:** Na prova, voce precisa entender a sintaxe basica do KQL: `where` (filtrar), `summarize` (agregar), `count()`, `avg()`, `max()`, `order by`, `render` (visualizar), `ago()` (tempo relativo) e `bin()` (agrupamento temporal). Nao e necessario memorizar queries complexas, mas entender a estrutura.

---

### Task 5.4: Habilitar VM Insights

VM Insights fornece uma visao completa de performance, dependencias de aplicacao e saude das VMs.

1. Pesquise e selecione **Monitor** > **Insights** > **Virtual Machines**

2. Selecione a aba **Not Monitored** para ver VMs sem Insights habilitado

3. Localize **az104-vm-monitor** e clique em **Enable**

4. Na configuracao:

   | Setting                       | Value           |
   | ----------------------------- | --------------- |
   | Enable Insights using         | **Azure Monitor Agent (Recommended)** |
   | Log Analytics workspace       | `az104-law1`    |
   | Data Collection Rule          | *crie ou selecione uma DCR* |

5. Clique em **Configure** e aguarde a configuracao (5-10 minutos)

6. Apos habilitado, explore as abas do VM Insights:

   - **Performance:** Graficos de CPU, memoria, disco e rede ao longo do tempo
   - **Map:** Mapa de dependencias mostrando conexoes de rede da VM com outros servicos e servidores
   - **Health:** Diagnostico de saude da VM (preview)

7. Na aba **Map**, observe:
   - Processos rodando na VM
   - Conexoes de entrada e saida
   - Portas em uso
   - Dependencias externas

   > **Conceito:** VM Insights usa o **Dependency Agent** (instalado automaticamente junto com o AMA) para mapear dependencias de rede. O mapa mostra conexoes TCP ativas, processos, portas e servidores remotos conectados. E extremamente util para entender a arquitetura de uma aplicacao e planejar migracoes.

   > **Dica AZ-104:** Para a prova, saiba que VM Insights requer: 1) Azure Monitor Agent instalado na VM, 2) Um Log Analytics workspace configurado, 3) O Dependency Agent para a funcionalidade de Map.

---

### Task 5.5: Criar Workbook personalizado

Workbooks combinam texto, queries KQL, metricas e parametros em relatorios interativos e reutilizaveis.

1. Pesquise e selecione **Monitor** > **Workbooks**

2. Clique em **+ New**

3. O editor do Workbook abre. Clique em **Add** > **Add text**:
   - Adicione o texto em markdown: `## Relatorio de Monitoramento - az104-rg13`
   - Clique em **Done Editing**

4. Clique em **Add** > **Add query**:

   | Setting         | Value                  |
   | --------------- | ---------------------- |
   | Data source     | **Logs**               |
   | Resource type   | **Log Analytics**      |
   | Log Analytics workspace | `az104-law1`   |

5. Cole a query:

   ```kql
   Perf
   | where TimeGenerated > ago(1h)
   | where ObjectName == "Processor" and CounterName == "% Processor Time"
   | summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m)
   | render timechart
   ```

6. Configure a visualizacao:

   | Setting       | Value          |
   | ------------- | -------------- |
   | Visualization | **Time chart** |
   | Size          | **Medium**     |

7. Clique em **Done Editing**

8. Adicione mais secoes conforme necessario (metricas, parametros, textos)

9. Clique em **Save** (icone de disquete):

   | Setting        | Value                     |
   | -------------- | ------------------------- |
   | Title          | `az104-monitoring-report` |
   | Resource Group | `az104-rg13`              |

10. Explore as opcoes:
    - **Pin** - fixar no dashboard
    - **Share** - compartilhar com outros usuarios
    - **Templates** - usar templates pre-construidos

    > **Conceito:** Workbooks sao mais poderosos que dashboards para relatorios porque suportam: parametros interativos (dropdowns, sliders), queries KQL dinamicas, formatacao rica com markdown, agrupamento de metricas e logs em um unico relatorio, e templates reutilizaveis.

---

### Task 5.6: Configurar Network Watcher (Connection Monitor)

O Network Watcher fornece ferramentas de diagnostico e monitoramento de rede para recursos Azure.

1. Pesquise e selecione **Network Watcher**

2. Explore as ferramentas disponiveis:

   | Ferramenta              | Funcao                                          |
   | ----------------------- | ----------------------------------------------- |
   | **Connection Monitor**  | Monitora conectividade continuamente             |
   | **Connection Troubleshoot** | Testa conectividade pontual entre endpoints |
   | **IP Flow Verify**      | Verifica se trafego e permitido/bloqueado por NSG |
   | **Next Hop**            | Mostra a proxima rota para trafego de uma VM    |
   | **NSG Diagnostics**     | Analisa regras NSG aplicadas                     |
   | **Packet Capture**      | Captura pacotes de rede de uma VM               |
   | **Topology**            | Visualiza topologia de rede                      |

3. Selecione **Connection Monitor** > **+ Create**

4. Na aba **Basics**:

   | Setting                   | Value                    |
   | ------------------------- | ------------------------ |
   | Connection Monitor Name   | `az104-conn-monitor`     |
   | Subscription              | *sua subscription*       |
   | Region                    | **East US**              |

5. Na aba **Test groups**, clique em **+ Add test group**:

   | Setting         | Value                    |
   | --------------- | ------------------------ |
   | Test group name | `vm-connectivity-test`   |

6. Clique em **Add sources** e selecione **az104-vm-monitor**

7. Clique em **Add destinations** e selecione um destino:
   - **External Addresses:** `www.microsoft.com` (porta 443)
   - Ou selecione outro recurso Azure

8. Clique em **Add test configuration**:

   | Setting    | Value        |
   | ---------- | ------------ |
   | Name       | `http-test`  |
   | Protocol   | **HTTP**     |
   | Port       | **443**      |
   | Test frequency | **30 seconds** |

9. Clique em **Add Test Group** > **Review + Create** > **Create**

10. Aguarde a configuracao e monitore os resultados:
    - **Reachability** - percentual de checks bem-sucedidos
    - **Round-trip time** - latencia
    - **Checks failed** - falhas de conectividade

11. Agora teste o **Connection Troubleshoot** (diagnostico pontual):
    - Selecione **Connection troubleshoot** no Network Watcher
    - Configure source (VM) e destination (IP/FQDN + porta)
    - Clique em **Check** e revise o resultado

    > **Conceito:** **Connection Monitor** e para monitoramento **continuo** - ideal para detectar problemas intermitentes e medir tendencias de latencia. **Connection Troubleshoot** e para diagnostico **pontual** - ideal para debug de problemas especificos. Ambos verificam NSGs, rotas e conectividade end-to-end.

    > **Dica AZ-104:** Na prova, saiba diferenciar as ferramentas do Network Watcher: IP Flow Verify (NSG check), Next Hop (routing), Connection Troubleshoot (end-to-end pontual), Connection Monitor (end-to-end continuo), Packet Capture (deep inspection).

---

## Modo Desafio - Bloco 5

- [ ] Criar (ou confirmar) Log Analytics Workspace `az104-law1` em East US
- [ ] Criar Data Collection Rule `az104-dcr-vm` para Windows Event Logs e Performance Counters
- [ ] Conectar `az104-vm-monitor` ao workspace via Azure Monitor Agent
- [ ] Aguardar dados chegarem e executar query Heartbeat
- [ ] Executar query Perf para CPU com timechart
- [ ] Executar query Event para erros e warnings
- [ ] Habilitar VM Insights para `az104-vm-monitor`
- [ ] Explorar abas Performance e Map do VM Insights
- [ ] Criar Workbook `az104-monitoring-report` com query de CPU
- [ ] Configurar Connection Monitor para monitorar conectividade da VM
- [ ] Testar Connection Troubleshoot para um destino externo
- [ ] Explorar IP Flow Verify e Next Hop no Network Watcher

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Qual e a sintaxe KQL correta para encontrar os 10 computadores com maior uso de CPU na ultima hora?**

A) `SELECT TOP 10 Computer, AVG(CPU) FROM Perf WHERE TimeGenerated > ago(1h)`
B) `Perf | where TimeGenerated > ago(1h) | where CounterName == "% Processor Time" | summarize AvgCPU = avg(CounterValue) by Computer | top 10 by AvgCPU desc`
C) `Perf.filter(TimeGenerated > ago(1h)).groupBy(Computer).avg(CounterValue).limit(10)`
D) `GET Perf WHERE time > 1h AND counter = "CPU" ORDER BY avg(value) LIMIT 10`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `Perf | where TimeGenerated > ago(1h) | where CounterName == "% Processor Time" | summarize AvgCPU = avg(CounterValue) by Computer | top 10 by AvgCPU desc`**

KQL usa o operador pipe (`|`) para encadear operacoes. A sintaxe basica e: `Tabela | operador1 | operador2`. Os operadores principais sao: `where` (filtrar), `summarize` (agregar), `top` (primeiros N resultados), `order by` (ordenar), `project` (selecionar colunas), `render` (visualizar). KQL NAO e SQL - a sintaxe e diferente.

</details>

### Questao 5.2
**Sua empresa quer migrar do Log Analytics Agent (MMA) para o Azure Monitor Agent (AMA). Qual e a principal vantagem do AMA?**

A) AMA e gratuito enquanto MMA e pago
B) AMA usa Data Collection Rules para configuracao granular, suporta multi-homing nativo e funciona com Azure Arc
C) AMA coleta mais tipos de dados que o MMA
D) AMA nao requer um Log Analytics workspace

<details>
<summary>Ver resposta</summary>

**Resposta: B) AMA usa Data Collection Rules para configuracao granular, suporta multi-homing nativo e funciona com Azure Arc**

O **Azure Monitor Agent (AMA)** oferece varias vantagens sobre o legado **Log Analytics Agent (MMA)**:
- **Data Collection Rules (DCR):** Configuracao centralizada e granular do que coletar e para onde enviar
- **Multi-homing nativo:** Enviar dados para multiplos workspaces sem configuracao adicional
- **Azure Arc:** Suporta servidores on-premises e multi-cloud via Azure Arc
- **Seguranca:** Usa managed identity em vez de workspace keys
- **Performance:** Melhor uso de recursos na VM

O MMA foi descontinuado em agosto de 2024.

</details>

### Questao 5.3
**Voce habilitou VM Insights para uma VM. Quais funcionalidades estao disponiveis?**

A) Apenas metricas de CPU e memoria
B) Performance (CPU, memoria, disco, rede), Map (dependencias e conexoes), e Health diagnostics
C) Apenas o mapa de dependencias
D) Apenas alertas automaticos de performance

<details>
<summary>Ver resposta</summary>

**Resposta: B) Performance (CPU, memoria, disco, rede), Map (dependencias e conexoes), e Health diagnostics**

VM Insights oferece tres funcionalidades principais:
- **Performance:** Graficos detalhados de CPU, memoria, disco e rede com tendencias temporais e comparacao entre VMs
- **Map:** Visualizacao das dependencias da VM incluindo processos, conexoes TCP, portas e servidores remotos (requer Dependency Agent)
- **Health:** Diagnostico de saude baseado em criterios pre-definidos

VM Insights requer o Azure Monitor Agent e, para a funcionalidade Map, tambem o Dependency Agent.

</details>

### Questao 5.4
**Um administrador precisa verificar se o trafego de uma VM esta sendo bloqueado por um NSG. Qual ferramenta do Network Watcher ele deve usar?**

A) Connection Monitor
B) Packet Capture
C) IP Flow Verify
D) Topology

<details>
<summary>Ver resposta</summary>

**Resposta: C) IP Flow Verify**

O **IP Flow Verify** verifica se um pacote especifico (definido por IP de origem/destino, porta e protocolo) e permitido ou negado pelas regras NSG associadas a uma VM. Ele retorna a regra NSG especifica que permite ou bloqueia o trafego. Ferramentas relacionadas:
- **Connection Monitor:** Monitora conectividade continuamente (nao especifico para NSG)
- **Packet Capture:** Captura pacotes para analise detalhada (nivel mais baixo)
- **Topology:** Visualiza a topologia de rede (nao diagnostica problemas)
- **NSG Diagnostics:** Analisa todas as regras NSG efetivas (mais abrangente que IP Flow Verify)

</details>

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos inesperados, especialmente VMs e replicacao ASR que geram custo contínuo.

## Passos Obrigatorios Antes de Deletar

> **IMPORTANTE:** Voce deve desabilitar backups e parar a replicacao ASR ANTES de deletar os resource groups e os vaults. Caso contrario, a exclusao falhara.

### 1. Desabilitar Backup de VMs e File Shares

1. Va para o vault **az104-rsv1** > **Protected items** > **Backup items**
2. Para cada item protegido (VM e File Share):
   - Selecione o item
   - Clique em **Stop Backup**
   - Selecione **Delete Backup Data**
   - Digite o nome do item para confirmar
   - Clique em **Stop Backup**

### 2. Parar Replicacao ASR

1. Va para o vault **az104-rsv-asr** > **Protected items** > **Replicated items**
2. Selecione **az104-vm-asr**
3. Clique em **Disable Replication**
4. Selecione **Disable replication and remove** (nao apenas parar)
5. Confirme a operacao

### 3. Deletar os Vaults

> **Nota:** Apos desabilitar todos os backups e replicacoes, voce pode deletar os vaults. Se a exclusao falhar, verifique se ainda existem items protegidos.

## Via Azure Portal

1. **Deletar Resource Groups** (na seguinte ordem):
   - `az104-rg13` (VMs de monitoramento, Log Analytics - PRIORIDADE)
   - `az104-rg12` (VMs ASR e vault ASR)
   - `az104-rg11` (VMs backup, vault backup, storage account)

   Para cada RG: selecione o RG > **Delete resource group** > digite o nome > **Delete**

2. **Verificar resource groups criados automaticamente pelo ASR:**
   - Pesquise **Resource groups** e procure por `az104-rg12-asr` (criado automaticamente pelo ASR)
   - Delete se existir

3. **Deletar dashboards compartilhados:**
   - Pesquise **Dashboard** > selecione `az104-monitoring-dashboard` > **Delete**

4. **Deletar alert rules e action groups:**
   - Pesquise **Monitor** > **Alerts** > **Alert rules** > delete `az104-cpu-alert`
   - Pesquise **Monitor** > **Alerts** > **Action groups** > delete `az104-action-group`

## Via CLI (alternativa rapida)

```bash
VAULT_NAME="az104-rsv1"
VAULT_ASR="az104-rsv-asr"
RG11="az104-rg11"
RG12="az104-rg12"
RG13="az104-rg13"

# 1. Desabilitar backup de VMs (descoberta dinamica dos nomes internos)
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG11" \
  --backup-management-type AzureIaasVM \
  --query "[].name" -o tsv 2>/dev/null); do
  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureIaasVM \
    --query "[].name" -o tsv 2>/dev/null); do
    echo "Desabilitando backup: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" -g "$RG11" \
      --backup-management-type AzureIaasVM \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 2. Desabilitar backup de File Shares (descoberta dinamica)
for CONTAINER in $(az backup container list \
  --vault-name "$VAULT_NAME" -g "$RG11" \
  --backup-management-type AzureStorage \
  --query "[].name" -o tsv 2>/dev/null); do
  for ITEM in $(az backup item list \
    --vault-name "$VAULT_NAME" -g "$RG11" \
    --container-name "$CONTAINER" \
    --backup-management-type AzureStorage \
    --query "[].name" -o tsv 2>/dev/null); do
    echo "Desabilitando backup: $ITEM"
    az backup protection disable \
      --container-name "$CONTAINER" --item-name "$ITEM" \
      --vault-name "$VAULT_NAME" -g "$RG11" \
      --backup-management-type AzureStorage \
      --delete-backup-data true --yes 2>/dev/null
  done
done

# 3. Deletar vault de backup (apos desabilitar protecoes)
az backup vault delete -g "$RG11" --name "$VAULT_NAME" --yes 2>/dev/null

# 4. Desabilitar replicacao ASR
#    NOTA: az site-recovery requer extensao (az extension add --name site-recovery).
#    Recomenda-se desabilitar via Portal: Vault > Replicated Items > Disable Replication
echo "Desabilite a replicacao ASR via Portal antes de deletar o vault."
echo "  Vault: $VAULT_ASR > Replicated Items > selecionar > Disable Replication"
az backup vault delete -g "$RG12" --name "$VAULT_ASR" --yes 2>/dev/null

# 5. Deletar RGs
az group delete --name "$RG13" --yes --no-wait
az group delete --name "$RG12" --yes --no-wait
az group delete --name "$RG11" --yes --no-wait

# 6. Deletar RG criado automaticamente pelo ASR (se existir)
az group delete --name az104-rg12-asr --yes --no-wait 2>/dev/null

# 7. Deletar Connection Monitor
az network watcher connection-monitor delete --name az104-conn-monitor --location eastus 2>/dev/null
```

## Via PowerShell (alternativa)

```powershell
# 1. Desabilitar protecoes de backup
$vault = Get-AzRecoveryServicesVault -ResourceGroupName az104-rg11 -Name az104-rsv1
Set-AzRecoveryServicesVaultContext -Vault $vault

# VM backup
$backupItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID
Disable-AzRecoveryServicesBackupProtection -Item $backupItem -RemoveRecoveryPoints -Force -VaultId $vault.ID

# File Share backup
$backupItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureStorage -WorkloadType AzureFiles -VaultId $vault.ID
Disable-AzRecoveryServicesBackupProtection -Item $backupItem -RemoveRecoveryPoints -Force -VaultId $vault.ID

# 2. Deletar vaults
Remove-AzRecoveryServicesVault -Vault $vault

# 3. Deletar RGs
Remove-AzResourceGroup -Name az104-rg13 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg12 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg11 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg12-asr -Force -AsJob

# 4. Deletar alert rule e action group
Remove-AzMetricAlertRuleV2 -ResourceGroupName az104-rg13 -Name az104-cpu-alert
Remove-AzActionGroup -ResourceGroupName az104-rg13 -Name az104-action-group
```

> **Nota:** A exclusao completa dos resource groups pode levar varios minutos, especialmente os que contem VMs e vaults. Verifique no portal se todos os RGs foram deletados com sucesso.

---

# Key Takeaways Consolidados

## Bloco 1 - VM Backup
| Conceito | Aplicacao no Exame |
| -------- | ------------------ |
| Recovery Services Vault vs Backup Vault | RSV suporta VMs, SQL, File Shares; Backup Vault suporta Disks, Blobs, PostgreSQL |
| Backup Policy (GFS) | Retencao diaria, semanal, mensal, anual - entenda a hierarquia |
| Instant Restore | Snapshots locais para restauracao rapida (minutos vs horas) |
| Opcoes de restauracao | Create new VM, Replace existing (VM deve existir), Restore disk |
| Backup on-demand | Usa retencao da policy salvo especificacao contraria |

## Bloco 2 - File & Blob Protection
| Conceito | Aplicacao no Exame |
| -------- | ------------------ |
| File Share Backup | Baseado em share snapshots, gerenciado pelo vault |
| Soft Delete (blobs) | Habilitado por padrao (7 dias), recuperacao via Undelete |
| Soft Delete (containers) | Deve ser habilitado separadamente |
| Blob Versioning | Versoes automaticas a cada modificacao, independente de soft delete |
| Snapshot vs Backup | Snapshot e manual; backup via vault e automatizado com retencao e alertas |

## Bloco 3 - Azure Site Recovery
| Conceito | Aplicacao no Exame |
| -------- | ------------------ |
| RPO vs RTO | RPO = perda de dados aceitavel; RTO = tempo para restaurar servico |
| Vault ASR na regiao de destino | Diferente do vault de backup (mesma regiao dos recursos) |
| Test Failover | Nao impacta producao, cleanup obrigatorio antes de failover real |
| Planned vs Unplanned Failover | Planned = zero data loss; Unplanned = possivel data loss |
| Recovery Plan | Orquestra failover de multiplas VMs em grupos sequenciais |

## Bloco 4 - Azure Monitor & Alerts
| Conceito | Aplicacao no Exame |
| -------- | ------------------ |
| Host metrics vs Guest OS metrics | Host = automatico; Guest OS = requer agente (AMA) |
| Metric alerts vs Log alerts | Metricas = tempo real, numerico; Logs = KQL, mais flexivel |
| Action Groups | Reutilizaveis, multiplas notificacoes e acoes em um unico grupo |
| Diagnostic Settings destinos | Log Analytics, Storage Account, Event Hub (simultaneos) |
| Dashboards compartilhados | Recursos Azure gerenciados por RBAC (Reader para visualizar) |

## Bloco 5 - Log Analytics & Insights
| Conceito | Aplicacao no Exame |
| -------- | ------------------ |
| AMA vs MMA (legado) | AMA usa DCR, multi-homing nativo, Azure Arc, managed identity |
| Data Collection Rules (DCR) | Configuracao centralizada do que coletar e para onde enviar |
| KQL basico | where, summarize, count(), avg(), top, render, ago(), bin() |
| VM Insights | Performance + Map (dependencias) + Health; requer AMA + Dependency Agent |
| Network Watcher tools | IP Flow Verify (NSG), Next Hop (routing), Connection Monitor (continuo) |
| Workbooks vs Dashboards | Workbooks = relatorios interativos com parametros e queries KQL |
