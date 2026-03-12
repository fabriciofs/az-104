> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 3 - Azure Resources & IaC](bloco3-iac.md)

# Bloco 2 - Governance & Compliance

**Origem:** Lab 02a (Subscriptions & RBAC) + Lab 02b (Azure Policy) + **novos exercicios de integracao**
**Resource Groups utilizados:** `rg-contoso-identity`

## Contexto

Com a identidade configurada no Bloco 1, agora voce estabelece governanca: RBAC para os **usuarios e grupos ja criados**, policies que serao **validadas no Bloco 3** durante o deploy de discos, e locks para proteger recursos. Tudo e feito no `rg-contoso-identity`, que tambem sera usado no Bloco 3 (IaC).

## Diagrama

```
┌────────────────────────────────────────────────────────────┐
│                  Root Management Group                     │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         mg-contoso-prod (Management Group)           │  │
│  │                                                      │  │
│  │  RBAC:                                               │  │
│  │  • VM Contributor → IT Lab Administrators (Bloco 1)  │  │
│  │  • Custom Support Request (custom role)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  rg-contoso-identity                                 │  │
│  │  Tag: Cost Center = 000                              │  │
│  │                                                      │  │
│  │  Policies:                                           │  │
│  │  • Deny: Require tag (testada e removida)            │  │
│  │  • Modify: Inherit tag                               │  │
│  │  • Deny: Allowed Locations (East US only)            │  │
│  │                                                      │  │
│  │  Lock: Delete (rg-lock)                              │  │
│  │                                                      │  │
│  │  RBAC:                                               │  │
│  │  • Reader → Guest user (Bloco 1)                     │  │
│  └──────────────────────────────────────────────────────┘  │
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
   | Management group ID           | `mg-contoso-prod` |
   | Management group display name | `mg-contoso-prod` |

6. Clique em **Submit** e **Refresh**

7. Selecione **mg-contoso-prod** > clique em **details**

8. Clique em **+ Add subscription** e selecione sua subscription > **Save**

   > **Conceito:** O Root Management Group e o topo da hierarquia. Policies e RBAC aplicados em um MG sao herdados por todas as subscriptions filhas. **Sem mover a subscription para dentro do MG, os roles atribuidos nele nao terao efeito nos recursos.**

---

### Task 2.2: Atribuir role built-in (Virtual Machine Contributor)

Voce atribui o role ao grupo **IT Lab Administrators** (criado no Bloco 1), que inclui `contoso-user1` e o guest user. Isso sera testado no **Bloco 5** quando contoso-user1 gerenciar VMs.

1. Selecione o management group **mg-contoso-prod**

2. Selecione **Access control (IAM)** > aba **Roles**

3. Navegue pelos built-in roles. Clique em **View** em um role para ver Permissions, JSON e Assignments

4. Clique em **+ Add** > **Add role assignment**

5. Pesquise e selecione **Virtual Machine Contributor**

   > **Conceito:** O role Virtual Machine Contributor permite gerenciar VMs, mas NAO o SO, a VNet ou o Storage Account conectados.

6. Clique em **Next** > na aba **Members**, clique em **Select Members**

7. Pesquise e selecione o grupo **IT Lab Administrators** > **Select**

8. Clique em **Review + assign** duas vezes

9. Confirme a atribuicao na aba **Role assignments**

   > **Conexao com Bloco 5:** O contoso-user1 (membro do IT Lab Administrators) podera gerenciar VMs em qualquer RG sob este Management Group. Testaremos isso no Bloco 5.

---

### Task 2.3: Criar custom RBAC role

1. No management group **mg-contoso-prod**, va para **Access control (IAM)**

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

1. No recurso **mg-contoso-prod**, selecione **Activity log**

2. Revise as atividades de role assignments

---

### Task 2.5: Criar Resource Group com tags

Voce cria o Resource Group `rg-contoso-identity` para testes de governanca e para uso no Bloco 3 (IaC). Ele recebe a tag `Cost Center`.

1. Pesquise e selecione **Resource groups** > **+ Create**:

   | Setting             | Value                 |
   | ------------------- | --------------------- |
   | Subscription        | *sua subscription*    |
   | Resource group name | `rg-contoso-identity` |
   | Location            | **East US**           |

2. Na aba **Tags**:

   | Name          | Value |
   | ------------- | ----- |
   | `Cost Center` | `000` |

3. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** O rg-contoso-identity sera usado para deploy de managed disks. As policies aplicadas aqui serao validadas quando os discos forem criados.

---

### Task 2.6: Aplicar Azure Policy (Deny) - Require tag no rg-contoso-identity

1. Pesquise e selecione **Policy** > **Authoring** > **Definitions**

2. Pesquise: `Require a tag and its value on resources`

3. Selecione a policy > **Assign policy**

4. Configure o **Scope**: Subscription + Resource Group **rg-contoso-identity**

5. Configure **Basics**:

   | Setting            | Value                                                 |
   | ------------------ | ----------------------------------------------------- |
   | Assignment name    | `Require Cost Center tag with value 000 on resources` |
   | Policy enforcement | **Enabled**                                           |

6. Na aba **Parameters**: Tag Name = `Cost Center`, Tag Value = `000`

7. Clique em **Review + Create** > **Create**

   > Aguarde 5-10 minutos para a policy entrar em vigor.

8. **Teste:** Pesquise **Storage Accounts** > **+ Create** no RG **rg-contoso-identity** com qualquer nome

9. Clique em **Review** > **Create** — voce deve receber **Validation failed** (recurso sem tag)

   > **Conceito:** O efeito **Deny** impede criacao de recursos que nao atendem as condicoes da policy.

---

### Task 2.7: Substituir Deny por Modify policy (Inherit tag) no rg-contoso-identity

1. Va em **Policy** > **Assignments** > localize a atribuicao **Require Cost Center tag...** > **...** > **Delete assignment**

2. Clique em **Assign policy** > Scope: **rg-contoso-identity**

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

   > **Conexao com Bloco 3:** Quando voce criar managed disks no rg-contoso-identity, eles receberao automaticamente a tag `Cost Center: 000`. Voce verificara isso em cada deploy.

---

### Task 2.8: Aplicar Allowed Locations policy no rg-contoso-identity

Esta policy restringe a criacao de recursos ao **East US** apenas. Sera testada no **Bloco 3** tentando criar um disco em outra regiao.

1. Em **Policy** > **Definitions** > pesquise: `Allowed locations`

2. Selecione a policy (nao confunda com "Allowed locations for resource groups") > **Assign policy**

3. Configure o **Scope**: Subscription + Resource Group **rg-contoso-identity**

4. Configure **Basics**:

   | Setting            | Value                                |
   | ------------------ | ------------------------------------ |
   | Assignment name    | `Restrict resources to East US only` |
   | Policy enforcement | **Enabled**                          |

5. Na aba **Parameters**: Allowed locations = **East US**

6. Clique em **Review + Create** > **Create**

   > **Conexao com Bloco 3:** No Bloco 3, voce tentara criar um disco em West US e vera que esta policy bloqueia a criacao.

---

### Task 2.9: Atribuir Reader role ao Guest user no rg-contoso-identity

O guest user (convidado no Bloco 1) recebera permissao somente-leitura no rg-contoso-identity, o que sera testado no **Bloco 3**.

1. Navegue para o resource group **rg-contoso-identity**

2. Selecione **Access control (IAM)** > **+ Add** > **Add role assignment**

3. Pesquise e selecione o role **Reader** > **Next**

4. Na aba **Members**, clique em **Select Members**

5. Pesquise e selecione o **guest user** (convidado no Bloco 1) > **Select**

6. Clique em **Review + assign** duas vezes

7. Confirme na aba **Role assignments** que o guest user tem role **Reader** no rg-contoso-identity

   > **Conexao com Bloco 3:** O guest user podera VER os discos criados no rg-contoso-identity, mas NAO podera criar ou modificar recursos. Testaremos isso no Bloco 3.

---

### Task 2.10: Configurar Resource Lock e testar

1. Navegue para **rg-contoso-identity** > **Settings** > **Locks**

2. Clique em **Add**:

   | Setting   | Value      |
   | --------- | ---------- |
   | Lock name | `rg-lock`  |
   | Lock type | **Delete** |

3. Clique em **Ok**

4. Tente deletar o resource group: **Overview** > **Delete resource group** > digite `rg-contoso-identity` > **Delete**

5. Voce deve receber uma notificacao **negando a exclusao**

   > **Conceito:** Locks protegem contra exclusoes acidentais. O lock Delete permite modificar mas impede exclusao. Locks **sobrescrevem quaisquer permissoes**, incluindo Owner.

---

### Task 2.11: Teste de integracao — Verificar acesso do contoso-user1

Aqui voce valida que o RBAC configurado neste bloco funciona com o usuario do Bloco 1.

1. Abra uma janela **InPrivate/Incognito** no navegador

2. Acesse `https://portal.azure.com`

