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

- [Bloco 1 - Azure Storage](#bloco-1---azure-storage)
- [Bloco 2 - Virtual Machines](#bloco-2---virtual-machines)
- [Bloco 3 - Azure Web Apps](#bloco-3---azure-web-apps)
- [Bloco 4 - Azure Container Instances](#bloco-4---azure-container-instances)
- [Bloco 5 - Azure Container Apps](#bloco-5---azure-container-apps)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - Azure Storage

**Origem:** Lab 07 - Manage Azure Storage
**Resource Groups utilizados:** `az104-rg6`

## Contexto

A Contoso Corp precisa de armazenamento centralizado para dados corporativos. Voce cria uma Storage Account que sera usada por todos os blocos seguintes: blobs para dados de aplicacoes (Blocos 3 e 5), file shares montados em containers (Bloco 4) e discos gerenciados para VMs (Bloco 2). A seguranca de rede integra-se com as VNets criadas na Semana 1 — voce configurara Service Endpoints e Private Endpoints na CoreServicesVnet/SharedServicesSubnet.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg6                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Storage Account: contosostore<uniqueid>                     │  │
│  │  Kind: StorageV2 | Replication: LRS                          │  │
│  │                                                               │  │
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
│  │                                                               │  │
│  │  Networking:                                                  │  │
│  │  • Service Endpoint: SharedServicesSubnet (Semana 1)          │  │
│  │  • Private Endpoint: CoreServicesVnet (Semana 1)              │  │
│  │  • SAS Token configurado                                      │  │
│  │                                                               │  │
│  │  → Usado nos Blocos 2-5 para dados, file shares e config      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Lifecycle Management + Immutability configurados             │  │
│  └──────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Storage Account

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

   | Setting              | Value                           |
   | -------------------- | ------------------------------- |
   | Name                 | `data`                          |
   | Public access level  | **Private (no anonymous access)** |

3. Clique em **Create**

4. Selecione o container **data** > **Upload**:

   | Setting   | Value                                       |
   | --------- | ------------------------------------------- |
   | Files     | *qualquer arquivo de teste (ex: readme.txt)* |
   | Overwrite | **checked**                                 |

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

   | Setting                      | Value                                        |
   | ---------------------------- | -------------------------------------------- |
   | Allowed services             | **Blob** (marque apenas Blob)                |
   | Allowed resource types       | **Container** + **Object**                   |
   | Allowed permissions          | **Read** + **List**                           |
   | Start date/time              | *data/hora atual*                             |
   | Expiry date/time             | *amanha, mesma hora*                          |
   | Allowed protocols            | **HTTPS only**                                |
   | Signing key                  | **key1**                                      |

3. Clique em **Generate SAS and connection string**

4. **Copie** o **Blob service SAS URL**

5. Abra uma nova aba do navegador e cole a URL SAS. Adicione o path do container e blob:
   - URL base SAS + `/data/readme.txt`

   > Voce deve conseguir visualizar ou baixar o arquivo agora.

6. Agora crie uma **Stored Access Policy** no container. Navegue para **Containers** > **data** > **Access policy**

7. Em **Stored access policies**, clique em **+ Add policy**:

   | Setting       | Value                   |
   | ------------- | ----------------------- |
   | Identifier    | `read-policy`           |
   | Permissions   | **Read** + **List**      |
   | Start time    | *data/hora atual*       |
   | Expiry time   | *7 dias a partir de hoje* |

8. Clique em **OK** > **Save**

   > **Conceito:** Stored Access Policies permitem gerenciar SAS tokens de forma centralizada. Voce pode revogar acesso alterando ou deletando a policy, ao inves de regenerar a storage key.

   > **Dica AZ-104:** Na prova, questoes frequentes: como revogar um SAS? (1) Deletar a stored access policy, (2) Regenerar a storage key usada para assinar, (3) Alterar a expiry date da policy.

---

### Task 1.4: Criar Azure File Share

O file share sera montado como unidade de rede nas VMs (Bloco 2) e como volume nos containers (Bloco 4).

1. Na Storage Account, navegue para **Data storage** > **File shares**

2. Clique em **+ File share**:

   | Setting          | Value            |
   | ---------------- | ---------------- |
   | Name             | `contoso-files`  |
   | Tier             | **Transaction optimized** |

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

   | Setting              | Value                              |
   | -------------------- | ---------------------------------- |
   | Rule name            | `move-to-cool`                     |
   | Rule scope           | **Apply rule to all blobs**        |
   | Blob type            | **Block blobs**                    |
   | Blob subtype         | **Base blobs**                     |

3. Na aba **Base blobs**, configure:

   | Setting                               | Value       |
   | ------------------------------------- | ----------- |
   | Last modified more than (days) ago    | `30`        |
   | Then                                  | **Move to cool storage** |

4. Adicione outra acao:

   | Setting                               | Value       |
   | ------------------------------------- | ----------- |
   | Last modified more than (days) ago    | `90`        |
   | Then                                  | **Move to archive storage** |

5. Clique em **Add**

6. Agora configure **Immutability** no container. Navegue para **Containers** > **data** > **Access policy**

7. Em **Immutable blob storage**, clique em **Add policy**:

   | Setting          | Value                                     |
   | ---------------- | ----------------------------------------- |
   | Policy type      | **Time-based retention**                  |
   | Retention period | `7` days                                  |

8. Clique em **Save**

   > **Conceito:** Lifecycle management automatiza a transicao entre tiers. Immutability (WORM) impede modificacao/exclusao de blobs por um periodo — usado para compliance (SEC, FINRA, CFTC).

   > **Dica AZ-104:** Na prova, diferencie: Lifecycle = automacao de custo; Immutability = compliance e retencao legal.

---

### Task 1.6: Configurar Service Endpoint na VNet da Semana 1

Voce restringe o acesso a Storage Account para aceitar trafego apenas da SharedServicesSubnet criada na Semana 1 (CoreServicesVnet).

1. Navegue para a **Storage Account** > **Security + networking** > **Networking**

2. Selecione **Enabled from selected virtual networks and IP addresses**

3. Em **Virtual networks**, clique em **+ Add existing virtual network**:

   | Setting         | Value                                  |
   | --------------- | -------------------------------------- |
   | Subscription    | *sua subscription*                     |
   | Virtual network | **CoreServicesVnet** (do az104-rg4, Semana 1) |
   | Subnets         | **SharedServicesSubnet**               |

   > **Nota:** Se a VNet da Semana 1 nao existir mais, crie uma nova VNet `StorageVnet` (10.50.0.0/16) com subnet `StorageSubnet` (10.50.0.0/24) no az104-rg6 e use-a.

4. Clique em **Add**

5. Em **Firewall**, adicione **seu IP de cliente** (marque a checkbox se disponivel) para manter acesso pelo portal

6. Clique em **Save**

7. **Validacao:** Aguarde 30 segundos. Navegue para **Containers** > **data** — voce deve ainda conseguir acessar (seu IP esta na whitelist)

   > **Conceito:** Service Endpoints adicionam uma rota otimizada do subnet para o servico Azure. O trafego permanece na rede backbone da Microsoft. O endpoint e habilitado na subnet e referenciado no firewall do storage.

   > **Conexao com Semana 1:** Voce esta usando a infraestrutura de rede criada no Bloco 4 (Virtual Networking) da Semana 1. A SharedServicesSubnet agora tem acesso direto e seguro ao storage.

---

### Task 1.7: Criar Private Endpoint para o Storage Account

O Private Endpoint atribui um IP privado da VNet ao storage, eliminando exposicao publica.

1. Navegue para a **Storage Account** > **Security + networking** > **Networking** > aba **Private endpoint connections**

2. Clique em **+ Private endpoint**

3. Aba **Basics**:

   | Setting        | Value                   |
   | -------------- | ----------------------- |
   | Subscription   | *sua subscription*      |
   | Resource group | `az104-rg6`             |
   | Name           | `pe-contosostore`       |
   | Network Interface Name | `pe-contosostore-nic` |
   | Region         | **East US**             |

4. Aba **Resource**:

   | Setting            | Value                |
   | ------------------ | -------------------- |
   | Target sub-resource | **blob**            |

5. Aba **Virtual Network**:

   | Setting         | Value                                  |
   | --------------- | -------------------------------------- |
   | Virtual network | **CoreServicesVnet** (do az104-rg4, Semana 1) |
   | Subnet          | **SharedServicesSubnet**               |

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

   | Setting             | Value                                    |
   | ------------------- | ---------------------------------------- |
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

# Bloco 2 - Virtual Machines

**Origem:** Lab 08 - Manage Virtual Machines
**Resource Groups utilizados:** `az104-rg7`

## Contexto

Com o armazenamento configurado no Bloco 1, voce agora implanta cargas de trabalho de computacao. As VMs serao criadas nas VNets da Semana 1 (CoreServicesVnet e ManufacturingVnet), usando o storage do Bloco 1 para dados. Voce tambem criara um VMSS com auto-scaling para cenarios de alta disponibilidade. Os data disks demonstram integracao com o storage, e a montagem do file share valida a conectividade end-to-end.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg7                                 │
│                                                                    │
│  ┌────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  az104-vm-win              │  │  az104-vm-linux             │  │
│  │  (Windows Server 2022)     │  │  (Ubuntu 22.04 LTS)        │  │
│  │                            │  │                             │  │
│  │  VNet: CoreServicesVnet    │  │  VNet: ManufacturingVnet    │  │
│  │  Subnet: Core (Semana 1)  │  │  Subnet: Manufacturing     │  │
│  │  Size: Standard_D2s_v3    │  │  Size: Standard_D2s_v3     │  │
│  │                            │  │                             │  │
│  │  Data Disk: 32 GiB        │  │  Custom Script Ext.        │  │
│  │  File Share: Z: drive     │  │  (instala Nginx)           │  │
│  │  (← Bloco 1)              │  │                             │  │
│  └────────────────────────────┘  └─────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  az104-vmss                                                  │  │
│  │  (VM Scale Set - Ubuntu 22.04)                               │  │
│  │                                                               │  │
│  │  VNet: CoreServicesVnet (Semana 1)                            │  │
│  │  Subnet: SharedServicesSubnet                                 │  │
│  │  Instances: min 1, max 3 (CPU > 75% scale out)               │  │
│  │  → Usa rede ja protegida por NSG (Semana 1)                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → VMs usam VNets da Semana 1 (cross-resource-group)              │
│  → File Share do Bloco 1 montado na Windows VM                    │
│  → Data Disk demonstra gerenciamento de storage para VMs          │
└───────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 2.1: Criar Windows VM na CoreServicesVnet

A VM Windows sera implantada na CoreServicesVnet criada na Semana 1, demonstrando cross-resource-group deployment.

1. Pesquise e selecione **Virtual Machines** > **Create** > **Azure Virtual Machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `az104-rg7` (crie se necessario)              |
   | Virtual machine name | `az104-vm-win`                                |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2022 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa (salve!)*                     |
   | Public inbound ports | **Allow selected ports**                      |
   | Select inbound ports | **RDP (3389)**                                |

3. Aba **Disks**: mantenha defaults (OS disk: Premium SSD)

4. Aba **Networking**:

   | Setting         | Value                                              |
   | --------------- | -------------------------------------------------- |
   | Virtual network | **CoreServicesVnet** (de az104-rg4, Semana 1)      |
   | Subnet          | **Core** (10.20.0.0/24)                            |
   | Public IP       | **(new) az104-vm-win-ip**                          |
   | NIC NSG         | **Basic**                                          |
   | Public inbound ports | **Allow selected ports**                      |
   | Select inbound ports | **RDP (3389)**                                |

   > **Nota:** Se a VNet da Semana 1 nao existir, crie uma VNet `ComputeVnet` (10.40.0.0/16) com subnet `ComputeSubnet` (10.40.0.0/24) no az104-rg7.

   > **Conexao com Semana 1:** A VM esta sendo implantada na mesma VNet usada para networking (cross-RG). Isso demonstra que VMs e VNets nao precisam estar no mesmo Resource Group.

5. Aba **Management**: mantenha defaults

6. Aba **Monitoring**: **Disable** Boot diagnostics

7. Clique em **Review + create** > **Create**

8. Aguarde o deployment concluir > **Go to resource**

9. No blade **Overview**, anote:
   - **Private IP address** (ex: 10.20.0.4)
   - **Public IP address**
   - **Status**: Running

---

### Task 2.2: Adicionar Data Disk e montar File Share (Storage do Bloco 1)

Voce adiciona um data disk gerenciado e monta o file share do Bloco 1 como unidade de rede.

**Adicionar Data Disk:**

1. Na VM **az104-vm-win**, navegue para **Settings** > **Disks**

2. Clique em **+ Create and attach a new disk**:

   | Setting          | Value                  |
   | ---------------- | ---------------------- |
   | LUN              | `0`                    |
   | Disk name        | `az104-vm-win-disk1`   |
   | Storage type     | **Premium SSD**        |
   | Size (GiB)       | `32`                   |
   | Encryption       | Default                |

3. Clique em **Apply**

4. Conecte-se a VM via **RDP**:
   - Clique em **Connect** > **Connect** (native RDP)
   - Baixe o arquivo RDP e conecte com as credenciais `localadmin`

5. Dentro da VM, abra **Server Manager** > **File and Storage Services** > **Disks**

6. Localize o disco de 32 GiB (offline). Clique com botao direito > **Bring Online** > **Yes**

7. Clique com botao direito > **Initialize** (GPT)

8. Clique com botao direito no espaco nao alocado > **New Simple Volume**:
   - Drive letter: `F`
   - File system: NTFS
   - Volume label: `Data`

9. Confirme que o drive `F:` aparece no File Explorer

**Montar File Share do Bloco 1:**

10. Dentro da VM, abra **PowerShell** como Administrator

11. Execute o script de conexao do File Share copiado na Task 1.4 do Bloco 1:

    > **Nota:** O script usa `net use` ou `New-PSDrive` para mapear o share como drive Z:. Ele autentica com a storage account key.

    ```powershell
    # Exemplo de script (use o script gerado no portal):
    $connectTestResult = Test-NetConnection -ComputerName contosostore<uniqueid>.file.core.windows.net -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        cmd.exe /C "cmdkey /add:`"contosostore<uniqueid>.file.core.windows.net`" /user:`"localhost\contosostore<uniqueid>`" /pass:`"<storage-account-key>`""
        New-PSDrive -Name Z -PSProvider FileSystem -Root "\\contosostore<uniqueid>.file.core.windows.net\contoso-files" -Persist
    }
    ```

12. Verifique que o drive **Z:** aparece no File Explorer com o conteudo do file share

13. Crie um arquivo de teste no drive Z: `echo "Hello from VM" > Z:\vm-test.txt`

14. Volte ao **Azure Portal** > Storage Account > **File shares** > **contoso-files** — confirme que `vm-test.txt` aparece

    > **Conexao com Bloco 1:** O file share criado no Bloco 1 esta montado na VM. Isso demonstra integracao entre compute e storage. O mesmo share sera montado como volume no Bloco 4 (ACI).

15. Desconecte do RDP

---

### Task 2.3: Criar Linux VM na ManufacturingVnet com Custom Script Extension

1. Pesquise **Virtual Machines** > **Create** > **Azure Virtual Machine**

2. Aba **Basics**:

   | Setting              | Value                                     |
   | -------------------- | ----------------------------------------- |
   | Resource group       | `az104-rg7`                               |
   | Virtual machine name | `az104-vm-linux`                          |
   | Region               | **(US) East US**                          |
   | Security type        | **Standard**                              |
   | Image                | **Ubuntu Server 22.04 LTS - x64 Gen2**   |
   | Size                 | **Standard_D2s_v3**                       |
   | Authentication type  | **Password**                              |
   | Username             | `localadmin`                              |
   | Password             | *senha complexa*                          |
   | Public inbound ports | **Allow selected ports**                  |
   | Select inbound ports | **HTTP (80)**, **SSH (22)**               |

3. Aba **Networking**:

   | Setting         | Value                                              |
   | --------------- | -------------------------------------------------- |
   | Virtual network | **ManufacturingVnet** (de az104-rg4, Semana 1)     |
   | Subnet          | **Manufacturing** (10.30.0.0/24)                   |
   | Public IP       | **(new) az104-vm-linux-ip**                        |

   > **Conexao com Semana 1:** A Linux VM fica na ManufacturingVnet. Se o peering da Semana 1 ainda existir, ela pode se comunicar com a Windows VM na CoreServicesVnet.

4. Aba **Monitoring**: **Disable** Boot diagnostics

5. Clique em **Review + create** > **Create**

6. Apos o deploy, navegue para **az104-vm-linux** > **Operations** > **Run command** > **RunShellScript**

7. Execute o Custom Script para instalar Nginx:

   ```bash
   sudo apt-get update
   sudo apt-get install -y nginx
   echo "<h1>Hello from az104-vm-linux (ManufacturingVnet)</h1>" | sudo tee /var/www/html/index.html
   ```

8. Clique em **Run** e aguarde a saida

9. Copie o **Public IP** da VM e acesse via navegador — voce deve ver a pagina do Nginx

   > **Conceito:** Custom Script Extension permite executar scripts pos-provisioning automaticamente. Util para configuracao, instalacao de software e deployment.

---

### Task 2.4: Comparar tamanhos de VM e Resize

1. Navegue para **az104-vm-win** > **Availability + scale** > **Size**

2. Explore os tamanhos disponiveis. Observe as familias:
   - **D-series**: proposito geral (balanceado CPU/memoria)
   - **E-series**: otimizado para memoria
   - **F-series**: otimizado para CPU
   - **B-series**: burstable (economico para workloads variaveis)

3. Selecione **Standard_DS1_v2** (menor custo) > **Resize**

   > **Nota:** O resize pode reiniciar a VM. Alguns tamanhos requerem deallocate primeiro.

4. Aguarde a operacao. A VM sera reiniciada.

5. Confirme o novo tamanho no **Overview**

6. **Opcional:** Faca resize de volta para **Standard_D2s_v3**

   > **Dica AZ-104:** Na prova, questoes sobre familias de VM sao comuns. Memorize: B=burstable, D=general purpose, E=memory optimized, F=compute optimized, N=GPU.

---

### Task 2.5: Criar VM Scale Set (VMSS)

O VMSS sera implantado na SharedServicesSubnet da CoreServicesVnet (Semana 1), que ja tem o NSG `myNSGSecure` associado.

1. Pesquise **Virtual machine scale sets** > **+ Create**

2. Aba **Basics**:

   | Setting              | Value                                   |
   | -------------------- | --------------------------------------- |
   | Resource group       | `az104-rg7`                             |
   | VMSS name            | `az104-vmss`                            |
   | Region               | **(US) East US**                        |
   | Availability zone    | **None**                                |
   | Orchestration mode   | **Uniform**                             |
   | Security type        | **Standard**                            |
   | Image                | **Ubuntu Server 22.04 LTS - x64 Gen2** |
   | Size                 | **Standard_B1s** (economico)            |
   | Authentication type  | **Password**                            |
   | Username             | `localadmin`                            |
   | Password             | *senha complexa*                        |

3. Aba **Networking**:

   | Setting         | Value                                              |
   | --------------- | -------------------------------------------------- |
   | Virtual network | **CoreServicesVnet** (de az104-rg4, Semana 1)      |
   | Subnet          | **SharedServicesSubnet** (10.20.10.0/24)           |
   | Load balancer   | **None** (para simplificar)                        |

   > **Conexao com Semana 1:** O VMSS esta na SharedServicesSubnet, que tem o NSG `myNSGSecure` associado (Semana 1, Bloco 4). Isso significa que as regras de inbound/outbound do NSG se aplicam a todas as instancias do VMSS automaticamente.

4. Aba **Scaling**:

   | Setting           | Value     |
   | ----------------- | --------- |
   | Initial instance count | `1` |
   | Scaling policy    | **Custom** |
   | Minimum instances | `1`       |
   | Maximum instances | `3`       |

5. Configure a regra de scale-out:
   - Metric: **Percentage CPU**
   - Operator: **Greater than**
   - Threshold: `75`
   - Duration: `10` minutes
   - Increase count by: `1`

6. Configure a regra de scale-in:
   - Metric: **Percentage CPU**
   - Operator: **Less than**
   - Threshold: `25`
   - Duration: `10` minutes
   - Decrease count by: `1`

7. Aba **Management**: mantenha defaults

8. Clique em **Review + create** > **Create**

9. Apos o deploy, navegue para **az104-vmss** > **Instances** > confirme que 1 instancia esta Running

   > **Conceito:** VMSS permite criar e gerenciar um grupo de VMs identicas com auto-scaling. As instancias compartilham configuracao, imagem e regras de scaling.

---

### Task 2.6: Gerenciar VMSS — Upgrade Policy e instancias

1. No **az104-vmss**, navegue para **Settings** > **Scaling**

2. Revise as regras de auto-scale configuradas

3. Navegue para **Upgrade policy** e note a politica configurada (Manual ou Automatic)

   > **Conceito:** Upgrade policies controlam como atualizacoes sao aplicadas as instancias. **Manual** requer acao explicita; **Automatic** atualiza instancias automaticamente; **Rolling** atualiza em lotes.

4. Navegue para **Instances** > selecione a instancia > explore:
   - **Status**: Running
   - **Latest model**: sim/nao (indica se esta atualizada)
   - **Protection**: opcoes de protecao contra scale-in

5. **Opcional:** Force scale-out manual:
   - Em **Scaling**, altere temporariamente o **minimum** para `2`
   - Aguarde a criacao da segunda instancia
   - Reverta o minimum para `1`

---

### Task 2.7: Configurar VM Backup e testar Run Command

1. Navegue para **az104-vm-win** > **Operations** > **Backup**

2. Revise as opcoes:

   | Setting          | Value                                    |
   | ---------------- | ---------------------------------------- |
   | Recovery Services vault | *crie ou selecione um existente*  |
   | Backup policy    | **DefaultPolicy** (diario, 30 dias)      |

   > **Nota:** Nao e necessario habilitar o backup de fato (gera custo). Apenas revise as opcoes.

3. Agora teste **Run Command** na Windows VM:
   - Navegue para **az104-vm-win** > **Operations** > **Run command** > **RunPowerShellScript**

4. Execute:

   ```powershell
   Get-Disk | Format-Table Number, PartitionStyle, OperationalStatus, Size
   Get-Volume | Format-Table DriveLetter, FileSystemLabel, SizeRemaining, Size
   ```

5. Revise a saida — voce deve ver o disco C: (OS), F: (Data) e Z: (File Share, se ainda montado)

6. Teste Run Command na Linux VM:
   - Navegue para **az104-vm-linux** > **Operations** > **Run command** > **RunShellScript**

   ```bash
   df -h
   systemctl status nginx
   curl localhost
   ```

7. Confirme que Nginx esta ativo e respondendo

   > **Conceito:** Run Command e util para troubleshooting sem necessidade de RDP/SSH. Os comandos executam via VM Agent.

---

## Modo Desafio - Bloco 2

- [ ] Criar `az104-vm-win` (Windows) na subnet Core da **CoreServicesVnet (Semana 1)**
- [ ] Adicionar Data Disk 32 GiB → inicializar como drive F: dentro da VM
- [ ] **Integracao Bloco 1:** Montar File Share `contoso-files` como drive Z: na VM
- [ ] Criar arquivo de teste no share via VM → confirmar no portal
- [ ] Criar `az104-vm-linux` (Ubuntu) na subnet Manufacturing da **ManufacturingVnet (Semana 1)**
- [ ] Instalar Nginx via Custom Script Extension / Run Command
- [ ] Comparar tamanhos de VM e executar resize
- [ ] Criar VMSS `az104-vmss` na **SharedServicesSubnet (Semana 1)** com auto-scale (CPU 75%/25%)
- [ ] **Integracao Semana 1:** Verificar que NSG da SharedServicesSubnet se aplica ao VMSS
- [ ] Gerenciar instancias do VMSS (status, latest model)
- [ ] Testar Run Command em ambas as VMs

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce precisa anexar um data disk a uma VM em execucao. E necessario reiniciar a VM?**

A) Sim, sempre e necessario reiniciar
B) Nao, hot-attach e suportado para data disks em VMs com suporte
C) Apenas se o disco for Premium SSD
D) Apenas se a VM estiver em um Availability Set

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, hot-attach e suportado para data disks em VMs com suporte**

Data disks podem ser anexados/desanexados de VMs em execucao (hot-attach/hot-detach) em tamanhos de VM que suportam este recurso. O OS disk requer stop/deallocate.

</details>

### Questao 2.2
**Voce configurou uma regra de auto-scale no VMSS: scale-out quando CPU > 75% por 10 minutos. O CPU fica em 80% por 8 minutos e depois cai para 60%. O VMSS faz scale-out?**

A) Sim, porque o CPU ultrapassou 75%
B) Nao, porque o threshold nao foi mantido pelo periodo completo de 10 minutos
C) Sim, mas apenas apos 15 minutos de cooldown
D) Depende do numero atual de instancias

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, porque o threshold nao foi mantido pelo periodo completo de 10 minutos**

