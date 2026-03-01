> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 2 - Virtual Machines](bloco2-vms.md)

# Bloco 1 - Azure Storage

**Origem:** Lab 07 - Manage Azure Storage
**Resource Groups utilizados:** `az104-rg6`

## Contexto

A Contoso Corp precisa de armazenamento centralizado para dados corporativos. Voce cria uma Storage Account que sera usada por todos os blocos seguintes: blobs para dados de aplicacoes (Blocos 3 e 5), file shares montados em containers (Bloco 4) e discos gerenciados para VMs (Bloco 2). A seguranca de rede integra-se com as VNets criadas na Semana 1 — voce configurara Service Endpoints e Private Endpoints na CoreServicesVnet/SharedServicesSubnet.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                          az104-rg6                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Storage Account: contosostore<uniqueid>                     │  │
│  │  Kind: StorageV2 | Replication: LRS                          │  │
│  │                                                              │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │
│  │  │ Blob Service │  │ File Service │  │ Table/Queue       │   │  │
│  │  │              │  │              │  │ (explorar)        │   │  │
│  │  │ Container:   │  │ Share:       │  │                   │   │  │
│  │  │ data         │  │ contoso-     │  │                   │   │  │
│  │  │ (upload blob)│  │ files        │  │                   │   │  │
│  │  │              │  │ (5 GiB)      │  │                   │   │  │
│  │  │ Tiers:       │  │              │  │                   │   │  │
│  │  │ Hot/Cool/    │  │ → Bloco 4    │  │                   │   │  │
│  │  │ Archive      │  │   (ACI mount)│  │                   │   │  │
│  │  └──────────────┘  └──────────────┘  └───────────────────┘   │  │
│  │                                                              │  │
│  │  Networking:                                                 │  │
│  │  • Service Endpoint: SharedServicesSubnet (Semana 1)         │  │
│  │  • Private Endpoint: CoreServicesVnet (Semana 1)             │  │
│  │  • SAS Token configurado                                     │  │
│  │                                                              │  │
│  │  → Usado nos Blocos 2-5 para dados, file shares e config     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Lifecycle Management + Immutability configurados            │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Storage Account

> **Cobranca:** A Storage Account gera cobranca por dados armazenados. Para parar, delete a conta ou os dados.

Voce cria a Storage Account principal que sera referenciada em todos os blocos seguintes.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Storage accounts** > **+ Create**

3. Aba **Basics**:

   | Setting              | Value                                                    |
   | -------------------- | -------------------------------------------------------- |
   | Subscription         | *sua subscription*                                       |
   | Resource group       | `az104-rg6` (crie se necessario)                         |
   | Storage account name | `contosostore<uniqueid>` (3-24 chars, lowercase+numeros) |
   | Region               | **(US) East US**                                         |
   | Performance          | **Standard**                                             |
   | Redundancy           | **Locally-redundant storage (LRS)**                      |

4. Aba **Advanced**: revise as opcoes de seguranca — note **Require secure transfer for REST API operations** (habilitado por padrao)

5. Aba **Networking**: mantenha **Enable public access from all networks** por enquanto (sera restrito nas Tasks 1.6 e 1.7)

6. Aba **Data protection**: revise as opcoes de soft delete (habilitadas por padrao para blobs e containers)

7. Aba **Encryption**: note que Microsoft-managed keys (MMK) e o padrao

8. Clique em **Review + Create** > **Create** > **Go to resource**

9. No blade **Overview**, identifique:
   - **Primary endpoint** (URLs para blob, file, queue, table)
   - **Primary location** e **Replication status**

   > **Conceito:** Uma Storage Account fornece um namespace unico para seus dados no Azure. Cada objeto tem um endereco que inclui o nome da conta. LRS replica dados 3x dentro de um datacenter.

   > **Conexao com Blocos 2-5:** Esta storage account sera usada para connection strings (Bloco 3), file share mount (Bloco 4) e dados de aplicacoes (Bloco 5).

