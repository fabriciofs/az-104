# Lab Unificado AZ-104 - Semana 1: Identity, Governance, IaC, Networking & Connectivity

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce foi contratado como **Azure Administrator** de uma empresa em expansao. Sua missao e configurar todo o ambiente Azure do zero: identidade, governanca, automacao de recursos, rede virtual e conectividade entre sites. Ao final deste lab, voce tera um ambiente corporativo funcional com boas praticas aplicadas.

---

## Indice

- [Bloco 1 - Identity](#bloco-1---identity)
- [Bloco 2 - Governance & Compliance](#bloco-2---governance--compliance)
- [Bloco 3 - Azure Resources & IaC](#bloco-3---azure-resources--iac)
- [Bloco 4 - Virtual Networking](#bloco-4---virtual-networking)
- [Bloco 5 - Intersite Connectivity](#bloco-5---intersite-connectivity)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - Identity

**Origem:** Lab 01 - Manage Microsoft Entra ID Identities
**Resource Groups utilizados:** Nenhum (recursos no Entra ID)

## Contexto

Antes de provisionar qualquer recurso, voce precisa configurar a base de identidade: criar usuarios, convidar parceiros externos (B2B) e organizar tudo em grupos de seguranca.

## Diagrama

```
┌─────────────────────────────────────┐
│         Microsoft Entra ID          │
│                                     │
│  ┌─────────┐    ┌────────────────┐  │
│  │ User    │    │  Guest User    │  │
│  │az104-   │    │  (B2B Invite)  │  │
│  │ user1   │    │                │  │
│  └────┬────┘    └───────┬────────┘  │
│       │                 │           │
│       └────────┬────────┘           │
│                ▼                    │
│  ┌──────────────────────┐           │
│  │ Security Group       │           │
│  │ IT Lab Administrators│           │
│  │ (Assigned membership)│           │
│  └──────────────────────┘           │
└─────────────────────────────────────┘
```

---

### Task 1.1: Criar e configurar conta de usuario

Nesta task voce cria uma conta de usuario interna com propriedades detalhadas.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Microsoft Entra ID**

3. Explore o blade **Overview** e a aba **Manage tenants**

   > **Conceito:** Um tenant e uma instancia especifica do Microsoft Entra ID contendo contas e grupos. Dependendo da sua situacao, voce pode criar mais tenants e alternar entre eles.

4. No blade **Manage**, selecione **Users** > **New user** > **Create new user**

5. Preencha as configuracoes:

   | Setting                | Value         |
   | ---------------------- | ------------- |
   | User principal name    | `az104-user1` |
   | Display name           | `az104-user1` |
   | Auto-generate password | **checked**   |
   | Account enabled        | **checked**   |

6. Va para a aba **Properties** e preencha:

   | Setting        | Value                  |
   | -------------- | ---------------------- |
   | Job title      | `IT Lab Administrator` |
   | Department     | `IT`                   |
   | Usage location | **United States**      |

7. Clique em **Review + create** e depois **Create**

8. **Refresh** a pagina e confirme que o usuario foi criado

   > **Dica AZ-104:** Na prova, preste atencao em propriedades como Usage location - ela e obrigatoria para atribuir licencas ao usuario.

---

### Task 1.2: Convidar usuario externo (Guest/B2B)

Nesta task voce convida um usuario externo para colaborar no tenant da organizacao.

1. Ainda em **Users**, clique em **New user** > **Invite an external user**

2. Preencha as configuracoes:

   | Setting             | Value                                    |
   | ------------------- | ---------------------------------------- |
   | Email               | *seu email pessoal*                      |
   | Display name        | *seu nome*                               |
   | Send invite message | **check the box**                        |
   | Message             | `Welcome to Azure and our group project` |

3. Va para a aba **Properties** e preencha:

   | Setting        | Value                  |
   | -------------- | ---------------------- |
   | Job title      | `IT Lab Administrator` |
   | Department     | `IT`                   |
   | Usage location | **United States**      |

4. Clique em **Review + invite** e depois **Invite**

5. **Refresh** a pagina e confirme que o usuario convidado foi criado. Voce deve receber o email de convite em breve.

   > **Conceito B2B:** Azure AD B2B permite que usuarios externos acessem recursos do seu tenant usando suas proprias credenciais. O usuario aparece como **Guest** no diretorio.

---

### Task 1.3: Criar grupo de seguranca

Nesta task voce cria um grupo de seguranca para organizar os administradores do lab.

1. No Azure Portal, pesquise e selecione **Microsoft Entra ID** > blade **Manage** > **Groups**

2. Familiarize-se com as configuracoes de grupo no painel esquerdo:
   - **Expiration:** configura tempo de vida do grupo em dias
   - **Naming policy:** configura palavras bloqueadas e prefixos/sufixos

3. No blade **All groups**, selecione **+ New group**:

   | Setting           | Value                                   |
   | ----------------- | --------------------------------------- |
   | Group type        | **Security**                            |
   | Group name        | `IT Lab Administrators`                 |
   | Group description | `Administrators that manage the IT lab` |
   | Membership type   | **Assigned**                            |

   > **Nota:** Entra ID Premium P1 ou P2 e necessario para **Dynamic membership**. Se disponivel, as opcoes aparecerao no dropdown.

---

### Task 1.4: Adicionar owners e members ao grupo

1. Clique em **No owners selected**

2. Na pagina **Add owners**, pesquise e selecione **voce mesmo** como owner

3. Clique em **No members selected**

4. Na pagina **Add members**, pesquise e selecione:
   - **az104-user1**
   - O **guest user** que voce convidou

5. Clique em **Create** para criar o grupo

6. **Refresh** a pagina e verifique que o grupo foi criado

7. Selecione o novo grupo e revise as informacoes de **Members** e **Owners**

---

## Modo Desafio - Bloco 1

Para repeticoes rapidas, execute sem consultar os passos detalhados:

- [ ] Criar usuario `az104-user1` com Job title `IT Lab Administrator`, Department `IT`, Usage location `United States`
- [ ] Convidar usuario externo (guest) com mesmas propriedades
- [ ] Criar grupo de seguranca `IT Lab Administrators` (tipo Assigned)
- [ ] Adicionar voce como owner
- [ ] Adicionar `az104-user1` e o guest user como members
- [ ] Verificar members e owners do grupo

---

## Questoes de Prova - Bloco 1

### Questao 1.1
**Sua organizacao precisa que membros de um grupo sejam automaticamente adicionados/removidos com base no departamento do usuario. Qual tipo de membership voce deve configurar?**

A) Assigned
B) Dynamic user
C) Dynamic device
D) Microsoft 365

<details>
<summary>Ver resposta</summary>

**Resposta: B) Dynamic user**

Dynamic user membership permite criar regras baseadas em propriedades do usuario (como department, jobTitle, etc.) para adicionar/remover membros automaticamente. Requer licenca Entra ID Premium P1 ou P2. Dynamic device e para grupos baseados em propriedades de dispositivos. Assigned requer adicao manual.

</details>

### Questao 1.2
**Um usuario externo foi convidado para o seu tenant via Azure AD B2B. Qual e o tipo de conta (User type) desse usuario no diretorio?**

A) Member
B) Guest
C) External
D) Federated

<details>
<summary>Ver resposta</summary>

**Resposta: B) Guest**

Usuarios convidados via B2B aparecem com User type = **Guest** no diretorio. Usuarios criados diretamente no tenant sao do tipo **Member**. Os termos External e Federated nao sao valores validos para User type.

</details>

### Questao 1.3
**Voce precisa atribuir uma licenca Microsoft 365 a um usuario. Ao tentar, recebe um erro. Qual propriedade do usuario provavelmente esta faltando?**

A) Department
B) Job title
C) Usage location
D) Manager

<details>
<summary>Ver resposta</summary>

**Resposta: C) Usage location**

A propriedade **Usage location** e obrigatoria para atribuir licencas a um usuario no Microsoft Entra ID. Sem ela, a atribuicao de licenca falha. As demais propriedades sao opcionais para esse fim.

</details>

---

# Bloco 2 - Governance & Compliance

**Origem:** Lab 02a (Subscriptions & RBAC) + Lab 02b (Azure Policy)
**Resource Groups utilizados:** `az104-rg2`

## Contexto

Com a identidade configurada, agora voce precisa estabelecer governanca: organizar subscriptions em Management Groups, controlar acesso com RBAC (roles built-in e custom), aplicar policies para padronizar tags e proteger recursos com locks.

## Diagrama

