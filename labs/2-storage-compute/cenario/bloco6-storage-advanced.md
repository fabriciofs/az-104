> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 7 - ACR e App Service Avancado](bloco7-acr-appservice-advanced.md)

# Bloco 6 - Storage Avancado e Disk Encryption

**Origem:** Lab 07 - Manage Azure Storage (topicos avancados) + Azure Disk Encryption
**Resource Groups utilizados:** `rg-contoso-storage` (Storage do Bloco 1) + `rg-contoso-compute` (VMs do Bloco 2) + `rg-contoso-storage` (recursos novos)

## Contexto

Com a Storage Account e as VMs ja operacionais (Blocos 1-2), a Contoso Corp precisa implementar operacoes avancadas de storage cobradas no exame AZ-104: transferencias em massa com AzCopy, gerenciamento visual com Storage Explorer, replicacao entre storage accounts, criptografia com chaves gerenciadas pelo cliente (CMK), controle de acesso baseado em identidade para Azure Files, e criptografia de discos de VMs existentes.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     rg-contoso-storage + rg-contoso-storage                             │
│                                                                          │
│  ┌──────────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ stcontosoprod01 (Bloco 1)      │  │ stcontosorepl01 (NOVO)            │  │
│  │                              │  │                                  │  │
│  │ Container: data              │  │ Container: data-replica          │  │
│  │ File Share: contoso-files    │  │                                  │  │
│  │                              │  │                                  │  │
│  │ ←─── AzCopy ────────────────→│  │                                  │  │
│  │ ←─── Object Replication ────→│──│─── regras de replicacao          │  │
│  │                              │  │                                  │  │
│  │ Encryption: CMK              │  └──────────────────────────────────┘  │
│  │ └─ via Key Vault             │                                        │
│  │                              │  ┌──────────────────────────────────┐  │
│  │ File Share: Identity-based   │  │ Key Vault: kv-contoso-prod            │  │
│  │ └─ Entra ID auth             │  │ • Key: storage-cmk               │  │
│  └──────────────────────────────┘  │ • Key: disk-encryption           │  │
│                                    └──────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │ rg-contoso-compute (VMs do Bloco 2)                                       │    │
│  │ • vm-web-01: Azure Disk Encryption (via Key Vault)            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### Task 6.1: Transferir blobs com AzCopy

AzCopy e a ferramenta de linha de comando para transferencias de alta performance entre storage accounts.

**Gerar SAS tokens:**

1. Navegue para a Storage Account **stcontosoprod01** (do Bloco 1) > **Security + networking** > **Shared access signature**

2. Configure o SAS de **origem** (leitura):

   | Setting                | Value                      |
   | ---------------------- | -------------------------- |
   | Allowed services       | **Blob**                   |
   | Allowed resource types | **Container** + **Object** |
   | Allowed permissions    | **Read** + **List**        |
   | Expiry                 | *amanha*                   |
   | Allowed protocols      | **HTTPS only**             |

3. Clique em **Generate SAS and connection string** > copie o **SAS token** (comeca com `?sv=`)

4. Crie uma segunda Storage Account para destino. Pesquise **Storage accounts** > **+ Create**:

   | Setting              | Value                               |
   | -------------------- | ----------------------------------- |
   | Resource group       | `rg-contoso-storage` (crie se necessario) |
   | Storage account name | `stcontosorepl01`           |
   | Region               | **(US) East US**                    |
   | Redundancy           | **LRS**                             |

5. **Review + create** > **Create**

6. Na **stcontosorepl01**, crie um container `data-replica` (Private)

7. Gere um SAS de **destino** (escrita) na stcontosorepl01:

   | Setting                | Value                                        |
   | ---------------------- | -------------------------------------------- |
   | Allowed services       | **Blob**                                     |
   | Allowed resource types | **Container** + **Object**                   |
   | Allowed permissions    | **Read** + **Write** + **List** + **Create** |
   | Expiry                 | *amanha*                                     |