A regra de auto-scale requer que a metrica exceda o threshold pelo **periodo completo** (duration). Se o CPU cair antes dos 10 minutos, a condicao nao e atendida e o scale-out nao e disparado.

</details>

### Questao 2.3
**Voce precisa executar um script de troubleshooting em uma VM Azure mas nao tem acesso RDP/SSH. Qual recurso voce deve usar?**

A) Azure Bastion
B) Run Command
C) Custom Script Extension
D) Serial Console

<details>
<summary>Ver resposta</summary>

**Resposta: B) Run Command**

Run Command permite executar scripts diretamente na VM via Azure Portal, CLI ou PowerShell, sem necessidade de conectividade RDP/SSH. E executado pelo VM Agent. Custom Script Extension e para cenarios de deployment/configuracao automatizada, nao troubleshooting ad-hoc.

</details>

### Questao 2.4
**Qual familia de VM Azure e mais adequada para cargas de trabalho com uso intensivo de memoria, como bancos de dados em memoria?**

A) B-series (Burstable)
B) D-series (General Purpose)
C) E-series (Memory Optimized)
D) F-series (Compute Optimized)

<details>
<summary>Ver resposta</summary>

**Resposta: C) E-series (Memory Optimized)**

E-series e otimizada para cargas de trabalho com alto consumo de memoria (bancos de dados, caches, analytics in-memory). D-series e general purpose, F-series e compute optimized, B-series e para workloads variaveis.