```
┌─────────────────────────────────────────────────┐
│                 Root Management Group           │
│                                                 │
│   ┌─────────────────────────────────────────┐   │
│   │        az104-mg1 (Management Group)     │   │
│   │                                         │   │
│   │  ┌───────────────────────────────────┐  │   │
│   │  │ RBAC Assignments:                 │  │   │
│   │  │ • VM Contributor → helpdesk       │  │   │
│   │  │ • Custom Support Request          │  │   │
│   │  └───────────────────────────────────┘  │   │
│   └─────────────────────────────────────────┘   │
│                                                 │
│   ┌─────────────────────────────────────────┐   │
│   │        az104-rg2 (Resource Group)       │   │
│   │        Tag: Cost Center = 000           │   │
│   │                                         │   │
│   │  ┌───────────────────────────────────┐  │   │
│   │  │ Policies:                         │  │   │
│   │  │ • Deny: Require tag on resources  │  │   │
│   │  │ • Modify: Inherit tag from RG     │  │   │
│   │  │                                   │  │   │
│   │  │ Lock: Delete (rg-lock)            │  │   │
│   │  └───────────────────────────────────┘  │   │
│   └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

---

### Task 2.1: Criar Management Group

Management Groups organizam subscriptions logicamente. Permitem aplicar RBAC e Azure Policy de forma herdada.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Microsoft Entra ID**

3. No blade **Manage**, selecione **Properties**

4. Revise a area **Access management for Azure resources** - note que voce pode gerenciar acesso a todas as subscriptions e management groups do tenant

5. Pesquise e selecione **Management groups**

6. Clique em **+ Create** e preencha:

   | Setting                       | Value                                     |
   | ----------------------------- | ----------------------------------------- |
   | Management group ID           | `az104-mg1` (deve ser unico no diretorio) |
   | Management group display name | `az104-mg1`                               |

7. Clique em **Submit**

8. **Refresh** a pagina e confirme que o management group aparece

   > **Conceito:** O **Root Management Group** e embutido na hierarquia para que todos os management groups e subscriptions se organizem abaixo dele. Permite aplicar policies e roles no nivel do diretorio.

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

Agora voce vai atribuir um role built-in ao grupo helpdesk no management group.

> **Nota:** Se voce nao tem um grupo **helpdesk**, crie-o rapidamente em Entra ID > Groups > + New group (Security, Assigned membership).

1. Selecione o management group **az104-mg1**

2. Selecione o blade **Access control (IAM)** > aba **Roles**

3. Navegue pelos built-in roles. **View** um role para ver detalhes de **Permissions**, **JSON** e **Assignments**

4. Clique em **+ Add** > **Add role assignment**

5. Pesquise e selecione **Virtual Machine Contributor**

   > **Conceito:** O role Virtual Machine Contributor permite gerenciar VMs, mas NAO o SO, a VNet ou o Storage Account conectados.

6. Clique em **Next**

7. Na aba **Members**, clique em **Select Members**

8. Pesquise e selecione o grupo `helpdesk`. Clique em **Select**

9. Clique em **Review + assign** duas vezes para criar a atribuicao

10. Na aba **Role assignments** do blade **Access control (IAM)**, confirme que o grupo **helpdesk** tem o role **Virtual Machine Contributor**

    > **Best practice:** Sempre atribua roles a **grupos**, nao a individuos.

---

### Task 2.3: Criar custom RBAC role

Voce vai criar um role customizado clonando um existente e removendo permissoes desnecessarias.

1. No management group **az104-mg1**, va para **Access control (IAM)**

2. Clique em **+ Add** > **Add custom role**

3. Preencha a aba **Basics**:

   | Setting              | Value                                             |
   | -------------------- | ------------------------------------------------- |
   | Custom role name     | `Custom Support Request`                          |
   | Description          | `A custom contributor role for support requests.` |
   | Baseline permissions | **Clone a role**                                  |
   | Role to clone        | **Support Request Contributor**                   |

4. Clique em **Next** para ir a aba **Permissions**

5. Clique em **+ Exclude permissions**

6. No campo de busca do resource provider, digite `.Support` e selecione **Microsoft.Support**

7. Na lista de permissoes, marque o checkbox de **Other: Registers Support Resource Provider** e clique em **Add**

   > **Conceito:** O role agora inclui essa permissao como **NotAction**. Um resource provider e um conjunto de operacoes REST que habilitam funcionalidade para um servico Azure especifico.

8. Na aba **Assignable scopes**, verifique que seu management group esta listado. Clique em **Next**

9. Revise o JSON: observe **Actions**, **NotActions** e **AssignableScopes**

10. Clique em **Review + Create** e depois **Create**

---

### Task 2.4: Monitorar role assignments via Activity Log

1. No portal, localize o recurso **az104-mg1** e selecione **Activity log**

2. Revise as atividades de role assignments

   > **Dica:** O Activity Log fornece insights sobre eventos no nivel da subscription. Voce pode filtrar por operacoes especificas.

---

### Task 2.5: Criar Resource Group com tag

Agora voce configura governanca no nivel de Resource Group com tags.

1. Pesquise e selecione **Resource groups**

2. Clique em **+ Create**:

   | Setting             | Value              |
   | ------------------- | ------------------ |
   | Subscription        | *sua subscription* |
   | Resource group name | `az104-rg2`        |
   | Location            | **East US**        |

3. Clique em **Next** e va para a aba **Tags**:

   | Setting | Value         |
   | ------- | ------------- |
   | Name    | `Cost Center` |
   | Value   | `000`         |

4. Clique em **Review + Create** e depois **Create**

---

### Task 2.6: Aplicar Azure Policy (Deny) - Require tag

Voce aplica uma policy que **bloqueia** a criacao de recursos sem a tag obrigatoria.

1. Pesquise e selecione **Policy**

2. No blade **Authoring**, selecione **Definitions**

3. Pesquise a policy built-in: `Require a tag and its value on resources`

4. Selecione a policy e revise a definicao. Clique em **Assign policy**

5. Configure o **Scope**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | **az104-rg2**      |

6. Configure as propriedades **Basics**:

   | Setting            | Value                                                                          |
   | ------------------ | ------------------------------------------------------------------------------ |
   | Assignment name    | `Require Cost Center tag and its value on resources`                           |
   | Description        | `Require Cost Center tag and its value on all resources in the resource group` |
   | Policy enforcement | **Enabled**                                                                    |

7. Clique em **Next** e defina os **Parameters**:

   | Setting   | Value         |
   | --------- | ------------- |
   | Tag Name  | `Cost Center` |
   | Tag Value | `000`         |

8. Clique em **Next**, revise **Remediation** (deixe sem managed identity), clique em **Review + Create** > **Create**

   > **Nota:** A policy pode levar de 5 a 10 minutos para entrar em vigor.

9. **Teste a policy:** Pesquise e selecione **Storage Accounts** > **+ Create**:

   | Setting              | Value                             |
   | -------------------- | --------------------------------- |
   | Resource group       | **az104-rg2**                     |
   | Storage account name | *qualquer nome unico globalmente* |

10. Clique em **Review** e depois **Create**

11. Voce deve receber um erro **Validation failed** - a policy bloqueou a criacao porque o recurso nao tem a tag `Cost Center` com valor `000`

    > **Conceito:** O efeito **Deny** impede que recursos sejam criados/modificados quando nao atendem as condicoes da policy.

---

### Task 2.7: Aplicar Azure Policy (Modify) - Inherit tag + Remediation

Agora voce substitui a policy anterior por uma que **herda** a tag automaticamente do Resource Group.

1. Pesquise e selecione **Policy** > **Authoring** > **Assignments**

2. Localize a atribuicao **Require Cost Center tag...**, clique no icone de reticencias (**...**) e selecione **Delete assignment**

3. Clique em **Assign policy** e configure o **Scope**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg2`        |

4. Pesquise e selecione a policy: `Inherit a tag from the resource group if missing`

5. Configure as propriedades **Basics**:

   | Setting            | Value                                                                              |
   | ------------------ | ---------------------------------------------------------------------------------- |
   | Assignment name    | `Inherit the Cost Center tag and its value 000 from the resource group if missing` |
   | Description        | `Inherit the Cost Center tag and its value 000 from the resource group if missing` |
   | Policy enforcement | **Enabled**                                                                        |

6. Clique em **Next** e defina os **Parameters**:

   | Setting  | Value         |
   | -------- | ------------- |
   | Tag Name | `Cost Center` |

7. Clique em **Next** e configure a aba **Remediation**:

   | Setting                   | Value                                                |
   | ------------------------- | ---------------------------------------------------- |
   | Create a remediation task | **enabled**                                          |
   | Policy to remediate       | **Inherit a tag from the resource group if missing** |

   > **Conceito:** O efeito **Modify** requer uma **Managed Identity** porque altera recursos existentes. A remediation task corrige recursos nao-conformes retroativamente.

8. Clique em **Review + Create** > **Create**

   > **Nota:** Aguarde 5-10 minutos para a policy entrar em vigor.

9. **Teste a policy:** Pesquise **Storage Accounts** > **+ Create**:

   | Setting              | Value                             |
   | -------------------- | --------------------------------- |
   | Resource group       | **az104-rg2**                     |
   | Storage account name | *qualquer nome unico globalmente* |

10. Clique em **Review** > **Create** - desta vez a validacao deve **passar**

11. Apos o provisionamento, clique em **Go to resource**

12. No blade **Tags**, verifique que a tag **Cost Center** com valor **000** foi automaticamente atribuida

---

### Task 2.8: Configurar Resource Lock e testar

1. Pesquise e selecione seu resource group **az104-rg2**

2. No blade **Settings**, selecione **Locks**

3. Clique em **Add**:

   | Setting   | Value      |
   | --------- | ---------- |
   | Lock name | `rg-lock`  |
   | Lock type | **Delete** |

4. Clique em **Ok**

5. Va para o blade **Overview** do resource group e selecione **Delete resource group**