3. Faca login como **contoso-user1@{seu-dominio}.onmicrosoft.com** usando a senha salva no Bloco 1

4. Pesquise **Management groups** — voce deve ver **mg-contoso-prod**

5. Pesquise **Virtual Machines** — voce deve poder ver a pagina (mas nao havera VMs ainda)

6. Pesquise **Resource groups** — voce deve ver os RGs, mas com permissoes limitadas

7. Tente criar um **Storage Account** no rg-contoso-identity — deve **falhar** (VM Contributor nao tem permissao para storage)

   > **Validacao:** contoso-user1 tem VM Contributor (pode gerenciar VMs) mas nao pode criar outros tipos de recursos. No Bloco 5, testaremos com VMs reais.

8. Feche a janela InPrivate

---

## Modo Desafio - Bloco 2

- [ ] Criar Management Group `mg-contoso-prod` e **mover sua subscription para dentro dele**
- [ ] Atribuir **VM Contributor** ao grupo `IT Lab Administrators` (Bloco 1) no MG
- [ ] Criar custom role **Custom Support Request** (clone + NotActions)
- [ ] Verificar no Activity Log
- [ ] Criar RG `rg-contoso-identity` com tag `Cost Center: 000`
- [ ] Aplicar Deny policy (Require tag) → testar → remover
- [ ] Aplicar Modify policy (Inherit tag)
- [ ] Aplicar **Allowed Locations** (East US only)
- [ ] Atribuir **Reader** ao guest user
- [ ] Criar Resource Lock (Delete) → testar exclusao
- [ ] **Integracao:** Login como contoso-user1 → verificar acesso limitado

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