</details>

---

# Bloco 3 - Azure Web Apps

**Origem:** Lab 09a - Implement Web Apps
**Resource Groups utilizados:** `az104-rg8`

## Contexto

Com armazenamento (Bloco 1) e computacao (Bloco 2) configurados, voce agora implanta aplicacoes web usando Azure App Service. As Web Apps se conectam ao storage do Bloco 1 via connection strings para acessar blobs e file shares. Voce tambem configura deployment slots para estrategias de deploy blue/green, demonstrando como a Contoso Corp pode fazer deploys sem downtime.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg8                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  App Service Plan: az104-appplan                              │  │
│  │  SKU: Standard S1                                             │  │
│  │  OS: Linux                                                    │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────┐     │  │
│  │  │  Web App: az104-webapp-<uniqueid>                     │     │  │
│  │  │                                                       │     │  │
│  │  │  Runtime: PHP 8.2                                     │     │  │
│  │  │  Deployment: GitHub/External Git                      │     │  │
│  │  │                                                       │     │  │
│  │  │  App Settings:                                        │     │  │
│  │  │  • STORAGE_CONNECTION (← Bloco 1 Storage Account)     │     │  │
│  │  │                                                       │     │  │
│  │  │  Deployment Slots:                                    │     │  │
│  │  │  • Production (default)                               │     │  │
│  │  │  • staging (swap target)                              │     │  │
│  │  │                                                       │     │  │
│  │  │  Scaling:                                             │     │  │
│  │  │  • Scale out: min 1, max 3 (CPU > 60%)               │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Connection String referencia Storage Account do Bloco 1         │
│  → Deployment Slots permitem deploy blue/green sem downtime        │
└───────────────────────────────────────────────────────────────────┘
```

---

### Task 3.1: Criar App Service Plan e Web App

1. Pesquise e selecione **App Services** > **+ Create** > **Web App**

2. Aba **Basics**:

   | Setting              | Value                                       |
   | -------------------- | ------------------------------------------- |
   | Subscription         | *sua subscription*                          |
   | Resource group       | `az104-rg8` (crie se necessario)            |
   | Name                 | `az104-webapp-<uniqueid>` (globalmente unico) |
   | Publish              | **Code**                                    |
   | Runtime stack        | **PHP 8.2**                                 |
   | Operating System     | **Linux**                                   |
   | Region               | **East US**                                 |
   | App Service Plan     | *Create new*: `az104-appplan`               |
   | Pricing plan         | **Standard S1**                             |

   > **Nota:** Standard S1 ou superior e necessario para deployment slots. Free/Basic nao suportam slots.

3. Aba **Deployment**: mantenha defaults (nenhum deployment continuo)

4. Aba **Networking**: mantenha defaults

5. Aba **Monitoring**: **Disable** Application Insights (para simplificar)

6. Clique em **Review + create** > **Create** > **Go to resource**

7. No blade **Overview**, copie a **Default domain** URL (ex: `az104-webapp-<uniqueid>.azurewebsites.net`)

8. Acesse a URL no navegador — voce deve ver a pagina padrao do App Service

   > **Conceito:** Um App Service Plan define os recursos de compute (CPU, memoria, features) disponiveis para as Web Apps hospedadas nele. Multiplas Web Apps podem compartilhar o mesmo plan.

---

### Task 3.2: Configurar Connection String do Storage (Bloco 1)

Voce conecta a Web App ao Storage Account do Bloco 1 para que a aplicacao possa acessar blobs e dados.

1. Na Web App, navegue para **Settings** > **Environment variables**

2. Na aba **App settings**, clique em **+ Add**:

   | Setting | Value                                                                     |
   | ------- | ------------------------------------------------------------------------- |
   | Name    | `STORAGE_ACCOUNT_NAME`                                                    |
   | Value   | `contosostore<uniqueid>` (nome do storage account do Bloco 1)            |

3. Clique em **Apply**

4. Na aba **Connection strings**, clique em **+ Add**:

   | Setting | Value                                                        |
   | ------- | ------------------------------------------------------------ |
   | Name    | `AzureStorageConnection`                                     |
   | Value   | *cole a connection string da Storage Account (Bloco 1)*      |
   | Type    | **Custom**                                                   |

   > **Para obter a connection string:** Va ate a Storage Account (Bloco 1) > **Security + networking** > **Access keys** > copie a **Connection string** de key1.

5. Clique em **Apply** > **Apply** (confirme as alteracoes)

   > **Conexao com Bloco 1:** A Web App agora tem referencia direta ao Storage Account. Em um cenario real, a aplicacao usaria esta connection string para acessar blobs, queues ou tables.

6. **Validacao:** Na Web App, navegue para **Advanced tools** > **Go** (Kudu)

7. No Kudu, va para **Environment** e procure `STORAGE_ACCOUNT_NAME` e `CUSTOMCONNSTR_AzureStorageConnection` — ambos devem estar listados

   > **Dica AZ-104:** Na prova, connection strings definidas como App Settings aparecem com prefixo no ambiente: `CUSTOMCONNSTR_`, `SQLCONNSTR_`, `SQLAZURECONNSTR_`, etc.

---

### Task 3.3: Deploy de aplicacao e Deployment Slots

1. Na Web App, navegue para **Deployment** > **Deployment Center**

2. Configure o source:

   | Setting    | Value            |
   | ---------- | ---------------- |
   | Source     | **External Git** |
   | Repository | `https://github.com/Azure-Samples/php-docs-hello-world` |
   | Branch     | `master`         |

