> Voltar para o [Cenário Contoso](../cenario-contoso.md) | Próximo: [Bloco 2 - Virtual Machines](bloco2-vms.md)

# Bloco 1 - Azure Storage

**Origem:** Lab 07 - Manage Azure Storage
**Resource Groups utilizados:** `rg-contoso-storage`

## Contexto

A Contoso Corp precisa de armazenamento centralizado para dados corporativos. Voce cria uma Storage Account que sera usada por todos os blocos seguintes: blobs para dados de aplicacoes (Blocos 3 e 5), file shares montados em containers (Bloco 4) e discos gerenciados para VMs (Bloco 2). A seguranca de rede integra-se com as VNets criadas na Semana 1 — voce configurara Service Endpoints e Private Endpoints na vnet-contoso-hub/snet-shared.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                          rg-contoso-storage                        │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Storage Account: stcontosoprod01                            │  │
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
│  │  • Service Endpoint: snet-shared (Semana 1)                  │  │
│  │  • Private Endpoint: vnet-contoso-hub (Semana 1)             │  │
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

**O que estamos fazendo e por que:** A Storage Account e o ponto de entrada para todo armazenamento no Azure. Pense nela como um "predio" que contem diferentes "andares" (Blob, File, Queue, Table) — cada um otimizado para um tipo de dado. Tudo que voce armazena no Azure passa por uma Storage Account.

Voce cria a Storage Account principal que sera referenciada em todos os blocos seguintes.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Storage accounts** > **+ Create**

3. Aba **Basics**:

   | Setting              | Value                                             |
   | -------------------- | ------------------------------------------------- |
   | Subscription         | *sua subscription*                                |
   | Resource group       | `rg-contoso-storage` (crie se necessario)         |
   | Storage account name | `stcontosoprod01` (3-24 chars, lowercase+numeros) |
   | Region               | **(US) East US**                                  |
   | Performance          | **Standard**                                      |
   | Redundancy           | **Locally-redundant storage (LRS)**               |

   > **Performance:** Standard usa HDD (mais barato, maioria dos cenarios). Premium usa SSD (baixa latencia, I/O intensivo). Na prova, Standard e a resposta padrao a menos que o cenario exija baixa latencia.

   > **Redundancy:** LRS replica dados 3x dentro de um unico datacenter. E a opcao mais barata, mas nao protege contra falha do datacenter. Para producao critica, considere ZRS (3 zonas), GRS (2 regioes) ou GZRS (3 zonas + regiao secundaria).

4. Aba **Advanced**: revise as opcoes de seguranca — note **Require secure transfer for REST API operations** (habilitado por padrao)

   > **Secure transfer** forca HTTPS em todas as chamadas REST. Desabilitar permite HTTP, o que e inseguro. Na prova, se o cenario menciona "secure transfer", esta se referindo a essa configuracao.

5. Aba **Networking**: mantenha **Enable public access from all networks** por enquanto (sera restrito nas Tasks 1.6 e 1.7)

6. Aba **Data protection**: revise as opcoes de soft delete (habilitadas por padrao para blobs e containers)

7. Aba **Encryption**: note que Microsoft-managed keys (MMK) e o padrao

8. Clique em **Review + Create** > **Create** > **Go to resource**

9. No blade **Overview**, identifique:
   - **Primary endpoint** (URLs para blob, file, queue, table)
   - **Primary location** e **Replication status**

   > **Conceito:** Uma Storage Account fornece um namespace unico para seus dados no Azure. Cada objeto tem um endereco que inclui o nome da conta (ex: `stcontosoprod01.blob.core.windows.net/data/arquivo.txt`). O nome e globalmente unico justamente por fazer parte da URL.

   > **Conexao com Blocos 2-5:** Esta storage account sera usada para connection strings (Bloco 3), file share mount (Bloco 4) e dados de aplicacoes (Bloco 5).

---

