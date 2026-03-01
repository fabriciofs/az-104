> Voltar para o [Cenario Contoso](../cenario-contoso.md) | Proximo: [Bloco 2 - Governance & Compliance](bloco2-governance.md)

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