3. Clique em **Save**

4. Aguarde o deployment. Navegue para **Deployment Center** > aba **Logs** para acompanhar

5. Acesse a URL da Web App — voce deve ver "Hello World!" (ou conteudo similar do sample app)

**Criar Deployment Slot:**

6. Navegue para **Deployment** > **Deployment slots**

7. Clique em **+ Add Slot**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `staging`   |
   | Clone settings from | **Do not clone settings** |

8. Clique em **Add**

9. Selecione o slot **staging** (abre como uma Web App separada)

10. No slot staging, configure um deployment diferente (ou use o mesmo repo):
    - Navegue para **Deployment Center** do slot staging
    - Mantenha o mesmo source ou altere o branch para demonstrar a diferenca

11. Acesse a URL do slot staging: `az104-webapp-<uniqueid>-staging.azurewebsites.net`

   > **Conceito:** Slots permitem testar alteracoes em um ambiente identico ao producao antes de promover (swap). Cada slot tem sua propria URL, configuracoes e deployment.

---

### Task 3.4: Swap de Deployment Slots

1. Navegue de volta para a Web App principal (nao o slot) > **Deployment** > **Deployment slots**

2. Clique em **Swap**:

   | Setting     | Value              |
   | ----------- | ------------------ |
   | Source      | **staging**        |
   | Target      | **Production**     |