---

### Task 1.2: Criar Blob Container e fazer upload

O blob container armazenara dados corporativos que serao acessados pelas Web Apps (Bloco 3) e Container Apps (Bloco 5).

1. Na Storage Account, navegue para **Data storage** > **Containers**

2. Clique em **+ Container**:

   | Setting             | Value                             |
   | ------------------- | --------------------------------- |
   | Name                | `data`                            |
   | Public access level | **Private (no anonymous access)** |

3. Clique em **Create**

4. Selecione o container **data** > **Upload**:

   | Setting   | Value                                        |
   | --------- | -------------------------------------------- |
   | Files     | *qualquer arquivo de teste (ex: readme.txt)* |
   | Overwrite | **checked**                                  |

5. Clique em **Upload**

6. Selecione o blob uploaded > no blade de propriedades, revise:
   - **URL** (endpoint completo)
   - **Access tier** (Hot por padrao)

7. Tente acessar a URL do blob no navegador — deve receber **ResourceNotFound** ou **AuthenticationFailed** (container e Private)

   > **Conceito:** O nivel de acesso **Private** requer autenticacao para qualquer operacao. Niveis **Blob** e **Container** permitem acesso anonimo de leitura.

8. No blade do blob, clique em **Change tier** e explore as opcoes: **Hot**, **Cool**, **Cold**, **Archive**

   > **Conceito:** Hot = acesso frequente (custo de armazenamento maior). Cool = acesso infrequente (30 dias min). Cold = acesso raro (90 dias min). Archive = acesso raríssimo (180 dias min, latencia alta para rehydrate).

---

### Task 1.3: Configurar acesso via SAS Token e Stored Access Policy

1. Navegue para a **Storage Account** > **Security + networking** > **Shared access signature**

2. Configure o SAS:

   | Setting                | Value                         |
   | ---------------------- | ----------------------------- |
   | Allowed services       | **Blob** (marque apenas Blob) |
   | Allowed resource types | **Container** + **Object**    |
   | Allowed permissions    | **Read** + **List**           |
   | Start date/time        | *data/hora atual*             |
   | Expiry date/time       | *amanha, mesma hora*          |
   | Allowed protocols      | **HTTPS only**                |
   | Signing key            | **key1**                      |

3. Clique em **Generate SAS and connection string**

4. **Copie** o **Blob service SAS URL**

5. Abra uma nova aba do navegador e cole a URL SAS. Adicione o path do container e blob:
   - URL base SAS + `/data/readme.txt`

   > Voce deve conseguir visualizar ou baixar o arquivo agora.

6. Agora crie uma **Stored Access Policy** no container. Navegue para **Containers** > **data** > **Access policy**

7. Em **Stored access policies**, clique em **+ Add policy**:

   | Setting     | Value                     |
   | ----------- | ------------------------- |
   | Identifier  | `read-policy`             |
   | Permissions | **Read** + **List**       |
   | Start time  | *data/hora atual*         |
   | Expiry time | *7 dias a partir de hoje* |

8. Clique em **OK** > **Save**

   > **Conceito:** Stored Access Policies permitem gerenciar SAS tokens de forma centralizada. Voce pode revogar acesso alterando ou deletando a policy, ao inves de regenerar a storage key.

   > **Dica AZ-104:** Na prova, questoes frequentes: como revogar um SAS? (1) Deletar a stored access policy, (2) Regenerar a storage key usada para assinar, (3) Alterar a expiry date da policy.

---

### Task 1.4: Criar Azure File Share

O file share sera montado como unidade de rede nas VMs (Bloco 2) e como volume nos containers (Bloco 4).

1. Na Storage Account, navegue para **Data storage** > **File shares**

2. Clique em **+ File share**:

   | Setting | Value                     |
   | ------- | ------------------------- |
   | Name    | `contoso-files`           |
   | Tier    | **Transaction optimized** |