8. Copie o **SAS token** do destino

**Executar AzCopy no Cloud Shell:**

9. Abra o **Cloud Shell** (Bash)

10. Execute a copia entre containers:

    ```bash
    azcopy copy \
      'https://stcontosoprod01.blob.core.windows.net/data?<SAS-ORIGEM>' \
      'https://stcontosorepl01.blob.core.windows.net/data-replica?<SAS-DESTINO>' \
      --recursive
    ```

11. Verifique o resultado — o blob do container `data` deve aparecer em `data-replica`

12. Navegue para **stcontosorepl01** > **Containers** > **data-replica** e confirme que o blob foi copiado

    > **Conceito:** AzCopy transfere dados entre storage accounts usando a rede backbone do Azure (server-to-server). Nao passa pelo seu computador local. Suporta SAS tokens, Azure AD auth e access keys. Para volumes grandes, use `--cap-mbps` para limitar banda.

    > **Dica AZ-104:** Na prova, AzCopy e a ferramenta recomendada para transferencias em massa. Storage Explorer usa AzCopy internamente. Para copias programaticas, use `az storage blob copy` (CLI) ou `Start-AzStorageBlobCopy` (PowerShell).

---

### Task 6.2: Gerenciar blobs com Storage Explorer (versao portal)

1. Navegue para a Storage Account **stcontosoprod01** > **Storage browser** (no menu lateral)

2. Expanda **Blob containers** > selecione **data**

3. Explore as funcoes:
   - **Upload**: faca upload de mais um arquivo de teste
   - **New folder**: crie uma pasta virtual `logs/`
   - **Upload** um arquivo dentro da pasta `logs/`

4. Selecione um blob > clique em **...** (mais opcoes):
   - **View/edit**: visualize o conteudo (se for texto)
   - **Generate SAS**: gere um SAS token especifico para este blob

5. Gere um **SAS token** para um blob individual:

   | Setting     | Value             |
   | ----------- | ----------------- |
   | Permissions | **Read**          |
   | Expiry      | *1 hora a frente* |

6. Clique em **Generate SAS token and URL** > copie a **Blob SAS URL**

7. Abra a URL em uma aba anonima — o blob deve ser acessivel

8. Explore **File shares** > **contoso-files** no Storage Browser:
   - Navegue pelos arquivos
   - Faca upload/download de arquivos

   > **Conceito:** Storage Browser (no portal) e Storage Explorer (app desktop) permitem gerenciar blobs, files, queues e tables visualmente. SAS tokens gerados no nivel do blob oferecem acesso granular — mais seguro que SAS no nivel da conta.

---

### Task 6.3: Configurar Object Replication entre storage accounts

Object Replication copia blobs assincronamente entre storage accounts, util para cenarios de DR, latencia reduzida e compliance.

1. Na Storage Account **stcontosoprod01** (origem), navegue para **Data management** > **Object replication**

2. Clique em **Set up replication rules**:

   | Setting             | Value               |
   | ------------------- | ------------------- |
   | Destination account | **stcontosorepl01** |

3. Configure a regra:

   | Setting               | Value          |
   | --------------------- | -------------- |
   | Source container      | `data`         |
   | Destination container | `data-replica` |

   > **Nota:** Object Replication requer **versioning** habilitado em ambas as storage accounts e **change feed** habilitado na origem. O portal habilita automaticamente se nao estiverem ativos.

4. Clique em **Create**

5. **Validacao:** Faca upload de um novo blob no container `data` da conta de origem