3. Revise as **Config changes** (mostra quais settings vao mudar)

4. Clique em **Swap**

5. Aguarde a operacao concluir

6. Acesse a URL de producao — o conteudo agora e o que estava no staging

   > **Conceito:** Swap e uma operacao instantanea (switch de DNS/routing). Nao ha downtime. Se algo der errado, faca swap novamente para reverter.

   > **Dica AZ-104:** Slot settings marcados como "deployment slot setting" NAO sao swapped — ficam fixos no slot. Isso e util para connection strings de staging vs production.

---

### Task 3.5: Configurar Auto-scaling

1. Na Web App, navegue para **Settings** > **Scale out (App Service plan)**

2. Selecione **Rules Based** (se disponivel) ou configure:

   | Setting               | Value                        |
   | --------------------- | ---------------------------- |
   | Minimum instances     | `1`                          |
   | Maximum instances     | `3`                          |
   | Rules                 | *custom rule abaixo*         |

3. **+ Add a rule** (scale-out):

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Metric source      | **Current resource**     |
   | Metric name        | **CPU Percentage**       |
   | Operator           | **Greater than**         |
   | Metric threshold   | `60`                     |
   | Duration           | `5` minutes              |
   | Operation          | **Increase count by**    |
   | Instance count     | `1`                      |
   | Cool down          | `5` minutes              |

4. **+ Add a rule** (scale-in):

   | Setting            | Value                    |
   | ------------------ | ------------------------ |
   | Metric source      | **Current resource**     |
   | Metric name        | **CPU Percentage**       |
   | Operator           | **Less than**            |
   | Metric threshold   | `30`                     |
   | Duration           | `5` minutes              |
   | Operation          | **Decrease count by**    |
   | Instance count     | `1`                      |
   | Cool down          | `5` minutes              |

5. Clique em **Save**

   > **Conceito:** Auto-scale no App Service opera no nivel do **App Service Plan**, nao da Web App individual. Todas as apps no mesmo plan sao escaladas juntas.

---

### Task 3.6: Explorar App Service Features (Networking, Logs)

1. Navegue para **Settings** > **Networking** na Web App

2. Explore as opcoes:
   - **Inbound Traffic**: Access restrictions, Private endpoints
   - **Outbound Traffic**: VNet integration, Hybrid connections

   > **Conceito:** VNet Integration permite que a Web App acesse recursos em uma VNet (como o storage com Private Endpoint do Bloco 1).

3. Navegue para **Monitoring** > **App Service logs**

4. Configure:

   | Setting                  | Value            |
   | ------------------------ | ---------------- |
   | Application Logging (Filesystem) | **On** |
   | Level                    | **Information**  |
   | Web server logging       | **File System**  |
   | Quota (MB)               | `35`             |
   | Retention Period (Days)  | `3`              |

5. Clique em **Save**

6. Navegue para **Log stream** e observe os logs em tempo real enquanto acessa a URL da Web App em outra aba

   > **Conceito:** Logs do App Service podem ser enviados para File System, Blob Storage ou Application Insights. Log stream mostra logs em tempo real via browser.

---

## Modo Desafio - Bloco 3

- [ ] Criar App Service Plan `az104-appplan` (Standard S1, Linux) no az104-rg8
- [ ] Criar Web App com runtime PHP 8.2
- [ ] **Integracao Bloco 1:** Configurar App Setting com nome do Storage Account e Connection String
- [ ] Validar variaveis de ambiente via Kudu
- [ ] Deploy de app sample via External Git
- [ ] Criar slot `staging` e fazer deploy
- [ ] Executar **Swap** staging → production
- [ ] Configurar auto-scaling (CPU > 60% scale-out, < 30% scale-in)
- [ ] Explorar Networking (VNet Integration, Access restrictions)
- [ ] Habilitar App Service Logs e testar Log stream

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce precisa de deployment slots para sua Web App. Qual tier minimo do App Service Plan e necessario?**

A) Free F1
B) Basic B1
C) Standard S1
D) Premium P1

<details>
<summary>Ver resposta</summary>

**Resposta: C) Standard S1**

Deployment slots estao disponiveis a partir do tier **Standard S1**. Free e Basic nao suportam slots. Standard permite ate 5 slots, Premium ate 20.

</details>

### Questao 3.2
**Voce fez um swap do slot staging para production. Uma connection string marcada como "deployment slot setting" no slot staging vai para production?**

A) Sim, todas as settings sao swapped
B) Nao, "deployment slot settings" permanecem no slot original
C) Apenas connection strings sao swapped
D) Depende do tipo da connection string

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, "deployment slot settings" permanecem no slot original**

Settings marcadas como "deployment slot setting" sao **sticky** — permanecem no slot e NAO sao swapped. Isso permite ter connection strings diferentes para staging e production (ex: banco de dados diferente).

</details>

