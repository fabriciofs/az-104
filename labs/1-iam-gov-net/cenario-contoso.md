# Lab Unificado AZ-104 - Semana 1 (v2: Exercicios Interconectados)

> **Pre-requisitos:** Assinatura Azure ativa, navegador moderno, acesso ao Azure Portal
>
> **Regiao padrao:** East US (ajuste conforme necessidade)

---

## Cenario Corporativo

Voce foi contratado como **Azure Administrator** da Contoso Corp, uma empresa em expansao. Sua missao e configurar o ambiente Azure corporativo **do zero**, onde cada etapa depende da anterior:

1. **Identidade** — criar usuarios e grupos que serao usados em todo o ambiente
2. **Governanca** — aplicar RBAC e policies que restringem o que esses usuarios podem fazer
3. **Automacao (IaC)** — provisionar recursos respeitando as policies, validando que a governanca funciona
4. **Rede** — construir a infraestrutura de rede onde os recursos serao implantados
5. **Conectividade** — implantar VMs nas redes criadas, testar comunicacao e validar tudo de ponta a ponta

Ao final, voce tera **um ambiente corporativo funcional** onde identidade, governanca, IaC, networking e compute estao integrados.

---

## Mapa de Dependencias

```
Bloco 1 (Identity)
  │
  ├─ az104-user1 ──────────────────┐
  ├─ Guest user ───────────────────┤
  ├─ IT Lab Administrators ────────┤
  └─ helpdesk ─────────────────────┤
                                   │
                                   ▼
Bloco 2 (Governance) ──────────────────────────────────────┐
  │                                                        │
  ├─ RBAC: VM Contributor → IT Lab Administrators (MG)     │
  ├─ RBAC: Reader → Guest user (az104-rg3)                 │
  ├─ Policy: Require tag (Deny) → az104-rg2 (testada)      │
  ├─ Policy: Inherit tag (Modify) → az104-rg2 + az104-rg3  │
  ├─ Policy: Allowed Locations (Deny) → az104-rg3          │
  ├─ Lock: Delete → az104-rg2                              │
  └─ Cria az104-rg3 com tag Cost Center = 000              │
                                   │                       │
                                   ▼                       │
Bloco 3 (IaC) ◄──── Valida governanca ─────────────────────┘
  │
  ├─ Disks em az104-rg3 → tags herdadas automaticamente ✓
  ├─ Deploy West US → bloqueado por Allowed Locations ✓
  ├─ Guest user → Reader, nao pode criar recursos ✓
  ├─ Cloud Shell configurado ────────────────────────┐
  └─ Skills ARM/Bicep aprendidas ────────────────────┤
                                                     │
                                                     ▼
Bloco 4 (Networking) ◄──── Reusa Cloud Shell e ARM skills
  │
  ├─ CoreServicesVnet (10.20.0.0/16) ──────────────┐
  ├─ ManufacturingVnet (10.30.0.0/16) via ARM ─────┤
  ├─ NSG + ASG na SharedServicesSubnet             │
  ├─ DNS publico: contoso.com (nslookup via Shell) │
  └─ DNS privado: private.contoso.com ─────────────┤
                                                   │
                                                   ▼
Bloco 5 (Connectivity) ◄──── VMs nas VNets do Bloco 4
  │
  ├─ CoreServicesVM na CoreServicesVnet (10.20.0.0/24)
  ├─ ManufacturingVM na ManufacturingVnet (10.30.0.0/24)
  ├─ Peering entre as VNets do Bloco 4
  ├─ DNS privado resolve nome real da VM ✓
  ├─ az104-user1 gerencia VMs (VM Contributor) ✓
  └─ Route table + NVA + custom route
```

---

## Indice