6. Aguarde alguns minutos e verifique se o blob aparece em `data-replica` na conta de destino

   > **Conceito:** Object Replication e assincrona — nao ha SLA de tempo para a replicacao. Apenas novos blobs (apos a regra ser criada) sao replicados, a menos que voce habilite "Copy over existing blobs". Os blobs replicados mantem os mesmos nomes e metadados.

   > **Dica AZ-104:** Na prova, diferencie: GRS/GZRS = replicacao sincrona gerenciada pelo Azure (redundancia); Object Replication = replicacao assincrona configuravel pelo usuario (flexibilidade). Object Replication funciona entre qualquer regiao e qualquer conta.

---

### Task 6.4: Configurar Customer-Managed Keys (CMK) via Key Vault

Por padrao, Azure Storage usa Microsoft-managed keys (MMK). CMK permite usar suas proprias chaves armazenadas no Key Vault.

**Criar Key Vault:**

1. Pesquise **Key vaults** > **+ Create**:

   | Setting        | Value                                     |
   | -------------- | ----------------------------------------- |
   | Resource group | `rg-contoso-storage`                            |
   | Key vault name | `kv-contoso-prod<uniqueid>` (globalmente unico) |
   | Region         | **(US) East US**                          |
   | Pricing tier   | **Standard**                              |

2. Aba **Access configuration**:

   | Setting          | Value                               |
   | ---------------- | ----------------------------------- |
   | Permission model | **Azure role-based access control** |
   | Purge protection | **Enable** (requerido para CMK)     |

3. **Review + create** > **Create** > **Go to resource**

**Atribuir permissao para criar chaves:**

4. No Key Vault, navegue para **Access control (IAM)** > **+ Add** > **Add role assignment**:

   | Setting   | Value                        |
   | --------- | ---------------------------- |
   | Role      | **Key Vault Crypto Officer** |
   | Assign to | *sua conta de administrador* |

5. **Review + assign**

**Criar chave:**

6. Navegue para **Objects** > **Keys** > **+ Generate/Import**:

   | Setting  | Value         |
   | -------- | ------------- |
   | Options  | **Generate**  |
   | Name     | `storage-cmk` |
   | Key type | **RSA**       |
   | Key size | **2048**      |

7. Clique em **Create**

**Configurar CMK na Storage Account:**

8. Navegue para **stcontosoprod01** > **Security + networking** > **Encryption**

9. Altere:

   | Setting         | Value                                |
   | --------------- | ------------------------------------ |
   | Encryption type | **Customer-managed keys**            |
   | Key vault       | `kv-contoso-prod<uniqueid>`                |
   | Key             | `storage-cmk`                        |
   | Identity type   | **System-assigned managed identity** |

   > **Nota:** Se o portal solicitar, habilite a System-assigned Managed Identity na Storage Account e atribua a role **Key Vault Crypto Service Encryption User** no Key Vault.

10. Clique em **Save**

11. **Validacao:** Navegue para **Encryption** e confirme que o tipo de criptografia mostra **Customer-managed keys** com o Key Vault e chave corretos

    > **Conceito:** CMK oferece controle total sobre as chaves de criptografia. A Storage Account usa Managed Identity para acessar o Key Vault. Se a chave for revogada ou deletada, os dados ficam inacessiveis. Purge Protection garante que chaves deletadas nao possam ser permanentemente removidas por 90 dias.

    > **Dica AZ-104:** Na prova: CMK requer Key Vault com purge protection habilitado. A Storage Account precisa de Managed Identity com permissao no Key Vault. CMK pode ser aplicado no nivel da conta (todos os dados) ou por escopo de criptografia.

---

### Task 6.5: Configurar acesso baseado em identidade para Azure Files

Azure Files suporta autenticacao via Entra ID (Azure AD) para acesso SMB, eliminando a necessidade de storage keys.

1. Navegue para **stcontosoprod01** > **Data storage** > **File shares**

2. Selecione **contoso-files** > **Settings** > note que o acesso atual usa storage account key

3. Navegue para **stcontosoprod01** > **Data storage** > **File shares** > **Active Directory** (no menu lateral) ou **Settings** > **Identity-based access**