### Questao 3.3
**Voce configurou auto-scaling baseado em CPU no App Service Plan. Quando o scale-out acontece, quais apps sao escaladas?**

A) Apenas a Web App que disparou a regra
B) Todas as Web Apps no mesmo App Service Plan
C) Apenas Web Apps com a mesma connection string
D) Depende da configuracao individual de cada app

<details>
<summary>Ver resposta</summary>

**Resposta: B) Todas as Web Apps no mesmo App Service Plan**

Auto-scaling opera no nivel do **App Service Plan**, nao da Web App individual. Quando o plan escala, TODAS as apps hospedadas nele recebem mais instancias. Por isso e importante planejar quais apps compartilham o mesmo plan.

</details>

---

# Bloco 4 - Azure Container Instances

**Origem:** Lab 09b - Implement Azure Container Instances
**Resource Groups utilizados:** `az104-rg9`

## Contexto

A Contoso Corp precisa executar cargas de trabalho em containers para processos batch e microservicos rapidos. Voce implanta Azure Container Instances (ACI) usando o file share do Bloco 1 como volume persistente. Isso demonstra como containers stateless podem acessar dados persistentes armazenados no Azure Storage.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg9                                 │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Container Group: az104-aci-1                                 │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────┐       │  │
│  │  │  Container: az104-container-1                       │       │  │
│  │  │  Image: mcr.microsoft.com/azuredocs/aci-helloworld │       │  │
│  │  │                                                     │       │  │
│  │  │  Resources: 1 CPU, 1.5 GiB memory                  │       │  │
│  │  │  Port: 80 (HTTP)                                    │       │  │
│  │  │  Restart policy: On failure                         │       │  │
│  │  │                                                     │       │  │
│  │  │  Volume Mount:                                      │       │  │
│  │  │  ┌──────────────────────────────────────────┐       │       │  │
│  │  │  │  /mnt/fileshare → contoso-files          │       │       │  │
│  │  │  │  (Azure File Share do Bloco 1)           │       │       │  │
│  │  │  │  Storage: contosostore<id>               │       │       │  │
│  │  │  └──────────────────────────────────────────┘       │       │  │
│  │  └────────────────────────────────────────────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → File share do Bloco 1 montado como volume no container         │
│  → Dados criados pela VM (Bloco 2) visiveis no container          │
└───────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar Container Instance com imagem publica

1. Pesquise e selecione **Container instances** > **+ Create**

2. Aba **Basics**:

   | Setting          | Value                                              |
   | ---------------- | -------------------------------------------------- |
   | Subscription     | *sua subscription*                                 |
   | Resource group   | `az104-rg9` (crie se necessario)                   |
   | Container name   | `az104-container-1`                                |
   | Region           | **East US**                                        |
   | SKU              | **Standard**                                       |
   | Image source     | **Other registry**                                 |
   | Image type       | **Public**                                         |
   | Image            | `mcr.microsoft.com/azuredocs/aci-helloworld`       |
   | OS type          | **Linux**                                          |
   | Size             | **1 vcpu, 1.5 GiB memory**                        |

3. Aba **Networking**:

   | Setting            | Value      |
   | ------------------ | ---------- |
   | Networking type    | **Public** |
   | DNS name label     | `az104-aci-<uniqueid>` (globalmente unico) |
   | Ports              | `80`       |
   | Port protocol      | **TCP**    |

4. Aba **Advanced**:

   | Setting          | Value          |
   | ---------------- | -------------- |
   | Restart policy   | **On failure** |

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment > **Go to resource**

7. No blade **Overview**, copie o **FQDN** (ex: `az104-aci-<uniqueid>.eastus.azurecontainer.io`)

8. Acesse o FQDN no navegador — voce deve ver a pagina "Welcome to Azure Container Instances!"

9. Revise no blade:
   - **Status**: Running
   - **IP address** (publico)
   - **Restart count**

   > **Conceito:** ACI e a forma mais simples de executar containers no Azure. Sem orquestracao, sem gerenciamento de cluster. Ideal para tarefas rapidas, batch jobs e cenarios simples.

---

### Task 4.2: Montar File Share do Bloco 1 como Volume

Voce cria um novo container que monta o file share `contoso-files` do Bloco 1, demonstrando persistencia de dados entre containers e VMs.

1. Primeiro, obtenha a **storage account key** do Bloco 1:
   - Navegue para Storage Account **contosostore\<uniqueid\>** > **Security + networking** > **Access keys**
   - Copie **key1**

2. Pesquise **Container instances** > **+ Create**

3. Aba **Basics**:

   | Setting          | Value                                              |
   | ---------------- | -------------------------------------------------- |
   | Resource group   | `az104-rg9`                                        |
   | Container name   | `az104-container-2`                                |
   | Region           | **East US**                                        |
   | Image source     | **Other registry**                                 |
   | Image type       | **Public**                                         |
   | Image            | `mcr.microsoft.com/azuredocs/aci-helloworld`       |
   | OS type          | **Linux**                                          |
   | Size             | **1 vcpu, 1.5 GiB memory**                        |

4. Aba **Networking**:

   | Setting            | Value      |
   | ------------------ | ---------- |
   | Networking type    | **Public** |
   | DNS name label     | `az104-aci2-<uniqueid>` |
   | Ports              | `80`       |

5. Aba **Advanced**:

   | Setting          | Value          |
   | ---------------- | -------------- |
   | Restart policy   | **On failure** |

6. Em **Volume mounts**, clique em **+ Add volume**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Volume name          | `filesharevolume`                              |
   | Volume type          | **Azure file share**                           |
   | Storage account name | `contosostore<uniqueid>` (Bloco 1)            |
   | Storage account key  | *cole key1 copiada acima*                     |
   | File share name      | `contoso-files`                                |
   | Mount path           | `/mnt/fileshare`                               |

7. Clique em **Add**

8. Clique em **Review + create** > **Create**

9. Apos o deploy, navegue para o container > **Settings** > **Containers** > selecione o container > **Connect**

10. Selecione `/bin/sh` > **Connect**

11. No terminal do container, execute:

    ```bash
    ls /mnt/fileshare/
    cat /mnt/fileshare/vm-test.txt
    ```

    > Voce deve ver o arquivo `vm-test.txt` criado pela Windows VM no Bloco 2!

12. Crie um arquivo a partir do container:

    ```bash
    echo "Hello from ACI container" > /mnt/fileshare/aci-test.txt
    ```

13. **Validacao cruzada:** Volte ao portal > Storage Account > **File shares** > **contoso-files** — confirme que `aci-test.txt` aparece

    > **Conexao com Blocos 1 e 2:** O mesmo file share e acessado pela Windows VM (drive Z:) e pelo container ACI (/mnt/fileshare). Dados sao compartilhados entre compute platforms diferentes via Azure Files.

---

### Task 4.3: Revisar logs e eventos do container

1. Na container instance **az104-container-1**, navegue para **Settings** > **Containers**

2. Selecione o container e explore as abas:
   - **Events**: mostra eventos de lifecycle (Pull, Start, etc.)
   - **Logs**: mostra stdout/stderr da aplicacao
   - **Properties**: configuracao detalhada

3. Na aba **Logs**, revise as mensagens de log da aplicacao

4. Navegue para a container instance > **Monitoring** > **Metrics**

5. Explore metricas como:
   - **CPU Usage**
   - **Memory Usage**
   - **Network Bytes Received/Sent**

   > **Conceito:** ACI fornece metricas e logs basicos. Para cenarios mais avancados, integre com Azure Monitor e Log Analytics.

---

### Task 4.4: Testar restart e lifecycle do container

1. Na container instance **az104-container-1**, clique em **Restart** no blade **Overview**

2. Observe os **Events** durante o restart

3. Agora clique em **Stop**