6. Digite o nome do resource group `az104-rg2` para confirmar

7. Clique em **Delete**

8. Voce deve receber uma notificacao **negando a exclusao**

   > **Conceito:** Locks protegem contra exclusoes e modificacoes acidentais. O lock **Delete** permite modificar mas impede exclusao. O lock **ReadOnly** impede ambos. Locks sobrescrevem quaisquer permissoes de usuario.

   > **Importante:** Para excluir o resource group no cleanup, voce precisara remover o lock primeiro.

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `az104-mg1`
- [ ] Criar grupo `helpdesk` (se nao existir)
- [ ] Atribuir role **Virtual Machine Contributor** ao grupo helpdesk no MG
- [ ] Criar custom role **Custom Support Request** (clone de Support Request Contributor, excluindo Registers Support Resource Provider)
- [ ] Verificar role assignments no Activity Log
- [ ] Criar RG `az104-rg2` com tag `Cost Center: 000`
- [ ] Aplicar policy **Deny** (Require a tag and its value) no RG - testar criando storage sem tag
- [ ] Deletar policy Deny
- [ ] Aplicar policy **Modify** (Inherit a tag from the resource group if missing) com remediation - testar criando storage
- [ ] Verificar que a tag foi herdada automaticamente
- [ ] Criar Resource Lock (Delete) no RG e testar exclusao

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce precisa garantir que apenas usuarios do grupo helpdesk possam criar e gerenciar VMs, mas nao possam acessar o SO ou gerenciar a VNet e o Storage Account. Qual role built-in voce deve atribuir?**

A) Virtual Machine Administrator Login
B) Virtual Machine Contributor
C) Contributor
D) Virtual Machine User Login

<details>
<summary>Ver resposta</summary>

**Resposta: B) Virtual Machine Contributor**

O role **Virtual Machine Contributor** permite gerenciar VMs mas NAO concede acesso ao SO, VNet ou Storage Account. O role Contributor daria permissoes excessivas. VM Administrator Login e VM User Login concedem acesso ao SO via login, nao gerenciamento de recursos.

</details>

### Questao 2.2
**Voce criou um custom role clonando o Support Request Contributor e adicionou `Microsoft.Support/register/action` em NotActions. O que acontece quando um usuario com esse role tenta registrar o resource provider Microsoft.Support?**

A) A acao e permitida porque esta em Actions
B) A acao e negada porque NotActions tem prioridade sobre Actions
C) A acao e negada apenas se nao houver outro role atribuido ao usuario
D) A acao gera um erro de autenticacao

<details>
<summary>Ver resposta</summary>

**Resposta: B) A acao e negada porque NotActions tem prioridade sobre Actions**

**NotActions** remove permissoes especificas do conjunto de **Actions**. Se uma acao esta tanto em Actions quanto em NotActions, ela e efetivamente removida. Porem, se o usuario tiver outro role que concede essa permissao, ele ainda podera executa-la (RBAC e aditivo).

</details>

### Questao 2.3
**Voce aplicou uma Azure Policy com efeito "Deny" que exige a tag `Cost Center` em todos os recursos de um Resource Group. Um desenvolvedor tenta criar um Storage Account sem essa tag. O que acontece?**

A) O recurso e criado e a tag e adicionada automaticamente
B) O recurso e criado mas um alerta de compliance e gerado
C) A criacao do recurso falha com erro de validacao
D) O recurso e criado mas marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: C) A criacao do recurso falha com erro de validacao**

O efeito **Deny** impede ativamente a criacao ou modificacao de recursos que nao atendem as condicoes da policy. Diferente do **Audit** (que apenas reporta), o Deny bloqueia a operacao. O efeito **Modify** e que altera recursos automaticamente.

</details>

### Questao 2.4
**Qual a diferenca entre os efeitos Deny, Audit e Modify no Azure Policy?**

A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente
B) Todos os tres bloqueiam a criacao de recursos
C) Deny e Audit sao identicos, Modify cria recursos novos
D) Audit bloqueia, Deny registra, Modify exclui recursos

<details>
<summary>Ver resposta</summary>

**Resposta: A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente**

- **Deny:** Impede criacao/modificacao de recursos nao-conformes
- **Audit:** Permite a criacao mas registra o recurso como non-compliant no compliance dashboard
- **Modify:** Altera propriedades do recurso (como tags) automaticamente durante a criacao. Requer Managed Identity para remediation tasks.

</details>

### Questao 2.5
**Voce configurou um Resource Lock do tipo Delete em um Resource Group. Um usuario com role Owner tenta excluir o Resource Group. O que acontece?**

A) A exclusao e permitida porque o Owner tem todas as permissoes
B) A exclusao e bloqueada - locks sobrescrevem permissoes de usuario
C) A exclusao e permitida mas gera um alerta
D) A exclusao e bloqueada apenas para usuarios sem role Owner

<details>
<summary>Ver resposta</summary>

**Resposta: B) A exclusao e bloqueada - locks sobrescrevem permissoes de usuario**

Resource Locks **sobrescrevem quaisquer permissoes de usuario**, incluindo o role Owner. Para excluir o recurso, o lock precisa ser removido primeiro. Isso protege contra exclusoes acidentais mesmo por administradores.

</details>

---

# Bloco 3 - Azure Resources & IaC

**Origem:** Lab 03b - Manage Azure Resources by Using ARM Templates
**Resource Groups utilizados:** `az104-rg3`

## Contexto

Com identidade e governanca configurados, voce vai aprender a automatizar o provisionamento de recursos usando diferentes metodos: portal, ARM Templates (PowerShell e CLI) e Bicep. Isso reduz overhead administrativo, erros humanos e aumenta consistencia.

## Diagrama

```
┌────────────────────────────────────────────┐
│                  az104-rg3                 │
│                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │az104-    │  │az104-    │  │az104-    │  │
│  │disk1     │  │disk2     │  │disk3     │  │
│  │(Portal)  │  │(ARM      │  │(ARM +    │  │
│  │          │  │ Portal)  │  │PowerShell│  │
│  └──────────┘  └──────────┘  └──────────┘  │
│                                            │
│  ┌──────────┐  ┌──────────┐                │
│  │az104-    │  │az104-    │                │
│  │disk4     │  │disk5     │                │
│  │(ARM +    │  │(Bicep +  │                │
│  │ CLI)     │  │ CLI)     │                │
│  └──────────┘  └──────────┘                │
└────────────────────────────────────────────┘
```

---

### Task 3.1: Criar managed disk e exportar ARM template

Voce cria um managed disk pelo portal e exporta o template gerado para reutilizar.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Disks**

3. Clique em **Create** e preencha:

   | Setting           | Value                                     |
   | ----------------- | ----------------------------------------- |
   | Subscription      | *sua subscription*                        |
   | Resource Group    | `az104-rg3` (crie se necessario)          |
   | Disk name         | `az104-disk1`                             |
   | Region            | **East US**                               |
   | Availability zone | **No infrastructure redundancy required** |
   | Source type       | **None**                                  |
   | Performance       | **Standard HDD** (altere o tamanho)       |
   | Size              | **32 GiB**                                |

4. Clique em **Review + Create** > **Create**

5. Apos o deploy, selecione **Go to resource**

6. No blade **Automation**, selecione **Export template**

7. Revise as abas **Template** e **Parameters**

8. Em cada aba, clique em **Download** para salvar os arquivos JSON localmente

   > **Conceito:** Voce pode exportar o ARM template de qualquer recurso ou resource group. O template descreve a infraestrutura de forma declarativa em JSON.

---

### Task 3.2: Editar template e fazer deploy de az104-disk2 via portal

Voce reutiliza o template exportado para criar um segundo disco.

1. Pesquise e selecione **Deploy a custom template**

2. Selecione **Build your own template in the editor**

3. Clique em **Load file** e carregue o arquivo **template.json** baixado

4. No editor, faca estas alteracoes:
   - Altere `disks_az104_disk1_name` para `disk_name` (**dois** locais)
   - Altere `az104-disk1` para `az104-disk2` (**um** local)

5. Clique em **Save**

6. Selecione **Edit parameters** > **Load file** > carregue **parameters.json**

7. Altere `disks_az104_disk1_name` para `disk_name` (**um** local)

8. Clique em **Save**

9. Complete as configuracoes de deployment:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource Group | `az104-rg3`        |
   | Region         | **(US) East US**   |
   | Disk_name      | `az104-disk2`      |

10. Clique em **Review + Create** > **Create**

11. Selecione **Go to resource** e verifique que **az104-disk2** foi criado

12. Va para o resource group **az104-rg3** > blade **Settings** > **Deployments** para ver o historico

---

### Task 3.3: Configurar Cloud Shell e deploy de az104-disk3 via PowerShell

Voce configura o Azure Cloud Shell e usa PowerShell para fazer deploy do template.

1. Clique no icone do **Cloud Shell** no canto superior direito do portal (ou acesse `https://shell.azure.com`)

2. Quando perguntado, selecione **PowerShell**

3. Na tela **Getting started**, selecione **Mount storage account**, selecione sua subscription e clique em **Apply**