### Task 1.2: Criar Blob Container e fazer upload

**O que estamos fazendo e por que:** Blobs (Binary Large Objects) sao o servico de armazenamento de objetos do Azure — como um disco infinito na nuvem. Voce precisa de um **container** para organizar os blobs (analogia: container = pasta raiz, blob = arquivo). Sem container, nao ha onde colocar os dados.

O blob container armazenara dados corporativos que serao acessados pelas Web Apps (Bloco 3) e Container Apps (Bloco 5).

1. Na Storage Account, navegue para **Data storage** > **Containers**

2. Clique em **+ Container**:

   | Setting             | Value                             |
   | ------------------- | --------------------------------- |
   | Name                | `data`                            |
   | Public access level | **Private (no anonymous access)** |

   > **Public access level** controla se usuarios anonimos (sem autenticacao) podem ler os blobs. **Private** = ninguem sem credenciais acessa. **Blob** = leitura anonima por blob individual. **Container** = leitura anonima de todos os blobs + listagem. Em producao, use Private sempre que possivel.

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

   > **Conceito:** As tiers controlam o equilibrio entre custo de armazenamento e custo de acesso. Pense como estantes: Hot = mesa de trabalho (acesso rapido, caro para guardar). Cool = armario (30 dias min). Cold = deposito (90 dias min). Archive = cofre externo (180 dias min, precisa "desenterrar" antes de usar — rehydrate pode levar horas).

   > **Dica prova:** Archive tier NAO permite leitura direta. O blob precisa ser rehidratado para Hot ou Cool antes de poder ser acessado. Questoes sobre "acessar blob em Archive" — a resposta envolve Change Tier primeiro.

---

### Task 1.3: Configurar acesso via SAS Token e Stored Access Policy

**O que estamos fazendo e por que:** Compartilhar a storage account key da acesso total a tudo — e como dar a chave do predio inteiro. SAS (Shared Access Signature) permite criar "chaves temporarias" com permissoes limitadas (so leitura, so blob, expira amanha). E a forma recomendada de conceder acesso granular sem expor credenciais completas.

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

   > **Signing key** define qual chave da storage account assina o SAS. Se essa chave for regenerada, TODOS os SAS assinados por ela se tornam invalidos imediatamente. Isso e um mecanismo de revogacao de emergencia.

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

   > **Conceito:** Stored Access Policies permitem gerenciar SAS tokens de forma centralizada. Voce pode revogar acesso alterando ou deletando a policy, ao inves de regenerar a storage key. Analogia: SAS sem policy = chave avulsa (para revogar, troca a fechadura toda). SAS com policy = cartao de acesso (desativa so o cartao).

   > **Dica AZ-104:** Na prova, questoes frequentes: como revogar um SAS? (1) Deletar a stored access policy, (2) Regenerar a storage key usada para assinar, (3) Alterar a expiry date da policy.

---

### Task 1.4: Criar Azure File Share

**O que estamos fazendo e por que:** Azure Files fornece file shares na nuvem acessiveis via protocolo SMB (Windows) ou NFS (Linux). A grande vantagem sobre Blob Storage e que voce pode **montar como unidade de rede** — VMs, containers e ate maquinas on-premises veem como um drive normal (Z:, por exemplo). E como ter um servidor de arquivos sem gerenciar o servidor.

O file share sera montado como unidade de rede nas VMs (Bloco 2) e como volume nos containers (Bloco 4).

1. Na Storage Account, navegue para **Data storage** > **File shares**

2. Clique em **+ File share**:

   | Setting | Value                     |
   | ------- | ------------------------- |
   | Name    | `contoso-files`           |
   | Tier    | **Transaction optimized** |

   > **Tier do File Share:** Transaction optimized = uso geral (maioria dos cenarios). Hot = acesso frequente. Cool = arquivo/compliance. Premium = I/O intensivo (SSD). Na prova, Transaction optimized e a escolha padrao.