4. Observe o status mudar para **Stopped**

5. Clique em **Start** para reiniciar

6. Acesse o FQDN novamente para confirmar que o container esta respondendo

   > **Conceito:** ACI containers podem ser stopped/started. Quando stopped, voce NAO e cobrado por compute (apenas por storage de logs). A restart policy determina o comportamento automatico: Always, OnFailure, Never.

   > **Dica AZ-104:** Na prova, diferencie: ACI = containers simples sem orquestracao; AKS = Kubernetes gerenciado com orquestracao completa; Container Apps = meio-termo (orquestracao serverless baseada em KEDA/Dapr).

---

## Modo Desafio - Bloco 4

- [ ] Criar container `az104-container-1` com imagem `aci-helloworld` e acesso publico
- [ ] Acessar FQDN e confirmar que o container esta respondendo
- [ ] **Integracao Bloco 1:** Criar `az104-container-2` com volume montando file share `contoso-files`
- [ ] **Integracao Bloco 2:** Via terminal do container, ler arquivo criado pela VM (`vm-test.txt`)
- [ ] Criar arquivo no container → confirmar no portal do Storage Account
- [ ] Revisar logs e eventos do container
- [ ] Testar restart/stop/start e observar lifecycle

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce precisa montar um Azure File Share em um container ACI. Quais informacoes sao necessarias?**

A) Apenas o nome do file share
B) Storage account name, storage account key e file share name
C) Apenas a connection string do storage
D) O SAS token do file share

<details>
<summary>Ver resposta</summary>

**Resposta: B) Storage account name, storage account key e file share name**

Para montar um Azure File Share como volume em ACI, voce precisa do storage account name, da storage account key (para autenticacao) e do nome do file share.

</details>

### Questao 4.2
**Qual restart policy do ACI e mais adequada para um job de processamento batch que deve executar uma vez e parar?**

A) Always
B) OnFailure
C) Never
D) Scheduled

<details>
<summary>Ver resposta</summary>

**Resposta: C) Never**

A restart policy **Never** faz o container executar uma vez e parar. **OnFailure** reinicia apenas se o container falhar (exit code != 0). **Always** reinicia sempre (default para servicos long-running).

</details>

### Questao 4.3
**Voce tem um container ACI no estado Stopped. Voce esta sendo cobrado por compute?**

A) Sim, enquanto o container existir
B) Nao, containers stopped nao geram custo de compute
C) Sim, mas com 50% de desconto
D) Depende do SKU

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, containers stopped nao geram custo de compute**

ACI cobra por segundo de uso de CPU e memoria. Containers no estado Stopped nao consomem compute e nao geram custo de compute. Voce e cobrado apenas quando o container esta Running.

</details>

---

# Bloco 5 - Azure Container Apps

**Origem:** Lab 09c - Implement Azure Container Apps
**Resource Groups utilizados:** `az104-rg10`

## Contexto

Como passo final, voce implanta Azure Container Apps — uma plataforma serverless para containers que oferece recursos avancados de orquestracao como auto-scaling baseado em HTTP, revisoes e integracao com KEDA. O Container Apps Environment sera configurado para usar a VNet da Semana 1 e o storage do Bloco 1, demonstrando a integracao completa do ecossistema.

## Diagrama