4. Selecione **I want to create a storage account** > **Next** e preencha:

   | Setting         | Value                                                      |
   | --------------- | ---------------------------------------------------------- |
   | Resource Group  | **az104-rg3**                                              |
   | Region          | *sua regiao*                                               |
   | Storage account | *nome unico globalmente (3-24 chars, lowercase + numeros)* |
   | File share      | `fs-cloudshell`                                            |

5. Clique em **Create** (aguarde o provisionamento)

6. Selecione **Settings** (barra superior) > **Go to classic version**

7. Clique em **Upload/Download files** > **Upload** e carregue ambos os arquivos (template.json e parameters.json)

8. Clique no icone do **Editor** (chaves) e navegue ate o arquivo template.json

9. Altere o nome do disco para `az104-disk3`. Salve com **Ctrl+S**

10. Execute o deploy:

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName az104-rg3 -TemplateFile template.json -TemplateParameterFile parameters.json
    ```

11. Verifique que o **ProvisioningState** e **Succeeded**

12. Confirme que o disco foi criado:

    ```powershell
    Get-AzDisk | ft
    ```

---

### Task 3.4: Deploy via CLI (Bash) de az104-disk4

Voce alterna para Bash e usa o Azure CLI para fazer deploy.

1. No Cloud Shell, selecione **Bash** e **confirme** a troca

2. Verifique que os arquivos estao disponiveis:

   ```sh
   ls
   ```

3. Abra o **Editor** e altere o nome do disco no template.json para `az104-disk4`. Salve com **Ctrl+S**

4. Execute o deploy:

   ```sh
   az deployment group create --resource-group az104-rg3 --template-file template.json --parameters parameters.json
   ```

5. Verifique que o **ProvisioningState** e **Succeeded**

6. Confirme que o disco foi criado:

   ```sh
   az disk list --resource-group az104-rg3 --output table
   ```

---

### Task 3.5: Deploy via Bicep de az104-disk5

Voce usa um arquivo Bicep para criar o quinto managed disk.

1. Continue no **Cloud Shell** (Bash)

2. Clique em **Manage files** > **Upload** e carregue o arquivo `azuredeploydisk.bicep`

   > **Nota:** O arquivo Bicep esta em `Allfiles/Labs/03/azuredeploydisk.bicep` no repositorio do lab

   **Conteudo original do arquivo `azuredeploydisk.bicep`:**

   ```bicep
   @description('Name of the managed disk to be copied')
   param managedDiskName string = 'diskname'

   @description('Disk size in GiB')
   @minValue(4)
   @maxValue(65536)
   param diskSizeinGiB int = 8

   @description('Disk IOPS value')
   @minValue(100)
   @maxValue(160000)
   param diskIopsReadWrite int = 100

   @description('Disk throughput value in MBps')
   @minValue(1)
   @maxValue(2000)
   param diskMbpsReadWrite int = 10

   @description('Location for all resources.')
   param location string = resourceGroup().location

   resource managedDisk 'Microsoft.Compute/disks@2020-09-30' = {
     name: managedDiskName
     location: location
     sku: {
       name: 'UltraSSD_LRS'
     }
     properties: {
       creationData: {
         createOption: 'Empty'
       }
       diskSizeGB: diskSizeinGiB
       diskIOPSReadWrite: diskIopsReadWrite
       diskMBpsReadWrite: diskMbpsReadWrite
     }
   }
   ```

3. Abra o **Editor** e selecione o arquivo **azuredeploydisk.bicep**

4. Revise a estrutura do Bicep. Observe como o recurso de disco e definido de forma mais concisa que ARM JSON.

5. Faca as seguintes alteracoes:
   - Linha 2: altere **managedDiskName** para `az104-disk5`
   - Linha 26: altere **sku name** para `StandardSSD_LRS`
   - Linha 7: altere **diskSizeinGiB** para `32`

6. Salve com **Ctrl+S**

7. Execute o deploy:

   ```sh
   az deployment group create --resource-group az104-rg3 --template-file azuredeploydisk.bicep
   ```

8. Confirme que o disco foi criado:

   ```sh
   az disk list --resource-group az104-rg3 --output table
   ```

   > **Resultado:** Voce criou 5 managed disks, cada um por um metodo diferente: Portal, ARM via Portal, ARM via PowerShell, ARM via CLI e Bicep.

---

## Modo Desafio - Bloco 3

- [ ] Criar managed disk `az104-disk1` (Standard HDD, 32 GiB) via portal
- [ ] Exportar ARM template do disco
- [ ] Editar template e fazer deploy de `az104-disk2` via Custom deployment no portal
- [ ] Configurar Cloud Shell (PowerShell) e fazer deploy de `az104-disk3` via `New-AzResourceGroupDeployment`
- [ ] Trocar para Bash e fazer deploy de `az104-disk4` via `az deployment group create`
- [ ] Fazer deploy de `az104-disk5` via Bicep (StandardSSD_LRS, 32 GiB)
- [ ] Verificar todos os 5 discos no resource group

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Qual comando do Azure PowerShell voce usa para fazer deploy de um ARM template em um Resource Group?**

A) `Set-AzResourceGroup`
B) `New-AzResourceGroupDeployment`
C) `New-AzDeployment`
D) `Deploy-AzTemplate`

<details>
<summary>Ver resposta</summary>

**Resposta: B) New-AzResourceGroupDeployment**

- `New-AzResourceGroupDeployment` faz deploy no nivel de Resource Group
- `New-AzDeployment` (ou `New-AzSubscriptionDeployment`) faz deploy no nivel de Subscription
- `Set-AzResourceGroup` modifica propriedades do RG, nao faz deploy
- `Deploy-AzTemplate` nao existe

</details>

### Questao 3.2
**Qual a principal diferenca entre ARM Templates (JSON) e Bicep?**

A) Bicep e uma linguagem interpretada, ARM e compilada
B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON
C) ARM Templates suportam mais tipos de recursos que Bicep
D) Bicep requer uma runtime separada no Azure

<details>
<summary>Ver resposta</summary>

**Resposta: B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON**

Bicep e uma DSL (Domain-Specific Language) que compila transparentemente para ARM JSON. Oferece sintaxe mais limpa, type safety e suporte a modulos. Ambos suportam exatamente os mesmos tipos de recursos, pois Bicep e apenas uma camada de abstracao sobre ARM.

</details>

### Questao 3.3
**Voce precisa fazer deploy de um ARM template no nivel de uma Subscription (nao em um Resource Group). Qual comando CLI voce usa?**

A) `az deployment group create`
B) `az deployment sub create`
C) `az deployment subscription create`
D) `az deployment create`

<details>
<summary>Ver resposta</summary>

**Resposta: B) `az deployment sub create`**

Os escopos de deployment no CLI sao:
- `az deployment group create` → Resource Group
- `az deployment sub create` → Subscription
- `az deployment mg create` → Management Group
- `az deployment tenant create` → Tenant

</details>

---

# Bloco 4 - Virtual Networking

**Origem:** Lab 04 - Implement Virtual Networking
**Resource Groups utilizados:** `az104-rg4`

## Contexto

Com a infraestrutura base provisionada, voce vai configurar a rede virtual da organizacao: VNets com subnets planejadas, seguranca com NSG e ASG, e resolucao de nomes com DNS publico e privado.

## Diagrama

```
┌──────────────────────────────────────────────────────────────┐
│                        az104-rg4                             │
│                                                              │
│  ┌──────────────────────────┐  ┌───────────────────────────┐ │
│  │  CoreServicesVnet        │  │  ManufacturingVnet        │ │
│  │  10.20.0.0/16            │  │  10.30.0.0/16             │ │
│  │                          │  │                           │ │
│  │  ┌────────────────────┐  │  │  ┌─────────────────────┐  │ │
│  │  │SharedServicesSubnet│  │  │  │ SensorSubnet1       │  │ │
│  │  │ 10.20.10.0/24      │  │  │  │ 10.30.20.0/24       │  │ │
│  │  │ ← NSG: myNSGSecure │  │  │  └─────────────────────┘  │ │
│  │  └────────────────────┘  │  │  ┌─────────────────────┐  │ │
│  │  ┌────────────────────┐  │  │  │ SensorSubnet2       │  │ │
│  │  │ DatabaseSubnet     │  │  │  │ 10.30.21.0/24       │  │ │
│  │  │ 10.20.20.0/24      │  │  │  └─────────────────────┘  │ │
│  │  └────────────────────┘  │  └───────────────────────────┘ │
│  └──────────────────────────┘                                │
│                                                              │
│  ┌──────────────┐  ┌──────────────────────────────────────┐  │
│  │ ASG: asg-web │  │ DNS Zones:                           │  │
│  └──────────────┘  │ • Public:  contoso.com (A: www)      │  │
│                    │ • Private: private.contoso.com       │  │
│                    │   └─ Link: ManufacturingVnet         │  │
│                    └──────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar VNet CoreServicesVnet via portal

Voce cria a VNet principal com planejamento de enderecamento para crescimento futuro.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Virtual Networks**

3. Clique em **Create** e preencha a aba **Basics**:

   | Setting        | Value                            |
   | -------------- | -------------------------------- |
   | Resource Group | `az104-rg4` (crie se necessario) |
   | Name           | `CoreServicesVnet`               |
   | Region         | **(US) East US**                 |