- [Bloco 1 - Identity](#bloco-1---identity)
- [Bloco 2 - Governance & Compliance](#bloco-2---governance--compliance)
- [Bloco 3 - Azure Resources & IaC](#bloco-3---azure-resources--iac)
- [Bloco 4 - Virtual Networking](#bloco-4---virtual-networking)
- [Bloco 5 - Intersite Connectivity](#bloco-5---intersite-connectivity)
- [Pausar entre Sessoes](#pausar-entre-sessoes)
- [Cleanup Unificado](#cleanup-unificado)
- [Key Takeaways Consolidados](#key-takeaways-consolidados)

---

# Bloco 1 - Identity

**Origem:** Lab 01 - Manage Microsoft Entra ID Identities
**Resource Groups utilizados:** Nenhum (recursos no Entra ID)

## Contexto

Antes de provisionar qualquer recurso, voce precisa configurar a base de identidade. Os usuarios e grupos criados aqui serao usados nos **Blocos 2 a 5** para testar RBAC, policies e acesso a recursos.

## Diagrama

```
┌──────────────────────────────────────────────┐
│            Microsoft Entra ID                │
│                                              │
│  ┌─────────────┐       ┌──────────────────┐  │
│  │  az104-     │       │   Guest User     │  │
│  │  user1      │       │   (B2B Invite)   │  │
│  │ IT Lab Admin│       │  IT Lab Admin    │  │
│  └──────┬──────┘       └────────┬─────────┘  │
│         │                       │            │
│    ┌────┴───────────────────────┴────┐       │
│    │                                 │       │
│    ▼                                 ▼       │
│  ┌───────────────────┐  ┌────────────────┐   │
│  │ IT Lab            │  │ helpdesk       │   │
│  │ Administrators    │  │ (Security)     │   │
│  │ (Security)        │  │                │   │
│  │                   │  │ Members:       │   │
│  │ Members:          │  │ • az104-user1  │   │
│  │ • az104-user1     │  └────────────────┘   │
│  │ • Guest user      │                       │
│  └───────────────────┘                       │
│                                              │
│  → Usados nos Blocos 2-5 para RBAC e testes  │
└──────────────────────────────────────────────┘
```

---

### Task 1.1: Criar e configurar conta de usuario

Nesta task voce cria uma conta de usuario interna que sera usada como **membro de grupos com RBAC** nos blocos seguintes.

1. Acesse o **Azure Portal** - `https://portal.azure.com`

2. Pesquise e selecione **Microsoft Entra ID**

3. Explore o blade **Overview** e a aba **Manage tenants**

   > **Conceito:** Um tenant e uma instancia especifica do Microsoft Entra ID contendo contas e grupos.

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

8. **IMPORTANTE:** Copie e salve a senha gerada automaticamente. Voce usara esta conta para testes de RBAC nos Blocos 2 e 5.

   > **Dica AZ-104:** Na prova, preste atencao em propriedades como Usage location - ela e obrigatoria para atribuir licencas ao usuario.

---

### Task 1.2: Convidar usuario externo (Guest/B2B)

Este usuario externo sera usado no **Bloco 2** (atribuicao de Reader role) e no **Bloco 3** (teste de acesso somente-leitura).

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

5. **Refresh** a pagina e confirme que o usuario convidado foi criado

6. **Aceite o convite:** Abra o email de convite no seu email pessoal e aceite. Isso sera necessario para os testes de acesso nos Blocos 2-3.

   > **Conceito B2B:** Microsoft Entra External ID (antigo Azure AD B2B) permite que usuarios externos acessem recursos do seu tenant usando suas proprias credenciais. O usuario aparece como **Guest** no diretorio.

---

### Task 1.3: Criar grupo IT Lab Administrators

Este grupo recebera o role **Virtual Machine Contributor** no Bloco 2.

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

   > **Nota:** Entra ID Premium P1 ou P2 e necessario para **Dynamic membership**.

4. Clique em **No owners selected** > pesquise e selecione **voce mesmo** como owner

5. Clique em **No members selected** > pesquise e selecione:
   - **az104-user1**
   - O **guest user** que voce convidou

6. Clique em **Create**

7. **Refresh** e verifique que o grupo foi criado com os members corretos

---

### Task 1.4: Criar grupo helpdesk

Este grupo sera usado no **Bloco 2** para atribuicao de role RBAC.

1. Ainda em **Groups**, selecione **+ New group**:

   | Setting           | Value                                     |
   | ----------------- | ----------------------------------------- |
   | Group type        | **Security**                              |
   | Group name        | `helpdesk`                                |
   | Group description | `Helpdesk team for support and VM access` |
   | Membership type   | **Assigned**                              |

2. Adicione **az104-user1** como member

3. Clique em **Create**

4. **Refresh** e verifique ambos os grupos: `IT Lab Administrators` e `helpdesk`

   > **Conexao com Blocos 2-5:** Os usuarios e grupos criados neste bloco serao o alicerce de toda a governanca. O az104-user1 (membro de ambos os grupos) tera roles RBAC atribuidos no Bloco 2, e o acesso sera testado nos Blocos 3 e 5.

---

## Modo Desafio - Bloco 1

- [ ] Criar usuario `az104-user1` com Job title `IT Lab Administrator`, Department `IT`, Usage location `United States`
- [ ] **Salvar a senha gerada** (necessaria para testes nos Blocos 2 e 5)
- [ ] Convidar usuario externo (guest) com mesmas propriedades + aceitar o convite
- [ ] Criar grupo `IT Lab Administrators` (Assigned) — members: az104-user1 + guest
- [ ] Criar grupo `helpdesk` (Assigned) — member: az104-user1
- [ ] Verificar members e owners de ambos os grupos

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

Dynamic user membership permite criar regras baseadas em propriedades do usuario (como department, jobTitle, etc.) para adicionar/remover membros automaticamente. Requer licenca Entra ID Premium P1 ou P2.

</details>

### Questao 1.2
**Um usuario externo foi convidado para o seu tenant via Microsoft Entra External ID (B2B). Qual e o tipo de conta (User type) desse usuario no diretorio?**

A) Member
B) Guest
C) External
D) Federated

<details>
<summary>Ver resposta</summary>

**Resposta: B) Guest**

Usuarios convidados via B2B aparecem com User type = **Guest**. Usuarios criados diretamente no tenant sao do tipo **Member**.

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

A propriedade **Usage location** e obrigatoria para atribuir licencas a um usuario no Microsoft Entra ID.

</details>

---

# Bloco 2 - Governance & Compliance

**Origem:** Lab 02a (Subscriptions & RBAC) + Lab 02b (Azure Policy) + **novos exercicios de integracao**
**Resource Groups utilizados:** `az104-rg2`, `az104-rg3`

## Contexto

Com a identidade configurada no Bloco 1, agora voce estabelece governanca: RBAC para os **usuarios e grupos ja criados**, policies que serao **validadas no Bloco 3** durante o deploy de discos, e locks para proteger recursos. Voce tambem prepara o `az104-rg3` que sera usado no Bloco 3 (IaC).

## Diagrama

```
┌────────────────────────────────────────────────────────────┐
│                  Root Management Group                     │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         az104-mg1 (Management Group)                 │  │
│  │                                                      │  │
│  │  RBAC:                                               │  │
│  │  • VM Contributor → IT Lab Administrators (Bloco 1)  │  │
│  │  • Custom Support Request (custom role)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────┐  ┌─────────────────────────┐ │
│  │  az104-rg2               │  │  az104-rg3              │ │
│  │  Tag: Cost Center = 000  │  │  Tag: Cost Center = 000 │ │
│  │                          │  │                         │ │
│  │  Policies:               │  │  Policies:              │ │
│  │  • Deny: Require tag     │  │  • Modify: Inherit tag  │ │
│  │  • Modify: Inherit tag   │  │  • Deny: Allowed Loc.   │ │
│  │                          │  │    (East US only)       │ │
│  │  Lock: Delete (rg-lock)  │  │                         │ │
│  │                          │  │  RBAC:                  │ │
│  │                          │  │  • Reader → Guest user  │ │
│  │                          │  │    (Bloco 1)            │ │
│  └──────────────────────────┘  └─────────────────────────┘ │
│                                                            │
│  → Policies validadas no Bloco 3 (deploy de discos)        │
│  → RBAC testado nos Blocos 3 e 5                           │
└────────────────────────────────────────────────────────────┘
```

---

### Task 2.1: Criar Management Group

1. Acesse o **Azure Portal** e pesquise **Microsoft Entra ID**

2. No blade **Manage**, selecione **Properties**

3. Revise a area **Access management for Azure resources**

4. Pesquise e selecione **Management groups**

5. Clique em **+ Create**:

   | Setting                       | Value       |
   | ----------------------------- | ----------- |
   | Management group ID           | `az104-mg1` |
   | Management group display name | `az104-mg1` |

6. Clique em **Submit** e **Refresh**

7. Selecione **az104-mg1** > clique em **details**

8. Clique em **+ Add subscription** e selecione sua subscription > **Save**

   > **Conceito:** O Root Management Group e o topo da hierarquia. Policies e RBAC aplicados em um MG sao herdados por todas as subscriptions filhas. **Sem mover a subscription para dentro do MG, os roles atribuidos nele nao terao efeito nos recursos.**

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

Voce atribui o role ao grupo **IT Lab Administrators** (criado no Bloco 1), que inclui `az104-user1` e o guest user. Isso sera testado no **Bloco 5** quando az104-user1 gerenciar VMs.

1. Selecione o management group **az104-mg1**

2. Selecione **Access control (IAM)** > aba **Roles**

3. Navegue pelos built-in roles. Clique em **View** em um role para ver Permissions, JSON e Assignments

4. Clique em **+ Add** > **Add role assignment**

5. Pesquise e selecione **Virtual Machine Contributor**

   > **Conceito:** O role Virtual Machine Contributor permite gerenciar VMs, mas NAO o SO, a VNet ou o Storage Account conectados.

6. Clique em **Next** > na aba **Members**, clique em **Select Members**

7. Pesquise e selecione o grupo **IT Lab Administrators** > **Select**

8. Clique em **Review + assign** duas vezes

9. Confirme a atribuicao na aba **Role assignments**

   > **Conexao com Bloco 5:** O az104-user1 (membro do IT Lab Administrators) podera gerenciar VMs em qualquer RG sob este Management Group. Testaremos isso no Bloco 5.

---

### Task 2.3: Criar custom RBAC role

1. No management group **az104-mg1**, va para **Access control (IAM)**

2. Clique em **+ Add** > **Add custom role**

3. Preencha a aba **Basics**:

   | Setting              | Value                                             |
   | -------------------- | ------------------------------------------------- |
   | Custom role name     | `Custom Support Request`                          |
   | Description          | `A custom contributor role for support requests.` |
   | Baseline permissions | **Clone a role**                                  |
   | Role to clone        | **Support Request Contributor**                   |

4. Na aba **Permissions**, clique em **+ Exclude permissions**

5. Digite `.Support`, selecione **Microsoft.Support**

6. Marque **Other: Registers Support Resource Provider** > **Add**

   > **Conceito:** A permissao agora aparece em **NotActions**. NotActions remove permissoes do conjunto de Actions.

7. Na aba **Assignable scopes**, verifique que o MG esta listado

8. Revise o JSON: observe **Actions**, **NotActions** e **AssignableScopes**

9. Clique em **Review + Create** > **Create**

---

### Task 2.4: Monitorar role assignments via Activity Log

1. No recurso **az104-mg1**, selecione **Activity log**

2. Revise as atividades de role assignments

---

### Task 2.5: Criar Resource Groups com tags

Voce cria **dois** Resource Groups: `az104-rg2` para testes de governanca e `az104-rg3` para uso no Bloco 3 (IaC). Ambos recebem a tag `Cost Center`.

**Criar az104-rg2:**

1. Pesquise e selecione **Resource groups** > **+ Create**:

   | Setting             | Value              |
   | ------------------- | ------------------ |
   | Subscription        | *sua subscription* |
   | Resource group name | `az104-rg2`        |
   | Location            | **East US**        |

2. Na aba **Tags**:

   | Name          | Value |
   | ------------- | ----- |
   | `Cost Center` | `000` |

3. Clique em **Review + Create** > **Create**

**Criar az104-rg3:**

4. Repita o processo para `az104-rg3` com a mesma tag `Cost Center: 000`

   > **Conexao com Bloco 3:** O az104-rg3 sera usado para deploy de managed disks. As policies aplicadas aqui serao validadas quando os discos forem criados.

---

### Task 2.6: Aplicar Azure Policy (Deny) - Require tag no az104-rg2

1. Pesquise e selecione **Policy** > **Authoring** > **Definitions**

2. Pesquise: `Require a tag and its value on resources`

3. Selecione a policy > **Assign policy**

4. Configure o **Scope**: Subscription + Resource Group **az104-rg2**

5. Configure **Basics**:

   | Setting            | Value                                                 |
   | ------------------ | ----------------------------------------------------- |
   | Assignment name    | `Require Cost Center tag with value 000 on resources` |
   | Policy enforcement | **Enabled**                                           |

6. Na aba **Parameters**: Tag Name = `Cost Center`, Tag Value = `000`

7. Clique em **Review + Create** > **Create**

   > Aguarde 5-10 minutos para a policy entrar em vigor.

8. **Teste:** Pesquise **Storage Accounts** > **+ Create** no RG **az104-rg2** com qualquer nome

9. Clique em **Review** > **Create** — voce deve receber **Validation failed** (recurso sem tag)

   > **Conceito:** O efeito **Deny** impede criacao de recursos que nao atendem as condicoes da policy.

---

### Task 2.7: Substituir Deny por Modify policy (Inherit tag) no az104-rg2

1. Va em **Policy** > **Assignments** > localize a atribuicao **Require Cost Center tag...** > **...** > **Delete assignment**

2. Clique em **Assign policy** > Scope: **az104-rg2**

3. Pesquise: `Inherit a tag from the resource group if missing`

4. Configure **Basics**:

   | Setting            | Value                                                                              |
   | ------------------ | ---------------------------------------------------------------------------------- |
   | Assignment name    | `Inherit the Cost Center tag and its value 000 from the resource group if missing` |
   | Policy enforcement | **Enabled**                                                                        |

5. Na aba **Parameters**: Tag Name = `Cost Center`

6. Na aba **Remediation**: Enable **Create a remediation task**

   > **Conceito:** O efeito **Modify** requer uma **Managed Identity** para alterar recursos existentes.

7. Clique em **Review + Create** > **Create**

---

### Task 2.8: Aplicar Modify policy (Inherit tag) no az104-rg3

Aplique a **mesma** policy ao az104-rg3 para que os discos criados no Bloco 3 herdem a tag automaticamente.

1. Em **Policy** > **Assignments** > **Assign policy** > Scope: **az104-rg3**

2. Pesquise: `Inherit a tag from the resource group if missing`

3. Configure:

   | Setting            | Value                                            |
   | ------------------ | ------------------------------------------------ |
   | Assignment name    | `Inherit Cost Center tag on az104-rg3 resources` |
   | Policy enforcement | **Enabled**                                      |
   | Tag Name (param)   | `Cost Center`                                    |
   | Remediation task   | **enabled**                                      |

4. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** Quando voce criar managed disks no az104-rg3, eles receberao automaticamente a tag `Cost Center: 000`. Voce verificara isso em cada deploy.

---

### Task 2.9: Aplicar Allowed Locations policy no az104-rg3

Esta policy restringe a criacao de recursos ao **East US** apenas. Sera testada no **Bloco 3** tentando criar um disco em outra regiao.

1. Em **Policy** > **Definitions** > pesquise: `Allowed locations`

2. Selecione a policy (nao confunda com "Allowed locations for resource groups") > **Assign policy**

3. Configure o **Scope**: Subscription + Resource Group **az104-rg3**

4. Configure **Basics**:

   | Setting            | Value                                |
   | ------------------ | ------------------------------------ |
   | Assignment name    | `Restrict resources to East US only` |
   | Policy enforcement | **Enabled**                          |

5. Na aba **Parameters**: Allowed locations = **East US**

6. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** No Bloco 3, voce tentara criar um disco em West US e vera que esta policy bloqueia a criacao.

---

### Task 2.10: Atribuir Reader role ao Guest user no az104-rg3

O guest user (convidado no Bloco 1) recebera permissao somente-leitura no az104-rg3, o que sera testado no **Bloco 3**.

1. Navegue para o resource group **az104-rg3**

2. Selecione **Access control (IAM)** > **+ Add** > **Add role assignment**

3. Pesquise e selecione o role **Reader** > **Next**

4. Na aba **Members**, clique em **Select Members**

5. Pesquise e selecione o **guest user** (convidado no Bloco 1) > **Select**

6. Clique em **Review + assign** duas vezes

7. Confirme na aba **Role assignments** que o guest user tem role **Reader** no az104-rg3

   > **Conexao com Bloco 3:** O guest user podera VER os discos criados no az104-rg3, mas NAO podera criar ou modificar recursos. Testaremos isso no Bloco 3.

---

### Task 2.11: Configurar Resource Lock e testar

1. Navegue para **az104-rg2** > **Settings** > **Locks**

2. Clique em **Add**:

   | Setting   | Value      |
   | --------- | ---------- |
   | Lock name | `rg-lock`  |
   | Lock type | **Delete** |

3. Clique em **Ok**

4. Tente deletar o resource group: **Overview** > **Delete resource group** > digite `az104-rg2` > **Delete**

5. Voce deve receber uma notificacao **negando a exclusao**

   > **Conceito:** Locks protegem contra exclusoes acidentais. O lock Delete permite modificar mas impede exclusao. Locks **sobrescrevem quaisquer permissoes**, incluindo Owner.

---

### Task 2.12: Teste de integracao — Verificar acesso do az104-user1

Aqui voce valida que o RBAC configurado neste bloco funciona com o usuario do Bloco 1.

1. Abra uma janela **InPrivate/Incognito** no navegador

2. Acesse `https://portal.azure.com`

3. Faca login como **az104-user1@{seu-dominio}.onmicrosoft.com** usando a senha salva no Bloco 1

4. Pesquise **Management groups** — voce deve ver **az104-mg1**

5. Pesquise **Virtual Machines** — voce deve poder ver a pagina (mas nao havera VMs ainda)

6. Pesquise **Resource groups** — voce deve ver os RGs, mas com permissoes limitadas

7. Tente criar um **Storage Account** no az104-rg2 — deve **falhar** (VM Contributor nao tem permissao para storage)

   > **Validacao:** az104-user1 tem VM Contributor (pode gerenciar VMs) mas nao pode criar outros tipos de recursos. No Bloco 5, testaremos com VMs reais.

8. Feche a janela InPrivate

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `az104-mg1` e **mover sua subscription para dentro dele**
- [ ] Atribuir **VM Contributor** ao grupo `IT Lab Administrators` (Bloco 1) no MG
- [ ] Criar custom role **Custom Support Request** (clone + NotActions)
- [ ] Verificar no Activity Log
- [ ] Criar RGs `az104-rg2` e `az104-rg3` com tag `Cost Center: 000`
- [ ] Aplicar Deny policy (Require tag) no rg2 → testar → remover
- [ ] Aplicar Modify policy (Inherit tag) no rg2 e rg3
- [ ] Aplicar **Allowed Locations** (East US only) no rg3
- [ ] Atribuir **Reader** ao guest user no rg3
- [ ] Criar Resource Lock (Delete) no rg2 → testar exclusao
- [ ] **Integracao:** Login como az104-user1 → verificar acesso limitado

---

## Questoes de Prova - Bloco 2

### Questao 2.1
**Voce atribuiu VM Contributor a um grupo no Management Group. Um membro do grupo tenta criar um Storage Account. O que acontece?**

A) A criacao e permitida porque VM Contributor inclui todas as permissoes de compute
B) A criacao falha porque VM Contributor nao inclui permissoes de Storage
C) A criacao e permitida no nivel de Management Group
D) A criacao depende do Resource Group