3. Clique em **Create**

4. Selecione **contoso-files** > **Upload**:
   - Faca upload de um arquivo de teste (ex: `config.txt`)

5. Clique em **Upload**

6. Selecione o file share **contoso-files** > **Properties**:
   - Note o **URL** e a **Quota**

7. Clique em **Connect** > selecione **Windows**:
   - Revise o script PowerShell gerado. Note que ele usa **storage account key** para autenticacao
   - **Copie e salve** o script — sera usado no Bloco 2 para montar o share na VM

8. Explore as opcoes:
   - **Snapshots**: para backup point-in-time
   - **Backup**: integracao com Azure Backup

   > **Conceito:** Azure Files oferece file shares SMB e NFS acessiveis via protocolo padrao. SMB 3.0 suporta criptografia em transito.

   > **Conexao com Bloco 2:** O script de conexao sera executado na Windows VM para montar o share como drive Z:.
   > **Conexao com Bloco 4:** O file share sera montado como volume no container ACI.

---

### Task 1.5: Configurar Blob Lifecycle Management e Immutability

1. Na Storage Account, navegue para **Data management** > **Lifecycle management**

2. Clique em **Add a rule**:

   | Setting      | Value                       |
   | ------------ | --------------------------- |
   | Rule name    | `move-to-cool`              |
   | Rule scope   | **Apply rule to all blobs** |
   | Blob type    | **Block blobs**             |
   | Blob subtype | **Base blobs**              |

3. Na aba **Base blobs**, configure:

   | Setting                            | Value                    |
   | ---------------------------------- | ------------------------ |
   | Last modified more than (days) ago | `30`                     |
   | Then                               | **Move to cool storage** |

4. Adicione outra acao:

   | Setting                            | Value                       |
   | ---------------------------------- | --------------------------- |
   | Last modified more than (days) ago | `90`                        |
   | Then                               | **Move to archive storage** |

5. Clique em **Add**

6. Agora configure **Immutability** no container. Navegue para **Containers** > **data** > **Access policy**

7. Em **Immutable blob storage**, clique em **Add policy**:

   | Setting          | Value                    |
   | ---------------- | ------------------------ |
   | Policy type      | **Time-based retention** |
   | Retention period | `7` days                 |

8. Clique em **Save**

   > **Conceito:** Lifecycle management automatiza a transicao entre tiers. Immutability (WORM) impede modificacao/exclusao de blobs por um periodo — usado para compliance (SEC, FINRA, CFTC).

   > **Dica AZ-104:** Na prova, diferencie: Lifecycle = automacao de custo; Immutability = compliance e retencao legal.

---

### Task 1.6: Configurar Service Endpoint na VNet da Semana 1

Voce restringe o acesso a Storage Account para aceitar trafego apenas da SharedServicesSubnet criada na Semana 1 (CoreServicesVnet).

1. Navegue para a **Storage Account** > **Security + networking** > **Networking**

2. Selecione **Enabled from selected virtual networks and IP addresses**

3. Em **Virtual networks**, clique em **+ Add existing virtual network**:

   | Setting         | Value                                         |
   | --------------- | --------------------------------------------- |
   | Subscription    | *sua subscription*                            |
   | Virtual network | **CoreServicesVnet** (do az104-rg4, Semana 1) |
   | Subnets         | **SharedServicesSubnet**                      |

   > **Nota:** Se a VNet da Semana 1 nao existir mais, crie uma nova VNet `StorageVnet` (10.50.0.0/16) com subnet `StorageSubnet` (10.50.0.0/24) no az104-rg6 e use-a.

4. Clique em **Add**

5. Em **Firewall**, adicione **seu IP de cliente** (marque a checkbox se disponivel) para manter acesso pelo portal

6. Clique em **Save**