4. Va para a aba **IP Addresses**:

   | Setting            | Value                               |
   | ------------------ | ----------------------------------- |
   | IPv4 address space | Substitua pelo valor `10.20.0.0/16` |

5. **Delete** a subnet default (se existir)

6. Clique em **+ Add a subnet** e crie as subnets:

   | Subnet                   | Setting          | Value                  |
   | ------------------------ | ---------------- | ---------------------- |
   | **SharedServicesSubnet** | Subnet name      | `SharedServicesSubnet` |
   |                          | Starting address | `10.20.10.0`           |
   |                          | Size             | `/24`                  |
   | **DatabaseSubnet**       | Subnet name      | `DatabaseSubnet`       |
   |                          | Starting address | `10.20.20.0`           |
   |                          | Size             | `/24`                  |

   > **Conceito:** Cinco IPs sao sempre reservados em cada subnet Azure: network address, gateway, 3 IPs para uso interno do Azure. Considere isso no planejamento.

7. Clique em **Review + create** > **Create**

8. Selecione **Go to resource** e verifique o **Address space** e as **Subnets**

9. No blade **Automation**, selecione **Export template** e **Download** tanto o template quanto os parameters (voce usara na proxima task)

---

### Task 4.2: Criar VNet ManufacturingVnet via ARM template

Voce reutiliza o template exportado, editando para criar uma segunda VNet.

1. Localize os arquivos **template.json** e **parameters.json** baixados

   > **Voce pode:** (A) exportar o template da CoreServicesVnet criada na Task 4.1 e editar manualmente, ou (B) usar o template pronto abaixo. Ambos os caminhos chegam ao mesmo resultado.

   **Se escolher o caminho A** — edite o template exportado fazendo estas substituicoes:
   - `CoreServicesVnet` → `ManufacturingVnet` (todas as ocorrencias)
   - `10.20.0.0` → `10.30.0.0` (todas as ocorrencias)
   - `SharedServicesSubnet` → `SensorSubnet1` (todas as ocorrencias)
   - `10.20.10.0/24` → `10.30.20.0/24` (todas as ocorrencias)
   - `DatabaseSubnet` → `SensorSubnet2` (todas as ocorrencias)
   - `10.20.20.0/24` → `10.30.21.0/24` (todas as ocorrencias)

   **Se escolher o caminho B** — use os templates prontos abaixo:

   **`template.json` (ManufacturingVnet):**

   ```json
   {
       "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
       "contentVersion": "1.0.0.0",
       "parameters": {
           "virtualNetworks_ManufacturingVnet_name": {
               "defaultValue": "ManufacturingVnet",
               "type": "String"
           }
       },
       "variables": {},
       "resources": [
           {
               "type": "Microsoft.Network/virtualNetworks",
               "apiVersion": "2023-05-01",
               "name": "[parameters('virtualNetworks_ManufacturingVnet_name')]",
               "location": "eastus",
               "properties": {
                   "addressSpace": {
                       "addressPrefixes": [
                           "10.30.0.0/16"
                       ]
                   },
                   "encryption": {
                       "enabled": false,
                       "enforcement": "AllowUnencrypted"
                   },
                   "subnets": [
                       {
                           "name": "SensorSubnet1",
                           "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_ManufacturingVnet_name'), 'SensorSubnet1')]",
                           "properties": {
                               "addressPrefixes": [
                                   "10.30.20.0/24"
                               ],
                               "delegations": [],
                               "privateEndpointNetworkPolicies": "Disabled",
                               "privateLinkServiceNetworkPolicies": "Enabled",
                               "defaultOutboundAccess": true
                           },
                           "type": "Microsoft.Network/virtualNetworks/subnets"
                       },
                       {
                           "name": "SensorSubnet2",
                           "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('virtualNetworks_ManufacturingVnet_name'), 'SensorSubnet2')]",
                           "properties": {
                               "addressPrefixes": [
                                   "10.30.21.0/24"
                               ],
                               "delegations": [],
                               "privateEndpointNetworkPolicies": "Disabled",
                               "privateLinkServiceNetworkPolicies": "Enabled",
                               "defaultOutboundAccess": true
                           },
                           "type": "Microsoft.Network/virtualNetworks/subnets"
                       }
                   ],
                   "virtualNetworkPeerings": [],
                   "enableDdosProtection": false
               }
           },
           {
               "type": "Microsoft.Network/virtualNetworks/subnets",
               "apiVersion": "2023-05-01",
               "name": "[concat(parameters('virtualNetworks_ManufacturingVnet_name'), '/SensorSubnet1')]",
               "dependsOn": [
                   "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_ManufacturingVnet_name'))]"
               ],
               "properties": {
                   "addressPrefixes": [
                       "10.30.20.0/24"
                   ],
                   "delegations": [],
                   "privateEndpointNetworkPolicies": "Disabled",
                   "privateLinkServiceNetworkPolicies": "Enabled",
                   "defaultOutboundAccess": true
               }
           },
           {
               "type": "Microsoft.Network/virtualNetworks/subnets",
               "apiVersion": "2023-05-01",
               "name": "[concat(parameters('virtualNetworks_ManufacturingVnet_name'), '/SensorSubnet2')]",
               "dependsOn": [
                   "[resourceId('Microsoft.Network/virtualNetworks', parameters('virtualNetworks_ManufacturingVnet_name'))]"
               ],
               "properties": {
                   "addressPrefixes": [
                       "10.30.21.0/24"
                   ],
                   "delegations": [],
                   "privateEndpointNetworkPolicies": "Disabled",
                   "privateLinkServiceNetworkPolicies": "Enabled",
                   "defaultOutboundAccess": true
               }
           }
       ]
   }
   ```

   **`parameters.json`:**

   ```json
   {
       "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
       "contentVersion": "1.0.0.0",
       "parameters": {
           "virtualNetworks_ManufacturingVnet_name": {
               "value": "ManufacturingVnet"
           }
       }
   }
   ```

2. No portal, pesquise **Deploy a custom template**

3. Selecione **Build your own template in the editor** > **Load file** > selecione o template (editado ou pronto) > **Save**

4. Selecione **Edit parameters** > **Load file** > selecione o parameters (editado ou pronto) > **Save**

5. Verifique que o resource group **az104-rg4** esta selecionado

6. Clique em **Review + create** > **Create**

7. Aguarde o deploy e confirme que a VNet Manufacturing e suas subnets foram criadas

---

### Task 4.3: Criar ASG e NSG

Voce cria um Application Security Group e um Network Security Group para controlar trafego.

**Criar o ASG:**

1. Pesquise e selecione **Application security groups**

2. Clique em **Create**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource group | **az104-rg4**      |
   | Name           | `asg-web`          |
   | Region         | **East US**        |

3. Clique em **Review + create** > **Create**

**Criar o NSG:**

4. Pesquise e selecione **Network security groups**

5. Clique em **+ Create**:

   | Setting        | Value              |
   | -------------- | ------------------ |
   | Subscription   | *sua subscription* |
   | Resource group | **az104-rg4**      |
   | Name           | `myNSGSecure`      |
   | Region         | **East US**        |

6. Clique em **Review + create** > **Create**

7. Selecione **Go to resource**

---

### Task 4.4: Associar NSG a subnet + regras inbound/outbound

1. No NSG **myNSGSecure**, em **Settings**, clique em **Subnets** > **Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg4)** |
   | Subnet          | **SharedServicesSubnet**         |

2. Clique em **OK**

**Regra Inbound - Allow ASG:**

3. Em **Settings**, selecione **Inbound security rules**

4. Revise as regras default (apenas VNets e Load Balancers sao permitidos)

5. Clique em **+ Add**:

   | Setting                 | Value                          |
   | ----------------------- | ------------------------------ |
   | Source                  | **Application security group** |
   | Source ASG              | **asg-web**                    |
   | Source port ranges      | `*`                            |
   | Destination             | **Any**                        |
   | Service                 | **Custom**                     |
   | Destination port ranges | `80,443`                       |
   | Protocol                | **TCP**                        |
   | Action                  | **Allow**                      |
   | Priority                | `100`                          |
   | Name                    | `AllowASG`                     |

6. Clique em **Add**

**Regra Outbound - Deny Internet:**

7. Selecione **Outbound security rules**

8. Note a regra **AllowInternetOutBound** (priority 65001, nao pode ser deletada)

9. Clique em **+ Add**:

   | Setting                 | Value                  |
   | ----------------------- | ---------------------- |
   | Source                  | **Any**                |
   | Source port ranges      | `*`                    |
   | Destination             | **Service tag**        |
   | Destination service tag | **Internet**           |
   | Service                 | **Custom**             |
   | Destination port ranges | `*`                    |
   | Protocol                | **Any**                |
   | Action                  | **Deny**               |
   | Priority                | `4096`                 |
   | Name                    | `DenyInternetOutbound` |

10. Clique em **Add**

    > **Conceito:** NSG rules sao processadas por **priority** (menor numero = maior prioridade). A regra DenyInternetOutbound (4096) tem prioridade maior que AllowInternetOutBound (65001), entao bloqueia o trafego para a Internet.

---

### Task 4.5: Criar zona DNS publica com registro A

1. Pesquise e selecione **DNS zones**