4. Em **Identity-based access for file shares**, configure:

   | Setting                         | Value                           |
   | ------------------------------- | ------------------------------- |
   | Microsoft Entra Domain Services | *Nao habilitado (requer AADDS)* |
   | Microsoft Entra Kerberos        | **Enable** (se disponivel)      |

   > **Nota:** A configuracao completa de autenticacao via Entra ID para Azure Files requer Microsoft Entra Domain Services (AADDS) ou hybrid join. Em ambiente de lab sem AD on-premises, voce explora as configuracoes disponiveis e entende os conceitos.

5. Clique em **Save** (se alteracoes foram feitas)

6. Explore as opcoes de **RBAC para file shares**. Navegue para **contoso-files** > **Access control (IAM)**:
   - Note as roles disponiveis: **Storage File Data SMB Share Reader**, **Storage File Data SMB Share Contributor**, **Storage File Data SMB Share Elevated Contributor**

7. Revise as diferencas entre as roles:

   | Role                                             | Permissoes                          |
   | ------------------------------------------------ | ----------------------------------- |
   | Storage File Data SMB Share Reader               | Read access a arquivos e diretorios |
   | Storage File Data SMB Share Contributor          | Read, write, delete em arquivos     |
   | Storage File Data SMB Share Elevated Contributor | Acima + modificar ACLs NTFS         |

   > **Conceito:** Autenticacao baseada em identidade para Azure Files permite que usuarios acessem file shares usando suas credenciais Entra ID (via Kerberos), sem precisar de storage keys. As permissoes sao atribuidas via RBAC (nivel de share) + ACLs NTFS (nivel de arquivo/diretorio).

   > **Dica AZ-104:** Na prova: existem 3 metodos de autenticacao para Azure Files: (1) Storage account key (padrao), (2) Entra ID Domain Services, (3) On-premises AD DS via sync. RBAC controla acesso no nivel do share; ACLs NTFS controlam acesso granular.

---

### Task 6.6: Habilitar Azure Disk Encryption em VM existente

Azure Disk Encryption (ADE) usa BitLocker (Windows) ou DM-Crypt (Linux) para criptografar discos de VMs usando chaves do Key Vault.

1. Primeiro, crie uma chave no Key Vault para disk encryption. Navegue para **kv-contoso-prod** > **Keys** > **+ Generate/Import**:

   | Setting  | Value             |
   | -------- | ----------------- |
   | Options  | **Generate**      |
   | Name     | `disk-encryption` |
   | Key type | **RSA**           |
   | Key size | **2048**          |

2. Clique em **Create**

3. Habilite o Key Vault para disk encryption. Navegue para **kv-contoso-prod** > **Settings** > **Properties** (ou **Access policies**):
   - Localize **Azure Disk Encryption for volume encryption**
   - Marque **Enabled**
   - Clique em **Save**

4. Navegue para a VM **vm-web-01** (do Bloco 2, em rg-contoso-compute)

   > **Nota:** A VM precisa estar **running** para habilitar ADE.

5. **Settings** > **Disks** > **Additional settings** (ou procure por **Encryption**):
   - Localize **Disks to encrypt**: **OS and data disks** ou **OS disk only**

6. Alternativamente, use o **Cloud Shell** (mais confiavel):

   ```bash
   az vm encryption enable \
     --resource-group rg-contoso-compute \
     --name vm-web-01 \
     --disk-encryption-keyvault kv-contoso-prod<uniqueid> \
     --key-encryption-key disk-encryption \
     --volume-type All
   ```

7. Aguarde o comando completar (pode levar 10-15 minutos)

8. **Validacao:** Verifique o status da criptografia:

   ```bash
   az vm encryption show \
     --resource-group rg-contoso-compute \
     --name vm-web-01 \
     --query "[osDiskEncryptionSettings, dataDiskEncryptionSettings]"
   ```