3. Clique em **Create**

4. Selecione **contoso-files** > **Upload**:
   - Faca upload de um arquivo de teste (ex: `config.txt`)

5. Clique em **Upload**

6. Selecione o file share **contoso-files** > **Properties**:
   - Note o **URL** e a **Quota**

7. Clique em **Connect** > selecione **Windows**:
   - Revise o script PowerShell gerado. Note que ele usa **storage account key** para autenticacao
   - **Copie e salve** o script — sera usado no Bloco 2 para montar o share na VM

   > **Por que o portal gera um script?** Montar um file share remoto requer autenticacao e configuracao de rede. O script gerado pelo portal inclui tudo: teste de conectividade (porta 445), armazenamento de credenciais e mapeamento do drive. Voce so precisa copiar e executar.

8. Explore as opcoes:
   - **Snapshots**: para backup point-in-time
   - **Backup**: integracao com Azure Backup

   > **Conceito:** Azure Files oferece file shares SMB e NFS acessiveis via protocolo padrao. SMB 3.0 suporta criptografia em transito. A porta 445 (SMB) precisa estar aberta — muitos ISPs bloqueiam essa porta, o que pode impedir acesso de redes domesticas.

   > **Conexao com Bloco 2:** O script de conexao sera executado na Windows VM para montar o share como drive Z:.
   > **Conexao com Bloco 4:** O file share sera montado como volume no container ACI.

---

### Task 1.5: Configurar Blob Lifecycle Management e Immutability

**O que estamos fazendo e por que:** Com o tempo, dados acumulam e o custo cresce. Lifecycle Management automatiza a movimentacao de blobs entre tiers baseado em regras (ex: "apos 30 dias sem acesso, mova para Cool"). Immutability garante que dados nao possam ser modificados ou deletados por um periodo — essencial para compliance regulatoria (financeiro, saude, governo).

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

   > **Lendo a regra completa:** "Para todos os block blobs na conta: se nao foram modificados ha mais de 30 dias, mova para Cool. Se nao foram modificados ha mais de 90 dias, mova para Archive." Isso cria uma cascata automatica que reduz custos ao longo do tempo.

5. Clique em **Add**

6. Agora configure **Immutability** no container. Navegue para **Containers** > **data** > **Access policy**

7. Em **Immutable blob storage**, clique em **Add policy**:

   | Setting          | Value                    |
   | ---------------- | ------------------------ |
   | Policy type      | **Time-based retention** |
   | Retention period | `7` days                 |

8. Clique em **Save**

   > **Conceito:** Lifecycle management automatiza a transicao entre tiers (questao de custo). Immutability (WORM — Write Once, Read Many) impede modificacao/exclusao de blobs por um periodo — questao de compliance (SEC, FINRA, CFTC). Sao recursos complementares com propositos completamente diferentes.

   > **Dica AZ-104:** Na prova, diferencie: Lifecycle = automacao de custo; Immutability = compliance e retencao legal. Immutability tem dois modos: **time-based** (bloqueia por X dias) e **legal hold** (bloqueia indefinidamente ate ser removido manualmente).

---

### Task 1.6: Configurar Service Endpoint na VNet da Semana 1

**O que estamos fazendo e por que:** Ate agora, a Storage Account aceita trafego de qualquer lugar na internet. Service Endpoint cria uma "rota expressa" entre uma subnet e o servico Azure — o trafego viaja pelo backbone privado da Microsoft em vez da internet publica. Alem de melhorar seguranca, voce pode configurar o firewall do storage para aceitar trafego **apenas** dessa subnet.

Voce restringe o acesso a Storage Account para aceitar trafego apenas da snet-shared criada na Semana 1 (vnet-contoso-hub).

1. Navegue para a **Storage Account** > **Security + networking** > **Networking**

2. Selecione **Enabled from selected virtual networks and IP addresses**