2. Clique em **+ Create**:

   | Setting        | Value                                          |
   | -------------- | ---------------------------------------------- |
   | Subscription   | *sua subscription*                             |
   | Resource group | **az104-rg4**                                  |
   | Name           | `contoso.com` (ajuste se ja estiver reservado) |
   | Region         | **East US**                                    |

3. Clique em **Review + create** > **Create**

4. Selecione **Go to resource**

5. No blade **Overview**, **copie** o endereco de um dos quatro name servers (voce precisara para o nslookup)

6. Expanda o blade **DNS Management** e selecione **Recordsets** > **+ Add**:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `www`      |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

7. Clique em **Add**

8. Teste a resolucao via terminal/prompt:

   ```sh
   nslookup www.contoso.com <name-server-copiado>
   ```

9. Verifique que o hostname resolve para `10.1.1.4`

---

### Task 4.6: Criar zona DNS privada com virtual network link

1. Pesquise e selecione **Private dns zones**

2. Clique em **+ Create**:

   | Setting        | Value                 |
   | -------------- | --------------------- |
   | Subscription   | *sua subscription*    |
   | Resource group | **az104-rg4**         |
   | Name           | `private.contoso.com` |
   | Region         | **East US**           |

3. Clique em **Review + create** > **Create**

4. Selecione **Go to resource**

5. Note que nao ha name servers no **Overview** (zona privada)

6. Expanda **DNS Management** > **Virtual network links** e configure:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Link name       | `manufacturing-link` |
   | Virtual network | `ManufacturingVnet`  |

7. Clique em **Create** e aguarde

8. Em **DNS Management** > **+ Recordsets**, adicione um registro:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `sensorvm` |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

---

## Modo Desafio - Bloco 4

- [ ] Criar VNet `CoreServicesVnet` (10.20.0.0/16) com subnets SharedServicesSubnet (10.20.10.0/24) e DatabaseSubnet (10.20.20.0/24)
- [ ] Exportar template e criar VNet `ManufacturingVnet` (10.30.0.0/16) com subnets SensorSubnet1 e SensorSubnet2 via ARM
- [ ] Criar ASG `asg-web` e NSG `myNSGSecure`
- [ ] Associar NSG a SharedServicesSubnet
- [ ] Criar regra inbound AllowASG (80,443 TCP, priority 100)
- [ ] Criar regra outbound DenyInternetOutbound (priority 4096)
- [ ] Criar zona DNS publica `contoso.com` com registro A `www` → 10.1.1.4
- [ ] Testar com nslookup
- [ ] Criar zona DNS privada `private.contoso.com` com link para ManufacturingVnet e registro A `sensorvm`

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Voce tem um NSG com as seguintes regras inbound:
- Rule A: Priority 100, Allow, Port 80
- Rule B: Priority 200, Deny, Port 80
- Rule C: Priority 300, Allow, Port 80

Um pacote chega na porta 80. O que acontece?**

A) O pacote e negado pela Rule B
B) O pacote e permitido pela Rule A
C) O pacote e avaliado por todas as regras e a ultima vence
D) O pacote e permitido porque ha mais regras Allow que Deny

<details>
<summary>Ver resposta</summary>

**Resposta: B) O pacote e permitido pela Rule A**

NSG rules sao processadas em ordem de **priority** (menor numero primeiro). A Rule A (priority 100) e a primeira a ser avaliada e como permite o trafego, o pacote e aceito. As regras B e C nao sao avaliadas.

</details>

### Questao 4.2
**Quantos enderecos IP utilizaveis existem em uma subnet /24 no Azure?**

A) 256
B) 254
C) 251
D) 250

<details>
<summary>Ver resposta</summary>

**Resposta: C) 251**

Uma subnet /24 tem 256 enderecos totais. O Azure reserva **5 enderecos** em cada subnet:
- x.x.x.0 → Network address
- x.x.x.1 → Gateway
- x.x.x.2, x.x.x.3 → Azure DNS
- x.x.x.255 → Broadcast

Portanto: 256 - 5 = **251** enderecos utilizaveis.

</details>

### Questao 4.3
**Qual e a diferenca entre um NSG e um ASG?**

A) NSG filtra trafego por IP, ASG agrupa VMs logicamente para aplicar regras NSG
B) ASG substitui o NSG em cenarios de producao
C) NSG funciona no nivel de VNet, ASG no nivel de subnet
D) NSG e ASG sao intercambiaveis

<details>
<summary>Ver resposta</summary>

**Resposta: A) NSG filtra trafego por IP, ASG agrupa VMs logicamente para aplicar regras NSG**

O **ASG** permite agrupar NICs de VMs logicamente (ex: web servers, db servers) e usar esses grupos como source/destination em regras NSG. Isso simplifica o gerenciamento de regras quando voce tem muitas VMs, evitando gerenciar IPs individuais.

</details>

### Questao 4.4
**Voce criou uma zona DNS publica no Azure para `contoso.com`. Para que o dominio funcione na internet, o que mais voce precisa fazer?**

A) Nada, o Azure configura automaticamente
B) Atualizar os name servers no registrador de dominio para apontar para os name servers do Azure
C) Criar um CNAME record apontando para o Azure
D) Configurar uma VPN entre o Azure e o registrador

<details>
<summary>Ver resposta</summary>

**Resposta: B) Atualizar os name servers no registrador de dominio para apontar para os name servers do Azure**

O Azure DNS hospeda a zona mas **nao e um registrador de dominios**. Voce precisa ir ao seu registrador (GoDaddy, Namecheap, etc.) e atualizar os NS records para apontar para os name servers do Azure (ex: ns1-01.azure-dns.com).

</details>

### Questao 4.5
**Qual a principal diferenca entre Azure DNS public zones e private zones?**

A) Public zones sao gratuitas, private zones sao pagas
B) Public zones resolvem nomes na internet, private zones resolvem apenas dentro de VNets linkadas
C) Private zones suportam mais tipos de registro que public zones
D) Public zones requerem VPN, private zones nao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Public zones resolvem nomes na internet, private zones resolvem apenas dentro de VNets linkadas**

- **Public DNS zones:** resolvem nomes acessiveis pela internet. Requerem que o dominio tenha NS records apontando para o Azure.
- **Private DNS zones:** resolvem nomes apenas para recursos dentro das VNets que possuem virtual network links configurados. Nao sao acessiveis pela internet.

</details>

---

# Bloco 5 - Intersite Connectivity

**Origem:** Lab 05 - Implement Intersite Connectivity
**Resource Groups utilizados:** `az104-rg5`

## Contexto

Voce agora precisa conectar as diferentes areas da empresa. Vai criar VMs em VNets separadas, comprovar que por padrao nao ha conectividade, configurar VNet Peering para habilitar a comunicacao, e criar rotas customizadas para controlar o fluxo de trafego.

> **Atencao - VNets com mesmos nomes mas IPs diferentes:** Este bloco cria VNets chamadas `CoreServicesVnet` e `ManufacturingVnet` no resource group `az104-rg5`, com address spaces **diferentes** do Bloco 4 (`az104-rg4`). Sao recursos totalmente separados. Veja a comparacao:
>
> | VNet | Bloco 4 (az104-rg4) | Bloco 5 (az104-rg5) |
> | --- | --- | --- |
> | CoreServicesVnet | 10.20.0.0/16 | 10.0.0.0/16 |
> | ManufacturingVnet | 10.30.0.0/16 | 172.16.0.0/16 |

> **Nota importante:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

## Diagrama