9. No portal, navegue para **vm-web-01** > **Disks** e verifique que o disco mostra **Encryption: SSE with CMK** ou **ADE**

   > **Conceito:** Azure Disk Encryption (ADE) criptografa o conteudo do disco usando BitLocker/DM-Crypt. E diferente de Server-Side Encryption (SSE), que criptografa o disco no nivel do storage. ADE protege os dados mesmo se o disco for extraido da VM. Ambos podem ser usados juntos.

   > **Dica AZ-104:** Na prova, diferencie: SSE (padrao, automatico, no storage layer) vs ADE (no OS, via BitLocker/DM-Crypt, requer Key Vault). ADE e SSE sao complementares. ADE requer Key Vault com disk encryption habilitado.

---

### Task 6.6: Data Lake Storage Gen2 — Namespace Hierarquico e ACLs POSIX

> Esta task cobre conceitos que cairam no simulado: tipos de conta que suportam ADLS Gen2, namespace hierarquico como pre-requisito para ACLs POSIX, e a diferenca visual entre blob flat vs hierarquico.

**Criar storage account com HNS (Data Lake Gen2):**

1. Pesquise **Storage accounts** > **+ Create**:

   | Setting               | Value                       |
   | --------------------- | --------------------------- |
   | Resource group        | `rg-contoso-storage`              |
   | Storage account name  | `stcontosodatalake` + sufixo  |
   | Region                | **East US**                 |
   | Performance           | **Standard**                |
   | Redundancy            | **LRS**                     |

2. Aba **Advanced**:

   | Setting                          | Value          |
   | -------------------------------- | -------------- |
   | **Enable hierarchical namespace** | **Checked** ✅ |

   > **Conceito:** Marcar "Enable hierarchical namespace" transforma a conta em **Azure Data Lake Storage Gen2**. Sem essa opcao, a conta e blob storage flat (sem diretorios reais).

3. **Review + create** > **Create**

**Verificar que Premium Block Blobs tambem suporta HNS:**

4. Inicie a criacao de outra storage account (NAO precisa criar de fato):

   | Setting     | Value                  |
   | ----------- | ---------------------- |
   | Performance | **Premium**            |
   | Account type| **Block blobs**        |

5. Na aba **Advanced**, confirme que a opcao **Enable hierarchical namespace** esta disponivel

6. Agora troque para **Premium > Page blobs** e note que **HNS NAO esta disponivel**

7. Cancele a criacao (nao precisa criar)

   > **REGRA AZ-104:** Apenas 2 tipos de conta suportam Data Lake Gen2 (HNS): **Standard GPv2** e **Premium Block Blobs**. Page Blobs e File Shares NAO suportam.

**Explorar estrutura hierarquica vs flat:**

8. Navegue para **stcontosodatalake\*** > **Storage browser** > **Blob containers** > **+ Add container**:

   | Setting | Value    |
   | ------- | -------- |
   | Name    | `dados`  |

9. Dentro do container `dados`, clique em **+ Add Directory**:

   | Setting | Value        |
   | ------- | ------------ |
   | Name    | `vendas`     |

10. Dentro de `vendas`, crie outro diretorio `2026` > dentro de `2026`, faca upload de um arquivo qualquer (.txt)

11. Note a estrutura: `dados/vendas/2026/arquivo.txt` — sao **diretorios reais**, nao prefixos virtuais

12. Compare com a storage account **stcontosoprod01** (sem HNS): la, "pastas" sao apenas prefixos no nome do blob

   > **Conceito:** Sem HNS, o Azure simula pastas usando `/` no nome do blob (ex: `vendas/2026/arquivo.txt` e um unico blob com nome longo). Com HNS, diretorios sao objetos reais com metadados proprios — isso habilita operacoes atomicas de rename/move em diretorios inteiros.

**Configurar ACLs POSIX:**

13. No container `dados`, selecione o diretorio `vendas` > clique em **Manage ACL**