3. Em **Virtual networks**, clique em **+ Add existing virtual network**:

   | Setting         | Value                                                  |
   | --------------- | ------------------------------------------------------ |
   | Subscription    | *sua subscription*                                     |
   | Virtual network | **vnet-contoso-hub** (do rg-contoso-network, Semana 1) |
   | Subnets         | **snet-shared**                                        |

   > **Nota:** Se a VNet da Semana 1 nao existir mais, crie uma nova VNet `StorageVnet` (10.50.0.0/16) com subnet `StorageSubnet` (10.50.0.0/24) no rg-contoso-storage e use-a.

4. Clique em **Add**

5. Em **Firewall**, adicione **seu IP de cliente** (marque a checkbox se disponivel) para manter acesso pelo portal

   > **Por que adicionar seu IP?** Ao restringir para "selected networks", voce tambem bloqueia seu proprio acesso pelo portal. Adicionar seu IP garante que voce continue gerenciando a conta. Em producao, use VPN ou Azure Bastion em vez de whitelist de IP.

6. Clique em **Save**

7. **Validacao:** Aguarde 30 segundos. Navegue para **Containers** > **data** — voce deve ainda conseguir acessar (seu IP esta na whitelist)

   > **Conceito:** Service Endpoints adicionam uma rota otimizada do subnet para o servico Azure. O trafego permanece na rede backbone da Microsoft, nunca passando pela internet publica. O endpoint e habilitado na subnet (camada de rede) e referenciado no firewall do storage (camada de servico) — ambos precisam estar configurados.

   > **Conexao com Semana 1:** Voce esta usando a infraestrutura de rede criada no Bloco 4 (Virtual Networking) da Semana 1. A snet-shared agora tem acesso direto e seguro ao storage.

---

### Task 1.6b: Aplicar Service Endpoint Policy na subnet

**O que estamos fazendo e por que:** Service Endpoint resolve o problema de "por onde o trafego viaja", mas cria outro: a subnet com endpoint habilitado pode acessar **qualquer** Storage Account no Azure — inclusive de outros tenants. Imagine que um insider mal-intencionado copia dados para uma Storage Account pessoal. Service Endpoint Policy resolve isso, restringindo o **destino** do trafego para apenas as contas autorizadas.

Sem uma policy, a subnet com Service Endpoint para `Microsoft.Storage` pode acessar **qualquer** Storage Account do Azure — inclusive de outros tenants. Voce cria uma policy para restringir o acesso apenas a Storage Account da Contoso.

1. No portal, pesquise **Service endpoint policies** na barra de busca e clique no servico

2. Clique em **+ Create**

3. Aba **Basics**:

   | Setting        | Value                       |
   | -------------- | --------------------------- |
   | Subscription   | *sua subscription*          |
   | Resource group | `rg-contoso-storage`        |
   | Name           | `policy-storage-contoso`    |
   | Location       | **East US** (mesma da VNet) |

4. Aba **Policy definitions**, clique em **+ Add a resource**:

   | Setting        | Value                                     |
   | -------------- | ----------------------------------------- |
   | Service        | **Microsoft.Storage**                     |
   | Scope          | **Select a single account**               |
   | Subscription   | *sua subscription*                        |
   | Resource group | `rg-contoso-storage`                      |
   | Resource       | *sua Storage Account* (`stcontosoprod01`) |

5. Clique em **Add** e depois **Review + create** > **Create**

6. Agora associe a policy a subnet. Navegue para **Virtual networks** > **vnet-contoso-hub** > **Subnets** > **snet-shared**

7. Em **Service endpoint policy**, selecione **policy-storage-contoso**

8. Clique em **Save**