7. **Validacao:** Aguarde 30 segundos. Navegue para **Containers** > **data** — voce deve ainda conseguir acessar (seu IP esta na whitelist)

   > **Conceito:** Service Endpoints adicionam uma rota otimizada do subnet para o servico Azure. O trafego permanece na rede backbone da Microsoft. O endpoint e habilitado na subnet e referenciado no firewall do storage.

   > **Conexao com Semana 1:** Voce esta usando a infraestrutura de rede criada no Bloco 4 (Virtual Networking) da Semana 1. A SharedServicesSubnet agora tem acesso direto e seguro ao storage.

---

### Task 1.7: Criar Private Endpoint para o Storage Account

> **Cobranca:** Private Endpoints geram cobranca enquanto existirem.

O Private Endpoint atribui um IP privado da VNet ao storage, eliminando exposicao publica.

1. Navegue para a **Storage Account** > **Security + networking** > **Networking** > aba **Private endpoint connections**

2. Clique em **+ Private endpoint**

3. Aba **Basics**:

   | Setting                | Value                 |
   | ---------------------- | --------------------- |
   | Subscription           | *sua subscription*    |
   | Resource group         | `az104-rg6`           |
   | Name                   | `pe-contosostore`     |
   | Network Interface Name | `pe-contosostore-nic` |
   | Region                 | **East US**           |

4. Aba **Resource**:

   | Setting             | Value    |
   | ------------------- | -------- |
   | Target sub-resource | **blob** |

5. Aba **Virtual Network**:

   | Setting         | Value                                         |
   | --------------- | --------------------------------------------- |
   | Virtual network | **CoreServicesVnet** (do az104-rg4, Semana 1) |
   | Subnet          | **SharedServicesSubnet**                      |

   > **Nota:** Se a VNet da Semana 1 nao existir, use a VNet alternativa criada na Task 1.6.

6. Aba **DNS**: Mantenha **Yes** para integrar com Private DNS Zone

7. Clique em **Review + Create** > **Create**

8. Apos o deploy, navegue para o Private Endpoint criado. Note:
   - **Network interface** com IP privado atribuido (ex: 10.20.10.x)
   - **DNS configuration** com FQDN apontando para o IP privado

9. **Validacao:** Navegue para **Private DNS zones** no portal. Uma zona `privatelink.blob.core.windows.net` foi criada automaticamente com um registro A apontando para o IP privado.

   > **Conceito:** Private Endpoints usam Azure Private Link para projetar o servico na sua VNet. O DNS e atualizado para resolver o FQDN publico para o IP privado. Diferente de Service Endpoints, o trafego usa um IP da sua subnet.

   > **Conexao com Semana 1:** O Private Endpoint esta na SharedServicesSubnet da CoreServicesVnet. VMs nessa VNet (ou VNets peered) acessarao o storage via IP privado, sem sair da rede Microsoft.

---

### Task 1.8: Testar acesso anonimo e Soft Delete

1. Na Storage Account, navegue para **Settings** > **Configuration**

2. Localize **Allow Blob anonymous access** e altere para **Enabled** (se nao estiver)

3. Clique em **Save**

4. Navegue para **Containers** > **data** > **Change access level**:

   | Setting             | Value                                           |
   | ------------------- | ----------------------------------------------- |
   | Public access level | **Blob (anonymous read access for blobs only)** |

5. Clique em **OK**

6. Copie a URL do blob e acesse em uma aba anonima — agora deve funcionar

7. **Reverta** o acesso para **Private** imediatamente (best practice)

8. Agora teste **Soft Delete**: navegue para **Containers** > **data**, selecione o blob e clique em **Delete** > **OK**

9. Ative **Show deleted blobs** (toggle no topo da lista)

10. O blob deletado aparece. Selecione-o > **Undelete** para restaurar

   > **Conceito:** Soft delete protege contra exclusao acidental. O periodo padrao e 7 dias. Na prova, lembre: soft delete se aplica a blobs, containers e file shares separadamente.

   > **Dica AZ-104:** Questao classica: "Um blob foi deletado acidentalmente. Como recuperar?" — Soft delete (se habilitado) ou snapshots/versioning.