```
┌───────────────────────────────────────────────────────────────┐
│                         az104-rg5                             │
│                                                               │
│  ┌────────────────────────┐     ┌───────────────────────────┐ │
│  │  CoreServicesVnet      │     │  ManufacturingVnet        │ │
│  │  10.0.0.0/16           │     │  172.16.0.0/16            │ │
│  │                        │     │                           │ │
│  │  ┌──────────────────┐  │     │  ┌─────────────────────┐  │ │
│  │  │ Core subnet      │  │     │  │ Manufacturing       │  │ │
│  │  │ 10.0.0.0/24      │  │ ←──peering──→ │ 172.16.0.0/24│  │ │
│  │  │                  │  │     │  │                     │  │ │
│  │  │ CoreServicesVM   │  │     │  │ ManufacturingVM     │  │ │
│  │  └──────────────────┘  │     │  └─────────────────────┘  │ │
│  │  ┌──────────────────┐  │     └───────────────────────────┘ │
│  │  │ perimeter        │  │                                   │
│  │  │ 10.0.1.0/24      │  │     ┌───────────────────────────┐ │
│  │  │ (NVA: 10.0.1.7)  │  │     │ Route Table:              │ │
│  │  └──────────────────┘  │     │ rt-CoreServices           │ │
│  └────────────────────────┘     │ PerimetertoCore route     │ │
│                                 │ → Core subnet             │ │
│                                 └───────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

---

### Task 5.1: Criar CoreServicesVM em nova VNet

Voce cria a primeira VM com sua propria VNet (note: IPs diferentes do Bloco 4).

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Virtual Machines**

3. Clique em **Create** > **Virtual machine**

4. Preencha a aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `az104-rg5` (crie se necessario)              |
   | Virtual machine name | `CoreServicesVM`                              |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_DS2_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

5. Clique em **Next: Disks >** (aceite defaults)

6. Clique em **Next: Networking >**

7. Para Virtual network, clique em **Create new** e configure:

   | Setting              | Value              |
   | -------------------- | ------------------ |
   | Name                 | `CoreServicesVnet` |
   | Address range        | `10.0.0.0/16`      |
   | Subnet Name          | `Core`             |
   | Subnet address range | `10.0.0.0/24`      |

8. Clique em **OK**

9. Va para a aba **Monitoring** e selecione **Disable** para Boot diagnostics

10. Clique em **Review + create** > **Create**

11. **Nao precisa esperar** - continue para a proxima task

---

### Task 5.2: Criar ManufacturingVM em nova VNet

1. Pesquise e selecione **Virtual Machines**

2. Clique em **Create** > **Virtual machine**

3. Preencha a aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `az104-rg5`                                   |
   | Virtual machine name | `ManufacturingVM`                             |
   | Region               | **(US) East US**                              |
   | Security type        | **Standard**                                  |
   | Availability options | No infrastructure redundancy required         |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_DS2_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

4. Clique em **Next: Disks >** (aceite defaults) > **Next: Networking >**

5. Para Virtual network, clique em **Create new**:

   | Setting              | Value               |
   | -------------------- | ------------------- |
   | Name                 | `ManufacturingVnet` |
   | Address range        | `172.16.0.0/16`     |
   | Subnet Name          | `Manufacturing`     |
   | Subnet address range | `172.16.0.0/24`     |

6. Clique em **OK**

7. Va para a aba **Monitoring** > **Disable** Boot diagnostics

8. Clique em **Review + create** > **Create**

9. **Aguarde ambas as VMs serem provisionadas** antes de continuar

---

### Task 5.3: Network Watcher - Connection Troubleshoot

Voce verifica que por padrao, VMs em VNets diferentes NAO se comunicam.

1. Pesquise e selecione **Network Watcher**

2. Em Network diagnostic tools, selecione **Connection troubleshoot**

3. Preencha:

   | Setting              | Value                        |
   | -------------------- | ---------------------------- |
   | Source type          | **Virtual machine**          |
   | Virtual machine      | **CoreServicesVM**           |
   | Destination type     | **Select a virtual machine** |
   | Virtual machine      | **ManufacturingVM**          |
   | Preferred IP Version | **Both**                     |
   | Protocol             | **TCP**                      |
   | Destination port     | `3389`                       |

4. Clique em **Run diagnostic tests**

5. Aguarde os resultados (pode levar alguns minutos)

6. **Resultado esperado:** Connectivity test mostra **Unreachable**

   > **Conceito:** Por padrao, recursos em VNets diferentes NAO podem se comunicar. Voce precisa configurar VNet Peering, VPN Gateway ou ExpressRoute para habilitar conectividade.

---

### Task 5.4: Configurar VNet Peering bidirecional

Voce configura peering entre as duas VNets para habilitar comunicacao.

1. No portal, selecione a VNet **CoreServicesVnet**

2. Em **Settings**, selecione **Peerings**

3. Clique em **+ Add** e configure:

   | Setting                                                                        | Value                                   |
   | ------------------------------------------------------------------------------ | --------------------------------------- |
   | **This virtual network**                                                       |                                         |
   | Peering link name                                                              | `CoreServicesVnet-to-ManufacturingVnet` |
   | Allow 'CoreServicesVnet' to access 'ManufacturingVnet'                         | **selected** (default)                  |
   | Allow 'CoreServicesVnet' to receive forwarded traffic from 'ManufacturingVnet' | **selected**                            |
   | **Remote virtual network**                                                     |                                         |
   | Peering link name                                                              | `ManufacturingVnet-to-CoreServicesVnet` |
   | Virtual network                                                                | **ManufacturingVnet (az104-rg5)**       |
   | Allow 'ManufacturingVnet' to access 'CoreServicesVnet'                         | **selected** (default)                  |
   | Allow 'ManufacturingVnet' to receive forwarded traffic from 'CoreServicesVnet' | **selected**                            |

4. Clique em **Add**

5. Em **Peerings** do CoreServicesVnet, verifique que o peering **CoreServicesVnet-to-ManufacturingVnet** esta listado. **Refresh** ate o **Peering status** ser **Connected**

6. Navegue para **ManufacturingVnet** > **Peerings** e verifique que **ManufacturingVnet-to-CoreServicesVnet** tambem esta **Connected**

   > **Conceito:** VNet Peering e NAO transitivo. Se VNet A esta peered com VNet B, e VNet B com VNet C, VNet A NAO se comunica com VNet C automaticamente.

---

### Task 5.5: Testar conexao via Run Command + Test-NetConnection

1. Pesquise e selecione a VM **CoreServicesVM**

2. No blade **Overview** > secao **Networking**, **anote o Private IP address**

3. Navegue para a VM **ManufacturingVM**

4. No blade **Operations**, selecione **Run command**

5. Selecione **RunPowerShellScript** e execute:

   ```powershell
   Test-NetConnection <CoreServicesVM-private-IP> -port 3389
   ```

6. Aguarde o resultado (pode levar alguns minutos)

7. **Resultado esperado:** `TcpTestSucceeded: True`

   > O peering esta funcionando! As VMs agora se comunicam pela rede backbone da Microsoft.

---

### Task 5.6: Criar subnet perimeter, Route Table e custom route

Voce cria uma rota customizada para direcionar trafego atraves de um Network Virtual Appliance (NVA).

**Criar subnet perimeter:**

1. Pesquise e selecione **CoreServicesVnet**

2. Selecione **Subnets** > **+ Subnet**:

   | Setting          | Value         |
   | ---------------- | ------------- |
   | Name             | `perimeter`   |
   | Starting address | `10.0.1.0/24` |

3. Clique em **Add**

**Criar Route Table:**

4. Pesquise e selecione **Route tables** > **+ Create**:

   | Setting                  | Value              |
   | ------------------------ | ------------------ |
   | Subscription             | *sua subscription* |
   | Resource group           | `az104-rg5`        |
   | Region                   | **East US**        |
   | Name                     | `rt-CoreServices`  |
   | Propagate gateway routes | **No**             |

5. Clique em **Review + create** > **Create**

**Criar custom route:**

6. Apos o deploy, navegue para **rt-CoreServices**

7. Expanda **Settings** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `PerimetertoCore`     |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.0.0.0/16`         |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.0.1.7`            |

8. Clique em **Add**

**Associar route table a subnet:**

9. Selecione **Subnets** > **+ Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg5)** |
   | Subnet          | **Core**                         |

10. Clique em **OK**

    > **Conceito:** User-Defined Routes (UDR) permitem controlar o fluxo de trafego substituindo as rotas do sistema. O **next hop** tipo Virtual appliance direciona o trafego para um NVA (firewall, proxy, etc.) para inspecao antes de chegar ao destino.

---

## Modo Desafio - Bloco 5

- [ ] Criar VM `CoreServicesVM` em VNet `CoreServicesVnet` (10.0.0.0/16, subnet Core 10.0.0.0/24)
- [ ] Criar VM `ManufacturingVM` em VNet `ManufacturingVnet` (172.16.0.0/16, subnet Manufacturing 172.16.0.0/24)
- [ ] Usar Network Watcher > Connection Troubleshoot para verificar que as VMs NAO se comunicam
- [ ] Configurar VNet Peering bidirecional entre as duas VNets
- [ ] Verificar Peering status = Connected em ambas as VNets
- [ ] Usar Run Command + Test-NetConnection para verificar que as VMs AGORA se comunicam (porta 3389)
- [ ] Criar subnet `perimeter` (10.0.1.0/24) na CoreServicesVnet
- [ ] Criar Route Table `rt-CoreServices` com rota `PerimetertoCore` (destino 10.0.0.0/16, next hop 10.0.1.7)
- [ ] Associar route table a subnet Core

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**VNet A tem peering com VNet B. VNet B tem peering com VNet C. VNet A consegue se comunicar com VNet C?**

A) Sim, o peering e transitivo
B) Nao, o peering NAO e transitivo - voce precisa criar peering direto entre A e C
C) Sim, mas apenas se o trafego forwarding estiver habilitado
D) Nao, voce precisa de um VPN Gateway

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, o peering NAO e transitivo**

VNet Peering **nao e transitivo**. Se voce precisa de conectividade entre A e C, deve criar um peering direto entre elas, ou usar uma topologia hub-spoke com um NVA/VPN Gateway no hub para rotear o trafego.

</details>

### Questao 5.2
**Voce criou uma User-Defined Route com next hop type "Virtual appliance" apontando para o IP 10.0.1.7. O que acontece se nao houver nenhum NVA nesse IP?**

A) O trafego e roteado normalmente ignorando a regra
B) O trafego e descartado (dropped)
C) O Azure cria automaticamente um NVA
D) O trafego e redirecionado para o gateway padrao

<details>
<summary>Ver resposta</summary>

**Resposta: B) O trafego e descartado (dropped)**

Se o next hop IP nao for alcancavel (nao existe NVA ou a VM esta desligada), o trafego e **descartado**. UDRs sobrescrevem as rotas do sistema, entao nao ha fallback para o roteamento padrao.

</details>

### Questao 5.3
**Qual ferramenta do Azure voce usa para diagnosticar problemas de conectividade entre duas VMs?**

A) Azure Monitor
B) Network Watcher - Connection Troubleshoot
C) Azure Advisor
D) Service Health

<details>
<summary>Ver resposta</summary>

**Resposta: B) Network Watcher - Connection Troubleshoot**

O **Network Watcher** oferece diversas ferramentas de diagnostico de rede, incluindo **Connection Troubleshoot** que testa conectividade entre dois endpoints. Tambem oferece IP flow verify, Next hop, NSG diagnostics, entre outros.

</details>

### Questao 5.4
**Qual e a vantagem do VNet Peering sobre uma VPN Gateway para conectar VNets na mesma regiao?**

A) Peering e mais seguro que VPN
B) Peering usa a rede backbone da Microsoft com baixa latencia e sem criptografia overhead
C) Peering permite conectar VNets em diferentes tenants, VPN nao
D) Peering suporta mais protocolos que VPN

<details>
<summary>Ver resposta</summary>

**Resposta: B) Peering usa a rede backbone da Microsoft com baixa latencia e sem criptografia overhead**

VNet Peering:
- Usa a rede backbone privada da Microsoft
- Baixa latencia, alta largura de banda
- Sem gateways, sem criptografia overhead
- Funciona entre regioes (Global VNet Peering)

VPN Gateway:
- Usa tunel criptografado sobre a internet (ou ExpressRoute)
- Maior latencia
- Necessario para cenarios hibridos (on-premises)
- Suporta conectividade transitiva em topologia hub-spoke

</details>

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos inesperados, especialmente as VMs do Bloco 5.

## Via Azure Portal

1. **Remover Resource Locks primeiro:**
   - Navegue para `az104-rg2` > **Settings** > **Locks** > Delete o lock `rg-lock`

2. **Deletar Resource Groups** (na seguinte ordem):
   - `az104-rg5` (VMs - PRIORIDADE, pois geram custo)
   - `az104-rg4` (VNets, DNS, NSG)
   - `az104-rg3` (Disks)
   - `az104-rg2` (Storage, Policies)

   Para cada RG: selecione o RG > **Delete resource group** > digite o nome > **Delete**

3. **Deletar Management Group:**
   - Pesquise **Management groups** > selecione `az104-mg1` > **Delete**

4. **Deletar usuarios e grupos do Entra ID:**
   - Microsoft Entra ID > **Users** > delete `az104-user1` e o guest user
   - Microsoft Entra ID > **Groups** > delete `IT Lab Administrators` e `helpdesk`

5. **Deletar policy assignments:**
   - Pesquise **Policy** > **Assignments** > delete todas as assignments criadas

6. **Deletar custom role:**
   - Management group > **Access control (IAM)** > **Roles** > encontre `Custom Support Request` > delete

## Via CLI (alternativa rapida)

```bash
# Resolver IDs dinamicamente (evita placeholders)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG2_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/az104-rg2"