9. **Validacao:** A partir de agora, VMs nessa subnet so conseguem acessar via Service Endpoint a Storage Account especificada na policy. Tentativas de acessar outras Storage Accounts serao bloqueadas.

   > **Conceito:** Service Endpoint Policies filtram o **destino** do trafego de Service Endpoints. Sem policy, a subnet pode acessar qualquer recurso PaaS do tipo habilitado. Com policy, apenas recursos especificos sao permitidos. Isso evita exfiltracao de dados para Storage Accounts nao autorizadas (inclusive de outros tenants). A policy so funciona com Service Endpoints habilitados e atualmente suporta **Microsoft.Storage** (GA) e Azure SQL Database (preview).

   > **Dica AZ-104:** Na prova, se o cenario diz "permitir acesso via Service Endpoint apenas a uma Storage Account especifica (nao a todas)", a resposta e **Service Endpoint Policy**. Nao confunda com NSG (que filtra IP/porta) nem com firewall do storage (que filtra subnet/IP de origem). A policy filtra o **destino** do Service Endpoint.

---

### Task 1.7: Criar Private Endpoint para o Storage Account

> **Cobranca:** Private Endpoints geram cobranca enquanto existirem.

**O que estamos fazendo e por que:** Private Endpoint vai alem do Service Endpoint — ele cria um **IP privado da sua VNet** para o servico. Com Service Endpoint, o storage ainda tem IP publico (o trafego so muda de caminho). Com Private Endpoint, o storage ganha um IP privado (ex: 10.20.10.5) e voce pode desabilitar completamente o acesso publico. E como trazer o servico para "dentro" da sua rede.

O Private Endpoint atribui um IP privado da VNet ao storage, eliminando exposicao publica.

1. Navegue para a **Storage Account** > **Security + networking** > **Networking** > aba **Private endpoint connections**

2. Clique em **+ Private endpoint**

3. Aba **Basics**:

   | Setting                | Value                    |
   | ---------------------- | ------------------------ |
   | Subscription           | *sua subscription*       |
   | Resource group         | `rg-contoso-storage`     |
   | Name                   | `pe-stcontosoprod01`     |
   | Network Interface Name | `pe-stcontosoprod01-nic` |
   | Region                 | **East US**              |

4. Aba **Resource**:

   | Setting             | Value    |
   | ------------------- | -------- |
   | Target sub-resource | **blob** |

   > **Target sub-resource** define qual servico do storage ganha o IP privado. Cada servico (blob, file, queue, table) precisa de seu proprio Private Endpoint. Aqui estamos criando apenas para blob.

5. Aba **Virtual Network**:

   | Setting         | Value                                                  |
   | --------------- | ------------------------------------------------------ |
   | Virtual network | **vnet-contoso-hub** (do rg-contoso-network, Semana 1) |
   | Subnet          | **snet-shared**                                        |

   > **Nota:** Se a VNet da Semana 1 nao existir, use a VNet alternativa criada na Task 1.6.

6. Aba **DNS**: Mantenha **Yes** para integrar com Private DNS Zone

   > **Por que integrar com DNS?** Sem integracao DNS, o FQDN `stcontosoprod01.blob.core.windows.net` continua resolvendo para o IP publico. Com a Private DNS Zone, o mesmo FQDN resolve para o IP privado quando consultado de dentro da VNet. Isso garante que aplicacoes existentes funcionem sem mudanca de URL.

7. Clique em **Review + Create** > **Create**

8. Apos o deploy, navegue para o Private Endpoint criado. Note:
   - **Network interface** com IP privado atribuido (ex: 10.20.10.x)
   - **DNS configuration** com FQDN apontando para o IP privado

9. **Validacao:** Navegue para **Private DNS zones** no portal. Uma zona `privatelink.blob.core.windows.net` foi criada automaticamente com um registro A apontando para o IP privado.

   > **Conceito:** Private Endpoints usam Azure Private Link para projetar o servico na sua VNet. O DNS e atualizado para resolver o FQDN publico para o IP privado. Diferente de Service Endpoints, o trafego usa um IP da sua subnet — o servico literalmente "aparece" na sua rede.

   > **Conexao com Semana 1:** O Private Endpoint esta na snet-shared da vnet-contoso-hub. VMs nessa VNet (ou VNets peered) acessarao o storage via IP privado, sem sair da rede Microsoft.