14. Observe a estrutura POSIX:

   | Entidade | Read (r) | Write (w) | Execute (x) |
   | -------- | :------: | :-------: | :---------: |
   | Owner    | ✅       | ✅        | ✅          |
   | Group    | ✅       | ❌        | ✅          |
   | Other    | ❌       | ❌        | ❌          |

15. Modifique: conceda **Read + Execute** para **Other** > **Save**

16. Agora volte a storage account **stcontosoprod01** (sem HNS) > tente acessar **Manage ACL** em um blob

17. **Resultado esperado:** A opcao **NAO existe** — ACLs POSIX so funcionam com HNS habilitado

   > **PEGADINHA AZ-104:** "ACLs compativeis com POSIX" → a resposta e **namespace hierarquico** (HNS). NAO e SFTP (protocolo de acesso), NAO e camada de acesso, NAO e suporte imutavel. SFTP inclusive depende de HNS estar habilitado.

---

### Task 6.7: Cleanup Data Lake

1. Delete a storage account **stcontosodatalake\*** (so foi usada para demonstracao)

   > **Nota:** Esta storage account nao e usada em outros blocos, pode ser deletada com seguranca.

---

## Modo Desafio - Bloco 6

- [ ] Gerar SAS tokens (origem: read, destino: write) para ambas as storage accounts
- [ ] Executar AzCopy entre containers de storage accounts diferentes
- [ ] Usar Storage Browser para upload, criar pasta virtual e gerar SAS de blob individual
- [ ] Configurar Object Replication entre stcontosoprod01 e stcontosorepl01
- [ ] Criar Key Vault com purge protection e gerar chave `storage-cmk`
- [ ] Configurar CMK na storage account via Managed Identity + Key Vault
- [ ] Explorar roles RBAC para Azure Files (SMB Share Reader/Contributor/Elevated)
- [ ] Criar chave `disk-encryption` e habilitar ADE na VM Windows **(Bloco 2)**
- [ ] Criar storage account GPv2 **com HNS** (Data Lake Gen2) e verificar que Premium Block Blobs tambem suporta
- [ ] Verificar que Premium Page Blobs **NAO** suporta HNS
- [ ] Criar diretorios reais (vendas/2026/) e comparar com blob flat (prefixos virtuais)
- [ ] Configurar ACLs POSIX no diretorio e confirmar que **sem HNS nao ha ACLs POSIX**
- [ ] Cleanup: deletar stcontosodatalake\*

---

## Questoes de Prova - Bloco 6

### Questao 6.1
**Voce precisa copiar 500 GB de blobs entre duas storage accounts em regioes diferentes. Qual ferramenta e mais eficiente?**

A) Azure Portal (upload/download manual)
B) AzCopy com SAS tokens
C) Azure Data Factory
D) Storage Explorer desktop

<details>
<summary>Ver resposta</summary>

**Resposta: B) AzCopy com SAS tokens**

AzCopy faz transferencias server-to-server (dados trafegam pela rede backbone Azure, nao pelo seu computador). Para volumes grandes entre storage accounts, e a opcao mais eficiente e rapida. Data Factory e mais indicado para pipelines complexos com transformacoes.

</details>

### Questao 6.2
**Voce configurou Object Replication da Storage Account A (East US) para Storage Account B (West Europe). Um blob existente no container de origem nao aparece no destino. Por que?**

A) Object Replication nao funciona entre regioes diferentes
B) Object Replication replica apenas blobs criados apos a configuracao da regra (por padrao)
C) O blob esta no tier Archive e nao pode ser replicado
D) Voce precisa executar AzCopy manualmente para blobs existentes

<details>
<summary>Ver resposta</summary>

**Resposta: B) Object Replication replica apenas blobs criados apos a configuracao da regra (por padrao)**

Por padrao, Object Replication so replica novos blobs. Para incluir blobs existentes, voce precisa habilitar "Copy over existing blobs" na regra de replicacao. Object Replication funciona entre qualquer regiao e qualquer tipo de conta StorageV2.