# Deletar RGs (o mais importante - para de gerar custos)
az group delete --name az104-rg5 --yes --no-wait
az group delete --name az104-rg4 --yes --no-wait
az group delete --name az104-rg3 --yes --no-wait

# Remover lock antes de deletar az104-rg2
az lock delete --name rg-lock --resource-group az104-rg2
az group delete --name az104-rg2 --yes --no-wait

# Deletar Management Group
az account management-group subscription remove --name az104-mg1 --subscription "$SUBSCRIPTION_ID" 2>/dev/null
az account management-group delete --name az104-mg1

# Deletar policy assignments do RG2 por ID (mais robusto), filtrando os do lab
for ASSIGN_ID in $(az policy assignment list --scope "$RG2_SCOPE" --query "[?contains(displayName, 'Cost Center')].id" -o tsv); do
  az policy assignment delete --ids "$ASSIGN_ID"
done

# Deletar custom role
az role definition delete --name "Custom Support Request"

# Deletar usuarios e grupos do Entra ID
USER1_ID=$(az ad user list --filter "startsWith(userPrincipalName, 'az104-user1@')" --query "[0].id" -o tsv)
if [ -n "$USER1_ID" ]; then
  az ad user delete --id "$USER1_ID"
fi
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
az ad user list --filter "userType eq 'Guest'" --query "[].{id:id,mail:mail,displayName:displayName}" -o table
az ad group delete --group "IT Lab Administrators"
az ad group delete --group "helpdesk"
```

> **Nota:** Ao deletar `az104-rg3`, o storage account do Cloud Shell tambem sera removido. Na proxima vez que abrir o Cloud Shell, sera necessario reconfigurar o storage.

## Via PowerShell (alternativa)

```powershell
$subscriptionId = (Get-AzContext).Subscription.Id
$rg2Scope = "/subscriptions/$subscriptionId/resourceGroups/az104-rg2"

# Deletar RGs
Remove-AzResourceGroup -Name az104-rg5 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg4 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg3 -Force -AsJob

# Remover lock e RG
Remove-AzResourceLock -LockName rg-lock -ResourceGroupName az104-rg2
Remove-AzResourceGroup -Name az104-rg2 -Force -AsJob

# Deletar Management Group
Remove-AzManagementGroupSubscription -GroupName az104-mg1 -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
Remove-AzManagementGroup -GroupName az104-mg1

# Deletar policy assignments do RG2
Get-AzPolicyAssignment -Scope $rg2Scope |
Where-Object {
    $_.DisplayName -match 'Cost Center' -or $_.Properties.DisplayName -match 'Cost Center'
} | ForEach-Object {
    Remove-AzPolicyAssignment -Name $_.Name -Scope $rg2Scope -ErrorAction SilentlyContinue
}

# Deletar custom role
Remove-AzRoleDefinition -Name "Custom Support Request" -Force

# Deletar usuarios e grupos do Entra ID
$user1 = Get-AzADUser -Filter "startsWith(userPrincipalName,'az104-user1@')" | Select-Object -First 1
if ($user1) { Remove-AzADUser -ObjectId $user1.Id }
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
Get-AzADUser -Filter "userType eq 'Guest'" | Select-Object Id, Mail, DisplayName | Format-Table
Remove-AzADGroup -DisplayName "IT Lab Administrators"
Remove-AzADGroup -DisplayName "helpdesk"
```

---

# Key Takeaways Consolidados

## Bloco 1 - Identity
- Um **tenant** representa sua organizacao e gerencia uma instancia especifica dos servicos Microsoft cloud
- Microsoft Entra ID tem contas de **usuario** e **guest** (B2B), cada uma com nivel de acesso apropriado
- **Groups** combinam usuarios ou dispositivos. Tipos: Security e Microsoft 365
- Membership pode ser **Assigned** (manual) ou **Dynamic** (automatica, requer Premium P1/P2)
- **Usage location** e obrigatoria para atribuicao de licencas

## Bloco 2 - Governance & Compliance
- **Management Groups** organizam subscriptions logicamente e permitem heranca de RBAC e Policy
- Azure tem muitos **built-in roles**; voce pode criar **custom roles** baseados neles
- Roles sao definidos em JSON com **Actions**, **NotActions** e **AssignableScopes**
- **Azure Policy** estabelece convencoes: Deny bloqueia, Audit reporta, Modify altera automaticamente
- **Remediation tasks** corrigem recursos nao-conformes retroativamente
- **Resource Locks** protegem contra exclusao/modificacao acidental, sobrescrevendo permissoes
- Azure Policy e seguranca **pre-deployment**; RBAC e Locks sao **post-deployment**

## Bloco 3 - Azure Resources & IaC
- **ARM Templates** (JSON) permitem deploy declarativo e repetivel de infraestrutura
- Voce pode exportar templates de recursos existentes e reutiliza-los
- **Bicep** e uma DSL que compila para ARM JSON, oferecendo sintaxe mais concisa
- Metodos de deploy: Portal, PowerShell (`New-AzResourceGroupDeployment`), CLI (`az deployment group create`), Bicep
- Escopos de deploy: Resource Group, Subscription, Management Group, Tenant

## Bloco 4 - Virtual Networking
- **VNet** e a representacao da sua rede na cloud. Evite sobreposicao de ranges IP
- Cada **subnet** perde 5 IPs reservados pelo Azure
- **NSG** filtra trafego com regras processadas por **priority** (menor = maior prioridade)
- **ASG** agrupa VMs logicamente para simplificar regras NSG
- **Azure DNS** hospeda zonas publicas (internet) e privadas (VNets linkadas)
- DNS privado requer **Virtual Network Link** para resolucao

## Bloco 5 - Intersite Connectivity
- Por padrao, recursos em VNets diferentes **NAO se comunicam**
- **VNet Peering** habilita conectividade via backbone Microsoft (baixa latencia, sem criptografia overhead)
- Peering **NAO e transitivo** (A↔B e B↔C nao implica A↔C)
- **User-Defined Routes (UDR)** sobrescrevem rotas do sistema
- **Network Virtual Appliance (NVA)** permite inspecao de trafego (firewall, proxy)
- **Network Watcher** oferece ferramentas de diagnostico: Connection Troubleshoot, IP Flow Verify, Next Hop