---

### Task 1.8: Testar acesso anonimo e Soft Delete

**O que estamos fazendo e por que:** Esta task demonstra dois conceitos importantes: (1) a diferenca pratica entre acesso Private e Blob/Container (anonimo), e (2) como Soft Delete funciona como "lixeira" protegendo contra exclusao acidental. Ambos sao temas recorrentes no AZ-104.

1. Na Storage Account, navegue para **Settings** > **Configuration**

2. Localize **Allow Blob anonymous access** e altere para **Enabled** (se nao estiver)

   > **Atencao:** Esta e uma configuracao no nivel da **conta** que permite ou bloqueia acesso anonimo. Mesmo com ela habilitada, cada container ainda precisa ter seu nivel de acesso configurado individualmente. E um "portao duplo" — ambos precisam estar abertos para acesso anonimo funcionar.

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

   > **Conceito:** Soft delete protege contra exclusao acidental — funciona como uma lixeira com prazo. O periodo padrao e 7 dias. Na prova, lembre: soft delete se aplica a blobs, containers e file shares **separadamente** — cada um tem sua propria configuracao de retencao.

   > **Dica AZ-104:** Questao classica: "Um blob foi deletado acidentalmente. Como recuperar?" — Soft delete (se habilitado) ou snapshots/versioning. Se soft delete nao estava habilitado, nao ha como recuperar.

---

## Modo Desafio - Bloco 1

- [ ] Criar Storage Account `stcontosoprod01` (LRS, East US) no rg-contoso-storage
- [ ] Criar container `data` (Private) e fazer upload de arquivo
- [ ] Gerar SAS token (Blob, Read+List, HTTPS only) e testar acesso via URL
- [ ] Criar Stored Access Policy `read-policy` no container
- [ ] Criar File Share `contoso-files` (Transaction optimized) e fazer upload
- [ ] Copiar script de conexao Windows para uso no Bloco 2
- [ ] Configurar Lifecycle Management: Cool (30d), Archive (90d)
- [ ] Configurar Immutability policy (7 dias) no container `data`
- [ ] **Integracao Semana 1:** Service Endpoint na snet-shared da vnet-contoso-hub
- [ ] Criar Service Endpoint Policy restringindo acesso apenas a Storage Account da Contoso
- [ ] Associar a policy na snet-shared
- [ ] **Integracao Semana 1:** Private Endpoint (blob) na snet-shared
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
**Uma subnet tem Service Endpoint habilitado para Microsoft.Storage. A equipe de seguranca reporta que VMs nessa subnet estao acessando Storage Accounts de outros departamentos nao autorizados. O que voce deve configurar para restringir o acesso apenas a Storage Account autorizada, sem remover o Service Endpoint?**

A) Network Security Group com regra de saida bloqueando IPs das outras Storage Accounts
B) Service Endpoint Policy associada a subnet, permitindo apenas a Storage Account autorizada
C) Firewall da Storage Account nao autorizada bloqueando a subnet
D) Azure Policy com efeito Deny para Storage Accounts fora do resource group

<details>
<summary>Ver resposta</summary>

**Resposta: B) Service Endpoint Policy associada a subnet, permitindo apenas a Storage Account autorizada**

Service Endpoint Policies filtram o destino do trafego de Service Endpoints. A policy e aplicada na subnet e restringe quais recursos PaaS especificos podem ser acessados. NSG filtra IP/porta (nao recurso PaaS). Firewall do storage filtra origem (nao resolve o problema na subnet). Azure Policy governa criacao de recursos, nao trafego de rede.

</details>

### Questao 1.3
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

### Questao 1.4
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

### Questao 1.5
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