</details>

### Questao 6.3
**Voce quer configurar Customer-Managed Keys (CMK) para uma Storage Account. Qual configuracao do Key Vault e OBRIGATORIA?**

A) Soft delete habilitado
B) Purge protection habilitado
C) Network firewall configurado
D) Access policy com Wrap/Unwrap Key

<details>
<summary>Ver resposta</summary>

**Resposta: B) Purge protection habilitado**

CMK requer que o Key Vault tenha purge protection habilitado. Isso garante que chaves deletadas nao possam ser permanentemente removidas por 90 dias, protegendo contra perda acidental de acesso aos dados criptografados. Soft delete e habilitado automaticamente com purge protection.

</details>

### Questao 6.4
**Qual a diferenca entre Azure Disk Encryption (ADE) e Server-Side Encryption (SSE)?**

A) ADE e SSE sao a mesma coisa com nomes diferentes
B) ADE criptografa no nivel do OS (BitLocker/DM-Crypt); SSE criptografa no nivel do storage service
C) SSE requer Key Vault; ADE nao
D) ADE esta disponivel apenas para VMs Linux

<details>
<summary>Ver resposta</summary>

**Resposta: B) ADE criptografa no nivel do OS (BitLocker/DM-Crypt); SSE criptografa no nivel do storage service**

SSE e habilitado por padrao em todos os managed disks e criptografa dados at rest no storage layer. ADE usa BitLocker (Windows) ou DM-Crypt (Linux) para criptografar o conteudo do disco no nivel do sistema operacional. Ambos podem ser usados simultaneamente para dupla camada de protecao.

</details>

### Questao 6.5
**Voce precisa conceder acesso a um Azure File Share para usuarios usando suas credenciais do Entra ID. Qual role RBAC voce atribui para permitir leitura e escrita nos arquivos?**

A) Storage Account Contributor
B) Storage Blob Data Contributor
C) Storage File Data SMB Share Contributor
D) Reader

<details>
<summary>Ver resposta</summary>

**Resposta: C) Storage File Data SMB Share Contributor**

As roles especificas para Azure Files via SMB sao: Reader (somente leitura), Contributor (leitura + escrita + exclusao) e Elevated Contributor (acima + modificar ACLs NTFS). Storage Account Contributor gerencia a conta, nao os dados. Storage Blob Data Contributor e para blobs, nao files.

</details>

### Questao 6.6
**Voce precisa criar uma storage account que forneca ACLs (listas de controle de acesso) compativeis com POSIX. Qual opcao voce deve configurar?**

A) Camada de acesso
B) Namespace hierarquico
C) SFTP
D) Suporte imutavel no nivel da versao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Namespace hierarquico**

ACLs POSIX so existem quando o namespace hierarquico (HNS) esta habilitado, o que transforma a conta em Data Lake Storage Gen2. SFTP e um protocolo de acesso que depende de HNS, mas nao habilita ACLs por si so. Camada de acesso e suporte imutavel nao tem relacao com permissoes POSIX.

</details>

### Questao 6.7
**Quais dois tipos de conta suportam Azure Data Lake Storage Gen2?**

A) Standard GPv2 + Premium Page Blobs
B) Standard GPv2 + Premium Block Blobs
C) Premium Block Blobs + Premium File Shares
D) Standard GPv1 + Standard GPv2

<details>
<summary>Ver resposta</summary>

**Resposta: B) Standard GPv2 + Premium Block Blobs**

Data Lake Gen2 requer suporte a Blob Storage com namespace hierarquico (HNS). Apenas Standard GPv2 e Premium Block Blobs suportam HNS. Page Blobs sao usados para discos de VM (I/O aleatorio) e nao suportam HNS. File Shares sao Azure Files (SMB/NFS), servico diferente de Blob.

</details>

---