<details>
<summary>Ver resposta</summary>

**Resposta: B) A criacao falha porque VM Contributor nao inclui permissoes de Storage**

VM Contributor permite gerenciar VMs (Microsoft.Compute/virtualMachines/*) mas NAO inclui permissoes para Storage, Network ou outros servicos. RBAC no Azure e aditivo — o usuario so pode fazer o que os roles atribuidos permitem explicitamente.

</details>

### Questao 2.2
**Voce aplicou a policy "Allowed locations" com East US em um Resource Group. Um usuario tenta criar um disco em West US via ARM template nesse RG. O que acontece?**

A) O disco e criado em West US normalmente
B) O disco e criado em East US automaticamente
C) O deploy falha com erro de policy violation
D) O disco e criado mas marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: C) O deploy falha com erro de policy violation**

A policy "Allowed locations" usa o efeito **Deny**, que bloqueia ativamente a criacao de recursos em locais nao permitidos. O ARM template falhara durante a validacao.

</details>

### Questao 2.3
**Qual a diferenca entre os efeitos Deny, Audit e Modify no Azure Policy?**

A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente
B) Todos os tres bloqueiam a criacao de recursos
C) Deny e Audit sao identicos, Modify cria recursos novos
D) Audit bloqueia, Deny registra, Modify exclui recursos

<details>
<summary>Ver resposta</summary>

**Resposta: A) Deny bloqueia, Audit apenas registra, Modify altera o recurso automaticamente**

- **Deny:** Impede criacao/modificacao de recursos nao-conformes
- **Audit:** Permite a criacao mas registra como non-compliant
- **Modify:** Altera propriedades automaticamente (requer Managed Identity)

</details>

### Questao 2.4
**Um usuario com role Owner tenta excluir um Resource Group que tem um Delete lock. O que acontece?**

A) A exclusao e permitida porque Owner tem todas as permissoes
B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario
C) A exclusao e permitida mas gera um alerta
D) A exclusao e bloqueada apenas para usuarios sem role Owner

<details>
<summary>Ver resposta</summary>

**Resposta: B) A exclusao e bloqueada — locks sobrescrevem permissoes de usuario**

Resource Locks sobrescrevem quaisquer permissoes, incluindo Owner. O lock precisa ser removido primeiro.

</details>

### Questao 2.5
**Voce atribuiu Reader role a um guest user em um Resource Group. O que este usuario pode fazer?**

A) Criar e modificar recursos no RG
B) Apenas visualizar recursos, sem poder criar ou modificar
C) Gerenciar apenas VMs no RG
D) Nada — guest users nao podem receber roles

<details>
<summary>Ver resposta</summary>

**Resposta: B) Apenas visualizar recursos, sem poder criar ou modificar**

O role **Reader** permite apenas visualizar recursos existentes. Nao concede permissoes de criacao, modificacao ou exclusao. Guest users podem receber qualquer role RBAC, assim como usuarios internos.

</details>

---

# Bloco 3 - Azure Resources & IaC

**Origem:** Lab 03b - Manage Azure Resources by Using ARM Templates + **testes de integracao com governanca**
**Resource Groups utilizados:** `az104-rg3` (preparado no Bloco 2 com policies)

## Contexto

Voce vai provisionar recursos usando diferentes metodos de IaC. O diferencial desta versao: todos os discos sao criados no **az104-rg3** que ja tem policies ativas do Bloco 2 (Modify tag + Allowed Locations). A cada deploy, voce **valida que a governanca funciona**: tags herdadas e restricao de regiao.

## Diagrama

```
┌───────────────────────────────────────────────────────────┐
│                    az104-rg3                              │
│               Tag: Cost Center = 000                      │
│          Policy: Modify (inherit tag) ← Bloco 2           │
│          Policy: Allowed Locations (East US) ← Bloco 2    │
│          RBAC: Reader → Guest user ← Bloco 2              │
│                                                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │az104-    │ │az104-    │ │az104-    │ │az104-    │      │
│  │disk1     │ │disk2     │ │disk3     │ │disk4     │      │
│  │(Portal)  │ │(ARM      │ │(ARM +    │ │(ARM +    │      │
│  │          │ │ Portal)  │ │PowerShell│ │ CLI)     │      │
│  │Tag: ✓    │ │Tag: ✓    │ │Tag: ✓    │ │Tag: ✓    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│                                                           │
│  ┌──────────┐ ┌──────────────────────────────────────┐    │
│  │az104-    │ │ Testes de integracao:                │    │
│  │disk5     │ │ • Tags herdadas em cada disco ✓      │    │
│  │(Bicep +  │ │ • Deploy West US → bloqueado ✓       │    │
│  │ CLI)     │ │ • Guest user → somente leitura ✓     │    │
│  │Tag: ✓    │ └──────────────────────────────────────┘    │
│  └──────────┘                                             │
│                                                           │
│  → Cloud Shell configurado aqui → reusado nos Blocos 4/5  │
│  → ARM/Bicep skills → usadas no Bloco 4                   │
└───────────────────────────────────────────────────────────┘
```

---

### Task 3.1: Criar managed disk e exportar ARM template

1. Pesquise e selecione **Disks** > **Create**:

   | Setting           | Value                                     |
   | ----------------- | ----------------------------------------- |
   | Subscription      | *sua subscription*                        |
   | Resource Group    | `az104-rg3`                               |
   | Disk name         | `az104-disk1`                             |
   | Region            | **East US**                               |
   | Availability zone | **No infrastructure redundancy required** |
   | Source type       | **None**                                  |
   | Performance       | **Standard HDD** (altere o tamanho)       |
   | Size              | **32 GiB**                                |

2. Clique em **Review + Create** > **Create**

3. Selecione **Go to resource**

4. **Validacao de governanca:** No blade **Tags**, verifique que a tag **Cost Center = 000** foi automaticamente atribuida pela policy Modify do Bloco 2.

   > **Conexao com Bloco 2:** A policy "Inherit tag from resource group if missing" esta funcionando! O disco herdou a tag do az104-rg3 sem voce precisar configura-la manualmente.

5. No blade **Automation**, selecione **Export template**

6. Revise as abas **Template** e **Parameters**

7. Clique em **Download** em cada aba para salvar os arquivos JSON

---

### Task 3.2: Editar template e fazer deploy de az104-disk2 via portal

1. Pesquise **Deploy a custom template** > **Build your own template in the editor**

2. **Load file** > carregue **template.json**

3. No editor, altere:
   - `disks_az104_disk1_name` → `disk_name` (dois locais)
   - `az104-disk1` → `az104-disk2` (um local)

4. Clique em **Save**

5. **Edit parameters** > **Load file** > carregue **parameters.json**

6. Altere `disks_az104_disk1_name` → `disk_name`

7. Clique em **Save**

8. Complete o deployment:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource Group | `az104-rg3`   |
   | Region         | **East US**   |
   | Disk_name      | `az104-disk2` |

9. Clique em **Review + Create** > **Create**

10. Selecione **Go to resource**

11. **Validacao de governanca:** Verifique no blade **Tags** que `Cost Center = 000` foi herdada automaticamente.

---

### Task 3.3: Configurar Cloud Shell e deploy de az104-disk3 via PowerShell

1. Clique no icone do **Cloud Shell** no canto superior direito

2. Selecione **PowerShell**

3. Na tela Getting started, selecione **Mount storage account** > selecione sua subscription > **Apply**

4. Selecione **I want to create a storage account** > **Next**:

   | Setting         | Value                                                      |
   | --------------- | ---------------------------------------------------------- |
   | Resource Group  | **az104-rg3**                                              |
   | Region          | *sua regiao*                                               |
   | Storage account | *nome unico globalmente (3-24 chars, lowercase + numeros)* |
   | File share      | `fs-cloudshell`                                            |

5. Clique em **Create**

   > **Conexao com Blocos 4/5:** O Cloud Shell configurado aqui sera reutilizado para nslookup (Bloco 4) e outros comandos (Bloco 5). Nao sera necessario reconfigurar.

6. Selecione **Settings** > **Go to classic version**

7. **Upload** os arquivos template.json e parameters.json

8. No **Editor**, altere o nome do disco para `az104-disk3`. Salve com **Ctrl+S**

9. Execute o deploy:

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName az104-rg3 -TemplateFile template.json -TemplateParameterFile parameters.json
    ```

10. Verifique que o ProvisioningState e **Succeeded**

11. **Validacao de governanca:** Verifique a tag:

    ```powershell
    Get-AzDisk -ResourceGroupName az104-rg3 -DiskName az104-disk3 | Select-Object Name, Tags
    ```

    A tag `Cost Center: 000` deve aparecer.

---

### Task 3.4: Deploy via CLI (Bash) de az104-disk4

1. No Cloud Shell, selecione **Bash** e **confirme**

2. Verifique os arquivos: `ls`

3. No **Editor**, altere o nome do disco para `az104-disk4`. Salve com **Ctrl+S**

4. Execute o deploy:

   ```sh
   az deployment group create --resource-group az104-rg3 --template-file template.json --parameters parameters.json
   ```

5. Verifique o ProvisioningState: **Succeeded**

6. **Validacao de governanca:**

   ```sh
   az disk show --resource-group az104-rg3 --name az104-disk4 --query tags
   ```

   Resultado esperado: `{"Cost Center": "000"}`

---

### Task 3.5: Deploy via Bicep de az104-disk5

1. Continue no **Cloud Shell** (Bash)

2. **Upload** o arquivo `azuredeploydisk.bicep`:

   **Conteudo do arquivo `azuredeploydisk.bicep`:**

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

   resource managedDisk 'Microsoft.Compute/disks@2023-10-02' = {
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

3. No **Editor**, faca as alteracoes:
   - Linha 2: `managedDiskName` default → `az104-disk5`
   - Linha 27 (dentro do bloco `sku`): name → `StandardSSD_LRS`
   - Linha 7: `diskSizeinGiB` default → `32`

4. Salve com **Ctrl+S**

5. Execute o deploy:

   ```sh
   az deployment group create --resource-group az104-rg3 --template-file azuredeploydisk.bicep
   ```

6. **Validacao de governanca:**

   ```sh
   az disk show --resource-group az104-rg3 --name az104-disk5 --query tags
   ```

7. Liste todos os 5 discos:

   ```sh
   az disk list --resource-group az104-rg3 --output table
   ```

---

### Task 3.6: Teste de integracao — Allowed Locations policy

Voce testa a policy do Bloco 2 que restringe recursos ao East US.

1. No Cloud Shell (Bash), tente criar um disco em **West US**:

   ```sh
   az deployment group create --resource-group az104-rg3 \
     --template-file azuredeploydisk.bicep \
     --parameters managedDiskName=az104-disk-test location=westus
   ```

2. **Resultado esperado:** O deploy **falha** com erro de policy violation:

   ```
   "Resource 'az104-disk-test' was disallowed by policy."
   ```

   > **Conexao com Bloco 2:** A policy "Allowed locations" aplicada no Bloco 2 esta funcionando! Recursos so podem ser criados em East US neste resource group.

3. Confirme que o disco de teste NAO foi criado:

   ```sh
   az disk list --resource-group az104-rg3 --output table
   ```

   Devem aparecer apenas os 5 discos originais.

---

### Task 3.7: Teste de integracao — Guest user com Reader role (Opcional)

Este teste valida o RBAC configurado no Bloco 2 (Reader para o guest user).

> **Pre-requisito:** O guest user deve ter aceito o convite do Bloco 1.

1. Abra uma janela **InPrivate/Incognito**

2. Acesse `https://portal.azure.com`

3. Faca login com as credenciais do **guest user** (seu email pessoal)

4. Pesquise e selecione **Resource groups** > **az104-rg3**

5. Voce deve conseguir **ver** os discos criados

6. Tente criar um novo disco (**Disks** > **Create**) — deve **falhar** com erro de permissao

   > **Conexao com Blocos 1 e 2:** O guest user (convidado no Bloco 1) recebeu Reader (atribuido no Bloco 2) e pode ver mas nao criar recursos. Isso demonstra RBAC em acao.

7. Feche a janela InPrivate

---

## Modo Desafio - Bloco 3

- [ ] Criar `az104-disk1` via Portal em az104-rg3 → **verificar tag herdada**
- [ ] Deploy `az104-disk2` via ARM Portal → **verificar tag herdada**
- [ ] Configurar Cloud Shell (PowerShell) → deploy `az104-disk3` → **verificar tag**
- [ ] Trocar para Bash → deploy `az104-disk4` → **verificar tag**
- [ ] Deploy `az104-disk5` via Bicep → **verificar tag**
- [ ] **Integracao:** Tentar deploy em West US → bloqueado por policy
- [ ] **Integracao (opcional):** Login como guest → Reader somente leitura

---

## Questoes de Prova - Bloco 3

### Questao 3.1
**Voce aplicou uma policy Modify "Inherit tag from resource group" no az104-rg3. Voce cria um managed disk via ARM template sem tags. O que acontece com as tags do disco?**

A) O disco e criado sem tags
B) O disco herda a tag Cost Center = 000 do resource group automaticamente
C) O deploy falha porque o disco nao tem a tag
D) O disco e criado e marcado como non-compliant

<details>
<summary>Ver resposta</summary>

**Resposta: B) O disco herda a tag Cost Center = 000 do resource group automaticamente**

O efeito **Modify** altera as propriedades do recurso durante a criacao. A policy "Inherit tag from resource group if missing" copia a tag do RG para o recurso se ele nao a possuir. Diferente do Deny (que bloquearia) ou Audit (que apenas registraria).

</details>

### Questao 3.2
**Qual comando PowerShell faz deploy de um ARM template em um Resource Group?**

A) `Set-AzResourceGroup`
B) `New-AzResourceGroupDeployment`
C) `New-AzDeployment`
D) `Deploy-AzTemplate`

<details>
<summary>Ver resposta</summary>

**Resposta: B) New-AzResourceGroupDeployment**

- `New-AzResourceGroupDeployment` → deploy no nivel de Resource Group
- `New-AzDeployment` → deploy no nivel de Subscription
- Os escopos de deploy CLI sao: `az deployment group|sub|mg|tenant create`

</details>

### Questao 3.3
**Qual a principal diferenca entre ARM Templates (JSON) e Bicep?**

A) Bicep e interpretada, ARM e compilada
B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON
C) ARM suporta mais tipos de recursos
D) Bicep requer runtime separada

<details>
<summary>Ver resposta</summary>

**Resposta: B) Bicep oferece sintaxe declarativa mais concisa e compila para ARM JSON**

Bicep e uma DSL que compila transparentemente para ARM JSON. Ambos suportam os mesmos recursos.

</details>

---

# Bloco 4 - Virtual Networking

**Origem:** Lab 04 - Implement Virtual Networking
**Resource Groups utilizados:** `az104-rg4`

## Contexto

Com IaC dominado e Cloud Shell configurado (Bloco 3), voce constroi a infraestrutura de rede. As VNets criadas aqui serao **usadas no Bloco 5** para implantar VMs. O deploy da ManufacturingVnet via ARM template reutiliza os skills do Bloco 3. O nslookup usa o Cloud Shell ja configurado.

## Diagrama

```
┌────────────────────────────────────────────────────────────────────┐
│                          az104-rg4                                 │
│                                                                    │
│  ┌──────────────────────────────┐  ┌────────────────────────────┐  │
│  │  CoreServicesVnet            │  │  ManufacturingVnet         │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16              │  │
│  │                              │  │  (deploy via ARM ← Bloco 3)│  │
│  │  ┌────────────────────────┐  │  │                            │  │
│  │  │SharedServicesSubnet    │  │  │  ┌─────────────────────┐   │  │
│  │  │ 10.20.10.0/24          │  │  │  │ SensorSubnet1       │   │  │
│  │  │ ← NSG: myNSGSecure     │  │  │  │ 10.30.20.0/24       │   │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘   │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────┐   │  │
│  │  │ DatabaseSubnet         │  │  │  │ SensorSubnet2       │   │  │
│  │  │ 10.20.20.0/24          │  │  │  │ 10.30.21.0/24       │   │  │
│  │  └────────────────────────┘  │  │  └─────────────────────┘   │  │
│  └──────────────────────────────┘  └────────────────────────────┘  │
│                                                                    │
│  → No Bloco 5: subnets adicionais para VMs nestas VNets            │
│  → No Bloco 5: peering entre estas VNets                           │
│                                                                    │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐    │
│  │ ASG: asg-web │  │ DNS Zones:                               │    │
│  └──────────────┘  │ • Public:  contoso.com (A: www)          │    │
│                    │ • Private: private.contoso.com           │    │
│                    │   └─ Link: ManufacturingVnet             │    │
│                    │   → No Bloco 5: record com IP real da VM │    │
│                    └──────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

---

### Task 4.1: Criar VNet CoreServicesVnet via portal

1. Pesquise e selecione **Virtual Networks** > **Create**

2. Aba **Basics**:

   | Setting        | Value                            |
   | -------------- | -------------------------------- |
   | Resource Group | `az104-rg4` (crie se necessario) |
   | Name           | `CoreServicesVnet`               |
   | Region         | **(US) East US**                 |

3. Aba **IP Addresses**: IPv4 address space = `10.20.0.0/16`

4. **Delete** a subnet default (se existir)

5. **+ Add a subnet** para cada:

   | Subnet                   | Setting          | Value                  |
   | ------------------------ | ---------------- | ---------------------- |
   | **SharedServicesSubnet** | Subnet name      | `SharedServicesSubnet` |
   |                          | Starting address | `10.20.10.0`           |
   |                          | Size             | `/24`                  |
   | **DatabaseSubnet**       | Subnet name      | `DatabaseSubnet`       |
   |                          | Starting address | `10.20.20.0`           |
   |                          | Size             | `/24`                  |

   > **Conceito:** Cinco IPs sao reservados em cada subnet Azure. Uma /24 tem 251 IPs utilizaveis.

6. Clique em **Review + create** > **Create** > **Go to resource**

7. Verifique **Address space** e **Subnets**

8. **Automation** > **Export template** > **Download** template e parameters

   > **Conexao com Bloco 5:** Esta VNet sera usada para implantar a CoreServicesVM. Voce adicionara uma subnet adicional para VMs no Bloco 5.

---

### Task 4.2: Criar VNet ManufacturingVnet via ARM template

Voce reutiliza os **skills de ARM template do Bloco 3** para criar a segunda VNet.

> **Voce pode:** (A) editar o template exportado da CoreServicesVnet, ou (B) usar o template pronto abaixo.

**Se escolher o caminho A** — edite fazendo estas substituicoes:
- `CoreServicesVnet` → `ManufacturingVnet`
- `10.20.0.0` → `10.30.0.0`
- `SharedServicesSubnet` → `SensorSubnet1`
- `10.20.10.0/24` → `10.30.20.0/24`
- `DatabaseSubnet` → `SensorSubnet2`
- `10.20.20.0/24` → `10.30.21.0/24`

**Se escolher o caminho B** — use os templates prontos:

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
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "virtualNetworks_ManufacturingVnet_name": {
            "value": "ManufacturingVnet"
        }
    }
}
```

**Deploy no portal:**

1. Pesquise **Deploy a custom template** > **Build your own template in the editor** > **Load file** > template > **Save**

2. **Edit parameters** > **Load file** > parameters > **Save**

3. Resource group: **az104-rg4**

4. **Review + create** > **Create**

5. Confirme que a ManufacturingVnet e subnets foram criadas

   > **Conexao com Bloco 3:** Voce usou as mesmas skills de ARM template aprendidas no Bloco 3, mas agora para criar infraestrutura de rede.

---

### Task 4.3: Criar ASG e NSG

**Criar o ASG:**

1. Pesquise **Application security groups** > **Create**:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource group | **az104-rg4** |
   | Name           | `asg-web`     |
   | Region         | **East US**   |

2. **Review + create** > **Create**

**Criar o NSG:**

3. Pesquise **Network security groups** > **+ Create**:

   | Setting        | Value         |
   | -------------- | ------------- |
   | Resource group | **az104-rg4** |
   | Name           | `myNSGSecure` |
   | Region         | **East US**   |

4. **Review + create** > **Create** > **Go to resource**

---

### Task 4.4: Associar NSG a subnet + regras inbound/outbound

1. No NSG **myNSGSecure**, em **Settings** > **Subnets** > **Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg4)** |
   | Subnet          | **SharedServicesSubnet**         |

2. Clique em **OK**

**Regra Inbound - Allow ASG:**

3. **Inbound security rules** > **+ Add**:

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

4. Clique em **Add**

**Regra Outbound - Deny Internet:**

5. **Outbound security rules** > note a regra **AllowInternetOutBound** (priority 65001) > **+ Add**:

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

6. Clique em **Add**

   > **Conceito:** NSG rules sao processadas por **priority** (menor = maior prioridade). A DenyInternetOutbound (4096) tem prioridade maior que AllowInternetOutBound (65001).

   > **Conexao com Bloco 5:** Este NSG esta associado apenas a SharedServicesSubnet. As VMs criadas no Bloco 5 ficarao em subnets diferentes (Core, Manufacturing), entao NAO serao afetadas por este NSG — demonstrando que NSGs sao associados por subnet, nao por VNet.

---

### Task 4.5: Criar zona DNS publica com registro A

1. Pesquise **DNS zones** > **+ Create**:

   | Setting        | Value                                          |
   | -------------- | ---------------------------------------------- |
   | Resource group | **az104-rg4**                                  |
   | Name           | `contoso.com` (ajuste se ja estiver reservado) |
   | Region         | **Global** (DNS zones sao recursos globais)    |

2. **Review + create** > **Create** > **Go to resource**

3. **Copie** o endereco de um name server (voce precisara para nslookup)

4. **DNS Management** > **Recordsets** > **+ Add**:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `www`      |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

5. Clique em **Add**

6. Teste via **Cloud Shell** (ja configurado no Bloco 3):

   ```sh
   nslookup www.contoso.com <name-server-copiado>
   ```

   > **Conexao com Bloco 3:** O Cloud Shell ja esta configurado e pronto para uso — sem necessidade de reconfigurar.

7. Verifique que resolve para `10.1.1.4`

---

### Task 4.6: Criar zona DNS privada com virtual network link

1. Pesquise **Private dns zones** > **+ Create**:

   | Setting        | Value                 |
   | -------------- | --------------------- |
   | Resource group | **az104-rg4**         |
   | Name           | `private.contoso.com` |
   | Region         | **Global**            |

2. **Review + create** > **Create** > **Go to resource**

3. Note que nao ha name servers (zona privada)

4. **DNS Management** > **Virtual network links** > configure:

   | Setting         | Value                |
   | --------------- | -------------------- |
   | Link name       | `manufacturing-link` |
   | Virtual network | `ManufacturingVnet`  |

5. Clique em **Create** e aguarde

6. **+ Recordsets** > adicione um registro placeholder:

   | Setting    | Value      |
   | ---------- | ---------- |
   | Name       | `sensorvm` |
   | Type       | **A**      |
   | TTL        | `1`        |
   | IP address | `10.1.1.4` |

   > **Conexao com Bloco 5:** No Bloco 5, voce adicionara um registro com o IP **real** da CoreServicesVM e testara a resolucao de nome a partir da ManufacturingVM. Voce tambem adicionara um link para CoreServicesVnet.

---

## Modo Desafio - Bloco 4

- [ ] Criar VNet `CoreServicesVnet` (10.20.0.0/16) com SharedServicesSubnet e DatabaseSubnet
- [ ] Exportar template → criar `ManufacturingVnet` (10.30.0.0/16) via ARM (**skills do Bloco 3**)
- [ ] Criar ASG `asg-web` e NSG `myNSGSecure`
- [ ] Associar NSG a SharedServicesSubnet + regras inbound/outbound
- [ ] Criar DNS publica `contoso.com` + nslookup via **Cloud Shell (Bloco 3)**
- [ ] Criar DNS privada `private.contoso.com` + link para ManufacturingVnet

---

## Questoes de Prova - Bloco 4

### Questao 4.1
**Um NSG esta associado a SharedServicesSubnet. Voce cria uma VM em DatabaseSubnet (mesma VNet). A VM e afetada pelas regras do NSG?**

A) Sim, o NSG se aplica a toda a VNet
B) Nao, o NSG se aplica apenas a subnet associada
C) Sim, se o ASG incluir a VM
D) Depende das regras de priority

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, o NSG se aplica apenas a subnet associada**

NSGs sao associados a **subnets** ou **NICs**, nao a VNets inteiras. Uma VM em DatabaseSubnet nao e afetada por um NSG associado a SharedServicesSubnet, mesmo que estejam na mesma VNet.

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

O Azure reserva 5 IPs: network address (.0), gateway (.1), Azure DNS (.2, .3), broadcast (.255). 256 - 5 = 251.

</details>

### Questao 4.3
**Voce tem regras NSG: Rule A (Priority 100, Allow, Port 80) e Rule B (Priority 200, Deny, Port 80). Um pacote chega na porta 80. O que acontece?**

A) Negado pela Rule B
B) Permitido pela Rule A
C) Avaliado por todas as regras, ultima vence
D) Permitido porque ha mais regras Allow

<details>
<summary>Ver resposta</summary>

**Resposta: B) Permitido pela Rule A**

NSG rules sao processadas em ordem de priority (menor primeiro). Rule A (100) e avaliada primeiro e permite o trafego. Rule B nunca e alcancada.

</details>

### Questao 4.4
**Qual a diferenca entre Azure DNS public zones e private zones?**

A) Public zones sao gratuitas, private zones sao pagas
B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas
C) Private zones suportam mais tipos de registro
D) Public zones requerem VPN

<details>
<summary>Ver resposta</summary>

**Resposta: B) Public zones resolvem na internet, private zones apenas dentro de VNets linkadas**

Private DNS zones requerem Virtual Network Links e resolvem apenas para recursos nas VNets linkadas.

</details>

### Questao 4.5
**Voce criou uma zona DNS privada e linkou a VNet A. Uma VM na VNet B (nao linkada) tenta resolver um nome nessa zona. O que acontece?**

A) Resolve normalmente
B) Falha — a VNet B nao esta linkada a zona
C) Resolve usando o DNS publico
D) Resolve apenas se houver peering entre A e B

<details>
<summary>Ver resposta</summary>

**Resposta: B) Falha — a VNet B nao esta linkada a zona**

Zonas DNS privadas so resolvem para VNets que possuem Virtual Network Links configurados. Peering entre VNets NAO implica resolucao DNS automatica — o link precisa ser explicitamente criado.

</details>

---

# Bloco 5 - Intersite Connectivity

**Origem:** Lab 05 - Implement Intersite Connectivity + **integracoes com Blocos 1-4**
**Resource Groups utilizados:** `az104-rg5` (VMs e route tables) + `az104-rg4` (VNets do Bloco 4)

## Contexto

Este e o bloco final onde tudo se conecta. As VMs sao implantadas nas **VNets criadas no Bloco 4** (cross-resource-group), o DNS privado do Bloco 4 resolve nomes reais das VMs, e o RBAC configurado nos Blocos 1-2 e testado de ponta a ponta.

## Diagrama

```
┌─────────────────────────────────────────────────────────────────────┐
│                az104-rg4 (VNets do Bloco 4)                         │
│                                                                     │
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  CoreServicesVnet            │  │  ManufacturingVnet          │  │
│  │  10.20.0.0/16                │  │  10.30.0.0/16               │  │
│  │                              │  │                             │  │
│  │  SharedServicesSubnet        │  │  SensorSubnet1 (Bloco 4)    │  │
│  │  10.20.10.0/24 (← NSG)       │  │  SensorSubnet2 (Bloco 4)    │  │
│  │  DatabaseSubnet              │  │                             │  │
│  │  10.20.20.0/24               │  │  Manufacturing (NOVO)       │  │
│  │                              │  │  10.30.0.0/24               │  │
│  │  Core (NOVO) ←──────────── peering ──────────→ ManufacturingVM│  │
│  │  10.20.0.0/24                │  │  (az104-rg5)                │  │
│  │  CoreServicesVM              │  └─────────────────────────────┘  │
│  │  (az104-rg5)                 │                                   │
│  │                              │                                   │
│  │  perimeter (NOVO)            │  ┌────────────────────────────┐   │
│  │  10.20.1.0/24                │  │ DNS: private.contoso.com   │   │
│  │  (NVA: 10.20.1.7)            │  │ + corevm → IP real da VM   │   │
│  └──────────────────────────────┘  │ + Link: CoreServicesVnet   │   │
│                                    └────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ az104-rg5                    │                                   │
│  │ (VMs + Route Table)          │                                   │
│  │                              │                                   │
│  │ • CoreServicesVM             │                                   │
│  │ • ManufacturingVM            │                                   │
│  │ • rt-CoreServices            │                                   │
│  └──────────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
```

> **Nota:** Este bloco cria VMs que geram custo. Faca o cleanup assim que terminar.

---

### Task 5.1: Adicionar subnets para VMs nas VNets existentes

Antes de criar as VMs, adicione subnets dedicadas nas VNets do Bloco 4.

**Core subnet na CoreServicesVnet:**

1. Pesquise e selecione **Virtual Networks** > **CoreServicesVnet** (em az104-rg4)

2. **Subnets** > **+ Subnet**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `Core`      |
   | Starting address | `10.20.0.0` |
   | Size             | `/24`       |

3. Clique em **Add**

**Manufacturing subnet na ManufacturingVnet:**

4. Navegue para **ManufacturingVnet** (em az104-rg4)

5. **Subnets** > **+ Subnet**:

   | Setting          | Value           |
   | ---------------- | --------------- |
   | Name             | `Manufacturing` |
   | Starting address | `10.30.0.0`     |
   | Size             | `/24`           |

6. Clique em **Add**

   > **Conexao com Bloco 4:** Voce esta evoluindo as VNets criadas no Bloco 4, adicionando subnets para compute. Isso demonstra que VNets sao estruturas vivas que crescem conforme a necessidade.

---

### Task 5.2: Criar CoreServicesVM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. Pesquise **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Subscription         | *sua subscription*                            |
   | Resource group       | `az104-rg5` (crie se necessario)              |
   | Virtual machine name | `CoreServicesVM`                              |
   | Region               | **(US) East US**                              |
   | Availability options | No infrastructure redundancy required         |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** (aceite defaults) > **Next: Networking >**

4. Para Virtual network, selecione **CoreServicesVnet** (de az104-rg4)

   > **Nota:** VMs podem referenciar VNets de outros Resource Groups. O dropdown mostra todas as VNets acessiveis na subscription.

5. Para Subnet, selecione **Core (10.20.0.0/24)**

6. Aba **Monitoring** > **Disable** Boot diagnostics

7. **Review + create** > **Create**

8. **Nao precisa esperar** — continue para a proxima task

---

### Task 5.3: Criar ManufacturingVM

> **Cobranca:** Este recurso gera cobranca enquanto estiver alocado. Desaloque ao pausar o lab (veja [Pausar entre Sessoes](#pausar-entre-sessoes)).

1. **Virtual Machines** > **Create** > **Virtual machine**

2. Aba **Basics**:

   | Setting              | Value                                         |
   | -------------------- | --------------------------------------------- |
   | Resource group       | `az104-rg5`                                   |
   | Virtual machine name | `ManufacturingVM`                             |
   | Region               | **(US) East US**                              |
   | Security type        | **Standard**                                  |
   | Image                | **Windows Server 2025 Datacenter - x64 Gen2** |
   | Size                 | **Standard_D2s_v3**                           |
   | Username             | `localadmin`                                  |
   | Password             | *senha complexa*                              |
   | Public inbound ports | **None**                                      |

3. **Next: Disks >** > **Next: Networking >**

4. Virtual network: **ManufacturingVnet** (de az104-rg4)

5. Subnet: **Manufacturing (10.30.0.0/24)**

6. **Monitoring** > **Disable** Boot diagnostics

7. **Review + create** > **Create**

8. **Aguarde ambas as VMs serem provisionadas** antes de continuar

---

### Task 5.4: Network Watcher — Connection Troubleshoot

1. Pesquise **Network Watcher** > **Connection troubleshoot**

2. Preencha:

   | Setting              | Value                        |
   | -------------------- | ---------------------------- |
   | Source type          | **Virtual machine**          |
   | Virtual machine      | **CoreServicesVM**           |
   | Destination type     | **Select a virtual machine** |
   | Virtual machine      | **ManufacturingVM**          |
   | Preferred IP Version | **Both**                     |
   | Protocol             | **TCP**                      |
   | Destination port     | `3389`                       |

3. **Run diagnostic tests**

4. **Resultado esperado:** Connectivity test = **Unreachable**

   > **Conceito:** VNets diferentes NAO se comunicam por padrao, mesmo estando no mesmo RG ou sendo gerenciadas pela mesma subscription.

---

### Task 5.5: Configurar VNet Peering bidirecional

Peering entre as VNets **do Bloco 4** para habilitar comunicacao.

1. Navegue para **CoreServicesVnet** (em az104-rg4)

2. **Settings** > **Peerings** > **+ Add**:

   | Setting                                          | Value                                   |
   | ------------------------------------------------ | --------------------------------------- |
   | **This virtual network**                         |                                         |
   | Peering link name                                | `CoreServicesVnet-to-ManufacturingVnet` |
   | Allow access to 'ManufacturingVnet'              | **selected**                            |
   | Allow forwarded traffic from 'ManufacturingVnet' | **selected**                            |
   | **Remote virtual network**                       |                                         |
   | Peering link name                                | `ManufacturingVnet-to-CoreServicesVnet` |
   | Virtual network                                  | **ManufacturingVnet (az104-rg4)**       |
   | Allow access to 'CoreServicesVnet'               | **selected**                            |
   | Allow forwarded traffic from 'CoreServicesVnet'  | **selected**                            |

3. Clique em **Add**

4. **Refresh** ate Peering status = **Connected** em ambas as VNets

   > **Conceito:** VNet Peering e **NAO transitivo**. Se A↔B e B↔C, A nao se comunica com C automaticamente.

---

### Task 5.6: Testar conexao via Run Command

1. Navegue para **CoreServicesVM** > **Overview** > anote o **Private IP address**

2. Navegue para **ManufacturingVM** > **Operations** > **Run command** > **RunPowerShellScript**

3. Execute:

   ```powershell
   Test-NetConnection <CoreServicesVM-private-IP> -port 3389
   ```

4. **Resultado esperado:** `TcpTestSucceeded: True`

   > O peering funciona! As VMs se comunicam pela rede backbone da Microsoft.

---

### Task 5.7: Teste de integracao — DNS privado com IP real da VM

Voce atualiza a zona DNS privada do **Bloco 4** com o IP real da CoreServicesVM e testa a resolucao.

1. Navegue para a zona **private.contoso.com** (em az104-rg4)

2. Primeiro, adicione um **Virtual network link** para CoreServicesVnet:

   | Setting         | Value               |
   | --------------- | ------------------- |
   | Link name       | `coreservices-link` |
   | Virtual network | `CoreServicesVnet`  |

3. Clique em **Create** e aguarde

4. Em **Recordsets**, adicione um novo registro com o IP **real** da CoreServicesVM:

   | Setting    | Value                          |
   | ---------- | ------------------------------ |
   | Name       | `corevm`                       |
   | Type       | **A**                          |
   | TTL        | `1`                            |
   | IP address | *IP privado da CoreServicesVM* |

5. Clique em **Add**

6. Agora teste a resolucao a partir da **ManufacturingVM**. Va para **ManufacturingVM** > **Run command** > **RunPowerShellScript**:

   ```powershell
   Resolve-DnsName corevm.private.contoso.com
   ```

7. **Resultado esperado:** O comando retorna o IP privado da CoreServicesVM

   > **Conexao com Bloco 4:** A zona DNS privada criada no Bloco 4 agora resolve nomes reais de VMs do Bloco 5. A ManufacturingVnet (linkada no Bloco 4) e a CoreServicesVnet (linkada agora) podem resolver nomes nesta zona.

---

### Task 5.8: Criar subnet perimeter, Route Table e custom route

**Criar subnet perimeter:**

1. Navegue para **CoreServicesVnet** (em az104-rg4) > **Subnets** > **+ Subnet**:

   | Setting          | Value       |
   | ---------------- | ----------- |
   | Name             | `perimeter` |
   | Starting address | `10.20.1.0` |
   | Size             | `/24`       |

2. Clique em **Add**

**Criar Route Table:**

3. Pesquise **Route tables** > **+ Create**:

   | Setting                  | Value              |
   | ------------------------ | ------------------ |
   | Subscription             | *sua subscription* |
   | Resource group           | `az104-rg5`        |
   | Region                   | **East US**        |
   | Name                     | `rt-CoreServices`  |
   | Propagate gateway routes | **No**             |

4. **Review + create** > **Create**

**Criar custom route:**

5. Navegue para **rt-CoreServices** > **Settings** > **Routes** > **+ Add**:

   | Setting                  | Value                 |
   | ------------------------ | --------------------- |
   | Route name               | `PerimetertoCore`     |
   | Destination type         | **IP Addresses**      |
   | Destination IP addresses | `10.20.0.0/16`        |
   | Next hop type            | **Virtual appliance** |
   | Next hop address         | `10.20.1.7`           |

6. Clique em **Add**

**Associar route table a subnet:**

7. **Subnets** > **+ Associate**:

   | Setting         | Value                            |
   | --------------- | -------------------------------- |
   | Virtual network | **CoreServicesVnet (az104-rg4)** |
   | Subnet          | **Core**                         |

8. Clique em **OK**

   > **Conceito:** UDRs sobrescrevem rotas do sistema. O next hop "Virtual appliance" direciona trafego para um NVA (firewall, proxy). Se o NVA nao existir no IP configurado, o trafego e **descartado**.

---

### Task 5.9: Teste de integracao — Verificar isolamento NSG por subnet

Este teste confirma que o NSG do Bloco 4 afeta apenas a subnet associada.

1. Lembre-se: o NSG **myNSGSecure** esta associado a **SharedServicesSubnet** (Bloco 4)

2. A CoreServicesVM esta na subnet **Core** (sem NSG associado)

3. A ManufacturingVM esta na subnet **Manufacturing** (sem NSG associado)

4. Verifique: navegue para **myNSGSecure** (az104-rg4) > **Subnets**

5. Confirme que apenas **SharedServicesSubnet** esta listada

   > **Validacao:** As VMs NAO sao afetadas pelo NSG porque estao em subnets diferentes. NSGs sao associados a **subnets ou NICs**, nao a VNets inteiras. Se voce quisesse proteger as VMs, precisaria associar o NSG (ou outro) as subnets Core e Manufacturing tambem.

---

### Task 5.10: Teste de integracao final — RBAC de ponta a ponta

Teste final que valida todo o RBAC configurado desde o Bloco 1.

1. Abra uma janela **InPrivate/Incognito**

2. Faca login como **az104-user1** (senha salva no Bloco 1)

3. Navegue para **Virtual Machines**

4. Voce deve ver **CoreServicesVM** e **ManufacturingVM**

5. Selecione **CoreServicesVM** > tente **Stop** (desligar) a VM — deve **funcionar** (VM Contributor permite)

6. Tente deletar o resource group **az104-rg2** — deve **falhar** por dois motivos:
   - az104-user1 nao tem Contributor/Owner no RG
   - O resource lock (Delete) do Bloco 2 impede a exclusao

7. Navegue para **Storage Accounts** > tente criar um — deve **falhar** (VM Contributor nao inclui permissoes de Storage)

   > **Validacao completa:**
   > - **Bloco 1:** Identidade criada ✓
   > - **Bloco 2:** RBAC (VM Contributor) funciona + Lock protege ✓
   > - **Bloco 5:** az104-user1 gerencia VMs mas nao outros recursos ✓

8. **Se parou a VM no passo 5**, inicie-a novamente antes de fechar

9. Feche a janela InPrivate

---

## Modo Desafio - Bloco 5

- [ ] Adicionar subnet `Core` (10.20.0.0/24) na CoreServicesVnet **(Bloco 4)**
- [ ] Adicionar subnet `Manufacturing` (10.30.0.0/24) na ManufacturingVnet **(Bloco 4)**
- [ ] Criar `CoreServicesVM` em az104-rg5, na subnet Core da **VNet do Bloco 4**
- [ ] Criar `ManufacturingVM` em az104-rg5, na subnet Manufacturing da **VNet do Bloco 4**
- [ ] Network Watcher → Unreachable
- [ ] Configurar VNet Peering bidirecional entre VNets **do Bloco 4**
- [ ] Test-NetConnection → Success
- [ ] **Integracao:** Adicionar link DNS + registro A com IP real → Resolve-DnsName da ManufacturingVM
- [ ] Criar subnet `perimeter` + Route Table + custom route (NVA 10.20.1.7)
- [ ] **Integracao:** Verificar NSG isolado por subnet
- [ ] **Integracao final:** Login como az104-user1 → gerenciar VM ✓, criar Storage ✗

---

## Questoes de Prova - Bloco 5

### Questao 5.1
**Uma VM no az104-rg5 usa uma VNet do az104-rg4. E possivel?**

A) Nao, VMs e VNets devem estar no mesmo Resource Group
B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription
C) Sim, mas apenas via ARM template
D) Nao, a VNet precisa ser movida para o mesmo RG

<details>
<summary>Ver resposta</summary>

**Resposta: B) Sim, VMs podem referenciar VNets de qualquer RG na mesma subscription**

No Azure, VMs e VNets nao precisam estar no mesmo RG. Voce pode organizar recursos em RGs diferentes conforme a funcao (networking, compute, etc.) e referencia-los entre si.

</details>

### Questao 5.2
**VNet A tem peering com VNet B. VNet B tem peering com VNet C. VNet A se comunica com VNet C?**

A) Sim, peering e transitivo
B) Nao, peering NAO e transitivo — precisa de peering direto A↔C
C) Sim, se forwarded traffic estiver habilitado
D) Nao, precisa de VPN Gateway

<details>
<summary>Ver resposta</summary>

**Resposta: B) Nao, peering NAO e transitivo**

Peering nao e transitivo. Para A↔C, crie peering direto ou use hub-spoke com NVA/VPN Gateway.

</details>

### Questao 5.3
**Voce criou uma UDR com next hop "Virtual appliance" IP 10.20.1.7, mas nao ha NVA nesse IP. O que acontece com o trafego?**

A) Roteado normalmente, ignorando a regra
B) Descartado (dropped)
C) Azure cria um NVA automaticamente
D) Redirecionado para o gateway padrao

<details>
<summary>Ver resposta</summary>

**Resposta: B) Descartado (dropped)**

UDRs sobrescrevem rotas do sistema. Se o next hop nao for alcancavel, o trafego e descartado sem fallback.

</details>

### Questao 5.4
**Voce configurou VNet Peering entre CoreServicesVnet e ManufacturingVnet. Voce quer que o trafego da ManufacturingVM passe por um NVA na CoreServicesVnet antes de alcançar a CoreServicesVM. O que voce precisa configurar alem do peering?**

A) Apenas um NSG na subnet de destino
B) Uma User-Defined Route (UDR) na subnet da ManufacturingVM com next hop apontando para o NVA
C) Habilitar IP forwarding no NVA e nada mais
D) Criar um VPN Gateway entre as VNets

<details>
<summary>Ver resposta</summary>

**Resposta: B) Uma User-Defined Route (UDR) na subnet da ManufacturingVM com next hop apontando para o NVA**

Para forcar trafego atraves de um NVA, voce precisa criar uma UDR na subnet de origem com o next hop tipo "Virtual appliance" apontando para o IP do NVA. Alem disso, o NVA precisa ter **IP forwarding** habilitado na NIC. Apenas o peering nao e suficiente — ele habilita conectividade direta, mas nao roteia trafego atraves de intermediarios.

</details>

### Questao 5.5
**Voce criou uma Private DNS Zone `private.contoso.com` e vinculou (Virtual Network Link) apenas a VNet A. Uma VM na VNet B (que tem peering com VNet A) tenta resolver `sensorvm.private.contoso.com`. O que acontece?**

A) A resolucao funciona porque o peering compartilha DNS automaticamente
B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada
C) A resolucao funciona se o peering tiver "Allow forwarded traffic" habilitado
D) A resolucao funciona apenas se a VM usar um DNS forwarder na VNet A

<details>
<summary>Ver resposta</summary>

**Resposta: B) A resolucao falha porque a VNet B nao tem Virtual Network Link para a zona privada**

Private DNS Zones resolvem nomes **apenas** para VNets que possuem um Virtual Network Link configurado. O VNet Peering nao propaga resolucao DNS automaticamente. Para que VMs na VNet B resolvam nomes da zona privada, voce precisa criar um Virtual Network Link adicional para a VNet B, ou configurar um DNS forwarder customizado.

</details>

---

# Pausar entre Sessoes

Se voce nao vai completar todos os blocos em um unico dia, desaloque os recursos para evitar cobrancas desnecessarias.

### Pausar (parar cobranca de compute)

```bash
# CLI
az vm deallocate -g az104-rg5 -n CoreServicesVM --no-wait
az vm deallocate -g az104-rg5 -n ManufacturingVM --no-wait
```

```powershell
# PowerShell
Stop-AzVM -ResourceGroupName az104-rg5 -Name CoreServicesVM -Force
Stop-AzVM -ResourceGroupName az104-rg5 -Name ManufacturingVM -Force
```

### Retomar (quando voltar ao lab)

```bash
az vm start -g az104-rg5 -n CoreServicesVM --no-wait
az vm start -g az104-rg5 -n ManufacturingVM --no-wait
```

> **Nota:** Desalocar a VM para a cobranca de compute mas discos e IPs publicos continuam gerando cobranca. Para zerar completamente, delete o Resource Group.

---

# Cleanup Unificado

> **IMPORTANTE:** Remova todos os recursos para evitar custos, especialmente as VMs do Bloco 5.

## Via Azure Portal

1. **Remover Resource Locks primeiro:**
   - `az104-rg2` > **Settings** > **Locks** > Delete `rg-lock`

2. **Deletar Policy Assignments:**
   - Policy > Assignments > delete todas as atribuicoes criadas (tag inherit rg2, tag inherit rg3, allowed locations rg3)

3. **Deletar Custom Role:**
   - Management groups > `az104-mg1` > **Access control (IAM)** > **Roles** > `Custom Support Request` > Delete

4. **Remover subscription do Management Group e deletar MG:**
   - Management groups > `az104-mg1` > selecione a subscription > **Remove**
   - Depois: Management groups > `az104-mg1` > **Delete**

5. **Deletar Resource Groups** (prioridade: VMs primeiro):
   - `az104-rg5` (VMs — PRIORIDADE por custo)
   - `az104-rg4` (VNets, DNS, NSG)
   - `az104-rg3` (Disks, Cloud Shell storage)
   - `az104-rg2` (Storage)

6. **Deletar usuarios e grupos do Entra ID:**
   - Users > delete `az104-user1` e o guest user (por Object ID)
   - Groups > delete `IT Lab Administrators` e `helpdesk`

## Via CLI

> **Nota:** Execute os comandos de policy e lock **antes** de deletar os RGs. Use `az policy assignment list --query "[].{name:name, scope:scope}" -o table` para encontrar os nomes reais das assignments (o portal gera nomes internos que podem diferir do display name).

```bash
# Resolver IDs dinamicamente (evita placeholders)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG2_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/az104-rg2"
RG3_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/az104-rg3"

# 1. Deletar policy assignments ANTES dos RGs
#    Removemos por ID (mais robusto que nome/displayName), filtrando apenas os do lab
for ASSIGN_ID in $(az policy assignment list --scope "$RG2_SCOPE" --query "[?contains(displayName, 'Cost Center')].id" -o tsv); do
  az policy assignment delete --ids "$ASSIGN_ID"
done
for ASSIGN_ID in $(az policy assignment list --scope "$RG3_SCOPE" --query "[?contains(displayName, 'Cost Center') || contains(displayName, 'East US')].id" -o tsv); do
  az policy assignment delete --ids "$ASSIGN_ID"
done

# 2. Remover lock antes de deletar az104-rg2
az lock delete --name rg-lock --resource-group az104-rg2

# 3. Deletar RGs (VMs primeiro por custo)
az group delete --name az104-rg5 --yes --no-wait
az group delete --name az104-rg4 --yes --no-wait
az group delete --name az104-rg3 --yes --no-wait
az group delete --name az104-rg2 --yes --no-wait

# 4. Remover subscription do MG antes de deletar
az account management-group subscription remove --name az104-mg1 --subscription "$SUBSCRIPTION_ID"
az account management-group delete --name az104-mg1

# 5. Deletar custom role
az role definition delete --name "Custom Support Request"

# 6. Deletar usuarios e grupos
USER1_ID=$(az ad user list --filter "startsWith(userPrincipalName, 'az104-user1@')" --query "[0].id" -o tsv)
if [ -n "$USER1_ID" ]; then
  az ad user delete --id "$USER1_ID"
fi
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
az ad user list --filter "userType eq 'Guest'" --query "[].{id:id,mail:mail,displayName:displayName}" -o table
az ad group delete --group "IT Lab Administrators"
az ad group delete --group "helpdesk"
```

## Via PowerShell

> **Nota:** Execute os comandos de policy e lock **antes** de deletar os RGs.

```powershell
# Resolver IDs dinamicamente (evita placeholders)
$subscriptionId = (Get-AzContext).Subscription.Id
$rg2Scope = "/subscriptions/$subscriptionId/resourceGroups/az104-rg2"
$rg3Scope = "/subscriptions/$subscriptionId/resourceGroups/az104-rg3"

# 1. Deletar policy assignments
Get-AzPolicyAssignment -Scope $rg2Scope |
Where-Object {
    $_.DisplayName -match 'Cost Center' -or $_.Properties.DisplayName -match 'Cost Center'
} | ForEach-Object {
    Remove-AzPolicyAssignment -Name $_.Name -Scope $rg2Scope -ErrorAction SilentlyContinue
}
Get-AzPolicyAssignment -Scope $rg3Scope |
Where-Object {
    $_.DisplayName -match 'Cost Center|East US' -or $_.Properties.DisplayName -match 'Cost Center|East US'
} | ForEach-Object {
    Remove-AzPolicyAssignment -Name $_.Name -Scope $rg3Scope -ErrorAction SilentlyContinue
}

# 2. Remover lock e deletar RGs
Remove-AzResourceLock -LockName rg-lock -ResourceGroupName az104-rg2 -Force
Remove-AzResourceGroup -Name az104-rg5 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg4 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg3 -Force -AsJob
Remove-AzResourceGroup -Name az104-rg2 -Force -AsJob

# 3. Remover subscription do MG e deletar
Remove-AzManagementGroupSubscription -GroupName az104-mg1 -SubscriptionId $subscriptionId
Remove-AzManagementGroup -GroupName az104-mg1

# 4. Custom role, usuarios e grupos
Remove-AzRoleDefinition -Name "Custom Support Request" -Force
$user1 = Get-AzADUser -Filter "startsWith(userPrincipalName,'az104-user1@')" | Select-Object -First 1
if ($user1) { Remove-AzADUser -ObjectId $user1.Id }
# Guest users: listar e remover manualmente o ID correto (evita apagar guest indevido)
Get-AzADUser -Filter "userType eq 'Guest'" | Select-Object Id, Mail, DisplayName | Format-Table
Remove-AzADGroup -DisplayName "IT Lab Administrators"
Remove-AzADGroup -DisplayName "helpdesk"
```

> **Nota:** Ao deletar az104-rg3, o storage account do Cloud Shell tambem sera removido. Execute todos os comandos CLI/PowerShell **antes** de deletar az104-rg3, ou use o portal para os passos finais.

---

# Key Takeaways Consolidados

## Bloco 1 - Identity
- Um **tenant** representa sua organizacao no Microsoft Entra ID
- Usuarios podem ser **Member** (internos) ou **Guest** (B2B externos)
- **Groups** organizam usuarios: Security e Microsoft 365. Membership: Assigned ou Dynamic (P1/P2)
- **Usage location** e obrigatoria para licencas
- **Identidades sao a base de todo o RBAC** — sem usuarios/grupos, nao ha controle de acesso

## Bloco 2 - Governance & Compliance
- **Management Groups** organizam subscriptions e permitem heranca de RBAC/Policy
- **RBAC e aditivo** — permissoes somam entre roles; NotActions remove do conjunto de Actions
- **Azure Policy:** Deny bloqueia, Audit reporta, Modify altera automaticamente
- **Allowed Locations** restringe onde recursos podem ser criados
- **Resource Locks** sobrescrevem QUALQUER permissao, incluindo Owner
- **Governanca preparada antecipadamente** garante compliance desde o primeiro recurso

## Bloco 3 - Azure Resources & IaC
- **ARM Templates** e **Bicep** permitem deploy declarativo e repetivel
- **Modify policy valida automaticamente** — tags herdadas em cada deploy sem intervencao manual
- **Allowed Locations valida automaticamente** — recursos fora da regiao permitida sao bloqueados
- **Reader role** permite visualizar mas nao criar/modificar — RBAC funciona em conjunto com policies
- Cloud Shell configurado uma vez e **reusado** em blocos posteriores

## Bloco 4 - Virtual Networking
- **VNet** e a representacao da rede na cloud. Evite sobreposicao de ranges IP
- Cada **subnet** perde 5 IPs reservados pelo Azure (251 utilizaveis em /24)
- **NSG** se aplica por **subnet** ou NIC, nao por VNet inteira
- **ASG** agrupa VMs logicamente para regras NSG simplificadas
- **DNS publico** resolve na internet; **DNS privado** apenas em VNets linkadas
- **VNets sao estruturas evolutivas** — subnets podem ser adicionadas conforme necessidade

## Bloco 5 - Intersite Connectivity
- VMs podem usar VNets de **outros Resource Groups** (cross-RG)
- VNets diferentes **NAO se comunicam** por padrao — peering habilita conectividade
- Peering **NAO e transitivo** (A↔B + B↔C ≠ A↔C)
- **UDRs** sobrescrevem rotas do sistema; trafego sem next hop alcancavel e descartado
- **DNS privado + VNet links** permitem resolucao de nomes entre VNets
- **RBAC + Locks** funcionam de ponta a ponta: VM Contributor gerencia VMs, Lock protege RGs

## Integracao Geral
- **Identidade (Bloco 1)** e a base de toda governanca e acesso
- **Policies (Bloco 2)** sao validadas automaticamente em cada deploy (Blocos 3-4)
- **IaC (Bloco 3)** e uma skill reutilizavel em todo o ambiente
- **Networking (Bloco 4)** e a infraestrutura onde compute (Bloco 5) vive
- **Tudo se conecta:** um usuario criado no Bloco 1 pode gerenciar VMs no Bloco 5 por causa do RBAC do Bloco 2, em VNets do Bloco 4, com DNS resolvendo nomes reais