---

## Modo Desafio - Bloco 1

- [ ] Criar Storage Account `contosostore<uniqueid>` (LRS, East US) no az104-rg6
- [ ] Criar container `data` (Private) e fazer upload de arquivo
- [ ] Gerar SAS token (Blob, Read+List, HTTPS only) e testar acesso via URL
- [ ] Criar Stored Access Policy `read-policy` no container
- [ ] Criar File Share `contoso-files` (Transaction optimized) e fazer upload
- [ ] Copiar script de conexao Windows para uso no Bloco 2
- [ ] Configurar Lifecycle Management: Cool (30d), Archive (90d)
- [ ] Configurar Immutability policy (7 dias) no container `data`
- [ ] **Integracao Semana 1:** Service Endpoint na SharedServicesSubnet da CoreServicesVnet
- [ ] **Integracao Semana 1:** Private Endpoint (blob) na SharedServicesSubnet
- [ ] Testar acesso anonimo → reverter para Private
- [ ] Testar Soft Delete: deletar e restaurar blob

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Voce precisa garantir que blobs nao acessados ha mais de 30 dias sejam movidos para Cool storage automaticamente. Qual recurso voce deve configurar?**

A) Azure Policy com efeito Modify
B) Blob Lifecycle Management rule
C) Storage Account Replication
D) Immutability policy

<details>
<summary>Ver resposta</summary>

**Resposta: B) Blob Lifecycle Management rule**

Lifecycle Management permite criar regras baseadas em ultima modificacao ou ultimo acesso para mover blobs entre tiers (Hot → Cool → Cold → Archive) ou deletar automaticamente.

</details>

### Questao 1.2
**Qual a diferenca entre Service Endpoint e Private Endpoint para Storage?**

A) Service Endpoint cria um IP privado; Private Endpoint usa rota otimizada
B) Service Endpoint adiciona rota otimizada na subnet; Private Endpoint atribui IP privado da VNet ao servico
C) Ambos sao identicos em funcionalidade
D) Service Endpoint requer DNS privado; Private Endpoint nao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Service Endpoint adiciona rota otimizada na subnet; Private Endpoint atribui IP privado da VNet ao servico**

Service Endpoint: rota otimizada, trafego via backbone Microsoft, servico continua com IP publico. Private Endpoint: IP privado da VNet, resolve via DNS privado, elimina exposicao publica.

</details>

### Questao 1.3
**Um SAS token foi comprometido. Qual a maneira MAIS RAPIDA de revogar acesso se o SAS foi gerado com uma Stored Access Policy?**

A) Regenerar todas as storage keys
B) Deletar a Stored Access Policy associada
C) Deletar a Storage Account
D) Alterar o firewall da Storage Account

<details>
<summary>Ver resposta</summary>

**Resposta: B) Deletar a Stored Access Policy associada**

Deletar ou modificar a Stored Access Policy revoga imediatamente todos os SAS tokens gerados com base nela. Regenerar keys tambem funciona, mas afeta TODOS os SAS tokens (inclusive os nao comprometidos).

</details>

### Questao 1.4
**Voce habilitou Soft Delete para blobs com retencao de 14 dias. Um usuario deleta um blob. Apos 10 dias, ele tenta restaurar. O que acontece?**

A) O blob nao pode ser restaurado apos a delecao
B) O blob e restaurado com sucesso (dentro do periodo de retencao)
C) O blob so pode ser restaurado pelo Owner da subscription
D) O blob e restaurado mas com access tier alterado

<details>
<summary>Ver resposta</summary>

**Resposta: B) O blob e restaurado com sucesso (dentro do periodo de retencao)**

Soft delete mantem blobs deletados pelo periodo configurado. Qualquer usuario com permissao de escrita no container pode fazer Undelete enquanto o blob estiver no periodo de retencao.

</details>

---

