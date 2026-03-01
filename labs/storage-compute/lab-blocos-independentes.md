# Lab Unificado AZ-104 - Semana 2: Storage, VMs, Web Apps & Containers

> **Pre-requisitos:**
>
> - Assinatura ativa do Azure (Pay-As-You-Go, Visual Studio ou Student)
> - Navegador moderno (Edge, Chrome, Firefox)
> - Acesso ao [Portal Azure](https://portal.azure.com)
> - Conhecimento basico de navegacao no Portal (completar Semana 1)
> - Resource Groups da Semana 1 podem ser reutilizados ou recriados conforme necessario

**Regiao padrao:** East US (a menos que indicado de outra forma)

**Cenario Corporativo:** Voce e o administrador Azure de uma empresa em expansao. Apos configurar identidade, governanca e rede na Semana 1, agora precisa provisionar a infraestrutura de armazenamento e computacao. A empresa precisa de storage accounts para arquivos corporativos, maquinas virtuais para workloads legados, Web Apps para aplicacoes web modernas e containers para microsservicos. Nesta semana, voce vai configurar toda essa camada de storage e compute seguindo as melhores praticas de seguranca, disponibilidade e custo.

---

## Indice

- [Bloco 1 - Storage](#bloco-1---storage)
- [Bloco 2 - Virtual Machines](#bloco-2---virtual-machines)
- [Bloco 3 - Web Apps](#bloco-3---web-apps)
- [Bloco 4 - Azure Container Instances](#bloco-4---azure-container-instances)
- [Bloco 5 - Azure Container Apps](#bloco-5---azure-container-apps)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - Storage

**Origem:** Lab 07
**Resource Groups utilizados:** `az104-rg6`

## Contexto

O armazenamento e a base de qualquer infraestrutura cloud. Neste bloco, voce vai criar e configurar uma Storage Account completa, incluindo Blob containers para objetos, File Shares para compartilhamentos SMB, tokens SAS para acesso granular, lifecycle management para otimizacao de custos e seguranca de rede com Service Endpoints, Private Endpoints e Firewall.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                        az104-rg6                                    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Storage Account (LRS/GRS)                   │  │
│  │                                                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │
│  │  │ Blob Container│  │  File Share  │  │ Lifecycle Policy  │   │  │
│  │  │  (Hot/Cool/  │  │  (SMB 3.0)   │  │  (Hot→Cool→      │   │  │
│  │  │   Archive)   │  │              │  │   Archive→Delete) │   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └───────────────────┘   │  │
│  │         │                 │                                   │  │
│  │         ▼                 ▼                                   │  │
│  │  ┌──────────────┐  ┌──────────────┐                          │  │
│  │  │  SAS Token   │  │  SMB Mount   │                          │  │
│  │  │  (Account/   │  │  (Windows/   │                          │  │
│  │  │   Service)   │  │   Linux)     │                          │  │
│  │  └──────────────┘  └──────────────┘                          │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                  Network Security                       │  │  │
│  │  │  ┌───────────┐  ┌────────────────┐  ┌───────────────┐  │  │  │
│  │  │  │  Service   │  │    Private     │  │   Storage     │  │  │  │
│  │  │  │  Endpoint  │  │   Endpoint +   │  │   Firewall    │  │  │  │
│  │  │  │  (Subnet)  │  │  Private DNS   │  │  (IP/VNet)    │  │  │  │
│  │  │  └───────────┘  └────────────────┘  └───────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Task 1.1: Criar Storage Account

1. No Portal Azure, navegue ate **Storage accounts**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg6` (criar novo se necessario) |
   | Storage account name | `az104storage<seu-sufixo>` (nome unico global) |
   | Region | East US |
   | Performance | Standard |
   | Redundancy | Locally-redundant storage (LRS) |

4. Na aba **Advanced**, configure:
   - **Require secure transfer for REST API operations:** Enabled
   - **Allow enabling anonymous access on individual containers:** Disabled
   - **Enable storage account key access:** Enabled
   - **Default to Microsoft Entra authorization in the Azure portal:** Enabled
   - **Access tier:** Hot

5. Na aba **Networking**, configure:
   - **Network access:** Enable public access from all networks (vamos restringir depois)

6. Clique em **Review + Create** e depois **Create**
7. Aguarde o deploy completar e clique em **Go to resource**
8. No blade da Storage Account, observe as informacoes:
   - **Essentials:** nome, tipo, localizacao, redundancia
   - No menu lateral, explore **Settings > Configuration**
   - Note a opcao de alterar **Redundancy** de LRS para GRS

> **Conceito:** LRS replica dados 3 vezes dentro de um unico datacenter. GRS replica para uma regiao secundaria distante. ZRS replica entre 3 availability zones na mesma regiao. GZRS combina ZRS com replicacao geografica.

> **Dica AZ-104:** Na prova, saiba que mudar de LRS para GRS pode ser feito a qualquer momento, mas GRS para LRS requer uma solicitacao de suporte ou copia dos dados.

---

### Task 1.2: Criar Blob Container e Configurar Tiers

1. Na Storage Account criada, no menu lateral, clique em **Data storage > Containers**
2. Clique em **+ Container**
3. Configure:

   | Setting | Value |
   |---------|-------|
   | Name | `documentos` |
   | Anonymous access level | Private (no anonymous access) |

4. Clique em **Create**
5. Clique no container `documentos` para abri-lo
6. Clique em **Upload**
7. Selecione um arquivo de teste do seu computador (qualquer arquivo pequeno)
8. Expanda **Advanced** e configure:
   - **Access tier:** Hot
9. Clique em **Upload**
10. Repita o upload com outro arquivo, mas desta vez selecione **Access tier:** Cool
11. Apos o upload, clique no arquivo que esta em **Hot** tier
12. No blade do blob, observe as propriedades:
    - **Access tier:** Hot
    - **Blob type:** Block blob
13. Clique em **Change tier** e altere para **Archive**
14. Confirme a alteracao

> **Conceito:** Hot tier e para dados acessados frequentemente (maior custo de storage, menor custo de acesso). Cool tier e para dados acessados raramente (30+ dias). Archive e para dados de retencao de longo prazo (180+ dias). Cold tier e similar ao Cool mas para 90+ dias.

> **Dica AZ-104:** Rehydratar um blob de Archive pode levar ate 15 horas (Standard priority) ou ate 1 hora (High priority, custo maior). Enquanto esta em Archive, o blob nao pode ser lido diretamente.

---

### Task 1.3: Criar Azure File Share e Mapear via SMB

1. Na Storage Account, no menu lateral, clique em **Data storage > File shares**
2. Clique em **+ File share**
3. Configure:

   | Setting | Value |
   |---------|-------|
   | Name | `compartilhamento` |
   | Tier | Transaction optimized |

4. Clique em **Create**
5. Clique no file share `compartilhamento`
6. Clique em **+ Add directory** e crie um diretorio chamado `relatorios`
7. Entre no diretorio `relatorios` e faca upload de um arquivo de teste
8. Volte para a raiz do file share
9. Clique em **Connect** na barra superior
10. No painel que abre:
    - Selecione seu sistema operacional (Windows/Linux/macOS)
    - **Drive letter:** Z (Windows)
    - Copie o script de conexao exibido
11. Observe o script — ele contem:
    - O comando `net use` (Windows) ou `mount` (Linux)
    - A chave de acesso da Storage Account
    - O caminho UNC `\\<storage-account>.file.core.windows.net\compartilhamento`
12. No file share, clique em **Settings > Properties**
13. Anote a **URL** do file share para referencia

> **Conceito:** Azure Files oferece compartilhamentos de arquivos na nuvem via protocolo SMB (445) ou NFS (2049). Ideal para lift-and-shift de aplicacoes que dependem de file shares on-premises.

> **Dica AZ-104:** A porta 445 precisa estar aberta para conexoes SMB. Muitos ISPs residenciais bloqueiam essa porta. Em ambientes corporativos, use VPN ou ExpressRoute para acessar file shares via rede privada.

---

### Task 1.4: Gerar SAS Token e Testar Acesso

1. Na Storage Account, no menu lateral, clique em **Security + networking > Shared access signature**
2. Configure o **Account SAS**:

   | Setting | Value |
   |---------|-------|
   | Allowed services | Blob, File |
   | Allowed resource types | Container, Object |
   | Allowed permissions | Read, List |
   | Start date/time | Data/hora atual |
   | End date/time | +24 horas |
   | Allowed protocols | HTTPS only |
   | Signing key | key1 |

3. Clique em **Generate SAS and connection string**
4. Copie o **SAS token** (comeca com `?sv=`)
5. Copie a **Blob service SAS URL**
6. Abra uma nova aba do navegador e cole a **Blob service SAS URL**
7. Voce devera ver uma resposta XML listando os containers (pois deu permissao de List)
8. Agora vamos gerar um **Service SAS** para um blob especifico:
   - Navegue ate **Containers > documentos**
   - Clique no arquivo que voce fez upload
   - Clique nos tres pontos (**...**) e selecione **Generate SAS**
   - Configure:

     | Setting | Value |
     |---------|-------|
     | Signing method | Account key |
     | Signing key | key1 |
     | Permissions | Read |
     | Start | Data/hora atual |
     | Expiry | +1 hora |

   - Clique em **Generate SAS token and URL**
   - Copie a **Blob SAS URL**
9. Cole a URL em uma nova aba — o arquivo devera ser exibido/baixado
10. Aguarde o token expirar (ou altere a data para o passado) e tente novamente — acesso negado

> **Conceito:** SAS (Shared Access Signature) permite conceder acesso granular e temporario a recursos de storage sem expor as chaves da conta. Existem 3 tipos: Account SAS, Service SAS e User Delegation SAS (mais seguro, usa Microsoft Entra ID).

> **Dica AZ-104:** User Delegation SAS e o mais seguro pois usa credenciais do Entra ID em vez de chaves da conta. Se a chave da conta for regenerada, todos os SAS tokens baseados nela sao invalidados.

---

### Task 1.5: Configurar Lifecycle Management Policy

1. Na Storage Account, no menu lateral, clique em **Data management > Lifecycle management**
2. Clique em **+ Add a rule**
3. Na aba **Details**, configure:

   | Setting | Value |
   |---------|-------|
   | Rule name | `mover-para-cool` |
   | Rule scope | Apply rule to all blobs in your storage account |
   | Blob type | Block blobs |
   | Blob subtype | Base blobs |

4. Clique em **Next**
5. Na aba **Base blobs**, configure:
   - **If:** Base blobs were last modified more than **30** days ago
   - **Then:** Move to cool storage
6. Clique em **+ Add condition**
   - **If:** Base blobs were last modified more than **90** days ago
   - **Then:** Move to archive storage
7. Clique em **+ Add condition**
   - **If:** Base blobs were last modified more than **365** days ago
   - **Then:** Delete the blob
8. Clique em **Add**
9. Verifique a regra na lista de Lifecycle Management
10. Clique na regra criada para revisar o JSON gerado:
    - Observe a estrutura com `filters` e `actions`
    - Note os `daysAfterModificationGreaterThan` para cada acao

> **Conceito:** Lifecycle Management permite automatizar a transicao de blobs entre tiers e a exclusao de dados antigos. As regras sao avaliadas uma vez por dia e podem levar ate 24 horas para serem executadas pela primeira vez.

> **Dica AZ-104:** Lifecycle policies se aplicam apenas a Block blobs e Append blobs. Page blobs (usados por discos de VM) nao sao suportados. As regras podem filtrar por prefixo de nome ou por tag de blob.

---

### Task 1.6: Configurar Service Endpoint para Subnet

1. Primeiro, precisamos de uma VNet. Navegue ate **Virtual networks**
2. Clique em **+ Create** e configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg6` |
   | Name | `vnet-storage` |
   | Region | East US |
   | Address space | `10.60.0.0/16` |

3. Na aba **Subnets**, adicione uma subnet:

   | Setting | Value |
   |---------|-------|
   | Subnet name | `subnet-storage` |
   | Address range | `10.60.1.0/24` |
   | Service endpoints | Microsoft.Storage |

4. Clique em **Review + Create** e depois **Create**
5. Agora, volte para a Storage Account
6. No menu lateral, clique em **Security + networking > Networking**
7. Em **Firewalls and virtual networks**, selecione **Enabled from selected virtual networks and IP addresses**
8. Em **Virtual networks**, clique em **+ Add existing virtual network**
9. Selecione:
   - **Virtual networks:** `vnet-storage`
   - **Subnets:** `subnet-storage`
10. Clique em **Add**
11. Clique em **Save**
12. Aguarde a atualizacao completar

> **Conceito:** Service Endpoints estendem a identidade da VNet ate o servico Azure. O trafego do storage continua passando pelo backbone do Azure, mas agora o storage sabe que a requisicao vem de uma subnet especifica e pode restringir acesso.

> **Dica AZ-104:** Service Endpoints nao fornecem IP privado ao servico — o storage ainda usa seu IP publico. Para IP privado, use Private Endpoint. Service Endpoints sao gratuitos; Private Endpoints tem custo.

---

### Task 1.7: Configurar Private Endpoint e Private DNS Zone

1. Na Storage Account, no menu lateral, clique em **Security + networking > Networking**
2. Clique na aba **Private endpoint connections**
3. Clique em **+ Private endpoint**
4. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg6` |
   | Name | `pe-storage-blob` |
   | Network Interface Name | `pe-storage-blob-nic` |
   | Region | East US |

5. Clique em **Next: Resource**
6. Configure:

   | Setting | Value |
   |---------|-------|
   | Target sub-resource | blob |

7. Clique em **Next: Virtual Network**
8. Configure:

   | Setting | Value |
   |---------|-------|
   | Virtual network | `vnet-storage` |
   | Subnet | `subnet-storage` |
   | Private IP configuration | Dynamically allocate IP address |

9. Clique em **Next: DNS**
10. Configure:

    | Setting | Value |
    |---------|-------|
    | Integrate with private DNS zone | Yes |
    | Private DNS Zone | `privatelink.blob.core.windows.net` (criar nova) |

11. Clique em **Review + Create** e depois **Create**
12. Aguarde o deploy completar
13. Navegue ate **Private DNS zones** no Portal
14. Clique em `privatelink.blob.core.windows.net`
15. Observe o registro **A** criado automaticamente apontando para o IP privado da Storage Account
16. Volte para a Storage Account > **Networking > Private endpoint connections**
17. Verifique que o status do Private Endpoint e **Approved**

> **Conceito:** Private Endpoint atribui um IP privado da sua VNet ao servico Azure. Todo trafego para o storage passa pela rede privada, nunca pela internet publica. A Private DNS Zone resolve o FQDN do storage para o IP privado automaticamente.

> **Dica AZ-104:** Quando um Private Endpoint e criado, o DNS publico do storage (`*.blob.core.windows.net`) e redirecionado para `*.privatelink.blob.core.windows.net`, que resolve para o IP privado dentro da VNet.

---

### Task 1.8: Configurar Storage Firewall

1. Na Storage Account, no menu lateral, clique em **Security + networking > Networking**
2. Na aba **Firewalls and virtual networks**, verifique que esta em **Enabled from selected virtual networks and IP addresses**
3. Em **Firewall**, adicione seu IP publico:
   - Marque **Add your client IP address**
   - Ou digite manualmente um IP/CIDR em **Address range**
4. Em **Exceptions**, marque:
   - **Allow Azure services on the trusted services list to access this storage account**
5. Clique em **Save**
6. Abra uma nova janela **InPrivate/Incognito** do navegador
7. Tente acessar a Storage Account pelo Portal — voce devera conseguir (seu IP foi permitido)
8. Agora, remova seu IP da lista de firewall e salve
9. Tente acessar os blobs pela URL direta — acesso sera negado (403 Forbidden)
10. Recoloque seu IP e salve novamente para continuar trabalhando

> **Conceito:** O Storage Firewall permite restringir acesso por IP, VNet/Subnet e servicos confiados do Azure. Quando habilitado, todo trafego que nao corresponde a uma regra e bloqueado por padrao (deny by default).

> **Dica AZ-104:** Servicos confiados do Azure (como Azure Backup, Azure Monitor, Azure Event Grid) podem acessar o storage mesmo com firewall habilitado, desde que a excecao esteja marcada. Isso e diferente de Service Endpoints.

---

## Modo Desafio - Bloco 1

Tente realizar as tarefas abaixo **sem consultar as instrucoes acima**:

- [ ] Criar uma Storage Account com redundancia GRS e tier Cool
- [ ] Criar um Blob container e fazer upload de 3 arquivos com tiers diferentes (Hot, Cool, Archive)
- [ ] Criar um File Share com quota de 5 GiB e criar estrutura de diretorios
- [ ] Gerar um User Delegation SAS (requer atribuicao de role `Storage Blob Data Contributor`)
- [ ] Criar lifecycle policy que mova blobs com prefixo `logs/` para Archive apos 7 dias
- [ ] Configurar Service Endpoint em uma subnet existente
- [ ] Criar Private Endpoint para o sub-recurso `file` (nao blob)
- [ ] Configurar firewall para permitir apenas seu IP e uma subnet especifica

---

## Questoes de Prova - Bloco 1

**Questao 1:** Sua empresa precisa de storage com protecao contra falha de datacenter dentro da mesma regiao. Qual redundancia voce deve escolher?

<details><summary>Ver resposta</summary>

**Zone-redundant storage (ZRS).** ZRS replica dados sincronamente entre 3 availability zones dentro da mesma regiao, protegendo contra falha de um datacenter inteiro. LRS protege apenas dentro de um unico datacenter. GRS protege contra falha regional mas nao garante protecao por zona.

</details>

**Questao 2:** Voce criou um SAS token com permissao de Read e Write para um blob container. Um usuario reporta que consegue ler mas nao consegue escrever. Qual e a causa mais provavel?

<details><summary>Ver resposta</summary>

O SAS token pode estar correto, mas a **Storage Account pode ter uma access policy mais restritiva** (como firewall bloqueando o IP do usuario), ou o container pode ter uma **stored access policy** que sobrescreve as permissoes do SAS. Tambem e possivel que o **RBAC da Storage Account** esteja restringindo — se a conta usa Microsoft Entra authorization, o SAS baseado em chave pode conflitar com permissoes RBAC.

</details>

**Questao 3:** Voce configurou uma lifecycle policy para mover blobs para Archive apos 30 dias. Um blob foi movido para Archive, mas agora precisa ser acessado imediatamente. O que voce deve fazer?

<details><summary>Ver resposta</summary>

Voce deve **rehydratar o blob** alterando seu tier de Archive para Hot ou Cool. Para acesso mais rapido, use **High priority rehydration** (ate 1 hora, custo maior). Standard priority pode levar ate **15 horas**. Alternativamente, voce pode **copiar o blob** de Archive para outro blob em tier Hot/Cool (Copy Blob operation), que tambem inicia o processo de rehydration.

</details>

**Questao 4:** Qual a diferenca entre Service Endpoint e Private Endpoint para proteger acesso ao Storage?

<details><summary>Ver resposta</summary>

**Service Endpoint** mantem o IP publico do storage mas roteia o trafego pelo backbone do Azure e permite restringir acesso por subnet. E gratuito e mais simples. **Private Endpoint** atribui um IP privado da VNet ao storage, eliminando completamente a exposicao publica. Requer Private DNS Zone para resolucao de nomes. Private Endpoint tem custo por hora e por GB processado. Para compliance que exige zero exposicao publica, use Private Endpoint.

</details>

---

## Key Takeaways - Bloco 1

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Redundancia (LRS/ZRS/GRS/GZRS) | Escolher redundancia baseado em requisitos de disponibilidade e RPO |
| Access Tiers (Hot/Cool/Cold/Archive) | Selecionar tier baseado em frequencia de acesso e custo |
| SAS Tokens (Account/Service/User Delegation) | User Delegation SAS e o mais seguro; SAS baseado em chave e invalidado ao regenerar chave |
| Lifecycle Management | Automatiza transicao de tiers e exclusao; avaliado 1x por dia |
| Service Endpoint vs Private Endpoint | Service Endpoint = gratuito, IP publico; Private Endpoint = pago, IP privado |
| Storage Firewall | Deny by default quando habilitado; trusted services como excecao |

---

# Bloco 2 - Virtual Machines

**Origem:** Lab 08
**Resource Groups utilizados:** `az104-rg7`

## Contexto

Maquinas virtuais sao o servico IaaS mais fundamental do Azure. Neste bloco, voce vai criar VMs Windows e Linux, configurar alta disponibilidade com Availability Zones, gerenciar discos e extensoes, e criar VM Scale Sets para escalabilidade automatica. Essas habilidades sao essenciais para o exame AZ-104 e para o dia a dia de administracao Azure.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              az104-rg7                                   │
│                                                                          │
│  ┌──────────────────────┐    ┌──────────────────────┐                    │
│  │   Availability Zone 1│    │   Availability Zone 2│                    │
│  │  ┌────────────────┐  │    │  ┌────────────────┐  │                    │
│  │  │  VM Windows    │  │    │  │  VM Linux       │  │                    │
│  │  │  ┌──────────┐  │  │    │  │  ┌──────────┐  │  │                    │
│  │  │  │ OS Disk  │  │  │    │  │  │ OS Disk  │  │  │                    │
│  │  │  └──────────┘  │  │    │  │  └──────────┘  │  │                    │
│  │  │  ┌──────────┐  │  │    │  │  ┌──────────┐  │  │                    │
│  │  │  │Data Disk │  │  │    │  │  │Data Disk │  │  │                    │
│  │  │  └──────────┘  │  │    │  │  └──────────┘  │  │                    │
│  │  │  ┌──────────┐  │  │    │  │  ┌──────────┐  │  │                    │
│  │  │  │Extension │  │  │    │  │  │Cloud-init│  │  │                    │
│  │  │  │(Custom   │  │  │    │  │  │(startup) │  │  │                    │
│  │  │  │ Script)  │  │  │    │  │  │          │  │  │                    │
│  │  │  └──────────┘  │  │    │  │  └──────────┘  │  │                    │
│  │  └────────────────┘  │    │  └────────────────┘  │                    │
│  └──────────────────────┘    └──────────────────────┘                    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                  VM Scale Set (VMSS)                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │ Instance │  │ Instance │  │ Instance │  │ Instance │  ← Auto  │  │
│  │  │    0     │  │    1     │  │    2     │  │    N     │   Scale  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │  │
│  │                                                                    │  │
│  │  Autoscale Rules: CPU > 75% → Scale Out │ CPU < 25% → Scale In   │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Criar VM Windows

1. No Portal Azure, navegue ate **Virtual machines**
2. Clique em **+ Create > Azure virtual machine**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg7` (criar novo) |
   | Virtual machine name | `vm-win01` |
   | Region | East US |
   | Availability options | Availability zone |
   | Availability zone | Zone 1 |
   | Security type | Standard |
   | Image | Windows Server 2022 Datacenter: Azure Edition - x64 Gen2 |
   | Size | Standard_B2s (2 vcpus, 4 GiB memory) |
   | Username | `azureadmin` |
   | Password | Uma senha complexa (anote!) |
   | Public inbound ports | Allow selected ports |
   | Select inbound ports | RDP (3389) |

4. Na aba **Disks**, configure:

   | Setting | Value |
   |---------|-------|
   | OS disk type | Standard SSD (locally-redundant storage) |
   | Delete with VM | Marcado |

5. Na aba **Networking**, configure:

   | Setting | Value |
   |---------|-------|
   | Virtual network | Criar nova: `vnet-compute` (10.70.0.0/16) |
   | Subnet | `subnet-vms` (10.70.1.0/24) |
   | Public IP | Criar nova (SKU Standard) |
   | NIC network security group | Basic |
   | Public inbound ports | Allow selected ports |
   | Select inbound ports | RDP (3389) |
   | Delete public IP and NIC when VM is deleted | Marcado |

6. Na aba **Management**, configure:
   - **Auto-shutdown:** Enable
   - **Shutdown time:** 19:00
   - **Time zone:** (UTC-03:00) Brasilia

7. Clique em **Review + Create** e depois **Create**
8. Aguarde o deploy completar (3-5 minutos)
9. Clique em **Go to resource**
10. No blade da VM, observe:
    - **Status:** Running
    - **Public IP address:** anote o IP
    - **Size:** Standard_B2s
    - **OS:** Windows Server 2022

> **Conceito:** VMs do Azure sao maquinas virtuais IaaS que voce gerencia. Voce e responsavel por patches, atualizacoes de SO e configuracao. O Azure gerencia o hardware fisico, hypervisor e rede.

> **Dica AZ-104:** Sempre use Standard SSD ou Premium SSD para producao. Standard HDD e apenas para dev/test. Para o exame, saiba que o tipo de disco afeta o SLA da VM: Premium SSD oferece SLA de 99.9% para single VM.

---

### Task 2.2: Criar VM Linux com SSH Key e Cloud-init

1. No Portal Azure, navegue ate **Virtual machines**
2. Clique em **+ Create > Azure virtual machine**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg7` |
   | Virtual machine name | `vm-linux01` |
   | Region | East US |
   | Availability options | Availability zone |
   | Availability zone | Zone 2 |
   | Security type | Standard |
   | Image | Ubuntu Server 24.04 LTS - x64 Gen2 |
   | Size | Standard_B2s |
   | Authentication type | SSH public key |
   | Username | `azureadmin` |
   | SSH public key source | Generate new key pair |
   | Key pair name | `vm-linux01-key` |

4. Na aba **Disks**, configure:

   | Setting | Value |
   |---------|-------|
   | OS disk type | Standard SSD |

5. Na aba **Networking**, configure:

   | Setting | Value |
   |---------|-------|
   | Virtual network | `vnet-compute` (existente) |
   | Subnet | `subnet-vms` |
   | Public IP | Criar nova |
   | NIC network security group | Basic |
   | Select inbound ports | SSH (22) |

6. Na aba **Advanced**, na secao **Custom data**, cole o seguinte script cloud-init:
   ```yaml
   #cloud-config
   package_update: true
   packages:
     - nginx
   runcmd:
     - systemctl enable nginx
     - systemctl start nginx
     - echo "<h1>VM Linux - AZ-104 Lab</h1>" > /var/www/html/index.html
   ```

7. Clique em **Review + Create** e depois **Create**
8. **IMPORTANTE:** Quando solicitado, clique em **Download private key and create resource**
9. Salve o arquivo `.pem` em local seguro
10. Aguarde o deploy completar
11. No blade da VM Linux, anote o **Public IP address**

> **Conceito:** Cloud-init e o padrao da industria para customizacao de VMs Linux na primeira inicializacao. Permite instalar pacotes, executar comandos e configurar servicos automaticamente. O script e executado apenas uma vez, na criacao da VM.

> **Dica AZ-104:** Para o exame, saiba que SSH Key e mais seguro que senha para VMs Linux. O Azure armazena a chave publica na VM e voce mantem a chave privada. Use `chmod 400` no arquivo .pem para restringir permissoes.

---

### Task 2.3: Configurar Availability Zone

1. As VMs ja foram criadas em Availability Zones diferentes (Zone 1 e Zone 2)
2. No Portal, navegue ate **Virtual machines**
3. Clique em `vm-win01` e observe em **Essentials**:
   - **Availability zone:** 1
4. Volte e clique em `vm-linux01`:
   - **Availability zone:** 2
5. Navegue ate **Resource groups > az104-rg7**
6. Observe todos os recursos criados:
   - VMs, discos, NICs, public IPs, NSGs
   - Note que os public IPs sao **Zone-redundant** (SKU Standard)
7. Para verificar a distribuicao, navegue ate o **Resource Group > Overview**
8. Use o filtro de tipo para exibir apenas **Virtual machines**
9. Observe a coluna **Location** mostrando as zonas

> **Conceito:** Availability Zones sao datacenters fisicamente separados dentro de uma regiao Azure. Cada zona tem energia, refrigeracao e rede independentes. Distribuir VMs entre zonas oferece SLA de 99.99%.

> **Dica AZ-104:** Nem todas as regioes suportam Availability Zones. Para VMs em zonas diferentes, voce precisa de um Load Balancer Standard SKU para distribuir trafego. Basic SKU nao suporta zonas.

---

### Task 2.4: Redimensionar VM

1. No Portal, navegue ate **Virtual machines > vm-win01**
2. No menu lateral, clique em **Settings > Size**
3. Observe os tamanhos disponiveis:
   - Filtre por **Family:** B-series (burstable)
   - Note os tamanhos com diferentes quantidades de vCPUs e memoria
4. Selecione **Standard_B2ms** (2 vCPUs, 8 GiB memory — mais memoria que B2s)
5. Clique em **Resize**
6. **IMPORTANTE:** A VM sera reiniciada durante o redimensionamento
7. Aguarde a operacao completar (1-3 minutos)
8. Verifique o novo tamanho na pagina **Overview** da VM
9. Agora, tente selecionar um tamanho de familia diferente (ex: **Standard_D2s_v5**)
10. Se disponivel na mesma zona, o resize sera possivel
11. Volte para **Standard_B2s** para economizar custos

> **Conceito:** O redimensionamento de VM requer reinicializacao. Nem todos os tamanhos estao disponiveis em todas as zonas/regioes. Se o tamanho desejado nao estiver disponivel, pode ser necessario desalocar a VM primeiro ou mover para outra zona.

> **Dica AZ-104:** Para o exame, saiba diferenciar as familias de VM: B-series (burstable, dev/test), D-series (general purpose), E-series (memory optimized), F-series (compute optimized), N-series (GPU). O resize mantem os discos e dados.

---

### Task 2.5: Adicionar Data Disk

1. No Portal, navegue ate **Virtual machines > vm-win01**
2. No menu lateral, clique em **Settings > Disks**
3. Em **Data disks**, clique em **+ Create and attach a new disk**
4. Configure:

   | Setting | Value |
   |---------|-------|
   | Name | `vm-win01-data-disk01` |
   | Storage type | Standard SSD |
   | Size (GiB) | 32 |

5. Clique em **Apply** (ou **Save** na parte superior)
6. Aguarde o disco ser attached
7. Agora, conecte-se a VM via RDP:
   - No blade da VM, clique em **Connect > RDP**
   - Clique em **Download RDP file**
   - Abra o arquivo RDP e conecte com as credenciais (`azureadmin` / sua senha)
8. Dentro da VM Windows, abra o **Server Manager**
9. Clique em **File and Storage Services > Disks**
10. Localize o novo disco (32 GiB, status Offline)
11. Clique com botao direito no disco e selecione **Bring Online**
12. Clique com botao direito novamente e selecione **Initialize** (GPT)
13. Clique com botao direito no espaco nao alocado e selecione **New Volume**
14. No assistente:
    - **Drive letter:** F
    - **File system:** NTFS
    - **Volume label:** `DataDisk`
15. Conclua o assistente — o disco agora esta disponivel como F:\

> **Conceito:** Data disks sao discos adicionais que voce pode attachar a VMs. O OS disk contem o sistema operacional; data disks sao para dados de aplicacao. Managed Disks simplificam o gerenciamento — o Azure cuida da storage account subjacente.

> **Dica AZ-104:** O numero maximo de data disks depende do tamanho da VM. B2s suporta ate 4 data disks. Para o exame, saiba que Premium SSD v2 oferece IOPS e throughput configuraveis independentemente do tamanho do disco.

---

### Task 2.6: Instalar Custom Script Extension

1. No Portal, navegue ate **Virtual machines > vm-win01**
2. No menu lateral, clique em **Settings > Extensions + applications**
3. Clique em **+ Add**
4. Na lista de extensoes, selecione **Custom Script Extension** e clique em **Next**
5. Configure:
   - **Script file (Required):** Voce pode fazer upload de um script ou apontar para um blob
   - Para este lab, vamos usar o campo de comando direto
6. Alternativamente, use a abordagem via **Run command**:
   - No menu lateral da VM, clique em **Operations > Run command**
   - Selecione **RunPowerShellScript**
   - No campo de script, digite:
     ```powershell
     Install-WindowsFeature -Name Web-Server -IncludeManagementTools
     Set-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value "Hello from vm-win01 - AZ-104 Lab"
     ```
   - Clique em **Run**
7. Aguarde a execucao completar (2-5 minutos)
8. Verifique a saida indicando sucesso
9. No navegador, acesse `http://<IP-publico-da-VM>`
10. Voce devera ver a mensagem "Hello from vm-win01 - AZ-104 Lab"

> **Conceito:** Extensions sao pequenas aplicacoes que fornecem configuracao pos-deploy e automacao em VMs Azure. Custom Script Extension executa scripts na VM. Outras extensoes comuns: Azure Monitor Agent, Microsoft Antimalware, DSC Extension.

> **Dica AZ-104:** Run Command e uma forma rapida de executar scripts sem precisar de RDP/SSH. O Custom Script Extension e baixado e executado uma vez; se voce precisar executar novamente, precisa remover e reinstalar a extensao.

---

### Task 2.7: Criar VM Scale Set com Autoscale

1. No Portal Azure, pesquise **Virtual machine scale sets**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg7` |
   | Virtual machine scale set name | `vmss-web` |
   | Region | East US |
   | Availability zone | Zones 1, 2, 3 |
   | Orchestration mode | Uniform |
   | Security type | Standard |
   | Image | Ubuntu Server 24.04 LTS - x64 Gen2 |
   | Size | Standard_B2s |
   | Authentication type | Password |
   | Username | `azureadmin` |
   | Password | Sua senha complexa |

4. Na aba **Disks**, mantenha o padrao (Standard SSD)
5. Na aba **Networking**, configure:
   - **Virtual network:** `vnet-compute`
   - Clique em **Edit network interface** e habilite **Public IP address**
   - Em **Load balancing**, selecione **Azure load balancer**
   - Clique em **Create a load balancer**:

     | Setting | Value |
     |---------|-------|
     | Load balancer name | `lb-vmss` |
     | Type | Public |
     | Protocol | TCP |
     | Frontend port / Backend port | 80 / 80 |

   - Clique em **Create**

6. Na aba **Scaling**, configure:

   | Setting | Value |
   |---------|-------|
   | Initial instance count | 2 |
   | Scaling policy | Custom |
   | Minimum number of instances | 1 |
   | Maximum number of instances | 5 |
   | Scale out - CPU threshold (%) | 75 |
   | Scale out - Number of instances to increase by | 1 |
   | Scale in - CPU threshold (%) | 25 |
   | Scale in - Number of instances to decrease by | 1 |

7. Na aba **Advanced**, em **Custom data**, cole:
   ```yaml
   #cloud-config
   package_update: true
   packages:
     - nginx
     - stress
   runcmd:
     - systemctl enable nginx
     - systemctl start nginx
     - echo "<h1>VMSS Instance - $(hostname)</h1>" > /var/www/html/index.html
   ```

8. Clique em **Review + Create** e depois **Create**
9. Aguarde o deploy completar (5-10 minutos)
10. Navegue ate o VMSS criado
11. No menu lateral, clique em **Instances** e observe as 2 instancias em execucao
12. Anote o IP publico do Load Balancer (visivel na pagina Overview do VMSS ou no recurso do LB)
13. Acesse `http://<IP-do-LB>` — voce vera a pagina do nginx com o hostname da instancia

> **Conceito:** VM Scale Sets permitem criar e gerenciar um grupo de VMs identicas com load balancing. O autoscale ajusta automaticamente o numero de instancias baseado em metricas como CPU, memoria ou metricas customizadas.

> **Dica AZ-104:** Para o exame, saiba que VMSS pode usar Uniform (instancias identicas) ou Flexible (instancias heterogeneas) orchestration mode. Uniform e o modo classico; Flexible e o recomendado para novos workloads. Scale policies podem ser baseadas em metricas, schedule ou ambos.

---

## Modo Desafio - Bloco 2

Tente realizar as tarefas abaixo **sem consultar as instrucoes acima**:

- [ ] Criar uma VM Windows em Availability Zone 3 com Premium SSD
- [ ] Criar uma VM Linux com SSH key e cloud-init que instale Docker
- [ ] Redimensionar uma VM para D2s_v5 e verificar o impacto
- [ ] Attachar 2 data disks a uma VM e configurar RAID 0 (Linux: mdadm)
- [ ] Instalar a extensao Azure Monitor Agent via Portal
- [ ] Criar VMSS com scaling baseado em schedule (horario comercial: 3 instancias; fora: 1)
- [ ] Configurar Rolling Upgrade policy no VMSS

---

## Questoes de Prova - Bloco 2

**Questao 1:** Uma empresa precisa garantir 99.99% de SLA para uma aplicacao rodando em VMs Azure. Qual configuracao atende esse requisito?

<details><summary>Ver resposta</summary>

**Distribuir VMs entre 2 ou mais Availability Zones** com um Load Balancer Standard SKU. Isso oferece SLA de 99.99%. Um Availability Set oferece apenas 99.95%. Uma unica VM com Premium SSD oferece 99.9%. Para o maior SLA, as VMs devem estar em zonas diferentes dentro da mesma regiao.

</details>

**Questao 2:** Voce precisa redimensionar uma VM de Standard_B2s para Standard_E4s_v5, mas o tamanho nao esta disponivel. O que voce deve fazer?

<details><summary>Ver resposta</summary>

Primeiro, **desalocar a VM** (Stop/Deallocate). Isso libera o hardware fisico e pode disponibilizar novos tamanhos. Se ainda nao estiver disponivel, pode ser necessario **mover a VM para outra zona** na mesma regiao ou **recriar a VM** em uma zona/regiao diferente. Desalocar e diferente de apenas parar — parar mantem a alocacao de hardware.

</details>

**Questao 3:** Qual a diferenca entre Uniform e Flexible orchestration mode em VM Scale Sets?

<details><summary>Ver resposta</summary>

**Uniform mode** usa um modelo de VM identico para todas as instancias — todas sao criadas com a mesma imagem, tamanho e configuracao. E ideal para workloads homogeneos. **Flexible mode** permite adicionar VMs com configuracoes diferentes ao mesmo scale set, suporta mixing de imagens e tamanhos, e permite adicionar VMs existentes. Flexible e o modo recomendado para novos deployments e suporta Availability Zones nativamente.

</details>

**Questao 4:** Voce instalou Custom Script Extension em uma VM, mas precisa executar um script diferente. A extensao falha ao ser atualizada. O que voce deve fazer?

<details><summary>Ver resposta</summary>

**Remova a Custom Script Extension existente** e reinstale com o novo script. A Custom Script Extension nao suporta atualizacao in-place de scripts em todos os cenarios. A abordagem mais confiavel e remover a extensao, aguardar a remocao completar e adicionar novamente com o novo script. Alternativamente, use **Run Command** que e independente de extensoes e pode ser executado multiplas vezes.

</details>

---

## Key Takeaways - Bloco 2

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Availability Zones | Distribuir VMs em 2+ zonas = SLA 99.99%; requer LB Standard |
| VM Sizing | B-series = burstable; D = general purpose; E = memory; F = compute; N = GPU |
| Managed Disks | Premium SSD para producao; tipo do disco afeta SLA de single VM |
| Extensions | Custom Script Extension para automacao pos-deploy; Run Command para execucao rapida |
| VMSS Autoscale | Scale out/in baseado em CPU, memoria, metricas customizadas ou schedule |
| Cloud-init | Padrao para customizacao de Linux no primeiro boot; executado uma unica vez |

---

# Bloco 3 - Web Apps

**Origem:** Lab 09a
**Resource Groups utilizados:** `az104-rg8`

## Contexto

O Azure App Service e a plataforma PaaS para hospedar aplicacoes web, APIs REST e backends moveis. Neste bloco, voce vai criar um App Service Plan, fazer deploy de uma Web App, configurar deployment slots para deploy sem downtime e configurar autoscale. O App Service abstrai a infraestrutura — voce nao gerencia VMs, patches ou load balancers.

## Diagrama

```
┌────────────────────────────────────────────────────────────────┐
│                          az104-rg8                             │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              App Service Plan (Standard S1)              │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │              Web App (Production)                 │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌───────────────┐  ┌──────────────────────┐     │    │  │
│  │  │  │   App Settings│  │  Connection Strings  │     │    │  │
│  │  │  └───────────────┘  └──────────────────────┘     │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                         │                                │  │
│  │                    Slot Swap                              │  │
│  │                         │                                │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │           Deployment Slot (Staging)              │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌───────────────┐  ┌──────────────────────┐     │    │  │
│  │  │  │   App Settings│  │  Connection Strings  │     │    │  │
│  │  │  │  (slot-sticky)│  │    (slot-sticky)     │     │    │  │
│  │  │  └───────────────┘  └──────────────────────┘     │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │              Autoscale Rules                      │    │  │
│  │  │  CPU > 70% → Scale Out (max 3 instances)         │    │  │
│  │  │  CPU < 30% → Scale In (min 1 instance)           │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

### Task 3.1: Criar App Service Plan

1. No Portal Azure, pesquise **App Service plans**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg8` (criar novo) |
   | Name | `asp-lab09` |
   | Operating System | Linux |
   | Region | East US |
   | Pricing plan | Standard S1 |

4. Clique em **Review + Create** e depois **Create**
5. Aguarde o deploy completar
6. Navegue ate o App Service Plan criado
7. Observe as informacoes na pagina Overview:
   - **Pricing tier:** Standard S1
   - **Number of apps:** 0
   - **App Service Plan status:** Ready
8. No menu lateral, clique em **Settings > Scale up (App Service plan)**
9. Observe os tiers disponiveis:
   - **Free (F1):** Sem slots, sem autoscale, sem custom domain SSL
   - **Basic (B1):** Sem slots, sem autoscale
   - **Standard (S1):** 5 slots, autoscale, custom domain SSL
   - **Premium (P1v3):** 20 slots, autoscale, staging environments
10. Mantenha em Standard S1

> **Conceito:** O App Service Plan define os recursos de computacao (CPU, memoria, instancias) que suas Web Apps compartilham. Multiplas apps podem rodar no mesmo plan. O tier determina quais features estao disponiveis.

> **Dica AZ-104:** Para o exame, memorize: Free/Shared = sem SLA, sem slots, sem autoscale. Basic = SLA, sem slots, sem autoscale. Standard = SLA, 5 slots, autoscale. Premium = SLA, 20 slots, autoscale, VNet integration nativa.

---

### Task 3.2: Criar Web App e Fazer Deploy

1. No Portal Azure, pesquise **App Services**
2. Clique em **+ Create > Web App**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg8` |
   | Name | `webapp-lab09-<seu-sufixo>` (nome unico global) |
   | Publish | Code |
   | Runtime stack | PHP 8.2 |
   | Operating System | Linux |
   | Region | East US |
   | App Service Plan | `asp-lab09` (existente) |

4. Clique em **Review + Create** e depois **Create**
5. Aguarde o deploy completar e clique em **Go to resource**
6. Na pagina Overview, clique na **Default domain** (URL da web app)
7. Voce vera a pagina padrao do Azure App Service
8. Agora, vamos fazer deploy de codigo simples:
   - No menu lateral, clique em **Development Tools > Advanced Tools (Kudu)**
   - Clique em **Go →**
   - No Kudu, clique em **SSH** no menu superior
   - No terminal SSH, execute:
     ```bash
     cd /home/site/wwwroot
     echo '<?php echo "<h1>Web App AZ-104 Lab</h1><p>Hostname: " . gethostname() . "</p>"; ?>' > index.php
     ```
9. Volte ao navegador e acesse a URL da web app novamente
10. Voce devera ver "Web App AZ-104 Lab" com o hostname

> **Conceito:** Azure App Service suporta multiplas linguagens: .NET, Java, Node.js, Python, PHP, Ruby. O deploy pode ser feito via Git, GitHub Actions, Azure DevOps, FTP, ZIP deploy ou Kudu. Cada web app tem uma URL padrao `<nome>.azurewebsites.net`.

> **Dica AZ-104:** O nome da web app deve ser globalmente unico no dominio `azurewebsites.net`. Para o exame, saiba que Always On deve ser habilitado para apps que precisam estar sempre quentes (disponivel a partir do tier Basic).

---

### Task 3.3: Configurar Deployment Slots

1. Na Web App, no menu lateral, clique em **Deployment > Deployment slots**
2. Clique em **+ Add Slot**
3. Configure:

   | Setting | Value |
   |---------|-------|
   | Name | `staging` |
   | Clone settings from | `webapp-lab09-<seu-sufixo>` (production) |

4. Clique em **Add**
5. Clique no slot `staging` na lista para abri-lo
6. Observe que o slot staging tem sua propria URL: `webapp-lab09-<sufixo>-staging.azurewebsites.net`
7. No slot staging, va para **Development Tools > Advanced Tools (Kudu) > SSH**
8. No terminal, execute:
   ```bash
   cd /home/site/wwwroot
   echo '<?php echo "<h1>STAGING - Nova Versao v2.0</h1><p>Hostname: " . gethostname() . "</p>"; ?>' > index.php
   ```
9. Acesse a URL do slot staging e verifique que mostra "STAGING - Nova Versao v2.0"
10. Acesse a URL de producao e verifique que ainda mostra a versao original

> **Conceito:** Deployment slots sao ambientes de producao live com seus proprios hostnames. Eles permitem deploy e teste de novas versoes sem afetar producao. Quando pronto, voce faz swap entre slots — a troca e instantanea e sem downtime.

> **Dica AZ-104:** Slots compartilham o mesmo App Service Plan (mesmos recursos de computacao). O numero de slots depende do tier: Standard = 5, Premium = 20. Algumas configuracoes sao "slot-sticky" (ficam no slot) e outras sao swapped com o codigo.

---

### Task 3.4: Executar Slot Swap

1. Na Web App (producao), no menu lateral, clique em **Deployment > Deployment slots**
2. Clique em **Swap** na barra superior
3. No painel de swap, configure:

   | Setting | Value |
   |---------|-------|
   | Swap type | Swap |
   | Source | staging |
   | Target | production |

4. Revise as **Config Changes** — mostra quais configuracoes serao trocadas
5. Clique em **Swap**
6. Aguarde o swap completar (normalmente 10-30 segundos)
7. Acesse a URL de producao — agora mostra "STAGING - Nova Versao v2.0"
8. Acesse a URL do slot staging — agora mostra a versao anterior
9. Se precisar fazer rollback, basta executar o swap novamente

> **Conceito:** O swap troca o conteudo e a maioria das configuracoes entre dois slots. E atomico e sem downtime porque o Azure aquece (warms up) o slot de destino antes de trocar o trafego. Isso elimina cold starts.

> **Dica AZ-104:** Settings marcados como "Deployment slot setting" (slot-sticky) NAO sao trocados durante o swap. Exemplos: connection strings de banco de dados de teste devem ser slot-sticky no slot staging para nao irem para producao.

---

### Task 3.5: Configurar Autoscale no App Service Plan

1. Navegue ate o **App Service Plan `asp-lab09`**
2. No menu lateral, clique em **Settings > Scale out (App Service plan)**
3. Selecione **Rules Based** (se disponivel) ou **Custom autoscale**
4. Clique em **+ Add a rule** e configure a regra de Scale Out:

   | Setting | Value |
   |---------|-------|
   | Metric source | Current resource |
   | Metric name | CPU Percentage |
   | Time grain statistic | Average |
   | Operator | Greater than |
   | Threshold | 70 |
   | Duration (minutes) | 5 |
   | Operation | Increase count by |
   | Instance count | 1 |
   | Cool down (minutes) | 5 |

5. Clique em **Add**
6. Clique em **+ Add a rule** para Scale In:

   | Setting | Value |
   |---------|-------|
   | Metric name | CPU Percentage |
   | Operator | Less than |
   | Threshold | 30 |
   | Duration (minutes) | 5 |
   | Operation | Decrease count by |
   | Instance count | 1 |
   | Cool down (minutes) | 5 |

7. Configure os limites de instancias:

   | Setting | Value |
   |---------|-------|
   | Minimum | 1 |
   | Maximum | 3 |
   | Default | 1 |

8. Clique em **Save**
9. Verifique as regras configuradas na pagina de Scale out

> **Conceito:** Autoscale no App Service ajusta automaticamente o numero de instancias do plan. Todas as apps no mesmo plan compartilham as instancias. Regras podem ser baseadas em metricas (CPU, memoria, HTTP queue) ou schedule (horarios especificos).

> **Dica AZ-104:** Sempre configure regras de Scale In junto com Scale Out para evitar custos desnecessarios. O cool down period evita oscilacoes rapidas (flapping). Para o exame, saiba que autoscale nao esta disponivel em Free, Shared e Basic tiers.

---

### Task 3.6: Configurar Application Settings e Connection Strings

1. Na Web App (producao), no menu lateral, clique em **Settings > Environment variables**
2. Na aba **App settings**, clique em **+ Add**
3. Adicione as seguintes configuracoes:

   | Name | Value | Deployment slot setting |
   |------|-------|------------------------|
   | `APP_ENVIRONMENT` | `production` | Marcado (slot-sticky) |
   | `APP_VERSION` | `2.0` | Desmarcado |
   | `LOG_LEVEL` | `warning` | Desmarcado |

4. Para cada setting, clique em **Add** (ou **Apply**)
5. Agora, clique na aba **Connection strings**
6. Clique em **+ Add** e configure:

   | Name | Value | Type | Deployment slot setting |
   |------|-------|------|------------------------|
   | `DatabaseConnection` | `Server=prodserver;Database=proddb;` | SQLAzure | Marcado (slot-sticky) |

7. Clique em **Apply** e confirme
8. Agora, vamos verificar no slot staging:
   - Navegue ate o slot `staging`
   - Va para **Settings > Environment variables**
   - Observe que `APP_ENVIRONMENT` mostra o valor do staging (nao production)
   - `APP_VERSION` e `LOG_LEVEL` foram herdados do clone mas serao swapped
9. Adicione no staging:

   | Name | Value | Deployment slot setting |
   |------|-------|------------------------|
   | `APP_ENVIRONMENT` | `staging` | Marcado |

10. Adicione connection string no staging:

    | Name | Value | Type | Deployment slot setting |
    |------|-------|------|------------------------|
    | `DatabaseConnection` | `Server=testserver;Database=testdb;` | SQLAzure | Marcado |

> **Conceito:** App Settings sao variaveis de ambiente injetadas na aplicacao. Connection Strings sao especificamente para conexoes de banco de dados. Quando marcados como "Deployment slot setting", ficam fixos no slot e nao sao trocados durante swap.

> **Dica AZ-104:** Para o exame, entenda que marcar como "Deployment slot setting" e essencial para separar configuracoes de producao e staging. Sem isso, connection strings de teste iriam para producao durante um swap, causando problemas.

---

## Modo Desafio - Bloco 3

Tente realizar as tarefas abaixo **sem consultar as instrucoes acima**:

- [ ] Criar um App Service Plan com tier Premium P1v3 e OS Windows
- [ ] Criar uma Web App com runtime .NET 8 e fazer deploy via ZIP deploy
- [ ] Criar 3 deployment slots: staging, testing, canary
- [ ] Configurar traffic routing: 90% producao, 10% canary
- [ ] Configurar autoscale baseado em HTTP Queue Length
- [ ] Marcar connection strings como slot-sticky e verificar comportamento apos swap
- [ ] Configurar Always On e ARR Affinity nas configuracoes gerais

---

## Questoes de Prova - Bloco 3

**Questao 1:** Qual tier minimo do App Service Plan suporta deployment slots?

<details><summary>Ver resposta</summary>

**Standard (S1).** Os tiers Free, Shared e Basic NAO suportam deployment slots. Standard suporta ate 5 slots, e Premium suporta ate 20 slots. Deployment slots sao essenciais para deploy sem downtime.

</details>

**Questao 2:** Voce fez swap de staging para producao e a aplicacao esta com problemas. Qual a forma mais rapida de fazer rollback?

<details><summary>Ver resposta</summary>

**Execute o swap novamente** entre os mesmos slots. O slot staging agora contem a versao anterior de producao (que foi trocada durante o swap). Fazer swap novamente restaura o estado original. Isso e uma das grandes vantagens do modelo de slots — rollback instantaneo.

</details>

**Questao 3:** Uma connection string marcada como "Deployment slot setting" no slot staging aponta para o banco de testes. Apos o swap para producao, para onde essa connection string aponta?

<details><summary>Ver resposta</summary>

**Continua apontando para o banco de testes, mas apenas no slot staging.** Settings marcados como "Deployment slot setting" (slot-sticky) NAO sao trocados durante o swap. A connection string do staging fica no staging, e a do production fica no production. Isso garante que o codigo swapped para producao use automaticamente a connection string de producao.

</details>

---

## Key Takeaways - Bloco 3

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| App Service Plan Tiers | Free/Shared = sem SLA; Basic = sem slots/autoscale; Standard+ = slots + autoscale |
| Deployment Slots | Permitem deploy sem downtime; swap e atomico; rollback = swap novamente |
| Slot-sticky Settings | Nao sao trocados durante swap; ideal para connection strings por ambiente |
| Autoscale | Disponivel a partir do Standard; regras baseadas em metricas ou schedule |
| Always On | Mantem a app quente; disponivel a partir do Basic; essencial para producao |

---

# Bloco 4 - Azure Container Instances

**Origem:** Lab 09b
**Resource Groups utilizados:** `az104-rg9`

## Contexto

Azure Container Instances (ACI) e a forma mais rapida e simples de rodar containers no Azure. Nao requer gerenciamento de VMs ou orquestradores. E ideal para cenarios simples como batch jobs, build agents, testes e aplicacoes stateless de curta duracao. Neste bloco, voce vai criar containers, configurar variaveis de ambiente, montar Azure File Shares e gerenciar politicas de restart.

## Diagrama

```
┌────────────────────────────────────────────────────────────────┐
│                          az104-rg9                             │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Container Instance (nginx)                    │  │
│  │                                                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │   Container  │  │   Env Vars   │  │  Resource    │   │  │
│  │  │   (nginx:    │  │  APP_ENV=    │  │  Limits:     │   │  │
│  │  │    latest)   │  │  production  │  │  CPU: 1      │   │  │
│  │  │   Port: 80   │  │              │  │  Memory: 1.5 │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │       Container Instance (com File Share)                │  │
│  │                                                          │  │
│  │  ┌──────────────┐         ┌─────────────────────────┐   │  │
│  │  │   Container  │────────→│   Azure File Share      │   │  │
│  │  │   (custom)   │  mount  │   /mnt/data             │   │  │
│  │  │              │         │   (Storage Account)     │   │  │
│  │  └──────────────┘         └─────────────────────────┘   │  │
│  │                                                          │  │
│  │  Restart Policy: OnFailure │ Logs: Container Logs       │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar ACI com Imagem Publica

1. No Portal Azure, pesquise **Container instances**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg9` (criar novo) |
   | Container name | `aci-nginx-01` |
   | Region | East US |
   | Availability zones | None |
   | SKU | Standard |
   | Image source | Other registry |
   | Image type | Public |
   | Image | `mcr.microsoft.com/oss/nginx/nginx:latest` |
   | OS type | Linux |
   | Size | 1 vCPU, 1.5 GiB memory (padrao) |

4. Clique em **Next: Networking**
5. Configure:

   | Setting | Value |
   |---------|-------|
   | Networking type | Public |
   | DNS name label | `aci-nginx-<seu-sufixo>` |
   | DNS name label scope reuse | Tenant |
   | Ports | 80 (TCP) |

6. Clique em **Next: Advanced**
7. Mantenha os padroes (Restart policy: On failure)
8. Clique em **Review + Create** e depois **Create**
9. Aguarde o deploy completar (1-2 minutos)
10. Clique em **Go to resource**
11. Na pagina Overview, observe:
    - **Status:** Running
    - **IP address (Public):** anote
    - **FQDN:** `aci-nginx-<sufixo>.eastus.azurecontainer.io`
12. Acesse o FQDN no navegador — voce vera a pagina padrao do nginx

> **Conceito:** ACI executa containers sem gerenciar infraestrutura. E serverless para containers — voce paga pelo tempo de execucao (por segundo) baseado em CPU e memoria alocadas. Ideal para workloads simples e de curta duracao.

> **Dica AZ-104:** ACI suporta containers Linux e Windows, mas nao no mesmo container group. Cada container group tem um IP publico ou privado (quando em VNet). Para o exame, saiba que ACI e diferente de AKS — ACI e para containers individuais simples, AKS e para orquestracao complexa.

---

### Task 4.2: Configurar Environment Variables e Resource Limits

1. Como ACI nao permite editar variaveis apos criacao, vamos criar uma nova instancia
2. Navegue ate **Container instances** e clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg9` |
   | Container name | `aci-custom-01` |
   | Region | East US |
   | Image source | Other registry |
   | Image type | Public |
   | Image | `mcr.microsoft.com/azuredocs/aci-helloworld:latest` |
   | OS type | Linux |
   | Size | Clique em **Change size** |

4. No painel de tamanho, configure:

   | Setting | Value |
   |---------|-------|
   | CPU cores | 0.5 |
   | Memory (GiB) | 0.5 |

5. Clique em **OK**
6. Clique em **Next: Networking**
7. Configure:

   | Setting | Value |
   |---------|-------|
   | Networking type | Public |
   | DNS name label | `aci-custom-<seu-sufixo>` |
   | Ports | 80 (TCP) |

8. Clique em **Next: Advanced**
9. Em **Environment variables**, clique em **+ Add** e configure:

   | Name | Type | Value |
   |------|------|-------|
   | `APP_ENVIRONMENT` | Not secure | `production` |
   | `APP_VERSION` | Not secure | `1.0.0` |
   | `DB_PASSWORD` | Secure | `MinhaSenh@Secreta123` |

10. Clique em **Review + Create** e depois **Create**
11. Aguarde o deploy completar
12. Navegue ate o container instance criado
13. No menu lateral, clique em **Settings > Containers**
14. Observe:
    - **Environment variables** listadas (variaveis secure nao exibem o valor)
    - **Resource requests:** CPU 0.5, Memory 0.5 GiB
15. Acesse o FQDN — a app aci-helloworld exibira informacoes do container

> **Conceito:** Variaveis de ambiente permitem configurar containers sem alterar a imagem. Variaveis marcadas como "Secure" sao criptografadas e nao aparecem na UI do Portal nem em logs. Resource limits definem CPU e memoria maximos para o container.

> **Dica AZ-104:** ACI suporta ate 4 CPU cores e 16 GiB de memoria por container group (limites podem variar por regiao). Variaveis secure sao o equivalente a Kubernetes secrets no ACI. Para o exame, saiba que resource requests definem o que e alocado; resource limits definem o maximo.

---

### Task 4.3: Criar ACI com Azure File Share Mount

1. Primeiro, certifique-se de ter uma Storage Account com File Share:
   - Se voce fez o Bloco 1, use a Storage Account do `az104-rg6`
   - Caso contrario, crie uma Storage Account rapida em `az104-rg9`:
     - Navegue ate **Storage accounts > + Create**
     - Nome: `acistorage<sufixo>`, RG: `az104-rg9`, Region: East US
     - Crie um file share chamado `aci-data`
2. Anote o **nome da Storage Account** e a **chave de acesso** (Settings > Access keys)
3. Navegue ate **Container instances** e clique em **+ Create**
4. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg9` |
   | Container name | `aci-fileshare-01` |
   | Image | `mcr.microsoft.com/azuredocs/aci-hellofiles:latest` |
   | OS type | Linux |
   | Size | 1 vCPU, 1.5 GiB memory |

5. Clique em **Next: Networking**
6. Configure:

   | Setting | Value |
   |---------|-------|
   | Networking type | Public |
   | DNS name label | `aci-files-<sufixo>` |
   | Ports | 80 (TCP) |

7. Clique em **Next: Advanced**
8. Em **Volumes**, clique em **+ Add** e configure:

   | Setting | Value |
   |---------|-------|
   | Name | `data-volume` |
   | Volume type | Azure file share |
   | Storage account name | `<sua-storage-account>` |
   | Storage account key | `<sua-chave-de-acesso>` |
   | File share name | `aci-data` (ou `compartilhamento` do Bloco 1) |
   | Mount path | `/mnt/data` |
   | Read only | Desmarcado |

9. Clique em **Review + Create** e depois **Create**
10. Aguarde o deploy completar
11. Navegue ate o container e va para **Containers**
12. Clique em **Connect** e selecione `/bin/sh`
13. No terminal do container, execute:
    ```bash
    ls /mnt/data
    echo "Arquivo criado pelo ACI" > /mnt/data/teste-aci.txt
    cat /mnt/data/teste-aci.txt
    ```
14. Navegue ate a Storage Account e verifique que o arquivo `teste-aci.txt` aparece no File Share

> **Conceito:** Montar Azure File Shares em containers ACI permite persistencia de dados alem do ciclo de vida do container. Quando o container e destruido, os dados permanecem no File Share. Isso e essencial para containers stateful.

> **Dica AZ-104:** ACI suporta apenas Azure Files para volumes persistentes (nao Azure Disks). O mount usa SMB, entao precisa do nome da storage account e chave de acesso. Para seguranca, use Private Endpoints no storage e ACI em VNet.

---

### Task 4.4: Configurar Restart Policy e Verificar Logs

1. Na instancia `aci-nginx-01`, no menu lateral, clique em **Settings > Containers**
2. Clique na aba **Logs**
3. Observe os logs do nginx mostrando requisicoes HTTP (se voce acessou a pagina)
4. Clique na aba **Events**
5. Observe os eventos de lifecycle:
   - **Pulling:** imagem sendo baixada
   - **Created:** container criado
   - **Started:** container iniciado
6. Agora, vamos entender as restart policies:
   - No menu lateral, clique em **Overview**
   - Observe o **Restart policy** (configurado na criacao)
7. Para criar um container com restart policy diferente, va para **Container instances > + Create**
8. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Resource group | `az104-rg9` |
   | Container name | `aci-batch-01` |
   | Image | `mcr.microsoft.com/azuredocs/aci-wordcount:latest` |
   | OS type | Linux |

9. Na aba **Advanced**, configure:
   - **Restart policy:** Never

10. Clique em **Review + Create** e depois **Create**
11. Aguarde o deploy completar
12. Navegue ate o container
13. Observe o **Status** — sera **Terminated** (pois o container executa e encerra)
14. Va para **Containers > Logs** e observe a saida do processamento de palavras
15. Note que o container NAO reiniciou (policy = Never)

> **Conceito:** Restart policies controlam o comportamento quando um container para. **Always** reinicia sempre (ideal para servidores). **OnFailure** reinicia apenas em caso de erro (exit code != 0). **Never** nao reinicia (ideal para batch jobs e tarefas unicas).

> **Dica AZ-104:** Para o exame, associe: Always = web servers/APIs, OnFailure = tarefas com retry, Never = batch jobs/scripts. ACI cobra por segundo de execucao, entao containers com Never param de gerar custos apos terminar. Os logs ficam disponiveis mesmo apos o container terminar.

---

## Modo Desafio - Bloco 4

Tente realizar as tarefas abaixo **sem consultar as instrucoes acima**:

- [ ] Criar ACI com imagem `mcr.microsoft.com/azuredocs/aci-helloworld` expondo porta 80
- [ ] Criar ACI com 3 variaveis de ambiente (1 secure) e resource limits customizados
- [ ] Montar Azure File Share em um container e persistir um arquivo
- [ ] Criar ACI com restart policy "Never" usando imagem de batch processing
- [ ] Acessar logs e eventos de um container para troubleshooting
- [ ] Criar container group com 2 containers (sidecar pattern) via Azure CLI

---

## Questoes de Prova - Bloco 4

**Questao 1:** Qual a principal diferenca entre Azure Container Instances e Azure Kubernetes Service?

<details><summary>Ver resposta</summary>

**ACI** e para containers individuais ou grupos simples, sem orquestracao. E serverless — voce nao gerencia infraestrutura e paga por segundo de execucao. **AKS** e para orquestracao complexa de multiplos containers com Kubernetes, oferecendo service discovery, auto-scaling, rolling updates e muito mais. Use ACI para tarefas simples e rapidas; use AKS para aplicacoes de producao que requerem orquestracao.

</details>

**Questao 2:** Um container ACI com restart policy "OnFailure" termina com exit code 0. O que acontece?

<details><summary>Ver resposta</summary>

**O container NAO reinicia.** A policy "OnFailure" reinicia apenas quando o exit code e diferente de 0 (indicando falha). Exit code 0 indica sucesso, entao o container para normalmente e permanece no estado "Terminated". Se o exit code fosse 1 ou outro valor, o container seria reiniciado automaticamente.

</details>

**Questao 3:** Voce precisa que dados gerados por um container ACI persistam apos o container ser deletado. Qual a melhor abordagem?

<details><summary>Ver resposta</summary>

**Montar um Azure File Share como volume.** ACI suporta montar Azure Files como volumes persistentes. Os dados gravados no mount path sao armazenados no File Share e persistem independentemente do ciclo de vida do container. Alternativamente, o container pode gravar dados em um servico externo como Azure Blob Storage, Azure SQL ou Cosmos DB via API.

</details>

---

## Key Takeaways - Bloco 4

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| ACI vs AKS | ACI = simples, serverless, sem orquestracao; AKS = Kubernetes completo |
| Restart Policies | Always = servers; OnFailure = retry; Never = batch jobs |
| Environment Variables | Secure vars sao criptografadas e nao aparecem em logs/UI |
| File Share Mount | Unica opcao de volume persistente nativo para ACI (Azure Files) |
| Resource Limits | Max 4 vCPU e 16 GiB por container group (varia por regiao) |

---

# Bloco 5 - Azure Container Apps

**Origem:** Lab 09c
**Resource Groups utilizados:** `az104-rg10`

## Contexto

Azure Container Apps e uma plataforma serverless para rodar containers com suporte a microservicos, event-driven processing e escala automatica (incluindo escala para zero). E construido sobre Kubernetes e KEDA, mas abstrai toda a complexidade. Neste bloco, voce vai criar um Container Apps Environment, fazer deploy de apps, configurar scaling rules, ingress e traffic splitting entre revisions.

## Diagrama

```
┌──────────────────────────────────────────────────────────────────────┐
│                            az104-rg10                                │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │           Container Apps Environment                          │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────┐      │  │
│  │  │           Container App (web-app)                    │      │  │
│  │  │                                                      │      │  │
│  │  │  ┌────────────┐     ┌────────────┐                   │      │  │
│  │  │  │ Revision 1 │     │ Revision 2 │                   │      │  │
│  │  │  │ (v1.0)     │     │ (v2.0)     │                   │      │  │
│  │  │  │ Traffic:80%│     │ Traffic:20%│                   │      │  │
│  │  │  └────────────┘     └────────────┘                   │      │  │
│  │  │                                                      │      │  │
│  │  │  ┌──────────────────────────────────────────────┐    │      │  │
│  │  │  │           Scaling Rules                      │    │      │  │
│  │  │  │  HTTP: min 0, max 10                         │    │      │  │
│  │  │  │  Scale to zero when no traffic               │    │      │  │
│  │  │  └──────────────────────────────────────────────┘    │      │  │
│  │  │                                                      │      │  │
│  │  │  ┌──────────────────────────────────────────────┐    │      │  │
│  │  │  │           Ingress                            │    │      │  │
│  │  │  │  Type: External (public)                     │    │      │  │
│  │  │  │  Target port: 80                             │    │      │  │
│  │  │  │  Transport: Auto (HTTP/HTTPS)                │    │      │  │
│  │  │  └──────────────────────────────────────────────┘    │      │  │
│  │  └──────────────────────────────────────────────────────┘      │  │
│  │                                                                │  │
│  │  Log Analytics Workspace (linked)                              │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar Container Apps Environment

1. No Portal Azure, pesquise **Container Apps Environments**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg10` (criar novo) |
   | Environment name | `cae-lab09` |
   | Region | East US |
   | Environment type | Workload profiles |

4. Na aba **Monitoring**, configure:

   | Setting | Value |
   |---------|-------|
   | Log Analytics workspace | Create new: `law-cae-lab09` |

5. Na aba **Workload profiles**, mantenha o **Consumption** profile padrao
6. Clique em **Review + Create** e depois **Create**
7. Aguarde o deploy completar (2-5 minutos)
8. Clique em **Go to resource**
9. Observe as informacoes do environment:
   - **Status:** Ready
   - **Default domain:** um sufixo unico sera atribuido
   - **Workload profiles:** Consumption (serverless)

> **Conceito:** O Container Apps Environment e o boundary seguro para seus Container Apps. Apps no mesmo environment compartilham a mesma rede virtual e Log Analytics workspace. E analogico a um namespace Kubernetes, mas gerenciado pelo Azure.

> **Dica AZ-104:** Container Apps Environment suporta dois tipos de planos: Consumption (serverless, paga por uso) e Dedicated (workload profiles com recursos reservados). Consumption e o mais comum para o exame. O environment pode ter VNet customizada para integracao com recursos privados.

---

### Task 5.2: Criar Container App com Imagem Publica

1. No Portal Azure, pesquise **Container Apps**
2. Clique em **+ Create**
3. Na aba **Basics**, configure:

   | Setting | Value |
   |---------|-------|
   | Subscription | Sua assinatura |
   | Resource group | `az104-rg10` |
   | Container app name | `ca-web-01` |
   | Region | East US |
   | Container Apps Environment | `cae-lab09` (existente) |

4. Clique em **Next: Container**
5. Desmarque **Use quickstart image** e configure:

   | Setting | Value |
   |---------|-------|
   | Image source | Docker Hub or other registries |
   | Image type | Public |
   | Registry login server | `mcr.microsoft.com` |
   | Image and tag | `azuredocs/containerapps-helloworld:latest` |
   | CPU and Memory | 0.25 CPU cores, 0.5 Gi memory |

6. Em **Environment variables**, adicione:

   | Name | Source | Value |
   |------|--------|-------|
   | `APP_ENV` | Manual entry | `production` |

7. Clique em **Next: Ingress**
8. Configure:

   | Setting | Value |
   |---------|-------|
   | Ingress | Enabled |
   | Ingress traffic | Accepting traffic from anywhere |
   | Ingress type | HTTP |
   | Target port | 80 |

9. Clique em **Review + Create** e depois **Create**
10. Aguarde o deploy completar (2-3 minutos)
11. Clique em **Go to resource**
12. Na pagina Overview, clique na **Application Url**
13. Voce vera a aplicacao hello world do Container Apps
14. Observe no overview:
    - **Revision:** uma revision foi criada automaticamente
    - **Replicas:** numero atual de replicas (pode ser 0 se scale-to-zero)

> **Conceito:** Container Apps permitem rodar containers sem gerenciar infraestrutura Kubernetes. Suportam qualquer runtime, linguagem e framework que rode em container. Diferente de ACI, Container Apps tem ingress nativo, scaling sofisticado e gerenciamento de revisions.

> **Dica AZ-104:** Para o exame, saiba que Container Apps e a escolha ideal quando voce precisa de features como scale-to-zero, revisions, traffic splitting e event-driven scaling, mas nao quer a complexidade de gerenciar AKS.

---

### Task 5.3: Configurar Scaling Rules

1. Na Container App `ca-web-01`, no menu lateral, clique em **Application > Scale**
2. Clique em **Edit and deploy**
3. Na aba **Scale**, configure:

   | Setting | Value |
   |---------|-------|
   | Min replicas | 0 |
   | Max replicas | 5 |

4. Clique em **+ Add** para adicionar uma regra de scaling
5. Configure a regra HTTP:

   | Setting | Value |
   |---------|-------|
   | Rule name | `http-scaling` |
   | Type | HTTP scaling |
   | Concurrent requests | 10 |

6. Clique em **Add**
7. Voce tambem pode adicionar uma regra customizada:
   - Clique em **+ Add** novamente
   - Selecione **Custom** como tipo
   - Explore as opcoes de KEDA scalers disponiveis (Azure Queue, Kafka, etc.)
   - Cancele por enquanto (a regra HTTP e suficiente para o lab)
8. Clique em **Create** para aplicar as alteracoes
9. Aguarde a nova revision ser criada
10. Volte para **Scale** e observe as regras configuradas
11. Na pagina **Overview**, observe que **Replicas** pode mostrar 0 (scale-to-zero em acao)

> **Conceito:** Container Apps usa KEDA (Kubernetes Event Driven Autoscaler) por baixo para scaling. Regras HTTP escalam baseado em requisicoes concorrentes. Regras customizadas suportam dezenas de event sources (Azure Queue, Kafka, Cron, etc.). Scale-to-zero e uma feature unica — zero custo quando nao ha trafego.

> **Dica AZ-104:** Para o exame, entenda que min replicas = 0 permite scale-to-zero (primeiro request tera cold start). Min replicas = 1 mantem pelo menos uma replica ativa (sem cold start, mas com custo continuo). Concurrent requests define o ponto de scale out — quando cada replica recebe mais que N requests, uma nova replica e criada.

---

### Task 5.4: Configurar Ingress

1. Na Container App `ca-web-01`, no menu lateral, clique em **Settings > Ingress**
2. Observe a configuracao atual:
   - **Ingress:** Enabled
   - **Ingress traffic:** Accepting traffic from anywhere (external)
   - **Target port:** 80
3. Altere a configuracao:

   | Setting | Value |
   |---------|-------|
   | Ingress traffic | Limited to Container Apps Environment (internal) |

4. Clique em **Save**
5. Tente acessar a URL anterior — acesso sera negado (403 ou timeout)
6. Isso porque o ingress agora e interno — apenas outros apps no mesmo environment podem acessar
7. Volte para a configuracao de Ingress e altere:

   | Setting | Value |
   |---------|-------|
   | Ingress traffic | Accepting traffic from anywhere (external) |
   | Transport | Auto |
   | Client certificate mode | Ignore |

8. Clique em **Save**
9. Acesse a URL novamente — a aplicacao estara acessivel
10. Observe as opcoes adicionais:
    - **IP Security Restrictions:** permite configurar allow/deny por IP range
    - **CORS:** permite configurar Cross-Origin Resource Sharing

> **Conceito:** Ingress controla como o trafego chega ao Container App. External permite acesso da internet. Internal restringe para dentro do environment (comunicacao entre apps). O Transport pode ser HTTP/1.1, HTTP/2 ou Auto. O Azure gerencia o TLS automaticamente.

> **Dica AZ-104:** Container Apps com ingress externo recebem uma URL HTTPS automatica com certificado TLS gerenciado pelo Azure. Para custom domains, voce pode trazer seu proprio certificado ou usar um certificado gerenciado gratuito. IP restrictions sao uteis para restringir acesso a ranges corporativos.

---

### Task 5.5: Criar Revision e Gerenciar Traffic Splitting

1. Na Container App `ca-web-01`, no menu lateral, clique em **Application > Revisions and replicas**
2. Observe a revision atual (unica)
3. Primeiro, configure o modo de revisions:
   - No menu lateral, clique em **Settings > Configuration** (ou **Properties**)
   - Localize **Revision mode** e altere para **Multiple** (se estiver em Single)
   - Clique em **Save**
4. Agora, vamos criar uma nova revision:
   - Volte para **Revisions and replicas**
   - Clique em **+ Create new revision**
5. Na aba **Container**, edite o container existente:
   - Altere ou adicione uma environment variable:

     | Name | Source | Value |
     |------|--------|-------|
     | `APP_VERSION` | Manual entry | `2.0.0` |

6. Clique em **Create**
7. Aguarde a nova revision ser criada (1-2 minutos)
8. Agora configure traffic splitting:
   - Na pagina **Revisions and replicas**, voce vera 2 revisions
   - Clique em **Manage traffic** (ou edite a coluna Traffic)
   - Configure:

     | Revision | Traffic (%) |
     |----------|-------------|
     | Revision 1 (original) | 80 |
     | Revision 2 (nova) | 20 |

9. Clique em **Save**
10. Acesse a URL da aplicacao varias vezes
11. Observe que ~80% das vezes voce recebe a versao original e ~20% a nova versao
12. Para promover a nova versao, altere o traffic splitting:

    | Revision | Traffic (%) |
    |----------|-------------|
    | Revision 1 | 0 |
    | Revision 2 | 100 |

13. Salve e verifique que todo trafego agora vai para a revision 2

> **Conceito:** Revisions sao snapshots imutaveis do Container App. Cada alteracao (imagem, env vars, scaling) cria uma nova revision. Traffic splitting permite distribuir trafego entre revisions, habilitando canary deployments e A/B testing. Single mode permite apenas 1 revision ativa; Multiple permite varias.

> **Dica AZ-104:** Para o exame, saiba que: Single revision mode = apenas a ultima revision recebe trafego (ideal para apps simples). Multiple revision mode = permite traffic splitting entre revisions (ideal para canary/blue-green). Revisions antigas podem ser desativadas para nao consumir recursos.

---

## Modo Desafio - Bloco 5

Tente realizar as tarefas abaixo **sem consultar as instrucoes acima**:

- [ ] Criar Container Apps Environment com VNet customizada
- [ ] Criar Container App com imagem do Docker Hub (nao MCR)
- [ ] Configurar scaling com min=1, max=10 e regra HTTP de 5 concurrent requests
- [ ] Alternar ingress entre external e internal e testar acessibilidade
- [ ] Criar 3 revisions e configurar traffic splitting: 70/20/10
- [ ] Configurar IP restriction para permitir apenas seu IP
- [ ] Desativar revisions antigas que nao recebem mais trafego

---

## Questoes de Prova - Bloco 5

**Questao 1:** Qual a principal vantagem do Azure Container Apps sobre Azure Container Instances?

<details><summary>Ver resposta</summary>

**Container Apps oferece scaling sofisticado (incluindo scale-to-zero), revisions com traffic splitting, ingress integrado e event-driven scaling via KEDA.** ACI e mais simples e adequado para containers individuais sem necessidade de orquestracao. Container Apps e ideal para microservicos e aplicacoes event-driven, enquanto ACI e melhor para tarefas pontuais, batch jobs e cenarios simples.

</details>

**Questao 2:** Voce configurou min replicas = 0 em um Container App. Um usuario reporta latencia alta na primeira requisicao apos periodo de inatividade. Qual a causa e solucao?

<details><summary>Ver resposta</summary>

**Causa: Cold start.** Com min replicas = 0, o Container App escala para zero quando nao ha trafego. A primeira requisicao precisa aguardar uma replica ser provisionada e o container iniciar. **Solucao:** Configurar min replicas = 1 para manter pelo menos uma replica sempre ativa, eliminando cold starts. O trade-off e que havera custo continuo mesmo sem trafego.

</details>

**Questao 3:** Qual a diferenca entre Single e Multiple revision mode no Container Apps?

<details><summary>Ver resposta</summary>

**Single revision mode:** Apenas a revision mais recente e ativa e recebe trafego. Revisions anteriores sao automaticamente desativadas. Ideal para aplicacoes simples que nao precisam de canary deployments. **Multiple revision mode:** Permite multiplas revisions ativas simultaneamente com traffic splitting configuravel. Ideal para canary deployments, A/B testing e blue-green deployments. O modo pode ser alterado a qualquer momento.

</details>

---

## Key Takeaways - Bloco 5

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Container Apps vs ACI | Container Apps = scaling, revisions, ingress; ACI = simples, sem orquestracao |
| Scale-to-zero | Min replicas = 0 reduz custos mas causa cold start na primeira requisicao |
| Revisions | Snapshots imutaveis; Single mode = 1 ativa; Multiple mode = traffic splitting |
| Ingress | External = publico; Internal = apenas dentro do environment |
| Traffic Splitting | Distribui trafego entre revisions; habilita canary e blue-green deployments |
| KEDA Scalers | HTTP concurrent requests, Azure Queue, Kafka, Cron e dezenas de outros |

---

# Cleanup Unificado

> **IMPORTANTE:** Execute o cleanup para evitar custos desnecessarios. Os recursos criados neste lab (especialmente VMs e VMSS) geram custos continuos.

## Opcao 1: Portal

1. Navegue ate **Resource groups**
2. Selecione e delete os seguintes resource groups (um de cada vez):
   - `az104-rg6` (Storage)
   - `az104-rg7` (VMs e VMSS)
   - `az104-rg8` (Web Apps)
   - `az104-rg9` (Container Instances)
   - `az104-rg10` (Container Apps)
3. Para cada um:
   - Clique no resource group
   - Clique em **Delete resource group**
   - Digite o nome do resource group para confirmar
   - Clique em **Delete**
4. Aguarde a exclusao de cada grupo (pode levar 5-15 minutos por grupo)

## Opcao 2: Azure CLI

```bash
# Deletar todos os resource groups do lab
az group delete --name az104-rg6 --yes --no-wait
az group delete --name az104-rg7 --yes --no-wait
az group delete --name az104-rg8 --yes --no-wait
az group delete --name az104-rg9 --yes --no-wait
az group delete --name az104-rg10 --yes --no-wait
```

> O parametro `--no-wait` permite executar todos os comandos sem aguardar cada um completar.

## Opcao 3: PowerShell

```powershell
# Deletar todos os resource groups do lab
$rgs = @('az104-rg6', 'az104-rg7', 'az104-rg8', 'az104-rg9', 'az104-rg10')
foreach ($rg in $rgs) {
    Remove-AzResourceGroup -Name $rg -Force -AsJob
}
```

> O parametro `-AsJob` executa cada remocao como um job em background.

---

# Key Takeaways Consolidados

## Bloco 1 - Storage

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Redundancia (LRS/ZRS/GRS/GZRS) | Escolher baseado em RPO e requisitos de disponibilidade regional/zonal |
| Access Tiers (Hot/Cool/Cold/Archive) | Hot = acesso frequente; Archive = retencao longo prazo (rehydration necessaria) |
| SAS Tokens | User Delegation SAS e mais seguro; regenerar chave invalida SAS baseados nela |
| Lifecycle Management | Automatiza transicao de tiers; avaliado 1x/dia; apenas block/append blobs |
| Private Endpoint vs Service Endpoint | PE = IP privado + DNS; SE = gratuito, backbone Azure, IP publico mantido |

## Bloco 2 - Virtual Machines

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Availability Zones | 2+ zonas = SLA 99.99%; requer LB Standard SKU |
| VM Families | B = burstable; D = general; E = memory; F = compute; N = GPU |
| Managed Disks | Premium SSD = single VM SLA 99.9%; tipo disco impacta performance e SLA |
| Extensions e Run Command | Custom Script Extension para automacao; Run Command para execucao rapida |
| VMSS | Uniform vs Flexible; autoscale por metricas ou schedule; spread across zones |

## Bloco 3 - Web Apps

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| App Service Plan Tiers | Standard+ para slots e autoscale; Premium para VNet integration nativa |
| Deployment Slots | Deploy sem downtime; swap atomico; rollback = swap novamente |
| Slot-sticky Settings | Connection strings e app settings que ficam no slot durante swap |
| Autoscale | Baseado em CPU, memoria, HTTP queue ou schedule; Cool down evita flapping |

## Bloco 4 - Azure Container Instances

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| ACI vs AKS | ACI = simples, serverless; AKS = Kubernetes completo com orquestracao |
| Restart Policies | Always = servers; OnFailure = retry; Never = batch jobs |
| Volumes | Azure Files e a unica opcao nativa de volume persistente para ACI |
| Resource Limits | Max 4 vCPU e 16 GiB por container group |

## Bloco 5 - Azure Container Apps

| Conceito | Aplicacao no Exame |
|----------|-------------------|
| Container Apps vs ACI | CA = scaling, revisions, ingress, KEDA; ACI = simples, sem orquestracao |
| Scale-to-zero | Min 0 = sem custo ocioso, mas cold start; Min 1 = sem cold start, custo continuo |
| Revisions e Traffic Splitting | Single mode = 1 ativa; Multiple = canary/blue-green com % configuravel |
| Ingress | External = publico com TLS automatico; Internal = comunicacao entre apps |

---

> **Proximo passo:** Na Semana 3, voce vai configurar monitoramento, backup e disaster recovery para os recursos criados. Continue praticando os conceitos desta semana, especialmente storage networking e VM availability, que sao temas frequentes no exame AZ-104.