```
┌───────────────────────────────────────────────────────────────────┐
│                          az104-rg10                                │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Container Apps Environment: az104-cae                        │  │
│  │  (Ambiente gerenciado para Container Apps)                    │  │
│  │                                                               │  │
│  │  VNet Integration: CoreServicesVnet (Semana 1)                │  │
│  │  ou subnet dedicada                                           │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────┐     │  │
│  │  │  Container App: az104-ca-1                            │     │  │
│  │  │  Image: mcr.microsoft.com/azuredocs/containerapps-   │     │  │
│  │  │         helloworld:latest                             │     │  │
│  │  │                                                       │     │  │
│  │  │  Ingress: External (HTTP, port 80)                    │     │  │
│  │  │  Scaling: min 0, max 5 (HTTP requests)                │     │  │
│  │  │  Revisions: Multiple (blue/green)                     │     │  │
│  │  │                                                       │     │  │
│  │  │  Environment Variables:                               │     │  │
│  │  │  • STORAGE_CONN (← Bloco 1)                          │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────┐     │  │
│  │  │  Container App: az104-ca-2                            │     │  │
│  │  │  (segunda revisao / multi-container)                  │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  → Usa VNet da Semana 1 para integracao de rede                   │
│  → Storage Account do Bloco 1 referenciado via env vars           │
│  → Demonstra evolucao: VMs → Web Apps → ACI → Container Apps     │
└───────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Container Apps Environment

O environment define a infraestrutura compartilhada onde os Container Apps executam.

1. Pesquise e selecione **Container Apps Environments** > **+ Create**

2. Aba **Basics**:

   | Setting          | Value                          |
   | ---------------- | ------------------------------ |
   | Subscription     | *sua subscription*             |
   | Resource group   | `az104-rg10` (crie se necessario) |
   | Environment name | `az104-cae`                    |
   | Region           | **East US**                    |
   | Environment type | **Consumption only**           |

3. Aba **Networking**:

   | Setting                     | Value                                      |
   | --------------------------- | ------------------------------------------ |
   | Use your own virtual network | **Yes**                                   |
   | Virtual network             | **CoreServicesVnet** (de az104-rg4, Semana 1) |
   | Infrastructure subnet       | *Crie uma nova subnet dedicada* `ContainerAppsSubnet` (10.20.30.0/23, minimo /23) |

   > **Nota:** Container Apps requer uma subnet dedicada com tamanho minimo /23. Se a CoreServicesVnet nao tiver espaco disponivel ou nao existir, crie sem VNet integration (selecione **No**) e prossiga.

   > **Conexao com Semana 1:** O Container Apps Environment esta integrado a CoreServicesVnet, permitindo comunicacao com recursos na VNet e VNets peered (ManufacturingVnet).

4. Aba **Monitoring**: selecione **Do not create** para Log Analytics (simplificar) ou crie um novo workspace

5. Clique em **Review + create** > **Create**

6. Aguarde o deployment (pode levar 3-5 minutos)

   > **Conceito:** O Container Apps Environment e analogo a um "cluster" — fornece isolamento, logging e networking compartilhados. Multiplos Container Apps podem coexistir no mesmo environment.

---

### Task 5.2: Criar Container App com imagem publica

1. Pesquise **Container Apps** > **+ Create**

2. Aba **Basics**:

   | Setting            | Value                          |
   | ------------------ | ------------------------------ |
   | Subscription       | *sua subscription*             |
   | Resource group     | `az104-rg10`                   |
   | Container app name | `az104-ca-1`                   |
   | Region             | **East US**                    |
   | Container Apps Environment | **az104-cae** (criado acima) |

3. Aba **Container**:

   | Setting         | Value                                                        |
   | --------------- | ------------------------------------------------------------ |
   | Image source    | **Docker Hub or other registries**                           |
   | Image type      | **Public**                                                   |
   | Registry login server | `mcr.microsoft.com`                                   |
   | Image and tag   | `azuredocs/containerapps-helloworld:latest`                  |
   | CPU and Memory  | **0.25 CPU cores, 0.5 Gi memory**                           |

4. Em **Environment variables**, clique em **+ Add**:

   | Setting | Value                                              |
   | ------- | -------------------------------------------------- |
   | Name    | `STORAGE_CONNECTION`                               |
   | Source  | **Manual entry**                                   |
   | Value   | *connection string do Storage Account (Bloco 1)*   |

   > **Conexao com Bloco 1:** A variavel de ambiente referencia o Storage Account, permitindo que a aplicacao acesse dados do Bloco 1. Em producao, use secrets ao inves de manual entry.

5. Aba **Ingress**:

   | Setting               | Value        |
   | --------------------- | ------------ |
   | Ingress               | **Enabled**  |
   | Ingress traffic        | **Accepting traffic from anywhere** |
   | Ingress type           | **HTTP**     |
   | Target port            | `80`         |

6. Clique em **Review + create** > **Create**

7. Apos o deploy, navegue para o Container App > **Overview**

8. Copie a **Application Url** e acesse no navegador — voce deve ver a pagina de boas-vindas

   > **Conceito:** Container Apps oferece HTTPS automatico, auto-scaling e gerenciamento de revisoes. A URL gerada inclui HTTPS com certificado gerenciado.

---

### Task 5.3: Configurar Scaling e Revisions

1. No Container App **az104-ca-1**, navegue para **Application** > **Scale and replicas**

2. Clique em **Edit and deploy**

3. Na aba **Scale**:

   | Setting          | Value |
   | ---------------- | ----- |
   | Min replicas     | `0`   |
   | Max replicas     | `5`   |

4. Revise a regra de scaling padrao (**HTTP scaling**):
   - Concurrent requests per replica: `10` (cada replica lida com ate 10 requests simultaneos)

5. Clique em **Create**

   > **Conceito:** Container Apps pode escalar ate ZERO replicas quando nao ha trafego (scale-to-zero). Isso reduz custos drasticamente. O primeiro request apos scale-to-zero pode ter **cold start** (latencia adicional).

6. Navegue para **Application** > **Revisions and replicas**

7. Observe a revisao atual (ativa, com 100% do trafego)

   > **Conceito:** Cada alteracao no Container App cria uma nova **Revision**. Voce pode ter multiplas revisoes ativas para canary deployments ou A/B testing.

---

### Task 5.4: Criar nova revisao (Blue/Green deployment)

1. Navegue para **Revisions and replicas** > **+ Create new revision**

2. Na aba **Container image**:
   - Mantenha a mesma imagem mas altere uma environment variable:

   | Setting | Value                       |
   | ------- | --------------------------- |
   | Name    | `APP_VERSION`               |
   | Source  | **Manual entry**            |
   | Value   | `v2`                        |

3. Clique em **Create**

4. Apos a criacao, navegue para **Revisions and replicas**

5. Agora ha **duas revisoes**. Configure o traffic split:
   - Selecione **Revision management** > altere o modo para **Multiple: Several revisions active simultaneously**
   - Revisao v1: `50%`
   - Revisao v2: `50%`

6. Clique em **Save**

7. Acesse a URL da aplicacao varias vezes — voce pode observar respostas de diferentes revisoes

   > **Conceito:** Traffic splitting permite canary deployments e A/B testing. Voce pode gradualmente migrar trafego para a nova revisao (ex: 10%, 25%, 50%, 100%) e reverter se necessario.

   > **Conexao com Bloco 3:** Compare com deployment slots do App Service (Bloco 3). Container Apps usa revisoes para o mesmo proposito, mas com mais granularidade no traffic split.

---

### Task 5.5: Explorar Features do Container Apps (Secrets, Logs, Metrics)

1. Navegue para **Settings** > **Secrets**

2. Clique em **+ Add**:

   | Setting | Value                                     |
   | ------- | ----------------------------------------- |
   | Key     | `storage-key`                             |
   | Type    | **Container Apps Secret**                 |
   | Value   | *cole a storage account key do Bloco 1*   |

3. Clique em **Add**

   > **Conceito:** Secrets sao armazenados de forma segura no Container Apps Environment. Eles podem ser referenciados como environment variables nos containers, evitando hardcode de credenciais.

4. Navegue para **Monitoring** > **Log stream**

5. Selecione a revisao ativa e observe os logs em tempo real

6. Navegue para **Monitoring** > **Metrics**

7. Explore metricas como:
   - **Requests** (total de requests HTTP)
   - **Replica Count** (numero de replicas ativas)
   - **CPU Usage** e **Memory Usage**

8. Navegue para **Application** > **Containers**:
   - Revise a configuracao do container
   - Note os resource limits (CPU/Memory)

   > **Conceito:** Container Apps integra com Azure Monitor para metricas e logs. Em cenarios de producao, use Log Analytics workspace para consultas avancadas (KQL).

   > **Dica AZ-104:** Na prova, compare: ACI = containers simples (sem scaling avancado); Container Apps = serverless com auto-scale, revisions, HTTPS automatico; AKS = controle total do Kubernetes.

---

## Modo Desafio - Bloco 5

- [ ] Criar Container Apps Environment `az104-cae` no az104-rg10
- [ ] **Integracao Semana 1:** Configurar VNet Integration com CoreServicesVnet (subnet dedicada /23)
- [ ] Criar Container App `az104-ca-1` com imagem `containerapps-helloworld`
- [ ] **Integracao Bloco 1:** Adicionar env var com connection string do Storage Account
- [ ] Acessar Application URL e confirmar resposta
- [ ] Configurar scaling: min 0, max 5 (HTTP, 10 concurrent requests)
- [ ] Criar nova revisao com env var `APP_VERSION=v2`
- [ ] Configurar traffic split: 50%/50% entre revisoes
- [ ] Adicionar Secret com storage key do Bloco 1
- [ ] Explorar Log stream e Metrics

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Qual o tamanho minimo de subnet necessario para um Container Apps Environment com VNet integration?**

A) /28
B) /27
C) /24
D) /23

<details>
<summary>Ver resposta</summary>

**Resposta: D) /23**

Container Apps requer uma subnet dedicada com tamanho minimo **/23** (512 enderecos). Isso e necessario para acomodar a infraestrutura do environment e as replicas dos containers.

</details>

### Questao 5.2
**Voce configurou um Container App com min replicas = 0. O que acontece quando nao ha trafego HTTP?**

A) Uma replica permanece ativa (minimo 1)
B) O Container App e escalado para zero replicas (nao gera custo de compute)
C) O Container App e deletado automaticamente
D) O Container App entra em modo hibernacao com custo reduzido

<details>
<summary>Ver resposta</summary>

**Resposta: B) O Container App e escalado para zero replicas (nao gera custo de compute)**

Container Apps suporta **scale-to-zero** — quando nao ha trafego, nenhuma replica e executada e nao ha custo de compute. O primeiro request apos scale-to-zero pode ter cold start (latencia adicional).

</details>

### Questao 5.3
**Qual servico Azure e mais adequado para executar containers com orquestracao serverless, auto-scaling baseado em HTTP e suporte a revisoes para canary deployment?**

A) Azure Container Instances (ACI)
B) Azure Kubernetes Service (AKS)
C) Azure Container Apps
D) Azure App Service (containers)

<details>
<summary>Ver resposta</summary>

**Resposta: C) Azure Container Apps**

Container Apps oferece orquestracao serverless com auto-scaling (incluindo scale-to-zero), revisoes para canary/blue-green deployments, HTTPS automatico e integracao com KEDA para scaling baseado em eventos. ACI e mais simples (sem orquestracao), AKS oferece controle total do Kubernetes.

</details>

### Questao 5.4
**Voce tem duas revisoes do Container App com traffic split 80/20. Voce quer reverter totalmente para a revisao anterior. O que voce deve fazer?**

A) Deletar a nova revisao
B) Alterar o traffic split para 100/0 (revisao anterior/nova)
C) Fazer rollback via CLI
D) Recriar o Container App

<details>
<summary>Ver resposta</summary>

**Resposta: B) Alterar o traffic split para 100/0 (revisao anterior/nova)**

Basta alterar o traffic split para enviar 100% do trafego para a revisao desejada. As revisoes podem ser mantidas ativas para futuras mudancas. Nao e necessario deletar a revisao.

</details>

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