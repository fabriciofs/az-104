> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 3 - Site Recovery (DR)](bloco3-site-recovery.md)

# Bloco 2 - File & Blob Protection

**Origem:** Lab 10 (continuacao) + Azure Backup for File Shares + Soft Delete & Versioning
**Resource Groups utilizados:** `az104-rg-backup` (vault do Bloco 1) + `az104-rg6` (Storage da Semana 2)

## Contexto

Na Semana 2, voce criou storage accounts com file shares e blob containers no `az104-rg6`. Agora voce protege esses dados com backup de file shares (usando o **mesmo vault do Bloco 1**) e configura soft delete + versioning como camadas adicionais de protecao.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                    az104-rg-backup (Bloco 1)                       │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          Recovery Services Vault: az104-rsv (Bloco 1)        │  │
│  │                                                              │  │
│  │  Backup Items:                                               │  │
│  │  ├─ Azure VMs: az104-vm-win, az104-vm-linux ◄── Bloco 1      │  │
│  │  └─ Azure File Share: az104-share ◄── NOVO (este bloco)      │  │
│  │                                                              │  │
│  │  File Share Backup Policy:                                   │  │
│  │  └─ az104-fs-policy (daily, 30 days)                         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  az104-rg6 (Semana 2 — Storage)                              │  │
│  │                                                              │  │
│  │  ┌───────────────────────────────────────────────┐           │  │
│  │  │ Storage Account: az104storageXXX (Semana 2)   │           │  │
│  │  │                                               │           │  │
│  │  │ File Shares:                                  │           │  │
│  │  │ └─ az104-share ──── backup via RSV ✓          │           │  │
│  │  │                                               │           │  │
│  │  │ Blob Containers:                              │           │  │
│  │  │ └─ az104-container                            │           │  │
│  │  │    ├─ Soft delete: 14 dias ✓ (NOVO)           │           │  │
│  │  │    └─ Versioning: habilitado ✓ (NOVO)         │           │  │
│  │  └───────────────────────────────────────────────┘           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Vault reutilizado do Bloco 1                                    │
│  → Storage account reutilizado da Semana 2                         │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Configurar backup de file share

Voce usa o **mesmo vault** criado no Bloco 1 para proteger o file share da Semana 2.

> **Pre-requisito:** O storage account com file share `az104-share` deve existir no `az104-rg6` (criado na Semana 2). Se nao existir, crie um storage account com um file share antes de continuar.

1. No vault **az104-rsv** (criado no Bloco 1), va para **Getting started** > **Backup**

2. Configure:

   | Setting                         | Value                |
   | ------------------------------- | -------------------- |
   | Where is your workload running? | **Azure**            |
   | What do you want to back up?    | **Azure File Share** |

3. Clique em **Backup**

4. Em **Storage Account**, clique em **Select** > selecione o storage account do `az104-rg6` (da Semana 2)

   > **Conexao com Semana 2:** Voce esta protegendo o mesmo file share que os usuarios da Contoso Corp utilizam para armazenamento corporativo (configurado na Semana 2).

5. Clique em **OK** e aguarde o vault registrar o storage account

---

### Task 2.2: Criar policy de backup para file share

1. Em **Backup policy**, clique em **Create a new policy**

2. Configure:

   | Setting            | Value                                           |
   | ------------------ | ----------------------------------------------- |
   | Policy name        | `az104-fs-policy`                               |
   | Frequency          | **Daily**                                       |
   | Time               | `12:00 AM`                                      |
   | Timezone           | **(UTC-03:00) Brasilia**                        |
   | Retention of daily | **30** days                                     |
   | Weekly backup      | **Enabled** — Sunday, retain **8** weeks        |
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

   | Opcao                  | Descricao                                        |
   | ---------------------- | ------------------------------------------------ |
   | **Full Share Restore** | Restaura todo o file share para original ou novo |
   | **Item Level Restore** | Restaura arquivos/pastas individuais             |

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

   | Setting                           | Value       |
   | --------------------------------- | ----------- |
   | Enable soft delete for blobs      | **Checked** |
   | Days to retain deleted blobs      | **14**      |
   | Enable soft delete for containers | **Checked** |
   | Days to retain deleted containers | **14**      |

4. Clique em **Save**

   > **Conceito:** Soft delete mantem os dados deletados por um periodo configuravel (1-365 dias). Durante esse periodo, voce pode restaurar blobs e containers excluidos. Depois do periodo, a exclusao se torna permanente.

---

### Task 2.7: Habilitar blob versioning

1. No mesmo storage account, ainda em **Data management** > **Data protection**

2. Em **Tracking**, configure:

   | Setting                     | Value       |
   | --------------------------- | ----------- |
   | Enable versioning for blobs | **Checked** |

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

